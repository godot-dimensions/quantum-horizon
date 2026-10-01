@tool
extends Node4D

## The ana owl: a tawny owl that sits on a post outside the Lookout's north window, at
## w +1.5 - off the farm's slice, so from the cab there is nothing there until the camera's
## focus ring finds it. The first secret, and the one that teaches the ring.
##
## BUILT THE WAY THE PEN'S ANIMALS ARE (pen_cat_4d.gd): a lofted body of balls, plus boxes
## for what a loft cannot make - the facial disc, the eyes and beak, the ear tufts, the
## barred wings, the streaks on its breast. The head is a SECOND loft on a pivot of its own,
## so turning the head is moving a node (free) rather than re-lofting the bird (not).
##
## THICK IN W ON PURPOSE. Every ball is stretched along W (w_scale), and every box on the
## face is as deep in W as the head is. A real owl's proportions in W would make it a
## sliver - in focus for a few centimetres of the ring - and the face would vanish before the
## head did. Stretched, it is sharp over about +-0.2 m of the ring and its face stays on it.
##
## WHAT IT DOES (the journal's four stars, rarest last):
##   SIT       the resting owl: the head swings to look about, it blinks
##   LOOK      watched for a moment, through a camera in focus on it, it turns to look back
##   STRETCH   now and then, one wing down and out, and folded again
##   TURN_W    rarely: the head turns further than a head should, through W. The face
##             rotates out of your slice into ana and comes back - the head itself stays a
##             round head, because a ball's slice is a disc whichever way it turns
##   HOOT      three hoots (lookout_owl.wav), heard in every slice: sound does not care
##             which W you are at

enum State { SIT, LOOK, STRETCH, TURN_W, HOOT }

const RIG := preload("res://ramon/chickenpen/scripts/loft_rig_4d.gd")
const BALL := preload("res://ramon/chickenpen/scripts/loft_ball_4d.gd")
const SIDES := 14

@export_group("Shape")
## Standing height, roughly. A tawny owl is about 0.4 m; this one is a little big, to read
## from the cab.
@export_range(0.2, 2.0, 0.01, "suffix:m") var size: float = 0.55:
	set(v):
		size = v
		_changed()
@export_range(1.0, 4.0, 0.05) var w_stretch: float = 2.4:
	set(v):
		w_stretch = v
		_changed()
@export var plumage: Color = Color(0.47, 0.34, 0.22):
	set(v):
		plumage = v
		_changed()
@export var plumage_dark: Color = Color(0.30, 0.21, 0.14):
	set(v):
		plumage_dark = v
		_changed()
@export var disc: Color = Color(0.80, 0.68, 0.52):
	set(v):
		disc = v
		_changed()
@export var eye: Color = Color(0.96, 0.60, 0.10):
	set(v):
		eye = v
		_changed()

@export_group("Life")
## Who watches it: the Lookout (its station's camera). Without one - in the showcase - it
## looks now and then at [member look_target_path] instead.
@export var lookout_path: NodePath
@export var look_target_path: NodePath
@export_range(0.2, 6.0, 0.1, "suffix:s") var watched_for: float = 1.2
@export_range(5.0, 120.0, 1.0, "suffix:s") var stretch_every: float = 26.0
@export_range(5.0, 240.0, 1.0, "suffix:s") var turn_w_every: float = 44.0
@export_range(5.0, 240.0, 1.0, "suffix:s") var hoot_every: float = 32.0
@export var hoot_sound: AudioStream = preload("res://ramon/chickenpen/audio/sfx/lookout_owl.wav")

var state: int = State.SIT

var _head_pivot: Node4D
var _wings: Array[Node4D] = []
var _primaries: Array = []
var _eyes: Array[Node4D] = []
var _throat: Node4D
var _head_yaw: float = 0.0
var _yaw_goal: float = 0.0
var _w_turn: float = 0.0
var _t: float = 0.0
var _state_t: float = 0.0
var _next_glance: float = 2.0
var _next_blink: float = 3.0
var _blink: float = 0.0
var _watched: float = 0.0
var _timers: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _voice: AudioStreamPlayer


func _changed() -> void:
	if is_node_ready():
		rebuild()


