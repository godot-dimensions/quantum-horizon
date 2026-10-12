# Demo hub: what 2026-08-18 cost to find out

Written after a day building the hub's dais, room, signage and gate transitions.
Everything below was measured, not assumed — the measurements are included so a
future reader can tell "I checked" from "I reckoned". Companion to
`engine_gotchas.md`; the engine-level entries here belong to the same family.

## Physics is bounding-box only. This is the big one.

`PhysicsServer4D`'s only engine is `axis_aligned_box_physics_engine_4d`, and
`_calculate_shape_rects` reduces **every** collision shape to
`get_rect_bounds_global()` — an axis-aligned box. There is no shape-specific
collision anywhere in it.

Consequences, all of which bit:

- **A round collider collides as a square.** The dais was a `CubinderShape4D`
  disc; the player stood on invisible floor well past the visible rim, and met an
  invisible wall at the circumscribing square's corners.
- **There are no walkable steps, and no ramps.** `CharacterBody4D` has
  `_snap_distance = 0.1` and no step-up logic of any kind. A 0.2 m dais was a
  20 cm wall: you could walk off it and never get back on. A ramp does not help,
  because a ramp collides as its own bounding box too.
- **So a raised platform is not really representable.** The dais ended up a 2 cm
  visual inlay with no collider at all, reading as a zone by colour rather than by
  height. The room's wall carries no collider for the same reason — each rotated
  segment would inflate into a much larger axis-aligned box and the ring of them
  would close in well inside the visible wall.

**This threatens `hub2`'s tiered-height design** ("front doors low, left doors on
a slightly higher plane"). Check it against the physics before building further on
it — the heights are not walkable.

## 4D shapes and meshes

- **`Shape4D.to_tetra_mesh(options)` exists and is bound to GDScript**, so a shape
  can generate its own render mesh. But **only `BoxShape4D` and
  `CubinderShape4D` implement it.** `CylinderShape4D`, `SphereShape4D` and
  `DuocylinderShape4D` inherit the base, which forwards to a script override that
  does not exist, and return **null**.
- **`CylinderShape4D` is not what the name suggests.** It constrains
  `x² + z² + w² <= r²` — a 3-ball in the (x, z, w) hyperplane extruded along y.
  Slice rotation only ever mixes x, z and w, so that constraint is **invariant
  under it**: its cross-section is the same circle at every rotation. That is the
  mathematically right shape for hub furniture, and it cannot be drawn.
  `CubinderShape4D` is the disc-in-XZ extruded along y and w, which stretches by
  `1 / cos(θ)` under θ of zw rotation — measured at 15.5% at 30°.
- **Cubinder meshes carry no UVW map at all.** Measured: a cubinder at 16 segments
  gives 264 tetrahedra and **0** texture-map entries, where an equivalent
  `BoxTetraMesh4D` gives 160. The tiled shader samples `albedo_texture_3d` by UVW,
  so anything built from `to_tetra_mesh` renders flat no matter what the material
  says. This is why `dais_textured` does nothing.
- **Corollary trick:** the room's ceiling wanted to be a textured disc and cannot
  be, so it is a square `BoxTetraMesh4D` spanning the room's diameter. From inside
  a closed round room the wall occludes everything past its own radius, so a
  square ceiling reads as a round one — and boxes have a proper unwrap.

Two upstream gaps worth one report between them: `CylinderShape4D::to_tetra_mesh`,
and a UVW map for the cubinder.

## Do not put a 2D image on 4D box geometry

Tried putting each gate's icon on its editor placeholder via a one-layer
`ImageTexture3D`. It works mechanically and looks wrong: a `BoxTetraMesh4D`
carries a fixed **per-cell** UVW unwrap, so a single image is stretched across
whole cells rather than sitting on a face, and it reads as one smeared texture
spanning every slab. Reverted to flat colour.

If you do need an image through that path, note the import format trap:
`ImageTexture3D.create` compares the declared format against the layer exactly,
and imported textures arrive **VRAM-compressed with mipmaps** (measured: format
19, compressed, mipmapped). The sequence that works is `decompress()` →
`clear_mipmaps()` → `convert(FORMAT_RGBA8)`. A bare `convert()` silently fails,
because it will not touch a compressed image.

## Fonts

- **The variable font `wght` axis is inert in this build.** Montserrat's variable
  file reports its axis correctly (`get_supported_variation_list()` returns tag
  2003265652 spanning 100–900) and `FontVariation` stores the value back
  faithfully, but the glyphs do not change: "QUANTUM RANGE" measures **exactly
  931.00 px at 100, 400, 700 and 900**, with String and StringName keys alike.
  Tracking through the same `FontVariation` does work, so the object is live —
  only that axis is dead.
