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
| **Z** | Camera | raises it anywhere once Wren has given it to you; Z or Esc lowers it |
| **J** | Field journal | the book, on the ground, on the deck or in the balloon |
| **B** | Balloon | once it is up beside the tower: straight up, from anywhere on the farm |
| **F** | Climb | at the ladder; on the deck, at the gap in the rail, climbs down |

- Walk towards the tower: a short camera move up it ("The Lookout") and down onto **Wren**.
  **F** to talk to her: she gives you her camera. (Replies: Up/Down and Space. The number
  keys never reach the dialogue in the pen - the inventory belt takes 1-5 first.)
- **Camera up** (Z, or after the climb): you walk as ever with WASD, the view at your eyes,
  and the viewfinder says it is a camera - a matte top and bottom, frame corners, the mode and
  the film in the top strip, and two of the pen's own cards over it: the **metrics** (the
  slice offset, the lens, what is in your slice and how much of it, how a photo is judged)
  and **every key** the camera has right now, F's current job lit at the top. F3 hides both.
  - **wheel** zooms, 19 mm to 222 mm: a W-T bar up the right with stops at 1 2 4 8 12x,
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

| | pen alone | with the Lookout |
|---|---|---|
| scripts | 4.3 ms | 4.8 ms |
| render CPU | 0.48 ms | 0.55 ms |
| render GPU | 1.55 ms | 1.7 ms |
| video memory | 710 MB | 734 MB (751 with the balloon up) |

In the cab and the basket the frame is cheaper than at the spawn (less of the farm in view).
Three fixes got it there from ~2 ms extra: a cached current camera (a whole-tree search every
frame was 2.5 ms on its own), the owl and heron posing only when a camera could see them, and
the merged meshes.

## Traps found

1. **`Camera4D.field_of_view_3d` does nothing under the default projection.** `projection_type`
   defaults to `PERSPECTIVE_4D`, and then `godot_3d_rendering_engine_4d.cpp _update_3d_camera`
   uses `field_of_view_4d` (default 77°). So the pen's camera (set to 55° 3D) and the cinematic's
   camera actually draw at 77°. Your call whether the pen should be 55° (set the 4D one).
2. **The pen's inventory belt takes the number keys in `_input`**, before any dialogue: reply
   choices by number never work in the pen. Arrows and Space do.
3. **A GDScript setter must store its own value.** `pen_range_master_4d.gd`'s
   `set = _set_colour` with `func _set_colour(_v)` never stores it, so inspector edits of the
   range master's colours are ignored. Not touched.
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

## Still your call

- **Moving it into `chickenpen.tscn`** (your word).
- **Wren's lines** (`wren_script.gd`) and the radio lines (`lookout_story_4d.gd`,
  `balloon_4d.gd` RADIO): written in her voice, no dashes; yours to rewrite.
- **Tuning**: balloon after the owl and 8 photos; heron flushes at 8 m; 24 a roll in the cab,
  36 in the basket; the focus ring's 3 m; the white starling is bird 2731.
- **The pen camera's FOV** (trap 1).
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
