import Core

/// Offline-first: the screen shows the cache at once, the network replaces it
/// and writes it back.
public protocol PostRepository: Sendable {
    func cachedPosts() -> [Post]
    /// Fetches page 1 and replaces the cache.
    func refresh() async throws(AppError) -> [Post]
    /// Cache first; network fallback for posts that were never cached (deep link, search).
    func post(id: Int) async throws(AppError) -> Post
    func comments(postId: Int) async throws(AppError) -> [Comment]
}

public struct LivePostRepository: PostRepository {
    public static let pageSize = 20
    private static let cacheKey = "posts_cache_v1"

    private let api: APIClient
    private let store: any KeyValueStore

    public init(api: APIClient, store: any KeyValueStore) {
        self.api = api
        self.store = store
    }

    public func cachedPosts() -> [Post] {
        store.value([Post].self, forKey: Self.cacheKey) ?? []
    }

    public func refresh() async throws(AppError) -> [Post] {
        let posts: [Post] = try await api.get("posts", query: ["_page": "1", "_limit": "\(Self.pageSize)"])
        store.setValue(posts, forKey: Self.cacheKey)
        return posts
    }

    public func post(id: Int) async throws(AppError) -> Post {
        if let cached = cachedPosts().first(where: { $0.id == id }) { return cached }
        return try await api.get("posts/\(id)")
    }

    public func comments(postId: Int) async throws(AppError) -> [Comment] {
        try await api.get("posts/\(postId)/comments")
    }
}
