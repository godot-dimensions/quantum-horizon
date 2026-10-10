@tool
extends Node4D

## THE EDGE-ON DOOR (discovery, 9 Oct 2026; follow_up/pen_discovery_plan.md, easter egg 3): a doorway that is a thin
## glowing slit in the farm's slice and a whole door in a slice turned a quarter. Walk through it whole and you come
## out on top of the Watchstone. Ramon's brief: "a mysterious sci-fi door somewhere in the environment. When the
## player discovers it and walks through, they're transported to the top of the watchtower ... reuse an existing
## doorway or transition system". Placed in the quiet east of the valley (measured: the far edge north of where the
## town wall ends), about 70 m from the tower, so arriving on top is a real jump and you can look back at where you
## stood.
##
## WHAT IT TEACHES: that a thing can be thin in one slice and whole in another. The door is Trym's portal arch
## (theatre/theatre_arch_4d.gd: frame, edge strips, a shimmering field, its own two lamps and chime, the dev look
## leaving it be), built thin through W ([member w_depth]) and turned a quarter into W, so its width lies along W. In
## the farm's slice you see its cut across the middle of the doorway: the field edge-on, a narrow glowing slit with a
## sliver of lintel and sill. Turn your slice sideways a quarter and the slice holds W, height and depth: the whole
## arch stands there.
##
## THE TRIGGER IS ITS OWN, not the arch's: the arch measures you in its own frame, and turned into W its "flat
## distance" ignores x (anywhere along a line would wake it). Here you go through when you are inside the doorway's
## box (its depth along z, its width along W, a little either side in x) AND your slice is turned far enough that
## the door is whole in it (the slice's normal mostly along x). Walking into the slit at W 0 does nothing; that is
## the puzzle.
##
## THE WAY OUT is the Watchstone's own: arrive where its walk-up lands you (watchstone_4d.gd _climb_off, clear of the
## red oak, whose trunk box would hold you if you landed in it), the slice laid flat, facing back toward the door,
## and Systems/Lookout.on_cab_entered() (Wren's first-climb line). Down again by its "Go down?" ladder.
##
## NO class_name (engine_gotchas.md).

const Arch := preload("res://ramon/chickenpen/theatre/theatre_arch_4d.gd")
const WSense := preload("res://ramon/chickenpen/discovery/w_sense_4d.gd")

@export var player_path: NodePath = ^"../../Player"
@export var tower_path: NodePath = ^"../LookoutSite/Lookout"
@export var lookout_path: NodePath = ^"../../Systems/Lookout"
@export_range(0.8, 6.0, 0.1) var width: float = 2.2:
	set(v):
		width = v
		_later()
@export_range(1.4, 8.0, 0.1) var height: float = 3.1:
	set(v):
		height = v
		_later()
## How deep the arch is across the slice it is thin in (its depth through W before the turn).
@export_range(0.05, 1.0, 0.05) var w_depth: float = 0.3:
	set(v):
		w_depth = v
		_later()
@export var edge_color: Color = Color(0.78, 0.50, 1.0):
	set(v):
		edge_color = v
		_later()
@export var field_color: Color = Color(0.48, 0.30, 0.95):
	set(v):
		field_color = v
		_later()
## How far the slice must be turned for the door to count as whole: the share of the slice's normal along x.
@export_range(0.3, 1.0, 0.05) var whole_at: float = 0.6
## It lights and chimes when you come this close (ground distance), so a slit in a field is noticed.
@export_range(1.0, 20.0, 0.5) var notice_within: float = 9.0

var _player: CharacterBody4D
var _cam: Camera4D
var _arch: Node4D
var _fade: ColorRect
var _phase: int = 0
var _t: float = 0.0
var _cool: float = 0.0
var _near: bool = false
var _chime: AudioStreamPlayer
var _used_once: bool = false


func _later() -> void:
	if is_node_ready():
		rebuild()


func _ready() -> void:
	rebuild()
	if Engine.is_editor_hint():
		return
	add_to_group(&"discovery_reset")
	_player = get_node_or_null(player_path) as CharacterBody4D
	_cam = WSense.camera_of(_player)
	var layer := CanvasLayer.new()
	layer.name = "DoorFade"
	layer.layer = 58
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0.85, 0.80, 1.0, 0.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_fade)
	_chime = AudioStreamPlayer.new()
	_chime.name = "Chime"
	_chime.volume_db = -11.0
	add_child(_chime)
	if _arch != null and _arch.has_method("_make_chime"):
		_chime.stream = _arch.call("_make_chime")
	_build_hint()


