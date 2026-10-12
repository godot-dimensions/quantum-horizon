extends Node4D
## Crosswise: what the little walker does with his hands. E lifts a crate and puts it down; the
## left mouse button swings a small hammer at a rock (PLAN.md steps 26-27, 38-41, 45-46).
##
## ONLY IN THE SLICE YOU SEE. A crate or a rock counts as in reach only if it shares your slice
## (within a hand's width along the axis you cannot see), so you never lift what is not on screen.
##
## LIFTING: the walker stoops (the gait's pickup), the crate rises from where it stood to over his
## head over a third of a second, and his arms go up and his knees take the load (the gait's carry
## pose, load 0.6). It rides there, turned with the view, until it is put down.
##
## PUTTING DOWN: the spot is a pace ahead of where he faces, snapped to a 0.25 m grid along the two
## floor axes you can see (never along the hidden one, which stays his, so the crate lands in your
## slice), dropped onto whatever floor is under it. A ghost outline shows the spot while you carry:
## green where it can go, red where it cannot (no floor, or it would overlap a wall, a rock, another
## crate or him). Pressing E on red shakes his head instead.
##
## THE HAMMER: it appears in his right hand for the swing only (the pen pickaxe's arc, copied:
## chickenpen/scripts/pen_pickaxe_4d.gd), and the blow lands at the bottom of the arc. Swinging at
## nothing is still a swing; only a rock in reach counts it.
##
## Runs after the gait (process_priority), because the gait writes the arms every frame and a swing
## has to overwrite them.
##
## NO class_name (engine_gotchas.md).

signal lifted(crate: Node)
signal placed(crate: Node)
signal refused(reason: String)
signal swung(hit: bool)

const Build := preload("res://ramon/Crosswise/world/mk_build.gd")
const Mats := preload("res://ramon/Crosswise/world/mk_materials.gd")

const REACH := 1.35
const SLICE_TOLERANCE := 0.45
const PLACE_AHEAD := 0.95
const GRID := 0.25
const LIFT_SECONDS := 0.32
const SWING_SECONDS := 0.5
const HIT_AT := 0.62
const CARRY_HEIGHT := 1.30
const GHOST_OK := Color(0.35, 0.95, 0.55)
const GHOST_NO := Color(1.0, 0.35, 0.30)

## The game node (crosswise_4d.gd), asked for the solids; optional.
var game: Node
var carried: Node4D = null
var input_enabled: bool = true

var _walker: CharacterBody4D
var _avatar: Node4D
var _gait: Node
var _camera: Node
var _lift_t: float = -1.0
var _lift_from: Vector4
var _swing_t: float = -1.0
var _swing_hit: bool = false
var _swing_target: Node = null
var _hammer: Node4D
var _ghost: Node4D
var _ghost_marks: Array = []
var _ghost_ok: bool = false
var _ghost_spot: Vector4 = Vector4.ZERO
var _shake_t: float = -1.0


func _ready() -> void:
	process_priority = 20
	process_physics_priority = 20
	_walker = get_parent() as CharacterBody4D
	_avatar = _walker.get_node_or_null("Avatar") as Node4D
	_gait = _walker.get_node_or_null("Gait")
	_ghost = Node4D.new()
	_ghost.name = "Ghost"
	add_child(_ghost)
	var s: float = 0.72
	var t := 0.045
	for spec in [[Vector4(0, 0, -s * 0.5, 0), Vector4(s + t, 0.025, t, s)], [Vector4(0, 0, s * 0.5, 0), Vector4(s + t, 0.025, t, s)],
			[Vector4(-s * 0.5, 0, 0, 0), Vector4(t, 0.025, s + t, s)], [Vector4(s * 0.5, 0, 0, 0), Vector4(t, 0.025, s + t, s)]]:
		var m := MeshInstance4D.new()
		m.mesh = Mats.box_mesh(spec[1])
		m.material_override = Mats.glow(GHOST_OK, 1.0, 0.0, true)
		m.position = spec[0]
		_ghost.add_child(m)
		_ghost_marks.append(m)
	_ghost.visible = false


func _cam() -> Node:
	if _camera == null:
		var path: NodePath = _walker.get("camera_path")
		if not path.is_empty():
			_camera = _walker.get_node_or_null(path)
	return _camera


