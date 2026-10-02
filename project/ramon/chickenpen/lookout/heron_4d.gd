@tool
extends Node4D

## A grey heron that fishes in the ana marsh, out at w +8: the third secret, and the
## balloon ride's payoff.
##
## BUILT FOR POSES THAT COST NOTHING. A heron is its neck: drawn in to an S at rest, shot out
## to strike, folded back in flight. Lofting the neck as one chain would mean re-lofting it
## every frame it moves (about 11 microseconds a tetrahedron - milliseconds a frame). So the
## neck is three short lofted segments on a chain of pivots, the legs are two bars each on
## a hip and a heel pivot, and the wings are boxes on shoulder pivots; every pose is a few
## rotations. Only the body is one loft, and it never changes.
##
## DRESSED FROM THE FIELD GUIDES (the Heron Specialist Group's and eBird's grey heron): grey
## above, a white head and neck, a broad black brow running back into the black plumes, two
## lines of black streaks down the front of the neck to the breast, black shoulder patches and
## black on the flanks over white thighs, a yellow dagger of a bill; in flight the neck pulled
## in to a bulge, the legs trailing, the flight feathers dark. Round joints at every bend of
## the neck and at the heels, so the segments read as one neck, not a chain of tubes.
##
## THICK IN W, like the owl, so the ring has a fair width to find it in: the balls are
## stretched along W and the bars and boxes are as deep in W as the body is.
##
## WHAT IT DOES (the journal's stars):
##   STAND / ALERT  1  standing in the shallows, neck drawn in; ALERT, neck up straight,
##                     when something whistles
##   ONE_LEG        2  resting on one leg, the other folded up under it
##   STALK, STRIKE  3  wading slowly, neck out and low; then the stab, and now and then a fish
##   TAKE_OFF, FLY  4  put up - by someone walking close, or the camera's first good photo of
##                     it (the payoff) - it lifts off on slow, deep wingbeats with its legs
##                     trailing and flies to the far bank

enum State { STAND, ALERT, ONE_LEG, STALK, STRIKE, TAKE_OFF, FLY, LAND }

const RIG := preload("res://ramon/chickenpen/scripts/loft_rig_4d.gd")
const BALL := preload("res://ramon/chickenpen/scripts/loft_ball_4d.gd")

## Neck poses: [segment 1, 2, 3, head] as forward tilts in radians.
const POSES := {
	"rest": [-0.35, 1.25, -1.1, 0.2],
	"alert": [-0.08, 0.05, 0.0, -0.05],
	"stalk": [0.85, 0.3, 0.15, 0.05],
	"strike": [1.15, 0.25, 0.1, 0.05],
	"fly": [-1.25, 2.2, -1.0, 0.05],
}

@export_range(0.4, 2.5, 0.01, "suffix:m") var size: float = 1.0:
	set(v):
		size = v
		_changed()
@export_range(1.0, 4.0, 0.05) var w_stretch: float = 2.2:
	set(v):
		w_stretch = v
		_changed()
## Blue-grey: a plain grey lit by the pen's sunset reads as beige.
@export var grey: Color = Color(0.38, 0.43, 0.52)
@export var pale: Color = Color(0.86, 0.87, 0.86)
@export var dark: Color = Color(0.13, 0.13, 0.15)
@export var bill: Color = Color(0.86, 0.62, 0.22)
@export var leg: Color = Color(0.62, 0.52, 0.30)

@export_group("Life")
## Only stand and look about: for the creature showcase (Ramon, 2 Oct: "just doing an idle
## animation standing"). No wading, no striking, no flying off.
@export var idle_only: bool = false
## The marsh it lives in (ana_marsh_4d.gd): its fishing spot and its refuge.
@export var marsh_path: NodePath
## Who can put it up by walking close.
@export var player_path: NodePath
@export var lookout_path: NodePath
@export_range(2.0, 30.0, 0.5, "suffix:m") var flush_within: float = 8.0
@export var croak: AudioStream = preload("res://ramon/chickenpen/audio/sfx/lookout_heron.wav")
@export var wingbeats: AudioStream = preload("res://ramon/chickenpen/audio/sfx/lookout_wings.wav")

