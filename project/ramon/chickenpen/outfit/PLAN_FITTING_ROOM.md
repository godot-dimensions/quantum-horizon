# The fitting room: Ramon's version (8 Oct 2026, evening)

Ramon, watching the in-world circle:

> "this presentation feels subpar. It be that we need to create a seperate tscn just for the swap
> function. like on the left he stands on a panel, and on the right is a rotating pants in a certain
> color. with easier keystrokes because now we have little availability. a seperate tscn might also
> prevent breaking the scene or adding complexities and make us have a proper UI that shows what we
> can do with enough space and stuff. teleport the settings back into the pen and voila."

Then: "on the other hand i also like it", and then "Finish what you did ... but make my option
separately as a function i can check ... my version then with plan, and start executing".

So:
- The circle stays exactly as it is (finished, committed `953b2c6`).
- This is a second way of dressing, beside it, that he can switch to and compare.
- It is a scene of its own: `chickenpen/outfit/fitting_room.tscn`.

## The idea

**Trym's fitting room.** In the circle, Enter takes you there in a cyan flash. The scan still runs
first, as the doorway. You arrive in a small white lab room:
- **On the left,** you stand on the lab's pedestal, full size, facing out.
- **On the right,** on a second pedestal, the one piece of clothing you are changing turns slowly,
  twice life size. The trousers, say, in cobalt, with its name under it.
- **The back wall** is the lab's blue teaching wall, its title painted on.
- **A black-glass panel down the right of the screen** has room for everything:
  - the six parts as numbered buttons;
  - the styles as named buttons;
  - the colours as big swatches;
  - Surprise me, Undo and Done.

You can use the mouse, or easy keys: 1 to 6, the arrows, Enter. Done saves and puts you back in the
circle on the farm, dressed. The pen never knew anything happened.

## What it reuses, and what is new

**Kept as it is:**
- the store and palettes (`outfit_4d.gd`);
- the wearer (`outfit_wearer_4d.gd`, which paints any block figure);
- the hats (`outfit_pieces_4d.gd`);
- the keeper, which dresses the pen's player on the way back.

**From the lab kit, read only:**
- `lab_room_4d.gd`: light and sky;
- `kit_room_4d.gd` and `kit_wall_text_4d.gd`: the white room, and the blue wall with its painted
  type;
- `kit_pedestal.gd`: the pedestals;
- `kit_style.gd`: black glass, white type, the code blue.

**New, all in `chickenpen/outfit/`:**
- the room scene and its script;
- the garment display;
- the panel;
- the trip from the pen and back;
- an Enter key and a switch on the circle;
- runners.

## Research, for this version

- **Fortnite's locker** turns the chosen item on its own beside the character. Its redesign drew a
  backlash for raising the clicks a change takes. Changing anything here takes one click or one key.
- **Fall Guys and Among Us** keep the character big on one side and the choices on the other, with
  swatches as large targets.
- **The research's rules carry over:**
  - live on the real figure, no confirm;
  - an undo to what you arrived in;
  - the selection marked by shape, not only by colour;
  - curated palettes.
- **Ramon's lab rules** (memory, 4 and 5 Oct):
  - nothing in front of the exhibit (the panel stays clear of both pedestals);
  - no text that resizes with distance (all words are fixed-size, on screen or painted on the wall);
  - rotate the exhibit, not the room;
  - blue for teaching walls, black glass for screens;
  - a numbered box is a button;
  - big, cinema scale, not tiny platforms.

## The plan

### A. Ground (1 to 6)

1. Write this plan, and keep the circle's version untouched.
2. Read the lab kit's room, wall text, pedestal and style (done), and the laptop trip's parking of
   the pen (done).
3. Pick the layout by measurement in a frame:
   - the camera fixed, the figure about a third in from the left, the garment just right of centre;
   - the panel on the right 32% of the screen, over the room's empty right side.
4. Every key free in the room: nothing of the pen runs there, as the pen is parked.
5. Fix the scope: the room is for the player's outfit only, the same six rows as the circle.
6. A test save file for every runner, as before.

### B. Getting there and back (7 to 14)

7. `outfit_room_trip_4d.gd`: a CanvasLayer on the window's root, as the laptop trip is.
   - `go(room_path)` notes the WorldEnvironment4D in use, the pen's camera and the mouse mode.
   - It flashes to a pale cyan.
   - It takes the pen out of the tree, holding it, not freeing it, and makes the room the current
     scene.
   - It fades back in.
8. `come_back()`:
   - flashes;
   - frees the room and puts the pen back;
   - makes its environment current and its camera current;
   - gives the mouse back;
   - fades in.
9. The circle opens the room on Enter while you are dressing (`open_room()`), shown on its hint line.
10. A switch on the circle, `opens_room` (off by default): when on, the scan ends straight in the
    fitting room. Ramon can flip it in the editor to try his version as the only way.
11. Parking the pen ends the circle's dressing cleanly (its `_exit_tree` already saves and gives
    back input and camera). On the way back, you are standing in the circle, which waits for you to
    step out.
12. The room works on its own too (F6 in the editor). With no pen to return to, Done just saves
    and says so.
13. Esc: back to what you came in wearing, then home (cancel).
14. The trip never changes the window's size or scale (the room uses the window as it finds it).

### C. The room (15 to 20)

15. `fitting_room.tscn`: root `FittingRoom` (`outfit_room_4d.gd`), with:
    - `Room` (`lab_room_4d.gd`, bright, its own sky and light);
    - `Walls` (`kit_room_4d.gd`, a white room about 10 x 5 x 8 m, ceiling off);
    - `Lesson` (`kit_wall_text_4d.gd`, the north wall in code blue).
