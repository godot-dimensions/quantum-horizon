@tool
extends Node4D

## Wren's balloon: the Lookout's set piece. Moored beside the tower once you have earned it,
## it takes you up on a ride Wren and the wind choose - over the farm, through the
## murmuration, and then slowly ANA, out of the farm's slice altogether, to a marsh that is
## only there along W, and back.
##
## A RAIL, AS POKEMON SNAP'S IS, because a rail solves the hardest problem a 4D game has:
## steering through W. The ride's path is (x, y, z AND w), planned (RIDE below), and the
## camera's slice rides with the basket - so as the balloon drifts ana the farm thins and
## goes, not because anything moved but because you did. You only look, zoom, focus and
## shoot: 36 shots, no reloads up there. X whistles, and what can hear it looks up.
##
## BUILT FROM THE SAME PARTS AS EVERYTHING ELSE:
##   the envelope  a loft of balls stacked up a teardrop (loft_rig_4d.gd), coloured per ball
##                 (use_ball_colors) - two balls a centimetre apart at every band's edge, so
##                 the bands are crisp rather than a fade. It is a 4D solid of revolution:
##                 off its W-middle it shows a smaller balloon, like everything round here
##   the basket    a closed 4D room, eight walls (follow_up/4d_enclosure_rule.md): floor,
##                 four sides and two W walls, open on top. Wicker, with a leather rim
##   the burner    on four rods over the basket; its flame is two boxes that flicker
##   the ropes     thin bars from the mouth ring to the basket's corners
##   moored        a tether to a stake, and sandbags
##
## INFLATES when the story makes it ready (set_ready): the envelope swells from the mouth
## over a few seconds, which you can watch from the cab.

signal ride_finished

const RIG := preload("res://ramon/chickenpen/scripts/loft_rig_4d.gd")
const BALL := preload("res://ramon/chickenpen/scripts/loft_ball_4d.gd")

## The ride: [seconds, position of the basket floor (x, y, z, w)]. Wren's line for the
## moment, if any, is in RADIO. The marsh is at w +8, west of the tower (ana_marsh_4d.gd).
const RIDE := [
	[0.0, Vector4(0.0, 0.0, 0.0, 0.0)],
	[10.0, Vector4(1.5, 9.0, 1.5, 0.0)],
	[24.0, Vector4(9.0, 18.0, 9.0, 0.0)],
	[38.0, Vector4(20.0, 21.0, 17.0, 0.0)],
	[54.0, Vector4(27.0, 20.0, -6.0, 0.0)],
	[70.0, Vector4(24.0, 19.0, -34.0, 0.0)],
	[86.0, Vector4(8.0, 17.0, -26.0, 1.5)],
	[102.0, Vector4(-4.0, 13.0, -12.0, 5.5)],
	[116.0, Vector4(-5.0, 7.5, 1.0, 8.0)],
	[130.0, Vector4(-3.0, 5.5, 7.0, 8.0)],
	[144.0, Vector4(-1.0, 6.0, 4.0, 4.0)],
	[156.0, Vector4(-0.3, 2.0, 1.0, 0.8)],
	[164.0, Vector4(0.0, 0.0, 0.0, 0.0)],
]
## [seconds, Wren's lines].
const RADIO := [
	[1.0, ["Off we go. Mind your head on the burner."]],
	[30.0, ["There's the pen. Everything's in it, for once."]],
	[58.0, ["Starlings, dead ahead. Into them. Thirty six shots, don't spend them all."]],
	[84.0, ["Now we go ana. Don't worry, the farm's still there.", "We just aren't."]],
	[108.0, ["There. Water. I told you.", "Something's standing in it. Quiet, now. X if you want it to look up."]],
	[142.0, ["Back we come. Kata, and down."]],
	[158.0, ["And down. Gently."]],
]

@export var envelope_colours: Array[Color] = [Color(0.62, 0.14, 0.10), Color(0.90, 0.84, 0.70), Color(0.66, 0.16, 0.11),
	Color(0.88, 0.62, 0.16), Color(0.16, 0.42, 0.44), Color(0.62, 0.14, 0.10)]
@export var wicker: Color = Color(0.62, 0.47, 0.28)
## Whether it is up and ready by the tower, or not here at all yet.
@export var ready_now: bool = false
@export_range(1.0, 20.0, 0.5, "suffix:s") var inflate_seconds: float = 6.0
## Faster than real, for tests: 1 is the ride as planned.
@export_range(0.1, 10.0, 0.1) var ride_speed: float = 1.0

