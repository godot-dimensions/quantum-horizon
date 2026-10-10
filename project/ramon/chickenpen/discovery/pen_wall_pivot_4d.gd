@tool
extends Node4D

## THE WALL'S PIVOT (10 Oct 2026, Ramon's walkthrough item 16; follow_up/pen_feedback_10oct.md): "End the approaching
## path at a visible pivot ball just before the wall ... When the player reaches the pivot, trigger a short animated
## explanation ... a brief bird's-eye or elevated camera perspective: Start with the camera looking toward the player
## and wall. Move the camera around toward the opposite side of the wall while keeping the player in view. Show that
## the wall blocks the obvious 3D route. Return control to the player. Display the animated mouse tutorial ...
## Find a way past the wall through W."
##
## THE ROAD now ends here, in the farm's slice, a couple of metres short of the wall (PenLayout/paths/pen_b.tres: node
## 26 at this spot, from junction 8); it used to dive 13 m through W toward the gate over a few metres, and in a turned
## slice that line looked as if it ran on under the wall. The gate's own short crossing (nodes 19 and 20, at the gate's
## W) is still there, for whoever finds it. This node is the ball: an orange glow floating over a ring on the ground,
## the same in both looks.
##
## THE MOMENT, once a session, when you step up to it: your controls held, the talk camera (World/TalkCam) rises behind
## you looking at the wall, swings up and over it to the far side and looks back at you (3.6 s), then your own camera
## again and the W guide's card: turn the slice forward (the gate is ahead of you along W), or step through W.
##
## THE WALL IS SOLID NOW. Andrew's wall (World/TownWall, a FenceGenerator4D from wall_with_gate.obj) had no collider, so
## you could walk straight through it, which says nothing about W. The engine's physics is boxes only and the wall bends
## through W, so this keeps you out of it itself: the wall's own sheet (the OBJ's 4x4 grid: across X and W, bent in Z,
## its centre square open, the gate) is checked every physics frame, and a step that would put you inside its slab is
## taken back. The gate stays open; the wall's ends and its edge in W are where they are.
##
## NO class_name (engine_gotchas.md).

const Mats := preload("res://ramon/CreationLab/LabKit/lab_materials.gd")
const Loft := preload("res://ramon/chickenpen/scripts/loft_builder_4d.gd")

@export var player_path: NodePath = ^"../../Player"
@export var wall_path: NodePath = ^"../TownWall"
@export var talk_cam_path: NodePath = ^"../TalkCam"
@export var main_cam_path: NodePath = ^"../../Player/CameraRig/Pitch/Camera4D"
@export var guide_path: NodePath = ^"../../Systems/WGuide"
@export var colour: Color = Color(1.0, 0.55, 0.20)
@export_range(0.5, 5.0, 0.1, "suffix:m") var reach: float = 1.8
@export_range(1.0, 10.0, 0.1, "suffix:s") var orbit_seconds: float = 3.6
## Keep the wall solid (see above).
@export var solid_wall: bool = true

## The wall's sheet in its own frame: X across, W across, the bend in Z (wall_with_gate.obj: x, y, z -> X, Z, W).
const XS := [-10.0, -0.333333, 0.333333, 10.0]
const WS := [10.0, 0.333333, -0.333333, -10.0]
const ZS := [[0.0, -0.5, -0.5, 0.0], [0.5, 0.0, 0.0, 0.5], [0.5, 0.0, 0.0, 0.5], [0.0, -0.5, -0.5, 0.0]]
## Half the slab's thickness plus your body, and its height, in the wall's frame (it is scaled six times).
const HALF_SLAB := 0.09
const TOP := 0.76

## Once a session (a new launch, or Ctrl+R).
static var shown: bool = false

var _player: CharacterBody4D
var _wall: Node4D
var _ball: Node4D
var _t: float = 0.0
var _orbit: float = -1.0
var _last_ok := Vector4.ZERO
var _have_ok: bool = false


