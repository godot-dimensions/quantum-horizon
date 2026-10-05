# PathCreator: plan (5 Oct 2026, draft for Ramon)

**Status, 5 Oct evening:**
- Done: steps 1 to 79 and 85 to 90; `CASE_STUDY.md` has what each one taught, with pictures.
- Waiting on Ramon:
  - 65, the W-mode defaults
  - 80 to 84, the editor dock: it needs a plugin under `addons/` enabled in `project.godot`, both
    shared files
  - the size of P for the pen (case study, section 8)

A kit prototype: rebuild the direction path system from scratch, as a graph of routes and
destinations that also connects places in W, plus a builder to lay it out while you play. Source:
Ramon's Figma sheet "Path_Indicator" (Creation Lab, Aligned Layout file, page 5:20). Everything goes
in `CreationLab/PathCreator/`; the case study grows alongside it in `PathCreator/CASE_STUDY.md`.

## What the sheet says (read in full, 5 Oct)

- **One contract, seven skins.** Libraries 01 Axial Lock, 02 Orbital Index, 03 Vector Cross, 04
  Dock Frame, 05 Phase Array, 06 Base Wayfinding and 07 Futuristic Stencil all carry the same ten
  symbols: A primary route, B secondary route, C junction, D arrival, E action available, F focused,
  G completed, H square frame, I round frame, J player scale. "Keep the logic, change the skin."
- **It is a graph, not scattered arrows** (rule 01). Nodes are destinations and junctions; edges are
  directed routes with a priority. Arrows go by cumulative arc length along the route.
- **Units come from the player** (P = 0.6 m ground diameter):
  - primary marks 0.54 m wide every 1.2 m; secondary 0.45 m every 1.3 m
  - arrival art 1.32 m
  - no arrow within the junction or destination radius plus 0.25P
- **Turns are straight chords** (the large field map, B1): no curved arrows. A bend is a ball and
  ring, and a broad curve is short chords joined by small balls. A junction (a choice) is a larger
  segmented node.
- **Priority belongs to the route, state to the destination.**
  - Arrival: a still ring.
  - Available: one outer 90° arc turns once every 6 s.
  - Focused: cyan, plus a centre dot.
  - Completed: a tick.
- **Objects** keep their footprint apart from their frame, with an approach gap; arrival sits
  outside the door.
- **In a 4D room** (rule 09): drawings anchor in the walkable plane, and invalid edges hide.
- **Detail budget:** no glow fields, no noise, no repeated labels.

## The approach, and why