var lookout: Node
var riding: bool = false
var ride_time: float = 0.0

var _envelope: Node4D
var _flame: Array[Node4D] = []
var _basket_body: StaticBody4D
var _tether: Array[Node4D] = []
var _moor: Vector4
var _inflate: float = 1.0
var _burn: float = 0.0
var _burner_sound: AudioStreamPlayer
var _said: int = 0
var _hurry: float = 0.0
var _t: float = 0.0


func _ready() -> void:
	rebuild()
	_moor = position
	if Engine.is_editor_hint():
		return
	_inflate = 1.0 if ready_now else 0.0
	visible = ready_now
	_apply_inflation()


## Up by the tower or gone. [param instant] skips the inflating, for a journal that was
## already this far when the scene loaded.
func set_ready(on: bool, instant: bool = false) -> void:
	if on == ready_now and not instant:
		return
	ready_now = on
	visible = on
	_inflate = (1.0 if instant else 0.02) if on else 0.0
	_apply_inflation()


func rebuild() -> void:
	for child in get_children():
		child.free()
	_flame.clear()
	_tether.clear()
	_build_envelope()
	_build_basket()
	_build_burner_and_ropes()
	_build_mooring()


func _build_envelope() -> void:
	_envelope = Node4D.new()
	_envelope.name = "Envelope"
	add_child(_envelope)
	_own(_envelope)
	_envelope.position = Vector4(0.0, 3.0, 0.0, 0.0)
	var hide := MeshInstance4D.new()
	hide.name = "Skin"
	hide.set_script(RIG)
	var m := TetraMaterial4D.new()
	m.albedo_color = Color.WHITE
	hide.material_override = m
	_envelope.add_child(hide)
	hide.set("profile_sides", 16)
	hide.set("profile_rings", 4)
	hide.set("smoothing", 2)
	hide.set("verbose", false)
	hide.set("live_rebuild", false)
	hide.set("use_ball_colors", true)
	_own(hide)
	# The teardrop, as radius by height above the mouth.
	var profile: Array = [[0.0, 0.55], [0.8, 1.5], [1.8, 2.5], [3.0, 3.2], [4.4, 3.55], [5.8, 3.5], [7.0, 3.0], [7.9, 2.1], [8.4, 1.0], [8.56, 0.3]]
	var bands: Array = [0.0, 1.8, 3.4, 5.0, 6.4, 7.6, 9.0]
	var heights: Array = []
	for p in profile:
		heights.append(float(p[0]))
	for k in range(1, bands.size() - 1):
		heights.append(float(bands[k]) - 0.006)
		heights.append(float(bands[k]) + 0.006)
	heights.sort()
	var i: int = 0
	for y in heights:
		var band: int = 0
		while band < bands.size() - 2 and float(y) >= float(bands[band + 1]):
			band += 1
		var ball := MeshInstance4D.new()
		ball.name = "Ring%02d" % i
		ball.set_script(BALL)
		hide.add_child(ball)
		ball.position = Vector4(0.0, float(y), 0.0, 0.0)
		ball.set("radius", _radius_at(profile, float(y)))
		ball.set("color", envelope_colours[band % envelope_colours.size()])
		_own(ball)
		i += 1
	hide.call("build", false)
	# The mouth's ring, dark, and the scoop of fabric below it.
	for k in 4:
		var a: float = float(k) * PI * 0.5
		_box(_envelope, "Mouth%d" % k, Vector4(cos(a) * 0.55, -0.02, sin(a) * 0.55, 0.0), Vector4(0.12 if k % 2 == 0 else 1.1, 0.08, 1.1 if k % 2 == 0 else 0.12, 1.1), Color(0.15, 0.12, 0.1))


func _radius_at(profile: Array, y: float) -> float:
	for k in range(profile.size() - 1):
		var a: Array = profile[k]
		var b: Array = profile[k + 1]
		if y <= float(b[0]):
			var u: float = (y - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.0001)
			return lerpf(float(a[1]), float(b[1]), smoothstep(0.0, 1.0, u))
	return float(profile[-1][1])


