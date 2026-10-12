# PathCreator: how the paths work

The direction-path system for 4D: routes and destinations drawn on the floor as flat vector
symbols, from Ramon's Figma sheet "Path_Indicator" (Creation Lab, Aligned Layout file, page 5:20).
Built 5 to 6 Oct 2026. It runs in the PathCreator lab (`pathcreator.tscn`) and in the chicken pen
(`chickenpen/playable_world.tscn`, node `World/Paths`).

Also here: `PLAN.md` (the 90-step build plan), `CASE_STUDY.md` (what was tried and measured). Every
script's header explains its own part in more depth; this file is the map.

## The idea in one paragraph

A room's paths are a **graph** saved as a `.tres`: nodes (starts, bends, junctions, destinations)
with a 4D position each, and edges between them. A **network** node (`graph/path_network_4d.gd`)
reads the graph and lays it on the floor: every edge is one thin flat 4D box along its chord, every
node one small square box, all drawn by one shader that draws the Figma's own symbol outlines (no
4D meshes of arrows). Arrows repeat by distance along a whole route, so they run on unbroken
through bends. Everything is laid when the graph changes, never per frame, and moving a node
re-lays only what touches it.

## Where things are

| Path | What it is |
|---|---|
| `graph/path_graph.gd` | The graph resource: nodes, edges, `routes()`, `validate()` (the sheet's rule 10) |
| `graph/path_network_4d.gd` | The network node: lays a graph on the floor, all the behaviours below |
| `path_spec.gd` | Every number from the sheet (sizes, spacings, clearances, colours, timings). Nothing else types one |
| `render/path_mark.gdshader` | The symbols: each pixel's distance to the sheet's vector outlines, sharp at any distance |
| `render/path_sand.gdshader` | The sand strip under a path: soft wavering edge fading into the ground, no seams |
| `render/path_draw.gd`, `path_svg.gd`, `path_symbols.gd` | Boxes, reading the SVG masters, packing them for the shader |
| `sets/06`, `sets/07` | Symbol libraries (the sheet's sets), SVG masters per slot |
| `builder/pc_builder.gd` | The in-game builder (F4 in the lab): edit graphs from above while playing |
| `pathcreator.tscn`, `pathcreator_4d.gd` | The lab: a white walkplane, targets at different W, the networks |
| `graphs/*.tres` | The lab's graphs. The pen's is `PenLayout/paths/pen_b.tres` (written by `PenLayout/scripts/_make_pen_paths_b_runner.gd`) |
| `scripts/_*_runner.gd` | Tests and captures (below) |

## The graph

**Nodes**, each a Dictionary:

| Field | Meaning |
|---|---|
| `id` | unique number |
| `kind` | `start` (where you come in), `chord` (a small ball on a curve), `bend` (a turn's ball and ring), `junction` (a choice), `destination` (a place to arrive and act) |
| `pos` | Vector4: x, y (0 on the floor), z, **and its W** |
| `band` | how deep in W its symbol is, metres (wide: seen from far off in W) |
| `state` | a destination's: `arrival`, `available`, `focused`, `completed` (the sheet's symbols D, E, F, G; E and F animate) |
| `target` | name of the object it is for (under the network's `targets`); its frame goes round that object's footprint |
| `frame` | `none`, `rect`, `round` (symbols H, I), open toward `approach` |
| `approach` | Vector2 (x, z): the side you arrive from |
| `anchor` | true: the destination follows its target object as it moves (a chicken, a cart) |
| `curve`, `curve_r`, `corner` | on a rounded corner's chords: which curve, its radius, the sharp corner it replaced |

**Edges**, each a Dictionary:

| Field | Meaning |
|---|---|
| `from`, `to` | node ids; arrows point from -> to |
| `priority` | `primary` or `secondary` (smaller chevron, symbol B; narrower sand) |
| `w_mode` | how it lies in W: see the next section |
| `band` | how deep in W it is when not static, metres (default 1.2) |

A **route** is a run of edges from a start, junction or destination to the next; `routes()` works
them out, and arrows are spaced along each route as a whole.

## Paths through W: the four modes

Each **edge** has its own `w_mode`, so one route can mix them:

| Mode | Where the stretch lies in W | Use |
|---|---|---|
| `static` | the floor's whole W depth | readable from any W |
| `here` | at its **from**-node's W, `band` deep | a path that belongs to one slice |
| `follow` | slanting from its from-node's W to its to-node's: the box is sheared through W along its length, so the slice cuts a stretch that slides along as you walk | leading the player through W |
| `reveal` | only at its **to**-node's W | a way you find by stepping into the destination's slice |

In the pen today (`pen_b.tres`, 17 nodes): the roads `here` at W 0; the camp's last stretch `follow`,
down to the camp's W (-2.5); the cave's road `follow` up to the door's W (3) and then a short `here`
stretch lying flat at it; a `secondary` branch to the balloon.

### Laying a route through W (what the pen taught, 7 Oct)

- **Land flat.** A `follow` stretch that runs all the way into its destination arrives on a slant: you
  meet the circle short of its W, and the slanted road leads the eye past what you came for. End the
  climb a few metres short (a `chord`) and lie the last stretch `here` at the destination's W.
- **Narrow the destination's band** (1.2 instead of 2.4) when its W matters: the circle then shows only
  when you are within 0.6 m of the right slice, so seeing it means you are there.
- **Pick the W by looking.** The right W for a place is where it reads best, not always its middle:
  the cave's arch stands tallest a metre kata of its centre (`chickenpen/look/_cave_w_sweep_runner.gd`
  renders a place at a row of W for a contact sheet).
- **Side ways are `secondary`**: a narrower chevron and sand, so the main road still reads first.
- **Anchor to a spot, never to a thing that moves away**: the balloon's circle is anchored to its
  mooring; anchored to the balloon, it would chase the balloon into the sky.

Node symbols have their own `band`, at their own W. A node whose incoming and outgoing stretches
lie at different W shows a small W cue (dots: warm for ana, cool for kata) so you can see that the
way goes on through W.

The network's `w_mode_override` ("" or a mode) lays **every** edge one way without changing the
graph, to compare the modes over a whole layout. The pen switches it with 9 (below).

## The rules from the sheet, as built

- **Arc length** (rule 01): arrows repeat by distance along the whole route, turned to each chord.
- **Keep clear** (rule 03): marks stop short of every node by its art's radius + 0.25P and slide under
  that edge as they flow (`clear_style` "hide"), or stop at the clearance ("keep").
- **Short stretches** (B1): a chord too short for a mark and both clearances carries only the guide line.
- **Crossings** (rule 05): where two routes cross without a node, the weaker one's marks break.
- **Priority** (rule 06) belongs to the route.
- **States** (rule 07): arrival still; available, an arc turning once in 6 s; focused, cyan; completed, a tick.
- **Blocked** (rule 09, `hide_blocked`): a route with a static box across it hides until the way opens.
- **Acceptance** (rule 10): `validate()` and `notes()` report overlaps, routes through objects,
  unreachable arrivals; `scripts/_proof_runner.gd` checks the camera-dependent parts.

P is the player's ground diameter, 0.6 m; one sheet unit is 0.015 m. `p_scale` scales everything the
sheet gives in P (the pen uses 1.4).

## The network's settings (`graph/path_network_4d.gd` exports)

**What it draws**
- `graph`: the graph resource. `targets` (+ `targets_deep`): where the destinations' objects are.
- `look`: `dev` (the sheet's colours, emitted) or `walk` (one sand colour, lit like paint).
- `show_marks`, `show_sand`: the symbols and the sand strip, separately. `sand_width`, `sand_patch`:
  the strip's width, and how much wider the round patches at nodes and destinations are.
- `libraries`, `default_library`: which symbol set each slot (A to J) comes from, slot by slot.
- `under_color`: the floor colour the symbols' antialiased edges blend into.
- `floor_swatch` (9 Oct): on a lab floor, its LabKit swatch (`"kit_floor"`); `under_color` then follows
  that swatch's surface colour, so the marks stay blue into black when a room switches to its black
  palette (with the grey floor's colour fixed, every mark had a thin light rim). Empty by default: the
  pen sets its own colour.
- `frame_tint` (9 Oct, from the Voxel Lab: "change the UI lines surrounding the large central pedestal
  to blue"): the frames round objects (the rectangle and the round one) in one colour instead of the
  sheet's; its alpha is how much. Clear (the default) keeps the sheet's colours.
- `motion`, `flow`: arrows flowing along the route, and how fast (m/s).
- `clear_style`: `hide` or `keep` (above). `p_scale`: size.

**Reveal: found as you go** (not the same as the `reveal` W mode)
- `reveal`: on, a stretch shows only once you have been within `reveal_radius` of it (W counts as
  distance too), fades in over `reveal_fade` and stays found; a route leaving a found node shows its
  first `reveal_tease` metres, so you see a way goes on. Off: every route shows all the time.
- `reveal_from`: whose nearness counts (the player). `reset_reveal()` forgets what was found.

**Ground**
- `drape`: routes lie on whatever static box is under them (a ray down at each node, and along each
  edge every 0.2 m), climbing a step as a run on the lower box and a run on the upper. Physics is
  boxes only, so a step is the only bend ground can have. `drape_mask`: the layers it stands on.
- `set_ground({...})`: the ground's colours, so the sand's soft edge fades into the real green (the
  pen hands it the grass's glow).

**Other**
- `hide_blocked` (rule 09). `w_mode_override` (above).

## The builder (in the lab, F4)

A top view over where you were, the live slice, every graph drawn over it: nodes coloured by W (blue
kata, white at W 0, warm ana), each one's W band as a halo. You edit the graph files the scene loaded,
and the paths on the floor follow as you drag.

- Mouse: left picks and drags a node; wheel zooms (over a node: its W; with Shift: its band); middle or
  right drag pans; the W lane at the bottom drags a node through W.
- N new node joined from the picked one (1 to 5 its kind) · X split a route with a chord · C join ·
  Del remove · K kind · S state · F frame · R round a corner (again: wider 2, 4, 7 m, then sharp)
- **P** the hovered route's priority · **M** its W mode (static, here, follow, reveal)
- L the next library for one symbol · [ ] the slice through W · G snap 0.25 m · Ctrl+Z / Ctrl+Y
- T walk from here · Ctrl+S save every graph · F4 back to walking

The lab's own keys: F4 builder, F5 the next library for every slot, F6 the look (DEV / WALK), F7
volume view; 9 the paths' type and Shift+9 found as you go, as in the pen (below); number keys take you
to its places.

## In the editor's volume view

The marks only draw in the slice. In the editor's volume view (Projected, or Combined) each stretch is a
plain box as deep in W as its type makes it, coloured by that type so you can see its W shape: **static**
cyan, **here** yellow, **follow** magenta, **reveal** red; nodes, their sand patches, W cues and frames
white. Editor only: playing, the volume view keeps the sand colour. To see W as a direction on screen,
turn the camera into W (Ctrl while orbiting) or use Layout → Preset: Ground View, whose two lower views
put W up the screen. A scene open before this change shows the colours once it is reopened.
**Volume view solidity** (`editor_volume_solidity`, on the network, default 200) makes the paths read
solid there instead of drowned by the deep ground: in the editor their volume view draws with the engine's
own shader plus one opacity setting (render/path_draw.gd `volume_shader()`). 1 is the engine's own look.
Nothing extra is drawn for it.

## In the pen

- `World/Paths`: the network, graph `PenLayout/paths/pen_b.tres`, draped, `p_scale` 1.4, sand 1.8 m.
- `Systems/Paths` (`chickenpen/scripts/pen_paths_4d.gd`), the player's switches, on the controls card
  (H) and in the **Paths** row of the left-hand panel:
  - **9** goes round the type like Tab goes round the cameras: as drawn, then every stretch static,
    here, follow, reveal (`w_mode_override`).
  - **Shift+9**: found as you go, or every path shown (`reveal`).
  - Both remembered in `user://pen_settings.cfg`.
- The look follows the world's (`chickenpen/look/pen_look_4d.gd`, key I): sand strips in the art; in
  the dev look the arrows alone on the dev floor, no strips.
- The paths window (`chickenpen/scripts/pen_paths_panel_4d.gd`): the same two switches as buttons, with
  a line saying what the lit type does, stacked on the look panel.
- With the projection on (P), the paths are left out of it (`lookout/lookout_4d.gd projection_leaves_out`):
  their static stretches are 30 m deep in W and ghosted as a sheet of sand colour.
- `PenLayout/scripts/_make_pen_paths_b_runner.gd` builds the pen's graph (layout A's was
  `_make_pen_paths_runner.gd`, `pen_a.tres`); `_verify_journey_b_runner.gd` walks it.

## Tests and captures

`scripts/_proof_runner.gd` (rule 10 at the player camera), `_probe_*` (symbols, colours, draping
through W, places), `_capture_*` (builder, curves, looks, the yard, the W field, tilted slices). Run
them with `CreationLab/scripts/lab_run.sh windowed <name> res://ramon/CreationLab/PathCreator/scripts/<runner>.gd`.

## Things to know

- No `class_name` anywhere (the engine's class cache breaks on them here): `preload` the scripts.
- The editor's F5 to F8 (Run, Run Current, Pause, Stop) also act while the game window has focus, so
  the pen's switches are not on F-keys.
- A symbol box is a flat 4D box with the shader; twelve on screen cost about 0.1 ms. The sand's soft
  edge writes depth pushed back by how near its strip's edge a pixel is, so overlapping strips never
  show a seam at the joints.
- In the editor there may be no physics to ask, so draped routes lie at y 0 there.
