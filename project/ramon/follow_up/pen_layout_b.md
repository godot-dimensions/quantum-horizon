# The pen, layout B (6 and 7 Oct 2026)

From Ramon's painted sketch over the top view (6 Oct), then his playtest notes (7 Oct). The plans, their
decisions and their progress: `PenLayout/PLAN_B.md` (the layout, 40 steps, with the measured table) and
`PenLayout/PLAN_B_ROUND2.md` (the notes, 51 steps; its Status section says what landed). Layout A, the one
before: `follow_up/pen_layout_a.md`.

## What you play now

1. You start on the path at the field's south-east (24.9, 19.1), facing south. The objective: "Follow the
   path to Trym's house." His house is at the path's end, sand in front of it and the destination circle.
2. The path runs west past the cave's turn (the cave's door is 4 m ana: its stretch climbs through W, the
   one "follow" stretch), past the pen (sand round its run, the coop inside, Nike nearby), and north to the
   bend.
3. The town wall runs straight across the valley, 4 m high, through all of W; the gate (3.4 m) is the only
   way north. Mithra searches the field behind it.
4. North of the gate: the range to the west (its yard sand, the yard closed in W), the researchers' camp in
   the meadow (2.5 m kata: turn the slice until it half shows and press V), and the Watchstone at the far
   end with its red oak and Wren's balloon; the flock over the meadow to its right.
5. 104 oaks and bushes where Ramon painted them, and the same planting again at 4.5 and 9 m ana and kata
   (shifted, turned, a little different), so a turned slice always shows a wood.

## Keys (the controls card, H, lists them all)

- **9** the path type for every stretch: as drawn, static, here, follow, reveal (round and round, as Tab goes
  round the cameras); **Shift+9** found as you go, or all shown. Also in the paths' own window.
- **I** the dev look or the art. **O** the grass looks; **Alt+O** grass on or off; **Shift+O** the ground paint;
  **Ctrl+Shift+O** one green or the falloff. (Ctrl+O, the centre glow, is gone.)
- **V** align to the slice (at the camp, and at the marsh). **T** lock on to the nearest loose chicken.
- **C** into the cinema and back; **Shift+C** into the cave and back (it was V, the same as the camp's align:
  that is why V at the camp dropped you in the cave).

## What changed on 7 Oct, and where

- Mithra (`scripts/pen_searcher_4d.gd`): checks a spot is clear before she walks to it, and gives it up when
  she stops getting closer. Before, a spot behind the town wall held her there for good.
- Sand is bare ground: every `ground_sand` shape (the range's yard, the camp, Trym's sand, `Pen/PenSand`,
  `World/Cave/CaveSand`, any `scripts/pen_sand_patch_4d.gd`, round or a rectangle) also clears the grass, with
  the ragged edge and short-grass fringe of the clearings. Clearings live in four W lanes
  (`clearing_lanes`: the farm, the camp, the cave, the marsh).
- The paths' soft edge fades into the ground's own paint (`CreationLab/PathCreator/render/path_sand.gdshader`,
  ground mode 2): no green rim where a path crosses sand.
- Grass on the hills: blades stand on baked heights (`grass/grass_heights_4d.gd`; bake again with
  `grass/_bake_grass_heights_runner.gd` after moving a hill or mound; if you forget, the grass makes them as
  it starts, half a second, and the panel says so).
- Grass at the paths: a field of the paths' own (`build_path_field` in `grass/pen_grass_4d.gd`): the blades
  stop just inside the sand and lean over it, no green strip. Made again when the path type changes, so in
  follow the grass parts where the sand is in W.
- The grass panel: Save settings (`grass/grass_saved.cfg`: look, darkness, wind, leaves, flowers, ground,
  even green); Rebake greens always saved the main green. The paths have their own window.
- The coop (`scripts/pen_coop_4d.gd`, `fence_walls`): its walls by the fence tech, a darker frame showing on
  purpose (flush rails flickered in dashes); off gives the box walls back.
