# The Dream Shifter: onboarding for Dev Mode and Art Mode (handover, 10 Oct 2026)

Ramon's brief (9 Oct, last thing before bed): a stumpy Greek pillar with a floating 24-cell, "the crystalline entity",
that introduces the I toggle between the dev look and the art look; a very short talk; the first shift happening live
in the scene; then a short explainer built from real engine visuals (not skippable for 5 s); a reinforcing message the
first time the player presses I themselves; and "a super obvious, entirely impossible to miss prompt in the main scene
that tells you to click the toggle button between the different views". Built directly in `playable_world.tscn`,
like the discovery work (backup: `chickenpen/.backup/2026-10-09_before_discovery/`, see its README).

## Questions for Ramon

1. **When the big prompt comes unasked.** It comes after the orb's explainer (your turn), or if you walk on past the
   pillar without touching it, or after 75 s of play without switching. It never shows before the orb on a normal
   start, so the orb gets the first reveal. If you want it from the very first second, set
   `Systems/LookGuide` `prompt_after` to 0.
2. **"Dev Mode" / "Art Mode".** The explainer and the prompt use your words. The Look's own little note at the top of
   the screen said "Dev look   I" / "Art look   I"; it now says "Dev Mode" / "Art Mode" to match. The panel's buttons
   still say Dev and Art. OK?
3. **The words** (all yours to change, in `pen_look_explainer.gd` and `dream_shifter_script.gd`):
   - DEV MODE: "How we build. We block it out, test it, and find out what is possible in 4D."
   - ART MODE: "Where it is going. The same world, dressed as the vision it can become."
   - "Rough on purpose. This is a prototype, and every block in it is a question we are answering about 4D."
   - The orb asks "what this world could become?" when you are in the dev look (the pen opens in it) and "what this
     world is really made of?" when you are in the art look.

## The five decisions the brief asked for

1. **Where:** halfway down the very first road, start to Trym's house, on the right as you walk it, at the end of a
   2.5 m spur (`World/DreamShifter` at (21.4, 0, 29, W 0); path nodes 25 (junction on the road) and 24 (in front of the
   pillar) in `PenLayout/paths/pen_b.tres`). The first objective is "Follow the path to Trym's house", so every player
   passes within 3.5 m of it about ten seconds in, and it stands in plain view from the start. In front of Trym's
   house itself was busier (his door, his circle, the sand) and the gate and the wall come much later.
2. **How the first shift is triggered:** the orb does it. F at the pillar, four lines ("Whoa. What is this orb?",
   "I am the Dream Shifter.", the question, "Check it out."), one choice (Show me / Not now). When the box closes the
   crystal flares, a rising shimmer plays, and the world switches through the real Look (`set_dev`) in your own
   camera: the HUD steps aside, the frame from just before is frozen over the screen and a line of light sweeps across
   it with the new look live behind the line. Then 1.7 s of the new look, live, before any words.
3. **The explainer:** your Dev Logs slider, played. One 16:9 frame in the middle, the dev look left of a glowing line
   and the art right of it. The first pictures are the player's own two frames from the shift (caught as it happened);
   then the Watchstone, the cave and the camp (`discovery/dream_shifter/views/`, captured from the game by
   `_capture_views_runner.gd`). Beats: the title "One world. Two modes."; the line sweeps to show all the dev while
   DEV MODE is explained; then all the art while ART MODE is; then the message and "[I] switches between them, any
   time." A filling bar for 5 s, then "Space continue" (Space, Enter, F, Esc or a click). It closes itself after 32 s.
4. **Dev vs Art without overexplaining:** two columns of one line each, under the half of the picture they describe,
   and one sentence of why. "We" throughout.
