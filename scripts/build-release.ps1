# Build Release Script for 3DMigoto-Endfield
# Creates four distribution packages:
#   1. Player EXE  - EndfieldLoader.exe, hunting=0
#   2. Dev EXE     - EndfieldLoader.exe, hunting=1
#   3. Python ZIP  - Player + Dev as subdirectories with .py scripts (single ZIP)

param(
    [switch]$SkipBuild,      # Skip DLL/EXE build, just package
    [switch]$ExeOnly,        # Only build EXE packages
    [switch]$PythonOnly      # Only build Python package
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
$DistRoot = Join-Path $RepoRoot "dist"
$DevEnv = Join-Path $RepoRoot "DevEnv"
$BuildOutput = Join-Path $RepoRoot "builds\x64\Release"
$ConfigDir = Join-Path $RepoRoot "Config"
$LoaderDir = Join-Path $RepoRoot "Loader"

# Version - update this for each release
$Version = "1.0.0"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "3DMigoto-Endfield Release Builder v$Version" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# ============================================================
# Step 1: Build DLL
# ============================================================
if (-not $SkipBuild) {
    Write-Host "`n[1/5] Building 3DMigoto DLL..." -ForegroundColor Yellow
    
    $MSBuild = "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\MSBuild.exe"
    if (-not (Test-Path $MSBuild)) {
        Write-Error "MSBuild not found at: $MSBuild"
        exit 1
    }
    
    Push-Location $RepoRoot
    & $MSBuild StereovisionHacks.sln /p:Configuration=Release /p:Platform=x64 /t:DirectX11 /m /v:minimal
    if ($LASTEXITCODE -ne 0) {
        Write-Error "DLL build failed!"
        exit 1
    }
    Pop-Location
    
    Write-Host "DLL build complete!" -ForegroundColor Green
    
    # Step 2: Build Loader EXE (only if we need EXE packages)
    if (-not $PythonOnly) {
        Write-Host "`n[2/5] Building EndfieldLoader.exe..." -ForegroundColor Yellow
        
        Push-Location $LoaderDir
        & "$RepoRoot\.venv\Scripts\python.exe" -m PyInstaller --onefile --clean --distpath "$BuildOutput" EndfieldLoader.py 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Loader build failed!"
            exit 1
        }
        Pop-Location
        
        Write-Host "Loader build complete!" -ForegroundColor Green
    } else {
        Write-Host "`n[2/5] Skipping EXE build (Python-only mode)" -ForegroundColor Gray
    }
} else {
    Write-Host "`n[1-2/5] Skipping build (using existing binaries)" -ForegroundColor Gray
}

# ============================================================
# Step 3: Create distribution folders
# ============================================================
Write-Host "`n[3/5] Creating distribution packages..." -ForegroundColor Yellow

# Clean and create dist folder
if (Test-Path $DistRoot) {
    Remove-Item -Recurse -Force $DistRoot
}
New-Item -ItemType Directory -Path $DistRoot | Out-Null

# --- Helper: populate a package directory with shared files ---
function New-PackageBase {
    param(
        [string]$PackageDir,
        [string]$Edition       # "Player" or "Dev"
    )

    New-Item -ItemType Directory -Path $PackageDir -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $PackageDir "Mods") | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $PackageDir "ShaderFixes") | Out-Null

    # Core DLLs
    Copy-Item (Join-Path $BuildOutput "d3d11.dll") $PackageDir
    Copy-Item (Join-Path $BuildOutput "d3dcompiler_47.dll") $PackageDir

    # Config
    if ($Edition -eq "Player") {
        Copy-Item (Join-Path $ConfigDir "d3dx-playing.ini") (Join-Path $PackageDir "d3dx.ini")
    } else {
        Copy-Item (Join-Path $ConfigDir "d3dx-development.ini") (Join-Path $PackageDir "d3dx.ini")
    }

    # .gitkeep files
    "" | Out-File -FilePath (Join-Path $PackageDir "Mods\.gitkeep") -Encoding UTF8
    "" | Out-File -FilePath (Join-Path $PackageDir "ShaderFixes\.gitkeep") -Encoding UTF8
}

