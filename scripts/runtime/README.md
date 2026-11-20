# Cross-platform repository runtime

Entry points:
- POSIX shell: scripts/runtime/run.sh
- PowerShell: scripts/runtime/run.ps1
- Windows Command Prompt: scripts/runtime/run.cmd

Requirements: Git, Python 3, and Flutter SDK 3.47.2 (the version selected by repository CI).

Usage:
- sh scripts/runtime/run.sh --preflight
- sh scripts/runtime/run.sh --full
- ./scripts/runtime/run.ps1 -Preflight
- ./scripts/runtime/run.ps1 -Full
- scripts\runtime\run.cmd --preflight
- scripts\runtime\run.cmd --full

Preflight verifies the Git checkout, the expected CI SHA when GITHUB_SHA is set, and required executables. Full mode runs flutter pub get, flutter analyze, and the complete flutter test suite.

The runtime does not commit, push, merge, deploy, delete project data, reset a database, or change repository settings. Required command failures return non-zero exit codes. Skipped or unavailable checks are not treated as passes.

The GitHub Actions workflow exercises all three entrypoints. The full quality suite runs in Linux sh and Windows PowerShell; launcher smoke tests run in Linux PowerShell and Windows CMD to avoid multiplying the expensive Flutter test suite.

This is a quality runner, not an autonomous code-writing agent. A green run proves only commands that actually executed on that exact commit. Platform release builds, Laravel tests, integration tests, deployment, live Google services, and data recovery require their own evidence.
