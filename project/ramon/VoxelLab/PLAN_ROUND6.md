# Voxel Lab, round 6 (10 Oct): Ramon's walkthrough parts 8 and 9, items 60 to 75

His order. Part 8: the title, then the big landscape's fixed square, then keep the water, trees, grass, foam
and presets as they are. Part 9: the gentle swell, the platform held still, the up and down keys (platform
and bird), tree controls and the lighthouse, the desert and the lava, then performance and the way back.

## Part 8 (60 to 64)

1. **"How a World Is Made"** (#60). The sign's title is two lines now, "HOW A WORLD IS / MADE", in the same
   type. The sign paints each line and shrinks the size only if a line would not fit
   (`carried/kit/kit_wall_text_4d.gd`, the "sign" kind; the title in `tools/make_scene.py`).
2. **The big landscape keeps its square** (#61). A drag no longer turns it (no more "helicopter"). The
   pedestal and its square footprint stay put, and a drag sweeps the slice through W instead, back and forth
   like a triangle wave, 0.7 of the land's W reach either way. The land changes inside the square as you go,
   with no gaps and no hard stop: the sweep turns back at the end (`sweep_w` on the terrain case,
   `kit_showcase_4d.gd` `turn_by` and `_process`). The wheel and Q/E still step through W, R puts it back.
   Possible here because the land is built deep in W: a sweep only moves the cut.
3. **The three small layer specimens** (#62) keep their rotation, untouched (only the terrain case has
   `sweep_w`).
4. **Foam** (#63). The band is narrower (0.06 m against 0.25) and it comes mostly where crests reach the shore.
   The crest test now measures against the live waves' own height (`crest_ref`), so a calm sea still has
   crests to foam on. Bubbles are a third of the size (0.08 m against 0.24 in your saved file). Water depth
   and how far you see into it stay on Tab. Your saved file changed only in those three foam numbers
   (`shore_width`, `foam_cell`, `shore_breakup`). Everything else is as you saved it.
5. **Presets** (#64). All eight kept, Calm as before, your saved preset (1) untouched.

## Part 9 (65 to 75)

6. **Moderate swell, gentle** (#65). A ninth preset on Tab. The Aquatic Lab's Moderate swell train (five
   waves round one wind, so the cross pattern stays), half the height, half again as long, with Calm's softer
   steepness, still Gerstner. It lives in `field/vl_sea_4d.gd` (the Aquatic Lab's presets file is not
   touched).
7. **The whole walkway holds still** (#66). The slice's hold used to turn only the blue disc, so the grey
   pier and the deck slid while you sliced. Now it turns everything you stand on together (`raft`: the deck,
   the pier, the stations, the rails, the disc). Every position is worked out from the deck's home
   (`_deck_at`), never from the turning node.
8. **The Turn the Slice page** (#67) sits 0.5 m right of the disc's middle (`PAGE_SHIFT`). Its weight is on
   its left (title and lead), so it now reads centred from above.
9. **The platform lifts** (#68). On the blue, Space takes it up and Shift takes it down: 4 m a second, up
   to 40 m over where it was built and down to just over the sea. You ride it, and its floor rides with it.
   Lifted, two bars close the ring's opening toward the pier; they go again at the bottom. Hint on
   the page ("Up (Shift: down)") and along the bottom while you are on the blue. The same keys as the bird.
10. **The bird's dive** (#69). Shift used to fold the wings and nothing else, so unless you pitched down with
    the mouse nothing happened. Now held Shift takes the nose down to a stoop and you drop; let go and the
    mouse has it again. Flight is otherwise as it was.
11. **Props on each land** (#70, #72, #73). One scatter for all of them, with a new Tab window, PROPS ON EACH
    LAND. For each prop: clumps, how many in each, how far a clump spreads, size. Each clump is denser
    towards its middle, so clumps read tighter: trees spread 2 m by default, half of round 5's. Seeded, so
    the same each time; planted again a moment after you let go of a slider. Trees keep their three greens.
12. **The lighthouse** (#71). On the green island, on a high point by the shore in sight of the platform: a
    stone foot, red and white bands up a tapering tower, a dark gallery, a lantern that glows and breathes,
    a red cap. All discs, 2.5 m deep through W, so it holds as you slice.
13. **The red desert** (#72). Red sand, red-brown dirt, dark red rock, and a red clay pan where the white salt
    flat was (the station's case too: one palette, `stations/vl_case_exhibit_4d.gd`). Strata on the slopes,
    bands of darker and lighter red wobbling with the noise, and a faint wind ripple on the flats (the land
    shader). Mesas and buttes as Monument Valley has them: a skirt of fallen rock, a sheer cliff in thin bands of
    red each a little off the last, a paler caprock (the first try, three equal drums, read as barrels). Small
    saguaro clusters (a trunk and one or two arms). Each with its Tab controls.
14. **The lava field** (#73). The lava moves: two layers of noise drift through it over time, a black crust
    in plates where it is cool, bright cracks between them, orange to yellow where it is hot, glowing and
    breathing; deep red to orange, yellow only where hottest (the first try was yellow all over and read flat).
    The rock just over it is warmer, a few of its cracks faintly alight in patches. The rock elsewhere has
    patches of ash and rust. Embers rise and drift from the lava, and small molten bubbles swell and burst on
    it (70 and 18, recycled; one switch on Tab). Tiny volcanoes in clumps (seven steps narrowing to a cone, a
    glowing crater), with Tab controls.
15. **The way back** (#75). The Change the world station now names every other land. On the desert or the
    lava field option 1 is always "Back to the green island". On arrival a toast says how to come back (7
    s), the loading board says it, the station's panel says "KEY 1 HERE TAKES YOU BACK TO THE GREEN", and the
    keys along the bottom start with it while you are away. The HUD's "You" row names the land you are on.

## World switching performance (#74): what it does, what it costs

- **One world at a time already.** A switch frees the old landscape before the new one builds, so memory
  never holds two. The green island is about 656 chunks, 2.0 million tetrahedra and about 2.4 GB of video
  memory.
- **Green to desert or lava (and back): built again, about 8 s behind the board.** The land's shape is the
  same in all three. What differs is the generator's sea: on the green island it is empty (our moving water
  is a separate mesh), on the other two it is filled with voxels (the clay pan, the lava). The voxel world
  cannot change that without building again. The ground is then mapped again (0.2 s, on a worker) and the
  grass baked for the green (under a second, on a worker).
- **Desert to lava (and back): instant.** Only the palette changes, then the props are planted again (a few
  ms).
- **Nothing unnecessary found.** The grass is only baked for the green, the props are cheap, the height map is
  needed because the ground changes.
- **Keeping two worlds built** would make every switch instant but doubles video memory (about 4.8 GB). Not
  advised while the PC is short of memory (the crashes of 9 Oct).
- **To make every switch instant** (not done, it is a rewrite): build the land once with an empty sea for all
  three, and draw the desert's clay pan and the lava as a flat mesh at sea level, as the green island's water
  already is. Every switch would then be a repaint. The cost: the lava would be a plane with its own shader,
  not voxels; the land shader's molten part would move to that plane. About half a day.

## Also

- The big landscape's key strip says "Right drag: Sweep through W" (it said "Turn in 4D").
- Leaving the open world while the ground is mapped or the grass baked (on worker threads) now waits for them
  first. A runner crashed quitting mid-bake; a player leaving by the door at that moment could have too.

## Tests

- `field/_capture_field_runner.gd`: the whole deck turns with the slice; the desert's options (option 1 the
  way back), its props, an overview and a mesa; on to the lava (a repaint), its embers and spots, an overview,
  the lava close twice (it moves), a volcano; back to green with key 1 at the station; the lighthouse; the lift
  up with Space and down with Shift; a view of the lighthouse from the platform.
- `scripts/_probe_terrain_runner.gd`: the square foot never turns, a drag sweeps the slice through W.
