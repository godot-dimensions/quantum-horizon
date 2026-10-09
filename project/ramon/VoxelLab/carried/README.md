# Carried over, not reused

Copies made 6 Oct 2026, so the Voxel Lab never loads the originals and never changes them (Ramon's rule
for remakes: "carry it over, and not reuse it"; the Quantum Range and the Arboretum did the same).

## Where they came from

- **Everything here** from `res://ramon/Arboretum/carried/` as it stood on 6 Oct (its last commit
  `42c9fb8`), which itself came from `res://ramon/CreationLab/` at `8c6b193`. The Arboretum's carried kit
  is the Creation Lab kit plus the changes its README lists (a square pedestal, exhibits that tell their
  own story through `chapters()` and `numbers()`, the "methods" research layout, presenter fixes), which
  is what this room needs too. Its `shrubbery/` was not copied.
- Paths `res://ramon/Arboretum/carried/` are rewritten to `res://ramon/VoxelLab/carried/`. Comments that
  say "ARBORETUM (carried copy)" describe where a change was first made and are left as they were.

## Copying conventions

- No `.uid` sidecars, so Godot resolves these by path.
- No `class_name` in any of them, so nothing clashes with the originals.

## Shared on purpose, not copied

- Fonts: `res://ramon/Demo/fonts/Montserrat/`.
- The dev textures: `res://textures/dev_finals/`.
- `res://scripts/gait_controller.gd`, which the carried gait preloads (as the Creation Lab's does).

## Changes from the source

- `kit/kit_glyphs.gd` `animal()`: three more kinds, drawn in the same 100-unit box: "block" (a
  chamfered block with a crater, a notch and a tunnel), "column" (a round column on a square foot,
  notched) and "terrain" (a cube of landscape with the sea's line and a cave). The research panel's
  specimen glyph uses them.

- `kit/kit_room_4d.gd` `_plain()`, `_wall_ink()`, `_print_mood()`: text on a plain wall shows in the
  dark mood's light ink while the B switch has the walls black (the signs read black on black): a
  static print shows the "dark" picture it already holds, a live one paints with that ink.

- **8 Oct, the pen's current walk and camera.** `LabKit/carried/chickenpen/scripts/`
  `block_walker_character_4d.gd` and `pen_orbit_rig_4d.gd` carried again from the pen as they are since
  Andrew's 4 and 7 Oct changes (stepping along the view's W, the body turning through W, the camera's
  heading and slice held as one floor frame), with `ground_basis_4d.gd` (the pen's `GroundBasis4D`, no
  class_name here, preloaded as `Ground`). The walker is the pen's unchanged. The rig keeps the labs'
  `slice_turning` switch, and with it off a right drag now leaves the view alone (it used to look round
  while it turned the exhibit). The lab's body and run gait still replace the pen's chibi and gait.
- `kit/kit_showcase_4d.gd`: the exhibit's turn through W is a floor-only frame (`turn_basis`, the pen's
  mapping: sideways tilts its width into W, up and down its depth). It was a swing plus a tilt of UP into
  W, and a column or a tree leaned after a few drags.

- **9 Oct, round 2:** `kit/panels/kit_wall_panel_4d.gd` claims its wall in blue once the room has
  built its walls (they come after the panel's own `_ready`, so the claim was never made and the walls
  stayed grey); `kit/panels/kit_panel_charts.gd` `Tesseract` (the block's 4D frame, turning) and
  `kit_panel_research.gd`'s "tesseract" chart, ticked at 30 a second; `kit/kit_room_4d.gd`'s deferred
  rebuild skips a room that has left the tree.

- **9 Oct, Trym's sea for the open world.** `water4d/` (`water4d_surface.gd`, `water4d_presets.gd`,
  `water4d.gdshader`) and `shaders/foam_4d.gdshaderinc` from `res://ramon/Water/carried/` (the Water
  prototype's copy of Trym's 4D sea), paths rewritten to here. Changes: a GRADED grid
  (`grid_resolution`, `fine_extent`: even squares near the camera, growing to `extent`), so the sea can
  reach a kilometre at the cost of the old 280 m; and in the shader, `calm_from` and `calm_to`: the
  waves, foam and ripple die away toward the far edge, so the large far squares never sample a wave
  they are too coarse for. With the defaults both are as Trym made them.

## Going back to the shared kit

To point the Voxel Lab at the shared kit once it settles, rewrite these paths back to
`res://ramon/CreationLab/` and carry the changes above across. That is a question for Ramon.
