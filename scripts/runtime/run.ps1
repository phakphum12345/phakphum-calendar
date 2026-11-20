[CmdletBinding()]
param([switch]$Preflight, [switch]$Full)
$ErrorActionPreference = "Stop"
if (-not $Preflight -and -not $Full) { $Full = $true }
function Invoke-Checked([string]$Command, [string[]]$Arguments) {
    & $Command @Arguments
    if ($LASTEXITCODE -ne 0) { throw "Command failed ($LASTEXITCODE): $Command $($Arguments -join ' ')" }
}
try {
    $root = (& git rev-parse --show-toplevel).Trim()
    if ($LASTEXITCODE -ne 0 -or -not $root) { throw "Not inside a Git repository." }
    Set-Location -LiteralPath $root
    $head = (& git rev-parse HEAD).Trim()
    if ($LASTEXITCODE -ne 0) { throw "Unable to read Git HEAD." }
    if ($env:GITHUB_SHA -and $head -ne $env:GITHUB_SHA) { throw "Checkout SHA mismatch: expected $env:GITHUB_SHA, got $head" }
    foreach ($tool in @("git", "python", "flutter")) {
        if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) { throw "Required executable is missing: $tool" }
    }
    if (-not (Test-Path -LiteralPath "pubspec.yaml")) { throw "pubspec.yaml is missing." }
    Write-Host "RUNTIME: PASS (PowerShell preflight)"
    Write-Host "Repository: $root"
    Write-Host "HEAD: $head"
    Invoke-Checked "flutter" @("--version")
    Invoke-Checked "python" @("--version")
    if ($Full) {
        Invoke-Checked "flutter" @("pub", "get")
        Invoke-Checked "flutter" @("analyze")
        Invoke-Checked "flutter" @("test")
    }
    Write-Host "RUNTIME: PASS (sha=$head)"
    exit 0
} catch {
    Write-Error "RUNTIME: FAIL - $($_.Exception.Message)"
    exit 1
}
