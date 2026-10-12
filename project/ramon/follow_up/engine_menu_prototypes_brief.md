# Quantum Horizon — the engine, the two menus, and the prototypes

Context file for an outside reader (e.g. ChatGPT). Written 2026-09-18 against the
`RamonPrototypes` branch. Everything below was read off the repository or the running
project on that date, except where marked *reported* — those come from working notes
and should be treated as claims, not facts.

Quantum Horizon is an R&D programme at IO Research asking whether four-dimensional
space works as a **game** platform. A gate on **16 October 2026** decides whether to
fund a 2027 preproduction year, rescope, or stop. All three outcomes are live.

---

## 1. Repository layout

Three engine layers and two separate Godot projects.

| Path | What it is |
| --- | --- |
| `engine/godot/` | Submodule: a fork of Godot Engine (`godot-dimensions/godot`) |
| `engine/modules/4d/` | Submodule: **Godot 4D** (`godot-dimensions/godot-4d`) — a general-purpose, open-source C++ engine module adding 4D types to Godot. Shared well beyond this project; maintained by Aaron |
| `engine/modules/quantum_horizon/` | This project's **own** C++ module (not a submodule) |
| `project/` | The actual game project — GDScript, scenes, assets. Where the day-to-day work happens |
| `workhorse/` | A second, independent Godot project (own `project.godot`) used as a 4D content/tooling workhorse — mesh and heightmap conversion scripts |

**The `quantum_horizon` module is currently scaffold only** — it contains an
`ExampleNode` and the registration boilerplate, nothing more. Its README states the
admission rule: code belongs there only when it is *both* performance-critical *and*
not general-purpose 4D code. General 4D features belong in `4d`; if performance does
not demand C++, GDScript is preferred. In practice essentially all gameplay work is
GDScript, which matters for the developer-experience argument below.

Prerequisites are Git LFS, Python + SCons, and a C++ toolchain. `run_editor_windows.bat`
(and `.command` / `.sh` equivalents) updates submodules, builds the engine, then opens
the editor.

---

## 2. What Godot 4D adds

Godot 4D creates a **parallel 4D scene graph** alongside Godot's normal 2D/3D one. It
does not retrofit 4D onto 3D nodes.

| Type | Role |
| --- | --- |
| `Node4D` | Transform and parenting |
| `Camera4D` | Projects 4D → 2D |
| `CollisionObject4D` / `CollisionShape4D` / `Shape4D` | Physics bodies and shapes |
| `PhysicsServer4D` | The physics server |
| `MeshInstance4D` / `Mesh4D` | Tetrahedral and wireframe meshes |
| `Area4D` | Detection volumes |

A 4D transform's basis is a **`Projection`** — a Godot core type — whose `.x` / `.y` /
`.z` / `.w` members *are* the basis columns directly. No `get_column()` needed.

### The two planes of rotation

This is the single most important conceptual point, and the one non-specialists miss.

- **`zx`** behaves like ordinary 3D yaw. **`yz`** is pitch.
- **`w`** is the fourth axis — "ana/kata". Rotating into a `w`-plane (**`xw`**, **`zw`**)
  is **slice rotation**: it changes *which 3D cross-section of the 4D world you are
  currently seeing*, not merely which way you face within it.

Helpers are `Basis4D.from_zx`, `from_yz`, `from_xw`, `from_zw`.

So: the player always sees a 3D cross-section. Moving along `w`, or rotating into a
`w`-plane, changes which slice that is — and therefore which walls, floors and gaps
exist right now. A wall can be present at `w = 0` and simply absent at `w = -6`,
with nothing else about the world having changed.

### Raycasting

4D raycasts go through `RaycastParameters4D` + `PhysicsServer4D.raycast_physics_objects()`.
**`Area4D` is detection-only and is not hit by raycasts** unless `collide_with_areas = true`
is set explicitly — a trap that has cost real debugging time.

---

## 3. The player controller — the canonical composition example

`project/player/player.gd`, documented at length in `project/player/CONTROLLER_NOTES.md`.
Worth understanding because it shows how the two rotation planes are kept from
contaminating each other.

- **Yaw** (`Basis4D.from_zx`) and **slice rotation** (`from_xw` / `from_zw`, applied
  while a `rotate_4d` input is held) are applied directly to the `CharacterBody4D`
  root's own basis.
- **Pitch** (`Basis4D.from_yz`) is applied only to a child `Node4D` called `PlayerHead`,
  and as an **absolute clamped set** rather than an incremental multiply — so it cannot
  drift and cannot leak into movement or turning maths.
