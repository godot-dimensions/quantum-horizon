# Maze Remake 2, the Annex (handover)

`project/ramon/MazeRemake2/maze_remake_2.tscn`, built 10 and 11 Oct 2026 from Ramon's brief "FACE MAZE,
REMAKE 2" (100 steps, autonomous), then round 2 from his notes mid-run (dark, spooky, the Tall Ones,
lore, a slice map). In the menu as **The Annex** (menu_final, the experiments, right after The Maze).
The Phase Maze (`ramon/PhaseMaze/`) and the first remake (`ramon/PhaseMazeRemake/`, The Maze) are untouched.

Beside the scene, `PLAN.md` holds the 100 steps as adapted, the levels on paper, the gizmo trial
(section 9) and round 2's 30 steps.

## Round 3 (12 Oct, after Ramon played it)

- **The niche** in level 1 (behind the amber door, kata) no longer holds the old Phase Maze monitor. It is
  kept as the level's one lesson in going kata: a blue panel "THE OTHER WAY THROUGH W" and the relic (now
  "the amber glint", moved off the panel).
- **Popup explainers** (`hud/mr2_popup.gd`; the game holds you still, Space, Enter or a click carries on,
  Esc closes it too): each level opens once a session with its controls card (every slicing control
  marked YOURS, NEW or LATER: level 1 E/Q and V new, turning later; level 2 the Lens new; level 3 turning
  and R new). After the first sighting's film, "THEY HAVE NOT SEEN YOU": a small diagram acts it out
  (a Tall One in one slice, you walking into it, its eyes going red, you shifting to the next slice)
  beside three lines. Runners turn them off with `popups = false`; the features runner tests the cards,
  the walkers runner the Tall Ones' card.
- **Subdued colour**: floors keep only a faint W hue and grey grid lines; the skirting is a dim neutral
  line; the pools of light are neutral (warm white in the bright rooms; the kennel stays red); decorative
  strips and the Long Hall's panels went grey. Colour stays where it tells you something: door frames and
  passage stripes (the band they open at), the bridges, the lifts, relics, seal lights, the hub's
  landmark pillar, the vault's ring, the HUD, the eyes.
- **The cave's music** (12 Oct): the pen's cave track, Michael Vignola's "Follow Me Nowhere", plays under
  every level, read from `chickenpen/audio/music/` (not copied: 49 MB), looped as the pen loops it (30 s
  to 4 s before the end) subtle at -26 dB, far under the cave's -12 (his ask: "less volume ... just subtle"). Tab has a Music row to trim it; the code-made hum, W tone,
  creaks and the Tall Ones' sounds stay on top. If the pen's file ever moves, the Annex plays on without it.
- **The fence generator, analysed and not used.** The pen's walls (`chickenpen/scripts/pen_town_wall_4d.gd`,
  `pen_ruin_wall_4d.gd`, Andrew's TownWall) use FenceGenerator4D for two things: a solid wall deep in W
  (the town wall: the same as a box), and a masonry rhythm through W (the ruin: its posts stand at seed
  vertices, so they appear only within a post's thickness of those W's, about 0.1 m, then thinner ribs).
  For the Annex's rooms neither adds W readability: a box wall looks the same at every W either way, the
  post rhythm flickers for a twentieth of a second at walking W speed, and what changes with W here
  (doors sliding, walls sinking, bridges narrowing) is already 4D geometry the fence cannot make. It also
  has no collision and costs 3 to 13 ms a build per wall. If walls should show your W motion, the useful
  idea from the ruin is a rhythm of W-thin pilasters, which the Annex's own morph boxes can do (not built;
  question for Ramon).

## Questions for Ramon

None of these blocked anything; each has a default in place.

A. **The name.** "The Annex" on screen (the building the levels are in), folder `MazeRemake2`. Keep it?
B. **Dark is the default now**, B gives the bright lab look back (remembered). One bright room per
   level stays lit in both: level 1's garden hall, level 2's reading room, level 3's Heart.
C. **The Tall Ones' numbers** have no Tab sliders yet: walk 1.15 m/s, notice 5 to 8 m inside an 80°
   cone, eyes red over 0.9 s, catch within 0.95 m, give up 3 s after you leave their slice (W more than
   0.5 from theirs). Want sliders, or other numbers?
