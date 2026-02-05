# Build Release Script for 3DMigoto-Endfield
# Creates Player and Dev distribution packages

param(
    [switch]$SkipBuild,      # Skip DLL/EXE build, just package
    [switch]$DevOnly,        # Only build Dev package
    [switch]$PlayerOnly      # Only build Player package
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

# Step 1: Build DLL
if (-not $SkipBuild) {
    Write-Host "`n[1/4] Building 3DMigoto DLL..." -ForegroundColor Yellow
    
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
    
    # Step 2: Build Loader
    Write-Host "`n[2/4] Building EndfieldLoader.exe..." -ForegroundColor Yellow
    
    Push-Location $LoaderDir
    & "$RepoRoot\.venv\Scripts\python.exe" -m PyInstaller --onefile --clean --distpath "$BuildOutput" EndfieldLoader.py 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Loader build failed!"
        exit 1
    }
    Pop-Location
    
    Write-Host "Loader build complete!" -ForegroundColor Green
} else {
    Write-Host "`n[1-2/4] Skipping build (using existing binaries)" -ForegroundColor Gray
}

# Step 3: Create distribution folders
Write-Host "`n[3/4] Creating distribution packages..." -ForegroundColor Yellow

# Clean and create dist folder
if (Test-Path $DistRoot) {
    Remove-Item -Recurse -Force $DistRoot
}
New-Item -ItemType Directory -Path $DistRoot | Out-Null

$Packages = @()
if (-not $DevOnly) { $Packages += "Player" }
if (-not $PlayerOnly) { $Packages += "Dev" }

foreach ($Package in $Packages) {
    Write-Host "  Creating $Package package..." -ForegroundColor Gray
    
    $PackageDir = Join-Path $DistRoot "Endfield-Mods-$Package"
    New-Item -ItemType Directory -Path $PackageDir | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $PackageDir "Mods") | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $PackageDir "ShaderFixes") | Out-Null
    
    # Copy binaries
    Copy-Item (Join-Path $BuildOutput "d3d11.dll") $PackageDir
    Copy-Item (Join-Path $BuildOutput "d3dcompiler_47.dll") $PackageDir
    Copy-Item (Join-Path $BuildOutput "EndfieldLoader.exe") $PackageDir
    
    # Copy appropriate config
    if ($Package -eq "Player") {
        Copy-Item (Join-Path $ConfigDir "d3dx-playing.ini") (Join-Path $PackageDir "d3dx.ini")
    } else {
        Copy-Item (Join-Path $ConfigDir "d3dx-development.ini") (Join-Path $PackageDir "d3dx.ini")
    }
    
    # Create README
    $ReadmeContent = @"
3DMigoto for Arknights Endfield - $Package Edition
===================================================
Version: $Version
Build Date: $(Get-Date -Format "yyyy-MM-dd")

INSTALLATION:
1. Extract this folder anywhere (e.g., Desktop)
2. Run EndfieldLoader.exe
3. The game will launch automatically with mods enabled

ADDING MODS:
- Place mod folders in the 'Mods' directory
- Each mod should have its own folder with .ini files

$(if ($Package -eq "Dev") {
@"
DEV MODE FEATURES:
- Hunting enabled (Numpad 7/8/9 to cycle shaders/buffers)
- Logging enabled (check d3d11_log.txt)
- Press Numpad 0 to toggle hunting overlay
"@
} else {
@"
PLAYER MODE:
- Optimized for performance
- Hunting/logging disabled
- Just play with your mods!
"@
})

GitHub: https://github.com/lightninglast/3Dmigoto-AE
"@
    $ReadmeContent | Out-File -FilePath (Join-Path $PackageDir "README.txt") -Encoding UTF8
    
    # Create .gitkeep files
    "" | Out-File -FilePath (Join-Path $PackageDir "Mods\.gitkeep") -Encoding UTF8
    "" | Out-File -FilePath (Join-Path $PackageDir "ShaderFixes\.gitkeep") -Encoding UTF8
}

# Step 4: Create ZIP files
Write-Host "`n[4/4] Creating ZIP archives..." -ForegroundColor Yellow

foreach ($Package in $Packages) {
    $PackageDir = Join-Path $DistRoot "Endfield-Mods-$Package"
    $ZipPath = Join-Path $DistRoot "Endfield-Mods-$Package-v$Version.zip"
    
    Compress-Archive -Path "$PackageDir\*" -DestinationPath $ZipPath -Force
    Write-Host "  Created: $ZipPath" -ForegroundColor Gray
    
    # Clean up folder after zipping
    Remove-Item -Recurse -Force $PackageDir
}

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "Build Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "Output directory: $DistRoot"
Write-Host ""
Get-ChildItem $DistRoot -Filter "*.zip" | ForEach-Object {
    Write-Host "  $($_.Name) - $([math]::Round($_.Length / 1MB, 2)) MB" -ForegroundColor Cyan
}
