# Botany Lab (the Arboretum's rework, 9 Oct 2026)

Ramon renamed the Arboretum the Botany Lab and walked it. This folder holds the rework. It is built
beside the original, per his rule: finished scenes are reworked in an adjacent copy, and only he says
when it goes live. The plan and the status are in `follow_up/arboretum.md`, section 7.

- **The hall:** `../botany_lab.tscn`, its root script `botany_lab_4d.gd`.
- **The second room:** `compare/botany_compare.tscn`, its root script `compare/bl_compare_4d.gd`. You
  reach it through the hall's back door.
- **The flower room** (round 3, 10 Oct; section 9 of the handover): `flowers/flower_room.tscn`, its root
  script `flowers/flower_room_4d.gd`. You reach it through the holographic doorway in the hall's right
  wall, at the end of the flower border.
- **The original:** `../arboretum.tscn` and `../arboretum_4d.gd` are untouched, and so is the menu's
  card, which still opens `arboretum.tscn`.

## What is here

| Path | What it is |
| --- | --- |
| `carried/` | The newer kit: the Aquatic Lab's carried kit (water and flock left out), with the Voxel Lab's `kit/kit_showcase_4d.gd` (the GroundBasis turn, so trees never lean), `voxel_lab/vl_shimmer_4d.gd` (the holographic doorway) and `voxel_lab/vl_load_board.gd` (the loading board). |
| `botany_lab_4d.gd` | The hall. It forks `../arboretum_4d.gd` onto the new kit. |
| `pen_walk.gd` | The playable world's walk (Andrew's walker's values, Q/E through W). |
| `room/` | The dev HUD (`bl_dev_panel.gd`, the artist panel), the lights' editor (`bl_light_editor.gd`, the Aquatic Lab's), the floating panels' words (`bl_panel_words.gd`), the floor marks and the route targets. |
| `exhibits/` | The four pedestals, reworked (`bl_ex_*.gd` on `bl_tree_exhibit_4d.gd`). |
| `botany/bl_dc_tree_builder_4d.gd` | The smooth-voxel builder with leaf masses and order stages. |
| `baked/` | The rework's own bakes and their record (`bl_bake.cfg`), made by `scripts/_bl_bake_runner.gd`. |
| `paths/hall.tres` | The hall's route, made by `scripts/_bl_make_paths_runner.gd`. |
| `compare/` | The second room. |
| `flora/` | Round 3: the flowering plants and butterflies, lofted in 4D (`flora_species.gd` the data, `flower_4d.gd` the builder and the one shared material, `flora_plant.gdshader` its wind, `flora_air_4d.gd` feeding it each render), the butterflies (`butterfly_4d.gd`, `butterflies_4d.gd`), drifting petals and leaves (`flora_drift*`, the pen's wind bits carried) and the small foliage (`flora_sprigs*`, the pen's grass trick carried). `flora/baked/` holds their bakes (made on first run). |
| `flowers/` | Round 3: the flower room. |
| `room/bl_border_4d.gd` | Round 3: the hall's flower border, eight small planters. |
| `scripts/` | The runners: proof, play, capture, compare, paths, bake; round 3's flora probe and gallery, flower room and film. |

## What is shared, and must stay

The rework reads these from the Arboretum and does not change them. **Do not delete them while this
fork exists:**

- **Builders and helpers:** `../botany/*` (tree builders, skeletons, wind, leaves, style, bake store)
  and `../shaders/botany_*`.
- **Bakes:** `../baked/`, which holds the skeletons, `vx_wood`, `vx_stage_*`, `lf_*`, `oak_*`,
  `bones_main_*` and the grove's `grove_vx_*`, `grove_ok_*` and `grove_*_skeleton` (the second room
  plants these).
- **Panels and shrubbery:** `../room/arb_panel_source.gd` (the research board's numbers) and
  `../carried/shrubbery/` (the skeletons' crown shapes).
- **The wind:** `../botany/wind_4d.gd`, shared with the Arboretum. Round 2 added optional strength,
  width and lead to its `gust()`; called without them it behaves as before.

## Rules

- Fork, don't edit. A shared file that has to change for the Botany Lab is forked into this folder,
  and only the fork is pointed at it.
- `.uid` sidecars are Godot's own; none were copied in, so none clash with the originals.