func _view() -> Projection:
	var c := _cam()
	return c.call("slice_rotation") if c != null else Projection.IDENTITY


func _normal() -> Vector4:
	var c := _cam()
	return (c.call("slice_normal") as Vector4) if c != null else Vector4(0, 0, 0, 1)


func _turning() -> bool:
	var c := _cam()
	return c != null and bool(c.call("is_turning"))


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled or not _walker.get("input_enabled"):
		return
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_E:
		use()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"fire"):
		strike()
		get_viewport().set_input_as_handled()


## E: lift the crate in reach, or put the carried one down.
func use() -> void:
	if _turning() or _lift_t >= 0.0 or _swing_t >= 0.0:
		return
	if carried != null:
		_try_place()
	else:
		var crate: Node4D = crate_in_reach()
		if crate != null:
			_lift(crate)
		else:
			_refuse("nothing to lift")


## The crate he would lift now, or null.
func crate_in_reach() -> Node4D:
	if game == null or not game.has_method("crates"):
		return null
	var best: Node4D = null
	var best_d: float = INF
	var n: Vector4 = _normal()
	var me: Vector4 = _walker.global_position
	var face: Vector4 = _walker.call("facing_direction")
	for c in game.call("crates"):
		var crate := c as Node4D
		if crate == null or crate.call("is_carried"):
			continue
		var d: Vector4 = crate.global_position - me
		if absf(d.dot(n)) > SLICE_TOLERANCE or absf(d.y) > 0.9:
			continue
		var flat: Vector4 = d - n * d.dot(n)
		flat.y = 0.0
		var dist: float = flat.length()
		if dist > REACH:
			continue
		# Prefer what he faces.
		var score: float = dist - 0.4 * flat.normalized().dot(face)
		if score < best_d:
			best_d = score
			best = crate
	return best


## The rock he would hit now, or null.
func plug_in_reach() -> Node:
	if game == null or not game.has_method("plugs"):
		return null
	var n: Vector4 = _normal()
	var chest: Vector4 = _walker.global_position + Vector4(0, 0.8, 0, 0)
	var face: Vector4 = _walker.call("facing_direction")
	var best: Node = null
	var best_d: float = INF
	for p in game.call("plugs"):
		if p.call("is_broken"):
			continue
		var b: Array = p.call("bounds")
		var centre: Vector4 = b[0]
		var size: Vector4 = b[1]
		var d: Vector4 = centre - chest
		# In the slice: the rock spans your slice along the hidden axis.
		var hidden: float = absf(d.dot(n))
		var hidden_half: float = absf(Vector4(size.x * n.x, size.y * n.y, size.z * n.z, size.w * n.w).length()) * 0.5
		if hidden > hidden_half + 0.2:
			continue
		# Distance from his chest to the rock's box, within the slice.
		var gap: Vector4 = (d.abs() - size * 0.5).max(Vector4.ZERO)
		gap = gap - n.abs() * gap.dot(n.abs())
		var dist: float = gap.length()
		if dist > 0.9:
			continue
		var toward: Vector4 = d - n * d.dot(n)
		toward.y = 0.0
		if toward.length() > 0.01 and toward.normalized().dot(face) < 0.2:
			continue
		if dist < best_d:
			best_d = dist
			best = p
	return best


## LMB: swing the hammer.
func strike() -> void:
	if carried != null:
		_refuse("hands full")
		return
	if _turning() or _swing_t >= 0.0 or _lift_t >= 0.0:
		return
	_swing_target = plug_in_reach()
	_swing_t = 0.0
	_swing_hit = false
	_show_hammer(true)


func _lift(crate: Node4D) -> void:
	carried = crate
	crate.call("pick_up", _walker)
	_lift_from = crate.global_position
	_lift_t = 0.0
	if _gait != null:
		_gait.call("set_carrying", true, 0.6)
	lifted.emit(crate)


## Where a carried crate rides (its foot), in the world.
func carry_point() -> Vector4:
	var bob: float = _avatar.position.y if _avatar != null else 0.0
	return _walker.global_position + _view() * Vector4(0, CARRY_HEIGHT + bob, 0.04, 0)


