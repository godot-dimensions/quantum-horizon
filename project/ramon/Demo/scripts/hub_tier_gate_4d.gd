@tool
extends Node4D

## One hub2 door: frame, membrane, threshold pad, state dot. No billboard - see
## HUB2_README.md for why identity is address, not signage.
##
## Forked from hub1's hub_gate_4d.gd rather than reused: hub1 must keep
## generating exactly what it always has for the A/B to mean anything, and this
## scene needs less than it does - no circular-shape option, no billboard, no
## per-gate w-ghosting. That last one is the key difference: in hub2 the RAMP
## carries every w-dependency (see HubTierRing4D), so the door itself is always
## w-invariant and can be as boringly constant as most of hub1's gates already
## are.
##
## Generated children are deliberately unowned, same reasoning as hub1: nothing
## here should ever serialise into hub2.tscn.

const SurfaceMaterial := preload("res://ramon/Demo/scripts/hub_material_4d.gd")

const GENERATED_META := "hub_generated"

@export_tool_button("Rebuild") var _rebuild_action: Callable = rebuild

@export_group("Aperture")
@export_range(0.5, 6.0, 0.1, "suffix:m") var aperture_radius: float = 1.1:
	set(value):
		aperture_radius = value
		rebuild()

@export_range(0.1, 2.0, 0.05, "suffix:m") var frame_thickness: float = 0.25:
	set(value):
		frame_thickness = value
		rebuild()

@export_range(0.1, 3.0, 0.05, "suffix:m") var frame_depth: float = 0.6:
	set(value):
		frame_depth = value
		rebuild()

## Long enough to stay present at any slice the player can reach. Unlike hub1,
## nothing in hub2's door is ever the ghosted element - see the note at the top
## of this file.
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
@export var gate_name: String = "Untitled"
@export var visited: bool = false

@export_group("Membrane")
@export var show_membrane: bool = true:
	set(value):
		show_membrane = value
		rebuild()

@export_range(0.0, 1.0, 0.01) var membrane_alpha: float = 0.35:
	set(value):
		membrane_alpha = value
		rebuild()

@export var membrane_color: String = "black_metal":
	set(value):
		membrane_color = value
		rebuild()

@export_range(0.05, 8.0, 0.05, "suffix:m") var membrane_texture_metres: float = 0.5:
	set(value):
		membrane_texture_metres = value
		rebuild()

@export_group("Texturing")
@export var use_dev_textures: bool = true:
	set(value):
		use_dev_textures = value
		rebuild()

@export_range(0.1, 32.0, 0.1, "suffix:m") var texture_metres: float = 1.0:
	set(value):
		texture_metres = value
		rebuild()


func _ready() -> void:
	rebuild()


func get_aperture_width() -> float:
	return aperture_radius * 2.0


## A circle sits with its lowest point on the floor, so its highest point is
## one diameter up - kept for parity with hub1's formula even though hub2 only
## ever builds the rectangular frame, in case a second shape is added later.
func get_aperture_top() -> float:
	return aperture_radius * 2.0


func rebuild() -> void:
	if not is_inside_tree():
		return
	_clear_generated()
	_build_frame()
	if show_membrane:
		_build_membrane()
	_build_threshold()
	_build_state_dot()


func _clear_generated() -> void:
	for child in get_children():
		if child.has_meta(GENERATED_META):
			child.queue_free()
			remove_child(child)


func _adopt(node: Node) -> void:
	node.set_meta(GENERATED_META, true)
	add_child(node)


func _make_box(box_name: String, size: Vector4, offset: Vector4, material: TetraMaterial4D) -> MeshInstance4D:
	var mesh := BoxTetraMesh4D.new()
	mesh.size = size
	var instance := MeshInstance4D.new()
	instance.name = box_name
	instance.mesh = mesh
	instance.material_override = material
	instance.position = offset
	return instance


## Post and lintel: two pillars and a top piece, exactly three boxes - hub1's
## rectangular option, minus the circular alternative this scene has no use
## for.
func _build_frame() -> void:
	var frame := Node4D.new()
	frame.name = "Frame"
	_adopt(frame)

	var width := get_aperture_width()
	var height := get_aperture_top()
	var pillar_centre := width * 0.5 + frame_thickness * 0.5

	var pillar_size := Vector4(frame_thickness, height, frame_depth, w_extent)
	var pillar_material := SurfaceMaterial.surface("grey", pillar_size, texture_metres, use_dev_textures)
	for side in [-1.0, 1.0]:
		var label := "PillarLeft" if side < 0.0 else "PillarRight"
		frame.add_child(_make_box(
			label,
			pillar_size,
			Vector4(side * pillar_centre, height * 0.5, 0.0, 0.0),
			pillar_material
		))

	var lintel_size := Vector4(width + frame_thickness * 2.0, frame_thickness, frame_depth, w_extent)
	frame.add_child(_make_box(
		"Lintel",
		lintel_size,
		Vector4(0.0, height + frame_thickness * 0.5, 0.0, 0.0),
		SurfaceMaterial.surface("grey", lintel_size, texture_metres, use_dev_textures)
	))


## A flat pane filling the opening, so a gate reads as something you step INTO
## rather than an empty frame. Always the full-width rectangle - hub2 never
## builds the circular shape hub1's inscribed-square workaround was for.
func _build_membrane() -> void:
	var width := get_aperture_width()
	var height := get_aperture_top()
	var rect_size := Vector4(width, height, 0.03, w_extent)
	_adopt(_make_box(
		"Membrane",
		rect_size,
		Vector4(0.0, height * 0.5, 0.0, 0.0),
		SurfaceMaterial.surface(membrane_color, rect_size, membrane_texture_metres, use_dev_textures, membrane_alpha)
	))


## On local +Z, the side facing the spawn point - see the ring's note on which
## way local Z points for this scene's gates.
func _build_threshold() -> void:
	if threshold_depth <= 0.0:
		return
	var pad_size := Vector4(get_aperture_width(), 0.04, threshold_depth, w_extent)
	_adopt(_make_box(
		"Threshold",
		pad_size,
		Vector4(0.0, 0.02, frame_depth * 0.5 + threshold_depth * 0.5, 0.0),
		SurfaceMaterial.surface("yellow", pad_size, texture_metres, use_dev_textures)
	))


## The one piece of hub1's colour legend this scene keeps - it is a colour, not
## text, so dropping the billboard does not touch it.
func _build_state_dot() -> void:
	var dot_size := Vector4(0.25, 0.25, 0.25, w_extent)
	_adopt(_make_box(
		"StateDot",
		dot_size,
		Vector4(0.0, get_aperture_top() + frame_thickness * 0.5, 0.0, 0.0),
		SurfaceMaterial.flat("white" if visited else "black_metal")
	))
