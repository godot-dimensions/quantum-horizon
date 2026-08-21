# hub2: tiered addresses

A second hub, built to A/B against `hub1.tscn` rather than replace it - open
`hub2.tscn` directly; `project.godot`'s `main_scene` still points at hub1 until
someone decides this one has won. Same job as hub1 - a spawn point facing an
arc of gates, one per prototype - a different bet on how a door tells you what
it is.

## The one idea to know

**A door's identity is where it is, not what it says.** hub1 carries identity on
a billboard: text and an icon, camera-relative, always readable. hub2 has no
billboard at all. Every gate's address is two coordinates: **bearing** (which
way you turn from spawn - front, left, right) and **tier** (which height plane
it stands on - ground, raised, or higher still). "The raised door on the left"
is the sign.

Bearing and tier alone are a 3D idea, though - a stakeholder could build the
same mental map in an ordinary game with stairs. What makes it belong here is
what carries the actual climbing:

**The platform a gate stands on is always there. The ramp up to it is not.**
Every platform is w-invariant, exactly like hub1's ordinary structure - it never
vanishes under a player already standing on it. The ramp connecting it to the
main floor is the opposite: it exists only inside one w-band, the same trick
hub1 spends on its single ghosted gate, but spent here on the *path* instead of
the *door*, and on every tier above ground instead of one special case. Turn
the ana/kata dial (`rotate_4d` + mouse) and one tier's ramp fades in as another
fades out. **Remove the w axis and this does not flatten into an ordinary
multi-level lobby - it breaks.** A ramp whose presence is a function of w has
nothing to be a function of without w, so the raised doors stop being "harder
to reach" and become either permanently sealed or arbitrarily always-open;
either way the one thing the whole scene is meant to demonstrate stops meaning
anything.

## Controls

Identical to hub1 - nothing here is hub2-specific.

**R restores the home slice** (`hub_slice_reset.gd`, reused unmodified - it
already only touches the player and the spawn point, so it needed no forking).
Zeroes w rotation and w position, and - because `also_return_to_spawn` is on -
teleports back to the spawn point too.

## How a lost player recovers

Two layers, deliberately redundant:

1. **Falling is always safe.** Tier heights are a step or a shallow ramp's
   worth (0.6-1.1 m at the defaults) - if a tier's ramp scrolls out of your
   slice while you are still on the platform, or you simply walk off an edge,
   you drop a trivial distance back to the main floor. No fall damage exists in
   this project, so this is a way *down* that needs no w-alignment at all.
2. **R is a deterministic full reset.** Wherever you are - which tier, which
   w-slice - one press puts you back at the exact spawn transform, home slice.

Between the two, there is no state a stakeholder can reach that does not have
an obvious, low-effort way out - the brief's "disorientation is a bug" applies
to recovery, not just to the layout.

## What a first-timer gets for free

The front, ground-level gate (`gate03`, currently *Phase maze*) sits at tier 0:
no platform, no ramp, no w-dependency, reachable by walking straight ahead from
spawn. A stakeholder who never touches `rotate_4d` still completes one full
prototype loop. The other four gates are visibly there the whole time -
platforms standing, doors named only by their address - genuinely unreachable
until they try turning, which is the entire pitch for the mechanic in one
demonstration.

## Layout

Radius 10.5 m, matching hub1's scale. **150° arc**, wider than hub1's 60° -
"left" and "right" need to actually separate for bearing to mean anything as an
address. Five slots, tiers assigned symmetrically: front is ground, the two
inner slots are tier 1, the two outer slots are tier 2.

| Slot | Bearing | Tier | Prototype |
| --- | --- | --- | --- |
| 0 | far left | 2 (higher) | Voxel port |
| 1 | left | 1 (raised) | Voxel mining |
| 2 | front | 0 (ground) | Phase maze |
| 3 | right | 1 (raised) | Sky box clouds |
| 4 | far right | 2 (higher) | Quantum range |

Reordering `GateRing.gates` re-lays-out bearing exactly as in hub1. Changing a
gate's `tier` re-lays-out its height, platform and ramp - `HubTierRing4D`
rebuilds a gate's whole vertical address from that one int, the "authored
placement on top of a derived arc" the brief asked for.

## Tiers are shared, not per-gate

`HubTierRing4D.tiers` holds one `HubTier4D` per non-ground tier - height,
`ramp_run`, and the ramp's `w_offset`/`w_extent`. Both tier-1 gates (left and
right) share tier 1's numbers, both tier-2 gates share tier 2's; a gate's
`.tres` only ever picks *which* tier, never its own height or w-band. That is
the same shared-parameters idea as hub1's "Gate defaults" export group, applied
to the one new axis hub2 adds.