func _ready() -> void:
	_build()
	if Engine.is_editor_hint():
		return
	add_to_group(&"discovery_reset")
	_player = get_node_or_null(player_path) as CharacterBody4D
	_wall = get_node_or_null(wall_path) as Node4D


func _build() -> void:
	for child in get_children():
		if child.has_meta(&"_pivot_part"):
			remove_child(child)
			child.free()
	_ball = Node4D.new()
	_ball.name = "Ball"
	_ball.set_meta(&"_pivot_part", true)
	add_child(_ball)
	_ball.position = Vector4(0.0, 1.0, 0.0, 0.0)
	var secs: Array = []
	for i in range(1, 8):
		var th: float = PI * float(i) / 8.0
		secs.append({"center": Vector4(0.0, -cos(th) * 0.32, 0.0, 0.0), "radius": sin(th) * 0.32, "v_scale": 1.0, "w_scale": 1.0})
	var mi := MeshInstance4D.new()
	mi.name = "Glow"
	mi.mesh = Loft.build(secs, 4, 10, true, false, false, 1, false)
	mi.material_override = Mats.glow(colour, 1.0)
	mi.set_meta(&"_look_own", true)
	mi.set("allow_projection", false)
	_ball.add_child(mi)
	# A ring on the ground under it: eight short bars round a circle.
	var ring := MeshInstance4D.new()
	ring.name = "Ring"
	ring.set_meta(&"_pivot_part", true)
	ring.set_meta(&"_look_own", true)
	var m := ArrayTetraMesh4D.new()
	for k in 8:
		var a: float = TAU * float(k) / 8.0
		var bar := BoxTetraMesh4D.new()
		bar.size = Vector4(0.42, 0.04, 0.08, 0.5)
		m.merge_with(bar.to_array_tetra_mesh(), Vector4(cos(a) * 0.62, 0.02, sin(a) * 0.62, 0.0), Basis4D.from_zx(-a + PI * 0.5))
	ring.mesh = m
	ring.material_override = Mats.glow(colour.darkened(0.15), 1.0)
	ring.set("allow_projection", false)
	add_child(ring)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_t += delta
	if _ball != null:
		_ball.position.y = 1.0 + sin(_t * 1.6) * 0.08
		_ball.basis = Basis4D.from_zx(_t * 0.8)
	if _player == null:
		return
	if _orbit >= 0.0:
		_run_orbit(delta)
		return
	if shown or _player.get("input_enabled") == false:
		return
	var gap: Vector4 = global_position - _player.global_position
	if Vector2(gap.x, gap.z).length() <= reach and absf(gap.w) < 1.0:
		_start_orbit()


func _start_orbit() -> void:
	shown = true
	_orbit = 0.0
	_player.set("input_enabled", false)
	_player.set("velocity", Vector4.ZERO)
	var cam := get_node_or_null(talk_cam_path) as Node4D
	if cam != null:
		cam.set("current", true)


## The camera round the wall: from behind you, up and over, to the far side looking back at you.
func _run_orbit(delta: float) -> void:
	_orbit += delta / orbit_seconds
	var cam := get_node_or_null(talk_cam_path) as Node4D
	var e: float = clampf(_orbit, 0.0, 1.0)
	e = e * e * (3.0 - 2.0 * e)
	if cam != null and _wall != null:
		var me: Vector4 = _player.global_position
		var wall_at: Vector4 = _wall_point_near(me)
		var away: Vector2 = Vector2(me.x - wall_at.x, me.z - wall_at.z)
		if away.length() < 0.1:
			away = Vector2(0.0, 1.0)
		away = away.normalized()
		# Round the vertical through the wall point, from your side (angle 0) to the far side (PI), a little to one side.
		var ang: float = lerpf(0.0, PI, e)
		var side := Vector2(-away.y, away.x)
		var flat: Vector2 = (away * cos(ang) + side * sin(ang) * 0.55) * 9.0
		var height: float = 4.0 + 5.0 * sin(PI * e)
		var from := Vector4(wall_at.x + flat.x, wall_at.y + height, wall_at.z + flat.y, me.w)
		var look_at_pt: Vector4 = me.lerp(wall_at, 0.35) + Vector4(0.0, 1.0, 0.0, 0.0)
		cam.global_position = from
		cam.global_basis = _look_basis(look_at_pt - from)
	if _orbit >= 1.15:
		_orbit = -1.0
		var main := get_node_or_null(main_cam_path) as Node4D
		if main != null:
			main.set("current", true)
		_player.set("input_enabled", true)
		var guide: Node = get_node_or_null(guide_path)
		if guide != null and guide.has_method("teach"):
			guide.call("teach", [["drag_v", "TURN THE SLICE FORWARD"], ["keys", "OR STEP THROUGH W"]], "Find a way past the wall through W.", 7.0)