5. **The reinforcement:** after the explainer the big prompt arrives in the middle of the screen ("Switch the view /
   Dev Mode / Art Mode / Press I, or click Dev or Art here") and flies to the Look row on the left-hand panel, docking
   beside it with an arrow and a pulsing ring round the Dev and Art buttons. It stays until you switch (key or
   click). That first switch ticks it off and brings the praise card: "Well done. Now you are starting to understand
   how we work." / "This is a prototype world: one part discovery, one part construction." Once a session.

## The pieces

| File | What |
|---|---|
| `discovery/dream_shifter/pen_dream_shifter_4d.gd` | `World/DreamShifter`: the column (lofted round through W, square steps and abacus), its collider, the crystal (the project's 24-cell model, a smaller one inside, three 16-cells in orbit, a light). It turns through W, so its slice keeps changing shape. Wakes as you come near, flares when it shifts. |
| `discovery/dream_shifter/dream_crystal.gdshader` | The crystal's look: unshaded, faceted (flat normals from derivatives), bright rims, a band of light that sweeps up. |
| `discovery/dream_shifter/dream_shifter_script.gd` | Its lines. |
| `discovery/dream_shifter/pen_dream_shifter_talk_4d.gd` | `Systems/ShifterDriver` (a PenNpcTalk4D): F, the prompt over it, the two-shot, then hands over to the guide. |
| `discovery/dream_shifter/pen_look_guide_4d.gd` | `Systems/LookGuide`: the live shift, the explainer, the big prompt, the praise, the prompt unasked. |
| `discovery/dream_shifter/pen_look_explainer.gd` | The explainer's drawing. |
| `discovery/dream_shifter/pen_look_prompt.gd` | The big prompt and the praise card. |
| `discovery/dream_shifter/_capture_views_runner.gd` | Recaptures the explainer's places (run it after the valley changes). |
| `discovery/dream_shifter/_verify_shifter_runner.gd` | Plays it all through and checks it, frames in `smoke_test_output/dream_shifter/<look>/`. |

Scene: `World/DreamShifter` (+ `Head`), `UI/ShifterTag`, `UI/ShifterBox`, `Systems/LookGuide`, `Systems/ShifterTalk`,
`Systems/ShifterDriver`; "DreamShifter" added to the Look's `orange_units` (the column is orange in the dev look; the
crystal is the Look's own and the same in both).

## What was checked

`discovery/dream_shifter/_verify_shifter_runner.gd` plays it as a player would, in both looks (frames in
`smoke_test_output/dream_shifter/<look>/`). Final runs, 10 Oct 02:20: **all pass, dev look and art look**:

- the pillar and the crystal in view down the road from the start; the "F  touch the orb" prompt at the spur's end;
- F starts the talk; the question matches the look (dev: "could become", art: "really made of"); Show me; "Check it
  out." and the world shifts (dev to art, or art to dev) in the staged shot with the sweep;
- the explainer opens after the breath; Space before 5 s does nothing, after it closes it; the player can move again;
- the big prompt arrives in the middle and docks by the Dev and Art buttons; I switches the look; the praise comes on
  that first switch, once; the prompt goes with the switch;
- the orb's second talk ("again": shift again, tell me again, thanks);
- walking on past the orb without touching it brings the prompt unasked (16 m on, not at 9 m).

Found and fixed by looking at the frames:
- the praise card never cleared (a canvas keeps its last drawing; it is redrawn once more after it ends now);
- the praise sat on top of the player and then over the to-do list: it appears where the prompt docked now;
- the centre-stage prompt touched the orb's prompt, and the orb's prompt covered the crystal: both moved up;
- the talk box overlapped the left-hand panel: the panel steps aside while the orb talks;
- the shift was seen over the player's shoulder: it is a staged wide shot now (the talk camera, from the pillar,
  down the road to Trym's house), and the explainer's first pictures are that shot in both looks;
- the HUD came back mid-moment and the catcher's "Catch [F]" re-showed itself through it: the HUD is faded out (by
  `modulate`, which nothing else touches) from the flare until the explainer.

Not checked by a person yet: the crystal's look and size at your 4K, the shimmer sound, and whether 75 s is the right
wait for the unasked prompt.

## Known limits

- The live frames are grabbed from the screen, which stalls that one frame (about 0.1 s) twice during the shift; it
  is hidden in the flare and the sweep.
- `PenLayout/scripts/_make_pen_paths_b_runner.gd` regenerates `pen_b.tres` from scratch: running it would drop the
  spur (and the cache trail, and Andrew's gate nodes). Add them to that runner before ever running it again.
