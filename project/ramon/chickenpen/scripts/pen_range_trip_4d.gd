extends Node

## To the shooting range and back, with the pen exactly as you left it.
##
## A REAL SCENE CHANGE, NOT A HOSTED ONE. Ramon: "when walking into the shooting gallery,
## you can be teleported to that actual corresponding tscn. I don't want you to build a
## working shooting gallery inside the chicken pen." The cave and the theatre are opened
## beside the field by pen_crossing_4d; the gallery cannot be - its root is a Control, its
## world is built at the origin where the field is, and it has its own player, camera and
## environment. So this swaps scenes properly.
##
## BUT THE PEN IS PARKED, NOT FREED. change_scene_to_file would throw away the run - the
## chickens carried home, the watch, the gold. Instead the pen's root is taken out of the
## tree and held, the gallery becomes the current scene, and coming back frees the gallery
## and puts the very same pen back. Out of the tree it does not process, so it is exactly
## as you left it; it costs its memory while you are away, which it was already costing.
##
## THE WAY HOME IS LEFT ON THE ROOT, NOT WIRED INTO THE GALLERY. The gallery's own return
## key goes to the menu, and it is launched from the menu too, so it must keep doing that.
## While the pen is parked, a Callable and a label are left as metadata on the tree root;
## the range's way-home node (QuantumRange/scripts/range_way_home_4d.gd since 5 Oct; the old
## gallery's range_way_home_ramon.gd before it) looks for them and, if they are there, relabels
## its return prompt and uses them instead. Launched from the menu there is nothing there
## and it behaves as it always has. Neither side preloads the other.

const QUESTS := preload("res://ramon/chickenpen/scripts/pen_quests_4d.gd")

@export_file("*.tscn") var gallery_path: String = "res://ramon/QuantumRange/quantum_range_final.tscn"
@export var camera_path: NodePath = NodePath("../../Player/CameraRig/Pitch/Camera4D")
@export var label: String = "BACK TO THE CHICKEN PEN   %s"

const WAY_HOME := "chickenpen_way_home"
const WAY_HOME_LABEL := "chickenpen_way_home_label"

var _pen: Node
var _gallery: Node
var _mouse := Input.MOUSE_MODE_VISIBLE


func is_away() -> bool:
	return _pen != null


## Off to the range. Deferred: this is reached from a conversation ending, inside input
## handling, and swapping the current scene there pulls the ground out from under it.
func go() -> void:
	if is_away():
		return
	_swap.call_deferred()


func _swap() -> void:
	var tree := get_tree()
	var packed: PackedScene = load(gallery_path) as PackedScene
	if packed == null:
		push_warning("RangeTrip: no gallery at %s" % gallery_path)
		return
	QUESTS.mark_visited("range")
	_mouse = Input.mouse_mode
	_pen = tree.current_scene
	tree.root.remove_child(_pen)
	_gallery = packed.instantiate()
	tree.root.set_meta(WAY_HOME, come_back)
	tree.root.set_meta(WAY_HOME_LABEL, label)
	tree.root.add_child(_gallery)
	tree.current_scene = _gallery


## Home again. Called by the gallery through the root's metadata.
func come_back() -> void:
	if not is_away():
		return
	_return.call_deferred()


func _return() -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree.root.has_meta(WAY_HOME):
		tree.root.remove_meta(WAY_HOME)
	if tree.root.has_meta(WAY_HOME_LABEL):
		tree.root.remove_meta(WAY_HOME_LABEL)
	if is_instance_valid(_gallery):
		tree.root.remove_child(_gallery)
		_gallery.queue_free()
	_gallery = null
	var pen: Node = _pen
	_pen = null
	tree.root.add_child(pen)
	tree.current_scene = pen
	var camera: Node = get_node_or_null(camera_path)
	if camera != null:
		camera.set("current", true)
	Input.mouse_mode = _mouse
