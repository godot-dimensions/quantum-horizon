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

None yet. Any change goes in this list.
