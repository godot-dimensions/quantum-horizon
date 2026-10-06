extends "res://ramon/QuantumRange/scripts/range_target_4d.gd"

## THE WOLF (06 Wolf Run): the pen's wolf in rigid pieces (range_wolf.gd), running a route across the
## range. It wears a collar: red for the one to tag (its body is the core, one quick shot, and it is gone
## in a holodeck scan), green for one to leave alone (a penalty).
##
## HOW IT MOVES. Every piece moves by transform only, every frame; nothing is re-lofted or re-skinned.
##   GALLOP (fast): a rotary gallop, as dogs and wolves run: hind left, hind right, fore right, fore
##     left, each foot down for under a third of the stride, then all four up in the gathered
##     suspension. About 2.3 strides a second at 6.5 m/s, so a stride of nearly three metres. Each foot
##     is PLANTED where it lands and stays there while the body passes over it (two-joint leg solving,
##     knee behind the line, the way both of a wolf's leg joints bend), so the feet never skate. The
##     back flexes and stretches at the barrel, the body rocks, heaves at the suspension, leans into
##     turns; the head stays low and steady; the tail streams behind.
##   TROT (slower): diagonal pairs together, a lighter bounce.
##   LEAP: it gathers (the body dips, the hind feet come under), pushes off, flies on a true arc with
##     its forelegs tucked and then reaching for the ground and its hind legs stretched back, lands
##     front feet first and runs on.
##   CATCH (the chase): it slows to a trot as it closes, pounces (a short leap, head down, jaw open),
##     snaps the jaw shut on the chicken, lifts its head and shakes it, stands a moment, and lopes off
##     with the bird in its mouth, still flapping.
##
## A route is a list of steps, run in turn (the experiment writes them):
##   {"run": Vector4, "speed": m/s}    to a point on the floor; its w is reached on the way (the run
##                                      out of the slice the pen's wolf is known for)
##   {"leap": Vector4, "height": m}     over something, landing at the point
##   {"pounce": chicken}                after the bird, and the catch
##   {"wait": seconds}
## When the route runs out it leaves, unless `loop` is on.

const Wolf := preload("res://ramon/QuantumRange/scripts/range_wolf.gd")
const Shapes := preload("res://ramon/QuantumRange/scripts/range_shapes.gd")

## Bigger than the pen's (0.8 m at the shoulder): a holodeck dire wolf, 1.3 m at the shoulder, that reads
## across the range (at 1.25 it was a speck at fifteen metres, play/wolf_0_play, 6 Oct).
var size: float = 1.6
## "red": the one to tag. "green": one to leave alone.
var collar: String = "red"
var route: Array = []
var loop: bool = false
## Seconds before it sets off (a pack staggers).
var delay: float = 0.0
## Set when it has caught its chicken (the chase fails there).
var caught: bool = false
## The chicken it carries, once caught.
var prey: Node4D

const G := -9.8
## Rotary gallop: [hind L, hind R, fore R, fore L] touch down at these fractions of the stride.
const GALLOP := {"HindL": 0.0, "HindR": 0.1, "ForeR": 0.42, "ForeL": 0.52}
## Trot: diagonal pairs.
const TROT := {"ForeL": 0.0, "HindR": 0.0, "ForeR": 0.5, "HindL": 0.5}

var _body: Node4D
var _front: Node4D
var _rear: Node4D
var _neck: Node4D
var _jaw: Node4D
var _mouth: Node4D
var _tail1: Node4D
var _tail2: Node4D
var _legs: Array = []          # dicts, below
var _heading: float = 0.0
var _speed: float = 0.0
var _want_speed: float = 0.0
var _cycle: float = 0.0
var _step: int = 0
var _step_t: float = 0.0
var _leap: Dictionary = {}     # {from, to, height, t, dur, gather, land, pounce}
var _act: String = "run"       # run / leap / shake / stand
var _act_t: float = 0.0
var _jaw_open: float = 0.0
var _turn_rate: float = 0.0
var _flex: float = 0.0
var _w_from: float = 0.0
var _run_from: Vector4 = Vector4.ZERO
var _tail_lag: Vector2 = Vector2.ZERO


