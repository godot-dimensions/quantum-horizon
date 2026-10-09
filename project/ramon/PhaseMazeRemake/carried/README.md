# Carried over, not reused

Copies, made 8 Oct 2026, so the Phase Maze remake never loads the originals. The rule is Ramon's,
for the Creation Lab and the pen: carry it over, and do not change the original.

## Where they came from

- **`LabKit/`, `kit/`, `kit/panels/` and `scripts/`** come from the Shooting Range's carried copy
  (`res://ramon/QuantumRange/carried/`, itself from `CreationLab/` at `60e6524`), with the range's
  `edge_ends` fix. Paths `res://ramon/QuantumRange/carried/` are rewritten to
  `res://ramon/PhaseMazeRemake/carried/`.
- **`walker/`** comes from the pen at commit `11971e1`, 8 Oct, after Andrew's 214dfe4 and e4ff9cb.
  It is Andrew's way of walking and seeing:
  - stepping along the view's W;
  - facing through W;
  - W-thick body parts.
  - Files:
    - `chickenpen/scripts/ground_basis_4d.gd`;
    - `pen_orbit_rig_4d.gd`;
    - `block_walker_character_4d.gd`;
    - `block_avatar_4d.gd`;
    - `block_gait_4d.gd`;
    - `project/scripts/gait_controller.gd` (shared, copied too).
  - To compare with the pen later: `git diff 11971e1 -- project/ramon/chickenpen/scripts/`.

- **`rewards/`** (round 2, 9 Oct): what stands in the reward halls.
  - From the Shooting Range at `11971e1`: `range_target_4d.gd`, `range_style.gd`, `range_mats.gd`,
    `range_fx_4d.gd`, `range_shapes.gd`, `range_wolf.gd`, `targets/target_wolf.gd`,
    `targets/target_chicken.gd`, and `carried/chicken/` (`chicken.tscn` and its loft scripts).
  - From the pen: `chickenpen/cave/cave_dreamer_4d.gd` and `chickenpen/scripts/loft_builder_4d.gd`, as
    `rewards/dreamer/`. The pen's own files are never touched.
  - All their `res://` paths point at these copies. The chicken scene's `uid=` attributes are stripped,
    so its IDs cannot clash with the range's.

## Copying conventions

- No `class_name` in any copy, so nothing clashes with the originals. `GroundBasis4D` is a class name
  in the pen; here it is `preload`ed as `GB` by the rig and the walker.
- Godot writes `.uid` sidecars as it loads the copies; they are kept, so the scene's IDs stay put.

## Changes from the source

- `LabKit/lab_room_4d.gd`: the mood is remembered in `user://phase_maze_remake_settings.cfg`.
- `kit/kit_light_4d.gd`: aims at its own W, not at W 0, so the spot over the walker still points
  down when the walker is in another layer of the maze.
- `kit/kit_glyphs.gd`: `animal()` also draws the six level glyphs (`hud/maze_glyphs.gd`), for the
  research wall's specimen.
- `walker/block_avatar_4d.gd`: `face`, `belt_colour` and `boot_colour` exports. Ramon, 9 Oct: "make the
  character dark blue, with subtle shifts, like a brighter blue for the face". At their defaults the
  figure is built exactly as in the pen.
- `walker/ground_basis_4d.gd`: the `class_name` line removed (see above).
- `walker/pen_orbit_rig_4d.gd` and `walker/block_walker_character_4d.gd`: `GroundBasis4D.` calls are
  `GB.` calls.
- `walker/block_gait_4d.gd`: preloads the copied `gait_controller.gd`.
- `walker/block_walker_character_4d.gd`: the step-up also looks along W (round 2: stairs that rise
  through W climb once you turn to walk along them), and its debug print of every 40th probe is gone.

## Shared on purpose, not copied

- Fonts: `res://ramon/Demo/fonts/Montserrat/`.
- Dev textures: `res://textures/dev_finals/`.
- The back-to-menu prompt: `res://ramon/Demo/return_button.tscn`.
