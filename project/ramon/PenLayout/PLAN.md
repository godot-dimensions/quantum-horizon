# Pen layout: plan (6 Oct 2026, for Ramon to approve)

Ramon's goals for today:
- make every important unit its own scene, instanced in the pen, so each one can be tuned in 4D
- a watchtower case study with the fence tech
- then an intelligent layout around the pen
- then paths that stay tied to the units when they move

Agreed so far:
- Straight into the live pen (`chickenpen/playable_world.tscn`), with a backup
  (`chickenpen/.backup/2026-10-06_before_units/`) and the local tag `before-units-2026-10-06`.
- The pen itself stays as it is.
- Units turn in 90 degree steps.
- Where a unit stands (position, W, turn) lives in the pen scene; what a unit is (its shape, its
  W depth, the offsets between its parts) lives in its own scene, built round its own middle at W 0.

What the units are tied to (measured):
- **Links stored in the scene:** 402 in all. 50 point into the units: Trym's cabin 17, the keeper 15,
  the professor 6, the range 5, the tower 4, the rock pile 3, the cave 0. They can be rewritten
  automatically.
- **Paths typed into scripts:** about 15 lines in 11 files. These are found and fixed by hand.
- **Fixed world coordinates:**
  - the cave (its hill, mouth and block are constants: HILL (17, -40), MOUTH (16.5, -28.6))
  - the invitation's door spot
  - the theatre's laptop spot
  - the Lookout's balloon, marsh and wood defaults

## Phase 0: the fence fix (prepared, waiting for go)

1. Through the editor's own open and save (Aaron's advice): Pen/Fence gets
   `pen_fence_compat_4d.gd` (the old fence's questions answered by Aaron's fence, and its footprint
   built at load). The eight links cleared in the swap are set again.
2. Rerun the pen's own tests against this evening's baseline. In the broken state now:
   - script errors: fence 10,924; returns 43,224; flow 9,893
   - the celebration test fails
3. Play-check:
   - a chicken thrown in the pen is counted
   - the twelfth return throws the party
   - crows perch on the rail
   - the wolf leaps the fence
   - Nike hops it
4. Commit.

## Phase A: units as scenes (instancing)

5. **A tool that does a unit in one go**, run inside the editor so Godot writes the files. It:
   - makes the unit's root at the unit's anchor
   - moves the unit's nodes under it, keeping where they are in the world
   - rewrites every stored link that pointed at a moved node
   - saves the branch as its own scene (`chickenpen/units/<unit>/<unit>.tscn`) and puts an
     instance of it back
   - saves the pen

   A dry run first prints every change.
6. Its checks after each unit: the pen still loads, every link still resolves, nothing moved in the
   world (positions compared before and after), and the pen's tests are no worse than the baseline.
7. Script paths and fixed coordinates, made relative to their unit.

8. The units, one commit each:

| # | Unit | Nodes that go into it | Also |
|---|---|---|---|
| 1 | Trym's cabin | Shed, Trym, TrymHead, TrymStand, TrymLaptopUse, TrymDoor, RedCat (her den is the shed) | the invitation's door spot and the theatre's laptop spot made relative to the cabin |
| 2 | The keeper | Keeper, KeeperHead, KeeperFacing, TalkCam | |
| 3 | The range | RangeBooth, RangeMaster, RangeMasterHead, RangeMasterFacing | |
| 4 | The professor | Professor, ProfessorHead, ProfessorFacing | |
| 5 | The watchtower | the LookoutSite (tower, Wren, the owl's perch) | |
| 6 | Balloon, marsh, kata wood | one small unit each: their placement node, out of the tower site | the Lookout reads them by their own paths |
| 7 | The rock pile | RockPile, Cat | |
| 8 | The cave | CaveHill, with its mouth, block and hill constants made relative | the cave fade and the dream wake use the unit's place |

9. **Turning:** check that a unit turned 90 degrees keeps working, colliders included (the physics
   is boxes that do not turn, so this is tested, not assumed). Try it on the range first.
10. **The 4D pass per unit:** its W depth and closing in W (`follow_up/4d_enclosure_rule.md`), and
    frames at several W and in volume view, as in `STUDY.md`. This is where each unit is tuned
    against the fence tech.
11. **Proof:**
    - every pen test against the baseline
    - one scripted walk through the pen, with frames
    - the tower open and saved once in the editor to confirm it saves clean
12. Commit; tell Aaron and Andrew the pen is now split, and that the split is one large change to
    pull.

## Phase C0: every unit movable (Ramon, 6 Oct: "the fixes now that the instances are made are the most important")

Goal: any unit can be moved anywhere in the field, at any W, and turned in 90 degree steps, and
everything that belongs to it follows. Found by reading every script tied to a unit (the ones on
its nodes and the ones that link to them), every hard-coded position in the pen's scripts, and
every position-like value set in the scene.

Already safe:
- talk triggers and staging (world distances to the speaker; TalkCam is staged per conversation)
- the cats (their den door follows the shed's transform)
- the range's counter (local)
- the Lookout's balloon, marsh and wood (they follow the site)
- grass clearings (keyed by node)
- the walkable radius (a circle round the origin)

Not part of this: the cave's inside is its own scene, loaded far away (1 km along x) when you
walk in, and it never moves.

30. **The cave:**
    - the entrance trigger, the darkness fade on the way in, and the spot you wake at after the
      dream all compare against the hill's world coordinates; they move into the cave node's own
      frame
    - the crossing's way back out (8.5 m in front, facing out) turns with the cave
31. **Trym's walk and door:** the invitation's route (desk to door) and the door's spot are field
    coordinates; they become the cabin's own.
32. **The balloon ride:** its pass over the pen is drawn for the pen where it is now. The ride
    bends toward wherever the pen is from the mooring on that stretch (and nowhere else: take-off,
    landing and the W legs over the marsh and wood stay as drawn), so the Lookout can stand
    anywhere and Wren's "There's the pen" still has the pen below.
33. **Turning:** a unit turned 90 degrees keeps its colliders right (tested: the physics is boxes
    that do not turn).
34. **A layout check:** units not overlapping each other or the pen, inside the walkable circle,
    and no chicken home inside a building.
35. **Proof on a moved pen:**
    - a scratch copy of the pen with every unit moved and turned
    - the pen's tests run against it
    - checks that the cave entrance, Trym's door, the ride and the colliders went with their units
    - then the real pen put back

**What the proof found (6 Oct):**
- Fixed in the game:
  - waking from the dream pointed the camera at heading 0, so with a turned cave you woke
    looking away from it; it now faces the cave however the unit is turned
  - the crows measured the shed's roof without its turn, so on a turned, non-square shed they
    could land in the air beside it
  - the cats worked out where to go in field directions but walked in their unit's frame: in a
    turned unit the rock-pile cat never got back to its seat, and a cat could flee toward you.
    Their seat, perch, den and flight, and the grab's carry and throw, are now in the unit's frame
  - the people who turn to face you (keeper, professor, range master, Wren: one shared script)
    would have faced off by however much their unit was turned; the keeper's test passed anyway
    because it measured the same local angle, and now measures in the field
- The same mistake every time: a direction in the field's coordinates used as one in the unit's.
  Turning is kept (Ramon offered to drop it); each fix was two or three lines.
  - the hill lookup (`CaveHill.node_in`) failed from a node inside a unit (its owner is the unit,
    not the pen)
  - one fused line in `units/cave/cave.tscn` (two properties on one line; Godot read it, but it
    would not have survived much)
- Fixed in the tests: five of them (cave, cave fade, dreamer, professor, crossing) walked to the
  cave's old field coordinates; they now work in the hill's frame.
- **A layout rule, not code: the professor goes with the cave.** He stands at the mouth
  pointing people at it (his test checks 3 to 9 m), but nothing in his scripts reads the cave.
  Moving one without the other breaks the story silently, so the layout check says so.
- Already safe, checked: the crows find the shed by its node; the cat keeps out of the shed in
  the shed's own frame.
- The new layout check (`scripts/_check_layout_runner.gd`, step 34) caught the proof's own first
  layout: the cave turned so the professor stood 48 m out, past the 46 m the player can walk.

## Phase B: watchtower case study

Done last (Ramon). It works in `PenLayout/Watchtower/` and does not touch the pen.

13. Measure today's tower (`lookout/lookout_tower_4d.gd`): its legs, X braces, cab, catwalk and
    ladder; its tetrahedra and frame cost; frames at W 0, ±2 and its W ends, tilted, in Combined
    and in Projected.
14. A study copy without the diagonals (a fork of the tower script, so the live tower is
    untouched).
15. The base rebuilt with FenceGenerator4D:
    - a box footprint the size of the legs' spread, as deep in W as the cab (6.4 m)
    - posts as tall as the deck (about 10 m)
    - `top_footprint_ratio` = the cab's width over the legs' spread, so the legs lean in
    - three to five rings of rails
    - no filler, so only the corner legs
    - steel colours
16. The same measurements and frames as step 13, side by side. Variants: the ratio, the ring count,
    and filler legs.
17. A short verdict: how the fence tech serves structures here, and where else it fits (the cab's
    railing, a gate, the range's frame, scaffolding).
18. If Ramon likes it, the tower unit's base is swapped for the fence-built one.

## Phase C: the layout (after Phase A)

19. **A layout brief:**
    - the pen at the centre
    - the places in rings by how often they are visited (keeper and Trym close, then the range,
      the rock pile and the professor, then the tower and the cave)
    - sight lines: from the tower, the pen and the cave mouth
    - room kept for the flock and the cinematics
    - the field's edge (the hills start at 50 m)
    - the W places: the marsh at +8, the wood at -8, the owl at +1.5
20. **Two or three layouts drawn from above** for Ramon to choose.
21. The chosen one placed: unit instances moved and turned in the pen scene only.
22. **What else depends on where things stand** (found, then adjusted):
    - the chickens' spawn spots
    - Mithra's walk
    - the crows' perches
    - the cinematic cameras
    - the Lookout's photo spots
    - the wolf's run-in
    - Nike's ground
23. Proof: the pen's tests, and a walk-through with frames.

## Phase D: paths (after Phase C)

24. **Each unit gets an Arrival marker** in its scene (the spot and the way you come in).
25. **PathCreator's anchors learn to turn with their object:** today an anchored destination keeps
    a fixed offset; it should keep it in the object's own frame.
26. **The pen's path graph:**
    - a loop round the pen with spurs to each unit's arrival, each destination anchored to its
      unit, so moving or turning a unit carries its path
    - draped where the ground steps
27. **Routes to Mithra:** a route set of their own, shown in the dev look only, until Ramon decides
    on the walk look.
28. **Bringing the path network into the pen:** the kit scripts used from the pen. Nothing in the
    pen's own scripts changes for it.
29. Proof: rule 10 at the pen's camera (PathCreator's proof runner, pointed at the pen).

## What changed while doing it (6 Oct)

- **Phase 0 is done.** The fence fix took the pen's tests from about 63,000 script errors to none.
  Godot's own headless save rewrote 3,000 lines of the pen for a 10-line change (null shader
  parameters, renumbered resources), so the pen is edited at the text level and checked by loading
  it.
- **The units are 7, not 9:**
  - Trym's cabin (with RedCat)
  - the keeper (without TalkCam: it is every conversation's camera and stays in World)
  - the range
  - the professor
  - the Lookout as one unit (tower, Wren, owl, balloon, marsh, kata wood: the balloon's ride is
    drawn relative to its mooring and passes over the marsh and the wood, Wren's lines expect the
    pen below, and the story moors it by the tower)
  - the rock pile (with the cat)
  - the cave
- **Shared resources:** the cave's tint texture is also the hills', so it is now its own file
  (`terrain/terrain_tint_3d.tres`) that both use.
- **Script links:** where a script's default link pointed at a node that moved, the new path is
  set on the node in the scene, not in the script (`chickenpen_old.tscn` still uses those
  defaults). Five scripts that looked units up by a fixed text path now find them by name under
  World when the path misses.
- **Step 10 (the 4D pass per unit) waits** (Ramon: "optimization of instanced units can wait till
  later").
- **Couplings to keep in mind when units move (Phase C):**
  - the cave's HILL, MOUTH and BLOCK constants are world positions
  - the invitation's door spot is a world position
  - TalkCam frames every conversation from where it stands
  - the balloon's ride crosses the pen

## Order and answers (Ramon, 6 Oct)

- Order: Phase 0, then A (units), C (layout), D (paths), and B (the watchtower) last: "much less
  important than the layout for now".
- RedCat goes with Trym's cabin.
- Phase D is the first real use of PathCreator's path tooling, in the pen.

## Open questions for Ramon (answered above)

- **Phase B, now or after Phase A?** Running beside A is possible, since B never touches the pen.
- **RedCat:** in Trym's cabin (her den is the shed), or a unit of her own?
- **Scenery and Pickups:** they stay in the pen as they are for now. They are not buildings.
