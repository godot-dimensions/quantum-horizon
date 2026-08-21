# Demo hub

A dev-look hub scene: a spawn point at the focus of an arc of gates, each
advertising one prototype. Built as a stakeholder-facing testing ground, so the
priority is layout, readability and dynamics rather than finished art.

Open `hub1.tscn` — it is also the project's `main_scene`. It does not teleport
anywhere yet; the gates are geometry and signage only.

A second hub, `hub2.tscn`, explores a different structural idea — tiered
addresses instead of the arc-plus-billboard model below, built to A/B against
this one rather than replace it. See `HUB2_README.md`; this file only covers
hub1.

## The one idea to know

**The hub is a list, not a layout.** `hub1.tscn` contains no gates and no
billboards. It contains a `GateRing` node holding an array of `HubGateDef4D`
resources from `gates/`, and everything visible is generated from that array at
runtime.

Consequences worth knowing before editing anything:

- **Adding a prototype is one `.tres`** dropped into the ring's `gates` array. No
  placement, no re-spacing of the gates already there.
- **Reordering the array re-lays-out the arc.** Array order is arc order, left to
  right. Moving an entry to the middle puts it in the centre slot, which is the
  first thing anyone looks at — so A/B-ing that is a two-second experiment.
- **Generated nodes are not owned by the scene**, so they are never serialised
  into `hub1.tscn`. That is what stops geometry going stale, and it sidesteps the
  `[editable path]` resave trap in `CLAUDE.md` entirely. `_verify_hub.gd` asserts
  it, because a violation is invisible until weeks later.
- **Changing a gate dimension on the ring re-cuts every gate.** That is the point
  of generating them.

## Controls

**R restores the home slice** (`hub_slice_reset.gd`). Nothing else in the project
does — the editor's only Reset buttons belong to the preview sun and environment,
and `project.godot` has no reset action at all. It rebuilds the body basis from
your current heading, so w rotation goes to zero while the direction you face is
preserved, and it zeroes your w *position* too: `move_ana`/`move_kata` leave you
in a parallel slice that no amount of rotating undoes.

Deliberately Demo-local, and bound to a raw keycode rather than an input action —
`project.godot` is shared, so an action there would leak this out of the folder.

## Colour legend

Sampled from `res://textures/dev_finals/ramdev_*.png` at runtime by
`hub_palette.gd`, so editing those PNGs re-tints the hub without touching code.

| Colour | Means |
| --- | --- |
| grey / white / black | structure — floor, wall, gate frames |
| yellow | interaction and 4D relevance — threshold pads |
| blue | signage only |
| red | **not used in the hub** |

Red is deliberately absent. It already means "primary target" inside the shooting
gallery, and spending it on hub decoration would burn that meaning. The hub uses
fewer colours than any prototype it links to, because it is the frame around the
work rather than a competitor to it.

Gates are structurally identical and neutral. **Identity is carried by the
billboard icon silhouette, not by colour** — which keeps colour free to encode
state (the `StateDot`), the thing colour is actually good at.

## Layout

A **full 360° ring**, seven slots, radius solved rather than fixed.

This reverses the original design, which was a 60° arc argued for on the grounds
that a closed ring always has content behind the player, and someone disoriented
by their first slice rotation may never turn around. Two things retired that
argument. The **enclosing room** now wraps you on all sides, so the wall does the
orientation anchoring the back wall used to do alone. And at **seven prototypes**
a single sweep had to spread so wide that the end gates fell behind you regardless
— so the arc was paying the cost of a ring without the benefit.

Set `arc_degrees` below 360 and it behaves as an arc again; both cases are
supported. The difference lives in `_slot_divisor`, and it is not cosmetic: an
open arc spreads N gates across **N−1** gaps so the outer two land on the ends of
the sweep, while a closed ring has no ends and needs **N**. Using N−1 on a full
circle puts the first and last gate at the same angle, exactly on top of each
other — and the spacing check does not catch that, because their separation is
zero rather than merely tight.

`auto_radius` treats `radius` as a minimum and grows it until the gates clear each
other, so adding a prototype widens the circle instead of crowding it. The ring
still warns in the editor if gates or signage would collide.

