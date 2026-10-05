# The pen's hills, the cave in the hill, and the range — 28 Sept 2026

Phases D–G of the 70-step pen plan, plus Ramon's notes given while it was being
built, plus his thirteen notes from the evening of the 28th (at the end). Everything
here is committed locally on `RamonPrototypes` and **not pushed**.

## Try it

- **The hills** are everywhere you look, including with the slice turned into W.
- **The cave.** Back and to the right of the pen there is a round hill with a
  half-sunk arch in a dark grey rock face. Walk in and keep walking: the screen
  goes dark as you go, and you arrive in the cave in the black. **V** goes
  straight in and out (a debug key, like **C** is for the theatre).
- **Inside**: down the corridor to the chamber. **F** at Hale, the miner in the
  spacesuit. Walk up to the researchers. Find the laptop on their table. Take the
  pickaxe (**1**) to the cube on the plinth and see what they do. Walk back toward
  the daylight behind where you arrived: the screen goes white and you step out
  into the mouth of the cave, facing the field.
- **The range** is beside Trym's shed. Stand at the counter: the camera comes over
  your shoulder, and **left click** shoots the boards down the range. **F** at the
  range master, *Show me*, and you are in `shooting_gallery_ramon.tscn`. **H**
  there says *BACK TO THE CHICKEN PEN* and brings you home with everything as you
  left it. Opened from the menu, the gallery still says *BACK TO MENU*.

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
| Ruins pedestal, the voxel block as a 2001 monolith | First a black slab; since the evening notes, the pen's original voxel cube again (see below), on a three-tier plinth among broken columns. It mines and has the gold seam. |
| Spacesuit miner talking voxel benchmarks with mystery | Hale. Every number he gives was measured the same day (see below), and the mystery is what the numbers do. |
| Three researchers in white measuring; crates, tools | A surveyor at a tripod, one kneeling at the plinth taking samples, one with a tablet; tables, instruments, cases, crates, a generator. |
| "Delicate equipment, please don't touch"; they don't know where it came from | Up close and calm they address you; overheard, they talk about an artifact with no quarry, no tool marks, nothing to date. |
| Researchers panic when you mine it; won't encourage you | Every blow sets all three off - they turn to you, hands up, shouting across the chamber. From then on they mutter about you. |
| "Afterwards … hitting it was bad but we got more data" | Up close after a blow: grudging, and quoting the slab's live collider count and the blows they logged. |
| The professor outside knows something is off | He sends you to the hole, uneasy about what they found there: a cube on a plinth older than the hill, on a lattice nobody laid. (His first version, about an 8 carried in and a 10 on the plinth, was confusing - note 12 below.) |
| Range booth, rustic, near-black wood, guns, boards, show only | A covered firing line in near-black timber by the shed: rifle rack, rifles and tins on the counter, target boards spread through z and w, a sandbag berm. Since note 8, the boards can be shot. |
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
| Hill ring, first version ("Classic") | 61,440 tetrahedra, bakes in 0.7 s |
| Voronoi mountains | 92,160 tetrahedra in 13 layers (about 113 MB of video memory, 36 MB more than Classic), bakes in 2.4 s |
| Cave hill | 80,919 tetrahedra, bakes in 8.2 s |
| Cave (walls, floor, props, the start of the way through W) | 81,951 tetrahedra, bakes in 9.5 s (65,313 before the way through W) |
| The far room and the tunnel to it (`cave_far.res`, its own mesh) | 61,126 tetrahedra, bakes in 7.5 s |
| Cave frame, with the far room | **1.32 ms** mean (756 fps), p99 2.28 - against 0.96 before it |
| Video memory in the cave, pen resident | **549 MB** in the chamber, with the pen's mountains and cave hill let go (`pen_scenery_release_4d.gd`); 756 MB in the tunnel by the way out, where they are kept; 828 MB with the far room streamed in. An empty window is 70 MB and the pen alone 645-655 MB, about 376 MB of it the 4D meshes (308,000 tetrahedra, 56% of them in those two) |
| The cube on the plinth | 8⁴ = 4,096 points at 0.8 m; 6,000 tetrahedra whole, 6,480 after five blows; 544 surface colliders whole, 522 after five blows; **184–208 ms a blow** |
| The slab it replaced | 10⁴ = 10,000 points at 0.66 m; 1,368 tetrahedra whole; 63 colliders; 172 ms a blow (its "363 after five blows" counted colliders already queued for freeing) |
| Pen frame, from the spawn point | **2.69 ms** mean (371 fps), p99 3.82 - against 2.60 before the hills and 2.46 this morning |
| Cave frame, at the chamber's mouth | **0.96 ms** mean, p99 1.43 |
| Video memory | **475 MB** in the pen (280 before the hills); **626 MB** in the cave, with the pen still resident |

