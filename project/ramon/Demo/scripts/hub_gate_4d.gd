@tool
extends Node4D

## One hub gate: an aperture, a threshold pad, and a billboard above the door.
##
## Everything below the gate node is GENERATED and deliberately not owned by the
## scene. Nodes added without setting `owner` show up in the editor but are never
## serialised into the `.tscn`, so the scene file stores only the parameters and
## the geometry regenerates from them. That is what stops instances drifting out
## of sync with the source, and it sidesteps the `[editable path]` resave trap
## described in CLAUDE.md entirely - there is nothing persisted to go stale.
##
## APERTURE SHAPE. Slice-rotating mixes an axis with w, so a box that is long in
## w becomes long in x after an xw rotation - it survives the rotation but its
## apparent width changes as you turn. A profile that is rotationally symmetric
## in the rotated planes holds a more constant cross-section, which is why
## [constant SHAPE_CIRCULAR] approximates a ring out of box segments.
## [constant SHAPE_RECTANGULAR] is the honest post-and-lintel version - two
## pillars and a top piece - which is cheaper, reads more like a doorway, and is
## less stable under rotation. Which one actually feels better is a judgement
## call that needs eyes on it, hence both.

const Palette := preload("res://ramon/Demo/scripts/hub_palette.gd")
const SurfaceMaterial := preload("res://ramon/Demo/scripts/hub_material_4d.gd")

## Marks generated children so a rebuild can clear exactly what it made and
## nothing else. Checked via has_meta rather than name matching, which would
## break the moment Godot deduplicates a name.
const GENERATED_META := "hub_generated"

enum {
	SHAPE_CIRCULAR,
	SHAPE_RECTANGULAR,
}

@export_tool_button("Rebuild") var _rebuild_action: Callable = rebuild

@export_group("Aperture")
@export_enum("Circular", "Rectangular") var gate_shape: int = SHAPE_CIRCULAR:
	set(value):
		gate_shape = value
		rebuild()

## Half the width of the walkable opening, in metres. Drives BOTH shapes: a
## circular gate is a hole of this radius, a rectangular one is twice this wide.
## One control rescales gates whichever shape they are.
@export_range(0.5, 6.0, 0.1, "suffix:m") var aperture_radius: float = 1.5:
	set(value):
		aperture_radius = value
		rebuild()

## Keeps a rectangular opening as tall as it is wide, so dragging
## [member aperture_radius] scales it uniformly - the same feel as the circular
## gate. Turn it off for a doorway that is taller than it is wide.
@export var link_height_to_width: bool = true:
	set(value):
		link_height_to_width = value
		rebuild()

## Opening height for a rectangular gate. Ignored while
## [member link_height_to_width] is on, and always ignored for circular gates - a
## circular aperture is as tall as it is wide by definition, and squashing it to
## an ellipse would break the rotational symmetry that makes the shape worth
## having in the first place.
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

## How many box segments approximate the circular ring. 16 reads as round at 12 m
## without costing much; below about 10 it starts to look like a polygon.
@export_range(6, 48, 1) var segment_count: int = 16:
	set(value):
		segment_count = value
		rebuild()

## How far the gate extends along w. A large value keeps it PRESENT across every
## slice the player can rotate to. Present is not the same as unchanged.
@export_range(1.0, 200.0, 1.0, "suffix:m") var w_extent: float = 60.0:
	set(value):
		w_extent = value
		rebuild()

@export_group("Threshold")
@export_range(0.0, 6.0, 0.1, "suffix:m") var threshold_depth: float = 2.0:
	set(value):
		threshold_depth = value
		rebuild()

@export_group("Content")
@export var gate_name: String = "Untitled":
	set(value):
		gate_name = value
		rebuild()

@export_multiline var blurb: String = "":
	set(value):
		blurb = value
		rebuild()

@export var icon: Texture2D:
	set(value):
		icon = value
		rebuild()

## Makes this the hub's one w-varying gate: its frame and membrane are pushed out
## along w and given a short w extent, so they are genuinely ABSENT from the home
## slice and only enter it as the player slice-rotates.
##
## Every other gate is deliberately w-invariant - a long [member w_extent] keeps
## it present and stable at any rotation, because navigation furniture that
## changes as you turn is disorienting. This one breaks that rule on purpose, and
## the scarcity is what makes it legible as special.
##
## The threshold pad, state dot and billboard deliberately stay w-invariant even
## here. That is the "signpost the absence" idea: you see a yellow pad on the
## floor and a sign naming the destination, with no door above it. The affordance
## is visible; only the way through is not.
@export var ghosted: bool = false:
	set(value):
		ghosted = value
		rebuild()

