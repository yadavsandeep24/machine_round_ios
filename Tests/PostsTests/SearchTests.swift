import Core
import Testing
@testable import Posts

@MainActor
@Suite struct SearchTests {
    func makeModel() -> (PostsViewModel, FakePostRepository) {
        let repo = FakePostRepository()
        repo.remote = [makePost(1, "Swift tips"), makePost(2, "Kotlin flows"), makePost(3, "Swift concurrency")]
        return (PostsViewModel(repository: repo, debounce: .milliseconds(50)), repo)
    }

    /// What `.task(id: query)` does: cancel the previous task, start a new one.
    func type(_ texts: [String], into model: PostsViewModel, gap: Duration = .milliseconds(5)) async {
        var task: Task<Void, Never>?
        for text in texts {
            task?.cancel()
            task = Task { await model.search(text) }
            try? await Task.sleep(for: gap)
        }
        await task?.value
    }

    @Test func fastTypingSendsOneRequest() async {
        let (model, repo) = makeModel()
        await type(["s", "sw", "swift"], into: model)
        #expect(repo.searchedQueries == ["swift"])
        #expect(model.searchState.value?.map(\.id) == [1, 3])
    }

    @Test func aSlowOlderResponseNeverOverwritesANewerQuery() async {
        let (model, repo) = makeModel()
        repo.searchDelays["kotlin"] = .milliseconds(300)
        await type(["kotlin", "swift"], into: model, gap: .milliseconds(120)) // kotlin's request is in flight
        try? await Task.sleep(for: .milliseconds(350))
        #expect(model.activeQuery == "swift")
        #expect(model.searchState.value?.map(\.id) == [1, 3])
    }

    @Test func retypingTheSameQueryDoesNotSearchAgain() async {
        let (model, repo) = makeModel()
        await model.search("swift")
        await model.search(" swift ")
        #expect(repo.searchedQueries == ["swift"])
    }

    @Test func clearingIsInstantAndErrorsCanBeRetried() async {
        let (model, repo) = makeModel()
        repo.searchFailWith = .noInternet
        await model.search("swift")
        #expect(model.searchState.error == .noInternet)
        repo.searchFailWith = nil
        await model.search("swift", force: true)
        #expect(model.searchState.value?.count == 2)
        await model.search("")
        #expect(model.isSearching == false)
    }
}
