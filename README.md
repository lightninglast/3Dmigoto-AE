# 3DMigoto for Arknights Endfield

A mod loader for Arknights Endfield, enabling character skin mods, visual tweaks, and other customizations.

This is a fork of [bo3b/3Dmigoto](https://github.com/bo3b/3Dmigoto) with modifications specific to Arknights Endfield.

## Features

- **Index Buffer TextureOverride Support** - Enables `handling=skip` and other commands to work with 8-character IB hashes
- **Injection Loader** - Injects 3DMigoto directly into the game process
- **Player & Dev Editions** - Pre-configured packages for regular players (optimized) and mod developers (hunting enabled)

## Quick Start (Players)

1. Download the **Player** release from [Releases](https://github.com/lightninglast/3Dmigoto-AE/releases)
2. Extract anywhere (e.g., Desktop)
3. Add mods to the `Mods` folder
4. Run `EndfieldLoader.exe`
5. Launch the game normally - the loader will inject automatically

## Quick Start (Mod Developers)

1. Download the **Dev** release from [Releases](https://github.com/lightninglast/3Dmigoto-AE/releases)
2. Extract anywhere
3. Run `EndfieldLoader.exe`
4. Launch the game normally - the loader will inject automatically
5. Use hunting keys to find hashes:
   - `Numpad 0` - Toggle hunting overlay / Cycle marking mode
   - `Numpad 1/2` - Cycle pixel shaders, `3` - Copy hash
   - `Numpad 4/5` - Cycle vertex shaders, `6` - Copy hash
   - `Numpad 7/8` - Cycle index buffers, `9` - Copy hash

## Project Structure

```
Config/           - INI presets for Player/Dev modes
Loader/           - Python injection loader source
scripts/          - Build automation
DirectX11/        - Modified 3DMigoto source
```

## Building from Source

For general build instructions, see the [upstream 3DMigoto repository](https://github.com/bo3b/3Dmigoto).

### Quick Build Steps

1. Install Visual Studio 2022 with C++ and Windows 10/11 SDK
2. Clone this repo
3. Open `StereovisionHacks.sln`
4. Build in Release x64
5. Run `.\scripts\build-release.ps1` to create distribution packages

### Build Requirements

- Visual Studio 2022 (Community or Build Tools)
- Windows 10/11 SDK (10.0.26100.0 or later)
- Python 3.10+ with `pyinjector` and `psutil` (for loader)

## Technical Changes from Upstream

### Index Buffer TextureOverride Support

The upstream 3DMigoto only processes TextureOverride command lists at draw time for shaders (16-char hashes). This fork adds support for Index Buffers (8-char hashes):

- Modified `IASetIndexBuffer()` to track IB hash when TextureOverrides exist
- Added `ProcessIndexBufferOverride()` to run command lists at draw time
- Integrated into `BeforeDraw()` pipeline

### Files Modified

- `DirectX11/HackerContext.cpp` - IB override implementation
- `DirectX11/HackerContext.h` - Added function declarations and struct members

## Credits

- [bo3b](https://github.com/bo3b) - 3DMigoto creator and maintainer
- [SilentNightSound](https://github.com/SilentNightSound) - GIMI and modding tools
- The modding community for testing and feedback

## License

This project inherits the GPL license from the original 3DMigoto project. See [LICENSE.GPL.txt](LICENSE.GPL.txt).