func build() -> void:
	family = "wolf"
	var s: float = size
	var p: Dictionary = Wolf.pieces()
	var spine: Vector4 = Wolf.SPINE
	# The hitbox: the body and head, legs tucked; it is the part (core or friend), everything hangs off it.
	var role: String = "core" if collar == "red" else "friend"
	var core: Dictionary = add_part("Wolf", role, null, Vector4(0.42, 0.62, 1.45, 0.5) * s, {"radar": true, "at": Vector4(0.0, spine.y, spine.z, 0.0) * s})
	_body = core["node"]
	_front = _joint(_body, "Front", Vector4.ZERO)
	_rear = _joint(_body, "Rear", Vector4.ZERO)
	_piece("Front", _front, p, Vector4.ZERO)
	_piece("Rear", _rear, p, Vector4.ZERO)
	# The head on its neck, its parts, the jaw and the mouth.
	_neck = _joint(_front, "Neck", (Wolf.NECK - spine) * s)
	for nm in ["Head", "Snout", "NoseTip"]:
		_piece(nm, _neck, p, Vector4.ZERO)
	_piece("Ear", _neck, p, Vector4.ZERO)
	_piece("Ear", _neck, p, Vector4.ZERO, true)
	for side in [1.0, -1.0]:
		var eye := Vector4(Wolf.EYE.x * side, Wolf.EYE.y, Wolf.EYE.z, 0.0) - Wolf.NECK
		var e: Dictionary = add_part("Eye" + ("L" if side > 0.0 else "R"), "cover", Shapes.box(Wolf.EYE_SIZE * s), Vector4.ZERO, {"parent": _neck, "radar": false, "material": Mats.lit(Wolf.EYE_COLOR)})
		(e["mesh"] as MeshInstance4D).position = eye * s
	_jaw = _joint(_neck, "JawHinge", (Wolf.JAW - Wolf.NECK) * s)
	_piece("Jaw", _jaw, p, Vector4.ZERO)
	_mouth = _joint(_jaw, "Mouth", (Wolf.MOUTH - Wolf.JAW) * s)
	# The collar: a band of its colour round the neck, and a tag hanging at the front.
	var c: Color = Color(0.95, 0.12, 0.10) if collar == "red" else Color(0.15, 0.85, 0.35)
	var band: Dictionary = add_part("Collar", "cover", Shapes.ball(), Vector4.ZERO, {"parent": _front, "radar": false, "material": Mats.glow(c, 1.4),
		"basis": Basis4D.from_yz(-0.45) * Basis4D.from_scale(Vector4(0.15, 0.035, 0.12, 0.12) * s)})
	(band["mesh"] as MeshInstance4D).position = (Vector4(0, 0.71, 0.43, 0) - spine) * s
	var tag: Dictionary = add_part("Tag", "cover", Shapes.ball(), Vector4.ZERO, {"parent": _front, "radar": false, "material": Mats.glow(c, 1.8),
		"basis": Basis4D.from_scale_uniform(0.045 * s)})
	(tag["mesh"] as MeshInstance4D).position = (Vector4(0, 0.6, 0.5, 0) - spine) * s
	# The tail in two.
	_tail1 = _joint(_rear, "Tail1", (Wolf.TAIL_ROOT - spine) * s)
	_piece("Tail1", _tail1, p, Vector4.ZERO)
	_tail2 = _joint(_tail1, "Tail2", (Wolf.TAIL_MID - Wolf.TAIL_ROOT) * s)
	_piece("Tail2", _tail2, p, Vector4.ZERO)
	# The legs: fore on the front half, hind on the rear; the right ones are the left ones' meshes (a leg
	# is lofted about its own hip, x = 0, so it is its own mirror).
	for kind in ["Fore", "Hind"]:
		var parent: Node4D = _front if kind == "Fore" else _rear
		var hip_at: Vector4 = Wolf.BALL[kind + "Hip"][0]
		var knee_at: Vector4 = Wolf.BALL[kind + "Knee"][0]
		var foot_at: Vector4 = Wolf.BALL[kind + "Foot"][0]
		for side in [1.0, -1.0]:
			var nm: String = kind + ("L" if side > 0.0 else "R")
			var hip := _joint(parent, nm + "Hip", (Vector4(hip_at.x * side, hip_at.y, hip_at.z, 0.0) - spine) * s)
			_piece(kind + "Upper", hip, p, Vector4.ZERO)
			var knee := _joint(hip, nm + "Knee", (knee_at - hip_at) * s)
			_piece(kind + "Lower", knee, p, Vector4.ZERO)
			var th0 := Vector2(knee_at.y - hip_at.y, knee_at.z - hip_at.z)
			var sh0 := Vector2(foot_at.y - knee_at.y, foot_at.z - knee_at.z)
			_legs.append({"name": nm, "kind": kind, "side": side, "parent": parent, "hip": hip, "knee": knee,
				"l1": th0.length() * s, "l2": sh0.length() * s, "th0": atan2(th0.y, th0.x), "sh0": atan2(sh0.y, sh0.x),
				"plant": Vector4.ZERO, "planted": false, "lift": Vector4.ZERO, "rest": Vector2(foot_at.y - hip_at.y, foot_at.z - hip_at.z) * s})
	# Facing its first point already, rather than turning on the spot as it appears.
	_heading = 0.0
	if not route.is_empty() and (route[0] as Dictionary).has("run"):
		var to: Vector4 = route[0]["run"]
		_heading = atan2(to.x - position.x, to.z - position.z)
	_run_from = position


