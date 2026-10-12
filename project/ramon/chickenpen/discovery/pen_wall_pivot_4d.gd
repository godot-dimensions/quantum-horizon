@tool
extends Node4D

## THE WALL'S MOMENT (10 Oct 2026, Ramon's walkthrough items 16, 38 and 39; follow_up/pen_feedback_10oct.md).
##
## Item 16 asked for the road to end before the wall and a short camera move showing why plain walking will not get you
## past it, then the W card. Items 38 and 39 (later the same day): "Zoom the camera farther out. Use a more cinematic
## elevated or bird's-eye perspective ... After the wide shot, consider briefly cutting to a closer view of the player
## ... 'My path is blocked. I need to find another way through W.' ... The floating orange interaction orb near the wall
## is unnecessary ... the cinematic should trigger automatically when the player approaches the wall for the first time
## ... approximately 5 meters before the wall ... Play it only once ... return control ... Show the appropriate
## contextual W-navigation hint."
##
## SO: nothing to see here any more (the orb is gone; the road still ends here, PenLayout/paths/pen_b.tres node 26).
## The first time you come within [member trigger_m] of the wall in the farm's slice, near the road's end: your controls
## held, the talk camera (World/TalkCam) high behind you, pulling up and over the wall to look back down at you from far
## above the other side (the wall between, plainly in the way); then a cut to your face and the thought; then your own
## camera and the W card (turn the slice forward, or step). Space, Enter, F or a click skip to the end once
## [member skip_after] seconds have shown the wall.
##
## THE WALL IS SOLID. Andrew's wall (World/TownWall, a FenceGenerator4D from wall_with_gate.obj) had no collider, so
## you could walk straight through it, which says nothing about W. The engine's physics is boxes only and the wall bends
## through W, so this keeps you out of it itself: the wall's own sheet (the OBJ's 4x4 grid: across X and W, bent in Z,
## its centre square open, the gate) is checked every physics frame, and a step that would put you inside its slab is
## taken back. The gate stays open; the wall's ends and its edge in W are where they are.
##
## NO class_name (engine_gotchas.md).


@export var player_path: NodePath = ^"../../Player"
@export var wall_path: NodePath = ^"../TownWall"
@export var talk_cam_path: NodePath = ^"../TalkCam"
@export var main_cam_path: NodePath = ^"../../Player/CameraRig/Pitch/Camera4D"
@export var guide_path: NodePath = ^"../../Systems/WGuide"
@export var thought_path: NodePath = ^"../../UI/ThoughtBox"
## How near the wall it starts, and how far either side of this node (along x) it listens.
@export_range(1.0, 15.0, 0.5, "suffix:m") var trigger_m: float = 5.0
@export_range(2.0, 40.0, 0.5, "suffix:m") var listen_x: float = 12.0
## The wide shot's length, the close shot's, and when it may be skipped.
@export_range(1.0, 10.0, 0.1, "suffix:s") var orbit_seconds: float = 4.2
@export_range(1.0, 10.0, 0.1, "suffix:s") var close_seconds: float = 3.4
@export_range(0.0, 5.0, 0.1, "suffix:s") var skip_after: float = 1.2
@export var line: String = "My path is blocked. I need to find another way through W."
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
var _t: float = 0.0
## Seconds into the moment (-1: not playing).
var _orbit: float = -1.0
var _said: bool = false
var _close_from := Vector4.ZERO
var _close_at := Vector4.ZERO
var _last_ok := Vector4.ZERO
var _have_ok: bool = false


func _ready() -> void:
	# What the 9 Oct pivot built (the orb and its ring) is gone; anything of it a scene saved is cleared.
	for child in get_children():
		if child.has_meta(&"_pivot_part") or String(child.name) in ["Ball", "Ring"]:
			remove_child(child)
			child.free()
	if Engine.is_editor_hint():
		return
	add_to_group(&"discovery_reset")
	_player = get_node_or_null(player_path) as CharacterBody4D
	_wall = get_node_or_null(wall_path) as Node4D


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _player == null or _wall == null:
		return
	_t += delta
	if _orbit >= 0.0:
		_run(delta)
		return
	if shown or _player.get("input_enabled") == false:
		return
	var p: Vector4 = _player.global_position
	if absf(p.w) > 1.5 or absf(p.x - global_position.x) > listen_x:
		return
	if _wall_distance(p) <= trigger_m:
		_start()


