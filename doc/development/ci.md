# Component CI

[Component checks](../../.github/workflows/ci.yml) runs quality checks on the
pinned and current stable Flutter SDKs and builds the Android example on Linux.
Each pull request update cancels the previous run for that pull request. Feature
branch pushes get their CI run through the pull request.

On ordinary pull requests, the Linux scope job compares the PR merge commit
with its base parent. The CocoaPods and Swift Package Manager simulator
builds and the iOS 26 and iOS 27 native interaction suites run when the diff
touches any of these inputs.

- The plugin and example iOS projects in `ios/` and `example/ios/`.
- The package and example Dart sources in `lib/` and `example/lib/`, the
  example assets in `example/assets/`, and `example/.metadata`.
- Package manifests and lockfiles at the root and under `example/`.
- The Component checks workflow or `.github/scripts/`.

Documentation, Dart unit tests and Android-only changes keep their Linux
checks and skip the macOS jobs. Pushes to `main` or `release/**`, tag pushes,
manual runs and pull requests involving a `release/**` branch run the full
suite. Every push and manual run gets its own concurrency group.

[Publish release assets](../../.github/workflows/release.yml) requires a
successful push or manual Component checks run for the tagged commit. The
artifact verification and publishing steps are unchanged.
