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
- **Nothing is stored.** Instance n is a cell of a grid round you, snapped to the world (so a
  blade never swims); a hash of the cell gives its jitter, height, facing and w.
- **"You" is the player, not the camera** (Ramon, 2 Oct: "the detailed circle area should always
  take you as its middle point"). When the camera is the player's own (the orbit rig, a few
  metres behind them) both rings are centred on the player, so the detail spreads out round
  them, behind as far as ahead; on any other camera (the hawk, the Lookout's camera, a cutscene)
  on the camera. The slice and the frustum are always the camera's.

## The blade, the clumps, the wind

- **Blade:** a cubic Bezier from root to tip; 11 vertices near, 7 far, more of them towards
  the tip; widest at the root, a point at the tip. Normals turned out at the edges (rounded),
  thickened in view space when seen edge-on.
- **Clumps:** a Voronoi of clump points (1.3 m), banded along W too; each blade takes its nearest
  clump's height (0.82-1.18x), colour (lush, ordinary or dry) and a slight lean to its middle.
  Kept gentle on purpose: strong clumps read as tufts.
- **Colour:** dark root, the clump's green, a pale tip; the passing gust brightens the tips (the
  silver waves on a field); one blade in 80 a flower stalk with a small head (white, yellow,
  violet); the ring's edge turning the field's own colour.
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

## Cost (RTX 5080, 1280x720, interleaved on/off, after the pen's warm-up)

| | |
|---|---|
| blades | 467,142 (near ring 12 m at 8.5 cm, far ring 44 m at 32 cm, 3 layers in W) |
| GPU | **+1.10 ms** a frame from the farm camera (1.87 -> 2.97), +1.04 ms low in the field |
| CPU | under +0.01 ms (a dozen uniforms a frame) |
| video memory | about +19 MB (the MultiMesh buffers and the mask; the scene read 848 MB at 337k blades, 854 MB now) |

Getting there: the first dense version was +1.28 ms with 520k blades. Two things did it:
- **dead blades skip the work**: out of the slice, thinned out, masked, behind the camera or off
  the side of the view, all their vertices go to one point before any of the clump, wind and
  curve work;
- **the far ring has fewer, wider blades**: they are a pixel or two wide out there, and tiny
  triangles are what costs.

It was +0.79 ms (337k blades) while the grid sat 30% of its radius ahead of the camera, so
little was made behind it. That pushed the detailed ring's near edge forward of the player and
broke the field spreading round you, so the rings were centred on the player (2 Oct) and the
full square is made: +0.3 ms, mostly the blades behind the camera that are made and dropped,
plus more of the detailed disc in view. A round grid (rows of varying length) would make 21%
fewer and win most of that back.

Thinner (2 Oct, spacing unchanged): `blade_width` 0.016 -> 0.009, `far_blade_width` 0.045 -> 0.025.

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

Rings (`near_spacing`, `near_radius`, `far_spacing`, `far_radius`, `layers`, `layer_spacing`,
`w_radius`), blades (`blade_height` 0.5, `blade_width` 0.009, `far_blade_width` 0.025,
`clump_size`, the colours), wind (`wind_speed`, `gustiness`, `gust_length`, `gust_width`,
`bend_max`, `stiffness`, `sheen`), `enabled`.

## Not done yet

- No shadows from or onto the blades (the cut's own shadows do not reach them).
- The projection (P) does not ghost the grass (as with the flock, it would need its own pass).
- Paths, mown patches and grass types per area: a "type map" texture would do it, as Ghost's.
- Runners: `grass/_capture_grass_runner.gd` (frames), `_measure_grass_runner.gd` (cost),
  `_film_grass_runner.gd` (the film), `_probe_ground_things_runner.gd` (what stands on the ground).
