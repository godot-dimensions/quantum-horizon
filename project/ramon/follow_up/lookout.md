# The Lookout: handover (night of 1–2 Oct 2026)

Ramon, 1 Oct: "draw a plan of 70 steps, for the new gameplay element with the photography
thing ... work with the W, and make it immersive ... definitely add the balloon ... when you
created the 70 step plan, execute." The plan is `lookout_plan.md`; this is what got built,
what changed on the way and why, what was measured, and what is still your call.

## Play it

Open `res://ramon/chickenpen/chickenpen_lookout.tscn` and run it (F6). It is the pen,
inherited: `chickenpen.tscn` is untouched, and the Lookout's nodes move into it when you say
so. The tower is behind the pen as you spawn. **The Lookout card** in the HUD's right column
lists every way in, each on a key the pen did not use, and says what to do next:

| key | | |
|---|---|---|
| **Z** | Camera | on the deck, once Wren has given it to you; Z or Esc lowers it (it is the lookout's: on the ground Wren says so; the balloon has its own) |
| **J** | Field journal | the book, on the ground, on the deck or in the balloon |
| **B** | Balloon | once it is up beside the tower: straight up, from anywhere on the farm |
| **F** | Climb | at the ladder; on the deck, at the gap in the rail, climbs down |
| **U** | Fly as the hawk | the flock's own; U or Esc lands |
| **P** | Projection | the cut, or the cut plus a ghost of everything along W |
| **F4** | Developer overlay | W depths, the slice, the numbers |
| **L** | Lens (camera up) | the next prime, 18 to 200 mm; Shift+L back |

- Walk towards the tower: a short camera move up it ("The Lookout") and down onto **Wren**.
  **F** to talk to her: she gives you her camera. (Replies: Up/Down and Space, or the number
  keys since round three.)
- **Camera up** (Z, or after the climb): you walk as ever with WASD, the view at your eyes,
  and the viewfinder says it is a camera - a matte top and bottom, frame corners, the mode and
  the film in the top strip, and two of the pen's own cards over it: the **metrics** (the
  slice offset, the lens, what is in your slice and how much of it, how a photo is judged)
  and **every key** the camera has right now, F's current job lit at the top. F3 hides both.
  - **wheel** zooms, 18 mm to 216 mm (L steps through the primes): a W-T bar up the right marked in mm,
    the mm and the field of view beside it, the magnification big while you zoom and the
    old framing shrinking away as corner marks
  - **E / Q** turn the focus ring (not a step through W while the camera is up): it slides
    your slice along W, up to 3 m either way. **T** autofocus. **Right-drag** turns the
    slice, **R** straightens it. **Click** shoots (24 a roll; it reloads).
  - **The W-meter** along the bottom: a tick for every creature in front of you at its W,
    bright if the journal still wants it, taller and named as the needle nears it, a band
    round the needle for the depth of field. **The ghost rings**, the second locator: a
    dashed ring in the picture where each creature off your slice is, with its W.
- **The balcony**: F at the ladder climbs to an open deck with a very small cabin in the
  middle, railings below your eye and nothing else in the way. You arrive facing the pen with
  the camera up and can walk all the way round. The ana owl sits on its post off the north
  side, at **w +1.5**, five metres out.
- With the owl and eight photos in the book, Wren's **balloon** goes up beside the tower:
  **B** from anywhere (or F at the basket, or ask Wren). The ride is 2 min 44 s: over the
  pen, through the starlings, then ana to a round pond at w +8 and back. **X** whistles. Esc
  once tells you how to get down; twice brings it straight down.
- The journal: 10 pages, 4 behaviours each (40 photos). Three secrets: the ana owl, the white
  starling (one in five thousand, long lens), the heron (in the marsh).
- The journal is saved (`user://lookout_journal.cfg`, photos beside it). **Ctrl+Backspace
  twice** in the book starts a fresh one, and the story with it.
- The first design, the closed cab you stand in at a window, is still there:
  `World/Lookout` > Design > Cab.

