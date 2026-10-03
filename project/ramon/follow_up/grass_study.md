# Grass for the pen: the case study

Ramon, 2 Oct 2026: "could there be a way to make grass, some kind of smart fakery, so we dont
have to draw millions of 4d blades? ... research one, and put all efforts in making this look
amazing ... i wanna see wavey grass", then "thinner ... medium long ... a realistic wind
algorithm ... the movement more subtle".

Built: `chickenpen/grass/pen_grass_4d.gd` + `pen_grass.gdshader`, a node `World/Grass` in the
Lookout scene (`chickenpen_lookout.tscn`; the pen file is untouched). Film:
`smoke_test_output/video/Grass test.mp4`.

## What the research said

| source | what we took |
|---|---|
| Ghost of Tsushima (Sucker Punch, GDC 2021) | every blade a **cubic Bezier rebuilt each frame** from four points; **Voronoi clumps** setting height, colour and lean; wind as **scrolled noise**; **rounded normals**; **view-space thickening** edge-on; LOD that **thins three blades in four** before handing over; 15 / 7 vertex blades; 83,000 blades in 2.5 ms on a PS4 |
| Breath of the Wild (and NedMakesGames' write-up) | root-to-tip colour ramp between two palettes; wind as low octaves applied at the tip, the root anchored |
| hexaquo's Godot grass series | the field fading into the ground colour so there is no edge; infinite plains by snapping instances to the camera |
| Unity-Grass (cainrademan) | AO faked by blade length; distance blending of normals |

Not taken: grass cards (they need transparency, and read as cards up close); shell texturing (a
lawn from above, not a meadow from the side).

## The 4D part: why it is not millions of 4D blades

The flock already proved the route. A Cross-section render draws in **camera space**, into a
World3D of its own; a plain 3D MultiMesh put in that world is in the same picture, depth-tested
against the 4D meshes, lit by the same suns - **as long as its shader moves its vertices into the
camera's frame itself** (the view uniforms, set every `RenderingServer4D.pre_render`). So the
blades are ordinary 3D geometry made by the GPU; only the shader knows about W:

- **Every blade has a w** and is thin along W (`w_radius` 0.3 m). The slice cuts it like any 4D
  body: full size on its own slice, shrinking as `sqrt(1 - (dw / r)^2)` as it leaves. Walk ana and
  the grass round you shrinks away while the next grows in.
- **Three layers along W** at every spot, set round **the w where the camera's slice crosses
  that spot of ground** - so a turned slice (RMB) still finds grass wherever it passes, instead
  of only along a line.
- **Nothing is stored.** The field is cut into square **tiles**, snapped to the world (so a
  blade never swims). The mesh is one tile's blades, each knowing its cell and layer (UV2); the
  script lists the tiles in view every frame and the MultiMesh draws one instance per tile. A
  hash of the cell gives its jitter, height, facing and w.
- **"You" is the player, not the camera** (Ramon, 2 Oct: "the detailed circle area should always
  take you as its middle point"). When the camera is the player's own (the orbit rig, a few
  metres behind them) the bands are centred on the player, so the detail spreads out round
  them, behind as far as ahead; on any other camera (the hawk, the Lookout's camera, a cutscene)
  on the camera. The slice and the frustum are always the camera's.

## The blade, the clumps, the wind

- **Blade:** a flat strip of ordinary 3D triangles bent along a cubic Bezier from root to tip,
  rebuilt every frame from four points: upright at the root, the tip's slope about 1.5x the lean
  (as a stalk held at its root bends). 11 vertices at your feet (9 triangles), then 9, 7, 5 and
  3 (one triangle) band by band out; more of them towards the tip; widest at the root, a point
  at the tip. Normals turned out at the edges (rounded), thickened in view space when seen
  edge-on.
- **Clumps:** a Voronoi of clump points (1.3 m), banded along W too; each blade takes its nearest
  clump's height (0.82-1.18x), colour (lush, ordinary or dry) and a slight lean to its middle.
  Kept gentle on purpose: strong clumps read as tufts.
- **Colour:** dark root, the clump's green, a pale tip; the passing gust brightens the tips (the
  silver waves on a field); one blade in 80 a flower stalk with a small head (white, yellow,
  violet); the field's far edge turning the field's own colour.
- **The painted look** (Ramon, 2 Oct, from a Ghibli-style meadow: "a very subtle color/hue offset
  for each blade, and clump parts with different color regions"; then, after three strong
  regions read off, "the scale slightly bigger and the colors on a whole less contrasty ...
  sapgreen as main and 2 corresponding offsets ... so sapgreen has the highest ratio"):
  - **sap green** (`colour_base`, #507D2A) is the field's main colour, over half of it;
  - **two offsets of it**, deeper and cooler (`region_deep`) and lighter and warmer
    (`region_bright`), each over a quarter (`region_share` 0.25), as the two ends of one slow
    world-space noise field about 13 m across (`region_size`). The cuts are the noise's own
    quantiles, read off its image at start, so the shares are what they say. A region moves the
    whole blade, root to tip, by its offset from sap green;
  - each blade's **hue** wanders a little towards yellow or blue (`hue_jitter` 0.05), its
    brightness by +-9%;
  - less contrast all over: a lighter root, the dry clumps half as strong;
  - **darker, to sit with the ground** (Ramon: "the groundplan color offsets too much"): every
    blade colour times `shade` 0.7 in linear light (about 0.85 on the sRGB numbers), so the
    field's edge and the bare ground between blades no longer read as a different green;
  - **sap green and its bright offset pulled towards the ground's colour** (`toward_ground`; 0.35
    first, then 0.18, "somewhere in between"),
    with the lush clumps and the tips; the deep region left alone (Ramon: "i like that one of the
    3 color codes merges with the base green ground ... darkening the remaining 2 colors closer
    to the base ground color too");
  - **saturation 1.45** (`saturation`; 1.25 first, then "more saturation"), about each blade's
    own brightness, so greener at the same values ("can you saturate the grass a bit?").
- **Light** (Ramon, 2 Oct: "what would you do to make it look better colorwise"; my answer was
  that the colours were nearly right and the light was missing - the sky is a low warm sunset,
  the grass was lit as on an overcast day):
  - **the sun through the tips**: tried and taken out (Ramon: "i doubt the tip thing works"). At
    0.3 it moved the field's brightness 2% looking into the sun - measured, glow off against on -
    and the yellow you see against the sun was already there, from Godot's BACKLIGHT on the
    blades; at ten times it only bleached a pale band along the horizon, where far blades lie
    straight towards the sun;
  - **cool roots** (`colour_root` a dark blue-green, not olive-black): the warm-over-cool split;
  - **haze with distance**: built, and off (`haze_amount` 0). At 0.5 it washed the field
    grey-beige while the bare ground and the buildings beside it stayed clear, so the grass stood
    out more, not less;
  - **cloud shadows** (`cloud_shadows`, off; 0.8 tried): soft dark patches about 40 m across
    drifting with the wind, the tips' glow gone under them. Only the grass darkens - the
    ground, buildings and people do not - which may show once one passes something.
  One texture read a vertex, about +0.02 ms.
- **Wind, modelled on wind in a crop:**
  - a mean wind (3 m/s) leans everything a little downwind;
  - **gusts travel downwind at 0.8 of the wind speed, in bands lying across the wind** (honami,
    the coherent gusts the shear at the top of a canopy makes); anisotropic noise 7 m down the
    wind by 18 m across, with a slow swell in the gustiness;
  - the bend follows the wind's **pressure** (speed squared) and **saturates** at the blade's
    stiffness (`tanh`): a breeze barely moves it, a gust lays it over, never flat (`bend_max` 0.42);
  - **taller blades lag**: each samples the gusts up to half a second in the past, so a gust
    travels through the field rather than snapping it;
  - each blade **rocks at its own natural frequency** (1.1-2.2 Hz, shorter ones faster), harder in a
    gust, with a little turbulent flutter across the wind.
- **Pushed aside** by the player, the chickens, Nike, the cats and the people (the 16 nearest),
  only within 0.6 m of their w.

## Where it does not grow

A mask texture (half a metre a cell over the 120 m field) holds, per cell, **up to two stretches
of W** where something stands on the ground. Two, because the marsh at w +8 and the kata wood at
w -8 are over the same patch of field. Built once at start from the **real geometry**: every
tetrahedron of every still mesh that touches the ground and stays low (a floor, a pond, a stone,
the foot of a wall - not a tower leg) marks the cells under it with its W reach; the hills and the
cave hill come from the Lookout's height map. 7,311 cells, 0.33 s, spread over frames; the grass
grows in when it is done. Moving things (people, animals, the balloon) are left out.

## The bands: the gap widens from you, the blade gets simpler, nothing steps

Ramon, 2 Oct: two rings (fine blades to 12 m, then wider ones further apart) read as "the second
row has bigger blades". He asked for "a radial gradient of widening the space in between the
blades, coming from center" and "less complex blades in radial rows behind center circle". So:

- **The gap is a smooth curve of distance from you**, not a step: 8.5 cm out to 3 m
  (`spacing`, `spacing_from`), then growing as a power of the distance to 30 cm at 44 m
  (`spacing_far`, `radius`).
- **Five bands** (`band_radii` 5, 10, 18, 28, 44 m), **the same blade in each, with fewer
  vertices** (`band_vertices` 11, 9, 7, 5, 3). A band's grid is as fine as the gap wanted at its
  inner edge and keeps (its gap / the gap wanted)^2 of its blades, by hash, so the density follows
  the curve inside the band too.
- **Neighbouring bands overlap and cross-fade** (0.75 m + 3% of the radius each side), and a blade
  near its hash's cut is shrunk rather than dropped, so walking grows and shrinks blades and
  never moves a line.
- **The width does not step either.** A blade is `blade_width` (9 mm) until that would be thinner
  than `min_pixels` (0.8) on screen, then that. At 30 m 9 mm is a fifth of a pixel: it flickers
  and the field goes bare, which is why the old far ring had wider blades - but as a step.
- **Tiles, culled on the CPU**: about 2 m near you to 7 m at the edge; listed round you when you
  have moved half a metre, tested against the view every frame (a ball round each middle, at the
  slice's w there). Only tiles in view are drawn, so there is no work behind the camera.

| band | gap at its start | tile | vertices | tiles in view (farm camera) |
|---|---|---|---|---|
| 0-5 m | 8.5 cm | 2.2 m | 11 | 39 |
| 5-10 m | 9.8 cm | 2.9 m | 9 | 58 |
| 10-18 m | 14.2 cm | 3.8 m | 7 | 60 |
| 18-28 m | 19.0 cm | 5.1 m | 5 | 55 |
| 28-44 m | 23.6 cm | 6.9 m | 3 | 54 |

## Rings that moved with you, the trail, the clearings (2 Oct, late)

- **The rings** (Ramon: "i see subtle rings move with the character grass in the distance").
  Measured with `_rings_grass_runner.gd`: still air, a camera held still that is the player's own,
  the player stepped a metre at a time; any change far off is the bands. The thinning had
  overshot by a quarter (`share x 1.25`), so each band ended 5-12% denser than the next began:
  a step at every band edge, moving with you. Now the hash cut is centred on the share kept,
  and the shrink is in height only, so two cross-fading bands add up to one. What is left is
  unstructured: blades near their cut grow and shrink as you walk, as any distance thinning
  does. (The flutter now scales with the wind, so still air is still.)
- **Laid the way you walk, and a trail** (Ramon: "it shouldnt go down radial, but in the
  direction you move ... stay down but a bit, and slowly veer up again, 3 meter behind you"):
  every pusher has a way (where it has gone since it last moved 5 cm), and the grass is laid
  along it, a little aside too so it does not stand up through the legs. The player drops a
  trail point every 30 cm; each keeps the grass down, at full strength for the first 40 cm,
  coming up smoothly by 3 m behind (`trail_length`), and over 6 s if you stand
  (`trail_seconds`). Pushers are now (x, strength, z, w) plus (way, reach), 24 at most;
  `_trail_grass_runner.gd` films it.
- **Clearings** (Ramon: "the marsh, the pen, and the tower, should have a radius around it that
  doesn't have the grass, the edges shouldnt be straight square or round, but uneven like
  realistic"): `clearings` names what gets one and how far out (AnaMarsh 1.2 m, Lookout 2.5,
  Pen 1.5); `clearing_fill` names those cleared inside their whole outline too (the pen's run,
  the ground under the tower). Built with the mask: what they stand on seeds a grid, a two-pass
  distance sweep spreads it (18 ms), per group of w (the farm's, ana, kata) so the marsh at w +8
  clears only there. The shader breaks the edge with two scales of noise (`clearing_ragged`
  1.2 m) and thins and shortens the grass over a fringe outside it (`clearing_fringe` 1.5 m).
- **The mask follows the real shape.** A tetrahedron marks only the cells its shadow on the
  ground covers, not its bounding box: the marsh's mud is a fan of long thin wedges whose boxes
  bared a square in front of it. The mask now takes 0.85 s (was 0.33), still spread over frames.
  `_probe_bare_runner.gd` says what keeps grass off a spot.
- **A test look** (Ramon: "slightly higher, slightly more, and slightly broader from the start,
  to the tip"): `blade_height` 0.38, `spacing` 0.075 near and 0.27 far, `blade_width` 0.011
  and `taper` 0.5 (was 0.75: the blade stays broad further up).
- Cost now: **+0.64 ms GPU** from the farm camera (+0.35 low), the script about 0.11-0.14 ms.

## Looks: presets and the grass panel (2 Oct, night)

Ramon: "make transparent hud buttons for a grass panel, save this as preset 1. now lets work in
preset 2. longer grass, thinner grass and more grass, yes more, and improve the wind animation,
make it flow like on barley fields, even though its not".

- `grass/pen_grass_looks.gd` holds the looks: **1 Meadow** names every value a look sets (the
  field as it was then); **2 Hay meadow** (first called Barley) names only what it changes (0.62 m tall, 7.5 mm wide,
  taper 0.6, 5.8 cm apart near and 21 cm far, the barley waves on, softer gusts, more sheen).
  `start_preset` on the Grass node picks the look to start in (2 now; 0 keeps the node's own
  values); `apply_preset(n)` switches, rebuilding the bands (their grids depend on the gaps).
- **The panel** (`grass/pen_grass_panel_4d.gd`, made by the Grass node when `show_panel`): the
  camera picker's see-through style, one button per look, on the left just above the to-do list
  (on 2560 x 1440 the right side is full). Click one (Esc first, for the mouse) or **G** for
  the next. `_panel_grass_runner.gd` checks it switches.
- **Barley waves** (`wave_strength`, `wave_length` 8 m, `wave_speed` 3.2 m/s, `wave_width`
  22 m): a travelling wave down the wind whose crests are bent and broken by noise, in sets of
  stronger and weaker; its pressure adds to the wind's, so the stalks lean and come back
  together (the tall ones a moment after, by the lag), each stalk's own rock and flutter cut
  by 60% under it, and the tips catch the light as a crest lays them over (sheen). Film:
  `smoke_test_output/video/Grass barley.mp4`.
- Cost of Barley: **+1.08 ms GPU** from the farm camera (+0.58 low), 1.3 million blades handed
  over in view; Meadow stays at +0.64.

## 3 Oct: Hay meadow, the lighter ground, O not G

- Preset 2 renamed **Hay meadow** (Ramon: "i wouldn't call it barley ... its more like longer
  beautiful grass"). The waves are still the barley-field motion he asked for.
- **The panel's key is O** (Shift+O the ground). It was G for a night, but G is the project's
  `carry_pig` action (picking Nike up): checking the input map first would have caught it.
- **Lighter ground, a reversible test** (Ramon: "align the darker green ground color to the
  barley, meaning, making the ground floor lighter. but i do want to be able to revert"):
  `lighter_ground` on the Grass node (on), `lighter_ground_colour` (0.28, 0.34, 0.10). The
  pen's ground material is only changed in memory while the scene runs, its own colour kept on
  the material as metadata and put back when it is off; nothing in `chickenpen.tscn` changes.
  The panel's Ground buttons ("Pen's own", "Lighter (test)") and Shift+O switch it. Measured
  on the wide view: bare ground past the grass (80, 97, 39) against the grass at 15-25 m
  (82, 96, 37), so the field ends without an edge; the pen's own was (62, 71, 41). The far
  edge of the grass fades to whichever ground is drawn (`edge_colour`).

## 3 Oct, later: the painted ground, Pasture, fewer vertices

- **The flat lighter ground is gone** (Ramon: "the original, darker green still makes more
  sense in regards to the dusk or dawn mood"). In its place **the painted ground**
  (`grass/pen_ground_paint_4d.gd`, `ground_paint` on the Grass node): the ground slab's
  material colours it from a 3D texture through each cell corner's UVW, as the baked terrain
  does, with every corner's UVW its own x, z and w - so the texture is a map of the field, lit
  and cut like any 4D surface. On it:
  - **a glow**: `glow_colour` (0.25, 0.31, 0.095), a touch darker than the grass, full out to
    `glow_in` 8 m round `glow_centre` (-4, -14) (the farm's buildings are round it), the pen's
    own dark green by `glow_out` 85 m; along W gone by `glow_w` 30 m. Measured: the ground
    behind the pen (66, 88, 36) against the pen's own (55, 72, 38), the far corners unchanged;
  - **the sandy yard** ("keep the surface of the pen inside, and a little beyond 'sandy'"):
    within `sand_beyond` 1.8 m of the pen's outline (taken from the mask's footprints, at the
    pen's w), the edge broken by `sand_ragged` 1 m of noise, mottled, worn towards the grass.
  - **W is piecewise**: the slab is nine boxes stacked along W at -60, -24, -10, -4, -1.5, 1.5,
    4, 10, 24, 60, a texture layer at each break: fine near w 0, coarse where it is all dark.
  - **Cost**: painting it is 10 layers of 256 x 256 texels in GDScript, about 0.3 s **once, at
    the start**, a layer a frame (after the mask). Nothing a frame after that: one texture read
    where the ground is drawn. About 5 MB of video memory. It could be baked to a file to make
    the start free too.
  - Reversible: off puts the pen's own mesh and material back (panel: Ground, "Pen's own" /
    "Painted"; Shift+O). Nothing is saved into `chickenpen.tscn`.
- **Preset 1 is now Pasture** ("option one could be the shorter grazed grass ... start from
  scratch ... less thick, more, and shorter, feel free to reduce polycount"): 16 cm, 6 mm wide,
  4.5 cm apart near, 5 vertices a blade near you and 3 beyond 10 m, small clumps, a stiff short
  bend and more sheen. +0.82 ms GPU from the farm camera, 1.5 million blades handed over.
  The old 38 cm Meadow is `BASE` in `pen_grass_looks.gd` now; each look names only what it
  changes from it, so reworking one cannot move another.
- **Hay meadow, one bend fewer** ("if you'd remove one vertex on each grass, would that help?
  ... the general style is low poly"): bands 9, 7, 5, 3, 3 vertices (from 11, 9, 7, 5, 3).
  Measured the same session: +1.31 ms -> **+0.85 ms** GPU from the farm camera; side by side
  at play distance the bend reads the same.
- **The looks file: no packed arrays in a constant.** Godot will not parse
  `PackedInt32Array([...])` inside a `const` dictionary, and a Grass script that fails to load
  leaves the measure runner waiting for the grass for ever: it now gives up after 90 s. The
  looks list plain arrays; `_take` turns them into packed ones.

## 3 Oct, afternoon: sand round the marsh too, a faster painter, Pasture again, a longer trail

- **Sand by footprint, not by rectangle.** `sand_round` is a dictionary now (Pen 1.8 m,
  AnaMarsh 2.4 m): while the mask is built, every ground-touching tetrahedron of a named thing
  records the cells its shadow covers (and a `clearing_fill` name its whole outline too), and a
  two-pass distance sweep turns that into "how far inside the sand" per half-metre cell. So the
  pen's yard follows the fence and the marsh's sand follows the pond's oval, each at its own w
  (the marsh's at w +8).
- **The painter is about ten times faster** (Ramon: "0.3 seconds for what painted ground? seems
  like a lot"): the glow is smooth, so it is worked out on a 48 x 48 grid and scaled up, once
  per distinct strength along W; only the sand is painted texel by texel, and only round the
  sand. 321 ms -> 14-34 ms, once, at the start. The W layers now follow the sand: a pair either
  side of each patch, so the marsh's sand at w 8 is sharp.
- **Pasture, second pass** ("remove the strong brown gradient from the bottom entirely ...
  lower the vertexes and add more grass"): `root_dark` 0 (no ramp from the root colour and no
  shadow at the root - a new knob, 1 for the other looks), one triangle a blade everywhere, 3.6
  cm apart near and 16 cm far.
- **Hay meadow's trail** ("make the walked down trail longer, but let the grass recover a little
  faster"): `trail_length` 3 -> 5 m, `trail_seconds` 6 -> 4 s, a point every 35 cm. The trail
  knobs are in the looks now (BASE 3 m, 6 s).
- **The glow, judged** (Ramon: "i cant judge the brighter center falloff well, was it worth
  it?"): subtle. The grass covers the middle, so it shows in the strip of bare ground past the
  grass and in the clearings: past the grass on the left (62, 71, 41) -> (70, 83, 39), behind the
  pen (55, 72, 37) -> (67, 88, 35), the far corners unchanged. It costs nothing a frame and rides
  on the painted ground the sand needs anyway. **Its own toggle** ("can you make a toggle for me
  for the subtle brighter center falloff?"): `ground_glow`, the panel's "Centre glow" button,
  Ctrl+O; the ground is painted again without it (the sand stays), ~30 ms. Ramon found it hard
  to see ("center glow doesnt work, maybe overwritten by the paint layer"): measured, it does
  switch - with it off the painted ground IS the pen's own colour past the grass (62, 71, 41),
  only the sand added; with it on (70, 83, 39), and (73, 96, 37) behind the pen. It just hides
  under the grass except in the strip of bare ground past it.
- **Grass on / off** ("i also need a toggle for turning the grass off"): the panel's Grass
  button and Alt+O (`enabled`; not G, which picks Nike up).

## 3 Oct, later still: the far field fades out, the glow kept to the middle, Pasture stays put

- **The hard cutoff in the distance** (Ramon: "the centre glow was intended to fix the hard
  cutoff of the grass in the distance. right now, the center glow is not a gradient and cuts
  directly into the mountains, so the experiment failed"). Two things were wrong:
  - the glow reached 85 m, past the field's edge 46 m north of its middle, so it was still half
    on where the ground meets the hills and stopped there in a line: now `glow_in` 12 m,
    `glow_out` 40 m, gone well before the hills;
  - the real edge was the grass's: the far blades kept 55% of their own colour to the end (and
    only the last band faded at all), so the field ended bright against the dark ground. Now
    every band fades the blades to the colour of the ground under them from `far_fade_from`
    (half the radius, 22 m) to the edge, `far_fade` 1 of the way, glow included (the shader
    works the glow out too: `glow_area`, `glow_colour`, `glow_on`). The field ends without a
    line, and it is round you, wherever you are.
- **Pasture** ("should be more, and slightly wider. and when you walk over it, it should stay as
  is"): 3 cm apart near, 14 cm far, 7.5 mm wide; `trample` off (no pushing aside, no trail).
  +0.97 ms GPU from the farm camera, 1.6 million blades handed over.
- **Two looks cost one**: only the look in use exists; switching frees the old bands and builds
  the new (`_free_bands`). The other look is a dictionary of numbers. So there is no budget held
  by Pasture while Hay meadow shows.

## 3 Oct: darker, Pasture grazed, a third look

- **Both looks darker** ("make both grasses a bit darker"): `shade` 0.7 -> 0.6 in BASE.
- **Pasture, grazed** ("improve the pasture as you see fit"): up close it read as a combed
  carpet, every blade upright. Three new knobs, BASE values keeping the meadows as they were:
  `splay` (each blade's own lean, 0.08 -> 0.3: tousled), `tuft_share`/`tuft_height` (12% of
  clumps left long where the animals passed over, 1.9x and lusher), `flower_height` (stems 0.75 of
  a blade, so clover and daisies sit low among it; 2% of blades). Clumps 1.1 m. +1.07 ms GPU.
- **Hay meadow II** ("make a second grass meadow with changes you suggest"): Hay meadow with the
  budget it could have as the main field - 11 vertices at your feet (then 7, 5, 3, 3), 5 cm
  apart near and 20 cm far, 66 cm tall, reaching 52 m (the fade into the ground from 29 m), 2%
  wildflowers standing a little above it. **+1.19 ms** GPU from the farm camera against Hay
  meadow's +0.87 (measured the same session). O cycles the three looks.

## 3 Oct, afternoon: big gusts, sliders, daisies, leaves on the wind

- **Hay meadow II**: wildflowers 2% -> 0.7% ("its all over now"); **big gusts** ("sometimes
  have a stronger and larger gust of wind blow over"): one broad front (its line bowed by noise,
  steep in front, a longer tail) sweeps downwind across the whole field round you, a chance every
  16 s taken 70% of the time, +6 m/s and `big_gust_lean` 0.32 past the wind's own bend limit,
  14 m deep at 14 m/s, the tips lit as it passes. A speed alone barely showed (bend saturates
  at `bend_max`); the extra lean is what makes it read. The front runs from 90 m upwind to 110 m
  past you, so its tail has left the field before the next cycle (cut short, it ended in a
  flash). `_big_gust_runner.gd` stills every other wind and prints the field's brightness: a
  front lifts it ~95 -> ~105 and lets it down over a few seconds.
- **Darkness slider** ("so i can test and tell you later which number to pick"): the panel's
  Darkness, 0-0.75; it sets `shade_test` = 1 - darkness over every look's own shade, kept across
  looks. The number on the panel is the one to pick.
- **Wind slider** ("a windstrength slide or toggle? what you think is best" - a slider, one
  control for all of it): `wind_scale` 0-3 times the look's breeze, its gusts and their travel,
  the waves (capped at 1.6x) and the big fronts; the leaves follow it too. Kept across looks.
- **Daisies in Pasture** ("patches of these very little white flowers"): `flower_patch_size` 4 m
  patches from the noise, one blade in ten inside a patch a flower and none between;
  `flower_dot` 1.1 cm: a flower is drawn as a small dot facing you at its stem's top (a pentagon
  on the nearest band, which now has 5 vertices; a triangle beyond), lit as if facing the sky so
  it stays white; `flower_white` 1.
- **Leaves and bits on the wind** (`grass/pen_wind_bits.gdshader`; "flying leaves in the sky,
  but in a way that is natural. more wind would mean more leaves and bits"): up to 6,000 small
  diamonds in one MultiMesh, the same route as the grass (the camera frame by hand, in the
  Cross-section world). 30% leaves (7 cm, dry greens and browns, tumbling end over end), the
  rest seed fluff and specks (2 cm, pale, a little light of their own - lit only by the low sun
  from behind, they read as dark specks against the sky). In a 44 m box round you, wrapped so
  they stay put in the world; downwind by `travel` (the air's distance, added up by the script
  from a smoothed wind, so moving the slider speeds them up rather than throwing them across
  the sky), each at its own share of it, swirling and bobbing on the noise; leaves low, fluff up
  to 14 m, higher in more wind. Each has a w and drifts through W round the slice, 0.5 m thick:
  now and then one blows in from ana. How many are up: none below `bits_calm` 0.8 m/s, all by
  `bits_gale` 9 m/s (~1,900 at Hay meadow's 3.4, ~5,600 at 2.5x). Cost: **+0.016 ms** GPU in a
  gale (`_measure_grass_runner.gd -- toggle=bits_enabled wind_scale=2.5`). `_leaves_runner.gd`
  checks the counts; films: `video/Leaves on the wind, gale.mp4` and `..., breeze.mp4`.

## Cost (RTX 5080, 1280x720, interleaved on/off, after the pen's warm-up)

| | |
|---|---|
| blades handed to the GPU | about 380,000-610,000, depending on the view (whole tiles in view, 3 layers in W) |
| GPU | **+0.47 ms** a frame from the farm camera, +0.25 ms low in the field |
| CPU | the grass script about 0.09-0.12 ms a frame (the tile tests; the frame's uniforms packed into one array) |
| video memory | the scene read 836 MB with it (854 MB with the two rings): the tile meshes are small, the old per-blade instance buffers are gone |

Getting there:
- the first dense version was +1.28 ms with 520k blades;
- **dead blades skip the work**: out of the slice, thinned out, masked, behind the camera or off
  the side of the view, all their vertices go to one point before any of the clump, wind and
  curve work;
- two rings, the far one fewer and wider blades: +0.79 ms, but the grid sat ahead of the camera,
  which put the detailed ring's edge in front of the player; centred on the player, the full
  square was made: +1.10 ms;
- **the bands on tiles culled to the view: +0.47 ms**, with grass round you in every direction.

Thinner (2 Oct, spacing unchanged): `blade_width` 0.016 -> 0.009. Shorter, to test (2 Oct):
`blade_height` 0.5 -> 0.4 -> 0.3.

**The tip hook** (Ramon, 2 Oct: "at the top of each blade there's a small tiny curl ... is that
normal?"). It was not: the Bezier's middle points were at 40% and 90% of the height, which left
all the bend for the last few centimetres, so every leaning blade hooked over at the tip. Now at
35% and 70%, the second pushed 45% of the way to the tip's lean.

## Traps found

1. **Godot does not allow `return` in a spatial shader's vertex().** The shader then fails to
   compile ("Using 'return' in the 'vertex' processor function is incorrect") and **nothing draws -
   but the GPU still costs about as much**, so an A/B timing happily reports a cost for invisible
   grass. Grep runner logs for `SHADER ERROR` before believing a number.
2. **Merged meshes make useless bounds**: the marsh's water and the wood's litter are each one mesh
   of many discs, the tower one mesh per colour. An AABB per mesh would bare whole squares; per
   tetrahedron is right.
3. **The pen's `Hills` mesh is the far mountain range**, +-600 m in every axis: never a footprint.

## Knobs (on the Grass node)

Field (`spacing` 0.075, `spacing_far` 0.27, `spacing_from` 3, `radius` 44, `band_radii`,
`band_vertices`, `layers`, `layer_spacing`, `w_radius`), blades (`blade_height` 0.38,
`blade_width` 0.011, `taper` 0.5, `min_pixels` 0.8, `clump_size`, the colours, `region_deep`,
`region_bright`, `region_size`, `region_share`, `region_strength`, `hue_jitter`, `shade` 0.7, `toward_ground` 0.18, `saturation` 1.45), light (`haze_*`, `cloud_shadows`, `cloud_size`), wind (`wind_speed`,
`gustiness`, `gust_length`, `gust_width`, `bend_max`, `stiffness`, `sheen`), trampling (`trail_length`, `trail_spacing`, `trail_seconds`), clearings (`clearings`, `clearing_fill`, `clearing_ragged`, `clearing_fringe`), `enabled`. A
revert point for the two-ring version: the local branch `grass-before-lod`.

## Not done yet

- No shadows from or onto the blades (the cut's own shadows do not reach them).
- The projection (P) does not ghost the grass (as with the flock, it would need its own pass).
- Paths, mown patches and grass types per area: a "type map" texture would do it, as Ghost's.
- Runners: `grass/_capture_grass_runner.gd` (frames), `_measure_grass_runner.gd` (cost),
  `_film_grass_runner.gd` (the film), `_probe_ground_things_runner.gd` (what stands on the ground).
