@tool
extends Node4D

## Lays the hub's gates out along an arc and builds each one from its definition.
##
## The hub scene holds no gates and no billboards - it holds this node and an
## array of [HubGateDef4D]. Everything visible is generated, unowned, and rebuilt
## from the array whenever anything changes. Adding a prototype to the demo is
## one new `.tres` dropped into [member gates].
##
## WHY AN ARC RATHER THAN A FULL RING: a closed ring always has content behind
## the player, and someone disoriented by their first slice rotation may simply
## never turn around. An arc puts every option inside one sweep and leaves a
## solid wall at the player's back, which is orientation anchoring - you always
## know which way "back" is. That matters more here than it would in a 3D scene,
## because slice rotation removes most of the other cues people navigate by.
##
## [member gates] order drives angular position, so reordering the array in the
## inspector re-lays-out the arc. Centre slot is the one a stakeholder looks at
## first, so being able to A/B that in two seconds is the point.

const GateScript := preload("res://ramon/Demo/scripts/hub_gate_4d.gd")
const GENERATED_META := "hub_generated"

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

## Total angular spread. Beyond about 180° gates start falling behind the player.
@export_range(20.0, 340.0, 1.0, "suffix:°") var arc_degrees: float = 160.0:
	set(value):
		arc_degrees = value
		rebuild()

## Rotates the whole arc about the spawn point, for aiming it at a back wall.
@export_range(-180.0, 180.0, 1.0, "suffix:°") var arc_offset_degrees: float = 0.0:
	set(value):
		arc_offset_degrees = value
		rebuild()

@export_group("Gate defaults")
## Applied to every generated gate. Changing one number here re-cuts all of them,
## which is the whole reason gates are generated rather than hand-placed.
@export_enum("Circular", "Rectangular") var gate_shape: int = 0:
	set(value):
		gate_shape = value
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

@export var panel_size: Vector2 = Vector2(2.0, 1.0):
	set(value):
		panel_size = value
		rebuild()

## Typeface for every sign in the ring. Leave empty for Godot's default.
@export var font: Font:
	set(value):
		font = value
		rebuild()

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
	_clear_generated()
	if gates.is_empty():
		return

	var count: int = gate_count if gate_count > 0 else gates.size()
	var arc_radians := deg_to_rad(arc_degrees)
	var offset_radians := deg_to_rad(arc_offset_degrees)
	# A single gate sits dead ahead rather than at one end of the arc.
	var step := 0.0 if count <= 1 else arc_radians / float(count - 1)
	var start := 0.0 if count <= 1 else -arc_radians * 0.5

	for i in count:
		# Wraps, so gate_count above the catalogue size repeats entries rather
		# than leaving holes in the arc.
		var definition: HubGateDef4D = gates[i % gates.size()]
		if definition == null:
			push_warning("HubGateRing4D: gates[%d] is empty, skipping." % i)
			continue
		var angle := start + step * float(i) + offset_radians + deg_to_rad(definition.angle_nudge)
		_build_gate(definition, angle, radius + definition.radius_nudge, i)

	_check_spacing(step)


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
	gate.use_dev_textures = use_dev_textures
	gate.texture_metres = texture_metres
	gate.font = font
	gate.hidden_w_offset = hidden_w_offset
	gate.hidden_w_extent = hidden_w_extent
	gate.show_membrane = show_membrane
	gate.membrane_alpha = membrane_alpha
	gate.membrane_color = membrane_color
	gate.membrane_texture_metres = membrane_texture_metres
	gate.gate_name = definition.gate_name
	gate.blurb = definition.blurb
	gate.icon = definition.icon
	gate.ghosted = definition.w_hidden
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
	gate.position = Vector4(gate_radius * sin_a, 0.0, -gate_radius * cos_a, 0.0)

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
func _check_spacing(step: float) -> void:
	if gates.size() < 2:
		return
	var spacing := radius * step
	# Both shapes are the opening plus a frame on each side, so one formula covers
	# them: circular is 2*(r + t), rectangular is 2r + 2t. Same number.
	var gate_width := (aperture_radius + frame_thickness) * 2.0
	# Signage sits above the aperture rather than beside it, so its horizontal
	# footprint is just the panel width - it only collides if the panels
	# themselves would meet.
	var widest: float = maxf(gate_width, panel_size.x)
	if spacing < widest * 1.1:
		var culprit := "gates" if gate_width >= panel_size.x else "billboards"
		push_warning(
			"HubGateRing4D: %s overlap - %.1f m apart but %.1f m wide. Increase radius or arc_degrees, remove a gate, or shrink panel_size."
			% [culprit, spacing, widest]
		)
