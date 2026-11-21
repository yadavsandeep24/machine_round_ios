import Foundation

// MARK: C01 — Retain cycle through a stored closure

/// BUG: "the screen's view model is never deallocated" (memory graph shows it
/// after every visit). `onUpdate` is STORED by the service and captures `self`
/// strongly: view model → service → closure → view model.
public final class ProfileViewModelBuggy {
    public let service = ProfileService()
    public private(set) var name = ""
    public init() {
        service.onUpdate = { name in self.name = name }
    }
}

/// FIX: `[weak self]` in escaping, stored closures. (`unowned` only when the
/// closure provably cannot outlive self.)
public final class ProfileViewModelFixed {
    public let service = ProfileService()
    public private(set) var name = ""
    public init() {
        service.onUpdate = { [weak self] name in self?.name = name }
    }
}

public final class ProfileService {
    public var onUpdate: ((String) -> Void)?
    public init() {}
    public func push(_ name: String) { onUpdate?(name) }
}

// MARK: C02 — A stored Task keeps its owner alive

/// BUG: "polling keeps running after the screen closes". The Task captures
/// `self` strongly and loops forever, so `deinit` never runs and nothing
/// cancels it.
public final class PricePollerBuggy: @unchecked Sendable {
    public private(set) var ticks = 0
    private var task: Task<Void, Never>?
    public init() {
        task = Task {
            while !Task.isCancelled {
                self.ticks += 1
                try? await Task.sleep(for: .milliseconds(5))
            }
        }
    }
}

/// FIX: capture weakly inside the loop and cancel in `deinit` (or better, use
/// SwiftUI's `.task {}`, which is cancelled when the view disappears).
public final class PricePollerFixed: @unchecked Sendable {
    public private(set) var ticks = 0
    private var task: Task<Void, Never>?
    public init() {
        task = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                self.ticks += 1
                try? await Task.sleep(for: .milliseconds(5))
            }
        }
    }
    deinit { task?.cancel() }
}
