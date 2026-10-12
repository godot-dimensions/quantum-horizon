# Ref-lock: building from the paintings, measured (plan, 6 Oct 2026)

Ramon, 6 Oct, after the first Watchstone and range: "It looks nothing like the concept ... IS there
a way to be more accurate? research a way how to make this happen. analyse deeper and measure if you
have to." Then: more low-poly rocks with clear cut faces, in a hierarchy; scaffolds and fences that
follow the design (fence tech, no pins); a campsite and Trym's cottage from new sheets; a 60-step
plan with testing, rethinking and pivoting; "always rewatch the ref. ref ref ref". Halt on executing,
show the plan first.

**Status: a plan only. Nothing below is built yet.**

Pictures that go with this plan, all in `PenLayout/refs/` (hidden from Godot by a `.gdignore`):

| File | What it is |
|---|---|
| `watchstone_views.png`, `range_views.png`, `camp_views.png`, `trym_cottage_views.png` | Your four sheets, full resolution |
| `watchstone_concept.png`, `range_concept.png` | The two first paintings |
| `analysis/first_build_vs_ref.png` | Your painting next to my first build, with what went wrong |
| `analysis/watchstone_breakdown.png` | Your three views with every timber part numbered (T1-T9) and the rock courses (R0-R4) |
| `analysis/watchstone_materials.png` | Your three views split by colour into rock, grass and timber, with the measured shares |
| `analysis/rock_system.png` | The rock hierarchy as a system, and what a "designed cut" stone is |

---

## 1. Why the first build missed (the honest version)

Measured against your sheet (`analysis/first_build_vs_ref.png`):

1. **Silhouette.** Yours is a tapered drum in three stepped courses with a flat top. Mine is a
   lumpy beehive.
2. **Rocks.** Yours are crisp grey blocks, taller than wide, laid in courses with grass in every
   joint. Mine are soft beige blobs in a random ring, with no joints.
3. **Grass.** 28% of your front view and 31% of your side view is grass and moss (counted, pixel by
   pixel). Mine has almost none on the crag.
4. **The route.** Yours: ground → lower landing → long stair back across the face → walkway along a
   ledge → cantilevered platform; a separate scaffold tower carries the upper platform and its ladder.
   I built a different route.
5. **The scaffold.** Yours is a three-post tower with one diagonal per bay, standing on the lower
   landing and hugging the east face. Mine stands off to one side.
6. **Colour.** Your rock measures #a2988f, timber #976e4b, grass #757915. Mine went beige and dark
   under the pen's evening sun, and I never checked.
7. **Method, the real cause.** I read the painting once, wrote a recipe from memory and randomised
   it. I did not measure, did not overlay, did not look again. My own note from the deck work says
   exactly this ("eyeballed glyphs were not even close"); I did not apply it.

## 2. The research: how to get accurate

How 3D artists match concept art, and how measurement in computer vision checks it, matched to what
this engine allows:

- **Blueprint modelling.** Artists put the front, side and top views behind the model and build to
  them. Our 4D views cannot show an image plane, so the comparison happens on captured frames.
- **Camera matching.** fSpy and Blender's camera match recover the painting's camera from known
  lines. Your sheets are paintings with mild perspective, so I fit each view's camera from known
  points instead: the player (1.54 m), the plateau's ring and the ground disc. That is camera
  resection by least squares, a few lines of numpy.
- **Blockout first.** The big shapes are placed as grey boxes and checked against the painting
  before any detail goes on. This is where the first build went wrong, and it is the cheapest place
  to fix things.
- **Primary, secondary, tertiary forms** (the rock sculpting rule): one big form, medium forms on
  it, small forms last. Sizes roughly 60/30/10. This is your hierarchy point exactly.
- **Measured comparison.** Silhouette overlap (IoU: how much of the painting's outline the build
  covers, and vice versa), overlap per material (rock, grass, timber from the colour split), colour
  difference per material, and how far named landmarks are off in metres.

The colour split already works on your sheet: `analysis/watchstone_materials.png` separates rock,
grass and timber cleanly.

## 3. The system: Ref-lock

Every unit goes through the same loop, and nothing moves on without its sheet.

1. **Refs in the repo**, one folder per unit, never edited.
2. **Measure.** A tool cuts each view out of its background, splits it into materials by colour,
   and gives width per height, material shares and mean colours. The player in each view is the
   scale bar. Measured so far: player 73 px tall in the Watchstone front view and 67 px in the side
   view, so about 45 px a metre. The crag is about 13 m tall and 13-14 m across at its foot, and
   the plateau is about 7 m across.
