# Platform support policy

## Current release scope

The active build and delivery pipeline covers five targets:

1. **Windows x64** — packaged release ZIP with SHA-256 checksum.
2. **Web** — Flutter Web release deployed to GitHub Pages.
3. **Android** — release APK artifact (debug-key signed; not Play Store ready).
4. **iOS** — unsigned release app artifact (not App Store ready).
5. **Linux x64** — release application bundle archive.

Android, iOS, and Linux builds validate and publish downloadable CI artifacts.
Mobile distribution still requires the appropriate production signing setup.

| Platform | Product source | Release CI/CD | Status |
| --- | --- | --- | --- |
| Windows x64 | Yes | `.github/workflows/windows.yml` | Supported |
| Web | Yes | `.github/workflows/web.yml` | Supported |
| Android | Yes | `.github/workflows/android.yml` | Build supported |
| iOS | Yes | `.github/workflows/ios.yml` | Unsigned build supported |
| macOS | Preserved for now | None | Paused |
| Linux x64 | Yes | `.github/workflows/linux.yml` | Build supported |
| Backend/Laravel | Preserved if present | None | Paused |

## Build artifacts and distribution

The Android, iOS, and Linux workflows build artifacts without making mobile
store signing a prerequisite. These artifacts prove the app compiles for each
target; they do not replace production signing or store release workflows.

## Failure containment

Build workflows must not depend on:

- `integration_test/` existing;
- coverage files such as `coverage/lcov.info`;
- production Android/iOS signing credentials;
- backend/Laravel services;
- broad repository validation jobs.

This prevents the previously observed failures—missing `integration_test/`,
formatter self-modification, and missing coverage artifacts—from blocking the
supported release targets.

## Add another platform procedure

To add another platform, add a dedicated workflow only after:

1. the platform has an explicit product requirement;
2. its build/signing prerequisites are documented;
3. its workflow is independently tested;
4. failure in that platform cannot silently block unrelated delivery targets;
5. the support matrix is updated in the same change.
