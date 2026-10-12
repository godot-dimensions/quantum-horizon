@tool
extends Node4D

## Kit: a handle for the sun. Move this node in the editor (or with the light panel's Sun sliders
## while playing) and the room's key light comes from where it stands, towards `target` (Ramon,
## 4 Oct: "put in the gizmo a way for me to tweak sun direction"). A small glowing marker and a
## dotted line to the target show it in the editor; in the game they are hidden.
##
## The LabKit room (lab_room_4d.gd) takes the sun as an elevation and an azimuth in its mood
## settings; this writes both into its mood_overrides for every mood, keeping whatever else is
## there, and re-applies the mood.
##
## NO class_name (engine_gotchas.md).

const Build := preload("res://ramon/Arboretum/carried/scripts/chamber_build.gd")
const Batch := preload("res://ramon/Arboretum/carried/LabKit/lab_batch.gd")
const Mats := preload("res://ramon/Arboretum/carried/LabKit/lab_materials.gd")

## The LabKit Room whose sun this sets.
@export var room: NodePath = NodePath("../Room")
## The point the sun shines towards, world x, y, z (the exhibit).
@export var target: Vector3 = Vector3(0, 0, -1.5)

var _last: Vector4 = Vector4.INF
var _last_target: Vector3 = Vector3.INF
var _marker: Node4D


func _ready() -> void:
	_build_marker()


func _process(_delta: float) -> void:
	if not is_inside_tree():
		return
	if global_position != _last or target != _last_target:
		_last = global_position
		_last_target = target
		_apply()
		if Engine.is_editor_hint():
			_build_marker()


## The sun's elevation and azimuth in degrees, as the room takes them.
func angles() -> Vector2:
	var d: Vector4 = global_position - Vector4(target.x, target.y, target.z, 0.0)
	var dir := Vector3(d.x, d.y, d.z)
	if dir.length() < 0.001:
		return Vector2(90.0, 0.0)
	dir = dir.normalized()
	return Vector2(rad_to_deg(asin(clampf(dir.y, -1.0, 1.0))), rad_to_deg(atan2(dir.x, dir.z)))


## Moves the handle to this elevation and azimuth (degrees), keeping its distance from the target.
func set_angles(elevation: float, azimuth: float) -> void:
	var t := Vector4(target.x, target.y, target.z, 0.0)
	var dist: float = maxf((global_position - t).length(), 1.0)
	var e: float = deg_to_rad(elevation)
	var a: float = deg_to_rad(azimuth)
	global_position = t + Vector4(sin(a) * cos(e), sin(e), cos(a) * cos(e), 0.0) * dist


func _apply() -> void:
	var r: Node = get_node_or_null(room)
	if r == null:
		return
	var ang: Vector2 = angles()
	var all: Dictionary = (r.get("mood_overrides") as Dictionary).duplicate(true)
	for m in ["bright", "dark"]:
		var over: Dictionary = (all.get(m, {}) as Dictionary).duplicate()
		over["key_elevation"] = ang.x
		over["key_azimuth"] = ang.y
		all[m] = over
	r.set("mood_overrides", all)
	r.call("set_mood", String(r.get("mood")), true, false)


func _build_marker() -> void:
	if is_instance_valid(_marker):
		_marker.queue_free()
	_marker = null
	if not Engine.is_editor_hint():
		return
	var b := Batch.new()
	b.box("m", Vector4(0.5, 0.5, 0.5, 0.5), Vector4.ZERO)
	# A dotted line down to the target, in the handle's own space.
	var to: Vector4 = Vector4(target.x, target.y, target.z, 0.0) - global_position
	var steps: int = int(to.length() / 0.5)
	for i in range(1, steps):
		b.box("m", Vector4(0.08, 0.08, 0.08, 0.3), to * (float(i) / float(steps)))
	_marker = b.instance("m")
	_marker.name = "SunMarker"
	_marker.material_override = Mats.glow(Color(1.0, 0.85, 0.3), 1.5)
	_marker.set_meta(Build.GENERATED, true)
	add_child(_marker)
