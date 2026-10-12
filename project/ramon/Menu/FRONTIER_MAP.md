# Frontier Map

The second way into the same prototypes. `Menu2.tscn` answers *what can I play*;
`FrontierMap.tscn` answers *what is this programme, and what has it proved*.

Two views of **one** catalogue. `entries/catalogue.tres` is shared, so a blurb
rewritten for one screen is rewritten for both, and neither can drift into
claiming a prototype the other does not have.

Built 2026-09-04 from `D:\temp_docs\brief_01\` (the brief plus the reference
SVG). The framework vocabulary — frontier, fog, node states — comes from
Hoskinson's *Gravity Products* paper; see "What is deliberately absent" below
for how much of it was taken.

## Files

| File | What it owns |
| --- | --- |
| `FrontierMap.tscn` | one `Control`, four resource references, nothing else |
| `scripts/frontier_map.gd` | builds the screen; `@tool`, so it draws in the editor |
| `scripts/frontier_node.gd` | one circular node in all five states |
| `scripts/frontier_edges.gd` | route curves, category ticks, band separators |
| `scripts/prototype_launcher.gd` | launch + return, extracted from `menu2.gd` |
| `scripts/frontier_entry.gd` | where a prototype sits and what state it is in |
| `scripts/frontier_category.gd` | one of the four kinds of proof |
| `scripts/frontier_gateway.gd` | a planning gateway; **not** a prototype |
| `scripts/frontier_layout.gd` | all placements, categories, gateways, screen text |
| `entries/frontier_layout.tres` | the data |
| `style/frontier_style.tres` | every colour and dimension |

## Four rules that are load-bearing

**1. Order is the catalogue's, not the map's.** The route follows
`catalogue.tres`'s array order — the project's one running order, the same one
Menu2's Move up / Move down buttons write. The brief proposed a separate
`tour_index`; it was dropped, because a second ordering those buttons cannot see
is a drift waiting to happen. Re-sequencing the tour is still one drag in the
inspector, and it re-sequences both screens at once.

**2. The curve is rhythm, not logic.** Every edge joins two prototypes that are
adjacent in the catalogue and nothing else. No branching, no dependencies, and
no meaning in a curve's height beyond keeping ten circles off one boring
horizontal. That claim is printed under the map because a reader who assumes the
shape encodes dependencies misreads the whole screen.

**3. An edge takes the colour of the category it leads into**, so the hue
changes on the edge that crosses into a new kind of proof rather than one node
later. Edge colour is separate from heading colour (`edge_color` vs `color`):
Spatial Interaction's heading is blue like Orientation's, but its stretch of the
route is muted grey. An edge is dashed when it arrives at anything not
built-and-playable — a dashed hop is a claim about direction, not a report of
somewhere you can stand.

**4. Nothing unenterable offers a button.** Fog nodes take no focus and no
clicks. Planning gateways are a separate resource type entirely, so they cannot
accidentally acquire a scene path or inherit launch behaviour. An `UPCOMING`
node shows `NOT BUILT YET` instead of `LAUNCH`.

## Interaction

**Press selects. Drag pulls. Double click launches.** Holding a node and moving
the mouse pulls it with tension — 55% of the mouse's travel, hard-capped at 26
reference pixels, so it feels attached rather than stuck to the cursor. Route
neighbours follow at 0.34 and 0.12, measured along the ROUTE rather than by
screen distance, because the line is the relationship and that is what should
visibly bend. Let go and everything eases home slowly: no spring, no overshoot,
no bounce, which would read as a physics toy and pull the eye off what the
screen is saying.

Edges rebuild from the nodes' live centres each frame while anything moves, and
the whole thing stops itself once settled, so a still screen does no per-frame
work. A press never launches, so grabbing a node to move it cannot start a
two-minute prototype by accident.

**The selection ring is the living one** — a wobbling circle, two harmonics at
incommensurate speeds so it never visibly repeats or reads as spinning, about
two pixels of wobble on a thirty-eight pixel circle. It animates only on the
selected node, so an idle screen animates exactly one ring. Hover gets a plain
ring at low weight instead: a quieter version of the same idea, so hovering
reads as "this one next" rather than competing with the real selection.

There is no separate focus ring. Keyboard focus selects, and selection is
already the loudest thing on the screen.

## Where the look comes from

**Icons come from `catalogue.tres`.** A node draws its `MenuEntry.icon`, so
changing an icon there changes it on both screens; `node_icon_scale` keeps it
small inside the circle, because the ring carries the state and a full-bleed
picture would drown it. A standalone node with no catalogue entry falls back to
its own `glyph`.

**Grounds and type are fully desaturated; nothing that carries meaning is.**
`frontier_style.tres` overrides every background and text colour to its
luminance grey. Category hues, route edges, state rings, the gold gate badge and
the blue Launch/Start buttons stay exactly as authored. The point is that colour
now means something here: if it is coloured, it is telling you which kind of
proof, which state, or which action.

**The banner is shared.** [MenuBanner] is built by both screens from the same
labels on `catalogue.tres` — same order, only the active index differs. It takes
colours and fonts as arguments rather than reading either style resource, so the
banner is shared without the two palettes becoming shared. Shortening it
(`banner_height`) hands the node field the difference; positions stay authored
against the reference art's 128px header.

## Sub-maps

Four maps, one scene. `FrontierLayout` is a **map**, not just the overview, and
`FrontierMap.tscn` swaps which one it is showing:

| Map | Resource |
| --- | --- |
| Overview (home) | `entries/frontier_layout.tres` |
| October Gate | `entries/map_october_gate.tres` |
| Open-Source + Game-Jam | `entries/map_open_source.tres` |
| 2027 Frontier | `entries/map_2027_frontier.tres` |

One scene rather than four, because the top strip then stays put by
construction, the last selection survives a round trip for free, and a fifth
sub-map is a `.tres` rather than a scene. October Gate, Open-Source and 2027 are
entered through their gateway **nodes** — they are deliberately not extra tabs,
so Frontier Map and Explore Freely remain the only persistent modes.

The layouts are generated by `entries/_build_maps.py` (needs `_gen_layouts.py`
beside it). Forty nodes and thirty edges of hand-written `.tres` is a lot of
places to fat-finger a coordinate; edit the spec and re-run it instead.

**Gateways are nodes now.** There is no separate gateway class: `FrontierEntry.kind`
is PROTOTYPE, GATEWAY or PLANNING, and only activation differs between them —
launch a scene, open a sub-map, or inspect only. Two node classes meant two
places for focus, hover and badge handling to drift apart.

**The overview's route skips them.** Only PROTOTYPE nodes join the chain of
edges, so the gateways sit in the lower band without becoming stages of the tour.

## Edges, and the honesty rule

The overview derives its route from catalogue order (`route_from_catalogue`).
Sub-maps name every edge explicitly, because there a line means *this work
plausibly enables that work*, which no ordering can express.

`FrontierEdge.estimated` draws the line dashed and dimmed. That is the
proposal's rule made visual: the dependency graph is a planning hypothesis until
Aaron and Andrew validate it, and a solid line would quietly promote a guess into
a claim. The October Gate map also carries an `ESTIMATED · ENGINEER VALIDATION
REQUIRED` caveat pill for the same reason.

## The contextual drawer

`FrontierDrawer` is a right-side overlay, **not a fourth sub-map**. It layers
over the current map, does not change the selection, and closing it returns you
exactly where you were.

Four ways in, all meaning "show me what is happening here": a node's blue
numbered badge, VIEW ACTIVITY in the detail panel, the next-cycle signal pill,
or a contribution-brief action. Two tabs — Activity (aggregate contribution,
lanes, player signal) and Next-cycle Signal (one bounded choice among three).

**The badge is a real child `Button`,** so its click never propagates to the
node and it takes its own place in the focus order. Body means "inspect or
enter"; badge means "show activity". Nobody should open a contribution drawer
because they wanted to launch a prototype.

**Everything in it is invented.** `FrontierActivity.illustrative` drives the gold
pill that says so on the drawer's face. The resource is shaped for a backend it
does not have yet — plain values and parallel arrays, no scene references — so a
real contribution feed can fill the same fields without the drawer changing.
Member chips are initials only: identity is a backend concern, and individuals
stay one level deeper than the drawer by design.

## Escape order

Strict, per the proposal: **close drawer → leave sub-map → leave the map.**
Anything else makes Escape a gamble about how much you are about to lose.

## Adding a node

Two edits, and they mean different things.

- **It exists**: add a `MenuEntry` to `catalogue.tres`. It now appears in Menu2.
- **It belongs here**: add a `FrontierEntry` to `frontier_layout.tres` with a
  `reference_position`, a category and a state. It now appears on the map.

A placement whose `entry_title` matches nothing in the catalogue is **not** an
error — it is a node for work that does not exist yet, which is most of why this
screen exists. Such a node draws from its own resource and uses `route_after` to
say which prototype it follows. Nevada Terrain is the current example: placed,
gate-badged, not built, and not in `catalogue.tres` — so it never appears in
Menu2 as an unlaunchable row.

Positions are authored in a 1920×1080 reference space, read straight off the
reference art. The whole map is scaled uniformly and centred into the window,
which is why `project.godot`'s CANVAS_ITEMS + EXPAND does not shove the layout
left on a display wider than 16:9.

## What is deliberately absent

No voting, conviction staking, contribution nodes, contributor names, unlock
economies, persistent profiles, backend accounts, or a dependency graph
generated from Notion. Per the brief, and consistent with the framework's own
gate: the Foundation phase has no conviction staking at all until roughly 200
active users at 40% seven-day retention, and Deliverable 1 puts the launchpad
behind Gate 2. The map and the fog are on-framework now; the governance
machinery is not.

**The guided tour is still not built.** `START THE TOUR` shows the same COMING
SOON notice Menu2 shows, deliberately — two screens should not disagree about
what exists. `_played` is in memory only and dies on quit; the brief explicitly
allows that for the first pass.

## Checking it

Editor closed, and **without** `--headless` (headless creates no rendering
device, so nothing is drawn):

```
engine/godot/bin/godot.windows.editor.double.x86_64.console.exe \
    --path project --resolution 1920x1080 \
    --script res://ramon/Menu/_shot_frontier.gd -- frontier_map.png "Nevada Terrain"
```

It prints the route order and flags every placement as `catalogue` or
`STANDALONE` before rendering. Read that report: a node silently missing because
its title does not match a catalogue entry is very hard to spot on a screen with
ten circles on it.

New `class_name` scripts need one editor-mode scan before anything referencing
them will parse — `--headless --editor --quit-after 400` writes the global class
cache and the `.uid` files. A plain `--headless --quit` does not, and reports a
wall of "Could not find type" errors that look like real bugs.

## Source material

- `D:\temp_docs\brief_01\QH_Frontier_Map_Screen_01_Godot_Brief.md` — the brief
- `D:\temp_docs\brief_01\07_QH_Organic_Frontier_Map_Refined.svg` — reference art
- `D:\temp_docs\Gravity_Products_summary.pdf` — the framework in three pages
- Notion → *Quantum Horizon — R&D Working Space* → "All of the features",
  "Deliverable 1 — Where This Ends Up", and the Deliverable & Task Tracker
