#!/usr/bin/env bash
# Runs the package tests (macOS, fast) and builds the iOS app for the simulator.
set -euo pipefail
cd "$(dirname "$0")/.."
swift test
xcodebuild -project App/MachineRound.xcodeproj -scheme MachineRound \
  -destination 'generic/platform=iOS Simulator' -derivedDataPath .build/xcode \
  build CODE_SIGNING_ALLOWED=NO | grep -E "error:|BUILD (SUCCEEDED|FAILED)"
