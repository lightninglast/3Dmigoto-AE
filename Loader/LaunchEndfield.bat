@echo off
:: Endfield 3DMigoto Loader
:: This batch file runs the Python loader with administrator privileges

:: Request admin privileges
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Requesting administrator privileges...
    powershell -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

:: Change to script directory
cd /d "%~dp0"

:: Check for virtual environment in parent directory
if exist "..\\.venv\\Scripts\\python.exe" (
    echo Using virtual environment...
    "..\\.venv\\Scripts\\python.exe" "EndfieldLoader.py"
) else (
    echo Using system Python...
    python "EndfieldLoader.py"
)

:: Keep window open if there's an error
if %errorLevel% neq 0 (
    echo.
    echo An error occurred. Press any key to exit...
    pause >nul
)