Tiers use different `w_offset`s (6 m and 14 m by default) so rotating further
reveals the higher tier *after* the first, rather than both at once - a small
discovery curve rather than a single reveal.

## Geometry: what the gate owns vs. what the ring owns

`hub_tier_gate_4d.gd` is a fork of hub1's `hub_gate_4d.gd`, trimmed to what
hub2 needs: rectangular frame, membrane, threshold pad, state dot. No circular
shape option, no billboard, no per-gate w-ghosting - the ramp carries every
w-dependency in hub2, so the door itself is exactly as w-invariant and boring
as most of hub1's doors already are. It builds pure geometry, no
`CollisionShape4D`, matching hub1 - a player was never meant to bump into a
gate's pillars in either scene.

`hub_tier_ring_4d.gd` (forked from hub1's `hub_gate_ring_4d.gd`) owns the parts
a player has to physically stand on: the platform and the ramp, each a
`StaticBody4D` with both a `CollisionShape4D` and a `MeshInstance4D` sized and
positioned identically, the same collision-plus-visual split
`phase_maze_builder.gd`'s `_add_panel()` uses for its walls. The ramp's tilt is
built by rotating `up`/`outward` toward each other by `atan(height / ramp_run)`
in their own shared plane - an ordinary 3D-style pitch that never touches w, so
the slope survives slice rotation exactly like a flat floor does.

## Colour legend

Trimmed from hub1's - no blue, because there is no signage to reserve it for.

| Colour | Means |
| --- | --- |
| grey / white / black | structure - floor, wall, gate frames, platforms, ramps |
| yellow | interaction - threshold pads |
| black_metal / white (state dot) | unvisited / visited |

## Files

| Path | What |
| --- | --- |
| `hub2.tscn` | the scene |
| `gates_tiered/gate01..05.tres` | the catalogue - destination, tier, address only, no text or icon |
| `gates_tiered/tier1.tres`, `tier2.tres` | the shared height/ramp/w-band numbers per tier |
| `scripts/hub_tier_ring_4d.gd` | arc layout, tier lookup, platforms, ramps |
| `scripts/hub_tier_gate_4d.gd` | builds one door: frame, membrane, threshold, state dot |
| `scripts/hub_tier_gate_def.gd` | the `HubTierGateDef4D` resource type |
| `scripts/hub_tier_def.gd` | the `HubTier4D` resource type |
| `_verify_hub2.gd` | headless structural check |

Reused unmodified from hub1, because they were already generic: `hub_sun_4d.gd`,
`hub_tiled_floor_4d.gd`, `hub_slice_reset.gd`, `hub_material_4d.gd`,
`hub_palette.gd`.

## Verifying

Run with the editor **closed**, same caveat as hub1's verifier:

```
engine/godot/bin/godot.windows.editor.double.x86_64.console.exe --headless --path project --script res://ramon/Demo/_verify_hub2.gd
```

Confirms the scene loads, all 5 slots generate, the ground gate has neither a
platform nor a ramp while the tiered gates have both, nothing generated is
owned by the scene, and prints each ramp's collision box size and w-offset so a
tier's numbers can be sanity-checked without opening the editor.

## Open questions

Headless has no renderer and CharacterBody4D physics were not exercised by the
verifier above - these need a playtest, with the editor closed:

1. **Does an 11-17° slope actually read as climbable** to
   `CharacterBody4D.move_and_slide()`? The floor/wall/ceiling snapping fix
   `CONTROLLER_NOTES.md` documents was written for axis-aligned floors; a
   tilted one is untested.
2. **Is the ramp's w-band wide enough to walk up without popping out from
   underfoot** at a normal `move_kata`/`move_ana` or slice-rotation drift, or
   too wide to feel like a real constraint?
3. **Does losing a ramp mid-climb read as "the floor is slice-dependent," or
   as a bug?** That is the load-bearing question for the whole pitch.
4. **Do the two tiers' w-bands (6 m and 14 m offset) actually arrive as a
   discovery curve**, or does the gap between them feel arbitrary?
5. Sun angle, sky colours, and the exact tier heights/ramp runs are first
   guesses, not a design - same caveat hub1's README gives its own numbers.

## Next

Nothing here wires up `target_scene` - same as hub1, that is a separate
problem this scene deliberately does not touch.
