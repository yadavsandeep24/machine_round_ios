import Testing
@testable import Checkout

@MainActor
@Suite struct CheckoutViewModelTests {
    @Test func paySucceeds() async {
        let gateway = SimulatedPaymentGateway(captureDelay: .milliseconds(5), networkDelay: .milliseconds(5))
        let model = CheckoutViewModel(service: CheckoutService(gateway: gateway), amountMinor: 1_000)

        model.pay()
        #expect(model.isProcessing)
        await model.waitForPayment()

        #expect(model.state == .paid(Receipt(holdID: HoldID("hold_1"), amountMinor: 1_000)))
    }

    @Test func cancelMovesToCancelledAndReleasesTheHold() async {
        let gateway = SimulatedPaymentGateway(captureDelay: .seconds(60), networkDelay: .milliseconds(5))
        let model = CheckoutViewModel(service: CheckoutService(gateway: gateway), amountMinor: 1_000)

        model.pay()
        await gateway.waitUntilCaptureStarted()
        model.cancel()
        await model.waitForPayment()

        #expect(model.state == .cancelled)
        #expect(await gateway.events == [.held(HoldID("hold_1")), .released(HoldID("hold_1"))])
    }

    @Test func payWhileProcessingIsIgnored() async {
        let gateway = SimulatedPaymentGateway(captureDelay: .milliseconds(5), networkDelay: .milliseconds(5))
        let model = CheckoutViewModel(service: CheckoutService(gateway: gateway), amountMinor: 1_000)

        model.pay()
        model.pay()
        await model.waitForPayment()

        #expect(await gateway.events.count == 2) // one hold, one capture
    }
}