func _joint(parent: Node4D, nm: String, at: Vector4) -> Node4D:
	var j := Node4D.new()
	j.name = nm
	j.position = at
	parent.add_child(j)
	return j


func _piece(nm: String, parent: Node4D, p: Dictionary, at: Vector4, mirror: bool = false) -> void:
	var entry: Array = p[nm]
	var d: Dictionary = add_part(nm + ("R" if mirror else ""), "cover", entry[0], Vector4.ZERO, {"parent": parent, "radar": false,
		"material": Mats.lit(entry[1]), "basis": (Basis4D.from_xw(PI) if mirror else Projection.IDENTITY) * Basis4D.from_scale_uniform(size)})
	(d["mesh"] as MeshInstance4D).position = at


func on_hit(p: Dictionary, outcome: String) -> void:
	if outcome == "pop" or outcome == "penalty":
		var c: Color = Color(0.95, 0.2, 0.15) if outcome == "pop" else Color(0.2, 0.9, 0.4)
		Fx.burst(get_parent(), (p["node"] as Node4D).global_position, c, 26, 0.06, 3.0)


## Tagged: the holodeck takes it (the base's scan and shrink). A chicken in its mouth is let go and
## runs off, away from where the wolf was heading.
func destroy() -> void:
	if prey != null and is_instance_valid(prey) and bool(prey.get("alive")):
		var bird: Node4D = prey
		var from: Vector4 = bird.global_position
		from.y = 1.05 * float(bird.get("size"))
		var away: Vector4 = -_fwd()
		var age0: float = float(bird.get("age"))
		bird.global_basis = Projection.IDENTITY
		bird.set("held", false)
		bird.set("running", true)
		bird.set("path", func(_t: Node4D, a: float) -> Vector4: return from + away * 3.4 * (a - age0))
		bird.set("lifetime", age0 + 3.0)
	prey = null
	super()


## Gone without being tagged (its run is over): what it carries goes with it.
func leave() -> void:
	if prey != null and is_instance_valid(prey):
		prey.call("leave")
	prey = null
	super()


# -- the route ---------------------------------------------------------------------------------------

func _fwd() -> Vector4:
	return Vector4(sin(_heading), 0.0, cos(_heading), 0.0)


