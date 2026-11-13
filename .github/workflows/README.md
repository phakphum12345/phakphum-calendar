# GitHub Actions workflows

The active build and delivery surface covers **Windows, Web, Android, iOS, and Linux**:

- `ci-auto-detect.yml` — capability detection plus selective Dart/Flutter quality checks.
- `windows.yml` — Windows x64 release ZIP + SHA-256 checksum.
- `web.yml` — Flutter Web release + GitHub Pages deployment.
- `android.yml` — Android release APK build artifact.
- `ios.yml` — unsigned iOS release app build artifact.
- `linux.yml` — Linux x64 release bundle archive.
- `final-gate.yml` — requires Auto Detect CI, Windows, and Web for the same `main` commit; Android, iOS, and Linux are best-effort and may be skipped with a recorded reason.

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
| Final evidence gate | Supported | `final-gate.yml` |
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

## Final gate policy

`final-gate.yml` is the final evidence gate for matching `main` pushes and
manual dispatches.

It requires successful Auto Detect CI, Windows, and Web runs for the **same
commit SHA**. Android, iOS, and Linux are optional artifact evidence; a missing
or unsuccessful optional run is recorded as `SKIPPED` and does not fail the
gate. A failed required workflow fails the final gate.

This prevents a green result from one platform being mistaken for a complete
release result and avoids bringing back the old formatter/coverage failure
chain.

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

The final gate combines required quality and core delivery evidence for one exact
commit. Optional platform artifacts are reported separately and do not block the
core result when unavailable or behind:

**Clean → Capability-aware CI → Windows PASS + Web PASS → optional Android/iOS/Linux PASS or SKIPPED → Final PASS**

## Failure-containment policy

The platform build workflows remain independent:

1. Auto Detect CI, Windows, and Web are required release evidence.
2. Android, iOS, and Linux are optional artifact evidence. Their workflows run
   for matching pull requests, relevant pushes to `main`, or manual dispatch.
   The final gate runs on `main`, waits up to 10 minutes for optional targets,
   then records any missing or unsuccessful target as `SKIPPED`.
3. Store-signing credentials must not be required for iOS or Android compile checks.
4. Missing `integration_test/` must never be treated as a CI failure for the
   supported targets.
5. Coverage artifacts are not required by any platform build workflow.
6. Formatting and coverage remain developer-side checks. Auto Detect CI and
   Windows run analysis and unit tests.
7. A workflow must not auto-commit generated formatting changes during a
   release gate. Formatting changes must be committed explicitly by the
   developer or a dedicated maintenance job.
8. Capability detection must not mutate the source tree or introduce a new
   platform automatically.
9. The final gate must compare required evidence using the same commit SHA.
10. Skipped optional targets must be visible in the job log with a reason; skipping
   an optional target must never hide a failure in required quality, Windows, or Web checks.

## Simplification policy

Keep each platform in a separate workflow so a native build failure is clearly
attributed and artifacts can be downloaded independently.
