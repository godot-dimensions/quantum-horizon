# Playable world: 4D onboarding, discovery and easter eggs (plan, 9 Oct 2026)

Ramon's brief "Playable World — 4D Onboarding, Exploration & Easter Eggs", plus the follow-up on hints along the
path network.

## Ramon's answers (9 Oct, 22:20). These override the plan below where they differ.

1. **Build directly in the main scene** (`playable_world.tscn`), no inherited fork. Keep it revertable: a backup of the
   original scene and of every file changed, in `chickenpen/.backup/2026-10-09_before_discovery/`.
2. **The balloon is locked until found**, but the "V Align to slice" prompt is forgiving: it appears within reason
   (wider reach, an earlier share).
3. **At the balloon's old spot: a fire and an NPC sitting at it**, with short, simple dialogue: the balloon is in W,
   ana or kata of him. (Replaces the weather mast.)
4. **Egg sites: the least busy places** (measured from the scene, not guessed).
5. **Trym's desk:** I put legs at W 0 myself.
6. **No towers in W.** Step 36 (echo towers) is dropped; the Watchstone stays single.

Added mid-build (Ramon, 9 Oct): **airships** far out to the right of the Watchstone, one in the farm's slice and four
ana, budget-friendly. Built on 9-10 Oct; what was built and checked: `follow_up/pen_discovery.md`. The Dream Shifter
(the dev/art onboarding brief that came after) is `follow_up/pen_dream_shifter.md`.

## The questions as first asked

1. **Where it gets built.** The pen is the shipped demo. I'd build everything in an adjacent scene that inherits it,
   `chickenpen/playable_world_discovery.tscn`, with all new code in `chickenpen/discovery/`. The shipped pen stays
   untouched until you say to copy it over. OK?
2. **The balloon's hiding place.** I propose parking it 5 m ana (W +5) above its stake while nobody has found it. The
   ride itself (its route through W to the marsh and the kata wood) stays exactly as it is. Should B ("board from
   anywhere") wait until you've found it?
3. **What stands at the balloon's old spot.** My pick is a researchers' weather mast with a spinning wind vane: it's
   different, fits Wren's lookout and is cheap to build. The other option is a small ring of standing stones.
4. **Egg sites.** Egg 1, the cache: the empty north-east meadow, around (30, −25), with the opening at W +6 to +8. Egg 3,
   the door: somewhere with a clear view of the Watchstone. Candidates are the open field west of the pen (about −30, 24)
   or the meadow south of the camp. Your eye decides.
5. **Trym's desk floats in the normal view** (all eight legs sit at W ±0.41 to 0.51). Keep it as a teaching moment
   ("its legs are ana and kata of you"), or ask Andrew to stand one pair at W 0? The bookshelf stays as he built it
   either way.
6. **The echo towers** (step 36) are an experiment with a hard budget. Worth trying?

## What I looked at

Five read-only sweeps of the code (the Aquatic Lab hints, the pen's guidance and rewards, the balloon / Watchstone /
W Exploder, the cave / doors / azoth, the map / bookshelf / hills). What matters for the plan:

- **The pen already teaches a lot, in pieces.**
  - The Tutor shows one text hint at a time, once each. Its "tutor spots" are nodes with metadata
    (`scripts/pen_tutor_4d.gd`). Two are in use: GateHint, and the cave's DoorSpot.
  - The chickens have the locator, the yellow glimpse that grows as you near their W, and SliceAssist (T).
  - The dial shows your slice against the farm.
  - "V Align to slice" exists twice already: at the camp (`pen_research_camp_4d.gd`) and the marsh (`lookout_4d.gd`).
    You turn until about 85% shows, and V flattens your slice onto it with `rig.align_to(w)`.
  - What's missing is anything animated, any sense of what the player has already learned, and hints along the route
    between the big moments.
- **The Aquatic Lab's mouse card** (`WaterLab/shared/mouse_tutorial.gd`) is pure drawing code with no player or scene
  dependencies. It drops into the pen with a small adapter: the pen's gestures are drag sideways and drag forward, the
  wheel is zoom here, and E/Q stepping needs one new gesture. Note that the lab's V moves the tank's contents, not your
  slice; the pen's camp code is the right template for a V-align.
- **The path is already 4D.** Three stretches climb through W: the cave road (to W 3), the gate road (down to W −13),
  and the camp road (to W −2.5). Since Andrew's shader change, path marks narrow and vanish as you leave the route's W.
  The path can tell you whether you're on its W. That's the backbone of the route hints.
- **The balloon is built in code by the Lookout at its mooring stake (−30, −32, W 0).** Moving the mooring in W would
  break its ride: the W legs would miss the marsh and the kata wood, B would stop working, and the landing would move.
  So hide its **parked** pose only, not the ride.
- **The W Exploder can't place Watchstones.** It is oak-only by design (its script filter, property copy, trunk slab
  and cull all assume an oak). Copying a whole scripted unit would duplicate the walk-up, Wren and the Lookout's story
  beats. Each full copy is also about 102k tetrahedra (~130 MB video memory) and 20 meshes in art, about 198 in dev.