func _next_step() -> void:
	_step += 1
	_step_t = 0.0
	_run_from = position
	if _step >= route.size():
		if loop and not route.is_empty():
			_step = 0
		else:
			leave()


func _follow(dt: float) -> void:
	if _step >= route.size():
		_want_speed = 0.0
		return
	var st: Dictionary = route[_step]
	_step_t += dt
	if st.has("wait"):
		_want_speed = 0.0
		if _step_t >= float(st["wait"]):
			_next_step()
		return
	if st.has("leap"):
		if _leap.is_empty():
			_start_leap(st["leap"], float(st.get("height", 0.8)), false)
		return
	if st.has("pounce"):
		var bird: Node4D = st["pounce"]
		if bird == null or not is_instance_valid(bird) or not bool(bird.get("alive")):
			_next_step()
			return
		var to: Vector4 = bird.global_position
		var d: float = Vector2(to.x - position.x, to.z - position.z).length()
		var bv: Vector4 = bird.get("_v")
		var flee: float = Vector2(bv.x, bv.z).length()
		_steer(to, dt)
		# Closing in: always faster than the bird, easing off as it gets near; then the pounce from about
		# two metres, aimed at where the bird will be when it lands.
		_want_speed = clampf(flee + 1.5 + (d - 2.0) * 0.5, flee + 1.2, 7.5)
		position.w = move_toward(position.w, to.w, dt * 1.5)
		if d < 1.7 * size and _leap.is_empty():
			var fly: float = 0.16 + maxf(0.3, d / maxf(_speed, 4.5))
			var ahead: Vector4 = to + Vector4(bv.x, 0.0, bv.z, 0.0) * fly
			var dir2 := Vector2(ahead.x - position.x, ahead.z - position.z).normalized()
			var land: Vector4 = ahead - Vector4(dir2.x, 0.0, dir2.y, 0.0) * (Wolf.MOUTH.z - Wolf.SPINE.z) * size
			_start_leap(Vector4(land.x, 0.0, land.z, to.w), 0.3 * size, true, bird)
		return
	var target: Vector4 = st["run"]
	_want_speed = float(st.get("speed", 6.5))
	_steer(target, dt)
	var total: float = maxf(0.01, Vector2(target.x - _run_from.x, target.z - _run_from.z).length())
	var left: float = Vector2(target.x - position.x, target.z - position.z).length()
	position.w = lerpf(_run_from.w, target.w, clampf(1.0 - left / total, 0.0, 1.0))
	if left < 0.9:
		_next_step()


func _steer(to: Vector4, dt: float) -> void:
	var d := Vector2(to.x - position.x, to.z - position.z)
	if d.length() < 0.05:
		return
	var want: float = atan2(d.x, d.y)
	var before: float = _heading
	_heading = rotate_toward(_heading, want, dt * 2.6)
	_turn_rate = lerpf(_turn_rate, angle_difference(before, _heading) / maxf(dt, 0.0001), 1.0 - exp(-dt * 8.0))


func _start_leap(to: Vector4, height: float, pounce: bool, bird: Node4D = null) -> void:
	var from := Vector4(position.x, 0.0, position.z, position.w)
	var dist: float = Vector2(to.x - from.x, to.z - from.z).length()
	var v: float = maxf(_speed, 4.5)
	_leap = {"from": from, "to": to, "height": height, "t": 0.0, "gather": 0.12 if not pounce else 0.16, "dur": maxf(0.3, dist / v),
		"land": 0.16, "pounce": pounce, "bird": bird}
	_act = "leap"


# -- every frame -------------------------------------------------------------------------------------