func rebuild() -> void:
	if _arch != null and is_instance_valid(_arch):
		remove_child(_arch)
		_arch.free()
	_arch = Node4D.new()
	_arch.name = "Arch"
	_arch.set_script(Arch)
	_arch.set("player_path", NodePath(""))
	_arch.set("armed", true)
	_arch.set("starts_open", true)
	_arch.set("width", width)
	_arch.set("height", height)
	_arch.set("w_depth", w_depth)
	_arch.set("edge_color", edge_color)
	_arch.set("field_color", field_color)
	_arch.set("glow_color", edge_color)
	_arch.set("wakes_within", 0.0)
	_arch.set("highlight", 0.35)
	add_child(_arch)
	# A quarter into W: the door's width (its x) now lies along W, its thin W depth along x.
	_arch.basis = Basis4D.from_xw(PI * 0.5)


func _build_hint() -> void:
	var hint := Node4D.new()
	hint.name = "Hint"
	hint.add_to_group(&"w_hint")
	hint.set_meta(&"w_hint_key", "w_door")
	hint.set_meta(&"w_hint_skill", "turn_side")
	hint.set_meta(&"w_hint_radius", 7.0)
	hint.set_meta(&"w_hint_target", NodePath(".."))
	hint.set_meta(&"w_hint_done", "flag")
	hint.set_meta(&"w_hint_linger", 8.0)
	hint.set_meta(&"w_hint_tier_min", 1)
	hint.set_meta(&"w_hint_chip_always", true)
	add_child(hint)


## For the W guide's "flag" rule: done once you have been through.
func hint_done() -> bool:
	return _used_once


## How whole the door is in your slice: 0 edge-on (the farm's slice), 1 a quarter turned.
func wholeness() -> float:
	if _cam == null:
		return 0.0
	var n: Vector4 = _cam.global_basis.w.normalized()
	var across: Vector4 = global_basis * Vector4(1, 0, 0, 0)
	return absf(n.dot(across.normalized()))


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _player == null:
		return
	_cool = maxf(_cool - delta, 0.0)
	var local: Vector4 = global_basis.inverse() * (_player.global_position - global_position)
	var near: bool = Vector2(local.x, local.z).length() <= notice_within
	if near and not _near and _chime != null and _chime.stream != null:
		_chime.play()
	_near = near
	if _arch != null:
		_arch.set("highlight", lerpf(0.35, 1.0, maxf(wholeness(), 0.6 if near else 0.0)))
	match _phase:
		0:
			if _cool <= 0.0 and _player.get("input_enabled") != false and _inside(local) and wholeness() >= whole_at:
				_go()
		1:
			_t += delta
			_fade.color.a = clampf(_t / 0.35, 0.0, 1.0)
			if _t >= 0.35:
				_arrive()
		2:
			_t += delta
			_fade.color.a = 1.0 - clampf(_t / 0.6, 0.0, 1.0)
			if _t >= 0.6:
				_phase = 0
				_player.set("input_enabled", true)


## In the doorway: within its depth along z, its width along W, and a little either side of it in x.
func _inside(local: Vector4) -> bool:
	return absf(local.z) <= 1.0 and absf(local.w) <= width * 0.5 and absf(local.x) <= 0.9


func _go() -> void:
	_phase = 1
	_t = 0.0
	_used_once = true
	_player.set("input_enabled", false)
	_player.set("linear_velocity", Vector4.ZERO)
	if _chime != null and _chime.stream != null:
		_chime.play()


func _arrive() -> void:
	var tower: Node = get_node_or_null(tower_path)
	var at := Vector4(-14.9, 13.65, -34.85, 0.0)
	if tower != null and tower.has_method("_climb_off") and tower.has_method("_global"):
		at = tower.call("_global", tower.call("_climb_off"))
	at.w = 0.0
	_player.global_position = at + Vector4(0.0, 0.05, 0.0, 0.0)
	_player.set("linear_velocity", Vector4.ZERO)
	var rig: Node = _player.get_node_or_null("CameraRig")
	if rig != null:
		# The slice laid flat (it was turned a quarter to see the door), facing back over the field to where you stood.
		rig.call("align_to", 0.0)
		var look: Vector4 = global_position - at
		look.y = 0.0
		look.w = 0.0
		if look.length() > 0.1:
			rig.call("face_toward", look)
		rig.set("pitch", -0.28)
		if rig.has_method("_apply"):
			rig.call("_apply")
	var lookout: Node = get_node_or_null(lookout_path)
	if lookout != null and lookout.has_method("on_cab_entered"):
		lookout.call("on_cab_entered")
	_phase = 2
	_t = 0.0
	_cool = 2.0


func reset() -> void:
	_used_once = false
	_phase = 0
	_cool = 0.0
	if _fade != null:
		_fade.color.a = 0.0
