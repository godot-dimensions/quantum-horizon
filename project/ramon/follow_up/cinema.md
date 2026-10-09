# The cinema (theatre), 9 to 10 Oct 2026

`res://ramon/chickenpen/theatre/theatre.tscn`, the room behind Trym's door: one presentation of nine
slides (I to VI in `theatre_show_4d.gd` and `theatre_primer_4d.gd`, VII to IX in
`theatre_part_two_4d.gd`). Worked on **in place** (Ramon, 9 Oct, asked: in place, not a fork); the
start point is the local branch `theatre-before-2026-10-09`.

## Questions for Ramon

1. **Anti-aliasing.** The cinema renders with no anti-aliasing, so every edge is stair-stepped
   (the ball's cut, the wire rings, the seats). That is part of what reads as "low resolution". MSAA
   on the window's viewport while you are in the cinema (set on the way in, put back on the way out)
   smooths it: measured on slide I, GPU 0.30 ms off, 0.39 at 4x, 0.45 at 8x, and the frame time does
   not move (it is CPU-bound, 2.0 ms). Side by side: `smoke_test_output/theatre_perf/msaa_off.png`,
   `msaa_4x.png`, `msaa_8x.png` (`scripts/_compare_msaa_runner.gd`). It changes the look of the whole
   room, so it is your call, not done. 4x is the one I would pick.
2. **Tempo** (Trym: "lots of text and lots to digest, so pacing will be important ... we can adjust
   that over the coming week"). Not touched. The knobs: `act_seconds` (16 s) on Show, each slide's
   `pace`, `moment_seconds` (17 s) on PartTwo.
3. **Slide VII's figures** say "nine Godot prototypes" and "2 of 4 of us are not engine
   programmers" (`theatre_part_two_4d.gd`, MOMENTS[0]). The menu now shows four labs and three
   experiments. Update the numbers?
4. **Spaced dashes** in player-facing lines, against your rule: the bodies of VII, VIII and IX, and
   Trym's closing line "The way out is behind you - mind the step". Not changed; say if you want
   them rewritten.
5. The hands are a warm skin tone with the thumb gold (Trym liked "the reference and the yellow
   highlight", so the gold thumb and the gold LEFT label stay). Colour, size (2.5 m tall on the drum)
   and pose are all in `theatre_hand_4d.gd`; say if they want a different look.

## What changed (10 Oct)

Trym's notes on the cinema, and Ramon's "work out optimization, and build/load at clever moments".

### Controls on V and VI (Trym: left drag 3D, right drag 4D)

- `theatre_primer_4d.gd`: on the two hands-on slides a **left drag turns the object in 3D** (sideways
  about the vertical, up and down about the picture's sideways axis) and a **right drag turns it
  through W** (sideways in the plane of the picture's sideways and W, up and down in depth and W).
  Both are about the axes of the picture, whatever angle the drum stands at, and compose like a hand
  on an object (each turn laid on top of the last, squared up every time). A clean left click still
  moves the talk on; the wheel still changes shape on V.
- VI: the left hand turns in 3D freely and stays a left hand; it becomes a right hand exactly when
  its own W axis points the other way (`_check_glove`), wherever the 3D turns have left it. Once it
  matches, W is locked (it stays a right hand) and 3D stays free, so it can be turned to sit against
  the reference. Turned for you past 58% of the slide if nobody does.
- Captions and the on-stage labels say so (no dashes).

### Lofted hands for VI (Trym: "a lofted hand model instead of the cube looking Claude one")

- `theatre_hand_4d.gd`: a palm, the ball of the thumb, four fingers and a thumb, each a chain of
  round sections, lofted with the pen's own `loft_builder_4d.gd`. **Proportions from human data**:
  bone lengths are the means of 66 adult hands on X-ray (Buryanov and Kotiuk, "Proportions of hand
  segments", Int. J. Morphol. 28(3) 2010, https://scielo.conicyt.cl/pdf/ijmorphol/v28n3/art15.pdf);
  breadth and thickness from hand anthropometry; the pose from the artists' rules (knuckle arc with
  the middle highest, fingers fanning, thumb off the palm's corner on a diagonal). Sources for those:
  Clip Studio's hand tutorials and David Rickert's anatomy notes.
- **It must not be flat.** A flat hand can be turned over in 3D into the other hand, so with 3D
  turning added the old box glove would have "proved" nothing. The fingers curl a little towards the
  palm, the thumb comes forward, the ball of the thumb stands out on the palm side.
- **As deep in W as it is thick, centred on w = 0**, so half a turn in a plane with W is a mirror.
  The right hand is the left one mirrored before lofting (not the left one turned).
- About 25,600 tetrahedra a hand (skin 20,128, thumb 2,560, cuff 2,912); about 0.35 s to loft, done on
  the cinema's worker thread with the shapes. Every loft checked sound (watertight, no folds, no
  slivers): `scripts/_capture_hands_runner.gd` prints the checks and photographs the hands turned in
  3D and through W (`smoke_test_output/theatre_hands/`).

### Slide I: the frame-rate drop and the "low resolution" ball

- **The drop was not the ball.** Fourteen seconds after the room opens, part two built its goat, and
  the goat's bake on disk was never found (next section), so it lofted live: twelve frames of 170 to
  525 ms, then the creature at 457 ms, right on the ball's pass through the sheet.
- **The ball's cut** was 26 flat strips, stepped round its edge; it is one round disc now (48 sides),
  resized by its basis each frame. The cone keeps its strips (its cut is a different curve at every
  distance).

### Optimisation: frame by frame, the whole talk

Measured with `scripts/_measure_talk_frames_runner.gd` (every frame's time and GPU time, labelled by
slide and tenth of a slide, spikes listed with what had just happened; windowed, vsync off;
`via=pen` goes in through the door). 1920x1080, this machine (RTX 5080).

| | first measured, 10 Oct | now |
|---|---|---|
| frames over 25 ms, arrival and slide I | 16, worst 616 ms | 1 (52 ms, on the still beat in the chair) |
| frames over 25 ms, whole talk | 14 with only the goat fixed (not measured before it) | the same 1 |
| slide I, typical frame | 4.3 ms | 2.0 ms |
| the door from the pen | | 14 ms, first frame in the room 6 ms |

What did it:

1. **The goat's bake was never read.** `theatre_goat_4d.gd` checked for `goat.cfg` with
   `ResourceLoader.exists`, which answers only for files a resource loader recognises; a `.cfg` is not
   one, so it said false from the day the bake was made (24 Sept). Now `FileAccess.file_exists`. Its
   twelve stages load in 3 ms; the stage files came out byte-identical when re-baked, so the bake was
   right all along. The adopted rig's own script is taken off before it enters the tree, so it does
   not loft itself either; the coat is painted from the colours the bake carries.
2. **Bakes for the creature and the rock**, the goat's pattern: the creature's 42 segments
   (`baked/creature_seg_*.res`, was 457 ms of lofting) and the carved rock (`baked/rock.res`, was
   620 ms of contouring on the still beat). Each bake carries a **fingerprint** of what it was made
   from (`theatre_bake_4d.gd`): every stored property of the loft rigs and handles, and the scripts
   that make the mesh. Edit the goat or the creature in the Model scenes, or the rock's recipe, and
   the cinema builds that exhibit live (correct, slow) until the bake is re-run.
   **Re-bake: `scripts/_bake_cinema_runner.gd`** (headless; `-- only=goat|creature|rock`).
3. **The two Model scenes load on a thread** from the moment the room opens (`load_threaded_request`
   in part two's `_ready`): loading them was 112 and 116 ms, the adoption itself 16 and 52.
4. **Part two builds on the still beat**, straight after part one's exhibits (when you land in the
   chair and the camera holds), not 14 s in, which was the middle of slide I.
5. **First draws, on a worker.** A mesh's draw buffers are built the first time it is drawn: the goat
   cost 54 ms on VII's first frame, the creature 62 on IX's, each of the goat's stages 16 to 58 ms as
   VIII played them, the rock 27 on III's. `Bake.warm` builds them on a WorkerThreadPool task as soon
   as the exhibits exist, and the slides wait for it before showing them (it is long done).
6. **The 2D overlays.** Slide I's see-through pane was 216 polygons a frame with every grid point put
   through the camera: 1.55 ms. Now one triangle array mapped from four projected corners (a flat
   sheet in perspective is a homography; checked against the camera, 0.000 px apart,
   `scripts/_verify_pane_runner.gd`), and redrawn only when the shot moves. The caption band
   re-wrapped its text word by word every frame on every slide: 1.1 ms. Now it redraws only while it
   fades in or when its words or the window change.

What is left: the creature's adoption, 52 ms, on the still beat in the chair (its 84 handle balls
build their wire previews, and its six solvers start). Slide I is 2.0 ms against 1.5 ms in the chair:
the sheet shot simply sees more of the room.

Probes: `_measure_slide1_parts_runner.gd` (slide I with each part switched off in turn),
`_probe_theatre_objects_runner.gd` (what is drawn, by branch), `_probe_adopt_cost_runner.gd`,
`_probe_goat_bake_runner.gd`.

## Checked

- By eye: every slide captured (`scripts/_capture_talk_runner.gd`, now also a frame of the whole goat
  early in VII), the hands from eleven turns (`_capture_hands_runner.gd`), the ball's disc close up.
  The goat, creature and rock from their bakes look as they did built live (the goat in its coat).
- Tests, headless: primer (16 checks, with the new 3D/4D drag and hand checks), shapes, theatre, part
  two, goat, release, resit, seat, after show, impatient all pass. The presenter runner keeps its one
  known older failure ("he moves in for the demonstration", listed on 1 Oct).

## Not done

- MSAA (question 1). Tempo (question 2).
- The pen itself was not touched. While measuring through the door, the pen threw a script error at
  load from `chickenpen/discovery/dream_shifter/pen_look_guide_4d.gd:458` (`_prompt` is null in
  `reset()`); that folder is untracked, so it is another window's work in progress.