func animate(t: float, dt: float) -> void:
	if dt <= 0.0:
		return
	if t < delay:
		visible = false
		return
	visible = true
	_act_t += dt
	if _act == "run":
		_follow(dt)
	_speed = move_toward(_speed, _want_speed, dt * (9.0 if _want_speed > _speed else 6.0))
	var body_pitch: float = 0.0     # nose up, radians
	var bob: float = 0.0
	var head_down: float = 0.1
	var crouch: float = 0.0
	var air: Dictionary = {}        # leg name -> local target from its hip (y, z), when not on the ground
	match _act:
		"run":
			position += _fwd() * _speed * dt
			position.y = 0.0
		"leap":
			var lp: Dictionary = _leap
			lp["t"] = float(lp["t"]) + dt
			var lt: float = float(lp["t"])
			var g: float = float(lp["gather"])
			var fly: float = float(lp["dur"])
			if lt < g:
				# The gather: it dips and brings its hind feet under, slowing a little.
				var k: float = lt / g
				crouch = 0.09 * size * sin(PI * 0.5 * k)
				position += _fwd() * _speed * 0.7 * dt
				_flex = lerpf(_flex, 0.16, 1.0 - exp(-dt * 20.0))
				head_down = 0.25 if bool(lp["pounce"]) else 0.12
				_jaw_open = 0.3 * k if bool(lp["pounce"]) else _jaw_open
				for l in _legs:
					if String(l["kind"]) == "Hind":
						air[l["name"]] = (l["rest"] as Vector2) * Vector2(0.75, 1.0) + Vector2(0.0, 0.18 * size)
				if lt + dt >= g:
					lp["from"] = Vector4(position.x, 0.0, position.z, position.w)
			elif lt < g + fly:
				# The flight: a true arc; forelegs tucked, then reaching; hind legs pushed back.
				var s2: float = (lt - g) / fly
				var a: Vector4 = lp["from"]
				var b: Vector4 = lp["to"]
				position = a.lerp(b, s2)
				position.y = 4.0 * float(lp["height"]) * s2 * (1.0 - s2)
				var vy: float = 4.0 * float(lp["height"]) * (1.0 - 2.0 * s2) / fly
				var vh: float = Vector2(b.x - a.x, b.z - a.z).length() / fly
				body_pitch = clampf(atan2(vy, vh) * 0.75, -0.5, 0.5)
				_flex = lerpf(_flex, -0.12, 1.0 - exp(-dt * 10.0))
				var reach: float = smoothstep(0.35, 0.85, s2)
				for l in _legs:
					var nm: String = l["name"]
					if String(l["kind"]) == "Fore":
						air[nm] = Vector2(-0.3, 0.12).lerp(Vector2(-0.44, 0.3), reach) * size
					elif bool(lp["pounce"]):
						# A short hop: the hind feet leave the ground but stay under it, ready to land.
						air[nm] = Vector2(-0.46, -0.12).lerp(Vector2(-0.44, -0.2), smoothstep(0.0, 0.5, s2)) * size
					else:
						air[nm] = Vector2(-0.42, -0.3).lerp(Vector2(-0.36, -0.42), smoothstep(0.0, 0.5, s2)) * size
				if bool(lp["pounce"]):
					head_down = 0.42
					_jaw_open = lerpf(0.3, 0.7, smoothstep(0.0, 0.6, s2))
				else:
					head_down = 0.05 - body_pitch * 0.5
			elif lt < g + fly + float(lp["land"]):
				# The landing: front feet first, the body absorbing it.
				var k2: float = (lt - g - fly) / float(lp["land"])
				position = lp["to"]
				position.y = 0.0
				position += _fwd() * _speed * 0.4 * k2 * dt
				crouch = 0.08 * size * sin(PI * k2)
				body_pitch = -0.12 * sin(PI * k2)
				_flex = lerpf(_flex, 0.1, 1.0 - exp(-dt * 12.0))
				if bool(lp["pounce"]):
					head_down = 0.42
					# The snap: the jaw shuts on the bird the moment it lands.
					_jaw_open = move_toward(_jaw_open, 0.06, dt * 12.0)
					var bird: Node4D = lp["bird"]
					if prey == null and bird != null and is_instance_valid(bird) and bool(bird.get("alive")):
						prey = bird
						bird.set("held", true)
						# It goes when the wolf does, not on its own clock.
						bird.set("lifetime", 0.0)
						caught = true
			else:
				for l in _legs:
					l["planted"] = false
				_leap = {}
				if prey != null:
					_act = "shake"
					_act_t = 0.0
					_speed = 0.0
				else:
					_act = "run"
					_next_step()
		"shake":
			# Head up, a hard shake, a moment still; then off with it.
			_want_speed = 0.0
			var k3: float = _act_t / 0.55
			head_down = lerpf(0.3, -0.25, smoothstep(0.0, 0.25, k3))
			crouch = 0.03 * size
			if _act_t > 1.0:
				_act = "run"
				_next_step()
	_cycle += dt * _stride_rate()
	_gait(dt, body_pitch, bob, head_down, crouch, air)
	_carry()