- The range's boards and runes: 28% of their spun faces were facing in; turned out (`_face_out`).
- Trees (`scripts/pen_oak_4d.gd`, `scripts/pen_trees_4d.gd`): round in W (`w_stretch` 1.8), the planting again in
  W layers (never saved; `echoes` off to see without), one culling loop. The tower's oak `red`.
- The dev look: tree crowns as tall as the leaves; Wren's balloon blue (it repaints itself).
- The gate 3.4 m wide, the wall 4 m (4.4).

## Checks

- `PenLayout/scripts/_verify_journey_b_runner.gd`: the route walked front to back on the move key, the cave
  twice; frames in `smoke_test_output/pen_layout/journey/`.
- `chickenpen/scripts/_verify_mithra_walk_runner.gd` (three minutes of Mithra; `fast` mode),
  `_verify_camp_align_runner.gd` (V at the camp, and not into the cave), `_audit_pen_keys_runner.gd` (every
  key and who holds it).
- `PenLayout/scratch/tests/probe_trees_turn_runner.gd` (trees in the slice as it turns),
  `PenLayout/scripts/_perf_layout_b_runner.gd` (frame and GPU time, flat and turned).
- `PenLayout/scripts/_capture_pen_runner.gd` sets `round2`, `coop`, `wturn`, `treecmp`, `volume` (volume view).
- The film: `PenLayout/scripts/_film_slice_tour_runner.gd` (`lab_run.sh movie_hd`).

## The playtest (7 Oct)

Fifty-five runners in one batch (a watchdog stops any that errors and goes quiet, or runs past its time;
the list and the script were in the session's scratchpad), then the journey. Everything that plays passes:
the story, Trym, the quests, catching and releasing, Nike, Mithra (talk, her watch, three minutes of
walking), the range and the Quantum Range trip, the rune stone, the camp's V, the walls (only the gate leads
north), the Lookout, the climb, the balloon ride, the hawk, the site, the cave (walk in, the fade, far, the
way back in W, the crossing, the dreamer, the pickaxe), the celebration, the cinematics card, the wolf raid,
the slice's way home (R), playing again, the meadow film, the theatre and its second part, the ticket door,
the dev look, the controls hint, the locator and T.

Found and fixed on the way:
- The grass built its mask over many frames and asked the tree for each one: a trip in the first second (the
  range, the cave) took the pen out of the tree, and it failed. It waits out the trip now.
- The balloon ride flew to where the marsh was drawn, 41 m off where layout B put it: its ana leg bends to
  the marsh wherever it is, as the farm leg bends to the pen.
- Coming out of the cave put the camera inside the hill's shoulder (you face away from the mouth, the camera
  behind you): in the dev look a blue screen. The way out sets you 13 m from the mouth (8.5).
- The balloon now follows the dev look as it is laid or lifted (in the cinema, the cave and before a save
  too), and puts its envelope back exactly as it was.
- T reached only one of its two listeners (see What changed).

Out of date and left so, not the game's fault: the opening (layout A's: `_verify_opening_runner.gd`; the
journey is layout B's), talk (a radar that is gone), the old range booth's shooting test, eggs and paths
(layout A's routes and keys), the fence test that counts rail meshes (the fence is one generated mesh now),
the HUD sizes, and the flock's CPU checks (headless only). Brought up to date: the pen tests (they drop
birds where the pen is, not at layout A's spot), the crossing (in front of Trym's door along the house's
facing), the professor (the wizard), the range (the Quantum Range), T (pressed for real).

## The camp's path and V (7 Oct, after the W tools)

Ramon, seeing the paths coloured in the editor's volume view: "why is the path to the campsite not follow? its
lower no?", "that also means placing the campsite at the landing spot of the path", and "v should only happen
when you almost got it all in slice but not quite ... v at 80 is also fine".
- The camp's last stretch is a follow path from the junction (W 0) down to the camp's W (2.5 kata), landing
  at its sand; its destination and ring (CampFrame) moved from the farm's W to the camp's (`CAMP_W` in
  `_make_pen_paths_b_runner.gd`, pen_b.tres regenerated). From the farm's slice nothing of the camp shows now,
  not even its ring; only its sand painted on the shared ground does.
