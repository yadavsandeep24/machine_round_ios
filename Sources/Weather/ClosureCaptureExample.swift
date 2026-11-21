import Foundation

/// The Swiggy follow-up: "why `self` in this closure? weak vs unowned?"
/// A class that STORES a closure which captures `self` strongly creates a
/// retain cycle: object → closure → object. Neither is ever freed.
public final class RefreshScheduler {
    public var onTick: (() -> Void)?
    public init() {}
    public func fire() { onTick?() }
}

public final class LeakyWeatherController {
    let scheduler = RefreshScheduler()
    public private(set) var refreshes = 0
    public init() {
        // Strong capture: controller → scheduler → closure → controller. Leaks.
        scheduler.onTick = { self.refreshes += 1 }
    }
    public func tick() { scheduler.fire() }
}

public final class SafeWeatherController {
    let scheduler = RefreshScheduler()
    public private(set) var refreshes = 0
    public init() {
        // `weak`: the closure does not keep the controller alive; it becomes
        // nil safely if the controller is gone. Use `unowned` only when the
        // closure can never outlive self (it crashes if it does).
        scheduler.onTick = { [weak self] in self?.refreshes += 1 }
    }
    public func tick() { scheduler.fire() }
}
