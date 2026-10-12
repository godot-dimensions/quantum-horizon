# Merging origin/RamonPrototypes (written 7 Oct, for the next push)

Ramon, 7 Oct: "leave his out and make a note when we merge" (Aaron's pen fix), and earlier: "under no conditions,
should the andrew switches be able to break my work".

The server branch has 4 commits the local branch does not (local was 110 ahead, 4 behind). A plain push is
refused until they are merged. **Never force-push**: that deletes the teammates' commits from the server.

## The four commits, and what to keep

| Commit | Who | What | Decision |
|---|---|---|---|
| `b342372` | Aaron, 6 Oct | "Fix chicken pen scripts and returning chickens to the pen": pen_fence_4d.gd made a FenceGenerator4D, six pen scripts re-pointed at it | **Left out.** Ramon fixed the same thing on 5 Oct his own way (`71642e7`, `scripts/pen_fence_compat_4d.gd`). Git would merge Aaron's script edits silently, and they call `footprint_bounds` / `rail_height` / `clamp_inside`, which the compat fence does not have: the chicken returns would break at runtime. |
| `5e03383` | Andrew (4Denthusiast), 5 Oct | "Make the grass more 4D isotropic" | **His code is already in, and since 7 Oct evening it is the pen's grass** (`grass/pen_grass_lattice.gdshader`, `pen_grass_4d.gd` andrew_4d defaults true), merged onto Ramon's later hills, W lanes and paths, with a base-width slider. Keep ours. |
| `b20b6c6` | Andrew, 5 Oct | "Make player movement more 4D" | **His code is already in, as the two choices on the walking card** (`scripts/pen_stepping_card_4d.gd`; `block_walker_character_4d.gd` andrew_turning / andrew_stepping, `GroundBasis4D.rotated_toward`), default off every run. Keep ours. |
| `006484d` | Andrew, 5 Oct | "Fix GCC compile error in fence code" (one line of C++) | **Take it.** No change on Windows. |

## Files to resolve to OUR version (`git checkout --ours <file>` during the merge, or `git checkout HEAD -- <file>` after it)

Aaron's `b342372`:
- `project/ramon/chickenpen/chickenpen_old.tscn`
- `project/ramon/chickenpen/playable_world.tscn`
- `project/ramon/chickenpen/scripts/pen_crow_4d.gd`
- `project/ramon/chickenpen/scripts/pen_debug_4d.gd`
- `project/ramon/chickenpen/scripts/pen_fence_4d.gd`
- `project/ramon/chickenpen/scripts/pen_return_4d.gd`
- `project/ramon/chickenpen/scripts/pen_slice_plane_4d.gd`
- `project/ramon/chickenpen/wolf/wolf_raid_4d.gd`

Andrew's `5e03383` and `b20b6c6`:
- `project/ramon/chickenpen/grass/pen_grass.gdshader`
- `project/ramon/chickenpen/grass/pen_grass_4d.gd`
- `project/ramon/chickenpen/grass/pen_grass_looks.gd`
- `project/ramon/chickenpen/scripts/block_walker_character_4d.gd`
- `project/ramon/chickenpen/scripts/chicken_catcher_4d.gd` (his change there was a comment only)
- `project/ramon/chickenpen/scripts/ground_basis_4d.gd`

## Files to resolve to THEIR version: the teammates' own tooling

Ramon, 7 Oct: "i used aarons 4dfence generator. but i dont want to override his source tooling. but me adapting his
work is fine". The local branch has never changed anything under `engine/` (checked: no diff since the merge
base), so the tooling simply comes out as the server has it:
- `engine/modules/quantum_horizon/model/fence/fence_build_job_4d.cpp` (Andrew's Linux line; the rest of Aaron's
  FenceGenerator4D is already identical)
- `engine/modules/4d` (Aaron's pointer bump to `a93146b`, his 6 Oct module fixes; inert for Ramon, the update script
  follows the branch tip and the built editor is untouched)