## How far along w a ghosted gate sits. It re-enters the slice at roughly
## atan(offset / distance-from-origin) of zw rotation, so with the default ~6 m
## offset and a gate ~10 m out, a modest turn brings it in - far enough to need
## a deliberate rotation, close enough not to feel like a hunt.
@export_range(0.0, 40.0, 0.5, "suffix:m") var hidden_w_offset: float = 6.0:
	set(value):
		hidden_w_offset = value
		rebuild()

## Thickness along w of a ghosted gate. Short, so it passes through the slice
## rather than lingering - that transience is the whole effect.
@export_range(0.5, 40.0, 0.5, "suffix:m") var hidden_w_extent: float = 4.0:
	set(value):
		hidden_w_extent = value
		rebuild()

@export var visited: bool = false:
	set(value):
		visited = value
		rebuild()

## Maps the imported dev textures onto the 4D geometry instead of using flat
## albedo sampled from them. OFF by default: [BoxTetraMesh4D] carries a fixed cell
## UVW unwrap with no exposed scale, so a texture likely maps once across a whole
## box rather than once per metre - fine on a 0.5 m frame segment, wrong on a
## large slab. Flip it on to see what the mapping actually does.
@export var use_dev_textures: bool = false:
	set(value):
		use_dev_textures = value
		rebuild()

## Metres one texture covers, shared with the floor and wall so every surface in
## the hub reads at the same grain. Set from the ring.
@export_range(0.1, 32.0, 0.1, "suffix:m") var texture_metres: float = 1.0:
	set(value):
		texture_metres = value
		rebuild()

@export_group("Membrane")
## A thin translucent pane filling the opening, so a gate reads as something you
## step INTO rather than an empty frame you walk past. Uses the dark metal entry
## from the palette, which is the only place black earns its keep in the hub.
@export var show_membrane: bool = true:
	set(value):
		show_membrane = value
		rebuild()

@export_range(0.0, 1.0, 0.01) var membrane_alpha: float = 0.35:
	set(value):
		membrane_alpha = value
		rebuild()

## Palette entry for the pane. "black_metal" reads as dark glass; "white" or
## "blue" give a brighter, more obviously energised portal.
@export var membrane_color: String = "black_metal":
	set(value):
		membrane_color = value
		rebuild()

## Metres per texture on the membrane specifically, separate from the rest of the
## gate. The pane is a very thin slab, so it is the surface most likely to have
## the shared scale land wrong on it - this exists so it can be dialled without
## disturbing everything else that currently looks right.
@export_range(0.05, 8.0, 0.05, "suffix:m") var membrane_texture_metres: float = 0.5:
	set(value):
		membrane_texture_metres = value
		rebuild()

@export_group("Billboard")
## Billboards are ordinary 3D nodes, not 4D geometry, because a [TetraMaterial4D]
## cannot carry readable typography and a 3D node has no w coordinate to rotate -
## which makes it w-invariant for free.
##
## They are positioned in CAMERA-RELATIVE space, updated every frame by the ring.
## The cross-section renderer builds its 3D scene relative to the camera
## (`camera_inverse_transform * global_transform` in rendering_engine_4d.cpp) and
## parks its own 3D camera at the origin, so a world-space position here renders
## as a fixed offset from the viewer - the sign appears welded to the screen.
## See [method get_sign_local_offset]; the ring does the conversion.
@export var show_billboard: bool = true:
	set(value):
		show_billboard = value
		rebuild()

## Clearance between the top of the aperture and the bottom of the panel.
@export_range(0.0, 4.0, 0.05, "suffix:m") var billboard_gap: float = 0.55:
	set(value):
		billboard_gap = value
		rebuild()

@export var panel_size: Vector2 = Vector2(2.4, 1.0):
	set(value):
		panel_size = value
		rebuild()

## Upright billboarding by default: the sign swings about its vertical axis to
## face the player but never tilts. Full billboarding reads as floating UI, which
## is exactly the clunky feel worth avoiding on a diegetic sign.
@export var keep_upright: bool = true:
	set(value):
		keep_upright = value
		rebuild()

