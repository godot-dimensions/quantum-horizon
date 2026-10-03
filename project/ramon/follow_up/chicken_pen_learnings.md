# Chicken pen: learnings for the next session (30 Sept 2026, cinema talk 1 Oct)

Read this before touching `res://ramon/chickenpen/`. The running log of what was asked and
built is `pen_hills_cave_range.md`; engine traps in general are in `engine_gotchas.md` and
`lofting_gotchas.md`. This file is the short version: where things are, what bites, and how
Ramon likes to work.

## Where things are

- **The pen**: `chickenpen/playable_world.tscn` (named `chickenpen.tscn` until 3 Oct; only the file was renamed, the code still says pen), run it directly (`--path project res://ramon/chickenpen/playable_world.tscn`). `chickenpen_old.tscn` is the pen before the Lookout and the grass were merged in.
- **The cave**: `cave/cave.tscn`, opened beside the pen by `CaveCrossing` (`pen_crossing_4d.gd`, `bring_player`, `keep_scene`), hung 1 km along x. The pen's own player walks in.
- **The far room (the secret)**: `cave/cave_far.tscn`, out along W at w 46, streamed by `cave/cave_far_stream_4d.gd` only while it can be seen. Reached through the arch in the chamber that only shows when the slice is turned through W (`cave_w_sheet_4d.gd`).
- **The cinema**: `theatre/theatre.tscn`, opened by `Crossing`. While it is open the pen's `Player`, `UI` and `Systems` are ASLEEP; the cinema has its own `Player`. Anything that must work there cannot live in pen `Systems`.
- **The cinema talk** (rebuilt 1 Oct as one presentation, no question between parts): slides I to VI are `theatre_show_4d.gd` (ACTS, curtain, walk_out, replay) with I, II, IV, V and VI built and run by `theatre_primer_4d.gd`; VII to IX are `theatre_part_two_4d.gd`. Shapes from their equations in `theatre_shapes_4d.gd`; the picture-in-picture flat view and 4D shadow in `theatre_screen_4d.gd`; slide I's see-through sheet is a screen-space overlay, `theatre_pane_4d.gd`; the END OF PRESENTATION card is `theatre_endcard_4d.gd`. Camera shots in `theatre_camera_4d.gd`.
- **The range**: `World/RangeBooth` (`pen_range_booth_4d.gd`, `pen_range_shooting_4d.gd`); the range master's trip parks the pen and opens `shooting_gallery_ramon.tscn` (`pen_range_trip_4d.gd`). A placeholder.
- **Laptops**: `pen_laptop_4d.gd` on a marker at each (Trym's desk, the cave table, the cinema stand); `pen_laptop_trip_4d.gd` parks the pen and opens `res://ramon/Menu2.tscn`.
- **Dialogue** (`ramon/dialogue/`): `dialogue_player_4d.gd` walks script dictionaries (keys: `speaker`, `lines`, `choices`, `goto`, `instead`, `topic`, `do`, `do_on_line`, `sets`, choice `once` / `needs`; `interrupt(key)` for a detour that resumes); `dialogue_box_4d.gd` draws it (layouts BOTTOM_BAND, LEFT_PANEL, OVER_HEAD, CINEMA); `world_tag_4d.gd` is the "F talk" prompt. Every talkable character extends `PenNpcTalk4D` (`scripts/pen_npc_talk_4d.gd`, group `npc_talk`).
- **Items**: `scripts/pen_inventory_4d.gd`. Azoth is `found_azoth` (it was gold; files and nodes still say gold on purpose). Only azoth stacks.
- **UI size**: `scripts/pen_ui_scale_4d.gd` sets the window's `content_scale_factor`; the dial is held at its authored pixel size plus its own `dial_percent`. Both saved in `user://pen_settings.cfg`. Keys `+ / -` and `Shift + / -` in `scripts/pen_controls_4d.gd`.
- **Baked meshes**: `terrain/baked/*.res`, rebuilt with `scripts/_bake_terrain_runner.gd -- what=hills|cave_hill|cave|cave_far|mountains`.

## What bites (4D and Godot)

- **Video memory, not frame time, is the budget for static scenery.** Every tetrahedron costs about 1.25 KB of proxy vertices whether or not it is on screen. Merge boxes into one baked mesh (one draw instead of sixty), and stream rooms you are not in.
- **Vertex colour goes through an 8-bit slot**, so baked colour is coded as sRGB in a colour cube. Changing that encoding means rebaking every `.res`.
- **A thin tube in 4D is mostly invisible**: it crosses your slice only within its radius. Thicken pieces along the slice's normal.
- **Only one WorldEnvironment4D wins, and it is decided by tree-entry order.** Taking a scene out of the tree and putting it back (any "trip") can hand the light to the wrong one: the cave came back lit by the field's sunset. Note the one in use before, `make_current()` it after.
- **Menus change the window** (`content_scale_*`, borderless fullscreen) and nothing puts it back. Save the window before, restore after. Leaving borderless fullscreen also trims a few pixels off a windowed size, so better not to switch mode at all.
- **Off-slice checks must use the camera's slice normal, not raw w.** Walking along W with the slice turned, "w" is the direction you are looking; raw-w tests hid prompts twenty metres ahead of you. Same for reach: measure distance in (x, z, w) where the approach is along W.
- **Build proxy meshes on a WorkerThreadPool** (`Mesh4D.get_proxy_mesh_3d()` is cached on the resource) or the first draw hitches: 141 ms down to 17.
- **OmniLight4D range scales with its node's scale**; lights reach only a few metres in cross-section.
- **The block avatar frees its children in its `_ready`**: attach props to it after, not before.
- **A Button is never shorter than its text**: squeeze two into a row and their hit areas overlap.
- **GDScript**: `Projection` has no `transposed()` (use dots with the basis columns for a rotation); constants are not readable through `obj.get()`, preload the script instead; a script that passes `load()` can still have parse errors, use `--check-only --script`.
- **`Node4D.set_global_position`** was wrong under an offset parent until 4d `0cd7372` (pulled 30 Sept). Older code sets local positions through the parent's inverse on purpose; that stays correct.
- **The cross-section renderer is opaque only.** Gradients built from mesh bands step and read as solid. For see-through glass, draw a 2D overlay projected through the live camera (`Camera4D.world_to_viewport`, `draw_polygon` with per-vertex alpha); Ramon is fine with that cheat for the talk.
- **A CanvasItem keeps its last drawing**: when a fade reaches 0, queue one more redraw or a faint ghost stays on screen.
- **Anything drawn "as seen from the room" must use the live camera** (the shot camera when seated), read once per draw, not per point. The 4D shadow panel was drawn from a fixed angle and turned differently from the slice beside it.
- **Godot output piped through `grep` is lost if `timeout` kills the process.** Write logs to a file, then grep the file.

## How Ramon works

- **Shared worktree, several Claude windows**: commit by explicit paths, never `git add -A`. `project.godot`, `theatre_numeral_4d.gd`, `deck_assets/` and `follow_up/presentation temp/` are not ours.
- **Commit locally; push only when he says.**
- **Never run Godot while his editor is open**, and take turns with the other windows: check `.claude/godot_in_use.txt` and `Get-Process` in the same command that launches, write your lock line, remove it after. His editor's line reads "Ramon's editor (opened for him by ...)". Open his editor on monitor 1 (x 2560 to 5120; it ignores `--position`, move it with Win32 `SetWindowPos`). Don't run the project-wide resave script; hand-check `.tscn` edits.
- **Test by playing, not only by asserting.** Runners save frames to `res://smoke_test_output/`; look at them. Headless passes have missed visual bugs more than once (the browner cave, the hidden prompt).
- **Your test windows**: small (`--windowed --resolution 1280x720 --position 40,40`) with `root.unfocusable = true`; his typing once opened the cinema through a focused test window. Fullscreen only when launching for him.
- **Tests must leave his saved UI sizes alone** (`user://pen_settings.cfg`): restore what they change.
- **No em dashes or spaced-hyphen dashes in player-facing lines.** They read as machine-written.
- **Ask before extending a fix to neighbouring places.** Recommend briefly with the trade-off, then build fast.
- **Show, don't describe**: capture a frame or launch the game for him (fullscreen) when he asks to see.

## State and open ends

- **Done and pushed** to `origin/RamonPrototypes` (7b40d9c and before): the cave with its NPCs and backstory, the secret room and its cinematic conversation, azoth, the three laptops, the mountains, the HUD sizes, the range placeholder. 4d module updated to `551d5e8` on 30 Sept (pointer not committed).
- **The cinema talk, 1 Oct, committed locally (not pushed)**: nine slides, every one with arrows and click; sitting after the end replays it; F or Esc in the chair, or forward on the outro, leaves the presentation; the end card shows only while you are seated. Open offer: Trym's head pokes into the bottom left of slide I's camera (angle C); nudge the camera right or keep him at the lectern.
- **Not touched yet**: the range beyond a placeholder.
- **The menus crash** now and then about a minute in (Menu2 / Frontier Map, launching prototypes). Ramon knows; parked, don't chase it unprompted.
- **Offered, not done**: a one-line guard in `chicken_cues_4d.gd` `quiet()` for a freed glimpse marker at the end of the hunt.
- **Stale tests, not regressions**: `_verify_hud_runner.gd` (expects the top-left card to resize; it has been fixed-size since 28 Sept), `_verify_talk_runner.gd` (looks for `UI/Radar`, long gone). `sandbox/terrain4d/*.gd` clash with the engine's native `VoxelWorld4D` class (since early Sept).

## The tests worth running after any change

Headless: `_verify_cave_runner`, `_verify_cave_far_runner`, `_verify_ui_scale_runner`, `_verify_professor_runner`, `_verify_gold_runner`, `_verify_crossing_runner`, `_verify_range_runner`, `_verify_scenery_release_runner`.
Windowed (they save frames): `_verify_dreamer_runner`, `_verify_laptop_runner`, `_verify_range_shooting_runner`, `_capture_dreamer_cinema_runner`.
All passed on the 30 Sept build: 288 checks.

The cinema, headless: `_verify_primer_runner`, `_verify_shapes_runner`, `_verify_theatre_runner`, `_verify_part_two_runner`, `_verify_release_runner`, `_verify_resit_runner`, `_verify_seat_runner`, `_verify_after_show_runner`, `_verify_impatient_runner`. All pass on 1 Oct except one known, older failure in `_verify_presenter_runner` ("moves in for the demonstration"). Frames of the whole talk: `_capture_talk_runner.gd` windowed, `-- until=<frame>` to stop early (e.g. `until=i_cone_cut`). `_capture_crossing_runner` is stale (stops at Trym's ticket door).
