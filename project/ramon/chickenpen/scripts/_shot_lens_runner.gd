extends SceneTree

## The same frame at five camera philosophies, so the choice can be looked at rather than
## argued about.
##
## SUBJECT SIZE IS HELD CONSTANT across the first four, which is the only fair way to
## compare lenses: narrowing the lens alone just zooms in, and of course a zoomed frame
## looks different. Pull back by 1/tan(fov/2) as you narrow and the player stays the same
## height on screen - what changes then is PERSPECTIVE, which is the thing actually being
## chosen. The fifth is deliberately not matched; it is the close over-the-shoulder.

const PRESETS: Array = [
	# name, fov degrees, distance, pivot height, pitch degrees
	["A_now_77", 77.3, 5.00, 1.10, -8.6],
	["B_filmic_60", 60.0, 6.93, 1.30, -12.0],
	["C_diorama_45", 45.0, 9.66, 1.90, -22.0],
	["D_long_35", 35.0, 12.69, 2.40, -28.0],
	["E_shoulder_60", 60.0, 3.00, 1.50, -6.0],
]

var _s: Node
var _f: int = 0
var _rig: Node4D
var _cam: Camera4D


func _initialize() -> void:
	_s = load("res://ramon/chickenpen/playable_world.tscn").instantiate()
	root.add_child(_s)
	current_scene = _s
	var rig: Node = _s.get_node_or_null("Player/CameraRig") if _s != null else null
	if rig != null:
		rig.set("mouse_sensitivity", 0.0)
	_rig = _s.get_node("Player/CameraRig")
	_cam = _s.get_node("Player/CameraRig/Pitch/Camera4D")


func _process(_d) -> bool:
	_f += 1
	if _f < 30:
		return false
	var i: int = int((_f - 30) / 30)
	if i >= PRESETS.size():
		return true
	var step: int = (_f - 30) % 30
	if step == 0:
		var p: Array = PRESETS[i]
		# Pinned every time, so all five frames are the same view of the same thing.
		(_s.get_node("Player") as Node4D).global_position = Vector4(4.6, 1.2, -2.0, 0.0)
		_rig.set("yaw", deg_to_rad(27.1))
		_rig.set("distance", float(p[2]))
		_rig.set("_zoom_target", float(p[2]))
		_rig.set("pivot_height", float(p[3]))
		_rig.set("_home_pivot", float(p[3]))
		_rig.set("pitch", deg_to_rad(float(p[4])))
		_cam.set("field_of_view_3d", deg_to_rad(float(p[1])))
		_rig.call("_apply")
	if step == 25:
		var p2: Array = PRESETS[i]
		var d: Vector4 = _cam.global_position - (_s.get_node("Player") as Node4D).global_position
		print("frame %3d  %-14s fov %.1f  asked %.2f m back, got %.2f" % [
			_f, p2[0], float(p2[1]), float(p2[2]), d.length()])
	return false
