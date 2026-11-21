# Machine Round iOS

A starter project for **iOS machine coding rounds**: SwiftUI (iOS 17+), Swift 6 language mode with strict concurrency, `@Observable` view models, async/await with structured cancellation, a typed `APIClient`, offline-first caching, manual pagination, debounced search, and Swift Testing. It is the iOS counterpart of the Android, Flutter and React Native starters.

The sample feature fetches posts from `jsonplaceholder.typicode.com`, caches them, and supports pagination, debounced server-side search, pull-to-refresh, favorites shared across screens, loading/error/empty states, and a detail screen with comments.

**Layout:** all code is a Swift package (`swift test` runs everything on macOS in seconds); `App/MachineRound.xcodeproj` is a thin iOS app that shows `RootView`. `./scripts/check.sh` runs the tests and builds the app for the iOS Simulator.

## Branches

**Step ladder.** Each branch builds on the previous one, so `git diff <prev>..<next>` shows exactly one feature:

| Branch | What it adds |
|---|---|
| `00-empty` | SwiftUI app shell over a Swift package, Swift Testing, check script |
| `01-minimal` | `AppError`, typed `APIClient` over an `HTTPClient` protocol, `Loadable` state enum, `KeyValueStore`, state views, composition root |
| `02-posts-list` | Offline-first list: `@MainActor @Observable` view model, cache then network, `.refreshable`, `.task` cancellation |
| `feature/post-detail` | Value-based navigation, `async let` parallel loads, cache-then-network, `.task(id:)` |
| `feature/pagination-manual` | Near-end row trigger, guarded load-more, footer states, stale-page guard |
| `feature/search-debounce` | `.searchable` + `.task(id:)` debounce (cancellable sleep), `checkCancellation`, distinct, retry |
| `main` | Everything above + persisted favorites shared through the environment, docs |

**Problem branches** (each from `01-minimal`), picked from **reported iOS rounds and fintech interview themes for your profile**. Sources: [docs/INTERVIEW_RESEARCH.md](docs/INTERVIEW_RESEARCH.md).

| Branch | Source | Problem |
|---|---|---|
| `interview/async-image-cache` | Senior iOS loop "async image loader"; common live task | Actor pipeline: in-flight dedupe (reentrancy), per-waiter cancellation, LRU, ImageIO downsampling, `CachedImage` view |
| `swiggy/weather-favourites-sync` | Swiggy iOS machine coding (1.5 h) | Sorted weather list, favourites synced across two screens via one observable store; `weak` vs `unowned` follow-up |
| `practice/json-decoding` | Common live task | snake_case, flexible ISO dates, `Decimal` money, optional vs default, unknown enums, lossy arrays |
| `fintech/payment-checkout-flow` | Fintech domain + your checkout/UPI background | Payment state machine, idempotency, backoff polling (timeout = unknown), `scenePhase` return, relaunch recovery |
| `fintech/transaction-history` | Fintech domain | Day sections, filters, debounced search, cursor pagination with `task(id:)` cancellation |
| `fintech/secure-session` | Fintech security themes | Keychain tokens, actor single-flight refresh, authorized HTTP client, auth-flow root |
| `practice/bugs-and-optimisation` | "Fix this snippet" live task | Top 10 Swift/SwiftUI bugs and performance problems with in-app demos and tests |

```bash
git checkout 02-posts-list && git checkout -b my-attempt
git diff 02-posts-list..feature/post-detail
```

## Architecture
```
SwiftUI View ──.task / actions──► @MainActor @Observable ViewModel ──► Repository (protocol) ──► APIClient ──► HTTPClient (URLSession | stub)
     ▲ reads only what it uses            │ Loadable<T> state                  │ throws(AppError)       └► KeyValueStore (cache)
     └────────────────────────────────────┘
Composition root (AppDependencies) builds concrete types; features see protocols.
```

## Concurrency rules used everywhere
- View models are `@MainActor`; state changes are compiler-checked to happen on the main thread.
- Loading runs in `.task {}` / `.task(id:)`, so it is **cancelled automatically** when the view goes away or the id changes; `AppError.cancelled` is never shown as an error.
- Debounce = `Task.sleep` inside a cancellable task; stale results are dropped with `Task.checkCancellation()`.
- Shared mutable caches are **actors**, and in-flight work is stored as a `Task` before awaiting (actor reentrancy).

## Things interviewers look for (already handled)
- One state enum instead of contradictory booleans; loading, error + Retry, empty, success; cached data kept on failure
- Client behind a protocol; typed errors; dependency injection without a container
- `List`/`ForEach` with stable ids, value-based navigation, `@State` owning `@Observable` models, `@Bindable` for bindings
- Tests with Swift Testing: stubs instead of network, controlled timing for cancellation and races

## Run
```bash
swift test                  # all package tests (macOS)
./scripts/check.sh          # tests + iOS Simulator build
open App/MachineRound.xcodeproj
```
Running on a simulator needs an iOS runtime that matches your Xcode; on this machine the build is verified with `xcodebuild` for the generic iOS Simulator destination.
