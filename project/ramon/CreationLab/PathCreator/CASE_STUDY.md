# PathCreator: case study

A path system for 4D: a graph of routes and destinations from Ramon's Figma sheet, symbols drawn
as vectors on the floor, routes that reach into W, and a builder to lay them out while playing.
The plan is in `PLAN.md`; this page collects what was learned building it, in order, with the
pictures (`img/`).

## 0. Starting point (5 Oct 2026)

- **The sheet:** Figma "Path_Indicator", seven symbol libraries sharing one routing contract, a
  46 × 30 m field map with real footprints. Library 07 (Futuristic Stencil) is built first, and
  every symbol slot can later come from a different library.
- **The old path system** (`CreationLab/kit/kit_path_4d.gd`, 4 Oct) drew marks along Catmull-Rom
  strips through W.
  - **What it taught:** uniform arrays are shared by every material in this engine, so per-path
    data must go in textures or plain uniforms. Discard-only strips work. Curved strips bend the
    arrows (Ramon: keep them rigid).
- **Ramon's answers:**
  - library 07 first
  - F4 builds, F5 cycles looks, F6 flips DEV and WALK
  - one beige for the sand look
  - the W range is my call: ±15 m, see `path_spec.gd` W_REACH

## 1. Probes (steps 3 to 8)

| Probe | What it showed |
|---|---|
| **Vectors in the shader** | Library 07's nine masters read as SVG, flattened and packed in 3.5 ms: 1,018 segments, 23 shapes, 9 symbols. The shader measures each pixel's distance to the Figma's own outlines, so every symbol is sharp up close and from far away (`img/01_lib07_states.png`). Twelve symbol boxes on screen cost 0.1 ms a frame. |
| **Layers found by difference** | What E and F draw that D does not is the moving arc and the focus accent. The arc turns in the shader; F's arc and diamond come out cyan, as on the sheet. |
| **W per pixel** | `local_pos.w` reaches the fragment stage, so a mark knows where it is inside its box's W band. |
| **A W-sheared box** | It cuts as a slanted band. A 10 m route climbing from W −2 to +2, 0.8 m deep in W, shows a 2 m window that slides along it as the slice moves (`img/02_w_probes.png`). This is the "follow" mode, for free. |
| **The band's edge** | Thinning the outlines made the chevrons vanish too early and looked like cuts. The marks now shrink to a quarter, then go: they recede into W. |
| **Colour** | Lit marks on a sunlit floor washed out to sky blue. In the DEV look the marks are now emitted at the token colour. At gain 1.0 the sheet blue #1761d7 comes out #166bca and the edge grey #668bae comes out #7196b2; the cyan loses a little to the tone map (`img/03_colour_calibration.png`). |
| **The light** | With the Creation Lab's light carried over, a white floor reads light blue-grey (#b7c6dc), as the lab's floors do: the room's blue ambient. Faithful to the lab, not pure white. |
| **Keys** | F4 to F7 are bound nowhere in the project or the walker. |

## 2. The yard: the field map rebuilt (steps 10 to 52)

- **The graph:** the B1 field map, node for node, measured off the sheet's export (40 px a metre),
  as `graphs/yard.tres`.
  - 20 nodes and 19 edges: the entry, the equal choice, the turns, the curved survey approach of
    four chords, five destinations in their states, with frames round their objects.
  - 45 floor boxes; 0.1 ms a frame with the whole yard on screen (`img/04_yard_top.png`).
- **Sizes from the field map, not the masters:**
  - The map's junction is 0.39 m across against the master's 0.24 m, so junctions are drawn at
    1.6×.
  - The bend ring is 0.39 m and the balls are 0.16 m.
  - The secondary guide is dotted, as the map draws it.
