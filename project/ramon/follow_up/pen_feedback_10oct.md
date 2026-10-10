# Playable world: Ramon's 10 Oct walkthrough feedback (handover)

Ramon's `D:\depot\feedback docs\world.docx`, parts 1 to 4, items 1 to 32, built into `chickenpen/playable_world.tscn`
on 10 Oct. Backup of the scene and the path graph from before this round: `chickenpen/.backup/2026-10-10_before_feedback_round/`
(every other changed file is in git at 3afee43).

## Questions for Ramon

1. **The pedestal (items 30-32), settled the same afternoon.** First a stone altar (your Alternative B) with a
   sci-fi cylinder beside it for comparing; then, from your reference picture, the "temple" pedestal: the reference's
   pedestal from its sloped skirt up (base block, a tall square shaft with a raised frame, a bronze boss and a carved
   glowing mark on its front, a band, the capital, the top slab), on a thin round stone plaque, with a small pillar of
   the same design either side. You then asked for the plaque much thinner and the little blocks under the top slab
   gone (gone on the small pillars too, to keep them the same design). The comparison cylinder is removed. The altar
   and the old column are still in the script (`style`), not in the scene.
2. **The campsite NPC's two places (items 19-20).** Tamsin at her fire (farm's slice) tells you about the balloon and
   the price; her twin stands by the grounded balloon at its W and takes the 2 azoth. After the ride the balloon lands
   back on its sand at W 5, so every ride is bought from her twin. OK, or should it come home to the farm's slice?
3. **Resizing in the layout editor** scales a card (text included), since the cards draw their own content at their
   own sizes. Is scaling enough, or do you want true width and height for some cards (that means changing each one)?
4. **Tree foliage (item 17)**: a quarter more leaves cost 0.16 ms of GPU in the densest view, so it is in.

## What changed, by item

