# The outfit changer: the fitting circle beside Trym's house, and Trym's fitting room (8 Oct 2026)

Ramon's brief (8 Oct):
- A simple clothing swapper that is remembered in other scenes, so the character stays the same.
- Hats, trousers, shoes and skin colour, and jokes like a big chicken neck and face.
- A sci-fi pedestal next to Trym's house, in the same tech as the arch Trym raises out of thin air.
- Step on it and get a little scan; the clothing choices appear in the world in an interesting way.
- Simple, thorough, and nothing breaks.

The plan (80 steps, with its status) is `chickenpen/outfit/PLAN_OUTFIT.md`.

**Two versions, side by side** (Ramon, 8 Oct evening: "Finish what you did ... but make my option
separately as a function i can check"):
- **The fitting circle:** you dress in the world, from strips of colour beside you.
- **Trym's fitting room:** Ramon's version, a room of its own with you on a pedestal, the piece
  turning beside you, and a proper panel. The plan is `chickenpen/outfit/PLAN_FITTING_ROOM.md`,
  51 steps.

Both change the same outfit, saved the same way, and worn the same way everywhere.

## Ramon's notes, 8 Oct evening, and what changed

- **The circle stands on the left of the house** (west), at (30.4, 43.6), its open front facing east.
- **It folds out within 3 m and folds in past 3 m;** before that it is a capped plate with a cyan rim.
  Its name shows only closer still (1.6 m).
- **F starts it** ("to use outfit scanner you press F"). Walking onto it does nothing. Up close it reads
  "F  Outfit scanner".
  - F is the catch key too, so the circle takes it only when nothing else would: no chicken in your
    arms or in reach, no cat in reach, nobody to talk to. That is the laptop's rule.
  - With a chicken in your arms the tag says "Put the chicken down first".
- **The basic mode is colours only, on the arrow keys,** with the strips on your left (clear of the HUD)
  and a floating arrow-key cluster over them. Under SHOES is **ADVANCED**: Right or Enter there opens
  Trym's fitting room. F is done, as before.
- **The dev look:** the plate, the pad and the frame turn the Look's blue; the rim round the plate stays
  cyan ("the closed panel should have the cyan outline, but everything else blue"). It follows the
  Look's colour swatches as well.
- **The fitting room:**
  - **Esc saves now,** the same as Enter ("when i pressed esc in advanced, nothing was saved. that was a
    bummer"). Z is the way back to what you came in wearing.
  - **A colour wheel beside the swatches.** A colour from it is that part's own, saved with the outfit
    (`<part>_custom` in the file). The arrows step off it onto the palette: right to the first swatch,
    left to the last. The basic strips show it in the middle, called "Your own".
  - **Tab shows the light's panel** in the outfit panel's place, with the lab tuner's rows:
    - LIGHT: spots, sky fill, sun, sun height, sun turn and exposure, per mood (B switches the mood).
    - SPOT: strength, cone, softness, reach, falloff, height and warmth, for the light over you, the
      light over the piece, or both.
    - "Save as default" writes `chickenpen/outfit/fitting_room_tuning.cfg`, which the room reads when
      it starts. Without that file the room starts from the Creation Lab's saved light. The lab's file
      is only ever read.
  - **The Creation Lab's pedestals:** its showcase pedestal in miniature, at its proportions, so the
    white ring is a thin rim round a big blue deck as it is in the lab. Each has the lab's hologram on
    its deck and its printed band on the side facing the camera. Under the piece, the hologram is drawn
    up towards it. To build them, `kit_pedestal.gd` `build()` takes an optional fourth argument that
    sizes its trims; the lab's own call does not pass it, so the lab is unchanged.
  - The panel is sized from the screen's height, never scaled, so it no longer jitters. The light and
    blue walls are the lab's, and there is no white bar at the ceiling.

## Questions for Ramon

0. **Which version, or both?** Both, as you asked: the circle is the basic mode, and ADVANCED under its
   last strip opens the fitting room.
   - To make the room the only way, tick `opens_room` on `World/OutfitCircle`; the scan then ends
     straight in the room.
1. **Should the labs' players wear the outfit too?** Today it reaches every scene of the playable world:
   the pen, the cave, the far room and the cinema. The Creation Lab, Arboretum and Voxel Lab carry their
   own copies of the avatar (`LabKit/carried/`), and Crosswise has its own (`mk_avatar_4d.gd`). They are
   left as their scenes make them; that was the scope rule. Extending it there is small (the keeper would
   accept those script paths), but it touches those prototypes, so it is your call.
2. **A carried chicken and a tall hat: done as you said** ("keep the hats minimal if they overlay with
   chicken").
   - While you hold a chicken over your head, the hat keeps low: the top hat a flat crown, the beanie
     without its pompom, the hypercube small on your hair, the costume just a comb, a beak and a wattle.
   - It comes back when you put the chicken down. The pen's carry itself is unchanged.
   - **The cat is held at the same spot** (`scripts/pen_cat_grab_4d.gd`), and Nike a little lower. Only
     the chicken does this now (your word). Should the cat too?
3. **The cinema's player is not quite the pen's player.** In `theatre.tscn` it has no eyes and shorter
   shorts. The outfit makes their colours and hats match, but not those two things. Matching them means
   touching the theatre, so it waits for your say.
4. **Where it stands.** On the left of the house, at (30.4, 43.6), as the unit `World/OutfitCircle`, so
   you can move it in the editor.
   - Its open front (its +Z) faces east, and the mirror's camera stands on that side.
   - Turn it and the camera's side turns with it.
   - If Trym, a cat or a chicken is in F's reach where you stand, the tag reads "Outfit scanner" without
     the key, and F goes to them. That is on purpose.
5. **The words.** Over it: "F  Outfit scanner" up close. On F when done: "Saved. It goes with you." A
   wheel colour is called "Your own". The jokes are called "Chicken" and "Hypercube". Change any of them
   freely (`outfit_circle_4d.gd`, `outfit_4d.gd`).
6. **Trym's lost outfit changer** (the board's card): if he commits his, this one's store
   (`outfit_4d.gd`) is the place for whatever his had that this does not.
7. **Ideas outside the plan**, not built:
   - Trym saying a line about the circle.
   - The hypercube teaching card in the lab look ("you only ever see its slice").
   - A slow turntable or a hologram double of you, so you see your back without orbiting.

## What to look at

- **The films**, 1920 x 1080, in `smoke_test_output/video/`:
  - `outfit_film.mp4`, the circle, 47 s. You walk up, the frame rises, you step in, the scan runs, you
    go through the changes, and you leave as a chicken.
  - `outfit_room_film.mp4`, your version, about 45 s. Into the circle, Enter, the flash into the
    fitting room, the changes, the piece turned through W, Done, and the farm again, dressed.
- **The fitting room's frames:** `smoke_test_output/outfit/room/`, with `4k_*.png` at your screen size
  and `12b_dark.png` in the lab's dark look.
- **The frames:**
  - `smoke_test_output/outfit/play/` (art look), with `4k_*.png` at your 3840 x 2160 and 145%.
  - `smoke_test_output/outfit/play_dev/` (the dev look).
  - `smoke_test_output/outfit/moves/` (each hat walking, carrying and knocked over).
- **To try it:**
  1. Open the playable world and follow the path to Trym's house.
  2. The frame rises on the left of the house when you come within 3 m.
  3. Walk up to it, and press F when it reads "F  Outfit scanner".

## Keys in the circle (your walking is off while you dress)

| Key | Does |
|---|---|
| F | start the scan (up close), and later done: saved, and you can walk again |
| Up / Down | which part: HAT, HAIR, SKIN, SHIRT, TROUSERS, SHOES, then ADVANCED |
| Left / Right | its colour |
| Right or Enter on ADVANCED | Trym's fitting room |

The mouse still orbits, so you can look at yourself from any side or turn the slice.

## Your version: Trym's fitting room

`chickenpen/outfit/fitting_room.tscn` and `outfit_room_4d.gd`, reached by `outfit_room_trip_4d.gd`.

- **To try it:** in the circle, go down to ADVANCED and press Enter. Or open `fitting_room.tscn` and
  press F6; on its own, Done just saves.
- **What you see:**
  - On the left, you on the lab's pedestal (in miniature). Q and E turn you, and so does a drag.
  - On the right, the one piece you are changing, turning on its own pedestal: the hat, the hair, a head
    for the skin, the shirt, the trousers or the boots.
  - The piece is scaled until its largest side is a metre, never past 2.2 times, so the chicken costume
    does not tower over you.
  - Its name is under it, and your size in four directions is under you.
- **The panel** is black glass down the right, filling the height at any screen size.
  - Six numbered part buttons (keys 1 to 6).
  - The styles by name (Up and Down).
  - The colours as big swatches (Left and Right, or click), with the colour wheel beside them.
  - "Turn the piece through W" (T), Surprise me (X), Undo (Z), and Done (Enter, or Esc: both save).
  - Tab swaps in the light's panel (`fitting_room_tuner.gd`).
- **The room is the lab kit's**, read only: `lab_room_4d.gd` light (B for its dark look),
  `kit_room_4d.gd` walls with the blue lesson wall (`edge_codes`, its words painted on),
  `kit_pedestal.gd` with the showcase's hologram and band, and `kit_style.gd`'s black glass.
- **The trip** works as the laptop's does: the farm is parked, not freed, then put back. The
  environment that lit the farm is made current again, and the pen's camera, the mouse and the HUD
  are as they were. The circle says "Saved. It goes with you." or "Nothing changed."
- **Measured:**

  | What | Time |
  |---|---|
  | Enter to the room, flash included | 0.56 s |
  | Done to the farm | 0.65 s |
  | A frame in the room | 0.47 ms (vsync off) |
- **Checks:** `outfit/_verify_room_runner.gd`, 38 checks.
  - The room on its own: every key, a click, the piece's parts per row, through W, surprise, undo,
    and save.
  - From the farm: through the circle, home dressed, the environment, camera, input and HUD put back,
    Esc, and `opens_room`.
  - `hud4k` runs it at your screen size.
- **Traps found:**
  - The kit's swatches (the code blue among them) exist only once `kit_style.apply()` has run. The
    Creation Lab does it at start; a scene of your own must too, or its blue wall comes out white.
  - A wall turns blue from the room's `edge_codes`, not from the text's own `code`.

## How it works, and where

Everything new is in `chickenpen/outfit/`, plus the unit `chickenpen/units/outfit/outfit_circle.tscn`.
The only shared file changed is `playable_world.tscn`, with one resource line and one node.

- **`outfit_4d.gd`, the outfit as numbers.**
  - Each choice is an index into a short palette: eight skin tones after the Monk scale, twelve
    clothing colours, eight hair colours, six hats and two trouser lengths.
  - Each clothing row starts with the figure's own colour, so the defaults are exactly today's figure.
  - Plus one colour of your own per part, from the room's wheel (`CUSTOM`, kept as `<key>_custom`).
  - It is static, so the outfit lasts the run, and saved to `user://pen_outfit.cfg` on F, so it is there
    next time. A garbled file falls back to the defaults.
  - No `class_name`; it is preloaded.
- **`outfit_wearer_4d.gd`, which paints the outfit on one figure.**
  - It paints the avatar's own parts by name. Props hung on the figure are skipped: the pickaxe has a
    part called Cap.
  - It hangs the hats on the Head, and takes the cap off for any other hat.
  - It lives beside the figure, never in it. `block_avatar_4d.gd` frees all its children when it
    rebuilds, so the wearer notices a rebuild (its mark has gone) and dresses the new body.
- **`outfit_pieces_4d.gd`, the hats as boxes.**
  - Each is at least as thick through W as the head it covers, so a turned slice never shows a bare head.
  - The chicken is a mascot's neck and head, with eyes along W as well (after Andrew's W ears).
  - The hypercube is a small tesseract turning through W, so its slice keeps changing shape.
- **`outfit_keeper_4d.gd`, which keeps it on in every scene.**
  - One node on the window's root, which survives scene swaps the way the laptop trip's node does.
  - It gives a wearer to every player figure that enters the tree: the Avatar on the pen's
    `block_avatar_4d.gd`, under a Player on the pen's walker.
  - NPCs and the labs' copies are never touched.
  - The circle adds it each time the pen enters the tree, so nothing shared (`project.godot`) changed.
- **`outfit_circle_4d.gd` and `outfit_strips_4d.gd`, the circle.**
  - Trym's arch's language: navy, cyan, a rising frame and a generated chime. Every mesh is
    `_look_own`, so the dev look leaves it alone; the circle paints itself in the dev look instead
    (`_follow_look`, as Wren's balloon does).
  - The lamps are white, not cyan: cyan light turned an orange shirt mustard.
  - The strips are a body diagram, printed by the scan as it passes each part. Each is a carousel of
    five tiles with the choice raised, rimmed and matted, and its words drawn flat over the screen, as
    the world tags are.

## Measured (8 Oct, RTX 5080, windowed, vsync off: `outfit/_perf_outfit_runner.gd`)

| What | Cost |
|---|---|
| The wearer, per frame, nothing changed | 0.7 µs |
| The circle, per frame, you far away | 0.8 µs |
| The circle, per frame, up and ready | 13 µs |
| A hat that takes the cap off (rebuild, repaint, hang) | 0.4 to 0.6 ms, once |
| A colour change | 0.13 to 0.16 ms, once |
| Whole frame, circle drawn vs hidden, ready | +0.1 ms; GPU +0.05 ms |
| Whole frame, circle drawn vs hidden, dressing | +0.4 to 0.8 ms; GPU +0.12 ms |
| Whole frame, circle drawn vs hidden, far | +0.03 ms; GPU 0 |

## Checks

- `outfit/_verify_outfit_runner.gd`: 70 checks, played as a player plays, with its own keys only.
  Run windowed with `frames=1` for the frames, `hud4k` for your screen, and `look=dev` or `look=art`.
  It covers:
  - the store (wrap, garbled file, round trip);
  - the default being today's figure, and nobody else being dressed;
  - the frame rising, the step in, the scan and the six strips;
  - every key, and that nothing else heard them;
  - surprise, undo, a rebuild, and F saving;
  - the cinema, the cave, and a laptop trip to the menu and back;
  - the file read back, and that your own saved outfit was not touched.
- `outfit/_capture_outfit_moves_runner.gd`: each hat walking, carrying and knocked down.
- `outfit/_probe_outfit_site_runner.gd`: what is round Trym's house, and whether a spot takes F from
  anyone.
- `outfit/_perf_outfit_runner.gd`, `outfit/_film_outfit_runner.gd` (movie_hd).
- The pen's own checks, before and after, gave the same results (see the plan's Status).

## Two traps found on the way

- **`reload()` is the Script's own method.** A static function called `reload()` on a preloaded script,
  called from another script as `Outfit.reload()`, runs `Script.reload()` instead. That recompiles the
  script and resets every static variable, the save path included. The first test run wrote the real
  save file that way; it held only the defaults and was removed. The function is `read_again()` now.
  Don't give a static function a Script method's name: `reload`, `new`, `get_source_code`, and so on.
- **A cyan lamp lies about colours.** Anything lit for choosing colours needs white light.

## Sources (research, 8 Oct)

- Fitting rooms and mirrors:
  - Animal Crossing New Horizons mirror and wardrobe:
    https://www.thesixthaxis.com/2020/03/20/animal-crossing-new-horizons-change-hair-appearance-look-clothes-outfit-mirror-wardrobe/
  - Able Sisters fitting room:
    https://www.nintendolife.com/guides/animal-crossing-new-horizons-able-sisters-how-to-unlock-the-clothing-shop
  - Astro Bot's changing room: https://www.destructoid.com/all-astro-bot-costumes-and-how-to-unlock-them/
  - Cyberpunk 2077's mirror: https://www.pcgamesn.com/cyberpunk-2077/patch-15
- Live preview, undo and click counts:
  - Destiny 2 shaders: https://primagames.com/tips/how-to-apply-shaders-destiny-2
  - Fortnite's locker:
    https://www.gfinityesports.com/article/fortnite-players-cant-stand-its-awful-revised-locker-system
  - EVE's finalise step: https://www.eveonline.com/news/view/new-character-creator-update
- Scans:
  - Total Recall's X-ray wall: https://en.wikipedia.org/wiki/Special_effects_of_Total_Recall_(1990_film)
  - Star Trek's transporter: https://slashfilm.com/746188/how-star-treks-transporter-effect-actually-worked
  - Response times: https://www.nngroup.com/topic/response-times/
- Skin tones: the Monk Skin Tone Scale (CC BY 4.0), https://en.wikipedia.org/wiki/Monk_Skin_Tone_Scale
- Godot:
  - Autoloads: https://docs.godotengine.org/en/stable/tutorials/scripting/singletons_autoload.html
  - Static variables: https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_basics.html#static-variables
  - ConfigFile: https://docs.godotengine.org/en/stable/classes/class_configfile.html
- Miegakure's characters, which have a real thickness in W:
  https://marctenbosch.com/news/2014/12/new-screenshot-miegakure-on-ps4-interviews-collision-detection/
