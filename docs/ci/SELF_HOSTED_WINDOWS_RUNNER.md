# Self-hosted Windows runner for phakphum-calendar

This setup adds an **isolated** Windows runner for
`phakphum12345/phakphum-calendar`. It must not reuse or reconfigure the
existing Calendar legacy runner, Drive-letter runner, or Development Control
Platform runner.

## Isolation requirements

- Install in a new directory: `C:\actions-runner-calendar`.
- Register it only to `https://github.com/phakphum12345/phakphum-calendar`.
- Add the custom label `calendar-windows`; GitHub supplies the standard
  `self-hosted`, `windows`, and `x64` labels.
- Keep its work directory inside this new runner folder.
- Do not copy a `.runner`, `.credentials`, or `.credentials_rsaparams`
  file from another runner.
- Never commit, paste into chat, or log the short-lived registration token.
- Do not stop, remove, rename, or reconfigure any existing runner service.

## Machine prerequisites

- Git and the Flutter stable SDK must be installed and available to the
  Windows account that runs the runner service.
- Install Visual Studio 2022 with the **Desktop development with C++**
  workload and a supported Windows SDK for Flutter Windows builds.
- Confirm `flutter doctor -v` reports the Windows toolchain as ready before
  dispatching the build workflow.
- Ensure the runner service account has access only to the files and secrets
  required for this repository.

## Installation

1. Open the repository's
   **Settings → Actions → Runners → New self-hosted runner** page:
   https://github.com/phakphum12345/phakphum-calendar/settings/actions/runners
2. Select **Windows** and **x64**.
3. Follow GitHub's current download and extraction commands in an elevated
   PowerShell window, changing the destination to
   `C:\actions-runner-calendar`.
4. Use the Configure command shown by GitHub for this repository. Add the
   custom label `calendar-windows` when prompted, or use the equivalent
   `--labels calendar-windows` option. Keep the default work folder
   `_work`.
5. Install and start the service from this new folder using GitHub's displayed
   instructions. Do not run the configuration command inside an existing
   runner folder.
6. Confirm the new runner appears as **Idle** in the repository's Runners page.
   Confirm the runner name and labels before starting a workflow.

GitHub rotates runner registration tokens. Generate a fresh token from the
repository's Runners page when configuring; do not save it in this document.

## Validation workflow

The workflow
[`Self-hosted Windows Validation`](../../.github/workflows/self-hosted-windows.yml)
is manual-only and targets the exact labels
`[self-hosted, windows, x64, calendar-windows]`.

Run it only after the new runner is **Idle**:

1. Open **Actions → Self-hosted Windows Validation**.
2. Choose **Run workflow** on `main`.
3. Confirm the selected run is queued to the new Calendar runner.
4. Verify toolchain, locked dependency installation, `flutter analyze`,
   `flutter test`, Windows release build, executable, ZIP, and SHA-256 artifact.

This workflow intentionally does not run for pull requests. Never add
`pull_request` or `pull_request_target` triggers to a self-hosted workflow:
untrusted pull-request code must not execute on a machine that has access to
local files, credentials, or other services.

## Rollback

If the dedicated runner is not healthy, disable or remove **only** the runner
named for this Calendar repository from this repository's Runners settings.
Do not modify the existing Calendar legacy, Drive-letter, or DCP runners.
