# iOS coding rounds: research for this repo (checked 22 Nov 2026)

Problem branches are picked for **your profile**: SDE3 / mobile architect, about 15 years, FinTech payment SDKs (in-app checkout, UPI intent, native↔WebView) and EdTech, iOS SDKs distributed via CocoaPods and SPM, targeting senior → principal mobile roles at fintechs (JPMorgan, Mastercard, Payoneer, Adyen, NPCI, Navi).

**No company publishes its coding questions.** Below are candidate reports, interviewer write-ups and (marked) domain problems. Medium and LeetCode pages block automated reading (HTTP 403), so for those only search summaries were available.

## What senior iOS live rounds look like in 2026
- **A small app task under a clock (about 60 min)**, graded on how you build and talk: clarify, plan out loud, build the core, then edge cases ([salari.dev](https://salari.dev/writing/ios-coding-interview-questions/)). The five tasks it names: a list screen with async loading (one state enum, `@MainActor` view model, client behind a protocol, cancellation as a normal outcome); parsing JSON (snake_case, dates, optionals, what happens when one item is bad); an **image cache** (actor reentrancy across `await`, store in-flight `Task`s, size limit, no stale image in a reused cell); **debounced search** (cancel + delay, `checkCancellation`, no request for an empty query); and **fixing a buggy snippet** (retain cycle through a stored closure, UI off the main actor, force unwrap of network data, reused-cell image).
- **Interviewer side** ([MobileNativeFoundation discussion, Mar–Jul 2026](https://github.com/MobileNativeFoundation/discussions/discussions/232)): 60–90 minutes on a small realistic project instead of algorithms; candidates fix a bug, refactor a component or add a small feature. Senior signals: architecture, testing strategy, dependency injection, Swift Concurrency, performance.
- **Swift 6 strict concurrency** is on by default; ignoring concurrency warnings in a live round reads as a red flag (2026 prep guides, e.g. [offerflow](https://offerflow.pro/interview-questions/ios-developer)).

## Reports and tasks used for branches
| Branch | Source | What was asked (paraphrased) |
|---|---|---|
| `interview/async-image-cache` | A senior iOS loop with "implement an async image loader" (search summary) + salari.dev task 3; an Apple phone screen on an "image manager" ([LeetCode](https://leetcode.com/discuss/interview-question/501476/), summary only) | Load thumbnails in a list without duplicate downloads: actor, in-flight task dedupe, cancellation semantics, memory limit, downsampling |
| `swiggy/weather-favourites-sync` | [Swiggy iOS interview](https://medium.com/@pranav_ps/swiggy-ios-interview-experience-ad1018f12353) (about 2023, summary only) | 1.5-hour machine coding: weather app with a sorted city list and a favourite button kept in sync across two screens; follow-ups on `self` in closures, `weak` vs `unowned` |
| `practice/json-decoding` | salari.dev task 2 | Decode snake_case keys, a date string and optional fields; decide what one malformed item does to the whole array |
| `fintech/payment-checkout-flow` | Domain problem (your checkout/UPI background; fintech interview guides on payment-state integrity) | Payment state machine, idempotency key, polling with backoff (timeout = unknown), return from the UPI app |
| `fintech/transaction-history` | Domain problem | Day-grouped list, filters, debounced search, cursor pagination, money as `Decimal`/minor units |
| `fintech/secure-session` | Fintech security emphasis (token storage questions) | Keychain token storage, single-flight refresh with an actor, logout only on a rejected refresh |
| `practice/bugs-and-optimisation` | salari.dev task 5 + the "fix a bug / refactor" live-round format | Top 10 iOS bugs and performance problems, buggy vs fixed with tests |

## Other signals
- **Swipe (intern):** rectangle-calculator machine coding with MVVM and error handling (Medium, summary only); below your level.
- **Take-homes:** a small SwiftUI app with networking, persistence and tests, often due in 48 hours (prep guides).
- **Not found:** first-hand 2025–2026 iOS coding-round reports for JPMorgan, Mastercard, Payoneer, PhonePe, Paytm or CRED.

## Practical takeaway
1. Practise the five live tasks above until each takes under 40 minutes with tests.
2. Talk through concurrency choices (actors, `@MainActor`, cancellation) unprompted.
3. For fintech loops, bring up money as `Decimal`, idempotency, Keychain storage and "unknown is not failed" before you are asked.
