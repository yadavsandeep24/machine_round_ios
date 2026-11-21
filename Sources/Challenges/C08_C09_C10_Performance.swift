import Combine
import Foundation
import Observation

// MARK: C08 — ObservableObject invalidates every observer

/// SLOW: `@Published` fires `objectWillChange` for ANY property, so a view
/// that only shows `title` re-renders whenever `likeCount` changes.
public final class PostModelBuggy: ObservableObject, @unchecked Sendable {
    @Published public var title = "Hello"
    @Published public var likeCount = 0
    public init() {}
}

/// FAST: `@Observable` tracks which properties each view body READ; changing
/// `likeCount` does not invalidate a view that reads only `title`.
@Observable
public final class PostModelFixed: @unchecked Sendable {
    public var title = "Hello"
    public var likeCount = 0
    public init() {}
}

// MARK: C09 — Formatter created per row

public enum FormatterCounter {
    nonisolated(unsafe) public static var created = 0
}

/// SLOW: a new `DateFormatter` per call (per row, per render). Creating
/// formatters is expensive; scrolling stutters.
public func rowDateBuggy(_ date: Date) -> String {
    FormatterCounter.created += 1
    let f = DateFormatter()
    f.dateStyle = .medium
    return f.string(from: date)
}

private let sharedRowFormatter: DateFormatter = {
    FormatterCounter.created += 1
    let f = DateFormatter()
    f.dateStyle = .medium
    return f
}()

/// FAST: create once and reuse (or use `date.formatted(...)` FormatStyles, cached by the system).
public func rowDateFixed(_ date: Date) -> String { sharedRowFormatter.string(from: date) }

// MARK: C10 — Unbounded cache

/// SLOW / CRASH: "memory grows while scrolling until the app is killed".
/// A dictionary cache never evicts.
public final class ThumbnailCacheBuggy: @unchecked Sendable {
    private var storage: [String: Data] = [:]
    public init() {}
    public func insert(_ data: Data, for key: String) { storage[key] = data }
    public var count: Int { storage.count }
}

/// FAST: `NSCache` with limits (evicts under memory pressure, thread-safe).
public final class ThumbnailCacheFixed: @unchecked Sendable {
    private let storage = NSCache<NSString, NSData>()
    private var keys = Set<String>()
    public init(countLimit: Int = 100, totalCostLimit: Int = 50_000_000) {
        storage.countLimit = countLimit
        storage.totalCostLimit = totalCostLimit
    }
    public func insert(_ data: Data, for key: String) {
        storage.setObject(data as NSData, forKey: key as NSString, cost: data.count)
        keys.insert(key)
    }
    /// Entries actually still cached.
    public var count: Int { keys.filter { storage.object(forKey: $0 as NSString) != nil }.count }
}