## Strides a second: galloping, about 2.3 at 6.5 m/s; trotting, a quicker 2.6.
func _stride_rate() -> float:
	if _speed > 4.2:
		return 2.3 + 0.06 * (_speed - 6.5)
	if _speed > 0.3:
		return 2.6 * clampf(_speed / 2.5, 0.6, 1.2)
	return 0.0


func _gait(dt: float, pitch_extra: float, _bob_extra: float, head_down: float, crouch: float, air: Dictionary) -> void:
	var s: float = size
	var galloping: bool = _speed > 4.2
	var trotting: bool = not galloping and _speed > 0.3
	var offs: Dictionary = GALLOP if galloping else TROT
	var duty: float = 0.3 if galloping else 0.45
	var ph: float = fposmod(_cycle, 1.0)
	# The body: heave at the gathered suspension, rock nose-up at the hind push, flex at the barrel.
	var bob: float = 0.0
	var rock: float = 0.0
	var flex_want: float = 0.0
	if galloping:
		bob = 0.05 * s * cos(TAU * (ph - 0.85))
		rock = 0.07 * sin(TAU * (ph - 0.12))
		flex_want = 0.13 * cos(TAU * (ph - 0.9))
	elif trotting:
		bob = 0.018 * s * cos(TAU * 2.0 * (ph - 0.2))
		flex_want = 0.03 * cos(TAU * 2.0 * ph)
	if _leap.is_empty():
		_flex = lerpf(_flex, flex_want, 1.0 - exp(-dt * 14.0))
	var roll: float = clampf(_turn_rate * _speed * 0.035, -0.3, 0.3)
	var pitch: float = rock + pitch_extra
	basis = Basis4D.from_zx(_heading) * Basis4D.from_xy(-roll)
	_body.position = Vector4(0.0, Wolf.SPINE.y * s + bob - crouch, Wolf.SPINE.z * s, 0.0)
	_body.basis = Basis4D.from_yz(-pitch)
	_front.basis = Basis4D.from_yz(_flex * 0.5)
	_rear.basis = Basis4D.from_yz(-_flex * 0.5)
	# The head: low and steady, taking back the body's rock and the front's flex.
	var nod: float = 0.04 * sin(TAU * (ph - 0.3)) if galloping else 0.0
	var shake: float = 0.0
	if _act == "shake":
		shake = 0.42 * sin(_act_t * 24.0) * exp(-_act_t * 3.5) if _act_t < 0.7 else 0.0
	_neck.basis = Basis4D.from_zx(shake) * Basis4D.from_yz(head_down + nod + pitch - _flex * 0.5)
	_jaw.basis = Basis4D.from_yz(_jaw_open)
	if _act != "leap" or not bool(_leap.get("pounce", false)):
		_jaw_open = move_toward(_jaw_open, 0.18 if (galloping and prey == null) else 0.04, dt * 2.0)
	# The tail: streaming back when it runs, hanging when it stands; the second piece lags the first.
	var run_k: float = clampf(_speed / 6.5, 0.0, 1.0)
	var lift: float = lerpf(0.0, 0.6, run_k) + 0.1 * sin(TAU * (ph - 0.2)) * run_k
	var wag: float = 0.08 * sin(TAU * ph * 2.0) * run_k - roll * 0.6
	_tail_lag = _tail_lag.lerp(Vector2(lift, wag), 1.0 - exp(-dt * 7.0))
	_tail1.basis = Basis4D.from_zx(_tail_lag.y) * Basis4D.from_yz(_tail_lag.x)
	_tail2.basis = Basis4D.from_zx(_tail_lag.y * 0.8) * Basis4D.from_yz((lift - _tail_lag.x) * 0.8 + 0.15 * run_k)
	# The legs.
	var fwd: Vector4 = _fwd()
	for l in _legs:
		var nm: String = l["name"]
		if air.has(nm):
			_solve(l, Vector2(air[nm]))
			l["planted"] = false
			continue
		var hip: Node4D = l["hip"]
		var hp: Vector4 = hip.global_position
		var neutral := Vector4(hp.x, 0.0, hp.z, hp.w) + fwd * (0.05 * s if String(l["kind"]) == "Fore" else 0.0)
		if not galloping and not trotting:
			_reach(l, neutral)
			l["planted"] = false
			continue
		var rate: float = maxf(_stride_rate(), 0.01)
		var stance: float = _speed * duty / rate
		var u: float = fposmod(_cycle - float(offs[nm]), 1.0)
		if u < duty:
			if not bool(l["planted"]):
				l["plant"] = neutral + fwd * stance * 0.5
				l["planted"] = true
			_reach(l, l["plant"])
		else:
			if bool(l["planted"]):
				l["lift"] = l["plant"]
				l["planted"] = false
			var sw: float = (u - duty) / (1.0 - duty)
			var land: Vector4 = neutral + fwd * (stance * 0.5 + _speed * (1.0 - sw) * (1.0 - duty) / rate)
			var from: Vector4 = l["lift"]
			if from == Vector4.ZERO:
				from = neutral
			var p: Vector4 = from.lerp(land, smoothstep(0.0, 1.0, sw))
			var h: float = (0.24 if String(l["kind"]) == "Fore" else 0.18) * s * (1.0 if galloping else 0.6)
			p.y += h * sin(PI * sw)
			_reach(l, p)


