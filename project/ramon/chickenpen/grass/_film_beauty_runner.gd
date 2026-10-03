extends SceneTree

## A beauty reel of the meadow and the pen (Ramon, 3 Oct: "can you create a cinematic video of the
## wavey grass and the pen in general, beauty shots"; then "more calm tilts of above showing the
## meadow 2 with the wavey grass.. not too much close up"): six calm shots from above at dusk, no
## HUD and no words, letterboxed, from black and back to black, with the farm's own sound. Recorded by the
## movie writer at a fixed 30 fps; it prints the film time the reel starts at ("REEL FROM"), so
## the wait for the grass can be cut off in the encode.
##
##   godot... --path project --windowed --resolution 1920x1080 --position 0,0
##       --write-movie <out>.avi --fixed-fps 30 --script res://ramon/chickenpen/grass/_film_beauty_runner.gd
##
## The teal sky fill is off for it, as for the films (Ramon, 1 Oct: "still best to turn off my
## teal blue light when showing the cinematics"); the wind up a little for the waves, more for the
## gust and the leaves; four chickens at home in the yard.

## [seconds, name, the grass's wind (times its own)]. Calm and from above, on the plain lens, the
## meadow (Hay meadow II) waving (Ramon, 3 Oct, after the first cut: "i want more calm tilts of
## above showing the meadow 2 with the wavey grass.. not too much close up").
const SHOTS := [
	[9.0, "tilt_down", 1.5], [9.0, "waves_from_above", 1.6], [10.0, "pen_orbit", 1.4],
	[9.0, "gust_from_above", 1.8], [9.0, "tilt_up_tower", 1.4], [11.0, "farewell", 1.4],
]
const FADE := 1.4

var _room: Node
var _grass: Node
var _cam: Camera4D
var _wide: float = 1.3
var _t: float = 0.0
var _started: bool = false
var _reel_t: float = 0.0
var _shot: int = 0
var _shot_t: float = 0.0
var _black: ColorRect
var _bars: Array[ColorRect] = []
var _own_wind: float = 1.0
## With "stills" after "--": a frame from the middle of each shot (res://smoke_test_output/
## beauty_<n>_<shot>.png), for checking the framing before a long render.
var _stills: bool = false
var _saved: Dictionary = {}


func _initialize() -> void:
	root.unfocusable = true
	_room = load("res://ramon/chickenpen/playable_world.tscn").instantiate()
	_room.get_node("Systems/Lookout").set("journal_path", "user://lookout_journal_beauty_test.cfg")
	root.add_child(_room)
	current_scene = _room
	_stills = OS.get_cmdline_user_args().has("stills")
	var layer := CanvasLayer.new()
	layer.layer = 90
	root.add_child(layer)
	for k in 2:
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		layer.add_child(bar)
		_bars.append(bar)
	_black = ColorRect.new()
	_black.color = Color.BLACK
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_black)


func _lay_out() -> void:
	var screen: Vector2 = root.get_visible_rect().size
	var bar: float = floorf((screen.y - minf(screen.y, screen.x / 2.39)) * 0.5)
	_bars[0].position = Vector2.ZERO
	_bars[0].size = Vector2(screen.x, bar)
	_bars[1].position = Vector2(0.0, screen.y - bar)
	_bars[1].size = Vector2(screen.x, bar)


func _set_up() -> void:
	_grass = _room.get_node("World/Grass")
	_own_wind = float(_grass.get("wind_scale"))
	_grass.set("big_gust_chance", 1.0)
	_grass.set("big_gust_every", 11.0)
	# The HUD off and kept off: the grass panel shows itself again every frame while the grass is
	# up, so its processing (and everything else's under UI) is stopped for the film.
	for c in _room.get_node("UI").get_children():
		if c is CanvasItem:
			(c as CanvasItem).visible = false
		c.process_mode = Node.PROCESS_MODE_DISABLED
	(_room.get_node("Player/StateLabel") as CanvasItem).visible = false
	var player := _room.get_node("Player") as Node4D
	player.visible = false
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var sky := _room.get_node_or_null("World/SkyFill") as Node4D
	if sky != null:
		sky.visible = false
	# Four chickens at home, on the yard's sand.
	var manager: Node = _room.get_node("Chickens")
	var pen: Vector4 = (_room.get_node("Pen/Fence") as Node4D).global_position
	var spots := [Vector2(-2.0, 1.2), Vector2(1.6, 0.4), Vector2(-0.6, -1.6), Vector2(2.4, 2.0)]
	var agents: Array = manager.get("agents")
	for i in mini(4, agents.size()):
		var bird := (agents[i] as Node).get_parent() as Node4D
		bird.global_position = Vector4(pen.x + spots[i].x, 0.0, pen.z + spots[i].y, 0.0)
		agents[i].call("on_landed", true)
	_cam = Camera4D.new()
	_cam.set("rendering_engine_name", "Cross-section")
	_room.add_child(_cam)
	_wide = float(_cam.get("field_of_view_4d"))
	_cam.make_current()


func _to_sun() -> Vector4:
	var sun := _room.get_node_or_null("World/Sun") as Node4D
	var z: Vector4 = sun.global_basis.z if sun != null else Vector4(1, 0, 0, 0)
	var flat := Vector4(z.x, 0.0, z.z, 0.0)
	return flat.normalized() if flat.length() > 0.05 else Vector4(1, 0, 0, 0)


