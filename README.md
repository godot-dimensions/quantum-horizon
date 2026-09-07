# Quantum Horizon

Quantum Horizon Godot project, engine submodule, and Godot 4D submodule.

## Installation and usage

### Prerequisites

- Git: https://git-scm.com/install/
- Git LFS: https://git-lfs.com/
- A clone of this repository.
- All submodules updated: Run `git submodule update --init --recursive` in a terminal in the root of the repository.
- Godot compile dependencies for your platform:
  - All platforms:
    - Python: https://www.python.org/downloads/
    - SCons: `pip install scons`
  - Windows:
    - Visual Studio 2022 (recommended) or 2026: https://visualstudio.microsoft.com/vs/community/
    - Visual Studio "Desktop development with C++" and "Game development with C++" workloads.
    - Visual Studio optional components for MSVC and Windows 11 SDK.
    - Follow the Godot docs: https://docs.godotengine.org/en/stable/engine_details/development/compiling/compiling_for_windows.html
  - macOS:
    - Xcode: https://apps.apple.com/us/app/xcode/id497799835
    - Vulkan SDK: https://sdk.lunarg.com/sdk/download/latest/mac/vulkan-sdk.dmg
    - Homebrew: https://brew.sh/
    - Follow the Godot docs: https://docs.godotengine.org/en/stable/engine_details/development/compiling/compiling_for_macos.html
  - Linux:
    - GCC, Clang, build-essential, pkg-config, x11, xcursor, xinerama, xi, xrandr, wayland-scanner, mesa, alsa, pulseaudio, libudev.
    - Run one of the "distro one-liners" in the Godot docs to get all of these at once through your package manager.
    - Follow the Godot docs: https://docs.godotengine.org/en/stable/engine_details/development/compiling/compiling_for_linuxbsd.html

### Compile and run

Once you have all the prerequisites installed:

- On Windows: Double-click `run_editor_windows.bat` in the root of the repository (or run it in a terminal).
- On macOS: Double-click `run_editor_macos.command` in the root of the repository (or run it in a terminal).
- On Linux: Double-click `run_editor_linux.sh` in the root of the repository (or run it in a terminal).

This will update all submodules, build the engine, and run the editor. Subsequent runs will skip recompilation if it detects that nothing has changed.

To skip generating IDE files, pass `-SkipIdeSetup` on Windows or `--skip-ide-setup` on macOS and Linux.

To regenerate the engine and module documentation after building, pass `-Doctool` on Windows or `--doctool` on macOS and Linux.

To run the engine test suite instead of opening the project, pass `-Test` on Windows or `--test` on macOS and Linux.

To normalize every `.tscn` file using Godot's editor save behavior, run `.\engine\scripts\resave_scenes_windows.ps1 -ProjectPath .\project\project.godot` on Windows or `./engine/scripts/resave_scenes_unix.sh --project-path ./project/project.godot` on macOS and Linux. Pass `-Dev` or `--dev` to use the development editor build.

### Develop with Visual Studio Code

The `setup_vscode_windows.ps1` and `setup_vscode_unix.sh` scripts will set up files for Visual Studio Code (VS Code).

These are automatically invoked when running the `run_editor` scripts. After compiling and running once, you can open the repository root in VS Code and it should have intellisense for the C++ code in the engine and modules.

### Develop with Visual Studio (Windows)

The `setup_visual_studio_windows.ps1` script will set up files for Visual Studio.

It should work the same as the VS Code setup script, being automatically invoked when running the `run_editor_windows.bat` script. After compiling and running once, you can open the generated `.sln` file in Visual Studio and it should have intellisense for the C++ code in the engine and modules.
