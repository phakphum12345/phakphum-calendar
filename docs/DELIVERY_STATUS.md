# Delivery Status

## Current delivery contract

Windows and Web are the required application delivery targets. Android, iOS,
and Linux have active optional artifact workflows; macOS has no active build
workflow.

```text
main
├── Required: Auto Detect CI, Windows, Web
├── Final Gate: verifies required workflows for the same main commit
├── Optional artifacts: Android, iOS, Linux
└── No active workflow: macOS
```

Use the Actions run for the exact commit SHA to determine its current result.
This document describes workflow policy, not a permanent PASS snapshot.

## Platform policy

| Target | Status | Workflow and role |
| --- | --- | --- |
| Auto Detect CI | Required | `.github/workflows/ci-auto-detect.yml` |
| Windows x64 | Required | `.github/workflows/windows.yml` |
| Web / GitHub Pages | Required | `.github/workflows/web.yml` |
| Final Gate | Required on `main` | `.github/workflows/final-gate.yml` |
| Android | Optional APK artifact | `.github/workflows/android.yml` |
| iOS | Optional unsigned IPA artifact | `.github/workflows/ios.yml` |
| Linux x64 | Optional application archive | `.github/workflows/linux.yml` |
| macOS | Paused; no workflow | None |
| Backend/Laravel | Backend tests, not deployment | `.github/workflows/laravel.yml` |

Android, iOS, and Linux builds are best-effort artifacts and do not block the
Final Gate. The backend workflow validates backend changes but is not an
application delivery gate.

## Failure-containment rules

- Do not require `integration_test/` when the repository does not contain it.
- Do not upload `coverage/lcov.info` from Windows/Web release workflows.
- Do not auto-commit formatter output inside a release gate.
- Do not add a macOS workflow without an explicit support decision.
- Keep Windows and Web workflows independent.
- Changes to documentation alone must not trigger platform builds unless the
  workflow path filter explicitly includes the relevant documentation.

## Optional platform policy

Android, iOS, and Linux artifacts are already built by independent workflows;
they remain optional evidence. Making any one a required gate requires an
explicit policy change and isolated verification. macOS remains paused and
would require its own workflow and verification before reactivation.