D. **The gizmo.** The slice map (bottom right) is the default: rooms as boxes through W, your slice as a
   sheet cutting them, doors and Tall Ones on it, a W bar beside it. The lens (brackets, ring, V) stays on
   the door you face. G still cycles MAP, RULER, DIAL, LENS. Is the map the "power of the slice" view
   you meant, or should it grow (bigger, or full-screen on a key, like the aquarium's tank)?
E. **The Dreamer** in the Heart: this folder's carried copy is gunmetal now, so it reads against the
   Heart's white walls. The pen's own Dreamer is untouched.
F. **The vault's face** in level 3 is a code-blue teaching wall; under the torch, turned, it is a
   very saturated blue. Keep, or darker?
G. **The menu film** is 21 s and 32.7 MB now (round 1: 17 s, 13.9 MB), in the range of the lab films.
   Six shots: the first door, the garden, a Tall One's head turning to you, the ambush, the pit's
   bridges, the turn into the Heart.
H. **The lore** (six logs, amber text on dark glass): Azathoth is named in log 5 as the blind thing at
   the centre whose dream is the world, the Tall Ones its pipers. Tone right?

## What it is

A first-person walk through W. Free mouse look and WASD; E and Q move you through W at walking pace
(the wheel nudges), and the building changes round you: door leaves slide apart, walls sink into the
floor, bridges grow out of the dark. When a door is about 70 per cent open, V finishes it exactly.
Round 2 made it a dark, quiet, slightly frightening place: soft pools of light at each room's own W,
floors whose grid lines glow in the colour of your W band, blue panels, the labs' holographic shimmer in
open doorways, and grey Tall Ones that only see their own slice.

## The levels

1. **The Threshold.** The corridor and the teal door (first door within a minute), the garden hall ana
   (the bright room, an oak), the second door, then the Long Hall: the first Tall One stands in it, and
   the first sight of it plays a short film (it has not seen you, not yet). Log 1 says what to do: move
   through W. The third door opens further ana than it can see. The amber niche kata holds a relic.
2. **The Stacks.** A 3 x 3 grid of bays whose doorways open at different W, so the same door leads to
   different rooms. The archive (home) has two Tall Ones pacing its aisles; kata it is the computer room
   and they are not there. The reading room (home) is the bright sanctuary. The pit's amber and teal
   bridges, the Lens in the north-east bay (its film turns the view into W). Then **the ambush**: a slab
   in the north-east wall sinks ana and five Tall Ones walk out of the kennel behind it. The lift's
   door only opens at home now, so you shift home (they lose you) and leave. Logs 2, 3, 4.
3. **The Heart.** The dark atrium and its crystal. Shifting ana at the centre stops dead: the vault
   stands there, and its doorway faces kata, so you can only see it by turning your view into W (right
   drag, V finishes). Two seals: the amber door kata (a Tall One walks the atrium at W -1.9; go through
   at W -2.5 and it never sees you), and the weave's three gates (one Tall One stands at home past the
   second gate; shift ana and walk on). Both lit, the grid goes; walk in along W to the Heart (white,
   warm, the Dreamer inside), the finale, the end card (Enter plays again, Esc to the menu). Logs 5, 6.

## Controls

WASD walk, mouse look, Shift sprint, E/Q (or wheel) move through W, V align / finish a reveal, right
drag turn into W (once you hold the Lens), R level the view or back to the room's W, Backspace back to
the room's way in, B dark or bright, G cycle the gizmo, F1 HUD, Tab tuning panel (SAVE/RESET), 1 2 3
levels, Esc asks before leaving (and skips a film / closes the panel first).

## The Tall Ones (`world/mr2_walker_4d.gd`)

