# GitHub Actions workflows

The active build and delivery surface covers **Windows, Web, Android, iOS, and Linux**:

- `ci-auto-detect.yml` — capability detection plus selective Dart/Flutter quality checks.
- `windows.yml` — Windows x64 release ZIP + SHA-256 checksum.
- `web.yml` — Flutter Web release + GitHub Pages deployment.
- `android.yml` — Android release APK build artifact.
- `ios.yml` — independent iOS/Xcode unsigned release build + IPA/SHA-256 artifacts.
- `linux.yml` — Linux x64 release bundle archive.
- `pull-request-gate.yml` — core PR evidence gate for Auto Detect CI, Windows, Web, Android, and Linux.
- `ios-evidence-gate.yml` — non-blocking PR advisory report for independent iOS evidence.
- `final-gate.yml` — post-merge gate for the same `main` commit; Auto Detect CI, Windows, and Web are required, while Android, iOS, and Linux remain best-effort on `main`.

macOS, broad repository validation, coverage gates, and integration-test gates
are not active delivery gates. Laravel Backend CI is active for backend changes
but does not deploy the API. The Android, iOS, and Linux workflows build
artifacts; mobile store distribution and signing are not configured.

## Support policy

For the current stabilization phase:

| Target | Status | CI/CD |
| --- | --- | --- |
| Windows x64 | Supported | `windows.yml` |
| Web / GitHub Pages | Supported | `web.yml` |
| Capability detection | Supported | `ci-auto-detect.yml` |
| Core pull request evidence gate | Required evidence workflow | `pull-request-gate.yml` |
| iOS advisory evidence report | Non-blocking diagnostic workflow | `ios-evidence-gate.yml` |
| Post-merge final evidence gate | Supported | `final-gate.yml` |
| Android | Build supported | `android.yml` |
| iOS | Unsigned build supported | `ios.yml` |
| macOS | Paused | No active workflow |
| Linux x64 | Build supported | `linux.yml` |
| Backend/Laravel | CI supported | `laravel.yml` (tests only; no deployment) |

Mobile artifacts are CI builds, not store-ready packages: Android currently
uses the debug signing configuration, and iOS is built without code signing.

## CI capability detection policy

`ci-auto-detect.yml` is the lightweight source-of-truth guard for the current
delivery surface. It detects whether the repository contains the Flutter/Dart
project and whether platform source directories exist. It treats
`integration_test/` as optional.

The workflow runs analysis and tests when the detected project capabilities
require them. It does not run formatting, generate coverage, or build platform
artifacts. It must not mutate source files or auto-format code.

## Pull request gate policy

`pull-request-gate.yml` is the core pre-merge evidence collector. For the exact
head SHA of a code/platform PR, it waits for and requires these five workflows:

1. Auto Detect CI
2. Windows
3. Web
4. Android
5. Linux

This gate does not wait for a macOS runner. A failed core workflow fails the
gate. Missing or still-running core evidence remains pending and fails if it
does not complete within 30 minutes. If the PR head changes while the gate is
waiting, the old run reports itself as superseded; the new head is evaluated by
its own gate run.

## Independent iOS / Xcode build

`ios.yml` owns the iOS build lifecycle. It starts on manual dispatch, iOS-relevant
pull-request changes, and matching pushes to `main`. It does not declare
`needs`, poll Windows/Linux/Android/Web/macOS workflows, or wait for their
results. Its concurrency group is unique per run and does not cancel a build
that is queued for a GitHub-hosted macOS runner.

The iOS workflow checks out the exact PR head SHA (or the pushed commit),
verifies the macOS/Xcode toolchain and iOS Runner project, resolves Flutter
dependencies, builds the unsigned iOS release, verifies the app bundle, and
publishes an IPA plus SHA-256 checksum as its own artifact. It uses
`macos-15` by default; `IOS_RUNNER_LABEL` can override the runner label.

GitHub may still queue the job while no matching macOS runner capacity is
available. This is runner allocation, not a dependency on another workflow.
The IPA is unsigned and is not ready for App Store distribution.

## Separate iOS advisory evidence

`ios-evidence-gate.yml` is a separate, non-blocking observer for the iOS build
of the same PR number and exact head SHA. It waits only for that PR's own iOS
workflow (not for any other platform CI), and never holds the core Pull Request
Gate open. It reports one of these states in its job summary:

- `PASS`: the unsigned iOS build completed successfully.
- `FAIL`: the iOS build ran and failed; the original `ios.yml` check remains
  failed and the report records the reason.
- `SKIPPED`: no iOS run became available in the observation window, or the run
  was cancelled before build evidence was produced (for example, runner
  allocation did not happen).

The advisory reporter itself exits successfully after publishing the report;
that means the report was delivered, **not** that iOS passed. The original
`ios.yml` result remains visible and is never rewritten as PASS or SKIPPED.

**Core merge eligibility:** iOS `FAIL` or `SKIPPED` does not block continued
core development or the core PR gate. Merge eligibility is based on the exact
head SHA passing the core Pull Request Gate, clean review/code checks, and the
repository's other required checks. iOS failures must remain visible and be
tracked for follow-up; they are not silently converted into success. The
workflow split does not change repository branch protection/rulesets, which
must be checked separately before relying on automatic enforcement.

Both evidence collectors use read-only repository, Actions, and pull-request
permissions. They do not build artifacts themselves, write to the PR, or
deploy anything. Platform build workflows remain independent so failures can
be attributed to the correct runner and platform.

## Final gate policy

`final-gate.yml` is the post-merge evidence gate for matching `main` pushes
and manual dispatches.

It requires successful Auto Detect CI, Windows, and Web runs for the **same
commit SHA**. Android, iOS, and Linux are optional artifact evidence on
`main`; a missing or unsuccessful optional run is recorded as `SKIPPED` and
does not fail this post-merge gate. A failed required workflow fails the gate.

This post-merge policy does not replace the pre-merge policy: the core PR gate
and all repository-required checks must pass; iOS is separately reported and
is non-blocking.

## Repository secrets

- `GOOGLE_WEB_CLIENT_ID` — used by the Web deployment when Google Sign-In is enabled.
- `GOOGLE_SERVER_CLIENT_ID` — optional server OAuth client used by the Windows build and Web build.

`GOOGLE_IOS_CLIENT_ID` may be configured for the iOS build. OAuth secrets are
optional for compilation; without them, Google sign-in is not configured for
the resulting artifact.

## Active delivery gates

### Windows

The Windows workflow installs dependencies, builds the release application,
packages it as a ZIP, and produces a SHA-256 checksum. It runs manually or
when relevant Windows, Flutter, asset, dependency, or workflow files change
on `main`.

### Web

The Web workflow installs dependencies, builds the release site, uploads the
build as a downloadable artifact, and deploys the same build to GitHub Pages
from `main`.

### Final

The delivery path is separated into pre-merge and post-merge evidence:

**PR: Core Quality + Windows + Web + Android + Linux PASS → Merge eligibility (iOS advisory PASS / FAIL / SKIPPED) → main: core Final Gate PASS**

## Failure-containment policy

The platform build workflows remain independent:

1. The core PR gate requires Auto Detect CI, Windows, Web, Android, and Linux evidence for the same PR head SHA.
2. The iOS advisory report records PASS, FAIL, or SKIPPED for the same PR head SHA; it never blocks the core gate and never changes the original iOS workflow result.
3. The post-merge main gate requires Auto Detect CI, Windows, and Web. Android, iOS, and Linux are best-effort on `main`; their status is explicitly reported as PASS or SKIPPED.
4. Store-signing credentials must not be required for iOS or Android compile checks.
5. Missing `integration_test/` must never be treated as a CI failure for the supported targets.
6. Coverage artifacts are not required by any platform build workflow.
7. Formatting and coverage remain developer-side checks. Auto Detect CI and Windows run analysis and unit tests.
8. A workflow must not auto-commit generated formatting changes during a release gate. Formatting changes must be committed explicitly by the developer or a dedicated maintenance job.
9. Capability detection must not mutate the source tree or introduce a new platform automatically.
10. Every evidence collector must compare workflow runs using the same exact commit SHA.
11. Missing, pending, skipped, and failed results must never be represented as PASS.

## Simplification policy

Keep each platform in a separate workflow so a native build failure is clearly
attributed and artifacts can be downloaded independently.
