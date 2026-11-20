#!/usr/bin/env sh
set -eu
ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "RUNTIME FAIL: not inside a Git repository" >&2; exit 2; }
cd "$ROOT"
MODE=full
for arg in "$@"; do
  case "$arg" in
    --preflight) MODE=preflight ;;
    --full) MODE=full ;;
    *) echo "Unknown argument: $arg" >&2; exit 2 ;;
  esac
done
HEAD_SHA="$(git rev-parse HEAD)"
EXPECTED_SHA="$(printenv GITHUB_SHA 2>/dev/null || true)"
if [ -n "$EXPECTED_SHA" ] && [ "$HEAD_SHA" != "$EXPECTED_SHA" ]; then
  echo "RUNTIME FAIL: checkout SHA mismatch (expected $EXPECTED_SHA, got $HEAD_SHA)" >&2
  exit 3
fi
for tool in git python3 flutter; do
  command -v "$tool" >/dev/null 2>&1 || { echo "RUNTIME FAIL: required executable missing: $tool" >&2; exit 4; }
done
[ -f pubspec.yaml ] || { echo "RUNTIME FAIL: pubspec.yaml is missing" >&2; exit 5; }
echo "RUNTIME: PASS (POSIX sh preflight)"
echo "Repository: $ROOT"
echo "HEAD: $HEAD_SHA"
flutter --version
python3 --version
if [ "$MODE" = full ]; then
  flutter pub get
  flutter analyze
  flutter test
fi
echo "RUNTIME: PASS (mode=$MODE, sha=$HEAD_SHA)"