## Typeface for both lines. Leave empty for Godot's default. Drop any .ttf/.otf
## into the project and drag it here - a mono face is worth keeping, it carries a
## lot of the honest-dev credibility the whole look depends on.
@export var font: Font:
	set(value):
		font = value
		rebuild()

## Cap height works out near 0.2 m at these defaults, which subtends about a
## degree from 12 m - readable from the spawn point, so a destination can be
## chosen without walking to every sign first.
@export var title_font_size: int = 64
@export var title_pixel_size: float = 0.003
## Deliberately smaller: the blurb only resolves from a few metres, and that
## gradient is the incentive to approach.
@export var blurb_font_size: int = 32
@export var blurb_pixel_size: float = 0.0025


func _ready() -> void:
	rebuild()


## Full width of the opening, in metres. Same for both shapes.
func get_aperture_width() -> float:
	return aperture_radius * 2.0


## w thickness for the parts that are allowed to leave the slice. Everything else
## in the gate uses [member w_extent] and stays put.
func _frame_w_extent() -> float:
	return hidden_w_extent if ghosted else w_extent


## w displacement for those same parts. Zero for an ordinary gate.
func _frame_w_offset() -> float:
	return hidden_w_offset if ghosted else 0.0


## Height of the top of the opening, in metres above the floor. A circle sits
## with its lowest point on the floor, so its highest point is one diameter up.
func get_aperture_top() -> float:
	if gate_shape == SHAPE_RECTANGULAR and not link_height_to_width:
		return aperture_height
	return aperture_radius * 2.0


## Where the billboard sits, in the gate's own local space. The ring converts
## this to camera-relative coordinates every frame - see the note on
## [member show_billboard] for why it cannot simply be a world position.
func get_sign_local_offset() -> Vector4:
	var height := get_aperture_top() + frame_thickness + billboard_gap + panel_size.y * 0.5
	return Vector4(0.0, height, 0.0, 0.0)


## Clears previously generated children and rebuilds the gate from the exports.
func rebuild() -> void:
	if not is_inside_tree():
		return
	_clear_generated()
	if gate_shape == SHAPE_RECTANGULAR:
		_build_rectangular_frame()
	else:
		_build_circular_frame()
	if show_membrane:
		_build_membrane()
	_build_threshold()
	_build_state_dot()
	if show_billboard:
		_build_billboard()
		if Engine.is_editor_hint():
			_build_sign_proxy()


## A flat pane sitting in the plane of the opening.
##
## For a rectangular gate it fills the opening exactly. For a circular one it is
## the INSCRIBED square (side = diameter / sqrt(2)), because a full-width square
## would poke out through the round hole. That leaves four gaps at the arcs,
## which is a deliberate trade: a square is what reads as a panel, and matching
## the circle would need generated disc geometry rather than a box.
func _build_membrane() -> void:
	var width := get_aperture_width()
	var height := get_aperture_top()
	if gate_shape == SHAPE_CIRCULAR:
		var side: float = width * 0.7071
		var round_size := Vector4(side, side, 0.03, _frame_w_extent())
		_adopt(_make_box(
			"Membrane",
			round_size,
			Vector4(0.0, aperture_radius, 0.0, _frame_w_offset()),
			SurfaceMaterial.surface(membrane_color, round_size, membrane_texture_metres, use_dev_textures, membrane_alpha)
		))
		return
	var rect_size := Vector4(width, height, 0.03, _frame_w_extent())
	_adopt(_make_box(
		"Membrane",
		rect_size,
		Vector4(0.0, height * 0.5, 0.0, _frame_w_offset()),
		SurfaceMaterial.surface(membrane_color, rect_size, membrane_texture_metres, use_dev_textures, membrane_alpha)
	))


## Editor-only stand-in for the billboard.
##
## The real sign is made of [Node3D]s positioned in camera-relative space by the
## ring, which the editor's 4D tab does not show. This puts a plain 4D slab at the
## same spot so the sign's position and size are visible while laying the hub out.
## It faces the gate's local Z and never turns - it is a placement aid, not a
## preview of how the sign will read in game.
func _build_sign_proxy() -> void:
	var proxy_size := Vector4(panel_size.x, panel_size.y, 0.06, minf(w_extent, 4.0))
	# Flat, not textured: it stands in for a sign, and tiling a dev grid across it
	# would make it read as another piece of structure.
	var proxy := _make_box(
		"SignProxyEditorOnly",
		proxy_size,
		get_sign_local_offset(),
		SurfaceMaterial.flat("blue", 0.85)
	)
	_adopt(proxy)


