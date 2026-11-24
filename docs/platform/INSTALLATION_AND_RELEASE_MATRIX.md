# Installation and release matrix

| Platform | Build evidence | Production evidence |
|---|---|---|
| Web | Exact-SHA web build | Deployed URL, origin/redirect, smoke/update test |
| Android | Release APK/AAB | Production signing, install/upgrade/auth test |
| iOS | Xcode archive/IPA | Apple signing/provisioning and device install/auth |
| Windows | Release build | Clean-machine install, update/uninstall |
| Linux | Release package | Clean-environment install and dependencies |
| macOS | Xcode build | Signing/notarization decision and clean install |

Record version, source SHA, checksum, signing identity, target, installation/auth test, rollback and limitations. Unsigned/ad-hoc artifacts are not public production releases.