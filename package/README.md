# How to make a package of Quantum Horizon

First, make sure you run the editor. This is required to ensure everything in the project is imported. Depending on the OS, run one of:

- `run_editor_windows.bat`
- `run_editor_macos.command`
- `run_editor_linux.sh`

Close the editor after it has finished importing everything.

---

Then, run the package script:

- `package_windows.bat`
- `package_macos.command`
- `package_linux.sh`

This will place a `.zip` file in the `package/bin/` folder.

Debug options for the package script:

- You can add `--debug` (macOS/Linux) or `-Debug` (Windows) to create a debug build, which will enable debugging features, report better errors, and sanity check more things, but is slower. This produces a `-debug.zip` package.
- You can add `--dev` (macOS/Linux) or `-Dev` (Windows) to enable engine development checks and debug symbols, which is even slower than a regular debug build. Dev implies debug, so also specifying `--debug`/`-Debug` will have no effect. This produces a `-dev.zip` package.
- The default is a release build, which runs faster, but may crash if something goes wrong (depending on the error, dev and debug builds can also crash). This produces a `-release.zip` package.

---

Important platform-specific notes:

- If you are making a package for Windows, that's pretty much it. Ship the resulting `.zip` file. Signing and notarizing is not required on Windows.

- If you are making a package for macOS, this only uses ad-hoc signing (integrity), not proper signing and notarization (authority). Users will need to disable macOS Gatekeeper to run the package. Or, we can figure out how to notarize it later.

- If you are making a package for Linux, note that in order to properly make a portable package, you need to compile it on an old distro, such as in a VM, container, or chroot environment. If you don't do this, and just compile on the latest Ubuntu or whatever, it will likely not run on other Linux distributions. This is because it will be compiled against the newest libraries and will fail on systems without all of those library versions.

- You can select the target architecture as an argument to the package script on Windows (`-Arch arm64`) or Linux (`--arch arm64`). The default on Windows/Linux is to match the host architecture. macOS always uses universal x86_64 + arm64.
