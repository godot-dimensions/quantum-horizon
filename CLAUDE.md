# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository structure

This repo bundles three things:

- `engine/godot/` — a submodule fork of Godot Engine (`godot-dimensions/godot`).
- `engine/modules/4d/` — a submodule for Godot 4D (`godot-dimensions/godot-4d`), a general-purpose C++ engine module adding `Node4D`/`Camera4D`/4D physics/4D meshes to Godot. This is open-source and shared beyond this project — general-purpose 4D engine features belong here, not in `quantum_horizon`.
- `engine/modules/quantum_horizon/` — this project's own (not submoduled) C++ engine module, for code that must be high-performance/low-level AND is specific to Quantum Horizon (not general-purpose 4D code). If unsure whether something is general-purpose, add it here first and move it to `4d` later. Prefer GDScript over adding code here when performance doesn't require C++.
- `project/` — the actual Godot game project (GDScript, scenes, assets). This is what you build the game in day to day.
- `workhorse/` — a separate, secondary Godot project (own `project.godot`) used as a 4D content/tooling workhorse (mesh/heightmap conversion scripts, etc.), independent from `project/`.

## Commands

Prerequisites (Git LFS, Python + SCons, and a C++ toolchain) must be installed first — see `README.md`.

- **Build engine + run editor on the main project**: `run_editor_windows.bat` (root of repo). Equivalent scripts exist for macOS (`run_editor_macos.command`) and Linux (`run_editor_linux.sh`), which call into `engine/scripts/run_editor_*`. This updates submodules, builds the engine, then opens the Godot editor.
  - Skip pulling submodules / regenerating IDE files on repeat runs: `-DoNotUpdate -SkipIdeSetup` (Windows) / `--do-not-update --skip-ide-setup` (macOS/Linux).
  - Development build with debug symbols (useful after an engine crash): `-Dev` / `--dev`.
  - Run the engine's C++ test suite instead of opening the editor: `-Test` / `--test`.
  - Regenerate engine/module documentation after building: `-Doctool` / `--doctool`.
