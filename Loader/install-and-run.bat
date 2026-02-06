@echo off
:: Endfield 3DMigoto Loader (Python Edition)
:: First run: creates venv and installs dependencies
:: Subsequent runs: just launches the loader
::
:: Requires Python 3.10+ installed and on PATH
:: https://www.python.org/downloads/

:: Request admin privileges (required for DLL injection)
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Requesting administrator privileges...
    powershell -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

:: Change to script directory
cd /d "%~dp0"

:: ---- Check for Python ----
where python >nul 2>&1
if %errorLevel% neq 0 (
    echo.
    echo ============================================================
    echo  ERROR: Python is not installed or not on PATH
    echo ============================================================
    echo.
    echo  This edition requires Python 3.10 or newer.
    echo  Download it from: https://www.python.org/downloads/
    echo.
    echo  IMPORTANT: During install, check "Add Python to PATH"
    echo.
    echo  If you don't want to install Python, download the
    echo  EXE edition instead from the GitHub releases page.
    echo.
    pause
    exit /b 1
)

:: ---- Check Python version ----
for /f "tokens=2 delims= " %%v in ('python --version 2^>^&1') do set PYVER=%%v
for /f "tokens=1,2 delims=." %%a in ("%PYVER%") do (
    set PYMAJOR=%%a
    set PYMINOR=%%b
)
if %PYMAJOR% LSS 3 (
    echo ERROR: Python 3.10+ required, found Python %PYVER%
    pause
    exit /b 1
)
if %PYMAJOR% EQU 3 if %PYMINOR% LSS 10 (
    echo ERROR: Python 3.10+ required, found Python %PYVER%
    pause
    exit /b 1
)

:: ---- Create venv if it doesn't exist ----
if not exist ".venv\Scripts\python.exe" (
    echo.
    echo First-time setup: Creating Python virtual environment...
    echo This only happens once.
    echo.
    python -m venv .venv
    if %errorLevel% neq 0 (
        echo ERROR: Failed to create virtual environment.
        pause
        exit /b 1
    )

    echo Installing dependencies...
    ".venv\Scripts\pip.exe" install -r requirements.txt --quiet
    if %errorLevel% neq 0 (
        echo ERROR: Failed to install dependencies.
        echo Try deleting the .venv folder and running again.
        pause
        exit /b 1
    )
    echo Setup complete!
    echo.
)

:: ---- Run the loader ----
echo Starting Endfield 3DMigoto Loader...
echo.
".venv\Scripts\python.exe" EndfieldLoader.py

:: Keep window open if there's an error
if %errorLevel% neq 0 (
    echo.
    echo An error occurred. Press any key to exit...
    pause >nul
)
