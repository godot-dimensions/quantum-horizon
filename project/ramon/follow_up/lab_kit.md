# The lab kit (`res://ramon/CreationLab/LabKit/`)

A design kit for explaining things in 4D, step by step, in the R&D lab look. The Creation Lab
(`CreationLab/creation_lab.tscn`) is its first user and its reference: open it next to this page.
Written 4 Oct 2026, after the Creation Lab's 70 steps (`follow_up/creation_lab_plan.md`).

The kit is three things that work on their own or together:

1. **The look:** a style (two moods, a colour code, type), materials on Ramon's dev textures, a
   room, a bay shell.
2. **The rig:** a test drum for any animal, with views (skin, blocks, lines, balls), a turn
   through W, pause and slow motion that work on every kind of creature.
3. **The step framework:** bays stacked along W and ridden by a lift, one idea per bay, a task,
   a card, a guide panel; a Watch mode that plays the whole route as a film.

Nothing in it has a `class_name` (engine_gotchas.md): preload the scripts.

## A lab of your own, in five minutes

1. A scene with a root `Node4D` and three children:
   - `Room` running `lab_room_4d.gd` (set `ground_size` and `ground_offset` to cover your stack),
   - `LabClock` (a plain `Node`) running `lab_clock_4d.gd`,
   - `Sequence` running `lab_sequence_4d.gd`, its `steps` array filled with step resources.
2. A root script that adds the player and hands it to the sequence:
   `var p := preload("res://ramon/CreationLab/LabKit/lab_player.gd").make(); add_child(p); $Sequence.player = p`
   (see `CreationLab/creation_lab_4d.gd`, which also picks the way in: guided, watch, explore).
3. One step resource per bay (`lab_step.gd`): code, part (atrium / build / motion / hall), number,
   title, idea, task and its key chips, the line said after the task, the card (method, shows,
   limits, measured and its evidence tier), extras for the curious, and the bay's content scene.
   Edit them in the inspector: the guide panel, the lectern card, the controls card and the
   film's captions all read the same words.
4. One content scene per bay, its root extending `lab_bay_content_4d.gd` and overriding what it
   needs:

   | method | what the sequence uses it for |
   |---|---|
   | `begin(seq)` / `end()` | you arrive in the bay / you leave it |
   | `task_done() -> bool` | polled every frame; true unlocks the step |
   | `handle_key(event) -> bool` | keys while you are in the bay (return true if used) |
   | `controls() -> Array` | rows for the controls card: `[key, what]` |
   | `metrics() -> Array` | LIVE rows for the lectern card: `[label, value]` |
   | `demo(t) -> float` | Watch mode: perform your own task at `t` seconds; return the length |
   | `rig() -> Node` | the rig the lab's own keys act on (pause, step, slow, view, spin) |
   | `framing() -> Dictionary` | a wider arrival camera for a big exhibit (`yaw`, `pitch`, `distance`) |
   | `film_marks() -> Dictionary` | your own film shots, `{"wide": [eye, look], ...}` in bay space |

   `shell` (the bay shell) is set before your content enters the tree: place things with
   `shell.spot("rig")`, `spot("lectern")`, `spot("pad")`. Join the group `lab_overlay_drawer`
   and write `draw_overlay(canvas, overlay)` to draw diagrams over the world; join
   `lab_mood_listener` and write `apply_mood(mood, instant)` to follow the bright and dark looks.
5. Test it with the runners (below), in both moods.

## The look

- **`lab_style.gd`:** the two moods (`BRIGHT` default, `DARK` on B, both designed, neither derived:
  Ramon, 3 Oct, "you have to optimize for both"), the type scale (`size(step, scale)`, Montserrat),
  `ui(role, mood)` colours, `panel_box(mood, scale)`, `surface(part, mood)` (which dev texture a
  floor, wall, trim, rig, lectern or pad uses), and `mood_of(tree)` for anything built after the
  room broadcast its mood.
- **The colour code** (`code(role, mood)`): greys are structure; yellow is "stand here, press
  this"; cyan is W (the lift, slice markers, rulers); violet is build; blue is animate; red is a
  limit or a failed check; green is a passed check.
- **Part tints** (`tint(part, role, mood)`, Ramon, 4 Oct: "make color variations of mine"): Build
  bays cast violet and Motion bays blue on the dev textures, faint, on the light walls and trim
  in bright and on the floor and trim in dark.
- **`lab_materials.gd`:** `surface(texture, size, metres, tint)` maps a dev texture by local
  position on all four axes (quadplanar, so a box never smears), `glow(colour)` is an unshaded
  strip of light, `flat(colour)` a plain lit colour, `box_mesh(size)`.
