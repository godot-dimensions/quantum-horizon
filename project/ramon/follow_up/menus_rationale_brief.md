# Quantum Horizon — the two menus: what they are, why they exist, and where the Frontier Map came from

Context file for an outside reader (e.g. ChatGPT) helping build a presentation.
Written 2026-09-18 against the `RamonPrototypes` branch.

**Companion file, not a replacement.** `engine_menu_prototypes_brief.md` (same folder)
is the *technical* reference — scene structure, resources, interaction contract, node
states, the nine prototypes. This file is the *argument*: what each screen is for, why
there are two, and how the Frontier Map came to exist. Read this one for slide content
and narrative; read that one for implementation accuracy.

Everything below was read off the repository on 2026-09-18, except where marked
***reported*** — those come from working notes and should be treated as claims, not
verified facts.

---

## 0. THE BRIEF: one slide about the menu system

This is what the file is for. Everything after §1 is supporting background — use it to
answer questions, not to fill the slide.

**The claim the slide should make:**

> Nine prototypes are not an argument. The menu system turns them into one.

**The structure that carries it — two screens, two questions:**

| Screen | Question it answers | Who asks it |
| --- | --- | --- |
| **Explore Freely** *(the entry point)* | *What can I play?* | Anyone arriving for the first time |
| **Frontier Map** *(one click away)* | *What is this programme, and what has it proved?* | A gate audience |

**The three points worth the space** (in priority order — cut from the bottom):

1. **The four categories are the argument.** Orientation → Spatial Interaction → World
   Systems → Living Systems. Nine demos in a list invite *"so what?"*; the same nine
   sorted by *kind of proof* read as a programme with coverage.
2. **The map can show unbuilt work without lying about it.** Nevada Terrain sits on the
   map, gold-badged as gate evidence, labelled `NOT BUILT YET`. Dependency guesses draw
   dashed. For a gate audience, a roadmap that marks its own uncertainty is more
   credible than one that does not.
3. **Previews are recorded playthroughs, not screenshots** — because a still 4D
   cross-section is indistinguishable from an ordinary 3D screenshot. The subject *is*
   what happens when the slice turns.

**Best single visual:** the **October Gate sub-map**. It shows the categories, the
dependency graph, the gold gate badges and the dashed estimated edges in one frame — and
it is about the gate the audience is sitting in. Second choice: the Frontier Map
overview, which reads more immediately but makes a weaker point.

**Do not put on the slide:** the curve (it is rhythm, not logic, and inviting anyone to
read meaning into it is a net loss), the interaction model, the audio, or any drawer
screenshot without its `ILLUSTRATIVE FUTURE DATA` pill visible.

**One-line version if the slide is shared with other content:**
*Two front doors on one catalogue — a playable menu, and a map that sorts the same nine
prototypes by what they prove.*

---

## 1. Why a menu at all — the context that makes this not busywork

A gate on **16 October 2026** decides whether Quantum Horizon gets a funded 2027
preproduction year, gets rescoped, or stops. All three outcomes are live.

Four deliverables are due to Scott by **Monday 12 October**. Ramon's work sits under
**D4 — the accompanying artefact / demo bar**, whose agreed scope is four items: the
voxel system, scalable asset-generation tooling, **interface / comprehension scenes**,
and general engine fundamentals. The middle two are Ramon's. ***Reported:*** D4's demo
bar was confirmed to Scott in writing on 15 Sept 2026.

Two consequences that explain the whole design:

1. **The menu is the exposition layer for D4.** The prototypes are the evidence; the
   menu is how a stakeholder who will not open Godot encounters them. Presentation is
   not polish on top of the work — for this deliverable it *is* part of the work.
2. ***Reported:*** **Ramon's seat is the one stakeholders have specifically questioned
   funding.** The stated defence is that comprehension is the second of the project's
   two hard problems, not a nice-to-have on top of the engine one. That raises the bar
   on how legible this work has to be to an outsider.

There is also a kill condition attached: if producing new 4D content still
fundamentally requires bespoke specialist hand-construction, the "sustainable
development rate" thesis is unproven. It is assessed on a **non-expert independence
ladder** on which ***reported:*** Ramon is Rung 1, the must-have floor — a non-engineer
producing working 4D scenes with bounded, logged developer help.

---

## 2. What came before: the diegetic hub, and why it was parked

The original front door was **not** a menu. It was `HubFinal.tscn` — a playable 4D hub
you walked around, with gates you stepped through to teleport into each prototype and
back. It is still in the repo.