- Every frame the body's basis is forced back to `y = Vector4(0,1,0,0)` and
  re-orthonormalised (`Basis4D.orthonormalized`) to guard against float drift from
  repeated rotation composition.

**Consequence that bites:** any code needing "which way should the player turn or
slice-rotate" — bearing maths, POI arrows, minimaps — **must read the `Player` body's
own `global_position` / `global_basis`, never the camera or head chain.** Pitch lives on
`PlayerHead` and would silently leak vertical look angle into what should be a
horizontal-only quantity. `project/scripts/bearing_utility_4d.gd` is the shared
implementation and documents the specific bug this fixed.

---

## 4. Two front doors onto the same work

There are two menu screens, deliberately answering different questions, and they read
from **one** shared catalogue so neither can drift into claiming a prototype the other
does not have.

| Scene | Question it answers |
| --- | --- |
| `project/ramon/Menu2.tscn` — *Explore Freely* | *What can I play?* |
| `project/ramon/FrontierMap.tscn` — *Frontier Map* | *What is this programme, and what has it proved?* |

(`project/ramon/Menu.tscn` is the earlier mockup of the same idea. Note that
`project.godot`'s `run/main_scene` currently points at `ramon/Model/rigged_creature.tscn`
— that is a transient working state from creature-rig work, not the intended entry
point.)

### 4a. The menu itself

- **One node, everything generated.** The `.tscn` is a bare `Control` plus a script;
  roughly sixty widgets are built at runtime and never given an `owner`, so nothing
  serialises into the scene file. If you open it expecting clickable nodes, you will
  not find them — the knobs live in two resources instead.
- **`style/default_style.tres`** (`MenuStyle`) — type is a **modular scale**
  (`base_font_size × type_ratio^step`), one `spacing_unit`, the palette, per-corner
  preview radii.
- **`entries/catalogue.tres`** (`MenuCatalogue` of `MenuEntry`) — the nine prototypes,
  every on-screen string, and **array order is the tour order** for both screens.
- Layout: a hero *START THE TOUR* over a banner list; the detail pane shows a looping
  clip, title and maturity badge, key caps, and three fixed info cells
  (**question / approach / finding**).
- **Clips are recorded, not screen-grabbed.** `Menu/_capture_clip.gd` drives the real
  prototype through a per-prototype choreography table; ffmpeg encodes to `.ogv` into
  `thumbs/`. Drop any `<clip>.ogv` there and it plays.
- Launching runs the prototype as a child of the tree **root** with the menu hidden
  beneath, so Escape unwinds losslessly.
- *START THE TOUR* currently shows a COMING SOON notice — sequencing is not built, and
  both screens agree about that on purpose.

### 4b. The Frontier Map

Built 2026-09-04. Its framework vocabulary — *frontier*, *fog*, node states — comes
from Hoskinson's *Gravity Products* paper. Fully documented in
`project/ramon/Menu/FRONTIER_MAP.md`; the four load-bearing rules are:

1. **Order is the catalogue's, not the map's.** The overview route follows
   `catalogue.tres` array order. A proposed separate `tour_index` was dropped, because a
   second ordering the menu's Move up / Move down buttons cannot see is drift waiting to
   happen.
2. **The curve is rhythm, not logic.** On the overview, every edge joins two prototypes
   adjacent in the catalogue and nothing else. No branching, no dependencies, no meaning
   in a curve's height. This is *printed under the map*, because a reader who assumes the
   shape encodes dependencies misreads the whole screen.
3. **An edge takes the colour of the category it leads into**, so the hue changes on the
   edge crossing into a new kind of proof. An edge is **dashed** when it arrives at
   anything not built-and-playable — a dashed hop is a claim about direction, not a
   report of somewhere you can stand.
4. **Nothing unenterable offers a button.** Fog nodes take no focus and no clicks. An
   `UPCOMING` node shows `NOT BUILT YET` instead of `LAUNCH`.

**Interaction:** press selects, drag pulls, double-click launches. Dragging a node pulls
it with tension (55% of mouse travel, capped at 26 reference px) and route neighbours
follow at 0.34 and 0.12 — measured *along the route*, not by screen distance, because
the line is the relationship. A press never launches, so grabbing a node cannot start a
two-minute prototype by accident.

**Colour policy:** grounds and type are fully desaturated; nothing that carries meaning
is. Category hues, route edges, state rings, the gold gate badge and the blue action
buttons stay as authored. If it is coloured, it is telling you which kind of proof,
which state, or which action.

**Node states** (legend, in order): `PLAYED`, `ACTIVE`, `AVAILABLE`, `RESEARCH`,
`LATER / FOG`, plus a separate `GATE ESSENTIAL` badge.

