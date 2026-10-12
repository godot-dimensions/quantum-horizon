# Playable world: W onboarding, discovery and easter eggs (handover, 10 Oct 2026)

The brief "Playable World — 4D Onboarding, Exploration & Easter Eggs" plus the hints-along-the-path idea, planned in
`follow_up/pen_discovery_plan.md` (40 steps, research, Ramon's six answers at the top) and built directly in
`chickenpen/playable_world.tscn`, as Ramon asked. Everything changed is backed up in
`chickenpen/.backup/2026-10-09_before_discovery/` (its README says how to put it back); git's a8f5d9c is the same
state. The Dream Shifter (the dev/art onboarding) came after it the same night: `follow_up/pen_dream_shifter.md`.

## Questions for Ramon

1. **Tamsin**, the balloon's ground crew at the fire: the name is mine. She says Wren's balloon "is right above me.
   Not up in the sky. Along W." Keep, rename, or another voice?
2. **The airships**: one in the farm's slice, four 9 m ana, far north-east past the Watchstone. They drift and bob and
   are kept out of the projection (P). Too many, too few, too far?
3. **The edge-on door** comes out on top of the Watchstone. Should using it also count for anything (a journal page,
   a line from Wren), or is the surprise the reward?

## What is in the pen now

| What | Where | How it plays |
|---|---|---|
| **The W guide** (hints along the path) | `Systems/WGuide`, spots in `World/WHints` | Linger near something off your slice and a hint comes: first time the animated mouse/keys card (the Aquatic Lab's, copied), later a small chip, after three uses of a skill nothing but the world's own cues. Each spot is done for good once you do the thing. Spots: Trym's desk (step), the cave road (step), the gate road (turn forward), the camp road (turn sideways + V), the cache and the door (chips). |
| **Trym's desk** | `scripts/pen_trym_4d.gd` | Two legs at W 0 (Ramon: "put the legs there yourself"), so it stands in the farm's slice; the rest still change as you step. |
| **Easter egg 1, the kata cache** | `World/KataCache` (25, 0, −32), the quietest corner | A knoll of rocks at W 0; its mouth is open only ana of W 5.5, the chest at W 7.5. The dotted trail from the camp climbs through W to it. F opens the chest: it spins, shrinks, pays 10 azoth, confetti. |
| **Easter egg 2, the balloon hidden in W** | `lookout/balloon_4d.gd`, `Systems/BalloonFinder`, `World/BalloonCrew` | The balloon hovers 5 m ana and 3.5 m up from its stake until found. Turn the slice until about half of it shows and "V align" comes up (forgiving, as asked); V finds it. Until then it cannot be boarded. At its stake: a fire and Tamsin sitting at it, who tells you where it is (and where the airships are). |
| **Easter egg 3, the edge-on door** | `World/WDoor` (45, 0, 2), the quietest corner of the east | Trym's portal arch, thin, turned a quarter into W: a glowing slit in the farm's slice, a whole door when you turn the slice sideways. Walk through it whole and you come out on top of the Watchstone. |
| **The airships** | `World/Zeppelins` | Ramon's mid-build idea: one in the farm's slice, four more 9 m ana. Budget: three merged meshes a ship. |

Keys are the pen's own: E and Q step, the right mouse button turns the slice, V aligns, F opens and talks, R goes home.

## What was checked

`chickenpen/discovery/_verify_discovery_runner.gd` plays it through as a player would (its own keys and mouse, a frame
at each beat in `smoke_test_output/discovery/<look>/`). Final run, art look, 10 Oct 02:18: **23 of 23 pass**:

- the cards at Trym's desk, the gate road and the camp road; the chip on the cave road; every hint done once you do
  the thing (a step, the gate in your slice, the camp's V);
- the camp's V comes up after a 5 degree turn on the camp road and counts as learning to align;
- the cache: its chip after lingering, open at W 7.5, F opens the chest, 10 azoth in the belt;
- the door: walked through whole, you stand on top of the Watchstone (y 13.6);
- the balloon: 5 m ana until found, no boarding before, V comes up turned 8 degrees with 53% of it showing, V finds
  it, boarding opens at the basket at its W;
- the dev look with the projection on: no "Too many instances" in the log (art and dev runs).

Found and fixed by playing it:
- **F never reached the chest**: the catcher takes every F in `_unhandled_input`. The chest now listens in `_input`
  (as the talking characters do) and leaves F to the catcher whenever a chicken is in reach or in your arms.
- **A hint stayed up after you had done the thing, or walked away**, and blocked the next spot's card. A hint now goes
  the moment it is done, or once you are well away from its spot (the research's "end a hint when the player does
  the action").
- The card's title was cut off at "TURN THE SLICE FORWAR": it shrinks to fit now.
- The airships read as near at 95 m: the fleet is out at 150 to 175 m now.

Not checked by a person yet: how the hints feel at your 4K and 145% UI, and the airships' size from the farm.

## Known issues and notes

- **`PenLayout/scripts/_make_pen_paths_b_runner.gd` regenerates `pen_b.tres` from scratch.** Running it would drop the
  cache trail (nodes 21-23), the Dream Shifter spur (24, 25) and Andrew's gate nodes (19, 20). Add them to that
  runner before ever running it again.
- Andrew's wall (9 Oct): solid at every W from −73 to 47 with the gate only at W −15 to −11; no collision; a 9 m gap at
  its east end. Not touched here (his to fix on Sunday, per Ramon's message).
- The Tutor's place hints still measure raw W, not the turned slice's offset. The W guide uses the true offset
  (`discovery/w_sense_4d.gd`); the Tutor was left as it is.
- Every new mesh is either the Look's own (`_look_own`, the same in both looks) or follows the Look's rules; the
  airships and the confetti are kept out of the projection.
