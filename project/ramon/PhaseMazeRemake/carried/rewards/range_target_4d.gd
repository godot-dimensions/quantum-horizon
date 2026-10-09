extends Node4D

## A target: an abstract research specimen made of PARTS, each a mesh and its own hitbox, each playing
## one of the range's roles (scripts/range_style.gd ROLE; follow_up/quantum_range_final.md section 4):
##
##   core    red     the thing to hit: any shot takes it. A core can be LOCKED (dark, and a shot only
##                   pings off it) until whatever guards it is gone; then it lights and pulses.
##   armour  amber   only a charged shot breaks it; a quick shot scuffs it
##   cover   white   any shot breaks it (some take more than one)
##   shell   grey    nothing breaks it: go round it through W
##   friend  green   do not shoot: a shot costs you
##   w       cyan    a guide (a ring, a lane): no hitbox, shots pass through
##
## The target is destroyed when its last VITAL part goes (its cores, unless a family says otherwise). Families (scripts/targets/*.gd) extend this and
## build their parts in build(), and move them in animate(t, dt): rigid motion only, nodes moving,
## nothing re-lofted (follow_up/lofting_gotchas.md).
##
## HITBOXES ARE BOXES, square to the world (the engine collides axis-aligned bounding boxes), each an
## Area4D found by the weapon's raycast (collide_with_areas). A part's box is as deep through W as the
## part itself, which is what makes a grey shell solid in your slice and nothing at all a step away.
##
## It joins the group "range_target"; the radar asks each for marks() and the HUD for the part you are
## aiming at.
##
## NO class_name (engine_gotchas.md): preload it.

const Style := preload("res://ramon/PhaseMazeRemake/carried/rewards/range_style.gd")
const Mats := preload("res://ramon/PhaseMazeRemake/carried/rewards/range_mats.gd")
const Fx := preload("res://ramon/PhaseMazeRemake/carried/rewards/range_fx_4d.gd")

signal destroyed(target: Node4D)
signal part_hit(target: Node4D, part: Dictionary, outcome: String)

## The family's name, for the radar, the gallery and the metrics.
var family: String = "target"
var parts: Array = []
var alive: bool = true
## Seconds since it appeared.
var age: float = 0.0
## Where it was put (motion is relative to this).
var home: Vector4 = Vector4.ZERO
## Optional: something else moves it each frame (an experiment's path), fn(target, t) -> Vector4.
var path: Callable
## Seconds to live before it leaves unhit (0: forever). Experiments read `expired`.
var lifetime: float = 0.0
var expired: bool = false
## Set by whoever spawned it, read back by whoever counts.
var tag: Dictionary = {}

var _appear: float = 0.0
var _dissolve: float = -1.0
var _mats: Dictionary = {}
var _flash_mat: TetraMaterial4D
var _flash_on: bool = false


func _init() -> void:
	add_to_group("range_target")


func _ready() -> void:
	home = position
	_flash_mat = Mats.glow(Style.glow("w"))
	build()
	_set_flash(true)
	_flash_on = true
	scale_all(0.25)


## Families make their parts here.
func build() -> void:
	pass


## Families move their parts here (t: seconds alive).
func animate(_t: float, _dt: float) -> void:
	pass


