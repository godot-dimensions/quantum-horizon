extends Node4D

## Standalone preview for a possible hub centerpiece - not wired into hub1 or
## hub2. Loads a 4D polytope mesh, idles with a slow ambient spin so it is
## never static even for someone who just stands and looks, and reacts to the
## player's own rotate_4d drag with an AMPLIFIED version of the same rotation,
## so the spectacle is visibly tied to the one control the whole game is
## about rather than being an unrelated decoration.
##
## Rotation and scale are kept separate on purpose: [member _rotation] is an
## orthonormal Projection updated every frame, and [member display_scale] is
## only reapplied when writing the mesh's actual basis. Multiplying the scaled
## basis directly by a rotation and re-orthonormalizing (the way player.gd
## re-orthonormalizes its own basis every frame) would force every column back
## to unit length and silently shrink the mesh to scale 1 on the first update.

@export var mesh_path: String = "res://models/primitives/platonic/120_cell/120_cell_smooth.g4b"
@export_range(0.1, 20.0, 0.1, "suffix:m") var display_scale: float = 3.0
@export var albedo_color: Color = Color(0.85, 0.82, 0.92)

@export_group("Idle spin")
@export_range(0.0, 90.0, 0.5, "suffix:°/s") var idle_speed_xw_degrees: float = 6.0
@export_range(0.0, 90.0, 0.5, "suffix:°/s") var idle_speed_zw_degrees: float = 4.0

@export_group("Reaction to the player")
## How much harder the centerpiece turns than the player's own rotate_4d drag -
## 3.0 means "three times the player's own slice-rotation speed."
@export_range(0.0, 10.0, 0.1) var reaction_multiplier: float = 3.0
## Same sensitivity constant player.gd applies to raw mouse motion, so
## [member reaction_multiplier] is a comparison against the player's own turn
## rate rather than an arbitrary extra number to tune independently.
const MOUSE_SENSITIVITY := 0.002

var _mesh_instance: MeshInstance4D = null
var _rotation: Projection = Projection.IDENTITY


func _ready() -> void:
	_build()


func _build() -> void:
	for child in get_children():
		child.queue_free()

	var mesh: ArrayTetraMesh4D = load(mesh_path)
	if mesh == null:
		push_warning("CenterpieceProbe4D: could not load %s" % mesh_path)
		return

	_mesh_instance = MeshInstance4D.new()
	_mesh_instance.name = "Polytope"
	_mesh_instance.mesh = mesh
	var material := TetraMaterial4D.new()
	material.albedo_color = albedo_color
	_mesh_instance.material_override = material
	add_child(_mesh_instance)

	_rotation = Projection.IDENTITY
	_apply_transform()


func _apply_transform() -> void:
	_mesh_instance.basis = Projection(
		_rotation.x * display_scale,
		_rotation.y * display_scale,
		_rotation.z * display_scale,
		_rotation.w * display_scale
	)


func _process(delta: float) -> void:
	if _mesh_instance == null:
		return
	var idle_xw := deg_to_rad(idle_speed_xw_degrees) * delta
	var idle_zw := deg_to_rad(idle_speed_zw_degrees) * delta
	var spin := Basis4D.from_xw(idle_xw) * Basis4D.from_zw(idle_zw)
	_rotation = Basis4D.orthonormalized(_rotation * spin)
	_apply_transform()


func _input(event: InputEvent) -> void:
	if _mesh_instance == null or not (event is InputEventMouseMotion):
		return
	if not Input.is_action_pressed(&"rotate_4d"):
		return
	var rel: Vector2 = (event as InputEventMouseMotion).relative * MOUSE_SENSITIVITY * reaction_multiplier
	var extra := Basis4D.from_xw(-rel.x) * Basis4D.from_zw(rel.y)
	_rotation = Basis4D.orthonormalized(_rotation * extra)
	_apply_transform()
