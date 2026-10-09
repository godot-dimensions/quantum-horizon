extends Node4D

## WATER LAB: a herring gull (Ramon, 9 Oct: "make them fly up, make them land on one of the poles of the
## walkway and on the rims ... land, look around, fly off again and sit again. I stress the wings needs
## to work. They should look good"). The pieces are gull_body.gd's 4D lofts, baked; this hangs them on
## joints and turns only the joints, every frame (no re-lofting).
##
## THE WINGS (the research in follow_up/water_lab.md): each is an arm (shoulder to wrist) and a hand
## (wrist to tip). The shoulder raises the wing (elevation), swings it fore and aft (sweep) and turns it
## about its own length (twist); the wrist folds the hand back and droops it. With those:
##   FLAP    2.5 beats a second (the herring gull's measured mean), the downstroke 45% of the beat with
##           the wing spread, the upstroke with the wrist folded and the hand swept back (big birds do);
##           the body heaves a little against it.
##   GLIDE   the gull's M: the arms raised a little, the wrists forward, the hands swept back and drooped.
##   FLARE   landing: the body pitched up, the wings high, forward and cupped, the tail fanned down, the
##           feet down; quick shallow back-flaps (about 4 a second, as measured before touchdown).
##   FOLDED  perched: the wings laid back along the body, the black tips crossed just past the tail.
##           Rigid pieces cannot fold in half the way a real wing's Z-fold does, so the arm and hand
##           also shorten along their length as they fold, which reads as folding.
## Every pose is a set of joint angles, and the gull is always a blend of two (the fold one way, the
## flap cycle the other), so nothing snaps.
##
## WHAT IT DOES: soars round the harbour (glides, a few beats now and then, banking into its turns);
## picks a free perch (a rail post, a rail, the pole's top, a door's lintel: the harbour hands them out),
## comes in down the wind, flares, lands; looks round (a head turn every 2 to 5 s), calls now and then
## (the long call: head down, then thrown back), shifts its feet; drops off and flies again.
##
## It flies in its parent's frame; `wind` is where the wind blows FROM. NO class_name (engine_gotchas.md).

signal called(kind: String)

const Body := preload("res://ramon/WaterLab/gull/gull_body.gd")
## The body's origin stands this high over the perch (hip, leg, foot).
const FOOT := 0.136

## Where it flies round (its parent's frame), how high, how far out.
var home := Vector4(10.0, 9.0, 8.0, 0.0)
var roam_radius: float = 22.0
var altitude := Vector2(5.0, 14.0)
var wind := Vector4(1.0, 0.0, 0.0, 0.0)
## Who hands out perches (gull_flock_4d.gd): perch_for(gull), release(gull).
var harbour: Node = null
## Slow motion for the test bed (1 normal).
var time_scale: float = 1.0

var p := Vector4.ZERO
var forward := Vector4(0, 0, 1, 0)
var speed: float = 8.0
var state: String = "roam"
var perch: Dictionary = {}

var _rig: Dictionary = {}
var _t: float = 0.0
var _state_t: float = 0.0
var _flap: float = 0.0
var _flap_phase: float = 0.0
var _flap_rate: float = 2.5
var _flap_bursts: float = 0.0
var _fold: float = 0.0
var _flare: float = 0.0
var _legs: float = 0.0
var _roll: float = 0.0
var _pitch: float = 0.0
var _turn: float = 0.0
var _orbit: float = 0.0
var _target := Vector4.ZERO
## On the final glide in (past the staging point downwind of the perch).
var _final: bool = false
## How long it sits this time (picked on landing).
var _stay: float = 15.0
var _look: float = 0.0
var _look_want: float = 0.0
var _look_t: float = 2.0
var _call_t: float = 0.0
var _call_pose: float = 0.0
var _rng := RandomNumberGenerator.new()
## Microseconds spent in every gull's _process together, ever (the runners take differences).
static var cpu_us: int = 0
## The pose being shown by the test bed, or "" for life.
var forced: String = ""


func _ready() -> void:
	_rng.randomize()
	_build()
	_orbit = _rng.randf() * TAU
	if p == Vector4.ZERO:
		p = home + Vector4(cos(_orbit) * roam_radius, 0.0, sin(_orbit) * roam_radius, 0.0)
	_target = _roam_point()
	_flap_phase = _rng.randf()