- **`lab_room_4d.gd`:** the moods' lights and sky, the ground slab, B to toggle (remembered in
  `user://lab_settings.cfg`).
- **`lab_bay_4d.gd`:** the test cell: chamfered walls, a skirting light and a cap, a light ring and
  crossbars, the step's number as segmented digits, the lift's pad, an exhibit light for the dark
  mood. Every piece has its own W thickness, so a bay thins away through W in a set order during a
  lift ride. The rig, lectern and pad spots are the same in every bay whatever its size (the lift
  is one object through all of W).

## The rig (`lab_rig_4d.gd`)

Give it `animal_scene` (a creature scene running `CreationLab/scripts/lab_creature_4d.gd`, which
wraps any of six drivers behind one surface: the strider, Trym's gait driver, the chicken, the
birds, the avatar, the armature) and it builds a drum with a deck, a belt that runs at the
animal's own foot speed, an optional boom, a light pool for the dark mood, and a contact disc.

- `animal_scale` (shown enlarged or reduced, said on the card; Trym's creature cannot scale),
  `animal_yaw` (90 shows a forward-facing animal side on, the way motion reads best),
  `show_belt`, `show_boom`, `radius`.
- `set_view("skin" | "blocks" | "lines" | "balls")`, `set_w_spin(degrees)` (the animal turns
  through W in place), `is_asleep()`; `sleep_distance` puts far rigs to sleep in their pose;
  `joint_distance` lets only near animals re-pose their joint bands (each band is re-sent to the
  GPU every frame it moves: the Hall went from 14 to 3 ms when this came down to 6 m).
- Pause, slow motion and frame steps go through the lab clock (`lab_clock_4d.gd`), which steps a
  creature's own `_process` and `_physics_process` itself, so they work exactly on any driver.

## The step framework (`lab_sequence_4d.gd` and friends)

- **The stack:** one bay per step at `spacing` (12 m) along `axis` (W; X is the fallback if W ever
  confuses people). Only the bay you are in is visible and running.
- **The lift:** N glides you onto the pad facing the exhibit, then slides you along W; Shift+N goes
  back; M lists every floor. Guided mode refuses to skip an unfinished step; explore opens every
  floor. A lift frame (four posts spanning all of W) is the one thing that stays put while the
  bays dissolve and grow in. A leash keeps you within 2 m of your bay in W.
- **The beat:** arrive, show, try, unlock, next. The HUD (`lab_hud.gd`) has the guide panel (step x
  of n, idea, task with key chips and a tick, then the line after), the controls card (the step's
  keys; C for the rest), the W ladder on the right with the ride's marker, the floor list, and a
  chime. The lectern (`lab_lectern_4d.gd`) stands beside the exhibit like a museum label; its card
  is compact until the task is done, then opens to METHOD, SHOWS, LIMITS, MEASURED and LIVE.
- **The reveal:** in the last bay, P draws every bay's shell at once with the projection.
- **Keys the kit uses:** N, Shift+N, M, C, P, F3 (hide every panel), B (mood), V, U, Space, `.`,
  `,`. Already taken in the player: WASD, Shift, Alt, Q/E, F, Tab, T, R, Esc, RMB; H is the shared
  back-to-menu prompt.

## Watch mode and the film

- **`lab_autopilot_4d.gd`:** add it and call `start(sequence)`: its own camera, shots worked out
  from each bay's rig spot and framing (wide while the caption says the idea, medium during the
  demo, close for the line after, then the lift filmed from beside the pad, riding along W), a
  lower-third caption, Esc to take over. `film = true` hides the HUD, the cards and the avatar and
  fades from and to black.
- **The film:** `lab_run.sh movie <name> res://ramon/CreationLab/scripts/_film_creation_lab_runner.gd`
  writes `smoke_test_output/video/<name>.avi` at a fixed 30 fps; `windowed ... stills` gives a frame
  per shot to check before the long render. ffmpeg is installed for the encode.

## Wall panels (`CreationLab/kit/panels/`, 5 Oct 2026)

A room's two walls of explanation: an **introduction** (room number, title, lead, up to five lines,
2–4 shortcuts) and a **research panel** (denser, live data). Both are built from Ramon's Figma
handoff "Creation Lab / Aligned Layout": frame 01 is the layout, frame 02 the rules. They are
native Godot 2D (every text, rule, icon, bar and row is its own named node) printed into the
wall's own surface, so the room's light falls on them. The plan and its 20 steps are in
`follow_up/wall_panels_plan.md`.

