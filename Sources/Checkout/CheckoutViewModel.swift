import Core
import Foundation
import Observation

@MainActor
@Observable
public final class CheckoutViewModel {
    public enum State: Equatable {
        case idle
        case processing
        case paid(Receipt)
        case cancelled
        case failed(AppError)
    }

    public private(set) var state: State = .idle
    public let amountMinor: Int

    private let service: CheckoutService
    private var payment: Task<Void, Never>?

    public init(service: CheckoutService, amountMinor: Int) {
        self.service = service
        self.amountMinor = amountMinor
    }

    public var isProcessing: Bool { state == .processing }

    public func pay() {
        guard !isProcessing else { return }
        state = .processing
        payment = Task {
            do {
                state = .paid(try await service.pay(amountMinor: amountMinor))
            } catch is CancellationError {
                state = .cancelled
            } catch {
                state = .failed(AppError.map(error))
            }
        }
    }

    /// User tapped Cancel or left the screen. The service still releases the hold.
    public func cancel() {
        payment?.cancel()
    }

    /// For tests: wait for the current payment to finish.
    public func waitForPayment() async {
        await payment?.value
    }
}
