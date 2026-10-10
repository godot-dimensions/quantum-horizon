# Creature Lab, round 5 (Ramon's walkthrough Part 5, items 51-58; 10 Oct 2026)

A targeted pass on the Creature Showcase. The wolf's, brachiosaurus's and goat's close looks stay as they are; no
changes to the room, the paths, the architecture, the animals' walks or the W turn, except where an item says so.

## Card placement: the references, exactly

- **North** is the hall's blue title wall (-z), **south** the entrance (+z); **west** is -x, your left as you walk in.
- A pedestal's **front** is the side its path arrives at (each station's `front` in `STATIONS`: the brachiosaurus's,
  Nike's, the goat's, the owl's, the chipmunk's and the crows' face south, toward the entrance; the wolf's, Azathoth's,
  the chickens' and the heron's face north, toward the middle aisle).
- A card stands on its **card side**: the front, unless round 4 gave it a side (heron west, chickens east, Azathoth
  west, facing the middle of the room). Those sides stay.
- **Where along it** (round 5): on the floor just outside the pedestal's edge, 0.45 m out, so at the start of the
  platform and never inside the hologram standing on the deck. Facing out from the pedestal on that side.
- Azathoth's card in addition slides along its west side to the front end (2.3 m north of the pedestal's middle), so
  it is the first thing you meet coming from the path, well before you are close enough to turn it red (3 m from it).

## Required

1. **Azathoth further back (51):** 1.6 m toward the back of its deck (south), centred across; scale, height, limbs,
   animation and the W turn as they are; still within the hologram.
2. **Cards forward (52):** every card as above; Azathoth's at the front end of its west side.
3. **Azathoth's close look (53):** over your shoulder, three quarters to its face (it turns to face you), you in the
   lower part of the frame, its limbs filling the rest; the same gentle drift as the others.
4. **You stay in the picture (54):** no hiding your avatar in any close look. Where you would stand between the camera
   and the creature, the camera swings round it a step at a time until you do not; framings that already work keep.
5. **R in a close look (55):** puts the animals whole again; the close look goes on; the strip says so.
6. **The wolf's eyes (56):** the wolf on show is `v2/wolf2.tscn` (both rooms). Its eyes become small 24-cells (the engine
   has no 24-cell mesh; it hulls the 24 points into one), 2.4 cm across, about half set into the face, near black.
7. **All spotlights (57):** one slider in the Tab panel for the kit's shared spotlight multiplier, over each light's
   own values (they stay, their rows still work); saved with SAVE. The hall owns it now (default 3.26: what it ran at
   when entered from room 1, which set it for itself; opened on its own it ran at 1.0).
8. **The room's light (58):** only what the scene has: exposure, the ambient light (how much, warmer or cooler), the
   sky's colours (how bright), the key light the Sun handle aims (strength, elevation, direction), the fill light.
   Live; saved with SAVE; RESET puts back the room's own. No new sun or sky.

## Optional

None asked for. (Not done: a separate ambient colour picker; warmth covers the tint with one slider.)

## Checks

Runner checks for each item (Azathoth back, every card outside its pedestal, you visible in all ten close looks, R in
a close look, the new sliders live with each light's own value kept), frames of the close looks and the wolf's face,
the frame time against round 4's 8.6 ms. Committed locally, never pushed.
