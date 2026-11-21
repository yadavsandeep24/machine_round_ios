import Core
import Foundation
import Observation

@MainActor
@Observable
public final class CheckoutViewModel {
    public private(set) var state: PaymentState = .idle
    public var method: PaymentMethod = .upi
    public let lines: [(title: String, price: Money)]
    public let total: Money

    public struct Dependencies: Sendable {
        public var gateway: any PaymentGateway
        public var store: any KeyValueStore
        public var newKey: @Sendable () -> String
        public var sleep: @Sendable (Duration) async throws -> Void
        /// Opens the UPI app / 3DS page (`openURL` in the view).
        public var openURL: @MainActor @Sendable (URL) -> Void
        /// Exponential backoff, about 60 s in total, then UNKNOWN.
        public var pollDelays: [Duration]

        public init(
            gateway: any PaymentGateway, store: any KeyValueStore,
            newKey: @escaping @Sendable () -> String = { "idem_\(UUID().uuidString)" },
            sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) },
            openURL: @escaping @MainActor @Sendable (URL) -> Void = { _ in },
            pollDelays: [Duration] = [1, 2, 4, 8, 15, 30].map { .seconds($0) }
        ) {
            self.gateway = gateway
            self.store = store
            self.newKey = newKey
            self.sleep = sleep
            self.openURL = openURL
            self.pollDelays = pollDelays
        }
    }

    @ObservationIgnored private let deps: Dependencies
    @ObservationIgnored private let orderId: String
    @ObservationIgnored private var polling = false
    private static let pendingKey = "pending_payment_v1"

    public init(orderId: String, lines: [(title: String, price: Money)], deps: Dependencies) {
        self.orderId = orderId
        self.lines = lines
        self.total = (try? Money.sum(lines.map(\.price))) ?? Money(minor: 0)
        self.deps = deps
    }

    private func send(_ event: PaymentEvent) { state = state.reduce(event) }

    /// Relaunch after an app kill: re-check the last in-flight payment.
    public func restoreIfNeeded() async {
        guard case .idle = state, let pending = deps.store.value(PendingPayment.self, forKey: Self.pendingKey) else { return }
        send(.restored(key: pending.key, paymentId: pending.paymentId))
        await poll(paymentId: pending.paymentId)
    }

    public func pay() async {
        switch state {
        case .idle, .failed: break
        default: return // double tap: the state already left .idle synchronously
        }
        if case .failed = state { send(.reset) }
        let key = deps.newKey() // one key per attempt; a retry after FAILED gets a new one
        send(.pay(key: key))
        let request = CreatePaymentRequest(orderId: orderId, amount: total, method: method)
        let created: CreatedPayment
        do {
            created = try await deps.gateway.create(request, idempotencyKey: key)
        } catch {
            // Lost response: the payment may exist. Retry ONCE with the SAME key.
            do {
                created = try await deps.gateway.create(request, idempotencyKey: key)
            } catch {
                send(.createFailed(reason: "Could not start the payment. You were not charged."))
                return
            }
        }
        deps.store.setValue(PendingPayment(key: key, paymentId: created.paymentId), forKey: Self.pendingKey)
        send(.created(paymentId: created.paymentId, authorizationURL: created.authorizationURL))
        if let url = created.authorizationURL.flatMap(URL.init(string:)) {
            deps.openURL(url) // polling starts when the user comes back
        } else {
            await poll(paymentId: created.paymentId)
        }
    }

    /// Call when `scenePhase` becomes `.active` (back from the UPI app or background).
    public func appBecameActive() async {
        if case .awaitingAuthorization = state { send(.returnedFromAuthorization) }
        if case .processing(_, let id) = state { await poll(paymentId: id) }
    }

    public func checkAgain() async {
        if case .unknown(_, let id) = state { await poll(paymentId: id) }
    }

    private func poll(paymentId: String) async {
        guard !polling else { return } // one poller at a time
        polling = true
        defer { polling = false }
        for delay in deps.pollDelays {
            do { try await deps.sleep(delay) } catch { return } // view gone: stop quietly
            guard let status = try? await deps.gateway.status(paymentId: paymentId) else {
                continue // network blip while polling is NOT a failure
            }
            send(.status(status))
            if status != .pending {
                deps.store.remove(Self.pendingKey)
                return
            }
        }
        send(.timedOut)
    }
}
