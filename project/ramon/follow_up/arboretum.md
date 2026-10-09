# Arboretum: plan and handover (Shrubbery Lab remake, started 5 Oct 2026)

The remake of the Shrubbery Lab as a new scene, `res://ramon/Arboretum/arboretum.tscn`. Nothing
in `sandbox/shrubbery/`, `CreationLab/` or the playable world is changed: what this scene needs
from them is carried over into `Arboretum/carried/`, as the Quantum Range did.

**The name.** ARBORETUM, with "Botanical systems" as its running line: a collection of trees
grown four ways. (Ramon asked for a name "indicating botanical systems". It is one word in the
room's data file, `Arboretum/arboretum_info.tres`, if you want another.)

## Questions for Ramon

(Each was settled with the most reversible option and the run went on.)

1. **The name.** ARBORETUM, running line "Botanical systems". One word in `Arboretum/arboretum_info.tres`
   and the sign's title in `arboretum.tscn` (Hall/Sign) if you want another.
2. **The menu.** The menu's Shrubbery Lab entry still opens the old `sandbox/shrubbery/shrubbery_lab.tscn`.
   I did not touch the catalogue (another window has uncommitted edits in it). Point that entry at
   `res://ramon/Arboretum/arboretum.tscn`, and rename it?
3. **The trees' form through W** (case study 2). The trees are flattened through W so one slice holds
   most of a tree (turned a quarter turn through W they show their narrow side). 4Denthusiast's
   direction for the pen is the other way: the same in X, Z and W. The isotropic form is one constant
   away (`botany/tree_species.gd` FORM = "isotropic", then rebake); in a slice it shows a trunk, stubs
   and a leaf cloud. Keep the flattened form for this room?
4. **The oak's leaves reach further through W than its wood** (0.6 m against at most 0.45 m), which
   is what makes the crown read full. Walk 0.6 m through W in the grove and you see leaf clouds with
   no wood under them. Keep, or tie the leaves to the wood (a thinner crown)?
5. **Two growth algorithms.** Pedestals 01 to 03 keep the Shrubbery Lab's generator (that is their
   point: the old lab's skeleton, built three ways). The oak grows by the paper's own space
   colonization (`botany/colonize_4d.gd`, case study 4), which makes a much better tree. Move the
   specimen to it too? It would need its crown re-tuned and a rebake.
6. **Video memory.** 1.3 GB with the hall drawn, 2.0 GB once you have walked into the grove (a
   drawn mesh keeps its memory when hidden). Fine on our machines. If this has to run on smaller
   cards, the grove can become its own scene, so the hall is freed when you go through. Say if so.
7. **The kit.** Everything shared is carried into `Arboretum/carried/`, with every change listed in
   its README (a square pedestal, the "methods" panel layout, the presenter fixes). When the shared
   kit settles, should these go back into `CreationLab/`?

---

## 1. The idea in one line

**One 4D skeleton, three ways to build a tree on it, then an oak.** The first three trees grow from
the same branch skeleton (the Shrubbery Lab's own 4D space colonization), so the only thing that
changes from pedestal to pedestal is the construction method. The fourth pedestal, the biggest, is an
oak grown the best way we found: its own skeleton by the paper's space colonization, lofted wood,
leaves the graphics card places in your slice, and one wind for all of it. A second room shows each
method at the scale of a grove.

## 2. What the research says (5 Oct)

**Our own code, read first:**
- **The Shrubbery Lab** (`sandbox/shrubbery/`, Trym, Aug 2026) ports TanTanDev's *shrubbery* to 4D: a
  branch graph grown by space colonization in a 4D box, voxelized at 10 cm (wood and leaf voxels)
  and meshed one box per voxel with hidden faces culled. Its smooth mesher (marching tetrahedra in
  GDScript) took 172 s for a tiny shrub and is not used. A 20-tree forest measured 5.66 million
  tetrahedra, about 280,000 a tree.
- **The engine's voxels** (`engine/modules/4d/voxel/`, 4Denthusiast, Sept-Oct): `VoxelWorld4D` now
  meshes by **dual contouring in C++** (Hermite data on every edge, one QEF-placed vertex per
  surface per cell). Generators are settable from GDScript; `SphereVoxelEdit4D`,
  `BoxVoxelEdit4D` and `ParallelogramVoxelEdit4D` write into it, and writing a material over
  itself is a true union (the farther crossing wins). Its chunk meshes are ordinary
  `MeshInstance4D` children, so they can be read back. So the smooth tree can be the engine's own
  work, live.
- **The loft builder** (`chickenpen/scripts/loft_builder_4d.gd`, carried in the Creation Lab) lofts
  any ordered chain of 3D cross-sections with parallel-transport frames: a triangular prism between
  rings is 3 tetrahedra, so a branch costs 3 x (profile triangles) per span. The rig sorts balls by
  height, but the builder itself takes any order, so branches can be lofted root to tip in any
  direction. The Lookout's tree (`chickenpen/lookout/lookout_tree_4d.gd`) lofts limbs once and merges
  them: a few thousand tetrahedra a tree.
- **The grass** (`chickenpen/grass/`): not 4D geometry at all. Ordinary 3D blades in the
  cross-section renderer's own World3D, placed by the shader from the camera's 4D frame every
  render, each blade thin in W and cut by the slice. Lit by the scene's suns. This is the route
  for leaves.
- **The Creation Lab kit and PathCreator**: room plans, wall panels, pedestals, the story presenter,
  the tuner, the floor route graph with W modes, the in-game builder. The Quantum Range carried them
  over rather than reusing them; so does this.

**Prior art:**
- **Space colonization** (Runions, Lane and Prusinkiewicz, *Modeling Trees with a Space Colonization
  Algorithm*, 2007, [paper](https://www.algorithmicbotany.org/papers/colonization.egwnp2007.html)):
  attraction points fill the crown envelope, tips grow toward the points in their radius of
  influence, points within the kill distance are removed. Afterwards: **decimate** the nodes, move
  branch points half way toward their parents and **subdivide** for smooth limbs, then size every
  limb by the **pipe model** `r^n = r1^n + r2^n` (n between 2 and 3), and build **generalized
  cylinders** on parallel-transport frames. Wide spreading trees (their Fig. 5b) come from an open
  envelope and a radius of influence of about 8 segments.
- **The pipe model in 4D:** a branch's cross-section is a 3D ball, so if the pipes add up by
  cross-section the exponent is 3, not 2. Real trees sit between 2 and 3 anyway; 4D pushes it to
  the top of that range. A small fact worth a callout.
- **Oak form** (*Quercus robur*): a short trunk, decurrent (no single leader), a broad, irregular,
  rounded crown often wider than tall, knotted sinuous limbs, leaves crowded at the ends of the twigs
  ([RHS](https://www.rhs.org.uk/plants/14294/wd/details),
  [van den Berk](https://www.vdberk.co.uk/trees/quercus-robur/)).
- **Wind:** Crysis (Sousa, *GPU Gems 3* ch. 16,
  [chapter](https://developer.nvidia.com/gpugems/GPUGems3/gpugems3_ch16.html)) splits it into a
  **main bend** of the whole plant along the wind, length preserved, scaled by height, and **detail
  bending** of branches and leaves with per-branch phases and four smoothed triangle waves
  (1.975, 0.793, 0.375, 0.193). **Pivot Painter 2** (Unreal,
  [docs](https://dev.epicgames.com/documentation/unreal-engine/pivot-painter-tool-2.0-in-unreal-engine))
  stores every branch's pivot, direction and parent in a texture so the vertex shader can swing each
  branch about its own base and pass the motion down the hierarchy. Tree physics: the trunk sways
  slowest, higher branch orders faster and out of phase with it.
- **Foliage:** cards over blob volumes with normals taken from a sphere round the crown, so the
  crown shades as one soft mass instead of a thousand flat cards
  ([polycount](https://polycount.com/discussion/comment/2717475)).
- **Dual contouring** (Ju, Losasso, Schaefer and Warren, 2002,
  [paper](https://www.cs.wustl.edu/~taoju/research/dualContour.pdf)): one vertex per cell placed
  where the surface really is, so it keeps sharp features and avoids the stair steps a blocky
  mesher leaves.
- **4D trees elsewhere:** Miegakure's trees open their interiors when you turn into the fourth
  dimension, and its grove of tilted spherinders reads as different shapes from different slices
  ([80.lv](https://80.lv/articles/scattering-a-grove-with-4d-spherinders)). 4D Miner grows voxel
  trees in a 4D voxel world.
- **How the room teaches** (`follow_up/lab_case_study/`): one direction, text painted on walls at a
  fixed size, nothing in front of the exhibit, demo first and then try, the exhibit as the weenie at
  the end of the axis.

## 3. The design

### The visitor's walk
1. **A short entrance corridor** with ARBORETUM painted over the doorway, then the hall opens up (low
   and narrow, then tall: compress and release).
2. **The hall**, 28 m wide, 38 m deep, 12 m high. Down its middle you see the oak at the far end in
   its pool of light, framed by the two blue panels on the angled back walls: the introduction on
   the left, the research on the right.
3. **An avenue of three trees** on alternating sides of the axis: 01 left, 02 right, 03 left. The
   floor route (PathCreator) zigzags from one to the next and on to the oak, then round it to the
   grove door. Each destination ring turns "completed" when you have seen its tree.
4. **At each pedestal** its story plays once as you come near (the Creation Lab's title card and
   callouts), the tree itself performing each part: the skeleton grows, the surface is built, the
   slice slides through W, the wind blows. Then you try: the wheel slides it through W, a right drag
   turns it, E does its one action, and a console beside it opens its card (method, what it shows,
   its limits, measured numbers, and whether it is baked or live).
5. **PLAY THE SHOWCASE**, a pad by the entrance: the camera takes a short guided tour of the four
   pedestals and ends looking into the grove, then hands the camera back. Esc or a click skips.
6. **The grove**, through a door behind the oak: one plot per method, each a small grove of its
   trees, with the same wind crossing them all and each plot's live cost painted at its corner.
   It is a 4D grove: more trees stand ana and kata of you than you can see; Q and E walk through W
   there, and a follow route leads to the hidden ones.

### The four pedestals

| # | Code | Method | Pedestal | What it shows |
|---|---|---|---|---|
| 01 | VX-01 | **Voxels.** The skeleton written into 12.5 cm 4D cells, one box per cell (E: 18.75 and 25 cm). The Shrubbery Lab's method, carried over. | Box (it is made of boxes) | The simplest method; why a 4D surface is expensive (a skin that is a volume) |
| 02 | DC-02 | **Smooth voxels.** The same skeleton as chains of 4D spheres in the engine's own voxel world, meshed by dual contouring in C++. | Round | The engine's native voxels; the same cells as 01, a smooth surface; live generation |
| 03 | LF-03 | **Lofted.** The same skeleton as chains of our loft tool's balls. | Round | A tenth of the voxels' cost; the tool that builds our animals builds trees |
| 04 | OK-04 | **The oak.** Its own skeleton (the paper's space colonization in an oak's crown), lofted wood, 77,000 GPU leaves, one wind. | Round, the largest | What the methods add up to |

Foliage follows the method too: leaf voxels on 01, smooth leaf blobs on 02, lofted leaf clumps on
03, and real leaves on the oak.

### One wind for all four
A pivot texture holds every branch of a tree (its base, its direction, its stiffness and its
parent). The bark shader (a fork of the kit's surface shader, the vertex stage kept identical) bends
every tetrahedron corner about its branch's pivot and then its parent's, down to the trunk, before
slicing. The leaf shader runs the same function on each leaf's anchor, so leaves stay on their twigs.
Every mesh carries its branch in its texture coordinates, whatever built it: the loft and the voxel
builder write it as they build, and the dual-contoured mesh is labelled afterwards by the nearest
branch. Wind can blow through W as well as across the floor, which moves branches in and out of
your slice.

### Loading (decided by measurement, step 90; case study 6)
- **The pedestal trees and their story stages are pre-baked** by `scripts/_bake_runner.gd` into
  `Arboretum/baked/` and loaded with the room (it opens in 0.8 s). Each card says so: a gold
  "PRE-BAKED 2026-10-06" pill, or a green "GROWN LIVE" one after you rebuild a tree.
- **Each pedestal can rebuild live** (E), timed in front of you: the voxel tree at another cell size
  (60 ms), the engine's tree from a new seed (about 0.7 s, in C++, chunk by chunk), the loft at
  another resolution (0.5 s); the oak's key turns its season.
- **The grove is streamed:** its trees (baked lighter variants, one mesh per variant shared by every
  tree that uses it) load on worker threads when you come within 22 m of its door (16 ms), but are
  **drawn only within 12 m of the door or inside**, and the hall's four trees are not drawn once you
  are 6 m into the grove. Loaded is cheap; drawn is what costs (case study 5). A scene of its own was
  not needed for frame time; it would be the answer for video memory (question 6).

### Controls
WASD walk, mouse look, wheel: slide the nearest tree through W, right drag: turn it in 4D, E: its
action (or open the console's card), click or arrows: next part of its story, G: a gust of wind,
V: volume view (the whole 4D tree, ghosted), B: grey or black palette, F1: the dev panel, F4: the
path builder, H: back to the menu. In the grove Q and E walk through W. Every key is checked free
before it is used.

## 4. The 100 steps

### A. Ground truth (1-12)
1. Folder `Arboretum/` (scene, scripts, shaders, botany, bake, runners), this plan and its handover.
2. Keys: list what the kit player, the walker, the kit and PathCreator use, and confirm G, V, R and
   the number keys are free for the room.
3. Probe the old shrub generator as it stands: branches, voxels, tetrahedra, time per stage, at
   10, 12.5 and 15 cm cells, with and without leaves (headless).
4. Probe the engine's voxel world: an all-air generator, a load trigger over a tree-sized region,
   how long until every chunk is defined, and whether an edit into a pending chunk is lost.
5. Probe a branch as a chain of sphere edits: spacing against bumpiness, apply time, meshing time,
   tetrahedra, and reading the chunk meshes back into one mesh in metres.
6. Probe the bark shader fork: the kit's vertex stage plus a displacement of the corners before the
   slice, on a lofted branch; check nothing cracks and the light still works.
7. Probe leaves in the cross-section world: a MultiMesh of leaf cards placed from 4D anchors through
   the camera's frame (the grass route), lit by the room's suns, depth-tested against 4D meshes,
   and cut by the slice; frame cost at 10k, 40k and 100k leaves.
8. Probe whether per-material uniform arrays are shared in this engine (PathCreator's finding),
   for the leaf frames of several trees at once.
9. Probe the Combined renderer switch (volume view) in this room's setup, and keep V only if it holds.
10. Measure the tetrahedron and memory budget: what four pedestal trees and a grove may cost to stay
    under 8 ms a frame and a sane amount of video memory (about 1.25 KB a tetrahedron).
11. Decide the cell size, loft resolution and leaf count from 3 to 10, written into this plan.
12. Write what the probes found into the case study section below, with frames.

### B. The carried kit (13-18)
13. Copy the kit (LabKit with its carried player, kit, panels, the build scripts) into
    `Arboretum/carried/`, paths rewritten, no `.uid` sidecars, no `class_name`.
14. Copy PathCreator (graph, render, symbol sets, builder, spec) into `Arboretum/carried/PathCreator/`.
15. Copy the shrubbery generator (generator, branch, species, attractor shapes, blocky mesher) into
    `Arboretum/carried/shrubbery/`, its class names taken out and its references preloaded.
16. Copy the loft builder (already carried by the Creation Lab) with it.
17. `carried/README.md`: where each came from, at which commit, and every change made.
18. Parse-check every carried script and run a bare scene with the kit player in it.

### C. The skeleton (19-28)
19. `botany/tree_skeleton_4d.gd`: grows the skeleton with the carried generator from a species.
20. Decimation and smoothing: every node moved half way toward its parent, then subdivided
    (Runions et al.), so limbs curve instead of zigzagging at 0.5 m.
21. Chains: the graph cut into branches from fork to fork, each with an order (trunk 0, limbs 1, ...)
    and a parent branch and the point on it where it starts.
22. The pipe model, `r^n = sum r_i^n`, from a twig radius up, with n as a species setting (2.5 by
    default; 3 is the true 4D pipe), replacing the generator's per-step falloff.
23. The species for the three comparison trees: about 4.2 m tall, a crown about 4 m across and 3 m
    deep in W, a clear trunk; seeds searched for a good silhouette from the front.
24. The oak species: an envelope wider than tall, open at the top, a 2 m trunk, a radius of influence
    of about 8 segments for a decurrent crown, a gentle downward tropism on the outer limbs; about
    7.5 m tall and 9 m across.
25. Pivots: every branch's base, direction, length, stiffness (from its radius and length) and
    parent, packed into a float texture for the shaders.
26. The skeleton as a drawable: thin gold tubes (lofted at 4 sides), and its growth as stages (one
    per few iterations) for the stories.
27. Save and load a skeleton (`.tres`), so a baked tree and its live regrowth share one source.
28. Runner: all four skeletons from the front, the side and through W, with their numbers.

### D. Four ways to build (29-46)
29. Voxel builder: the carried voxelize and blocky mesher, writing each cell's branch into its
    texture coordinates, wood and leaves as two materials.
30. Voxel stages for the story: the cells arriving by generation, a handful of baked steps.
31. Voxel cost: tetrahedra, memory and build time at the chosen cell size, against the old lab's.
32. Dual-contoured builder: an air world, a load trigger, the chains as sphere edits (wood) and
    leaf glomes (a second material), then the chunks read back into one mesh in metres.
33. Its branch labels: every vertex given its nearest branch, so the wind finds it.
34. Live growth: the same edits applied over a second or two in front of you, chunk by chunk, with
    the engine's own time shown.
35. Its cost and its quality against 01 at the same cell size (frames side by side).
36. Lofted builder: each chain lofted root to tip (`loft_builder_4d.gd` build), sides by order
    (8 for the trunk, 6, 5, 4 for twigs), tips tapered, merged into one mesh.
37. Its balls as the story's first step: the cross-sections as gold rings along each branch.
38. Its leaf clumps: lofted ellipsoids at the outer branch ends, a second material.
39. Its live rebuild (E: more or fewer sides), timed.
40. The oak's wood: the same lofter on the oak skeleton, bark tinted darker toward the base,
    roots flaring into the pedestal.
41. Bark colour and the specimen palette: bark, leaf greens (sap green first), voxel and loft
    tones close enough to compare, set in one style file.
42. The bark shader in use on all four: colour by material, a slight per-branch tone, the light.
43. The bake runner: every pedestal tree, its stages, and the grove's lighter variants into
    `Arboretum/baked/`, with a bake record of each one's time, tetrahedra and memory.
44. Load the baked trees and check they match a fresh build.
45. Cost of all four standing in the hall: frame time, GPU time, memory.
46. Runner: the four trees side by side, from the player's camera, both palettes.

### E. Leaves (47-56)
47. Leaf anchors from the oak skeleton: clusters at the twig ends and along the last two orders,
    each leaf with a 4D place, a facing in 4D, a size and its twig.
48. The leaf node: one MultiMesh in the cross-section world, the anchors in a texture, the camera's
    frame every render (the grass's route), drawn only where the slice passes.
49. A leaf cut by the slice: each leaf thin in W, full size on its own slice and shrinking as it
    leaves it, turned in 3D by how its 4D facing meets the slice.
50. The leaf shape: an oak leaf outline (lobed) as a small fan of triangles, no transparency, two
    sided, a centre vein lighter.
51. Crown normals: each leaf lit as part of one soft mass (normals from the crown's middle, blended
    with its own), so the crown shades round.
52. Colour: sap green, two close offsets by cluster, a per-leaf hue, lighter at the crown's top and
    outside, darker inside.
53. Leaves follow the wind: the same branch function as the bark, plus a flutter per leaf.
54. Leaves in the story: they grow in cluster by cluster; and the season, E on the oak: summer,
    autumn, bare, and back.
55. Cost: leaves at 10k, 30k and 60k against the 8 ms budget; pick the count.
56. Runner: the oak close up, from below, through W, in the wind, with frames to look at.

### F. Wind (57-64)
57. `botany/wind_4d.gd`: one wind for the room: direction (across the floor and through W),
    strength, gusts travelling downwind, and a time every shader shares.
58. The bark shader's wind: each corner swung about its branch's pivot, then its parent's, down to
    the trunk, by an angle from the wind, the branch's stiffness and its own frequency (trunk
    slowest).
59. The main bend: the whole tree leaning with the wind, length kept (Crysis).
60. Gusts: G sends one across the hall; it reaches each tree in turn.
61. Wind through W: a direction with a W part, so branches swing in and out of the slice.
62. The same wind on all four methods, checked to move each one the same way.
63. Cost of the wind (GPU) on all four, against no wind.
64. Runner: frames of a gust passing, and a short film.

### G. The room (65-76)
65. The room plan: the entrance corridor, the hall (28 x 38 x 12 m, angled back corners), the grove
    room behind it; built from the carried room plan and KitRoom.
66. Lights: the Creation Lab's bright look, a downlight per pedestal, a bigger one for the oak, the
    sun handle; the light bench's numbers as the start.
67. Pedestals: the kit pedestal, a box variant for 01, sizes per tree, the hologram ring kept subtle.
68. A station per pedestal: the carried showcase holding the tree as its exhibit (slice, turn, action,
    story), four of them in one room, the nearest one active.
69. Pedestal labels: the code and method printed round each pedestal's side.
70. The two wall panels: the introduction (left back wall) and the research panel (right back wall)
    in a new "methods" layout: the four methods in four equal columns on one scale.
71. The panel source: the measured numbers from the bake record and the live frame, every number
    tagged live, baked or sample.
72. A console beside each pedestal (the kit's research desk), the key prompt, and the card: method,
    what it shows, its limits, measured, baked or live.
73. The painted sign over the entrance and the numbers on the floor by each pedestal.
74. The HUD: the control strip (the keys that work where you stand), toasts, the palette switch.
75. Room runner: the hall from the entrance, from each pedestal, the panels straight on, both palettes.
76. Fix what the frames show, then run them again.

### H. Stories and the showcase (77-84)
77. The story for each method (its parts, lines and callouts with measured numbers), the showcase
    asking its exhibit for its own parts.
78. The exhibits performing each part: skeleton growth, voxels arriving, the dual-contoured surface
    building, the balls and the loft, the oak's leaves, the slice, the wind.
79. The presenter: one title card for the pedestal you are at, callouts low, never over the tree.
80. The story plays once as you arrive, a click or the arrows step through it.
81. PLAY THE SHOWCASE: a pad by the entrance; the camera tour (wide, then each tree doing its key
    part, then the grove), captions, Esc or a click to leave, the camera handed back.
82. Volume view (V), if the probe held: the whole tree ghosted in the Combined renderer.
83. Story runner: every part of every pedestal, a frame each.
84. The showcase as a film (30 fps) to watch from start to end.

### I. Paths (85-89)
85. The route graph (`Arboretum/paths/arboretum.tres`): entrance, the three trees, the oak, the grove
    door, the showcase pad; written by a runner and editable with F4.
86. The network in the hall: destinations round each pedestal's footprint, states that move on as you
    go (available, focused, completed).
87. The grove's paths: a loop round the plots and a follow route up through W to the hidden trees,
    with the W cue.
88. The builder (F4) working in this room: top view, drag, save, walk it.
89. Proof: rule 10's acceptance on both graphs, and legibility from the player's camera.

### J. The grove (90-95)
90. Loading, measured: everything at open, the grove streamed on approach, or a scene of its own;
    pick by open time, memory and frame time, and write the answer here.
91. The grove room: four plots, each a small grove of one method's lighter trees, varied by seed,
    scale and turn, at several W.
92. Each plot's numbers painted at its corner (trees, tetrahedra, memory, frame time), live.
93. Wind across the grove: one gust crossing all four plots.
94. W in the grove: Q and E walk through it, trees ana and kata appear, the follow route.
95. Grove runner: frames from the door, inside each plot, through W, and its cost.

### K. Tools, proof and handover (96-100)
96. The dev panel (F1): light, spot, sun and room shape as in the Creation Lab, plus TREES (sizes,
    pedestal radii and heights), WIND, LEAVES and GROVE, with SAVE.
97. Performance pass: every area under 8 ms; fix what is not.
98. Play it through as a visitor (a runner with simulated keys from the door to the grove), frames
    at every beat, and look at them.
99. The case study and this handover finished, `engine_capabilities.md` and memory updated.
100. Commit by explicit paths (only `Arboretum/` and this file), and report.

## 5. Status

**Done, 6 Oct 2026, and seen working in frames and a film.** All 100 steps ran; where a step changed
course the case study says how. What to look at first:

1. **Play it:** open `res://ramon/Arboretum/arboretum.tscn` and run it. Walk the floor route from the
   door: 01, 02, 03, the oak, round it to the grove door. Each story plays as you arrive; click or the
   arrows step it on; E at a pedestal rebuilds it (or turns the oak's season), E at its console opens
   its card. G a gust, V the volume view, B the palette, F1 the dev panel, F4 the path builder.
   The pad by the entrance (PLAY THE SHOWCASE) runs the guided tour.
2. **The film:** `project/smoke_test_output/video/arboretum_tour.mp4` (48 s, the guided tour and a gust).
3. **Frames:** `project/smoke_test_output/arboretum/` (`room/`, `room/stories/` a frame per story part,
   `room/cards/`, `room/grove/`, `room/volume/`, `play/` the play-through, `oak/` the oak study).

**Proof:** `scripts/_proof_runner.gd` 0 failed (stations, baked counts, stories, every text token
filled, the oak's leaves, both path graphs pass rule 10, the panels' text fits, the grove loads with
its four plots). `scripts/_play_runner.gd` 29 of 29: the room played by its keys (the tour and Esc,
arrival stories, the arrows, E at each pedestal and console, G, V, B, F1, F4, the grove drawn near its
door and the hall hidden deep inside it). `scripts/_perf_runner.gd`: every view under 8 ms (case
study 6).

**Not checked by a runner:** the mouse. A click, the wheel and a right drag are read only while the
mouse is captured, and a runner must not capture yours; a click runs the same code as the arrows and
E, the wheel and drag are the carried showcase's own, as in the Creation Lab. The F1 sliders were
opened and shut, not each moved.

**Changed from the plan:** the oak grows by its own space colonization (case study 4), the grove's
trees stand within a metre of your slice, not 2.4 m (case study 5), and the volume view projects only
the trees (case study 7). The step-10 budget figure of 1.25 KB a tetrahedron was too low; measured
memory is in case study 6.

### What is where

| Path (under `project/ramon/Arboretum/`) | What it is |
|---|---|
| `arboretum.tscn`, `arboretum_4d.gd` | The scene and its root: room shape exports, the player, HUD, stations, tour, grove streaming, keys |
| `arboretum_info.tres` | The wall panels' words (title, lead, description, controls) |
| `botany/` | The trees: skeleton, species (FORM, PRESETS, the oak's loft and leaves), `colonize_4d.gd` (the oak's growth), the voxel, engine (DC) and loft builders, leaves, wind, pivots, style, bake store |
| `exhibits/` | One script per pedestal (its story `chapters()`, its key `action()`, its `card()`) on a shared base |
| `grove/` | The grove: plots, streaming, signs |
| `room/` | Consoles and cards, floor numbers, path targets, the dev panel (F1), the panels' data source |
| `shaders/` | `botany_bark.gdshader` (wood, wind), `botany_leaf.gdshader` (GPU leaves) |
| `paths/` | The hall's and the grove's route graphs (F4 edits them) |
| `baked/` | Everything pre-baked, and `bake.cfg`, each bake's own numbers |
| `carried/` | The kit, PathCreator, the Shrubbery Lab's generator and the loft builder, carried; `README.md` lists every change |
| `scripts/` | The runners and `arb_run.sh` |

**To rebake** after changing a species or a builder: `scripts/arb_run.sh headless bake res://ramon/Arboretum/scripts/_bake_runner.gd`
(all), or name parts after it (`skeleton voxel dc loft oak grove`). Then `_proof_runner.gd`.
**To tune** while playing: F1, then SAVE (writes `Arboretum/arboretum_tuning.cfg`).

## 6. Case study (what each step found)

### 1. Probes (steps 3 to 8), 5 and 6 Oct

| Probe | What it showed |
|---|---|
| **The old generator** (`scripts/_probe_shrub_runner.gd`) | The Shrubbery Lab's tree as it stood: 200 points, 4.3 m tall, 2.9 m deep in W. At 10 cm cells 21,533 cells and **295,710 tetrahedra** (about 361 MB), at 12.5 cm 149,450, at 15 cm 83,430. Growing it takes 26 ms, voxelizing 43 to 121 ms, meshing 79 to 304 ms: the whole tree is under half a second, so voxel trees can be grown live. Leaves are half the cost. |
| **The engine's voxel world** (`_probe_dc_runner.gd`) | `VoxelWorld4D` meshes by **dual contouring in C++**, generators are settable from GDScript, and writing a material over itself is a true union. An all-air world over the tree is defined in 25 ms; **an edit sent before its chunks are defined is lost** (they load on worker threads), so edits wait. The tree as 1,669 sphere edits: applied in 37 ms, meshed in 185 ms over 11 frames, **148,330 tetrahedra** in 157 chunks: the same as the blocks at the same cell, as dual contouring makes one face for every grid edge the surface crosses. Read back into one mesh in 49 ms. A chunk loads when its centre is in the trigger's radius, so the radius needs half a chunk's diagonal more than the tree. |
| **GDScript packed arrays** (`_probe_packed_runner.gd`) | `(dict["a"] as PackedInt32Array).append(x)` appends to a COPY and is lost; `dict["a"].append(x)` and a typed local (`var a: PackedInt32Array = dict["a"]`) share the array. Three builders had the cast form. |
| **Three methods, one skeleton** (`_probe_trees_runner.gd`, frames in `smoke_test_output/arboretum/probe/`) | Every builder works from the shared skeleton: voxels 117,210 tetrahedra built in 67 ms, the engine's tree read back and labelled for the wind (36,738 points in 154 ms), the loft 37,028 in 471 ms, 3,598 GPU leaves in 7 ms. The wind moves all three the same way, the leaves draw in the cross-section world and are cut by the slice. **But the wood is nearly invisible** (case study 2). |

### 2. The first pivot: a 4D tree's form

The frames of the first probe showed leaf clumps floating over bare trunks. The skeleton spreads
1.5 m through W, the twigs are 2 to 4 cm thick: a branch is in your slice only where its W is within
its own radius of the slice's, a few percent of it. That is true 4D, and it does not read as a tree.

Two answers, compared side by side (`_compare_forms_runner.gd`, frames in `smoke_test_output/arboretum/forms/`):
- **A, squashed:** grown, then flattened through W (x0.45), and the wood four times deeper in W than
  across. The default slice holds most of the tree; but W is special, and turned through W it shows
  its edge.
- **B, isotropic:** grown free in 4D, the same in X, Z and W (4Denthusiast's direction for the grass
  and the player, 5 Oct), with the wood twice as thick all round and a denser leaf crown.

What the frames showed (`forms/01_w0.png` to `04_turned_45.png`, and the enlarged `zoom_*.png`):
- In every variant the **leaves carry the read**; the wood shows as a trunk and a few limbs.
- **A** gives the fuller crowns at W 0 and as the slice moves; turned a quarter turn through W its
  crown becomes a narrow slab, which is what a tree flattened in W is.
- **B** reads the same from every side, as promised, but sparsely in any one of them: a trunk, the
  stubs of the limbs that cross your slice, a leaf cloud. A branch leaning into W shows a stub about
  2r / sin(lean) long: in a tree grown evenly through W, only a few percent of the limbs lie in any one
  slice.
- **Decision: A** for the pedestals (the room has to read as four trees), softened (W x0.55, the wood
  three times deeper in W, at least 22 cm), with **B one constant away** (`botany/tree_species.gd`
  FORM). It is a question for Ramon (and worth showing 4Denthusiast).
- The frames also showed the real problem under both: **the Shrubbery Lab's tree is not much of a
  tree.** Its attraction box reaches the ground, so the trunk bends over like a question mark and the
  crown is a shrub (case study 3).

### 3. A skeleton that makes a tree

The generator is right; its setting is not. Runions et al. grow a tree into a crown envelope that
sits above a clear trunk, so the trunk climbs on its own until the envelope is in reach and the crown
branches inside it. `botany/crown_shape_4d.gd` is that envelope in 4D (an ellipsoid cut flat
underneath, denser toward its skin), and both species now grow in one (`tree_species.gd` PRESETS).
Candidates compared side by side in `scripts/_species_runner.gd` (frames in `species/`, enlarged in
`species/zoom_*.png`), all lofted in the room's form with the GPU leaves:

| Candidate | Points | Branches | Loft | Leaves | What it looks like |
|---|---|---|---|---|---|
| the Shrubbery Lab's box | 200 | 41 | 32,804 | 4,658 | a trunk curling over, a shrub |
| crown A (700 points, reach 1.25 m) | 520 | 158 | 55,056 | 11,426 | a tree: trunk, rounded crown |
| crown B (reach 1.8 m) | 520 | 158 | 54,312 | 11,494 | narrower, a tight ball |
| **crown C (1,100 points, denser skin)** | 700 | 195 | 69,812 | 15,970 | **the fullest crown, the clearest limbs** |
| the oak | 950 | 286 | 93,976 | 21,092 | wide crown; its trunk leans hard |

- **Crown C** became the specimen. Turned an eighth through W and at W 0.35 every crown candidate still
  reads as a tree (the squashed form's softer setting holds up).
- **The oak's lean:** its crown starts low and its points are in reach of the very first tip, so the
  trunk bends toward whichever side it sees first. Both species now grow a **straight trunk first**
  (`trunk`, 1.2 m and 1.7 m) and let the crown colonise from its top.
- **Later, case study 4:** the straight trunk was not enough for the oak; it now grows by a different
  algorithm.

### 4. The oak's skeleton: the paper's own algorithm

In the room the oak still leaned: its trunk curved up and over like a question mark, its crown thin
and off to one side. The trunk was not the cause. The carried generator differs from the paper in two
ways that matter for a wide crown: **every point pulls every tip in reach** (in the paper a point pulls
only the node nearest to it, so neighbouring branches share the space out), and **only tips grow** (in
the paper any node with points of its own sprouts, which is where side limbs come from). In a crown
4.6 m wide every tip chased the same clusters, and the oak spent its 950-node cap on a few long
wandering limbs.

`botany/colonize_4d.gd` is the paper's version in 4D: nearest node within the radius of influence, any
node sprouts toward its points' average, a perception cone (a node ignores points behind it), the kill
distance, a straight trunk first. Each point remembers its nearest node, and each step only the new
nodes are checked against it, so 2,400 nodes and 2,600 points grow in **0.23 s** of GDScript. Compared
in `scripts/_oak_runner.gd` (frames in `smoke_test_output/arboretum/oak/`; lean is the trunk's angle
from upright to 3 m up, balance how far the tips' middle sits off the trunk against the half width):

| Oak | Nodes | Lean | Balance | Wood (tetrahedra) | Leaves | What it looks like |
|---|---|---|---|---|---|---|
| the carried generator | 950 | 6.0° | 0.66 | 149,376 | 21,066 | a leaning trunk, a crown off to one side |
| **paper, cone 60°, limbs drooping (0.1)** | 2,400 | 2.7° | 0.02 | 397,492 | 59,282 | **an oak: straight trunk, spreading limbs, a round crown** |
| paper, cone 80° | 2,372 | 4.4° | 0.01 | 394,676 | 56,826 | the same, limbs climbing more |
| paper, 0.5 m steps | 1,500 | 3.5° | 0.03 | 230,472 | 35,182 | sparser twigs (the grove's oaks use it) |

- **The wood's cost** came from lofting by branch order: in the paper's tree most nodes sit on thin
  limbs of low order, which got the trunk's eight-sided rings. Sides and smoothing now follow each
  branch's own thickness (`loft_tree_builder.gd` "by_radius", `tree_species.gd` OAK_LOFT):
  **397,492 tetrahedra became 131,972** with no visible change at the room's distances.
- **The crown.** With the old leaf settings the crown was a speckle you could see through. Compared at
  five settings (`oak/sheet3.png`), the chosen one is 44 leaves a node, 0.22 m leaves, 0.6 m deep in W:
  **76,762 leaves**, a full crown that still shows its limbs. Deeper or more spread turned it into a
  green blob. (Question 4: the leaves now reach further through W than the wood.)
- The story's first part now says what the algorithm does ("each point in the crown pulls only its
  nearest bud, and any bud can sprout") and the card names it.

### 5. The grove: drawn is what costs, and a 4D lattice eats thin trunks

Four findings, each from frames or numbers:

- **Loaded is not drawn, but drawn is paid for everywhere.** The cross-section renderer cuts every
  tetrahedron of every visible mesh each frame, in view or not. The grove (870,000 tetrahedra drawn)
  started loading 22 m from its door, which is at pedestal 03, and from then on it cost the hall about
  **5 ms of GPU** (the empty hall measured 7.1 ms, more than the full hall from the door, which is how
  it showed). Now the grove is drawn only within 12 m of its door or inside, and the hall's trees are
  not drawn 6 m into the grove: the empty hall is **0.4 ms**, pedestal 03 **2.2 ms** instead of 8.4,
  the grove's crossing **2.5 ms** instead of 6.3 with the hall drawn.
- **A grove spread through W is an empty grove.** The trees stood up to 2.4 m ana and kata; a
  flattened tree is about 1.4 m deep in W, so at W 0 you saw two or three trees of seven. Now two in
  three stand within 0.3 m of your slice and the rest 0.5 to 0.9 m out, where they show as thinner
  cuts and grow and shrink as you walk through W (`room/grove/07_oak_plot_w*.png`).
- **The 25 cm voxel and engine trees had no trunks.** Their meshes started at 1.5 m: crowns floating
  over the floor. In 4D the cell centres nearest a vertical line can be **√3/2 of a cell** from it
  (across X, Z and W at once), 21.7 cm at 25 cm cells, and the trunk's radius was 21.2 cm, so no
  cell was filled. The engine's sphere edits miss the same way. The grove's trees now draw nothing
  thinner than 0.9 of a cell (`min_r_cells`, both builders); the room's 12.5 cm trees are unchanged.
- The capture spots stood behind the signs at the crossing; the plots are now shot from the aisles.

### 6. Performance, memory and the loading answer

Measured by `scripts/_perf_runner.gd` (vsync off, 150 frames a view, medians; this machine, Windows;
the window 1280 x 720):

| View | Frame | GPU |
|---|---|---|
| the door, the whole hall in view | 4.8 ms | 4.4 ms |
| at 01 / 02 / 03 | 4.0 / 2.5 / 2.5 ms | 3.6 / 2.2 / 2.2 ms |
| at the oak | 2.1 ms | 0.7 ms |
| each tree alone (01 / 02 / 03 / 04), from the door | 1.6 / 1.7 / 1.4 / 2.3 ms | 1.4 / 1.4 / 1.1 / 2.0 ms |
| the empty hall | 0.8 ms | 0.4 ms |
| near the grove door (hall and grove drawn) | 7.8 ms | 7.3 ms |
| the grove's crossing (hall hidden) | 2.8 ms | 2.5 ms |

- **The wind** (A/B/A at the door): **1.2 ms of GPU** for all four trees and the leaves. Every corner
  walks its branch's chain of parents to the trunk. Cheaper would be the branch rotations worked out
  once a frame on the CPU and written into the pivot texture.
- **The leaves:** 0.8 ms for 76,762. Each leaf was 45 vertices and every vertex runs the whole wind
  chain; 24 vertices keep the lobes and halved it (1.35 ms before).
- **Video memory** (the engine's own count): **1.3 GB** with the hall drawn, **2.0 GB** once the grove
  has been drawn (+665 MB), and it is not given back when the grove is hidden. The step-10 estimate of
  1.25 KB a tetrahedron was low.
- **The answer to step 90:** bake the pedestal trees and load them with the room (0.8 s to open);
  stream the grove on approach and draw it only near; no separate scene for frame time. A separate
  grove scene is the lever for video memory, if that ever matters (question 6).

### 7. What the frames caught in the presentation

Each found by looking at captured frames, fixed, and shot again:

- The title card stayed on screen after you walked away from every pedestal (the carried presenter
  stopped redrawing when it had no showcase), and the last pedestal's callout showed at the next one.
- A part's own line printed its token raw ("{leaves} leaves, ..."), in the presenter and in the tour's
  caption. The proof runner now checks every line, not only the callouts.
- The floor numbers cut their titles ("02 | SMOOTH V"); they now shrink to fit.
- Walking away mid-story left a pedestal holding a skeleton; leaving now hands the tree back whole.
- The story runner counted frames, so every later shot came early; it now waits on the story's clock.
- The tour's camera sat inside the new oak's crown; its shots for the oak stand further back, and its
  grove shot starts inside the grove's door (and shows the grove, which the 12 m rule had hidden).
- The volume view (V) projected the walls, floor and pedestals as a haze and the trees barely at all.
  Only the trees are now projected (`allow_projection`, as Slice Garden does), and the ghost is
  stronger: the engine divides the projected colour by (alpha + `projection_opacity_base`), so lower
  is stronger; 0.12 here, the engine's 1.0 is faint. Now the oak's whole skeleton and the grove's
  hidden limbs show as a pale ghost (`room/volume/`).
- F4's path builder failed drawing the route targets: it reads each target's `color`, which the
  Arboretum's targets lacked. Found by the play-through runner.

## 7. Botany Lab: Ramon's walkthrough, part 1 (9 Oct)

He renamed the Arboretum the Botany Lab (c280514, text only) and walked it. The brief, in short:
- bring it in line with the newer Voxel Lab and Aquatic Lab (paths, floating panels, slice
  controls, signage, presentation);
- simplify the hall's route;
- fix the trees leaning when turned;
- give each of the first three pedestals its own technique;
- keep the oak, and grow its branches out of the trunk;
- replace the grove with a second room comparing blocky and smooth voxel landscapes side by side,
  as a separate scene behind a holographic door and a loading screen.

**Fork, per his rule** ("make it as botany labs tscn"): `botany_lab.tscn` beside `arboretum.tscn`;
its scripts in `botany_lab/`. `arboretum.tscn`, its scripts and the menu card stay as they are
until he says to switch.

**Baseline, before anything changed** (16:18, `smoke_test_output/arboretum/baseline_9oct/`):
- proof: every check passes;
- play-through: 29 of 29;
- frames of the room;
- perf: the door 4.71 ms, at 01 3.86, at the oak 1.99, near the grove door 7.80;
- video memory: 1.3 GB, 2.0 GB with the grove.

**What the research found** (three surveys, 9 Oct):
- The Arboretum carries the 4 Oct kit. Its walker and rig predate the pen's GroundBasis4D, and its
  path network has no colour exports.
- **Why the trees lean.**
  - The showcase turns a tree with `from_zw * from_wy`, which tips the trunk (y) into W.
  - Composed with the other drag, that becomes a real lean, and the lean then precesses with the
    turntable.
  - The Voxel Lab's showcase already fixed this (`Ground.cleaned(Ground.sliced(...))`, 8 Oct: "a
    tree leaned 20 degrees").
- **The two kits.** The Aquatic Lab's carried kit is a superset of the Arboretum's, except for the
  research board's "methods" layout and charts, which are the Arboretum's own.
- **Why some of the path reads grey.**
  - A destination turns "completed" the moment you arrive, and the completed symbol is drawn in
    grey-blue #668BAE.
  - The frames carry one grey stroke.
  - `under_color` never follows the B palette.
- **Voxels.**
  - The native VoxelWorld4D always dual-contours. A blocky look needs box content (the Voxel Lab's
    bricks) or the project's own box-per-cell mesher (`botany/voxel_tree_builder.gd`).
  - The sandbox's GDScript voxel world (Trym's, tidied by Aaron) fails to parse. The native one is
    Andrew's.
  - No code anywhere makes cohesive foliage masses. The dual-contoured leaf balls fuse wherever they
    overlap, so fewer, bigger, jittered balls should merge into masses.
  - A blocky and a smooth version of the same tree already exist: the voxel bake and the
    dual-contoured bake.

### The plan (78 steps)

**A. The fork (1-8)**
1. `botany_lab/carried/`: a copy of the Aquatic Lab's carried kit, with its paths rewritten. Leave
   out water4d and flock.
2. Merge into that copy:
   - from the Voxel Lab: `kit_showcase_4d.gd` (the GroundBasis turn, `reset_view`, `max_tilt`,
     `band_print`), `vl_shimmer_4d.gd` and `vl_load_board.gd`;
   - from the Arboretum: the "methods" research layout and its charts.
3. `botany_lab.tscn`: a copy of `arboretum.tscn`, repointed to the new root and the carried kit.
   The GroveRoom, the Grove and its route go.
4. `botany_lab/botany_lab_4d.gd`: a fork of `arboretum_4d.gd` on the new kit:
   - the pen's walker values (`pen_walk`);
   - Q/E stepping through W, paused at E spots;
   - the rig's slice turning off in the hall (the exhibits turn, as in the other labs).
5. Fork the exhibits into `botany_lab/exhibits/` (base, VX, DC, LF, OK), pointed at the new kit's
   style, print and build scripts. The builders (`botany/*`) and the bakes stay shared.
6. `botany_lab/README.md`: what is forked, what is shared, and what not to delete.
7. Fork the runners into `botany_lab/scripts/` (proof, play, capture, perf, paths), each taking
   `scene=`.
8. Check: the fork opens clean, and the proof passes on the untouched content.

**B. The entrance and the dev HUD (9-16)**
9. The corridor:
   - the arrival corridor's ceiling goes from 6 m to 7.5 m, and the entrance doorway from 4.2 m to
     5 m;
   - the intro is kept as it is.
10. Tab opens the dev HUD: the Aquatic Lab's light editor. It lists every kit light in the scene,
    with strength, spread, softness, reach and fall-off, a top view, and SAVE to
    `botany_lab_lights.cfg`.
11. The artist panel (trees, wind, leaves, hall) opens with it on Tab, on the left. F1 stays as an
    alias.
12. The lights get clear names in the editor's list: Pedestal 01 to 04, Entrance, Door.
13. The mouse is freed while the HUD is open and captured again when it closes, as in the Aquatic
    Lab.
14. B palette: the path's `under_color` follows the floor swatch (`floor_swatch "kit_floor"`).
15. Check: Tab opens and closes the HUD, and a slider moves a light (frames before and after).
16. Check the HUD at 4K and 145% UI.

**C. The route (17-26)**
17. A new `botany_lab/scripts/_make_paths_runner.gd` writes `botany_lab/paths/hall.tres`.
18. The layout:
    - a straight spine down the hall's middle (x 0), from the corridor to the oak's front ring;
    - one 45-degree branch to each pedestal's approach ring, on the side facing the spine;
    - the oak's ring on the spine itself;
    - a straight run round the oak to the back door.
19. The pedestals keep their places: 01 left, 02 right, 03 left, the oak at the end. Each branch
    leaves the spine 3.6 m before its pedestal and meets the ring at 45 degrees.
20. Each ring sits 1.2 m off its pedestal's deck edge, which leaves room to walk round the
    showcase.
21. The paths are drawn the newer labs' way: `edge_color #1761d7`, `frame_margin 0.12`,
    `floor_swatch "kit_floor"`. The grey of the frames and the done ticks goes to blue.
22. Route states the Voxel Lab's way:
    - visited within the footprint plus 2.6 m;
    - focused (cyan) within 2 m;
    - completed (blue) once you leave.
23. The tour pad joins the route as a short branch off the spine by the entrance.
24. The targets become the newer `water_target_4d` (label, size, w_depth), so the F4 builder works.
25. Check: the graph validates (rule 10), and the proof passes.
26. Check: frames of the whole route, from above and while walking it.

**D. Floating panels (27-35)**
27. The four booth consoles (metal stand and black screen) and the TourSign console are retired.
28. Each pedestal gets a floating panel (the Aquatic Lab's `float_panel_4d`):
    - 1.6 m wide;
    - 1.2 m beside its approach ring, between the ring and the spine;
    - facing the way you come.
29. The panel's face: the number, title and kicker, and three live rows (tetrahedra, build time,
    tier) from `exhibit.face()`.
30. E gives more, a page at a time: METHOD, WHAT IT SHOWS, LIMITS, MEASURED.
    - These are the card's words, so the card overlay goes.
    - The prompt reads "E: More about it".
31. The tour pad gets a floating panel, "THE WHOLE SHOWCASE", with E to play it.
32. The panels light when you are near (`set_near`) and turn to face you.
33. When you are not at its panel, E at a pedestal still does the tree's own thing. The strip says
    which E does what.
34. The floor numbers (01 VOXELS and so on) stay, moved to sit beside each ring.
35. Check: each panel's face and pages (frames), and E paging through them (play runner).

**E. The slice (36-41)**
36. The showcase turns with the floor-only frame (`Ground.cleaned(Ground.sliced(...))`). Up is
    never touched, so trunks stay upright.
37. `max_tilt` is 35 degrees for the trees, so no crown is ever lost.
38. R puts the tree back (`reset_view`), and the strip shows it.
39. The turn resets when a story starts and when you leave a pedestal.
40. The wind keeps its W share: it is a sway, not a lean. Checked in frames.
41. Check: frames of a tree after a run of drags, and the measured lean of its trunk (its y
    component) stays 0.

**F. 01 Voxels: one language (42-47)**
42. The gold twig skeleton goes. The exhibit shows the voxel method itself.
43. The story:
    - THE GRID: a cage of the 12.5 cm cells round the tree;
    - GROWING: the cells fill in by birth order (`vx_stage_0..5`), trunk first;
    - THE COST: cells and tetrahedra;
    - THE SLICE;
    - THE WIND.
44. The cage is drawn as the lab grid's lines on a box, so there is no new mesh language.
45. The leaves stay voxel cells, blocky like the rest.
46. E: the cell size, 12.5 to 18.75 to 25 cm, as now.
47. Check: a frame of each part of the story.

**G. 02 Smooth voxels: smooth throughout (48-54)**
48. The boxy "spheres" stage goes; it was showing the voxel stages. The story shows the actual
    sphere edits: smooth balls along the branches, then contoured into one surface.
49. The foliage becomes fewer, bigger leaf balls that overlap and fuse into masses:
    - leaf radius from 0.22 m to about 0.5 m;
    - three balls to a clump, offset and sized at random (seeded);
    - clumps only at the outer twigs.
50. A new bake, `baked/bl_dc_wood.res`, with that foliage. The Arboretum's bake is untouched.
51. The story:
    - THE BRANCHES: sphere chains, smooth;
    - THE CONTOUR: the engine's dual contouring;
    - THE LEAVES: the masses;
    - THE SLICE;
    - THE WIND.
52. E grows a new seed live, as now, with the new foliage.
53. Check: frames, the foliage reading as masses, and the tetrahedra and build time recorded.
54. If the masses still read as balls, try the Clipped generator with noise over a box. Note which
    way won.

**H. 03 Lofted: a branch and loft showcase (55-60)**
55. The spherical foliage clumps go.
56. The story:
    - THE SECTIONS: the gold station rings along every branch, where the loft samples;
    - THE SKIN: lofted through them, branch order by branch order, trunk first;
    - THE JOINTS: close on a fork, where the twigs grow out of the lofted wood;
    - THE SLICE;
    - THE WIND.
57. E: the resolution (as baked, coarse, fine, in sides and rings), shown on the wood itself.
58. The panel's words say how it differs from 02: a surface built along each branch, not a volume
    filled and then contoured.
59. If anything changes in the wood, bake `bl_lf_*`; otherwise share the existing bake.
60. Check: a frame of each part.

**I. The oak: grown from its trunk (61-65)**
61. The gold bones go, and the "form" part becomes GROWING:
    - the trunk alone (`oak_order_0`);
    - each branch order growing out of the wood in turn (`oak_order_1..3`), each revealed with a
      short scale-in from its base.
62. Then the leaves grow (as now), then the slice and the wind. The final state is the oak as it
    is now.
63. The oak's dense trunk, its silhouette and its foliage are unchanged.
64. Check: the growth in frames, one a second.
65. Check: the oak's frame time against the baseline.

**J. The door and the second room (66-76)**
66. A black-text destination sign over the back door, Voxel Lab style (`kind "sign"`, plain wall):
    "TWO VOXEL WORLDS / BLOCKY AND SMOOTH, SIDE BY SIDE".
67. The back door becomes a holographic doorway (`vl_shimmer_4d`, 3.2 x 4.1). Walking in flashes
    out and loads `botany_lab/compare/botany_compare.tscn`.
68. `botany_compare.tscn`: a kit room of about 36 x 12 x 48 m, with the same walker, rig, HUD and
    dev HUD (Tab, with its own lights file).
69. The loading board (`vl_load_board`):
    - "TWO VOXEL WORLDS";
    - the parts coming in, with a dot per chunk;
    - it finishes when both worlds are steady and every tree is placed.
70. LEFT, blocky:
    - a square ground display (box pedestal style, about 14 x 22 m) of 4D voxel terrain;
    - 0.5 m cells, heights from noise over x, z and w, meshed box per cell like the voxel tree;
    - trees from the blocky bakes (`grove_vx_*`), with voxel leaves;
    - square silhouettes throughout.
71. RIGHT, smooth:
    - the same display size and the same height noise, as Andrew's native VoxelWorld4D
      (dual-contoured, the Landscape generator clipped to the square);
    - lofted trees (`grove_lf_*`, `oak_lite2/3`) with the GPU leaves.
72. Both halves use the same layout seeds, so the same hills and the same tree spots are built two
    ways.
73. The centre path runs straight down the middle between the halves, with a ring at each half's
    viewpoint and one at the far end.
74. The explanations:
    - left blue wall, THE BLOCKY WAY: a heading, three short lines, and a diagram (cells to boxes);
    - right blue wall, THE SMOOTH WAY: cells to a contoured surface;
    - one floating panel per side by its ring, with live numbers (voxels, tetrahedra, build ms).
75. The way back: a holographic doorway at the near end. The hall spawns you at its back door,
    facing in.
76. Check: the load time, the frame times on the path, frames of both halves and of the boards,
    and the trip there and back.

**K. Close (77-78)**
77. Full checks on the fork:
    - proof, play-through and frames, against the baseline;
    - perf against the baseline, plus the new room's numbers.
78. Commit by explicit paths. Then:
    - update this handover's status, and memory;
    - add his questions at the end: when to switch the menu to the fork, and whether to retire the
      grove.