3. **Spec sheet.** Every element named (T1-T9 timber, R0-R4 rock, and so on), with its position and
   size in metres taken from all three views: the top view gives the plan, front and side give the
   heights. Where your views disagree (they are paintings), I list each clash and the rule I used:
   the top view wins on plan, front and side on heights. Any clash that matters goes to you.
4. **Camera presets.** One fitted camera per view, so a capture lines up with your sheet pixel for
   pixel.
5. **Ref-match captures.** The unit is rendered from each fitted camera at your sheet's size, on
   your grey background (sky and terrain hidden). There are two lights: a neutral one to compare
   colours, and the pen's own.
6. **Compare sheet.** Your view, the build, a 50% overlay and a silhouette difference (red: missing,
   blue: extra), with the numbers.
7. **Gates.** Silhouette overlap at least 0.85 per view, named landmarks within 0.4 m, material
   colours within a just-visible difference, and a written ref audit: every named element present,
   in place, the right count, the right shape.
8. **Rewatch.** Every step ends on the compare sheet. I write down the three biggest differences
   before touching anything else. The sheets are numbered in `refs/progress/`, so the history is
   visible to you.

## 4. Case study: the rock system

From your front and side views (see `analysis/rock_system.png`):

- **L1, the core.** One large rock is the crag's mass. It sets the silhouette (a stepped drum, three
  courses, flat top) and carries the colliders. It is built from the measured width profiles, not
  from a ring of random boulders.
- **L2, the face blocks.** Medium stones, upright (taller than wide), one course per tier, set
  against the core with narrow joints. Their count and sizes are measured from your views by tracing
  every block's outline, not guessed. Where your painting has a big one (the large block left of the
  middle in the base course), the build has a big one there.
- **L3, ledge and joint stones.** Small and flattish, lying where the courses step in and grass
  collects.
- **L4, debris.** What fell from the face: big near the foot, smaller further out, fewer further
  out, half sunk, in clusters of three and five. Your sheet has a ring of it round the base.
- **Logic.** Every stone rests on something (a runner checks: no floating, no deep overlap). Moss
  goes on what faces up. Grass grows on ledges and in joints, tuned to the measured 28-31%.
- **One stone: designed cuts.** Each stone is built exactly as the intersection of 8 to 14 placed
  flat planes. In maths terms that is a convex polytope; in sculpting terms, a block with its planes
  cut deliberately. There is a near-level cap, four to six near-vertical sides and chamfers on the
  main edges for the rounded look. Big faces come first, small chamfers second. It is flat shaded,
  so every plane reads as one clean face. The planes lean in W too, so a turned slice still cuts
  clean faces. About 200-400 tetrahedra a stone, against 2,240 now.

## 5. Timber and fence tech

Read from the generator's own docs (`engine/modules/quantum_horizon/doc_classes/FenceGenerator4D.xml`):
a fence's seed may rise and fall. The posts stay vertical and the rails follow the slope, sheared so
they keep their thickness. So **stair railings can be real fence tech**. My first build hand-made
them; that changes.

| Part | Built as |
|---|---|
| T9 plateau railing | Round fence, post count and height measured, two rails, post caps |
| T1, T3 stair railings | Sloped fences (seed with heights); stringers and treads at the measured slope |
| T2, T5, T7 platform railings | Box fences, open where a stair or ladder joins |
| T6 scaffold tower | Box-fence frame: the posts as drawn, ties at the four drawn levels, one diagonal per bay in the drawn directions (the diagonals as struts; the fence has none) |
| T8 ladder | Two rails and the counted rungs |
| Range fences, board frames | Fence tech, posts with caps, rails counted |
| Camp cooking frame, lantern post, tent poles | Fence tech where it fits (two posts and a beam) |

Pins in the wood are skipped. Everything else is counted and measured: post spacing, rail count and
heights, cap size, brace directions per bay, plank direction, tread count.

## 6. The 60 steps

Each part ends on a rethink. A **pivot** line says what I change if a gate fails. **Show** means
frames go to you before I carry on.

### A. The Ref-lock system (1-10)
1. **Refs in.** The sheets in `PenLayout/refs/` (done while drafting this plan), with each view cut
   out as its own file.
2. **Measure tool.** `PenLayout/tools/ref_measure.py`: background cut-out, the material split, width
   per height, material shares and colours. Output is a measure sheet per view. *Test:* run it on all
   four sheets and check every material split by eye against the painting.
3. **Scale.** Render the chibi avatar and measure its true height (1.54 m from its code, to be
   confirmed in a frame). Pixels per metre per view, corrected for depth with the ground disc.
4. **Camera fit.** Fit each view's camera by least squares: tilt, turn, field of view and distance,
   from at least six landmarks. *Test:* the fitted camera puts a known test scene (posts at known
   spots, plus the player) on the painting's landmarks within 5 px.
   *Pivot:* if a painted view will not fit one camera (painted perspective cheats), fall back to a
   per-element fit and score element by element.