# --- Helper: generate a README ---
function New-Readme {
    param(
        [string]$PackageDir,
        [string]$Edition,       # "Player" or "Dev"
        [string]$Variant        # "EXE" or "Python"
    )

    if ($Variant -eq "EXE") {
        $InstallSteps = @"
INSTALLATION:
1. Extract this folder anywhere (e.g., Desktop)
2. Run EndfieldLoader.exe as Administrator
3. Launch the game through the normal launcher
4. The loader will detect the game and inject 3DMigoto
"@
    } else {
        $InstallSteps = @"
REQUIREMENTS:
- Python 3.10 or newer  (https://www.python.org/downloads/)
  IMPORTANT: Check "Add Python to PATH" during install

INSTALLATION:
1. Extract this folder anywhere (e.g., Desktop)
2. Double-click install-and-run.bat
   - First run creates a virtual environment and installs dependencies
   - Subsequent runs start instantly
3. Launch the game through the normal launcher
4. The loader will detect the game and inject 3DMigoto
"@
    }

    if ($Edition -eq "Dev") {
        $ModeInfo = @"
DEV MODE FEATURES:
- Hunting enabled (use Numpad keys to find hashes)
  - Numpad 0: Toggle overlay / Cycle marking mode
  - Numpad 1/2: Cycle PS, 3: Copy hash
  - Numpad 4/5: Cycle VS, 6: Copy hash
  - Numpad 7/8: Cycle IB, 9: Copy hash
- Logging enabled (check d3d11_log.txt)
"@
    } else {
        $ModeInfo = @"
PLAYER MODE:
- Optimized for performance
- Hunting/logging disabled
- Just play with your mods!
"@
    }

    $ReadmeContent = @"
3DMigoto for Arknights Endfield - $Edition Edition ($Variant)
===================================================
Version: $Version
Build Date: $(Get-Date -Format "yyyy-MM-dd")

$InstallSteps

ADDING MODS:
- Place mod folders in the 'Mods' directory
- Each mod should have its own folder with .ini files

$ModeInfo

GitHub: https://github.com/lightninglast/3Dmigoto-AE
"@
    $ReadmeContent | Out-File -FilePath (Join-Path $PackageDir "README.txt") -Encoding UTF8
}

# ============================================================
# Step 4: Build EXE packages (Player EXE + Dev EXE)
# ============================================================
if (-not $PythonOnly) {
    Write-Host "`n[4/5] Creating EXE packages..." -ForegroundColor Yellow

    foreach ($Edition in @("Player", "Dev")) {
        Write-Host "  Creating $Edition EXE package..." -ForegroundColor Gray

        $PackageDir = Join-Path $DistRoot "Endfield-Mods-$Edition-EXE"
        New-PackageBase -PackageDir $PackageDir -Edition $Edition

        # Copy loader EXE
        Copy-Item (Join-Path $BuildOutput "EndfieldLoader.exe") $PackageDir

        # README
        New-Readme -PackageDir $PackageDir -Edition $Edition -Variant "EXE"
    }
} else {
    Write-Host "`n[4/5] Skipping EXE packages (Python-only mode)" -ForegroundColor Gray
}

# ============================================================
# Step 5: Build Python package (Player + Dev in one ZIP)
# ============================================================
if (-not $ExeOnly) {
    Write-Host "`n[5/5] Creating Python package..." -ForegroundColor Yellow

    $PythonRoot = Join-Path $DistRoot "Endfield-Mods-Python"
    New-Item -ItemType Directory -Path $PythonRoot | Out-Null

    foreach ($Edition in @("Player", "Dev")) {
        Write-Host "  Creating $Edition Python subdirectory..." -ForegroundColor Gray

        $PackageDir = Join-Path $PythonRoot $Edition
        New-PackageBase -PackageDir $PackageDir -Edition $Edition

        # Copy Python loader files
        Copy-Item (Join-Path $LoaderDir "EndfieldLoader.py") $PackageDir
        Copy-Item (Join-Path $LoaderDir "requirements.txt") $PackageDir
        Copy-Item (Join-Path $LoaderDir "install-and-run.bat") $PackageDir

        # README
        New-Readme -PackageDir $PackageDir -Edition $Edition -Variant "Python"
    }

    # Top-level README for the Python ZIP
    $PythonTopReadme = @"
3DMigoto for Arknights Endfield - Python Edition
=================================================
Version: $Version
Build Date: $(Get-Date -Format "yyyy-MM-dd")

This archive contains two editions:

  Player/  - Hunting & logging OFF. Best for normal play.
  Dev/     - Hunting & logging ON.  For finding hashes.

Pick the one you need, or keep both and switch as needed.

REQUIREMENTS:
  Python 3.10+  (https://www.python.org/downloads/)
  Check "Add Python to PATH" during install.

QUICK START:
  1. Open the Player or Dev folder
  2. Double-click install-and-run.bat
  3. Launch the game

GitHub: https://github.com/lightninglast/3Dmigoto-AE
"@
    $PythonTopReadme | Out-File -FilePath (Join-Path $PythonRoot "README.txt") -Encoding UTF8
} else {
    Write-Host "`n[5/5] Skipping Python package (EXE-only mode)" -ForegroundColor Gray
}

# ============================================================
# Create ZIP files
# ============================================================
Write-Host "`nCreating ZIP archives..." -ForegroundColor Yellow

# EXE zips (one per edition)
if (-not $PythonOnly) {
    foreach ($Edition in @("Player", "Dev")) {
        $PackageDir = Join-Path $DistRoot "Endfield-Mods-$Edition-EXE"
        $ZipPath = Join-Path $DistRoot "Endfield-Mods-$Edition-EXE-v$Version.zip"
        Compress-Archive -Path "$PackageDir\*" -DestinationPath $ZipPath -Force
        Write-Host "  Created: $ZipPath" -ForegroundColor Gray
        Remove-Item -Recurse -Force $PackageDir
    }
}

# Python zip (single archive with both editions)
if (-not $ExeOnly) {
    $PythonRoot = Join-Path $DistRoot "Endfield-Mods-Python"
    $ZipPath = Join-Path $DistRoot "Endfield-Mods-Python-v$Version.zip"
    Compress-Archive -Path "$PythonRoot\*" -DestinationPath $ZipPath -Force
    Write-Host "  Created: $ZipPath" -ForegroundColor Gray
    Remove-Item -Recurse -Force $PythonRoot
}

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "Build Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "Output directory: $DistRoot"
Write-Host ""
Get-ChildItem $DistRoot -Filter "*.zip" | ForEach-Object {
    Write-Host "  $($_.Name) - $([math]::Round($_.Length / 1MB, 2)) MB" -ForegroundColor Cyan
}
