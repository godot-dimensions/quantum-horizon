@tool
extends Node4D

## Lays the hub's gates out along an arc and builds each one from its definition.
##
## The hub scene holds no gates and no billboards - it holds this node and an
## array of [HubGateDef4D]. Everything visible is generated, unowned, and rebuilt
## from the array whenever anything changes. Adding a prototype to the demo is
## one new `.tres` dropped into [member gates].
##
## ARC OR FULL RING, and why that changed. The original argument was that a closed
## ring always has content behind the player, and someone disoriented by their
## first slice rotation may never turn around - so an arc kept every option in one
## sweep with a solid wall at your back for orientation.
##
## The hub is now a full 360 deg ring, deliberately. Once the enclosing room
## arrived, the wall is all around you and does the orientation anchoring on its
## own, so the arc was buying nothing; and with eight prototypes a single sweep had
## to spread so wide that the end gates fell behind you anyway. Turning around to
## find a door is a fair thing to ask in a room you can see the whole of.
##
## Set [member arc_degrees] below 360 and it behaves as an arc again - the layout
## maths handles both, and [method _slot_divisor] is where the difference lives.
##
## [member gates] order drives angular position, so reordering the array in the
## inspector re-lays-out the arc. Centre slot is the one a stakeholder looks at
## first, so being able to A/B that in two seconds is the point.

const GateScript := preload("res://ramon/Demo/scripts/hub_gate_4d.gd")
const SurfaceMaterial := preload("res://ramon/Demo/scripts/hub_material_4d.gd")
const Palette := preload("res://ramon/Demo/scripts/hub_palette.gd")
const GENERATED_META := "hub_generated"

## Every property that names a palette entry. They are plain Strings so nothing
## needs migrating, and the dropdown is applied as a HINT at inspect time - see
## [method _validate_property]. Listed in one place so a new colour property
## cannot quietly go back to being a free-text field where a typo falls through
## to flat magenta.
const PALETTE_PROPERTIES: Array[StringName] = [&"dais_color", &"room_color", &"membrane_color"]

## Clearance the spacing check wants between neighbouring gates, as a multiple of
## the widest footprint. Also what [member auto_radius] solves for, so the check
## and the fix cannot disagree about what "enough room" means.
const SPACING_CLEARANCE := 1.1

## How much of the platform slab sits below floor level. Only has to be deep
## enough that the rim never shows a gap when viewed edge-on from across the hub.
const BURIED_DEPTH := 0.4

## CharacterBody4D's own snap distance, mirrored here so the dais can warn about
## exceeding it. Not read from the player, because the ring has no reference to one
## and the value is a controller constant rather than a per-scene setting.
const CHARACTER_SNAP_DISTANCE := 0.1

## Slack in the spacing check, in metres. A millimetre is far below anything that
## could read as crowding and far above double-precision rounding on these sizes.
const SPACING_EPSILON := 0.001

@export_tool_button("Rebuild ring") var _rebuild_action: Callable = rebuild

## The catalogue. Array order is arc order, left to right.
@export var gates: Array[HubGateDef4D] = []:
	set(value):
		gates = value
		rebuild()

## How many gates to actually build. 0 means "one per catalogue entry".
##
## Set it higher and the catalogue repeats to fill the arc; set it lower and only
## the first N entries are used. This is for judging LAYOUT independently of
## content - whether seven doors reads as a wall of choices or three feels empty
## is a question about spacing, and it should not require inventing four more
## prototypes or deleting real ones to ask it.
@export_range(0, 24, 1) var gate_count: int = 0:
	set(value):
		gate_count = value
		rebuild()

@export_group("Layout")
## Distance from spawn to each gate. Far enough that the arc feels like a place
## rather than a menu; close enough that a 0.2 m cap height still reads.
@export_range(4.0, 40.0, 0.5, "suffix:m") var radius: float = 12.0:
	set(value):
		radius = value
		rebuild()

## Total angular spread. 360 closes it into a full ring, which is what the hub
## uses; below that it is an arc and the two outermost gates sit on the ends of the
## sweep. The range reaches 360 rather than stopping short precisely so the closed
## case is selectable - see [method _slot_divisor] for why the two differ.
@export_range(20.0, 360.0, 1.0, "suffix:°") var arc_degrees: float = 160.0:
	set(value):
		arc_degrees = value
		rebuild()

## Rotates the whole arc about the spawn point, for aiming it at a back wall.
@export_range(-180.0, 180.0, 1.0, "suffix:°") var arc_offset_degrees: float = 0.0:
	set(value):
		arc_offset_degrees = value
		rebuild()

## Treats [member radius] as a MINIMUM and grows it until the gates clear each
## other, instead of letting them intersect.
##
## Without this, [member gate_count] is a slider that silently breaks the layout:
## at radius 10.5 over a 60° arc, five gates already sit 2.75 m apart against
## 2.70 m of gate width - 5 cm of clearance - so a sixth genuinely overlaps.
## Growing the radius rather than the arc keeps the 60° framing and the back
## wall's relationship to the spawn point, and with a dais under the gates the
## growth is legible in itself: more prototypes means a visibly bigger platform.
@export var auto_radius: bool = true:
	set(value):
		auto_radius = value
		rebuild()

