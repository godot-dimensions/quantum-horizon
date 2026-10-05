extends Node

## Cinematic 2, the meadow: a title from black, eight shots of the grass, each with a caption
## that says how it is done, and a fade out. Ramon, 3 Oct: "an explainer cinematic about the
## meadow, not unlike the one for the starlings. explain the research testcase, how you
## researched [Ghost of Tsushima] tech, and even though its 3d it follows 4d slicing behavior
## making it semi-4d, and how real 4d would be near impossible with so many tets", and "also
## talk about the wind and other stuff". The facts in the captions are the case study's
## (follow_up/grass_study.md): change one there, change it here.
##
## BUILT AS THE STARLINGS' IS (cinematic_murmuration_4d.gd): the same letterbox, title card,
## caption card and fades, played by name through the pen's Cinematics node, Escape skipping
## to the fade out. It borrows the pen and gives it all back: the HUD, the player (frozen and
## hidden), the farm's buses, the teal sky fill, and the grass's own wind, which two shots
## raise for a while.
##
## THE WALK-THROUGH SHOT HAS NO ONE IN IT. The camera is the walker: lent to the grass
## (pen_grass_4d.gd's add_walker) it parts the grass and leaves a trail as the player does,
## and it looks back over its shoulder at the trail. The player stays where they were.
##
## THE GRASS GROWS ROUND THE CAMERA, not the player: on any camera but the player's own the
## grass centres its rings on the camera, so every shot has the full detail round it.

signal finished

const STYLE := preload("res://ramon/Menu/style/menu_final_style.tres")

## [title, line, seconds]. No dashes in the lines (player-facing): full stops, commas, colons.
const SHOTS := [
	["A research test case", "Can a 4D farm have a living meadow? Half a million blades, 0.47 ms a frame on the GPU", 7.0],
	["Studied from Ghost of Tsushima", "As in Sucker Punch's GDC 2021 talk: every blade a curve, rebuilt on the GPU each frame", 9.0],
	["Semi-4D", "Ordinary 3D blades, but each has its own w. Step along W and the slice cuts them like the fence", 11.0],
	["Why not true 4D?", "As real 4D each blade is up to 27 tetrahedra: millions for the field, against 330,000 for the whole farm", 9.0],
	["The wind", "Gusts roll downwind in bands, as over a crop. Each blade bends to the wind's pressure and sways at its own pace", 11.0],
	["Leaves on the wind", "Up to 6,000 leaves and seeds, more as the wind rises. Each has a w, so now and then one blows in from ana", 8.0],
	["Walking through", "It lies down the way you went, then stands up again a few metres behind you", 9.0],
	["Where it grows", "Finer round you, sparser and simpler far out. None under the pen, the tower or the marsh", 9.0],
]
const KICKER := "QUANTUM HORIZON R&D  ·  GRASS STUDY 01"
const TITLE := "Wind Through the 4D Meadow"
const SUBTITLE := "Half a million blades of grass, grown live on the GPU every frame"
const METHOD := "Ghost of Tsushima's technique, taught to follow the fourth dimension"

const TITLE_IN := 0.6
const TITLE_HOLD := 3.4
const TITLE_OUT := 0.8
const REVEAL := 1.6
const END_FADE := 2.2
const SKIP_FADE := 1.0
const WIND_SHOT := 4
const LEAVES_SHOT := 5
const WALK_SHOT := 6

## The farm's own music: the meadow is the farm's.
@export_file("*.ogg", "*.wav") var music_file: String = "res://ramon/chickenpen/audio/music/Yotam Agam - Unconscious Mind Delta.wav"
@export_range(-40.0, 6.0, 0.5, "suffix:dB") var music_db: float = -6.0
@export_range(1.5, 3.0, 0.01) var letterbox_aspect: float = 2.39
## The middle of the open meadow the shots are set in: east of the start, towards the low sun.
@export var meadow: Vector4 = Vector4(16.0, 0.0, 2.0, 0.0)
## The grass's wind for the wind shot and the leaves shot, times its own.
@export_range(1.0, 3.0, 0.05) var wind_shot_scale: float = 1.8
@export_range(1.0, 3.0, 0.05) var leaves_shot_scale: float = 2.4

