import Foundation

public protocol Downloader: Sendable {
    func download(_ url: URL) async throws -> Data
}

// MARK: C03 — Actor reentrancy

/// BUG: "the same image downloads 10 times". An actor is NOT locked across
/// `await`: ten callers all check the cache (miss), then all download.
public actor AvatarCacheBuggy {
    private var cache: [URL: Data] = [:]
    private let downloader: any Downloader
    public init(downloader: any Downloader) { self.downloader = downloader }

    public func avatar(_ url: URL) async throws -> Data {
        if let hit = cache[url] { return hit }
        let data = try await downloader.download(url) // suspension point: others get in here
        cache[url] = data
        return data
    }
}

/// FIX: store the in-flight Task BEFORE awaiting, so later callers join it.
public actor AvatarCacheFixed {
    private var cache: [URL: Data] = [:]
    private var inFlight: [URL: Task<Data, any Error>] = [:]
    private let downloader: any Downloader
    public init(downloader: any Downloader) { self.downloader = downloader }

    public func avatar(_ url: URL) async throws -> Data {
        if let hit = cache[url] { return hit }
        if let running = inFlight[url] { return try await running.value }
        let downloader = self.downloader
        let task = Task { try await downloader.download(url) }
        inFlight[url] = task
        defer { inFlight[url] = nil }
        let data = try await task.value
        cache[url] = data
        return data
    }
}

// MARK: C04 — Stale async result overwrites a newer one

public protocol Searcher: Sendable {
    func search(_ q: String) async throws -> [String]
}

/// BUG: "results don't match what I typed". The old request ("sw", slow)
/// finishes after the new one ("swift") and overwrites it.
@MainActor
public final class SearchModelBuggy {
    public private(set) var results: [String] = []
    private var task: Task<Void, Never>?
    private let searcher: any Searcher
    public init(searcher: any Searcher) { self.searcher = searcher }

    public func queryChanged(_ q: String) {
        task = Task { results = (try? await searcher.search(q)) ?? [] } // previous task neither cancelled nor checked
    }
    public func wait() async { await task?.value }
}

/// FIX: cancel the previous task and check cancellation before applying the
/// result (`.task(id: query)` does the cancelling for you in SwiftUI).
@MainActor
public final class SearchModelFixed {
    public private(set) var results: [String] = []
    private var task: Task<Void, Never>?
    private let searcher: any Searcher
    public init(searcher: any Searcher) { self.searcher = searcher }

    public func queryChanged(_ q: String) {
        task?.cancel()
        task = Task {
            guard let found = try? await searcher.search(q), !Task.isCancelled else { return }
            results = found
        }
    }
    public func wait() async { await task?.value }
}
