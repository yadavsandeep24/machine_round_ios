import Foundation
import Observation
import Testing
@testable import Challenges

@Suite struct RetainCycleTests {
    @Test func c01StrongStoredClosureLeaksWeakDoesNot() {
        weak var buggy: ProfileViewModelBuggy?
        weak var fixed: ProfileViewModelFixed?
        do {
            let b = ProfileViewModelBuggy(); b.service.push("Ada"); buggy = b
            let f = ProfileViewModelFixed(); f.service.push("Ada"); fixed = f
            #expect(b.name == "Ada" && f.name == "Ada")
        }
        #expect(buggy != nil) // leaked
        #expect(fixed == nil) // freed
    }

    @Test func c02StoredTaskKeepsOwnerAliveAndPolling() async throws {
        weak var buggy: PricePollerBuggy?
        weak var fixed: PricePollerFixed?
        do {
            let b = PricePollerBuggy(), f = PricePollerFixed()
            buggy = b
            fixed = f
        }
        try await Task.sleep(for: .milliseconds(30))
        #expect(buggy != nil) // still alive, still polling
        #expect(fixed == nil) // freed, loop stopped
    }
}

final class CountingDownloader: Downloader, @unchecked Sendable {
    private let lock = NSLock()
    private var _count = 0
    var count: Int { lock.withLock { _count } }
    func download(_ url: URL) async throws -> Data {
        lock.withLock { _count += 1 }
        try await Task.sleep(for: .milliseconds(20))
        return Data([1, 2, 3])
    }
}

struct SlowFirstSearcher: Searcher {
    func search(_ q: String) async throws -> [String] {
        try? await Task.sleep(for: q == "sw" ? .milliseconds(100) : .milliseconds(10))
        return ["result for \(q)"]
    }
}

@Suite struct ConcurrencyTests {
    let url = URL(string: "https://x.test/a.png")!

    @Test func c03ReentrancyDuplicatesDownloadsUntilInFlightIsShared() async throws {
        let d1 = CountingDownloader(), d2 = CountingDownloader()
        let buggy = AvatarCacheBuggy(downloader: d1), fixed = AvatarCacheFixed(downloader: d2)
        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<10 {
                group.addTask { _ = try await buggy.avatar(url) }
                group.addTask { _ = try await fixed.avatar(url) }
            }
            try await group.waitForAll()
        }
        #expect(d1.count == 10)
        #expect(d2.count == 1)
    }

    @MainActor @Test func c04StaleResultOverwritesUntilCancelledAndChecked() async throws {
        let buggy = SearchModelBuggy(searcher: SlowFirstSearcher())
        let fixed = SearchModelFixed(searcher: SlowFirstSearcher())
        for model in [buggy as AnyObject, fixed as AnyObject] {
            if let m = model as? SearchModelBuggy { m.queryChanged("sw"); m.queryChanged("swift") }
            if let m = model as? SearchModelFixed { m.queryChanged("sw"); m.queryChanged("swift") }
        }
        try await Task.sleep(for: .milliseconds(200))
        #expect(buggy.results == ["result for sw"]) // wrong: stale
        #expect(fixed.results == ["result for swift"])
    }
}

@Suite struct LogicTests {
    @Test func c05MutatingACopyChangesNothing() {
        var a = [TodoItem(title: "a"), TodoItem(title: "b")]
        var b = a
        markAllDoneBuggy(&a)
        markAllDoneFixed(&b)
        let anyDoneInBuggy = a.contains(where: \.isDone)
        let allDoneInFixed = b.allSatisfy(\.isDone)
        #expect(anyDoneInBuggy == false)
        #expect(allDoneInFixed)
    }

    @Test func c06UnstructuredTaskKeepsRunningAfterTheScreenCloses() async throws {
        let buggy = FeedLoader(), fixed = FeedLoader()
        buggy.startBuggy()
        let handle = fixed.startFixed()
        try await Task.sleep(for: .milliseconds(20))
        handle.cancel() // the view disappeared (.task does this)
        let (b, f) = (buggy.pages, fixed.pages)
        try await Task.sleep(for: .milliseconds(40))
        #expect(buggy.pages > b) // still loading
        #expect(fixed.pages <= f + 1) // stopped
    }

    @Test func c07DoubleMoneyDriftsIntegerMinorUnitsDoNot() {
        #expect(cartTotalBuggy([0.1, 0.2]) != 0.3)
        #expect(cartTotalFixed([10, 20]) == 30)
    }
}

@Suite struct PerformanceTests {
    @Test func c08ObservableObjectInvalidatesOnUnrelatedChanges() async {
        let buggy = PostModelBuggy()
        var fired = 0
        let sub = buggy.objectWillChange.sink { fired += 1 }
        buggy.likeCount += 1 // a view showing only `title` would still re-render
        #expect(fired == 1)
        sub.cancel()

        let fixed = PostModelFixed()
        let changed = Box()
        withObservationTracking { _ = fixed.title } onChange: { changed.value = true }
        fixed.likeCount += 1
        #expect(changed.value == false) // a view reading only `title` is untouched
        fixed.title = "Hi"
        #expect(changed.value == true)
    }

    @Test func c09FormatterPerRowVersusShared() {
        let rows = (0..<200).map { Date(timeIntervalSince1970: Double($0) * 86_400) }
        FormatterCounter.created = 0
        rows.forEach { _ = rowDateBuggy($0) }
        #expect(FormatterCounter.created == 200)
        _ = rowDateFixed(rows[0]) // first use creates the shared one
        FormatterCounter.created = 0
        rows.forEach { _ = rowDateFixed($0) }
        #expect(FormatterCounter.created == 0)
    }

    @Test func c10UnboundedCacheGrowsForeverNSCacheIsCapped() {
        let buggy = ThumbnailCacheBuggy(), fixed = ThumbnailCacheFixed(countLimit: 50)
        for i in 0..<1000 {
            buggy.insert(Data(count: 10), for: "\(i)")
            fixed.insert(Data(count: 10), for: "\(i)")
        }
        #expect(buggy.count == 1000)
        #expect(fixed.count <= 50)
    }
}

final class Box: @unchecked Sendable { var value = false }

@Suite struct GalleryTests {
    @Test func everyDemoShowsADifferentOutcome() async {
        #expect(challenges.map(\.id) == Array(1...10))
        for c in challenges {
            let r = await c.demo()
            #expect(r.buggy != r.fixed, "challenge \(c.id)")
        }
    }
}