- **Normalize `.tscn` files** (required any time you hand-edit or generate a `.tscn` and Godot is not currently open — Godot's editor save behavior fixes missing UIDs, unsorted properties, etc.): `.\engine\scripts\resave_scenes_windows.ps1 -ProjectPath .\project\project.godot` (Windows) or `./engine/scripts/resave_scenes_unix.sh --project-path ./project/project.godot` (macOS/Linux). Add `-Dev`/`--dev` to use a development editor build. This expects the editor to already be built.
- **Update submodules only**: `engine/scripts/update_submodules_windows.ps1` / `update_submodules_unix.sh`.

There is no separate lint/format command to run manually beyond what `pre-commit` wires up (`pre-commit run --all-files`, after `pip install pre-commit` and `pre-commit install`) — it just normalizes text file encoding/line-endings/trailing whitespace via `.github/workflows/file_format.py`.

## Editing scenes and scripts

- Files are organized **by feature, not by type**. `project/scripts/` (flat, top-level) is legacy/prototyping-era and discouraged going forward — a script specific to one scene should live next to that scene (see `project/player/player.gd` + `player.tscn`, or `project/sandbox/shooting_gallery/`).
- **Never edit `project/sandbox/shooting_gallery/shooting_gallery.tscn` directly** — it's the shared/canonical version. If changes are needed there, make them in `project/sandbox/shooting_gallery/shooting_gallery_ramon.tscn` instead (a personal duplicate used for testing). This restriction is specific to these two files only — every other scene/script in the project can be edited normally.
- Corollary: any `.gd` script that needs changes specifically to support `shooting_gallery_ramon.tscn` must be forked as `<original_name>_ramon.gd` (e.g. `gallery_target_spawner.gd` → `gallery_target_spawner_ramon.gd`), with only the ramon scene's node repointed at the fork — never edit the shared script in place, since scripts are code shared across both scenes just like `shooting_gallery.tscn` itself. Same pattern for any `.tscn` sub-scene a script instances (e.g. `gallery_target.tscn` → `gallery_target_ramon.tscn`) if it also needs to change.
- After hand-editing or generating a `.tscn`, run the resave script above (with the editor closed) to normalize it, then review the diff. If Godot removes nodes on resave, that usually means a missing `[editable path="..."]` on an instanced/inherited scene — confirm the path is correct before assuming that's the cause.
- If a human already has Godot open, don't run the editor scripts yourself — just tell them what changed. If they have uncommitted changes you're at risk of clobbering, copy their files into a gitignored `.backup/` folder rather than overwriting.
- GDScript style: tabs for indentation, LF line endings, 200 col soft limit (`.editorconfig`/`.prettierrc.json`). Prefer explicit static typing (`var x: Type = ...`, typed function signatures) and `class_name` for reusable utility scripts (e.g. `BearingUtility4D`). Non-obvious math/physics reasoning is documented inline in `##` doc comments above the relevant function/class rather than assumed — follow that convention when the "why" isn't obvious from the code itself (see `bearing_utility_4d.gd`, `hitscan_weapon.gd`).

## 4D architecture (the part that isn't derivable from a single file)

Godot 4D adds a parallel 4D scene-graph next to Godot's normal 2D/3D one: `Node4D` (transform/parenting), `CollisionObject4D`/`CollisionShape4D`/`Shape4D` (4D physics via `PhysicsServer4D`), `Camera4D` (projects 4D → 2D), `MeshInstance4D`/`Mesh4D` (tetrahedral and wireframe meshes). A 4D transform's basis is a `Projection` (Godot core type) whose `.x`/`.y`/`.z`/`.w` members are the basis columns directly — no `get_column()` needed.

Rotations compose two independent planes of meaning:
- `x`/`z` (and `y` for vertical look) behave like normal 3D yaw/pitch.
- `w` is the fourth ("ana/kata") axis. Rotating into a `w`-plane (`xw`, `zw`) is "slice rotation" — it changes what 3D cross-section of the 4D world is currently visible, not just which way you face within it.

This project's player controller (`project/player/player.gd`, documented in detail in `project/player/CONTROLLER_NOTES.md`) is the canonical example of how these compose:
- Yaw (`Basis4D.from_zx`) and slice-rotation (`Basis4D.from_xw`/`from_zw`, held while `rotate_4d` is active) are applied directly to the `CharacterBody4D` (`Player`) root's own basis.
- Pitch (`Basis4D.from_yz`) is applied only to a child `Node4D` (`PlayerHead`), as an absolute clamped set rather than an incremental multiply, so it never drifts and never affects movement/turning math.
- Every frame, the body's basis is forced back to `y = Vector4(0,1,0,0)` and re-orthonormalized (`Basis4D.orthonormalized`) to guard against float drift from repeated rotation composition.
- **Any code that needs "which way should the player turn/slice-rotate" (bearing math, POI arrows, minimaps) must read the `Player` body's own `global_position`/`global_basis`, never the camera/head chain** — pitch lives on `PlayerHead` and would silently leak vertical look angle into what should be a horizontal-only (yaw) quantity. `project/scripts/bearing_utility_4d.gd` is the shared implementation of this and documents the specific bug this fixed.
- Raycasting against 4D physics goes through `RaycastParameters4D` + `PhysicsServer4D.raycast_physics_objects()` (see `hitscan_weapon.gd`). Targets implemented as `Area4D` are detection-only and are *not* hit by raycasts unless `collide_with_areas = true` is set explicitly.

Before relying on notes in `project/player/CONTROLLER_NOTES.md` or module READMEs for exact current behavior, treat them as historical/explanatory rather than authoritative — verify against the actual `.gd`/`.tscn` source, especially on feature branches (e.g. `rotate_4d`/`fire` key bindings are currently swapped on `shooting-gallery` vs. `main`, as a `project.godot` `[input]`-only change).
