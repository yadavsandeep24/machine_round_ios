import Core
import Orders
import SwiftUI

public struct RootView: View {
    let dependencies: AppDependencies

    public init(dependencies: AppDependencies = .live()) {
        self.dependencies = dependencies
    }

    private var page: OrdersPage? {
        try? OrdersDecoder.shared.decode(OrdersPage.self, from: Data(SampleOrders.json.utf8))
    }

    public var body: some View {
        NavigationStack {
            List {
                if let page {
                    Section("Orders (\(page.$items.skipped.count) malformed skipped)") {
                        ForEach(page.items) { order in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("#\(order.id)").font(.headline)
                                    Text(order.createdAt, format: .dateTime.day().month().hour().minute())
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(order.amount, format: .currency(code: order.currency))
                            }
                        }
                    }
                }
            }
            .navigationTitle("Decoded orders")
        }
        .tint(Theme.accent)
    }
}
