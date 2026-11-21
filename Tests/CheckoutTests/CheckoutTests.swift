import Core
import Foundation
import Testing
@testable import Checkout

@Suite struct PaymentMachineTests {
    @Test func upiHappyPath() {
        let s = PaymentState.idle
            .reduce(.pay(key: "k1"))
            .reduce(.created(paymentId: "p1", authorizationURL: "upi://pay"))
            .reduce(.returnedFromAuthorization)
            .reduce(.status(.pending))
            .reduce(.status(.succeeded))
        #expect(s == .succeeded(paymentId: "p1"))
    }

    @Test func secondPayWhileInitiatingIsIgnored() {
        #expect(PaymentState.idle.reduce(.pay(key: "k1")).reduce(.pay(key: "k2")) == .initiating(key: "k1"))
    }

    @Test func timeoutIsUnknownAndALateSuccessStillLands() {
        let unknown = PaymentState.idle.reduce(.pay(key: "k")).reduce(.created(paymentId: "p", authorizationURL: nil)).reduce(.timedOut)
        #expect(unknown == .unknown(key: "k", paymentId: "p"))
        #expect(unknown.reduce(.status(.pending)) == unknown)
        #expect(unknown.reduce(.status(.succeeded)) == .succeeded(paymentId: "p"))
    }

    @Test func successIsFinal() {
        let done = PaymentState.succeeded(paymentId: "p")
        #expect(done.reduce(.status(.failed(reason: "x"))) == done)
        #expect(done.reduce(.pay(key: "k")) == done)
    }

    @Test func moneyIsExactAndFormattedForIndia() throws {
        let total = try Money.sum([Money(minor: 49_900), Money(minor: 8_982)])
        #expect(total.minor == 58_882)
        #expect(total.formatted == "₹588.82")
        #expect(throws: MoneyError.self) { try Money.sum([Money(minor: 1, currency: "USD")]) }
    }
}

/// Scriptable gateway: queued statuses, idempotency by key, optional lost first response.
final class FakeGateway: PaymentGateway, @unchecked Sendable {
    private let lock = NSLock()
    var statuses: [GatewayStatus]
    var loseFirstCreateResponse = false
    var card = true
    private(set) var createKeys: [String] = []
    private var byKey: [String: CreatedPayment] = [:]
    var uniquePayments: Int { lock.withLock { Set(byKey.values.map(\.paymentId)).count } }

    init(statuses: [GatewayStatus]) { self.statuses = statuses }

    func create(_ request: CreatePaymentRequest, idempotencyKey: String) async throws -> CreatedPayment {
        try lock.withLock {
            createKeys.append(idempotencyKey)
            let created = byKey[idempotencyKey] ?? CreatedPayment(paymentId: "pay_\(byKey.count + 1)", authorizationURL: card ? nil : "upi://pay")
            byKey[idempotencyKey] = created
            if loseFirstCreateResponse { loseFirstCreateResponse = false; throw URLError(.timedOut) } // server created it, reply lost
            return created
        }
    }

    func status(paymentId: String) async throws -> GatewayStatus {
        lock.withLock { statuses.isEmpty ? .pending : statuses.removeFirst() }
    }
}

final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var n = 0
    func next() -> String { lock.withLock { n += 1; return "key_\(n)" } }
}

@MainActor
@Suite struct CheckoutViewModelTests {
    func makeModel(_ gateway: FakeGateway, store: InMemoryStore = InMemoryStore(), opened: OpenedURLs = OpenedURLs()) -> CheckoutViewModel {
        let counter = Counter()
        return CheckoutViewModel(
            orderId: "o1",
            lines: [("Plan", Money(minor: 10_000))],
            deps: .init(gateway: gateway, store: store, newKey: { counter.next() }, sleep: { _ in },
                        openURL: { opened.urls.append($0) }, pollDelays: Array(repeating: .zero, count: 4))
        )
    }

    @Test func upiOpensTheAppThenPollsAfterReturning() async {
        let gateway = FakeGateway(statuses: [.pending, .succeeded])
        gateway.card = false
        let opened = OpenedURLs()
        let model = makeModel(gateway, opened: opened)
        await model.pay()
        #expect(opened.urls.map(\.absoluteString) == ["upi://pay"])
        guard case .awaitingAuthorization = model.state else { Issue.record("\(model.state)"); return }
        await model.appBecameActive()
        #expect(model.state == .succeeded(paymentId: "pay_1"))
    }

    @Test func doubleTapCreatesOnePayment() async {
        let gateway = FakeGateway(statuses: [.succeeded])
        let model = makeModel(gateway)
        async let first: Void = model.pay()
        async let second: Void = model.pay()
        _ = await (first, second)
        #expect(gateway.createKeys == ["key_1"])
        #expect(model.state == .succeeded(paymentId: "pay_1"))
    }

    @Test func lostCreateResponseIsRetriedWithTheSameKey() async {
        let gateway = FakeGateway(statuses: [.succeeded])
        gateway.loseFirstCreateResponse = true
        let model = makeModel(gateway)
        await model.pay()
        #expect(gateway.createKeys == ["key_1", "key_1"])
        #expect(gateway.uniquePayments == 1)
        #expect(model.state == .succeeded(paymentId: "pay_1"))
    }

    @Test func noAnswerInTimeIsUnknownNeverFailed() async {
        let gateway = FakeGateway(statuses: [.pending, .pending, .pending, .pending, .succeeded])
        let model = makeModel(gateway)
        await model.pay()
        #expect(model.state == .unknown(key: "key_1", paymentId: "pay_1"))
        await model.checkAgain()
        #expect(model.state == .succeeded(paymentId: "pay_1"))
    }

    @Test func declineThenRetryUsesANewKey() async {
        let gateway = FakeGateway(statuses: [.failed(reason: "Card declined"), .succeeded])
        let model = makeModel(gateway)
        await model.pay()
        #expect(model.state == .failed(reason: "Card declined"))
        await model.pay()
        #expect(gateway.createKeys == ["key_1", "key_2"])
        #expect(model.state == .succeeded(paymentId: "pay_2"))
    }

    @Test func relaunchRechecksTheSavedPayment() async {
        let store = InMemoryStore()
        store.setValue(PendingPayment(key: "k", paymentId: "pay_9"), forKey: "pending_payment_v1")
        let model = makeModel(FakeGateway(statuses: [.succeeded]), store: store)
        await model.restoreIfNeeded()
        #expect(model.state == .succeeded(paymentId: "pay_9"))
        #expect(store.data(forKey: "pending_payment_v1") == nil)
    }
}

@MainActor final class OpenedURLs { var urls: [URL] = [] }
