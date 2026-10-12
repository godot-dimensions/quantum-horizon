# W tools: online research on 4D games and papers (7 Oct 2026)

This follows `desk_research.md` and leaves out what it already covers. Notation is the same: the slice turns by θ in a (v, W) plane about the camera. **h** is an object's half-size along the slice normal and **r** is its distance from the camera in that plane. Lines marked *(mine)* are my own arithmetic or inference.

**What I could not get.** CodeParade's devlogs are video only, and YouTube served no captions, so I used only their chapter titles. Miegakure's monthly notes since late 2022 are on Patreon behind a login.

---

## 1. 4D Golf (CodeParade) and Engine4D

**The level editor builds a track; it does not place objects freely.** The patch notes mention:
- track pieces and their wall configurations, and branching track elements;
- an "insert" mode when you go past the end of the track;
- a bug fix where a piece's orientation reset when another was inserted before it;
- an "Angle" field for rotations;
- size options for obstacles.

Sources: [1.0.6](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/5749481331450888691), [1.0.7](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/5756237364305290339), [1.0.9](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/5756237364321196665), [1.1.2](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/5766372999953118223). Devlog #5's chapters include "Turning Directions", "Branching Tracks" and "Rotation and Translation" ([video](https://www.youtube.com/watch?v=5pTBSafvQ7Y)). *(mine)* So authors chain pieces one after another, like a turtle, and rotate them by typed angles. They never drag things around in W.