## Puts the leg's foot on world point `at` (as near as it reaches).
func _reach(l: Dictionary, at: Vector4) -> void:
	var parent: Node4D = l["parent"]
	var hip: Node4D = l["hip"]
	var local: Vector4 = parent.global_to_local(at) - hip.position
	_solve(l, Vector2(local.y, local.z))


## Two-joint solve in the leg's side plane: hip to foot `d` (y, z) from the hip, knee behind the line
## (towards -Z), as both a wolf's elbow-and-wrist and its stifle-and-hock fold. Angles run from +Y
## towards +Z, which is what Basis4D.from_yz turns by.
func _solve(l: Dictionary, d: Vector2) -> void:
	var l1: float = l["l1"]
	var l2: float = l["l2"]
	var dist: float = clampf(d.length(), absf(l1 - l2) + 0.002, l1 + l2 - 0.002)
	var at: float = atan2(d.y, d.x)
	var a: float = acos(clampf((l1 * l1 + dist * dist - l2 * l2) / (2.0 * l1 * dist), -1.0, 1.0))
	var th: float = at + a
	var knee := Vector2(cos(th), sin(th)) * l1
	var foot := Vector2(cos(at), sin(at)) * dist
	var sh: float = atan2(foot.y - knee.y, foot.x - knee.x)
	var turn1: float = th - float(l["th0"])
	(l["hip"] as Node4D).basis = Basis4D.from_yz(turn1)
	(l["knee"] as Node4D).basis = Basis4D.from_yz(sh - turn1 - float(l["sh0"]))


## The chicken in its mouth: across the jaws, on its side, carried with the head.
func _carry() -> void:
	if prey == null or not is_instance_valid(prey):
		prey = null
		return
	var hold: Projection = _mouth.global_basis * Basis4D.from_zx(PI * 0.5) * Basis4D.from_xy(PI * 0.5)
	prey.global_basis = hold
	prey.global_position = _mouth.global_position - hold * Vector4(0.0, 0.12 * float(prey.get("size")) / 0.3, 0.0, 0.0)