The film: `smoke_test_output/video/The Lookout.mp4` (96 s, 1080p, the game's own sound),
made by `lookout/_film_lookout_runner.gd`.

## Where it is

Everything is in `chickenpen/lookout/` (21 scripts and 7 runners, each with a header that says why):

| | |
|---|---|
| `lookout_4d.gd` | the game's root (`Systems/Lookout`): finds the pen's nodes, builds the rest |
| `lookout_tower_4d.gd` | the tower (`World/Lookout`): the balcony (default) or the closed cab, the frame, the ana post |
| `lookout_station_4d.gd` | the climb, the camera raised anywhere (HELD), the cab, the ride: zoom, focus ring, slice turn, shutter |
| `lookout_viewfinder_4d.gd` | the matte, the W-T zoom bar, the W-meter and ghost rings, the metrics and keys cards, blackout, toasts |
| `photo_subjects_4d.gd` | who can be photographed, read by duck typing from the pen's own state |
| `photo_judge_4d.gd` | judging from game state: in frame, sharp in W, size, centring, behaviour, blocked |
| `field_journal_4d.gd` | pages, slots, best photo per slot, saving |
| `journal_card_4d.gd`, `journal_book_4d.gd` | the Lookout card (`UI/Journal`: Z J B F) and the J book |
| `lookout_story_4d.gd`, `lookout_radio_4d.gd`, `lookout_cutscene_4d.gd` | the beats, Wren on the radio, the camera moves |
| `lookout_wren_4d.gd`, `lookout_wren_talk_4d.gd`, `wren_script.gd` | Wren (the shared avatar, dressed) and her dialogue |
| `owl_4d.gd`, `heron_4d.gd` | the creatures; both also stand in `Model/rigged_creature_ramon.tscn` |
| `balloon_4d.gd`, `ana_marsh_4d.gd` | the balloon and its ride; the marsh at w +8 |
| `lookout_sound_4d.gd`, `bake_lookout_sound.py` | 19 synthesised sounds (`audio/sfx/lookout_*.wav`) |
| `_verify_lookout_runner.gd` (23 checks), `_verify_story_runner.gd` (25), `_verify_ride_runner.gd` (14), `_verify_extras_runner.gd` (white / marsh / showcase), `_measure_lookout_runner.gd`, `_capture_creature_runner.gd`, `_film_lookout_runner.gd` | runners |

Outside the folder, three small changes: the flock got an opt-in white bird
(`flock/pen_flock_4d.gd` `white_bird`, default -1 = none; `flock/flock_bird.gdshader`
`white_index`), and the creature showcase got the owl and the heron.

## How the 4D idea works

- **The focus ring** moves the camera along its own slice normal. A 4D body off your slice
  by dw shows a cross-section sqrt(1 - (dw/R)^2) of itself and nothing past R, so the judge
  scores sharpness from exactly that, and "out of focus" is literal.
- **The owl** sits on a post that is only 0.3 m deep in W, at w +1.5: invisible from the
  farm's slice, right outside the window at focus +1.5. Its head can turn **through W**
  (zw rotation): the face slides out of your slice and the head stays a round blank,
  because a ball's slice is a disc whichever way it turns.
- **The ride** is a rail in (x, y, z, w). The camera's slice rides with the basket, so as
  the balloon drifts ana the farm thins and goes "not because anything moved but because
  you did", and the marsh comes up out of nothing.
- **The reeds** in the marsh each stand at their own w, so sliding through the marsh (on foot
  or with the ring) they come and go one by one.
- **The cab is a closed 4D room** (eight walls, the W walls with windows), so the slice
  can be turned a quarter through W and you are still in a room, looking out along W.

## What changed from the plan, and why

1. **The cab is 6.4 m deep in W, not 4.** The focus ring slides up to 3 m; a cab ending at
   2 m vanished round you halfway along it.
2. **The ana post is at w +1.5, not +2.6,** inside the cab's W depth, so the cab frames it.
3. **Zoom goes through `field_of_view_4d`.** Under the default `PERSPECTIVE_4D` projection
   the renderer takes the 3D camera's angle from the 4D field of view; `field_of_view_3d`
   is ignored. (See trap 1.)
4. **The owl and heron are thick in W** (balls stretched 2.2-2.4x along W), or the ring would
   find them over a few centimetres.
5. **The heron's neck is three rigid lofted segments on pivots.** Re-lofting a neck every
   frame would cost milliseconds.
6. **The balloon is moored on the ground beside the tower**, not at the deck; the departure
   is the burner, the tether dropping and the ground falling away, not a separate cutscene.
7. **A secret wins the photo**: the white starling in a picture of five thousand starlings is
   a photo of the white starling.
8. **The whistle startles the nearest starlings**, so it sends a wave through the flock on
   demand (the "turning wave" photo). Not in the plan.
9. **The cab eye goes to the wall you face**, never into a corner; a diagonal long-lens view
   was a close-up of a corner post.
10. **No door leaf**: folded back, it covered a pane from outside.
11. **The Journal card goes beside the Cinematics card** when the right column runs out of
    room (1280x720 at 125% UI). At 2560x1440 it sits under it.
12. **Tower, marsh: one mesh per colour** (159 nodes to 12). See "Cost".

## Cost (RTX 5080, 1280x720, after the pen's own warm-up)

Round two:

| | pen alone | with the Lookout |
|---|---|---|
| scripts | 4.3 ms | 4.8 ms |
| render CPU | 0.48 ms | 0.55 ms |
| render GPU | 1.55 ms | 1.7 ms |
| video memory | 710 MB | 734 MB (751 with the balloon up) |

Round three (owl tree, marsh, kata wood, chipmunks, hawk, overlays), spawn point:

| | pen alone | with the Lookout |
|---|---|---|
| scripts, A/B on the field | | +0.06 ms (method floor about 0.06) |
| scripts, A/B in the balloon over the flock, camera up | | +0.18 ms |
| the viewfinder's own draw | | 0.17 ms a frame (F4 shows it; `draw_usec`) |
| render CPU | 0.47 ms | 0.64 ms |
| render GPU | 1.54 ms | 1.92 ms |
| video memory | 710 MB | 871 MB |
| tetrahedra | 227k | +101k (wood 33k, marsh 23k, balloon 13k, owl tree 11k, tower 7.5k, heron 7.4k) |

The scripts' A/B is `_measure_ab_runner.gd` (see trap 11); geometry is
`_count_cells_runner.gd` (headless). The render and memory growth is the new lofted geometry;
it was 135k tetrahedra before the trees were trimmed (one twig a limb, six-sided trunks,
two-ball leaf clumps, fewer ring segments).

In the cab and the basket the frame is cheaper than at the spawn (less of the farm in view).
Three fixes got it there from ~2 ms extra: a cached current camera (a whole-tree search every
frame was 2.5 ms on its own), the owl and heron posing only when a camera could see them, and
the merged meshes.

## Traps found

1. **`Camera4D.field_of_view_3d` does nothing under the default projection.** `projection_type`
   defaults to `PERSPECTIVE_4D`, and then `godot_3d_rendering_engine_4d.cpp _update_3d_camera`
   uses `field_of_view_4d` (default 77.3°). FIXED for the pen camera in round three, keeping the
   look (Ramon: "keep the actual look and distance ... adjust incorrect numbers"): the orbit
   rig's presets all say 77.3 and set `field_of_view_4d`, the scene's dead 55° line is gone,
   and the minimap wedge reads the real angle with its narrowing cut 0.76 -> 0.59 so it draws
   the same width. Still set on the dead property, not touched: the cinematics
   (`cave_dreamer_cinema_4d.gd`, `cinematic_murmuration_4d.gd`), `cave/cave_far.tscn` and three
   capture runners.
2. **The pen's inventory belt takes the number keys in `_input`**, before any dialogue. FIXED in
   round three: it steps aside while any `npc_talk` conversation is running.
3. **A GDScript setter must store its own value.** `pen_range_master_4d.gd` FIXED in round three
   (one setter each). `cave/cave_suit_4d.gd` has the same pattern (`func _set_colour(_v)`), not
   touched.
4. **Godot smooths the frame delta**: 240 deltas came back identical. Measure with
   `viewport_get_measured_render_time_cpu/gpu` and `Performance.TIME_PROCESS`. The pen also
   has a ~10 s warm-up (14 ms of scripts) before it settles.
5. **`find_children` over the pen every frame costs milliseconds.**
6. **`TetraMesh4D.to_array_tetra_mesh()` + `ArrayTetraMesh4D.merge_with(other, offset, basis)`**
   merge static boxes into one mesh per colour; it is the cheap way to build anything big.
7. **A Control under a CanvasLayer can lay out to zero size on its first frames**: draw with
   `get_viewport_rect().size`.
8. **Don't name a method `_set`**: it is Object's virtual.
9. **A runner killed by `timeout` leaves its test journal behind**: the runners clean at start.
10. **Under the movie writer, `Engine.time_scale` slow motion records as slow motion**; a timer
    meant in real seconds divides by the time scale.
11. **`Performance.TIME_PROCESS` lies in two ways.** It is coarse (90 frames in a row can read
    the same value), and the pen's own scripts swing between about 4 and 15 ms over a minute.
    The balloon numbers of `_measure_lookout_runner.gd` (10 to 23 ms) were that swing, not the
    Lookout. An interleaved A/B is the only honest number, and even that needs a settle after
    any set-up (toggling an EMPTY node "cost" 1.8 ms until the first block stopped landing on
    the boarding) and an on/off/off/on order.
12. **The Combined renderer draws its cut into a SubViewport two deep**
    (`CombinedProjectedSubViewport4D/CombinedCrossSectionSubViewport4D`). Anything that puts its
    own 3D instances into the cut's World3D (the flock) has to look there. And its projection
    pass only covers 4D meshes, so the flock draws its own ghost (`flock_ghost.gdshader`).
13. **Switching a live camera between Cross-section and Combined works now** (Aaron's
    world-restore fix, 4d `da3586b`, in the 1 Oct build): the menu crash of 30 Sept is gone for
    this path.
14. **A cutscene that starts while the camera is raised** used to leave the pen's HUD hidden for
    good (both saved and restored it, in the wrong order). The camera, and the hawk, now come
    down before a cutscene takes the HUD.

## Still your call

- **Moving it into `chickenpen.tscn`** (your word).
- **Wren's lines** (`wren_script.gd`) and the radio lines (`lookout_story_4d.gd`,
  `balloon_4d.gd` RADIO): written in her voice, no dashes; yours to rewrite.
