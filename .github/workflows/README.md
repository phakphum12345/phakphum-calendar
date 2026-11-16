# GitHub Actions workflows

The active build and delivery surface covers **Windows, Web, Android, iOS, and Linux**:

- `ci-auto-detect.yml` — capability detection plus selective Dart/Flutter quality checks.
- `windows.yml` — Windows x64 release ZIP + SHA-256 checksum.
- `web.yml` — Flutter Web release + GitHub Pages deployment.
- `android.yml` — Android release APK build artifact.
- `ios.yml` — unsigned iOS release app build artifact.
- `linux.yml` — Linux x64 release bundle archive.
- `pull-request-gate.yml` — requires all seven PR evidence workflows to succeed for the exact PR head SHA.
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
| Pull request evidence gate | Required evidence workflow | `pull-request-gate.yml` |
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

`pull-request-gate.yml` is the pre-merge evidence collector. For the exact
head SHA of a code/platform PR, it waits for and requires all of these workflows
to finish successfully:

1. Auto Detect CI
2. Windows
3. Web
4. Android
5. iOS
6. Linux
7. DISKPATH generation/validation

A failed workflow fails the gate. Missing or still-running evidence remains
pending and fails if it does not complete within 30 minutes. If the PR head
changes while the gate is waiting, the old run reports itself as superseded;
the new head must be evaluated by its own gate run.

The gate uses read-only repository, Actions, and pull-request permissions. It
does not build artifacts itself, write to the PR, or deploy anything. Each
platform workflow remains independent so failures can be attributed to the
correct runner and platform.

## Final gate policy

`final-gate.yml` is the post-merge evidence gate for matching `main` pushes
and manual dispatches.

It requires successful Auto Detect CI, Windows, and Web runs for the **same
commit SHA**. Android, iOS, and Linux are optional artifact evidence on
`main`; a missing or unsuccessful optional run is recorded as `SKIPPED` and
does not fail this post-merge gate. A failed required workflow fails the gate.

This post-merge policy does not replace the stricter pre-merge PR gate. The PR
gate requires all seven workflows; the main gate confirms the core delivery
path after merge.

## DISKPATH security policy

`generate-diskpath-md.yml` is read-only on pull requests. It checks the committed
manifests against the exact checked-out commit and never pushes changes. Pull
request code is untrusted input and must not receive a write-capable token while
its scripts are executed. Contributors regenerate `DISKPATH.json` and
`DISKPATH.md` locally and commit them with their changes. The workflow disables
persisted checkout credentials and grants only `contents: read`.

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

**PR: Quality + Windows + Web + Android + iOS + Linux + DISKPATH PASS → Merge → main: core Final Gate PASS**

## Failure-containment policy

The platform build workflows remain independent:

1. The PR gate requires Auto Detect CI, Windows, Web, Android, iOS, Linux, and DISKPATH evidence for the same PR head SHA.
2. The post-merge main gate requires Auto Detect CI, Windows, and Web. Android, iOS, and Linux are best-effort on `main`; their status is explicitly reported as PASS or SKIPPED.
3. Store-signing credentials must not be required for iOS or Android compile checks.
4. Missing `integration_test/` must never be treated as a CI failure for the supported targets.
5. Coverage artifacts are not required by any platform build workflow.
6. Formatting and coverage remain developer-side checks. Auto Detect CI and Windows run analysis and unit tests.
7. A workflow must not auto-commit generated formatting changes during a release gate. Formatting changes must be committed explicitly by the developer or a dedicated maintenance job.
8. Capability detection must not mutate the source tree or introduce a new platform automatically.
9. Every evidence collector must compare workflow runs using the same exact commit SHA.
10. Missing, pending, skipped, and failed results must never be represented as PASS.

## Simplification policy

Keep each platform in a separate workflow so a native build failure is clearly
attributed and artifacts can be downloaded independently.
