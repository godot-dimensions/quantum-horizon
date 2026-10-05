# Carried over, not reused

These are copies, made 5 Oct 2026, so the Quantum Range never loads the originals.

**Ramon, 5 Oct:** "do study the creator folder. but dont change anything in there!" He used
the same rule for the Creation Lab: "carry it over, and not reuse it".

## Where they came from

- **`LabKit/`, `kit/`, `kit/panels/`, `scripts/`** come from `res://ramon/CreationLab/` at
  commit `60e6524` (5 Oct, 16:16). Paths `res://ramon/CreationLab/` are rewritten to
  `res://ramon/QuantumRange/carried/`.
- **`chicken/`** comes from `res://ramon/chickenpen/`:
  - the three loft scripts from `chickenpen/scripts/`;
  - `chicken.tscn`, with the walker, the agent, the follow script and the wing mark taken out,
    the feet placed where their follow script put them, and the wing built one side only
    (`mirror_x = false`). The range turns a copy of it 180° through the xw plane for the other
    side.

## Copying conventions

- No `.uid` sidecars, so Godot resolves these by path.
- No `class_name` in any of them, so nothing clashes with the originals.

## Changes from the source

Anything else changed is listed here.

- `LabKit/lab_room_4d.gd`: the mood is remembered in `user://quantum_range_settings.cfg`, not
  the lab's own file.
- `LabKit/lab_room_4d.gd`: the sky's sun halo is 0.4°, not 30°. The range has no roof, and the
  dim fill light's halo showed as a dark blob in its sky. The fill's own sun disc is shrunk to
  nothing too.
- `scripts/chamber_build.gd`: `W_DEPTH` is 24 m, not 8. The range's cores sit up to 7 m off in
  W and you reach them by turning the slice, so the room must still be there when you do.

## Shared on purpose, not copied

- Fonts: `res://ramon/Demo/fonts/Montserrat/`.
- Dev textures: `res://textures/dev_finals/`.
- The back-to-menu prompt: `res://ramon/Demo/return_button.tscn`.
- Primitive meshes: `res://models/primitives/`.

## Going back to the shared kit

To point the range at the shared kit again once it settles, rewrite these paths back to
`res://ramon/CreationLab/`. That is a question for Ramon.
