extends SceneTree

## The game as it plays, for a film (Ramon, 3 Oct: "I just want to record the main character
## walking around a bit in the game through the grass, and then maybe one overview shot", "which
## is not too high"). The player walks a loop through the meadow east of the pen on their own
## camera (the orbit rig), the runner holding the forward key and turning the rig gently towards
## each next point; then one overview, four and a half metres up, drifting, the player walking on
## towards the pen. No HUD; the game's own light and sound. From black and back to black.
## Recorded by the movie writer at a fixed 30 fps; prints the film time it starts at.
##
##   godot... --path project --windowed --resolution 1920x1080 --position 0,0
##       --write-movie <out>.avi --fixed-fps 30 --script res://ramon/chickenpen/grass/_film_walk_runner.gd
##
## With "stills" after "--": a frame every four seconds instead (res://smoke_test_output/
## walk_<n>.png), for checking it before a long render.

const WALK := 32.0
const OVERVIEW := 10.0
const FADE := 1.2
## The loop through the meadow, in x and z.
const POINTS := [Vector2(16.0, 3.0), Vector2(24.0, -5.0), Vector2(16.0, -13.0), Vector2(7.0, -5.0), Vector2(10.0, 4.0)]

var _room: Node
var _player: Node4D
var _rig: Node
var _cam: Camera4D
var _black: ColorRect
var _t: float = 0.0
var _started: bool = false
var _film_t: float = 0.0
var _point: int = 0
var _stills: bool = false
var _next_still: float = 0.0
var _n: int = 0
var _over_from := Vector4.ZERO


func _initialize() -> void:
	root.unfocusable = true
	_room = load("res://ramon/chickenpen/playable_world.tscn").instantiate()
	_room.get_node("Systems/Lookout").set("journal_path", "user://lookout_journal_walkfilm_test.cfg")
	root.add_child(_room)
	current_scene = _room
	_stills = OS.get_cmdline_user_args().has("stills")
	var layer := CanvasLayer.new()
	layer.layer = 90
	root.add_child(layer)
	_black = ColorRect.new()
	_black.color = Color.BLACK
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_black)


func _set_up() -> void:
	for c in _room.get_node("UI").get_children():
		if c is CanvasItem:
			(c as CanvasItem).visible = false
		c.process_mode = Node.PROCESS_MODE_DISABLED
	(_room.get_node("Player/StateLabel") as CanvasItem).visible = false
	_player = _room.get_node("Player") as Node4D
	_rig = _room.get_node("Player/CameraRig")
	_player.global_position = Vector4(8.0, 0.1, 1.0, 0.0)
	_player.set("linear_velocity", Vector4.ZERO)
	_rig.set("pitch", -0.22)
	var first: Vector2 = POINTS[0]
	_rig.set("yaw", atan2(-(first.x - 8.0), -(first.y - 1.0)))


func _hide_layers() -> void:
	for layer in _room.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false


func _process(d: float) -> bool:
	_t += d
	if not _started:
		if _t > 90.0:
			print("WALK FILM FAIL: no grass after 90 s")
			return true
		var grass: Node = _room.get_node_or_null("World/Grass")
		if (grass != null and not bool(grass.get("mask_ready"))) or _t < 6.0:
			return false
		_set_up()
		_started = true
		print("FILM FROM %.3f s" % _t)
		return false
	_film_t += d
	_hide_layers()
	var total: float = WALK + OVERVIEW
	_black.modulate.a = 1.0 - minf(clampf(_film_t / FADE, 0.0, 1.0), clampf((total - _film_t) / FADE, 0.0, 1.0))
	_walk(d)
	if _film_t >= WALK:
		_overview()
	if _stills and _film_t >= _next_still:
		_next_still += 4.0
		root.get_texture().get_image().save_png("res://smoke_test_output/walk_%d.png" % _n)
		_n += 1
	if _film_t >= total:
		Input.action_release(&"move_forward")
		print("WALK FILM DONE at %.3f s" % _t)
		return true
	return false


## On along the loop: the forward key held, the rig turned gently towards the next point, so the
## camera swings round with the walk rather than snapping.
func _walk(d: float) -> void:
	Input.action_press(&"move_forward")
	var here := Vector2(_player.global_position.x, _player.global_position.z)
	var to: Vector2 = POINTS[_point]
	if here.distance_to(to) < 2.5:
		_point = (_point + 1) % POINTS.size()
		to = POINTS[_point]
	var gap: Vector2 = to - here
	var want: float = atan2(-gap.x, -gap.y)
	var yaw: float = float(_rig.get("yaw"))
	_rig.set("yaw", rotate_toward(yaw, want, d * 0.45))
	_rig.set("pitch", -0.22)


## One shot from a way off and not high: four and a half metres up, drifting slowly sideways,
## keeping the player in frame as they walk on.
func _overview() -> void:
	if _cam == null:
		_cam = Camera4D.new()
		_cam.set("rendering_engine_name", "Cross-section")
		_room.add_child(_cam)
		var at: Vector4 = _player.global_position
		var pen: Vector4 = (_room.get_node("Pen/Fence") as Node4D).global_position
		var away := Vector2(at.x - pen.x, at.z - pen.z).normalized()
		var side := Vector2(-away.y, away.x)
		_over_from = Vector4(at.x + away.x * 10.0 + side.x * 8.0, 4.5, at.z + away.y * 10.0 + side.y * 8.0, 0.0)
		_cam.make_current()
	var k: float = clampf((_film_t - WALK) / OVERVIEW, 0.0, 1.0)
	var pen: Vector4 = (_room.get_node("Pen/Fence") as Node4D).global_position
	var drift: Vector4 = (pen - _over_from)
	drift.y = 0.0
	_cam.global_basis = Projection.IDENTITY
	_cam.global_position = _over_from + drift.normalized() * 3.0 * smoothstep(0.0, 1.0, k)
	_cam.look_at(_player.global_position.lerp(pen, 0.25) + Vector4(0.0, 0.8, 0.0, 0.0))
	_cam.make_current()