func _process(d: float) -> bool:
	_t += d
	if not _started:
		if _t > 90.0:
			print("BEAUTY FAIL: no grass after 90 s")
			return true
		var grass: Node = _room.get_node("World/Grass")
		if not bool(grass.get("mask_ready")) or _t < 6.0:
			return false
		_set_up()
		_started = true
		print("REEL FROM %.3f s" % _t)
		return false
	_reel_t += d
	_shot_t += d
	var length: float = float(SHOTS[_shot][0])
	if _shot_t >= length:
		_shot += 1
		_shot_t = 0.0
		if _shot >= SHOTS.size():
			print("BEAUTY DONE at %.3f s (reel %.1f s)" % [_t, _reel_t])
			return true
		length = float(SHOTS[_shot][0])
	var total: float = 0.0
	for s in SHOTS:
		total += float(s[0])
	# From black, and back to black at the end.
	_black.modulate.a = 1.0 - minf(clampf(_reel_t / FADE, 0.0, 1.0), clampf((total - _reel_t) / FADE, 0.0, 1.0))
	_lay_out()
	# The wind, eased to the shot's.
	var want: float = _own_wind * float(SHOTS[_shot][2])
	_grass.set("wind_scale", lerpf(float(_grass.get("wind_scale")), want, minf(d * 0.8, 1.0)))
	_hide_ui()
	_frame(String(SHOTS[_shot][1]), clampf(_shot_t / length, 0.0, 1.0))
	if _stills and _shot_t > length * 0.5 and not _saved.has(_shot):
		_saved[_shot] = true
		root.get_texture().get_image().save_png("res://smoke_test_output/beauty_%d_%s.png" % [_shot, SHOTS[_shot][1]])
	return false


## No HUD and no words, every frame: the grass panel shows itself again while the grass is up,
## and the farm's people say things in boxes on layers of their own.
func _hide_ui() -> void:
	for c in _room.get_node("UI").get_children():
		if c is CanvasItem:
			(c as CanvasItem).visible = false
	for layer in _room.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false


## Each shot placed exactly from its own start, eased through; a cut between them.
func _frame(shot: String, k: float) -> void:
	var up := Vector4(0, 1, 0, 0)
	var sun: Vector4 = _to_sun()
	var side := Vector4(-sun.z, 0.0, sun.x, 0.0)
	var wind2: Vector2 = (_grass.get("wind_direction") as Vector2).normalized()
	var wind := Vector4(wind2.x, 0.0, wind2.y, 0.0)
	var across := Vector4(-wind.z, 0.0, wind.x, 0.0)
	var meadow := Vector4(16.0, 0.0, 2.0, 0.0)
	var pen: Vector4 = (_room.get_node("Pen/Fence") as Node4D).global_position
	pen.y = 0.0
	var tower: Vector4 = (_room.get_node("World/LookoutSite/Lookout") as Node4D).global_position
	var s: float = smoothstep(0.0, 1.0, k)
	var eye := Vector4.ZERO
	var look := Vector4.ZERO
	var lens: float = 1.0
	match shot:
		"tilt_down":
			# Six metres up, drifting forward, the view tilting slowly down off the hills onto the field.
			eye = meadow - sun * lerpf(16.0, 11.0, s) + side * 4.0 + up * 6.0
			look = eye + sun * 20.0 + up * lerpf(-1.0, -9.0, s)
		"waves_from_above":
			# Nine metres up, looking down across the wind, drifting slowly with it: the waves roll
			# through under the camera.
			eye = meadow - across * 9.0 + wind * lerpf(-6.0, 2.0, s) + up * 9.0
			look = meadow + across * 6.0 + wind * lerpf(-3.0, 5.0, s)
		"pen_orbit":
			# A slow quarter turn round the pen at eight metres, the meadow waving all round it.
			var a: float = atan2(sun.z, sun.x) + PI * 0.15 + 0.6 * s
			eye = pen + Vector4(cos(a) * 22.0, 8.0, sin(a) * 22.0, 0.0)
			look = pen + up * 0.5
		"gust_from_above":
			# Twelve metres up, looking down the wind, as a big gust sweeps over the field.
			eye = meadow - wind * 14.0 + across * 3.0 + up * 12.0
			look = meadow + wind * lerpf(6.0, 10.0, s)
		"tilt_up_tower":
			# Five metres up, looking down at the grass, tilting up to the tower and the flock.
			var to_tower: Vector4 = (tower - meadow)
			to_tower.y = 0.0
			to_tower = to_tower.normalized()
			eye = tower - to_tower * 30.0 + side * 6.0 + up * 5.0
			look = (eye + to_tower * 10.0 - up * 4.0).lerp(tower + up * 8.0, s)
		"farewell":
			# Rising over the meadow, the pen in the middle of it, the hills and the sky.
			eye = (pen + sun * 14.0 + side * 10.0 + up * 9.0).lerp(pen + sun * 26.0 + side * 18.0 + up * 18.0, s)
			look = pen - sun * 4.0 + up * lerpf(-1.0, 2.0, s)
	_cam.set("field_of_view_4d", _wide * lens)
	_cam.global_basis = Projection.IDENTITY
	_cam.global_position = eye
	_cam.look_at(look)
	_cam.make_current()
