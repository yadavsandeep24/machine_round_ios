import Core
import SwiftUI

public struct CheckoutView: View {
    @State private var model: CheckoutViewModel
    private let gateway: SimulatedPaymentGateway
    @State private var log: [GatewayEvent] = []

    public init(gateway: SimulatedPaymentGateway = SimulatedPaymentGateway()) {
        self.gateway = gateway
        _model = State(initialValue: CheckoutViewModel(service: CheckoutService(gateway: gateway), amountMinor: 49_900))
    }

    public var body: some View {
        List {
            Section {
                LabeledContent("Amount", value: (Decimal(model.amountMinor) / 100).formatted(.currency(code: "INR")))
                statusRow
            }
            Section {
                if model.isProcessing {
                    Button("Cancel payment", role: .destructive) { model.cancel() }
                } else {
                    Button("Pay") { model.pay() }
                }
            } footer: {
                Text("Tap Pay, then Cancel while it is waiting for the bank. The hold is still released.")
            }
            Section("Gateway log") {
                if log.isEmpty { Text("No calls yet").foregroundStyle(.secondary) }
                ForEach(Array(log.enumerated()), id: \.offset) { _, event in
                    Text(Self.describe(event)).font(.callout.monospaced())
                }
            }
        }
        .navigationTitle("Checkout")
        .task {
            // Demo only: refresh the gateway log a few times a second.
            while !Task.isCancelled {
                log = await gateway.events
                try? await Task.sleep(for: .milliseconds(200))
            }
        }
    }

    @ViewBuilder private var statusRow: some View {
        switch model.state {
        case .idle: LabeledContent("Status", value: "Ready")
        case .processing: LabeledContent("Status") { ProgressView() }
        case .paid(let receipt): LabeledContent("Status", value: "Paid (\(receipt.holdID))")
        case .cancelled: LabeledContent("Status", value: "Cancelled")
        case .failed(let error): LabeledContent("Status", value: error.userMessage)
        }
    }

    static func describe(_ event: GatewayEvent) -> String {
        switch event {
        case .held(let id): "HOLD     \(id)"
        case .captured(let id): "CAPTURE  \(id)"
        case .released(let id): "RELEASE  \(id)"
        case .releaseSkippedByCancellation(let id): "LEAKED   \(id) (release cancelled)"
        }
    }
}

#Preview { NavigationStack { CheckoutView() } }
