# The outfit changer: plan (8 Oct 2026)

Ramon's brief (8 Oct): a simple clothing swapper that is remembered when you go to other scenes,
so the character stays the same. Pants colour, hats and their colour, shoes and their colour,
skin colour, and jokes like a big chicken neck and face. A simple sci-fi pedestal next to Trym's
house, in the same tech as the arch Trym raises out of thin air. Step on it, get a little sci-fi
scan, and the clothing choices appear in the world in an interesting way. Simple, but thorough,
and it must not break anything.

## The idea in one paragraph

**The fitting circle.** A dark plate with a cyan ring lies in the grass beside Trym's sand. Walk
up to it and its frame grows out of the ground, the way Trym's arch does. Step in: the camera
comes round to face you, as a mirror would. A ring of light sweeps up your body from the boots to
the cap. As it passes each part (shoes, trousers, shirt, hands, hair, hat), it leaves a slim
holographic strip of colour tiles at that height beside you, like the labels on a body diagram.
At the top, the scan reads out your size in all four directions, including how thick you are
in W. You dress from the strips: up and down picks the part, left and right the colour, Q and E
the style. Each change shows on you at once. F saves it: the strips fold back into the ring, the
frame lowers, and you walk off wearing it. The outfit is saved to disk and goes with you into the
cave, the far room and the cinema, and it is still there next time you play.

## What I found (research, and the code)

**Prior art** (cited in `follow_up/outfit.md`, Sources).
- **Fitting rooms and mirrors:** Animal Crossing's Able Sisters fitting room, the Sims, Splatoon.
- **One-key randomise:** Fall Guys and Among Us, where customising is a quick trip between games.
- **The scan in sci-fi:** Total Recall's X-ray wall, Star Trek's transporter, Prey's and Mass
  Effect's scanners.

What carries over:
- Show the change on the character live, not on a preview.
- Keep a short curated palette per part rather than a free colour picker.
- Keep a way back to what you came in wearing.
- Keep the camera on the character.
- A scan reads best as one clean sweep, about a second and a half, ending in a readout.

**The code it builds on.**
- **The avatar:** `scripts/block_avatar_4d.gd`, the chibi build. Every body part is its own named
  box with its own material: Tunic, UpperArm, Head, ears in X and in W, Hair, Cap or Crown, Belt
  (which doubles as shorts), Thigh, Shin, Boot, Forearm, Hand. The avatar frees all its children
  whenever it rebuilds, so anything worn must re-attach itself, the way the pickaxe does.
- **The tech it echoes:** Trym's arch, `theatre/theatre_arch_4d.gd`.
  - Navy frame (0.16, 0.19, 0.27), cyan edge (0.32, 0.86, 1.0), blue field.
  - It grows up out of the ground with the frame first and the field after, and leaves upward
    through the air.
  - Its own lamps and a generated chime.
  - It is thick through W, and `_look_own`, so the dev look leaves it alone.
- **The mirror shot:** the camera rig's `set_talking(true)` (the conversation framing) and the
  walker's `face_towards(point)`.
- **Living across scenes:** the laptop trip already adds a node to the window's root, which
  survives scene changes. The cinema (`theatre/theatre.tscn`) has a player of its own, and the
  cave and the far room use the pen's player.
- **F is `catch_target`:** the talkers use `_input`, the catcher `_unhandled_input`, and the
  laptops yield to both. All of them check `input_enabled`.

## What it touches

- **New and mine:**
  - `chickenpen/outfit/`: the store, the wearer, the pieces, the circle, runners.
  - `chickenpen/units/outfit/outfit_circle.tscn`.
  - `follow_up/outfit.md`.
- **One shared file:** `chickenpen/playable_world.tscn`, one instanced unit beside Trym's
  house. The cabin unit itself is not touched.
- **Not touched:** the avatar script, the walker, the theatre, the menu, the labs,
  `project.godot`. Nothing is added to autoloads.

## The plan