5. **Ref-match capture mode** in `_capture_pen_runner.gd`: fitted camera, your grey behind it, sky
   and terrain hidden, a neutral light option, rendered at your sheet's pixel size.
6. **Compare tool.** `ref_compare.py`: your view | build | 50% overlay | red/blue difference, plus
   silhouette overlap, overlap per material, colour difference per material and width error per
   metre of height.
7. **Spec sheet format.** JSON plus an annotated image per unit: every element named, with its
   position and size in metres and which view each number came from. View clashes are listed with
   the rule used.
8. **Gates written down** (section 3, point 7) and the ref audit checklist template.
9. **Rewatch rule in the loop.** Every capture round writes its compare sheet to `refs/progress/`
   with a number, plus my three-differences note.
10. **Prove the system on itself.** Score the first Watchstone build. It must fail clearly. Then
    score a quick blockout made from the spec. It must score far better. *Rethink:* if the numbers
    don't separate a bad build from a good one, the gates are wrong; fix them before building
    anything. **Show** you the two scores and sheets.

### B. The rock system (11-20)
11. **Trace the stones.** Outline every boulder in your Watchstone front and side views. Record
    count, size spread, upright ratio, tilt and joint width, course by course. Same for the range's
    outcrop. This is the case study's numbers.
12. **The designed-cut stone.** A generator that builds a stone exactly from its planes, cuts it
    into tetrahedra and flat-shades it, with moss on up-facing faces. *Test:* one stone at W 0, ±0.5
    and in a turned slice; count the tetrahedra; no cracks or inside-out faces.
13. **Stone archetypes.** Six to eight designed recipes matching your shapes: upright block, tall
    slab, cap stone, wedge, rounded block (more chamfers), ledge stone, debris chip. *Test:* a sheet
    of each next to a crop of its painted twin.
14. **Hierarchy as rules.** L1 core from the width profiles. L2 courses with counts and sizes from
    step 11. L3 on ledges and joints. L4 debris with the falloff and clusters.
15. **Rest-on check.** A runner that finds floating stones and deep overlaps, and fails on any.
16. **Grass and moss kit.** Low-poly spiky tufts like yours, moss caps on up-facing faces and grass
    strips along every ledge and joint. Coverage is tuned to the measured share in the ref-match
    capture.
17. **Colour calibration.** Measure the rendered rock, grass and timber colours under the pen's
    light, and set the albedos so they land on your measured colours within the gate.
18. **Crag study scene** (rocks only, `PenLayout/Watchstone/rock_system_study.tscn`), scored against
    your views with the timber masked out of your painting by the material split.
19. **Rethink.** **Show** you the archetype sheet and the crag study next to your views.
    *Pivot:* if it doesn't read as your rocks, change the cut recipe (bigger facets, fewer or more
    chamfers) or the courses. If rules can't get the composition, place the L2 blocks by hand from
    the traced outlines.
20. **Budget.** Tetrahedra per crag and frame time in the pen against today's build, then bake the
    stones to files.

### C. The Watchstone (21-34)
21. **Spec sheet.** Crag dimensions per course, ledge depths, the plateau and where it sits on the
    crag, and T1-T9 positions, heights, slopes and counts, all in metres.
22. **Blockout.** Grey boxes for the courses and every timber part, scored. *Gate:* silhouette 0.85
    and landmarks 0.4 m before any detail. *Pivot:* if the gate fails twice, re-measure that view;
    the spec is wrong, not the build.
23. **L1 core** from the measured profiles.
24. **L2 courses** following your traced outlines, big blocks where yours are big.
25. **L3, L4 and grass.** Compare, rewatch, fix.
26. **Fence-tech audit.** A study scene with each timber type from the fence generator (box, round,
    sloped seed), framed at W 0 and either side. Measure post and rail sizes as they appear in the
    slice, and set each part's numbers.
27. **T9 plateau railing.** Round fence: posts counted from your top view, two rails, caps.
28. **T1 first run and T3 long stair.** Stringers and treads at the measured slopes, sloped fences
    for the railings, support posts down to the rock as drawn.
29. **T2 lower landing and T5 left platform.** Decks with the drawn plank direction, box-fence
    railings open where stairs join, legs and the drawn diagonal braces.
30. **T6 scaffold tower, T7 upper platform, T8 ladder**, exactly as drawn: the posts, the four tie
    levels, one diagonal per bay in its drawn direction, standing on T2 and the rock.