**Node kinds:** `PROTOTYPE`, `GATEWAY`, `PLANNING` — only activation differs (launch a
scene, open a sub-map, or inspect only). Gateways are nodes, not a separate class, and
the overview's route skips them so they never become stages of the tour.

**Placements are authored in a 1920×1080 reference space**, read off the reference art,
then scaled uniformly and centred into the window. Forty nodes and thirty edges of
hand-written `.tres` is a lot of places to fat-finger a coordinate, so the layouts are
generated by `entries/_build_maps.py`.

**Adding a node is two edits meaning different things.** *It exists* → add a `MenuEntry`
to `catalogue.tres`. *It belongs here* → add a `FrontierEntry` to a layout with a
`reference_position`, a category and a state. A placement matching nothing in the
catalogue is **not an error** — it is a node for work that does not exist yet, which is
most of why the screen exists.

#### Sub-maps — four maps, one scene

| Map | Resource |
| --- | --- |
| Overview (home) | `entries/frontier_layout.tres` |
| **October Gate** | `entries/map_october_gate.tres` |
| Open-Source + Game-Jam | `entries/map_open_source.tres` |
| 2027 Frontier | `entries/map_2027_frontier.tres` |

Sub-maps **name every edge explicitly**, because there a line means *this work plausibly
enables that work*, which no ordering can express. Escape order is strict: close drawer
→ leave sub-map → leave the map.

#### The honesty rule, made visual

`FrontierEdge.estimated` draws a line **dashed and dimmed**. The dependency graph is a
planning hypothesis until Aaron and Andrew validate it, and a solid line would quietly
promote a guess into a claim.

#### The October Gate sub-map, specifically

11 placements, 12 edges, of which **four are marked `estimated`**. Three category bands:
**LIVE ARTIFACT** → **GATE EVIDENCE** → **DECISION PACK**.

Nodes: Voxel Core · Surfacing Modes · Materials + Scatter · **Nevada Terrain** ·
In-Place Regen · Perf + World Scale · Gate Evidence · 2027 Roadmap · Open-Source Plan ·
RFP Draft · October Gate.

The screen carries a caveat pill reading `ESTIMATED · ENGINEER VALIDATION REQUIRED`, and
a route caption distinguishing the two kinds of line: *technical edges show estimated
prerequisites; decision-pack edges show required inputs, not engine dependencies.*

**Nevada Terrain is the instructive node.** It is `state = 3` (research/upcoming),
`gate_essential = true`, subtitled *PROCEDURAL PROOF*, tagged `GATE ESSENTIAL` /
`VOXEL CORE` / `KILL-CONDITION PROOF`, and its action label reads **`NOT BUILT YET`**.
Its detail text: *"Demonstrates usable 4D terrain generated from seeds and parameters
rather than bespoke construction… Its output feeds the S1–S3 evidence package; the exact
dependencies still need Aaron and Andrew to validate."* It is deliberately **not** in
`catalogue.tres`, so it never appears in the menu as an unlaunchable row.

#### What is deliberately absent

No voting, conviction staking, contribution nodes, contributor names, unlock economies,
persistent profiles, backend accounts, or a dependency graph generated from Notion. The
map and the fog are on-framework; the governance machinery is not. The contextual
drawer's contribution data is entirely invented and says so on its own face via
`FrontierActivity.illustrative`.

---

## 5. The nine prototypes

Read verbatim from `project/ramon/Menu/entries/catalogue.tres`. Array order is the tour
order. Each entry carries a **question**, an **approach**, a **finding** and a
**benchmark** — the menu renders these, so the deck and the artifact quote the same
source.

**1. Slice Vision** — `ramon/MiegakureLook/levels/level_1_wall.tscn` — *Playable*
- Q: Can anyone read a 4D scene at all without training?
- A: Third-person diorama, discrete 90° turns, floor banded along `w`.
- F: **Banding is load-bearing; an unbanded rotated view is a blank diamond.**
- B: 10 / 10 scripted checks pass · 3 levels · 90° turn eased over 0.7 s

**2. Phase Maze** — `ramon/PhaseMaze/phase_maze.tscn` — *Playable*
- Q: Does rotation work as a navigation verb rather than a camera trick?
- A: Maze walls occupy `w`-bands; rotating changes which ones are solid.
- F: It reads immediately, but only where the route is signposted.
- B: 2 levels · walls 0.4 m thick in `z` · slice rotation on right mouse

**3. 4D Ascent** — `ramon/ObstacleCourse/w_gap.tscn` — *Greybox*
- Q: Can a vertical course stay legible once the slice can change?
- A: Bounded tower, tier-coloured back wall as the only HUD.
- F: **Physics is axis-aligned boxes only: no ramps, every rise is a step.**
- B: Gap 7 m vs 4.59 m jump reach — uncrossable until `w` changes