Gates are currently **rectangular** (`gate_shape = 1`): two pillars and a lintel.
The circular option is still there and is the more defensible shape in theory —
slice-rotating mixes an axis with w, so a box long in w becomes long in x after an
xw rotation, surviving the rotation but changing apparent width, which is wrong
for furniture the player uses to stay oriented. A rotationally symmetric profile
holds a more constant cross-section. The circular build approximates that from box
segments sized by the **chord at the outer radius**, so neighbours meet exactly at
the visible edge instead of crossing and leaving a lip.

## The one w-varying gate

Every gate but one is deliberately w-invariant: a long `w_extent` keeps it present
and stable at any rotation, because navigation furniture that changes as you turn
is disorienting.

The gate whose definition sets `w_hidden` breaks that on purpose. Its frame and
membrane sit `hidden_w_offset` out along w with a short `hidden_w_extent`, so they
are genuinely **absent** from the home slice and pass through it as you rotate —
roughly `atan(offset / distance)` of zw rotation, about 30° at the defaults.

Its threshold pad, state dot and billboard stay w-invariant even so. That is the
"signpost the absence" idea: a yellow pad on the floor and a sign naming the
destination, with no door above it. The affordance is visible; only the way
through is not. The scarcity is what makes it legible as special.

## Billboards

Ordinary 3D nodes (`MeshInstance3D` panel, `Sprite3D` icon, two `Label3D`s), not
4D geometry — a `TetraMaterial4D` takes a `Texture3D` and cannot carry readable
typography, and a 3D node has no w coordinate to rotate out of the slice.

They are positioned in **camera-relative space**, rewritten every `pre_render`.
The cross-section renderer does not draw the world in world coordinates: it
computes `camera_inverse_transform * global_transform` for every mesh
(`rendering_engine_4d.cpp`) and parks its own 3D camera at the origin. A
world-space position therefore renders welded to the viewer. The w component of
the offset is discarded, which is what keeps signage readable at any rotation.

Orientation is left to the materials' billboard mode, upright by default — full
billboarding tilts and reads as floating UI rather than a sign.

Text is live, never baked into the sign texture. Changing a blurb is editing a
string, and a Figma panel design would supply **one** texture reused by every
sign, not one image per sign.

## Floor tiling

`hub_tiled_floor_4d.gd` exists because `BoxTetraMesh4D`'s built-in unwraps assign
UVW per simplex-cell vertex, and the shader interpolates those along each sliced
edge — so the box's own tetrahedralisation shows through as diagonal skew. Both
`CROSS_ISLAND` and `FILL_EACH_SIDE` have this problem; scaling them just gives
smaller diagonals.

So the texture map is discarded and rebuilt by projecting world position:
`u = x / texture_metres`, `v = z / texture_metres`. Lines run straight along X and
Z, one texture spans exactly one metre by construction, and there is no scale
factor to calibrate.

**Slicing cannot stretch it.** The shader interpolates uvw with the same weight it
uses for position, and linear interpolation commutes with a linear projection, so
a sliced point's uvw equals its own x/z. Rotating in xw or zw never touches Y
either, so the floor cannot tilt out from under the projection.

`box_mapping` handles the rest. A 4D box is bounded by **eight cubic cells**, not
six faces, tetrahedralised into 40 simplices — and two of those cells face **w**.
Projecting everything down Y smears the ones that do not face Y, so the projection
plane is chosen per cell from `simplex_cell_boundary_normals`. That is the
per-cell equivalent of triplanar; per-fragment would mean forking the shader,
which would cost the floor its lighting, since the engine appends `light()` to its
own shader source and a fork freezes without it.

The script is a `Node4D` that **spawns** a `MeshInstance4D` rather than being one,
because `mesh` is a stored property and assigning generated geometry to it bakes
the whole tetrahedral array into the scene file.

## Lighting

The stock cross-section shader's angle-based term
(`albedo * (dot(normal, up) / 2 + 0.5)`) was removed in Aaron's lighting update
and survives only as a comment. **Any `TetraMaterial4D` surface with no 4D light in
the scene now renders flat.** The hub has a `DirectionalLight4D` for that reason.

