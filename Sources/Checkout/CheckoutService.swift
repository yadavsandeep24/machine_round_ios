import Foundation

/// How to run cleanup when the payment task may already be cancelled.
public enum CleanupStrategy: Sendable, CaseIterable {
    /// NEW (Swift 6.4, SE-0504): `withTaskCancellationShield`. Structured, awaited,
    /// and code inside sees `Task.isCancelled == false`.
    case cancellationShield
    /// OLD: start an unstructured `Task {}`. It does not inherit cancellation, so
    /// the release runs, but it is a new task outside structured concurrency.
    case unstructuredTask
    /// BUG, for comparison: just call it. The task is cancelled, so the call throws
    /// `CancellationError` straight away and the hold leaks.
    case naive
}

/// Pays with a reserve-then-capture flow and guarantees the hold is released
/// if anything goes wrong, including the user leaving the screen (task cancellation).
public struct CheckoutService: Sendable {
    let gateway: any PaymentGateway
    let cleanup: CleanupStrategy

    public init(gateway: any PaymentGateway, cleanup: CleanupStrategy = .cancellationShield) {
        self.gateway = gateway
        self.cleanup = cleanup
    }

    public func pay(amountMinor: Int) async throws -> Receipt {
        let hold = try await gateway.placeHold(amountMinor: amountMinor)
        do {
            let receipt = try await gateway.capture(hold)
            return Receipt(holdID: receipt.holdID, amountMinor: amountMinor)
        } catch {
            // We are probably cancelled here. Cleanup must still reach the server.
            await release(hold)
            throw error
        }
    }

    func release(_ hold: HoldID) async {
        switch cleanup {
        case .cancellationShield:
            if #available(iOS 27, macOS 27, *) {
                await withTaskCancellationShield {
                    try? await gateway.releaseHold(hold)
                }
            } else {
                await releaseInUnstructuredTask(hold) // same guarantee on older OS versions
            }
        case .unstructuredTask:
            await releaseInUnstructuredTask(hold)
        case .naive:
            try? await gateway.releaseHold(hold)
        }
    }

    /// Before Swift 6.4: a new top-level task is not cancelled by its creator.
    /// We await `.value` so the release still finishes before `pay` returns;
    /// forgetting this `await` turns it into fire-and-forget.
    private func releaseInUnstructuredTask(_ hold: HoldID) async {
        let gateway = gateway
        await Task { try? await gateway.releaseHold(hold) }.value
    }
}
