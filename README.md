# Latest feature: Task cancellation shields, `withTaskCancellationShield` (iOS / Swift, Swift 6.4, 15 Sep 2026)

Branch: `latest/2026-11-27-task-cancellation-shield` (built on `01-minimal`).

## What's new

Swift 6.4 adds `withTaskCancellationShield { ... }` (Swift Evolution SE-0504). Code inside the closure runs as if the task were **not** cancelled:

- `Task.isCancelled` is `false` and `Task.checkCancellation()` does not throw.
- Cancellation-aware APIs (`Task.sleep`, `URLSession`, child tasks created inside) do not stop early.
- The task is still cancelled after the closure returns. The shield hides cancellation; it does not clear it.
- `Task.hasActiveCancellationShield` tells you whether you are inside a shield.

It exists for **cleanup that must finish**: releasing a payment hold, closing a server session, flushing a write, unlocking a resource. It pairs with SE-0493 (`await` inside `defer`), which is also in Swift 6.4.

Official sources:
- [SE-0504: Task Cancellation Shields, review](https://forums.swift.org/t/se-0504-task-cancellation-shields/84095) (Swift Forums, review 12 Jan to 2 Feb 2026)
- [Accepted: SE-0504](https://forums.swift.org/t/accepted-se-0504-task-cancellation-shields/84667) (Swift Forums, Feb 2026)
- [`withTaskCancellationShield(operation:)`](https://developer.apple.com/documentation/swift/withtaskcancellationshield(operation:)-8zlgh) (Apple Developer Documentation)
- [What's new in Swift (WWDC26)](https://developer.apple.com/wwdc26/guides/swift/) (Apple, June 2026)
- [swift.org blog](https://www.swift.org/blog/) (Swift 6.4 released 15 Sep 2026; this Mac has Swift 6.4.2 in Xcode 27.2)

## Why it matters

Swift concurrency uses cooperative cancellation. When the user leaves a SwiftUI screen, its `.task` is cancelled, and every child call that checks cancellation stops. That is good for loading data. It is bad for cleanup:

```swift
} catch {
    try? await gateway.releaseHold(hold)   // task is cancelled -> URLSession throws at once -> hold leaks
    throw error
}
```

In payments this is a real bug. The user taps Pay, the app reserves funds, the user backs out while 3-DS is pending, and the release call never leaves the device. The money stays blocked until the bank's hold expires.

Use a shield for short, bounded cleanup that must reach the end. Do not wrap long or user-visible work in it: shielded code ignores the user's cancel, so a hanging call inside it hangs the task. Add your own timeout inside the shield if the cleanup call could hang.

## Before vs after

```swift
// Before (Swift < 6.4): escape cancellation with a new unstructured task
private func releaseInUnstructuredTask(_ hold: HoldID) async {
    let gateway = gateway
    await Task { try? await gateway.releaseHold(hold) }.value   // forget `await` and it is fire-and-forget
}

// After (Swift 6.4): stay in the same task, structured and awaited
if #available(iOS 27, macOS 27, *) {
    await withTaskCancellationShield {
        try? await gateway.releaseHold(hold)
    }
}

// Also new in 6.4 (SE-0493): async cleanup in defer
defer { await withTaskCancellationShield { await session.close() } }
```

## How this branch uses it

The home screen is a checkout. Tap **Pay**: the app places a hold, then waits for capture. Tap **Cancel payment** while it waits: the task is cancelled, and the gateway log still shows `RELEASE`.

- `Sources/Checkout/CheckoutService.swift`: reserve-then-capture flow; `CleanupStrategy` with the new shield, the old unstructured-task way, and the naive (buggy) way.
- `Sources/Checkout/PaymentGateway.swift`: `PaymentGateway` protocol and `SimulatedPaymentGateway`, an actor that fails fast on cancellation like a real network call, and records events.
- `Sources/Checkout/CheckoutViewModel.swift`: `@Observable @MainActor` view model; `pay()` and `cancel()`.
- `Sources/Checkout/CheckoutView.swift`: SwiftUI screen with amount, status, Pay/Cancel and a live gateway log.
- `Sources/AppFeature/RootView.swift`, `Package.swift`: new `Checkout` target wired in as the home screen.
- `Tests/CheckoutTests/CheckoutServiceTests.swift`: cancel mid-capture with each strategy (shield releases, old way releases, naive leaks), plus what code inside a shield observes.
- `Tests/CheckoutTests/CheckoutViewModelTests.swift`: success, cancel releases the hold, double tap ignored.

## Interview talking points

- "Cancellation in Swift is cooperative. That is right for loading, but cleanup code also checks cancellation, so it can be skipped. Swift 6.4's `withTaskCancellationShield` lets cleanup finish."
- "Before 6.4 I used an unstructured `Task {}` for cleanup. It works, but it leaves structured concurrency, and if someone drops the `await` it becomes fire-and-forget and tests get flaky."
- "The shield does not un-cancel the task. After the closure, `Task.isCancelled` is true again, so the caller still sees `CancellationError`."
- "I keep shielded work small and bounded. A shield ignores the user's cancel, so a hanging call inside it would hang the task."
- "On the server side I still want idempotent release and a hold expiry. The client fix reduces leaks; it is not the only safety net."
- "The demo gateway is an actor that behaves like URLSession on cancellation, so tests prove the bug and the fix without a network."

Likely follow-ups:
- **What about child tasks?** Child tasks created *inside* the shield are shielded too. Wrapping only the `addTask` call does not shield a child created outside it.
- **Why not `Task.detached`?** Detached also escapes cancellation, but it drops actor isolation, priority and task-local values. A shield keeps all of them.
- **How do you support iOS 17?** The API needs iOS 27 / macOS 27. Use `if #available` and fall back to the unstructured-task version, as `CheckoutService.release` does.

## Gotchas and compatibility

- Needs the Swift 6.4 compiler (Xcode 27) **and** iOS 27 / macOS 27 at runtime (`@available(anyAppleOS 27.0, *)` in the SDK). This package targets iOS 17, so the call is behind `if #available(iOS 27, macOS 27, *)` with the old way as a fallback.
- There are two overloads: async and sync. If the closure has no `await`, call it without `await` or you get an "unnecessary await" warning.
- `await` inside `defer` (SE-0493) is a Swift 6.4 language feature; it was verified with the Swift 6.4.2 compiler on this Mac.
- No dependency bumps. New package target `Checkout` and test target `CheckoutTests`.

## Run it

```bash
git checkout latest/2026-11-27-task-cancellation-shield
./scripts/check.sh          # swift test + iOS Simulator build
swift test --filter CheckoutTests
open App/MachineRound.xcodeproj   # run on an iOS 27 simulator to use the shield path
```