## The point on the wall's sheet nearest the farm's slice in front of [param p] (its middle height).
func _wall_point_near(p: Vector4) -> Vector4:
	var local: Vector4 = (p - _wall.global_position) / 6.0
	var z: float = _sheet_z(local.x, local.w)
	return _wall.global_position + Vector4(local.x, 0.38, z, local.w) * 6.0


static func _look_basis(gap: Vector4) -> Projection:
	var forward: Vector3 = Vector3(gap.x, gap.y, gap.z).normalized()
	var zc: Vector3 = -forward
	var xc: Vector3 = Vector3(0.0, 1.0, 0.0).cross(zc)
	if xc.length_squared() < 0.000001:
		xc = Vector3(1.0, 0.0, 0.0)
	xc = xc.normalized()
	var yc: Vector3 = zc.cross(xc)
	return Projection(Vector4(xc.x, xc.y, xc.z, 0.0), Vector4(yc.x, yc.y, yc.z, 0.0), Vector4(zc.x, zc.y, zc.z, 0.0), Vector4(0.0, 0.0, 0.0, 1.0))


# --- The wall, solid -----------------------------------------------------------------------------

## The sheet's Z at (x, w) in the wall's frame, by the OBJ's grid (bilinear in its cell).
static func _sheet_z(x: float, w: float) -> float:
	var ix: int = 0
	for i in 3:
		if x >= float(XS[i]):
			ix = i
	var iw: int = 0
	for i in 3:
		if w <= float(WS[i]):
			iw = i
	var x0: float = XS[ix]
	var x1: float = XS[ix + 1]
	var w0: float = WS[iw]
	var w1: float = WS[iw + 1]
	var fx: float = clampf((x - x0) / (x1 - x0), 0.0, 1.0)
	var fw: float = clampf((w - w0) / (w1 - w0), 0.0, 1.0)
	var a: float = lerpf(float(ZS[iw][ix]), float(ZS[iw][ix + 1]), fx)
	var b: float = lerpf(float(ZS[iw + 1][ix]), float(ZS[iw + 1][ix + 1]), fx)
	return lerpf(a, b, fw)


## Whether a body standing at [param p] (global) is inside the wall's slab.
func in_wall(p: Vector4) -> bool:
	if _wall == null:
		return false
	var l: Vector4 = (p - _wall.global_position) / 6.0
	if absf(l.x) > 10.0 or absf(l.w) > 10.0:
		return false
	# The gate: the open centre square.
	if absf(l.x) < 0.333333 and absf(l.w) < 0.333333:
		return false
	if l.y < -0.05 or l.y > TOP:
		return false
	return absf(l.z - _sheet_z(l.x, l.w)) < HALF_SLAB


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint() or not solid_wall or _player == null or _wall == null:
		return
	var p: Vector4 = _player.global_position
	if in_wall(p):
		if _have_ok:
			_player.global_position = _last_ok
			_player.set("velocity", Vector4.ZERO)
		return
	_last_ok = p
	_have_ok = true


## Ctrl+R (through the W guide): the moment again for the next visitor.
func reset() -> void:
	shown = false