@export_group("Dais")
## A shallow circular platform centred on the spawn point, with the gates standing
## on its outer part and the floor continuing below and beyond it.
##
## WHAT "A CYLINDER IN 4D" MEANS HERE, because there are three of them and they
## are not interchangeable. [CubinderShape4D] is a disc in the XZ plane extruded
## along BOTH y and w. [CylinderShape4D] in this module is something else entirely
## - it constrains `x² + z² + w² <= r²`, a 3-ball in the (x, z, w) hyperplane
## extruded along y. That second one is the mathematically right dais: slice
## rotation only ever mixes x, z and w, so `x² + z² + w²` is invariant under it and
## its visible cross-section is the SAME circle at every rotation, which is exactly
## the constancy [member HubGate4D.gate_shape]'s doc comment wishes for.
##
## We use the cubinder anyway, because [CylinderShape4D] does not implement
## `to_tetra_mesh` - only [BoxShape4D] and [CubinderShape4D] do - so the invariant
## shape can be collided with but not drawn. Mixing them (invariant collision under
## a deforming visual) desynchronises the moment the player uses move_ana, since
## the 3-ball's radius shrinks with w while the cubinder's does not, and they would
## fall through a floor they can still see. One shape drives both instead.
##
## The residual cost is that the disc stretches by `1 / cos(θ)` under θ of zw
## rotation - about 15% at the 30° the ghosted gate needs. The w thickness comes
## from [member w_extent], so the disc never clips out of the slice.
@export var show_dais: bool = true:
	set(value):
		show_dais = value
		rebuild()

## How far the platform's top surface sits above the floor.
##
## MUST STAY TINY, and that is a physics constraint rather than a taste one.
## PhysicsServer4D's only engine is axis_aligned_box_physics_engine_4d, which
## reduces every collision shape to `get_rect_bounds_global()` - an axis-aligned
## box. Nothing in it steps up onto a ledge, and [CharacterBody4D]'s snap distance
## is 0.1 m. At the 0.2 m this started out as, the player walked off the platform
## and then could not get back on: a 20 cm wall with no step logic and no ramp
## possible, since a ramp would collide as its own bounding box too.
##
## So this is an INLAY, not a platform - a couple of centimetres, enough to avoid
## z-fighting with the floor and to catch the light differently, not enough to
## walk into. The zone still reads, because it is carried by colour.
@export_range(0.0, 0.25, 0.01, "suffix:m") var dais_height: float = 0.02:
	set(value):
		dais_height = value
		rebuild()

## Gives the platform a collider. OFF by default, and think before turning it on.
##
## Because collision is bounding-box only, a round platform collides as a SQUARE
## circumscribing it - so the player stands on invisible floor out past the visible
## rim, and meets an invisible ledge at the square's edge. Visual-only is both
## honest about what the engine can represent and the reason movement works.
@export var dais_collision: bool = false:
	set(value):
		dais_collision = value
		rebuild()

## How far the platform extends beyond the gate arc's radius, so the gates stand
## ON it with a margin rather than teetering on the rim.
##
## Kept small because the platform is a full disc centred on the spawn, so this
## margin is added on every side - including behind the player, where it can grow
## out past the back wall (26 m wide in hub1) and leave the wall sitting in the
## middle of the platform rather than at its edge.
@export_range(0.0, 12.0, 0.25, "suffix:m") var dais_rim_margin: float = 1.5:
	set(value):
		dais_rim_margin = value
		rebuild()

## Sides in the generated circle. Higher than the gates' [member segment_count]
## because this is one large continuous curve seen from its own centre, where
## faceting reads immediately.
@export_range(8, 96, 1) var dais_segments: int = 48:
	set(value):
		dais_segments = value
		rebuild()

## Maps the dev textures onto the platform rather than flat albedo.
##
## CURRENTLY HAS NO EFFECT, and the reason is worth knowing before trying to fix
## it by fiddling with [member dais_texture_metres]. The dais mesh comes from
## `CubinderShape4D.to_tetra_mesh`, which produces NO UVW map - measured at 264
## tetrahedra and zero texture-map entries, where an equivalent [BoxTetraMesh4D]
## gives 160. The tiled shader samples `albedo_texture_3d` by UVW, so with none it
## has nothing to read and the surface renders flat whatever this says.
##
## The ceiling dodges this by being a square box hidden behind the wall, but the
## dais cannot: its rim is visible from every side, so squaring it would show.
## Fixing it properly means generating a UVW map for the cubinder, which belongs
## upstream in the 4d module alongside the missing `CylinderShape4D.to_tetra_mesh`.
@export var dais_textured: bool = false:
	set(value):
		dais_textured = value
		rebuild()

## Metres per texture on the platform only. Separate from [member texture_metres]
## for the same reason [member membrane_texture_metres] is separate: this is one
## very large, very flat surface, and it is the one most likely to want a
## different grain from everything around it. Match it to the floor's own scale
## and the inlay reads as part of the floor rather than a decal on top of it.
@export_range(0.1, 32.0, 0.1, "suffix:m") var dais_texture_metres: float = 1.0:
	set(value):
		dais_texture_metres = value
		rebuild()