### A. Ground (1 to 10)

1. Research prior art: fitting rooms, randomisers, scan effects, skin tone ranges, Godot
   persistence. Cite the sources in the handover.
2. Survey the code: the avatar's parts, the arch's tech, the dev look's `_look_own`, the rig's
   talk framing, the walker's facing, who listens to F.
3. Make a revert point: a local branch `outfit-before-2026-10-08` at the starting commit, plus a
   snapshot of `playable_world.tscn` in `chickenpen/.backup/2026-10-08_outfit/`.
4. Right before any shared edit, check no other window is changing `playable_world.tscn` or the
   units: uncommitted changes, modified times.
5. Run a baseline of the pen's checks before anything changes, and keep the PASS/FAIL lines:
   journey B, look, climb, dreamer, lookout, laptop, crossing, key audit.
6. From the key audit, confirm which keys the circle can take. It only takes them while you
   stand in it, with movement switched off.
7. Measure a free spot beside Trym's house from a top view. It must keep clear of:
   - his sand (radius 3.4 m) and the paths;
   - the arch's spot and his invitation walk;
   - every F reach (Trym, his laptop, the red cat);
   - the destination circle.
8. Measure the player's figure, pen and cinema both: each part's size, including the W sizes
   from Andrew's 7 Oct change and the ears along W, so hats fit round the head in all four
   directions.
9. Fix the scope of "other scenes": the pen, the cave, the far room and the cinema. The labs
   and Crosswise have avatars of their own and are left as they are (question 1).
10. Start the handover `follow_up/outfit.md`, with "Questions for Ramon" at the top.

### B. The outfit, as data (11 to 20)

11. `outfit/outfit_4d.gd`, with no `class_name`, preloaded by whatever uses it: the store. The
    slots are hat, hat colour, hair, skin, shirt, trousers, trouser colour and shoes, each
    stored as an index into its palette.
12. Palettes from the research:
    - eight skin tones across the full range;
    - about twelve clothing colours that read on flat-shaded boxes;
    - eight hair colours.
13. The first tile of every palette is today's colour, so a player who never visits looks
    exactly as now: green tunic and cap, brown shorts and boots, blond hair, and today's skin.
14. Save with a `ConfigFile` in `user://pen_outfit.cfg`. Load once, lazily. Save on F. A missing
    or garbled value falls back to the default instead of failing.
15. Give the save path a test override, so no runner ever touches Ramon's saved outfit.
16. Add a revision number that goes up on every change, so anything wearing the outfit knows to
    repaint.
17. Add `randomise()`, which never returns the same outfit twice in a row, and `revert()` to
    the outfit you stepped in with.
18. Give every option a short name for the labels: "Teal", "Top hat".
19. Parse-check.
20. A headless test of the store: save and load round trip, bad values, defaults.

### C. Dressing the figure (21 to 35)

21. `outfit/outfit_wearer_4d.gd`: a node next to the avatar, never inside it, because the
    avatar frees its children when it rebuilds.
22. What it paints:
    - **shirt:** Tunic and the upper arms;
    - **skin:** Head, the four ears, forearms and hands, and the legs when in shorts;
    - **trousers:** Belt, plus thighs and shins when long;
    - **shoes:** boots;
    - **hair:** Hair, Crown, ponytail;
    - **hat:** Cap or whatever hat is worn.