Frame times from `_measure_pen_frame_runner.gd` (windowed, 1280×720, vsync off; `cave=1` for
the cave). Drawing the new scenery is close to free; what it costs is video memory. The frame
and memory figures are from before the evening notes and were not re-measured after them.

## Traps found (the first three are in `engine_gotchas.md`; 7-9 are from the evening)

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
   The cave and range runners count drawn frames. Anything on a clock (the fade, the
   boards) has to be waited for in seconds: headless frames are far shorter than real ones.
7. **The cross-section shader's colour coordinates go partly through an 8-bit slot.**
   The engine packs the four corners' texture coordinates into whatever vertex slots
   are free (`tetra_mesh_4d.cpp`, `append_proxy_mesh_surfaces_3d`): the fourth corner's,
   and the first corner's third component, go in the vertex COLOR, which Godot stores
   at 8 bits. Colour coded linearly into that loses 40% of a dark rock's value in one
   step, and because a vertex is a different corner in each tetrahedron it sits in,
   every tetrahedron came out its own shade - the "pattern" in the cave mouth's
   gradient. Fixed for every baked mesh by coding the coordinate as sRGB, with a
   32-texel half-float colour cube that turns it back into linear light
   (`terrain_bake_4d.gd`). Anyone putting colour through a Texture3D onto dark
   surfaces will meet this.
8. **A dual-contour grid centred on w = 0 draws nothing on a surface that barely
   changes along W**: its vertices sit exactly on the slice, and a slice through a
   tetrahedron's vertices has no area. The cave hill's grid is shifted a third of a
   cell off w = 0.
9. **`Camera4D.world_to_viewport` answers in window pixels**, not canvas units. The
   same until the window's content is scaled; then every tag and head-anchored
   dialogue box is off by the scale. `world_tag_4d.gd` and `dialogue_box_4d.gd` convert.

## Not done, and why

- **Engine voxel world (step 36), probed, not adopted.** `VoxelWorld4D` on the module's
  main (`_probe_voxel_world_runner.gd`): its built-in test torus streams in in 0.64 s as 256
  chunk meshes; a radius-2 carve applies in 0.25 ms and the next frame costs about 25 ms
  more than the ones either side of it - roughly seven times cheaper than a blow on our
  GDScript slab, and only in the chunks it touches. It cannot be used here yet: the
  generator is hard-coded (`VoxelData4D()`: "Temporary: hard-coded test data") and
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

## Ramon's thirteen notes (28 Sept, evening)

