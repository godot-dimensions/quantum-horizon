extends Node4D

## WATER LAB: a harbour's gulls (Ramon, 9 Oct: "seagulls at harbour frequency ... make them land on one
## of the poles of the walkway and on the rims ... land, look around, fly off again and sit again").
## Spawns the gulls (gull_4d.gd), hands out the perches, plays their calls.
##
## PERCHES are points a gull may sit on, one gull each: add_perch(pos, face) for one, add_rail(from,
## to, every) for a row along a rail's top. A gull that wants to land asks for one (perch_for), the
## harbour picks a free one at random and holds it for that gull until it leaves (release). The
## seascape gives it its rail tops, the pole's top and the doors' lintels; the test bed its posts.
## Without a `face` a gull sits facing into the wind, as gulls do, so a row of them all face one way.
##
## HOW MANY: a harbour by day has a handful in the air and a row on the rails; 12 by default, the
## seascape HUD's HARBOUR slider sets it (0 to 30). Most start sitting.
##
## THE SCHOOL: when the sardines come near the surface (`school`, the seascape's fish_school_4d.gd,
## its middle above `lure_depth`), the gulls in the air gather low over them, as gulls do over a bait
## ball.
##
## PEOPLE: a sitting gull lets you come only so close (its flight distance, about 3 m here, a little
## more or less for each bird), then gives the alarm and flies; and a gull coming in to land picks a
## perch away from you. So walking a pier lifts the gulls off its rails ahead of you, and they settle
## again behind.
##
## SOUND: there is no positional audio in 4D (pen_sfx_4d.gd), so each call is a one-shot on one of a
## few buses of the harbour's own, each with a panner (toward the caller's side of the listener) and a
## low-pass (closing with distance: air takes the top off far sound); its volume falls with distance.
## The calls are synthesized (audio/bake_water_lab_sound.py): the long call, the laugh, the alarm
## "kek" on take-off, a soft wing-rustle on landing.
##
## NO class_name (engine_gotchas.md).

const Gull := preload("res://ramon/WaterLab/gull/gull_4d.gd")
const SOUND_DIR := "res://ramon/WaterLab/audio/"
const SOUNDS := ["gull_long", "gull_laugh", "gull_kek", "gull_land"]
const BUS_PREFIX := "WLGulls"
const VOICES := 4

## Setting it spawns or sends off gulls (the seascape HUD's HARBOUR slider sets it).
@export var count: int = 8:
	set(v):
		count = clampi(v, 0, 60)
		if is_inside_tree():
			_sync_count()
## Where they wheel round (this node's frame), how far out, how high.
@export var home := Vector4(10.0, 8.0, 8.0, 0.0)
@export var roam_radius: float = 24.0
@export var altitude := Vector2(5.0, 13.0)
## Where the wind blows FROM (they land and take off facing it).
@export var wind := Vector4(1.0, 0.0, 0.0, 0.0)
@export_range(0.0, 1.0) var start_perched: float = 0.7
## Who the gulls keep away from (the player), and how close they let it come.
var walker: Node4D = null
@export var flush_distance: float = 3.2
## A gull coming in picks a perch at least this far from the walker.
@export var shy_distance: float = 6.0
## The sea's school (fish_school_4d.gd); `lure_on` while its middle is above `lure_depth`.
var school: Node4D = null
## The school rides about 2 m down; it comes over this when it rises (the plesiosaur under it).
@export var lure_depth: float = -1.6
var lure := Vector4.ZERO
var lure_on: bool = false
var _lure_check: float = 0.0
@export_group("Sound")
@export var sound_on: bool = true
## A call's level at a few metres.
@export_range(-40.0, 12.0, 0.5, "suffix:dB") var volume_db: float = -8.0
## Past this distance a call is not heard.
@export var hearing: float = 60.0
@export var send_bus: StringName = &"Master"

## Who hears (the camera, a Node4D); without one, the world origin.
var listener_4d: Node4D = null
var perches: Array = []
var gulls: Array = []
var time_scale: float = 1.0:
	set(v):
		time_scale = v
		for g in gulls:
			if is_instance_valid(g):
				g.set("time_scale", v)