- **A second cave through a crossing is possible but costly.** Much is wired to the one cave by name: the fade, the
  music, the dev look's hold, the controls card. A crossing must also put Bounds to sleep. A small cave you can walk
  into in W, with no scene switch, avoids all of that.
- **Rewards exist to reuse.**
  - Azoth: `add_item("found_azoth")` in a loop, as the collector does. Watch the 5-slot belt, which silently refuses a
    new item type when full.
  - The gauntlet award's spin-and-shrink showcase.
  - The celebration's W-deep confetti burst (hard-wired to the pen, so copy it).
  - The Lookout's "secret" chime.
- **Engine limits that shape the plan:**
  - Box-only physics.
  - Mounds already collide as 1.8 m box walls, so you can't climb them.
  - Projection (P) counts double against the mesh limit. The dev look already hit it once, today.
  - Anything bent or turned through W becomes a thick slab in projection.
  - Every teleport destination must be clear: the engine never pushes a body out of a box. For example,
    `ladder_top()` would land you inside the red oak's trunk.

## Research (prior art)

- **4D Golf:** faint copies of objects along the unseen axis to judge where things are, plus buttons that jump to the
  ball or hole. The pen's P and V are the same ideas.
- **Fez:** secrets hidden behind turning the view. It teaches by letting you notice what changes, with only cryptic
  hints.
- **The Witness:** rules taught without words, by the place itself; small "aha" moments.
- **Hint design:**
  - End a hint when the player does the action.
  - Trigger on hesitation, not on arrival.
  - Don't vanish before it can be read (3-5 s is a common complaint).
  - Remember what was learned.
  - Players clearly prefer animated hints to text.
  - Hints can also backfire if they come too often.