func _clear_generated() -> void:
	for child in get_children():
		if child.has_meta(GENERATED_META):
			child.queue_free()
			remove_child(child)


func _adopt(node: Node) -> void:
	node.set_meta(GENERATED_META, true)
	add_child(node)


## Builds a material at the hub's shared world texture scale.
##
## [param size] is the box the material goes on, not the gate: the shader derives
## tiling from it per cell, so a 0.25 m frame segment and the 48 m floor end up
## with the same grain instead of one texture stretched across each regardless of
## size. That consistency is the whole reason this goes through
## hub_material_4d.gd rather than being built inline.
func _make_material(palette_name: String, size: Vector4, alpha: float = 1.0) -> TetraMaterial4D:
	return SurfaceMaterial.surface(palette_name, size, texture_metres, use_dev_textures, alpha)


func _frame_material(size: Vector4) -> TetraMaterial4D:
	if ghosted:
		# Whether the cross-section renderer sorts translucent tetrahedra
		# correctly is UNVERIFIED - if this reads badly, fall back to a solid
		# frame in a dimmed structure colour.
		return _make_material("yellow", size, 0.35)
	return _make_material("grey", size)


## Creates a box mesh instance without parenting it - the caller decides whether
## it belongs to a sub-group or needs [method _adopt] to mark it generated.
func _make_box(box_name: String, size: Vector4, offset: Vector4, material: TetraMaterial4D, basis_override: Variant = null) -> MeshInstance4D:
	var mesh := BoxTetraMesh4D.new()
	mesh.size = size
	var instance := MeshInstance4D.new()
	instance.name = box_name
	instance.mesh = mesh
	instance.material_override = material
	instance.position = offset
	if basis_override != null:
		instance.basis = basis_override
	return instance


func _build_circular_frame() -> void:
	var frame := Node4D.new()
	frame.name = "Frame"
	_adopt(frame)

	var centre_radius := aperture_radius + frame_thickness * 0.5
	# Length is the CHORD at the outer radius, not the arc at the mid radius.
	# Using the arc length overshoots, so neighbouring boxes cross each other and
	# leave a visible lip on the inside of the ring - the offset at the joins.
	# The chord meets exactly at the outer edge; whatever overlaps further in is
	# buried inside the frame where it cannot be seen. 1.02 is anti-seam slack.
	var segment_length := 2.0 * (aperture_radius + frame_thickness) * sin(PI / float(segment_count)) * 1.02
	# Every segment is the same size, so one material serves all of them.
	var segment_size := Vector4(frame_thickness, segment_length, frame_depth, _frame_w_extent())
	var material := _frame_material(segment_size)

	for i in segment_count:
		var angle := TAU * float(i) / float(segment_count)
		var cos_a := cos(angle)
		var sin_a := sin(angle)
		# Rotate about Z so the box's local X points radially outward.
		var segment_basis := Projection(
			Vector4(cos_a, sin_a, 0.0, 0.0),
			Vector4(-sin_a, cos_a, 0.0, 0.0),
			Vector4(0.0, 0.0, 1.0, 0.0),
			Vector4(0.0, 0.0, 0.0, 1.0)
		)
		# Ring centred at y = aperture_radius so the hole's lowest point sits on
		# the floor and the gate is walkable rather than a window.
		frame.add_child(_make_box(
			"Seg%d" % i,
			Vector4(frame_thickness, segment_length, frame_depth, _frame_w_extent()),
			Vector4(centre_radius * cos_a, aperture_radius + centre_radius * sin_a, 0.0, _frame_w_offset()),
			material,
			segment_basis
		))


## Post and lintel: two pillars and a top piece, exactly three boxes.
func _build_rectangular_frame() -> void:
	var frame := Node4D.new()
	frame.name = "Frame"
	_adopt(frame)

	var width := get_aperture_width()
	var height := get_aperture_top()
	var pillar_centre := width * 0.5 + frame_thickness * 0.5

	# Pillars and lintel are different shapes, so each needs its own material for
	# the texture scale to come out the same on both.
	var pillar_size := Vector4(frame_thickness, height, frame_depth, _frame_w_extent())
	var pillar_material := _frame_material(pillar_size)
	for side in [-1.0, 1.0]:
		var label := "PillarLeft" if side < 0.0 else "PillarRight"
		frame.add_child(_make_box(
			label,
			pillar_size,
			Vector4(side * pillar_centre, height * 0.5, 0.0, _frame_w_offset()),
			pillar_material
		))

	# Lintel spans both pillars so the corners read as solid rather than notched.
	var lintel_size := Vector4(width + frame_thickness * 2.0, frame_thickness, frame_depth, _frame_w_extent())
	frame.add_child(_make_box(
		"Lintel",
		lintel_size,
		Vector4(0.0, height + frame_thickness * 0.5, 0.0, _frame_w_offset()),
		_frame_material(lintel_size)
	))