16. The lesson wall's words:
    - title "Fitting room";
    - one line: "What you wear here goes with you: the farm, the cave, the cinema.";
    - a short paragraph on why the hats are as thick through W as your head.

    Painted, not overlaid.
17. Two kit pedestals: the figure's on the left (radius 0.75), the garment's on the right (0.5,
    lower).
18. A fixed Camera4D, cross-section, framed so both pedestals and the figure's full height sit in the
    left two thirds.
19. The room has its own WorldEnvironment4D (the lab room's) and makes it current, so the farm's
    evening never leaks in.
20. Check it in the bright look, and also with the lab's B (dark), since the kit supports both.

### D. You, on the left (21 to 25)

21. A block figure with the player's own settings (the chibi build, eyes, shorts length): the pen
    Player's Avatar exports, read from the parked pen when there is one.
22. Dressed by its own wearer (`outfit_wearer_4d.gd`), so it is exactly what the farm will show.
23. It faces out. Q and E turn it round (a turntable under it). The mouse drags it round too.
24. A change lights the part on you for a moment (the wearer's flash), so you see what moved.
25. Your size in four directions in small type under you, the circle's 4D readout, kept.

### E. The garment, on the right (26 to 32)

26. A second figure, dressed by its own wearer, showing only the parts of the chosen row. Everything
    else has its mesh set aside (not hidden), so a rebuild cannot bring it back by surprise.
    - **HAT:** the hat, the costume or the hypercube.
    - **HAIR:** hair and crown.
    - **SKIN:** the head with its ears and eyes.
    - **SHIRT:** tunic and sleeves.
    - **TROUSERS:** the waistband, and the legs when long.
    - **SHOES:** the boots.
27. Twice life size, centred over its pedestal by its own bounds, so a hat and a boot both sit at
    the same height.
28. Turning slowly, about 30 degrees a second, the exhibit turned and not the room.
29. "Turn through W" on the panel (key T): the garment also turns through W, so you see its slice
    change. Off by default.
30. Its name under it, large and fixed: "TROUSERS  Long, Cobalt".
31. A change swaps it in place, and the new piece grows in from 90% over a fifth of a second, so
    the change reads.
32. The hypercube turns through W on its own already; on this pedestal that is the point.

### F. The panel (33 to 40)

33. Black glass (`kit_style` UI_GLASS), white type, the code blue for what is chosen, Montserrat.
    Right edge, full height minus margins, about 32% wide.
34. **Parts:** six numbered buttons in two columns, "1 Hat" to "6 Shoes", the chosen one in code blue.
    Keys 1 to 6.
35. **Style:** named buttons (Cap, No hat, Beanie, Top hat, Chicken, Hypercube; Shorts, Long), only on
    rows that have styles. Keys Up and Down.
36. **Colour:** the palette as big swatch buttons in a grid, the chosen one with a thick white ring
    and its name under the grid. Keys Left and Right.
37. A hat with nothing to paint (no hat, the chicken) shows its swatches greyed, with the reason in
    one line.
38. **Buttons:** Surprise me (X), Undo (Z or Backspace), Done (Enter). Esc is cancel.
39. Every button works by mouse and its key, and shows its key on itself.
40. At 4K and 145%, and at 1080p: legible, nothing clipped.

### G. Saved, and home (41 to 43)

41. Done saves through the store, and the trip takes you home, where the keeper dresses the pen's
    player from the same store.
42. Back on the farm: input on, camera current, environment current, HUD as it was, the circle
    waiting for you to step out.
43. "Saved. It goes with you." over the circle on arrival.

### H. Look, test, hand over (44 to 51)

44. `_verify_room_runner.gd`:
    - standalone: keys, clicks, the garment's parts per row, save, cancel;
    - from the pen: circle, Enter, room, change, Done, home dressed; the environment, camera, input
      and HUD put back; a second trip.
45. Frames of every row in the room, at 720p and at 4K.
46. Look at every frame; fix and capture again.
47. A short film: the circle, Enter, the room, a few changes, Done, the farm.
48. Run the pen's checks and the circle's own runner again: unchanged.
49. Measure: the trip's swap time, and the room's frame time.
50. Update the handover `follow_up/outfit.md`: both versions, how to switch, and the questions.
51. Commit locally by path, then report: which to look at first, how to try both.

## Status (8 Oct, evening)

All 51 steps done.

- **Checks:** `_verify_room_runner.gd`, 38 of 38. The circle's own runner, 74 of 74, after its Enter and
  switch were added. The pen's key audit is unchanged (28 keys, the same 5 old clashes).
- **Film:** `smoke_test_output/video/outfit_room_film.mp4`. Frames in `smoke_test_output/outfit/room/`,
  with `4k_*` at Ramon's screen size and `12b_dark` in the lab's dark look.
- **Measured:**

  | What | Time |
  |---|---|
  | Enter to the room | 0.56 s |
  | Done to the farm | 0.65 s |
  | A frame in the room | 0.47 ms |
- **Changes from the plan, found in frames:**
  - The camera is closer (3.3 m), for cinema scale.
  - The piece is scaled to a one-metre largest side, never past 2.2 times: a fixed 2.2 made the
    chicken costume tower over you.
  - The panel keeps fixed section sizes and scales to fill the screen's height, so it never changes
    size between parts and reads the same at 720p and at 4K.
  - The lesson wall needed `kit_style.apply()` and the room's `edge_codes` to come out blue.
  - The words in the room follow the lab's B mood.
- **Not done:** step 20's dark mood is checked in one frame only; the kit's pedestals follow it on
  their own.