# -- the body -------------------------------------------------------------------------------------------

func _build() -> void:
	var mat: TetraMaterial4D = Body.material()
	var root := Node4D.new()
	root.name = "Body"
	add_child(root)
	_rig["body"] = root
	_mesh(root, "BodyMesh", "body", mat)
	_rig["neck"] = _joint(root, "Neck", Body.NECK)
	_mesh(_rig["neck"], "HeadMesh", "head", mat)
	_rig["tail"] = _joint(root, "Tail", Body.TAIL)
	_mesh(_rig["tail"], "TailMesh", "tail", mat)
	for side in ["L", "R"]:
		# The right side is the left turned by from_xw(PI): x and W flipped, a rotation.
		var holder := Node4D.new()
		holder.name = "Side" + side
		if side == "R":
			holder.basis = Basis4D.from_xw(PI)
		root.add_child(holder)
		# Each mesh hangs under its own holder, which alone is scaled (the fold shortens it): the
		# joints under it stay unscaled.
		var shoulder: Node4D = _joint(holder, "Shoulder" + side, Body.SHOULDER)
		var arm := Node4D.new()
		arm.name = "Arm" + side
		shoulder.add_child(arm)
		_mesh(arm, "ArmMesh", "arm", mat)
		var wrist: Node4D = _joint(shoulder, "Wrist" + side, Vector4(Body.ARM, 0.0, 0.0, 0.0))
		var hand := Node4D.new()
		hand.name = "Hand" + side
		wrist.add_child(hand)
		_mesh(hand, "HandMesh", "hand", mat)
		var hip: Node4D = _joint(holder, "Hip" + side, Body.HIP)
		_mesh(hip, "LegMesh", "leg", mat)
		_rig["shoulder" + side] = shoulder
		_rig["arm" + side] = arm
		_rig["wrist" + side] = wrist
		_rig["hand" + side] = hand
		_rig["hip" + side] = hip


func _joint(parent: Node, nm: String, at: Vector4) -> Node4D:
	var j := Node4D.new()
	j.name = nm
	j.position = at
	parent.add_child(j)
	return j


func _mesh(parent: Node, nm: String, piece: String, mat: TetraMaterial4D) -> void:
	var mi := MeshInstance4D.new()
	mi.name = nm
	mi.mesh = Body.mesh(piece)
	mi.material_override = mat
	parent.add_child(mi)


# -- rotations, written out so their signs are plain ---------------------------------------------------------

## +X toward +Y by `a` (raises a wing pointing +X).
static func rot_xy(a: float) -> Projection:
	return Projection(Vector4(cos(a), sin(a), 0, 0), Vector4(-sin(a), cos(a), 0, 0), Vector4(0, 0, 1, 0), Vector4(0, 0, 0, 1))


## +X toward +Z by `a` (swings a wing pointing +X forward).
static func rot_xz(a: float) -> Projection:
	return Projection(Vector4(cos(a), 0, sin(a), 0), Vector4(0, 1, 0, 0), Vector4(-sin(a), 0, cos(a), 0), Vector4(0, 0, 0, 1))


## +Z toward +Y by `a` (lifts the nose, or the leading edge of a wing pointing +X).
static func rot_zy(a: float) -> Projection:
	return Projection(Vector4(1, 0, 0, 0), Vector4(0, cos(a), -sin(a), 0), Vector4(0, sin(a), cos(a), 0), Vector4(0, 0, 0, 1))


static func stretch_x(k: float) -> Projection:
	return Projection(Vector4(k, 0, 0, 0), Vector4(0, 1, 0, 0), Vector4(0, 0, 1, 0), Vector4(0, 0, 0, 1))


## A wing piece's holder: `k` along its length (x), `c` across its chord (z).
static func stretch_xz(k: float, c: float) -> Projection:
	return Projection(Vector4(k, 0, 0, 0), Vector4(0, 1, 0, 0), Vector4(0, 0, c, 0), Vector4(0, 0, 0, 1))


# -- poses ----------------------------------------------------------------------------------------------------

