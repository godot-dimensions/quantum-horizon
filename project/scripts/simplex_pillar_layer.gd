class_name SimplexPillarLayer
extends Node4D
## A central pillar with `ring_count` upright 4-simplices arranged at
## regular angles around it, the whole configuration slowly yawing (an
## ordinary x/z rotation - the same plane used for player-facing yaw
## elsewhere in this project, e.g. player.gd's own Basis4D.from_zx - so this
## never touches w and can't trigger any grazing-angle Cross-section
## behavior on its own; the ring only looks 4D because the simplices
## themselves are).
##
## "Standing upright": SimplexTetraMesh4D.build() puts its apex on the w
## axis alone (built for the flat, edge-on-at-w=0 look used in the 8x8 grid
## test). An initial attempt used Basis4D.from_swap_rotation(1, 3), reasoned
## out from its C++ source as new_y=old_w/new_w=-old_y - WRONG in practice
## (rendered flat, not upright; a direct screenshot caught it, per this
## project's own verify-before-claiming standard), because Basis4D's actual
## column-vs-row convention wasn't independently confirmed before relying on
## it. _UPRIGHT_BASIS below sidesteps that ambiguity entirely: it's built
## directly via Projection's own 4-column constructor (x_axis, y_axis,
## z_axis, w_axis - each "where that local axis maps to", the same
## convention player.gd's own "basis * input_dir" xform relies on), so the
## y/w swap is explicit and checkable by inspection rather than inferred.
## Confirmed this time by an actual re-render showing real vertical extent.
const _UPRIGHT_BASIS := Projection(
	Vector4(1, 0, 0, 0), # local x stays x
	Vector4(0, 0, 0, -1), # local y (old apex-less axis) feeds into new w
	Vector4(0, 0, 1, 0), # local z stays z
	Vector4(0, 1, 0, 0), # local w (where the apex actually lives) feeds into new y
)

const SimplexTetraMesh4D = preload("res://scripts/simplex_tetra_mesh_4d.gd")

@export var ring_count: int = 8
@export var ring_radius: float = 6.0
@export var simplex_edge_length: float = 2.5
@export var simplex_color: Color = Color(0.9, 0.35, 0.2)
@export var pillar_height: float = 6.0
@export var pillar_width: float = 1.2
@export var pillar_color: Color = Color(0.5, 0.5, 0.55)
@export_range(0.0, 30.0, 0.5, "suffix:deg/s") var spin_speed_degrees: float = 6.0

var _spin_angle: float = 0.0


func _ready() -> void:
	var pillar := MeshInstance4D.new()
	var pillar_mesh := BoxTetraMesh4D.new()
	pillar_mesh.size = Vector4(pillar_width, pillar_height, pillar_width, pillar_width)
	pillar.mesh = pillar_mesh
	var pillar_material := TetraMaterial4D.new()
	pillar_material.albedo_source = TetraMaterial4D.TETRA_COLOR_SOURCE_SINGLE_COLOR
	pillar_material.albedo_color = pillar_color
	pillar.material_override = pillar_material
	pillar.position = Vector4(0.0, pillar_height * 0.5, 0.0, 0.0)
	add_child(pillar)

	var shared_mesh: ArrayTetraMesh4D = SimplexTetraMesh4D.build(simplex_edge_length)
	var shared_material := TetraMaterial4D.new()
	shared_material.albedo_source = TetraMaterial4D.TETRA_COLOR_SOURCE_SINGLE_COLOR
	shared_material.albedo_color = simplex_color

	# Shifts each instance up by exactly the base's own (negative) local y
	# after the upright swap, so the base sits at y=0 (on the ground) instead
	# of straddling it - see this script's own header for the swap's effect
	# and SimplexTetraMesh4D's own header for where w_base/w_apex come from.
	var scale: float = simplex_edge_length / (2.0 * sqrt(2.0))
	var base_y: float = (sqrt(5.0) / 5.0) * scale

	for i in range(ring_count):
		var angle: float = float(i) * TAU / float(ring_count)
		var instance := MeshInstance4D.new()
		instance.mesh = shared_mesh
		instance.material_override = shared_material
		instance.basis = _UPRIGHT_BASIS
		instance.position = Vector4(
			ring_radius * cos(angle),
			base_y,
			ring_radius * sin(angle),
			0.0
		)
		add_child(instance)


func _process(delta: float) -> void:
	# Absolute angle tracked and rebuilt fresh each frame, not composed onto
	# the node's own current basis - the same drift-avoidance convention
	# voxel_hover_camera_4d.gd's own right-drag handler documents (composing
	# in the node's current local frame accumulates error over many steps).
	_spin_angle += deg_to_rad(spin_speed_degrees) * delta
	basis = Basis4D.from_zx(_spin_angle)