var _room: Node
var _grass: Node
var _cam: Camera4D
var _wide: float = 1.3
var _walker: Node4D
var _music: AudioStreamPlayer
var _layer: CanvasLayer
var _bars: Array[ColorRect] = []
var _black: ColorRect
var _title_box: Control
var _caption: PanelContainer
var _cue: ColorRect
var _caption_title: Label
var _caption_line: Label
var _playing: bool = false
var _t: float = 0.0
## How long the title has held for the grass.
var _held: float = 0.0
var _shot: int = -1
var _shot_t: float = 0.0
var _ending: float = -1.0
var _end_length: float = END_FADE
var _saved: Dictionary = {}
var _heights := PackedFloat32Array()
const GROUND_CELL := 3.0
const GROUND_SPAN := 200.0


## Starts it, in [param room] - the pen's root.
func play(room: Node) -> void:
	if _playing:
		return
	_room = room
	_grass = _room.get_node_or_null("World/Grass")
	_borrow()
	_map_ground()
	_build_overlay()
	_cam = Camera4D.new()
	_cam.name = "CinematicCamera"
	_cam.set("rendering_engine_name", "Cross-section")
	# The 4D lens: a Camera4D projects in 4D by default, and field_of_view_3d does nothing then.
	# Its own default for the wide shots, as they were framed.
	_wide = float(_cam.get("field_of_view_4d"))
	_room.add_child(_cam)
	_cam.make_current()
	_music = AudioStreamPlayer.new()
	_music.stream = load(music_file)
	_music.bus = &"Master"
	_music.volume_db = -60.0
	add_child(_music)
	_music.play()
	_playing = true
	_t = 0.0
	_held = 0.0
	_shot = -1
	_ending = -1.0
	set_process(true)
	set_process_input(true)


func is_playing() -> bool:
	return _playing


## Straight to the fade out.
func skip() -> void:
	if _playing and _ending < 0.0:
		_end_length = SKIP_FADE
		_ending = 0.0


func _ready() -> void:
	set_process(false)
	set_process_input(false)


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
		skip()
		get_viewport().set_input_as_handled()


# --- Borrowing the pen, and giving it back ---------------------------------------------------

func _borrow() -> void:
	var hud: Dictionary = {}
	for child in _room.get_node("UI").get_children():
		if child is CanvasItem:
			hud[child] = (child as CanvasItem).visible
	var buses: Dictionary = {}
	for bus in [&"Music", &"Ambience", &"SFX", &"Flock"]:
		var i: int = AudioServer.get_bus_index(bus)
		if i >= 0:
			buses[i] = AudioServer.is_bus_mute(i)
			AudioServer.set_bus_mute(i, true)
	var player := _room.get_node("Player") as Node
	var sky := _room.get_node_or_null("World/SkyFill") as Node4D
	_saved = {
		"hud": hud, "buses": buses,
		"player_mode": player.process_mode, "player_shown": (player as Node4D).visible,
		"sky": sky.visible if sky else true,
		"label": (_room.get_node("Player/StateLabel") as CanvasItem).visible,
	}
	if _grass != null:
		_saved["wind_scale"] = _grass.get("wind_scale")
		_saved["big_gust_chance"] = _grass.get("big_gust_chance")
	player.process_mode = Node.PROCESS_MODE_DISABLED
	(player as Node4D).visible = false
	if sky:
		sky.visible = false


