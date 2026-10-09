@tool
extends Node

## The Arboretum's wind: one for the whole room, read by every tree's bark and every leaf (Ramon,
## 5 Oct: "maybe a wind version"). Put one in the scene; trees register their shader materials with
## the node they hang under, and every frame each one is handed the wind in its own space.
##
##   direction   across the floor and through W: a wind with a W part swings branches out of your
##               slice and back, which is the 4D part of a 4D wind
##   speed       m/s; a branch's pressure goes with the speed squared and saturates (botany_bark)
##   gusts       G sends one down the wind at `gust_speed`: a band of stronger wind `gust_width` wide
##               that reaches each tree in turn; a slow random swell adds smaller ones on its own
##   time        one clock for every tree, so a room of trees is one weather
##
## NO class_name (engine_gotchas.md): preload it.

## The wind's direction (x, z and W; y is ignored), normalised when used.
@export var direction: Vector4 = Vector4(1.0, 0.0, 0.25, 0.35)
@export_range(0.0, 30.0, 0.1) var speed: float = 6.0
@export var enabled: bool = true
## A gust's speed along the wind (m/s), its width (m), its extra strength (radians at full flex).
@export_range(1.0, 30.0, 0.5) var gust_speed: float = 7.0
@export_range(0.5, 20.0, 0.5) var gust_width: float = 4.0
@export_range(0.0, 1.0, 0.01) var gust_strength: float = 0.22
## How often the room makes a gust of its own, on average (seconds; 0: never).
@export_range(0.0, 60.0, 0.5) var gust_every: float = 9.0
## How far a branch turns per unit of pressure, and the sway's share of it (botany_bark).
@export_range(0.0, 0.3, 0.001) var bend: float = 0.05
@export_range(0.0, 1.5, 0.01) var sway: float = 0.35

var time: float = 0.0
## The gust running now: where its front is along the wind (world metres), and from where it began.
var gust_front: float = -1000.0
var _gust_on: bool = false
var _next_gust: float = 4.0
## [ShaderMaterial, Node4D] pairs, held weakly.
var _users: Array = []
var _rng := RandomNumberGenerator.new()
## The running gust's own strength and width when a key sent a stronger one (-1: the room's).
var _strength_now: float = -1.0
var _width_now: float = -1.0


func _enter_tree() -> void:
	add_to_group("arb_wind")


## The room's wind, from anywhere under the same tree.
static func of(tree: SceneTree) -> Node:
	return tree.get_first_node_in_group("arb_wind") if tree != null else null


## A tree's (or leaves') shader material, to be handed the wind every frame in `owner`'s space.
func register(cs: ShaderMaterial, owner: Node4D) -> void:
	if cs == null or owner == null:
		return
	_users.append([weakref(cs), weakref(owner)])
	_apply(cs, owner)


## Sends a gust down the wind from behind every tree. With no arguments, the room's own gust; a key may
## send a stronger, wider one that starts `lead` metres before the first tree (BOTANY LAB round 2: the
## second room's G started 8 m out and took seconds to arrive, so it looked as if nothing happened).
func gust(strength: float = -1.0, width: float = -1.0, lead: float = 8.0) -> void:
	_strength_now = strength
	_width_now = width
	gust_front = _start_of_gust(lead)
	_gust_on = true


## This gust's width and strength (its own, or the room's).
func _width() -> float:
	return _width_now if _width_now > 0.0 else gust_width


func _strength() -> float:
	return _strength_now if _strength_now >= 0.0 else gust_strength


func world_direction() -> Vector4:
	var d := Vector4(direction.x, 0.0, direction.z, direction.w)
	return d.normalized() if d.length() > 0.0001 else Vector4(1, 0, 0, 0)


func _start_of_gust(lead: float = 8.0) -> float:
	var d: Vector4 = world_direction()
	var lo: float = INF
	for u in _users:
		var o: Node4D = (u[1] as WeakRef).get_ref()
		if o != null and o.is_inside_tree():
			lo = minf(lo, o.global_position.dot(d))
	return (lo if lo < INF else 0.0) - lead - _width()


func _process(delta: float) -> void:
	time += delta if enabled else 0.0
	if enabled and not Engine.is_editor_hint():
		if gust_every > 0.0:
			_next_gust -= delta
			if _next_gust <= 0.0:
				_next_gust = gust_every * _rng.randf_range(0.6, 1.4)
				if not _gust_on:
					gust()
		if _gust_on:
			gust_front += gust_speed * delta
			if gust_front > _end_of_room():
				_gust_on = false
				gust_front = -1000.0
				_strength_now = -1.0
				_width_now = -1.0
	var alive: Array = []
	for u in _users:
		var cs: ShaderMaterial = (u[0] as WeakRef).get_ref()
		var o: Node4D = (u[1] as WeakRef).get_ref()
		if cs == null or o == null:
			continue
		alive.append(u)
		if o.is_inside_tree():
			_apply(cs, o)
	_users = alive


func _end_of_room() -> float:
	var d: Vector4 = world_direction()
	var hi: float = -INF
	for u in _users:
		var o: Node4D = (u[1] as WeakRef).get_ref()
		if o != null and o.is_inside_tree():
			hi = maxf(hi, o.global_position.dot(d))
	return (hi if hi > -INF else 0.0) + 12.0 + _width()


func _apply(cs: ShaderMaterial, o: Node4D) -> void:
	var d: Vector4 = world_direction()
	var inv: Projection = o.global_basis.inverse() if o.is_inside_tree() else Projection.IDENTITY
	var origin: Vector4 = o.global_position if o.is_inside_tree() else Vector4.ZERO
	# The tree may be scaled to its pedestal: its own space gets the wind's direction, at the
	# wind's own speed, and the gust's front in its own metres.
	var s: float = maxf((o.global_basis.x as Vector4).length(), 0.0001) if o.is_inside_tree() else 1.0
	var local_dir: Vector4 = inv * d
	local_dir = local_dir.normalized() if local_dir.length() > 0.0001 else Vector4(1, 0, 0, 0)
	cs.set_shader_parameter("wind", local_dir * speed)
	cs.set_shader_parameter("wind_time", time)
	cs.set_shader_parameter("wind_on", 1.0 if enabled else 0.0)
	cs.set_shader_parameter("bend", bend)
	cs.set_shader_parameter("sway", sway)
	cs.set_shader_parameter("gust_front", (gust_front - origin.dot(d)) / s if _gust_on else -1000.0)
	cs.set_shader_parameter("gust_width", _width() / s)
	cs.set_shader_parameter("gust_strength", _strength() if _gust_on else 0.0)
