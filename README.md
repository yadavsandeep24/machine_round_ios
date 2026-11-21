# Bugs and optimisation: top 10 iOS "fix this code" questions

Built from `01-minimal`. The fifth common live task is "fix a buggy ~30-line snippet: name the root cause, make the smallest fix, say how you'd catch it next time" ([salari.dev](https://salari.dev/writing/ios-coding-interview-questions/)); interviewers also run "fix a bug / refactor a component" sessions on small projects ([MobileNativeFoundation discussion](https://github.com/MobileNativeFoundation/discussions/discussions/232)). These are the 10 that come up most in Swift/SwiftUI, each with buggy and fixed code side by side, an in-app demo ("Run buggy vs fixed"), and a test that proves both.

## How to practise
1. Run the app (or read `Sources/Challenges/`). Each challenge shows the symptom; say the cause out loud, then **Show answer**.
2. Fix the `…Buggy` type yourself without reading the `…Fixed` one.
3. `swift test --filter ChallengesTests`; the buggy assertions document the broken behaviour.

## The 10
| # | Type | Symptom | Root cause | Fix | Test proves |
|---|---|---|---|---|---|
| 1 | Bug | View model never deallocated | Stored closure captures `self` strongly | `[weak self]` | buggy still alive, fixed freed |
| 2 | Bug | Polling continues after closing | Stored `Task` loop captures `self` | weak capture + cancel in `deinit` / `.task {}` | buggy alive and ticking, fixed freed |
| 3 | Bug | Same image downloaded 10× | **Actor reentrancy** across `await` | store the in-flight `Task` first | 10 downloads vs 1 |
| 4 | Bug | Results don't match the query | Older slow request lands last | cancel previous + check cancellation (`.task(id:)`) | stale "sw" vs "swift" |
| 5 | Bug | "Mark all done" does nothing | `for var item in items` mutates copies | mutate via indices | 0/2 vs 2/2 |
| 6 | Bug | Requests continue after leaving | `onAppear { Task { } }` is never cancelled | `.task { }` / keep and cancel the handle | pages keep growing vs stop |
| 7 | Bug | ₹0.30000000000000004 | `Double` money | integer minor units / `Decimal` | `0.1+0.2 != 0.3` vs exact |
| 8 | Perf | Unrelated views re-render | `ObservableObject` fires for any `@Published` | `@Observable` per-property tracking | `objectWillChange` fires vs `withObservationTracking` untouched |
| 9 | Perf | Date list stutters | `DateFormatter` per row | one shared formatter / `FormatStyle` | 200 created vs 0 |
| 10 | Perf | Memory grows until killed | Dictionary cache never evicts | `NSCache` with limits | 1000 entries vs ≤ 50 |

## How you'd catch them next time (say this)
- **Swift 6 strict concurrency** flags UI updates off the main actor and non-`Sendable` captures at compile time; keep it on.
- **Memory Graph Debugger** and Instruments **Leaks/Allocations** for 1, 2, 10; a `weak var` + `#expect(… == nil)` test like the ones here.
- **Instruments SwiftUI / Time Profiler** and `Self._printChanges()` in a view body for 8, 9.
- **Tests with controlled timing** for 3, 4, 6.

## Bonus one-liners (SwiftUI-specific, often asked)
- `@State var x = initParam` ignores later changes to the parameter: derive it, or change the view's `.id(...)`.
- `ForEach(items, id: \.self)` with duplicates or `\.name` that isn't unique: rows mix up; use a stable unique id.
- Force unwraps / `try!` on network data crash on the first bad payload: decode safely (see `practice/json-decoding`).
- `AnyView` everywhere defeats diffing; prefer `@ViewBuilder` and concrete types.
- Heavy work inside `body` (sorting, formatting): compute in the model when inputs change.
- `GeometryReader` at the top of every row forces extra layout passes.
- Images decoded at full size in lists: downsample (see `interview/async-image-cache`).

## Tests (16)
Ten challenge tests + one test that runs every in-app demo and checks buggy ≠ fixed, plus core (5). Repeated 5× locally without flakes.