## Palette entry for the platform. Stays inside the legend's structure family -
## yellow means interaction and blue means signage, and a platform is neither.
##
## "white" rather than "grey" specifically because the FLOOR is grey: matching it
## made the platform invisible from the spawn point, which is where it has to work.
## A 0.2 m step cannot be seen from on top of it - the rim is 13 m away and
## subtends almost nothing - so the level change has to be carried by contrast, not
## by the step itself.
@export var dais_color: String = "white":
	set(value):
		dais_color = value
		rebuild()

@export_group("Room")
## A cylindrical wall enclosing the whole arc, so the hub reads as a room rather
## than furniture on an open plain.
##
## NOT a cubinder like the dais, and that is the point: a cubinder is a SOLID disc,
## and a room needs a hollow tube. There is no CSG here to subtract one from
## another, so the wall is built the way [member HubGate4D.gate_shape]'s circular
## option builds its ring - from box segments sized by the CHORD at the outer
## radius. Chord rather than arc length matters: arc length overshoots, so
## neighbouring boxes cross and leave a visible lip at every joint.
##
## Consequence worth knowing: box segments are w-invariant, so unlike the dais this
## does not deform under slice rotation at all. It is the most stable thing in the
## scene, which is what you want from the walls of a room.
@export var show_room: bool = true:
	set(value):
		show_room = value
		rebuild()

## How far beyond the gate arc the wall stands. The gates sit at the arc radius, so
## this is the clear space between a door and the wall behind it.
@export_range(1.0, 40.0, 0.5, "suffix:m") var room_margin: float = 6.0:
	set(value):
		room_margin = value
		rebuild()

@export_range(2.0, 40.0, 0.5, "suffix:m") var room_height: float = 8.0:
	set(value):
		room_height = value
		rebuild()

@export_range(0.1, 4.0, 0.05, "suffix:m") var room_wall_thickness: float = 0.5:
	set(value):
		room_wall_thickness = value
		rebuild()

## Caps the room with a flat disc, turning the open tube into an enclosed hall.
##
## Off by default because the two read very differently and it is a real choice,
## not an oversight: open, the sky and the [GradientSkyMaterial4D] do most of the
## lighting and the space feels like an arena; closed, the hub becomes an interior
## and every surface depends on the [DirectionalLight4D], which points DOWN and
## will now be occluded by the very ceiling you just added. Expect to relight.
##
## Unlike the wall this IS a cubinder, the same solid disc the dais uses - a
## ceiling wants to be filled in, so there is nothing to hollow out.
@export var show_room_ceiling: bool = false:
	set(value):
		show_room_ceiling = value
		rebuild()

## How far the room extends along w, INDEPENDENT of the gates' [member w_extent].
##
## This is the control that lets the doors move while the room does not. A gate
## given a short w extent thins out and vanishes as you slice-rotate; the room set
## long stays exactly where it is, so the rotation reads as the DOORS changing
## rather than the world changing. Matching them instead makes everything shift at
## once, which is the disorienting version and much harder to read.
##
## Large by default for the same reason the floor is: navigation furniture that
## leaves the slice takes the player's frame of reference with it.
@export_range(1.0, 400.0, 1.0, "suffix:m") var room_w_extent: float = 120.0:
	set(value):
		room_w_extent = value
		rebuild()

## Textures the ceiling independently of the wall, so it can be a flat colour
## while the wall keeps its grain. A ceiling is the one surface with no detail
## worth reading - nothing is ever close enough to it to judge scale from - so a
## dev grid up there is mostly just noise overhead.
@export var room_ceiling_textured: bool = true:
	set(value):
		room_ceiling_textured = value
		rebuild()

@export_range(0.05, 4.0, 0.05, "suffix:m") var room_ceiling_thickness: float = 0.4:
	set(value):
		room_ceiling_thickness = value
		rebuild()

## Sides in the wall. Higher than the gates' [member segment_count] because this is
## one very large continuous curve seen from inside it, where faceting shows up
## immediately - the same reason [member dais_segments] defaults high.
@export_range(8, 128, 1) var room_segments: int = 64:
	set(value):
		room_segments = value
		rebuild()

@export var room_color: String = "white":
	set(value):
		room_color = value
		rebuild()

@export var room_textured: bool = true:
	set(value):
		room_textured = value
		rebuild()

@export_range(0.1, 32.0, 0.1, "suffix:m") var room_texture_metres: float = 1.0:
	set(value):
		room_texture_metres = value
		rebuild()

@export_group("Gate defaults")
## Applied to every generated gate. Changing one number here re-cuts all of them,
## which is the whole reason gates are generated rather than hand-placed.
@export_enum("Circular", "Rectangular") var gate_shape: int = 0:
	set(value):
		gate_shape = value
		notify_property_list_changed()
		rebuild()

@export_range(0.5, 6.0, 0.1, "suffix:m") var aperture_radius: float = 1.5:
	set(value):
		aperture_radius = value
		rebuild()