| # | Note | What is there now |
|---|---|---|
| 1, 2 | The cave hole's gradient has a pattern; broken gaps in the cave mesh | The pattern was the 8-bit colour slot (trap 7), fixed for every baked mesh; the gradient into the dark is smooth. The gaps were the degenerate slice (trap 8). |
| 3 | Walking into the hole is like walking into a wall; enter in darkness, then teleport | The tunnel runs 11 m into the hill, darkening, and the screen fades to black with depth (from 3 m in, black by 8.4 m). The crossing fires in the black, which clears in the cave's own dark tunnel over 1.2 s. Walking out, the screen whitens toward the daylight, the way home fires in the white, and it clears on the field with you in the mouth of the cave. By position, not by timer: stop and it stops, turn back and it lifts (`pen_cave_fade_4d.gd`). |
| 4 | The original voxel cube back; it should cut in round bits | The pen's own 8⁴ cube at 0.8 m on the plinth; the pickaxe takes a round bite about two metres across. Hale's and the researchers' numbers are re-measured for it. |
| 5 | A glowing laptop in the cave, somewhere you can find it; the same in the theatre near Trym's booth | On the researchers' table left of the plinth, lit; and on a stand beside the theatre's podium, facing the seats. Nothing else in the theatre was touched. |
| 6 | Gold, or a mysterious 4D ore? | Waiting on Ramon. Recommended: a glowing 4D crystal in place of the gold, the loop unchanged. |
| 7 | Nike smaller; her legs stand still and move at once | Two-thirds the size. The legs: the rigid-piece skin gave body vertices near the hip a share of the leg; weights are now all-or-nothing within reach. |
| 8 | Very basic range functionality | At the counter the camera comes over your shoulder, a sight appears, and left click fires down it. A hit tips the board over backwards for 2.5 s; bull's-eyes are called; a tally sits under the sight. Boards on another slice cannot be hit until you turn to them (`pen_range_shooting_4d.gd`). |
| 9 | UI text and elements bigger, except the dial | Everything 1.3× at 1080 lines, following the window's height and never smaller than before; the dial held at exactly its old size (`pen_ui_scale_4d.gd`). Off in the theatre and in the gallery. The camera-test panel moves beside the controls card when hanging under it would cover the dial. |
| 10 | Remove the CHICKENS and RANGE signs | Gone. |
| 11 | Mountains block the sky; size variation; "what do you use voronoi for the seed?"; keep the old ones; parameters | The first range used no Voronoi: it was ridged simplex noise on direction, one continuous wall. The new one is Voronoi throughout: each cell on the sphere of directions (W included) is one mountain's seed; its random cell value says whether it has a mountain and how tall; F2 - F1 brings it down to a saddle at the cell's border. Three bands in the one radial mesh: a green rim at 115 m, a middle range at 240 m, snow-capped peaks at 450 m, with sky between (`terrain/pen_peaks_4d.gd`). Every number is a parameter on World/Hills with a **Bake** button (`terrain/pen_mountains_4d.gd`); **Style** switches back to the first version, kept as it was (`baked/hills.res`). |
| 12 | The professor's "carried an 8 in" story is confusing; the monolith should be a discovery | Rewritten: they found a cube in the hill, on a plinth older than the hill, on a lattice nobody laid. |
| 13 | A better main character | Waiting on Ramon: three directions proposed, "the cartographer" recommended, to be built as a switchable alternative. |
| - | The corridor planks in the cave | Removed; the rest as it was. |

### And the round after