var state: int = State.STAND

var _neck: Array[Node4D] = []
var _head: Node4D
var _hips: Array[Node4D] = []
var _heels: Array[Node4D] = []
var _folded: Array[Node4D] = []
var _spread: Array[Node4D] = []
var _wing_pivots: Array[Node4D] = []
var _fish: Node4D
var _body: Node4D
var _pose: Array = [-0.35, 1.25, -1.1, 0.2]
var _t: float = 0.0
var _state_t: float = 0.0
var _state_len: float = 8.0
var _rng := RandomNumberGenerator.new()
var _from: Vector4
var _to: Vector4
var _at_refuge: bool = false
var _cool: float = 0.0
var _walk_dir: float = 1.0
var _home: Vector4
var _voice: AudioStreamPlayer
var _wing_voice: AudioStreamPlayer
var _head_yaw: float = 0.0
var _head_yaw_goal: float = 0.0
var _next_look: float = 2.0
## As the owl's: posed only while a camera could see it (it lives at w +8).
var _seen: bool = true
var _seen_check: float = 0.0


func _changed() -> void:
	if is_node_ready():
		rebuild()


func _ready() -> void:
	_rng.seed = 77
	rebuild()
	if Engine.is_editor_hint():
		set_process(false)
		return
	_home = position
	_voice = _player(croak)
	_wing_voice = _player(wingbeats)


func _player(stream: AudioStream) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.bus = &"SFX" if AudioServer.get_bus_index(&"SFX") >= 0 else &"Master"
	add_child(p)
	return p