func _ready() -> void:
	_rng.seed = 41
	rebuild()
	if Engine.is_editor_hint():
		set_process(false)
		return
	_timers = {
		State.STRETCH: _rng.randf_range(0.5, 1.0) * stretch_every,
		State.TURN_W: _rng.randf_range(0.6, 1.0) * turn_w_every,
		State.HOOT: _rng.randf_range(0.2, 0.6) * hoot_every,
	}
	_voice = AudioStreamPlayer.new()
	_voice.stream = hoot_sound
	_voice.bus = &"SFX" if AudioServer.get_bus_index(&"SFX") >= 0 else &"Master"
	add_child(_voice)


func rebuild() -> void:
	for child in get_children():
		if child != _voice:
			child.free()
	_wings.clear()
	_eyes.clear()
	_primaries.clear()
	var u: float = size
	var ws: float = w_stretch
	# AN OWL IS AN EGG WITH A FACE. Seen perched, it has no neck, no shoulders and no arms:
	# the head is nearly as wide as the body and sits straight on it, and the folded wings
	# are part of the body's outline rather than things hanging off it. The first build was
	# slim, square-faced and winged like a beetle; this one is round.
	var body := _rig("Plumage", plumage)
	_ball(body, "Tail", Vector4(0.0, 0.05 * u, -0.15 * u, 0.0), 0.05 * u, ws * 0.7)
	_ball(body, "Belly", Vector4(0.0, 0.22 * u, -0.04 * u, 0.0), 0.215 * u, ws, 1.05)
	_ball(body, "Chest", Vector4(0.0, 0.42 * u, -0.005 * u, 0.0), 0.205 * u, ws)
	_ball(body, "Nape", Vector4(0.0, 0.57 * u, -0.02 * u, 0.0), 0.175 * u, ws)
	body.call("build", false)
	# Streaks down the breast, scattered rather than in rows (in rows they read as a keypad),
	# each sitting on the loft's surface where it is.
	var streaks: Array = [[-0.07, 0.42], [0.05, 0.45], [-0.02, 0.36], [0.09, 0.33], [-0.1, 0.29], [0.02, 0.26], [-0.05, 0.2], [0.07, 0.18]]
	for i in streaks.size():
		var sx: float = float(streaks[i][0]) * u
		var sy: float = float(streaks[i][1]) * u
		var r: float = (0.2 if sy > 0.32 * u else 0.212) * u
		var sz: float = sqrt(maxf(r * r - sx * sx, 0.0)) + (-0.005 if sy > 0.32 * u else -0.035) * u
		var streak := _box(self, "Streak%d" % i, Vector4(sx, sy, sz, 0.0), Vector4(0.016 * u, 0.05 * u, 0.012 * u, 0.24 * u * ws), plumage_dark)
		streak.basis = Basis4D.from_zx(atan2(sx, sz))
	# The head on its pivot: a second loft, big and round, and the face on it.
	_head_pivot = Node4D.new()
	_head_pivot.name = "HeadPivot"
	add_child(_head_pivot)
	_own(_head_pivot)
	_head_pivot.position = Vector4(0.0, 0.72 * u, 0.0, 0.0)
	var head := _rig("Head", plumage, _head_pivot)
	_ball(head, "Crown", Vector4(0.0, 0.035 * u, -0.035 * u, 0.0), 0.18 * u, ws * 0.95)
	_ball(head, "Face", Vector4(0.0, -0.01 * u, 0.02 * u, 0.0), 0.19 * u, ws * 0.95)
	head.call("build", false)
	var face_w: float = 0.3 * u * ws
	for side in [-1.0, 1.0]:
		var tag: String = "L" if side < 0.0 else "R"
		var at := Vector4(side * 0.078 * u, -0.005 * u, 0.0, 0.0)
		# The facial disc: an octagon (a square and a diamond) of pale feathers round each
		# eye, a dark rim behind it - together the owl's round, flat face.
		_octagon(_head_pivot, "Rim" + tag, at + Vector4(0, 0, 0.178 * u, 0), 0.175 * u, 0.012 * u, face_w, plumage_dark)
		_octagon(_head_pivot, "Disc" + tag, at + Vector4(0, 0, 0.19 * u, 0), 0.15 * u, 0.02 * u, face_w, disc)
		var e := _box(_head_pivot, "Eye" + tag, at + Vector4(side * 0.004 * u, 0.012 * u, 0.205 * u, 0.0), Vector4(0.072 * u, 0.072 * u, 0.012 * u, face_w * 0.8), eye)
		_box(e, "Pupil", Vector4(0.0, 0.0, 0.005 * u, 0.0), Vector4(0.04 * u, 0.044 * u, 0.008 * u, face_w * 0.8), Color(0.05, 0.04, 0.03))
		_box(e, "Glint", Vector4(0.013 * u, 0.015 * u, 0.009 * u, 0.0), Vector4(0.012 * u, 0.012 * u, 0.004 * u, face_w * 0.6), Color(1, 1, 0.95))
		_eyes.append(e)
		# Brows: pale, from above the beak out over each eye - the V that makes the face.
		var brow := _box(_head_pivot, "Brow" + tag, Vector4(side * 0.05 * u, 0.075 * u, 0.2 * u, 0.0), Vector4(0.11 * u, 0.022 * u, 0.014 * u, face_w * 0.8), disc.lightened(0.18))
		brow.basis = Basis4D.from_xy(side * 0.42)
		# Ear tufts: feathers, not ears - short, broad and leaning out.
		var tuft := _box(_head_pivot, "Tuft" + tag, Vector4(side * 0.115 * u, 0.165 * u, 0.02 * u, 0.0), Vector4(0.055 * u, 0.09 * u, 0.035 * u, face_w * 0.7), plumage_dark)
		tuft.basis = Basis4D.from_xy(-side * 0.5)
	var beak := _box(_head_pivot, "Beak", Vector4(0.0, -0.045 * u, 0.208 * u, 0.0), Vector4(0.04 * u, 0.04 * u, 0.03 * u, face_w * 0.6), Color(0.30, 0.29, 0.25))
	beak.basis = Basis4D.from_xy(PI * 0.25)
	_throat = _box(_head_pivot, "Throat", Vector4(0.0, -0.13 * u, 0.15 * u, 0.0), Vector4(0.11 * u, 0.06 * u, 0.05 * u, face_w * 0.8), disc.lightened(0.15))
	_throat.visible = false
	# Wings, folded against the sides - part of the outline - each on a shoulder pivot. The
	# flight feathers stay tucked away until the stretch fans them out.
	for side in [-1.0, 1.0]:
		var pivot := Node4D.new()
		pivot.name = "Wing" + ("L" if side < 0.0 else "R")
		add_child(pivot)
		_own(pivot)
		pivot.position = Vector4(side * 0.14 * u, 0.55 * u, -0.05 * u, 0.0)
		# Mostly inside the body: only the wing's dark edge shows down each side.
		var fold := _box(pivot, "Fold", Vector4(side * 0.045 * u, -0.2 * u, -0.01 * u, 0.0), Vector4(0.035 * u, 0.36 * u, 0.2 * u, 0.36 * u * ws), plumage_dark.lerp(plumage, 0.3))
		fold.basis = Basis4D.from_yz(0.14)
		_box(fold, "Bar", Vector4(side * 0.019 * u, -0.06 * u, 0.0, 0.0), Vector4(0.004 * u, 0.025 * u, 0.18 * u, 0.32 * u * ws), plumage.lightened(0.15))
		var fan: Array[Node4D] = []
		for f in 5:
			var feather := _box(pivot, "Primary%d" % f, Vector4(side * 0.03 * u, -0.38 * u, (-0.08 + 0.04 * float(f)) * u, 0.0),
				Vector4(0.025 * u, 0.22 * u, 0.05 * u, 0.3 * u * ws), plumage_dark if f % 2 == 0 else plumage)
			feather.visible = false
			fan.append(feather)
		_primaries.append(fan)
		_wings.append(pivot)
	# Feet: feathered to the toes, dark talons round the perch.
	for side in [-1.0, 1.0]:
		var tag: String = "L" if side < 0.0 else "R"
		_box(self, "Foot" + tag, Vector4(side * 0.06 * u, 0.02 * u, 0.07 * u, 0.0), Vector4(0.07 * u, 0.05 * u, 0.09 * u, 0.2 * u * ws), disc)
		for k in 3:
			_box(self, "Talon%s%d" % [tag, k], Vector4(side * 0.06 * u + (float(k) - 1.0) * 0.022 * u, -0.005 * u, 0.12 * u, 0.0),
				Vector4(0.012 * u, 0.025 * u, 0.02 * u, 0.12 * u * ws), Color(0.12, 0.11, 0.10))