func _give_back() -> void:
	var hud: Dictionary = _saved.get("hud", {})
	for item in hud:
		if is_instance_valid(item):
			(item as CanvasItem).visible = hud[item]
	var buses: Dictionary = _saved.get("buses", {})
	for i in buses:
		AudioServer.set_bus_mute(i, buses[i])
	(_room.get_node("Player") as Node).process_mode = _saved["player_mode"]
	(_room.get_node("Player") as Node4D).visible = _saved["player_shown"]
	var sky := _room.get_node_or_null("World/SkyFill") as Node4D
	if sky:
		sky.visible = _saved["sky"]
	(_room.get_node("Player/StateLabel") as CanvasItem).visible = _saved["label"]
	if _grass != null and _saved.has("wind_scale"):
		_grass.set("wind_scale", _saved["wind_scale"])
		_grass.set("big_gust_chance", _saved["big_gust_chance"])
	_lend_walker(false)
	var farm := _room.get_node_or_null("Player/CameraRig/Pitch/Camera4D") as Camera4D
	if farm:
		farm.make_current()
	if is_instance_valid(_cam):
		_cam.queue_free()
	if is_instance_valid(_music):
		_music.queue_free()
	if is_instance_valid(_layer):
		_layer.queue_free()


## The camera's stand-in on the ground, lent to the grass for the walk-through shot.
func _lend_walker(on: bool) -> void:
	if on and _walker == null:
		_walker = Node4D.new()
		_walker.name = "CinematicWalker"
		_room.get_node("World").add_child(_walker)
		if _grass != null and _grass.has_method("add_walker"):
			_grass.call("add_walker", _walker)
	elif not on and _walker != null:
		if _grass != null and _grass.has_method("remove_walker"):
			_grass.call("remove_walker", _walker)
		_walker.queue_free()
		_walker = null


# --- The overlay: letterbox, black, title, captions (as the starlings') ---------------------

