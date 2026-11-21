import Core
import Posts
import SwiftUI

public struct RootView: View {
    let dependencies: AppDependencies
    @State private var favorites: FavoritesStore

    public init(dependencies: AppDependencies = .live()) {
        self.dependencies = dependencies
        _favorites = State(initialValue: FavoritesStore(store: dependencies.store))
    }

    public var body: some View {
        NavigationStack {
            PostsView(model: PostsViewModel(repository: dependencies.postRepository))
        }
        .environment(favorites)
        .tint(Theme.accent)
    }
}

#Preview { RootView(dependencies: AppDependencies(api: APIClient(baseURL: Endpoints.jsonPlaceholder), store: InMemoryStore())) }