***Reported:*** on **2026-08-25** the direction changed, on Trym's call: a Portal-style
chamber package plus a **conventional menu**, with the diegetic hub parked.

This matters for the presentation because it is the first of two moments where the
project chose **legibility over immersion**. A 4D hub is a better demo of 4D and a
worse way to find things. With a gate audience who may get one pass through the
material, the conventional menu wins.

---

## 3. Menu one — *Explore Freely* (`project/ramon/Menu2.tscn`)

### What it is

A vertical banner list of the nine prototypes with a detail pane. Each row carries a
title, a maturity badge, a duration, and a one-line hook. The pane shows a **looping
recorded clip**, the control keys as key caps, and three fixed info cells —
**question / approach / finding** — plus a **MEASURED** strip of real numbers.

The `.tscn` is a bare `Control` plus a script; roughly sixty widgets are generated at
runtime. All the knobs live in two resources: `style/menu2_style.tres` (type scale,
palette, spacing) and `entries/catalogue.tres` (the nine prototypes and every string).

`Menu.tscn` is the earlier mockup of the same idea, kept frozen so the version already
shown to Trym still runs. Menu2 is the fork where subsequent work happened.

### Why it is the way it is

- **Previews must move.** A still frame of a 4D cross-section is indistinguishable from
  an ordinary 3D screenshot. The whole subject is what happens when the slice turns, so
  the previews are *recorded playthroughs* driven by a choreography table
  (`Menu/_capture_clip.gd`), not screen grabs. This is the single most
  presentation-relevant decision in the screen.
- **A vertical list implies an order; a grid implies "pick any".** The prototypes have
  a pedagogical sequence — learn to read the slice, then interact, then world systems.
  A grid would throw that away.
- **The three fixed info cells are what make nine prototypes comparable.** Identical
  labels on every entry turn nine blurbs into a series of answered questions, which is
  the shape an R&D or academic reader already thinks in.
- **A finding and a benchmark are kept separate.** A finding is a claim; a benchmark is
  a measurement. Mixing them weakens both, so MEASURED is its own strip.
- **Durations are stated** because eight unknowns feel longer than eight ninety-second
  things, and not knowing what you are committing to is itself a reason not to click.
- **Maturity badges set expectations before launch**, which is most of what stops a
  greybox reading as a bug.

### What it cannot do

This is the important part for the narrative. `MenuEntry` — the record behind a row —
can only describe something that **exists and launches**. It has a scene path, a clip,
a maturity. It has no way to express:

- work that is planned but not built
- a dependency between two pieces of work
- what *kind* of proof a prototype contributes
- anything that is not a playable prototype at all

So the list can only ever answer *what can I play*. Asked *is this a programme, and
what has it proved*, it has no vocabulary at all.

---

## 4. Menu two — the *Frontier Map* (`project/ramon/FrontierMap.tscn`)

### What it is

A node graph of the same nine prototypes, arranged left to right along a curved route,
sorted into **four categories of proof**:

| Category | Prototypes |
| --- | --- |
| **Orientation** | Slice Vision · Phase Maze |
| **Spatial Interaction** | 4D Ascent · Portal · Quantum Range |
| **World Systems** | Voxel Mining · Shrubbery Lab · Sky Box Clouds · *Nevada Terrain* |
| **Living Systems** | Motion Lab |

Below the route: a detail panel on the left half, and three **planning gateways** on
the right — October Gate, Open-Source + Game-Jam Path, 2027 Frontier — each opening a
**sub-map**. Four maps in total, all in one scene, swapped by resource.

Current contents, counted off the files:

| Map | Nodes | Explicit edges |
| --- | --- | --- |
| Overview (home) | 13 | 0 — route derived from catalogue order |
| October Gate | 11 | 12 (4 marked *estimated*) |
| Open-Source + Game-Jam | 11 | 12 |
| 2027 Frontier | 13 | 12 |

### Why it exists — three reasons, in order of weight

**1. Nine prototypes in a list read as nine unrelated demos.** The same nine sorted
into four kinds of proof read as a research programme with *coverage*. That is the
actual argument the gate needs to hear, and the categories — not the pretty curve — are
what carry it. If you cut one thing from a slide about this screen, cut the curve.

**2. It can show work that does not exist yet, honestly.** `FrontierEntry` adds states
the menu has no concept of: `UPCOMING`, `RESEARCH`, `FOG`. **Nevada Terrain** is the
worked example — the procedural-terrain proof the October gate needs, placed on the map,
gold-badged, and labelled **`NOT BUILT YET`** where every other node says `LAUNCH`. It
is deliberately *not* in `catalogue.tres`, so it never appears in the playable menu as a
dead row.

