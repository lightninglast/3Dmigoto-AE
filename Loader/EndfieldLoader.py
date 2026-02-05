#!/usr/bin/env python3
"""
Endfield 3DMigoto Loader
Injects 3DMigoto d3d11.dll directly into Endfield.exe process,
bypassing the anti-cheat in PlatformProcess.exe (launcher).

Usage:
1. Run this script as Administrator
2. Launch the game through normal launcher
3. Script will detect Endfield.exe and inject 3DMigoto

Requirements:
    pip install psutil pyinjector
"""

import os
import sys
import time
import ctypes
from ctypes import wintypes

try:
    import psutil
except ImportError:
    print("ERROR: psutil not installed. Run: pip install psutil")
    sys.exit(1)

try:
    import pyinjector
except ImportError:
    print("ERROR: pyinjector not installed. Run: pip install pyinjector")
    sys.exit(1)


# Windows API constants
THREAD_SUSPEND_RESUME = 0x0002
PROCESS_ALL_ACCESS = 0x1F0FFF

# Configuration
TARGET_PROCESS = "Endfield.exe"
DLL_NAME = "d3d11.dll"
POLL_INTERVAL = 0.05  # seconds between checks (very fast polling)
INJECTION_DELAY = 0.3  # Very short delay - try to beat anti-cheat
SUSPEND_BEFORE_INJECT = False  # Disabled - causes freeze


# Windows API functions
kernel32 = ctypes.windll.kernel32

def suspend_process(pid):
    """Suspend all threads in a process."""
    try:
        process = psutil.Process(pid)
        for thread in process.threads():
            handle = kernel32.OpenThread(THREAD_SUSPEND_RESUME, False, thread.id)
            if handle:
                kernel32.SuspendThread(handle)
                kernel32.CloseHandle(handle)
        return True
    except Exception as e:
        print(f"Warning: Could not suspend process: {e}")
        return False


def resume_process(pid):
    """Resume all threads in a process."""
    try:
        process = psutil.Process(pid)
        for thread in process.threads():
            handle = kernel32.OpenThread(THREAD_SUSPEND_RESUME, False, thread.id)
            if handle:
                kernel32.ResumeThread(handle)
                kernel32.CloseHandle(handle)
        return True
    except Exception as e:
        print(f"Warning: Could not resume process: {e}")
        return False


def is_admin():
    """Check if running with administrator privileges."""
    try:
        return ctypes.windll.shell32.IsUserAnAdmin()
    except:
        return False


def get_script_directory():
    """Get the directory where this script is located."""
    if getattr(sys, 'frozen', False):
        # Running as compiled executable
        return os.path.dirname(sys.executable)
    else:
        # Running as script
        return os.path.dirname(os.path.abspath(__file__))


def find_process(name):
    """Find a process by name and return its PID, or None if not found."""
    for proc in psutil.process_iter(['pid', 'name']):
        try:
            if proc.info['name'].lower() == name.lower():
                return proc.info['pid']
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            continue
    return None


def wait_for_process(name, timeout=None):
    """
    Wait for a process to start.
    Returns the PID when found, or None if timeout reached.
    """
    print(f"Waiting for {name} to start...")
    start_time = time.time()
    
    while True:
        pid = find_process(name)
        if pid is not None:
            return pid
        
        if timeout and (time.time() - start_time) > timeout:
            return None
        
        time.sleep(POLL_INTERVAL)


def inject_dll(pid, dll_path):
    """Inject a DLL into the target process."""
    try:
        pyinjector.inject(pid, dll_path)
        return True
    except Exception as e:
        print(f"ERROR: Failed to inject: {e}")
        return False


def main():
    print("=" * 60)
    print("Endfield 3DMigoto Loader")
    print("=" * 60)
    print()
    
    # Check admin privileges
    if not is_admin():
        print("WARNING: Not running as administrator!")
        print("Injection may fail. Please run as Administrator.")
        print()
    
    # Determine DLL path - check multiple locations
    script_dir = get_script_directory()
    parent_dir = os.path.dirname(script_dir)
    
    # Search order for DLL
    dll_search_paths = [
        os.path.join(script_dir, DLL_NAME),                              # Same folder as loader/exe
        os.path.join(parent_dir, DLL_NAME),                              # Parent folder
        os.path.join(script_dir, "builds", "x64", "Release", DLL_NAME),  # Build output (when exe is in repo root)
        os.path.join(parent_dir, "builds", "x64", "Release", DLL_NAME),  # Build output (when exe is in Loader/)
    ]
    
    dll_path = None
    for path in dll_search_paths:
        if os.path.exists(path):
            dll_path = path
            break
    
    if dll_path is None:
        print(f"ERROR: Could not find {DLL_NAME}")
        print("Searched locations:")
        for path in dll_search_paths:
            print(f"  - {path}")
        input("Press Enter to exit...")
        return 1
    
    print(f"DLL Path: {dll_path}")
    print(f"Target:   {TARGET_PROCESS}")
    print()
    
    # Check if target is already running
    existing_pid = find_process(TARGET_PROCESS)
    if existing_pid:
        print(f"Found existing {TARGET_PROCESS} (PID: {existing_pid})")
        response = input("Inject into existing process? (y/n): ").strip().lower()
        if response == 'y':
            pid = existing_pid
        else:
            print("Please close the game and restart it after starting this loader.")
            input("Press Enter to exit...")
            return 0
    else:
        print("Please start the game through the normal launcher.")
        print("This loader will inject once Endfield.exe starts.")
        print()
        
        # Wait for process
        pid = wait_for_process(TARGET_PROCESS)
        if pid is None:
            print("Timed out waiting for process.")
            return 1
    
    print(f"Found {TARGET_PROCESS} (PID: {pid})")
    
    # Suspend the process before anti-cheat initializes
    if SUSPEND_BEFORE_INJECT:
        print("Suspending process to beat anti-cheat initialization...")
        suspend_process(pid)
        time.sleep(0.1)  # Brief pause
    
    # Wait a moment for the process to initialize (if configured)
    if INJECTION_DELAY > 0:
        print(f"Waiting {INJECTION_DELAY}s for process to initialize...")
        time.sleep(INJECTION_DELAY)
    
    # Check if process is still running
    if not find_process(TARGET_PROCESS):
        print("ERROR: Process terminated before injection could complete.")
        input("Press Enter to exit...")
        return 1
    
    # Perform injection
    print(f"Injecting {DLL_NAME}...")
    success = inject_dll(pid, dll_path)
    
    # Resume the process after injection
    if SUSPEND_BEFORE_INJECT:
        print("Resuming process...")
        resume_process(pid)
    
    if success:
        print()
        print("=" * 60)
        print("SUCCESS! 3DMigoto injected into Endfield.exe")
        print("=" * 60)
        print()
        print("Check d3d11_log.txt in the game directory for confirmation.")
        print("You should see 'Game path: ...Endfield.exe' in the log.")
    else:
        print()
        print("FAILED: Injection was not successful.")
        print("The anti-cheat may still be blocking injection.")
    
    print()
    input("Press Enter to exit...")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print("\nAborted by user.")
        sys.exit(0)
    except Exception as e:
        print(f"Unexpected error: {e}")
        import traceback
        traceback.print_exc()
        input("Press Enter to exit...")
        sys.exit(1)
