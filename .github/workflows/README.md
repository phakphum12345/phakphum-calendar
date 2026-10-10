# GitHub Actions workflows

The active build and delivery surface covers **Windows, Web, Android, iOS, and Linux**:

- `ci-auto-detect.yml` — capability detection plus selective Dart/Flutter quality checks.
- `windows.yml` — Windows x64 release ZIP + SHA-256 checksum.
- `web.yml` — Flutter Web release + GitHub Pages deployment.
- `android.yml` — Android release APK build artifact.
- `ios.yml` — unsigned iOS release app build artifact.
- `linux.yml` — Linux x64 release bundle archive.
- `final-gate.yml` — verifies Auto Detect CI and all five platform builds passed for the same `main` commit.

macOS, Laravel/backend validation, broad repository validation, coverage
gates, and integration-test gates are not active delivery gates. The Android,
iOS, and Linux workflows build artifacts; mobile store distribution and signing
are not configured.

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
| Backend/Laravel | Paused | No active workflow |

Mobile artifacts are CI builds, not store-ready packages: Android currently
uses the debug signing configuration, and iOS is built without code signing.

## Owner-generated v6^6 capability policy

`ci-auto-detect.yml` is the lightweight source-of-truth guard for the current
delivery surface. It detects whether the repository contains the Flutter/Dart
project and whether platform source directories exist. It treats
`integration_test/` as optional.

The capability gate is intentionally independent of Dart formatting, static
analysis, coverage generation, and platform release builds. It must not mutate
source files and must not auto-format code.

## Final gate policy

`final-gate.yml` is the final evidence gate for `main`.

It is triggered when an active platform build completes on `main`. It verifies
that Auto Detect CI and Windows, Web, Android, iOS, and Linux all have
successful completed runs for the **same commit SHA** before reporting
`FINAL PASS`. A failed platform build fails the final gate.

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

The final gate combines quality and successful build evidence from all five
targets for one exact commit. The intended sequence is:

**Clean → Capability-aware CI → Windows PASS → Web PASS → Android PASS → iOS PASS → Linux PASS → Final PASS**

## Failure-containment policy

The platform build workflows remain independent:

1. Store-signing credentials must not be required for iOS or Android compile checks.
2. Missing `integration_test/` must never be treated as a CI failure for the
   supported targets.
3. Coverage artifacts are not required by any platform build workflow.
4. Formatting and coverage remain developer-side checks. Auto Detect CI and
   Windows run analysis and unit tests.
5. A workflow must not auto-commit generated formatting changes during a
   release gate. Formatting changes must be committed explicitly by the
   developer or a dedicated maintenance job.
6. Capability detection must not mutate the source tree or introduce a new
   platform automatically.
7. The final gate must compare results using the same commit SHA.

## Simplification policy

Keep each platform in a separate workflow so a native build failure is clearly
attributed and artifacts can be downloaded independently.
