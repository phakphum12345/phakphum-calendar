@echo off
setlocal EnableExtensions
set "MODE=full"
if /I "%~1"=="--preflight" set "MODE=preflight"
if /I "%~1"=="--full" set "MODE=full"
git rev-parse --show-toplevel >nul 2>&1
if errorlevel 1 (echo RUNTIME FAIL: not inside a Git repository.& exit /b 2)
for /f "usebackq delims=" %%R in (\`git rev-parse --show-toplevel\`) do set "ROOT=%%R"
cd /d "%ROOT%"
if errorlevel 1 exit /b 2
for /f "usebackq delims=" %%S in (\`git rev-parse HEAD\`) do set "HEAD_SHA=%%S"
if errorlevel 1 exit /b 3
if defined GITHUB_SHA if /I not "%HEAD_SHA%"=="%GITHUB_SHA%" (
  echo RUNTIME FAIL: checkout SHA mismatch.
  exit /b 3
)
where git >nul 2>&1 || (echo RUNTIME FAIL: git is missing.& exit /b 4)
where python >nul 2>&1 || (echo RUNTIME FAIL: python is missing.& exit /b 4)
where flutter >nul 2>&1 || (echo RUNTIME FAIL: Flutter SDK is missing.& exit /b 4)
if not exist pubspec.yaml (echo RUNTIME FAIL: pubspec.yaml is missing.& exit /b 5)
echo RUNTIME: PASS (CMD preflight)
echo Repository: %ROOT%
echo HEAD: %HEAD_SHA%
flutter --version
if errorlevel 1 exit /b 10
python --version
if errorlevel 1 exit /b 10
if "%MODE%"=="full" (
  flutter pub get
  if errorlevel 1 exit /b 20
  flutter analyze
  if errorlevel 1 exit /b 21
  flutter test
  if errorlevel 1 exit /b 22
)
echo RUNTIME: PASS (mode=%MODE%, sha=%HEAD_SHA%)
exit /b 0
