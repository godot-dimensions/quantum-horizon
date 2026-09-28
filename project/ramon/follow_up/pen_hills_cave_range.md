# The pen's hills, the cave in the hill, and the range — 28 Sept 2026

Phases D–G of the 70-step pen plan, plus Ramon's notes given while it was being
built. Everything here is committed locally on `RamonPrototypes` and **not pushed**.

## Try it

- **The hills** are everywhere you look, including with the slice turned into W.
- **The cave.** Back and to the right of the pen there is a round hill with a
  half-sunk arch in a dark grey rock face. Walk in and keep walking into the dark;
  at the back of the tunnel you arrive in the cave. **V** goes straight in and out
  (a debug key, like **C** is for the theatre).
- **Inside**: down the lit corridor to the chamber. **F** at Hale, the miner in
  the spacesuit. Walk up to the researchers. Take the pickaxe (**1**) to the
  monolith and see what they do. The daylight behind where you arrived is the way
  out; you come home in the mouth of the cave, facing the field.
- **The range** is beside Trym's shed. **F** at the range master, *Show me*, and
  you are in `shooting_gallery_ramon.tscn`. **H** there says *BACK TO THE CHICKEN
  PEN* and brings you home with everything as you left it. Opened from the menu,
  the gallery still says *BACK TO MENU*.

## What was asked, and what it became

| Ramon's note | What is there |
|---|---|
| Background hills and mountains, "around and in W" | A baked ring of foothills and mountains over the whole (x, z, w) sphere from 50 m to 600 m out (`terrain/pen_hills_4d.gd`). Turn the slice and there is still a skyline. |
| Cave entrance: a 4D shape with a hole, faked darkness | A hill whose mouth is a dual-contoured block: the tunnel is round in (x, w) and tall in y, so it is still a hole with the slice turned. The dark is painted on - 4D vertex occlusion plus colour falling to black with depth. |
| "Bigger and epic, not a sewer pipe … half a circle sitting in the ground" | The arch is 7.2 m wide and 5 m tall, centred on the ground line, cut into a rock face at the hill's foot; you walk straight in off the field. |
| "Dark grey, not terracotta; the hillside round the entrance bigger" | Cool dark grey stone (the evening sun warms neutral grey to terracotta); a turf shoulder wraps over and beside the rock frame and runs down to the field. |
| Entering transports to a new cave scene | `cave/cave.tscn`, opened by the pen's own crossing. **The pen's own player walks in** - same belt, pickaxe and dialogue system - so gold dug there comes home. |
| Readable darkness, dungeon-like but natural, high ceiling, moody excavation lights | The theatre's recipe underground: a black sky, a faint key, coloured lamps. Walls fade to black as they rise, so the chamber has a ceiling you cannot see. |
| Walk a bit to the site, symmetry framing, wow moment | A rough tunnel, then a straight excavated corridor lit by rings of work lights in x **and** w, opening on the plinth dead centre with the monolith on it. |
| Ruins pedestal, the voxel block as a 2001 monolith | The pen's voxel rock, stood on end as a black slab (`cave/cave_monolith_block.gd`) on a three-tier plinth among broken columns. It still mines and still has the gold seam. |
| Spacesuit miner talking voxel benchmarks with mystery | Hale. Every number he gives was measured the same day (see below), and the mystery is what the numbers do. |
| Three researchers in white measuring; crates, tools | A surveyor at a tripod, one kneeling at the plinth taking samples, one with a tablet; tables, instruments, cases, crates, a generator. |
| "Delicate equipment, please don't touch"; they don't know where it came from | Up close and calm they address you; overheard, they talk about an artifact with no quarry, no tool marks, nothing to date. |
| Researchers panic when you mine it; won't encourage you | Every blow sets all three off - they turn to you, hands up, shouting across the chamber. From then on they mutter about you. |
| "Afterwards … hitting it was bad but we got more data" | Up close after a blow: grudging, and quoting the slab's live collider count and the blows they logged. |
| The professor outside knows something is off | He sends you to the hole and is uneasy: an 8-lattice rock was carried in, and what stands on the plinth is a 10. Both true. |
| Range booth, rustic, near-black wood, guns, boards, show only | A covered firing line in near-black timber by the shed: rifle rack, rifles and tins on the counter, target boards spread through z and w, a sandbag berm. |
| F → "you look like you got some experience…" → the real range | The range master, ear defenders round his neck, with that line. |
| The range needs a way back | H in the gallery, relabelled only when you came from the pen. |