func rebuild() -> void:
	for child in get_children():
		if not (child is AudioStreamPlayer):
			child.free()
	_neck.clear()
	_hips.clear()
	_heels.clear()
	_folded.clear()
	_spread.clear()
	_wing_pivots.clear()
	var u: float = size
	var ws: float = w_stretch
	var deep: float = 0.26 * u * ws
	_body = Node4D.new()
	_body.name = "Body"
	add_child(_body)
	_own(_body)
	var plumage := _rig(_body, "Plumage", grey)
	_ball(plumage, "Tail", Vector4(0.0, 0.62 * u, -0.31 * u, 0.0), 0.045 * u, ws * 0.7)
	_ball(plumage, "Back", Vector4(0.0, 0.66 * u, -0.16 * u, 0.0), 0.115 * u, ws)
	_ball(plumage, "Breast", Vector4(0.0, 0.665 * u, 0.02 * u, 0.0), 0.12 * u, ws)
	_ball(plumage, "Chest", Vector4(0.0, 0.72 * u, 0.12 * u, 0.0), 0.075 * u, ws)
	plumage.call("build", false)
	# The pale breast plumes hanging below the chest, and the black shoulder patches.
	_box(_body, "Plumes", Vector4(0.0, 0.6 * u, 0.12 * u, 0.0), Vector4(0.08 * u, 0.12 * u, 0.03 * u, deep), pale)
	for side in [-1.0, 1.0]:
		_box(_body, "Shoulder%d" % int(side), Vector4(side * 0.085 * u, 0.73 * u, 0.07 * u, 0.0), Vector4(0.03 * u, 0.05 * u, 0.06 * u, deep), dark)
		_box(_body, "Flank%d" % int(side), Vector4(side * 0.1 * u, 0.6 * u, -0.02 * u, 0.0), Vector4(0.03 * u, 0.07 * u, 0.16 * u, deep), dark)
		_box(_body, "ThighCover%d" % int(side), Vector4(side * 0.055 * u, 0.55 * u, -0.03 * u, 0.0), Vector4(0.05 * u, 0.06 * u, 0.06 * u, deep * 0.7), pale)
	# Wings: folded along the back, or spread wide in flight - two sets, one shown at a time.
	for side in [-1.0, 1.0]:
		var pivot := Node4D.new()
		pivot.name = "Wing%d" % int(side)
		_body.add_child(pivot)
		_own(pivot)
		pivot.position = Vector4(side * 0.09 * u, 0.72 * u, 0.03 * u, 0.0)
		# Folded: mostly inside the body, the long flight feathers showing down the back.
		var fold := _box(pivot, "Folded", Vector4(side * 0.0, 0.0, -0.16 * u, 0.0), Vector4(0.022 * u, 0.09 * u, 0.32 * u, deep), grey.darkened(0.1))
		_box(fold, "Primaries", Vector4(side * 0.002 * u, -0.012 * u, -0.16 * u, 0.0), Vector4(0.024 * u, 0.05 * u, 0.12 * u, deep), dark.lightened(0.2))
		_folded.append(fold)
		var arm := _box(pivot, "Arm", Vector4(side * 0.24 * u, 0.0, -0.03 * u, 0.0), Vector4(0.44 * u, 0.025 * u, 0.28 * u, deep), grey)
		_box(arm, "Hand", Vector4(side * 0.4 * u, 0.0, -0.01 * u, 0.0), Vector4(0.38 * u, 0.022 * u, 0.24 * u, deep), grey.darkened(0.12))
		for f in 4:
			var finger := _box(arm, "Primary%d" % f, Vector4(side * (0.5 + 0.03 * float(f)) * u, 0.0, (0.06 - 0.055 * float(f)) * u, 0.0), Vector4(0.2 * u, 0.02 * u, 0.045 * u, deep), dark)
			finger.basis = Basis4D.from_zx(side * (0.1 + 0.12 * float(f)))
		arm.visible = false
		_spread.append(arm)
		_wing_pivots.append(pivot)
	# Legs: a hip and a heel pivot each - the "knee" that bends backwards is the heel.
	for side in [-1.0, 1.0]:
		var hip := Node4D.new()
		hip.name = "Hip%d" % int(side)
		_body.add_child(hip)
		_own(hip)
		hip.position = Vector4(side * 0.05 * u, 0.56 * u, -0.03 * u, 0.0)
		_box(hip, "Thigh", Vector4(0.0, -0.135 * u, -0.012 * u, 0.0), Vector4(0.026 * u, 0.27 * u, 0.026 * u, deep * 0.6), leg)
		var heel := Node4D.new()
		heel.name = "Heel"
		hip.add_child(heel)
		_own(heel)
		heel.position = Vector4(0.0, -0.27 * u, -0.025 * u, 0.0)
		_sphere(heel, "HeelJoint", Vector4.ZERO, 0.02 * u, leg.darkened(0.1), ws * 0.6)
		_box(heel, "Shank", Vector4(0.0, -0.145 * u, 0.012 * u, 0.0), Vector4(0.022 * u, 0.29 * u, 0.022 * u, deep * 0.6), leg)
		var foot := Node4D.new()
		foot.name = "Foot"
		heel.add_child(foot)
		_own(foot)
		foot.position = Vector4(0.0, -0.29 * u, 0.025 * u, 0.0)
		for k in 3:
			var toe := _box(foot, "Toe%d" % k, Vector4((float(k) - 1.0) * 0.025 * u, 0.0, 0.05 * u, 0.0), Vector4(0.012 * u, 0.01 * u, 0.1 * u, deep * 0.5), leg.darkened(0.15))
			toe.basis = Basis4D.from_zx((float(k) - 1.0) * 0.35)
		_box(foot, "Hind", Vector4(0.0, 0.0, -0.03 * u, 0.0), Vector4(0.01 * u, 0.01 * u, 0.06 * u, deep * 0.5), leg.darkened(0.15))
		_hips.append(hip)
		_heels.append(heel)
	# The neck: three lofted segments on a chain of pivots, then the head.
	var base := Node4D.new()
	base.name = "Neck0"
	_body.add_child(base)
	_own(base)
	base.position = Vector4(0.0, 0.74 * u, 0.15 * u, 0.0)
	var parent: Node4D = base
	var lengths: Array = [0.15, 0.14, 0.12]
	var radii: Array = [[0.048, 0.042], [0.042, 0.037], [0.037, 0.033]]
	for k in 3:
		var seg := _rig(parent, "Segment%d" % k, pale if k > 0 else pale.lerp(grey, 0.5))
		_ball(seg, "A", Vector4.ZERO, float(radii[k][0]) * u, ws * 0.85)
		_ball(seg, "B", Vector4(0.0, float(lengths[k]) * u, 0.0, 0.0), float(radii[k][1]) * u, ws * 0.85)
		seg.call("build", false)
		# A round joint where this segment meets the last, so the neck bends rather than breaks.
		_sphere(parent, "Joint%d" % k, Vector4.ZERO, float(radii[k][0]) * u * 1.04, pale if k > 0 else pale.lerp(grey, 0.5), ws * 0.85)
		# Two lines of black streaks down the front of the neck, to the breast.
		if k < 2:
			for j in 3:
				for side in [-1.0, 1.0]:
					_box(parent, "Streak%d_%d_%d" % [k, j, int(side)], Vector4(side * 0.011 * u, (0.03 + 0.045 * float(j)) * u, float(radii[k][0]) * u * 0.9, 0.0),
						Vector4(0.008 * u, 0.026 * u, 0.008 * u, deep * 0.5), dark)
		_neck.append(parent)
		var next := Node4D.new()
		next.name = "Neck%d" % (k + 1)
		parent.add_child(next)
		_own(next)
		next.position = Vector4(0.0, float(lengths[k]) * u, 0.0, 0.0)
		parent = next
	_head = parent
	_sphere(_head, "HeadJoint", Vector4.ZERO, 0.034 * u, pale, ws * 0.8)
	var head := _rig(_head, "Skull", pale)
	_ball(head, "Back", Vector4(0.0, 0.01 * u, -0.025 * u, 0.0), 0.035 * u, ws * 0.8)
	_ball(head, "Front", Vector4(0.0, 0.012 * u, 0.025 * u, 0.0), 0.03 * u, ws * 0.8)
	head.call("build", false)
	_box(_head, "Crown", Vector4(0.0, 0.04 * u, -0.01 * u, 0.0), Vector4(0.05 * u, 0.012 * u, 0.07 * u, deep * 0.5), dark)
	_box(_head, "Bill", Vector4(0.0, 0.005 * u, 0.1 * u, 0.0), Vector4(0.024 * u, 0.022 * u, 0.1 * u, deep * 0.45), bill)
	_box(_head, "BillTip", Vector4(0.0, 0.004 * u, 0.18 * u, 0.0), Vector4(0.014 * u, 0.012 * u, 0.07 * u, deep * 0.4), bill.darkened(0.15))
	for side in [-1.0, 1.0]:
		var eye := _box(_head, "Eye%d" % int(side), Vector4(side * 0.026 * u, 0.018 * u, 0.03 * u, 0.0), Vector4(0.01 * u, 0.014 * u, 0.014 * u, deep * 0.4), Color(0.95, 0.85, 0.2))
		_box(eye, "Pupil", Vector4(side * 0.002 * u, 0.0, 0.0, 0.0), Vector4(0.008 * u, 0.007 * u, 0.007 * u, deep * 0.4), Color(0.02, 0.02, 0.02))
		# The broad black brow, from over the eye back to the plumes.
		_box(_head, "Brow%d" % int(side), Vector4(side * 0.025 * u, 0.032 * u, -0.025 * u, 0.0), Vector4(0.012 * u, 0.014 * u, 0.085 * u, deep * 0.4), dark)
	for k in 2:
		var plume := _box(_head, "Plume%d" % k, Vector4((float(k) - 0.5) * 0.012 * u, 0.03 * u, -0.1 * u, 0.0), Vector4(0.006 * u, 0.006 * u, 0.15 * u, deep * 0.3), dark)
		plume.basis = Basis4D.from_yz(-0.45 - 0.12 * float(k))
	_fish = _box(_head, "Fish", Vector4(0.0, 0.0, 0.2 * u, 0.0), Vector4(0.02 * u, 0.012 * u, 0.08 * u, deep * 0.3), Color(0.78, 0.82, 0.84))
	_fish.basis = Basis4D.from_zx(PI * 0.5)
	_fish.visible = false
	_apply_neck(_pose)


