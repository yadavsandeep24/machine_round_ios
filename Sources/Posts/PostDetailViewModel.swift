import Core
import Observation

@MainActor
@Observable
public final class PostDetailViewModel {
    public enum State: Sendable {
        case loading
        case failed(AppError)
        /// Comments are secondary: their failure does not fail the screen.
        case loaded(Post, comments: [Comment], commentsError: AppError?)
    }

    public private(set) var state: State = .loading
    public let postId: Int
    private let repository: any PostRepository

    public init(postId: Int, repository: any PostRepository) {
        self.postId = postId
        self.repository = repository
    }

    public func load() async {
        state = .loading
        // Structured concurrency: both requests run in parallel and are both
        // cancelled if the view disappears (the .task is cancelled).
        async let postResult = fetchPost()
        async let commentsResult = fetchComments()
        let (post, comments) = await (postResult, commentsResult)

        if Task.isCancelled { return }
        switch post {
        case .failure(let error):
            if !error.isCancellation { state = .failed(error) }
        case .success(let post):
            switch comments {
            case .success(let list): state = .loaded(post, comments: list, commentsError: nil)
            case .failure(let error): state = .loaded(post, comments: [], commentsError: error)
            }
        }
    }

    private func fetchPost() async -> Result<Post, AppError> {
        do { return .success(try await repository.post(id: postId)) } catch { return .failure(error) }
    }

    private func fetchComments() async -> Result<[Comment], AppError> {
        do { return .success(try await repository.comments(postId: postId)) } catch { return .failure(error) }
    }
}