## A pale disc of feathers as an octagon: a square and the same square turned 45 degrees.
func _octagon(parent: Node, part: String, at: Vector4, across: float, thick: float, deep: float, colour: Color) -> void:
	var side: float = across * 0.83
	_box(parent, part, at, Vector4(side, side, thick, deep), colour)
	var turned := _box(parent, part + "Turned", at, Vector4(side, side, thick, deep), colour)
	turned.basis = Basis4D.from_xy(PI * 0.25)


func _rig(part: String, colour: Color, parent: Node = self) -> MeshInstance4D:
	var hide := MeshInstance4D.new()
	hide.name = part
	hide.set_script(RIG)
	var m := TetraMaterial4D.new()
	m.albedo_color = colour
	hide.material_override = m
	parent.add_child(hide)
	hide.set("profile_sides", SIDES)
	hide.set("profile_rings", 4)
	hide.set("verbose", false)
	hide.set("live_rebuild", false)
	_own(hide)
	return hide


func _ball(parent: Node, part: String, at: Vector4, radius: float, w_scale: float, v_scale: float = 1.0) -> Node4D:
	var node := MeshInstance4D.new()
	node.name = part
	node.set_script(BALL)
	parent.add_child(node)
	node.position = at
	node.set("radius", radius)
	node.set("w_scale", w_scale)
	node.set("v_scale", v_scale)
	_own(node)
	return node


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


