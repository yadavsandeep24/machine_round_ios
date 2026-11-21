import Foundation

public struct Challenge: Identifiable, Sendable {
    public enum Kind: String, Sendable { case bug = "Bug", perf = "Perf" }
    public let id: Int
    public let kind: Kind
    public let title: String
    public let symptom: String
    public let cause: String
    public let fix: String
    public let file: String
    /// Runs buggy and fixed side by side and describes the outcome.
    public let demo: @Sendable () async -> (buggy: String, fixed: String)
}

private struct DemoDownloader: Downloader {
    let counter = DemoCounter()
    func download(_ url: URL) async throws -> Data {
        counter.increment()
        try await Task.sleep(for: .milliseconds(20))
        return Data()
    }
}

final class DemoCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var n = 0
    func increment() { lock.withLock { n += 1 } }
    var value: Int { lock.withLock { n } }
}

private struct DemoSearcher: Searcher {
    func search(_ q: String) async throws -> [String] {
        try? await Task.sleep(for: q == "sw" ? .milliseconds(100) : .milliseconds(10))
        return ["results for “\(q)”"]
    }
}

public let challenges: [Challenge] = [
    Challenge(id: 1, kind: .bug, title: "Retain cycle via a stored closure",
              symptom: "The view model is never deallocated; memory grows with every visit.",
              cause: "A stored escaping closure captures self strongly: VM → service → closure → VM.",
              fix: "[weak self] in stored closures; check with the Memory Graph debugger.",
              file: "C01_C02_RetainCycles.swift") {
        weak var b: ProfileViewModelBuggy?; weak var f: ProfileViewModelFixed?
        do { let x = ProfileViewModelBuggy(), y = ProfileViewModelFixed(); b = x; f = y }
        return (b == nil ? "freed" : "LEAKED (still alive)", f == nil ? "freed" : "leaked")
    },
    Challenge(id: 2, kind: .bug, title: "A stored Task keeps its owner alive",
              symptom: "Polling keeps running after the screen closes.",
              cause: "The Task captures self strongly and loops forever; deinit never runs.",
              fix: "Capture weakly inside the loop and cancel in deinit, or use SwiftUI .task {}.",
              file: "C01_C02_RetainCycles.swift") {
        weak var b: PricePollerBuggy?; weak var f: PricePollerFixed?
        do { let x = PricePollerBuggy(), y = PricePollerFixed(); b = x; f = y }
        try? await Task.sleep(for: .milliseconds(30))
        return (b == nil ? "stopped" : "STILL POLLING (\(b!.ticks) ticks)", f == nil ? "stopped and freed" : "running")
    },
    Challenge(id: 3, kind: .bug, title: "Actor reentrancy: duplicate downloads",
              symptom: "The same image downloads ten times.",
              cause: "An actor isn't locked across await: every caller misses the cache before the first finishes.",
              fix: "Store the in-flight Task before awaiting; later callers join it.",
              file: "C03_C04_Concurrency.swift") {
        let url = URL(string: "https://x.test/a.png")!
        let d1 = DemoDownloader(), d2 = DemoDownloader()
        let buggy = AvatarCacheBuggy(downloader: d1), fixed = AvatarCacheFixed(downloader: d2)
        await withTaskGroup(of: Void.self) { g in
            for _ in 0..<10 {
                g.addTask { _ = try? await buggy.avatar(url) }
                g.addTask { _ = try? await fixed.avatar(url) }
            }
        }
        return ("\(d1.counter.value) downloads", "\(d2.counter.value) download")
    },
    Challenge(id: 4, kind: .bug, title: "Stale async result overwrites a newer one",
              symptom: "Search results don't match what was typed.",
              cause: "The slow request for an old query finishes last and overwrites the newer results.",
              fix: "Cancel the previous task and check Task.isCancelled before applying (.task(id:) in SwiftUI).",
              file: "C03_C04_Concurrency.swift") {
        await staleResultDemo()
    },
    Challenge(id: 5, kind: .bug, title: "Mutating a copy of a struct",
              symptom: "“Mark all as done” does nothing.",
              cause: "for var item in items iterates over copies; the array never changes.",
              fix: "Mutate through indices (items[i].isDone = true) or map to a new array.",
              file: "C05_C06_C07_Logic.swift") {
        var a = [TodoItem(title: "a"), TodoItem(title: "b")]; var b = a
        markAllDoneBuggy(&a); markAllDoneFixed(&b)
        return ("\(a.filter(\.isDone).count)/2 done", "\(b.filter(\.isDone).count)/2 done")
    },
    Challenge(id: 6, kind: .bug, title: "Unstructured Task in onAppear",
              symptom: "Network calls continue after leaving the screen.",
              cause: "Task { } in onAppear isn't tied to the view, so nothing cancels it.",
              fix: "Use .task { await … } (cancelled on disappear) or keep the handle and cancel it.",
              file: "C05_C06_C07_Logic.swift") {
        let b = FeedLoader(), f = FeedLoader()
        b.startBuggy(); let h = f.startFixed()
        try? await Task.sleep(for: .milliseconds(20)); h.cancel()
        let (pb, pf) = (b.pages, f.pages)
        try? await Task.sleep(for: .milliseconds(40))
        return ("+\(b.pages - pb) pages after leaving", "+\(f.pages - pf) pages after leaving")
    },
    Challenge(id: 7, kind: .bug, title: "Money in Double",
              symptom: "Cart total shows ₹0.30000000000000004 or is off by a paisa.",
              cause: "Binary floating point can't represent 0.1 exactly.",
              fix: "Integer minor units, or Decimal parsed from the server's string.",
              file: "C05_C06_C07_Logic.swift") {
        ("0.1 + 0.2 = \(cartTotalBuggy([0.1, 0.2]))", "10 + 20 paise = \(cartTotalFixed([10, 20])) paise")
    },
    Challenge(id: 8, kind: .perf, title: "ObservableObject invalidates every observer",
              symptom: "Changing a like count re-renders views that only show the title.",
              cause: "objectWillChange fires for any @Published property.",
              fix: "@Observable tracks the properties each body reads (iOS 17+).",
              file: "C08_C09_C10_Performance.swift") {
        ("any change → every observer re-renders", "only views that read the changed property")
    },
    Challenge(id: 9, kind: .perf, title: "Formatter created per row",
              symptom: "Scrolling a list of dates stutters.",
              cause: "A new DateFormatter per row per render; formatters are expensive to create.",
              fix: "Create once and reuse, or use FormatStyle (date.formatted(...)).",
              file: "C08_C09_C10_Performance.swift") {
        FormatterCounter.created = 0
        for i in 0..<200 { _ = rowDateBuggy(Date(timeIntervalSince1970: Double(i))) }
        let buggy = FormatterCounter.created
        FormatterCounter.created = 0
        for i in 0..<200 { _ = rowDateFixed(Date(timeIntervalSince1970: Double(i))) }
        return ("\(buggy) formatters for 200 rows", "\(FormatterCounter.created) new formatters")
    },
    Challenge(id: 10, kind: .perf, title: "Unbounded cache",
              symptom: "Memory grows while scrolling until iOS kills the app.",
              cause: "A dictionary cache never evicts.",
              fix: "NSCache with countLimit / totalCostLimit (also purged under memory pressure).",
              file: "C08_C09_C10_Performance.swift") {
        let b = ThumbnailCacheBuggy(), f = ThumbnailCacheFixed(countLimit: 50)
        for i in 0..<1000 { b.insert(Data(count: 10), for: "\(i)"); f.insert(Data(count: 10), for: "\(i)") }
        return ("\(b.count) entries", "≤ 50 entries (\(f.count))")
    },
]

@MainActor
private func staleResultDemo() async -> (buggy: String, fixed: String) {
    let b = SearchModelBuggy(searcher: DemoSearcher()), f = SearchModelFixed(searcher: DemoSearcher())
    b.queryChanged("sw"); b.queryChanged("swift")
    f.queryChanged("sw"); f.queryChanged("swift")
    try? await Task.sleep(for: .milliseconds(200))
    return ("typed “swift”, shows \(b.results.first ?? "-")", "typed “swift”, shows \(f.results.first ?? "-")")
}
