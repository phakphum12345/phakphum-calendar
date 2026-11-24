# Installation and Release Readiness

- Audit date: 2026-11-24
- This document distinguishes build artifacts from genuinely installable releases.

## 1. Current support evidence

The repository has build workflows for Web, Windows, Android, iOS, Linux, and recently isolated macOS Xcode work. The existence of a workflow is not proof of a production-signed installer or complete user journey.

| Platform | Build evidence / current documented state | Production installability | Remaining work |
|---|---|---|---|
| Web / PWA | Flutter Web and GitHub Pages workflow exists | Conditional; published SHA and live smoke test must be verified | Verify Pages deployment on main, exact deployed SHA, OAuth origin/redirect, PWA install/update |
| Windows x64 | Release ZIP workflow exists | Package may run; Google native sign-in is not established | Clean-machine install, dependencies, version/checksum, supported auth flow |
| Android | APK workflow currently documented as debug-key signed | Not a production release | Secure release keystore, signing config, checksum, clean-device install, auth test |
| iOS | Workflow produces unsigned IPA evidence | Not installable by ordinary users | Apple signing certificate, provisioning/distribution profile, bundle ID, real-device install |
| Linux x64 | Release bundle archive workflow exists | Build artifact only until dependency/install test passes | Runtime dependencies, package/install/uninstall guide, OAuth flow, clean-machine test |
| macOS | PR #179 merged independent Xcode workflow work | Do not infer broad installability from build/ad-hoc packaging | Verify exact current workflow output, signing identity, notarization/distribution decision, install test |

## 2. Android release requirements

- Store keystore and passwords only in protected GitHub Secrets or an approved signing system.
- Never commit keystore files or passwords.
- Verify application ID, version code/name, manifest permissions, deep links, and OAuth certificate fingerprints.
- Produce a release-signed APK/AAB as intended by distribution channel.
- Generate SHA-256 checksums and publish provenance/release notes.
- Install on a clean supported Android device and complete first-run, login, roster, shift-pay, report, update, and uninstall/reinstall tests.

## 3. iOS release requirements

- Configure Apple Developer team, bundle identifier, signing certificate, provisioning profile, and distribution method.
- Store credentials through protected CI secrets or an approved signing service.
- Produce a signed IPA/archive for the chosen distribution route.
- Verify URL schemes and Google OAuth client configuration.
- Install on a real supported iPhone/iPad using the intended distribution channel.
- Verify app update, data persistence, sign-in, and permissions.
- An unsigned IPA must always be labelled as a build artifact, not an installable release.

## 4. Windows and Linux

- Package all required Flutter/native runtime dependencies.
- Include version, architecture, checksum, release notes, and installation/uninstall instructions.
- Test on a clean machine without Flutter SDK or developer tools installed.
- Verify data storage path, permissions, upgrade behavior, and backup/restore.
- Do not advertise Google-connected functionality on a platform until its OAuth lifecycle passes.

## 5. Web/PWA

- Confirm the Pages deployment job actually ran and succeeded.
- Publish a deployment metadata file that records the exact source SHA and release version.
- Run HTTP smoke checks against the public site after deployment.
- Verify Flutter base path, service worker/cache update, offline fallback, and deep links.
- Configure Google OAuth authorized origin and redirect URI to the exact production URL.
- Ensure the final gate depends on successful deployment and post-deployment verification, not merely a successful build parent workflow.

## 6. macOS decision

Choose one explicit support statement:
- supported and distributed (requires signing/notarization and install verification);
- build-only/internal testing; or
- not supported for this release.

Do not advertise macOS as generally installable based only on Xcode build success or ad-hoc artifacts.

## 7. Release checklist

- [ ] Exact source SHA identified.
- [ ] Required CI checks pass on that SHA.
- [ ] Artifact name, version, architecture, and checksum verified.
- [ ] Signing identity/provenance verified where required.
- [ ] Clean installation and first-run test passed.
- [ ] Google auth test passed with a non-tester account where advertised.
- [ ] Personal mode and shift-pay journey passed.
- [ ] Upgrade and persistence behavior passed.
- [ ] Release notes and user guide updated.
- [ ] Deployment SHA verified for Web.
- [ ] No secrets included in source or artifacts.
