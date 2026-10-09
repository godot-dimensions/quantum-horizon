# Menu layout and labels: review for the menu window (9 Oct 2026, 16:30)

From the startup window, for whoever works on `res://ramon/menu_final.tscn`. Scope: the menu's layout
and labelling only, not the prototypes' detail copy. I changed nothing: this is read only, based on the
files on disk at 16:28 (`Menu/entries/catalogue_final.tres` saved 16:16, `menu_a.gd` 16:04,
`menu_final.gd` 16:01) and your frames from 16:17 (`smoke_test_output/menu_review/final/families_*`).
If you have changed things since, skip what no longer applies.

Only section 1 is Ramon's decision. Everything after it is a suggestion for him to accept or reject.

## 1. Ramon's decision: the films go, entirely

"those need to go, those film names entirely." Take "Flight of the 4D Starlings" and "Mountain Range" off
the menu everywhere: the row under the list (`menu_a.gd` `films_row`, line 411), the route view's film
names (`menu_a.gd` 612 to 672), the number keys that play them (`menu_final.gd` 1676), and the films'
heading in the detail pane (`menu_final.gd` 1460). They all read `catalogue.cinematics`, so emptying
that array in `catalogue_final.tres` should take them all out at once. The films themselves stay: the
murmuration still plays in the playable world (its Cinematics card, K). "Remove" here means off the
menu, not deleted.

## 2. Suggested structure

Keep the two groups and their members. Rename the headings and change the order:

- Headline: "Three experiments to play. Four labs to explore."
- **THE EXPERIMENTS**, subline "Learn to read 4D by playing": Crosswise, The Maze, Shooting Range
  (easiest first: read a slice, then move through W, then act across it).
- **THE LABS**, subline "How our 4D world is built, measured live": Voxel Lab, Botany Lab, Aquatic Lab,
  Creature Lab (the world from the ground up: the ground, what grows on it, what swims, what walks;
  the Creature Lab is the longest visit, so it closes the group).
- **THE WORLD** banner as now.
- Footer: "three experiments · four labs · one world".

**Why the experiments first:** Crosswise is the only scene built to teach someone new to 4D how to
read a slice. The labs assume you can already read one (you "turn the tank through W"). **The
trade-off:** the voxel system, the first item on D4's demo bar, moves to the second group. If the gate
audience comes first on 16 Oct, keep the labs on top; the rest still applies.

**Optional, for the gate reviewers:** every entry already carries its RFP thrust (`thrust`: Build it,
Fill it, Live it). The detail pane's kicker could show it, e.g. "THE LABS · FILL IT · 05 / 07", so the
reviewers see their own words without the list splitting in three. Don't split the list by thrust: the
Voxel Lab would stand alone in Build it.

## 3. The route view (ROUTE toggle): make it read as a route

What it shows today (frame `families_white_route_0.png`): one unbroken line through all seven stops,
stepping up and down in turn (Voxel high, Creature low, Botany high and so on), the two group names
standing above the first stop of each group, the PLAY THE WORLD button at the end, and under it all "A
capability map, not a required order."

What doesn't follow:

1. **One unbroken line through two kinds of thing.** Nothing on the line marks where the labs end and
   the experiments begin; the group names float above their first stop and don't span their stops.
2. **The up and down steps mean nothing**, but they read as two tracks (a high row and a low row), and
   each track mixes labs and experiments.
3. **It is drawn as a route and captioned as not one.** A line from a first stop to a last, ending in the
   world, is an order; "not a required order" contradicts it, and the detail pane counts the stops
   (01 / 07 to 07 / 07).
4. **The order on the line isn't a learning order.** It runs labs first, then experiments. A route is
   the one place where order should mean something.

Suggested route, left to right, the same order as the list (section 2), so the LIST / ROUTE toggle
never reshuffles the stops:

- **Three stages on one line:** THE EXPERIMENTS (Crosswise, The Maze, Shooting Range), then THE LABS
  (Voxel, Botany, Aquatic, Creature), then THE WORLD. Each stage's name centred over its own span, with
  a thin bracket under the span, and a clear break or gate in the line between stages. Read left to
  right: learn to read 4D, see how it is built, then everything together.
- **The stops on one level** (no up and down), or let the height mean something if you keep it.
- **Count the stops within their stage** in the kicker, "THE LABS · 2 OF 4" rather than "06 / 07".
  The stage is what matters, and it matches the brackets.
- **Replace the caption** with what the route actually is: "Our suggested route. Every stop can be
  launched on its own." That keeps the freedom and stops contradicting the line.
- **The world stays the end of the line**, as the button it is now: everything leads into it.
- With the films gone (section 1), nothing sits under the line on the right.

## 4. Group and lab names (researched)

**The "X Lab" naming is sound** (Ramon likes it, and the research agrees). Science museums name rooms
by subject the same way (the Exploratorium's Living Systems and Tinkering, the Smithsonian's Ocean Hall
and Hall of Fossils).

- **Aquatic Lab:** the right word. "Aquatic" covers fresh and salt water, "marine" only salt water. The
  lab has koi in a tank (freshwater) and the open sea, so "Marine" would be wrong for the tank.
- **Creature Lab:** right. Better than "Animal" or "Zoology": it holds a brachiosaurus, and "creature"
  is the game-dev word for the work.