var _rng := RandomNumberGenerator.new()
var _streams: Dictionary = {}
var _voices: Array = []
var _next_voice: int = 0


func _ready() -> void:
	_rng.randomize()
	if sound_on:
		_make_sound()
	_sync_count()


# -- perches ----------------------------------------------------------------------------------------------

func add_perch(pos: Vector4, face: Vector4 = Vector4.ZERO, stay := Vector2(10.0, 28.0)) -> Dictionary:
	var pr: Dictionary = {"pos": pos, "taken": null, "stay_min": stay.x, "stay_max": stay.y}
	if face != Vector4.ZERO:
		pr["face"] = face
	perches.append(pr)
	return pr


## A row of perches along a rail's top, `every` metres apart (gulls on a rail keep about a body length
## or two between them).
func add_rail(from: Vector4, to: Vector4, every: float = 1.4) -> void:
	var n: int = maxi(int((to - from).length() / every), 0)
	for i in n + 1:
		add_perch(from.lerp(to, (float(i) + 0.5) / float(n + 1)) if n > 0 else (from + to) * 0.5)


## Every perch gone (the piers rebuilt at a new size): the sitting gulls take off, then the owner
## adds the new ones.
func clear_perches() -> void:
	for g in gulls:
		if is_instance_valid(g) and String(g.get("state")) in ["perched", "approach", "flare"]:
			g.set("state", "takeoff")
			g.set("_state_t", 0.0)
	perches.clear()


func perch_for(g: Node) -> Dictionary:
	var free: Array = []
	var near: Vector4 = _walker_at()
	for pr in perches:
		if pr["taken"] == null and (walker == null or _flat((pr["pos"] as Vector4) - near) > shy_distance):
			free.append(pr)
	if free.is_empty():
		return {}
	var pr: Dictionary = free[_rng.randi() % free.size()]
	pr["taken"] = g
	return pr


func release(g: Node) -> void:
	for pr in perches:
		if pr["taken"] == g:
			pr["taken"] = null


func perched_count() -> int:
	var n: int = 0
	for g in gulls:
		if is_instance_valid(g) and String(g.get("state")) == "perched":
			n += 1
	return n


func _walker_at() -> Vector4:
	if walker == null or not is_instance_valid(walker):
		return Vector4(1e9, 0, 0, 0)
	return global_basis.inverse() * (walker.global_position - global_position)


static func _flat(v: Vector4) -> float:
	return Vector2(v.x, v.z).length()


## Sitting gulls the walker comes too close to take off (each its own distance).
func _process(delta: float) -> void:
	_lure_check -= delta
	if _lure_check <= 0.0:
		_lure_check = 0.5
		if school != null and is_instance_valid(school):
			var m: Vector4 = global_basis.inverse() * ((school.call("middle") as Vector4) - global_position)
			lure_on = m.y > lure_depth
			lure = m
		else:
			lure_on = false
	if walker == null:
		return
	var at: Vector4 = _walker_at()
	for g in gulls:
		if not is_instance_valid(g) or String(g.get("state")) != "perched":
			continue
		var shy: float = flush_distance * (0.8 + 0.4 * fmod(float(g.get_instance_id() % 1000) * 0.618, 1.0))
		var d: Vector4 = (g.get("p") as Vector4) - at
		if _flat(d) < shy and absf(d.y) < 4.0:
			g.call("flush")


# -- how many -----------------------------------------------------------------------------------------------

func set_count(n: int) -> void:
	count = n


func _sync_count() -> void:
	while gulls.size() < count:
		_spawn(gulls.size())
	while gulls.size() > count:
		var g: Node = gulls.pop_back()
		release(g)
		g.queue_free()


