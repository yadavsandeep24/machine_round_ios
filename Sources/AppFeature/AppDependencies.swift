import Core
import Foundation
import Posts

/// Composition root: the one place that knows concrete types. Features get
/// protocols; tests and previews pass fakes.
public struct AppDependencies: Sendable {
    public var api: APIClient
    public var store: any KeyValueStore

    public var postRepository: any PostRepository

    public init(api: APIClient, store: any KeyValueStore, postRepository: (any PostRepository)? = nil) {
        self.api = api
        self.store = store
        self.postRepository = postRepository ?? LivePostRepository(api: api, store: store)
    }

    public static func live() -> AppDependencies {
        AppDependencies(api: APIClient(baseURL: Endpoints.jsonPlaceholder), store: UserDefaultsStore())
    }
}
