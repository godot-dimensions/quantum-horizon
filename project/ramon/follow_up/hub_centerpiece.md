# Hub centerpiece — parked idea

**Status: idea, not decided, nothing wired in.** Written 2026-08-18 so the
probe and the reasoning behind its default aren't lost between sessions.

## The idea

A large, always-visible 4D polytope hovering over a hub (hub1 or hub2), giving
the space an ambient, unmissable "this is a 4D place" signal that doesn't
depend on a stakeholder ever touching `rotate_4d`. Motivated by hub2's tiered
gates+ramps reading as structurally sound but not *visually* striking - that
mechanic only reveals its 4D nature to someone who goes looking for it.

Two ways it was proposed to move: a slow constant idle spin (so it's alive
even for someone who just stands and looks) plus an amplified reaction to the
player's own `rotate_4d` drag (currently 3x), so the spectacle stays causally
tied to the one control the whole game is about, not just decoration.

## What was tried

`project/ramon/Demo/_centerpiece_probe.tscn` +
`scripts/centerpiece_probe_4d.gd` - a standalone probe, deliberately not
wired into hub1 or hub2. Loads one of the ready-made polytope meshes from
`project/models/primitives/platonic/` via `ArrayTetraMesh4D`, same pattern
`IsoclynicSun/isoclynic_sun.tscn` uses for its 600-cell ball.

Three shapes compared by rendering the same scene non-headless
(`_screenshot.gd`) at a few rotation states:

| Mesh | Verdict |
|---|---|
| `24_cell_smooth.g4b` | Too plain - a generic hyperplane slice only shows a handful of large flat panels. Confirmed the "isn't 24-cell too lowres" worry was right. |
| `120_cell_smooth.g4b` | **Current default.** Reads as a clean faceted "soccer ball" of pentagons/hexagons - noticeably richer than the 24-cell, still legible as one coherent gem. |
| `600_cell_smooth.g4b` | Denser and more crystalline, the most spectacular in raw facet count, but starts to read as busy/noisy rather than clean. |

Rendering, not just structure, mattered here - this could not have been judged
headless.

## Open questions

1. **Does it actually belong in hub2** (or hub1), and where - elevated above
   the arc, centered, high enough to never block a gate or a sightline was the
   working assumption, never tested in place.
2. **Idle-spin speed and reaction multiplier are first guesses** (6°/s xw,
   4°/s zw idle; 3x reaction) - untuned against how it actually feels to stand
   near.
3. **The tiny magenta artifact** seen once in the very first screenshot, not
   reproduced since - possibly a degenerate triangle at that specific slice.
   Not chased down.
4. Material is flat `albedo_color` only, matching `IsoclynicSun`'s ball - never
   explored whether the hub's dev-texture palette should apply here too, or
   whether flat is part of why it reads as a "gem" rather than "structure."