# --- For the camera ----------------------------------------------------------------------------

## The middle of its face, in the world.
func head_point() -> Vector4:
	return _head_pivot.global_position if _head_pivot != null else global_position


## Makes it do [param what] now: "turn_w", "stretch", "hoot", "look".
func perform(what: String, _amount: float = 1.0) -> void:
	match what:
		"turn_w":
			_enter(State.TURN_W)
		"stretch":
			_enter(State.STRETCH)
		"hoot":
			_enter(State.HOOT)
		"look":
			_enter(State.LOOK)


func behaviour() -> Array:
	match state:
		State.LOOK:
			return [2, "It's seen you"]
		State.STRETCH:
			return [3, "The wing stretch"]
		State.TURN_W:
			return [4, "A head turned through W"]
	return [1, "The ana owl"]


# --- Its life ---------------------------------------------------------------------------------

func _enter(s: int) -> void:
	state = s
	_state_t = 0.0
	if s == State.HOOT and _voice != null:
		_voice.volume_db = _hoot_level()
		_voice.play()


func _process(delta: float) -> void:
	_t += delta
	_state_t += delta
	var watcher: Variant = _watcher()
	if watcher != null:
		_watched = _watched + delta if bool(watcher["on_me"]) else maxf(_watched - delta * 2.0, 0.0)
	match state:
		State.SIT:
			_idle(delta)
			if watcher != null and _watched >= watched_for:
				_enter(State.LOOK)
			else:
				for s in [State.TURN_W, State.STRETCH, State.HOOT]:
					_timers[s] = float(_timers[s]) - delta
					if float(_timers[s]) <= 0.0:
						var every: float = [0.0, 0.0, stretch_every, turn_w_every, hoot_every][s]
						_timers[s] = every * _rng.randf_range(0.7, 1.3)
						_enter(s)
						break
		State.LOOK:
			if watcher != null:
				_yaw_goal = _yaw_to(watcher["eye"])
			if _state_t > 2.5 and (watcher == null or not bool(watcher["on_me"])):
				_enter(State.SIT)
			elif _state_t > 7.0 and watcher != null and _rng.randf() < delta * 0.25:
				# Stared at long enough, it does the thing.
				_enter(State.TURN_W)
		State.STRETCH:
			if _state_t > 2.8:
				_enter(State.SIT)
		State.TURN_W:
			if _state_t > 3.4:
				_enter(State.SIT)
		State.HOOT:
			if _state_t > 2.8:
				_enter(State.SIT)
	_pose(delta)


func _idle(delta: float) -> void:
	_next_glance -= delta
	if _next_glance <= 0.0:
		_next_glance = _rng.randf_range(1.8, 5.0)
		# An owl's look-about is wide - three quarters of a turn either way - and quick.
		_yaw_goal = _rng.randf_range(-1.7, 1.7) if _rng.randf() < 0.8 else _rng.randf_range(-0.3, 0.3)