## The wing and body angles of a pose (radians; lengths as a share). The shoulder turns the wing by
## sweep (fore and aft), then elev (up and down), then twist (about its length: + lifts the leading
## edge); the wrist turns the hand by fold (+ forward) and droop (+ up). `chord` shortens the wing pieces
## across, `drop` lowers the shoulders onto the flanks.
## FOLDED, worked out: the arm points straight back (sweep -1.55; pointed out, the wrists stuck out
## past the flanks and the folded wings drew a diamond from above: 9 Oct frames), twisted
## -0.45 so its grey upper side faces up and out (a roof over the back, the two wings meeting at the
## spine as the grey saddle a perched gull shows); the hand runs on back past the tail, turned in its
## own plane (fold -0.32, which in that twisted frame is inward and a little up) so the black tips
## cross over the tail; arm, hand and chord shortened, which reads as folding (rigid pieces cannot
## Z-fold).
static func pose(nm: String, k: float = 0.0) -> Dictionary:
	match nm:
		"folded":
			return {"sweep": -1.55, "elev": 0.0, "twist": -0.45, "fold": -0.32, "droop": -0.09, "arm": 0.55, "hand": 0.78, "chord": 0.5,
				"drop": 1.0, "pitch": 0.08, "tail": 0.0, "fan": 1.0, "legs": 1.0}
		"glide":
			return {"sweep": 0.14, "elev": 0.15, "twist": 0.06, "fold": -0.34, "droop": -0.26, "arm": 1.0, "hand": 1.0, "chord": 1.0,
				"drop": 0.0, "pitch": 0.0, "tail": 0.04, "fan": 1.1, "legs": 0.0}
		"flare":
			return {"sweep": 0.38, "elev": 0.78, "twist": 0.55, "fold": 0.12, "droop": 0.22, "arm": 1.0, "hand": 1.0, "chord": 1.0,
				"drop": 0.0, "pitch": 0.62, "tail": 0.4, "fan": 1.6, "legs": 1.0}
		"flap":
			# k: where in the beat, 0 to 1; the downstroke is the first 45%.
			var down: bool = k < 0.45
			var u: float = k / 0.45 if down else (k - 0.45) / 0.55
			var e: float = smoothstep(0.0, 1.0, u)
			var elev: float = lerpf(0.9, -0.62, e) if down else lerpf(-0.62, 0.9, e)
			var bow: float = sin(PI * u)
			return {"sweep": 0.08 if down else -0.12 * bow, "elev": elev, "twist": -0.12 if down else 0.18 * bow,
				"fold": -0.05 if down else -0.62 * bow, "droop": (-0.1 if down else -0.35) * (1.0 if down else bow), "arm": 1.0, "hand": 1.0,
				"chord": 1.0, "drop": 0.0, "pitch": 0.0, "tail": 0.0, "fan": 1.1, "legs": 0.0, "heave": (0.012 if down else -0.012) * bow}
	return {}


