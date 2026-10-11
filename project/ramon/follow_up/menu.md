# The menu (menu_final), 8 to 9 Oct 2026

## Read this first (9 Oct)

**`res://ramon/menu_final.tscn` is the master, and it is design "A" only.** Ramon: "keep the menu
final as the new main master and remove the tab variations". The look is `Menu/scripts/menu_a.gd`;
the working parts (catalogue, selection, keys, details, launching) `Menu/scripts/menu_final.gd`;
the words `Menu/entries/catalogue_final.tres`. `Menu/README.md` is the one-page map.

- The Tab design review is gone from the master. All 41 designs are frozen, for reference, in
  `res://ramon/menu_variations.tscn` (scripts `menu_variations.gd`, `_b.gd`, `_c.gd`; the design
  runners point there). Do not develop the menu there.
- Checking a change: frames only, `Menu/_capture_menu_final_runner.gd` (white and dark, list and
  route, three selections; `scene=` and `tag=`), diffed against the last good set. The 9 Oct cut
  was checked that way: the master and the frozen A match to the pixel. No launch tests: the
  interactive part is broken and Ramon fixes it later.
- `run/main_scene`: on 9 Oct it was `ramon/Arboretum/arboretum_water.tscn`, set by another window;
  ask Ramon before pointing it back at the menu.
- **The loading screen** (9 Oct, Ramon: "let your menu loader be in the same style as the voxel
  labs start loader ... consistent across all scenes ... your design can be different, but the
  style should be the same"; "makes more sense if the white fade in happens after the tscn
  loader"): `Menu/scripts/menu_load_board.gd`, the lab board's code blue, grid, white type and foot
  line, with the menu's own content (name, line, keys as caps, logo square with the question, the
  world's square showing the four marks, status and length). One white at the very end: a scene
  with its own `LoadBoard` layer (the Voxel Lab) takes over blue to blue and whites itself; any
  other scene gets the menu board's white. Same square and list position as the lab's board, so
  the hand-over does not jump. Frames: `smoke_test_output/menu_review/loader/`.
- **Two families** (9 Oct brief, "Prototype Menu Reorganization"): the menu groups by
  `MenuEntry.family`, named in the catalogue (`family_names`, `family_lines`): THE LABS (Voxel
  Lab, Creature Lab, Botany Lab, Aquatic Lab) and THE EXPERIMENTS (Shooting Range, The Maze,
  Crosswise: Ramon swapped Crosswise and the Shooting Range, 9 Oct); first called EXPLORE THE
  SYSTEMS and EXPERIENCE 4D, renamed by the review below. Marks: a flask and a
  play ring (`_paint_system_mark`). The four systems (`category`) and the thrusts stay in the
  catalogue as metadata only. Headline "Four labs to explore. / Three experiments to play.";
  footer "four labs · three experiments". Renamed: Creation Lab to Creature Lab (now opens
  `CreationLab/creation_lab2.tscn`, Ramon: "creation lab 2 is new"); Arboretum to Botany Lab
  (another window did the title). New entries: Aquatic Lab (`WaterLab/water_lab.tscn`, fish icon
  `Menu/icons/icon_aquatic.png`, VIDEO N/A) and The Maze (`PhaseMazeRemake/phase_maze_remake.tscn`,
  the maze icon, VIDEO N/A). Off the menu, kept: 4D Ascent (retired by the brief) and the old Phase
  Maze (The Maze replaces it). Blurbs cut to one line each so the list keeps its rhythm; the
  longer wording is in each detail. Linked only: no launch or return checks (other windows are
  working in those prototypes).
- **Relinks** (Ramon, 9 Oct: "soon a botany_lab.tscn will be build. keep in mind to relink";
  "soon a creature_lab.tscn will appear too"):
  - Creature Lab: DONE, `ramon/CreationLab/creature_lab.tscn` (the Creature Lab window renamed
    creation_lab2.tscn to it the same afternoon; the old name no longer exists).
  - Botany Lab: DONE, `ramon/Arboretum/botany_lab.tscn` (built the same afternoon by the Botany
    Lab window; arboretum.tscn stays as it was).
  Change `scene_path` in that entry of `Menu/entries/catalogue_final.tres`; find the new file's
  path first. Link only, no launch checks.
- **Keys checked against the scenes' own key strips** (9 Oct, by reading `_strip()`, nothing
  launched): Voxel Lab's were still the old voxel mining ones, now the room's; Creature Lab's
  from creature_lab_4d.gd; Aquatic Lab's from water_lab_4d.gd; The Maze's from its maze_hud.gd;
  Botany Lab's already matched. The Creature Lab's "measured" line (17 animals, 11 bays) was the
  parked W-lift lab's and is cleared.
