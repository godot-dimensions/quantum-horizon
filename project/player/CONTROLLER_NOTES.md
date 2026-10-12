# Aaron's player controller — reference notes

Read directly from `player.gd`/`player.tscn` as of commit `a0ca9e7` ("Add
player controller and minimal flat plane level"). This replaces the
workaround `player_4d.gd` from earlier prototyping entirely — that script is
retired, don't build against it.

**Update (`6f1c9cd`, "Add raycasting to the player"):** confirmed via direct
diff that this commit only touches `_input()` (an `if`/`elif` restructuring,
plus a new branch: an initial `rotate_4d` press with no drag now fires a
`RaycastParameters4D`/`PhysicsServer4D.raycast_physics_objects()` call from
`player_head.global_position` along `-player_head.global_basis.z`, currently
just `print()`ing the result as a functionality test). `player.tscn`,
`flat_plane.tscn`, and `main.tscn` are untouched by it - every node path
below still holds, re-confirmed directly rather than assumed. `_physics_process`
(movement, sprint) is untouched by this commit too - no interaction between
the two.

## Node hierarchy (`player.tscn`)

```
Player                  (CharacterBody4D, script = player.gd)
├── CapsuleShape        (CollisionShape4D, shape = CapsuleShape4D: radius=0.25, full_height=1.75)
├── PlayerHead           (Node4D, position = Vector4(0, 0.75, 0, 0))
│   └── FirstPersonCamera (Camera4D, current=true, rendering_engine="Cross-section")
└── PositionLabel        (Label, UI - shows live position, not part of the 4D tree)
```

**The actual `Camera4D` is `Player/PlayerHead/FirstPersonCamera`** - a child
of `PlayerHead`, which is itself a plain `Node4D` child of the `Player`
physics body. `PlayerHead` only ever holds pitch (see below); the camera
adds nothing further of its own. Anything reading the player's look
direction later (bearing utility, POI arrow, minimap) should read
`$PlayerHead/FirstPersonCamera`'s `global_basis`/`global_position`, not the
`Player` root's.

`Camera4D.projection_type` is left at its default (`PERSPECTIVE_4D`, value
`1`) - not set explicitly in the scene.

## Key bindings (`project.godot` `[input]`, from the same commit)

| Action | Key | Also bound to |
|---|---|---|
| `move_forward` / `move_back` | W / S | joypad axis 1 |
| `move_left` / `move_right` | A / D | joypad axis 0 |
| `move_kata` / `move_ana` | **Q / E** | joypad buttons |
| `move_up` / `move_down` | R / F | joypad buttons (defined, but **not read by `player.gd`** - see below) |
| `move_jump` | Space | joypad button 0 |
| `rotate_4d` | **left mouse button held** (not right-click) | - |

Important: `move_up`/`move_down` (R/F) are defined in the input map but
**`player.gd` never reads them** - only `move_kata`/`move_ana` (Q/E) feed
the w-axis, and y is gravity/jump-only. R/F currently do nothing.

**Branch-specific override (`shooting-gallery` branch only):** `rotate_4d` is
remapped to **right-click** and a new `fire` action is bound to **left-click**
(`project/project.godot`), to free up left-click for the shooting gallery's
hitscan weapon. Confirmed via grep that `rotate_4d`/`MOUSE_BUTTON_LEFT` are
never hardcoded anywhere in the project - the binding is purely an Input Map
entry, so this was a `project.godot`-only change, no code edits. This is
local to this branch; `main` still has `rotate_4d` on left-click as described
in the table above.

Also important: the earlier prototyping's right-click-drag convention is
**not** what Aaron built - his `rotate_4d` action is bound to left-click.

## Movement (`_physics_process`)

Direct 4-axis input vector, no slice-rotation detour needed to move in w:

```gdscript
var input_dir := Vector4(
    Input.get_axis("move_left", "move_right"),
    0.0,
    Input.get_axis("move_forward", "move_back"),
    Input.get_axis("move_kata", "move_ana"),
)
var direction: Vector4 = (basis * input_dir).normalized()
```

`basis` here is the `Player` body's own basis (a `Projection`), so movement
is always relative to the body's current orientation, exactly like the
earlier prototyping's gimbal-basis approach - except here it's just the
body's own basis directly, no separate gimbal node.

Gravity is still gated behind `is_on_floor()`
(`if not is_on_floor(): linear_velocity += get_gravity() * delta_time`) -
this only being safe now is exactly why Aaron's `is_on_floor()` engine fix
matters. Confirmed via the submodule pointer bump in the same commit: the
`engine/modules/4d` submodule moved forward to include
`752872f "Add wall/ceiling/floor snapping to CharacterBody4D"` - a real
engine-level fix (proper floor/wall/ceiling snapping in
`move_and_slide()`), not a GDScript workaround. This lines up exactly with
the root cause found earlier (missing floor-snap pass vs. `CharacterBody3D`).

## Rotation (`_input`, on `InputEventMouseMotion`)

Two mutually exclusive modes depending on whether `rotate_4d` (left mouse
button) is held:

**Normal look (button not held):**
- Yaw: applied to the **body's own basis** via `Basis4D.from_zx(-rel.x)`
  (zx plane - same plane the earlier prototyping used for yaw).
- Pitch: applied to **`PlayerHead`** only, via
  `player_head.basis = Basis4D.from_yz(_head_pitch)` - note this is an
  **absolute set** from a clamped float (`clampf(_head_pitch - rel.y, -1.57, 1.57)`),
  not an incremental composed rotation. Avoids any basis drift from
  repeated multiplication on the pitch axis specifically.

**Slice rotation (`rotate_4d` / left mouse button held):**
```gdscript
body_basis *= Basis4D.from_xw(-rel.x) * Basis4D.from_zw(rel.y)
```
Applied **directly to the `Player` body's own basis** - xw from
horizontal mouse motion, zw from vertical, composed together as one
`Projection` product then multiplied onto the existing body basis.

This is the one significant structural difference from the earlier
prototyping: that version specifically avoided rotating the physics body
itself (routing slice-rotation through a separate non-colliding
`SliceGimbal` node instead), because rotating a `CharacterBody4D` carrying
a collider through xw/zw broke collision entirely in testing at the time.
Aaron's controller rotates the body directly and is "confirmed working...
verified against the ground plane" - consistent with the floor/wall/ceiling
snapping fix (see above) also having fixed the axis-aligned-body assumption
that caused the earlier fall-through bug, not just the `is_on_floor()` flag
specifically. Worth a direct empirical check before relying on that
assumption elsewhere, but not re-verified here.

**After either mode, every frame:**
```gdscript
body_basis.y = Vector4(0, 1, 0, 0)
basis = Basis4D.orthonormalized(body_basis)
```
Forces the y column back to pure up (defensive - none of zx/xw/zw should
touch y, but this guards against float drift from repeated multiplication)
and re-orthonormalizes the whole basis every frame. `Basis4D` is used here
as a static-method utility class (`Basis4D.from_xw(angle)`,
`Basis4D.orthonormalized(a_basis)` - both take/return a plain `Projection`),
not via `Rotor4D`/`rotate_rotor_local()` the way the earlier prototyping did
it. Both are valid ways to drive the same underlying `Node4D.basis`
property - anything reading orientation later doesn't need to care which
convention produced it.

## For later reference (bearing utility, POI arrow, minimap, etc.)

**Correction (Milestone 5): read `Player` itself, not the camera.** The
guidance below this heading originally said to read
`Player/PlayerHead/FirstPersonCamera` - that caused a real bug: the POI
arrow drifted just from looking up/down, with zero turning involved.

- **Yaw is applied directly to `Player`'s own basis** (`Basis4D.from_zx`,
  see Rotation above) - confirmed by reading `_input()` directly, not just
  inferred from the node tree. So is slice-rotation (xw/zw, also on
  `Player`'s basis). **Pitch is the only rotation that lives on `PlayerHead`
  instead** (`Basis4D.from_yz`, absolute set) - it exists purely to aim the
  camera up/down and has no bearing on which way to turn or slice-rotate.
- Because pitch is a yz rotation, it leaves `PlayerHead`'s (and therefore the
  camera's) local x (right) axis alone but tilts its local z (forward) axis
  into world-y. Any bearing math that dots a world-space relative vector
  against the *camera's* basis.z therefore silently absorbs the vertical
  offset between camera-eye-height and target-height as a function of pitch
  alone - wrong, since "which way to turn toward a point" should be a
  horizontal-only (yaw) quantity, indifferent to where you're looking
  vertically.
- **Fix applied:** `BearingUtility4D.compute()` now takes the `Player` body
  node (not `Camera4D`) and uses `Player.global_position`/
  `Player.global_basis` throughout - for `rel`, `right_component`,
  `depth_component`, and `ana_offset` alike. Since yaw and slice-rotation are
  already `Player`'s own basis, this is also simpler: no need to walk down to
  `PlayerHead/FirstPersonCamera` at all for turn-direction purposes.
- Only reach back into `PlayerHead`/`FirstPersonCamera` for something that
  genuinely needs look direction (e.g. what's on-screen, raycasts from the
  eye) - not for "which way should the player turn" style bearing math.