func _rig(parent: Node, part: String, colour: Color) -> MeshInstance4D:
	var hide := MeshInstance4D.new()
	hide.name = part
	hide.set_script(RIG)
	var m := TetraMaterial4D.new()
	m.albedo_color = colour
	hide.material_override = m
	parent.add_child(hide)
	hide.set("profile_sides", 12)
	hide.set("profile_rings", 4)
	hide.set("verbose", false)
	hide.set("live_rebuild", false)
	_own(hide)
	return hide


## A round knob: a loft of two balls a hair apart.
func _sphere(parent: Node, part: String, at: Vector4, radius: float, colour: Color, w_scale: float) -> void:
	var knob := _rig(parent, part, colour)
	knob.position = at
	_ball(knob, "A", Vector4(0.0, -radius * 0.15, 0.0, 0.0), radius, w_scale)
	_ball(knob, "B", Vector4(0.0, radius * 0.15, 0.0, 0.0), radius, w_scale)
	knob.call("build", false)


func _ball(parent: Node, part: String, at: Vector4, radius: float, w_scale: float) -> void:
	var node := MeshInstance4D.new()
	node.name = part
	node.set_script(BALL)
	parent.add_child(node)
	node.position = at
	node.set("radius", radius)
	node.set("w_scale", w_scale)
	_own(node)