23. Hats: Cap (the avatar's own), None (the cap off, so the crown of hair shows), Beanie, and
    Top hat.
24. Two jokes:
    - **Chicken:** a mascot's big white neck and head on your shoulders, with comb, beak,
      wattle and eyes. It is bigger than your head in every direction, W included, so your
      head is simply inside it.
    - **Hypercube:** a small tesseract floating over your head, slowly turning through W, so
      its slice keeps changing shape. That is the 4D joke.
25. Build the pieces as boxes in `outfit/outfit_pieces_4d.gd`, sized from step 8's numbers and
    hung on the avatar's Head part, so the walk carries them.
26. If the figure rebuilds, notice it with one check a frame (a marker part has gone), then
    repaint and rehang. This is the pickaxe's pattern.
27. Switch the cap off only when a hat needs it. Measure what that rebuild costs.
28. Trousers come in two styles. Shorts: the belt in the trouser colour, legs bare. Long: belt,
    thighs and shins in the trouser colour.
29. Change nothing else on the avatar: eyes, proportions and build stay as they are.
30. The only per-frame cost is the hypercube's turn and the one check.
31. Measure the wearer's cost in the pen, in milliseconds.
32. Let a part be lit briefly, for the scan and for the flash on a change.
33. Check each hat with the walk, being knocked down, the pickaxe, carrying a chicken and
    throwing it.
34. Confirm the dev look leaves the player as it is in both looks.
35. A headless test:
    - every part takes its slot's colour;
    - everything survives a rebuild;
    - the default reproduces today's colours exactly.

### D. Remembered everywhere (36 to 42)

36. A small keeper node added once to the window's root, as the laptop trip adds its node, so
    it outlives scene changes. It dresses every player figure that enters the tree, and only
    those: the node "Avatar" on the pen's `block_avatar_4d.gd`, under a "Player" body on the
    pen's walker. NPCs and the labs' copies are never dressed.
37. The pen installs the keeper from the circle's `_ready` and dresses its own player
    straight away.
38. The cinema's own player is dressed through the keeper, with no theatre file touched.
39. The cave and the far room use the same player. Check it in frames.
40. Check the range trip, a laptop trip to the menu and back, and Play again.
41. Check across runs: quit, relaunch, and the outfit is back.
42. One runner covering 36 to 41.

### E. The fitting circle (43 to 60)

43. Build `units/outfit/outfit_circle.tscn` and `outfit/outfit_circle_4d.gd`.
44. The arch's language:
    - navy frame, cyan edges, blue field;
    - its own lamps and a generated chime;
    - every mesh `_look_own`, so it is the same in DEV and ART.
45. The base plate is always there: low, about 1.5 m across, a dark disc with a cyan ring you
    can see from the path. It has no collider, so there is no step to trip on.
46. It rises when you come within about 5 m: the frame grows up out of the plate, three slim
    posts and a top ring, then the field fills in. When you leave, it folds away up into the
    air, as the arch does.
47. A world tag over it: "Outfit scanner", and "Step in" when you are close.
48. It is thick through W, like the arch's field, so a turned slice still finds it.
49. Place it beside Trym's house at the measured spot, as its own unit under `World`, facing
    the path.
50. You step in when you stand within about half a metre of its centre, in your slice. It does
    not start:
    - while your input is off (a talk, a cutscene, Trym's walk);
    - while you carry a chicken (a line says so).
51. On stepping in:
    - your input goes off;
    - your figure eases to the centre and turns to face the camera;
    - the camera comes in to the conversation framing. That is the mirror.
52. The scan, about 1.6 s: a ring of light sweeps up from the plate to over your head. Each part
    lights cyan as it passes, boots first and hat last, with a soft tick for each.
53. The 4D beat: the readout gives your size in four directions (tall, wide, deep and thick in
    W), measured from your figure's actual parts.
54. The choices appear. As the ring passes each part it leaves a slim holographic strip at that
    height, on the camera's side and to your right: SHOES at the boots, TROUSERS, SHIRT, SKIN,
    HAIR, HAT over the head. A body diagram you dress from.
55. Each strip:
    - a thin 4D panel with a row of colour tiles;
    - the chosen tile raised and rimmed;
    - a short label beside it (the part, and the choice's name) drawn as the world tags are.
56. Keys, only while you stand in it:

    | Key | Does |
    |---|---|
    | W / S, or Up / Down | which part |
    | A / D, or Left / Right | its colour |
    | Q / E | its style (hat, trousers) |
    | X | surprise me |
    | Backspace | back to what you came in wearing |
    | F | done |

    Every change shows on you at once, and the part flashes.
57. One hint line with those keys, shown only while you are in the circle.
58. F:
    - the strips fold back into the ring and the frame lowers;
    - "Saved. It goes with you.";
    - the outfit is written to disk;
    - input and camera are given back.
59. The mouse still orbits while you dress, so you can look at yourself from any side, and
    turn the slice to see a hat in W.
60. Sound: the arch's chime on waking, a soft generated sweep for the scan, and a quiet tick
    per change.

### F. Not breaking anything (61 to 70)

61. Add the unit to `playable_world.tscn` (one resource line and one node). Check the diff by
    hand; no project-wide resave.
62. While you are in the circle, nothing else reacts to its keys: catching, talking, laptops,
    the belt, the camera's keys.
63. Run the key audit again: no new clash anywhere outside the circle.
64. Nothing of the circle shows away from it. Its labels and hint fade with distance, as a
    subgame should.
65. The HUD at Ramon's 4K and 145% (hud4k): the labels and hint line are legible and clear of
    the top row and the belt.
66. Check both looks: the circle reads the same in each, and switching the look leaves the
    outfit as it is.
67. A turned slice: the circle and its strips are findable, and the hats read through W.
68. Frame and GPU time near the circle, idle and in use, against the baseline (vsync off,
    windowed).
69. Run the baseline checks from step 5 again: the same PASS/FAIL lines.
70. Every test leaves Ramon's saved outfit and UI sizes as they were.

### G. Look, and hand over (71 to 80)

71. Capture frames:
    - walking up, and the frame rising;
    - the scan halfway, and the strips out;
    - every hat including the two jokes, and some colours changed;
    - done.
72. Capture the cinema and the cave wearing a changed outfit.
73. Capture the 4K HUD.
74. Look at every frame. Fix what reads wrong and capture again.
75. A short film of the whole beat, for Ramon to watch.
76. Write the handover `follow_up/outfit.md`: what to look at, where everything is, the keys,
    the questions.
77. Add the circle to `chicken_pen_learnings.md`'s "Where things are", record any engine fact in
    `engine_capabilities.md`, and update memory.
78. Commit locally, by explicit paths, only this work. Nothing is pushed.
79. Release the lock and clear the temporary output.
80. Report: what to look at first, then the questions.

## Status (8 Oct, evening)

All 80 steps done except where noted.

- **Where it stands.** The circle is at (20.2, 43.4), west of the house front, facing west (step 7):
  - On the east side, Trym's talk reach after the cinema would have shared F.
  - North of the sand is his walk to the arch.
  - The first framing came in through Bush06, so the mirror camera now comes round to the circle's own
    front, with the house behind you.
- **Changes from the plan, found by looking at frames:**
  - The lamps are white, not the arch's cyan: cyan light turned an orange shirt mustard.
  - The frame is 2.35 m tall, so the chicken's comb fits.
  - The strips start outside the posts, each tile has a light mat (charcoal vanished on the navy),
    and the strips hang on the circle's middle, not where you stood.
  - The readout sits over the key hint.
  - The sand under the booth is 1.8 m across, so the grass grows through neither the plate nor the
    shoes strip.
  - The frame wakes at 8 m, not 5.
- **Bugs found and fixed:**
  - `Outfit.reload()` ran Script.reload() and reset the save path (now `read_again()`).
  - The wearer painted the pickaxe's own "Cap" (now body parts only).
  - The keeper's list tidy choked on a freed wearer coming back from the menu.
- **Checks** (`_verify_outfit_runner.gd`): 70 of 70 pass, in the art look, the dev look and at 4K
  (24 there).
- **The pen's own checks, before and after** (step 69): see the handover; same results.
- **Not done, on purpose, and asked in the handover's questions:**
  - Lifting the pen's chicken carry over tall hats (step 33 found the overlap).
  - Dressing the labs' and Crosswise's players (step 9's scope).