31. **T4 mid walkway** along its ledge, with railing.
32. **Full compare**, all three views, fix list, second pass. Rewatch every T and R against the
    breakdown sheet.
33. **Rethink.** **Show** you the ref-match sheets and in-pen frames. *Pivot* on whatever you flag
    before wiring.
34. **Wire.** Walk-up zone moved onto the new T1, Wren on the plateau, colliders following the new
    courses, the way down at the T8 ladder head. Rerun the Lookout tests (they pass today on the
    first build).

### D. The range (35-41)
35. **Spec sheet** from its three views: yard size, fence posts and rails counted, board frames,
    outcrop, table, banner, stone, master.
36. **Blockout** and compare. *Gate* as step 22.
37. **Outcrop** with the rock system: a core ridge, face blocks, grass on top.
38. **Fences and board frames** from fence tech, counted and measured.
39. **Table, rifles, banner frame, barrel, rune stone** at spec, colours calibrated.
40. **Compare, rewatch, fix.** **Show** you.
41. **Into the pen.** The swap is already prepared and not applied: the shooting goes, the rune
    stone button, the master's reach. Then the sand floor and the tests (the rune stone runner is
    written, not yet run; the pen trip).

### E. The campsite (42-50)
42. **Spec sheet** from its three views: ground disc, both tents (size, angle, which one is open),
    fire ring, benches, crates, barrel, firewood, axe stump, lantern post, cooking frame, stones,
    guy ropes and stakes.
43. **Fence-tech map** for the camp: cooking frame (two posts and a beam), tent poles, lantern
    post, stakes. Canvas, bedroll, crates and barrel built as shapes.
44. **Blockout** and compare.
45. **Tents.** The open one with its bedroll, the closed one with the diamond, maroon trim, rope
    tops, guy ropes to stakes.
46. **Fire, cauldron, benches, crates, barrel, firewood, axe, lantern glow.**
47. **Ground.** Sandy disc, grass ring, stones.
48. **"Align to slice" button.** When the camp is about half in your slice, a button saying "Align
    to slice" appears and turns your slice onto it, the way V does at the marsh. *Test:* a runner
    turns the slice through the camp and checks that the button shows only around half-visible and
    that pressing it lands the camp fully in view.
49. **Compare, rewatch, fix.** **Show** you.
50. **Into the pen** in place of today's camp (the old one backed up). Rerun the eggs/paths and
    layout tests.

### F. Trym's cottage (51-57)
51. **Spec sheet** from its two views: width, depth, wall height, roof pitch and overhang, plinth,
    door, window, rune disc, glowing slits, lantern, banner, step.
52. **Couplings audit** of the current cabin unit: the desk and laptop, Trym's seat, the cat's
    perches on the shed, the talk camera. Decide which two walls stay (the two behind Trym and his
    desk as the talk camera sees them) and which go.
53. **The cottage as a new unit**, the old shed kept as a backup: fence tech for the timber frame
    where it fits, plinth stones, plank roof with bargeboards and end blocks, plaster walls, stone
    door frame, glows.
54. **Compare, rewatch, fix.** **Show** you.
55. **The cutaway.** When Trym starts talking, the roof and the two front walls go; the two back
    walls and his desk stay; everything returns when the talk ends. *Test:* start and end the talk
    and check nothing stays hidden. The cat still finds its perches.
56. **Into the pen** only when you say so (fork before replacing).
57. **Tests:** Trym, the dreamer, the crossing, the cat.

### G. Proof (58-60)
58. **Final ref-match sheets** for all four with the numbers table, in-pen frames at W 0 and either
    side, tetrahedra and frame time against today.
59. **The full pen test pass.**
60. **Handover** in `follow_up/`, memory notes, commits by explicit path.

## 7. Where things stand now (uncommitted, nothing committed since d25cbcd)

- **Wired and passing.** The first Watchstone is in the Lookout site, with the walk-up, Wren
  restyled on top, his lines moved to "he" and the Watchstone, and the path to the boardwalk's foot.
  These Lookout tests pass: lookout, story, site, extras, ride, marsh align, card, no carry-over,
  eggs and paths. The rebuild keeps this wiring and replaces the look.
- **One old failure.** The dial test fails one check: it expects the cave at W 0, and the cave
  door has been at 4 ana since layout A. Not from this work.
- **Halted.** The range swap (prepared, not applied), the rune stone button and its test (written,
  not run), the sand under the range.

## 8. Decisions I'll take unless you say otherwise

1. **Order:** A, B, C, then D, E, F. The system and the rocks first, because the other three units
   use them.
2. **The camp** replaces today's researchers' camp (EggCamp, at W -2.5), in the same spot.
3. **The cottage cutaway** keeps the two walls behind Trym's desk as the talk camera sees them.