## How it is built

**One offline bake tool** (`terrain/terrain_bake_4d.gd`): a height front end (a
grid over (x, z, w) lifted to y = h), a density front end (the voxel port's dual
contouring), and a box front end - all ending in one `ArrayTetraMesh4D` with a
colour per vertex, saved as `.res` and loaded like any mesh. Run
`_bake_terrain_runner.gd -- what=hills | cave_hill | cave` after changing a recipe.

**Per-vertex colour through a 2×2×2 texture.** The cross-section shader never reads
the engine's per-vertex colour arrays - only a `Texture3D` at a UVW on each corner.
So each vertex's UVW *is* its colour and the texture is the eight-texel colour cube;
linear filtering makes that exact.

**4D vertex occlusion**: the surface-nets trick one dimension up - the solid
fraction of the 3⁴ = 81 points round each vertex, darkening creases and hollows.

**The hill ring is a cube-sphere in three dimensions**: six faces of N×N directions
times radial layers, every cell cut into five tetrahedra. N must be even, or the
two faces meeting at a cube edge disagree about which diagonal to cut and the
surface cracks there.

**The cave's walls** are two dual-contoured grids, stretched per axis and sized to
the narrow tunnel and the big chamber; both contour the same air, so they cover
each other's edges. The floor is a flat height; the props are merged boxes.

**Keeping you in the cave without wall colliders**: physics here is boxes only, so
the same density the walls were baked from pushes you back into the air past a
margin, and the orbit camera marches its ray through it (a new optional
`clearance_provider` hook on `pen_orbit_rig_4d.gd`; null in the pen).

**The range trip parks the pen.** The gallery cannot be opened beside the field the
way the cave is (its root is a Control and its world sits at the origin), so the
pen's root is taken out of the tree and held, the gallery becomes the current scene,
and coming back puts the very same pen back. The way home is left as metadata on the
tree root for the gallery's new `range_way_home_ramon.gd` to find; neither side
preloads the other. `sandbox/shooting_gallery/shooting_gallery.tscn` is untouched.

## Numbers (measured 28 Sept 2026, this machine)

| | |
|---|---|
| Hill ring | 61,440 tetrahedra, bakes in 0.7 s |
| Cave hill | 55,431 tetrahedra |
| Cave (walls, floor, props) | 67,033 tetrahedra, bakes in 4.9 s |
| Monolith | 10⁴ = 10,000 points at 0.66 m; 1,368 tetrahedra whole; 63 surface colliders, 363 after five blows; **172 ms a blow** |
| The pen's old rock, same test | 8⁴ = 4,096 points, 544 colliders, **184–209 ms a blow** - slower than the slab with 2.4× the points, because rebuilding colliders costs more than contouring |
| Pen frame, from the spawn point | **2.69 ms** mean (371 fps), p99 3.82 - against 2.60 before the hills and 2.46 this morning |
| Cave frame, at the chamber's mouth | **0.96 ms** mean, p99 1.43 |
| Video memory | **475 MB** in the pen (280 before the hills); **626 MB** in the cave, with the pen still resident |

Frame times from `_measure_pen_frame_runner.gd` (windowed, 1280×720, vsync off; `cave=1` for
the cave). Drawing the new scenery is close to free; what it costs is video memory.

## Traps found (the first three are in `engine_gotchas.md`)