**4. Portal** — `ramon/Portal/portal_test_1.tscn`
- Q: Does Portal's momentum-preserving link survive four dimensions?
- A: Chunked voxel walls cut anywhere; two apertures carrying position, orientation and velocity.
- F: Both hold: cuts merge cumulatively, and crossings accelerate 7.7 → 22.2 m/s.
- B: 40.5 ms per chunk rebuild · 10,752 tetrahedra · 7.7 → 22.2 m/s over five crossings

**5. Quantum Range** — `ramon/ShootingGalleryRamon/shooting_gallery_ramon.tscn` — *Playable*
- Q: What does aiming mean when a target can leave your slice?
- A: Real 4D raycasts against 4D collision, independent of the camera.
- F: **You can miss in a direction you cannot see — and it reads as fair.**
- B: True 4D raycasts against 4D colliders, independent of the camera

**6. Voxel Mining** — `ramon/VoxelMining/voxel_mining_final_2.tscn`
- Q: Can 4D matter be destroyed at interactive rates?
- A: Persistent voxel field, dual contoured, re-meshed per hit.
- F: Yes: about 130 ms per carve at room scale, around 58 fps.
- B: ~130 ms per carve at room scale · ~58 fps · 10,752 tetrahedra

**7. Shrubbery Lab** — `sandbox/shrubbery/shrubbery_lab.tscn`
- Q: Does procedural growth still read as botanical once it grows in 4D?
- A: Space colonisation in 4D, rendered with the combined cross-section plus projection engine.
- F: One tree carries the projected pass comfortably where a whole forest turns it to soup.
- B: 1 tree · combined renderer · plane sharpness 0.2, skewness 0.35

**8. Sky Box Clouds** — `ramon/SkyBoxClouds/skybox_clouds.tscn`
- Q: Can weather be a real 4D solid rather than a painted backdrop?
- A: Noise over `x`, `z` and `w` seeds clumps of stretched polytopes, detailed on their own surfaces.
- F: **Coverage varies along `w`, so rotating the slice moves you into different weather.**
- B: 24-cell (96 tets) as the workhorse, 600-cell for hero puffs · three-level clump hierarchy

**9. Motion Lab** — `sandbox/limb_prototype/limb_prototype_treadmill.tscn`
- Q: Can a creature animate convincingly with no baked clips at all?
- A: FABRIK limbs, a gait state machine, hip suspension and spine IK, solved per tick.
- F: **Limb count and proportions fall out of parameters, so a new creature needs no rig.**
- B: 5 gaits · limbs and segments per limb changed live · per-foot ground raycast

> **Caveat on maturity labels:** only four of the nine currently have a `maturity` value
> set (three `Playable`, one `Greybox`). The rest are blank, so any claim of the form
> "N prototypes are playable" cannot be sourced from this file today.

---

## 6. The Creature Modeller — the tool, not one of the nine

`project/ramon/Model/`. It is **not** in `catalogue.tres` and is not a prototype: it is
the authoring tool that makes content *for* the prototypes. Nine prototypes plus one
tool is the "ten" that appears in some copy.

It builds 4D models by **lofting**: the artist places "balls" (cross-sections) in the
scene and everything between them is generated. Scripts: `loft_rig_4d.gd` (the rig),
`loft_ball_4d.gd` (a ball), `loft_builder_4d.gd` (shared geometry).

**Ten exported parameters per ball**, read off `loft_ball_4d.gd`: `radius`, `v_scale`,
`w_scale`, `starts_branch`, `symmetry_type`, `symmetry_count`, `mirror_branch`, `roll`,
`squareness`, `color`. That is a finite, named parameter set rather than code — which is
the point being made about it.

Working features: chains from scene-tree order, branching by parenting, bilateral
mirroring with a choosable axis, per-branch detach, spine-aligned sections, live rebuild,
ellipse sections, per-ball colour, and three self-checks (watertight, winding,
fold-through).

**Scale is 1 unit = 0.25 m.** Three bodies exist: a chicken (0.51 m), a goat (1.15 m) and
a brachiosaurus (10.2 m) — a twenty-fold range from one rig. The goat is the reference
build: *one rig, ten chains, one mesh*.

The tool prints a structural self-check about its own output, visible in the status bar:

```
[Loft] Watertight: all 1760 faces shared by exactly 2 tetrahedra.
```

**Traps, all *reported* from working notes rather than re-verified today:**