## Who is watching: {eye, on_me} - the camera, and whether it is aimed at the owl and in
## focus on its W.
func _watcher() -> Variant:
	var lookout: Node = get_node_or_null(lookout_path)
	if lookout != null:
		var station: Node = lookout.get("station")
		var cam: Camera4D = station.get("camera") if station != null else null
		if cam == null or not cam.is_current():
			return null
		var rel: Vector4 = head_point() - cam.global_position
		var basis: Projection = cam.global_basis
		var depth: float = -rel.dot(basis.z)
		var on: bool = depth > 0.5
		if on:
			var t: float = tan(float(cam.get("field_of_view_4d")) * 0.5)
			var sx: float = rel.dot(basis.x) / (depth * t)
			var sy: float = rel.dot(basis.y) / (depth * t)
			on = Vector2(sx, sy).length() < 0.45 and absf(rel.dot(basis.w)) < 0.3
		return {"eye": cam.global_position, "on_me": on}
	var target := get_node_or_null(look_target_path) as Node4D
	if target != null:
		var near: bool = target.global_position.distance_to(global_position) < 8.0
		return {"eye": target.global_position + Vector4(0, 1.5, 0, 0), "on_me": near and fmod(_t, 14.0) < 5.0}
	return null


func _yaw_to(p: Vector4) -> float:
	var local: Vector4 = global_basis.inverse() * (p - global_position)
	return clampf(atan2(local.x, local.z), -2.4, 2.4)


func _pose(delta: float) -> void:
	if _head_pivot == null:
		return
	# The head: quick to turn, then still, as an owl's is.
	_head_yaw = lerp_angle(_head_yaw, _yaw_goal, clampf(delta * 9.0, 0.0, 1.0))
	var w_goal: float = 0.0
	if state == State.TURN_W:
		var k: float = _state_t / 3.4
		w_goal = sin(clampf(k, 0.0, 1.0) * PI) * 1.4
		w_goal = minf(w_goal * 1.4, 1.4)
	_w_turn = lerpf(_w_turn, w_goal, clampf(delta * 5.0, 0.0, 1.0))
	var tilt: float = sin(_t * 0.7) * 0.05 + (0.18 if state == State.LOOK else 0.0) * sin(_t * 2.1)
	_head_pivot.basis = Basis4D.from_zx(_head_yaw) * Basis4D.from_xy(tilt * 0.6) * Basis4D.from_zw(_w_turn)
	# Breathing.
	var breath: float = 1.0 + sin(_t * 1.6) * 0.012
	scale_body(breath)
	# Blinks: the eyes squashed shut for a moment.
	_next_blink -= delta
	if _next_blink <= 0.0:
		_next_blink = _rng.randf_range(2.5, 6.0)
		_blink = 0.14
	_blink = maxf(_blink - delta, 0.0)
	var open: float = 0.12 if _blink > 0.0 else (1.15 if state == State.LOOK else 1.0)
	for e in _eyes:
		e.basis = Basis4D.from_scale(Vector4(1.0, open, 1.0, 1.0))
	# The wing stretch: one wing (and its leg's side) let down and out, the flight feathers
	# fanned, held, and folded away again - the classic owl stretch, not a wave.
	for i in _wings.size():
		var side: float = -1.0 if i == 0 else 1.0
		var out: float = 0.0
		if state == State.STRETCH and i == 1:
			out = smoothstep(0.0, 0.3, _state_t / 2.8) * (1.0 - smoothstep(0.7, 1.0, _state_t / 2.8))
		_wings[i].basis = Basis4D.from_xy(side * out * 0.75) * Basis4D.from_yz(out * 0.2)
		var fan: Array = _primaries[i] if i < _primaries.size() else []
		for f in fan.size():
			var feather := fan[f] as Node4D
			feather.visible = out > 0.05
			feather.basis = Basis4D.from_xy(side * out * (0.05 + 0.14 * float(f))) * Basis4D.from_scale(Vector4(1.0, 0.4 + 0.6 * out, 1.0, 1.0))
	if _throat != null:
		_throat.visible = state == State.HOOT and fmod(_state_t, 1.3) < 0.7


func scale_body(k: float) -> void:
	var body := get_node_or_null("Plumage") as Node4D
	if body != null:
		body.basis = Basis4D.from_scale(Vector4(k, 1.0, k, k))


## Louder near the camera, wherever in W it is.
func _hoot_level() -> float:
	var lookout: Node = get_node_or_null(lookout_path)
	var cam: Camera4D = lookout.call("current_camera") if lookout != null else null
	if cam == null:
		return -10.0
	var d: float = Vector3(cam.global_position.x - global_position.x, cam.global_position.y - global_position.y, cam.global_position.z - global_position.z).length()
	return -6.0 - 20.0 * log(maxf(d, 4.0) / 4.0) / log(10.0)
