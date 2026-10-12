# The Watchstone and the range: a medieval, ritual-tech remake (6 Oct 2026)

Ramon, 6 Oct, with two concept paintings: "a medieval, rural, ritual-tech aesthetic. The lore would
be that we've infiltrated this 4D world as futurists conducting research, which explains the sci-fi
elements, pop-up doors, and other technology." The watchtower becomes a rock crag with timber
walkways ("remaking the watchtower like this, come up with a new name"); the shooting range is
replaced outright, all its mechanics removed except a rune stone that takes you to the Quantum
Range. Both are units, instanced into the pen; the old ones are kept as copies, linked from nothing.

**The name: the Watchstone.** A crag that people watch from, a stone with a watcher on it; it
sounds like a place in a field rather than a building.

## What the references ask for

- **The Watchstone.** A tall crag of big, chunky grey boulders, wider at the foot, moss and grass on
  every ledge, a flat grassy top inside a timber railing. A timber boardwalk starts at the foot,
  climbs the face in runs between landings, and a tall braced scaffold carries the last platform; a
  short ladder from it reaches the top. You walk up the first slope only; then you are on top.
  Wren stands up there: no longer a ranger, a man with a beard in dark brown cloth, already looking
  out through his goggles.
- **The range.** A yard of trodden sand in a timber rail fence, three round target boards on timber
  stands with glowing runes (a dot, a diamond, a triangle) against a rocky outcrop, a table with
  three ritual-tech rifles on a red runner, a banner on a timber frame (maroon, a gold diamond), a
  barrel, the range master, and a stone block with a glowing diamond on top. The boards are only to
  look at. The block is the button: F there takes you to the Quantum Range.
- **The rocks** are the paintings' own: big, chunky, faceted, light grey, rounded at the edges, moss
  on top. Made as 4D shapes (dual-contoured, as the cave's rock face is), not boxes.

## The plan (20 steps)

Order: the look first, as two new unit scenes you can open and walk round, shown in frames; then
the wiring, once you have seen them.

### A. Safe to change (1-3)
1. **Copies.** Git tag `before-watchstone-2026-10-06`. The old tower unit, the range unit and their
   scripts copied to `chickenpen/.backup/2026-10-06_before_watchstone/`, referenced by nothing.
2. **The rock kit.** A chunky 4D boulder recipe: a rounded block cut by a few planes at random
   angles (the chiselled faces), its edges softened, dual-contoured like the cave's rock face, moss
   on the faces that look up. Six variants baked to files, instanced many times at different sizes
   and turns. Frames of each from the front, the side and two W; tetrahedra counted.
3. **Scale and place.** From the paintings against the player's height: the crag about 13 m tall
   and 11 m across at its foot, its top about 8 m across; the range's yard about 14 by 8 m. Laid
   out top-down against the paths, the balloon's mooring and the marsh and wood spots.

### B. The Watchstone (4-11)
4. **The crag.** Boulders stacked big to small into a tapering crag with ledges, as deep in W as
   the old deck (so it is a 4D rock, not a cardboard one), in `units/watchstone/watchstone.tscn`.
   Box colliders in tiers, as the cave hill has.
5. **Green.** Turf on every ledge and a grassy plateau on top, moss tufts in the cracks, a few loose
   stones round the foot.
6. **Timber.** The boardwalk: a walkable first run from the ground (a sloped deck over low steps,
   physics being boxes), landings on braced legs, runs up the face, the tall braced scaffold to the
   upper platform, the ladder to the top. Railings from the fence tech; posts and braces as beams.
7. **The top.** A timber railing round the plateau (the fence tech on a polygon footprint), a gap
   at the ladder.
8. **Wren, restyled.** A man, bearded, in dark brown cloth, goggles over his eyes, standing at the
   plateau's edge looking out. The same shared body with different clothes, as every character is.
9. **The walk-up.** Walk up the first run to its landing: the screen fades and you are on the top,
   facing out. At the ladder's head on top: fade, and you are at the foot. The old climb (F at the
   ladder, rung by rung) retires for the Watchstone. The Watchstone answers everything the Lookout
   asks of a tower (on the deck, the ladder's foot and top, its height, its outline on the dial,
   the owl's perch), so the photography, the balloon and the journal carry on as they are.
10. **Wren's story from the top.** Meeting him moves up there: the walk-up is open, the camera is
    handed over on the top. His lines changed from "her" to "his"; every changed line listed for you.
11. **Into the pen.** The LookoutSite instances the Watchstone instead of the tower; the balloon,
    marsh and wood spots stay; the path's end moves to the boardwalk's foot. The Lookout's tests
    (lookout, story, site, ride, marsh align) made to walk up rather than climb, and passing.

### C. The range (12-18)
12. **The yard.** Trodden sand (the pen's own painted sand), a timber rail fence on three sides from
    the fence tech, open toward the table; stones and grass clumps along its edges.
13. **The outcrop.** The rock kit piled behind the targets, moss on top.
14. **The boards.** Three round stone-faced boards with rings, each on a timber A-frame with iron
    straps, and a glowing rune at the centre (a dot, a diamond, a triangle). The glow from the lab
    kit's unshaded glow shader, since the renderer has no emission.
15. **The table.** Three ritual-tech rifles (stock, barrel, brass bands, a small glowing rune) on a
    red runner, a banner on a timber frame (maroon, a gold diamond), a barrel beside it.
16. **The rune stone.** A tapered stone block with a glowing diamond set in its top. F there takes
    you to the Quantum Range, through the pen's existing trip (another window's code, called, not
    changed). A prompt over it.
17. **What goes.** The booth, the local shooting (`Systems/RangeShooting`) and the old targets leave
    the pen. The range master stays by the table, and so does his talk. The old scripts stay in the
    repo, referenced by nothing.
18. **Into the pen.** The Range unit replaced; the path's end kept at the rune stone. The old
    shooting test retired; a new test: F at the rune stone starts the trip.

### D. Proof (19-20)
19. **Frames and numbers.** Both from the paintings' angle, at W 0 and two W either side, in volume
    view; tetrahedra and frame time against today; the layout check and the pen's tests.
20. **Handover.** A note in `follow_up/`, the lines for you to read, commits by explicit path.