- **The trap on top:** a variable font's *default instance* is its axis minimum,
  which for Montserrat is weight 100. Assign the variable file and you get Thin,
  and it looks like a styling mistake rather than an engine one.
- **Use the static faces** in `fonts/Montserrat/static/`.
- **Glyph height in metres is `font_size * pixel_size`.** At the hub's numbers the
  title is ~0.19 m and the blurb ~0.08 m; from 11 m on a 1080-line viewport that
  is roughly 15 px and 6 px of cap height. **The title reads and the blurb does
  not.** `_sign_board.tscn` exists to make that visible rather than arguable.

## Transparency sorting on the signs

Rounding the sign panel's corners needs alpha (a `QuadMesh` has four corners by
definition), which moves the panel into the **blended** pass, where surfaces sort
per-object by depth. The `Label3D` text sits 2 cm in front — far too close for
that sort to stay stable — so the panel intermittently drew over its own text and
the text popped in and out as the view turned.

Fix, both halves needed: panel gets `render_priority = -1`; title, blurb and icon
get `ALPHA_CUT_OPAQUE_PREPASS` (so they write depth and sort per-pixel) plus
`render_priority = 1`, with outlines pinned between at 0.

## Scene transitions

**`change_scene_to_packed` from a physics signal crashes.** `body_entered_self`
fires inside the physics step, and changing scene frees the current one
immediately — including the `Area4D` running the callback and the body the solver
is still iterating over. Use `call_deferred`.

The gate trigger is deliberately on the **membrane**, not the threshold pad. The
pad is w-invariant and the membrane is not, so the ghosted gate inherits the right
behaviour for free: its door is genuinely absent from the home slice, and so is
the way through. No `w_hidden` special case anywhere.

## @tool authoring traps

`engine_gotchas.md` already records that a `@tool` script gaining exports while
its scene is open returns `Nil` for them until reload. Three refinements learned
the hard way:

- **It applies to Resources too**, not just nodes. A `.tres` loaded before its
  script gained a property returns Nil for it.
- **Nil booleans are the dangerous ones.** A Nil int or array errors loudly. A Nil
  *bool* reads as **false**, so `if show_room:` skips the geometry in total
  silence and the scene merely looks unfinished. Every new toggle should join the
  `typeof(...) != TYPE_BOOL` guard at the top of `rebuild()`.
- **Nil Colors hard-error, at volume.** Assigning Nil to a Color property threw
  1090 identical `'modulate' ... Nil` messages. Colours are read through
  `get_panel_color()` / `get_text_color()`, which type-check and fall back.

Prefer one readable `push_warning` naming the fix over a wall of symptoms.

## Inspector details

- **`PROPERTY_HINT_ENUM` on a String is fragile** — the inspector treats an enum
  hint as index-based in several paths, so entries may fail to round-trip
  depending on position in the list (red worked, blue did not). Use
  **`PROPERTY_HINT_ENUM_SUGGESTION`**: it stores the name, not an index, and still
  allows typing an unlisted value.
- **Hide controls that cannot act** rather than leaving them editable and inert.
  `aperture_height` looked broken for weeks; it was simply overridden by
  `link_height_to_width`. Both now hide themselves via `_validate_property` when
  the shape is circular or the link is on.
- **`_get_property_list` + `_get`/`_set` with `PROPERTY_USAGE_EDITOR` and no
  `STORAGE`** is how the sign board surfaces the style resource's properties flat
  on the node without storing a second copy that could drift.

## The editor's 4D viewport is not scriptable

`EditorCamera4D::_bind_methods()` is empty and the class is not registered for
scripting, so **no `@tool` button can reset the editor's 4D view**. The built-in
route is the **rotation gizmo** in the viewport corner — clicking an axis calls
`set_ground_view_axis` internally. `SliceReset`'s button resets the *Player node*,
which is a different thing.

## Verification, and its limits

- **Editor-only code cannot be verified headlessly.** `Engine.is_editor_hint()` is
  false in a `--script` run, so anything behind it — `_build_sign_proxy`, the
  editor placeholders — never executes there. Those need human eyes, and saying so
  is better than implying coverage that does not exist.
- **`--check-only` catches real bugs and costs seconds.** A duplicate `var style`
  shipped unchecked took the whole sign board down to a grey rectangle. Parse-check
  before handing anything over.
- **Never run headless while the editor is open.** Two Godot processes on one
  `.godot` cache correlates with `@tool` buttons silently dying, and only a full
  editor restart clears it. Check with `tasklist | grep -i godot` first.
- **`_screenshot.gd`'s width/height arguments do not work** — `root.set_size` does
  not take, and output is always 1920x1080. The optional height/pitch arguments
  (args 5 and 6) do work, and a top-down shot is the fastest way to answer "is the
  geometry actually there".