## Keeps rectangular openings as tall as they are wide, so [member
## aperture_radius] rescales them uniformly - the same feel as a circular gate.
@export var link_height_to_width: bool = true:
	set(value):
		link_height_to_width = value
		notify_property_list_changed()
		rebuild()

## Opening height for rectangular gates, used only while
## [member link_height_to_width] is off.
@export_range(1.0, 12.0, 0.1, "suffix:m") var aperture_height: float = 3.0:
	set(value):
		aperture_height = value
		rebuild()

@export_range(0.1, 2.0, 0.05, "suffix:m") var frame_thickness: float = 0.5:
	set(value):
		frame_thickness = value
		rebuild()

@export_range(0.1, 3.0, 0.05, "suffix:m") var frame_depth: float = 0.5:
	set(value):
		frame_depth = value
		rebuild()

@export_range(6, 48, 1) var segment_count: int = 16:
	set(value):
		segment_count = value
		rebuild()

@export_range(1.0, 200.0, 1.0, "suffix:m") var w_extent: float = 60.0:
	set(value):
		w_extent = value
		rebuild()

@export_range(0.0, 6.0, 0.1, "suffix:m") var threshold_depth: float = 2.0:
	set(value):
		threshold_depth = value
		rebuild()

@export_subgroup("Signage")
## Fallback panel size, used only when no [member sign_style] is assigned - the
## style carries its own, so the board and the hub cannot disagree about it.
@export var panel_size: Vector2 = Vector2(2.0, 1.0):
	set(value):
		panel_size = value
		rebuild()

## Clear space between the top of a gate's frame and the bottom of its sign, in
## metres. This is the "move every sign up or down" control: signs are positioned
## at `aperture_top + frame_thickness + billboard_gap + panel_height / 2`, so this
## slides all of them together while keeping each one tied to its own gate.
##
## It existed on the gate all along but the ring never passed it on, so every
## generated gate silently used the 0.55 m default and there was no way to reach it.
@export_range(0.0, 4.0, 0.05, "suffix:m") var billboard_gap: float = 0.55:
	set(value):
		billboard_gap = value
		rebuild()

## Typeface for every sign in the ring. Leave empty for Godot's default. Ignored
## when [member sign_style] is assigned, which carries its own font.
@export var font: Font:
	set(value):
		font = value
		rebuild()

## Shared typography for every sign: case, tracking, weight, spacing, outline.
## Point this and _sign_board.tscn at the same `.tres` and the preview is driven by
## the settings that ship, rather than by a copy of them.
@export var sign_style: HubSignStyle4D:
	set(value):
		sign_style = value
		rebuild()

@export_subgroup("W-hidden gate")
## How far along w the one ghosted gate sits, and how thick it is there. Only the
## entry with `w_hidden` set uses these - every other gate stays w-invariant, so
## the hub holds still while you rotate and exactly one thing changes.
@export_range(0.0, 40.0, 0.5, "suffix:m") var hidden_w_offset: float = 6.0:
	set(value):
		hidden_w_offset = value
		rebuild()

@export_range(0.5, 40.0, 0.5, "suffix:m") var hidden_w_extent: float = 4.0:
	set(value):
		hidden_w_extent = value
		rebuild()

@export_subgroup("Membrane")
## Translucent pane filling each opening, so a gate reads as something you step
## into rather than an empty frame.
@export var show_membrane: bool = true:
	set(value):
		show_membrane = value
		rebuild()

@export_range(0.0, 1.0, 0.01) var membrane_alpha: float = 0.35:
	set(value):
		membrane_alpha = value
		rebuild()

## Depth of each pane along its gate's local Z. See
## [member HubGate4D.membrane_thickness] for why this is no longer hairline-thin.
@export_range(0.02, 1.0, 0.01, "suffix:m") var membrane_thickness: float = 0.3:
	set(value):
		membrane_thickness = value
		rebuild()

## Palette entry for the pane: "black_metal", "white", "blue", "grey"...
@export var membrane_color: String = "black_metal":
	set(value):
		membrane_color = value
		rebuild()

## Metres per texture on the membranes only. Separate from the gate's own scale
## because the pane is a thin slab and the shared scale is least reliable there.
@export_range(0.05, 8.0, 0.05, "suffix:m") var membrane_texture_metres: float = 0.5:
	set(value):
		membrane_texture_metres = value
		rebuild()

@export_subgroup("Texturing")
## Maps the dev textures onto the gates instead of flat albedo sampled from them.
## See the note on [member HubGate4D.use_dev_textures] - the box UVW unwrap has no
## exposed scale, so this is an experiment rather than a finished look.
@export var use_dev_textures: bool = false:
	set(value):
		use_dev_textures = value
		rebuild()

## Metres one texture covers, on every face of every gate. Match this to the
## floor and back wall and the whole hub reads at one grain, which is what makes
## the greybox usable as a scale reference instead of decoration.
@export_range(0.1, 32.0, 0.1, "suffix:m") var texture_metres: float = 1.0:
	set(value):
		texture_metres = value
		rebuild()


