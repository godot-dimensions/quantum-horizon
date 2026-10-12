extends RefCounted
class_name PrototypeLauncher

## Starting a prototype from a menu, and getting back out of it intact.
##
## Lifted wholesale out of `menu2.gd`, which had the only working version of
## this. It is extracted rather than copied because the logic is subtle in three
## separate places, all of them discovered the hard way, and two screens each
## carrying their own copy is how one of them silently stops matching the other.
##
## The three things that are not obvious:
##
## 1. **The prototype is a CHILD OF THE ROOT, not a scene change.**
##    `change_scene_to_file` frees the CURRENT scene - the menu - so a prototype
##    that adds anything to the root outlives it. That is what left an orphaned
##    return prompt floating over a freshly reloaded menu. Keeping the menu alive
##    underneath means leaving is a `queue_free`, and played state survives.
##
## 2. **`move_child(node, 0)` is the Esc fix.**
##    `player.gd` handles `ui_cancel` itself and calls change_scene_to_file on
##    the OLD menu. Godot delivers `_input` in REVERSE tree order, so putting the
##    prototype FIRST makes the menu last, and the menu therefore sees Esc first
##    and can consume it before the player ever hears about it. Done here rather
##    than by editing `player.gd`, which is shared with the whole project.
##
## 3. **The prototype's own return button is muted, not hidden.**
##    Its prompt is the only thing telling a player which key gets them out, so
##    it stays on screen; only its input handling is switched off, and the menu
##    answers H itself with the same lossless unwind Esc uses.
##
## 4. **The prototype IS made the current scene, while staying a root child.**
##    This used to be left alone, with a known cost: a prototype identifying
##    itself by `current_scene.scene_file_path` - MiegakureLook's level base
##    does - could not tell which level it was. The second consequence was worse
##    and took a soft-lock to find. A prototype with a door of its own calls
##    `change_scene_to_file`, which frees the CURRENT scene: the menu, not the
##    prototype. The new scene arrived while the old one was still running
##    underneath, its door trigger fired again, and the Aquatic Lab bounced
##    between the pier and a black loading screen for ever.
##
##    Setting `current_scene` costs nothing here - the node is already parented
##    to the root, and Esc still works because that is decided by tree ORDER
##    (see 2), not by which scene is current. It also fixes the known cost.
##    `close()` is what needs the care: see its note.

## Real, measured progress for the resource load only.
signal progress_changed(value: float)
## "LOADING", then "BUILDING THE SCENE". See `stage` note below.
signal stage_changed(stage: String)
signal failed(message: String)
signal launched(node: Node)
signal closed()

const STAGE_LOADING: String = "LOADING"
const STAGE_BUILDING: String = "BUILDING THE SCENE"

var _host: Node = null
var _running: Node = null
var _busy: bool = false
## The menu, set aside while a prototype is the current scene.
var _menu_scene: Node = null


func _init(host: Node) -> void:
	_host = host


func is_running() -> bool:
	# `is_instance_valid`, not a null test: a prototype that swapped itself out through
	# change_scene_to_file leaves this holding a freed node.
	return _running != null and is_instance_valid(_running)


func is_busy() -> bool:
	return _busy


func running_node() -> Node:
	return _running


## Loads and enters `path`. Awaits until the prototype is on screen.
##
## Returns false and emits `failed` for a missing or unloadable scene, so a
## caller can put the reason in its own UI rather than only in the console.
func launch(path: String) -> bool:
	if _busy or _host == null or not _host.is_inside_tree():
		return false
	if path == "":
		failed.emit("no scene wired yet - nothing to launch")
		return false
	if not ResourceLoader.exists(path):
		push_error("prototype launcher: scene missing - %s" % path)
		failed.emit("MISSING: %s" % path)
		return false

	_busy = true
	stage_changed.emit(STAGE_LOADING)
	progress_changed.emit(0.0)

	var tree: SceneTree = _host.get_tree()
	# STOPGAP for a 4D-module bug reported to Aaron on 30 Sept 2026: after a Cross-section
	# scene has let go of the root Window it has no World3D, and a Combined scene launched
	# then crashes the engine. menu_final.gd's ensure_root_world_3d() explains it at length;
	# this is the same one-line guard for the Frontier Map, which launches through here.
	if tree.root.world_3d == null:
		tree.root.world_3d = World3D.new()
	# TWO frames, not one. Showing an overlay only QUEUES a redraw; the first
	# frame after this is when it reaches the screen. Blocking on the load before
	# that gives the frozen click the overlay exists to remove.
	await tree.process_frame
	await tree.process_frame

	ResourceLoader.load_threaded_request(path)
	while true:
		var reported: Array = []
		var status: int = ResourceLoader.load_threaded_get_status(path, reported)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			break
		if status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			push_error("prototype launcher: could not load %s" % path)
			failed.emit("could not load %s" % path)
			_busy = false
			return false
		if reported.size() > 0:
			progress_changed.emit(float(reported[0]))
		await tree.process_frame

	progress_changed.emit(1.0)
	# The honest part. `instantiate()` runs the prototype's `_ready` on the main
	# thread - Portal builds 21 chunks in ~1,093 ms there, Voxel Mining ~512 ms -
	# and that cannot be measured or interrupted. So the bar stops and the label
	# says what is happening rather than inventing a percentage.
	stage_changed.emit(STAGE_BUILDING)
	await tree.process_frame

	var packed: PackedScene = ResourceLoader.load_threaded_get(path) as PackedScene
	if packed == null:
		push_error("prototype launcher: could not load %s" % path)
		failed.emit("could not load %s" % path)
		_busy = false
		return false

	_running = packed.instantiate()
	_claim_return_button(_running)
	tree.root.add_child(_running)
	tree.root.move_child(_running, 0)
	# The menu is remembered rather than assumed, so close() can put it back as the current
	# scene without caring what else has happened in between.
	if _menu_scene == null:
		_menu_scene = tree.current_scene
	tree.current_scene = _running

	_busy = false
	launched.emit(_running)
	return true


## Frees the running prototype and hands control back to the menu.
##
## Deferred free for the same reason gate triggers and level hand-offs are:
## tearing a scene down from inside input dispatch pulls the ground out from
## under the event still being delivered.
func close() -> void:
	var tree: SceneTree = _host.get_tree() if _host != null else null
	# WHAT IS ACTUALLY RUNNING MAY NOT BE WHAT WAS LAUNCHED. A prototype with a door of its
	# own - the Aquatic Lab's sea, the Voxel Lab's open world, the Creature Lab's hall -
	# replaces itself through change_scene_to_file, which leaves `_running` pointing at a
	# freed node and the second scene as the current one. Freeing only `_running` would then
	# leave that second scene on screen under the menu.
	var live: Node = _running if (_running != null and is_instance_valid(_running)) else null
	if live == null and tree != null and tree.current_scene != null 			and tree.current_scene != _menu_scene:
		live = tree.current_scene
	_running = null
	if live != null:
		live.queue_free()
	if tree != null and _menu_scene != null and is_instance_valid(_menu_scene):
		tree.current_scene = _menu_scene
	_menu_scene = null
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	closed.emit()


## Switches off the prototype's own return handling without hiding its prompt.
##
## Recognised by duck typing on `hub_scene_path` rather than by class, because
## the prompt is `Demo/return_button.tscn` instanced into scenes that otherwise
## share no base type.
func _claim_return_button(node: Node) -> void:
	for child in node.get_children():
		if "hub_scene_path" in child:
			child.set_process_unhandled_input(false)
			child.set_process_input(false)
		_claim_return_button(child)