Sources: [80.lv on 4D Golf](https://80.lv/articles/get-the-hang-of-4d-easily-in-this-unique-casual-golfing-game) ·
[TV Tropes, 4D Golf](https://tvtropes.org/pmwiki/pmwiki.php/VideoGame/FourDGolf) ·
[Critical Play: FEZ](https://mechanicsofmagic.com/2026/08/12/critical-play-fez-2/) ·
[PC Gamer, Fez](https://www.pcgamer.com/fez-review/) ·
[Game Informer, The Witness](https://gameinformer.com/games/the_witness/b/playstation4/archive/2013/06/14/five-features-that-define-the-game.aspx) ·
[Electron Dance, The Witness](https://www.electrondance.com/early-thoughts-on-the-witness/) ·
[bugnet, hint systems](https://bugnet.io/blog/how-to-design-a-hint-system-for-puzzles) ·
[Wayline, tutorials](https://www.wayline.io/blog/designing-effective-game-tutorials-and-onboarding)

## The design in one page

**Four skills, taught in order along the path, then tested by three eggs:**

| Skill | What the player learns | Taught at | Tested by |
|---|---|---|---|
| Step (E / Q) | moving ana and kata changes what exists around you | Trym's desk and bookshelf, the cave road | Egg 1, the kata cache |
| Turn sideways (drag left/right) | turning the slice shows what's beside your slice | the camp | Egg 2, the balloon |
| Turn forward (drag up/down) | turning forward lets you see ahead into W | the gate | Egg 2 / the gate |
| Align (V) | snap your slice onto something you can half see | the camp, the marsh | Egg 2, the balloon |
| *All of it* | a thing can be thin in one slice and whole in another | – | Egg 3, the edge-on door |

**How hints behave:**
- They appear only after you **linger** about 3 s near something hidden, with it still off your slice.
- They show for about 5 s and fade.
- They end for good when you've done the thing.
- They get **quieter as you learn**, tracked per skill:
  - Tier 0 (never done it): the animated card and one short line.
  - Tier 1: a small key or mouse chip at the spot.
  - Tier 2: nothing on screen, only the world's own cues (the path's marks, a glint, a hum).
- One hint at a time. They give way to the Tutor, dialogue, films, the cave and the Lookout subgame, and stay local to
  their spot.

## The 40 steps

### A. Groundwork
1. **Fork.** `chickenpen/playable_world_discovery.tscn` inheriting `playable_world.tscn`; new code in
   `chickenpen/discovery/`. Check it loads and plays like the original.
2. **Baseline.** Route frames in both looks, frame and GPU time at five spots, and the mesh count with P on in both looks
   (the number the new things must stay under).
3. **Test kit:**
   - a capture runner set for the fork (it extends `PenLayout/scripts/_capture_pen_runner.gd`);
   - a headless verify runner that places the player and drives the rig;
   - a separate `user://pen_discovery.cfg` that tests reset, so your saved settings are never touched.
4. **Slice sense** (`discovery/w_sense_4d.gd`):
   - how far a point is off your slice, along its true normal (`BearingUtility4D` `ana_offset`), not raw W (the Tutor's
     raw-W measure goes wrong once the slice turns);
   - the visible share of a thing of radius r: sqrt(1 − (d/r)²);
   - the slice's W at a point on the ground (the camp's formula).
5. **Skill tracker.** It counts real uses of step, turn sideways, turn forward and align, then saves the count and the
   tier per skill.

### B. The hint kit
6. **Pen mouse card** (`discovery/pen_mouse_card_4d.gd`, a copy of the lab's card):
   - gestures "turn sideways", "turn forward", and a new "E / Q step" gesture;
   - it scales with the pen's UI size;
   - it sits on its own canvas layer.
7. **Chip.** A small key or mouse glyph with two words on a WorldTag at the spot (`dialogue/world_tag_4d.gd`).
8. **W Guide** (`Systems/WGuide`):
   - hint spots in a `w_hint` group, carrying skill, target, radius, line and when it's done;
   - linger, show, fade, and done-forever logic.
9. **Manners:**
   - one hint at a time;
   - gives way to the Tutor, talks, films and crossings, and is asleep in the cave;
   - stays out of the Lookout subgame's area;
   - `reset()` on Ctrl+R.
10. **World cues:**
    - **Path W-step marks** on the three stretches that climb through W. A copy of the path graph,
        `pen_b_discovery.tres`, sets those stretches to the network's step mode.
    - A **glint** that grows as your slice nears a hidden thing (the chickens' glimpse, reused).
    - A quiet **hum** when you're in the right W band.
11. **Both looks.** New meshes get a dev-look rule or the look's own marker. Meshes that don't need projection are kept
    out of it. Mesh count checked with P on.

### C. The route as a curriculum (hints along the path)
12. **Trym's house, the first stop. Lesson: step.**
    - After 3 s in the shed: the E / Q card ("Step through W").
    - The desk's legs and the bookshelf change as you step. Only 27 of the 335 books cross W 0; every step kata shows
      others.
    - Done once you've moved 0.4 m in W.
    - The bookshelf itself stays exactly as Andrew built it.
13. **Trym's line** (optional): one line about his shelf, in a copy of his dialogue, for example "Each step kata, a
    different shelf. I keep the good ones out of the slice." No dashes in dialogue.
14. **Cave road (W 0 to 3). Lesson: step, again.** The door's text hint stays. The card shows only if step is still
    tier 0; otherwise a chip. W-step marks on the climb.
15. **The gate road (down to W −13). Lesson: turn forward.**
    - Card ("turn forward") after lingering south of the wall with the gate off your slice.
    - Done once your slice cuts the gate.
    - A soft glow on the hole's rim, visible only near W −13.
16. **One message at the gate, not two.** GateHint's text fires through the Guide, after the card. The Tutor's
    raw-W measure gets fixed in the fork's copy if it's still used.
17. **The camp road (W −2.5). Lesson: turn sideways, then V.** The card shows at tier 0 while under 85% of the camp
    shows. The existing camp V and the Camp Scout stay; V counts as "align learned".
18. **Progression pass.** Walk the route with a fresh skill file and a skilled one. The second half should show only
    chips and world cues. Tune radii and timings.

### D. Easter egg 1: the kata cache (step, and reading a trail)
19. **Site.** The empty north-east meadow, about (30, −25):
    - a low knoll of crag chunks (`scripts/pen_crag_chunk_4d.gd`: shared baked stones, box colliders), solid at W 0;
    - its opening exists only at W +6 to +8;
    - clear of the camp, the tree belt, the marsh (W +8) and MoundA (W +8.7).
20. **The cave.** A short tunnel (3-4 m) with a roof, a floor and one lamp. Box colliders leave only the W band open.
    The camera clearance is checked. No crossing and no scene switch.
21. **The trail.** A dotted secondary path from the camp to the knoll, climbing through W. At W 0 its marks thin out
    and vanish, so following it means stepping ana. The path itself is the clue.
22. **Closer clues:**
    - a three-stone cairn at W 0 by the knoll, its top stone set ana, so it looks odd until you turn;
    - the glint at the opening's W;
    - only as a last resort, after 8 s of lingering, a "step ana" chip.
23. **The chest.** A small model: body, lid and iron bands, 1.3 m deep in W like the balloon's basket. "F open"
    prompt, giving way to talks like the laptop does.
24. **The reward:**
    - the lid opens and crystals rise;
    - the gauntlet-style spin (about 2.5 s), then the chest spins and shrinks away;
    - **+10 azoth** (guarding the full belt), a "Found: 10 azoth" line, the secret chime, and a small W-deep confetti
      burst.
25. **Found once.** Saved in the discovery file; frames and a verify run.

### E. Easter egg 2: the balloon in W (turn sideways or forward, then align)
26. **Parked in W.**
    - Until found, the balloon idles tethered at **W +5**, so the envelope (radius 3.55 m) is gone at W 0.
    - The ride's route, W legs, landing and tests are unchanged.
    - Built in forked copies of the balloon and Lookout scripts, used only by the fork scene.
27. **Clue in the normal slice:**
    - the stake and sandbags stay, and the tether rope climbs and stops in mid-air, cut by the slice;
    - Wren's radio hints at it ("The wind pushed it ana last night").
28. **Reveal and V.**
    - The visible share comes from the slice sense at the balloon's spot.
    - At **70-80%**: "V Align to slice", in the same style as the camp and marsh.
    - V gives way to those two, then `rig.align_to(+5)`.
29. **Board from W +5.** F at the basket already works relative to W. Take-off eases the parked offset back onto the
    ride over the first ~8 s. After the first ride it moors at W 0: found.
30. **B and Wren's offer** board it only after it's been found. The Lookout card's B row is hidden until then.
31. **The old spot.** A weather mast with a spinning vane beside the stake: different, fits the researchers, cheap.
    Dev-look rule and frames.

### F. Easter egg 3: the edge-on door (thin in one slice, whole in another)
32. **The door.** Trym's portal arch (`theatre/theatre_arch_4d.gd`: frame, shimmer, lights, chime, polled trigger,
    already dev-look safe), restyled and **turned a quarter into W**. At W 0 it's a thin glowing post. Turn sideways
    90° and it's a whole door, a Fez moment.
33. **Placement and clue.** A spot with a sightline to the Watchstone. The clue is the post's pulse and hum. A "turn
    sideways" chip appears only after lingering; there's no card. The third egg is the test.
34. **Through it:**
    - fade, flatten the slice;
    - arrive at the plateau's safe point (−14.9, 13.65, −34.85, W 0), where the walk-up lands you, not `ladder_top()`;
    - face back toward the door's spot;
    - `Lookout.on_cab_entered()` plays Wren's first-climb line.
35. **The way down** is the existing "Go down?" ladder. Frames and a verify run.

### G. Measured experiments (kept only if they pass)
36. **Echo towers.** Two mesh-only Watchstone copies at W ±12 at the tower's x and z:
    - they share its meshes, as the old Optimiser's wrap did, so no extra video memory;
    - no collision and no scripts;
    - kept out of projection, drawn only when your slice cuts them, one box each in the dev look.
    - **Keep** only if each costs ≤ 0.5 ms GPU when seen and P raises no mesh-limit errors in either look.
37. **More hills through W.** 2-3 round hills (with their box colliders) at |W| ≥ 10, away from every route's W band:
    cave 0 to 3, camp −2.5, gate −13, marsh +8, wood −8. MoundF/G/H go into the grass-height, projection and look lists
    as well; they're missing today.
38. **Andrew's gate idea** (optional): a fallen pillar in the gate's hole at W −13 that you get past by turning. Only
    if you want it.

### H. Check and hand over
39. **Full playtest of the fork**, both looks, fresh and skilled skill files:
    - the journey including the W gate;
    - each egg found by a scripted run;
    - frames of every hint;
    - frame and GPU time at five spots;
    - the P mesh check.
40. **Handover.** `follow_up/pen_discovery.md` with questions first, plus the engine map and memory. Nothing goes into
    the shipped pen until you say so.

## Priorities

| | Value | Time | Risk |
|---|---|---|---|
| **Route hints** (A-C: card, chips, path marks, 4 spots) | highest: every visitor gets it | ~1 long session | low: reuses Tutor, camp V, the lab's card |
| **Edge-on door** (F) | high wow, teaches thin-vs-whole | small: reuses Trym's portal and the walk-up's landing | low |
| **Balloon in W** (E) | high: the clearest "find it in W" moment | medium: forks of balloon and Lookout scripts | medium: the ride must stay intact (tests exist) |
| **Kata cache** (D) | medium-high: the azoth treasure | medium: new knoll, chest, trail | low-medium: box colliders around the opening |
| **Echo towers** (G36) | medium: a skyline that changes through W | medium | **high**: video memory, projection, mesh limit. Measured, capped at 2 |
| **More hills** (G37) | low-medium | small-medium | medium: collision walls, grass rebake |
| Second cave via a crossing | – | high | high: replaced by D's cave in W |

**Suggested order:** A-C, then F, E, D, then G only if there's time and the numbers allow. The bookshelf is never an
optimisation target. The dev look's single box (today's fix) only applies with the dev look on.