## The spot ahead where the crate would go: [ok, foot position].
func place_spot() -> Array:
	var view: Projection = _view()
	var n: Vector4 = _normal()
	var face: Vector4 = _walker.call("facing_direction")
	var ahead: Vector4 = _walker.global_position + face * PLACE_AHEAD
	# Snap along the two floor axes you see (X and the view's depth), never the hidden one.
	var depth_axis: Vector4 = view * Vector4(0, 0, 1, 0)
	var x: float = snappedf(ahead.x, GRID)
	var along: float = snappedf(ahead.dot(depth_axis), GRID)
	var spot: Vector4 = ahead
	spot.x = x
	spot += depth_axis * (along - ahead.dot(depth_axis))
	# The hidden coordinate is exactly his.
	spot += n * (_walker.global_position - spot).dot(n)
	# Down onto whatever is under it.
	var params := RaycastParameters4D.new()
	params.global_ray_origin = Vector4(spot.x, _walker.global_position.y + 2.2, spot.z, spot.w)
	params.global_ray_direction = Vector4(0, -1, 0, 0)
	params.max_distance = 4.5
	var exclude: Array = [_walker]
	if carried != null:
		exclude.append(carried)
	params.set_exclude_nodes(exclude)
	var hit: Dictionary = PhysicsServer4D.raycast_physics_objects(params)
	if hit.is_empty() or not hit.has("global_point"):
		return [false, spot]
	var top: float = (hit["global_point"] as Vector4).y
	spot.y = top + 0.005
	if top < _walker.global_position.y - 1.6 or top > _walker.global_position.y + 1.0:
		return [false, spot]
	var size := Vector4(0.7, 0.7, 0.7, 0.7)
	var centre: Vector4 = spot + Vector4(0, 0.35, 0, 0)
	# Not into him.
	var me_size := Vector4(0.5, 1.3, 0.5, 0.5)
	if Build.overlaps(centre, size, _walker.global_position + Vector4(0, 0.65, 0, 0), me_size, 0.02):
		return [false, spot]
	if game != null and game.has_method("blocked") and bool(game.call("blocked", centre, size, carried)):
		return [false, spot]
	return [true, spot]


func _try_place() -> void:
	var r: Array = place_spot()
	if not bool(r[0]):
		_refuse("can't put it there")
		return
	var crate: Node4D = carried
	carried = null
	crate.call("put_down", r[1])
	if _gait != null:
		_gait.call("set_carrying", false)
	_ghost.visible = false
	placed.emit(crate)


## Let go of the crate wherever it is (a fall, a reset): it goes home by itself if it must.
func drop_carried() -> void:
	if carried == null:
		return
	var crate: Node4D = carried
	carried = null
	_lift_t = -1.0
	if _gait != null:
		_gait.call("set_carrying", false)
	crate.call("reset_home")
	_ghost.visible = false


func _refuse(reason: String) -> void:
	_shake_t = 0.0
	refused.emit(reason)


func _physics_process(delta: float) -> void:
	if carried != null:
		var view: Projection = _view()
		var target: Vector4 = carry_point()
		if _lift_t >= 0.0:
			_lift_t += delta
			var k: float = clampf(_lift_t / LIFT_SECONDS, 0.0, 1.0)
			var e: float = k * k * (3.0 - 2.0 * k)
			carried.set("carry_point", _lift_from.lerp(target, e) + Vector4(0, sin(k * PI) * 0.25, 0, 0))
			if k >= 1.0:
				_lift_t = -1.0
		else:
			carried.set("carry_point", target)
		carried.set("carry_rotation", view)
		_update_ghost(view)
	else:
		_ghost.visible = false


func _update_ghost(view: Projection) -> void:
	if _lift_t >= 0.0 or _turning():
		_ghost.visible = false
		return
	var r: Array = place_spot()
	_ghost_ok = bool(r[0])
	_ghost_spot = r[1]
	_ghost.visible = true
	_ghost.global_position = _ghost_spot + Vector4(0, 0.02, 0, 0)
	_ghost.global_basis = view
	for m in _ghost_marks:
		((m as MeshInstance4D).material_override as TetraMaterial4D).get_cross_section_material_3d() \
			.set_shader_parameter("glow_color", GHOST_OK if _ghost_ok else GHOST_NO)


