import Checkout
import Core
import SwiftUI

public struct RootView: View {
    let dependencies: AppDependencies
    @Environment(\.openURL) private var openURL

    public init(dependencies: AppDependencies = .live()) {
        self.dependencies = dependencies
    }

    public var body: some View {
        NavigationStack {
            CheckoutView(model: CheckoutViewModel(
                orderId: "order_1",
                lines: [("Monthly plan", Money(minor: 49_900)), ("GST (18%)", Money(minor: 8_982))],
                deps: .init(gateway: DemoGateway(), store: dependencies.store, openURL: { openURL($0) })
            ))
        }
        .tint(Theme.accent)
    }
}