## The basket: a room in four dimensions, open on top.
func _build_basket() -> void:
	var s: float = 1.3
	var wd: float = 1.3
	var h: float = 1.05
	var t: float = 0.06
	_box(self, "Floor", Vector4(0.0, 0.04, 0.0, 0.0), Vector4(s, 0.08, s, wd), wicker.darkened(0.25))
	for side in [-1.0, 1.0]:
		_box(self, "WallX%d" % int(side), Vector4(side * (s - t) * 0.5, h * 0.5, 0.0, 0.0), Vector4(t, h, s, wd), wicker)
		_box(self, "WallZ%d" % int(side), Vector4(0.0, h * 0.5, side * (s - t) * 0.5, 0.0), Vector4(s, h, t, wd), wicker)
		_box(self, "WallW%d" % int(side), Vector4(0.0, h * 0.5, 0.0, side * (wd - t) * 0.5), Vector4(s, h, s, t), wicker)
		# The leather rim round the top, and the weave as darker bands.
		_box(self, "RimX%d" % int(side), Vector4(side * (s - t) * 0.5, h, 0.0, 0.0), Vector4(t * 1.8, 0.07, s + 0.04, wd), Color(0.28, 0.17, 0.10))
		_box(self, "RimZ%d" % int(side), Vector4(0.0, h, side * (s - t) * 0.5, 0.0), Vector4(s + 0.04, 0.07, t * 1.8, wd), Color(0.28, 0.17, 0.10))
		for b in 3:
			var y: float = 0.22 + 0.27 * float(b)
			_box(self, "WeaveX%d_%d" % [int(side), b], Vector4(side * (s * 0.5 + 0.004), y, 0.0, 0.0), Vector4(0.01, 0.05, s, wd), wicker.darkened(0.2))
			_box(self, "WeaveZ%d_%d" % [int(side), b], Vector4(0.0, y, side * (s * 0.5 + 0.004), 0.0), Vector4(s, 0.05, 0.01, wd), wicker.darkened(0.2))
	_basket_body = StaticBody4D.new()
	_basket_body.name = "BasketBody"
	add_child(_basket_body)
	var shape := CollisionShape4D.new()
	var box := BoxShape4D.new()
	box.size = Vector4(s, h, s, wd)
	shape.shape = box
	shape.position = Vector4(0.0, h * 0.5, 0.0, 0.0)
	_basket_body.add_child(shape)


func _build_burner_and_ropes() -> void:
	var steel := Color(0.35, 0.36, 0.36)
	var top := Vector4(0.0, 2.3, 0.0, 0.0)
	for cx in [-1.0, 1.0]:
		for cz in [-1.0, 1.0]:
			var corner := Vector4(cx * 0.6, 1.05, cz * 0.6, 0.0)
			_strut(self, "Rod", corner, top + Vector4(cx * 0.25, 0.0, cz * 0.25, 0.0), 0.035, 0.3, steel)
			# The ropes, from the basket corners up to the mouth ring.
			_strut(self, "Rope", corner, Vector4(cx * 0.42, 3.0, cz * 0.42, 0.0), 0.025, 0.25, Color(0.55, 0.48, 0.36))
	_box(self, "BurnerFrame", top, Vector4(0.56, 0.05, 0.56, 0.5), steel)
	_box(self, "Burner", top + Vector4(0, 0.14, 0, 0), Vector4(0.24, 0.24, 0.24, 0.24), Color(0.55, 0.56, 0.55))
	_box(self, "Coil", top + Vector4(0, 0.29, 0, 0), Vector4(0.3, 0.06, 0.3, 0.3), Color(0.2, 0.2, 0.2))
	var outer := _box(self, "Flame", top + Vector4(0, 0.62, 0, 0), Vector4(0.24, 0.6, 0.24, 0.24), Color(1.0, 0.55, 0.12))
	var inner := _box(self, "FlameCore", top + Vector4(0, 0.5, 0, 0), Vector4(0.12, 0.4, 0.12, 0.12), Color(1.0, 0.92, 0.55))
	_flame = [outer, inner]
	for f in _flame:
		f.visible = false
	# A gas bottle in the corner.
	_box(self, "Tank", Vector4(0.42, 0.3, -0.42, 0.0), Vector4(0.2, 0.5, 0.2, 0.2), Color(0.72, 0.72, 0.68))


