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
  - **sap green and its bright offset pulled 35% towards the ground's colour** (`toward_ground`),
    with the lush clumps and the tips; the deep region left alone (Ramon: "i like that one of the
    3 color codes merges with the base green ground ... darkening the remaining 2 colors closer
    to the base ground color too");
  - **saturation 1.25** (`saturation`), about each blade's own brightness, so greener at the same
    values ("can you saturate the grass a bit?").
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

Field (`spacing` 0.085, `spacing_far` 0.30, `spacing_from` 3, `radius` 44, `band_radii`,
`band_vertices`, `layers`, `layer_spacing`, `w_radius`), blades (`blade_height` 0.3,
`blade_width` 0.009, `min_pixels` 0.8, `clump_size`, the colours, `region_deep`,
`region_bright`, `region_size`, `region_share`, `region_strength`, `hue_jitter`, `shade` 0.7, `toward_ground` 0.18, `saturation` 1.45), light (`haze_*`, `cloud_shadows`, `cloud_size`), wind (`wind_speed`,
`gustiness`, `gust_length`, `gust_width`, `bend_max`, `stiffness`, `sheen`), `enabled`. A
revert point for the two-ring version: the local branch `grass-before-lod`.

## Not done yet

- No shadows from or onto the blades (the cut's own shadows do not reach them).
- The projection (P) does not ghost the grass (as with the flock, it would need its own pass).
- Paths, mown patches and grass types per area: a "type map" texture would do it, as Ghost's.
- Runners: `grass/_capture_grass_runner.gd` (frames), `_measure_grass_runner.gd` (cost),
  `_film_grass_runner.gd` (the film), `_probe_ground_things_runner.gd` (what stands on the ground).
