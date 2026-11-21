# Fintech: payment checkout flow (Swift)

Built from `01-minimal`. A **domain problem** for your profile (in-app checkout, UPI intent, payment SDKs): fintech loops probe payment-state integrity, idempotency and money precision. Same design as the React Native version, in Swift Concurrency.

## The state machine (`PaymentMachine.swift`, pure `reduce`)
```
idle ─pay─► initiating ─created(url)─► awaitingAuthorization ─returnedFromAuthorization─► processing
               │       └─created─────────────────────────────────────────────────────►    │
               └─createFailed─► failed ◄─status(failed)──────────────────────────────────────┤
                                  └ reset ► idle                     timedOut ─► unknown ─────┤
                                                                                 status(succeeded) ─► succeeded (final)
```
Illegal events return the same state (double tap, anything after `succeeded`).

## Rules it enforces (all tested)
| Rule | Why |
|---|---|
| **Timeout = unknown, never failed** | "Failed" for a payment that went through makes users pay twice |
| **Same idempotency key on retry of a lost create response** | Server returns the same payment: 2 calls, 1 payment |
| **New key only after a definite failure** | A declined card is a new attempt |
| **Double tap → one payment** | `pay()` moves the state out of `.idle` before its first `await` (MainActor, no lock needed) |
| **Polling with backoff, network blips aren't failures** | 1, 2, 4, 8, 15, 30 s (sleep injected for tests) |
| **UPI / 3DS return** | `openURL`, then `scenePhase == .active` → `appBecameActive()` resumes polling |
| **App killed mid-payment** | Pending payment saved; `restoreIfNeeded()` re-checks it at launch |
| **Money** | `Int64` minor units, `Decimal` for display, `₹588.82` (en_IN), currency-mismatch guard |
| **PCI scope** | Cards go through the gateway SDK / hosted fields; the app never sees the PAN |

## Say this too
The server's webhook is the truth; polling is the client's view. Verify UPI status server-side, never trust the UPI app's return payload. No card data, VPA or tokens in logs or analytics.

## Tests (16)
Machine (5) + view model (6): UPI open → return → success, double tap → one payment, lost response → same key, polling budget → unknown → Check status, decline → new key, relaunch recovery. Plus core (5).
