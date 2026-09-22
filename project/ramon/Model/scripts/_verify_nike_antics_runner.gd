extends SceneTree

## Drives Nike's behaviour through every state and photographs each one, because none of
## it is visible in a still of the default pose. The state machine's own timers are far
## too long to wait out, so this forces each state in turn and lets it settle.

const _DIR: String = "res://smoke_test_output/"

var _antics: Node
var _walker: Node
var _rig: Node4D
var _camera: Camera4D
var _frames: int = 0
var _step: int = 0

# state to force, frames to hold it, what to call the shot
var _plan: Array = [
	[0, 26, "antics_walk"],
	[1, 30, "antics_root"],
	[2, 34, "antics_going_down"],
	[3, 30, "antics_lying"],
	[4, 18, "antics_getting_up"],
]


func _initialize() -> void:
	var scene: Node = (load("res://ramon/Model/animation_test.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	var nike: Node4D = scene.get_node("Nike")
	nike.position = Vector4(24.0, 0.0, 3.0, 0.0)
	_antics = scene.get_node("Nike/Antics")
	_walker = scene.get_node("Nike/Walker")
	_rig = scene.get_node("Nike/Hide")
	var horse: Node = scene.get_node("Creature/Strider")
	horse.get_node("Walker").set_process_mode(Node.PROCESS_MODE_DISABLED)
	horse.get_node("Hide").visible = false
	_camera = Camera4D.new()
	_camera.rendering_engine_name = "Cross-section"
	_camera.focal_length_3d = 2.75
	_camera.position = Vector4(30.6, 1.5, 4.4, 0.0)
	_camera.basis = Projection(
		Vector4(0, 0, -1, 0), Vector4(0.16, 0.987, 0, 0), Vector4(0.987, -0.16, 0, 0),
		Vector4(0, 0, 0, 1))
	scene.add_child(_camera)
	_camera.current = true


func _process(_d) -> bool:
	_frames += 1
	if _frames < 24:
		return false
	if _step >= _plan.size():
		return true
	var want: int = int(_plan[_step][0])
	var hold: int = int(_plan[_step][1])
	# Forced each frame, with BOTH clocks pinned: the machine would otherwise advance
	# itself straight back out, and its blend is a function of how far through the state
	# it is - leaving the timer at zero photographs the pose before it has faded in, which
	# is how the first run came back with a rooting pig standing perfectly upright.
	_antics.set("state", want)
	var pinned: Array = [
		[0.0, 8.0],   # walking: anywhere in the middle
		[1.5, 3.0],   # rooting: fully down, and not yet fading out
		[0.7, 1.1],   # going down: most of the way over
		[2.0, 10.0],  # lying: settled
		[0.4, 1.6],   # getting up: partway back
	][want]
	_antics.set("_timer", pinned[0])
	_antics.set("_limit", pinned[1])
	if _frames < 24 + hold:
		return false
	_report(String(_plan[_step][2]))
	var image: Image = root.get_texture().get_image()
	if image != null:
		image.save_png(_DIR + String(_plan[_step][2]) + ".png")
	_step += 1
	_frames = 0
	return false


func _report(label: String) -> void:
	print("%-20s halted=%-5s rig_y=%+.3f  basis.y=(%+.2f,%+.2f,%+.2f)" % [
		label, str(_walker.get("halted")), _rig.position.y,
		_rig.basis.y.x, _rig.basis.y.y, _rig.basis.y.z])