func _ready() -> void:
	rebuild()
	# Signage has to be re-placed every rendered frame, because its position is
	# expressed relative to the camera rather than in world space - see
	# _on_pre_render for why. Connecting here rather than in _enter_tree keeps it
	# symmetric with _exit_tree and avoids double connections on scene reload.
	if not RenderingServer4D.pre_render.is_connected(_on_pre_render):
		RenderingServer4D.pre_render.connect(_on_pre_render)


func _exit_tree() -> void:
	if RenderingServer4D.pre_render.is_connected(_on_pre_render):
		RenderingServer4D.pre_render.disconnect(_on_pre_render)


func rebuild() -> void:
	if not is_inside_tree():
		return
	# Same Nil-tolerance the sign board needed: a @tool script that gains exports
	# while its scene is open keeps the node's old property table until reload, so
	# the new ones read as Nil. One warning that names the fix beats a wall of
	# type errors from halfway through a rebuild. See follow_up/engine_gotchas.md.
	# The booleans are checked as well as the array, and that is the important part:
	# a stale Nil in an INT or ARRAY errors loudly further down, but a Nil in a bool
	# just reads as false, so `if show_room:` skips the geometry in total silence
	# and the scene looks merely unfinished rather than broken. Every new toggle
	# added here should join this list.
	if (
		typeof(gates) != TYPE_ARRAY
		or typeof(gate_count) != TYPE_INT
		or typeof(show_dais) != TYPE_BOOL
		or typeof(show_room) != TYPE_BOOL
		or typeof(show_room_ceiling) != TYPE_BOOL
		or typeof(room_ceiling_textured) != TYPE_BOOL
		or typeof(room_w_extent) != TYPE_FLOAT
	):
		push_warning("HubGateRing4D: exports are not initialised - reload the scene (Scene > Reload Saved Scene).")
		return
	_clear_generated()
	if gates.is_empty():
		return

	var count: int = gate_count if gate_count > 0 else gates.size()
	var arc_radians := deg_to_rad(arc_degrees)
	var offset_radians := deg_to_rad(arc_offset_degrees)
	# A single gate sits dead ahead rather than at one end of the arc.
	var step := 0.0 if count <= 1 else arc_radians / _slot_divisor(count)
	var start := 0.0 if count <= 1 else -arc_radians * 0.5
	# Solved before anything is placed, because the dais is sized from it too and
	# the two must not disagree about where the arc actually is.
	var arc_radius := _effective_radius(count, arc_radians)

	if show_dais:
		_build_dais(arc_radius)
	if show_room:
		_build_room(arc_radius)

	for i in count:
		# Wraps, so gate_count above the catalogue size repeats entries rather
		# than leaving holes in the arc.
		var definition: HubGateDef4D = gates[i % gates.size()]
		if definition == null:
			push_warning("HubGateRing4D: gates[%d] is empty, skipping." % i)
			continue
		var angle := start + step * float(i) + offset_radians + deg_to_rad(definition.angle_nudge)
		_build_gate(definition, angle, arc_radius + definition.radius_nudge, i)

	_check_spacing(step, arc_radius)


## Widest horizontal footprint one slot has to hold, gate or sign.
##
## Both gate shapes are the opening plus a frame on each side, so one formula
## covers them: circular is 2*(r + t), rectangular is 2r + 2t. Same number.
## Signage sits ABOVE the aperture rather than beside it, so its contribution is
## just the panel width - it only collides if the panels themselves would meet.
## Mirrors HubGate4D._validate_property, so the ring's copies of the height
## controls disappear under exactly the same conditions the gate's do. 0 is
## Circular in this node's enum, which has no separate constant.
func _validate_property(property: Dictionary) -> void:
	if property.name == &"link_height_to_width":
		if gate_shape == 0:
			property.usage = PROPERTY_USAGE_NO_EDITOR
	elif property.name == &"aperture_height":
		if gate_shape == 0 or link_height_to_width:
			property.usage = PROPERTY_USAGE_NO_EDITOR
	elif property.name in PALETTE_PROPERTIES:
		# SUGGESTION rather than plain ENUM: PROPERTY_HINT_ENUM on a String is
		# index-based in several inspector paths, so entries can fail to
		# round-trip depending on their position in the list. SUGGESTION stores
		# the name and still allows typing one that is not listed.
		property.hint = PROPERTY_HINT_ENUM_SUGGESTION
		property.hint_string = Palette.get_names_hint()


## True once the sweep closes on itself.
func _is_closed_ring() -> bool:
	return arc_degrees >= 359.9


## How many GAPS the gates are spread across, which is not the same as how many
## gates there are.
##
## An open arc has endpoints, so N gates leave N-1 gaps and the outer two sit on
## the ends of the sweep. A CLOSED ring has no endpoints - the gap between the last
## gate and the first is a real gap like any other - so it is N. Using N-1 on a
## full circle puts the first and last gate at the same angle, exactly on top of
## each other, and the spacing check does not catch it because their separation is
## zero rather than merely tight.
func _slot_divisor(count: int) -> float:
	if count <= 1:
		return 1.0
	return float(count) if _is_closed_ring() else float(count - 1)


func _widest_footprint() -> float:
	return maxf((aperture_radius + frame_thickness) * 2.0, _effective_panel_size().x)


