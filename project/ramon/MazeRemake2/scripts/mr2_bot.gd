extends RefCounted
## The test bot: plays the Annex through the player's real input actions (walking, Q/E, V through the
## game's own key handler), so a runner checks what a person would do. It faces where it wants to go by
## turning the body in place (the mouse's own path, player.look, would need pixel maths; the walk and W
## moves are the real ones).
##
## Every wait is bounded (memory: a runaway loop once crashed Ramon's PC). Waits count PHYSICS FRAMES
## (60 a second of game time), not the wall clock: the first frames of a level can be slow while its
## shaders compile, and a wall-clock budget ran out before the bot had walked (11 Oct). A wall-clock cap
## of four times the budget stays as the last guard.

var tree: SceneTree
var game: Node
var player: CharacterBody4D
var log_prefix: String = "BOT"
var fails: int = 0


func _init(t: SceneTree, g: Node) -> void:
	tree = t
	game = g
	player = g.get("player")


func check(ok: bool, what: String) -> void:
	print("%s %s: %s" % [log_prefix, "PASS" if ok else "FAIL", what])
	if not ok:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await tree.physics_frame


## Waits until `cond` is true, at most `seconds`.
func until(cond: Callable, seconds: float) -> bool:
	var t0: int = Time.get_ticks_msec()
	for i in int(seconds * 60.0) + 1:
		if cond.call():
			return true
		if Time.get_ticks_msec() - t0 > int(seconds * 4000.0):
			return false
		await tree.physics_frame
	return cond.call()


func face(x: float, z: float) -> void:
	var p: Vector4 = player.global_position
	var d := Vector2(x - p.x, z - p.z)
	if d.length() < 0.01:
		return
	var yaw: float = atan2(-d.x, -d.y)
	player.set("ground", Basis4D.from_zx(yaw))
	player.basis = Basis4D.from_zx(yaw)


func face_yaw(yaw: float) -> void:
	player.set("ground", Basis4D.from_zx(yaw))
	player.basis = Basis4D.from_zx(yaw)


## Walks to (x, z) through move_forward, facing it each step; true if it got within `near`.
func walk_to(x: float, z: float, seconds: float = 12.0, near: float = 0.35) -> bool:
	var t0: int = Time.get_ticks_msec()
	var ok: bool = false
	Input.action_press(&"move_forward")
	for i in int(seconds * 60.0):
		var p: Vector4 = player.global_position
		if Vector2(x - p.x, z - p.z).length() < near:
			ok = true
			break
		if Time.get_ticks_msec() - t0 > int(seconds * 4000.0):
			break
		face(x, z)
		await tree.physics_frame
	Input.action_release(&"move_forward")
	await frames(8)
	return ok


## Holds E (dir > 0) or Q until the player's W passes `w`, at most `seconds`; returns the W reached.
func shift_to(w: float, seconds: float = 8.0) -> float:
	var dir: float = signf(w - player.global_position.w)
	var action: StringName = &"move_ana" if dir > 0.0 else &"move_kata"
	Input.action_press(action)
	var t0: int = Time.get_ticks_msec()
	for i in int(seconds * 60.0):
		var pw: float = player.global_position.w
		if (dir > 0.0 and pw >= w) or (dir < 0.0 and pw <= w):
			break
		if Time.get_ticks_msec() - t0 > int(seconds * 4000.0):
			break
		await tree.physics_frame
	Input.action_release(action)
	await frames(10)
	return player.global_position.w


## Presses a key through the input system (the game's _unhandled_input hears it).
func key(code: Key) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = pressed
		Input.parse_input_event(e)
		await tree.process_frame
	await tree.process_frame
