import Core
import Testing
@testable import Posts

@MainActor
@Suite struct PostsViewModelTests {
    @Test func loadsFromNetworkIntoEmptyCache() async {
        let model = PostsViewModel(repository: FakePostRepository())
        await model.load()
        #expect(model.state.value?.count == 20)
        #expect(model.isRefreshing == false)
    }

    @Test func emptyCacheAndNetworkErrorIsFullScreenFailure() async {
        let repo = FakePostRepository()
        repo.failWith = .noInternet
        let model = PostsViewModel(repository: repo)
        await model.load()
        #expect(model.state.error == .noInternet)
    }

    @Test func cachedDataSurvivesNetworkErrorWithBanner() async {
        let repo = FakePostRepository(cached: [makePost(99)])
        repo.failWith = .timeout
        let model = PostsViewModel(repository: repo)
        await model.load()
        #expect(model.state.value?.map(\.id) == [99])
        #expect(model.bannerError == .timeout)
    }

    @Test func cancellationIsNotAnError() async {
        let repo = FakePostRepository()
        repo.failWith = .cancelled
        let model = PostsViewModel(repository: repo)
        await model.load()
        #expect(model.state.error == nil)
        #expect(model.bannerError == nil)
    }

    @Test func refreshWhileRefreshingIsDropped() async {
        let repo = FakePostRepository()
        let model = PostsViewModel(repository: repo)
        let (stream, continuation) = AsyncStream<Void>.makeStream()
        repo.gate = { for await _ in stream { break } }
        async let first: Void = model.refresh()
        await Task.yield()
        await model.refresh() // dropped
        await model.refresh() // dropped
        continuation.yield()
        await first
        #expect(repo.refreshCalls == 1)
    }
}
