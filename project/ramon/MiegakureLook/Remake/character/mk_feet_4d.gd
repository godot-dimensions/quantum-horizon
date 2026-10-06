extends Node4D
## Crosswise: what lies on the floor at the walker's feet (PLAN.md steps 25 and 29).
##
##   THE SHADOW  a soft dark disc under him on whatever floor is below (the 4D renderer casts no
##               shadows, and without one a figure on a white floor floats; with a jump it says how
##               high he is). Round in the view either way: it is turned with the view.
##   THE ROSE    four short arrows round his feet, one per key: A and D (always X) in pale grey, W and
##               S in the colour of the axis they walk: blue for Z in the normal view, warm amber for
##               W once turned (the lane code's warm is ana). So after a turn you can SEE that W/S now
##               walk through W, with no text. It shows while he walks and for a few seconds after a
##               turn, then shrinks away while he stands (no clutter while you look).
##
## Glow materials (unshaded), so the floor's lighting never changes them; the renderer is opaque, so
## "fading" is shrinking.
##
## NO class_name (engine_gotchas.md).

const Mats := preload("res://ramon/MiegakureLook/Remake/world/mk_materials.gd")

const SHADOW := Color(0.42, 0.44, 0.52)
const X_ARM := Color(0.86, 0.88, 0.92)
const Z_ARM := Color(0.35, 0.55, 1.0)
const W_ARM := Color(1.0, 0.62, 0.22)
const ARM_DISTANCE := 0.62

var _walker: CharacterBody4D
var _shadow: MeshInstance4D
var _rose: Node4D
var _depth_mats: Array = []
var _show: float = 0.0
var _hold: float = 3.0
var _last_turned: bool = false


func _ready() -> void:
	_walker = get_parent() as CharacterBody4D
	_shadow = MeshInstance4D.new()
	_shadow.name = "Shadow"
	var disc := CubinderShape4D.new()
	disc.radius = 0.34
	disc.height = 0.01
	disc.thickness = 0.34
	_shadow.mesh = disc.to_tetra_mesh({"segments": 32})
	_shadow.material_override = Mats.glow(SHADOW)
	add_child(_shadow)
	_rose = Node4D.new()
	_rose.name = "Rose"
	add_child(_rose)
	# Each arm: a bar and a tip, pointing out from his feet along the view's x or depth axis.
	for spec in [[Vector4(1, 0, 0, 0), false], [Vector4(-1, 0, 0, 0), false], [Vector4(0, 0, -1, 0), true], [Vector4(0, 0, 1, 0), true]]:
		var dir: Vector4 = spec[0]
		var depth: bool = spec[1]
		var mat: TetraMaterial4D = Mats.glow(Z_ARM if depth else X_ARM, 1.0, 0.0, true)
		if depth:
			_depth_mats.append(mat)
		var bar := MeshInstance4D.new()
		bar.mesh = Mats.box_mesh(Vector4(0.07, 0.012, 0.26, 0.07) if depth else Vector4(0.26, 0.012, 0.07, 0.07))
		bar.material_override = mat
		bar.position = dir * ARM_DISTANCE
		_rose.add_child(bar)
		var tip := MeshInstance4D.new()
		tip.mesh = Mats.box_mesh(Vector4(0.16, 0.012, 0.07, 0.07) if depth else Vector4(0.07, 0.012, 0.16, 0.07))
		tip.material_override = mat
		tip.position = dir * (ARM_DISTANCE + 0.15)
		_rose.add_child(tip)


func _view() -> Projection:
	return _walker.call("view_rotation") if _walker != null else Projection.IDENTITY


func _physics_process(delta: float) -> void:
	if _walker == null:
		return
	var view: Projection = _view()
	var me: Vector4 = _walker.global_position
	# The floor under him (a ray, so the shadow stays on the ground through a jump).
	var params := RaycastParameters4D.new()
	params.global_ray_origin = me + Vector4(0, 0.4, 0, 0)
	params.global_ray_direction = Vector4(0, -1, 0, 0)
	params.max_distance = 6.0
	var exclude: Array = [_walker]
	params.set_exclude_nodes(exclude)
	var hit: Dictionary = PhysicsServer4D.raycast_physics_objects(params)
	var floor_y: float = me.y
	var has_floor: bool = not hit.is_empty() and hit.has("global_point")
	if has_floor:
		floor_y = (hit["global_point"] as Vector4).y
	global_position = Vector4(me.x, floor_y + 0.012, me.z, me.w)
	global_basis = view
	var height: float = maxf(me.y - floor_y, 0.0)
	var s: float = clampf(1.0 - height * 0.35, 0.35, 1.0)
	_shadow.visible = has_floor
	_shadow.basis = Projection(Vector4(s, 0, 0, 0), Vector4(0, 1, 0, 0), Vector4(0, 0, s, 0), Vector4(0, 0, 0, s))
	# The rose: shown while he walks and for a while after a turn.
	var cam = _walker.get_node_or_null(_walker.get("camera_path")) if not (_walker.get("camera_path") as NodePath).is_empty() else null
	var turned: bool = cam != null and bool(cam.call("is_turned"))
	var amount: float = float(cam.call("turn_amount")) if cam != null else 0.0
	if turned != _last_turned:
		_last_turned = turned
		_hold = 3.5
	var moving: bool = float(_walker.call("horizontal_speed")) > 0.2
	if moving:
		_hold = maxf(_hold, 1.2)
	_hold = maxf(_hold - delta, 0.0)
	var want: float = 1.0 if (_hold > 0.0 or moving) else 0.0
	_show = move_toward(_show, want, delta * (4.0 if want > _show else 1.5))
	_rose.visible = _show > 0.02 and has_floor and height < 0.6
	var k: float = _show * _show * (3.0 - 2.0 * _show)
	_rose.basis = Projection(Vector4(k, 0, 0, 0), Vector4(0, 1, 0, 0), Vector4(0, 0, k, 0), Vector4(0, 0, 0, 1))
	var col: Color = Z_ARM.lerp(W_ARM, amount)
	for m in _depth_mats:
		(m as TetraMaterial4D).get_cross_section_material_3d().set_shader_parameter("glow_color", col)