- **The 9 Oct review applied** (`follow_up/menu_review_9oct.md`; Ramon: "yes labs first, go"):
  the films are off the menu (show_in_menu false: no film row, no 1 / 2 keys; they still play in
  the pen, K); one noun per family, THE LABS ("How our 4D world is built") and THE EXPERIMENTS
  ("Learn to read 4D by playing" until 10 Oct, now "How 4D holds up in play": Ramon wanted it to say
  the experiments are where we test how 4D works as play), labs first; the kicker counts within the family ("THE LABS · 2
  OF 4"); the header says the catalogue's `header_subject` ("4D PROTOTYPES"); every badge set on
  purpose (labs Prototype, experiments Playable); LAUNCH on every entry; a capital W in every
  displayed text; two verbs ("turn the slice", "step through W") and one key style (LMB, RMB,
  Wheel, "1 to 3"); one duration format ("10 min"); the experiments' lines say what you do;
  "six rounds" in the Shooting Range; "voxel" only in the Voxel Lab's line. Route: each family's
  name centred over its own stops with a bracket under them, the heads lined up with the rings
  (the world's column mirrored), dots between the two families, and the caption "Our suggested
  route. Every stop can be launched on its own." Kept: the weave (Ramon's pick, design 21), the
  thrust out of the kicker. Not invented: durations for the Aquatic Lab and The Maze.
- **The details panels rewritten from the scenes** (9 Oct, Ramon: "the descriptions in the second
  panel are completely off ... the labs are exhibition spaces of sorts ... the experiments work with
  testing 4d, and if its viable for a gaming platform"). Each entry's line, detail, question,
  approach, finding, evidence tier and measured line were written from a read of its scene, code,
  handover and newest frames (no launches), framed for the experiments by Notion: the RFP's Live
  it question, D2's "target-practice, navigation and landmark-recall scenes for playtesting", and
  Thrust C's warning that players can succeed without understanding 4D. The labs say what the
  exhibition shows and what was measured; the experiments say what the player does and that no
  person has played them yet (tier "Not yet tested"; the bot results are in the measured line).
  Quoted numbers only where a log or bench file states them; stale ones dropped (the parked W-lift
  lab's, the old Slice Vision's). Durations kept only where grounded (Shooting Range: its stage pars
  add to 522 s, "9 min"); the others are blank until someone times a visit. Texts are kept to three
  lines a research box and one measured line, so the route view's fixed-height panel holds them.
- **Screenshots until the videos come** (9 Oct, Ramon: "for now in the video sections, just paste
  a screenshot. videos will be made later ... and write video coming today on that image"): each
  entry has its own clip name now (voxel_lab, creature_lab, botany_lab, aquatic_lab,
  shooting_range, the_maze, crosswise, the_world) and a `Menu/thumbs/<clip>_still.png`, copied from
  the other windows' newest frames. The preview shows `<clip>.ogv` if it exists, otherwise the
  still with a code-blue "VIDEO COMING TODAY" label in its corner (caption SCREENSHOT). Drop a
  video in under the clip's name and it takes over; delete the still if you like. The old
  videos (voxel_mining.ogv, shrubbery.ogv, ...) are untouched, no longer named by any entry.
- **Declined: the world's line stays** "Every system on this menu, together in one open 4D world"
  (menu_review_9oct.md §6.3 suggested softening it because the Aquatic Lab's tank and sea are not in
  the playable world; Ramon, 9 Oct: "we might not have the water from the aquatic labs in the
  playable world but they dont need to know"). Don't reword it. (The world does have water: the
  Lookout's marsh along W, built in code by lookout/ana_marsh_4d.gd.)
- **The films** (9 Oct, Ramon: "make about 5 shots for each prototype video ... as hires as
  possible ... cinematic, immersive, cool, and also gameplay shots"): each prototype has a 15 to
  17 s clip at 1920 x 1080, 30 fps, in `Menu/thumbs/<clip>.ogv` (Theora q8; 11 to 51 MB each, the
  leafy and watery ones largest; q6 halves them, a little softer at full size). Made by
  `Menu/films/<clip>_film_runner.gd`, one per prototype, with the shared `film_kit.gd` (fixed 30 fps
  steps, JPG frames, eased glides, HUD hiding) and `film_run.sh <clip> <runner>` (lock-gated, waits
  up to 45 min; encodes an mp4 to review, the .ogv and a contact sheet into
  `smoke_test_output/menu_films/`; copying into Menu/thumbs is a separate step). The runners load
  each prototype's own scene directly, never through the menu, change nothing on disk, and switch
  the player's input off. Re-film one: `bash Menu/films/film_run.sh voxel_lab
  res://ramon/Menu/films/voxel_lab_film_runner.gd`, then copy the .ogv over. The screenshots
  (`<clip>_still.png`) stay as the fallback. Not filmed yet: the world (all its older footage
  predates the pen's Layout B).
- **Sounds:** the Frontier Map's MenuAudio cues, with its logic: click on picking a row or the
  world card (mouse or arrows), select on a launch and on LIST / ROUTE and light / dark, error on a
  missing or unwired scene, swipe on coming back from a prototype. The map's music bed is off
  (it would play under a running prototype). `_cue()` in menu_final.gd.
- **The foot (10 Oct):** LIST / ROUTE at the very middle (light grey edge, the "on" side blue);
  in the corner row (`CornerRow` in menu_a.gd) the words DARK MODE or LIGHT MODE (what a click
  turns it to) with the bare half-filled ball, then QUIT, which `_add_quit_button` appends to that
  row. The list's rows sit a little closer (padding 7, family gap 18) so all seven fit and the
  scrollbar is hidden; the ScrollContainer stays, and `scroll_rows` gives back the 22 px gap only
  while the bar shows, so an eighth entry brings the bar straight back.
- **Round 2 of the foot (10 Oct evening):** one button look for the foot, `foot_button()` in
  menu_a.gd: blue caps in a light grey edge, rounded like LAUNCH, white on blue when on. LIST /
  ROUTE is one pill (rounded only at its outer ends); QUIT uses the same look instead of the
  filled launch blue; the slug, the pill and the corner row are centred on one line (`FOOT_ROW`).
  Shooting Range's row title is back to Light. On the route the rings are 1 px and the logos
  greyer (ink at 0.5).
- **The icons (10 Oct):** Ramon's bold set, `Menu/icons/lab_icons_bold/` (white 512 px PNGs, the
  SVG sources in `svg/`, ignored by Godot; README from the set), used exactly as given for the seven
  visible entries in catalogue_final.tres. The PNGs are imported with mipmaps and drawn with
  `TEXTURE_FILTER_LINEAR_WITH_MIPMAPS` (list logos, route rings): at 56 px from 512 they shimmer
  otherwise. The old icons stay for the hidden entries and the other menus.
- **The greys and the Tab panel (10 Oct):** route rings light grey, route logos darker, list logos
  lighter. The three greys are ink strengths in `Menu/style/menu_tuning.cfg` ([greys] list_logos,
  route_logos, route_rings), read by menu_final (`tuning`, also in the editor) and used by menu_a.
  **Tab** on the menu opens `Menu/scripts/menu_tuning_hud.gd`: a slider per grey that repaints
  live (no rebuild, so the video keeps playing), SAVE writes the .cfg (it is in the repo, so a save
  is everyone's menu), REVERT reads it back. Tab does nothing while a prototype runs, and the panel
  hides on launch. More knobs go in the same file and panel: add a key to `TUNING_DEFAULTS` and a
  row to the panel's `ROWS`. Frames with it open: the capture runner's `tuning=1`.
- **THE ANNEX IS HIDDEN (11 Oct, Ramon: "remove it for now and restore to how it was, but keep the
  data").** Another window added The Annex (MazeRemake2) to the menu in c89bfc2 / 24a133b. Its entry
  stays in catalogue_final.tres with `show_in_menu = false` (text, icon, clip, scene path all kept);
  delete that line to bring it back. Before it comes back: its Esc guard (MazeRemake2/hud/mr2_escape.gd,
  a copy of the Voxel Lab's from 10 Oct) still calls the menu's question on Esc, and its key strip has no
  `M  Menu`; both need the 11 Oct change below (as vl_escape.gd and voxel_lab_4d.gd got it), or the end
  to end runner fails there and the Annex stays running under the next test.
- **ESC STOPS, M IS THE MENU (11 Oct; Ramon: "escape was always my button to break a presentation
  ... it was always: kill it").** The 10 Oct night's "Esc asks to go home" is reversed. Esc stops
  things again (talks, cinematics, presentations, seats, panels) and with nothing open frees the
  cursor; launched from the menu it never quits (rig copies, the Range). The menu's question opens on
  **M** (`MENU_KEY` in menu_way_home.gd), heard last as before; in the box Esc or M is No, Enter Yes.
  Every scene lists `M  Menu` in its own key strip while a WayHome is at the root (`_menu_key()` in
  the Voxel Lab and its field, Creature Lab and hall, Botany Lab and Two Gardens, Aquatic Lab and the
  sea, the Range; Crosswise's strip, the Maze's lists, the world's controls card). Keys moved off M:
  the Maze's map is O (its wall text too), the world's "finish the round" test key is F7 (G is
  Nike's carry). Kept as they were, Ramon's call: Crosswise's intro skip, the cave dreamer's refusal,
  the Dream Shifter's unskippable start, the lookout climb ignoring Esc. The theatre seat is back
  as it was (its escape_first group is gone). The text below about Esc asking is history.
- **The way home (10 Oct night; Ramon: "Escape must always provide a safe, consistent way back").**
  `Menu/scripts/menu_way_home.gd`, a CanvasLayer "WayHome" the first menu puts at the ROOT (it
  outlives the menu, which the world replaces, and every room change):
  - **One question everywhere:** "Return to Main Menu?" / "Yes, Return to Menu" / "No, Stay Here",
    centred, bright in light mode and black in dark (follows the root's `menu_light`). The tree is
    paused while it is up; Enter = yes, Esc = no. `ask()` is reused for other yes/no questions
    ("Start a new world?").
  - **Heard last:** WayHome sits FIRST among the root's children (moved back there on every root
    arrival), so in `_unhandled_input` it hears only an Esc nobody else took: open panels,
    conversations, cutscenes, the journal, the hawk close first. Nodes that poll Esc without taking
    it join group `escape_first` with `escape_wanted()` (the theatre seat). While asking it moves
    itself last so its `_input` is first.
  - **Yes:** under a live menu, `_close_running()`; in the world, the world is held by a
    `pen_laptop_trip_4d.gd` trip exactly as a laptop holds it; else a change of scene to the menu.
  - **Switched over (each guarded by "is there a WayHome at the root", so a scene run on its own
    behaves as before):** the menu's own Esc/H close (gone); the seven `pen_orbit_rig_4d.gd` copies
    (world, Creature, Water, Botany x2, Maze walker, Voxel) no longer free-then-QUIT; the Voxel Lab's
    `vl_escape.gd` and the Maze's `maze_escape.gd` keep their steps and call `ask_home()` instead of
    their own box; the Range's Esc no longer frees/quits after its F1 step; the old
    `Demo/return_button.gd` "BACK TO MENU  H" prompts are hidden and silenced as they appear (not on
    the world's own range trip); H is no longer a way home; hints updated (world controls card, Maze
    lobby, Crosswise finale).
  - **The world on hold:** the laptop trip no longer shows its own ESC RETURN TO THE PEN button or
    "Back to the chicken pen?" (`OWN_WAY_HOME := false`). The menu's foot shows a solid blue
    RETURN TO THE WORLD right of the LIST/ROUTE pill while a trip exists; the world card always means
    a new world (asks "Start a new world?" first, `discard()` frees the held one).
  - **Labs run clean:** held whole only while the menu is up; launching a lab calls the trip's
    `release_world()`, which frees the world (and a cave CaveCrossing parked in `_kept`) after it was
    written down at the moment it left (`pen_resume_4d.gd capture()`). Return then loads the world
    through the menu's own launch (loading board) and the trip restores what was written down once it
    is up (`expect_world()`). No resume script, no release: the world stays held, never lost.
  - **Checks:** `Menu/_verify_way_home_runner.gd` (every entry: Esc asks, No changes nothing, Esc +
    Enter lands on the menu; second rooms; the Maze's Tab panel closes first; the world: hold, return,
    release by a lab, reload and restore, a laptop; memory per stage). Frames in
    `smoke_test_output/way_home/`. Backups of every non-menu file touched:
    `Menu/.backup/2026-10-10_way_home/` and `chickenpen/.backup/2026-10-10_way_home/`.
- **Kept, uncommitted on purpose:** `Menu/scripts/menu_designs_b.gd` and `menu_designs_c.gd`, the
  originals of the frozen copies the variations scene reads (`menu_variations_b/c.gd`). Nothing uses
  them; Ramon, 9 Oct: "leave them out but i want to keep them". Don't delete them, don't commit them.
- Everything below is history: how A was found (8 Oct). Where it names `design`, `DESIGN_A`,
  `menu_designs_c.gd` or the Tab panel, read `menu_a.gd` / menu_variations instead.

The front door: `res://ramon/menu_final.tscn`, script `Menu/scripts/menu_final.gd`, its own
catalogue `Menu/entries/catalogue_final.tres`.

## Questions for Ramon

1. **Which design?** Nine are live behind Tab (see "The design review"). My pick for the gate:
   **9 LAB HUD in the LAB palette, grouped by question** (Tab, 9, B, G). Second choice, more
   restrained: **3 GROUPED PANELS**. Reasons under "Recommendation".
2. **Group by the Frontier Map's systems, or by the RFP's questions (Build it / Fill it / Live it)?**
   I'd use the questions for stakeholders: they are the committee's own words (RFP thrusts, D2 §8).
   The map's four categories are our internal taxonomy from early September.
3. **The header.** Now a slim running head: "QUANTUM HORIZON / 4D PROTOTYPES" and, right, the
   coverage counted from the catalogue. Notion calls this deliverable "a demo of the engine's core
   features" and its version 1 "the project's benchmark", measured Oct to Dec 2026, so I'd make it
   "QUANTUM HORIZON / CORE FEATURES DEMO" with "IO RESEARCH · VERSION 1 · OCTOBER 2026" on the
   right. Optionally a big title card on first arrival (the hypothesis) that settles into the slim
   head once you have launched something. Not built; your call on the words.
4. **The journey** (proposal below): keep PLAY THE WORLD on top as the way in for those who want
   it, but steer first-timers through the groups in order and end in the world? A small "NEXT" tag
   on the next unseen prototype and an "n of 7 seen" count would make the existing auto-advance
   visible. Not built.
5. **Prototype fixes the menu needs** (inside the prototypes, allowed by your 8 Oct rule; not done
   yet, all found by reading code, not played):
   - Voxel Lab: the gallery's far door calls `change_scene_to_file`, which frees the menu (the lab
     runs on top of it); H then loads a second lab and Esc quits the game. Fix: list the field as a
     second launch target, or guard the door when the lab is not the current scene.
   - Arboretum: Esc during its tour closes the whole prototype (the menu takes Esc first). Fix: the
     menu could leave Esc to prototypes that consume it, or the tour could end on a click only.
   - Crosswise: R after the finale calls `reload_current_scene()`, which reloads the menu.
   - 4D Ascent: its finish screen is added to the root and stays over the menu after Esc.
   - Portal and 4D Ascent still use shader copies reading the old UVW slots (wrong since 30 Sept).
6. **Copy still describing the old versions** (kept on purpose, "keep second panel same for now"):
   the right-hand panels of Crosswise (Slice Vision's three chambers), Voxel Lab (the old rock),
   Arboretum (Shrubbery's one tree), the Creation Lab's numbers and clip (the lift lab parked
   5 Oct), the pen banner ("nine loose chickens", "Trym's talk", 28 Sep benchmark). Researched,
   source-dated replacement copy for all of them is in this session's notes; ask and it goes in.

## What changed on 8 Oct

- **Lineup** (Ramon's list): Slice Vision became Crosswise, Quantum Range became Shooting Range (the
  game's own title), Voxel Mining became the Voxel Lab, Shrubbery Lab became the Arboretum, Lofted
  Creatures gave its place to the Creation Lab. Portal, Motion Lab, Sky Box Clouds and Lofted
  Creatures are taken off the menu with the new `MenuEntry.show_in_menu` checkbox, never deleted.
  Key caps were corrected on the converted entries (checked in each scene's input code).
- **Own catalogue.** `catalogue_final.tres` (copy of `catalogue.tres`). The Frontier Map places its
  nodes by entry TITLE, so renaming in the shared file would have broken it. Menu, Menu2 and the
  map keep `catalogue.tres`, untouched.
- **Frontier Map** no longer linked from the menu (its tabs are gone). It still opens on its own:
  `res://ramon/FrontierMap.tscn`.
- **No video:** the frame says "VIDEO N/A" (the pen, the two films).
- **Groups.** `MenuEntry.category` (the map's four systems) and `MenuEntry.thrust` (the RFP's three
  questions); the list is drawn in groups in either taxonomy. The detail pane's kicker reads
  "ORIENTATION · 04 / 07" (the Creation Lab title card's "PART 2 OF 5 · GOAT" logic).
- **Header.** The 104 px Frontier Map banner (QUANTUM HORIZON over a big EXPLORE FREELY) is replaced
  by a slim title line with a hairline (the research wall's header).
- **Snapshot** of the menu before the grouping: `res://ramon/menu_final_temp.tscn` with its own
  script and catalogue copies. Nothing points at it.
- **Fixes:** the arrow keys now scroll the selected row into view; a rebuild no longer leaves its old
  loading overlay behind; the selection bar no longer shifts a row's contents.

## Round 2 (8 Oct evening): 0 ORIGINAL and designs 10 to 19

Ramon: "i still want the original look ... in the options"; "number 7 was the most intresting";
"all white options, and all near black options ... dont mix this black and white together";
"keep the left outline right panel system, and also the system from number 7 can be tackled
again ... make a better relation to how the different protos fit". So:

- **0 ORIGINAL** (key 0): the menu as it was that morning (EXPLORE FREELY banner, tour and lab).
- **10 to 19** (the HUD's second row, mouse only), in `Menu/scripts/menu_designs_b.gd`. B there
  switches WHITE / BLACK (`WHITE_PALETTE`, `BLACK_PALETTE` in menu_final.gd), never mixed.
  10 research list, 11 blue plaques, 12 chapters, 13 three panes, 14 world first (list + details);
  15 question board, 16 stack, 17 hub, 18 evidence matrix, 19 journey (number 7 reworked).
- **The relation data** (new MenuEntry fields, read from the code by an agent, strict):
  `world_link` where the prototype's own system is in the world (Shooting Range: the range north
  of the gate; Arboretum: the oaks and the red oak on the Watchstone; Creation Lab: the chickens,
  the wolf raid, the cinema's goat (the pen is their source); Voxel Lab: the cave's Artifact
  block, on the OLDER voxel code; the starlings film: the flock, filmed live). `world_idea` where
  only the idea is (Crosswise: the cave's opening through W; Phase Maze: the camp 2.5 m kata, the
  cave door 4 m ana; 4D Ascent: the cave road climbing through W). `also_answers` (secondary RFP
  question, for the matrix): Build it for 4D Ascent, Shooting Range, Arboretum, Creation Lab.
- Checks: `_verify_menu_designs_runner.gd` now runs all 20 designs in both groupings: 160 checks,
  all pass. Frames: `designs/d<n>_<white|black>.png`, `sheet_round2_white.png`, `sheet_round2_black.png`.

## Round 3: the Octobergate deck (20 to 29)

From the Figma "Octobergate presentation" top row (node 447-8), read layer by layer (read only, in
the built-in browser once Ramon had signed in) and translated at half scale, white and blue (B: near
black and light blue), in `Menu/scripts/menu_designs_c.gd`. The deck's frame on every one: the
running eyebrow "QUANTUM HORIZON / OCTOBER GATE" with its blue tab, the act label at the right, the
footer rule and slug; Montserrat Regular for body (`DECK_FONT`), a blue ramp per group
(`DECK_BLUES_*`). 20 deck slide, 21 route slide (a curve through every prototype, ending in the
world, details below), 22 divider numerals, 23 measured rows, 24 cover, 25 two views, 26 index,
27 tesseract, 28 quiet, 29 full deck. Known: 21's details pane runs slightly into the footer.

## Final row: "A" (design 40)

**A is the menu since 9 Oct** (Ramon: "install final A as the main menu lander"), and later that
day the only design in the master (see "Read this first"). Its eyebrow is just "QUANTUM HORIZON"
(no "/ OCTOBER GATE"; the blue tab matches its width).

Ramon's pick, 23, worked (8 Oct), in `_design_a` (menu_designs_c.gd), `DESIGN_A` in menu_final.gd:

- Each prototype's own logo where P1, P2 stood: no frame, 23's grey made lighter (ink at 38%) and
  bigger (76 x 56). The group's small Frontier Map mark before each group name (follows G).
- One blue throughout (`_group_color` returns the accent for A), no hue shifts.
- The selected row: hard edged, a tint and a 4 px blue bar inside the row, not around it.
- The list's rules and selection stop 22 px short of the scrollbar (`scroll_rows(..., right_gap)`).
- No "CINEMATICS · PRESS 1 OR 2" heading; the two film names stay.
- The world as the big one (`world_big`): kicker "THE WORLD · WHERE IT ALL COMES TOGETHER" with all
  four marks, "Play the world" at 40 px, the new blurb ("Every system on this menu, together in one
  open 4D world") and what is in it. The world and the video frame take the launch button's
  corners; the details panel is flat (no stroke, no rounding). The Shooting Range's name one weight
  up (Regular), to compare.
- **LIST / ROUTE** switch at the bottom right, where the "00" page number was: ROUTE is design
  21's view built in. Kept for the session (root meta `menu_a_route`, `_a_route`,
  `_toggle_a_route`). The route view is cut in half both ways: the route in the top half (88 px
  rings, the spare height split 3 : 2 around it), the details in the bottom half at one fixed
  height (492 px, the Creation Lab's longest text fits, so the route never moves on a click),
  video left 50 %, words right 50 % (`_build_detail_column(true, halves)`: words a step smaller,
  closer gaps, no file path).
- **Light / dark**: a square with a half-filled disc, left of LIST / ROUTE (same as B in the HUD).
  The other candidate was the header's top right, beside "00 / PROTOTYPE HUB".
- 4D Ascent's row tries a step up (one weight, 31 px, its ink 20 % lighter), beside the Shooting
  Range's one-weight step, to compare. The cube mark (Spatial interaction) is drawn at 72 % stroke
  in A, as it read heavier than the other three.
- The world's catalogue copy (catalogue_final.tres hero) now reads as the place where everything
  runs together, not "bring nine loose chickens home"; its detail lists the systems, then the cave,
  the researchers, the camera and Trym's talk.

Frames: `designs/d40_white.png`, `d40_black.png`, `d40_white_route.png`, `d40_black_route.png`
(`_capture_menu_designs_runner.gd -- only=40 route=1 tag=route`).

## Round 4: the original, washed (30 to 39)

Ramon: "subtle variations that respect the original menu, but washed over with the new kit style
and figma style ... 10 variants based on the most original design. including black toggle". All
ten keep design 0's layout (banner, tour, films, lab, cards) and its words; each adds one wash, in
WHITE or BLACK (B): 30 kit type (ExtraBold titles), 31 kit caps (outline key caps, pill launch and
badge), 32 accent bars (the lab title card's 4 px bar on every card), 33 grid room (the lab's grid
ground), 34 kickers ("TOUR · PART 03 OF 07" over the title, numbered rows), 35 hairlines (flat
rows), 36 research header (the slim header instead of the big banner), 37 blue wall hero (the
world card as a Figma wall panel), 38 pills (pill headings, the lab's control strip), 39 all of
them. `WASH_FLAGS` in menu_final.gd lists each design's washes, so new mixes are one line.
Frames: `designs/sheet_round4_white.png`, `sheet_round4_black.png`. Round trip: 240 checks pass
(rounds 1, 2 and 4, both groupings).

## The design review (temporary, for Ramon only)

**Tab** shows a small glass panel at the top right. While it shows: **1 to 9** pick the design,
**B** the palette (GREY, today's, or LAB), **G** the grouping (the map's systems or the RFP's
questions). Hidden, the keys do what they always did (1 and 2 play the films). The choice is kept
for the session (root metas `menu_design`, `menu_bright`, `menu_taxonomy`, `menu_design_hud`).
Content, detail pane and launching are the same in all nine; only how the groups are drawn changes.
`design_review` on the root node turns the whole thing off.

| # | Design | Principle |
|---|---|---|
| 1 | Current | headings between identical cards (the baseline) |
| 2 | Segmented | proximity: a group's cards touch, 36 px between groups, heading 8 px above its stack |
| 3 | Grouped panels | common region: one panel per group, rows flat inside, an edge in the group's colour |
| 4 | Route | connectedness: the Frontier Map's route down each group, a node per prototype (filled when played) |
| 5 | Numbered index | Swiss two-column index: the group left, its prototypes numbered right, heavy rules between groups |
| 6 | System tabs | one group at a time |
| 7 | System board | the map's layout: one column per group across the top, the detail pane below, sideways |
| 8 | Lab wall | the lab's blue teaching wall for the list, the detail pane as a framed screen |
| 9 | Lab HUD | the Creation Lab's screens: black glass, round pills, outline key caps, title cards with a 4 px accent bar, ExtraBold titles, the lab's control strip |

**LAB palette (B):** the range's light holodeck wall with its grid as the ground, every panel black
glass (UI_GLASS 0.04, 0.06, 0.10 at 0.86-0.90, white 8% edge), white type, code-blue hero and
buttons. The lab and the range share this one screen style (`QuantumRange/carried/kit/kit_style.gd`
is a copy of `CreationLab/kit/kit_style.gd`): black glass over a bright room.

Frames: `smoke_test_output/menu_review/designs/` (`d<n>_<grey|lab>.png`, `*_questions.png`,
`sheet_grey.png`, `sheet_lab.png`, `sheet_questions.png`).

## Recommendation, and why

- **Grouping by question (G).** The gate reviews the RFP and the plan; their three thrusts are the
  questions the committee must answer (D2 §8: "Each group of KPIs tests one claim the committee needs
  to believe before production"). A menu grouped as "Live it: can ordinary players understand and
  control 4D?" shows each prototype as evidence for one of those claims. Live it carries most of the
  comprehension work, which D2 calls the second of the two hard problems.
- **Design 9 (or 3).** Common region beats proximity (Palmer 1992; NN/g), and only when rows give up
  their own boxes; 3 does exactly that. 9 adds the lab's language, so the menu and the prototypes it
  opens (the range, the Creation Lab) read as one product, and its accent-bar cards carry the system
  colour on every row, not only the selected one.
- **LAB palette.** Same argument: it is what the lab and the range look like.
- **Avoid in any copy** (from Notion): "fun" (out of scope until production), gameplay claims,
  "ARC", an engine brand name (pending).

## The journey (proposal)

Learn to read before being shown how it is made: **Live it** (Crosswise reads a slice, Phase Maze and
4D Ascent move through W, the Shooting Range acts across it), then **Fill it** (the Creation Lab and
the Arboretum: how 4D content is made), then **Build it** (the Voxel Lab: the engine under load),
then **the world**, where all three run together. The list is already in that order, the kicker
counts it ("04 / 07") and auto-advance follows it. To make it visible: a "NEXT" tag on the next
unseen prototype, and "n of 7 seen" on the banner.

## Research sources

- NN/g, Proximity and Common Region: https://www.nngroup.com/articles/gestalt-proximity/ ,
  https://www.nngroup.com/articles/common-region/
- Palmer (1992), common region overrides proximity and similarity: https://pubmed.ncbi.nlm.nih.gov/1516361/
- Laws of UX, uniform connectedness: https://lawsofux.com/law-of-uniform-connectedness/
- Material dividers and subheaders: https://m1.material.io/components/dividers.html ; M3 segmented
  lists: https://pub.dev/packages/m3e_segmented_list
- Apple inset grouped lists: https://developer.apple.com/documentation/swiftui/liststyle/insetgrouped.md
- WCAG 1.4.1, colour not the only cue: https://www.w3.org/WAI/WCAG21/Understanding/use-of-color
- Chrome tab groups (one colour per group): https://read.cv/cleer/tab-groups
- Teenage Engineering OP-1 colour coding: https://teenage.engineering/guides/op-1/original/layout
- Linear's divider clean-up: https://linear.app/now/behind-the-latest-design-refresh
- Notion (read only): D2 Twelve-Month Plan, D3 RFP, D1, Gap audit, Work Log (3 to 6 Oct copies;
  D2 and D3 are live in Google Docs).

## Checks

- `Menu/_verify_menu_final_runner.gd`: the menu's own checks (the groups, the kicker, VIDEO N/A, no
  map tab, Crosswise on top and Esc back). The pen's leg (banner into the pen, Trym's laptop back)
  only with `-- pen=1`; it fails until the pen's laptop path is updated (World/TrymCabin/...), left
  for Ramon's pen branch.
- `Menu/_verify_menu_designs_runner.gd`: every design in both groupings launches 4D Ascent and
  comes back on Esc; "A" a second time through its ROUTE switch. **Not to be run for now** (Ramon,
  8 Oct): the menu's interactive part (launching, coming back) is very broken and he deals with it
  later, and ~170 launches grab his mouse. While the menu is being designed: frames only
  (`_capture_menu_designs_runner.gd`). Last run 8 Oct, cut short: 285 pass, design 6 once slow to start.
- `Menu/_capture_menu_designs_runner.gd`: frames of every design and palette
  (`-- only=<n> group=1 hud=1 tag=<x>`). `Menu/_capture_menu_review_runner.gd`: before/after frames.
