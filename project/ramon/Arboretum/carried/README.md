# Carried over, not reused

Copies made 5 to 6 Oct 2026, so the Arboretum never loads the originals and never changes them
(Ramon's rule for remakes: "carry it over, and not reuse it"; the Quantum Range did the same).

## Where they came from

- **`LabKit/`, `kit/`, `kit/panels/`, `scripts/`, `PathCreator/`** from `res://ramon/CreationLab/` at
  commit `8c6b193` (5 Oct, 23:06; nothing in `CreationLab/` was modified in the working tree then).
  Only the files the Arboretum needs, found by following every preload and load from the pieces
  used. Paths `res://ramon/CreationLab/` are rewritten to `res://ramon/Arboretum/carried/`.
  - `LabKit/carried/chickenpen/scripts/` holds the Creation Lab's own copies of the pen's walker,
    avatar, gait, orbit rig and loft builder (it carried them from the pen).
  - `PathCreator/sets/06` and `07`: the symbol libraries' SVGs, read as text. The folder has a
    `.gdignore`, so Godot does not import them as pictures.
- **`shrubbery/`** from `res://sandbox/shrubbery/` (Trym, Aug 2026; a port of TanTanDev's
  *shrubbery*): the generator, its branch, species and attraction shapes, the blocky mesher, and
  `res://scripts/subdivided_box_tetra_mesh_4d.gd`, which the mesher builds its faces with.

## Copying conventions

- No `.uid` sidecars, so Godot resolves these by path.
- No `class_name` in any of them, so nothing clashes with the originals. The shrubbery's classes
  (`ShrubGenerator4D` and the rest) became preloaded constants without the "4D" suffix
  (`ShrubGenerator`, `ShrubSpecies`, ...), since constants named like a global class would shadow it.

## Shared on purpose, not copied

- Fonts: `res://ramon/Demo/fonts/Montserrat/`.
- `res://scripts/gait_controller.gd`, which the carried gait preloads (as the Creation Lab's does).

## Changes from the source

- `kit/kit_pedestal.gd`: a square pedestal (`build(..., form = "box")`) with the same parts as the
  round one, its label printed on the face its angle points at. The voxel tree stands on it.
- `kit/kit_showcase_4d.gd`:
  - `pedestal_shape` ("round" or "box"; a box has no hologram);
  - `sequences()` asks the exhibit for its own `chapters()` before the kit's one animal story, and a
    new `numbers()` asks it for its own callout numbers: each tree tells its own story;
  - the band round the pedestal asks the exhibit for its `band_line()`.
- `kit/kit_presenter.gd`: the title card and callouts read the showcase's `sequences()` and
  `numbers()` instead of the kit's fixed animal story; a part's own line takes those numbers too
  ("{leaves} leaves"). The room has four pedestals where the lab had one, so a new showcase drops the
  last one's callout at once, and no showcase (between pedestals) clears the card instead of leaving
  the last one drawn.
- `kit/panels/kit_panel_research.gd`: a fourth layout family, **"methods"**: four equal columns, one a
  method, read across on one cost scale (a bar each), the one you are at marked. Plus its sample.
- `kit/panels/kit_room_info.gd`: "methods" added to `research_layout`.
- `LabKit/carried/chickenpen/scripts/loft_builder_4d.gd`: `build(..., span_ratio)`, how long a span
  may be against its width before it is split (default unchanged, 3). Twigs are long and thin and
  would be split into many short spans for slivers nobody picks; the Arboretum lofts at 10.
- `shrubbery/shrub_generator.gd`: the reached-points check looks only at the branches added this
  step (`_consume_reached_attractors(species, first_new)`). Every point is placed before growth
  starts, so a point near an older branch was removed when that branch grew: same tree, and a
  950-node tree grows in under half a second instead of minutes. (The oak no longer uses this
  generator: botany/colonize_4d.gd, case study 4.)
- `shrubbery/*`: the class names taken out and the references preloaded (above).

## Going back to the shared kit

To point the Arboretum at the shared kit once it settles, rewrite these paths back to
`res://ramon/CreationLab/` and carry the changes above across. That is a question for Ramon.