## Builds the enclosing wall out of box segments arranged around the arc's centre.
##
## Each segment is sized (chord, height, thickness, w) in its own local axes and
## rotated to stand tangentially, reusing the exact basis convention _build_gate
## uses - local X tangential, local Z radial - so the wall and the gates agree
## about which way "outward" is.
##
## Sits on top of the dais rather than the floor, so there is never a sliver of
## floor visible between the two, and carries no collider for the same reason the
## dais does not: bounding-box physics would turn each rotated segment into an
## axis-aligned box far larger than the segment itself, and the ring of them would
## close in on the player well inside the visible wall.
func _build_room(arc_radius: float) -> void:
	var room := Node4D.new()
	room.name = "Room"
	room.set_meta(GENERATED_META, true)
	add_child(room)

	var wall_radius := arc_radius + room_margin
	# Chord at the OUTER face, not arc length at the mid radius: arc length
	# overshoots and neighbouring boxes cross, leaving a lip at every joint. The
	# 1.02 is anti-seam slack, buried inside the wall where it cannot be seen.
	var outer_radius := wall_radius + room_wall_thickness * 0.5
	var chord := 2.0 * outer_radius * sin(PI / float(room_segments)) * 1.02
	var segment_size := Vector4(chord, room_height, room_wall_thickness, room_w_extent)
	# One material for every segment - they are all identical, and the tiled
	# shader derives its grain from the size, which does not vary.
	var material := SurfaceMaterial.surface(
		room_color, segment_size, room_texture_metres, room_textured
	)
	var base_y := _gate_base_y() + room_height * 0.5

	for i in room_segments:
		var angle := TAU * float(i) / float(room_segments)
		var cos_a := cos(angle)
		var sin_a := sin(angle)
		var mesh := BoxTetraMesh4D.new()
		mesh.size = segment_size
		var instance := MeshInstance4D.new()
		instance.name = "Seg%d" % i
		instance.mesh = mesh
		instance.material_override = material
		instance.basis = Projection(
			Vector4(cos_a, 0.0, sin_a, 0.0),
			Vector4(0.0, 1.0, 0.0, 0.0),
			Vector4(-sin_a, 0.0, cos_a, 0.0),
			Vector4(0.0, 0.0, 0.0, 1.0)
		)
		instance.position = Vector4(wall_radius * sin_a, base_y, -wall_radius * cos_a, 0.0)
		room.add_child(instance)

	if show_room_ceiling:
		_build_room_ceiling(room, outer_radius)


## Flat cap across the top of the wall.
##
## A cubinder rather than segments, because a ceiling is solid - the wall had to be
## a hollow tube and this does not. Radius runs to the wall's OUTER face so the
## joint is buried inside the wall rather than landing on its inside corner, where
## any rounding error would show as a slot of daylight running round the room.
##
## Sunk so its top is flush with the top of the wall, which means it never floats
## above the wall no matter what thickness it is given.
func _build_room_ceiling(room: Node4D, outer_radius: float) -> void:
	# A SQUARE slab, not a disc, and that is what makes it texturable. A cubinder
	# from to_tetra_mesh carries no UVW map at all - measured: 264 tetrahedra and
	# zero texture-map entries, against 160 for an equivalent BoxTetraMesh4D - so
	# the tiled shader has nothing to sample and renders it flat. That is also why
	# the dais cannot be textured.
	#
	# The corners are free: from inside a closed round room the wall occludes
	# everything past its own radius, so a square ceiling spanning the diameter
	# reads as a round one. Only somebody looking from OUTSIDE, or over the top of
	# a wall shorter than the room is wide, would ever see them.
	var span := outer_radius * 2.0
	var size := Vector4(span, room_ceiling_thickness, span, room_w_extent)
	var mesh := BoxTetraMesh4D.new()
	mesh.size = size

	var instance := MeshInstance4D.new()
	instance.name = "Ceiling"
	instance.mesh = mesh
	instance.material_override = SurfaceMaterial.surface(
		room_color,
		size,
		room_texture_metres,
		room_ceiling_textured
	)
	instance.position = Vector4(
		0.0,
		_gate_base_y() + room_height - room_ceiling_thickness * 0.5,
		0.0,
		0.0
	)
	room.add_child(instance)


## Panel size actually in force: the assigned style's, or this node's own when
## there is none. Spacing is checked against the size the signs are really drawn
## at, so a style that widens the panels widens the arc to match.
func _effective_panel_size() -> Vector2:
	return sign_style.panel_size if sign_style != null else panel_size


## The radius actually used, which is [member radius] unless [member auto_radius]
## has to grow it to fit [param count] gates into [param arc_radians].
##
## Spacing along the arc is `R * step` where `step = arc / (count - 1)`, so the
## smallest radius that still clears is `widest * clearance * (count - 1) / arc`.
## Solving it here rather than warning after the fact is what makes
## [member gate_count] safe to drag past five.
func _effective_radius(count: int, arc_radians: float) -> float:
	if not auto_radius or count <= 1 or arc_radians <= 0.0:
		return radius
	var needed := _widest_footprint() * SPACING_CLEARANCE * _slot_divisor(count) / arc_radians
	return maxf(radius, needed)


