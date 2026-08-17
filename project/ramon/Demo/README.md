# Demo hub

A dev-look hub scene: a spawn point at the focus of an arc of gates, each
advertising one prototype. Built as a stakeholder-facing testing ground, so the
priority is layout, readability and dynamics rather than finished art.

Open `hub.tscn`. It does not teleport anywhere yet — the gates are geometry and
signage only.

## The one idea to know

**The hub is a list, not a layout.** `hub.tscn` contains no gates and no
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
  into `hub.tscn`. That is what stops geometry going stale, and it sidesteps the
  `[editable path]` resave trap in `CLAUDE.md` entirely — there is nothing
  persisted to go out of date. `_verify_hub.gd` asserts this.
- **Changing a gate dimension on the ring re-cuts every gate.** That is the point
  of generating them.

## Colour legend

Sampled from `res://textures/dev_finals/ramdev_*.png` at runtime by
`hub_palette.gd`, so editing those PNGs re-tints the hub without touching code.

| Colour | Means |
| --- | --- |
| grey / white / black | structure — floors, walls, gate frames |
| yellow | interaction and 4D relevance — threshold pads |
| blue | signage only |
| red | **not used in the hub** |

Red is deliberately absent. It already means "primary target" inside the
shooting gallery, and spending it on hub decoration would burn that meaning. The
hub uses fewer colours than any prototype it links to, because it is the frame
around the work rather than a competitor to it.

Gates are all structurally identical and neutral. **Identity is carried by the
billboard icon silhouette, not by colour** — that keeps colour free to encode
state (the `StateDot` changes when a prototype has been visited), which is what
colour is actually good at.

## Layout numbers

Radius 12 m, 160° arc, five slots 40° apart — 8.4 m of arc between gate centres
against 4 m-wide gates. An arc rather than a full ring, so nothing sits behind
the player and the back wall gives orientation anchoring, which matters more here
than in a 3D scene because slice rotation removes most other cues.

The ring warns in the editor if gates or their signage would collide, rather than
silently producing a broken layout.

Gate aperture is **circular**, not rectangular. Slice-rotating mixes an axis with
w, so a box that is long in w becomes long in x after an xw rotation — it
survives but its apparent width changes as you turn, which is wrong for
furniture the player is using to stay oriented. A profile that is rotationally
symmetric in the rotated planes holds a more constant cross-section. See the open
questions below: the ring of box segments **approximates** this, it does not
achieve it exactly.

## Billboards

Ordinary 3D nodes (`MeshInstance3D` panel, `Sprite3D` icon, two `Label3D`s), not
4D geometry. A 3D node has no w coordinate to rotate, so it is w-invariant for
free and can never slice out of view at the moment it is most needed.

Because Godot's `Node3D` only inherits a transform from a `Node3D` parent, these
children ignore their 4D parent and the ring writes **world-space** transforms
for them. Move a gate by hand and its sign will not follow until the next
rebuild.

Text is live, never baked into the sign texture. Changing a blurb is editing a
string. When a Figma panel design lands it supplies **one** panel texture reused
by every sign, not one image per sign.

## Files

| Path | What |
| --- | --- |
| `hub.tscn` | the scene |
| `gates/*.tres` | the catalogue — billboard text, icon, target, flags |
| `scripts/hub_gate_ring_4d.gd` | arc layout, spawns and places gates |
| `scripts/hub_gate_4d.gd` | builds one gate: frame, threshold, sign |
| `scripts/hub_gate_def.gd` | the `HubGateDef4D` resource type |
| `scripts/hub_palette.gd` | colour legend, sampled from the dev textures |
| `textures/` | generated placeholder icons |
| `_verify_hub.gd` | headless structural check |
| `_billboard_probe.tscn` | minimal 3D-nodes-in-a-4D-scene test |

## Verified

Run headlessly with the editor closed:

```
engine/godot/bin/godot.windows.editor.double.x86_64.console.exe --headless --path project --script res://ramon/Demo/_verify_hub.gd
```

Confirmed: the scene loads with no script errors; five gates generate at the
computed arc positions (phase maze lands dead centre at `(0, 0, -12, 0)`); 80
frame segments, 5 billboards, 10 `Label3D` and 5 `Sprite3D` nodes exist; and zero
generated nodes are owned by the scene.

## Open questions — NOT yet verified

Headless has no renderer, so everything below is structure-verified only. None of
it has been *looked at*.

1. **Do the 3D billboards actually render in the cross-section view?** The
   cross-section engine swaps in a private `World3D`. `Node3D` visual instances
   should follow that swap where an `Environment` does not, but this is
   inference. `_billboard_probe.tscn` isolates the question. If they do not
   render, the fallback is projecting labels to screen space via
   `Camera4D.world_to_viewport()`.
2. **Does the ghosted (translucent) frame sort correctly?** The centre gate uses
   alpha as a placeholder for the ghost-slice projection feature. Transparency in
   the cross-section renderer is untested, more so now that lighting has landed.
3. **How well does the segmented ring actually hold up under slice rotation?**
   It approximates rotational symmetry with box primitives. Whether that reads as
   stable in practice is exactly the thing to test.
4. **Texture tiling.** The dev PNGs import as `CompressedTexture3D`, so they *can*
   map onto 4D geometry — but `BoxTetraMesh4D` has a fixed cell UVW unwrap with no
   exposed scale, so a texture likely maps once per box rather than once per
   metre. That would stretch one tile across the whole 48 m floor. Flat albedo
   sampled from the same PNGs is the default for now; flip `use_dev_textures` on
   the ring to see what the mapping really does.
5. **Sun angle, sky colours and tonemapping** are a first guess, not a design.
   The sun currently has no w component, so lighting is consistent across slices;
   adding one is the knob for showing off 4D lighting at the cost of stability.

## Next

An `Area4D` trigger on each threshold pad, and the actual scene transition. The
`target_scene` field on every gate definition is already populated and unused.
