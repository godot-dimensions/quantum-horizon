# The menu

**The master is `res://ramon/menu_final.tscn`.** It is the project's menu, and since 9 Oct 2026 it has one design, "A", listing the prototypes in two families: THE LABS and THE EXPERIMENTS, set per entry by `MenuEntry.family` and named in the catalogue's `family_names` / `family_lines`.

| File | What it is |
|---|---|
| `scripts/menu_a.gd` | **The look.** Header and footer, the list, the route, the world's card, how a row lights up, the light / dark and LIST / ROUTE switches. |
| `scripts/menu_final.gd` | **The working parts.** Catalogue, selection, keys, the details pane, previews, launching and the way home, the window. Also A's two palettes. |
| `scripts/menu_load_board.gd` | **The loading screen**, from the click until the prototype is there, in the Voxel Lab loading board's style (code blue, its grid, white type, the line along the foot). One white fade, at the very end: a scene with its own board (a CanvasLayer named `LoadBoard`, like the Voxel Lab's) takes over blue to blue and does the white itself; any other scene gets this board's white. |
| `entries/catalogue_final.tres` | **The words.** Every prototype, its text, order and media. The menu's own copy (Menu, Menu2 and the Frontier Map read `catalogue.tres`). |
| `style/menu_final_style.tres` | Type scale, spacing, the details pane's measures. |

**Reference only, do not develop:** `res://ramon/menu_variations.tscn` (scripts `menu_variations*.gd`) is the 8 Oct design review frozen on 9 Oct: 41 designs behind Tab, A among them. It still reads the shared catalogue, style and MenuEntry, so it can drift if those change. `menu_final_temp.tscn` is an older snapshot (before the grouping).

**Checking a change:** frames only, `_capture_menu_final_runner.gd` (white and dark, list and route, three selections), compared with the last good set; `_capture_menu_loader_runner.gd` for the loading screen (put up directly, nothing launched, with the Voxel Lab's board drawn beside it for the style). No launch tests for now: the menu's interactive part is broken and gets fixed separately.

Handover and history: `ramon/follow_up/menu.md`.