## A part: a mesh in a role, with a hitbox `box` (world-square, in the part's own metres) unless the
## role is "w" or `box` is zero. `parent` is the node it hangs off (a hinge, a joint; the target itself
## by default). Options: at (Vector4), basis (the mesh's Projection, scale included), hp, locked,
## radar (shown on the radar, default true for cores, armour, friends and rings), color (override),
## glow (true: unshaded), material (its own, kept: no role colour), vital (its loss ends the target).
func add_part(nm: String, role: String, mesh: Mesh4D, box: Vector4, opts: Dictionary = {}) -> Dictionary:
	var parent: Node4D = opts.get("parent", self)
	var node: Node4D
	if role != "w" and box != Vector4.ZERO:
		var area := Area4D.new()
		var shape := CollisionShape4D.new()
		var bs := BoxShape4D.new()
		bs.size = box
		shape.shape = bs
		area.add_child(shape)
		area.set_meta("range_target", self)
		area.set_meta("range_part", nm)
		node = area
	else:
		node = Node4D.new()
	node.name = nm
	node.position = opts.get("at", Vector4.ZERO)
	parent.add_child(node)
	var mi := MeshInstance4D.new()
	mi.name = "Mesh"
	mi.mesh = mesh
	mi.basis = opts.get("basis", Projection.IDENTITY)
	node.add_child(mi)
	var p: Dictionary = {"name": nm, "role": role, "node": node, "mesh": mi, "hp": int(opts.get("hp", 1)),
		"alive": true, "locked": bool(opts.get("locked", false)), "box": box,
		"radar": bool(opts.get("radar", role in ["core", "armour", "friend", "w"])),
		"vital": bool(opts.get("vital", role == "core")),
		"color": opts.get("color", null), "glow": bool(opts.get("glow", false)), "dying": -1.0,
		"material": opts.get("material", null)}
	parts.append(p)
	_paint(p)
	return p


func part(nm: String) -> Dictionary:
	for p in parts:
		if String(p["name"]) == nm:
			return p
	return {}


## The colour a part shows now.
func _color_of(p: Dictionary) -> Color:
	if p["color"] != null:
		return p["color"]
	if String(p["role"]) == "core" and bool(p["locked"]):
		return Color(0.36, 0.10, 0.10)
	return Style.role(String(p["role"]))


func _paint(p: Dictionary) -> void:
	# A part that keeps its own material (a chicken's feathers, its comb).
	if p.get("material") != null:
		(p["mesh"] as MeshInstance4D).material_override = p["material"]
		return
	var c: Color = _color_of(p)
	var key: String = "%s|%s" % [c, p["glow"]]
	if not _mats.has(key):
		_mats[key] = Mats.glow(c) if bool(p["glow"]) or String(p["role"]) == "w" else Mats.lit(c)
	(p["mesh"] as MeshInstance4D).material_override = _mats[key]


func _set_flash(on: bool) -> void:
	for p in parts:
		if on:
			(p["mesh"] as MeshInstance4D).material_override = _flash_mat
		else:
			_paint(p)


## Scales every part's mesh about its own place (the appear and the dissolve).
func scale_all(k: float) -> void:
	for p in parts:
		var mi: MeshInstance4D = p["mesh"]
		if not mi.has_meta("rest"):
			mi.set_meta("rest", mi.basis)
		var rest: Projection = mi.get_meta("rest")
		mi.basis = Projection(rest.x * k, rest.y * k, rest.z * k, rest.w * k)


## Unlocks a core: it lights up and starts to pulse.
func unlock(nm: String) -> void:
	var p: Dictionary = part(nm)
	if p.is_empty() or not bool(p["locked"]):
		return
	p["locked"] = false
	_paint(p)
	Fx.burst(get_parent(), (p["node"] as Node4D).global_position, Style.glow("core"), 8, 0.05, 2.5)


## A shot reached part `nm`. `charged` tells a charged shot from a quick one. Returns what happened:
## "pop" (a core gone), "break" (armour or cover gone), "chip" (cover hit, not yet broken), "scuff"
## (armour hit by a quick shot), "ping" (a shell, or a locked core), "penalty" (a friendly), "".
func hit(nm: String, charged: bool, at: Vector4) -> String:
	var p: Dictionary = part(nm)
	if p.is_empty() or not bool(p["alive"]) or not alive or _appear < 1.0:
		return ""
	var outcome: String = ""
	match String(p["role"]):
		"core":
			if bool(p["locked"]):
				outcome = "ping"
			else:
				outcome = "pop"
		"armour":
			outcome = "break" if charged else "scuff"
		"cover":
			p["hp"] = int(p["hp"]) - (2 if charged else 1)
			outcome = "break" if int(p["hp"]) <= 0 else "chip"
		"shell":
			outcome = "ping"
		"friend":
			outcome = "penalty"
	var col: Color = Style.glow(String(p["role"])) if String(p["role"]) in ["core", "armour", "friend"] else _color_of(p)
	match outcome:
		"pop", "break", "penalty":
			_kill_part(p)
			Fx.burst(get_parent(), at, col, 14 if outcome == "pop" else 10, 0.07, 4.5)
		"chip", "scuff":
			Fx.burst(get_parent(), at, col, 5, 0.04, 3.0)
		"ping":
			Fx.burst(get_parent(), at, Color(0.85, 0.87, 0.9), 4, 0.03, 2.0)
	if not outcome.is_empty():
		on_hit(p, outcome)
		part_hit.emit(self, p, outcome)
	if outcome in ["pop", "break", "penalty"] and not bool(p["alive"]) and bool(p["vital"]) and _vitals_left() == 0:
		destroy()
	return outcome


