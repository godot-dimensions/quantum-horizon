# W tools: desk research (7 Oct 2026)

For two tools: a **W exploder** (stand copies of hand-placed trees ana and kata) and a **W optimiser** (make a landmark survive slice turns). Notation used throughout: an object at horizontal distance **d** from the camera, slice turned **θ** in a plane (v, W) where v is a horizontal direction, object half-size **hw** in W and **hu** along v.

---

## A. How existing 4D games and engines build objects

**Miegakure (Marc ten Bosch)**
- Primitives are extrusions. The grove's columns are spherinders, "a sphere that has been extruded in the fourth dimension"; tilted ones read as floating ellipsoids, fallen ones as spheres. Grass blades float because their roots are "out of sight in the fourth dimension": an accepted 4D signature, not a bug. [grove post, Nov 2016](https://marctenbosch.com/news/2016/11/spherinder-grove-video/)
- Trees: "A 3D slice of a 4D tree might look too different from a regular 3D tree, so we first introduce extruded 3D trees." Confusing 4D objects are moved later in the game or simplified. [SIGGRAPH blog interview, June 2025](https://blog.siggraph.org/?p=19413)
- Making doodads "correct" in 4D "made the game more visually complicated but also easier to play"; building slicing was standardised across the game. [Miegakure update end of 2019](https://marctenbosch.com/news/2020/01/miegakure-update-end-of-2019/)
- Level rules: tiny tile levels (e.g. 4x4x7x4) and few objects, because filling 4D grows as 10^4; the core move is a 90-degree swap of one axis for W, and levels get harder or easier by a 90-degree turn. [Nature as Designer, Oct 2014](https://marctenbosch.com/news/?p=905)

**4D Toys (ten Bosch)**
- Rendering: each object's 3D boundary is a tetrahedral mesh; each tetrahedron is sliced every frame into a triangle or quad (after GL4D). Figure 3 of the paper: dominoes "initially out of view, offset in the fourth dimension". [N-Dimensional Rigid Body Dynamics, SIGGRAPH 2020](https://marctenbosch.com/ndphysics/NDrigidbody.pdf); [GL4D](https://www.cse.cuhk.edu.hk/~cwfu/papers/GL4D/paper/GL4D.pdf)
- Slice rotation (2023): ten Bosch warns that turning the slice about the camera can make "the level completely invisible"; his interface keeps "the level always in front of you no matter how you rotate in 4D", with both continuous and 90-degree steps ("axis-aligned rotations are the easiest to understand"). Optional projection of 2D faces onto the slice shows roughly where objects are, but "it's very easy for the projections to overlap too much". [4D Toys update 8](https://marctenbosch.com/news/2023/03/4d-toys-update-v-1-8-rotating-the-3d-slice-2d-faces-projections-marble-scenes-and-many-more/)

**4D Golf (CodeParade) via Engine4D, its open-source core** ([README](https://github.com/HackerPoet/Engine4D): "This engine is the core of 4D Golf")
- The whole primitive library is generated from 3D meshes ([GenerateMeshes4D.cs](https://github.com/HackerPoet/Engine4D/blob/main/Assets/Editor/GenerateMeshes4D.cs)): `Generate4DExtrude` (spherinder = extruded icosphere, prisms, wedges), `GenerateDuoPrism` (cubinder, duocylinder), `GenerateRevolve` (spheritorus, tiger, ditorus: a +z half-mesh rotated in the zw plane, full or partial angle, the same idea as our xw spin), `Generate4DPyramid` (cones, spikes), `Generate4DFlat`, OFF polytopes. Compound props (the "Table") are prefabs of primitives merged into one mesh.
- Mesh deformers ([Mesh4DBuilder.cs](https://github.com/HackerPoet/Engine4D/blob/main/Assets/Editor/Mesh4DBuilder.cs)): `Perturb(x,y,z,w)`, `Wave`, `Twist(angle, plane, pivot, axis)`, `Spherize(ratio, aboveW)`, `Scale`.
- Visibility aids: every object can carry a low-detail "ghost projection" mesh, faded out by `_ShadowDist`; "meshes with lots of overlapping ghost triangles should use a very low alpha". Objects have `PositionW`/`scaleW`. An editor slicer window and volume mode (F10).
- Performance: `Occlusion4D` skips an object when its bounding sphere is further than its radius from the slice, or outside the view frustum ([Occlusion4D.cs](https://github.com/HackerPoet/Engine4D/blob/main/Assets/Scripts/Occlusion4D.cs)): the same test as our `is_cut_by`, with a sphere instead of a box.
- The level-editor devlog is video only ([Devlog #5](https://www.youtube.com/watch?v=5pTBSafvQ7Y)); I found no text of it, so nothing here relies on it.

**4D Miner (Mashpoe)**: a voxel world where turning the slice shears the world; no technical text on its trees was found. [Steam](https://store.steampowered.com/app/1941640), [list of 4D games](https://en.wikipedia.org/wiki/List_of_four-dimensional_games). (Hyperbolica was left out: it is curved 3D space with no W axis to slice.)

**godot-4d module** (local doc_classes; [repo](https://github.com/godot-dimensions/godot-4d)): shapes include spherinder (`CylinderShape4D`), `CubinderShape4D`, `DuocylinderShape4D`, `GeneralShape4D`, each with `to_tetra_mesh({"segments": n})`. `Camera4D` has `w_fade_mode`, `w_fade_distance` and hue shift (orange ana, blue kata), and for volume view `projection_opacity`, `projection_opacity_base`, `plane_sharpness` and `edge_falloff`. `MeshInstance4D.allow_projection = false` hides one mesh's projection in Combined and Projected modes.

**What they share:** (1) almost everything is an extrusion, a product or a revolution of a 3D shape; (2) small, sparse levels; (3) axis-aligned 90-degree turns as the readable default; (4) per-object slice culling; (5) faint projections or ghosts as a "where is it" aid, kept low in opacity.

---

## B. Vegetation in 4D

- **Published 4D trees:** I found none beyond Miegakure's grove (extruded trees first; seeing "inside" birch trees when facing W). There is no 4D L-system or colonization paper. Space colonization (attraction points, radius of influence, kill distance, node distance) uses only Euclidean distances, and its authors already lifted it from 2D to 3D ([Runions, Lane, Prusinkiewicz 2007](https://www.algorithmicbotany.org/papers/colonization.egwnp2007.pdf)). The Arboretum already runs it in 4D (`Arboretum/botany/colonize_4d.gd`). So variety comes from rebaking with other seeds or envelopes, not from new theory.
- **Blue noise in (x, z, w):** Bridson's Poisson-disk sampler works in any dimension: grid cells r/√n, candidates in the r..2r annulus, k ≈ 30 tries, O(N). He notes that jittered/stratified sampling "reduces but doesn't eliminate clustering". [Bridson 2007](https://www.cs.ubc.ca/~rbridson/docs/bridson-siggraph07-poissondisk.pdf). To keep a hand layout, put the authored trees into the grid and active list first. That is my adaptation, not in the paper. Sample elimination gives an exact count in any dimension, without choosing a radius ([Yuksel 2015](https://www.cemyuksel.com/research/sampleelimination/)). Relaxation (Lloyd-style) is the usual clean-up: Houdini Scatter "Relax Iterations", ProtonScatter "Relax Position".
- **Hand-placed at W 0, procedural elsewhere:** keep a protected band |W| < h_protect (crown W half-size plus leaf margin, now 4.5 m) where only authored trees stand, so the farm's slice is exactly what Ramon placed.
- **Stable seeds:** Houdini's "Primitive Seed Attribute" exists to keep results "consistent when primitives are added or removed" ([Scatter SOP](https://www.sidefx.com/docs/houdini/nodes/sop/scatter.html)). `pen_trees_4d.gd` draws everything from one sequential RNG, so adding or removing one authored tree reshuffles every echo. Seeding each echo from hash(tree id, layer) fixes this.
- **Rotations that keep trunks vertical:** any rotation in the xz, xw and zw planes leaves y alone, so a copy can take any orientation of the (x, z, w) space. The current code uses zx·xw, two of the three degrees of freedom; adding `Basis4D.from_zw` gives all three. With `w_stretch` 1.8 the crown is an ellipsoid, so the turned copies show cuts of varying width. Whether they read as different trees is an eye test (see Open questions).
- **Floating crowns:** a tree is cut wherever its crown reaches (about ±3.6 m in W), but its trunk only within its own W half-width (about 0.4–0.8 m). So most turned-slice cuts show crowns with no trunk, roughly r_trunk/h_crown ≈ 15–20 % with a trunk. Miegakure keeps this effect on purpose for grass. For a "natural wood" it is the main readability risk.

---

## C. Geometry a W optimiser can use

**Visibility under a slice turn about the camera.** Signed distance to the turned slice: s = w·cosθ − (p·v)·sinθ. A box is cut while |s| ≤ hu·sinθ + hw·cosθ (the `is_cut_by` test). For an object at d along v with w = 0, it stays visible while

  **tan θ ≤ hw / (d − hu)**, so the required half-thickness is **hw ≥ (d − hu)·tan θ.**

Required hw (taking hu = 0):

| d \ θ | 10° | 20° | 30° | 45° |
|---|---|---|---|---|
| 10 m | 1.8 | 3.6 | 5.8 | 10 |
| 20 m | 3.5 | 7.3 | 11.5 | 20 |
| 40 m | 7.1 | 14.6 | 23.1 | 40 |
| 60 m | 10.6 | 21.8 | 34.6 | 60 |

Past about 40 m a 30-degree turn needs over 20 m of W, which is wrap territory. At 90° only something the camera stands inside, or a wrap, survives.

**What the player sees with each strategy** (camera turning about itself):

| Strategy | As the slice turns | Gone at | Cost | Collision |
|---|---|---|---|---|
| Extrude in W (hw) | appears farther away (d/cosθ) and stretched 1/cosθ in depth, then clipped | atan(hw/d) | cheapest: two caps plus side walls | one box, W size = 2hw |
| Spin about own axis (radius r, xw) | cut off-centre, so it shrinks; appears closer (d·cosθ) | asin(r/d) | about steps × side walls (12–16× the profile) | box hugging the round shape; its corners stick out ~41 % at 45° |
| Spin a half-lathe (round in x, z, w; the range's barrels) | the same for xw and zw turns about its own axis | asin(r/d) | as spin | as spin |
| Quarter-turn copy about own axis | the same at 0° and 90° only if you stand inside it; both copies cross at 45° | (unchanged from afar) | 2× | 2 boxes |
| Repeat copies every Δ in W | copies take turns, appearing at lateral offsets kΔ/tanθ, so it "jumps" and multiplies | never, inside the band | N× (culled, so drawn about 1–2×) | box per copy |
| Wrap: sweep in the (radial, W) plane about the area centre, arc ±α at radius R | **stays at the same bearing and distance** for any turn ≤ α (mountain-shell behaviour) | α | steps × side walls; segment it so only 1–2 pieces draw | none needed if R ≥ the walkable boundary |

Derivation of the wrap row: the swept point at angle φ has s = R(sinφ·cosθ − cosφ·sinθ·(u·v)), and that is zero at tanφ = tanθ·(u·v). So one arc in the (radial, W) plane covers turns in every horizontal direction. A full ±180° wrap also puts a copy opposite the original in the flat slice, which is fine for mountains but wrong for a unique tower. Segment angle for a sagitta ε: Δφ ≈ √(8ε/R), about 7° at R = 50 m and ε = 0.1 m.

**The layered forest, explained.** A layer at W = w_k is cut along a lateral strip centred at t = w_k/tanθ, with width 2h/sinθ. A band of layers |W| ≤ W_max is therefore cut out to a lateral distance (W_max + h)/tanθ. With W_max = 9 m and h = 3.6 m that reach is 71 m at 10°, 35 m at 20° and 22 m at 30°. This explains the measured 40/51/44/31: full inside 40 m up to about 17°, thinning at 30°. Rules:
- **Reach:** W_max ≥ D·tanθ_target − h. For D = 40 m: 11 m for 20°, 19.5 m for 30°, 36 m for 45°.
- **No empty stripes:** layer spacing Δ ≤ 2h (4.5 ≤ 7.2 holds).
- **Same density turned as flat:** a turned slice shows share·2h/Δ times the authored density, which is 1.2× now. Share = Δ/(2h) ≈ 0.62 matches it; use a smaller effective h if crown-only cuts "don't count".
- **Instances:** n0·(1 + 2L·share) for L layers per side. Culling keeps the drawn count near the visible count, but the cull loop grows linearly (`cull_usec`).

**Draw cost.** The cross-section renderer cuts every tetrahedron of every drawn mesh each frame (`pen_oak_4d.gd` header). Every tetrahedron also costs about 1.25 KB of video memory (`theatre/theatre_shapes_4d.gd`). So:
- Echoes must share meshes (they do, per bake).
- Wraps and repeats must be separate culled pieces, never one merged mesh, because a merged mesh is drawn whole.
- Spinning a big landmark costs about 10× extruding it.
- Box culling with leaf margins (`_half` adds 1 m) can count the ±4.5 m layers as cut at 0° even when nothing shows. That may explain 40 cut at 0° against 27 authored.

**Readability.**
- Extruded objects stay recognisable (ten Bosch introduces them first). Full 4D shapes look different with every cut.
- Projections clutter fast (ten Bosch; Engine4D's low-alpha advice). Echo trees multiply volume-view clutter, so `allow_projection = false` on echoes and keeping it on landmarks is a cheap lever.

---

## D. Tool UX precedents

| Tool | Ideas worth taking |
|---|---|
| Houdini Scatter ([docs](https://www.sidefx.com/docs/houdini/nodes/sop/scatter.html)) | Density or Force Total Count (stops count flicker); Density Attribute; Relax Iterations; Global Seed plus per-primitive seed attribute |
| Unreal PCG ([overview](https://dev.epicgames.com/documentation/en-us/unreal-engine/procedural-content-generation-overview), [Self Pruning](https://dev.epicgames.com/documentation/en-us/unreal-engine/python-api/class/PCGSelfPruningParameters)) | Node graph: Surface Sampler (Points Per Square Meter, Point Extents, Looseness) → Density Filter → Transform Points (offset/rotation/scale min–max) → Static Mesh Spawner (weighted); Self Pruning (large-to-small); per-point seed; Generate button; per-node debug view |
| Unreal Procedural Foliage ([docs](https://dev.epicgames.com/documentation/en-us/unreal-engine/procedural-foliage-tool-in-unreal-engine)) | Growth simulation (Num Steps, Initial Seed Density, Average Spread Distance); Collision and Shade Radius; Overlap Priority; Blocking Volume |
| Unity trees ([docs](https://docs.unity3d.com/Manual/terrain-Trees.html)) | Tree Density as a minimum spacing; height and width ranges; Lock Width to Height; Random Tree Rotation; Color Variation; Mass Place with "keep existing" |
| ProtonScatter ([repo](https://github.com/HungryProton/scatter)) | A modifier stack: Create Inside (Poisson: radius, samples before rejection), Randomize Transforms, Relax Position, Project On Colliders (max slope), Remove Outside, Clusterize (mask), Look At; ScatterShape with `negative` for exclusion; `global_seed` plus per-modifier `override_global_seed`; `restrict_height` |
| Spatial Gardener ([repo](https://github.com/dreadpon/godot_spatial_gardener)) | Brushes: paint, erase, single, reapply; per-plant density, scale range, offset and rotation jitter; octree plus LOD |
| Horizon Zero Dawn ([talk](https://www.guerrilla-games.com/read/gpu-based-procedural-placement-in-horizon-zero-dawn)) | Placement rules recompute when artists "paint in a tree line" or redirect roads, so authored inputs drive the procedural ones |

**How they translate to W:**
- The modifier stack becomes Echo layers or 3D-Poisson → Shift/Jitter → Rotate (xz/xw/zw) → Scale/Swap → Exclude (paths, frames, walls, hills) → Ground-snap.
- Exclusion shapes become 3D regions in (x, z, w): the pen's sphere, not an xz circle. `_clear` ignores W for the valley bound today.
- "Reapply" or a brush on one tree regenerates only that tree's echoes (needs stable seeds).
- "Force total count" means fixing the echo count so tweaks don't flicker the population.
- A debug view means drawing the protected band and the predicted coverage reach on the map's top view.

---

## E. Local code and engine functions

**Existing tricks** (read-only survey):
- `pen_trees_4d.gd`: layers `echo_ws` ±4.5/±9, `echo_share` 0.75, `shift` 0.8–2.2 m, `size_jitter` 0.12, `swap_share` 0.3, `echo_seed`, clearances, valley circle, baked hill test per W layer, one cull loop.
- `pen_oak_4d.gd`: `w_stretch` 1.8 applied as node scale; `is_cut_by` (box against the slice normal), `is_in_view`, `crown_box()`, trunk box collider.
- `pen_rune_range_4d.gd`: `W_HALF` = half the yard width; `_box4` (copy turned `Basis4D.from_xw(PI/2)` about the yard axis; skipped when the box is its own turn); `_spun` (half profile → `extrude_spin_from_faces_xw(m, 12)` → tetra, then `_face_out` fixes winding); `_yard_fence` (one FenceGenerator4D seed whose faces are the two side fences plus two W-end fences); `_turn_stones`.
- `pen_town_wall_4d.gd`: fence-tech faces from −`w_half` to +`w_half` (60 m, past the walkable sphere), so the gate is the only way through from any W.
- `terrain_bake_4d.gd bake_height_shell`: the mountains are a shell in (x, z, w), so any slice near the origin cuts an annulus.
- `cut_stone_4d.gd`: bevels "the same in W".

**Engine functions the tools can call:**
- **PolyMeshBuilder4D:**
  - `convert_mesh_3d_to_4d_faces_only(mesh_3d, which_surface=-1, deduplicate=true)` imports a Godot 3D Mesh as faces.
  - `make_cells_from_manifold_sheets(mesh, tol)` turns faces into cells (needed before `extrude_linear`).
  - `extrude_linear(mesh, extrusion_vector=(0,0,0,1))` extrudes both ways by ±vector; the input needs faces and cells.
  - `extrude_spin_from_faces_xw(mesh, steps=16)` spins a faces-only, +X-half mesh a **full turn** in xw. There is no partial angle, so a partial wrap needs a custom sweep.
  - `solidify_faces(mesh, thickness, offset, miter_limit, hyperplane_normal)`
  - `delete_interior(mesh)`
  - `make_coplanar`, `merge_coplanar_faces`, `subdivide_elements`, `make_boundary_normals_topologically_consistent`, `reconstruct_from_tetra_mesh`
- **ArrayPolyMesh4D / ArrayTetraMesh4D:** `append_vertex`, `append_edge_indices`, `append_poly_cell`, `merge_with(other, offset, basis)`, `transform_mesh(offset, basis)`, `calculate_boundary_normals`, `set_flat_shading_normals`, `to_array_tetra_mesh()` (PolyMesh4D inherits TetraMesh4D), `get_simplex_cell_vertex_indices()` (size/4 = tetrahedron count, a cost metric), `get_signed_distance_to_mesh`.
- **Shapes and primitives:** `BoxTetraMesh4D.size`, `BoxPolyMesh4D`, and `Shape4D.to_tetra_mesh(options)` for `CylinderShape4D` (spherinder), `CubinderShape4D` and `DuocylinderShape4D`. `ConvexHullShape4D.create_from_mesh(mesh)`.
- **Basis and bounds:**
  - `Basis4D.from_xw`, `from_zw`, `from_zx`, `from_yz`, `rotate_plane_local`, `orthonormalized`; `Rotor4D.from_xw`/`from_zw`.
  - `Mesh4D.get_rect_bounds()`; `Node4D.get_rect_bounds_local()`, `get_rect_bounds_global_recursive(to_target_basis, to_target_origin)` (whole-landmark bounds in its own frame).
- **FenceGenerator4D:**
  - Input types: `INPUT_SHAPE_BOX` (with `box_size` x/z/w), `INPUT_SHAPE_SEED_MESH_4D`, `INPUT_SHAPE_SEED_MESH_3D` (3D Y maps to W).
  - Settings: `beam_count`, `beam_coverage` (1 = solid wall), `top_footprint_ratio` (leaning tower walls), `desired_spacing_meters`, `update_fence_mesh_now()`, `is_global_point_inside()`.
- **Rendering hooks:** `RenderingServer4D.pre_render(camera, viewport, engine)` (culling hook), `engine.get_friendly_name()`, `MeshInstance4D.allow_projection`, `Camera4D` w_fade and projection settings.

---

## Recommendations for the two tools

### Tool 1: W exploder (trees)

**Parameters:**
- Distribution: `mode` (Layers / Poisson3D), `layer_spacing` Δ, `w_extent` (or `target_angle` plus `view_radius`, from which it computes W_max = D·tanθ − h), `w_jitter`, `share` (default computed as Δ/2h).
- Placement: `shift` range, `protected_band` (auto: crown W half + 0.9 m).
- Variation: `rotate_planes` (xz/xw/zw toggles), `size_jitter`, `swap_table` (species/bake weights).
- Rules: exclusions (existing, plus the pen's 3D sphere), `seed` (hashed per tree id and layer), `echo_projection` (allow_projection on echoes).
- Buttons: Plant, Clear, Reapply-selected, Show coverage.
- Readout: predicted reach per angle, instance count, estimated drawn tetrahedra.

**Presets:**

| Preset | Layers | Share | Covers (D = 40 m) | Instances |
|---|---|---|---|---|
| Near wood (now) | ±4.5, ±9 | 0.75 | ~17° | 4× |
| Turnable forest | Δ 4.5 out to ±18, W jitter ±0.8 | 0.62 | 30° | ~6× |
| Wide turn | Δ 4.5 out to ±36 | 0.62 | 45° | ~11× |
| Full 4D | Poisson in the pen sphere, protected band, r tuned so a turned slice matches the authored density | – | any | ~13–15× |

- **Layers + jitter:** pros: predictable, matches today's code, easy to reason about. Cons: possible stripes at some angles; copies near their source can read as duplicates.
- **Poisson3D:** pros: no banding, truly 4D at 90°. Cons: most instances, needs the 3D exclusion test and the authored trees as fixed samples, harder to art-direct.
- **Trunk readability** (choose after testing): (a) accept crown-only cuts (the Miegakure precedent); (b) W-taper, a larger W scale near the base so trunks persist; (c) rebake crowns with a rounder (x, z, w) attraction envelope instead of post-scaling, which keeps the trunk thin.

### Tool 2: W optimiser (landmarks)

**Analysis steps:**
1. **Inputs:** landmark root; viewpoints (path-graph nodes within range, or the pen centre), giving d_near and d_far; target angle θ_t; budget (tetrahedra); `w_wrap_length` or preset.
2. **Gather parts:** each MeshInstance4D's bounds in the landmark frame, its tetrahedron count, material and colliders.
3. **Measure:** reach per part, θ_max = atan(hw/(d − hu)) at d_near and d_far; also the landmark's whole curve.
4. **Classify and choose per part:**
   - Ground/flat (low hy): **extrude** to the landmark's hw (always cheap).
   - Enclosures (long and thin): **fence tech** with box faces in xzw (closed in W).
   - Round in plan (barrels, posts, towers): **half-lathe + spin**, so it is identical for any turn about its own axis.
   - Facing panels and signs: **spin** (range boards) or a **quarter-turn copy**.
   - Off-axis props: **quarter-turn copy** about the landmark axis (`_box4`) when visitable; otherwise **extrude**.
   - Silhouette parts (tall, seen from beyond ~25 m): **extrude** to (d_far − hu)·tanθ_t if that is under about 15 m; otherwise a **wrap proxy**: a low-detail silhouette swept ±α about the area centre at the landmark's radius, segmented and culled, without collision, placed at or beyond the walkable boundary. The real landmark stays the φ = 0 piece.
   - Details under ~0.3 m: inherit their parent's strategy.
5. **Report:** before/after reach curves, tetrahedra, colliders, warnings (spin corners, wrap inside the walkable sphere).
6. **Build non-destructively:** output a generated sibling with an on/off switch, like `enclosed_in_w`.

**`w_wrap_length` presets:**

| Preset | Setting | Use |
|---|---|---|
| Prop | hw = footprint radius (spin or quarter turn) | furniture |
| Yard | hw = half the yard width | the range's W_HALF |
| Landmark 30° | hw = (d_typ − hu)·tan30°, e.g. 17 m at d = 35 m | tower and camp from the paths |
| Skyline | wrap α 30–60° at radius R (arc length 2αR) | far towers, crag tops |
| World-deep | hw ≥ pen radius (60 m) | walls that must block every W |

**Trade-offs:**
- Extrude: cheapest and simplest collision, but things slide away and stretch.
- Spin: reads as one object only near its axis, and costs ~10×.
- Quarter turn: exact at 90°, messy at 45°.
- Repeats: cheap with culling, but read as several objects.
- Wrap: the only way to stay steady in view, but needs custom sweep code, segmentation, and placement outside reach.

---

## Open questions to test (only the engine can answer)

1. Does a crown-only cut read as a tree, and what fraction of trunked cuts is enough?
2. Do the layered echoes show stripes at 10–30° compared with W-jittered layers and with Poisson3D?
3. Do xw/zw-rotated copies of one bake read as different trees?
4. How much does the box margin overcount, and should culling use the crown box?
5. Is a stable wrap proxy legible, or does the "following" tower feel wrong next to trees that slide away? Is it better than jumping repeats?
6. Is a quarter-turn copy acceptable at 45°?
7. How many projected echo trees fit before Combined view becomes mush, and does `allow_projection = false` on echoes fix it?
8. Does `convert_mesh_3d_to_4d_faces_only` → `make_cells_from_manifold_sheets` → `extrude_linear` produce clean meshes from Blender assets?
9. Do Cylinder/Cubinder collision shapes work in this physics, beyond boxes?
10. Pivot (Ramon's call, gameplay): should the slice ever turn about a point of interest instead of the camera, as in 4D Toys?

## Test ideas (measurements)

- **Coverage curves:** trees cut within 40 m against angle 0–90° in 5° steps, xw and zw, from 5 viewpoints. Split into trunk+crown / crown-only / box-cut-but-empty. Run per preset.
- **Landmark reach:** cut tetrahedra (or cross-section area) against angle at d = 10/20/40 m, before and after each strategy. Do it offline from boxes first, then confirm with `--write-movie` frames.
- **Draw cost:** drawn tetrahedra per frame, `cull_usec` against instance count, script-time monitors (not frame time, and never in a screenshot frame), VRAM against unique meshes.
- **Volume view:** fixed-camera Projected and Combined captures per preset, with and without echo projections; compare screen coverage and judge by eye.
- **Banding:** turned-slice captures at 10/20/30° for each distribution.
- **Determinism:** move one authored tree; only its echoes should change.
- **Collision:** walk through spun-part box corners at 45° slice turns; walk in W to wrap and repeat copies.
