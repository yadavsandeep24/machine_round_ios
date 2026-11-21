import Core
import Foundation

/// Composition root: the one place that knows concrete types. Features get
/// protocols; tests and previews pass fakes.
public struct AppDependencies: Sendable {
    public var api: APIClient
    public var store: any KeyValueStore

    public init(api: APIClient, store: any KeyValueStore) {
        self.api = api
        self.store = store
    }

    public static func live() -> AppDependencies {
        AppDependencies(api: APIClient(baseURL: Endpoints.jsonPlaceholder), store: UserDefaultsStore())
    }
}
