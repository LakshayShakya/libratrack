# setup.ps1 - One-step build setup for LibraTrack (Windows / PowerShell)
# Usage:  .\setup.ps1
#
# Prerequisites (install once):
#   - CMake   : https://cmake.org/download/  (add to PATH during install)
#   - A C++17 compiler:
#       Visual Studio 2019+  OR  MinGW-w64 via MSYS2  OR  WSL/Git Bash
#   - Git     : https://git-scm.com

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "+======================================+" -ForegroundColor Cyan
Write-Host "|       LibraTrack - Setup             |" -ForegroundColor Cyan
Write-Host "+======================================+" -ForegroundColor Cyan
Write-Host ""

# -- Refresh PATH from registry (picks up newly installed tools) --------------------
function Update-SessionPath {
    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("PATH", "User")
    # Also inject MSYS2 MinGW64 bin if it exists but is not in PATH
    foreach ($msysGcc in @("C:\msys64\mingw64\bin", "$env:SystemDrive\msys64\mingw64\bin")) {
        if ((Test-Path $msysGcc) -and ($env:PATH -notlike "*$msysGcc*")) {
            $env:PATH = "$msysGcc;$env:PATH"
        }
    }
}

# -- Helper: install a package via winget -------------------------------------------
function Install-WingetPackage {
    param([string]$Name, [string]$WingetId, [string]$Command = "")
    if (!$Command) { $Command = $Name }

    Write-Host "  Installing $Name via winget..." -ForegroundColor Yellow
    # winget returns non-zero for "already installed / no upgrade" - that is fine
    winget install --id $WingetId --silent --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null

    # Refresh PATH so newly installed tools are visible
    Update-SessionPath

    # Also probe common install locations for tools that don't update PATH immediately
    $extraPaths = @(
        "$env:ProgramFiles\CMake\bin",
        "$env:ProgramFiles\Git\cmd",
        "$env:ProgramFiles\Git\bin",
        "$env:ProgramFiles\LLVM\bin",
        "$env:ProgramFiles(x86)\CMake\bin"
    )
    foreach ($p in $extraPaths) {
        if ((Test-Path $p) -and ($env:PATH -notlike "*$p*")) {
            $env:PATH = "$p;$env:PATH"
        }
    }

    if (!(Get-Command $Command -ErrorAction SilentlyContinue)) {
        Write-Host "  [X] $Name was not found after install attempt." -ForegroundColor Red
        Write-Host "      Please install it manually and re-run setup.ps1" -ForegroundColor Red
        exit 1
    }
    Write-Host "  [OK] $Name ready." -ForegroundColor Green
}

