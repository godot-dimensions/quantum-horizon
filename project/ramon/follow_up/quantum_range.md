# Quantum Range (Ramon's shooting gallery): study, 5 Oct 2026

What it is, how it is built, what is broken today, and what the team's own gallery has that
this one doesn't. Read-only study: nothing in the range was changed. Frames are in
`res://smoke_test_output/range_study/` (`compare_aug_vs_today.png` first).

## Where it is and how you reach it

- Scene: `res://ramon/ShootingGalleryRamon/shooting_gallery_ramon.tscn`. CLAUDE.md still
  places it in `sandbox/shooting_gallery/`; it moved to its own folder on 18 Aug (393e2f4).
- Every script it runs is its own copy in `ShootingGalleryRamon/scripts/`. The team's
  `sandbox/shooting_gallery/shooting_gallery.tscn` runs the `res://scripts/` originals, so
  the two scenes share no gameplay script. They do share `res://player/player.tscn` and
  `ramon/Demo/return_button.tscn`.
- **From the menu:** "Quantum Range", Tour section, Playable. Its clip is from 25 Aug.
- **From the pen:** the range master's trip (`chickenpen/scripts/pen_range_trip_4d.gd`)
  parks the pen and makes the gallery the current scene. `range_way_home_ramon.gd` relabels
  the H prompt to "BACK TO THE CHICKEN PEN".

## How it is built

- **The room:**
  - The player stands on a black tile floor (60 one-metre tiles, z 5 to 11) behind a
    hazard-striped barrier at z = 5.
  - The play area is a 20 × 10 blue floor (z -5 to 5).
  - Both floors and the barrier are 10 m thick in W.
  - A "holodeck" of 341 black tiles (ceiling and four walls, 88 m across, 24 m thick in W)
    stands in for a sky. There are no lights: every material is swapped to the old flat
    shading (`FlatShadingRamon`).
