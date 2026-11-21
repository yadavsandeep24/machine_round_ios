import Core
import SwiftUI

public struct RootView: View {
    let dependencies: AppDependencies

    public init(dependencies: AppDependencies = .live()) {
        self.dependencies = dependencies
    }

    public var body: some View {
        NavigationStack {
            EmptyStateView("Add your first feature in Sources/", systemImage: "hammer")
                .navigationTitle("Machine Round")
        }
        .tint(Theme.accent)
    }
}

#Preview { RootView(dependencies: AppDependencies(api: APIClient(baseURL: Endpoints.jsonPlaceholder), store: InMemoryStore())) }