func _label(text: String, size: int, colour: Color, font: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	if font != null:
		l.add_theme_font_override("font", font)
	return l


func _build_overlay() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 60
	add_child(_layer)
	for k in 2:
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_layer.add_child(bar)
		_bars.append(bar)
	_caption = PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.04, 0.05, 0.08, 0.62)
	box.border_color = Color(1.0, 1.0, 1.0, 0.07)
	box.set_border_width_all(1)
	box.set_corner_radius_all(9)
	box.content_margin_left = 22
	box.content_margin_right = 26
	box.content_margin_top = 12
	box.content_margin_bottom = 14
	_caption.add_theme_stylebox_override("panel", box)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	_caption_title = _label("", 28, Color(1.0, 1.0, 1.0, 0.95), STYLE.font)
	_caption_line = _label("", 18, Color(1.0, 1.0, 1.0, 0.65))
	# These lines are longer than the starlings': wrapped to the picture's width (_lay_out).
	_caption_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_caption_title)
	column.add_child(_caption_line)
	_caption.add_child(column)
	_caption.modulate.a = 0.0
	_layer.add_child(_caption)
	_cue = ColorRect.new()
	_cue.color = STYLE.accent.lightened(0.3)
	_cue.size = Vector2(46, 4)
	_cue.modulate.a = 0.0
	_layer.add_child(_cue)
	_black = ColorRect.new()
	_black.color = Color.BLACK
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(_black)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 10)
	var cue := ColorRect.new()
	cue.color = STYLE.accent.lightened(0.3)
	cue.custom_minimum_size = Vector2(56, 4)
	cue.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var kicker := _label(KICKER, 15, Color(1.0, 1.0, 1.0, 0.5), STYLE.font)
	var title := _label(TITLE, 76, Color(1.0, 1.0, 1.0, 0.96), STYLE.font)
	var subtitle := _label(SUBTITLE, 21, Color(1.0, 1.0, 1.0, 0.75))
	var method := _label(METHOD, 21, Color(1.0, 1.0, 1.0, 0.5))
	for l in [kicker, title, subtitle, method]:
		(l as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(cue)
	stack.add_child(kicker)
	stack.add_child(title)
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", 0)
	lines.add_child(subtitle)
	lines.add_child(method)
	stack.add_child(lines)
	centre.add_child(stack)
	centre.modulate.a = 0.0
	_layer.add_child(centre)
	_title_box = centre
	_lay_out()


func _lay_out() -> void:
	var screen: Vector2 = get_viewport().get_visible_rect().size
	var picture_h: float = minf(screen.y, screen.x / letterbox_aspect)
	var bar: float = floorf((screen.y - picture_h) * 0.5)
	_bars[0].position = Vector2.ZERO
	_bars[0].size = Vector2(screen.x, bar)
	_bars[1].position = Vector2(0.0, screen.y - bar)
	_bars[1].size = Vector2(screen.x, bar)
	var room: float = minf(screen.x - 150.0, 980.0)
	if absf(_caption_line.custom_minimum_size.x - room) > 0.5:
		_caption_line.custom_minimum_size.x = room
		_caption.reset_size()
	_caption.position = Vector2(48.0, screen.y - bar - 32.0 - _caption.size.y)
	_cue.position = _caption.position + Vector2(22.0, -10.0)


# --- Keeping the camera out of the hills (as the starlings') ---------------------------------

func _map_ground() -> void:
	var cells: int = int(GROUND_SPAN * 2.0 / GROUND_CELL)
	_heights.resize(cells * cells)
	_heights.fill(0.0)
	for path in ["World/Hills", "World/CaveHill"]:
		# The cave hill is in the Cave unit since 6 Oct (World/Cave/CaveHill): found by name if not at its path.
		var hill := _room.get_node_or_null(path) as MeshInstance4D
		if hill == null and _room.get_node_or_null("World") != null:
			hill = _room.get_node("World").find_child(path.get_file(), true, false) as MeshInstance4D
		if hill == null or not (hill.mesh is ArrayTetraMesh4D):
			continue
		var basis: Projection = hill.global_basis
		var origin: Vector4 = hill.global_position
		for v in (hill.mesh as ArrayTetraMesh4D).get_vertex_positions():
			var p: Vector4 = basis * v + origin
			if absf(p.w - meadow.w) > 2.5:
				continue
			var cx: int = int((p.x + GROUND_SPAN) / GROUND_CELL)
			var cz: int = int((p.z + GROUND_SPAN) / GROUND_CELL)
			if cx < 0 or cz < 0 or cx >= cells or cz >= cells:
				continue
			var k: int = cz * cells + cx
			if p.y > _heights[k]:
				_heights[k] = p.y


func _ground(x: float, z: float) -> float:
	if _heights.is_empty():
		return 0.0
	var cells: int = int(GROUND_SPAN * 2.0 / GROUND_CELL)
	var cx: int = int((x + GROUND_SPAN) / GROUND_CELL)
	var cz: int = int((z + GROUND_SPAN) / GROUND_CELL)
	var top: float = 0.0
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var gx: int = cx + dx
			var gz: int = cz + dz
			if gx >= 0 and gz >= 0 and gx < cells and gz < cells:
				top = maxf(top, _heights[gz * cells + gx])
	return top


# --- Running it -------------------------------------------------------------------------------

func _process(d: float) -> void:
	if not _playing:
		return
	_t += d
	# The grass grows in a few seconds after the pen loads (its mask is built over frames), and
	# from the menu this starts with the pen: the title holds until it has (15 s at most).
	if _grass != null and not bool(_grass.get("mask_ready")) and _held < 15.0:
		_held += d
		_t = minf(_t, TITLE_IN + TITLE_HOLD)
	var title_end: float = TITLE_IN + TITLE_HOLD + TITLE_OUT
	var title_a: float = 0.0
	if _t < TITLE_IN + 0.4:
		title_a = clampf((_t - 0.4) / TITLE_IN, 0.0, 1.0)
	elif _t < title_end:
		title_a = clampf((title_end - _t) / TITLE_OUT, 0.0, 1.0)
	_title_box.modulate.a = title_a
	var sound_up: float = clampf(_t / 3.0, 0.0, 1.0)
	var picture_up: float = clampf((_t - title_end) / REVEAL, 0.0, 1.0)
	if _t >= title_end:
		_shot_t += d
		if _shot < 0 or (_shot < SHOTS.size() and _shot_t >= float(SHOTS[_shot][2])):
			if _shot < SHOTS.size() - 1:
				_shot += 1
				_shot_t = 0.0
				_start_shot()
		if _shot == SHOTS.size() - 1 and _ending < 0.0 and _shot_t >= float(SHOTS[_shot][2]) - END_FADE:
			_end_length = END_FADE
			_ending = 0.0
	var down: float = 1.0
	if _ending >= 0.0:
		_ending += d
		down = clampf(1.0 - _ending / _end_length, 0.0, 1.0)
	_black.modulate.a = 1.0 - picture_up * down
	_music.volume_db = music_db + linear_to_db(maxf(sound_up * down, 0.001))
	_hide_hud()
	if _shot >= 0:
		var length: float = float(SHOTS[_shot][2])
		var caption_a: float = clampf(minf((_shot_t - 0.4) / 0.6, (length - _shot_t - 0.3) / 0.6), 0.0, 1.0)
		_caption.modulate.a = caption_a * down
		_cue.modulate.a = _caption.modulate.a
		_wind(_shot)
		_frame_camera(_shot, clampf(_shot_t / length, 0.0, 1.0))
	_lay_out()
	if _ending >= _end_length + 0.4:
		_finish()


func _finish() -> void:
	_playing = false
	set_process(false)
	set_process_input(false)
	_give_back()
	finished.emit()


func _hide_hud() -> void:
	for child in _room.get_node("UI").get_children():
		if child is CanvasItem:
			(child as CanvasItem).visible = false
	(_room.get_node("Player/StateLabel") as CanvasItem).visible = false


func _start_shot() -> void:
	_caption_title.text = String(SHOTS[_shot][0])
	_caption_line.text = String(SHOTS[_shot][1])
	# Close on the blades, and on the leaves against the sky: a longer lens. Everything else as
	# the camera comes.
	_cam.set("field_of_view_4d", _wide * 0.6 if _shot == 1 or _shot == LEAVES_SHOT else _wide)
	_lend_walker(_shot == WALK_SHOT)


## The grass's wind: its own, raised over the wind shot and higher still for the leaves, eased
## up and down so no blade jumps; a big gust a certainty while it is up.
func _wind(shot: int) -> void:
	if _grass == null or not _saved.has("wind_scale"):
		return
	var own: float = float(_saved["wind_scale"])
	var target: float = own
	if shot == WIND_SHOT:
		target = own * wind_shot_scale
	elif shot == LEAVES_SHOT:
		target = own * leaves_shot_scale
	var now: float = float(_grass.get("wind_scale"))
	# About two seconds to get there: the gust bands travel with the wind, so a sudden change
	# would shift the whole field at once.
	_grass.set("wind_scale", lerpf(now, target, minf(get_process_delta_time() * 1.2, 1.0)))
	_grass.set("big_gust_chance", 1.0 if shot == WIND_SHOT or shot == LEAVES_SHOT else float(_saved["big_gust_chance"]))


## Towards the low sun, flat: the grass is lit from behind looking this way.
func _to_sun() -> Vector4:
	var sun := _room.get_node_or_null("World/Sun") as Node4D
	var z: Vector4 = sun.global_basis.z if sun != null else Vector4(1, 0, 0, 0)
	var flat := Vector4(z.x, 0.0, z.z, 0.0)
	return flat.normalized() if flat.length() > 0.05 else Vector4(1, 0, 0, 0)


func _wind_dir() -> Vector4:
	var w: Vector2 = _grass.get("wind_direction") if _grass != null else Vector2(0.82, 0.57)
	w = w.normalized()
	return Vector4(w.x, 0.0, w.y, 0.0)


## Where each shot puts the camera, [param k] from 0 to 1 through it. Every shot is placed
## exactly from its own start, no easing towards a target (the starlings' first shot taught
## that), and lifted out of a hill if one is in the way.
func _frame_camera(shot: int, k: float) -> void:
	var up := Vector4(0, 1, 0, 0)
	var sun: Vector4 = _to_sun()
	var side := Vector4(-sun.z, 0.0, sun.x, 0.0)
	var m: Vector4 = meadow
	var pen := _room.get_node_or_null("Pen") as Node4D
	var pen_at: Vector4 = pen.global_position if pen != null else Vector4(0.0, 0.0, -11.0, 0.0)
	var s: float = smoothstep(0.0, 1.0, k)
	var eye := Vector4.ZERO
	var look := Vector4.ZERO
	var w_step: float = 0.0
	match shot:
		0:
			# Over the meadow towards the low sun, forward and down to the grass. Low enough that
			# the field's far edge (44 m round the camera) stays behind the hills.
			eye = (m - sun * 22.0 + up * 5.5).lerp(m - sun * 6.0 + up * 1.8, s)
			look = (m + sun * 14.0).lerp(m + sun * 40.0 + up * 3.0, s)
		1:
			# Among the blades, a slow step sideways, looking into the sun past them.
			eye = m + side * (-1.5 + 3.0 * k) + up * 0.42
			look = eye + sun * 6.0 - up * 0.32
		2:
			# The pen's fence and the grass outside it, and one slow step along W and back:
			# blades shrink away and others grow in, as the fence's pieces do.
			eye = pen_at + sun * 12.0 + side * 9.0 + up * 2.2
			look = pen_at + sun * 3.0 + up * 0.4
			w_step = smoothstep(0.0, 1.0, sin(k * PI)) * 0.9
		3:
			# Low over the field, turning slowly round it, the whole meadow out to the hills. (High,
			# the field's edge showed as the rim of a disc.)
			var a: float = 2.2 + 0.55 * k
			eye = m + Vector4(cos(a) * 14.0, 3.0, sin(a) * 14.0, 0.0)
			look = m - Vector4(cos(a), 0.0, sin(a), 0.0) * 30.0 + up * 2.0
		4:
			# Low, across the wind: the gusts roll across the frame.
			var wind: Vector4 = _wind_dir()
			var across := Vector4(-wind.z, 0.0, wind.x, 0.0)
			eye = m - across * 11.0 - wind * (4.0 - 3.0 * k) + up * 1.7
			look = m + across * 8.0 + wind * 2.0
		5:
			# Low, towards the sunset glow: the leaves fly low, and cross the bright sky there.
			eye = m - sun * 3.0 + up * 0.7
			look = m + sun * 16.0 + up * (2.4 + 0.8 * k)
		6:
			# You walk, and look back over your shoulder at the trail.
			var along: Vector4 = side
			var feet: Vector4 = m - along * 5.0 + along * (10.0 * k)
			if _walker != null:
				_walker.global_position = feet
			eye = feet + up * 1.65 + along * 0.4
			look = feet - along * 4.0 + up * 0.1
		7:
			# Rising over the pen: its clearing, the meadow round it, the tower beyond.
			eye = (pen_at + sun * 12.0 + side * 12.0 + up * 4.0).lerp(pen_at + sun * 20.0 + side * 18.0 + up * 15.0, s)
			look = pen_at - sun * 6.0
	eye.y = maxf(eye.y, _ground(eye.x, eye.z) + (0.35 if shot == 1 or shot == 6 else 1.5))
	var at: Vector4 = eye + Vector4(0.0, 0.0, 0.0, w_step)
	_cam.global_basis = Projection.IDENTITY
	_cam.global_position = at
	_cam.look_at(look + Vector4(0.0, 0.0, 0.0, w_step))
	_cam.make_current()