**Three views.**
- **Slice view** is the default.
- **Volume view** turns the camera 90° in the y–W plane, eased over 0.75 s, and drops the eye to 0.05 above the ground ([CameraControl4D.cs](https://github.com/HackerPoet/Engine4D/blob/main/Assets/Scripts/CameraControl4D.cs)). The result is a slice at constant height, with ana–kata drawn as up–down. In 4D Golf, "volume" means a rotated slice, not a projection.
- **Map view** (V+1) adds ghosts to volume view. It shows a top-down 3D map of the course at every height, and parts stacked above each other overlap. A player guide calls it "arguably the most important view in 4D Golf" ([guide](https://steamcommunity.com/sharedfiles/filedetails/?id=3203209933)).
- **Volume line** is an option that draws a red line across volume view. The line marks what the normal slice will show when you switch back ([discussion](https://steamcommunity.com/app/2147950/discussions/0/4352239547063097798/)).

**How ghosts work** (more than the `_ShadowDist` note in the desk research):
- **Separate camera.** A second camera draws the ghosts with a replacement shader. Each object names its own ghost mesh (triangles, `_s`) and wireframe mesh (`_w`), or none ([ShadowFilter.cs](https://github.com/HackerPoet/Engine4D/blob/main/Assets/Scripts/ShadowFilter.cs)).
- **Cheaper ghost meshes.** The README suggests a cheaper mesh for the ghost than for the object, for example a 600-cell ghost for a high-poly glome ([README](https://github.com/HackerPoet/Engine4D/blob/main/README.md)).
- **Shader numbers** ([Core4D.cginc](https://github.com/HackerPoet/Engine4D/blob/main/Assets/ShadersND/Core4D.cginc), [ShadowND.shader](https://github.com/HackerPoet/Engine4D/blob/main/Assets/ShadersND/ShadowND.shader)):
  - ghost alpha is capped at 0.25;
  - ghosts fade out within 5 units of the camera;
  - they fade linearly to zero at a W offset of `_ShadowDist`, which defaults to 40;
  - their colour blends between two tints by the sign of the W offset, reaching full tint at about ±2.5 units.
- **One key** cycles ghosts off, on, and wireframe. Wireframe gets 10× the opacity ([BasicCamera4D.cs](https://github.com/HackerPoet/Engine4D/blob/main/Assets/Scripts/BasicCamera4D.cs)).
- **Tuned after launch.** Ghost colours for the Beyond courses were improved in a patch ([1.1.5](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/5741605105608114293)).

**Collision.**
- **Analytic colliders** cover the static world (box, sphere, spherinder, cubinder, duocylinder, cone, frustum, parallelotope, disk and more), plus a mesh collider that stores tetrahedra ([Colliders/](https://github.com/HackerPoet/Engine4D/tree/main/Assets/Scripts/Colliders)).
- Each returns the nearest point to a sphere, after a bounding-box early-out ([Collider4D.cs](https://github.com/HackerPoet/Engine4D/blob/main/Assets/Scripts/Colliders/Collider4D.cs)). Moving bodies are spheres only, and colliders are gathered once at scene start ([README](https://github.com/HackerPoet/Engine4D/blob/main/README.md)).
- Patch notes keep fixing missing colliders on track pieces ([1.1.6](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/5746109972544204776)).

**Objects per level and performance.** No figure has been published. Engine4D advises merging hand-built prefabs into one mesh with few materials, and warns that per-object occlusion has its own cost and may not pay off for small meshes ([README](https://github.com/HackerPoet/Engine4D/blob/main/README.md)). Player physics runs every other fixed step ([CameraControl4D.cs](https://github.com/HackerPoet/Engine4D/blob/main/Assets/Scripts/CameraControl4D.cs)).

**Trees.** I found no statement about trees. The only hint is `GenerateFernLeaf`, which nothing in the public repo calls ([GenerateMeshes4D.cs](https://github.com/HackerPoet/Engine4D/blob/main/Assets/Editor/GenerateMeshes4D.cs)). It grows a tapering triangular prism along W and bends it in the zw plane, giving a frond that curls through ana–kata. Devlog #6 ("Making Models in 4 Dimensions") has no text to read ([video](https://www.youtube.com/watch?v=Ir8oft_qAMQ)).

---

## 2. Miegakure (Marc ten Bosch)

**The plane that does not turn.** In a 90° swap two axes stay visible, so a whole plane is unchanged and "objects on this plane would be reference points" ([Nature as Designer](https://marctenbosch.com/news/?p=905)). The same post gives his reasons against projection: objects you cannot touch would overlap on screen, and colouring them by W is hard to read. Detailed objects sit on top of the puzzle tiles.

**Noise during the transition** ([art direction, Nov 2020](https://marctenbosch.com/news/2020/11/miegakure-update-november-2020-4d-art-direction/)):
- **Small things flash.** When the slice turns 90°, it passes through small objects for only a moment: "The smaller the objects, the quicker they will be appearing/disappearing." So he limits detail in 3D textures and geometry, even where he could add more.
- **Leaves must be real.** A canopy made of a few large flat planes, sliced, looks like intersecting planes. Leaves have to be modelled more realistically, but kept mostly one colour to reduce noise.
- **3D meshes get W thickness.** Ordinary 3D meshes are placed in the 4D world by giving them thickness in W. Detail goes into geometry rather than textures.
- **Dioramas need detail.** Levels are seen from far away, so large flat areas of colour do not work.

**Extruded trees, and clarity over correctness.** He sometimes gives up correctness for clarity: "I spent a long time on the extruded 3D trees and it was well worth it." ([Consistency Boundary, 2014](https://marctenbosch.com/news/2014/07/consistency-boundary-what-makes-a-logically-and-mathematically-consistent-system/)). The tree post he promised there never appeared that I could find.
- **Vegetation moved to general meshes.** It once had its own drawing system, later replaced by general tetrahedral meshes ([Sept 2021](https://marctenbosch.com/news/2021/09/miegakure-update-september-2021/)).
- **Consistency over a simpler hack.** He dropped an early, simpler building hack that faded sections to show interiors, because it did not match the rest of the game ([end of 2019](https://marctenbosch.com/news/2020/01/miegakure-update-end-of-2019/)).
- **Clean collision geometry.** His procedural rocks needed "very clean geometry for collision detection" (same post).

**Props got collision last.** Trees and lanterns had no collision for years, which never mattered because "you can almost never stand on these objects" ([PS4 post, 2014](https://marctenbosch.com/news/2014/12/new-screenshot-miegakure-on-ps4-interviews-collision-detection/)). The player is a 3D mesh with a little W thickness.

**W bands as separate worlds.** A level can have "a 'desert world' and a 'grass world.'" Neighbouring W positions look alike, which he uses to make levels easier to understand ([World of Miegakure, 2017](https://marctenbosch.com/news/2017/04/the-world-of-miegakure-concept-art/)).

**Teaching order** ([FAQ](https://miegakure.com/)). Sliding the slice along W is confusing because you cannot see where you are going, so it unlocks later. Free rotation exists but is held back at first. The game has projections of some sort.

**Tools for artists.** His team built tools "so that the artists on the team could contribute their visual talent" ([SIGGRAPH 2025](https://blog.siggraph.org/?p=19413)).

**Not found:** object counts beyond the tile sizes, or any "same in every slice" rule. The reference plane above is the nearest idea.

---

## 3. 4D Toys update 8 (2023) and earlier projection updates

Sources: [update 8](https://marctenbosch.com/news/2023/03/4d-toys-update-v-1-8-rotating-the-3d-slice-2d-faces-projections-marble-scenes-and-many-more/), [1.6](https://marctenbosch.com/news/2020/12/4d-toys-version-1-6-wireframe-projections/).

- **Pivot.** The post never names the pivot; it only says the interface keeps the level in front of you. *(mine)* 4D Toys scenes are small tabletops, so the slice probably turns about a point in the scene.
- **Axis indicator.** Three coloured lines show the horizontal axes; when the white one appears, you have traded a normal axis for W.
- **Slopes.** On a sloped level you see either the slope or W, so it can look flat.
- **Carrying and auto-follow.** A held shape turns with your slice, and "your slice always moves to the position of the last shape you touched."
- **Projections.** 1.6 projects object edges onto the slice; 1.8 adds 2D faces and a coloured wireframe. Both unlock after the matching levels. He says Miegakure has had a cooler version from the start.

---

## 4. 4D Miner (Mashpoe) and other vegetation

**Biomes** come from temperature and moisture noise (0.1.4.0, [Version History](https://4d-miner.fandom.com/wiki/Version_History)). Each biome in `biomeInfo.json` lists ([biomeInfo.json](https://4d-miner.fandom.com/wiki/BiomeInfo.json)):
- its ground layers;
- weighted tree types and `treeAbundance` (85 in Snowy Taiga, 0 in Snowy Tundra);
- decorations (flowers, bushes) and `decorationAbundance`;
- height multipliers.

**Trees** are made of wood and leaf voxels, with one species per biome ([Redleaf](https://4d-miner.fandom.com/wiki/Redleaf)).

**Readability aids:**
- The mouse wheel, or holding M, turns the slice in zw and xw ([Version History](https://4d-miner.fandom.com/wiki/Version_History)).
- Hotkeys snap to axis-aligned slices: reset, swap Z↔W, swap X↔W ([Getting Started](https://4d-miner.fandom.com/wiki/Tutorials/Getting_Started)).
- A compass shows 4D position and heading.
- 4D glasses show wireframes of chests, dropped items and creatures outside the slice, but not terrain or trees ([4D Glasses](https://4d-miner.fandom.com/wiki/4D_Glasses)).
- The tutorial tells players to scroll back and forth until dropped sticks reappear ([Getting Started](https://4d-miner.fandom.com/wiki/Tutorials/Getting_Started)).

**Devlog #1** has a chapter called "4D shadows and gameplay", but no text ([video](https://www.youtube.com/watch?v=WjnVeEkkeq4)).

**Others.** A developer on the VizionEck forum lists 4D trees among planned features and proposes a "hologram" view made of stacked horizontal slices ([forum](https://vizioneck.com/forum/index.php?msg=241920)). I found nothing called "Hypercraft", and no other game with documented 4D vegetation.

---

## 5. Papers and hobby work

- **Nothing on 4D plants.** I found no paper on 4D L-systems, 4D trees or 4D grass.
- **4D turtle.** The standard 3D turtle carries a frame (H, L, U) and turns by rotation matrices ([ABOP ch. 1](https://algorithmicbotany.org/papers/abop/abop-ch1.pdf)). *(mine)* A 4D turtle needs a fourth frame vector and plane rotations, and Engine4D's fern is effectively one.
- **Best-candidate sampling** (Mitchell). Each new sample is the candidate farthest from all earlier samples, and earlier samples stay where they are. It works in any dimension, but it costs O(N²) against Bridson's O(N) ([Bostock](https://bost.ocks.org/mike/algorithms/)).
- **Uniform points in a ball.** A uniform n-ball equals a uniform (n+1)-sphere projected down to n dimensions ([Voelker et al. 2017](https://compneuro.uwaterloo.ca/publications/voelker2017.html)). *(mine)* For an (x, z, w) ball, plain rejection from a cube is simpler and keeps π/6 ≈ 52 % of points.

---

## Dwell angle *(mine; used below)*

The desk research gives the in-band test, tan θ ≤ hw/(d − hu), for an object at W = 0. This section covers objects the turning slice sweeps across, such as echoes at other W. When the slice crosses such an object, its signed distance changes at the rate |ds/dθ| = r. So the object is cut for about **Δθ ≈ 2h / r** radians of turn.

| Part | h | r | Δθ |
|---|---|---|---|
| Crown | 3.6 m | 40 m | ≈ 10° |
| Trunk | 0.5 m | 40 m | ≈ 1.4° |
| Twig | 0.15 m | 40 m | ≈ 0.4° |

A 90° turn over 1 s at 60 fps moves 1.5° per frame. So a trunk lasts about one frame and a twig often none. This is ten Bosch's "smaller is quicker", in numbers.

---

## What this means for the two tools

### (a) W Exploder (copies of hand-placed trees at other W)

1. **Flicker floor.** Show the dwell angle at 40 m for each bake. Crowns pass; trunks and undergrowth flash for a frame. Accept it (Miegakure's floating grass), use the desk's W-taper on echoes only, or leave undergrowth out of echoes.
2. **Volumetric crowns only.** No card-based crowns for echoes, because sliced cards read as crossing planes. Keep each tree's leaves within a narrow hue.
3. **W bands with an identity.** Add an optional species and tint table by W that changes slowly, so neighbours look alike: for example oak at the farm, birch ana, pine kata. The forest then works as a W compass, on top of Camera4D's hue shift. Ramon's call.
4. **A density field instead of fixed layers.** Take 4D Miner's per-biome abundance and make it a density over (x, z, w), for example thinning as |W| grows and clearing near paths. Seeds stay per tree.
5. **Placement.** Best-candidate sampling with the authored trees inserted first keeps the hand layout exactly and gives blue noise in (x, z, w). *(mine)* At a few hundred trees the O(N²) cost is fine for an offline bake.
6. **Collision.** Echoes outside the walkable band need none, which Miegakure shipped without for years. Inside the band, give them an analytic trunk (spherinder or box), not a mesh collider.
7. **Projection.** For echoes, either turn projection off or use a cheap proxy with Engine4D's numbers: alpha ≤ 0.25 and a fade by W offset. *(mine, unverified)* godot-4d's `allow_projection` is only on or off, so a proxy would need a separate mesh that only projects. Check whether the module allows that.
8. **Debug view.** A 4D Golf-style map view, projected along y to show (x, z, w), is the natural way to see the whole echo cloud. Check whether Camera4D can project along y; if not, draw it as a 3D gizmo in the tool.
9. **Undergrowth.** Engine4D's fern recipe is a cheap, truly 4D frond worth testing.

### (b) W Optimiser (landmarks that survive slice rotation)

1. **Reference line.** For a turn in the (v, W) plane, the signed distance is s = w·cosθ − (p·v)·sinθ. So anything at W = 0 on the line through the camera across v keeps its cut at every angle. The tool can report, per viewpoint, the bearing at which each landmark is immune. Designers can use this by putting key landmarks to the side of a path's main turning direction.
2. **Aim for 90° as well as small angles.** All three games steer players to axis-aligned turns: Miegakure's swap, 4D Toys' arrows, and 4D Miner's hotkeys. For landmarks players can visit, a quarter-turn copy matches the one large angle players are taught. Extrusion covers the small angles.
3. **Detail parts.** The dwell angle shows small parts flickering. Extrude details to their parent's W size, and drop parts below an h_min from generated copies.
4. **Consistency.** Ten Bosch dropped a simpler building trick because it did not match the rest of the game. A wrap that stays put while trees slide away may break players' pattern reading the same way. Test it against open question 5, and prefer one rule family per area.
5. **A pivot instead of geometry.** 4D Toys keeps the level in front of you and has auto-follow. If Ramon chooses to turn the slice about a point of interest, r becomes the distance from that point, and most landmarks need much less W. This is a gameplay call.
6. **Colliders.** Generated geometry gets analytic shapes, not tetra-mesh colliders. Miegakure needed clean geometry for collision, and Engine4D keeps mesh colliders as the exception.
7. **Projections for landmarks.** Keep them on landmarks: low alpha, faded out by about 40 m in W, tinted ana or kata. A volume line or map view can show where a landmark is, more cheaply than a wrap.
8. **Partial sweeps.** Engine4D has a partial revolve and a path extrude (one extrusion along several segments, stretched to fit a path). Both are precedents for the custom wrap sweep that godot-4d lacks ([README](https://github.com/HackerPoet/Engine4D/blob/main/README.md)).