- **The player:** the project's shared first-person `player.tscn`.
  - It spawns with a 1.7° turn in xw. That is deliberate: a surface lying exactly on the
    slice divides by zero in the shader (`ray_beam_ramon.gd`'s header explains it).
  - Keys: WASD, Q/E along W, mouse look; hold RMB and move the mouse to turn the slice.
- **The weapon** (`hitscan_weapon_ramon.gd`):
  - Hold LMB to charge for up to 3 s. On release it fires a burst of 1 to 6 hitscan shots
    0.12 s apart.
  - Hold past 3 s and the charge is wasted.
  - The shot is a real 4D raycast (`RaycastParameters4D`, `collide_with_areas = true`)
    from the head.
  - Each shot shows a 4D box beam, and a poof on a hit.
  - The gun core is a 600-cell turning in xw and yz, and it glows redder as it charges.
- **What you shoot.** All of them are `Area4D` with box hitboxes, moved by setting
  position. The checks run in this order:

  | Thing | Script | Behaviour |
  |---|---|---|
  | Yellow cube | `gallery_target_spawner_ramon.gd` | One at a time, random in x ±8, y 1–2, z ±4, w ±4. A catch times you (T shows the stopwatch). |
  | Ducks | `duck_row_spawner.gd` | A conveyor on a diagonal in x and W at z = -2, one every 2.5 s. Not scored. |
  | White and grey blockers | `shape_blocker_spawner_ramon.gd` | 16 shapes (box, orthoplex, 5-, 24-, 120- and 600-cell, torisphere, spheritorus, cylinder) that drift and wobble. White: 1 hit. Grey box and cylinder: 2 hits. Each respawns in another slice. |
  | Black monolith | `black_stalker_spawner_ramon.gd` | Appears 5–12 s in at z -28, off your slice in W, and chases you, speeding up to 13 m/s over 35 s. It drifts in W at 15% of its speed and hums louder as it nears. 8 hits send it away; a touch flashes GAME OVER for 3 s and play carries on. Moved with `move_area` so its touch signal fires. |
  | Green spheres | `green_sphere_spawner_ramon.gd` | Up to 3, each shows for 6 s, darting in all four axes. 1 hit. |

- **The HUD:**
  - Top left: a legend (`instructions_overlay_ramon.gd`) and the result labels.
  - Left: the charge bar.
  - Bottom centre: the slice radar (`slice_radar_ramon.gd`, the shared one with a yellow
    target). It draws the slice as an ellipse with distance rings, a stem for W offset and
    the monolith as a square.
  - Edges: a green glow (`slice_alignment_glow.gd`) as the yellow cube comes into your
    slice.
  - Bottom left: the H prompt back to the menu.
  - The tutorial billboard (`textures/tutorial/testrange2.png`) stands to your left.
- **Cost:** 428 mesh instances, all on the flat shader. 1.33 ms a frame at 1280×720 with
  vsync off, standing at spawn (RTX 5080, 5 Oct).

## Found on 5 Oct

1. **The textures have been broken since 30 Sept.**
   - `FlatShadingRamon` uses `PhaseMaze/shaders/phase_maze_flat_shaded.gdshader`. That
     copy's vertex stage reads two texture corners from `COLOR`. Since godot-4d `b288c8d`
     the engine packs them into the bone weights (`engine_capabilities.md`).
   - Seen side by side (`compare_aug_vs_today.png`): the walls had a fine grid with cross
     marks on 25 Aug; today they show a broken grey and black triangle pattern, and so do
     the floor tiles.
   - The same file also shades Phase Maze directly, and Portal and Impossible Bypass
     through `FlatShadingRamon`. One fix in that shader mends all four. Copy the vertex
     stage from `CreationLab/LabKit/shaders/lab_surface.gdshader`.
2. **Text over text, top left.** The shared player's "Player position: ..." label (8, 4)
   prints over the legend's first line. The "Last catch" label (8, 64) lands among the
   legend lines too. Seen in `01_spawn.png` and `08_hud_after_catch.png`.
3. **The billboard sits on the edge of your slice.** It hangs at w -1.9 with a half
   thickness of 1.8, so at spawn the slice cuts it by 5 cm. A small step ana (E), or a few
   degrees of slice turn, hides it. Seen in `03` to `05`.
4. **Esc from the pen route lands on the old team menu.** The shared `player.gd` sends
   `ui_cancel` to `res://menu/main_menu.tscn`. `menu_final` catches Esc first when it
   launched the range, but the pen's trip does not. Esc there loses the parked pen and the
   way home. Found by reading, not played.
5. **Dashes in player-facing text:** the legend ("CHANGE SLICE - IT WILL"), the charge
   hint ("CHARGE - RELEASE TO FIRE") and the menu card's finding ("cannot see - and it
   reads as fair").
6. **The menu card has no measurement.** The other cards carry measured numbers. Its
   benchmark repeats its approach, and "it reads as fair" was never tested.
7. **Small leftovers:**
   - A stray unnamed 1 m black box at z 14.2, behind the spawn.
   - Holding RMB also prints a raycast to the console (a test left in the shared
     `player.gd`).
   - The HUD uses Godot's fallback font, not Montserrat.
   - Three places list the controls: the legend, the billboard and the charge hint.

## What the team's gallery has that this one doesn't

Trym's `sandbox/shooting_gallery/` (18 Aug, after this fork):

- `w_targeting.gd`: the mouse wheel cycles targets and the slice keeps turning so the
  chosen target, or it and a neighbour, stays in view.
- `contest/`: timed spawn sequences with a results overlay.
- `bullseye/`: a rail-driven range with its own stats HUD.
- `hud/combat_stats/`, `weapon/ammo_pips/` and a `radar_orb/` HUD.

Per CLAUDE.md, anything taken from it is copied into this folder as a `_ramon` fork, never
edited in place.