func _build_mooring() -> void:
	# A stake, a tether to it, and sandbags on the rim.
	var stake := Vector4(2.6, 0.0, 1.4, 0.0)
	_tether.append(_box(self, "Stake", stake + Vector4(0, 0.25, 0, 0), Vector4(0.08, 0.5, 0.08, 0.3), Color(0.3, 0.22, 0.14)))
	_tether.append(_strut(self, "Tether", Vector4(0.65, 0.9, 0.3, 0.0), stake + Vector4(0, 0.4, 0, 0), 0.03, 0.25, Color(0.55, 0.48, 0.36)))
	for k in 3:
		_tether.append(_box(self, "Sandbag%d" % k, Vector4(-0.72, 0.55 + 0.0 * float(k), -0.4 + 0.4 * float(k), 0.0), Vector4(0.12, 0.22, 0.16, 0.2), Color(0.66, 0.58, 0.42)))


func _box(parent: Node, part: String, at: Vector4, size: Vector4, colour: Color, basis: Projection = Projection.IDENTITY) -> MeshInstance4D:
	var node := MeshInstance4D.new()
	node.name = part
	var mesh := BoxTetraMesh4D.new()
	mesh.size = size
	node.mesh = mesh
	var material := TetraMaterial4D.new()
	material.albedo_color = colour
	node.material_override = material
	parent.add_child(node, true)
	node.position = at
	if basis != Projection.IDENTITY:
		node.basis = basis
	_own(node)
	return node


func _strut(parent: Node, part: String, a: Vector4, b: Vector4, thick: float, wd: float, colour: Color) -> MeshInstance4D:
	var d: Vector4 = b - a
	var length: float = d.length()
	var y: Vector4 = d / maxf(length, 0.0001)
	var x: Vector4 = Vector4(1, 0, 0, 0) - y * y.x
	if x.length() < 0.2:
		x = Vector4(0, 0, 1, 0) - y * y.z
	x = x.normalized()
	var z: Vector4 = Vector4(0, 0, 1, 0) - y * y.z - x * x.z
	if z.length() < 0.2:
		z = Vector4(1, 0, 0, 0) - y * y.x - x * x.x
	z = z.normalized()
	var w: Vector4 = (Vector4(0, 0, 0, 1) - y * y.w - x * x.w - z * z.w).normalized()
	return _box(parent, part, (a + b) * 0.5, Vector4(thick, length, thick, wd), colour, Projection(x, y, z, w))


func _own(node: Node) -> void:
	if Engine.is_editor_hint() and get_tree() != null and get_tree().edited_scene_root != null:
		node.owner = get_tree().edited_scene_root


# --- For the camera --------------------------------------------------------------------------

## Where the eye is, standing in the basket.
func eye() -> Vector4:
	return global_position + Vector4(0.0, 1.55, 0.0, 0.0)


## Makes it do [param what] now - for the portrait runner: "burn".
func perform(what: String) -> void:
	if what == "burn":
		_burn = 2.5


func _apply_inflation() -> void:
	if _envelope == null:
		return
	var k: float = smoothstep(0.0, 1.0, clampf(_inflate, 0.0, 1.0))
	# Swelling from the mouth: wide first, then tall, as hot air fills it.
	var wide: float = lerpf(0.25, 1.0, smoothstep(0.0, 0.6, k))
	var tall: float = lerpf(0.08, 1.0, k)
	_envelope.basis = Basis4D.from_scale(Vector4(wide, tall, wide, wide))


# --- The ride ---------------------------------------------------------------------------------

## Climb in: the camera to the basket, the burner lit, the tether off.
func board() -> void:
	if riding or not ready_now or lookout == null:
		return
	riding = true
	ride_time = 0.0
	_said = 0
	_hurry = 0.0
	position = _moor
	for t in _tether:
		t.visible = false
	_basket_body.process_mode = Node.PROCESS_MODE_DISABLED
	var station: Node = lookout.get("station")
	station.call("ride", Callable(self, "eye"), 36, 0.0, PI)
	station.call("look_along", Vector4(0.6, 0.35, 1.0, 0.0))
	lookout.call("on_ride_started")
	_burn = 3.0


## Escape in the basket: the first press is Wren telling you how to get down, the second
## brings her straight down.
func hurry() -> void:
	if not riding:
		return
	if _hurry > 0.0:
		ride_time = maxf(ride_time, float(RIDE[-3][0]))
		_said = maxi(_said, RADIO.size() - 2)
		_hurry = 0.0
		lookout.get("radio").call("say", ["Right you are. Taking her down."])
		return
	_hurry = 4.0
	lookout.get("radio").call("say", ["We'll be down in a couple of minutes. Escape again and I'll bring her straight down."])


