import Core
import Posts
import SwiftUI

public struct RootView: View {
    let dependencies: AppDependencies

    public init(dependencies: AppDependencies = .live()) {
        self.dependencies = dependencies
    }

    public var body: some View {
        NavigationStack {
            PostsView(model: PostsViewModel(repository: dependencies.postRepository))
        }
        .tint(Theme.accent)
    }
}

#Preview { RootView(dependencies: AppDependencies(api: APIClient(baseURL: Endpoints.jsonPlaceholder), store: InMemoryStore())) }