func _box(parent: Node, part: String, at: Vector4, box: Vector4, colour: Color) -> MeshInstance4D:
	var node := MeshInstance4D.new()
	node.name = part
	var mesh := BoxTetraMesh4D.new()
	mesh.size = box
	node.mesh = mesh
	var material := TetraMaterial4D.new()
	material.albedo_color = colour
	node.material_override = material
	parent.add_child(node)
	node.position = at
	_own(node)
	return node


func _own(node: Node) -> void:
	if Engine.is_editor_hint() and get_tree() != null and get_tree().edited_scene_root != null:
		node.owner = get_tree().edited_scene_root


# --- For the camera --------------------------------------------------------------------------

func behaviour() -> Array:
	match state:
		State.ONE_LEG:
			return [2, "On one leg"]
		State.STALK, State.STRIKE:
			return [3, "The strike" if state == State.STRIKE else "Stalking"]
		State.TAKE_OFF, State.FLY, State.LAND:
			return [4, "Heron rising"]
	return [1, "The ana heron"]


## Its middle, in the world.
func centre() -> Vector4:
	return global_position + global_basis * Vector4(0.0, 0.62 * size, 0.0, 0.0)


func perform(what: String) -> void:
	match what:
		"one_leg":
			_enter(State.ONE_LEG, 20.0)
		"stalk":
			_enter(State.STALK, 20.0)
		"strike":
			_enter(State.STRIKE, 0.9)
		"take_off":
			_take_off()
		"alert":
			_enter(State.ALERT, 3.0)


## A whistle from somewhere: it stands up straight and looks.
func hear() -> void:
	if state in [State.STAND, State.ONE_LEG, State.STALK]:
		_enter(State.ALERT, 3.2)


# --- Its life ---------------------------------------------------------------------------------

func _enter(s: int, seconds: float) -> void:
	state = s
	_state_t = 0.0
	_state_len = seconds


func _take_off() -> void:
	if state in [State.TAKE_OFF, State.FLY, State.LAND]:
		return
	var marsh := get_node_or_null(marsh_path) as Node4D
	_from = position
	if marsh != null:
		var spot: Vector4 = marsh.call("fishing_spot") if _at_refuge else marsh.call("refuge_spot")
		_to = marsh.position + spot
	else:
		_to = _home + Vector4(6.0, 0.0, 2.0, 0.0) * (-1.0 if _at_refuge else 1.0)
	_at_refuge = not _at_refuge
	_enter(State.TAKE_OFF, 1.0)
	_play(_voice, -4.0)
	_play(_wing_voice, -6.0)


func _play(p: AudioStreamPlayer, db: float) -> void:
	if p == null or p.stream == null:
		return
	var lookout: Node = get_node_or_null(lookout_path)
	var cam: Camera4D = lookout.call("current_camera") if lookout != null else null
	var d: float = 8.0
	if cam != null:
		var g: Vector4 = cam.global_position - global_position
		d = Vector3(g.x, g.y, g.z).length()
	p.volume_db = db - 20.0 * log(maxf(d, 6.0) / 6.0) / log(10.0)
	p.play()


