# Automatic CI detection

The CI layer now detects the project capabilities before enabling language-specific checks.

## Rules

- `pubspec.yaml` + Dart sources → Dart quality checks are enabled.
- Flutter project → Flutter SDK is used because `package:flutter/*` requires the Flutter SDK; it runs analysis and tests with the bundled Dart SDK.
- Pure Dart project → Dart SDK is used directly with `dart pub get`, `dart analyze`, and `dart test`.
- No Dart sources → Dart quality checks are skipped.
- `test/` with `*_test.dart` → unit tests are enabled; this workflow does not generate coverage.
- `integration_test/` with Dart files → Flutter integration tests are enabled only for Flutter projects.
- Platform directories are detected independently (`web`, `windows`, `android`, `ios`, `macos`, `linux`) and reported in the workflow summary.

## Failure prevention

The workflow never assumes that `integration_test/` exists and does not
require or upload a coverage artifact. Unit tests run only when test files are
detected. This prevents failures from a missing integration-test directory or
`coverage/lcov.info`.

Auto Detect CI, Windows, and Web are the required main-branch gates. Android,
iOS, and Linux have separate optional artifact workflows; Laravel Backend CI
tests relevant backend changes but does not deploy the API. Auto Detect CI
enables analysis and tests only when the corresponding project capability is
present.
