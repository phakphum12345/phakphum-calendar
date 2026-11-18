# GitHub Actions workflows

The active build and delivery surface covers **Windows, Web, Android, iOS, and Linux**:

- `ci-auto-detect.yml` — capability detection plus selective Dart/Flutter quality checks.
- `windows.yml` — Windows x64 release ZIP + SHA-256 checksum.
- `web.yml` — Flutter Web release + GitHub Pages deployment.
- `android.yml` — Android release APK build artifact.
- `ios.yml` — independent unsigned iOS release app build artifact.
- `linux.yml` — Linux x64 release bundle archive.
- `pull-request-gate.yml` — core PR evidence gate for Auto Detect CI, Windows, Web, Android, and Linux.
- `ios-evidence-gate.yml` — separate PR evidence collector that waits for the independent iOS workflow.
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
| iOS pull request evidence gate | Separate required evidence workflow | `ios-evidence-gate.yml` |
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

## Separate iOS evidence gate

`ios-evidence-gate.yml` independently waits for `ios.yml` to complete for the
same PR number and exact head SHA. It can wait up to 120 minutes without holding
the core Pull Request Gate open. A successful iOS build is PASS; a failed,
cancelled, missing, or timed-out iOS run is not PASS.

**Merge policy remains strict:** require both the core Pull Request Gate and
iOS Evidence Gate to pass for the current exact PR head. A green core gate
alone does not authorize merge. The repository branch-protection/ruleset
configuration must require both check names for GitHub to enforce this
automatically; otherwise the merge operator must verify both checks manually.
The workflow split itself does not change repository branch protection.

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

This post-merge policy does not replace the stricter pre-merge policy: the core
PR gate and the separate iOS Evidence Gate must both pass before merge.

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

**PR: Core Quality + Windows + Web + Android + Linux PASS AND iOS Evidence PASS → Merge → main: core Final Gate PASS**

## Failure-containment policy

The platform build workflows remain independent:

1. The core PR gate requires Auto Detect CI, Windows, Web, Android, and Linux evidence for the same PR head SHA.
2. The separate iOS Evidence Gate requires a successful iOS build for that same PR head SHA.
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
