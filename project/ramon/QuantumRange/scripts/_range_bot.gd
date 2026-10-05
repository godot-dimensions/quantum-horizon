extends RefCounted

## A test player for the range's runners: it plays an experiment the way a person would, with the same
## moves (no hitbox it could not see, no shot through what is in the way), so a runner can prove every
## stage can be finished and photograph it being played.
##
##   finding   a part within 1.9 m of W is reached by stepping (the player's W set, as Q/E would get
##             there); one further off by turning the slice until the part lies in it (as a drag with the
##             right mouse button would), keeping the room's up
##   choosing  unlocked cores first; when the only core is locked, the cover guarding it; never a friendly
##   shooting  a quick shot for cores and cover, a charged one for amber, only when the crosshair is over
##             the part it wants (the weapon's own hover): a grey shell in the way means stepping past it
##             through W; a petal means waiting; a tendril means shooting the tendril
##
## NO class_name (engine_gotchas.md): preload it.

var director: Node
var player: CharacterBody4D
var weapon: Node
var tree: SceneTree
## Seconds between shots, like a person (and so charged shots have time).
var pace: float = 0.5
var log_lines: bool = false

var _cool: float = 0.0
var _charging: float = -1.0
var _want: Dictionary = {}


func _cam() -> Camera4D:
	return player.get("camera")


## The part to go for now: [target, part], or [].
func pick() -> Array:
	var eye: Vector4 = _cam().global_position
	var best: Array = []
	var best_score: float = INF
	for t in director.call("alive"):
		var parts: Array = t.get("parts")
		var has_open_core: bool = false
		for p in parts:
			if String(p["role"]) == "core" and bool(p["alive"]) and not bool(p["locked"]):
				has_open_core = true
		for p in parts:
			if not bool(p["alive"]) or not (p["node"] is Area4D):
				continue
			var role: String = String(p["role"])
			var ok: bool = false
			match role:
				"core":
					ok = not bool(p["locked"]) or not _has_cover(parts)
				"armour":
					ok = true
				"cover":
					# Satellites and guards, only when no open core is there to take instead (not tendrils:
					# those are shot only when they are in the way).
					ok = not has_open_core and not String(p["name"]).begins_with("T") and String(t.get("family")) != "chicken"
			if not ok:
				continue
			var at: Vector4 = (p["node"] as Node4D).global_position
			var score: float = at.distance_to(eye) + (0.0 if role == "core" else 2.0) + (6.0 if bool(p["locked"]) else 0.0)
			if score < best_score:
				best_score = score
				best = [t, p]
	return best


func _has_cover(parts: Array) -> bool:
	for p in parts:
		if String(p["role"]) == "cover" and bool(p["alive"]) and not String(p["name"]).begins_with("T") and p["node"] is Area4D:
			return true
	return false


## Brings point `at` into your slice and under the crosshair.
func align(at: Vector4, prefer_w: float = INF) -> void:
	var eye: Vector4 = _cam().global_position
	var dw: float = at.w - eye.w
	var lim: float = float(player.get("w_limit"))
	var target_w: float = at.w if prefer_w == INF else prefer_w
	if absf(target_w) <= lim - 0.05:
		# Step there, and keep the room's slice.
		var p: Vector4 = player.global_position
		p.w = target_w
		player.global_position = p
		player.basis = Basis4D.from_zx(float(player.call("yaw")))
		player.call("aim_at", at)
		return
	# Too far to step: turn the slice so the line to the part lies in it.
	var d: Vector4 = at - eye
	var f := Vector4(d.x, 0.0, d.z, d.w).normalized()
	var wv: Vector4 = Vector4(0, 0, 0, 1) - f * f.w
	wv = wv.normalized() if wv.length() > 0.001 else Vector4(0, 0, 0, 1)
	var xv: Vector4 = Vector4(1, 0, 0, 0) - f * f.x - wv * wv.x
	xv = xv.normalized()
	var b := Projection(xv, Vector4(0, 1, 0, 0), -f, wv)
	if b.determinant() < 0.0:
		b.x = -b.x
	player.basis = b
	player.call("aim_at", at)
	if log_lines:
		print("BOT: turned the slice %.1f degrees for a part %.1f m off in W" % [float(player.call("slice_angle")), dw])


## One frame of play. Returns what it did ("", "aim", "shot", "charge", "wait").
func step(dt: float) -> String:
	_cool -= dt
	if _charging >= 0.0:
		_charging += dt
		if not _want.is_empty() and is_instance_valid(_want["t"]) and bool(_want["p"]["alive"]):
			align((_want["p"]["node"] as Node4D).global_position, _want.get("w", INF))
		if _charging >= 1.0:
			weapon.call("release")
			_charging = -1.0
			_cool = pace
			return "shot"
		return "charge"
	if _cool > 0.0:
		return "wait"
	var pk: Array = pick()
	if pk.is_empty():
		return ""
	var t: Node = pk[0]
	var p: Dictionary = pk[1]
	var at: Vector4 = (p["node"] as Node4D).global_position
	var role: String = String(p["role"])
	var want_w: float = INF
	# A shell round it: come at it from a slice past the shell.
	for q in t.get("parts"):
		if String(q["role"]) == "shell" and bool(q["alive"]) and String(t.get("family")) == "shell":
			var sw: float = float(t.get("shell_w"))
			want_w = at.w + (sw + 0.28) * (1.0 if player.global_position.w >= at.w else -1.0)
	align(at, want_w)
	_want = {"t": t, "p": p, "w": want_w}
	# Read the crosshair (the weapon's own ray) before shooting.
	weapon.call("_aim")
	var hover: String = String(weapon.get("hover"))
	if hover == "friend":
		_cool = 0.1
		return "wait"
	if hover == "shell":
		# A petal: wait for it to open.
		_cool = 0.1
		return "wait"
	if hover.is_empty():
		_cool = 0.1
		return "wait"
	if hover == "cover" and role == "core":
		# A tendril in the way: shoot it, it recoils.
		weapon.call("press")
		weapon.call("release")
		_cool = pace
		return "shot"
	if role == "armour" or hover == "armour":
		weapon.call("press")
		_charging = 0.0
		return "charge"
	if bool(weapon.get("hover_locked")):
		_cool = 0.15
		return "wait"
	weapon.call("press")
	weapon.call("release")
	_cool = pace
	return "shot"
