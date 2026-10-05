# PathCreator: case study

A path system for 4D: a graph of routes and destinations from Ramon's Figma sheet, symbols drawn
as vectors on the floor, routes that reach into W, and a builder to lay them out while playing.
The plan is in `PLAN.md`; this page collects what was learned building it, in order, with the
pictures (`img/`).

## 0. Starting point (5 Oct 2026)

- **The sheet:** Figma "Path_Indicator", seven symbol libraries sharing one routing contract, a
  46 × 30 m field map with real footprints. Library 07 (Futuristic Stencil) is built first, and
  every symbol slot can later come from a different library.
- **The old path system** (`CreationLab/kit/kit_path_4d.gd`, 4 Oct) drew marks along Catmull-Rom
  strips through W.
  - **What it taught:** uniform arrays are shared by every material in this engine, so per-path
    data must go in textures or plain uniforms. Discard-only strips work. Curved strips bend the
    arrows (Ramon: keep them rigid).
- **Ramon's answers:**
  - library 07 first
  - F4 builds, F5 cycles looks, F6 flips DEV and WALK
  - one beige for the sand look
  - the W range is my call: ±15 m, see `path_spec.gd` W_REACH

## 1. Probes (steps 3 to 8)

| Probe | What it showed |
|---|---|
| **Vectors in the shader** | Library 07's nine masters read as SVG, flattened and packed in 3.5 ms: 1,018 segments, 23 shapes, 9 symbols. The shader measures each pixel's distance to the Figma's own outlines, so every symbol is sharp up close and from far away (`img/01_lib07_states.png`). Twelve symbol boxes on screen cost 0.1 ms a frame. |
| **Layers found by difference** | What E and F draw that D does not is the moving arc and the focus accent. The arc turns in the shader; F's arc and diamond come out cyan, as on the sheet. |
| **W per pixel** | `local_pos.w` reaches the fragment stage, so a mark knows where it is inside its box's W band. |
| **A W-sheared box** | It cuts as a slanted band. A 10 m route climbing from W −2 to +2, 0.8 m deep in W, shows a 2 m window that slides along it as the slice moves (`img/02_w_probes.png`). This is the "follow" mode, for free. |
| **The band's edge** | Thinning the outlines made the chevrons vanish too early and looked like cuts. The marks now shrink to a quarter, then go: they recede into W. |
| **Colour** | Lit marks on a sunlit floor washed out to sky blue. In the DEV look the marks are now emitted at the token colour. At gain 1.0 the sheet blue #1761d7 comes out #166bca and the edge grey #668bae comes out #7196b2; the cyan loses a little to the tone map (`img/03_colour_calibration.png`). |
| **The light** | With the Creation Lab's light carried over, a white floor reads light blue-grey (#b7c6dc), as the lab's floors do: the room's blue ambient. Faithful to the lab, not pure white. |
| **Keys** | F4 to F7 are bound nowhere in the project or the walker. |

## 2. The yard: the field map rebuilt (steps 10 to 52)

- **The graph:** the B1 field map, node for node, measured off the sheet's export (40 px a metre),
  as `graphs/yard.tres`.
  - 20 nodes and 19 edges: the entry, the equal choice, the turns, the curved survey approach of
    four chords, five destinations in their states, with frames round their objects.
  - 45 floor boxes; 0.1 ms a frame with the whole yard on screen (`img/04_yard_top.png`).
- **Sizes from the field map, not the masters:**
  - The map's junction is 0.39 m across against the master's 0.24 m, so junctions are drawn at
    1.6×.
  - The bend ring is 0.39 m and the balls are 0.16 m.
  - The secondary guide is dotted, as the map draws it.
- **Where marks end:**
  - Marks stopping 0.25P short of a node looked cut, half arrows in empty floor.
  - The default is now "hide": marks run up to the node's art and slide under it as they flow
    (Ramon's hide-under technique, the art being what they hide under).
  - "keep" (the sheet's 0.25P) stays as an option (`img/05_yard_close.png`).

## 3. Routes through W (steps 53 to 66)

Five stations, each a route from W 0 to its own blue cube at W +4. From above at W 0 to 4
(`img/07_w_stations.png`, stations across, W down):

| Station | What you see |
|---|---|
| **A static** | The route, its ring and its bracket at every W; the cube only at W +4. The way and the frame, without the thing. |
| **B here** | The whole route at W 0, nothing between, the arrival and the cube at W +4. |
| **C follow** | The visible stretch slides along the route from W 0 to 4: the route unrolls toward its cube. The sheared box does this on its own. |
| **D reveal** | Only the start at W 0; at W +4 the whole route and the cube. |
| **E ladder** | One leg per metre of W: walk a leg, walk ana, the next leg appears. |

## 4. The builder (steps 67 to 79)

F4 in the running space:
- A camera straight down, still the live slice.
- Every node over it, coloured by its W (blue kata, white at 0, warm ana).
- Off-slice nodes and objects dimmed, and a W lane for the picked route (`img/08_builder.png`).

A scripted session through its own mouse and key handling passes every check:
- drag a node, N to add one, the wheel for W, X to split, M for W mode
- undo, redo, save and read back, the slice through W
- F4 back to walking

It edits the same `.tres` files the scene loads.

## 5. The symbols against an independent renderer (step 35)

Every master was rasterised by Godot's own SVG renderer at 4 px a sheet unit and laid against our
shader's drawing of it, measured as overlap of the inked pixels (`scripts/_probe_overlay_runner.gd`,
`img/10_overlay_check.png`). The first pass found four things wrong, all in how strokes were
read; after the fixes every symbol of libraries 06 and 07 scores 0.92 or better, most 0.97-0.99:

| Found | Fix |
|---|---|
| Strokes drawn with round ends (the junction's arcs too long, 0.67) | Flat (butt) caps: each open run carries the half-planes at its two ends, cutting every one of its segments, so flattened curves are cut square too. |
| Sharp joins rounded (the secondary chevron's tip, 0.89) | Miter wedges added as fills of the stroke's colour. |
| Dashes ignored (the round frame's four gaps, 0.82) | `stroke-dasharray` cuts the stroke into dashes. |
| A floor-coloured fill painted over its own stroke (06's hollow junction, 0.30) | A path's fill before its stroke, as SVG does; a "floor" colour role that paints the floor's albedo. |

## 6. Looks and sets (steps 38, 39)

F5 moves every slot to the next library; in the builder, L moves only the slot under the hand (a
picked node's symbol, or the hovered route's chevron), Ramon's "toggle sub-icons separately". F6
flips DEV and WALK (`img/09_looks.png`: 07, 06, A from 06 with the rest from 07, WALK).
