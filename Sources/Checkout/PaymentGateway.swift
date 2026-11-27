import Foundation

public struct HoldID: Hashable, Sendable, CustomStringConvertible {
    public let rawValue: String
    public init(_ rawValue: String) { self.rawValue = rawValue }
    public var description: String { rawValue }
}

public struct Receipt: Equatable, Sendable {
    public let holdID: HoldID
    public let amountMinor: Int
}

/// A card or wallet gateway with a two-step flow: reserve funds, then capture.
/// If capture does not happen, the hold MUST be released, or the user's money
/// stays blocked for days.
public protocol PaymentGateway: Sendable {
    func placeHold(amountMinor: Int) async throws -> HoldID
    /// Slow: waits for 3-DS / bank confirmation.
    func capture(_ hold: HoldID) async throws -> Receipt
    func releaseHold(_ hold: HoldID) async throws
}

/// What the gateway saw, in order. Used by the demo log and by tests.
public enum GatewayEvent: Equatable, Sendable {
    case held(HoldID)
    case captured(HoldID)
    case released(HoldID)
    /// A release that never reached the server because the task was already cancelled.
    case releaseSkippedByCancellation(HoldID)
}

/// In-memory gateway that behaves like a URLSession-backed one: every call
/// checks for cancellation first and throws `CancellationError` if the task
/// was cancelled. That is exactly why naive cleanup fails.
public actor SimulatedPaymentGateway: PaymentGateway {
    public private(set) var events: [GatewayEvent] = []
    private let captureDelay: Duration
    private let networkDelay: Duration
    private var nextID = 1
    private var captureStartedWaiters: [CheckedContinuation<Void, Never>] = []
    private var captureStarted = false

    public init(captureDelay: Duration = .seconds(3), networkDelay: Duration = .milliseconds(150)) {
        self.captureDelay = captureDelay
        self.networkDelay = networkDelay
    }

    public func placeHold(amountMinor: Int) async throws -> HoldID {
        try await Task.sleep(for: networkDelay)
        let id = HoldID("hold_\(nextID)")
        nextID += 1
        events.append(.held(id))
        return id
    }

    public func capture(_ hold: HoldID) async throws -> Receipt {
        captureStarted = true
        captureStartedWaiters.forEach { $0.resume() }
        captureStartedWaiters.removeAll()
        try await Task.sleep(for: captureDelay) // throws CancellationError when the task is cancelled
        events.append(.captured(hold))
        return Receipt(holdID: hold, amountMinor: 0)
    }

    public func releaseHold(_ hold: HoldID) async throws {
        do {
            try await Task.sleep(for: networkDelay) // a real network call also fails fast when cancelled
        } catch {
            events.append(.releaseSkippedByCancellation(hold))
            throw error
        }
        events.append(.released(hold))
    }

    /// Test helper: suspends until a capture is in flight.
    public func waitUntilCaptureStarted() async {
        if captureStarted { return }
        await withCheckedContinuation { captureStartedWaiters.append($0) }
    }
}