## How far [param p] is from the wall's sheet, in metres (across it).
func _wall_distance(p: Vector4) -> float:
	var l: Vector4 = (p - _wall.global_position) / 6.0
	if absf(l.x) > 10.0 or absf(l.w) > 10.0:
		return INF
	return absf(l.z - _sheet_z(l.x, l.w)) * 6.0


func _start() -> void:
	shown = true
	_orbit = 0.0
	_said = false
	_player.set("input_enabled", false)
	_player.set("velocity", Vector4.ZERO)
	var cam := get_node_or_null(talk_cam_path) as Node4D
	if cam != null:
		cam.set("current", true)


func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or _orbit < skip_after:
		return
	var go: bool = false
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		go = (event as InputEventKey).keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER] or event.is_action_pressed(&"catch_target")
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		go = true
	if go:
		get_viewport().set_input_as_handled()
		_finish()


## The wide shot (round, up and over the wall, far out), then the close shot with the thought.
func _run(delta: float) -> void:
	_orbit += delta
	var cam := get_node_or_null(talk_cam_path) as Node4D
	if cam == null:
		_finish()
		return
	var me: Vector4 = _player.global_position
	var wall_at: Vector4 = _wall_point_near(me)
	if _orbit < orbit_seconds:
		var e: float = clampf(_orbit / orbit_seconds, 0.0, 1.0)
		e = e * e * (3.0 - 2.0 * e)
		var away := Vector2(me.x - wall_at.x, me.z - wall_at.z)
		if away.length() < 0.1:
			away = Vector2(0.0, 1.0)
		away = away.normalized()
		var side := Vector2(-away.y, away.x)
		# From high behind you (behind and above, the wall ahead) round over the top to far above the other side.
		var ang: float = lerpf(0.15, PI - 0.25, e)
		var flat: Vector2 = (away * cos(ang) + side * sin(ang) * 0.45) * 17.0
		var height: float = 9.0 + 9.0 * sin(PI * e) + 3.0 * e
		var from := Vector4(wall_at.x + flat.x, wall_at.y + height, wall_at.z + flat.y, me.w)
		var look_at_pt: Vector4 = me.lerp(wall_at, 0.5) + Vector4(0.0, 0.6, 0.0, 0.0)
		cam.global_position = from
		cam.global_basis = _look_basis(look_at_pt - from)
		return
	if not _said:
		_said = true
		# The close shot: between you and the wall, a little to the side.
		var to_wall := Vector2(wall_at.x - me.x, wall_at.z - me.z).normalized()
		var side2 := Vector2(-to_wall.y, to_wall.x)
		# Above the grass (it hid you at head height), looking a little down at you.
		var spot: Vector2 = Vector2(me.x, me.z) + to_wall * 2.0 + side2 * 1.1
		_close_from = Vector4(spot.x, me.y + 1.25, spot.y, me.w)
		_close_at = me + Vector4(0.0, 0.35, 0.0, 0.0)
		var box: Node = get_node_or_null(thought_path)
		if box != null and box.has_method("say"):
			box.call("say", String(box.get("player_name")), line)
	cam.global_position = _close_from
	cam.global_basis = _look_basis(_close_at - _close_from)
	if _orbit >= orbit_seconds + close_seconds:
		_finish()


func _finish() -> void:
	if _orbit < 0.0:
		return
	_orbit = -1.0
	var box: Node = get_node_or_null(thought_path)
	if _said and box != null and box.has_method("close"):
		box.call("close")
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
	if _orbit >= 0.0:
		_finish()
