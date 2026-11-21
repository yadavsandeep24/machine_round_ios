import Foundation

// MARK: C05 — Mutating a copy (value semantics)

public struct TodoItem: Equatable, Sendable {
    public var title: String
    public var isDone = false
    public init(title: String) { self.title = title }
}

/// BUG: "Mark all as done does nothing". `for var item in items` iterates over
/// COPIES of the structs; the array itself never changes.
public func markAllDoneBuggy(_ items: inout [TodoItem]) {
    for var item in items { item.isDone = true }
}

/// FIX: mutate through the array (indices), or build a new array.
public func markAllDoneFixed(_ items: inout [TodoItem]) {
    for index in items.indices { items[index].isDone = true }
}

// MARK: C06 — Unstructured Task never cancelled

/// BUG: `.onAppear { Task { await model.loadForever() } }`: an unstructured
/// Task is not tied to the view; leaving the screen does not cancel it.
/// Modelled here: the caller has no handle to cancel.
public final class FeedLoader: @unchecked Sendable {
    private let lock = NSLock()
    private var _pages = 0
    public var pages: Int { lock.withLock { _pages } }
    public init() {}

    /// Loads pages until cancelled.
    public func loadForever() async {
        while !Task.isCancelled {
            lock.withLock { _pages += 1 }
            try? await Task.sleep(for: .milliseconds(5))
        }
    }

    public func startBuggy() { Task { await loadForever() } } // fire and forget: can't be cancelled

    /// FIX: an `async` function the VIEW owns via `.task { await loader.loadForever() }`;
    /// SwiftUI cancels it on disappear. (Or keep the Task and cancel it yourself.)
    public func startFixed() -> Task<Void, Never> { Task { await loadForever() } }
}

// MARK: C07 — Money in Double

/// BUG: "cart total is ₹0.30000000000000004" / totals off by a paisa.
/// Binary floating point can't represent 0.1 exactly.
public func cartTotalBuggy(_ prices: [Double]) -> Double { prices.reduce(0, +) }

/// FIX: integer minor units (or `Decimal` from the server's string).
public func cartTotalFixed(_ paise: [Int64]) -> Int64 { paise.reduce(0, +) }