## Y the gates stand at: on top of the dais when there is one, on the floor when
## there is not. Read by [method _build_gate] so the two cannot drift apart.
func _gate_base_y() -> float:
	return dais_height if show_dais else 0.0


## Builds the platform from ONE [CubinderShape4D], used both as the collision shape
## and, via `to_tetra_mesh`, as the visual. See [member show_dais] for why it is a
## cubinder and not the rotation-invariant [CylinderShape4D].
##
## Driving both from a single shape object is the point: a separately-authored
## collider and mesh would be two numbers to keep in sync, and the failure mode is
## a floor you can see but fall through.
func _build_dais(arc_radius: float) -> void:
	var shape := CubinderShape4D.new()
	shape.radius = arc_radius + dais_rim_margin
	# Thicker than it shows: dais_height is how far it stands PROUD of the floor,
	# and the remainder is buried so no edge-on gap opens up under the rim.
	shape.height = dais_height + BURIED_DEPTH
	# Same w extent as the gates, so the platform is present in every slice the
	# player can rotate to rather than vanishing from under them.
	shape.thickness = w_extent

	var mesh: TetraMesh4D = shape.to_tetra_mesh({"segments": dais_segments})
	if mesh == null:
		push_warning("HubGateRing4D: CubinderShape4D.to_tetra_mesh returned nothing, dais not built.")
		return

	var root: Node4D
	if dais_collision:
		root = StaticBody4D.new()
	else:
		root = Node4D.new()
	root.name = "Dais"
	root.set_meta(GENERATED_META, true)
	# The slab is mostly BURIED: its top sits dais_height above the floor and the
	# rest hangs below, so there is never a gap to see under and never a lip tall
	# enough for the bounding-box solver to stop the player against.
	root.position = Vector4(0.0, dais_height - shape.height * 0.5, 0.0, 0.0)
	add_child(root)

	if dais_collision:
		# An EXPLICIT box, not the cubinder, and this changes nothing physically -
		# axis_aligned_box_physics_engine_4d reduces every shape to
		# get_rect_bounds_global() anyway, so the cubinder was already colliding as
		# its own bounding square. Stating it as a box stops the scene data implying
		# a round collider that the engine has never been capable of.
		#
		# The consequence is unavoidable rather than a choice: the square
		# circumscribes the disc, so the player stands on invisible floor out past
		# the visible rim - 12.5 m becomes 17.7 m at the corners. An inscribed box
		# would trade that for a visible rim you cannot stand on. Neither is right;
		# boxes cannot be circles.
		var box := BoxShape4D.new()
		box.size = Vector4(shape.radius * 2.0, shape.height, shape.radius * 2.0, shape.thickness)
		var collision := CollisionShape4D.new()
		collision.name = "CollisionShape4D"
		collision.shape = box
		root.add_child(collision)
		# The real footgun is HEIGHT, not shape. CharacterBody4D snaps across drops
		# of up to 0.1 m and has no step-up logic at all, so anything taller is a
		# wall: you walk off the platform and cannot get back on. Silent, and it
		# reads in play as the controller sticking rather than as a level bug.
		if dais_height > CHARACTER_SNAP_DISTANCE:
			push_warning(
				"HubGateRing4D: dais_height %.2f m exceeds CharacterBody4D's %.2f m snap distance with dais_collision on - the player will be able to walk off the dais but not back on. Lower dais_height or turn dais_collision off."
				% [dais_height, CHARACTER_SNAP_DISTANCE]
			)

	var instance := MeshInstance4D.new()
	instance.name = "MeshInstance4D"
	instance.mesh = mesh
	# The tiled shader derives its grain from a box's size, so it is given the
	# platform's bounding extent rather than a radius.
	instance.material_override = SurfaceMaterial.surface(
		dais_color,
		Vector4(shape.radius * 2.0, shape.height, shape.radius * 2.0, w_extent),
		dais_texture_metres,
		dais_textured
	)
	root.add_child(instance)


func _clear_generated() -> void:
	for child in get_children():
		if child.has_meta(GENERATED_META):
			child.queue_free()
			remove_child(child)