func _spawn(i: int) -> void:
	var g := Node4D.new()
	g.name = "Gull%d" % i
	g.set_script(Gull)
	g.set("home", home)
	g.set("roam_radius", roam_radius)
	g.set("altitude", altitude)
	g.set("wind", wind)
	g.set("harbour", self)
	g.set("time_scale", time_scale)
	if _rng.randf() < start_perched:
		var pr: Dictionary = perch_for(g)
		if not pr.is_empty():
			g.set("perch", pr)
			g.set("state", "perched")
			g.set("p", pr["pos"] + Vector4(0.0, Gull.FOOT, 0.0, 0.0))
			g.set("_fold", 1.0)
			g.set("_legs", 1.0)
			g.set("speed", 0.0)
			var into := Vector4(wind.x, 0.0, wind.z, 0.0)
			g.set("forward", into.normalized() if into.length() > 0.05 else Vector4(0, 0, 1, 0))
			g.set("_stay", _rng.randf_range(4.0, 30.0))
	add_child(g)
	(g.get("called") as Signal).connect(_on_called.bind(g))
	gulls.append(g)


# -- sound --------------------------------------------------------------------------------------------------

func _make_sound() -> void:
	for nm in SOUNDS:
		var path: String = SOUND_DIR + nm + ".wav"
		if ResourceLoader.exists(path):
			_streams[nm] = load(path)
	if _streams.is_empty():
		return
	var send: StringName = send_bus if AudioServer.get_bus_index(send_bus) >= 0 else &"Master"
	for v in VOICES:
		var bus_name := StringName("%s%d" % [BUS_PREFIX, v])
		var bus: int = AudioServer.get_bus_index(bus_name)
		if bus < 0:
			AudioServer.add_bus()
			bus = AudioServer.bus_count - 1
			AudioServer.set_bus_name(bus, bus_name)
			AudioServer.add_bus_effect(bus, AudioEffectLowPassFilter.new(), 0)
			AudioServer.add_bus_effect(bus, AudioEffectPanner.new(), 1)
		AudioServer.set_bus_send(bus, send)
		var p := AudioStreamPlayer.new()
		p.bus = bus_name
		add_child(p)
		_voices.append({"player": p, "bus": bus})


## Plays a gull's call where it is: louder near, panned to its side, duller far off.
func _on_called(kind: String, g: Node4D) -> void:
	if _voices.is_empty() or not _streams.has(_sound_for(kind)) or not is_instance_valid(g):
		return
	var ear: Vector4 = Vector4.ZERO
	var right := Vector4(1, 0, 0, 0)
	if listener_4d != null and is_instance_valid(listener_4d):
		ear = listener_4d.global_position
		right = (listener_4d.global_basis * Vector4(1, 0, 0, 0)).normalized()
	var to: Vector4 = g.global_position - ear
	var d: float = to.length()
	if d > hearing:
		return
	var voice: Dictionary = _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	var p: AudioStreamPlayer = voice["player"]
	var bus: int = voice["bus"]
	# Inverse distance from 3 m in, and a fade to nothing at `hearing`.
	var level: float = volume_db - 20.0 * log(maxf(d, 3.0) / 3.0) / log(10.0) + 20.0 * log(maxf(1.0 - d / hearing, 0.01)) / log(10.0)
	if kind == "land":
		level -= 6.0
	p.volume_db = level
	p.pitch_scale = _rng.randf_range(0.92, 1.08)
	var pan: AudioEffectPanner = AudioServer.get_bus_effect(bus, 1) as AudioEffectPanner
	if pan != null:
		pan.pan = clampf(to.normalized().dot(right), -1.0, 1.0) * 0.8 if d > 0.01 else 0.0
	var lp: AudioEffectLowPassFilter = AudioServer.get_bus_effect(bus, 0) as AudioEffectLowPassFilter
	if lp != null:
		lp.cutoff_hz = lerpf(12000.0, 2200.0, clampf(d / hearing, 0.0, 1.0))
	p.stream = _streams[_sound_for(kind)]
	p.play()


func _sound_for(kind: String) -> String:
	match kind:
		"long":
			return "gull_long"
		"laugh":
			return "gull_laugh"
		"kek":
			return "gull_kek"
		"land":
			return "gull_land"
	return ""