**3. It puts the planning context next to the evidence.** The October Gate sub-map lays
out, in three bands, what must be proven (**LIVE ARTIFACT → GATE EVIDENCE → DECISION
PACK**) and marks which dependency claims are still guesses.

---

## 5. Why two screens rather than one

They answer different questions for different people, and merging them would damage
both. A stakeholder wants the argument; a playtester wants the thing to play. One screen
trying to do both becomes a project-management dashboard with a play button.

So: **a binary switch in a shared banner.** `FRONTIER MAP` / `EXPLORE FREELY`, same
labels, same position, same size on both screens — the half naming the current screen is
disabled rather than hidden, because a switch showing only the other option does not
read as a switch.

**Explore Freely is always the entry point.** `run/main_scene` opens it, by decision
rather than by accident. *What can I play* is the question a first-time visitor actually
has, and the prototypes are the evidence the programme rests on. *What has this proved*
is a second question, asked after the first — so the Frontier Map is one click away, not
in front of the work.

Three things are deliberately shared so the two can never disagree:

- **`catalogue.tres`** — one source for the nine prototypes and their copy.
- **`MenuBanner`** — one class, geometry as constants, so the bar cannot end up a
  different size on the two screens (it did, early on, and visibly jumped).
- **The running order** — array order in the catalogue, for both screens. A proposed
  separate `tour_index` for the map was dropped, because a second ordering that the
  menu's reorder buttons cannot see is drift waiting to happen.

---

## 6. How the Frontier Map came to be

Chronological, because the order explains the shape.

**Before 2026-09-04 — the gap was already visible.** Menu2 had been extended about as
far as its data model allowed: auto-advance to the next unplayed prototype on return, a
MEASURED strip for R&D readers, maturity and duration in the row. All of it still only
described things that existed.

**2026-09-04, morning — the framework arrives.** Ramon supplied Charles Hoskinson's
49-page *Gravity Products* paper plus his own 3-page plain-language summary of it, with
the instruction that it would inform "a secondary menu structure I already planned out".
The relevant mechanism in the paper is the **Frontier Map**: the roadmap as navigable
territory inside the product, nodes as features, fog hiding the distance.

**2026-09-04 — brief one: the overview screen.** A written Godot implementation brief
plus a finished reference SVG, specifying the header, the four category anchors, ten
nodes on one continuous route, the detail panel, three planning gateways and a decorative
fog teaser. Built that day. The explicit instruction was that this "should replace
neither the prototypes nor the existing free-selection menu" — hence the switch rather
than a rewrite.

**2026-09-04 — brief two: the rethink proposal.** A longer proposal plus four concept
SVGs, adding the three durable **sub-maps** and one reusable **contextual activity
overlay**, with an interaction contract (`selected` / `activated` /
`activity_requested`), a badge language, and a strict Escape order. Built the same day.

**2026-09-04 → 09-16 — iteration on legibility.** Successive passes on exactly the
things a presentation will be judged on: full desaturation of grounds and type so colour
only ever carries meaning; the banner shared and pinned; hover stopped changing the
detail panel; icons reused from the catalogue; sound cues added; the gate badge turned
from a circle into a bookmark.

**2026-09-04 onward — the October Gate sub-map became live planning.** It now carries 11
nodes and 12 edges, four of them marked as unvalidated estimates.

---

## 7. What was taken from *Gravity Products*, and what was deliberately refused

This distinction is worth a slide on its own, because it is the difference between
borrowing a good idea and adopting somebody else's product.

**Taken:**

- **The roadmap as navigable territory** rather than a list to read.
- **Node lifecycle states**, so unbuilt work has an honest appearance.
- **Fog** — near work shows as silhouettes, far work as undifferentiated atmosphere.
- **Progressive disclosure**, in the sense that detail lives one level deeper.

**Fog is the most defensible borrowing, and it has a body count.** It is an
anti-**Osborne-Effect** device: announcing a better version kills interest in the one
that exists. Osborne Computer pre-announced its successors in 1983 and filed for
bankruptcy within months; Nokia's Symbian went from 35% of global smartphone sales to
5.4% after Elop's leaked "burning platform" memo. Showing a roadmap at uniform
confidence is not neutral — it actively devalues what already works. That is why
`FRONTIER_MAP.md` has a rule that nothing unenterable offers a working button.