func _build_gate(definition: HubGateDef4D, angle: float, gate_radius: float, index: int) -> void:
	var cos_a := cos(angle)
	var sin_a := sin(angle)

	var gate := Node4D.new()
	gate.set_script(GateScript)
	gate.name = "Gate%d_%s" % [index, definition.gate_name.validate_node_name()]
	gate.set_meta(GENERATED_META, true)

	# Set every property BEFORE entering the tree. The gate's setters call
	# rebuild() and bail out while detached, so the geometry is built exactly
	# once, by _ready(), with the final values already in place.
	gate.gate_shape = gate_shape
	gate.aperture_radius = aperture_radius
	gate.link_height_to_width = link_height_to_width
	gate.aperture_height = aperture_height
	gate.frame_thickness = frame_thickness
	gate.frame_depth = frame_depth
	gate.segment_count = segment_count
	gate.w_extent = w_extent
	gate.threshold_depth = threshold_depth
	gate.panel_size = panel_size
	gate.billboard_gap = billboard_gap
	gate.use_dev_textures = use_dev_textures
	gate.texture_metres = texture_metres
	gate.font = font
	gate.sign_style = sign_style
	gate.hidden_w_offset = hidden_w_offset
	gate.hidden_w_extent = hidden_w_extent
	gate.show_membrane = show_membrane
	gate.membrane_alpha = membrane_alpha
	gate.membrane_color = membrane_color
	gate.membrane_thickness = membrane_thickness
	gate.membrane_texture_metres = membrane_texture_metres
	gate.gate_name = definition.gate_name
	gate.blurb = definition.blurb
	gate.icon = definition.icon
	gate.ghosted = definition.w_hidden
	gate.target_scene = definition.target_scene
	gate.visited = definition.visited

	# Forward is -Z, matching the player controller and Camera4D. Local -Z points
	# radially outward, so the gate's +Z - and therefore its billboard - faces the
	# spawn point at the arc's focus without any extra aiming.
	gate.basis = Projection(
		Vector4(cos_a, 0.0, sin_a, 0.0),
		Vector4(0.0, 1.0, 0.0, 0.0),
		Vector4(-sin_a, 0.0, cos_a, 0.0),
		Vector4(0.0, 0.0, 0.0, 1.0)
	)
	gate.position = Vector4(gate_radius * sin_a, _gate_base_y(), -gate_radius * cos_a, 0.0)

	add_child(gate)


## Places every billboard in CAMERA-RELATIVE space, once per rendered frame.
##
## This is the fix for signs that appear welded to the screen. The cross-section
## renderer does not draw the world in world coordinates: it computes
## `camera_inverse_transform * global_transform` for every 4D mesh
## (rendering_engine_4d.cpp) and parks its own 3D camera at the origin. A plain
## [Node3D] left at a world position is therefore interpreted as an offset from
## the viewer, so it tracks the camera instead of staying put. Writing the
## camera-relative transform ourselves puts the sign back in the world.
##
## Note this deliberately reads the CAMERA's basis, pitch included - unlike the
## bearing maths in bearing_utility_4d.gd, which must read the player body to
## avoid pitch leaking in. Here pitch is wanted: we are reproducing the renderer's
## own view transform, not asking a question about heading.
##
## The w component of the offset is discarded rather than used, which is what
## keeps signage readable at any slice rotation: the sign never rotates out of
## view, because it never had a w coordinate to rotate.
func _on_pre_render(camera: Camera4D, _viewport: Viewport, _rendering_engine: RenderingEngine4D) -> void:
	if camera == null or not is_inside_tree():
		return
	var camera_position := camera.global_position
	var camera_basis := camera.global_basis
	for gate in get_children():
		var billboard := gate.get_node_or_null("Billboard") as Node3D
		if billboard == null:
			continue
		var offset: Vector4 = gate.get_sign_local_offset()
		var gate_basis: Projection = gate.global_basis
		var world: Vector4 = gate.global_position \
			+ gate_basis.x * offset.x \
			+ gate_basis.y * offset.y \
			+ gate_basis.z * offset.z \
			+ gate_basis.w * offset.w
		var delta := world - camera_position
		# Transpose-multiply rather than a true inverse. Valid because the player
		# controller re-orthonormalises the body basis every frame specifically to
		# stop float drift accumulating through repeated rotation composition.
		billboard.position = Vector3(
			delta.dot(camera_basis.x),
			delta.dot(camera_basis.y),
			delta.dot(camera_basis.z)
		)
		# Orientation is left to the materials' billboard mode, which faces the
		# 3D camera at the origin - exactly where the cross-section renderer put it.
		billboard.basis = Basis()


## Warns rather than silently producing a layout where gates or their signs
## overlap. A silent geometry failure here would look like a modelling bug, which
## is exactly the trap the voxel work hit with grid overshoot.
## With [member auto_radius] on this should never fire, since the radius is solved
## to satisfy the very same inequality - so if it does, the two have diverged and
## that is worth knowing. With it off it is the old warning, unchanged.
func _check_spacing(step: float, arc_radius: float) -> void:
	if gates.size() < 2:
		return
	var spacing := arc_radius * step
	var widest := _widest_footprint()
	# Tolerance, because auto_radius solves for EXACTLY this boundary and then this
	# check re-derives the same number by a different route - radius * step here
	# against the closed form there. At the solution the two agree only to within
	# rounding, so a strict comparison fires on float noise and accuses
	# _effective_radius of a failure that is really a last-bit difference.
	if spacing < widest * SPACING_CLEARANCE - SPACING_EPSILON:
		var gate_width := (aperture_radius + frame_thickness) * 2.0
		var culprit := "gates" if gate_width >= _effective_panel_size().x else "billboards"
		var fix := (
			"auto_radius is ON and still short, which should not happen - check _effective_radius."
			if auto_radius
			else "Turn on auto_radius, or increase radius or arc_degrees, or shrink panel_size."
		)
		push_warning(
			"HubGateRing4D: %s crowded - %.2f m apart but %.2f m wide. %s"
			% [culprit, spacing, widest, fix]
		)
