extends CanvasLayer

## FROM THE FITTING CIRCLE TO TRYM'S FITTING ROOM AND BACK (outfit/PLAN_FITTING_ROOM.md), with the
## farm exactly as you left it.
##
## THE LAPTOP TRIP'S TRICK (scripts/pen_laptop_trip_4d.gd, whose notes on the environment are the
## reason for half of this): the pen is taken out of the tree and held, not freed, the room becomes
## the current scene, and on the way back the room goes and the pen is put back. This node lives on
## the window's root, outside both, so it outlives the swap.
##
## WHAT IT PUTS BACK. The WorldEnvironment4D that was lighting the farm (marked current and not under a
## branch a crossing has hidden), made current again, as the farm's evening otherwise loses the sky to
## whichever environment entered the tree last; the pen's camera; the mouse as it was. The room does
## not touch the window, so there is nothing of the window to restore.
##
## A FLASH, NOT A CUT. A pale cyan veil over everything for a fifth of a second either way: the arch's
## field colour, so the trip reads as Trym's tech doing it rather than a loading screen.

signal arrived
signal home

const NAME := &"OutfitRoomTrip"
const VEIL := Color(0.85, 0.97, 1.0)

var _pen: Node
var _camera: Camera4D
var _mouse: Input.MouseMode = Input.MOUSE_MODE_VISIBLE
var _environment: Node
var _veil: ColorRect
var _busy: bool = false
var _room: Node


func _ready() -> void:
	layer = 120
	_veil = ColorRect.new()
	_veil.name = "Veil"
	_veil.color = Color(VEIL.r, VEIL.g, VEIL.b, 0.0)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_veil)


## Whether the trip is between the farm and the room right now.
func is_busy() -> bool:
	return _busy


## Whether there is a farm parked behind the room to go back to.
func has_pen() -> bool:
	return _pen != null and is_instance_valid(_pen)


## To the room: flash, swap, unflash.
func go(room_path: String, camera: Camera4D) -> void:
	if _busy:
		return
	var packed: PackedScene = load(room_path) as PackedScene
	if packed == null:
		push_warning("OutfitRoomTrip: no room at %s" % room_path)
		return
	_busy = true
	_camera = camera
	await _fade(1.0, 0.2)
	var tree := get_tree()
	_mouse = Input.mouse_mode
	_pen = tree.current_scene
	_environment = _environment_in_use(_pen)
	tree.root.remove_child(_pen)
	_room = packed.instantiate()
	tree.root.add_child(_room)
	tree.current_scene = _room
	tree.root.move_child(self, -1)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await _fade(0.0, 0.35)
	_busy = false
	arrived.emit()


## Home: flash, the room freed and the farm put back as it was, unflash, and this node goes.
func come_back(saved: bool = true) -> void:
	if _busy:
		return
	_busy = true
	await _fade(1.0, 0.2)
	var tree := get_tree()
	var here: Node = tree.current_scene
	if here != null and here != _pen and is_instance_valid(here):
		tree.root.remove_child(here)
		here.queue_free()
	if has_pen():
		tree.root.add_child(_pen)
		tree.current_scene = _pen
	if _environment != null and is_instance_valid(_environment):
		_environment.call("make_current")
	if _camera != null and is_instance_valid(_camera):
		_camera.current = true
	Input.mouse_mode = _mouse
	# Tell the circle you are back, so it can say so over itself.
	var circle: Node = tree.get_first_node_in_group(&"outfit_circle")
	if circle != null and circle.has_method("came_back"):
		circle.call("came_back", saved)
	await _fade(0.0, 0.4)
	_busy = false
	home.emit()
	queue_free()


func _fade(to: float, seconds: float) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(_veil, "color:a", to, seconds)
	await tween.finished


## The WorldEnvironment4D lighting the farm: marked current and not inside a hidden branch, the last
## such in the tree (pen_laptop_trip_4d.gd's rule, kept here rather than reaching into that script).
static func _environment_in_use(scene: Node) -> Node:
	var found: Node = null
	for env in scene.find_children("*", "WorldEnvironment4D", true, false):
		if bool(env.get("current")) and (env as Node4D).is_visible_in_tree():
			found = env
	return found
