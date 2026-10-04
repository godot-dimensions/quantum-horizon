# LabKit/carried

Copies of what the labs (the Creation Lab, the Creation Gallery, the kit itself) used to borrow from
other prototypes, made on 4 Oct 2026 (Ramon: "if you reuse stuff from the playable world/pen scene
you should carry it over, and not reuse it. This could create conflicts later").

The labs load these copies, never the originals, so the pen and the loft-modelling prototype can
change without breaking a lab, and a lab can change its copy without touching them. Each file is
headed with where it came from.

| Folder | From | What |
|---|---|---|
| `chickenpen/` | `res://ramon/chickenpen/` (the pen, the playable world) | the third-person walker, avatar, gait and orbit camera; the loft rig, ball and builder; the strider; the cat, crow, chicken, Nike, owl, heron, chipmunk, the dreamer, the theatre's adoption of Trym's creature |
| `Model/` | `res://ramon/Model/` (the loft-modelling prototype) | the wolf, the goat (`model.tscn`), the horse (`animation_test.tscn`), Trym's creatures and their solvers, the symmetry creature |
| `Demo/scripts/hub_sun_4d.gd` | the hub | the sun the Model scenes carry |

**How they were copied** (`_verify_carried_runner.gd` checks the result): no `.uid` sidecars were
copied and every `uid=` was taken out of the copied scenes, because a duplicate UID makes Godot load
the original instead of the copy; every path between the copies points at the copies;
`class_name PlaneRotation4D` was dropped from the Model copy (a second one would collide, and
nothing uses the name).

**Still shared on purpose:** the back-to-menu prompt (`Demo/return_button.tscn`, one scene every
prototype instances so they change together), the team's project scripts (`res://scripts/`, the
gait controller and the IK chain), the project player (`res://player/`), the sandbox armature, and
the textures, fonts and sounds (copied sounds would not load until the editor imported them).

**Bringing a fix across:** a fix to an original does not reach here by itself. Copy the change in
by hand, or carry the file over again with the same treatment.