- **Ellipse axes turn with the spine.** `v_scale` and `w_scale` are named for the
  *unaligned* frame. With `align_to_spine` on, the frame is rebuilt perpendicular to the
  local spine direction — so for a body running along `z`, it is `w_scale` that stretches
  *vertically* and `v_scale` that stretches through `w`. The opposite of what the names
  suggest. Measure before using them on a new axis.
- **Slivers.** A tetrahedron flat in *shape* fails the inverse-metric computation, and
  the cache is then discarded wholesale, so raycast picking returns false for every ray
  and the editor drops the node — the model cannot be clicked, only selected from the
  Scene tree. **Drawing and physics are unaffected** (weapons go through
  `PhysicsServer4D`, not the mesh). Cause: long spans relative to section width. The
  brachiosaurus spine is reported never to clear this by resolution alone.
- **Smooth shading is impossible from GDScript.** The cross-section shader computes each
  normal from the sliced triangle and never reads the mesh's stored normals, so the
  faceted look is structural, not a setting. Raised with Aaron.
- **Joints overlap rather than fuse** — the brachiosaurus is six shells, not one.

---

## 7. Known engine limits worth knowing up front

- **4D physics is axis-aligned boxes only.** No ramps; every rise is a step. This shaped
  4D Ascent's whole design.
- **`Area4D` is not hit by raycasts** unless `collide_with_areas = true`.
- **Headless has no framebuffer** — any capture or screenshot script must run *windowed*,
  with the editor closed. `--headless` renders nothing.
- **New `class_name` scripts need one editor-mode scan** before anything referencing them
  will parse; otherwise you get a wall of "Could not find type" errors that look like
  real bugs.
- **Godot bundles Ogg Theora only.** MP4 playback needs a GDExtension, which is why menu
  clips are `.ogv`.
- **`Input.action_press()` only feeds polled reads** — it never reaches `_input`, so
  event-driven verbs never fire from script. Use `InputEventAction` through
  `Input.parse_input_event()`.
- **A sub-resource's `changed` signal does not bubble** to the resource holding it.
- `.tscn` files that are hand-edited or generated should be re-saved from the editor to
  normalise UIDs and property order — but note the resave script rewrites every scene in
  the project, so single-file edits are better hand-verified.
- Key bindings differ by branch: `rotate_4d` and `fire` are swapped between `main` and
  the shooting-gallery branch, as a `project.godot` `[input]`-only change.

---

## 8. Evidence discipline

This matters for reading any claim above. The programme's own framing is that it must
prove **four** things about 4D as a game platform: *it can run, it can be understood, it
can create worthwhile gameplay, and it can be developed at a sustainable rate.*

The honest current position:

- **Developer experience** is the best-evidenced: nine prototypes and the authoring tool,
  built by a designer rather than an engine programmer — with AI assistance and bounded,
  logged developer help, which is a stated confound rather than a hidden one.
- **Engine performance** has three provisional thresholds defined (S1 sustained frame
  rate, S2 world scale against a 4D Miner baseline, S3 in-place procedural regeneration)
  and **none of them measured**. Instrumentation exists and prints live readouts; runs
  against the thresholds do not.
- **Player comprehension** has one prior study on an *earlier* build (N=7, May–June 2026,
  with substantial caveats: a predisposed-favourable cohort, zero non-gamers, and a form
  bug that voided most responses to its most valuable question) and **no naive-player data
  at all** on any of the nine current Godot prototypes.
- **Worthwhile gameplay** has the nine prototypes and no external play.

Documentation caveat that applies throughout: `project/player/CONTROLLER_NOTES.md`,
`FRONTIER_MAP.md` and the module READMEs are historical and explanatory. Verify against
the actual `.gd` / `.tscn` source before relying on them for exact current behaviour,
especially on feature branches.

---

## 9. Vocabulary

| Term | Meaning |
| --- | --- |
| **`w`** | The fourth spatial axis. A coordinate like `x`, `y`, `z` — not a mode or a toggle |
| **Slice** | The 3D cross-section of the 4D world currently visible |
| **Slice rotation** | Rotating into a `w`-plane (`xw` / `zw`), which changes *which* slice you see |
| **Ana / kata** | The two directions along `w`, by analogy with up/down |
| **Fog** | Frontier Map state for work that is planned but not begun |
| **Gate essential** | Frontier Map badge: this node's output is required by the October gate |
| **Estimated** | A dashed, dimmed map edge — a planning hypothesis, not a validated dependency |
| **Tetrahedral mesh** | The 4D mesh primitive; a 4D solid is built from tetrahedra as a 3D one is from triangles |
| **S1 / S2 / S3** | The three provisional engine success thresholds: stability, world scale, procedural regeneration |
