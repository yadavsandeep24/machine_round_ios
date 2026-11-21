# Machine Round iOS: `00-empty`

A blank SwiftUI app (iOS 17+, Swift 6 language mode with strict concurrency) set up the way that is fastest in a machine round:

- **All code lives in a Swift package** (`Package.swift`, `Sources/`, `Tests/`). `swift test` builds and runs the tests on macOS in seconds, with no simulator.
- **`App/MachineRound.xcodeproj`** is a thin iOS shell: one `@main` file that shows `RootView` from the package (product `MachineRoundKit`, module `AppFeature`). Open it in Xcode and run.
- Tests use **Swift Testing** (`import Testing`, `@Test`, `#expect`).

```bash
swift test                 # package tests
./scripts/check.sh         # tests + iOS simulator build
open App/MachineRound.xcodeproj
```

Next step: `git checkout 01-minimal`.
