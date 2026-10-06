# The pen's dev look: case study and intermediate plan

6 Oct 2026. Nothing in the pen is changed by this study. The tests ran live in the running pen
through a probe (`PenLayout/scripts/dev_look_probe_4d.gd`, driven by `_capture_pen_runner.gd` sets
`devlook`, `devcold`, `devboxes`, `devart`). Frames: `smoke_test_output/pen_layout/devlook/`,
`devcold/`, `devboxes/`, `devart/`. Summary sheet: `PenLayout/refs/analysis/dev_look_study.png`.

## The ask

Ramon: toggle the whole pen to an R&D look (white ground, path arrows on, white mountains,
landmarks all blue or all red), instantly, with every mechanic still working. Any change in the
detailed world must show in the greybox, and ideally the other way round (move the Watchstone's big
cube, the Watchstone moves). Landmarks might swap for a block or another scene while staying aligned
and linked. The pen opens in the dev look, with the art as an option button.

## What's already agreed

- `follow_up/startup.md` section 3: "The exception is the playable world. It gets both a dev look
  and a reasonably fleshed-out game look, switched by a toggle." So the two looks in one world is
  the standing direction; this study is about how.
- Pieces exist already: the paths have a dev look (white strips, the sheet's blue arrows;
  `scripts/pen_paths_4d.gd` `set_dev`), and the capture runner can lay the lab's white grid floor
  (`devfloor`, `LabKit/lab_grid.gd`).

## How others do it (online)