func _build_threshold() -> void:
	if threshold_depth <= 0.0:
		return
	# Thin in Y so it reads as a floor marking rather than a step to trip on, and
	# on local +Z - the side facing the spawn point. The gate's local -Z points
	# radially OUTWARD, so putting the pad there parks it behind the gate where
	# the player never walks, which is what made them look like loose platforms
	# sitting out in the field.
	var pad_size := Vector4(get_aperture_width(), 0.04, threshold_depth, w_extent)
	_adopt(_make_box(
		"Threshold",
		pad_size,
		Vector4(0.0, 0.02, frame_depth * 0.5 + threshold_depth * 0.5, 0.0),
		_make_material("yellow", pad_size)
	))


## Small marker at a fixed position on every gate whose colour is the ONLY thing
## that differs between gates. Identity is the billboard's job; colour is kept
## free to carry state, which is what it is actually good at.
func _build_state_dot() -> void:
	var dot_size := Vector4(0.25, 0.25, 0.25, w_extent)
	# Flat: at 0.25 m a tiled grid would land as noise, and this marker's whole
	# job is to be one readable block of colour.
	_adopt(_make_box(
		"StateDot",
		dot_size,
		Vector4(0.0, get_aperture_top() + frame_thickness * 0.5, 0.0, 0.0),
		SurfaceMaterial.flat("white" if visited else "black_metal")
	))


func _build_billboard() -> void:
	var root := Node3D.new()
	root.name = "Billboard"
	_adopt(root)

	var billboard_mode := BaseMaterial3D.BILLBOARD_FIXED_Y if keep_upright else BaseMaterial3D.BILLBOARD_ENABLED

	var panel_material := StandardMaterial3D.new()
	panel_material.albedo_color = Palette.signage()
	# Unshaded so the sign reads identically wherever the sun falls, and stays
	# constant as the player slice-rotates past differently lit geometry.
	panel_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	panel_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	panel_material.billboard_mode = billboard_mode

	var quad := QuadMesh.new()
	quad.size = panel_size

	var panel := MeshInstance3D.new()
	panel.name = "Panel"
	panel.mesh = quad
	panel.material_override = panel_material
	root.add_child(panel)

	var text_colour := Palette.signage_text()
	var half_width: float = panel_size.x * 0.5
	var icon_cell: float = panel_size.y * 0.55
	var text_left := -half_width + 0.14

	if icon != null:
		var sprite := Sprite3D.new()
		sprite.name = "Icon"
		sprite.texture = icon
		sprite.shaded = false
		sprite.modulate = text_colour
		sprite.billboard = billboard_mode
		# Scale so the icon's long edge matches the cell regardless of the
		# source PNG's resolution.
		var longest: float = float(maxi(icon.get_width(), icon.get_height()))
		if longest > 0.0:
			sprite.pixel_size = icon_cell / longest
		sprite.position = Vector3(-half_width + icon_cell * 0.5 + 0.12, 0.0, 0.02)
		root.add_child(sprite)
		text_left = -half_width + icon_cell + 0.24

	var title := Label3D.new()
	title.name = "Title"
	title.text = gate_name
	if font != null:
		title.font = font
	title.font_size = title_font_size
	title.pixel_size = title_pixel_size
	title.modulate = text_colour
	title.billboard = billboard_mode
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.position = Vector3(text_left, panel_size.y * 0.19, 0.02)
	root.add_child(title)

	if not blurb.is_empty():
		var line := Label3D.new()
		line.name = "Blurb"
		line.text = blurb
		if font != null:
			line.font = font
		line.font_size = blurb_font_size
		line.pixel_size = blurb_pixel_size
		line.modulate = text_colour
		line.billboard = billboard_mode
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		line.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		line.width = maxf(0.1, panel_size.x - (text_left + half_width)) / blurb_pixel_size
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.position = Vector3(text_left, -panel_size.y * 0.19, 0.02)
		root.add_child(line)