1. **Vector in the shader, not textures.** The masters export as plain SVG paths (checked: 07 A is
   two filled polygons; 07 E is four ring paths, a separate arc path and a diamond).
   - The plan is to parse those paths, flatten them into line segments, and keep each library in a
     small data texture.
   - The floor shader then measures the exact distance to the Figma's own outlines for every pixel.
   - The result is true vector: crisp at any distance, antialiased by its own distance, with no
     atlas to go blurry.
   - A texture set is one data texture, so switching sets is one assignment, at a flick of a key.
   - Parts that move (E and F's arc) are their own layer, turned in the shader.
   - Fallback, if the shader cost shows: the same paths baked into a high-resolution
     signed-distance atlas.
2. **Thin 4D boxes, not 4D meshes of arrows.** One flat box per straight segment and one per node,
   with the symbols drawn by the shader and everything else discarded.
   - It suits straight chords and ball pivots exactly.
   - It is portable to any ground (the pen), unlike painting into one floor shader.
   - Each box's own W thickness is where in W the path exists.
   - A few dozen boxes cost next to nothing.
3. **W behaviour is per edge.** Every edge and node has a W centre and a W band. Four modes
   follow, all cut by the real slice, so they work with walking through W and with tilting it (the
   pen's two ways):
   - **static:** a wide band; visible from almost any W
   - **here:** a narrow band
   - **follow:** the W centre ramps along the edge (a W-sheared box), so the visible stretch slides
     along the route as you move through W and the path "unrolls" toward its target
   - **reveal:** it exists only at the target's W
   - A **bracket** keeps the destination's frame wide in W while the object itself stays thin: you
     see the way and the frame, not the thing. Your idea, and my pick for the pen.
4. **One graph file, two editors.** The routes live in a resource (`.tres`) that the scene loads.
   - **In the game:** a build mode (one key) switches to a camera straight down with every node
     drawn over it, coloured by its W, plus a W lane for the selected route. You drag nodes, wheel
     their W, add, split, delete, join and save, then switch back and walk it. You see the real
     slice while you build, which no editor view can show.
   - **In the editor:** the same top view and W lane in a dock, with undo, editing the same file.
     The 4D viewport shows the boxes.
   - This answers "how can we play a scene and a builder at the same time": the builder is a mode
     of the running scene, and the file is the link to the editor.
5. **Two looks at the flick of a switch:** DEV (the library's blue and cyan, moving) and WALK (a
   flat beige sand albedo, lit like ground paint, for the pen).

Prior art:
- **Floor wayfinding:** hospital and airport floor lines work "because they meet you where your
  eyes already are: down", hence the subtle blue guide line under the marks
  ([desirabilitylab](https://desirabilitylab.com/backfill/backfill-2023-148-wayfinding-floor-arrows)).
- **Lynch's paths, nodes and landmarks** (The Image of the City) is the sheet's graph.
- **Dead Space's locator line** (a route on demand) and **Fable II's breadcrumb trail** (a toggled
  glow trail) are the two poles of on-demand versus always-on.
- **4D slicing:** turning a slice "might make the level completely invisible", and 4D Golf answers
  it with stepped 90° slice turns
  ([Marc ten Bosch](https://marctenbosch.com/news/?p=3019),
  [4D games list](https://en.wikipedia.org/wiki/List_of_four-dimensional_games)). That is why
  routes need a W band and destinations need a bracket.

## The 90 steps

### A. Ground truth (1–9)
1. Folder `CreationLab/PathCreator/` (scene, scripts, shaders, sets, runners, case study) and a case study page started.
2. Measure the sheet at P = 0.6 m: every symbol's size, repeat, clearance and colour token, into one spec script (`path_spec.gd`), the single source of truth.
3. Probe: the cross-section shader's `local_pos` gives each pixel its own 4D position in a box, W included (needed for W fades); write it down.
4. Probe: a W-sheared Node4D basis cuts as a slanted band (the "follow" mode); also under a slice tilt.
5. Probe: a discard-only thin box over a floor, no z-fighting at 1 cm, from the player camera.
6. Probe: switching a live camera to the Combined renderer and back, given the known Cross-section to Combined crash; keep it only if it holds.
7. Probe: the pen's walker (carried copy) with W walking (Q/E) and slice tilt on, in a bare scene.
8. Probe: the shader cost of evaluating ~200 segments per pixel on a 2 m disc, against a frame budget.
9. Keys: list what the walker and the kit already use, and pick free ones for build mode, sets, style and volume view.

### B. The dev space (10–18)
10. `pathcreator.tscn`: a big white walkplane (about 120 × 120 m, deep in W so it exists at every W you can reach), with the Creation Lab's bright environment and sky carried over and no spot.
11. The player: the carried pen walker with W walking and slice tilt, the lab's grey suit.
12. A dev HUD in the kit's black glass: your W, the slice's tilt, the set and style, the keys.
13. Coloured target boxes at chosen W: red here (W 0), green at W −2, a yellow cubinder at W +2, the house-sized blue cube at W +4, a purple tower far at W +8. Each is thin in W, so it appears only near its own W.
14. A W marker pole by each target, in its colour, visible across W, as a dev aid only (off by default).
15. The Figma's 46 × 30 m yard rebuilt at true scale in one corner: hut, watchtower, round station, pen, store footprints. It is the reference layout to test against.
16. The volume-view toggle (if probe 6 holds): Combined, to see ghosts of what is ana and kata.
17. The sand look's colour, chosen against the white floor and a pen-like ground sample.
18. A runner: the space from above and from the player, every target at its W.

### C. The graph (19–28)
19. `path_graph.gd` (Resource), the room data of rule 10:
    - player diameter
    - nodes: id, kind, 4D position, W band; kinds are start, chord, bend, junction, destination
    - edges: from, to, priority, W mode
    - destinations: anchor, approach direction, state, frame, footprint, entry gap
20. Kinds as the sheet means them: a chord joint is a small ball, a bend a ball and ring, a junction a segmented node, a destination the state ring.
21. Routes: chains of edges between junctions and destinations, walked in order; arc length measured along each.
22. Arrow placement by cumulative arc length (rule 01), rotated to each chord, flowing at all times.
23. Exclusion zones (rule 03): no mark within node radius + 0.25P. Marks slide under the zone edge and vanish there (the "hide under the strip" technique), or cross over the ball (a setting).
24. Short chords: only the guide line when an arrow would crowd the end markers (B1 implementation note).
25. Crossings without a node (rule 05): the weaker route's marks break locally; the main route stays whole.
26. Merges share one downstream route; never two sets of chevrons on one line.
27. Validation (rule 10), reported in the HUD and as warnings: orphan edges, unreachable destinations, overlapping symbols, a route ending nowhere.
28. Save and load as `.tres`; a graph file for the dev space and one for the yard.

### D. Vector symbols (29–40)
29. Fetch every master of libraries 01–07 from the Figma as SVG (about 70; the tool's own export from your file) into `PathCreator/sets/<library>/`.
30. An SVG path reader in GDScript (M, L, H, V, C, S, Q, A, Z; fills and strokes), flattening curves to fine segments.
31. Layers: static parts, the moving arc (E and F minus D), the focus accent (dot or diamond), the tick (G).
32. A set resource per library: each symbol's segments, fill rule, stroke widths, layers, bounds, packed into one small float texture.
33. The vector shader: exact signed distance to the symbol's outlines per pixel, fill by winding, antialiased by the distance's own screen rate.
34. Colour by role from the sheet's tokens: blue for direction, cyan for focus, blue-grey for frames, the muted guide line.
35. Overlay check: render each symbol flat and lay the Figma export over it, measured in pixels (as the wall panels were).
36. Close-up test: stand on a chevron, look down, compare against the Figma at 8× zoom.
37. Cost test (step 8 again, real symbols); the signed-distance atlas fallback built only if needed.
38. Set switching: one key cycles 01–07 across every path at once; the choice is saved.
39. The WALK look: the same shapes in flat sand albedo, lit, no motion glow; one key flips DEV and WALK.
40. Reduced motion: arcs and arrows held still, colours kept (rule 07).

### E. On the floor (41–52)
41. A segment box: flat, 1 cm proud, as wide as its marks plus margin, as long as its chord.
42. The segment shader: the guide line, the marks every repeat, flowing, clipped at the zones, the crossing breaks.
43. A node box: square, the node's symbol (ball, ball and ring, junction, destination state).
44. Destination states animated as rule 07: the arc turning once in 6 s, the 160 ms focus colour change, the tick.
45. Frames H and I round object footprints: corner brackets or a thin perimeter, the approach gap, never scaled strokes.
46. The arrival ring outside the door, apart from the gameplay trigger radius (rule 08).
47. Priority: primary solid pairs and secondary open pairs at their own sizes and repeats, as the set says.
48. Equal forks: both exits identical; secondary forks change only the secondary edge.
49. A PathNetwork node that builds all of it from a graph file, in game and in the editor.
50. Rebuild only what changed when a node moves, so dragging stays smooth.
51. Instance budget: count boxes; merge static ones if a big graph nears the engine's instance limit.
52. Runner: the yard's routes from the player camera, each library, both looks.

### F. Paths through W (53–66)
53. Every node and edge gets a W centre and a W band; boxes take that W depth.
54. **Static:** a wide band; the route reads from anywhere you can stand.
55. **Here:** a narrow band; the route belongs to this slice.
56. **Follow:** the W centre ramps from node to node (a W-sheared box); the visible stretch slides along the route as you move through W.
57. **Reveal:** the route exists only near its target's W.
58. **Bracket:** the destination's frame and ring wide in W, the object thin: the way and the frame without the thing.
59. A W cue on brackets and W-crossing nodes: which way (ana or kata) and how far; colour and a small tick on the symbol, no text.
60. A W ladder: a route that steps through W at nodes, each step a node you slice at.
61. The edges of a band: marks dissolve (thin or erode) rather than cut, as you slice out of them.
62. Tilting instead of walking: the same routes under the pen's slice tilt; note where each mode holds.
63. Stations in the dev space, one per mode, all leading to the blue cube at W +4, each with a floor label.
64. Playtest pass: walk each station, frames captured at several W and tilts, notes in the case study.
65. Defaults chosen with you: which mode for main routes, which for W destinations (my bet: static or follow routes into bracketed destinations).
66. Runner: every station at five W and two tilts, a contact sheet.

### G. The builder in the game (67–79)
67. Build mode on one key: a camera straight down over you, the slice still rendered, the player paused, the HUD swapped.
68. The overlay: every node and edge drawn over the view, coloured by W, the band as a halo, off-slice ones dimmed.
69. The W lane: the selected route laid out flat, distance against W, its nodes draggable up and down.
70. Select and move nodes with the mouse; snapping to 0.25 m and to 90° turns; numbers typed in a field.
71. Wheel over a node: its W; shift-wheel: its band.
72. Add (click an edge to split it, or click empty space to extend the selection), delete, join two nodes.
73. Kind, priority, W mode and destination state from a small black panel by the selection.
74. The curve tool: two nodes, a radius, and it lays the chords and small balls between them.
75. A slice scrubber: preview any W from above without walking there.
76. Undo and redo.
77. Save (to the graph file), save as, load; a note when the file has unsaved changes.
78. Walk-test loop: build, one key, walk it, back, without reloading.
79. Runner: a scripted build session (add, move, change W, save, reload) checked against the file.

### H. The builder in the editor (80–84)
80. PathNetwork as a tool node: the boxes in the editor's 4D viewport from the same file.
81. An editor dock: the same top view and W lane as the game's builder, for the selected network.
82. Editor undo and redo for every dock edit.
83. Changes saved in the game show in the editor and the other way round, the file being the link.
84. A short guide in the case study: building a route in the editor, then in the game.

### I. Toward the pen (85–88)
85. Draping: nodes and chords follow uneven ground by downward 4D raycasts, with chords subdivided where the ground bends.
86. Anchors: a destination follows a moving object; a route hides when its way is blocked (rule 09).
87. A pen-like patch (a copied piece of terrain, never the pen itself) with a route across it and into W.
88. Notes on what the pen will need: the sand look over its grass and dirt, the W targets it has, the performance at its size.

### J. Proof and handover (89–90)
89. Final runs: legibility at the player camera (rule 10's acceptance list), cost with the whole yard and every station, every runner green, and frames to look at, not just logs.
90. The case study written up with images, the kit doc section, memory, and a commit by paths.

## What I need from you before I start
1. **Library order:** the field map uses 07 (Futuristic Stencil). Shall 07 be the first set built
   and checked, then the other six?
2. **Builder key:** I suggest F4 for build mode, F5 to cycle sets and F6 for DEV/WALK. I'll check
   they are free in the walker first.
3. **The sand:** a colour or a reference picture for "beige sandy albedo", or should I pick one
   and you judge?
4. **Scale of the space:** 120 × 120 m with W from −10 to +10. Bigger, if the pen's W range is
   wider?