| # | What | Where |
|---|---|---|
| 1 | The Dream Shifter sequence: kept as it was. | |
| 2 | The bookshelf's dev box is the landmark orange. | `look/pen_look_4d.gd` `_blockout(part, "orange")` |
| 3 | The cave road's card: "Face the hillside. Step through W to reveal the entrance.", the animated card every time, two beats (the mouse looking round, then the E/Q keys). | `World/WHints/CaveRoad`, `discovery/pen_mouse_card_4d.gd` (new `look_h` gesture), `pen_w_guide_4d.gd` (`w_hint_card_always`, `w_hint_acts`) |
| 4 | Professor Miner: "There's an opening in the hillside next to me. You might need to shift through W to find it." and "You already have an X-Pick. Press 1 to use it." | `scripts/professor_script.gd` |
| 5, 14 | Three eggs in the pen, across W: two white (W +2.2, W −2.6), one golden (W −3.4). Walk into them at their W; confetti, a toast ("An egg! 1 of the pen's 3 eggs"), into the belt. | `World/Pickups/PenEgg*`, `scripts/pen_pickup_4d.gd` (`WHITE_EGG`), `scripts/pen_collector_4d.gd` |
| 6, 7, 15 | The belt: two connected rows of five on one dark glass panel, flat silhouettes (purple gem, pale grey egg, gold egg), counts in the corner, one line under it for what is in hand. Keys 1 to 5 choose the top row. | `scripts/pen_inventory_4d.gd` |
| 8, 9 | The controls card: two groups side by side (Move to Esc; the shortcuts) with a thin rule; the two sizes in their own bracket beside the camera picker, "dial size / locator gizmo". | `scripts/pen_controls_4d.gd` |
| 10 | F2: move and size the HUD cards live; Save UI Location / Reset UI Layout; saved to `user://pen_ui_layout.cfg` and applied on load. The dial is left alone. Reusable: `CreationLab/LabKit/ui_layout_editor.gd`. | `Systems/UiLayout` |
| 11 | F1: the minimal HUD (the dial, the belt, the mode badge, and the play's own prompts). | `Systems/MinimalHud`, `scripts/pen_minimal_hud_4d.gd` |
| 12 | The mode switch, centred at the bottom (changed the same afternoon, your words: "just DEV / ART ... one of the button sides look like its activated ... under the button 'I to switch' just as text"): one pill, DEV and ART, the active half filled in its colour (blue, gold), the fill sliding across on a change; "I to switch" under it. A click on a half picks it. | `UI/LookBadge`, `discovery/dream_shifter/pen_look_badge.gd` |
| 13 | At the pen's entrance: the animated card, "Move through W to discover what's hidden inside the pen." | `World/WHints/PenPlatform` (there was no platform in the scene: the spot is the pen's entrance, by the fence's gate side) |
| 16 | The road from the pen's junction now ends at an orange pivot ball short of the wall (no more line diving under it). Reaching it: a 3.6 s camera move up and over the wall to the far side, then the card "Find a way past the wall through W." The wall is solid now (it had no collider): you are held out of its slab, the gate stays open. | `World/WallPivot`, `discovery/pen_wall_pivot_4d.gd`, `PenLayout/paths/pen_b.tres` (node 26) |
| 17 | The big and medium oaks have a quarter more leaves: measured 6.65 to 6.81 ms GPU over the start's oak belt (+0.16 ms), so it stays. | `scripts/pen_oak_4d.gd` `LEAVES`, `discovery/_perf_leaves_runner.gd` |
| 18 | The balloon sits on the ground at its W (5 m ana) on a sand patch; the first V find says "Whoa! You discovered a balloon!" | `lookout/balloon_4d.gd` (`park_rise` 0), `World/BalloonCrew/LandingSand`, `discovery/pen_balloon_finder_4d.gd`, `discovery/pen_discovery_toast.gd` |
| 19 | Tamsin: reach 3.4 m (was 2.6), a collider for her and her log. | `discovery/pen_balloon_crew_4d.gd`, `Systems/BalloonCrewDriver` |
| 20 | The ride costs 2 azoth, paid to her twin by the basket ("Fancy a balloon ride? It'll cost you 2 azoth." Yes. Pay 2 azoth / No. Maybe later; or "The ride costs 2 azoth, mate. Come back when you've got enough."). One payment, one ride; boarding (B or F) waits for it. | `discovery/pen_balloon_crew_talk_4d.gd` (one driver, two roles), `balloon_ride_script.gd`, `balloon_crew_script.gd`, `lookout/lookout_4d.gd` `can_board` |
| 21 | The airships are gone; four hot-air balloons drift in the sky instead (one in the farm's slice, three 9 m ana), earthy muted colours, one shared envelope mesh and a basket each, out of the projection. | `World/SkyBalloons`, `discovery/pen_sky_balloons_4d.gd` |
| 22 | The trail to the cache now starts from the north side of the camp's ring (left of your approach) and is a solid striped route, not dots. | `pen_b.tres` (nodes 27, 23) |
| 23 | The "floating white gem" is the kata cache's glint at its mouth; the cave is 7.5 m ana. Now: "V  Align to the opening" once part of the chamber shows, V takes your slice there, F opens the chest (10 azoth). | `discovery/pen_kata_cache_4d.gd` |
| 24 | At the research camp, looking out east over the meadow, once: "That's a beautiful stretch of grassland. I wonder what's out there?" | `Systems/MeadowThought` |
| 25 | The edge-on door: walking through the slit at W 0 now takes you to the top of the Watchstone too; turning toward it brings "V  Align to the door", which turns your slice the rest of the way so the whole arch stands there. | `discovery/pen_w_door_4d.gd` |
| 26, 27 | A strange clock at the meadow's far edge, 1.8 m ana (a chip after lingering): "A strange clock! Hey, this looks interesting. Maybe Mithra would like it." Mithra takes it: "Oh, that's wonderful! ... You know, when I need to relax, I sometimes fly above the world as a hawk. Try pressing U." (U already existed, always on.) | `World/Pickups/MeadowClock`, `dialogue/mithra_script.gd`, `scripts/pen_mithra_talk_4d.gd` |
| 28 | The wall's posts and ribs sit just above its top now (posts 0.83, ribs 0.95, the wall 0.945 of the post). | `World/TownWall` |
| 29 | The wall's stone: courses of blocks with darker joints, each a little lighter or darker, the whole darker at the foot; a small 3D texture made on load. | `Systems/TownWallLook`, `scripts/pen_town_wall_look_4d.gd` |
| 30-32 | The stone altar (see question 1). | `discovery/dream_shifter/pen_dream_shifter_4d.gd` (`style`) |

## What was checked

Played through by runners, frames looked at (`smoke_test_output/feedback_10oct/`, `feedback_10oct_b/`,
`dream_shifter/pedestal/`, `feedback_10oct/hud4k/`), 10 Oct afternoon:

- `discovery/_verify_feedback_runner.gd`, **27/27**: the door through the slit and by V; the balloon grounded at W 5,
  found by V with its toast; Tamsin from 3 m, her collider; no boarding unpaid; her twin; 2 azoth paid (3 to 1), the
  ride starts, lands back on its sand, the next ride needs paying again; the pen's card; all three eggs at their W;
  the cave's card; the pivot's camera move and control back; held out of the wall at W 0; the cache's V to W 7.5.
- `discovery/_verify_feedback2_runner.gd`, all pass: the switch and I; the controls card wider than tall; the sizes'
  bracket; F1 hides and restores; F2 on, a card dragged, Save writes the layout, Reset puts it back and deletes it;
  the meadow thought; the clock chip, the clock in the belt, Mithra takes it and names U.
- `discovery/_verify_discovery_runner.gd` (art and dev) and `dream_shifter/_verify_shifter_runner.gd` (art and dev):
  still all pass. The dev look with the projection on: no "Too many instances" (the eggs, the clock and the pivot ball
  had taken it over the engine's limit; they are out of the projection now).
- The HUD at 3840 x 2160 and 145% (`discovery/_shot_hud4k_runner.gd`): no two cards overlap. At 1920 x 1080 and 145%
  the screen is too small for everything (the controls card then steps under the to-do list).
- The oaks: 6.65 ms GPU as they were, 6.81 ms with a quarter more leaves (`discovery/_perf_leaves_runner.gd`).
- The wall's stone: the first try (a tiled stone texture) showed nothing, because the wall is one texture island and
  the texture is clamped; a loud test texture proved the coordinates reach the wall (`discovery/_probe_wall_runner.gd`),
  and the gradient is now packed into the band the wall uses.

## Notes

- `PenLayout/scripts/_make_pen_paths_b_runner.gd` still regenerates `pen_b.tres` from scratch and would undo the path
  changes of both rounds (and Andrew's gate nodes). Do not run it.
- The camp guide (the Camp Scout on the camp road) was not touched.
- The gate road's W hint (`GateRoad`) went with the road's dive; the gate's crossing (nodes 19 and 20) is still there.

## Parts 5 and 6 (10 Oct, evening): items 31-44

| # | What | Where |
|---|---|---|
| 31 | The DEV / ART switch stays hidden until the Dream Shifter has explained it; I works all along. | `discovery/dream_shifter/pen_look_badge.gd` |
| 32 | The belt a size up (slots 66, were 56); the pickaxe icon upright (haft down the middle, head across the top). | `scripts/pen_inventory_4d.gd` |
| 33 | The pedestal is a small dark-stone ritual site (style "ritual"): Göbekli Tepe's T-pillar under the crystal, a ring of seven leaning standing stones open toward the road (two of them small T-pillars), uneven slabs underfoot, loose stones behind, two stones ana and kata. No rune. The "golden egg stuck in it" was the temple pedestal's bronze boss: gone. | `discovery/dream_shifter/pen_dream_shifter_4d.gd` |
| 34, 44 | The wall: no texture any more; one medium gray (posts and ribs a touch darker). | `scripts/pen_town_wall_look_4d.gd` |
| 35 | By the hillside with the hidden cave door, the animated card again ("The opening is in this hillside. Step through W to find it."), until the door is in your slice. | `World/WHints/CaveHill` |
| 36 | The cave road's card fires on the road before the professor, as you come by (it sat beside him and seemed to follow talking to him). The gate's is the wall moment (38, 39). | `World/WHints/CaveRoad` |
| 37 | The eggs are one stretched 24-cell each (were eight boxes); white and gold kept. | `scripts/pen_pickup_4d.gd` |
| 38, 39 | The wall moment: no orb; it starts by itself within 5 m of the wall; a wide shot from high behind you, up and over the wall to far above the other side; then a close shot and the thought "My path is blocked. I need to find another way through W."; then the W card. Skippable (Space, Enter, F, click) after 1.2 s. The wall stays solid. | `discovery/pen_wall_pivot_4d.gd` |
| 40 | The cache's floating white glint is gone (the chest and its V stay). | `discovery/pen_kata_cache_4d.gd` |
| 41 | The sky balloons drift on 55 m by 26 m loops, about five minutes round, rising and sinking a few metres. | `discovery/pen_sky_balloons_4d.gd` |
| 42 | The block over the player's head was the outfit's joke hat, the Hypercube (hat 5 in your saved outfit, `user://pen_outfit.cfg`, chosen in Trym's fitting room). Your saved hat is the cap again; nothing else in the outfit changed, and the hat is still there to pick. | your `pen_outfit.cfg` (no code change) |
| 43 | The grounded balloon offers "V  Align to slice" whenever about 70% of it shows, every visit (it stopped once it had been found); her twin by the basket talks only once you are aligned (slice flat, within 30 cm of its W). | `discovery/pen_balloon_finder_4d.gd`, `discovery/pen_balloon_crew_talk_4d.gd` |

Checked by play the same evening: `_verify_feedback_runner` 27/27 (with the wall moment starting by itself 5 m out and
giving control back), `_verify_feedback2_runner` all pass (the switch hidden before the Dream Shifter and shown after),
`_verify_discovery_runner` (dev, projection on: no mesh-limit errors), `_verify_shifter_runner` (art).
