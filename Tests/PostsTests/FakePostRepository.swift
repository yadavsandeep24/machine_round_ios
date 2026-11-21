import Core
import Foundation
@testable import Posts

func post(_ id: Int, _ title: String? = nil) -> Post {
    Post(id: id, userId: 1, title: title ?? "Post \(id)", body: "Body \(id)")
}

/// In-memory repository with the same contract as the real one.
final class FakePostRepository: PostRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var _cache: [Post]
    var remote: [Post] = (1...45).map { post($0) }
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
}
