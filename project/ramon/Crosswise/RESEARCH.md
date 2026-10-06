# Crosswise: research (5 Oct 2026)

What Miegakure does, what its maker says about it, what players said, and what that changed in
this remake. Sources are linked inline. Quotes are kept to a minimum; everything else is a
paraphrase.

**First, a correction to the brief's premise:** Miegakure has not been released. Steam still says
"Coming soon" (checked today in the browser, store page app 355750, no user reviews), and the last
public showing was SIGGRAPH 2025 Real-Time Live ([SIGGRAPH blog](https://blog.siggraph.org/?p=19413)).
So there are no Steam reviews and no Reddit threads about finished levels; the player evidence is
from press hands-ons at demo events (2009 to 2015) and forum comments. Reddit could not be reached
from this session's fetcher.

## 1. The mechanic, in its maker's words

- **One horizontal axis swaps with W, the other never does.** Marc ten Bosch uses Z for up and
  never swaps it (so a jump is always a jump); X is left untouched; only Y, a horizontal axis,
  trades places with W, by a 90 degree turn interpolated smoothly. Two axes always stay, so one
  whole plane never changes and what stands on it is a reference point
  ([Nature as Designer, 2014](https://marctenbosch.com/news/2014/10/nature-as-designer-there-was-only-one-way-to-design-miegakure/);
  [Parallel Universes, 2015](https://marctenbosch.com/news/2015/02/miegakure-and-understanding-and-parallel-universes/)).
  In our Y-up engine that is: keep X and Y, swap Z with W. The old prototype already did this.
- **A button, not free rotation, and you only move in what you see.** Walking through W blind
  means hitting things you cannot see, so seeing and moving stay coupled; free rotation and
  sliding the slice come only late in the game ([miegakure.com FAQ](https://miegakure.com/)).
- **The swap is a smooth transition** that a reporter described as the world folding like an
  accordion ([Engadget 2014](https://www.engadget.com/2014-04-22-miegakure-solves-puzzles-breaks-your-brain-in-the-4th-dimension.html)).
  No source gives its length.
- **The player is a 3D figure with a little W thickness,** which is what lets it collide with 4D
  things ([Dec 2014](https://marctenbosch.com/news/2014/12/new-screenshot-miegakure-on-ps4-interviews-collision-detection/)).
- **Levels are small,** for example 4 x 4 x 7 x 4 tiles, so the player can hold the whole level in
  their head (Nature as Designer). About 140 levels, each with one idea
  ([May 2015](https://marctenbosch.com/news/2015/05/counting-levels-of-each-type/)).
- **The name:** miegakure is the Japanese islands technique of showing a thing only in part, so the
  rest is imagined: seeing three of the four dimensions at once
  ([Game Developer 2010](https://www.gamedeveloper.com/pc/road-to-the-igf-i-miegakure-i-s-marc-ten-bosch)).

## 2. The puzzles that are documented

- **Around a wall through W:** to a 3D onlooker you vanish and reappear on the other side
  ([trailer post](https://marctenbosch.com/news/2014/08/new-trailer-how-to-walk-through-walls-using-the-fourth-dimension/)).
- **Stealing from inside a closed building:** a temple sealed in 3D but open along W; you walk in
  from the W side, take a block and use it as a step to the exit, and an NPC shouts "thief"
  ([Game Informer 2015](https://gameinformer.com/games/miegakure/b/pc/archive/2015/05/25/indie-puzzler-miegakure-will-help-you-understand-the-forth-dimension.aspx);
  [talk slides](http://marctenbosch.com/miegakure/data/Marc%20ten%20Bosch%20-%20Exploring%20and%20Presenting%20a%20Game's%20Consequence-Space.pdf)).
- **A ledge with no block:** walk to a world that has one and push it into the world you need it in
  ([PC Gamer](https://www.pcgamer.com/miegakure-preview/), from search snippets).
- **Others:** two rings bound together, a mirror image from a 180 degree W turn, a box taken out of
  a closed box, things floating in mid-air. Marc's "main miracles" are going around walls, binding
  two rings, and stealing from inside a closed building
  ([2019 update](https://marctenbosch.com/news/2020/01/miegakure-update-end-of-2019/)).
- **How he orders them** (the slides): one consequence per level, split a level when players can't
  take it in; 3D-only levels that teach pushing and jumping on their own; let simple levels be
  brute-forced, which builds intuition; make the starting state suggest a first move; avoid states
  you can't get out of.
- **Not in any source:** carrying, breaking, ladders. Pushing is Miegakure's interaction. Our
  carry and two-strike rock are new, so they get taught on their own before they meet W.

## 3. How Miegakure stays readable

- **The ground is banded.** Marc: they "texture the ground differently at intervals, to group
  parallel worlds together" (Parallel Universes). His slides show grass worlds next to raked-sand
  worlds.
- **The plane that never changes** holds the anchors; trees and lanterns are placed so you keep
  track of where you are (Game Informer 2015).
- **Hints of what is just out of the slice:** raked circles round grove pillars grow before a
  spherinder appears and shrink after it goes
  ([Spherinder Grove](https://marctenbosch.com/news/2016/11/spherinder-grove-video/)); grass
  floats because its roots are elsewhere in W.
- **Sound** changes with what should be audible across W
  ([Sep 2021](https://marctenbosch.com/news/2021/09/miegakure-update-september-2021/)).
- **Characters react** to your "miracles"
  ([2017](https://marctenbosch.com/news/2017/04/the-world-of-miegakure-concept-art/)).
- **No HUD** in any screenshot; no axis gauge or ghost of the other slice is described.
- **Art direction:** detail without noise, geometry rather than fine textures (which shimmer during
  the transition), tree canopies modelled to slice well and kept nearly one colour
  ([Nov 2020](https://marctenbosch.com/news/2020/11/miegakure-update-november-2020-4d-art-direction/)).

## 4. Where players get lost, and what delights them

**Confusion** (all demo-event accounts):
- PC Gamer got through about six levels without understanding how; at first read the turned view
  as one other world, not as a stack of slices you can step onto; did not realise that where you
  stand when you turn decides which part of the other worlds you see
  ([PC Gamer](https://www.pcgamer.com/miegakure-preview/)).
- GDC 2009: it broke about half the audience's brains ([press page](https://marctenbosch.com/news/?p=3)).
- A forum critique calls slicing the "lossiest" view, hiding all but a thin subspace
  ([superliminal](https://superliminal.com/cube/pages/701.html)).

**Delight:**
- Once it clicked, PC Gamer found it fantastic; Wired's writer realised he knew where to stand in
  4D to solve a level ([Wikipedia](https://en.wikipedia.org/wiki/Miegakure)).
- Rock Paper Shotgun figured it out by toying with it
  ([hands-on](https://marctenbosch.com/news/2014/03/hands-on-miegakure/)).
- PAX 2014: over 400 plays averaging about 23 minutes; a 9-year-old coached her father
  ([PAX](https://marctenbosch.com/news/2014/09/miegakure-at-pax-prime/)).

## 5. The screenshots (looked at in the browser, 5 Oct)

From miegakure.com (`MKTemple`, `MKPillars`, `Windmill`, `WindmillRotated`, `MKCrystal`) and the
Steam store's five screenshots:

- **Floating islands cut like slabs of cake**, thick dark sides, seen from a high three-quarter
  view. The island and its one big landmark (a pagoda, a 120-cell dome, a windmill, a stand of
  maples) **fill most of the frame**; the sky is a margin, not a subject.
- **A pale mint cloud sky** in the normal view. In the turned view (`WindmillRotated`) the sky is
  **deep blue with white clouds and a mirror-like reflection** under the island, and the windmill
  has come apart into floating slabs. The sky alone says the world has changed.
- **Cut faces are coloured:** where the slice cuts a solid, the faces read deep violet-blue (the
  island's sides, the 120-cell's struts, the windmill's slabs).
- **The character is tiny,** red and blue, about a twentieth of the frame's height; it is the only
  saturated warm thing on the island, so it is never lost.
- **Raked sand rings** round standing stones (`MKPillars`): ground graphics that mark where
  something stands in other worlds.
- **Crystals** (`MKCrystal`): faceted, flat-shaded, blue-grey on orange sand. Flat facets are
  exactly what our cross-section renderer draws, so this is the Miegakure look we can match best.

## 6. Ten lessons, and where each lands in the plan

| # | Lesson | Where it lands |
|---|---|---|
| 1 | Never swap the vertical axis; keep X; anchors on the X-Y plane | decisions 1-2; landmarks spanning Z and W (step 16) |
| 2 | Keep moving through W coupled to seeing W | decision 1: no W key, only the swap |
| 3 | Small rooms, few objects, hold it all in your head | islands 12 m x 8 m of W, five lanes, one idea each |
| 4 | Each W lane its own ground; teach that the turned view is a stack of worlds | lane code (steps 13, 49); kata lanes cool slate, ana lanes warm sand |
| 5 | One idea per room; teach carry and the strike in plain 3D before mixing with W | a crate step at the end of island 1; a plain rock at the start of island 3 |
| 6 | Make each solve a "miracle" a 3D onlooker would notice; let someone react | a small onlooker on island 1 who loses you and finds you again |
| 7 | Signal what is near in W (growing rings, sound that fades with W) | the near-the-W-edge tint (step 7), W cues (51), footprint frames (52), W-faded sound (70) |
| 8 | Geometry and broad colour, not fine texture or tiny props | dev textures at a large scale with mipmaps; no small props on routes |
| 9 | Show how a new thing looks when cut through W before relying on it | the plain-3D rock first; the crate is a 4D cube that looks the same in both views |
| 10 | Breaking can't be undone: a cheap reset and a start that suggests the first move | R restarts the island; arrival rings; key icons and W cues at each island's start |

**Where this remake departs from Miegakure on purpose:**
- **Carrying instead of pushing.** The brief asks for it, and on a diorama a crate overhead is
  easier to follow through a turn than a push along an axis you just turned away from.
- **A small HUD** (the view badge and a W ruler). Miegakure has none; ours is a research showcase
  for people new to 4D, so it says where you are in W in one glance, and it can be hidden.
- **The cage on island 2 echoes Miegakure's "stealing from a closed building".** That is the
  brief's own retrieval beat and the purest 4D idea there is. Ours is different in what you take
  (a crate you carry overhead) and what it is for (a plate that slides a bridge out), and the cage
  is see-through, so you watch the crate sit inside it from every angle.
