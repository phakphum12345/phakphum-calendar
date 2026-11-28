# GitHub Actions workflows

The delivery surface has independent workflows for Windows, Web, Android, iOS, macOS and Linux, plus backend, security, cross-platform and evidence gates.

## Workflow roles

- \`ci-auto-detect.yml\` — capability detection and selective Dart/Flutter quality checks.
- \`windows.yml\` — Windows x64 build/package evidence.
- \`web.yml\` — Flutter Web build, downloadable artifact and guarded GitHub Pages deployment.
- \`android.yml\` — Android APK build evidence.
- \`ios.yml\` — unsigned iOS app build evidence.
- \`macos.yml\` — independent macOS/Xcode build and ad-hoc artifact evidence.
- \`linux.yml\` — Linux x64 build/package evidence.
- \`laravel.yml\` — backend validation/tests; it does not deploy the API.
- \`dependency-security.yml\` — dependency vulnerability scanning.
- \`pull-request-gate.yml\` — core exact-head PR evidence gate.
- \`ios-evidence-gate.yml\` — separate iOS advisory evidence.
- \`cross-platform-runtime.yml\` — cross-shell launcher/runtime checks.
- \`final-gate.yml\` — post-merge evidence collector for the exact main SHA.

## Backend configuration guard

Production release artifacts and the Pages deployment require a valid HTTPS \`ORGANIZATION_API_BASE_URL\`. The guard behavior was updated in PR #215:

- Pull-request builds can run build/test evidence without production backend configuration.
- On main/manual platform runs, a missing or non-HTTPS backend URL is recorded as an explicit SKIPPED production artifact; it is not represented as a successful release.
- The Web build artifact may be retained for inspection, but Pages deployment and published-site verification are skipped when the backend URL is invalid.
- No placeholder URL is inserted, no local-only Schedule fallback is published as production, and no backend is deployed by these workflows.
- When the valid HTTPS backend URL is configured, the production build/deployment path is eligible to run and must still pass its own checks.

A skipped production artifact or deployment is not a production release and must be reported as such.

## Platform support and distribution boundaries

| Target | CI evidence | Distribution boundary |
|---|---|---|
| Windows x64 | Build/package workflow | Clean-machine install and production release acceptance still required |
| Web | Build; Pages deployment only with valid HTTPS backend config | Exact deployed SHA and live health verification required |
| Android | APK build | Debug/unsigned or CI artifact is not store-ready without production signing and device acceptance |
| iOS | Unsigned build | Not installable for general distribution without signing/provisioning and device acceptance |
| macOS | Xcode build/ad-hoc artifact | Not notarized distribution unless separately configured and verified |
| Linux x64 | Build/package workflow | Clean-machine dependency/install acceptance still required |
| Laravel backend | CI/tests | No automatic API deployment is performed |

## Evidence rules

1. Verify base SHA and exact PR head SHA.
2. Inspect all changed files, deletions, review decisions and unresolved threads.
3. Require all repository-required checks to reach terminal success on the exact revision.
4. Treat skipped, unknown, cancelled, missing, stale and pending checks as not passing.
5. The PR gate and post-merge Final Gate are separate; neither substitutes for live provider/device acceptance.
6. Android, iOS, Linux and macOS artifact results must be reported individually; an advisory report succeeding does not convert a failed or skipped platform build into PASS.
7. Formatting changes must be committed explicitly; release workflows must not mutate source files.

## Deployment and security boundaries

- Laravel CI validates source and tests only; it does not provision infrastructure, run production migrations or deploy the backend.
- Production backend secrets, VAPID keys, OAuth settings, Google Calendar data and production deployments are outside CI and require controlled configuration.
- Do not expose secrets in source, logs, client bundles or artifacts.
- Record deployed SHA, environment, health checks, migration status and rollback evidence before declaring production readiness.