func _process(delta: float) -> void:
	if _swing_t >= 0.0:
		_swing_t += delta
		var t: float = clampf(_swing_t / SWING_SECONDS, 0.0, 1.0)
		_pose_swing(t)
		if not _swing_hit and t >= HIT_AT:
			_swing_hit = true
			var hit: bool = _swing_target != null and not bool(_swing_target.call("is_broken"))
			if hit:
				_swing_target.call("strike", _walker.global_position + Vector4(0, 0.8, 0, 0), _view())
			swung.emit(hit)
		if t >= 1.0:
			_swing_t = -1.0
			_show_hammer(false)
	if _shake_t >= 0.0:
		_shake_t += delta
		var head: Node4D = _avatar.get("head") as Node4D if _avatar != null else null
		if head != null:
			head.basis = Basis4D.from_zx(sin(_shake_t * 28.0) * 0.35 * maxf(0.0, 1.0 - _shake_t / 0.5))
		if _shake_t > 0.5:
			_shake_t = -1.0
			if head != null:
				head.basis = Projection.IDENTITY


## The arc at the shoulder (pen_pickaxe_4d.gd's, measured there): up and forward for the first
## third, then over and down fast so the contact reads as a hit.
func _pose_swing(t: float) -> void:
	if _avatar == null:
		return
	var shoulder: Node4D = _avatar.get("shoulder_right") as Node4D
	var elbow: Node4D = _avatar.get("elbow_right") as Node4D
	if shoulder == null:
		return
	var lift: float = -2.7
	var down: float = -0.9
	var angle: float
	if t < 0.35:
		angle = lerpf(0.0, lift, ease(t / 0.35, 0.4))
	else:
		angle = lerpf(lift, down, ease((t - 0.35) / 0.65, 2.6))
	shoulder.basis = Basis4D.from_yz(angle)
	if elbow != null:
		elbow.basis = Basis4D.from_yz(lerpf(-0.6, 0.0, clampf(t * 1.6, 0.0, 1.0)))


## A small mallet in the right fist: a haft and a stone head, built once, shown for the swing.
func _show_hammer(on: bool) -> void:
	if _avatar == null:
		return
	var hand: Node4D = _avatar.get("elbow_right") as Node4D
	if hand == null:
		return
	if _hammer == null or not is_instance_valid(_hammer) or _hammer.get_parent() != hand:
		_hammer = Node4D.new()
		_hammer.name = "Hammer"
		hand.add_child(_hammer)
		_hammer.position = Vector4(0, -0.22, 0, 0)
		var lean: float = deg_to_rad(90.0)
		_hammer.basis = Projection(Vector4(0, -sin(lean), cos(lean), 0), Vector4(0, cos(lean), sin(lean), 0), Vector4(-1, 0, 0, 0), Vector4(0, 0, 0, 1))
		for spec in [["Haft", Vector4(0, 0.10, 0, 0), Vector4(0.03, 0.34, 0.03, 0.3), Color(0.55, 0.36, 0.2)],
				["Head", Vector4(0, 0.29, 0, 0), Vector4(0.2, 0.11, 0.11, 0.3), Color(0.62, 0.64, 0.70)]]:
			var m := MeshInstance4D.new()
			m.name = spec[0]
			m.mesh = Mats.box_mesh(spec[2])
			m.material_override = Mats.flat(spec[3])
			m.position = spec[1]
			_hammer.add_child(m)
	_hammer.visible = on


## What the HUD should offer right now: {"key", "text", "at"} or {}.
func prompt() -> Dictionary:
	if carried != null:
		return {"key": "E", "text": "put down" if _ghost_ok else "no room here", "at": _ghost_spot + Vector4(0, 0.4, 0, 0), "ok": _ghost_ok}
	var crate: Node4D = crate_in_reach()
	if crate != null:
		return {"key": "E", "text": "lift", "at": crate.global_position + Vector4(0, 1.0, 0, 0), "ok": true}
	var plug: Node = plug_in_reach()
	if plug != null:
		var b: Array = plug.call("bounds")
		var left: int = int(plug.get("hits_needed")) - int(plug.get("hits"))
		return {"key": "CLICK", "text": "strike  (%d more)" % left, "at": (b[0] as Vector4) + Vector4(0, (b[1] as Vector4).y * 0.5 + 0.4, 0, 0), "ok": true}
	return {}