Ramon's adaptations of Aaron's fence stay his: `scripts/pen_fence_compat_4d.gd`, and the coop's walls as one
FenceGenerator4D `Pen/Coop/Walls` in `playable_world.tscn` (7 Oct).

**THE COOP: RAMON'S IS THE FINAL ONE.** Ramon, 7 Oct: "aaron remade the coup with his own 4d fence. thats what i
started with. but it should be clear that mine is the final currently". Aaron's fence-generator coop was the starting
point; the coop in Ramon's `playable_world.tscn` is the current final. Any version of the coop arriving from the
server is resolved to Ramon's, and the merge message says so.

Only `pen_grass.gdshader` and `playable_world.tscn` conflict; **the rest merge without a conflict, which is the
trap**: check every file above is ours after the merge (`git diff ORIG_HEAD HEAD -- <file>` shows nothing), not
just the two git stops on.

## Before and after

1. Ramon's own uncommitted edits (`project.godot`, `Menu/entries/catalogue.tres`, his `playable_world.tscn`) are
   his: commit or set aside with him first, never stash or overwrite them silently.
2. `git fetch`, then `git merge origin/RamonPrototypes`, resolve as above, commit with the message below.
3. Run the pen checks before pushing: `grass/_andrew_ab_runner.gd` (must print "defaults: YES"),
   `PenLayout/scripts/_verify_journey_b_runner.gd`, `scripts/_verify_climb_runner.gd`,
   `scripts/_verify_dreamer_runner.gd`, `lookout/_verify_lookout_runner.gd`, `look/_verify_look_runner.gd`.
   (`scripts/_verify_catch_runner.gd` says FAULT since Ramon's start-facing change of 7 Oct 12:32, `fbba5e0`: it
   now catches a different chicken than the one it measures. Not from the merge.)
4. Push. Then tell Aaron his pen fix was left out on purpose and why, so he does not re-apply it.

## The merge commit's message

```
Merge origin/RamonPrototypes: the pen keeps Ramon's versions, adapted from Andrew's and Aaron's work

The files in the pen are Ramon's current versions. Where they build on a
teammate's work, they were adapted by hand on 7 Oct rather than merged in,
because the pen had moved on since those commits (layout B, hills, W lanes,
paths, dev look):

Andrew's grass (5e03383, "Make the grass more 4D isotropic") is now the
pen's grass. Ramon adapted it into his newer grass instead of taking the
commit: Andrew's 4D lattice (blades spaced evenly through x, z and W, so the
meadow survives a steeply turned slice; the old grass thinned to a strip past
about 75 degrees) runs on top of Ramon's hills, four W lanes of clearings and
path clearings (grass/pen_grass_lattice.gdshader), with a new "Blade width at
the base" slider in the grass panel that starts at Andrew's wider blades.

Andrew's walking (b20b6c6, "Make player movement more 4D") was added to the
HUD as toggles, on the pen's new walking card (scripts/pen_stepping_card_4d.gd):
Stepping, where E/Q take you (default: the world's W; Andrew's: straight out
of the slice you see), and Facing, which way the character turns (default:
on the ground; Andrew's: through W, so the catch aims into W too). Both
start on the default every run.

Aaron's pen scripts (b342372, the chicken pen on FenceGenerator4D) are left
out: the pen already had its own fix for the same problem since 5 Oct
(71642e7, pen_fence_compat_4d.gd), and his scripts call functions that
fence does not have, so the chicken returns would break. The coop: Aaron's
FenceGenerator4D coop was the starting point; Ramon's adaptation in
playable_world.tscn (Pen/Coop/Walls) is the current final.

The teammates' own tooling comes through as they made it: Andrew's 006484d
(GCC fix in fence_build_job_4d.cpp) and Aaron's godot-4d pointer bump.
```

## Not part of this merge

The godot-4d module has 11 newer commits from Aaron (6 Oct: raycast and shape fixes, CollisionShape4D layer
getters, one removed default argument in `fit_texture_map_island`, which nothing here calls). Optional; a separate
step with the editor closed: update script, engine rebuild, then the checks above.
