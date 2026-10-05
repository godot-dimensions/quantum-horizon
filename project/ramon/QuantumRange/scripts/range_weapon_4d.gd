extends Node

## The range's weapon: one hitscan shot along your view, a real 4D raycast against 4D hitboxes
## (RaycastParameters4D + PhysicsServer4D.raycast_physics_objects, collide_with_areas on, since every
## target part is an Area4D; follow_up/engine_capabilities.md). The ray lies in your slice: you can only
## hit what your slice cuts, which is the whole range's premise.
##
## TWO SHOTS, ONE BUTTON (Ramon's charge mechanic, his _ramon fork, kept and made into a rule):
##   tap     a quick shot: takes red cores and white cover; only scuffs amber armour
##   hold    the ring round the crosshair fills amber; release when it is full (FULL seconds) for one
##           heavy shot that breaks amber. Release early and it is a quick shot after all.
##   vent    hold on past full for VENT_AFTER seconds and the charge vents: released, it fires nothing
##           (Ramon's commit-to-a-release-window risk, as his version had it)
##
## Every shot's raycast is timed (microseconds), and everything is counted for the metrics wall:
## stats, reset per experiment by the director.
##
## NO class_name (engine_gotchas.md).

const Fx := preload("res://ramon/QuantumRange/scripts/range_fx_4d.gd")
const Style := preload("res://ramon/QuantumRange/scripts/range_style.gd")

const TAP := 0.2
const FULL := 0.9
const VENT_AFTER := 2.5
const REACH := 80.0

signal shot(result: Dictionary)

var player: CharacterBody4D
var camera: Camera4D
var gun: Node4D
var fx_parent: Node
var enabled: bool = true

## 0 to 1 while a shot charges; `vented` once it has gone too long.
var charge: float = 0.0
var vented: bool = false
var charging: bool = false
## What the crosshair is over right now: the part's role ("core", "armour", ...), or "".
var hover: String = ""
var hover_locked: bool = false

var stats: Dictionary = {}
var _held: float = 0.0


func _ready() -> void:
	reset_stats()


func reset_stats() -> void:
	stats = {"shots": 0, "quick": 0, "charged": 0, "hits": 0, "pops": 0, "breaks": 0, "chips": 0, "scuffs": 0,
		"pings": 0, "penalties": 0, "misses": 0, "vents": 0, "ray_us": 0.0, "rays": 0}


func _unhandled_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or not enabled:
		return
	if mb.pressed:
		press()
	else:
		release()
	get_viewport().set_input_as_handled()


## The trigger, pressed and let go (the runners call these too).
func press() -> void:
	charging = true
	_held = 0.0
	charge = 0.0
	vented = false


func release() -> Dictionary:
	if not charging:
		return {}
	charging = false
	var held: float = _held
	var was_vented: bool = vented
	charge = 0.0
	vented = false
	if was_vented:
		stats["vents"] = int(stats["vents"]) + 1
		var r := {"fired": false, "vented": true}
		shot.emit(r)
		return r
	return fire(held >= FULL)


func _process(delta: float) -> void:
	if charging:
		_held += delta
		charge = clampf((_held - TAP) / (FULL - TAP), 0.0, 1.0)
		vented = _held >= FULL + VENT_AFTER
	if gun != null:
		gun.set("charge", charge if charging else 0.0)
		gun.set("vented", vented)
	_aim()


## What the crosshair is over, for its colour (one ray a frame: microseconds).
func _aim() -> void:
	hover = ""
	hover_locked = false
	if camera == null or not camera.is_inside_tree():
		return
	var r: Dictionary = _ray()
	if r.get("hit", false):
		var body: Object = r["body"]
		if body != null and body.has_meta("range_target"):
			var t: Node = body.get_meta("range_target")
			if is_instance_valid(t):
				var p: Dictionary = t.call("part", String(body.get_meta("range_part")))
				if not p.is_empty() and bool(p["alive"]):
					hover = String(p["role"])
					hover_locked = bool(p["locked"])


func _ray() -> Dictionary:
	var params := RaycastParameters4D.new()
	params.global_ray_origin = camera.global_position
	params.global_ray_direction = -camera.global_basis.z
	params.collide_with_areas = true
	if player != null:
		params.set_exclude_nodes([player])
	return PhysicsServer4D.raycast_physics_objects(params)


## Fires one shot, quick or charged. Returns what happened.
func fire(charged: bool) -> Dictionary:
	var t0: int = Time.get_ticks_usec()
	var r: Dictionary = _ray()
	var us: float = float(Time.get_ticks_usec() - t0)
	stats["ray_us"] = float(stats["ray_us"]) + us
	stats["rays"] = int(stats["rays"]) + 1
	stats["shots"] = int(stats["shots"]) + 1
	stats["charged" if charged else "quick"] = int(stats["charged" if charged else "quick"]) + 1
	var fwd: Vector4 = -camera.global_basis.z
	var end: Vector4 = camera.global_position + fwd * REACH
	var outcome: String = ""
	var target: Node = null
	if r.get("hit", false):
		end = r.get("global_point", end)
		var body: Object = r["body"]
		if body != null and body.has_meta("range_target"):
			target = body.get_meta("range_target")
			if is_instance_valid(target):
				outcome = String(target.call("hit", String(body.get_meta("range_part")), charged, end))
		elif fx_parent != null:
			Fx.burst(fx_parent, end, Color(0.75, 0.77, 0.80), 4, 0.03, 1.5)
	if outcome.is_empty():
		stats["misses"] = int(stats["misses"]) + 1
	else:
		stats["hits"] = int(stats["hits"]) + 1
		var key: String = {"pop": "pops", "break": "breaks", "chip": "chips", "scuff": "scuffs", "ping": "pings", "penalty": "penalties"}.get(outcome, "")
		if not key.is_empty():
			stats[key] = int(stats[key]) + 1
	if gun != null:
		gun.call("pulse")
	if fx_parent != null:
		var muzzle: Vector4 = camera.global_position
		if gun != null:
			muzzle = (gun as Node4D).global_position + (gun as Node4D).global_basis * Vector4(0.0, 0.035, -0.42, 0.0)
		var col: Color = Color(1.0, 0.85, 0.55) if charged else Color(0.75, 0.95, 1.0)
		Fx.beam(fx_parent, muzzle, end, camera.global_basis, charged, col)
	var result := {"fired": true, "charged": charged, "outcome": outcome, "target": target, "at": end, "us": us}
	shot.emit(result)
	return result
