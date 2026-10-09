# The Botany Lab's carried kit (9 Oct 2026)

A copy of the Aquatic Lab's `WaterLab/carried/` (its paths rewritten, `water4d/` and `flock/` left
out), with the Voxel Lab's `kit/kit_showcase_4d.gd`, `voxel_lab/vl_shimmer_4d.gd` and
`voxel_lab/vl_load_board.gd` merged in, and the research board's header saying BOTANY LAB. See
`../README.md`. The Aquatic Lab's notes follow, as they came.

---

# Water: carried files

Everything `water4d_test_ramon.tscn` needs from outside `ramon/Water/`, copied in on 8 Oct 2026 so
the scene stands on its own (and can be committed while Trym's water is still only on his branch).
Every `res://` path inside was rewritten to point here. No `.uid` files were copied (Godot makes
new ones), and the copied `.tscn` lost its `uid=` attributes, so nothing resolves back to the
originals.

| Here | From | When |
|---|---|---|
| `water4d/` (`water4d_surface.gd`, `water4d_presets.gd`, `water4d.gdshader`, `plesiosaur.tscn`, `plesiosaur_swimmer.gd`, `plesiosaur_pilot.gd`, `README.md`) | Trym's `sandbox/water4d/`, branch `origin/water-annex` at `76ff0fd` | 8 Oct |
| `shaders/foam_4d.gdshaderinc`, `shaders/README.md` | Trym's `shaders/`, the same branch | 8 Oct |
| `chickenpen/scripts/` (`loft_rig_4d.gd`, `loft_ball_4d.gd`, `plane_rotation_4d.gd`, `loft_builder_4d.gd`) | the pen's `chickenpen/scripts/` at `2b4a4e4`, which the plesiosaur is built on | 8 Oct |
| `LabKit/carried/chickenpen/scripts/` `pen_orbit_rig_4d.gd`, `block_walker_character_4d.gd`, `ground_basis_4d.gd` | the pen's `chickenpen/scripts/` at `e4ff9cb` (see the changes below) | 8 Oct |
| `kit/`, `LabKit/`, `scripts/` | the Arboretum's carried copy (`Arboretum/carried/`), itself the Creation Lab's at `8c6b193`; the Creation Lab's kit has not changed since (only `lab_run.sh`) | 8 Oct |
| `PathCreator/` | the Creation Lab's, the newest (the pen loads it directly), at `2c4ef41`: the Arboretum's set of files plus `render/path_sand.gdshader` | 8 Oct |

The kit came from the Arboretum's copy rather than the Creation Lab's so it keeps the fixes listed in
`Arboretum/carried/README.md` (the presenter, the square pedestal, the "methods" research layout).

The PathCreator here is newer than the Arboretum's: sand strips and node patches, routes that reveal
as you come near, `w_mode_override`, `targets_deep`, `set_ground`, and W-type tints in the editor's
volume view.

## Shared project files these still load

`res://scripts/gait_controller.gd` (the carried gait), the Montserrat fonts in `ramon/Demo/fonts/`
and the dev textures in `textures/dev_finals/`, as the Arboretum and the Creation Lab do.

## Changes from the sources

- **The player's rig and walk are the pen's current ones** (8 Oct, Ramon: "copy over rotations
  styles from the pen"): `LabKit/carried/chickenpen/scripts/pen_orbit_rig_4d.gd` and
  `block_walker_character_4d.gd` replaced by the pen's at `e4ff9cb` (7 Oct), with the pen's
  `ground_basis_4d.gd` beside them. That is 4Denthusiast's "usual controls" (4 Oct, `b27ffa1`): the
  rig holds heading and slice tilt in one ground basis, a right drag tilts the slice in the view's
  own axes (the same drag does the same thing on screen whichever way you face), looking round
  never re-cuts the world; and his walk (stepping and facing through the tilted slice), which the pen
  made its only one on 7 Oct. `GroundBasis4D` is a global class in the pen, so the copy has no
  `class_name` and the two scripts preload it as `GB`.
- **`slice_turning` put back on that rig**: the pen lets you tilt the slice anywhere; the water scene
  lends it only on pier 1's platform and pier 2's circle (off, a right drag looks round).
- The scene itself switches off the plesiosaur's `blend_joints` at run time (6 ms a physics tick);
  `water4d/plesiosaur_swimmer.gd` is unchanged.
