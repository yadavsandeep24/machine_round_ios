import Testing
@testable import Checkout

@Suite struct CheckoutServiceTests {
    /// Starts a payment, waits until capture is in flight, then cancels it
    /// (what SwiftUI does to a `.task` when the user leaves the screen).
    private func payThenCancel(_ strategy: CleanupStrategy) async -> (Result<Receipt, any Error>, [GatewayEvent]) {
        let gateway = SimulatedPaymentGateway(captureDelay: .seconds(60), networkDelay: .milliseconds(5))
        let service = CheckoutService(gateway: gateway, cleanup: strategy)
        let payment = Task { try await service.pay(amountMinor: 49_900) }
        await gateway.waitUntilCaptureStarted()
        payment.cancel()
        let result = await payment.result
        return (result, await gateway.events)
    }

    @Test func happyPathCapturesAndNeverReleases() async throws {
        let gateway = SimulatedPaymentGateway(captureDelay: .milliseconds(5), networkDelay: .milliseconds(5))
        let receipt = try await CheckoutService(gateway: gateway).pay(amountMinor: 49_900)
        #expect(receipt == Receipt(holdID: HoldID("hold_1"), amountMinor: 49_900))
        #expect(await gateway.events == [.held(HoldID("hold_1")), .captured(HoldID("hold_1"))])
    }

    @Test func cancellationShieldReleasesTheHoldEvenThoughTheTaskIsCancelled() async {
        let (result, events) = await payThenCancel(.cancellationShield)
        #expect(throws: CancellationError.self) { try result.get() }
        #expect(events == [.held(HoldID("hold_1")), .released(HoldID("hold_1"))])
    }

    @Test func unstructuredTaskAlsoReleasesTheHoldTheOldWay() async {
        let (result, events) = await payThenCancel(.unstructuredTask)
        #expect(throws: CancellationError.self) { try result.get() }
        #expect(events == [.held(HoldID("hold_1")), .released(HoldID("hold_1"))])
    }

    @Test func naiveCleanupLeaksTheHold() async {
        let (_, events) = await payThenCancel(.naive)
        #expect(events == [.held(HoldID("hold_1")), .releaseSkippedByCancellation(HoldID("hold_1"))])
    }

    @available(iOS 27, macOS 27, *)
    @Test func insideTheShieldTheTaskLooksNotCancelled() async {
        let observed = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            let outside = Task.isCancelled
            let inside = withTaskCancellationShield {
                (Task.isCancelled, Task.hasActiveCancellationShield, (try? Task.checkCancellation()) != nil)
            }
            return (outside, inside, Task.isCancelled)
        }
        let (outside, inside, after) = await observed.value
        #expect(outside == true)
        #expect(inside.0 == false) // isCancelled is false while shielded
        #expect(inside.1 == true) // and the task knows it is shielded
        #expect(inside.2 == true) // checkCancellation() does not throw
        #expect(after == true) // the shield does not clear cancellation; it only hides it
    }
}