- **Tuning**: balloon after the owl and 8 photos; heron flushes at 8 m; 24 a roll in the cab,
  36 in the basket; the focus ring's 3 m; the white starling is bird 2731.
- **The approach plays once per journal.** A fresh journal (Ctrl+Backspace twice) replays
  the whole story.
- **"Above the hawk"** (the hawk page's fourth star) needs the balloon to pass above the hawk;
  it can happen but is rare.

## Round two (2 Oct, from Ramon's first play)

- **Camera mode made obvious**: the viewfinder matte, the strip, two pen-style cards (metrics,
  keys). **Zoom made obvious**: the W-T bar, the big readout and the shrinking frame (from
  camcorder W-T bars, DJI's focal-length bar and its 1/2/4/7/14/28x stops).
- **The camera anywhere** (Z), walking in first person. E and Q's ana/kata bindings are lifted
  out of the InputMap while it is up and put back when it comes down (and if the scene goes).
- **The balcony** from Ramon's reference photo, walkable, colliders for boards, rails, both W
  ends and the cabin; the cab kept as a design option. The owl moved 5 m out.
- **The HUD card lists every way in** (Z J B F); **B boards the balloon** from anywhere.
- **The card is only there at the Lookout** (Ramon, 2 Oct: "tower subgame should change the hud,
  but it should never carry over"): within 18 m of the tower (and the marsh, and the wood, in
  their own w), or with the camera raised, on the balloon ride or in a cutscene; it fades out
  as you walk off and folds to no height so the camera picker moves back up. Z away from it no
  longer gets Wren's "Not down here" line. The keys themselves (J, B, U, P, F4) still work
  anywhere: asked Ramon whether they should be held to the Lookout too.
  `lookout/_verify_card_local_runner.gd` checks it.
- **V at the marsh: align to the slice** (Ramon, 3 Oct: "when you reach the marsh, can we
  create a button there that says, align to slice? so we can see it properly"). The marsh is
  at w +8 and only a few metres thick in W, so a little off its w, or with the slice turned,
  the cut takes a sliver of it. Within 14 m of it and 3.5 m of its w, on foot, a tag over the
  pond says "V  align to the slice" (and the card has a V row); V eases the slice flat and you
  to its w, as R does for the pen's (the rig's new `align_to(w)`, the same trip as
  `go_home`). `lookout/_verify_marsh_align_runner.gd` checks it.
- **The pond is round** (discs of turned boxes); the heron dressed from field guides (brow,
  plumes, two lines of neck streaks, black flanks over white thighs, darker grey) with round
  joints in the neck and at the heels - it had looked broken at the bends. The owl is an
  eagle owl (orange eyes, tufts), so its page says Bubo. Both stand idle in the showcase
  (`idle_only`).
- **Talking with the camera up** lowers it first; the pen's "F talk" tags follow the raised
  camera.
- Fixed on the way: bars along x or z were built flat (a degenerate frame, 22 errors a load);
  a killed runner left its journal behind (runners now clean at the start too).
- Still for a dedicated session (Ramon): the heron's animation and the marsh's look.

## Round three (2 Oct, evening)

Ramon: "make the suggested changes", the projection, a lens toggle, a round pond from real
shapes, the heron's feet, a proper study of how it moves, the owl in a dead tree, a tree with
chipmunks, fly as a hawk, keep the pen camera's look but make its numbers true. Film:
`smoke_test_output/video/The Lookout, round 3.mp4` (77 s, `_film_round3_runner.gd`).

- **P, the projection**, anywhere: the current camera goes to the Combined renderer (the cut,
  plus a see-through projection of everything along W, tinted ana/kata). The marsh shows as a
  ghost from the farm. The flock draws its own ghost of the birds off your slice.
  `projection_opacity` 0.55 and `projection_opacity_base` 0.05 on the Lookout node.
- **L, the lens primes**: 18, 24, 35, 50, 85, 135, 200 mm (Shift+L back), each with its angle;
  the zoom bar is marked in mm. The widest is now exactly 18 mm (`wide_fov` 1.176).
- **U, fly as the hawk** (`hawk_flight_4d.gd`): the flock's own sparrowhawk handed to you
  (`pen_flock_4d.gd pilot_hawk / fly_hawk`), so the starlings flee and roll by their own rules.
  Mouse steers, W flaps, S brakes, Space climbs, Shift stoops (24 m/s measured), E/Q slide
  through W: 2.5 m ana and you are out of their slice and they stop fleeing. Chase camera, its
  own HUD cards, an arrow to the flock.
- **F4, the developer overlay** (`lookout_dev_overlay_4d.gd`): each creature's whole extent
  (dashed), the part the slice cuts (solid), a W gauge, its numbers; a card with the camera's
  four coordinates, the slice normal and angles, the renderer, the frame.
- **Judging shown**: four bars on every photo toast (size, in focus, centred, behaviour), and
  **the roll**, a last page in the journal with every shot this time out and its bars.
- **A guided first photo**: Wren asks to be first and gets a pulsing frame; the owl's tick
  pulses on the W-meter until it is found (and secret names show as "?" on the meter).
- **The balloon**: Space works the burner (+10 m over the rail, -5 under it, never under 3 m
  over the ground, none of it near take-off and landing); at 70 s **the fork**: wherever the
  focus ring points (kata below -0.3) the ride goes ana to the marsh or kata to the wood.
- **The owl's dead tree** (`lookout_tree_4d.gd`): lofted, one merged mesh, its twig exactly
  where the post's top was. The post is off (`ana_post`).
- **The kata wood** (`kata_wood_4d.gd`) at w -8 over the same field as the marsh: four lofted
  trees, a log, litter, mushrooms, ferns, a burrow; **three chipmunks** (`chipmunk_4d.gd`):
  forage in dashes, sit up, stuff their cheeks, climb, perch, come down head first, and run
  round the trunk THROUGH W (the trunk is round in W too, `w_scale` 0.85), leaving your slice
  halfway round. A fourth secret page; the hint "The marsh is ana. What is kata of it?"
- **The heron** rebuilt from `follow_up/heron_motion_study.md`: legs trailing in flight,
  crouch-and-jump take-off, braking landing, planted-foot IK wading with a gliding head, a coiled
  strike, a swallowed fish.
- **The marsh**: real cubinder discs (pond, shallows band, mud, stones, tussocks), a lofted
  snag, reeds swaying in clumps, rings on the water (where the heron steps and stabs, too),
  glints. The 4D material has only a colour, so water is told by motion.
- **Pen fixes** (asked for): the pen camera's numbers (trap 1), the belt and dialogue numbers
  (trap 2), the range master's colours (trap 3).
- **Showcase**: an idle chipmunk beside the owl and heron.
- **Runners**: lookout 29, story 25, ride (ana, and `-- branch=kata`), extras white/marsh/
  showcase, hawk, round3 capture all pass; pen regressions (flock, cave, crossing, scenery
  release, UI scale, laptop, cinematics card, menu final) all pass.
- Open: trees are a first design (Ramon: "trees is still an issue to design"); the chipmunks
  have no sound; the kata wood is reached on foot by eight metres of Q.

Later the same evening, from Ramon watching the film:
- **The hawk is flown from its eyes**, with the hawk seen only in a 3 s intro (it comes in over
  you, the camera swoops into its eyes; a click skips). The flock hides its drawn hawk while
  you are inside it (`hawk_hidden`).
- **The owl's head is a real ball**: a two-ball loft is a short tilted lozenge (each end gets a
  cone half a radius deep, `loft_builder_4d.gd`), and the face had stood in front of it with a
  gap. Five sections up a circle, squashed front to back; the face halves sit on it.
- **No sticks in the air under the deck**: the twelve knee braces and the two ladder "hoops"
  met nothing and are gone.
- **The chipmunks climb on the bark**: the loft collapses a chain's END sections to points, so
  the trunk was half as thick near the ground as the radius they climbed against. The trunk's
  first ball is buried now, and `trunk_radius_at` follows the real surface (6 mm off the bark).
- **Measured on a real ride**: ridden into the flock rather than dropped into it, scripts are
  3.0 ms. Every "spike" in `_measure_lookout_runner.gd` came straight after one of its own
  jumps of the ride time (`-- natural` rides in instead).

And after that:
- **The camera is the lookout's** (Ramon chose "tower and balloon only"): Z raises it only on
  the deck; on the ground Wren says it's for up there; it comes down if you leave the deck.
  The first guided photo is Wren from the south rail. Round two's "Z anywhere" was my reading
  of his notes, not his ask.
- **One node moves the whole Lookout**: `World/LookoutSite` holds the tower, Wren and three
  markers (MooringSpot, MarshSpot, WoodSpot); the owl's tree, the balloon, the marsh, the wood
  and their creatures are built from it, turned with it, and the balloon's ride turns with
  it (`_verify_site_runner.gd` moves it 17 m and a quarter turn and checks it all). Keep the
  marsh and wood inside the pen's 46 m bounds, and the tower on level ground.
- **What each piece costs** (`_measure_pieces_runner.gd`, after the warm-up):

| piece | video memory | GPU | render CPU |
|---|---|---|---|
| the kata wood | 43.2 MB | +0.065 ms | +0.016 ms |
| the marsh | 24.8 MB | +0.024 ms | +0.029 ms |
| the balloon | 17.1 MB | +0.015 ms | +0.024 ms |
| the owl's tree | 13.4 MB | +0.023 ms | 0 |
| the tower | 9.2 MB | +0.011 ms | +0.009 ms |
| the heron | 9.1 MB | +0.024 ms | +0.036 ms |
| the chipmunks | 8.1 MB | +0.025 ms | +0.054 ms |
| the owl | 6.2 MB | +0.019 ms | +0.021 ms |
| Wren | 1.6 MB | +0.012 ms | +0.016 ms |

  About 1.3 KB of video memory a tetrahedron. If memory matters, the wood and the marsh could
  be built only when someone heads their way (68 MB until then).
