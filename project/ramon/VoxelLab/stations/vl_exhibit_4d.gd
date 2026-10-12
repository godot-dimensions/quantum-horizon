extends Node4D

## The Voxel Lab: a specimen on a pedestal, as the carried showcase (carried/kit/kit_showcase_4d.gd)
## holds an exhibit. The hero block, the column and the engine's test cases extend this; it holds what
## they share:
##
##   THE STAND      a turntable (the room never moves, the exhibit does: the cinema's rule) holding the
##                  specimen (specimen/vl_specimen_4d.gd), shown `display_scale` times its real size: a
##                  voxel costs the same however big it is drawn, so the pedestal can be cinema scale.
##   THE SPARE      a second, untouched specimen built at load and kept drawn, parked far below the
##                  floor, so a reset is a swap (Crosswise's trick): no frame pays for a rebuild. The used
##                  one is let go and the next spare is built hidden in the background, its draw buffers
##                  made on a worker thread before it is shown. `spare` off: a reset rebuilds in place.
##   THE STORY      chapters() (each {key, title, length, line, callouts, eye, look, fov}) and
##                  play_part(key, t, length), as the kit's presenter reads them; numbers() fills the
##                  callouts.
##   THE BENCH      `specimen` is what the bench cuts; `held` stops the turntable while you work.
##
## NO class_name (engine_gotchas.md).

signal reset_done

const Specimen := preload("res://ramon/VoxelLab/specimen/vl_specimen_4d.gd")
const Recipe := preload("res://ramon/VoxelLab/specimen/vl_recipe.gd")
const Cut := preload("res://ramon/VoxelLab/specimen/vl_cut.gd")

## Where a spare waits, below the floor, drawn.
const PARKED := Vector4(0, -300, 0, 0)

## Set by the showcase; specimens ignore them.
var grow_in: bool = false
var joint_balls: bool = true

## The code on the band and the cards ("VX-01").
var code: String = "VX-01"
var title: String = "Specimen"
## How many times its real size it is shown.
var display_scale: float = 1.0
## The turntable, degrees a second.
var turn_speed: float = 5.0
## Keep a spare for an instant reset.
var spare_on: bool = true

var stand: Node4D
var specimen: Node4D
var spare: Node4D
## True while the bench has it: the turntable stops.
var held: bool = false
## A fresh specimen being built hidden for a reset with no spare.
var _rebuilding: Node4D
var _yaw: float = 0.0
var _resets: int = 0


func _ready() -> void:
	stand = Node4D.new()
	stand.name = "Stand"
	add_child(stand)
	specimen = _make("Specimen", false)
	if spare_on:
		spare = _make("Spare", true)


## The recipe this exhibit shows (each exhibit its own).
func recipe() -> Dictionary:
	return {}


## A specimen built from recipe(): standing on the deck, or parked and built hidden.
func _make(nm: String, parked: bool, hidden: bool = false) -> Node4D:
	var r: Dictionary = recipe()
	var s := Node4D.new()
	s.name = nm
	s.set_script(Specimen)
	s.set("hidden_build", parked or hidden)
	s.scale = Vector4.ONE * display_scale
	s.position = _rest_position(r) + (PARKED if parked else Vector4.ZERO)
	stand.add_child(s)
	s.call("build", r)
	_after_make(s)
	return s


## The specimen's middle above the deck: its half height, shown size, plus a hair.
func _rest_position(r: Dictionary) -> Vector4:
	var h: Vector4 = r.get("half", Vector4.ONE)
	return Vector4(0, h.y * float(r.get("voxel", 0.1)) * display_scale + 0.01, 0, 0)


## For an exhibit to wire up a new specimen (signals and the like).
func _after_make(_s: Node4D) -> void:
	pass


func is_ready() -> bool:
	return specimen != null and bool(specimen.call("is_ready"))