**Add them to your prototype in five minutes:**

1. **A room data file:** make a `.tres` with `kit_panels/kit_room_info.gd` holding number, title,
   status, lead, description (`{tokens}` allowed), interactions `[[icon, label], ...]` and
   `research_layout` (`specimen`, `compare` or `steps`). Words only: layout and type live in
   `kit_panel_spec.gd`, never per room.
2. **Two panels:** add two `Node4D`s running `kit_wall_panel_4d.gd`, `kind` intro and research.
   - On a KitRoom wall: `room_path`, plus `wall_name` (a wall of the room's plan: "left_corner",
     "right", ...), or `wall_side` (a side of a rectangle room) or `wall_edge` (an edge number).
     A panel always hangs in the horizontal middle of its wall.
   - No room: it builds its own blue wall facing its +Z, at any turn.
3. **A pair:** add one `Node4D` running `kit_wall_panels_4d.gd`, with `intro`, `research`, `info`
   and `source`. It keeps the two the same size, at the same height and on the same data.
   - `size_mode` is "kit size" by default; "fit walls" grows or shrinks both together.
4. **A source**, if it is live: a node with `fill(text)` and `research(info)`.
   `kit_panel_source_showcase.gd` does it for a KitShowcase. With no source the panels show the
   room's words and the Figma's reference numbers.

**The fixed rules:**

| What | Rule |
|---|---|
| Size | One kit size everywhere: 1 Figma unit = `UNIT_M` (12 mm), so a panel is 9.6 × 5.9 m with its foot 1.3 m up. |
| Blue wall | A panel's whole wall is code blue, however long the wall and whatever the panel's size. |
| Short walls | A wall too short gets a warning and a red frame in the editor, never a smaller panel. Only the pair's fit mode changes the size, and then for both. |
| Type | Montserrat roles in units: hero 64/78, lead 26/36, body 18/26, specimen 34/42, value 24/30, section 22/28, control 12/18, small 10/14, label 8/12, micro 7/10, fine 6/10, tiny 5/10. |
| Colour | The six Figma tokens; on a wall the blue tints are white veils. |
| Overflow | Text is never shrunk; overflow is reported. |
| Centred | Always in the middle of its wall. To put two panels on one long wall, split it into walls in line (the review gallery does: three edges, a panel in the middle of each). |
| Bottom line | The introduction's shortcut labels stand on the research panel's footnote line (`shortcut_label_y()`). |
| Edge wiring | A wall is split where a panel begins and ends (a piece of wall carries one picture). |

**Proof runners:**

| Runner | What it proves |
|---|---|
| `_capture_panel_sheet_runner.gd` | Both panels flat on the Figma's 2048 × 732 canvas, plus the compare and steps families. Overlay it on frame 01 to measure. |
| `_capture_panels_runner.gd` | The lab's panels straight on and through the story; the frame-01 gallery; the walls switch both ways; the legibility check from the resting player camera. |
| `_capture_panel_test_room_runner.gd` | A second prototype (`tests/panel_test_room.tscn`): a box room, a freestanding turned panel, and the pair's fit mode. |

## Room plans (`CreationLab/kit/kit_room_plan.gd`, 5 Oct 2026)

A room's shape from what it is for, not from its corners. The plan starts from a box: its width,
how far the entrance and back walls are from the middle. Each back corner can be cut across by a
corner wall with its own length and its own angle off its side wall.

- **Lengthening a corner wall** slides it into its corner. The box stays; the side wall and back
  wall it meets get shorter.
- **A rectangle** is both corner walls at 0 m. It is the same builder; a zero-length wall is built
  as nothing and keeps its number.
- **Wall names** are `left`, `left_corner`, `back`, `right_corner`, `right` and `entrance`. A
  KitRoom carries them in `wall_names`; doorways, edge codes and wall panels can use them.
- **A corner wall too long** for its box is shortened, so the side wall keeps a metre and the back
  wall keeps room for its door.

**In the Creation Lab** (`creation_lab_4d.gd`, F1 ROOM SHAPE):

- the sliders are half width, entrance, back, the Creation Lab wall's length and angle, the right
  corner wall's length and angle, and the back door
- under them are every wall's length against the panels' width (warm if a panel wall is too
  short) and a live diagram from above (`kit_plan_view.gd`), with blue walls, the panels, doors
  and the plinth
- settings saved before the plan are read back as the same room (`from_points`)

