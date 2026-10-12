# Quantum Range, final: plan and handover (5 Oct 2026)

Called **Shooting Range** in the game since 6 Oct; the folder, files and this document keep the
QuantumRange name.

The consolidated shooting range: `res://ramon/QuantumRange/quantum_range_final.tscn`.

It is a new scene. Neither old range is changed:

- Trym's `sandbox/shooting_gallery/shooting_gallery.tscn` stays as it is.
- Ramon's `ShootingGalleryRamon/shooting_gallery_ramon.tscn` stays as it is.
- **The final menu opens this range** (Ramon, 5 Oct evening: "connect the new range to the
  final menu"). Its Quantum Range entry points here and plays a new clip.
- **So does the pen's range trip** (Ramon: "yes it should sent to the new range"). The one-line
  change is in `chickenpen/scripts/pen_range_trip_4d.gd` (`gallery_path`), left uncommitted
  because the pen is not this window's to commit.

The study of the two old ranges is in `quantum_range.md`.

## Status (5 Oct, evening)

**All 75 steps done.** Five experiments of four stages each, the target gallery, both walls,
the console, the dev views, the flying chickens. A test bot plays every stage to the end
(`_play_runner.gd`: 5 of 5 pass). The two old ranges still load and run unchanged
(`_regress_runner.gd`).

**To open it:** open `res://ramon/QuantumRange/quantum_range_final.tscn` and press F6. You
start in the entrance corridor; walk through the door to the counter. The console is on your
left: shoot a number or press 1 to 5, then START or F.

**Measured** (windowed, vsync off, RTX 5080, `_perf_runner.gd`):

| What | Cost |
|---|---|
| Opening the scene | 329 ms |
| Baking every target shape (first gallery or first use) | 285 ms, once |
| A frame in any stage | 1.28 to 1.51 ms (median), worst 1.78 ms |
| A frame in the target gallery (12 families) | 2.18 ms, worst 2.33 ms |
| GPU per frame | 0.20 to 0.34 ms |
| All target shapes together | 27,552 tetrahedra |
| One 4D raycast | 13 to 17 µs |

Nothing came near the 8 ms budget, so step 65 had nothing to fix.

**Frames:** `smoke_test_output/quantum_range/` holds `room/`, `moments/`, `play/` and
`gallery/`. The films are in `smoke_test_output/video/`: the bot playing each experiment from the
first card to the results, at 30 fps (`range_locate.avi` 18 s, `range_charge.avi` 41 s,
`range_reveal.avi` 24 s, `range_incoming.avi` 80 s, `range_skeet.avi` 29 s; MJPEG, 75 to 320 MB).

## 6 Oct: after Ramon played it

**The console** (`scripts/range_console_4d.gd`):

- **Look.** A floating panel in the kit's desk style: a light rounded plate, black glass, a
  glow line under it, tilted up at you. The tiles are the old size and shape, one per
  experiment, plus START. A sixth experiment widened the glass from 1.9 to 2.19 m.
- **Where it is.** It waits in the middle of the bay facing you as you come in. Once you start
  something it flies to beside you (right, a little ahead) and keeps facing you. It moves again
  only when you walk off, never as you look round. During a stage it tucks back and down out of
  view.
- **Picking.** By where your aim crosses the glass (`pick()`), not by physics: the physics is
  box-only and cannot pick a turned panel. During a stage shots pass through it.

**Choosing:**

- 1 to 6 picks an experiment. The same number again, or the same tile shot again, steps its
  stage A to D. START plays from that stage.
- Nothing is locked or "not yet" anywhere. A finished experiment carries a small green
  stopwatch and its best (whole runs from A only).

**The walls:**

- The explainer and metrics are the bay's own side walls, 13 m long and blue edge to edge,
  ending at the counter.
- The bay is 18 m wide, so they stand 9 m from its middle, as far as the Creation Lab's walls
  from its exhibit. The type on the panels was already identical; only the distance differed
  (measured: `scripts/_compare_walls_runner.gd`).
- Where the bay meets the wider hall, a white bar half a metre past the line ends each blue
  wall. The kit room copy gained `edge_ends` so the blue stops inside it.
- The skirting at the foot of the walls is a grey a little darker than the walls (it was cyan).

**Other changes:**

- **Escape:** frees the mouse, and a second Escape quits (as in the pen); F1 first, if it is
  open.
- **The slice:** the room stays sliceable by default. F1 "Room ignores the slice" turns the
  room's visible pieces with your slice so it looks still. Their collision stays where it was.
- **The chickens** fly properly (`targets/target_chicken.gd`):
  - Their wings spread (the model's wing is the folded one) and beat fast and unevenly.
  - The body heaves and climbs nose-up, the head stays level, and the legs tuck.
  - Shot, a bird tumbles out of the air instead of freezing.
  - Filmed by `scripts/_chicken_lab_runner.gd`.

### 06 Wolf Run

Track and intercept, the way of playing the other five did not have
(`experiments/exp_wolf.gd`):

| Stage | What happens |
|---|---|
| A **On the run** | One wolf at a time curves across the range. Tag the red collar. |
| B **Out of the slice** | Wolves leap two bars in your slice, then take a far leg out through W past your two metres. |
| C **The pack** | Three run abreast and cross over. Only the red collar counts; a green one is a penalty. |
| D **The chase** | A wolf after a running chicken. Tag it before it catches the bird; hitting the bird is a penalty. |

A wolf you do not tag runs its route again, so a stage ends when every red collar is tagged.
The results add "Chickens saved".

**The wolf** (`scripts/range_wolf.gd`, `targets/target_wolf.gd`) is the pen's wolf, built from
its ball numbers but cut finer than either the pen's or the Creation Lab's:

- **Pieces.** Two body halves that flex at the barrel; the head on a neck joint with a lower jaw
  that opens; ears, eyes, a two-piece tail; each leg upper and lower. 90 ms to loft once, shared
  by every wolf; after that everything moves by transform only.
- **Gait.** A rotary gallop: the hind pair, then the fore pair, then the gathered suspension,
  about 2.3 strides a second at 6.5 m/s. Each foot is planted by a two-joint solve, so nothing
  skates. Below 4.2 m/s it trots on diagonal pairs.
- **Leap.** It gathers, flies a true arc (forelegs tucked then reaching, hind legs back), and
  lands front first.
- **Catch.** It closes faster than the bird, pounces from about two metres at where the bird
  will be, and snaps the jaw shut. Then it lifts its head and shakes, stands a moment, and
  lopes off with the bird struggling in its jaws.
- **Size.** 1.6 times the pen's, so it reads across the range.
- **Filmed** by `scripts/_wolf_lab_runner.gd` (gallop, trot, leap, catch, and a hitbox check:
  9 of 10 single shots at running wolves tag them).
- **Console and gallery.** Its tile on the console has the kit's wolf glyph; F2 shows one
  standing.

**The menu clip** was filmed again (9.97 s): ring gate, shell, two chickens, and a wolf tagged in
mid-leap over a bar.

**The pen's trip** (`chickenpen/scripts/pen_range_trip_4d.gd`, one line, left uncommitted for the
pen's window): the range master now sends you here.

## Questions for Ramon

Each was settled during the run with the most reversible option, and the run carried on.

1. **The pen's own range runner.** The pen's range master sends you here now. But
   `chickenpen/scripts/_verify_range_runner.gd` still names the old gallery in its `GALLERY`
   constant, so its "yes opens the shooting gallery" check now fails. I did not touch it. The
   same checks pass against this range in `scripts/_verify_pen_trip_runner.gd` (18 of 18).
2. **The slice and the room.** The room stays sliceable (my recommendation, 6 Oct). Its walls
   sliding is the plainest cue of how far you have turned, and the game will be like that.
   F1 "Room ignores the slice" freezes it so you can compare (section "6 Oct" below).
3. **The spot.** At energy 12 it reads as a bright pool on the floor between you and the
   targets, in daylight. F1 has it (Spot, Spot cone); SAVE keeps your numbers.
4. **Bests from my test runs.** The bot's times were being saved as your bests in
   `user://quantum_range.cfg` until I stopped it. I moved that file aside to
   `quantum_range_bot_runs.cfg` in the same folder (`%APPDATA%/Godot/app_userdata/Quantum
   Horizon Main Godot Project/`) rather than delete it. Delete it when you like. The runners no
   longer save bests (`keep_bests`).
5. **The kit is a copy.** `QuantumRange/carried/` holds copies of the Creation Lab kit and
   the chicken, so nothing in `CreationLab/` or `chickenpen/` changed. Point the range at the
   shared kit once the kit settles?
6. **Which idea next?** Experiment 06 is now Wolf Run. The other ideas in section 6 are still
   ideas only.
7. **The radar's size.** It is your radar's size, forked, and takes the bottom third of the
   view. It reads well, but a smaller one would show more of the floor lanes in Incoming.
8. **The chicken's neck** prints a loft warning (22 of 2,300 tetrahedra fold inwards) the
   first time a chicken is baked. It comes with the carried rig and does not show at range
   distance; I left the rig as it is.
9. **The menu card.** The range is called **Shooting Range** now (Ramon, 6 Oct): the sign over
   the door, the explainer wall's title (and so the metrics wall's header) and the HUD. The folder
   and the files keep their QuantumRange names, so nothing that points at them breaks. The
   catalogue is shared, so its card still says "Quantum Range" and "Five experiments". It would
   read: title "Shooting Range"; detail "... Six experiments of four stages each, from finding a
   core in w to tagging a wolf that runs out of your slice."

---

## 1. Assessment: redesign or clearer rules?

**The mechanics are sound; the structure and the look are what fail.** Both versions already
have the hard part:

- **The core loop:** real 4D raycasts against 4D colliders, independent of the camera.
- **The locator:** a radar that shows W as a stem, which Ramon says works well.
- **The alignment glow:** an edge glow when the target crosses your slice.
- **Trym's additions:** contest sequences, W-targeting that turns your slice onto a target, and
  a projectile you have to lead.
- **Ramon's additions:** a charge shot with a commit window, floating 4D shapes, and the
  monolith.

What is missing is everything around that loop:

- **No structure.** Every system spawns at once and forever. Yellow cubes, ducks, 16 white
  shapes, green spheres and the monolith each have their own rule, with no start, goal, end or
  restart.
- **No visual logic.** Colour means nothing consistent, the white shapes look like targets but
  are cover, and nothing in their construction says how to interact with them.
- **The locator is incomplete.** Verified on 5 Oct, by code and by frame:
  - `slice_radar_ramon.gd` draws only the yellow cube, the ducks and the monolith.
  - The white and grey blockers and the green spheres are never on it.
  - In `smoke_test_output/range_study/10_slice_30.png`, white blockers are in view and the
    radar has no mark for them.
  - Trym's radar tracks the target, the ducks and the contest targets only.
- **The look is broken.** The textures have been wrong since 30 Sept, the HUD text overlaps,
  the controls are listed in three places, and the scene is dark.

So the answer is **clear rules, target roles and presentation**: keep every mechanic that
works, and rebuild the structure around it. That still means a new scene rather than a patch.
The old two are a free-for-all at their root, so structure cannot be added to them without
rewriting them.

## 2. The look

Light R&D holodeck, after the Creation Lab, but lighter:

- **Surfaces:** white and light grey prototype-grid floor and walls (the kit's grid, recoloured).
- **No roof.** A pale sky over the walls.
- **Light:** a warm key sun, a cool fill and ambient environment light (the LabKit bright mood
  as the base). Lit materials throughout, no flat-shading hack.
- **One spot,** and only while a stage is running, over the stage area.
- **Walls:** blue with white type, the kit's code blue.
- **Screens and overlays:** black glass, the kit rule. Montserrat throughout.
- **Sci-fi touch:** thin cyan light lines at the foot of the walls and along the firing line,
  and targets that materialise with a cyan scan and dissolve on a hit.

## 3. The room

A firing hall with one obvious direction, downrange:

- **The approach:** you start in a short entrance corridor. "QUANTUM RANGE" is painted over the
  doorway, and you walk through it into the firing bay.
- **The firing line:** a counter across the hall at z = 0. The console stands on its own to your
  left in the bay, facing across it (on the counter it covered the radar).
- **The two walls:** the hall's side walls are split just past the line. From the line to 11 m
  out, the left wall is the **explainer wall** (the kit's intro panel) and the right wall the
  **metrics wall** (the kit's research panel), each with its panel in the middle. This is the
  kit's rule for two panels on long walls: split them into walls in line.
- **The downrange hall:** one rectangle, 23 m wide, from the bay's back at z = 10 to the far wall
  at z = -36, no roof.
- **Walking out:** while no experiment runs you can walk downrange as far as the walls, to read
  them close. During a stage the counter holds you, and START brings you back to the line.
- **Your W range:** you can step ±2 m through W. Anything further off in W has to be reached by
  turning your slice.

Built in three tries, each judged from the firing line by frame:

1. A narrower bay opening onto the hall hid half of each panel behind the bay's own walls.
2. Two blue wings standing past the line, turned to face you, took 80° of the view between
   them at the kit's fixed 9.6 m panel width.
3. The side walls (now): the view downrange is clear, and each wall is a turn of the head away.

This is Ramon's "same room, see all, play there". The entrance door gives the "walk through a
door and play" moment as well.

## 4. Colour and shape: one role each

| Colour | Role | Shape language | How you deal with it |
|---|---|---|---|
| **Red** | The core, the thing to hit | Round: a lofted 4D ball, softly glowing | One quick shot |
| **Amber** | Armour | Faceted, angular | Only a charged shot breaks it |
| **White** | Breakable cover | Plates, petals, tendrils, satellites, in segments | Shoot it away, or wait it out |
| **Grey** (dark metal) | Unbreakable shell | Smooth, closed | Go round it, through W |
| **Green** | Friendly | A plus or cross silhouette, never round | Do not shoot (a penalty) |
| **Cyan** | Anything about W | Rings, lanes, the radar's stems, the alignment glow | A guide, never a target |
| **Blue** | Information | The walls, the signs | Read it |

The radar uses the same language: a red dot, an amber square, a white diamond, a grey ring, a
green cross and a cyan circle. Every target appears on it, which fixes the bug Ramon suspected.

## 5. Target families (abstract research specimens)

Each one is built from lofted pieces (the Model loft builder) and moved as rigid pieces only.
Nothing re-lofts per frame (`lofting_gotchas.md`: drawing is nearly free, re-lofting is not).

| Family | What it is | What its construction says |
|---|---|---|
| **Pip** | A bare red core, bobbing | Round and alone, so shoot it |
| **Amber block** | An amber faceted solid | Heavy, so charge it |
| **Armoured core** | A red core in an amber casing | Two steps: charge the casing, then tap the core |
| **Shell** | A red core inside a grey torisphere | Sealed in your slice. The shell is thin in W, so step past it. A 4D box has no lid along W. |
| **Cluster** | A red core with 8 white satellites on the 16-cell's vertices (±x ±y ±z ±w) | You see 6. The radar shows 2 more ana and kata. Clear all 8 and the core lights. |
| **Capsule** | A red core inside hinged white petals that open through W | In your slice the petals seem to dissolve, so shoot in the window |
| **Tendril sentinel** | A red core with 4 articulated white tendrils sweeping through W | Shoot a tendril and it recoils. Shoot the core through the gap. |
| **Ring gate** | A cyan ring, thick in W, marking a core far off in another slice | Turn the slice until the core shows inside the ring. The ring lights when you are aligned. |
| **Drone** | A red core with three fins, flying a lane. Amber "heavy" and green "friendly" variants. | Moves, so lead it |
| **Flying chicken** (Ramon's addition) | The pen's chicken, a carried copy, as rigid pieces with flapping wings, on ballistic arcs | Skeet: hit it in the air |

## 6. Experiments: the broad list

Every experiment has a clear start (pick it at the console and press F), an objective (on the
HUD card), a completion condition (shown on the card as progress), and a restart: R restarts
the stage, Shift+R the whole experiment. Each runs in four stages, after Nintendo's four-step
level design (kishōtenketsu: introduce, develop, twist, conclude).

1. **Locate & Align:** find cores in other slices with the radar, step to them, turn the slice
   for the far ones. *W: high.*
2. **Charge & Break:** read the target. Red takes a quick shot, amber takes a charge.
   *W: low (rises in stage C).*
3. **Reveal the Core:** shells, clusters, capsules and sentinels. The way in is always through
   W. *W: highest.*
4. **Incoming:** drones down painted lanes, some arriving from another slice. A miss costs a
   point; in strict mode (T) a miss stops the stage, and R starts it again. *W: medium.*
5. **Chicken Skeet:** "PULL" launches chickens on arcs, some crossing through W.
   *W: high.*
6. **Selective Fire:** red among green decoys, then "only the cores that are ana", read from
   the radar's stems. *W: medium.*
7. **Thread the Ring:** line up a near ring and a far core that are in different slices, by
   stepping and turning (4D iron sights). *W: highest.*
8. **The Monolith** (Ramon's stalker): survival. A slab drifts in from another slice; find it
   and break it before it reaches the line. *W: high.*
9. **Slice Dial:** three cores line up at only one slice angle. Find it (a combination lock).
   *W: high.*
10. **Mirror Decoys:** each real core has a decoy twin at a W offset; the stem tells which is
    real. *W: medium.*
11. **Projectile Lead** (Trym's projectile): a slow bolt you have to lead through W. *W: medium.*
12. **Lock and Sweep** (Trym's W-targeting): the wheel locks a target and the slice turns onto
    it. The assist as a mechanic. *W: an assist.*
13. **Blind Shot:** a charged shot thick in W hits what you cannot see; shoot by the radar.
    *W: high.*
14. **Speed Run:** experiments 1 to 4 back to back, against your best time.
15. **Free Range:** every family on stands, no score. Also the developers' target gallery.

**Recommended main sequence: 1 to 4.** Each is a different way of playing, not just harder:

- Locate & Align: **navigate**.
- Charge & Break: **read and discipline**.
- Reveal the Core: **reason spatially**.
- Incoming: **react under pressure**.

**5, Chicken Skeet,** follows as the bonus Ramon asked for, and is built too. 15 is built as
the target gallery (F2). 6 to 14 stay as ideas, to narrow down after review.

### The stages

**01 Locate & Align**
- A **In your slice:** three cores straight ahead. Learn to shoot.
- B **Step through W:** cores 0.8–2 m ana or kata, one after another. The radar's stem says
  which way, Q/E to step. The edge glow says when you are there.
- C **Too far to step:** ring gates downrange, each marking a core 4–7 m off in W, beyond the
  bay's ±2 m. Hold the right mouse button to turn the slice until the core shows inside its
  ring, and X to snap back.
- D **Drifting:** cores slowly drifting between slices. Combine stepping and turning.

**02 Charge & Break**
- A **Charge:** three amber blocks. Hold until the ring fills, then release.
- B **Two steps:** armoured cores. A charge breaks the casing, a tap takes the core.
- C **Charge, then step:** armoured cores in other slices that re-armour after 3 s. Charge
  first, step into their slice, release.
- D **Read fast:** a timed mixed wave of red pips that blink out after 2 s and amber blocks
  that stay. Switch between tap and charge.

**03 Reveal the Core**
- A **Shell:** a grey shell you cannot break. Step past it through W.
- B **Cluster:** 8 white satellites, two of them in other slices.
- C **Capsule:** petals that open through W on a cycle. Shoot in the window.
- D **Sentinel:** tendrils sweeping through W. Recoil them, or wait for the gap.

**04 Incoming**
- A **Lanes:** three painted lanes in your slice, slow drones one at a time.
- B **From another slice:** drones that start ana or kata and fade into your slice partway
  down. The radar says which lane.
- C **Mixed:** fast red drones, an amber heavy (charge it) and a green friendly (do not shoot).
- D **Hold the line:** a final wave. In strict mode, one miss stops the stage.

**05 Chicken Skeet**
- A **Pull:** single birds on arcs in your slice, launched with F.
- B **Doubles:** pairs from both traps.
- C **Through W:** arcs that swoop in from kata and out to ana, so a bird is in your slice for
  part of its flight. The glow says when.
- D **The flock:** a burst of six.

## 7. Controls (one place each: the explainer wall's shortcuts, and the HUD strip in context)

| Input | Action |
|---|---|
| Mouse | Look |
| WASD | Move: in the bay, or out to the walls while no experiment runs |
| Q / E | Step kata / ana through W (±2 m) |
| Hold right mouse + move | Turn the slice |
| X | Snap the slice back |
| Click | Quick shot |
| Hold click, release | Charged shot (full at 0.9 s; vents if held 2.5 s more, as in Ramon's version) |
| 1–5 | Pick an experiment |
| F (or Enter) | Start / pull (skeet) / press a console button you look at. Not E: E is the step ana. |
| R / Shift+R | Restart the stage / the experiment |
| T | Strict mode (Incoming) |
| F1 / F2 / F3 | Dev panel (lights, saved) / target gallery / hitbox view |
| H | Back to the menu (the shared prompt) |

## 8. The two walls

- **Explainer (intro panel):**
  - running header "04 / QUANTUM RANGE";
  - title, then the lead "Aim in four dimensions.";
  - the colour key in four lines;
  - four shortcuts (click and charge, Q/E, turn the slice, X).
  - It lights a shortcut when you use it (the kit already does this).
- **Metrics (research panel, a "range" layout in the range's copy of the kit):**
  - the five experiments as the story rows (done, now, upcoming);
  - the current experiment's page: headline, what it shows, a chart (time per stage), and three
    live metrics such as accuracy, W travelled and slice turned;
  - a results table, four rows round the chosen experiment: time, shots, accuracy, wasted
    shots, W travelled, slice turned, and what one 4D raycast cost (µs, measured);
  - footnote: GPU, OS and date, live.

## 9. Engineering calls

- **The kit is carried over, not reused.** Copies go in `QuantumRange/carried/` with paths
  rewritten, no .uid sidecars and a README naming the source commit. Why:
  - Ramon asked that nothing in `CreationLab/` be changed.
  - The kit moved folders twice on 5 Oct alone.
  - Its swatches are static state shared by every user.
  - Ramon's own rule for the Creation Lab was "carry it over, and not reuse it".
  - Re-pointing to the shared kit later is a Question for Ramon.
- **The chicken is carried over too.** Its loft rigs and the three loft scripts come from
  `chickenpen/`, then are baked once into rigid pieces. The pen is never touched.
- **Lit materials:**
  - The grid shader (lit, with prints) for the room.
  - The engine's own lit TetraMaterial4D for targets.
  - The kit's unshaded glow for light lines and core glows.
  - The PhaseMaze flat-shading fork is not used anywhere.
- **Physics:**
  - Every hitbox is a box, because the engine collides AABBs.
  - Targets are Area4D, found by `collide_with_areas` raycasts.
  - A shell is solid only within its W thickness. That is exactly what makes stepping past it
    work.
- **Cost:**
  - Every mesh is built once at load and shared.
  - Motion moves nodes, nothing deforms.
  - Static strips are merged (`ArrayTetraMesh4D.merge_with`) to stay clear of the
    shader-instance limit.
- **The line is a clamp, not a wall.** The player's `min_z` stops you at the counter. An
  invisible collider there blocked every raycast, because the ray starts behind it.
- **One number for distance.** `range_experiment.gd` `NEARER` (0.82) scales every stage's
  distances together. The stages were written at 10 to 30 m, where the specimens were too small
  to read how they are built.
- **Test runs never save bests.** The director's `keep_bests` is off in every runner.
- **No class_name anywhere** (`engine_gotchas.md`); everything is preloaded.
- **Godot turns:**
  - `QuantumRange/scripts/range_run.sh` waits for the lock and for other Godot processes
    (another window is working; Ramon, 5 Oct).
  - Test windows are small and unfocusable.
  - Positions are set before each capture, not trusted from spawn (stray keys once reached a
    test window).

## 10. The 75 steps

**A. Foundations**
1. This plan and design brief written down (this file), the Questions list on top.
2. `QuantumRange/` made. The kit pieces the range uses are carried over from `CreationLab/`
   (snapshot, paths rewritten, README with the source commit). Nothing in `CreationLab/` is
   touched.
3. The chicken's loft rigs and the loft scripts carried over from `chickenpen/` into
   `QuantumRange/carried/chicken/`.
4. `range_run.sh`: the launcher. It waits its turn for the engine lock, takes it in the same
   process, logs, greps for errors, and has a parse-check mode.
5. An empty `quantum_range_final.tscn` with its root script; a smoke runner proves it loads
   with no errors.
6. The room's plan: the bay, the 45° flares carrying the two walls, the downrange hall and the
   entrance corridor with its door. A top-view capture checks it.
7. The room built with the carried KitRoom (no ceiling, no cove) in the range's own white and
   grey swatches; QUANTUM RANGE painted over the doorway.
8. Light: the pale sky, warm key, cool fill, ambient and tonemap. Frames from the corridor, the
   line and downrange, tuned by eye.

**B. The player**
9. The first-person controller, after CLAUDE.md's conventions:
   - yaw and slice on the body, clamped pitch on the head;
   - orthonormalised every frame;
   - no position label, no Escape scene change.
10. Q/E steps through W within the bay's ±2 m. The counter keeps you behind the line.
11. Slice turning with the right mouse button held; X eases the slice back to the room's own.
12. The gun: Ramon's barrel, stock and 600-cell core, rebuilt in the lab palette; the core heats
    as it charges.
13. The way in: spawn in the corridor and walk to the line. Also the shared H prompt, and the
    pen's way home (inert unless the pen sent you).
14. Proof: a runner walks in, steps to the W limit, turns and snaps the slice. Frames.

**C. The weapon and its feedback**
15. The hitscan weapon:
    - a real 4D ray from the head;
    - a tap is a quick shot, a hold charges (full at 0.9 s, vents 2.5 s later), and release
      fires one heavy shot.
16. Shot visuals: a beam box along the ray, thicker when charged; sparks; a scuff, a crack or a
    pop by what was hit.
17. The damage rules: each part says what breaks it (red: any shot, amber: charged only, white:
    any, grey: nothing, green: a penalty).
18. Sound:
    - charge, release, pop, clink, ping, buzz and chime;
    - the range's own WAVs reused, plus project sfx (never the pen's .aac or the stray .exe).
19. The raycast's cost measured per shot (µs), for the metrics wall.
20. The crosshair with the charge ring round it: it fills amber, shows a white tick at full,
    and turns grey once vented.
21. Proof: a runner fires quick and charged shots at test parts. Frames of beams and impacts.

**D. The locator HUD**
22. The working radar forked into the range. It tracks every registered target part (the fix).
23. Marker language: a shape and colour per role; a stem for W; the current target
    highlighted.
24. A readout under the radar: your W against the bay limit, the slice angle, and the current
    target's W offset.
25. A cyan edge glow when the current target is cut by your slice.
26. Black glass and Montserrat. The control strip of key chips along the bottom, and toasts.
27. Proof: frames of every marker kind on and off the slice, and a check that no text
    overlaps.

**E. The targets**
28. The target base:
    - parts, each a mesh and an Area4D hitbox, with roles and hit rules;
    - it materialises (scale-in, cyan scan) and dissolves;
    - it registers its parts with the radar and reports to the director.
29. The lofted core: a red 4D ball with an inner glow, baked once and shared.
30. Pip.
31. Armoured core.
32. Amber block.
33. Shell: a grey torisphere round a core. The primitive's axes and its W thickness are
    checked against the core by frame.
34. Cluster: 8 satellites on the 16-cell's vertices.
35. Capsule: hinged lofted petals opening through W.
36. Tendril sentinel: 4 jointed lofted tendrils sweeping through W, recoiling when hit.
37. Ring gate: a cyan ring, thick in W, lighting when its far core is in your slice.
38. Drones: red, amber heavy and green friendly, flying lanes.
39. The flying chicken: the carried chicken baked to rigid pieces, flapping wings, a ballistic
    arc, a feather burst and a tumble when hit.
40. The target gallery (F2): every family on a stand with a label. Frames of each, in and off
    the slice.

**F. The experiment framework**
41. The director:
    - the list, selection and state (idle, countdown, stage, cleared, results);
    - R and Shift+R restart; Next goes on.
42. Experiments and stages as data: objective, spawns (family, place, W, motion), completion,
    failure and par.
43. The console on the counter: a black-glass screen with numbered buttons 01–05. Press a
    number key, or look at a button and press F.
44. The countdown and the holodeck materialise; the stage cards; the results card.
45. Scoring:
    - time against par, shots, hits, accuracy, penalties, W travelled and slice turned;
    - bests saved to `user://quantum_range.cfg`.
46. The objective card at the top left: experiment, stage, objective, progress and timer.
47. The explainer wall: the carried intro panel with the range's words and colour key.
48. The metrics wall: a "range" layout for the carried research panel, with a panel source
    feeding it live.
49. Proof: a runner plays a test experiment end to end. Frames of the console, the cards and
    both walls, and a legibility check from the line.

**G. The main sequence**
50. 01 Locate & Align, stages A–D.
51. 01 tuned by playing: a runner's aim completes every stage; frames per stage; distances
    adjusted so the stems read.
52. 02 Charge & Break, stages A–D.
53. 02 tuned.
54. 03 Reveal the Core, stages A–D.
55. 03 tuned.
56. 04 Incoming, stages A–D: lanes painted into the floor, strict mode.
57. 04 tuned.
58. 05 Chicken Skeet, stages A–D: the traps, and PULL on F.
59. 05 tuned.
60. The sequence: finishing one offers the next; all five done puts a summary on the metrics
    wall.
61. The one spot: a single spot over the stage area while one runs, judged by frames.

**H. Developer views**
62. F1 dev panel:
    - sun, fill, ambient, sky, exposure and spot; target speed and W limit;
    - SAVE writes `quantum_range_tuning.cfg`, read back at start.
63. F3 hitbox view: every part's box drawn through the live camera, dashed when off the slice.
64. Performance, windowed with vsync off:
    - frame time per experiment and in the gallery;
    - bake time at load;
    - tetrahedra in view.
65. Whatever the measurements show is over 8 ms gets fixed (merging, sleeping far targets).

**I. Proof and polish**
66. A full playthrough runner: all five experiments, every stage, by simulated aim and keys, in
    a small unfocusable window. Frames at every beat.
67. Every frame looked at on contact sheets, and what reads wrong fixed.
68. A legibility check for both walls and the console from the line (each role's height in
    pixels).
69. A text pass: no dashes in player-facing lines, and each control in one place.
70. Regression: both old ranges load untouched; `git diff` shows nothing changed in
    `CreationLab/`, `chickenpen/`, `ShootingGalleryRamon/` or `sandbox/shooting_gallery/`.
71. A short film of each experiment (the movie writer), for a menu clip later.
72. The menu card's text drafted here, not added (Ramon decides).

**J. Handover**
73. This file finished: how to open it, what is where, the Questions, the ideas list and the
    sources.
74. `engine_capabilities.md` and memory updated with what was learned.
75. A local commit by explicit paths, and a report that leads with frames.

### What changed from the plan while building

- **Step 6:** the 45° flares became one rectangular hall with split side walls (section 3).
- **Step 43:** the console moved off the counter onto its own stand to your left; on the
  counter it covered the radar.
- **Steps 51 to 59:** every specimen grew about 25%, and the stages came 18% nearer (`NEARER`).
- **Step 61:** the spot is driven by the director: it fades in while a stage runs and out
  after. Its strength is on F1.
- **Step 68:** the walls' tables do not read from the line, which led to walking out
  (Question 2).
- **Controls:** F (not E) starts, pulls and presses console buttons, because E steps ana.
- **Not planned, added:** the console's titles wrap onto two lines, and the results card widens
  for a long headline (both were cut off).

### What is where (`project/ramon/QuantumRange/`)

| Path | What |
|---|---|
| `quantum_range_final.tscn`, `quantum_range_4d.gd` | The scene and its root: builds the player, gun, HUD, director, console and dev panel at run time |
| `range_info.tres` | The words on both walls (kit room info) |
| `scripts/range_layout.gd` | Every position in the room, in one place |
| `scripts/range_style.gd` | Swatches, light, and the colour of each role |
| `scripts/range_director_4d.gd` | States, stages, keys, scoring, bests, the gallery |
| `scripts/range_experiment.gd`, `scripts/experiments/` | The experiment base and the five experiments |
| `scripts/range_target_4d.gd`, `scripts/targets/` | The target base (parts, roles, hit rules) and the ten families |
| `scripts/range_shapes.gd` | Every target mesh, built once and shared |
| `scripts/range_weapon_4d.gd`, `range_fx_4d.gd`, `range_gun_4d.gd` | The shot, its beams and bursts, and the gun |
| `scripts/range_hud.gd`, `range_radar.gd`, `range_crosshair.gd` | The HUD, your radar forked, the charge ring |
| `scripts/range_console_4d.gd` | The console and its six shootable buttons |
| `scripts/range_panel_source.gd` | Feeds the metrics wall live |
| `scripts/range_dev_panel.gd` | F1: the light, saved to `quantum_range_tuning.cfg` |
| `scripts/range_player_4d.gd` | The first-person controller |
| `scripts/range_run.sh` | Runs a runner when the engine is free (lock, wait, log) |
| `scripts/_*_runner.gd`, `_range_bot.gd` | The proof runners and the test player |
| `carried/` | The kit and chicken copies, with a README of what changed from the source |

### In the menu (5 Oct, evening)

The Quantum Range entry in `Menu/entries/catalogue.tres` (shared by menu_final, Menu, Menu2,
the Frontier Map and the deck) now:

- **opens** `res://ramon/QuantumRange/quantum_range_final.tscn`, on top of the menu like the
  other prototypes; H and Escape bring the menu back;
- **reads** "Aim in four dimensions: five experiments on a 4D shooting range", about 10 min,
  with the drafted detail text;
- **lists** WASD move, LMB shoot / hold to charge, Q / E through w, RMB rotate slice, F start;
- **plays** `Menu/thumbs/quantum_range_final.ogv` with `preview_focus` 0.5. The old
  `quantum_range.ogv` is still there, unused.

Its question, approach, finding and measured line are unchanged, because the deck copies them.
"True 4D raycasts" could become the measured "one 4D raycast 13 to 17 µs" if you want it.

**Checked** by `scripts/_verify_menu_range_runner.gd` (14 checks): the entry, the clip playing
in the pane, the range on top of the menu, a stage played there, H and Escape back, nothing
left on the root, the mouse free. Frames in `smoke_test_output/quantum_range/menu/`.

**The clip** (7.9 s, 1280x720, Theora, 2.1 MB) is three moments filmed from the player's eyes
by `scripts/_capture_menu_clip_runner.gd`:

1. a ring gate: the slice turns until the far core sits in its ring, one shot;
2. a shell: a step through W past it, and the red core inside is shot;
3. skeet: a chicken from each trap, met on its rise and shot in the air.

What shaped it:

- **The band.** The menu's pane is about 3.5:1 and shows the middle half of the 16:9 frame,
  so the HUD is hidden except the crosshair and the slice glow (the HUD's `clean`), and
  everything happens at the crosshair.
- **The lens.** It is 60° (45° for the birds) instead of play's 80°, so the specimens fill the
  band. The camera glides between poses where the test bot would jump.
- **Real shots.** Each shot is the range's own weapon and hit. The birds are met where
  their own flight path says they will be.

To remake it after a change to the range:

```
range_run.sh clip menu_clip res://ramon/QuantumRange/scripts/_capture_menu_clip_runner.gd
ffmpeg -framerate 30 -i smoke_test_output/quantum_range/clip_frames/%04d.png -c:v libtheora -q:v 8 -pix_fmt yuv420p -an ramon/Menu/thumbs/quantum_range_final.ogv
```

(the first from `project/ramon/QuantumRange`, the second from `project/`). The runner prints
each shot's outcome. The ring gates are placed at random, so if a ring shot prints a miss,
run it again.

**From the pen** (`scripts/_verify_pen_trip_runner.gd`, 18 checks, frames in
`smoke_test_output/quantum_range/pen_trip/`):

- the range master's yes parks the pen and opens this range, its prompt reading BACK TO THE
  CHICKEN PEN;
- a stage plays there;
- H brings back the same pen, with the belt, the camera and the checklist tick;
- a second trip, left by Escape, does the same.

Escape going home is new. `range_way_home_4d.gd` took only H, and Escape just freed the mouse,
although its header said otherwise. Escape now goes back to the pen, as it goes back to the
menu from the menu.

**Fixed on the way:**

- **Starting a stage from the corridor.** Keys 1 to 5 and F work anywhere, and a stage started
  from the entrance corridor was played through the door from 15 m back. Starting now puts
  you on the line from the corridor too.
- **The skeet traps.** They stood 2 m behind the point the birds launch from. They moved in
  with the rest (`NEARER`).
- **Test runs and your mouse.** The range takes the mouse when it opens, so in a test window
  your mouse moving in another window turned the camera mid-run (once mid-take). Every runner
  now switches the player's input off and frees the mouse.

## Sources

- Aim-trainer scenario families (clicking, tracking, target switching):
  [Aim Lab](https://aimlabs.com/articles/?p=3960) and
  [Aim Lab vs KovaaK's](https://www.oneesports.gg/valorant/aim-lab-vs-kovaak/).
- Teaching one mechanic per chamber, then twisting it:
  [Portal developer commentary](https://theportalwiki.com/wiki/Portal_developer_commentary) and
  [Game Informer, Making a test chamber](https://gameinformer.com/b/features/archive/2010/03/17/thinking-with-portals-making-a-test-chamber).
- Four-step levels (kishōtenketsu):
  [MCV, Nintendo's level design secrets](https://www.mcvuk.com/development/video-nintendos-level-design-secrets-in-four-steps).
- No-shoot targets carry one unique colour:
  [USPSA rules 4.1](https://rules.uspsa.org/uspsa/section/4.1) and
  [Action Target discretionary command targets](https://targets.net/blogs/news/shoot-no-shoot-targets).
- Discrete and continuous slice turns, axis-aligned being easiest:
  [80.lv on 4D Golf](https://80.lv/articles/get-the-hang-of-4d-easily-in-this-unique-casual-golfing-game).
- A 4D arena shooter (flank along W, evade by changing layer):
  [Slice 4D Shooter](https://www.moddb.com/games/slice-4d-shooter).