**The body (12 Oct, Ramon: "more lofted humanoid beings", built the Creature Lab's way).** The wolf,
horse and goat in the Creature Lab are ball rigs: chains of shaped cross-sections lofted into a hide,
each ball with its own colour baked into a ramp texture. The Aquatic Lab's hammerhead cuts such lofts
into rigid pieces that only turn at joints. The Tall One is both: 16 lofted pieces (pelvis, ribbed
trunk with a hunched back, long neck, an oval skull swept back with a dark visor band where the two tiny
eyes sit, upper arms, forearms, hands with four long fingers, thighs, shins, flat feet), their sections
written as data in `_piece_lofts()`, lofted once and shared by every Tall One, four greys on the ramp.
About 2.9 m tall, the fingertips below the knees. Every section is shaped by its own basis (the
hammerhead's rule), so a palm is thin across and wide front to back whatever way its spine runs. It
breathes, sways, turns and tilts its head now and then; walking, the swinging leg's knee bends and the
feet stay flat. Look at it from every side with `scripts/_walker_look_runner.gd`.

Each lives at one W: the trunk and head are 0.5 thick in W either side, the limbs 0.42, so as you shift
away the limbs thin out of your slice first and the trunk last; it collides only at its own W.

**How they behave (12 Oct, round 4: "how they see you at what angle, and when not.. walk pace
differences ... how the walk looks").** An awareness meter, 0 to 1, fills while it perceives you:
- sight from its eyes, so it turns with the head: a central cone 32 degrees either side out to its notice
  range, fastest close; a peripheral cone to 72 degrees, 60 % of the reach, a third as fast; nothing beside
  or behind; never through a wall
- only within 0.5 m of its W, and at half strength in the last 0.2 m of that (the edge of its slice)
- standing still you are half as easy to see, running nearly twice as easy; right at its back (1.7 m) it
  feels you; running within 6.5 m it hears you, round corners too
- at 0.3 it turns suspicious (stops, head to you, then body, then a slow step or two; eyes warm), at 1 it
  has you (the sting, eyes full red, head snaps), and hunts at 1.35 m/s, 1.6 within 4 m (it paces at 0.5;
  you walk 3.4), arms coming up as it closes. Lose its slice or its sight: it walks to about a metre
  short of where it last saw you (on the spot, its body would block you shifting back) and looks about
  for 5 s, still primed, then walks home.
- measured by `scripts/_walker_senses_runner.gd` (3 m ahead: 1.25 s; 6 m: 2.5 s; 50 degrees off at 3 m:
  2.65 s; at its back: 1.7 s; running behind: 1.7 s; edge of its slice: 2.9 s; beside, behind, out of its
  slice: never)

The walk is matched to its real speed (stride 0.5 to 0.8 m, cadence = speed over stride, so no skating);
the hips drop at each footfall, shift over the planted leg and twist, the trunk twists back; the arms
swing against the legs; standing it shuffles round as it turns; idle it breathes, shifts its weight, tilts
its head and now and then twitches. `scripts/_walker_clip_runner.gd` films it side-on (pacing, hunting,
searching) at a fixed 30 fps. States: idle (standing or pacing), notice (eyes grey to red,
a sting), hunt (a slow walk to you), return. Line of sight is a ray at its own W. Caught: a red flash,
back to the room's way in, every Tall One back at its post. The level owns them (`add_walker` in
`levels/mr2_level_4d.gd`); the slice map shows them, red when they are after you.

## Tests (all through the real keys, frames in `project/smoke_test_output/maze_remake_2/`)

Run with the gated launcher: `bash project/ramon/MazeRemake2/scripts/run.sh windowed <name> <runner>`.

| Runner | Result (11 Oct) |
|---|---|
| `_play_l1_runner.gd` level 1 start to lift, the sighting film, past the Tall One, the niche | 16 of 16 |
| `_play_l2_runner.gd` level 2, the Lens film, the ambush, home to the lift, side rooms, a fall | 19 of 19 |
| `_play_l3_runner.gd` level 3, the turn, both seals past both Tall Ones, the Heart, end card, replay | 23 of 23 |
| `_walkers_runner.gd` sighting film, notice, red eyes, lose by W, caught and respawn, ambush with the film skipped, the weave | 19 of 19 |
| `_features_runner.gd` Tab panel, Esc order, B, F1, G, wheel, R, Backspace, level keys | 20 of 20 |
| `_menu_roundtrip_runner.gd` launch from menu_final, Esc's WayHome question, back | 6 of 6 |
| `_perf_runner.gd` (vsync off, wall clock) | L1 1.0 ms, L2 1.5 to 1.8 ms, L3 3.1 ms; GPU under 0.7 ms |
| `_hud4k_runner.gd` | the HUD at 3840 x 2160 reads |

`_debug_views_runner.gd <level> [hud] [lenstaken] "x,z,w,yaw,pitch[,tilt]" ...` photographs any spot.
The menu film: `bash project/ramon/Menu/films/film_run.sh the_annex res://ramon/Menu/films/the_annex_film_runner.gd`,
then copy `smoke_test_output/menu_films/the_annex.ogv` to `Menu/thumbs/`.

## Known limitations

- Not played by a person yet; all of the above is the bot.
- The Tall Ones walk straight at you and slide along walls; they do not path round furniture. The
  kennel opening sits north of the sculptures' bench for that reason.
- Godot reports "2 resources still in use at exit" when a runner quits mid-level (harmless).
- The atrium in level 3 is bluer than levels 1 and 2 (slate walls under blue pools); tune `dark_lift`
  in `level_3_4d.gd` or the pools if it should match.
- Physics is boxes only: every morphing solid collides as boxes stepped every 0.1 m of W.

## Files

`maze_remake_2_4d.gd` (the game: levels, films, HUD feed, sightings, deaths), `player/` (the body,
look, W, turn), `world/` (morph boxes, the builder, light, the Tall Ones), `levels/` (the base and three
levels), `hud/` (HUD, slice map, ruler, dial, lens, key cards, Esc guard, tuning panel), `audio/`
(all sound made in code), `carried/` (copies from the Creation Lab kit, the pen's ground basis, the
Botany Lab's oak, the Dreamer: change these, never the originals), `scripts/` (runners and the bot).
Menu: `Menu/entries/catalogue_final.tres` (Resource_annex), `Menu/films/the_annex_film_runner.gd`,
`Menu/thumbs/the_annex.ogv` + `the_annex_still.png`, `Menu/icons/lab_icons_bold/icon_annex.png`.
