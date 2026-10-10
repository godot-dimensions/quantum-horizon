# Creature Lab, round 4 (Ramon's walkthrough Part 4, items 43-50; 10 Oct 2026)

Final feature round for the Creature Showcase. Keep the layout, the animations and the presentation systems; no new
path branches; the building stays still under W. Directions checked against the hall: its blue title wall is
north (-z), the entrance south (+z), so west is -x (the left as you walk in).

## First: Azathoth
1. **The cave's proportions (45).** Round 3 shrank it on purpose to fit the deck (scale 0.8, limbs 2 units, the
   mouth 1.5 m up); that is why it looked like a reduced copy. Back to the cave's own numbers (scale 2, limbs 12
   units with the cave's curl, 24 limbs of 20 pieces, the cave's breath and dust), raised to about 7 m over its
   deck, its limbs kept between the deck, the east wall and the ceiling.
2. **W turning (46).** It sat outside the turn pivots and squared itself to the camera's slice, so the turn never
   reached it. In a pivot like the others, its slice normal its own: the turn turns it, and it still faces you.
3. **Its pedestal (48).** The blue deck dark with thin white grid lines (the dev look's grid); the hologram the
   deck's own size, centred, inside the pedestal.

## Second: the close look for every creature (49, 50)
4. Within about 1 m of any creature's pedestal: a click (or C) starts a short presentation. Your camera's copy
   eases in to a framing set per creature, then drifts in a slow, small orbit; the creature keeps living; a panel
   on the left says what it is, how it is built, how it moves and what is 4D about it (the cards' words, plus a
   "built" line for each, from the code). Click, C or Esc to come back. Right drag still turns the animals.
5. Azathoth's framing far back and low, looking up at it, its limbs in frame.

## Third: the labels (47)
6. Each label at its pedestal's front edge, where the platform begins (not back on the deck), facing the way you
   come. Heron: its west side. Chickens: their east side. Azathoth: its west side, facing the middle of the room.
   Goat: as it faces, further forward. The rest: the same front-edge rule.

## Fourth: grass and the heron
7. **Grass (44):** denser (blade spacing 0.05 to 0.036 m, about twice the blades) and thinner (width 1.35 to 1.0
   of the pen's); measured, and eased back if it costs too much.
8. **The heron (43):** no croak; the wingbeats stay.

## Checks
The capture runner's checks for each, frames of every close look and of Azathoth turned, and the frame time
against round 3's 6.8 ms. Committed locally, never pushed.
