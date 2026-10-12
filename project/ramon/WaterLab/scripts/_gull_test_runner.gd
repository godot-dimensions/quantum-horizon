extends "res://ramon/WaterLab/scripts/_wl_shots.gd"

## WATER LAB: the gull on its own, each pose held still: the glide (side, front, above, three
## quarters, from below), four moments of a wingbeat, the flare, the folded wings. Frames in
## smoke_test_output/water_lab/gull/.

const Gull := preload("res://ramon/WaterLab/gull/gull_4d.gd")
const AT := Vector4(0.0, 1.0, 0.0, 0.0)

var _world: Node4D
var _gull: Node4D
var _cam: Camera4D


func setup() -> void:
	out = "res://smoke_test_output/water_lab/gull/"
	tag = "GULL"
	_world = test_world(Vector4(1.9, 1.05, 0.0, 0.0), AT)
	_cam = _world.get_node("Camera") as Camera4D
	_gull = Node4D.new()
	_gull.name = "Gull"
	_gull.set_script(Gull)
	_world.add_child(_gull)
	var only: String = ""
	for a in OS.get_cmdline_user_args():
		only = a
	step(5, _hold.bind("glide", 0.0))
	var views: Dictionary = {
		"side": Vector4(1.9, 1.05, 0.0, 0.0), "front": Vector4(0.0, 1.1, 2.0, 0.0), "above": Vector4(0.01, 2.9, 0.0, 0.0),
		"tq": Vector4(1.35, 1.6, 1.35, 0.0), "below": Vector4(0.9, 0.25, 0.9, 0.0), "back": Vector4(0.0, 1.3, -2.0, 0.0)}
	var plan: Array = [
		["glide", 0.0, ["side", "front", "above", "tq", "below"]],
		["flap", 0.0, ["front", "tq"]], ["flap", 0.22, ["front", "tq"]], ["flap", 0.45, ["front", "tq"]], ["flap", 0.72, ["front", "tq", "side"]],
		["flare", 0.0, ["side", "tq", "front"]],
		["folded", 0.0, ["side", "above", "tq", "back"]],
		["stretch", 0.0, ["side", "tq"]],
	]
	var n: int = 0
	for row in plan:
		var nm: String = row[0]
		if not only.is_empty() and nm != only:
			continue
		step(1, _hold.bind(nm, float(row[1])))
		for v in row[2]:
			n += 1
			step(1, _eye.bind(views[v]))
			step(3, nop, "%02d_%s%s_%s" % [n, nm, "" if nm != "flap" else str(int(float(row[1]) * 100)), v])


func _hold(nm: String, k: float) -> void:
	_gull.set_process(false)
	_gull.set("p", AT)
	_gull.set("forward", Vector4(0, 0, 1, 0))
	_gull.set("_flare", 1.0 if nm == "flare" else 0.0)
	_gull.set("state", "perched" if nm == "folded" else "roam")
	_gull.call("apply_pose", Gull.pose(nm, k))
	_gull.call("_place")


func _eye(at: Vector4) -> void:
	aim(_cam, at, AT)
