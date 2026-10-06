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

## Going back to the shared kit

To point the Voxel Lab at the shared kit once it settles, rewrite these paths back to
`res://ramon/CreationLab/` and carry the changes above across. That is a question for Ramon.