- **Where marks end:**
  - Marks stopping 0.25P short of a node looked cut, half arrows in empty floor.
  - The default is now "hide": marks run up to the node's art and slide under it as they flow
    (Ramon's hide-under technique, the art being what they hide under).
  - "keep" (the sheet's 0.25P) stays as an option (`img/05_yard_close.png`).

## 3. Routes through W (steps 53 to 66)

Five stations, each a route from W 0 to its own blue cube at W +4. From above at W 0 to 4
(`img/07_w_stations.png`, stations across, W down):

| Station | What you see |
|---|---|
| **A static** | The route, its ring and its bracket at every W; the cube only at W +4. The way and the frame, without the thing. |
| **B here** | The whole route at W 0, nothing between, the arrival and the cube at W +4. |
| **C follow** | The visible stretch slides along the route from W 0 to 4: the route unrolls toward its cube. The sheared box does this on its own. |
| **D reveal** | Only the start at W 0; at W +4 the whole route and the cube. |
| **E ladder** | One leg per metre of W: walk a leg, walk ana, the next leg appears. |

**The W cue (step 59).** On B and E a route stops where it goes on at another W, and nothing
said which way. The sheet has no symbol for this, so PathCreator adds one: a row of dots beside
the end you can see, one per metre of W still to go (at most four), warm for ana and cool for
kata (the builder's colours). It sits at the W you arrive from, not at the node's own, because
that is where you stand when you need it. On the ladder at W 0 one warm dot means walk ana a
metre; at station B's end, four warm dots, and at W +4 the dots are gone and the destination is
there (`img/11_w_cue.png`: ladder at W 0 and W 1 on top, station B at W 0 and W 4 below).
Follow and static routes get no dots: follow climbs as you walk, and static is already everywhere.

### Tilting instead of walking (steps 62, 64, 66)

The pen mostly moves you through W by tilting the slice (right mouse), not by walking. Tilted,
the slice is no longer one W: it pivots on you and climbs or falls with distance, about 0.09 m of
W a metre at 5° and 0.18 at 10°. So the same five stations were shot with the slice tilted
instead of moved (`scripts/_capture_tilt_runner.gd`, `img/12_w_stations_tilted.png`: stations
across; flat, 5° along, 10.3° along, 20° along and 15° across, down). 10.3° is the tilt that
matches the routes' own climb, W 0 to 4 over 22 m. Ink is counted in three stretches of each route
so this rests on numbers, and five checks pass.

| Mode | Under a tilt |
|---|---|
| **Static** | Holds at every tilt, every stretch. |
| **Here** | Becomes a short lamp around you: it shows while the slice stays inside its band, 7 m at 5°, 3 m at 10°. Its middle is gone at the matched tilt. |
| **Follow** | The find of this pass. At the tilt that matches its climb **the whole route shows at once, and the cube at its end with it**. Too little or too much tilt and it shrinks back to a stretch. |
| **Reveal** | Tilting toward its W brings its end into view from the start, before you get there. |
| **Ladder** | A piece of every leg at once, which reads as broken. The ladder is for walking. |

From the player's camera (`img/13_tilt_player_view.png`: station B flat and matched on top,
station C below) the follow result is the strongest picture in the study: flat, three chevrons and
nothing; tilted to match, the route runs out to its cube, and the other W +4 cubes stand up
behind it.

What it suggests for the pen (step 65, Ramon's call):
- **Main routes static.** They are the one mode that survives whatever the player does with the slice.
- **Routes into W follow, ending in a bracketed destination.** Walking through W unrolls them, and
  tilting to line one up shows all of it plus the place it leads. This is the pen's own trick
  (line up on a chicken by tilting) used for wayfinding.
- **Here and reveal** for local hints: "this belongs to your slice" and "something is over there in W".
- **The ladder** only where the player is meant to walk W step by step.

## 4. The builder (steps 67 to 79)

F4 in the running space:
- A camera straight down, still the live slice.
- Every node over it, coloured by its W (blue kata, white at 0, warm ana).
- Off-slice nodes and objects dimmed, and a W lane for the picked route (`img/08_builder.png`).

A scripted session through its own mouse and key handling passes every check:
- drag a node, N to add one, the wheel for W, X to split, M for W mode
- undo, redo, save and read back, the slice through W
- F4 back to walking

It edits the same `.tres` files the scene loads.

### The curve tool (step 74)

R over a corner in the builder rounds it the way the sheet draws curves: short straight chords
between small balls, as on the survey's approach. The corner is replaced by chords on an arc that
meets both legs tangentially, so the route runs straight into and out of the curve. R on the curve
again makes it wider (2, 4, 7 m), and after the widest it is a sharp corner again. Each chord is
at most 2.4 m long and turns at most 30°. Where a leg is too short for the radius, the curve
shrinks to fit (it uses at most 45% of the shorter leg). On a follow route, W climbs along the
curve as it did through the corner. The chords remember the corner they replaced, so making a
curve sharp again gives back the same corner (`img/14_curve_radii.png`: sharp, 2, 4 and 7 m on
16 m legs).

The work lives in the graph (`round_corner`, `curve_nodes`, `sharpen` in `path_graph.gd`), not in
the builder, so an editor dock can use the same three calls. It is tested two ways:
- `scripts/_capture_curve_runner.gd` checks where each radius meets its legs, and that W climbs on
  a follow curve.
- The builder session runs R on the yard's hut turn: round, wider, sharp again, with the same node
  count as before.

**Joints.** The first curves showed a fault that was already on the survey's approach: a chevron
crossing a chord was drawn half by each stretch, at two angles, so it looked broken. Now a
chevron is drawn whole by the stretch that holds its middle, reaching a little past the joint
(that stretch's box is half a chevron longer there). It crosses the joint whole and turns as it
moves on, and the small ball sits over it, as at any node (`img/15_curve_joints.png`, the 7 m
curve close up). Bends, junctions and destinations keep their clear floor.

## 5. The symbols against an independent renderer (step 35)

Every master was rasterised by Godot's own SVG renderer at 4 px a sheet unit and laid against our
shader's drawing of it, measured as overlap of the inked pixels (`scripts/_probe_overlay_runner.gd`,
`img/10_overlay_check.png`). The first pass found four things wrong, all in how strokes were
read; after the fixes every symbol of libraries 06 and 07 scores 0.92 or better, most 0.97-0.99:

| Found | Fix |
|---|---|
| Strokes drawn with round ends (the junction's arcs too long, 0.67) | Flat (butt) caps: each open run carries the half-planes at its two ends, cutting every one of its segments, so flattened curves are cut square too. |
| Sharp joins rounded (the secondary chevron's tip, 0.89) | Miter wedges added as fills of the stroke's colour. |
| Dashes ignored (the round frame's four gaps, 0.82) | `stroke-dasharray` cuts the stroke into dashes. |
| A floor-coloured fill painted over its own stroke (06's hollow junction, 0.30) | A path's fill before its stroke, as SVG does; a "floor" colour role that paints the floor's albedo. |

## 6. Looks and sets (steps 38, 39)

F5 moves every slot to the next library; in the builder, L moves only the slot under the hand (a
picked node's symbol, or the hovered route's chevron), Ramon's "toggle sub-icons separately". F6
flips DEV and WALK (`img/09_looks.png`: 07, 06, A from 06 with the rest from 07, WALK).

## 7. Toward the pen (steps 85 to 88)

**What the pen's ground is** (read from `playable_world.tscn`, nothing changed):
- The walkable field is one flat static box (`World/Ground`).
- The fence is six box walls: four in x and z, and two in W at -4 and +4.
- The hills and the cave hill are baked meshes nobody walks on, because physics is boxes only.

So uneven ground in the pen means boxes standing on the field (steps, platforms, crates), not a
height field. The pen's places (the keeper, the shed, the range booth, the professor, the
lookout) stand at W 0, over about 40 x 40 m, the yard's size. What lives in W is the chickens,
wandering inside the fence between W -4 and +4, and the pickups at about W +1.15.

**Draping (step 85).** A network with `drape` on lays its routes on whatever static box is under
them.
- Each node sits on the top it stands over (a ray straight down at its x, z and W).
- Each route is sampled every 0.2 m and laid as runs, one box per height, with the riser found to
  a centimetre.
- A chevron never crosses a riser. It shrinks as it nears the step edge, the way it does at a W
  band's edge, and the next run's chevron grows back beyond it. So the marks keep moving, and
  nothing hangs over a step or gets cut by one.
- A route that climbs more at once than the walker can step (0.32 m, its own `step_height`) gets
  a note in the builder.

Rays are cast only when routes are laid, never per frame.

**The pen patch (step 87).** `PenPatch` in the dev space (x 42, z -5) is built from the pen's own
numbers, a copy: nothing of the pen is loaded or changed.
- The fence: 8.4 x 7.6 m, W -4 to +4, with a 1.6 m gate.
- In front of the gate: a 0.25 m step and a 0.5 m deck.
- Inside: a feeder at W 0, a coop at W +3, and a hen.

The route (`graphs/pen.tres`) comes in over the steps, through the gate, to a choice:
- static to the feeder
- follow, up through W to the coop
- follow to the hen

`scripts/_capture_pen_runner.gd` passes 13 checks. The rays find floor, step, deck, step and floor;
the way in is laid in five runs, with risers at 3, 4, 8 and 9 m. The player then walks it with the
game's own input: up onto the deck (0.52 m at the highest), down, and through the gate into the
pen (`img/16_pen_views.png`: on the deck, in the pen, the approach in DEV and in WALK;
`img/17_pen_by_w.png`: from above at W 0, 1.5 and 3, where the coop route unrolls through W to its
coop).

**A bug found on the way.** The dev space's floor collider sat 0.25 m below the floor you see (it
copied the floor mesh's offset while also being its child). The player had been walking sunk 25 cm
into the floor everywhere in PathCreator, and it made the first 0.25 m step a 0.5 m wall the walker
could not climb. Fixed in `pathcreator_4d.gd`.

**Anchors (step 86).** A destination marked `anchor` follows its object. The hen wanders a loop in
the pen while drifting 1.5 m ana and kata (`space/pc_wander_4d.gd`), and her destination keeps its
place 0.8 m in front of her, in W as well. Only her own route, ball and frame are laid again, and
the graph file keeps the authored place (`img/18_hen_door.png`, top: three moments).

**Blocked routes (step 86, rule 09: "invalid edges hide").** With `hide_blocked`, a route whose way
is shut hides, and shows again when the way opens. "Shut" means a static box across it 0.4 m above
its ground: just over a step, so a step never counts. It is checked twice a second, one ray along
each run. Only routes hide; the nodes stay, so the junction still says there was a way. A door
across the gate hides the way in, while the routes on from the choice stay (`img/18_hen_door.png`,
bottom: shut, then open).

**What the pen will need (step 88).**
- **Looks.** WALK is one sand albedo, and the guide line is mixed toward the white floor's colour
  (`under_color`). On grass and dirt, `under_color` should be the ground's own colour, or the
  guide reads as a white stripe (it already does on the patch's grey steps).
- **W.** The places are at W 0, so their routes can be static. The chickens want anchored
  destinations on follow routes (the hen here), and the pickups at W +1.15 want a follow route or
  a W cue. The pen's W -4 to +4 is well inside the 15 m reach.
- **Size and cost.** The pen's 40 x 40 m is the yard's size. The yard costs about 0.2 ms with 45
  boxes. Draping adds rays only when a route is laid. Anchors re-lay one route each time their
  object moves 3 cm, so a dozen anchored chickens each lay one route a frame or two while they
  walk. Measure that in the pen before relying on it.
- **Fit.** The patch's interior shows the crowding: the pen is 8.4 m across, and a junction, three
  destinations and their frames fill it. In the pen itself, keep routes outside the fence to the
  gate, and give the chickens one shared anchored destination rather than one each.

## 8. The proof (step 89): rule 10 at the player's camera

The sheet's acceptance list (rule 10): "Test at the actual player camera: direction readable,
equal branches equally weighted, no symbol overlaps, object clearance maintained, arrival
reachable, and every visible route ends at a valid destination." `scripts/_proof_runner.gd` runs
all of it, and every PathCreator runner is green (twelve of them).

**The layout's own half** is now in `path_network_4d.gd` `acceptance()`, and so in the builder's
notes:
- no two symbols overlapping where their W bands meet, and no other node inside an object's frame
- no route within half a player of an object, measured in W where the route is walked (its nodes'
  W), not how far off it shows
- no destination standing inside an object
- every route that stops, stopping at a destination

The yard, the W field and the pen patch pass. The first run found a real fault in the patch: its
static routes were 8 m deep in W, exactly the fence's span, so they reached into its W walls.
They are 7.8 m now, just inside.

**Equal branches.** The yard's equal choice, from above: ink on the two branches over the same
3 m, averaged over five moments, comes out 0.91 to 1.

**Cost.** Every route in the space on screen at once (three networks, 112 boxes): +0.22 ms a
frame.

**Direction readable** (`img/19_read_at_camera.png`: the pen's Camera 2 at P x1, x1.5 and x2, down;
the yard's way in, the pen patch's steps and station C, across). Each blob of route ink on screen
is measured. One counts as readable at 24 x 8 px or more at 1280 x 720, which is 36 x 12 at
1080p: enough to see which way a chevron points. Each view has the player 8 m along a route,
walking it, so the route runs from under the camera past the player:

| | yard, static | pen steps, static | station C, follow |
|---|---|---|---|
| P x1 (0.6 m), Camera 2 | 22 readable | 5 | 1 |
| P x1, Camera 3 | 3 | 2 | 0 |
| P x1.5, Camera 2 | 27 | 4 | 2 |
| P x2 (1.2 m), Camera 2 | 28 | 4 | 4 |

What it says:
- **At the sheet's own size, walking a static route reads well** from the pen's own camera
  (Camera 2, the one it opens on).
- **A follow route shows only its stretch near you**, about 9 m of it here. Its nearest marks are
  4 to 12 m from the camera, about 20 x 8 px at the sheet's size, so their shape shows but they are
  under the bar. It takes P x2 for three readable marks.
- **Camera 3 (the diorama) reads worse at every size.** It is further back, so the marks are smaller.
- **The first version of this test was wrong.** It stood the player at each route's start. With
  the camera 8 m behind, nothing was near the camera, and the marks measured 12 x 3 px. The
  numbers are only worth what the camera's position is worth.

What size P should be in the pen is Ramon's call. It is a per-network setting (`p_scale`), and
the sheet's proportions hold at any size.
