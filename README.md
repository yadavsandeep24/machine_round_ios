# Latest feature: `await` in `defer` (iOS / Swift, Swift 6.4 — SE-0493, Sep 2026)

## What's new

From Swift 6.4 you can call `async` functions inside a `defer` block, as long as the surrounding function is already `async`:

```swift
await limiter.acquire()
defer { await limiter.release() }
```

The defer body runs on every exit path (return, throw, cancellation) and **finishes before the function returns**. It runs with the same isolation as the enclosing function. There is no new keyword (`defer async` was considered and rejected).

Sources:
- [SE-0493: Support `async` calls in `defer` bodies — review](https://forums.swift.org/t/se-0493-support-async-calls-in-defer-bodies/82293) and [acceptance](https://forums.swift.org/t/accepted-se-0493-support-async-calls-in-defer-bodies/83023) — Swift Forums (review Sep–Oct 2025, accepted late 2025).
- [What's new in Swift (WWDC26 guide)](https://developer.apple.com/wwdc26/guides/swift/) — Apple, June 2026.
- [Swift 6.4 released](https://www.infoq.com/news/2026/09/swift-6-4-released/) — InfoQ, Sep 2026 (async defer listed among 6.4 language changes).

This Mac has Xcode 27.2 / Swift 6.4.2, so the feature compiles here.

## Why it matters

- Many cleanups are async now: releasing an actor-based lock or semaphore, closing an upload session, flushing analytics, ending a DB transaction. Actor methods must be awaited from outside, so they could not be called from `defer`.
- The old options were all worse:
  - release by hand on every path (`do/catch` + rethrow) — easy to break with a new early `return`;
  - `defer { Task { await release() } }` — compiles, but releases **later on another task**; the function returns while the resource is still held, and cancellation/priority are lost.
- Use it for paired acquire/release around a scope in async code.
- Do not use it for long work: it adds hidden suspension points at the end of the scope. Keep defer bodies short. It does not make cleanup run if the task is cancelled — cleanup always runs anyway; if the cleanup itself must not be cancelled, combine it with a cancellation shield (see `latest/2026-11-27-task-cancellation-shield`).

## Before vs after

```swift
// Before (Swift ≤ 6.3): manual release on each path
await limiter.acquire()
do {
    let receipt = try await transport.send(document)
    await limiter.release()
    return receipt
} catch {
    await limiter.release()
    throw error
}

// Before (anti-pattern): fire-and-forget release, runs after we return
await limiter.acquire()
defer { Task { await limiter.release() } }
```

```swift
// After (Swift 6.4): one line, every exit path, finished before return
await limiter.acquire()
defer { await limiter.release() }
try Task.checkCancellation()
return try await transport.send(document)
```

## How this branch uses it

A KYC document upload screen: five documents, "Upload all", at most 2 uploads in flight, per-row status, cancel, retry failed ones.

- `Sources/Uploads/AsyncSemaphore.swift` — actor semaphore with FIFO hand-off; `release()` is actor-isolated, so it needs `await`.
- `Sources/Uploads/DocumentUploader.swift` — the feature: `defer { await limiter.release() }`, next to the old manual-release version (`ReleaseStrategy`).
- `Sources/Uploads/UploadTransport.swift` — `Document`, `UploadReceipt`, `UploadTransport` protocol, a simulated transport for the app.
- `Sources/Uploads/DocumentUploadViewModel.swift` — `@MainActor @Observable`; starts all uploads in a task group and lets the semaphore cap concurrency.
- `Sources/Uploads/DocumentUploadView.swift` — SwiftUI list with status icons, bottom bar with progress and Upload all / Cancel.
- `Sources/AppFeature/RootView.swift` — root now shows the upload screen.
- `Package.swift` — new `Uploads` and `UploadsTests` targets; tools version 6.4.
- `Tests/UploadsTests/DocumentUploaderTests.swift` — one spec run against both strategies: concurrency cap, release on throw, release on cancellation while waiting, FIFO order.
- `Tests/UploadsTests/DocumentUploadViewModelTests.swift` — batch upload, per-document failure, retry, cancel frees all permits.

## Interview talking points

- "`defer` can now `await` in async functions. That makes acquire/release pairs one line and correct on every exit path, including thrown errors and cancellation."
- "The important property is ordering: the async defer completes before the function returns. `defer { Task { ... } }` does not give that; it leaks the resource for an unknown time."
- "My semaphore is an actor, so `release()` is isolated and must be awaited. That is exactly the case async defer was made for."
- "Cancellation does not skip defer. A task cancelled while waiting for a permit still gets the permit, sees `Task.checkCancellation()` throw, and the defer gives the permit back. The test proves the cancelled document never hits the network."
- "I keep concurrency control in the uploader, not the view model. The view model just starts all tasks in a task group; the semaphore decides who runs."
- "Defer bodies add implicit suspension points at scope exit. Keep them short and side-effect safe."

**Likely follow-ups**

1. *Can I use `await` in `defer` inside a synchronous function?* — No. The enclosing context must be async. In a sync function you still need another approach.
2. *Does the defer body run if the task is cancelled?* — Yes, `defer` always runs. But async calls inside it see the task as cancelled; if the cleanup checks cancellation (for example a network call), wrap it in `withTaskCancellationShield` (SE-0504, also Swift 6.4).
3. *Why not `AsyncStream` or an `OperationQueue` with `maxConcurrentOperationCount`?* — Both work. The actor semaphore keeps structured concurrency (no detached work), supports cancellation and is easy to unit test.

## Gotchas and compatibility

- **Compiler**: Swift 6.4+ (Xcode 27). It is a compile-time feature, so it runs on any deployment target (this app: iOS 17).
- **Only in async contexts**: the parent of the `defer` must be async.
- **Order**: multiple `defer` blocks still run in reverse order; each async one is awaited before the next.
- **`AsyncSemaphore.acquire()` here is not cancellation-aware while waiting**: a cancelled waiter keeps its place until it gets a permit, then exits immediately. For long queues, add `withTaskCancellationHandler` to remove the waiter.
- **Dependency bumps in this branch**: `swift-tools-version` 6.0 → 6.4 in `Package.swift`, so older toolchains fail with a clear message instead of a syntax error.

## Run it

```bash
git checkout latest/2026-11-28-async-defer
./scripts/check.sh
open App/MachineRound.xcodeproj
```