**Deliberately refused:** conviction staking, community voting, contribution nodes,
contributor names on the map, unlock economies, persistent profiles, backend accounts,
and any dependency graph auto-generated from Notion.

The reason is the paper's own gate, and it is a good line to have ready: by *Gravity
Products*' own rules the project is in a Foundation phase where the threshold for
conviction staking is **200 active users at 40% seven-day retention**. The playtester
group is well short of that. So the map and the fog are on-framework; the governance
machinery is not.

The one place governance appears is the **contextual drawer**, and everything in it is
invented. It says so on its own face via an `ILLUSTRATIVE FUTURE DATA` pill driven by
`FrontierActivity.illustrative`. **If the drawer appears in the presentation, that pill
must be visible in the screenshot**, or the numbers read as measurements of the project.

---

## 8. The four rules that are load-bearing

Each of these exists because the alternative actively misleads a reader.

1. **Order is the catalogue's, not the map's.** One running order for both screens.
2. **The curve is rhythm, not logic.** On the overview, every edge joins two prototypes
   adjacent in the catalogue and nothing else — no branching, no dependency, no meaning
   in a curve's height. This is *printed under the map*, because a reader who assumes
   the shape encodes dependencies misreads the entire screen.
3. **Estimated dependencies draw dashed and dimmed.** Sub-map edges *do* mean "this work
   plausibly enables that work" — which is a hypothesis until Aaron and Andrew validate
   it. The October Gate map carries an `ESTIMATED · ENGINEER VALIDATION REQUIRED` pill.
   A solid line would quietly promote a guess into a claim.
4. **Nothing unenterable offers a working button.** Fog nodes take no focus and no
   clicks; unbuilt nodes say `NOT BUILT YET`; refusals are audible rather than silent,
   so a dead-end reads as *not yet* rather than *broken*.

---

## 9. What is not built — say this before someone finds it

- **The guided tour does not exist.** `START THE TOUR` shows a COMING SOON notice on
  both screens, deliberately, so the two never disagree about what exists.
- **Overlay animation and reduced-motion** are not implemented; the drawer appears and
  disappears.
- **The 2027 sub-map is missing its row headings** — it has the quarter columns but the
  row identity currently only shows in the detail panel.
- **Played state is in memory only** and dies on quit. There is no persistence of any
  kind — worth knowing, because the *Gravity Products* entry criteria ask for
  "persistent user-created state that makes leaving costly", and by Ramon's own summary
  that is the criterion this project least satisfies.
- **The sub-map layouts are generated** by `entries/_build_maps.py`. Re-running it
  overwrites the `.tres` files, so inspector edits to a layout are lost.

---

## 10. Facts to get right on a slide

| Claim | Status |
| --- | --- |
| Nine prototypes in the playable catalogue | **Verified** — 9 entries in `catalogue.tres` |
| Ten nodes on the Frontier Map route | **Verified** — the nine plus Nevada Terrain, which is not in the catalogue |
| Thirteen nodes on the overview | **Verified** — ten route nodes plus three planning gateways |
| Four maps, one scene | **Verified** |
| October Gate sub-map: 11 nodes, 12 edges, 4 estimated | **Verified** |
| Built 2026-09-04 | **Verified** by commit history |
| Gate date 16 October 2026; deliverables due 12 October | ***Reported*** |
| D4 demo bar confirmed to Scott 15 Sept 2026 | ***Reported*** |
| All drawer contribution numbers | **Invented**, and labelled as such in the UI |

**Entry point, settled 2026-09-18.** `run/main_scene` points at `Menu2.tscn`, so F5
opens **Explore Freely**. This is deliberate and committed — see §5. The Frontier Map had
briefly held it when the map first landed, which was wrong about which screen is the
front door.

---

## 11. If the menu system gets more than one slide

The slide brief is §0. If it expands to two or three, these are the beats in order —
each one is a whole slide's worth, and the first is the only one that is load-bearing:

1. **Nine prototypes is not an argument; the categories make it one.** The four kinds of
   proof, with the overview as the visual.
2. **Showing unbuilt work honestly.** Nevada Terrain, `NOT BUILT YET`, dashed estimated
   edges, the `ENGINEER VALIDATION REQUIRED` pill. The October Gate sub-map as the
   visual.
3. **Two front doors on one catalogue.** The switch, and why the playable menu is the
   one that opens.

**What not to expand into**, even with room: the interaction model (drag tension,
badges, Escape order), the audio cues, the reference-space scaling, and the generator
script. All real work, none of it an argument a stakeholder needs.
