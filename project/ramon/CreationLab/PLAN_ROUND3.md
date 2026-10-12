# Creature Lab, round 3 (Ramon's walkthrough Part 3, items 25-42; 10 Oct 2026)

Builds on `PLAN_V2.md` (round 2: the fork `creature_lab.tscn` and the hall `hall/creature_hall.tscn`). Keep what
works: the creature animations, the room layout, the transitions and loading boards, the specimen swap.

**The name.** "Nightpic" / "Nikepeg" is **Nike**, the pen's pig (speech to text). On screen: Nike.

**The principle (Ramon):** a living exhibition in a stable building. The creatures and trees are the 4D subjects;
walls, floors, pedestals, paths, doors and signs never change when you turn W.

## Required

### First: what is broken
1. **Nike stuck (31).** Cause: the leash (`nike_antics.leash`) stops him the moment he is past its radius, and
   checks again on the first frame of every walk, so once out he can never walk back in. The pen only uses it in
   a conversation. Fix: no leash; his own roam (heads home when he stops past `roam_radius`), shorter walks so he
   stays on his deck; the deck clamp stays.
2. **Tab light panel in the hall (40).** The hall has none. Carry the lab's per-light panel (as the other labs
   have it), every hall light on it, strength and the rest, Save defaults.
3. **The building stays still under W (38).** In the hall the view's slice no longer turns. Right drag turns
   every creature and tree through W, each round its own middle (a turn pivot that keeps its position exactly
   where its walk puts it, so walking, roaming and flight are untouched); R "Whole again" levels them. The
   room, pedestals, paths, doors and labels never move. The same rule room 1 and the Voxel Lab already follow.
4. **Dark mode everywhere (42).** The top-right toggle as the other labs have it ("DARK MODE ON / OFF"), and the
   change reaching every hall node, as it reaches room 1.

### Second: the creatures
5. **Horse out (30); Azathoth in (36)** on its spot: the cave's creature, its pedestal a step bigger than the
   horse's, technical (dark base, grid lines, blue centre, the hologram frame wider), always turned to you,
   W included, and alive.
6. **A framed label at every creature (28)**, the Botany Lab's: near the front edge, facing you, the name and a
   line or two (from the cards' words).
7. **The chipmunk (32)** twice the size, a tail you can see, the model a little better; it still fits its stand.
8. **Close look (33)** for the small creatures (chipmunk, owl; any station can ask): E near one, one well chosen
   camera, the creature still alive, any key or click to come back. Reusable per station.
9. **The holograms round the pedestals (37)**, the other labs' treatment, on every creature pedestal, strongest
   round the brachiosaurus.

### Third: the room
10. **Green and grass (29)** on the ordinary pedestals: green decks and the pen's grass (a lab copy), a little
    shorter, about as dense, never over the animals' feet. Azathoth's stays technical.
11. **Tree pedestals (34)** just wider than the trunk, green.
12. **One door into the showcase (27):** no room 2. The title over room 1's back door, the hologram in the
    door itself (inside the wall's thickness, the doorway's own size); the same for the hall's door. The boards
    and the way back stay.
13. **Entrance flicker (25):** the corridor's ceiling ran 0.5 m on past its open end, through room 1's entrance
    wall, its end face on the wall's face. A kit room option keeps a ceiling flush on its open sides, on for this
    entrance only.
14. **Path dots (26):** the dotted guide of the side routes went from about 2 to 6 cm when the guide line was made
    three times wider. Dot size and colour become settings of the path network (unchanged by default; the pen
    keeps its look); here small and a lighter cyan. Line widths and the arrival marks as they are.

### Fourth: polish
15. **Birds (39):** the crows already fly short loops round their perches and land again; check they keep to
    their station. The heron gets a loop that leaves its deck and comes back to the same spot.
16. **Lighting (41):** the hall a little dimmer, the creatures still clear, the holograms still read.
17. **Dark walls (42):** walls should keep their lines in dark mode, not go flat black; fix if not intended.

## Optional
- **The cat (35):** a small green pedestal, label and all, only if the model holds up and there is room. Judged
  by a frame: **left out.** On its deck between the wolf and Nike it did not read at all (a black cat, low in dark
  grass, from the path), and its sit and wash cannot show after the walker cuts its hide. Built and taken out again;
  the gap stays open.

## Checks
Runners updated: Nike walks, the building is still while the animals turn, Tab opens the lights, dark mode on
both scenes, Azathoth faces you as you move and step through W, the close look comes and goes, frames of every
station in both modes. Then the handover (`follow_up/creation_lab_v2.md`), committed locally, never pushed.
