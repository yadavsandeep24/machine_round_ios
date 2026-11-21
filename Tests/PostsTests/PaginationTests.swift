import Core
import Testing
@testable import Posts

@MainActor
@Suite struct PaginationTests {
    func loaded(_ repo: FakePostRepository = FakePostRepository()) async -> (PostsViewModel, FakePostRepository) {
        let model = PostsViewModel(repository: repo)
        await model.load()
        return (model, repo)
    }

    @Test func loadsUntilTheEnd() async {
        let (model, repo) = await loaded()
        await model.loadMore()
        await model.loadMore()
        await model.loadMore() // ignored: end reached
        #expect(model.state.value?.count == 45)
        #expect(model.hasReachedEnd)
        #expect(repo.requestedPages == [2, 3])
    }

    @Test func onlyRowsNearTheEndTrigger() async {
        let (model, repo) = await loaded()
        await model.loadMoreIfNeeded(currentItem: makePost(3))
        #expect(repo.requestedPages.isEmpty)
        await model.loadMoreIfNeeded(currentItem: makePost(16))
        #expect(repo.requestedPages == [2])
    }

    @Test func errorBlocksAutoRetryUntilRetryTapped() async {
        let (model, repo) = await loaded()
        repo.loadMoreFailWith = .noInternet
        await model.loadMore()
        await model.loadMore() // scrolling again: ignored
        #expect(model.loadMoreError == .noInternet)
        #expect(repo.requestedPages == [2])
        repo.loadMoreFailWith = nil
        await model.loadMore(isRetry: true)
        #expect(model.state.value?.count == 40)
    }

    @Test func pageFinishingAfterARefreshIsDropped() async {
        let (model, repo) = await loaded()
        let (stream, continuation) = AsyncStream<Void>.makeStream()
        repo.pageGates[2] = { for await _ in stream { break } }
        async let pending: Void = model.loadMore()
        await Task.yield()
        await model.refresh() // isLoadingMore is set, but a refresh still runs
        continuation.yield()
        await pending
        #expect(model.state.value?.count == 20)
    }
}
