# Fintech: secure session (Keychain, single-flight refresh)

Built from `01-minimal`. Why: security dominates fintech loops (your targets include Navi mobile security, NPCI, Mastercard), and token storage plus refresh under concurrency is the standard question. API: dummyjson auth (`/auth/login`, `/auth/refresh`, `/auth/me`; demo account in the [dummyjson docs](https://dummyjson.com/docs/auth)).

## What is built
- `KeychainTokenStore`: `SecItem*` with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` (not readable while locked, not restored to another device). `InMemoryTokenStore` for tests.
- `TokenRefresher` (actor): **single flight**: the in-flight refresh `Task` is shared, so 5 parallel 401s make one refresh call; if another request already refreshed, its token is reused. Only a rejected refresh token (401/403, or 400 from dummyjson) ends the session; 5xx/network keep it.
- `AuthorizedHTTPClient`: wraps any `HTTPClient`; adds the bearer, on 401 asks the refresher, retries **once**. Login/refresh use a plain client, so refresh can't recurse.
- `SessionModel` (`@MainActor @Observable`): restore at launch without a network call, sign in, sign out; expiry arrives through an `AsyncStream` (no MainActor object captured by the actor: Swift 6 data-race safe).
- Views: the root swaps Login ↔ Profile on status; login has validation, `.textContentType(.username/.password)` for AutoFill, focus handling, double-submit guard, a generic "Wrong username or password".

## Points to make in the round
| Question | Answer |
|---|---|
| Where do tokens go? | Keychain, not UserDefaults (plain plist). Access token short-lived; refresh token rotated on every refresh. |
| Refresh concurrency? | Actor + shared `Task` (tested: 5 parallel 401s → 1 refresh). Actor reentrancy is why the task must be stored *before* awaiting. |
| When to log out? | Only when the refresh endpoint rejects the token (tested), never on a network error (tested). |
| Biometrics? | `SecAccessControl` with `.biometryCurrentSet` on the refresh token, or `LAContext` on resume. |
| More hardening | TLS pinning for payment APIs, jailbreak signals, blur the app-switcher snapshot (`scenePhase == .inactive`), no tokens or PII in logs/crash reports, ATS on. |

## Tests (12)
Refresher (3): parallel 401s → one refresh, rejected refresh clears the session + expiry fires, 503 keeps the session. Session (4): restore without network, sign in → tokens stored → profile loads, wrong password stays signed out, sign out clears. Plus core (5). The real Keychain is not exercised by `swift test` (it needs an app entitlement context); run the app to try it.