`hub_sun_4d.gd` gives it usable rotation. `Node4D` does expose rotation, but 4D
has six rotation planes and the inspector packs them into an `AABB` — six
unlabelled floats; `basis` is a raw 16-float `Projection`. The script exposes
elevation, azimuth and an ana-tilt instead. Ana-tilt is 0 by default: any w
component makes lighting change as you slice-rotate, which is the genuinely 4D
behaviour but costs the hub its constancy.

`angular_radius_degrees` looks broken and is not — the sky shader compares
`cos(light_angular_radius_radians)` against the view angle, so at small values the
disc is a fraction of a degree wide. The broad glow is `sun_angle_max` on the
`GradientSkyMaterial4D`, a separate control.

## Files

| Path | What |
| --- | --- |
| `hub1.tscn` | the scene, and the project's main scene |
| `gates/gate01..05.tres` | the catalogue — billboard text, icon, target, flags |
| `scripts/hub_gate_ring_4d.gd` | arc layout, spawns gates, places signage |
| `scripts/hub_gate_4d.gd` | builds one gate: frame, membrane, threshold, sign |
| `scripts/hub_gate_def.gd` | the `HubGateDef4D` resource type |
| `scripts/hub_palette.gd` | colour legend, sampled from the dev textures |
| `scripts/hub_sun_4d.gd` | sun with elevation/azimuth/ana-tilt |
| `scripts/hub_tiled_floor_4d.gd` | per-metre floor tiling |
| `scripts/hub_slice_reset.gd` | R returns to the home slice |
| `textures/` | generated placeholder icons |
| `_verify_hub.gd` | headless structural check |
| `_billboard_probe.tscn` | minimal 3D-nodes-in-a-4D-scene test |

## Verifying

Run with the editor **closed** — two Godot processes on the same project's
`.godot` cache silently breaks `@tool` buttons in the running editor:

```
engine/godot/bin/godot.windows.editor.double.x86_64.console.exe --headless --path project --script res://ramon/Demo/_verify_hub.gd
```

Checks that the scene loads, gates generate at the computed arc positions, the
floor surface builds, and **nothing generated is owned by the scene**.

## Open questions

Headless has no renderer, so everything the verifier proves is structural. These
need eyes:

1. **Does the ghosted frame's transparency sort correctly?** The w-hidden gate and
   the gate membranes both use alpha. Transparency in the cross-section renderer
   is untested, more so now that lighting has landed.
2. **Does exactly one gate changing read as deliberate, or as a bug?** That is the
   whole premise of the centre slot.
3. **Does the segmented circular ring hold up under rotation** if you switch back
   to `gate_shape = 0`? It approximates rotational symmetry with box primitives.
4. **Sun angle, sky colours and ambient** are first guesses, not a design.

## Next

Transitions are **done**, in both directions.

Walking into a gate's **membrane** — not its threshold pad — loads that gate's
`target_scene`. The membrane is the trigger deliberately: the pad is w-invariant
and the membrane is not, so the ghosted gate inherits the right behaviour for
free, its door genuinely absent from the home slice and so is the way through. No
`w_hidden` special case anywhere. The scene change is deferred, because
`change_scene_to_packed` called straight from a physics signal frees the `Area4D`
running the callback and crashes.

Coming back is `return_button.tscn`, instanced once into each prototype: a
`CanvasLayer` prompt in the corner, key only (these scenes capture the mouse, so a
clickable button would fight the cursor), H by default. Editing that one scene
restyles every copy, and it reads colour and font from `sign_style.tres` so
restyling the signs restyles it too.

It references the hub by **path**, not by `PackedScene`, and that is load-bearing:
the hub already points at the prototypes, so a typed reference back would close
the loop `hub1 → prototype → return_button → hub1`. Godot resolves `ExtResource`
statically, cannot load a cycle, and fails with `Parse Error: Busy` — neither
scene opens. **Whenever two scenes link to each other, one edge has to be lazy.**

Still open: `gate01` (Voxel port) was dropped from the catalogue rather than
linked; its `.tres` and icon are still on disk if you want it back.
