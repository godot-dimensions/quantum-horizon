# Wall panels: the two-panel room kit (plan, 5 Oct 2026)

Source: Ramon's Figma handoff "Creation Lab / Aligned Layout" (frame 01, the 2048 × 732 layout;
frame 02, dimensions, preservation and the six room-kit rules). Kit work: every prototype that
explains itself on its walls uses this, not only the Creation Lab.

**The size decision:** one kit-wide scale, 1 Figma unit = 12 mm. Each panel (800 × 492 units) is
**9.6 × 5.9 m**, with its foot 1.3 m off the floor, on every wall in every prototype. It is never
scaled to the wall. 9.6 m is the widest panel that still fits the Creation Lab's angled left wall
(10.6 m) with half a metre each side. If a wall is too short, the panel is flagged, not squeezed.
It is one constant if you want it bigger.

## A. Foundation (reusable)
1. **Spec** `kit/panels/kit_panel_spec.gd`. This is the single source of truth taken from the Figma:
   - canvas 2048 × 732, panel 800 × 492
   - tracks: header 0–20 (rule at 19), main 36–360, lower rule 360, supporting rows 369–473, footnote 479
   - research columns 196 / 1 / 571 with 16 gaps; spacing unit 8
   - the ten Montserrat roles
   - the six colour tokens, which in the room are white veils over the lit blue wall so the room's light still falls on them
2. **Fixed physical size**: the one kit constant above. A wall that is too short shows a warning in the inspector and a red frame in the editor.
3. **Room data** `kit_room_info.gd`. The fields are number, title, lead, description (with live `{tokens}`), status line, 2–4 interactions and the research layout family. There is one `.tres` per room. Positions and type live only in the spec (rule 6).
4. **Element library**: native, individually addressable Controls named after their Figma layers. The set is: text by role (line height matched to Figma), rule, divider, surface, story row, metric (counts up), bar chart, table and icon. No rasterised images.
5. **Vector icons**: the three Figma icons (scroll wheel with up/down, rotate, E key) drawn from the file's own paths, plus the kit's existing kinds.

## B. The two panels
6. **Intro panel**:
   - running header: room number / title on the left, status on the right
   - a one-line title, the lead, and a body of at most five lines (max width 680)
   - the lower rule, then the CONTROLS row of 2–4 shortcuts
   - it never auto-shrinks text; copy that overflows is flagged (rule 2)
7. **Research panel shell**: the same header, content bounds and lower band for all three layout families (rule 3). The families are *specimen* (drawn), *compare* (two equal columns) and *steps* (three in sequence).
8. **Specimen family, as frame 01**:
   - left column: specimen label, name and metadata; the production animal glyph (not the Figma reference silhouette)
   - THE STORY with its status; five rows: played, now (accent underline), upcoming at 65%
   - the column divider
   - right column: chapter line, two-line headline, explanation, chart surface with three metrics, caption
9. **A page per part in that one layout**: balls, skin (the Figma bar chart), slice (W profile and the live slice), rig, walk (live cost) and the idle summary. The data and animations are today's wall's, re-set in the new grid.
10. **Supporting band**:
    - the benchmark table: 8 columns at the Figma widths, the specimen on the plinth marked ●
    - it is aligned with the intro's controls row
    - the footnote is live: GPU, OS and date
11. **Data contract**: the research panel reads a plain `panel_data()` dictionary from a source node. The Creation Lab's source wraps the showcase, bench and presentation; the measurement logic moves over as it is.

## C. Placement in 4D
12. **Host** `kit_wall_panel_4d.gd`: you give it a room, an edge (any angle) and an anchor along the wall. It prints on that wall's surface and asks the room for code blue.
13. **Box rooms and freestanding**: the same host works on the four sides of a rectangular KitRoom. With no room at all, it builds its own blue slab at its own transform, turned to any angle.
14. **Live but idle when nothing changes**: one viewport per panel, redrawn only when its content changes or while it animates. Interaction states are bound: the story follows the presentation, and a control's icon lights when you use it.
15. **Editor preview**: the panels show in the 4D editor with sample data, so you can place them by eye.

## D. Into the Creation Lab, with a way back
16. **Wiring**: the intro panel goes where the Lesson is (left angled wall) and the research panel where the research wall is (right wall). The old two stay in the scene, switched off; one switch (in the scene, and in F1 REVIEW) flips back. A revert tag first.
17. **Review gallery rebuilt as frame 01**: one 2048 × 732 wall with the panels 160 apart and 144 margins, so the flat export lines up with the Figma unit for unit.

## E. Proof
18. **Overlay check**: render the flat sheet at the Figma size, lay the Figma frame over it, measure every header, rule, title and row in pixels, and fix it until it matches.
19. **Legibility check (rule 5)** for each panel, from three spots: on approach, at the reading position and close up. It reports each role's on-screen height; title, lead, body and controls must pass from the reading position.
20. **Regression and handover**:
    - the full lab runner
    - a second-prototype test in Room 2: a box room with panels on two sides, plus one freestanding turned panel
    - a five-minute "add the two panels to your prototype" section in `lab_kit.md`
    - commit by paths