# -- Dependency checks (auto-install if missing) ------------------------------------
if (!(Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Host "  [!] winget not found - cannot auto-install dependencies." -ForegroundColor Yellow
    Write-Host "      Please install CMake and Git manually, then re-run setup.ps1" -ForegroundColor Yellow
    Write-Host "      CMake : https://cmake.org/download/" -ForegroundColor White
    Write-Host "      Git   : https://git-scm.com" -ForegroundColor White
    exit 1
}

# Refresh PATH first in case tools are installed but not yet in current session PATH
Update-SessionPath

foreach ($entry in @(
    @{ Tool = "cmake"; WingetId = "Kitware.CMake" },
    @{ Tool = "git";   WingetId = "Git.Git"       }
)) {
    if (!(Get-Command $entry.Tool -ErrorAction SilentlyContinue)) {
        Write-Host "  [!] Not found in PATH: $($entry.Tool)" -ForegroundColor Yellow
        Install-WingetPackage -Name $entry.Tool -WingetId $entry.WingetId -Command $entry.Tool
    } else {
        $path = (Get-Command $entry.Tool).Source
        Write-Host "  [OK] Found: $($entry.Tool)  ($path)" -ForegroundColor Green
    }
}
Write-Host ""

# -- Check GCC version supports C++17 (requires >= 7) -------------------------------
function Test-GCCVersion {
    if (!(Get-Command g++ -ErrorAction SilentlyContinue)) { return $false }
    $verLine = g++ --version 2>&1 | Select-Object -First 1
    if ($verLine -match '(\d+)\.\d+\.\d+') { return ([int]$Matches[1] -ge 7) }
    return $false
}

# -- Check any C++17 capable compiler is present ------------------------------------
function Test-CppCompiler {
    if (Get-Command cl -ErrorAction SilentlyContinue) { return $true }
    if (Test-GCCVersion)                              { return $true }
    return $false
}

# -- Install VS Build Tools (MSVC - most reliable on Windows) -----------------------
function Install-VSBuildTools {
    Write-Host "  Installing Visual Studio Build Tools (C++ workload)..." -ForegroundColor Yellow
    Write-Host "  This may take several minutes..." -ForegroundColor Yellow
    $prev = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    winget install --id Microsoft.VisualStudio.2022.BuildTools --silent `
        --accept-package-agreements --accept-source-agreements `
        --override "--quiet --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended --norestart" 2>&1 | Out-Null
    $ErrorActionPreference = $prev
    Update-SessionPath

    # VS Build Tools installs vcvarsall.bat - find and run it to activate MSVC env
    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (Test-Path $vswhere) {
        $vsPath = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath 2>&1
        if ($vsPath) {
            $vcvars = "$vsPath\VC\Auxiliary\Build\vcvars64.bat"
            if (Test-Path $vcvars) {
                # Import MSVC environment variables into current session
                $envDump = cmd /c "`"$vcvars`" && set"
                foreach ($line in $envDump) {
                    if ($line -match '^([^=]+)=(.*)$') {
                        [System.Environment]::SetEnvironmentVariable($Matches[1], $Matches[2], "Process")
                    }
                }
            }
        }
    }

    if (!(Get-Command cl -ErrorAction SilentlyContinue)) {
        Write-Host "  [!] VS Build Tools installed but cl.exe not in PATH yet." -ForegroundColor Yellow
        Write-Host "      A restart or new terminal may be needed." -ForegroundColor Yellow
        return $false
    }
    Write-Host "  [OK] VS Build Tools (MSVC) ready." -ForegroundColor Green
    return $true
}

# -- Install modern GCC via MSYS2 (fallback) ----------------------------------------
function Install-ModernGCC {
    Write-Host "  Installing MSYS2 to get a modern MinGW GCC..." -ForegroundColor Yellow
    winget install --id MSYS2.MSYS2 --silent --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null
    Update-SessionPath

    # Locate bash - MSYS2 defaults to C:\msys64
    $msys2Bash = @("C:\msys64\usr\bin\bash.exe",
                   "$env:SystemDrive\msys64\usr\bin\bash.exe") |
                 Where-Object { Test-Path $_ } | Select-Object -First 1
    if (!$msys2Bash) {
        Write-Host "  [X] MSYS2 install failed or installed to an unexpected path." -ForegroundColor Red
        Write-Host "      Install manually from https://www.msys2.org/ then re-run setup.ps1" -ForegroundColor Red
        exit 1
    }

    Write-Host "  Updating MinGW GCC via pacman (may take a minute)..." -ForegroundColor Yellow
    $prev = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    & $msys2Bash -lc "pacman -Sy --noconfirm mingw-w64-x86_64-gcc mingw-w64-x86_64-make" 2>&1 | Out-Null
    $ErrorActionPreference = $prev

    $mingw64bin = "C:\msys64\mingw64\bin"
    if (!(Test-Path $mingw64bin)) { $mingw64bin = "$env:SystemDrive\msys64\mingw64\bin" }
    if (Test-Path $mingw64bin) {
        $env:PATH = "$mingw64bin;$env:PATH"
        Write-Host "  [OK] Modern GCC installed via MSYS2." -ForegroundColor Green
    } else {
        Write-Host "  [X] Could not locate MSYS2 MinGW64 binaries after install." -ForegroundColor Red
        exit 1
    }
}

# -- Ensure a C++17 compiler is available (auto-install if not) ---------------------
if (!(Test-CppCompiler)) {
    $gppOld = (Get-Command g++ -ErrorAction SilentlyContinue) -and !(Test-GCCVersion)
    if ($gppOld) {
        Write-Host "  [!] MinGW GCC is too old for C++17 - installing VS Build Tools..." -ForegroundColor Yellow
    } else {
        Write-Host "  [!] No C++17 compiler found - installing VS Build Tools..." -ForegroundColor Yellow
    }
    $vsOk = Install-VSBuildTools
    if (!$vsOk) {
        Write-Host "  [!] Falling back to MSYS2/MinGW GCC..." -ForegroundColor Yellow
        Install-ModernGCC
    }
    if (!(Test-CppCompiler)) {
        Write-Host "  [X] Could not set up a C++17 compiler automatically." -ForegroundColor Red
        Write-Host "      Please install one manually and re-run setup.ps1:" -ForegroundColor Yellow
        Write-Host "        VS Build Tools: https://visualstudio.microsoft.com/downloads/" -ForegroundColor White
        Write-Host "        MSYS2/MinGW   : https://www.msys2.org/" -ForegroundColor White
        exit 1
    }
    Write-Host "  [OK] C++17 compiler ready." -ForegroundColor Green
}
Write-Host ""

# -- Detect best available CMake generator ------------------------------------------
# Returns a hashtable: @{ Generator = "..."; CC = "..."; CXX = "..." }
function Get-CMakeBuildInfo {
    # MSVC cl.exe (VS Developer prompt or vcvarsall already run) - check first,
    # it has its own linker and doesn't need special handling
    if (Get-Command cl -ErrorAction SilentlyContinue) {
        return @{ Generator = "NMake Makefiles"; CC = ""; CXX = "" }
    }
    # Visual Studio installations
    foreach ($vsGen in @(
        "Visual Studio 17 2022",
        "Visual Studio 16 2019",
        "Visual Studio 15 2017"
    )) {
        cmake -G $vsGen --version 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) { return @{ Generator = $vsGen; CC = ""; CXX = "" } }
    }
    # MinGW GCC (MSYS2) - must explicitly point to g++/gcc to avoid clang++ being picked up
    $gccExe = Get-Command g++ -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
    $ccExe  = Get-Command gcc -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
    if ($gccExe -and (Test-GCCVersion)) {
        # Prefer Ninja if available (faster), otherwise mingw32-make
        if (Get-Command mingw32-make -ErrorAction SilentlyContinue) {
            return @{ Generator = "MinGW Makefiles"; CC = $ccExe; CXX = $gccExe }
        }
        if (Get-Command ninja -ErrorAction SilentlyContinue) {
            return @{ Generator = "Ninja"; CC = $ccExe; CXX = $gccExe }
        }
        return @{ Generator = "MinGW Makefiles"; CC = $ccExe; CXX = $gccExe }
    }
    return $null
}

$buildInfo = Get-CMakeBuildInfo
if ($buildInfo) {
    $generator = $buildInfo.Generator
    Write-Host "  [OK] Using CMake generator: $generator" -ForegroundColor Green
    if ($buildInfo.CXX) {
        Write-Host "  [OK] Using compiler: $($buildInfo.CXX)" -ForegroundColor Green
    }
} else {
    Write-Host ""
    Write-Host "  [X] Could not find a working C++17 build toolchain." -ForegroundColor Red
    Write-Host "      Try re-running setup.ps1, or install manually:" -ForegroundColor Yellow
    Write-Host "        VS Build Tools: https://visualstudio.microsoft.com/downloads/" -ForegroundColor White
    Write-Host ""
    exit 1
}
Write-Host ""

# -- CMake configure -----------------------------------------------------------------
# If build dir exists with a different generator or compiler, wipe it
if (Test-Path "build\CMakeCache.txt") {
    $cachedGen = (Select-String -Path "build\CMakeCache.txt" -Pattern "^CMAKE_GENERATOR:").Line
    $cachedCXX = (Select-String -Path "build\CMakeCache.txt" -Pattern "^CMAKE_CXX_COMPILER:").Line
    $generatorChanged = $cachedGen -and ($cachedGen -notlike "*$generator*")
    $compilerChanged  = $buildInfo.CXX -and $cachedCXX -and ($cachedCXX -notlike "*$($buildInfo.CXX.Replace('\','/'))*")
    if ($generatorChanged -or $compilerChanged) {
        Write-Host "  [!] Build config changed - clearing stale build cache..." -ForegroundColor Yellow
        Remove-Item -Recurse -Force "build"
    }
}

Write-Host "[1/2] Configuring build..." -ForegroundColor White
$cmakeArgs = @("-S", ".", "-B", "build", "-DCMAKE_BUILD_TYPE=Debug", "-G", $generator)
if ($buildInfo.CXX) { $cmakeArgs += "-DCMAKE_CXX_COMPILER=$($buildInfo.CXX)" }
if ($buildInfo.CC)  { $cmakeArgs += "-DCMAKE_C_COMPILER=$($buildInfo.CC)" }
cmake @cmakeArgs
if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "  [X] CMake configure failed." -ForegroundColor Red
    Write-Host "      Make sure a C++17 compiler is installed:" -ForegroundColor Yellow
    Write-Host "        VS Build Tools : https://visualstudio.microsoft.com/downloads/" -ForegroundColor White
    Write-Host "        MinGW-w64      : https://www.msys2.org/" -ForegroundColor White
    exit 1
}
Write-Host ""

# -- Build ---------------------------------------------------------------------------
Write-Host "[2/2] Building..." -ForegroundColor White
cmake --build build --config Debug
if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "  [X] Build failed." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "  [OK] Setup complete!" -ForegroundColor Green
Write-Host ""
Write-Host "  Run the test for a specific issue:" -ForegroundColor White
Write-Host "    .\check.ps1 [issue-number]" -ForegroundColor Cyan
Write-Host "  Examples:" -ForegroundColor White
Write-Host "    .\check.ps1 1    - tests your fix for Issue #01" -ForegroundColor Cyan
Write-Host "    .\check.ps1 42   - tests your fix for Issue #42" -ForegroundColor Cyan
Write-Host ""