| Note | What is there now |
|---|---|
| The top-left card grows when prompts come in; distracting | A fixed size: room for eight rows at a fixed width, rows packed from the top as before and empty space left under them. With more than eight up at once the debug readouts make way first; a line too long is cut with an ellipsis (`pen_info_card_4d.gd`). |
| UI too big; a UI size slider | The scale is a plain percentage now (on a 4K screen the old rule came to 2.6x): 125% by default, set with a slider at the foot of the controls card, kept in `user://pen_settings.cfg`. |
| The hole on the left of the cave arch | A slit cut by the bake's own re-winding in the crease where rock meets turf; re-winding is off. And the height under the contoured block is cut back further, so its last cells no longer dip below where the block begins. |
| The laptop washes out in the light | On the table at the back now, with its own light a touch stronger. |
| The cube hovers over the plinth | It stood 0.40 m up (measured: lowest surface 1.90, plinth top 1.50); lowered with its gold, it now sits at exactly 1.50. |
| An opening you only see turning W, with a glowing fill you can pass through | A passage out of the chamber's wall in +w beside the plinth, filled with a pale glowing sheet that has no collider. All of it past w = 6, so the slice you arrive in is unchanged; turn the slice through W from anywhere by the plinth and it swings into view. Walking along +w from the chamber takes you through the sheet (`_capture_way_through_w_runner.gd`). |
| On the map, so you can align to it and find it; the cube too | The dial draws landmarks - anything in the group `slice_dial_landmark` - on a stem to their own w with a rung where your slice passes and a ring when it goes through them: the way through W as an archway, the cube as a cube. In the cave the dial centres on the chamber (`slice_dial_anchor`) instead of on the pen a kilometre off. |
| "A tunnel to another big room"; worried about memory | Its own scene, `cave/cave_far.tscn`, streamed: `cave_far_stream_4d.gd` loads it on a worker thread - its mesh made drawable there too - as soon as you turn the slice through W or step off w = 0, and frees it after 3 s back on the flat slice or when you leave the cave. No jump at the sheet: you still walk straight through. Measured: 756 MB without it, 828 MB with it; in 0.4 s from the start of the turn; the longest frame while it comes in 17 ms (141 ms before the build was moved off the main thread). Twenty metres of tunnel along W to a round hall as big as the chamber at w = 36, with a ring of six standing stones spread through x, z and W, lit by lamps with no fittings (the cave's 4D lights only reach a few metres, so each stone has its own). |

### The dreamer, and the round with it

| Note | What is there now |
|---|---|
| An abstract Azathoth-like being in the far room you can talk to: limbs in all dimensions, a vibrant core, blue when calm and red in warning | The dreamer (`cave/cave_dreamer_4d.gd`, its lines in `cave_dreamer_script.gd`, F to talk). A flat ring of a mouth, hung high, that slowly turns to face you in your own slice, two rows of teeth pointing in, a vortex of streaks inside it and only there, sinking back to a burning heart; two dozen thin metallic-grey limbs trailing behind, through W as well. Its warning lines (`"do": "warn"`) and crowding it turn it red and make it move faster. |
| Rigid, then lofted, tentacles | Both: one tapered segment and one cone are lofted once; every limb, lip, tooth and streak is one of those two meshes stretched into place, so nothing is skinned or rebuilt and the meshes' memory is paid once. Every piece is three times thicker through the slice's normal than across it: a thin tube in 4D crosses your slice only within its radius and was mostly invisible. |
| The cube is offset to the right | Its surface sits half a lattice cell off its node in every axis; the node is moved so the cube's middle is the plinth's, to a millimetre. |
| "Wow, what's this" on first seeing the chamber | Said once through the player's thought box as the corridor opens into it (`cave_first_look_4d.gd`). |
| The laptop's light is too bright | Its lamp down from 1.6 to 0.45 and in to 1.6 m. |
| The doorway's mark too high on the dial; "way through W" reads oddly | "anomalous reading", a larger beating dot with an exclamation mark; in the cave the dial's W scale is its own (`dial_w_fraction` on the anchor), so it stands half as high. |
| Walking through the arch, the camera goes through it a second time | The sheet parts as you or the camera reach it and closes only when both of you are back in the chamber (`cave_w_sheet_4d.gd`); a faint glowing line on the tunnel's floor leads on to the far room. |

**Chirality** needs a different solution (the signs were its test case); left until
Aaron's fence update lands.

### The dreamer speaks, and wakes you (28 Sept, late)

| Note | What is there now |
|---|---|
| Keep how it talks; only a small part of its intelligence is conscious and talking, the rest a mystery even to that part; it is the dreamer, the dream and every incarnation, the player too. Cross-reference Azathoth, don't copy my words | `cave_dreamer_script.gd` rewritten from the lore: the blind god at the centre, lulled by pipes and drums, whose waking ends the dream. What speaks is "a sliver of me that happens to be awake"; the music is a lullaby that keeps it under; you are "one of the ways I have of looking at myself". A third menu ("Something darker") holds who you are to it, what if it woke, and whether it could end all this. |
| It could destroy all dreams, goes red, you're scared, "did that scare you? wasn't intended as such" | `topic_end` warns (red); your "(You take a step back.)" and the first line of `end_after` keep it red - `"do_on_line": 0` holds the calm until "Did that frighten you? It was not meant to" has been said - then blue again. |
| Leaving: a flash, you're on the floor in front of the cave, shake your head, stand up | Its goodbye carries `"do": "leave_dream"`; when the talk closes, the pen's `Systems/DreamWake` (`scripts/pen_dream_wake_4d.gd`) flashes to white, carries you home by the cave's own crossing at the peak, lays you on your back 4.5 m out from the arch facing it, sits you up with a shake of the head, stands you, and you think "...What was that?". The HUD is held back until the white is up. |
| The whole creature twice as big | `creature_scale` 2 on the two nodes the frame turns - everything, the heart's light included, grows together. The mouth hangs at 11 m. Every limb point is kept inside the room's ellipsoid and above its floor, so limbs lie along walls rather than through them. |
| ...so the room grows | Half as big again (radii 28/22/28/22) and moved out to w 46, so the way through W is still a fifteen-metre walk; its grid is coarser (3.6 m cells) so it costs about what it did: 135k tetrahedra against 97k. Everything placed in it moved with it. Scenery is not read back while you are out along W. |
| Tentacles can't be longer because they slice in and out of W? | Yes: a limb only shows where it crosses your slice, and the ones set off through W leave it within a few metres; extra length mostly goes where you cannot see it. Keeping them nearer the slice is the only way to show more of them. |
| F starts a cinematic: fixed spot, no W dial, close-ups, side shot, mouth insides, your face, a slow pan for scale | `cave/cave_dreamer_cinema_4d.gd`. F stands you on `DreamerMark` (10 m in front, at its w), flattens and locks the slice, puts the whole HUD away and letterboxes. A camera of the far room's own cuts between eight shots, chosen per line in `SHOTS`: a slow left-to-right pan from behind you (scale), straight down its throat pushing in (teeth, swirl, heart), a slower push for threats, a low angle from under it, a side profile, a three-quarter close-up of you, a low over-your-left-shoulder shot while you choose (replies hang down the left), and a rise from behind you as it lets you go. A soft light in its heart's colour rides above you so the close-ups read - blue, then red on your step back. |
| A "skip cutscene" button that it refuses - "I won't let you skip, player, I dream you at your desk too" | Four seconds in, the top bar offers "Skip cutscene   Esc" (Escape ends every other conversation, so it is the key a player reaches for). Pressed, it breaks in (`DialoguePlayer4D.interrupt`, new, and `escape_leaves = false` on its player): a red "No.", the bars close in, and in a dead-still stare into its mouth it talks past your avatar to you - the chair, the finger on Escape, the real time on your clock, "the light on your face right now is mine", "there is no outside of a dream to skip to" - then "So. Where were we." and the conversation carries on at the exact line it was on. The offer stays struck through, on this visit and every later one; pressing again gets "Still no.", then shorter still. Escape never reaches the rig while it plays, so it cannot free the mouse or quit; "I'll go" is the way out. |
| Dust off the middle of the mouth, rising; a subtle up-and-down | 44 motes of 3.5 cm rise up its face over 7 s and fade; it breathes 0.35 m over 11 s with a one-degree nod. |

Test: `scripts/_verify_dreamer_runner.gd` (22 checks, now through the threat and the
waking) and `scripts/_capture_dreamer_cinema_runner.gd` (plays the scene through and saves a
frame of every shot, `cine_*.png`, plus 18 checks on the staging and the refused skip). `_verify_talk_runner.gd` was already stale before this (it looks for `UI/Radar`, long gone).

### Ramon's list, 29 Sept

| Note | What is there now |
|---|---|
| No gold in the lattice: a purple ore tied to Azathoth that the white suits study | **Azoth** (the alchemists' first matter). Violet 4D crystals in the rock (`pen_rock_gold_4d.gd`, file and node keep their names), the belt item `found_azoth` with a crystal icon and its count always shown. The professor, Hale, the keeper and Mithra talk about it; the dreamer calls it where it "held a dream too tightly. A drop of me, gone hard." |
| The laptops glow less | Cave: screen colour down to a blue-grey in the bake, its light 0.45 to 0.28. Cinema: the same screen colour, light 1.0 to 0.4. |
| The cinema laptop next to the stage and booth, on the chairs' side, further off, turned 90 degrees, near Trym after the show | On its own stand at (-7.9, 0, 1.2): past the podium on the flank of the seating, clear of the seats and the backdrop, screen facing out. Trym's after-show reach is 3 m (was 6), so from the laptop he is out of range. |
| Laptops open Menu2 (with its toggle to the Frontier Map); Escape asks "back to the pen?"; all three laptops; a tucked-in return button | `pen_laptop_4d.gd` at Trym's desk, the cave table and the cinema stand; `pen_laptop_trip_4d.gd` parks the whole pen the way the range trip does. Escape asks only after the menus have had it; Enter is yes, Escape no. "ESC  RETURN TO THE PEN" sits in the menus' top bar, placed from `menu_banner.gd`'s own numbers. No menu script was changed. |
| People talking must not clash with laptops: a laptop only takes F when no NPC could talk | Every conversation joins group `npc_talk`; a laptop asks each whether it could start and yields if so, and to a chicken in reach or in your arms. Trym's desk laptop is his while he sits at it. |
| In the cave, names too close to their icons; "the cube" should be "Artifact"; "anomalous reading" a space further right | Names now stand off by the icon's own size and a space (`_icon_clearance`); the cube's dial label is "Artifact". |
| The view wedge on the dial: narrower than 90 degrees, a red gradient instead of lines and fill | 0.76 of the lens's real sweep (about 69 degrees), red fading from you to its edge in five rings, no outline. |
| F for the dreamer from a distance, saying talk | "F talk" hangs on a spot 4.5 m up, not 11 m; reach 16 m and 7.5 through W; it fades out only past 22 m. |
| The dreamer's talk more like a film; "Are you Azathoth?"; a drop of the ore when you wake | A CINEMA layout in `dialogue_box_4d.gd` (no box, centred, off-white at 80%, soft shadow, on the lower bar, your lines in italics, replies a quiet list on the left). "Are you Azathoth?" takes the place of "What are you?" once asked (a node's new `"sets"` key raises the flag). Waking puts one azoth in your belt, every time. |
| Press 1 to mine at the Artifact without the pickaxe in hand | `cave_mine_prompt_4d.gd`: "Press N to mine" over it within 4.5 m, N the pickaxe's own slot, only with the pickaxe on the belt and not in hand. |
| The range: pick up a gun to shoot; different signs in 4D; the range master still sends you on | The first click at the counter takes a rifle off it and into your hands (then clicks shoot, and you face your aim); it goes back when you leave. Every board has a letter on one side of its rings through W and a red glyph on the other; read left to right the letters spell AZOTH. The range master is unchanged. |
| The mountains a little bigger | Rim, medium and far bands 12% taller (27 / 84 / 213 m), rebaked. |
| No em dashes in the dreamer's lines | Taken out, and out of the new lines for the others. |
| After a laptop, the cave came back browner and without its HUD; fix it for the pen and cinema laptops too; keep what was collected and mined | Two things outlived the menu. Menu2 sets the window's scaling (canvas items, 1920x1080) and went borderless fullscreen, so the HUD came back laid out for the wrong canvas; the trip now saves the window and puts it back, and Menu2 leaves the window's mode alone when a laptop opened it (the one change to the menus). And the pen, the cave and the cinema each have a WorldEnvironment4D marked current, so putting the pen back let the field's warm evening win in the cave; the trip notes the environment really in use and makes it current again. Belt, mined rock and what was dug out were always kept (the pen is parked, not freed); the test now proves it for all three laptops, 53 checks. |
| + and - for the UI size; then a small vertical control with no slider; and with Shift, one for the dial's size | No slider now: the size, and beside it a small plus over a minus, 10% a press, 50-300%. Now simply two key rows at the foot of the card, in its own grammar and with no buttons: "+ / -   135%  UI size" and under it "Shift + / -   100%  dial size", the number first in a column kept for the widest. 10% a press; the dial (50-200%, saved as `dial_percent`) grows up and left from its corner. |
| Plus and minus did nothing; the red wedge too red; Yes or No in the menu; "wow, I sense something" in the second cave; still no F for the dreamer, and from further; subtitles a little higher | The + and - keys (main row or numpad; Shift for the dial) now do what the buttons show, and the buttons no longer overlap each other (a Button is never shorter than its text). The wedge starts at 0.32 and falls off as (1-t)^2.6. The question's buttons are Yes and No. Coming into the far room along W: "Wow... and I sense something." (`cave_first_look_4d.gd` can trigger on W now). The dreamer's F: a prompt hid itself by raw w, and walking to it along W is all w - `world_tag_4d.gd` now measures off-slice along the camera's own slice normal (the same answer on the flat slice), and the dreamer's reach is one distance in (x, z, w). Subtitles hang just under the top of the lower bar. |

Tests: `_verify_laptop_runner.gd` (16 checks), `_verify_range_shooting_runner.gd` (now 27, with the rifle and the signs), `_verify_dreamer_runner.gd` (24, with the drop of azoth), `_capture_dreamer_cinema_runner.gd` (19, now through "Are you Azathoth?"). `_verify_hud_runner.gd` still expects the top-left card to size itself to its text, which it has not done since it was fixed in size on 28 Sept.

## For Aaron

`engine/modules/4d/nodes/node_4d.cpp`, `Node4D::set_global_position`:
`node_4d_parent->get_transform().xform_inv(...)` should be
`node_4d_parent->get_global_transform().xform_inv(...)`. Only wrong when the parent
has an offset parent of its own; the basis, transform and rotation setters are fine.
(Since fixed upstream, 0cd7372 - not yet pulled here.) And, FYI: the tetrahedron proxy's
12 vertices a tetrahedron (6 of them culled in the shader) is where all the video memory of
big static meshes goes.

And trap 7: in `append_proxy_mesh_surfaces_3d`, `uvw4` and `uvw1.z` go through
`set_color`, which Godot keeps at 8 bits, while the other ten texture coordinates are
floats. Any slot that stays float would fix it at the source; until then, colour coded as
sRGB is the workaround.