func burning() -> bool:
	return _burn > 0.0


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_t += delta
	if ready_now and _inflate < 1.0:
		_inflate = minf(_inflate + delta / inflate_seconds, 1.0)
		_apply_inflation()
		if _inflate < 0.95:
			_burn = maxf(_burn, 0.3)
	if _hurry > 0.0:
		_hurry -= delta
	if riding:
		_ride(delta)
	_burn = maxf(_burn - delta, 0.0)
	var lit: bool = _burn > 0.0
	for f in _flame:
		f.visible = lit
		if lit:
			var flick: float = 0.8 + 0.25 * sin(_t * 31.0) + 0.15 * sin(_t * 17.0)
			f.basis = Basis4D.from_scale(Vector4(1.0, flick, 1.0, 1.0))
	_sound_burner(lit, delta)


func _ride(delta: float) -> void:
	ride_time += delta * ride_speed
	var end: float = float(RIDE[-1][0])
	position = _moor + _path(minf(ride_time, end))
	# A slow turn, as a basket under a balloon always has.
	basis = Basis4D.from_zx(sin(ride_time * 0.05) * 0.8)
	# Burner bursts while climbing.
	var ahead: Vector4 = _path(minf(ride_time + 1.0, end)) - _path(minf(ride_time, end))
	if ahead.y > 0.25 * ride_speed and _burn <= 0.0:
		_burn = 1.6
	while _said < RADIO.size() and ride_time >= float(RADIO[_said][0]):
		lookout.get("radio").call("say", RADIO[_said][1])
		_said += 1
	if ride_time >= end:
		_land()


## Catmull-Rom through the ride's points, so it drifts rather than turning corners.
func _path(t: float) -> Vector4:
	var i: int = 0
	while i < RIDE.size() - 2 and t > float(RIDE[i + 1][0]):
		i += 1
	var p1: Vector4 = RIDE[i][1]
	var p2: Vector4 = RIDE[i + 1][1]
	var p0: Vector4 = RIDE[maxi(i - 1, 0)][1]
	var p3: Vector4 = RIDE[mini(i + 2, RIDE.size() - 1)][1]
	var u: float = clampf((t - float(RIDE[i][0])) / maxf(float(RIDE[i + 1][0]) - float(RIDE[i][0]), 0.0001), 0.0, 1.0)
	var u2: float = u * u
	var u3: float = u2 * u
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * u + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * u2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * u3)


func _land() -> void:
	riding = false
	position = _moor
	basis = Projection.IDENTITY
	for t in _tether:
		t.visible = true
	_basket_body.process_mode = Node.PROCESS_MODE_INHERIT
	var station: Node = lookout.get("station")
	var step_out: Vector4 = _moor + Vector4(1.6, 0.05, 1.2, 0.0)
	var tower: Node4D = lookout.get("tower")
	var facing: float = 0.0
	if tower != null:
		var d: Vector4 = tower.global_position - step_out
		facing = atan2(-d.x, -d.z)
	station.call("end_ride", step_out, facing)
	lookout.call("on_ride_ended")
	ride_finished.emit()


func _sound_burner(lit: bool, delta: float) -> void:
	if lookout == null:
		return
	if _burner_sound == null:
		var sounds: Node = lookout.get("sounds")
		if sounds == null or not bool(sounds.call("has", &"burner")):
			return
		_burner_sound = sounds.call("held", &"burner")
		var stream := _burner_sound.stream as AudioStreamWAV
		if stream != null:
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			stream.loop_end = int(stream.get_length() * float(stream.mix_rate))
		_burner_sound.volume_db = -60.0
		_burner_sound.play()
	if not lit and _burner_sound.volume_db <= -59.0:
		return
	# Loud in the basket, distant from the ground.
	var want: float = -60.0
	if lit:
		var cam: Camera4D = lookout.call("current_camera")
		var near: float = 1.0
		if cam != null:
			var d: Vector4 = cam.global_position - global_position
			near = clampf(6.0 / maxf(Vector3(d.x, d.y, d.z).length(), 6.0), 0.05, 1.0)
		want = -4.0 + linear_to_db(near)
	_burner_sound.volume_db = move_toward(_burner_sound.volume_db, want, delta * (160.0 if lit else 60.0))