The shut dev panel and the wall panels cost about 0.03 ms a frame each; the first walls cost
about 1 ms (`_capture_dev_panel_runner.gd`). `_probe_shape_runner.gd` proves the plan: the saved
shape, a longer Creation Lab wall, and a rectangle.

## Paths (`CreationLab/PathCreator/`, 5 Oct 2026)

Routes and destinations drawn on the floor as vectors, from Ramon's Figma sheet "Path_Indicator".
The full story, with pictures, is in `PathCreator/CASE_STUDY.md`; the dev space to try them is
`PathCreator/pathcreator.tscn` (F4 builder, F5 next library, F6 DEV or WALK, F7 volume view).

**Routes in a scene of your own:**
1. Add a Node4D with `graph/path_network_4d.gd`.
2. Give it a `graph`: a `.tres` of `graph/path_graph.gd`. Start one in the builder, or write one in
   code the way `scripts/_make_graphs_runner.gd` does.
3. Point `targets` at a node whose children are the objects the routes lead to: anything with
   `footprint()`, `size` and `w_depth` (`space/pc_target_4d.gd` is one). A destination names its
   object in `target`; its frame grows round that object's footprint.

**The network's settings:**
- `look`: DEV (the sheet's blues) or WALK (one sand albedo).
- `libraries` and `default_library`: which symbol set each slot comes from.
- `p_scale`: the sheet's P (0.6 m, the player's width) times this. See the proof in the case study
  before choosing one for the pen.
- `drape`: lay routes on the static boxes under them (steps, decks).
- `hide_blocked`: hide a route while a static box shuts its way.
- `motion`, `clear_style`, `flow`.

**In the graph:**
- Each edge has a W mode:
  - `static`: seen from any W
  - `here`: at its start's W
  - `follow`: climbs from W to W; the slice shows a stretch that moves as you go
  - `reveal`: only at its end's W
- A destination can carry `anchor: true` to follow a moving object.
- The builder's R key rounds a corner into chords (`round_corner` in the graph, so an editor dock
  can use it too).

**Notes.** `notes()` lists what is wrong with a layout, in sentences: the graph's own checks and
rule 10's (overlaps, objects kept clear, arrivals reachable, every route ending at a
destination). The builder shows them under ROUTE NOTES.

**Cost.** Every route in the dev space at once (112 boxes) costs 0.22 ms. Draping casts rays only
when a route is laid. An anchored destination lays its own route again each time its object moves
3 cm.

## Testing (`CreationLab/scripts/`)

`lab_run.sh <mode> <name> <runner> [args]` takes the Godot lock in the same command that launches,
refuses if Godot is running (exit 3), logs to `smoke_test_output/creation_lab/logs/<name>.log` and
greps it for errors. Modes: `headless`, `windowed` (1280x720, unfocusable), `movie`, `check`.

| runner | what it proves |
|---|---|
| `_verify_lift_runner.gd` | the lift both ways, the refusals, the leash, the floor list, frames mid-slide |
| `_guided_run_runner.gd` | the whole route played with simulated keys (`bays=0-11`), frames at every beat |
| `_perf_lab_runner.gd` | frame time in every bay and in the Hall, against 8 ms |
| `_framing_runner.gd` | the arrival camera at several settings, to choose by eye |
| `_verify_rig_runner.gd`, `_verify_creature_runner.gd` | the rig and every creature's controls |
| `_contact_sheet.py` | many frames on one sheet, for looking |

## Traps found while building it

- The orbit rig only rebuilds its camera basis on mouse motion: code that writes `yaw`, `pitch` or
  the slice angles must call `_apply()` after.
- The orbit camera always centres the avatar, so from straight behind it an exhibit hides behind
  your head: arrive with the camera 30 degrees to one side.
- Every 4D instance takes five shader instance variables; a few thousand at once overflow the
  engine's buffer ("Too many instances"). Merge static strips into one mesh per material
  (`ArrayTetraMesh4D.merge_with`), as the bay shell now does.
- Anything built after the room's first mood broadcast must read `LabStyle.mood_of(tree)`.
- A strider's cut pieces exist only after its first physics frame; before that the rig's
  MeshInstance4D children are the loft balls.
- `Projection * float` does not exist; set a node's `scale` instead.
- In a SceneTree runner, add the scene after the first frame (`call_deferred` or `await
  process_frame`): added in `_initialize`, its `_ready` has not run. A script error inside a runner
  leaves Godot idling until the launcher's timeout, so runners give up on their own after a minute
  or two.
- The Combined projection fades with distance in W: something twelve bays away barely shows.
