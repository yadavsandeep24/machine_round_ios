import Core
import Foundation
@testable import Posts

func makePost(_ id: Int, _ title: String? = nil) -> Post {
    Post(id: id, userId: 1, title: title ?? "Post \(id)", body: "Body \(id)")
}

/// In-memory repository with the same contract as the real one.
final class FakePostRepository: PostRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var _cache: [Post]
    var remote: [Post] = (1...45).map { makePost($0) }
    var failWith: AppError?
    private(set) var refreshCalls = 0
    /// Lets a test hold a request in flight.
    var gate: (@Sendable () async -> Void)?

    init(cached: [Post] = []) { _cache = cached }

    func cachedPosts() -> [Post] { lock.withLock { _cache } }

    func refresh() async throws(AppError) -> [Post] {
        lock.withLock { refreshCalls += 1 }
        await gate?()
        if let failWith { throw failWith }
        let first = Array(remote.prefix(20))
        lock.withLock { _cache = first }
        return first
    }

    var remoteById: [Int: Post] = [:]
    var commentsFailWith: AppError?
    var commentsDelay: Duration = .zero

    func post(id: Int) async throws(AppError) -> Post {
        if let cached = cachedPosts().first(where: { $0.id == id }) { return cached }
        guard let remote = remoteById[id] else { throw .notFound }
        return remote
    }

    func comments(postId: Int) async throws(AppError) -> [Comment] {
        if commentsDelay > .zero { try? await Task.sleep(for: commentsDelay) }
        if Task.isCancelled { throw .cancelled }
        if let commentsFailWith { throw commentsFailWith }
        return [Comment(id: postId * 10, name: "Commenter", email: "a@b.c", body: "Nice post")]
    }
}