- **One level, layers you switch.** Unreal's Data Layers organise a level's actors into layers you
  load or unload in the editor and at runtime, so artists and designers work on separate layers of
  the same level ([Epic docs](https://dev.epicgames.com/documentation/en-us/unreal-engine/world-partition---data-layers-in-unreal-engine)).
- **Logic and graphics apart.** Unity teams split a level into a Logic scene (the designers'
  blockout and colliders) and a Graphics scene (the art), loaded together; the art pass lands on top
  of the blockout, which is then removed
  ([Unity forum write-up](https://discussions.unity.com/t/advanced-additive-scenes-multi-scene-editing-now-with-free-demo/538329),
  [multi-scene workflow](https://diversion.dev/blog/avoid-merge-conflicts-by-using-a-multi-scene-workflow-in-unity)).
- **Blockout first, art replaces it.** The blockout is the playable draft; the art pass keeps its
  dimensions, either retexturing the blocks or rebuilding them, and the blocks end up hidden or
  deleted ([Robert Yang, how to graybox](https://www.blog.radiator.debacle.us/2017/09/how-to-graybox-blockout-3d-video-game.html),
  [UEFN greyboxing](https://dev.epicgames.com/documentation/en-us/uefn/greyboxing-in-unreal-editor-for-fortnite)).
- **Godot's tools for swapping.** `InstancePlaceholder.create_instance(replace, custom_scene)` loads a
  different scene in a placeholder's place
  ([docs](https://docs.godotengine.org/en/latest/classes/class_instanceplaceholder.html)). Scene
  inheritance passes changes from a base scene down to scenes inherited from it, one way. The
  community advice is composition (parts added as child nodes) over inheritance for visual variants
  ([editable children vs inheritance](https://uhiyama-lab.com/en/notes/godot/editable-children-vs-scene-inheritance/)).
  Godot's own "visible collision shapes" is an editor debug option only, not for a shipped look
  ([forum](https://forum.godotengine.org/t/toggle-visible-collision-shapes-in-game/101875)).

The common thread: gameplay lives in one place, the looks are layers over it, and you switch the
layers rather than swap the world.

## What our engine allows (checked in the source and measured)

- **No render layers.** `Camera4D` has no cull mask and 4D nodes no layers (searched the module), so
  a look has to be switched per mesh.
- **Hidden costs nothing to draw, but the first draw costs.** A mesh builds its GPU buffers the first
  time it is drawn (`engine_capabilities.md`). Measured: the pen opened straight in a dev look, the
  first switch to the art froze **1.7 s**. Once drawn, switching is instant.
- **Mechanics read visibility.** These stop working if their node is hidden: the rune stone
  (`pen_rune_stone_4d.gd:56`), the laptops (`pen_laptop_4d.gd:67`), the Lookout's photo subjects
  (`photo_subjects_4d.gd`), the tutor's markers (`pen_tutor_4d.gd`), the slice dial's outlines
  (`pen_slice_plane_4d.gd:755`). **So a look must never hide a node.** It can take a mesh off its
  node, or lay a material over it: only the picture changes.
- **The editor already links a block to its landmark.** Clicking any mesh inside an instanced unit
  selects the unit's root, not the mesh (`editor_main_viewport_4d.cpp`, `_gather_non_empty_visible_mesh_4d_nodes`),
  and hidden meshes can't be clicked. So a block that lives inside a unit's scene is clicked and
  moved as the unit: move the Watchstone's cube in the pen and the Watchstone moves, because they
  are one node.

## The tests

Three dev looks built live in the running pen, each switched to and back:

| Look | What it is | Switch | Frame / GPU |
|---|---|---|---|
| Art | as it is | 12 ms + one 9 ms frame | 4.1 / 3.3 ms |
| **Clay** | every landmark's own meshes in flat blue (the things you use red), ground the lab's white grid, mountains white, paths' arrows | 21 ms + one 20 ms frame | 4.6 / 3.7 ms |
| Blocks | as clay, but each landmark drawn from its own colliders | 20 ms + one 31 ms frame | 3.4 / 2.6 ms |
| Boxes | as clay, each piece of art as its own box | 36 ms + one 56 ms frame | 3.9 / 2.5 ms |

- **Nothing broke.** In every look: 496 scripted nodes, none hidden; 208 colliders, all there. Back
  in the art the pen view matched the start to 99.2% of pixels (the rest animals moving).
- **One coupling seen:** after the round trip the paths showed fully revealed (the dev look shows
  every path; the "found as you go" state has to be kept apart from the look).
- **What each looks like** (sheet): clay reads at once as an R&D model of the same world, always
  right because it is the art. Blocks from colliders are a convincing blockout where colliders
  exist (the tower's tiers, the cave's door, the camp, the range) and wrong where they don't (the
  scenery, the marsh, the wood fell back to one huge box over everything). Per-piece boxes are the
  worst: the landmarks merge their pieces into a few big meshes, so the camp became a staircase and
  the Watchstone one slab. Rejected.

## Three ways to do it

1. **One world, two looks (recommended).** The pen stays one scene. A look system switches each
   landmark between its art and its dev look, by meshes and materials only. Instant, nothing to
   sync (there is one node per landmark), every mechanic untouched by construction. Unreal's Data
   Layers and Unity's Logic/Graphics split are this idea.
2. **Two scenes, flipped behind a loading screen.** A dev scene inherited from the pen gets every
   change to the pen for free (Godot scene inheritance, one way). But the flip reloads the world:
   every quest, caught chicken, talk and inventory has to be carried across, and the player's place
   and slice. That is the "hundred things breaking at once". Not recommended.
3. **Swap landmark instances for block scenes** (`InstancePlaceholder`). Each swap frees the
   landmark's node and its state with it (Wren's story, the range master, the camp's align). Only
   safe for props with no state, and the look system above already covers those.

## The recommended system

- **`Systems/Look` (`pen_look_4d.gd`, @tool):** `look` DEV or ART, DEV by default. Switches:
  - the ground (through the Grass node's API, not its material: the Grass caches the ground's own
    material on first paint, and a dev floor laid under it would become "own");
  - the mountains and the two round hills (white);
  - the paths (their dev look, keeping the found-as-you-go state apart);
  - every landmark (below).
  Reads `look=dev|art` from the command line, so every test runs in either look. Key and button to
  switch.
- **Each landmark declares its dev look** (`LookPart` child in its unit scene, a few lines): which
  meshes are its art, its role (landmark blue, used red, character untouched), and an optional
  **authored blockout** node inside the unit scene. No blockout: clay. Explicit roles replace the
  probe's guessing by script names.
- **Never hidden, only swapped.** Art meshes have their mesh taken off (kept) or a flat material laid
  on; blockout meshes are the reverse. Visibility is left alone.
- **Rebuilt meshes follow.** Units that build or rebuild meshes at runtime (the Watchstone's stones
  after a green rebake, the range, the camp) get the current look applied to what they add.
- **No 1.7 s freeze.** At load, the art is drawn once under the opening fade, then the pen switches
  to dev, so the first switch to the art is as instant as the rest.
- **The editor.** The look shows in the editor too. Saving the scene must never store a dev look:
  the look puts the art back before Godot saves and re-applies after (pre- and post-save
  notifications), the same trap as the 4D editor saving whatever mesh a node holds.
- **Authored blockouts start from the colliders.** A tool button on a unit writes its colliders out
  as a blockout node to reshape (the cave as a wedge with its door, the tower as block, deck and
  stairs). Saved in the unit scene, so it moves with the unit.

## Intermediate plan

### Phase 1: the look, with clay (one session)
1. `pen_look_4d.gd`: the DEV/ART switch, the ground through the Grass node, mountains and hills
   white, paths through `pen_paths_4d.gd` with the reveal state kept.
2. Clay for every landmark, roles taken from a first `LookPart` per unit (seven units, the camp,
   the stone wall, the oak, the egg cairn, the pickups).
3. The look applied to meshes added later (rebuilds, the green rebake).
4. The warm-up under the opening fade; measure the first switch.
5. The switch: a key and the button where you want it (question 2); the pen opens in DEV.
6. `look=` on the command line; frames of both looks from the study's viewpoints.

### Phase 2: proof that the mechanics carry over
7. The pen's tests run in DEV and in ART: today's passing set (about 30 of the 118 runners, many
   stale) in both looks, compared with today's results.
8. A playthrough script in DEV: the start, the cave, the crossing, the Lookout's walk-up and a
   photo, the range trip, the camp's align, back.
9. The couplings list kept in this file: what reads visibility, materials or meshes, and how each
   is handled.

### Phase 3: authored blockouts where clay is not enough (your call per landmark)
10. The "colliders to blockout" tool button on a unit.
11. Blockouts for the landmarks you pick: the cave (wedge with door), the Watchstone (block, deck,
    stairs), Trym's shed, the range, the camp, the rock pile; the marsh and the wood as flat plates.
12. Check in the editor: click a blockout in the pen, move it, and the landmark moves with it;
    open the unit and both looks are there.

### Phase 4: the editor and the save trap
13. The look in the editor (@tool), with the save guard; save in DEV, reopen, nothing lost.
14. A one-way generated `playable_world_dev.tscn` only if you still want a separate file (an
    inherited scene that opens in DEV; nothing to keep in sync).

### Phase 5: hand-over
15. Frames of both looks, numbers, the couplings list, `follow_up/` handover, memory notes, commits.

## Questions for Ramon

1. **Colours.** All blue, or blue landmarks with red for what you use (the rune stone, laptops,
   pickups)? And "like the pen": which part of the pen did you mean for the colour?
2. **The button.** Where: the pen's HUD (with the grass panel, or the controls card), the main
   menu's PLAY THE WORLD, or both? Which key?
3. **Clay or blocks per landmark.** Clay is free and always right; blocks need authoring per
   landmark. Which landmarks should get real blockouts?
4. **The sky and light in DEV.** Keep the pen's sunset, or the Creation Lab's bright dev light?
5. **Creatures in DEV.** Keep the starlings, crows and animals as they are, or simplify them too?
6. **The menu's banner** shows the pen: DEV or ART there?
