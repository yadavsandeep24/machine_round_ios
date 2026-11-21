import SwiftUI

public struct CheckoutView: View {
    @State private var model: CheckoutViewModel
    @Environment(\.scenePhase) private var scenePhase

    public init(model: CheckoutViewModel) { _model = State(initialValue: model) }

    public var body: some View {
        @Bindable var model = model
        Group {
            switch model.state {
            case .initiating, .processing:
                status(spinner: true, "Processing payment…", "Please don’t close the app.")
            case .awaitingAuthorization:
                status(spinner: true, "Approve the payment in your UPI app", "Come back here after approving. We’ll confirm automatically.")
            case .succeeded(let id):
                status(spinner: false, "Paid \(model.total.formatted)", "Payment ID \(id)", symbol: "checkmark.circle.fill")
            case .unknown:
                VStack(spacing: 16) {
                    status(spinner: false, "We’re confirming your payment",
                           "This is taking longer than usual. You will not be charged twice; if money was debited and the payment fails, it is refunded automatically.",
                           symbol: "clock")
                    Button("Check status") { Task { await model.checkAgain() } }.buttonStyle(.borderedProminent)
                }
            case .idle, .failed:
                Form {
                    Section("Order summary") {
                        ForEach(model.lines, id: \.title) { line in
                            LabeledContent(line.title, value: line.price.formatted)
                        }
                        LabeledContent("Total") { Text(model.total.formatted).bold() }
                    }
                    Section("Pay with") {
                        Picker("Method", selection: $model.method) {
                            Text("UPI app").tag(PaymentMethod.upi)
                            Text("Card (gateway hosted fields)").tag(PaymentMethod.card)
                        }
                        .pickerStyle(.inline)
                        .labelsHidden()
                    }
                    if case .failed(let reason) = model.state {
                        Text(reason).foregroundStyle(.red)
                    }
                    Button(model.state == .idle ? "Pay \(model.total.formatted)" : "Try again · \(model.total.formatted)") {
                        Task { await model.pay() }
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .navigationTitle("Checkout")
        .task { await model.restoreIfNeeded() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await model.appBecameActive() } }
        }
    }

    private func status(spinner: Bool, _ title: String, _ subtitle: String, symbol: String? = nil) -> some View {
        VStack(spacing: 12) {
            if spinner { ProgressView().controlSize(.large) }
            if let symbol { Image(systemName: symbol).font(.system(size: 56)).foregroundStyle(.tint) }
            Text(title).font(.title3.bold()).multilineTextAlignment(.center)
            Text(subtitle).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