- **Botany Lab:** fine; a real science name, and it covers the trees.
- **Voxel Lab:** the one lab named after a technique, not a subject. Keep it anyway: D4's demo bar lists
  "voxel system" first, and the 4D audience knows voxels (4D Miner is a 4D voxel game). **Fix:** take
  "voxel" out of the Botany Lab's line ("How trees take shape through voxel and branching techniques"),
  so the word belongs to one lab.

**The headings:** "Explore the systems" and "Experience 4D" are vague verbs, and they look alike in
small caps. NN/g: "Stick to commonly used words"; menus are not the place for "abstract high-level
categorization". "Experience 4D" also suggests the labs aren't 4D experiences, though you turn the slice
in every one. **Fix:** the headline's own nouns, THE LABS and THE EXPERIMENTS (section 2).

**One vocabulary per group:** today each group has three names. The labs are "labs" (headline,
footer), "Explore the systems" (heading) and "Interactive R&D exhibitions" (subline); the experiments
are "experiments", "Experience 4D" and "Playable experiments". **Fix:** one noun each, everywhere.

## 5. Label inconsistencies, and how to fix them

1. **Status badges contradict the groups.** All four labs show PROTOTYPE only because it is
   `MenuEntry.maturity`'s default (none of them sets it). Crosswise and the Shooting Range say PLAYABLE;
   The Maze says PROTOTYPE although it sits under "Playable experiments". **Fix:** set every badge on
   purpose, or drop the badge (the group already says what kind of thing it is).
2. **The launch button.** The Creature Lab's says PLAY (`launch_label = "PLAY"`), every other says
   LAUNCH. **Fix:** clear its `launch_label`.
3. **W or w.** The Shooting Range's keys say "through w", the world's too; everything newer says W
   (Aquatic, The Maze, Voxel, Creature, Crosswise). **Fix:** capital W on screen everywhere.
4. **The same action, different words** in the key rows. Turning the slice is "rotate slice" (Shooting
   Range), "turn the slice" (Aquatic, the world), "turn in 4D" (Botany), "turn a quarter into W"
   (Crosswise), "turn into W" (The Maze). Moving along W is "through w", "through W", "step through W",
   "slice through W", "slide the tree through W". **Fix:** two verbs for the whole menu, "turn the slice"
   and "step through W", plus a qualifier where it differs ("turn the slice a quarter").
5. **Key names.** "LMB", "Click", "RMB", "RMB drag", "RMB / TAB", "Wheel"; "1 2 3" against "1 to 4".
   **Fix:** one style (LMB / RMB / Wheel, and "1 to 3").
6. **Durations.** "about 10 min", "5 min", "2 min", "90 sec", "90 sec a level", and none for the Aquatic
   Lab and The Maze. **Fix:** one format ("10 min", "90 sec"), and a number on every entry.
7. **One-liners under the names.** The labs' lines say what is inside; the experiments' are abstract
   ("Movement and spatial reasoning in four dimensions", "Aiming and targeting in a four-dimensional
   environment"), and spell out "four dimensions" where everything else says 4D. **Fix:** say what you
   do (Crosswise: four puzzle islands you cross by turning the world).
8. **"Experiments" inside the Experiments.** The Shooting Range's detail says "Six experiments of four
   stages each", inside a group called THE EXPERIMENTS. **Fix:** "six rounds" (or "six tests") there.
9. **Header.** "00 / PROTOTYPE HUB": the "00" is an old page number, and "hub" dates from the
   diegetic-hub plan. **Fix:** something like "4D PROTOTYPES".

## 6. The list view and the world

1. **The list doesn't fit.** In the list view the third experiment is below the fold and The Maze's line
   is cut in half, so the screen says "Three experiments" and shows two and a half; the selected row can
   be out of sight while its detail shows. Removing the films' row may be enough; check the frames after.
2. **The list's group headings** should mark their span the same way the route's stages do (section 3),
   so the two views read as one structure.
3. **"Every system on this menu, together in one open 4D world"** (the world's blurb and banner) isn't
   true for the Aquatic Lab: the playable world has no water (nothing named water, sea or pond in
   `playable_world.tscn`). **Fix:** "The systems on this menu, together in one open 4D world", or name
   what is there. Note the banner's small line is hard-coded in `menu_a.gd:556`, not read from the
   catalogue, so a catalogue edit won't reach it.

## Sources

- Exploratorium galleries: https://www.lonelyplanet.com/points-of-interest/exploratorium/383993
- Smithsonian NMNH halls: https://dashboard.si.edu/newsdesk/factsheets/national-museum-natural-history
- Aquatic vs marine: https://www.encyclopedia.com/science/news-wires-white-papers-and-books/aquatic-ecosystems
- 4D Miner: https://www.pcgamer.com/au/trying-to-understand-four-dimensional-minecraft-broke-my-brain/
- Unreal feature samples and game samples:
  https://dev.epicgames.com/documentation/unreal-engine/engine-feature-examples-for-unreal-engine ,
  https://dev.epicgames.com/documentation/en-us/unreal-engine/sample-game-projects-for-unreal-engine
- 4D Toys and Miegakure: https://roadtovr.com/hands-4d-toys-mind-bending-unique-vr-puzzler/ ,
  https://en.wikipedia.org/wiki/Miegakure
- NN/g: https://www.nngroup.com/articles/category-names-suck/ , https://www.nngroup.com/articles/menu-design/
- Notion (read only): QH Research Partnership RFP (D3), Twelve-Month Plan (D2), the Deliverable 4 card.
