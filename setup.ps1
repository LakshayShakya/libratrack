# setup.ps1 — One-step build setup for LibraTrack (Windows / PowerShell)
# Usage:  .\setup.ps1
#
# Prerequisites (install once):
#   - CMake   : https://cmake.org/download/  (add to PATH during install)
#   - A C++17 compiler:
#       Visual Studio 2019+  OR  MinGW-w64 via MSYS2  OR  WSL/Git Bash
#   - Git     : https://git-scm.com

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "╔══════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║       LibraTrack — Setup             ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# ── Dependency checks ─────────────────────────────────────────────────────────
$missing = $false
foreach ($tool in @("cmake", "git")) {
    if (!(Get-Command $tool -ErrorAction SilentlyContinue)) {
        Write-Host "  ✗ Missing: $tool" -ForegroundColor Red
        $missing = $true
    } else {
        $path = (Get-Command $tool).Source
        Write-Host "  ✓ Found: $tool  ($path)" -ForegroundColor Green
    }
}

if ($missing) {
    Write-Host ""
    Write-Host "Please install the missing tools and re-run setup.ps1" -ForegroundColor Red
    Write-Host "  CMake : https://cmake.org/download/"
    Write-Host "  Git   : https://git-scm.com"
    exit 1
}
Write-Host ""

# ── CMake configure ───────────────────────────────────────────────────────────
Write-Host "[1/2] Configuring build..." -ForegroundColor White
cmake -S . -B build -DCMAKE_BUILD_TYPE=Debug
if ($LASTEXITCODE -ne 0) {
    Write-Host "CMake configure failed." -ForegroundColor Red
    exit 1
}
Write-Host ""

# ── Build ─────────────────────────────────────────────────────────────────────
Write-Host "[2/2] Building..." -ForegroundColor White
cmake --build build --config Debug
if ($LASTEXITCODE -ne 0) {
    Write-Host "Build failed." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "  ✓ Setup complete!" -ForegroundColor Green
Write-Host ""
Write-Host "  Run the test for a specific issue:" -ForegroundColor White
Write-Host "    .\check.ps1 [issue-number]" -ForegroundColor Cyan
Write-Host "  Examples:" -ForegroundColor White
Write-Host "    .\check.ps1 1    — tests your fix for Issue #01" -ForegroundColor Cyan
Write-Host "    .\check.ps1 42   — tests your fix for Issue #42" -ForegroundColor Cyan
Write-Host ""
