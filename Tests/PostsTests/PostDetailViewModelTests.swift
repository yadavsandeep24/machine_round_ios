import Core
import Testing
@testable import Posts

@MainActor
@Suite struct PostDetailViewModelTests {
    @Test func loadsCachedPostWithComments() async {
        let model = PostDetailViewModel(postId: 1, repository: FakePostRepository(cached: [makePost(1)]))
        await model.load()
        guard case .loaded(let p, let comments, nil) = model.state else { Issue.record("\(model.state)"); return }
        #expect(p.id == 1)
        #expect(comments.count == 1)
    }

    @Test func fallsBackToNetworkForUncachedPost() async {
        let repo = FakePostRepository()
        repo.remoteById[7] = makePost(7)
        let model = PostDetailViewModel(postId: 7, repository: repo)
        await model.load()
        guard case .loaded(let p, _, _) = model.state else { Issue.record("\(model.state)"); return }
        #expect(p.id == 7)
    }

    @Test func missingPostIsAnError() async {
        let model = PostDetailViewModel(postId: 404, repository: FakePostRepository())
        await model.load()
        guard case .failed(.notFound) = model.state else { Issue.record("\(model.state)"); return }
    }

    @Test func commentsFailureStillShowsThePost() async {
        let repo = FakePostRepository(cached: [makePost(1)])
        repo.commentsFailWith = .server(status: 500)
        let model = PostDetailViewModel(postId: 1, repository: repo)
        await model.load()
        guard case .loaded(_, let comments, .server(500)) = model.state else { Issue.record("\(model.state)"); return }
        #expect(comments.isEmpty)
    }

    @Test func cancelledLoadLeavesStateUntouched() async {
        let repo = FakePostRepository(cached: [makePost(1)])
        repo.commentsDelay = .milliseconds(200)
        let model = PostDetailViewModel(postId: 1, repository: repo)
        let task = Task { await model.load() }
        await Task.yield()
        task.cancel() // the view disappeared
        await task.value
        guard case .loading = model.state else { Issue.record("\(model.state)"); return }
    }
}
