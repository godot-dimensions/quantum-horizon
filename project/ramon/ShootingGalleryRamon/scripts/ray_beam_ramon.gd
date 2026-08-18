extends Node4D
## Ramon-only: a brief visible beam along a hitscan shot's path, so it reads
## as a laser actually traveling to what it hits rather than an invisible
## instant check.
##
## This used to be a straight 2-vertex ArrayWireMesh4D, which turned out to
## be invisible in practice: a hitscan ray fired straight along the
## camera's own forward axis has, by definition, zero w-extent in camera-
## relative space (that's what "currently in the visible slice" means) -
## so the wire segment is coplanar with the cross-section slicing plane at
## every point along it. The slicing shader's mix_weight = v1.w / (v1.w -
## v2.w) degenerates to 0/0 there, the same kind of exactly-on-the-boundary
## case already diagnosed for GreenFloor's tiles earlier in this project -
## except here there's no tilt to add that fixes it, because the ray is
## defined relative to the camera's own axes at cast time, so it's always
## exactly on the plane no matter how the world is oriented.
##
## Fix: use a real 4D box (volume, not a 1D wire) so slicing it at w=0
## produces genuine cross-section geometry instead of a degenerate divide.
## Orientation comes directly from the same player_head.global_basis used
## to compute the ray direction in the first place - its z column already
## points the right way and is already orthonormal, so there's no need to
## derive a fresh 4D basis from scratch (which would otherwise need a
## Gram-Schmidt-style construction, since one direction vector alone
## doesn't pin down the other 3 orthogonal axes in 4D).

const MIN_LIFETIME_SEC := 0.12
const MAX_LIFETIME_SEC := 0.4
const MIN_THICKNESS := 0.035 # Meters now (a real box), not pixels (the old wire's line_thickness unit).
const MAX_THICKNESS := 0.16
const BASE_COLOR := Color(1.0, 0.35, 0.25, 1.0)
const INTENSE_COLOR := Color(1.0, 0.9, 0.5, 1.0)

var _material: TetraMaterial4D
var _age_sec: float = 0.0
var _lifetime_sec: float = MIN_LIFETIME_SEC


func setup(from: Vector4, to: Vector4, orientation: Projection, intensity: float = 0.0) -> void:
	intensity = clampf(intensity, 0.0, 1.0)
	_lifetime_sec = lerpf(MIN_LIFETIME_SEC, MAX_LIFETIME_SEC, intensity)

	var length: float = from.distance_to(to)
	var thickness: float = lerpf(MIN_THICKNESS, MAX_THICKNESS, intensity)
	var box_mesh := BoxTetraMesh4D.new()
	# z is the orientation basis's forward-aligned column - see class comment.
	box_mesh.size = Vector4(thickness, thickness, length, thickness)

	_material = TetraMaterial4D.new()
	_material.albedo_color = BASE_COLOR.lerp(INTENSE_COLOR, intensity)
	FlatShadingRamon.apply(_material)

	var mesh_instance := MeshInstance4D.new()
	mesh_instance.mesh = box_mesh
	mesh_instance.material_override = _material
	add_child(mesh_instance)

	global_position = (from + to) * 0.5
	global_basis = orientation


func _process(delta: float) -> void:
	_age_sec += delta
	if _material != null:
		_material.albedo_color.a = lerpf(1.0, 0.0, _age_sec / _lifetime_sec)
	if _age_sec >= _lifetime_sec:
		queue_free()