func _process(delta: float) -> void:
	_t += delta
	_state_t += delta
	_cool = maxf(_cool - delta, 0.0)
	_check_disturbed()
	_seen_check -= delta
	if _seen_check <= 0.0:
		_seen_check = 0.5
		_seen = _visible_to_camera()
	# Looking about while it stands: the head turns, holds, turns back.
	_next_look -= delta
	if _next_look <= 0.0:
		_next_look = _rng.randf_range(2.0, 5.0)
		_head_yaw_goal = _rng.randf_range(-0.9, 0.9) if _rng.randf() < 0.7 else 0.0
	if idle_only:
		state = State.STAND
		_state_t = 0.0
		if _seen:
			_animate(delta)
		return
	match state:
		State.STAND, State.ALERT, State.ONE_LEG:
			if _state_t > _state_len:
				_next_idle()
		State.STALK:
			# A step every second or so, pausing between, and back along its own line.
			var stepping: bool = fmod(_state_t, 1.6) < 0.9
			if stepping:
				position += global_basis * Vector4(0.0, 0.0, 0.11 * delta * _walk_dir, 0.0)
			if Vector2(position.x - _home.x, position.z - _home.z).length() > 1.6:
				_walk_dir = -_walk_dir
				position += global_basis * Vector4(0.0, 0.0, 0.05 * _walk_dir, 0.0)
				basis = basis * Basis4D.from_zx(PI)
			if _state_t > _state_len:
				_enter(State.STRIKE, 0.9)
		State.STRIKE:
			if _state_t > _state_len:
				if _fish != null:
					_fish.visible = _rng.randf() < 0.5
				_enter(State.STAND, _rng.randf_range(3.0, 6.0))
		State.TAKE_OFF:
			_fly(delta)
		State.FLY, State.LAND:
			_fly(delta)
	if _seen or state in [State.TAKE_OFF, State.FLY, State.LAND]:
		_animate(delta)


func _visible_to_camera() -> bool:
	var lookout: Node = get_node_or_null(lookout_path)
	if lookout == null:
		return true
	var cam: Camera4D = lookout.call("current_camera")
	if cam == null:
		return true
	var rel: Vector4 = global_position - cam.global_position
	return absf(rel.dot(cam.global_basis.w)) < 3.0 and rel.length() < 80.0


func _next_idle() -> void:
	if _fish != null:
		_fish.visible = false
	var roll: float = _rng.randf()
	if state == State.ONE_LEG or state == State.ALERT:
		_enter(State.STAND, _rng.randf_range(4.0, 8.0))
	elif roll < 0.4:
		_enter(State.ONE_LEG, _rng.randf_range(8.0, 15.0))
	elif roll < 0.8:
		_home = position
		_enter(State.STALK, _rng.randf_range(5.0, 9.0))
	else:
		_enter(State.STAND, _rng.randf_range(5.0, 9.0))


func _check_disturbed() -> void:
	if idle_only or _cool > 0.0 or state in [State.TAKE_OFF, State.FLY, State.LAND]:
		return
	var player := get_node_or_null(player_path) as Node4D
	if player == null or not player.is_visible_in_tree():
		return
	var gap: Vector4 = player.global_position - global_position
	if Vector2(gap.x, gap.z).length() < flush_within and absf(gap.w) < 2.0:
		_take_off()


## The flight: up on slow, deep beats, along an arc to where it is going, and down.
func _fly(_delta: float) -> void:
	var total: float = 5.5
	var k: float = clampf(_state_t / total, 0.0, 1.0)
	if state == State.TAKE_OFF and _state_t > 0.45:
		state = State.FLY
	if state == State.FLY and k > 0.82:
		state = State.LAND
	var lift: float = sin(k * PI) * 3.2
	var along: float = smoothstep(0.05, 1.0, k)
	position = _from.lerp(_to, along) + Vector4(0.0, lift, 0.0, 0.0)
	var d: Vector4 = _to - _from
	if Vector2(d.x, d.z).length() > 0.1:
		basis = Basis4D.from_zx(atan2(d.x, d.z))
	if k >= 1.0:
		position = _to
		_home = _to
		_cool = 8.0
		_enter(State.STAND, _rng.randf_range(4.0, 7.0))


