import Core
import SwiftUI
import Transactions

public struct RootView: View {
    let dependencies: AppDependencies

    public init(dependencies: AppDependencies = .live()) {
        self.dependencies = dependencies
    }

    public var body: some View {
        NavigationStack {
            TransactionsView(model: TransactionsViewModel(api: FakeTransactionAPI(all: FakeTransactionAPI.sample(count: 200))))
        }
        .tint(Theme.accent)
    }
}