static func blend(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	var out: Dictionary = {}
	for key in a:
		out[key] = lerpf(float(a[key]), float(b.get(key, a[key])), t)
	for key in b:
		if not out.has(key):
			out[key] = lerpf(0.0, float(b[key]), t)
	return out


## The joints set from a pose.
func apply_pose(q: Dictionary) -> void:
	for side in ["L", "R"]:
		var s: Node4D = _rig["shoulder" + side]
		s.position = Body.SHOULDER + Vector4(0.0, -0.03, -0.01, 0.0) * float(q.get("drop", 0.0))
		s.basis = rot_xz(float(q["sweep"])) * rot_xy(float(q["elev"])) * rot_zy(float(q["twist"]))
		var chord: float = float(q.get("chord", 1.0))
		(_rig["arm" + side] as Node4D).basis = stretch_xz(float(q["arm"]), chord)
		var w: Node4D = _rig["wrist" + side]
		w.position = Vector4(Body.ARM * float(q["arm"]), 0.0, 0.0, 0.0)
		w.basis = rot_xz(float(q["fold"])) * rot_xy(float(q["droop"]))
		(_rig["hand" + side] as Node4D).basis = stretch_xz(float(q["hand"]), chord)
		var hip: Node4D = _rig["hip" + side]
		# Legs: tucked forward under the belly in flight (the foot folds up into it), down (and a little
		# forward to land) on a perch.
		hip.basis = rot_zy(lerpf(1.4, 0.2 * _flare, float(q["legs"])))
	var body: Node4D = _rig["body"]
	body.basis = rot_zy(float(q["pitch"]))
	body.position = Vector4(0.0, float(q.get("heave", 0.0)), 0.0, 0.0)
	var tail: Node4D = _rig["tail"]
	tail.basis = rot_zy(float(q["tail"])) * stretch_x(float(q["fan"]))
	var neck: Node4D = _rig["neck"]
	# The head: looking round, and the long call (down, then thrown back).
	var call_pitch: float = 0.0
	if _call_pose > 0.0:
		call_pitch = -0.7 * sin(PI * clampf(_call_pose / 0.4, 0.0, 1.0)) if _call_pose < 0.4 else 0.9 * sin(PI * clampf((_call_pose - 0.4) / 1.6, 0.0, 1.0))
	neck.basis = rot_xz(_look) * rot_zy(call_pitch - float(q["pitch"]) * 0.8)


# -- life ------------------------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	var t0: int = Time.get_ticks_usec()
	_live(delta)
	cpu_us += Time.get_ticks_usec() - t0


func _live(delta: float) -> void:
	var dt: float = minf(delta, 0.05) * time_scale
	_t += dt
	_state_t += dt
	if not forced.is_empty():
		_show_forced(dt)
		return
	match state:
		"roam":
			_roam(dt)
		"approach":
			_approach(dt)
		"flare":
			_do_flare(dt)
		"perched":
			_perched(dt)
		"takeoff":
			_takeoff(dt)
	_head(dt)
	_pose_now(dt)
	_place()


func _roam_point() -> Vector4:
	_orbit += _rng.randf_range(0.6, 1.4)
	var r: float = roam_radius * _rng.randf_range(0.4, 1.0)
	return home + Vector4(cos(_orbit) * r, _rng.randf_range(altitude.x, altitude.y) - home.y, sin(_orbit) * r, 0.0)


func _roam(dt: float) -> void:
	if (p - _target).length() < 4.0:
		_target = _roam_point()
	_fly_toward(_target, 8.5, dt, 1.2)
	# Climbing or slow: beat; otherwise glide, with a burst of beats now and then.
	_flap_bursts -= dt
	if _flap_bursts < -_rng.randf_range(3.0, 7.0):
		_flap_bursts = _rng.randf_range(0.8, 1.8)
	var climbing: bool = forward.y > 0.08
	_flap = move_toward(_flap, 1.0 if (_flap_bursts > 0.0 or climbing) else 0.0, dt * 3.0)
	_fold = move_toward(_fold, 0.0, dt * 2.0)
	_flare = move_toward(_flare, 0.0, dt * 2.0)
	_legs = move_toward(_legs, 0.0, dt * 1.5)
	if _state_t > 10.0 and harbour != null and _rng.randf() < dt * 0.12:
		var pr: Dictionary = harbour.call("perch_for", self)
		if not pr.is_empty():
			perch = pr
			state = "approach"
			_state_t = 0.0
			_final = false


## Into the wind onto the perch (`wind` is where it blows FROM, so a gull lands facing it): first to a
## point downwind of the perch and above it, then the final glide straight in, legs coming down.
func _approach(dt: float) -> void:
	var at: Vector4 = perch["pos"] + Vector4(0.0, FOOT, 0.0, 0.0)
	var into: Vector4 = _into_wind()
	var stage: Vector4 = at - into * 9.0 + Vector4(0.0, 3.0, 0.0, 0.0)
	if not _final:
		if (p - stage).length() < 4.0 or _state_t > 25.0:
			_final = true
		else:
			_fly_toward(stage, 8.0, dt, 1.4)
			_flap = move_toward(_flap, 1.0 if forward.y > 0.05 else 0.25, dt * 2.0)
			return
	_fly_toward(at + Vector4(0.0, 0.15, 0.0, 0.0), lerpf(3.0, 7.0, clampf((p - at).length() / 10.0, 0.0, 1.0)), dt, 2.2)
	_flap = move_toward(_flap, 0.0, dt * 2.0)
	_legs = move_toward(_legs, 1.0 if (p - at).length() < 6.0 else 0.0, dt * 1.2)
	if (p - at).length() < 2.6:
		state = "flare"
		_state_t = 0.0
	elif _state_t > 45.0:
		# Could not get in (blown off its line): gives the perch back and flies on.
		if harbour != null:
			harbour.call("release", self)
		state = "roam"
		_state_t = 0.0


## Level, into the wind (or its heading when the wind is straight up or down).
func _into_wind() -> Vector4:
	var h := Vector4(wind.x, 0.0, wind.z, 0.0)
	return h.normalized() if h.length() > 0.05 else Vector4(forward.x, 0.0, forward.z, 0.0).normalized()


## The flare: pitched up, braking with quick back-flaps, onto the perch.
func _do_flare(dt: float) -> void:
	var at: Vector4 = perch["pos"] + Vector4(0.0, FOOT, 0.0, 0.0)
	_flare = move_toward(_flare, 1.0, dt * 3.5)
	_legs = 1.0
	_turn_to(_perch_face(), 4.0, dt)
	var to: Vector4 = at - p
	var step: float = minf(to.length(), maxf(speed, 0.6) * dt)
	speed = move_toward(speed, 0.4, dt * 4.0)
	if to.length() > 0.001:
		p += to.normalized() * step
	if to.length() < 0.03 or _state_t > 1.6:
		p = at
		state = "perched"
		_state_t = 0.0
		_flap = 0.0
		_stay = _rng.randf_range(float(perch.get("stay_min", 10.0)), float(perch.get("stay_max", 28.0)))
		called.emit("land")


## Which way it faces on its perch: the perch's own way if it has one, else into the wind.
func _perch_face() -> Vector4:
	var f: Vector4 = perch.get("face", _into_wind())
	f = Vector4(f.x, 0.0, f.z, 0.0)
	return f.normalized() if f.length() > 0.05 else _into_wind()


## Turns the heading toward `dir` (level) at `rate` rad/s.
func _turn_to(dir: Vector4, rate: float, dt: float) -> void:
	var f := Vector4(forward.x, 0.0, forward.z, 0.0)
	f = f.normalized() if f.length() > 0.05 else dir
	var a: float = atan2(f.x, f.z)
	var b: float = atan2(dir.x, dir.z)
	var d: float = wrapf(b - a, -PI, PI)
	var n: float = a + clampf(d, -rate * dt, rate * dt)
	forward = Vector4(sin(n), 0.0, cos(n), 0.0)


func _perched(dt: float) -> void:
	_turn_to(_perch_face(), 2.0, dt)
	_flare = move_toward(_flare, 0.0, dt * 1.5)
	_fold = move_toward(_fold, 1.0, dt * 1.1)
	_legs = 1.0
	speed = 0.0
	_flap = 0.0
	_call_t -= dt
	if _call_t <= 0.0:
		_call_t = _rng.randf_range(6.0, 16.0)
		if _rng.randf() < 0.55 and _call_pose <= 0.0:
			_call_pose = 0.001
			called.emit("long" if _rng.randf() < 0.6 else "laugh")
	if _state_t > _stay and _call_pose <= 0.0:
		state = "takeoff"
		_state_t = 0.0
		if harbour != null:
			harbour.call("release", self)
		called.emit("kek")


## Something came too close: off at once, with the alarm.
func flush() -> void:
	if state != "perched":
		return
	_call_pose = 0.0
	state = "takeoff"
	_state_t = 0.0
	if harbour != null:
		harbour.call("release", self)
	called.emit("kek")


## Off the perch: a crouch, a hop into the wind, deep beats, climbing away.
func _takeoff(dt: float) -> void:
	_fold = move_toward(_fold, 0.0, dt * 4.0)
	if _state_t < 0.18:
		return
	_flap = 1.0
	_flap_rate = 3.6
	var want: Vector4 = (_into_wind() + Vector4(0.0, 0.55, 0.0, 0.0)).normalized()
	forward = forward.lerp(want, 1.0 - exp(-3.0 * dt)).normalized()
	speed = move_toward(speed, 7.0, dt * 6.0)
	p += forward * speed * dt
	_legs = move_toward(_legs, 0.0, dt * 1.2)
	if _state_t > 2.2:
		state = "roam"
		_state_t = 0.0
		_flap_rate = 2.5
		_target = _roam_point()


## Steering in flight: the heading turns toward the point at no more than `rate` rad/s; it banks with
## the turn and pitches with the climb.
func _fly_toward(at: Vector4, want_speed: float, dt: float, rate: float) -> void:
	var to: Vector4 = at - p
	to.w = -p.w
	var want: Vector4 = to.normalized() if to.length() > 0.001 else forward
	want.y = clampf(want.y, -0.45, 0.45)
	want = want.normalized()
	var c: float = clampf(forward.dot(want), -1.0, 1.0)
	var ang: float = acos(c)
	var before: Vector4 = forward
	if ang > 0.0005:
		var perp: Vector4 = want - forward * c
		if perp.length() > 0.0001:
			var stp: float = minf(ang, rate * dt)
			forward = (forward * cos(stp) + perp.normalized() * sin(stp)).normalized()
	var right := Vector4(forward.z, 0.0, -forward.x, 0.0)
	right = right.normalized() if right.length() > 0.05 else Vector4(1, 0, 0, 0)
	_turn = lerpf(_turn, (forward - before).dot(right) / maxf(dt, 0.0001), 1.0 - exp(-4.0 * dt))
	speed = move_toward(speed, want_speed, dt * 2.5)
	p += forward * speed * dt


func _head(dt: float) -> void:
	if _call_pose > 0.0:
		_call_pose += dt
		if _call_pose > 2.0:
			_call_pose = 0.0
	_look_t -= dt
	if _look_t <= 0.0:
		_look_t = _rng.randf_range(2.0, 5.0) if state == "perched" else _rng.randf_range(3.0, 7.0)
		_look_want = _rng.randf_range(-1.4, 1.4) if state == "perched" else _rng.randf_range(-0.4, 0.4)
	_look = lerpf(_look, _look_want, 1.0 - exp(-6.0 * dt))


## The pose now: the flap cycle or the glide, blended toward the flare and the fold.
func _pose_now(dt: float) -> void:
	var rate: float = _flap_rate if _flare < 0.5 else 4.0
	_flap_phase = fmod(_flap_phase + dt * rate, 1.0)
	var flying: Dictionary = pose("glide")
	if _flap > 0.0:
		var f: Dictionary = pose("flap", _flap_phase)
		flying = blend(flying, f, _flap)
	if _flare > 0.0:
		var fl: Dictionary = pose("flare")
		# Back-flaps while flaring: shallow beats on top of the flare pose.
		var back: Dictionary = blend(fl, pose("flap", _flap_phase), 0.25)
		flying = blend(flying, back, _flare)
	var q: Dictionary = blend(flying, pose("folded"), _fold)
	q["legs"] = maxf(float(q["legs"]), _legs)
	apply_pose(q)


## Where the gull is and which way it faces: banked into its turns while it flies, level on a perch.
func _place() -> void:
	position = p
	var f: Vector4 = forward
	var flying: bool = state != "perched"
	_roll = lerpf(_roll, clampf(-_turn * 0.55, -0.7, 0.7) if flying else 0.0, 0.1)
	var up := Vector4(0, 1, 0, 0) - f * f.y
	up = up.normalized() if up.length() > 0.05 else Vector4(0, 1, 0, 0)
	var right := Vector4(f.z, 0.0, -f.x, 0.0)
	right = (right - up * right.dot(up) - f * right.dot(f))
	right = right.normalized() if right.length() > 0.05 else Vector4(1, 0, 0, 0)
	var r2: Vector4 = right * cos(_roll) + up * sin(_roll)
	var u2: Vector4 = up * cos(_roll) - right * sin(_roll)
	var w := Vector4(0, 0, 0, 1)
	basis = Projection(r2, u2, f, w)


## The test bed's poses: "glide", "flap", "flare", "folded", or "flight" (life, in place).
func _show_forced(dt: float) -> void:
	_flap_phase = fmod(_flap_phase + dt * 2.5, 1.0)
	var q: Dictionary
	match forced:
		"flap":
			q = pose("flap", _flap_phase)
		"flare":
			_flare = 1.0
			q = blend(pose("flare"), pose("flap", _flap_phase), 0.25)
		"folded":
			_fold = 1.0
			q = pose("folded")
		_:
			q = pose(forced)
	if q.is_empty():
		q = pose("glide")
	_head(dt)
	apply_pose(q)
	position = p
	basis = Projection(Vector4(forward.z, 0, -forward.x, 0).normalized(), Vector4(0, 1, 0, 0), forward, Vector4(0, 0, 0, 1))