## Families react to hits here (a tendril recoils, a guarded core unlocks).
func on_hit(_p: Dictionary, _outcome: String) -> void:
	pass


func _kill_part(p: Dictionary) -> void:
	p["alive"] = false
	p["dying"] = 0.0
	var node: Node4D = p["node"]
	if node is Area4D:
		# No longer in the way of the next shot. (CollisionShape4D has no `disabled`: the shape goes.)
		for c in node.get_children():
			if c is CollisionShape4D:
				node.remove_child(c)
				c.queue_free()


## Parts whose loss ends the target (cores by default; an amber block or a friendly says so itself).
func _vitals_left() -> int:
	var n: int = 0
	for p in parts:
		if bool(p["vital"]) and bool(p["alive"]):
			n += 1
	return n


func destroy() -> void:
	if not alive:
		return
	alive = false
	_dissolve = 0.0
	destroyed.emit(self)


## Leaves without being hit (its lifetime ran out, or an experiment cleared it).
func leave() -> void:
	if not alive:
		return
	alive = false
	expired = true
	_dissolve = 0.0


## Every live part the radar should show: [world position, role, locked, part name].
func marks() -> Array:
	var out: Array = []
	if not alive:
		return out
	for p in parts:
		if bool(p["alive"]) and bool(p["radar"]):
			out.append([(p["node"] as Node4D).global_position, String(p["role"]), bool(p["locked"]), String(p["name"])])
	return out


## How deep through W a part's hitbox reaches either side of its middle.
func w_reach(p: Dictionary) -> float:
	var b: Vector4 = p["box"]
	return b.w * 0.5 if b != Vector4.ZERO else 0.3


func _process(delta: float) -> void:
	age += delta
	if _appear < 1.0:
		_appear = minf(1.0, _appear + delta / 0.32)
		var k: float = 1.0 - pow(1.0 - _appear, 3.0)
		scale_all(0.25 + 0.75 * k)
		# The holodeck's materialise: cyan for the first half of the appear, then its real colours.
		if _flash_on and _appear >= 0.55:
			_flash_on = false
			_set_flash(false)
	if path.is_valid() and alive:
		position = path.call(self, age)
	if alive or _dissolve < 0.0:
		animate(age, delta)
	# Parts that were shot shrink away.
	for p in parts:
		if float(p["dying"]) >= 0.0:
			p["dying"] = float(p["dying"]) + delta / 0.18
			var mi: MeshInstance4D = p["mesh"]
			var rest: Projection = mi.get_meta("rest") if mi.has_meta("rest") else mi.basis
			var k2: float = maxf(0.0, 1.0 - float(p["dying"]))
			mi.basis = Projection(rest.x * k2, rest.y * k2, rest.z * k2, rest.w * k2)
			if float(p["dying"]) >= 1.0:
				p["dying"] = -2.0
				(p["node"] as Node4D).visible = false
	if lifetime > 0.0 and alive and age >= lifetime:
		leave()
	if _dissolve >= 0.0:
		_dissolve += delta / 0.25
		scale_all(maxf(0.0, 1.0 - _dissolve))
		if _dissolve >= 1.0:
			queue_free()