- V comes up only when 60% or more of the camp is in your slice but not all of it
  (`pen_research_camp_4d.gd` `shown_share()`, `align_share`; first 80%, then Ramon after playing it: "it was so
  hard to get the campsite to show up right. we should introduce V a bit sooner"); before, any slice through
  its middle brought it, a strip of it. `_verify_camp_align_runner.gd` passes (64 turns showing part of it under
  60%: no V; a small turn showing 73%: V), and so does the journey (23 checks).
- Stray boxes on a turned slice (Ramon's screenshots): `World/Scenery/Post5`-`Post7`, plain 0.7 x 2.2 x 0.7 m
  posts from the pen's first version at W +1.6, -1.6 and +2.4, moved by layout A's runner
  (`_make_moved_pen_runner.gd`); found by `WTools/tests/_probe_stray_boxes_runner.gd`. Deleted at his word ("yes delete the boxes"),
  with their mesh and material; `World/Scenery` is left empty. `_measure_scale_runner.gd` still looks for Post5.

## Ramon's 7 Oct feedback round (after the W tools)

Two batches, each checked in frames (`PenLayout/scripts/_capture_feedback_runner.gd <mode>`, frames in
smoke_test_output/feedback/) and by the tests named.
- The professor: rustic, no wizard: red hood (ears off under it) and cape, brown tunic and trousers, amber amulet; no
  robe, no staff (`scripts/pen_professor_4d.gd`; `_verify_professor_runner.gd`).
- The wolf raid: no endless circling (straight at its target when close, a time cap per run), left click or Esc
  skips to the end (`wolf/wolf_raid_4d.gd`; `wolf/_verify_wolf_loop_runner.gd` passes, the old code fails it 9 ways).
  The range's rigid wolf for the raid: parked at his word ("not important now").
- The start: the avatar faces where the camera looks (`block_walker_character_4d.gd _ready`).
- NPC rings (`scripts/pen_npc_markers_4d.gd`, Systems/NpcMarkers): the professor's turning ring for everyone you can
  talk to and the ground animals, following them, in the dev look only, in its landmark colour. Not on chickens.
- The camp: its ring on the ground (the camp's colliders are drape_through), V at 85% of it in the slice, and the
  Camp Scout (World/CampGuide; `pen_camp_guide_4d.gd`, `camp_guide_script.gd`, `pen_camp_guide_talk_4d.gd`) on the
  road where it fades from the farm's slice: look down the path and turn your slice.
- The Watchstone: dev look as four boxes and an orange top disc (`look/pen_blockouts_4d.gd TOWER_BOXES`), its timber
  kept and in the landmark colour; the walk-up cuts to the little ladder, and you climb its last rungs in the play
  view (1 s); at its head "Go down? Y / N"; Stone080 (it buried the ladder) removed from units/watchstone/watchstone.tscn.
  `lookout/_verify_lookout_runner.gd` 36/36.
- The dev look's two colours: FOUNDATION (the blue) and LANDMARK (the orange), little swatches under Dev / Art (dev
  look only), saved with the panel's Save settings to `look/look_saved.cfg`; the range, the pen, the camp and
  Trym's house drawn in the landmark colour as a test (`pen_look_4d.gd orange_units`).
- The paths window stacked on top of the grass panel, the pair clear of the inventory belt (`pen_inventory_4d.gd
  belt_rect`, which pen_hud_spot_4d.gd could not see: the inventory is full-screen).
- The kata wood's leafy trees without their leaf balls (`lookout/lookout_tree_4d.gd leaf_balls`, off).
- Not done: the team write-up of how the pen works (next).

## Open

- The range in W, and Ramon's W tools (a W exploder for trees, a W optimiser for landmarks): next, from
  research first (memory: project-w-tools).
- In projection (volume view) the slim light oaks nearly vanish; their leaves draw only in the slice.
- The third-person camera can stand inside a tree's crown; in the dev look a crown is solid blue.