func _animate(delta: float) -> void:
	var want: Array = POSES["rest"]
	match state:
		State.ALERT:
			want = POSES["alert"]
		State.STALK:
			want = POSES["stalk"]
		State.STRIKE:
			var k: float = _state_t / maxf(_state_len, 0.01)
			# Drawn back a little, then the stab, then back up.
			want = POSES["stalk"] if k < 0.25 else (POSES["strike"] if k < 0.6 else POSES["stalk"])
		State.TAKE_OFF, State.FLY, State.LAND:
			want = POSES["fly"] if state != State.TAKE_OFF else POSES["alert"]
	var rate: float = 22.0 if state == State.STRIKE else 5.0
	for i in 4:
		_pose[i] = lerpf(float(_pose[i]), float(want[i]), clampf(delta * rate, 0.0, 1.0))
	_apply_neck(_pose)
	# Legs.
	var flying: bool = state in [State.TAKE_OFF, State.FLY, State.LAND]
	for i in 2:
		var hip_a: float = 0.0
		var heel_a: float = 0.0
		if state == State.ONE_LEG and i == 1:
			hip_a = 0.35
			heel_a = -2.5
		elif state == State.STALK:
			var phase: float = _state_t * 3.5 + (PI if i == 1 else 0.0)
			var stepping: float = 1.0 if fmod(_state_t, 1.6) < 0.9 else 0.0
			hip_a = sin(phase) * 0.35 * stepping
			heel_a = -maxf(sin(phase), 0.0) * 0.6 * stepping
		elif flying:
			# Trailing behind in flight; reaching forward to land.
			hip_a = -1.35 if state != State.LAND else 0.4
			heel_a = 0.1 if state != State.LAND else -0.3
		_hips[i].basis = Basis4D.from_yz(lerpf(_angle_yz(_hips[i]), hip_a, clampf(delta * 8.0, 0.0, 1.0)))
		_heels[i].basis = Basis4D.from_yz(lerpf(_angle_yz(_heels[i]), heel_a, clampf(delta * 8.0, 0.0, 1.0)))
	# Wings: spread and beating in flight, folded otherwise.
	for i in 2:
		_folded[i].visible = not flying
		_spread[i].visible = flying
		var side: float = -1.0 if i == 0 else 1.0
		var beat: float = 0.0
		if flying:
			var rate_hz: float = 3.2 if state == State.TAKE_OFF else 2.1
			beat = sin(_t * TAU * rate_hz) * (0.75 if state != State.LAND else 0.35)
		_wing_pivots[i].basis = Basis4D.from_xy(side * beat)
	# The body leans forward in flight, crouches for the leap.
	var lean: float = 0.0
	var drop: float = 0.0
	if state == State.TAKE_OFF:
		drop = -0.06 * size * (1.0 - clampf(_state_t / 0.45, 0.0, 1.0))
	if flying:
		lean = 0.25
	if state == State.ONE_LEG:
		_body.position.x = lerpf(_body.position.x, -0.04 * size, clampf(delta * 3.0, 0.0, 1.0))
	else:
		_body.position.x = lerpf(_body.position.x, 0.0, clampf(delta * 3.0, 0.0, 1.0))
	_body.position.y = drop
	_body.basis = Basis4D.from_yz(lean)


func _angle_yz(node: Node4D) -> float:
	var y: Vector4 = node.basis.y
	return atan2(y.z, y.y)


func _apply_neck(pose: Array) -> void:
	for i in mini(_neck.size(), 3):
		_neck[i].basis = Basis4D.from_yz(float(pose[i]))
	if _head != null:
		var looking: bool = state in [State.STAND, State.ONE_LEG, State.ALERT]
		_head_yaw = lerpf(_head_yaw, _head_yaw_goal if looking else 0.0, 0.08)
		_head.basis = Basis4D.from_zx(_head_yaw) * Basis4D.from_yz(float(pose[3]))