1. **`Node4D.global_position = x` is wrong two levels below an offset node** - it
   converts through the parent's local transform. A nugget in the cave (hung 1 km
   along x) landed a kilometre further on. Worked round; one-word engine fix below.
2. **The cross-section renderer ignores per-vertex colour** (see above).
3. **Every tetrahedron is ~1.25 KB of video memory** (12 proxy vertices × 104 B).
   The first hill ring cost 0.04 ms a frame and 229 MB.
4. **Dual-contour vertex normals already point outward.** Negating them made every
   slope read as vertical and browned the hillside.
5. **A post with its own thin W depth at a W corner is off the home slice.** The
   booth's roof floated until the posts ran the booth's whole W depth - and a second
   set, running the whole X depth at the W corners, stands for a turned slice.
6. **Tests that wait in physics ticks are flaky headless**: a slow frame catches up
   several ticks in a row, before any `_process` has seen the move being waited on.
   The cave and range runners count drawn frames.

## Not done, and why

- **Engine voxel world (step 36), probed, not adopted.** `VoxelWorld4D` on the module's
  main (`_probe_voxel_world_runner.gd`): its built-in test torus streams in in 0.64 s as 256
  chunk meshes; a radius-2 carve applies in 0.25 ms and the next frame costs about 25 ms
  more than the ones either side of it - roughly seven times cheaper than a blow on our
  GDScript slab, and only in the chunks it touches. It cannot be used here yet: the
  generator is hard-coded (`VoxelData()`: "Temporary: hard-coded test data") and
  `set_generator` is not bound to scripts, so nothing of ours can be generated in it. And
  the torus alone is 890,880 tetrahedra - over a gigabyte of video memory at 1.25 KB each.
  Worth revisiting when generators are bindable.
- **Boids (step 67)** - optional, not started.
- **The pen fence** waits for Aaron's procedural fence.
- **Terraces (step 34)** were built, then replaced by Ramon's half-sunk arch.
- **The cave's hum** is the farm's own music slowed to 0.52× - checked to play,
  not yet listened to by a person.
- **The red cat** draws (3,080 tetrahedra, `_verify_no_rebuilds_runner`), but no capture
  framed it inside Trym's shed, so it has not been looked at in a frame.
- **Nothing is pushed.** That is Ramon's call.

## The full test pass (step 69)

All 86 `_verify_*` runners were run headless. Everything new passes: cave (26 checks),
range (12), gold, pickaxe, professor, quests, no-rebuilds, and the dialogue graph check
for every character. Two regressions from earlier today were found and fixed:

- **`_verify_catch_runner`**: the test teleported the player through Nike - three times the
  size since this morning - dragging the carried chicken into her side. In play the player
  collides with her too; the test's path now runs away from her.
- **The checklist stayed on screen during conversations**, under the dialogue box. All six
  pen conversations now hide it.

Nine runners fail **identically on the commit before today's work** (`5b95059`) or on this
morning's head (checked in a separate worktree), so none is from this work: comprehension,
dial, hidden_dials (nodes removed in `494b844`), loft_cost (`set_variation` missing on the
goat), mithra (a windowed-only frame save, run headless), presenter (0.32 m off his mark),
ring (expects more than nine chickens), talk, trym (three checks on standing up). Two more
report a verdict rather than failing: agent ("NEVER REACTED", a standalone chicken test)
and planted_feet ("FEET SLIP by 0.089", which Ramon has said is fine).

## For Aaron

`engine/modules/4d/nodes/node_4d.cpp`, `Node4D::set_global_position`:
`node_4d_parent->get_transform().xform_inv(...)` should be
`node_4d_parent->get_global_transform().xform_inv(...)`. Only wrong when the parent
has an offset parent of its own; the basis, transform and rotation setters are fine.
And, FYI: the tetrahedron proxy's 12 vertices a tetrahedron (6 of them culled in the
shader) is where all the video memory of big static meshes goes.
