# Machine Round iOS: `01-minimal`

Core infrastructure with no features. Start a round from here when you can bring a skeleton.

```
Package.swift                      Core, AppFeature targets; Swift 6 language mode (strict concurrency)
Sources/Core/
  Networking/AppError.swift        one error enum + userMessage + map(URLError/Decoding/Cancellation) + fromStatus
  Networking/APIClient.swift       HTTPClient protocol (URLSession conforms), typed get/send with typed throws
  State/Loadable.swift             idle / loading(previous) / loaded / failed(error, previous)
  Storage/KeyValueStore.swift      protocol + UserDefaultsStore + thread-safe InMemoryStore, JSON helpers
  UI/StateViews.swift              LoadingView, ErrorView(retry), EmptyStateView, LoadMoreFooter
Sources/AppFeature/
  AppDependencies.swift            composition root (live() for the app, fakes for tests/previews)
  RootView.swift                   NavigationStack shell
App/MachineRound.xcodeproj         iOS app target that shows RootView
```

## Why these choices (be ready to defend them)
- **One state enum (`Loadable`)**, not `isLoading`/`error`/`items` booleans that can contradict each other. `previous` keeps data on screen while reloading.
- **`HTTPClient` protocol:** `URLSession` conforms, tests pass a closure stub. No `URLProtocol` registration needed.
- **Typed throws (`throws(AppError)`)** on the client: callers switch exhaustively; views never see `URLError`.
- **Cancellation is not an error:** `AppError.cancelled` / `isCancellation` lets view models ignore it (user left or typed again).
- **Swift 6 strict concurrency on:** `Sendable` everywhere it matters; ignoring concurrency warnings in a live round is a red flag in 2026.
- **Composition root:** one place builds concrete types; features depend on protocols.

## Tests (Swift Testing)
Decoding + query building, status mapping (parameterised 401/404/500), bad JSON → `.decoding`, transport error mapping, corrupt storage treated as missing.

Next: `git checkout 02-posts-list`.