## Whole again. With a spare ready, at once; otherwise rebuilt in place.
func reset() -> void:
	_resets += 1
	if spare != null and bool(spare.call("is_ready")):
		var used: Node4D = specimen
		specimen = spare
		specimen.name = "Specimen%d" % _resets
		specimen.position = _rest_position(specimen.get("recipe"))
		used.queue_free()
		spare = null
		# The next spare, built hidden in the background.
		(func() -> void:
			if is_inside_tree() and spare_on:
				spare = _make("Spare%d" % _resets, true)).call_deferred()
	elif _rebuilding == null:
		# No spare (the big specimens): a fresh one built hidden where it stands, its draw buffers on a
		# worker, then swapped in; the used one stays on show until then (a second or two).
		_rebuilding = _make("Rebuild%d" % _resets, false, true)
		_rebuilding.connect("built", func(_st: Dictionary) -> void:
			var used: Node4D = specimen
			specimen = _rebuilding
			_rebuilding = null
			if is_instance_valid(used):
				used.queue_free(), CONNECT_ONE_SHOT)
	reset_done.emit()


func grown() -> bool:
	return is_ready()


func _process(_delta: float) -> void:
	pass


## The turntable, between stories (the showcase calls it).
func idle(delta: float) -> void:
	if held:
		return
	_yaw += deg_to_rad(turn_speed) * delta
	stand.basis = Basis4D.from_zx(_yaw)


## Square to the room (the bench and the story both want the front face toward you).
func face_front(k: float = 1.0) -> void:
	_yaw = lerp_angle(_yaw, 0.0, k)
	stand.basis = Basis4D.from_zx(_yaw)


func stand_basis() -> Projection:
	return stand.basis if stand != null else Projection.IDENTITY


## How far it reaches through W either side of its middle (shown size), metres.
func w_extent() -> float:
	var r: Dictionary = recipe()
	return (r.get("half", Vector4.ONE) as Vector4).w * float(r.get("voxel", 0.1)) * display_scale


func end_cinematic() -> void:
	pass


func chapters() -> Array:
	return []


func play_part(_key: String, _t: float, _length: float) -> Dictionary:
	return {}


## The numbers a callout or card can name.
func numbers() -> Dictionary:
	var st: Dictionary = specimen.get("stats") if specimen != null else {}
	var r: Dictionary = specimen.get("recipe") if specimen != null else {}
	var v: float = float(r.get("voxel", 0.1))
	var h: Vector4 = r.get("half", Vector4.ONE)
	var size: Vector4 = h * 2.0 * v
	return {
		"voxel": "%.0f cm" % (v * 100.0),
		"shown_voxel": "%.1f cm" % (v * 100.0 * display_scale),
		"size": "%.1f x %.1f x %.1f x %.1f m" % [size.x, size.y, size.z, size.w],
		"voxels": thousands(int(r.get("voxel_count", 0))),
		"chunks": str(int(st.get("chunks", 0))),
		"tets": thousands(int(st.get("tets", 0))),
		"mb": "%.0f MB" % float(st.get("mb", 0.0)),
		"mesh_ms": "%.0f ms" % float(st.get("mesh_ms", 0.0)),
	}


func data() -> Dictionary:
	var st: Dictionary = specimen.get("stats") if specimen != null else {}
	return {"name": title, "code": code, "icon": "cube", "stats": {"tetra": int(st.get("tets", 0))}}


func bench() -> Dictionary:
	return specimen.get("stats") if specimen != null else {}


func action_label() -> String:
	return ""


func action() -> String:
	return ""


func band_line() -> String:
	var n: Dictionary = numbers()
	return "%s  ·  %s VOXELS OF %s  ·  %s TETRAHEDRA  ·  LIVE" % [title.to_upper(), String(n["voxels"]), String(n["voxel"]).to_upper(), String(n["tets"])]


func card() -> Dictionary:
	return {}


func live() -> Array:
	return []


## The cuts made so far on the specimen in hand.
func cut_count() -> int:
	return (specimen.get("cuts") as Array).size() if specimen != null else 0


static func thousands(n: int) -> String:
	var s: String = str(absi(n))
	var out: String = ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out
