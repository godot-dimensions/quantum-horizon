extends Node

## Cinematic 1, the murmuration: a title from black, six shots of the flock, a fade out.
## Ramon, 1 Oct: the team film, then "create letterbox. cut the first shot after 4 seconds
## ... a mix pass ... fade in from black starting with [a title] ... a fade out, also for the
## audio. same should happen in the game cinematic option".
##
## ONE CINEMATIC, PLAYED IN THE GAME AND RECORDED FROM IT. The film is the movie writer
## pointed at this node (_film_flock_runner.gd), so what the team sees and what the menu's
## "1" plays cannot drift apart.
##
## IT BORROWS THE PEN AND GIVES IT BACK. While it plays: the HUD is hidden (the stats panel
## shows in the first shot, inside the letterbox), the player is frozen, its own camera
## flies, the sky-fill light is off (its sun disc is the blue orb behind the flock in upward
## shots), and the only sound is the music and the flock - the farm's music, bed and effects
## buses muted. Afterwards every one of those is put back as it was.
##
## THE MIX: the music at half volume (-6 dB) straight to Master; the flock's bus raised and
## sent straight to Master too, so the birds sit on top of the music when the camera is among
## them and under it when they are far off - the flock's own mix (flock_sound_4d.gd) does
## the near and far. Both fade up from silence with the title and down with the last shot.
## Escape skips to the fade out.

signal finished

const STYLE := preload("res://ramon/Menu/style/menu_final_style.tres")

## [title, line, seconds]. The first was 9 s; Ramon: "cut the first shot after 4 seconds".
const SHOTS := [
	["Over the pen at dusk", "5,000 starlings, one compute shader, 0.4 ms a frame", 4.0],
	["Underneath", "Seven neighbours each, not a radius: the flock holds its spacing at any density", 8.0],
	["Alongside", "Turning inertia: a turn crosses the flock as a wave instead of fading", 8.0],
	["Inside the flock", "Every bird is a 4D body, cut by the camera's slice like the rest of the farm", 7.0],
	["The hawk  (half speed)", "Birds near it flee and roll; neighbours copy the roll 70 ms later", 11.0],
	["Through W", "Half a metre along W, half the flock is gone: every bird is a 4D body", 11.0],
]
## Ramon's title, 1 Oct: "Flight of the 4D Starlings ... a bit more dreamy, and we can add
## all the murmuration and dry stuff underneath". So the title is the picture, and what it
## is and how it is done go in the lines below it.
const KICKER := "QUANTUM HORIZON R&D  ·  BOID STUDY 01"
const TITLE := "Flight of the 4D Starlings"
const SUBTITLE := "A murmuration of 5,000 starlings, simulated live on the GPU"
const METHOD := "Reynolds boids: seven nearest neighbours each, with turning inertia"

## Seconds: the title fading in, held, fading out, and the black lifting off the first shot.
## The flock forms during the title, which is also why it is as long as it is.
const TITLE_IN := 0.6
const TITLE_HOLD := 3.4
const TITLE_OUT := 0.8
const REVEAL := 1.6
const END_FADE := 2.2
const SKIP_FADE := 1.0

## An .ogg copy of Ramon's .wav: that file has the WAVE_FORMAT_EXTENSIBLE header (tag
## 0xFFFE), which Godot's importer refuses as "not PCM", though the audio in it is plain
## 24-bit PCM. The copy is also 2.6 MB against 32.
@export_file("*.ogg", "*.wav") var music_file: String = "res://ramon/chickenpen/audio/music/Romeo - Heaven.ogg"
@export_range(-40.0, 6.0, 0.5, "suffix:dB") var music_db: float = -6.0
## The flock's bus during the cinematic: on top of the music when the birds are close.
@export_range(-12.0, 18.0, 0.5, "suffix:dB") var flock_db: float = 6.0
## 2.39:1, the widescreen cinema frame.
@export_range(1.5, 3.0, 0.01) var letterbox_aspect: float = 2.39

var _room: Node
var _flock: Node4D
var _cam: Camera4D
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
var _shot: int = -1
var _shot_t: float = 0.0
var _ending: float = -1.0
var _end_length: float = END_FADE
var _eye := Vector4.ZERO
var _look := Vector4.ZERO
var _saved: Dictionary = {}
## The hills' heights on a coarse grid, from their own vertices - the cave hill has no
## collider, so a raycast cannot keep the camera out of it (see _ground).
var _heights := PackedFloat32Array()
const GROUND_CELL := 3.0
const GROUND_SPAN := 200.0


## Starts it, in [param room] - the pen's root.
func play(room: Node) -> void:
	if _playing:
		return
	_room = room
	_flock = _room.get_node("World/Flock") as Node4D
	_borrow()
	_map_ground()
	_build_overlay()
	_cam = Camera4D.new()
	_cam.name = "CinematicCamera"
	_cam.set("rendering_engine_name", "Cross-section")
	_cam.set("field_of_view_3d", 0.96)
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
	for bus in [&"Music", &"Ambience", &"SFX"]:
		var i: int = AudioServer.get_bus_index(bus)
		if i >= 0:
			buses[i] = AudioServer.is_bus_mute(i)
			AudioServer.set_bus_mute(i, true)
	var flock_bus: int = AudioServer.get_bus_index(&"Flock")
	var player := _room.get_node("Player") as Node
	var sky := _room.get_node_or_null("World/SkyFill") as Node4D
	var stats := _room.get_node_or_null("UI/FlockStats")
	_saved = {
		"hud": hud, "buses": buses, "flock_bus": flock_bus,
		"flock_send": AudioServer.get_bus_send(flock_bus) if flock_bus >= 0 else &"Ambience",
		"flock_volume": AudioServer.get_bus_volume_db(flock_bus) if flock_bus >= 0 else 0.0,
		"player_mode": player.process_mode, "sky": sky.visible if sky else true,
		"seen_share": _flock.get("hawk_seen_share"), "near_scale": _flock.get("hawk_near_scale"),
		"profile": _flock.get("profile_gpu"), "pin": stats.get("pin_top_left") if stats else false,
		"pin_at": stats.get("pin_at") if stats else Vector2(32.0, 32.0),
		"label": (_room.get_node("Player/StateLabel") as CanvasItem).visible,
	}
	if flock_bus >= 0:
		AudioServer.set_bus_send(flock_bus, &"Master")
		AudioServer.set_bus_volume_db(flock_bus, -60.0)
	player.process_mode = Node.PROCESS_MODE_DISABLED
	if sky:
		sky.visible = false
	# The hawk always comes in where the camera can see it, timed for the hawk shot, and a
	# little bigger up close than in the game, so it reads in a film frame.
	_flock.set("hawk_seen_share", 1.0)
	_flock.set("hawk_near_scale", 1.8)
	_flock.set("profile_gpu", true)
	# A second before the hawk shot: it starts 60-80 m out, and at half speed it would reach
	# the flock with the shot nearly over.
	var until_hawk: float = TITLE_IN + TITLE_HOLD + TITLE_OUT - 1.0
	for k in 4:
		until_hawk += float(SHOTS[k][2])
	if _flock.call("hawk_position") == null:
		_flock.set("_hawk_timer", until_hawk)
	if stats:
		stats.set("pin_top_left", true)


func _give_back() -> void:
	Engine.time_scale = 1.0
	var hud: Dictionary = _saved.get("hud", {})
	for item in hud:
		if is_instance_valid(item):
			(item as CanvasItem).visible = hud[item]
	var buses: Dictionary = _saved.get("buses", {})
	for i in buses:
		AudioServer.set_bus_mute(i, buses[i])
	var flock_bus: int = _saved.get("flock_bus", -1)
	if flock_bus >= 0:
		AudioServer.set_bus_send(flock_bus, _saved["flock_send"])
		AudioServer.set_bus_volume_db(flock_bus, _saved["flock_volume"])
	(_room.get_node("Player") as Node).process_mode = _saved["player_mode"]
	var sky := _room.get_node_or_null("World/SkyFill") as Node4D
	if sky:
		sky.visible = _saved["sky"]
	_flock.set("hawk_seen_share", _saved["seen_share"])
	_flock.set("hawk_near_scale", _saved["near_scale"])
	_flock.set("profile_gpu", _saved["profile"])
	var stats := _room.get_node_or_null("UI/FlockStats")
	if stats:
		stats.set("pin_top_left", _saved["pin"])
		stats.set("pin_at", _saved["pin_at"])
	(_room.get_node("Player/StateLabel") as CanvasItem).visible = _saved["label"]
	var farm := _room.get_node_or_null("Player/CameraRig/Pitch/Camera4D") as Camera4D
	if farm:
		farm.make_current()
	if is_instance_valid(_cam):
		_cam.queue_free()
	if is_instance_valid(_music):
		_music.queue_free()
	if is_instance_valid(_layer):
		_layer.queue_free()


# --- The overlay: letterbox, black, title, captions ------------------------------------------

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
	# The caption, in the HUD's card style, with the one accent bar above it.
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
	# Black over everything, lifted after the title.
	_black = ColorRect.new()
	_black.color = Color.BLACK
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(_black)
	# The title card, centred on the black.
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
	kicker.add_theme_constant_override("outline_size", 0)
	var title := _label(TITLE, 76, Color(1.0, 1.0, 1.0, 0.96), STYLE.font)
	var subtitle := _label(SUBTITLE, 24, Color(1.0, 1.0, 1.0, 0.75))
	var method := _label(METHOD, 16, Color(1.0, 1.0, 1.0, 0.45))
	for l in [kicker, title, subtitle, method]:
		(l as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(cue)
	stack.add_child(kicker)
	stack.add_child(title)
	stack.add_child(subtitle)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 14)
	stack.add_child(gap)
	stack.add_child(method)
	centre.add_child(stack)
	centre.modulate.a = 0.0
	_layer.add_child(centre)
	_title_box = centre
	_lay_out()


## The letterbox for whatever the window is, and the caption inside the picture.
func _lay_out() -> void:
	var screen: Vector2 = get_viewport().get_visible_rect().size
	var picture_h: float = minf(screen.y, screen.x / letterbox_aspect)
	var bar: float = floorf((screen.y - picture_h) * 0.5)
	_bars[0].position = Vector2.ZERO
	_bars[0].size = Vector2(screen.x, bar)
	_bars[1].position = Vector2(0.0, screen.y - bar)
	_bars[1].size = Vector2(screen.x, bar)
	_caption.position = Vector2(48.0, screen.y - bar - 32.0 - _caption.size.y)
	_cue.position = _caption.position + Vector2(22.0, -10.0)
	var stats := _room.get_node_or_null("UI/FlockStats")
	if stats:
		stats.set("pin_at", Vector2(32.0, bar + 28.0))


# --- Keeping the camera out of the hills ---------------------------------------------------

## The top of the field's hills on a grid, near the flock's W. Built once, under the title
## card, so the hitch it costs (one pass over the hills' vertices) is never seen.
func _map_ground() -> void:
	var cells: int = int(GROUND_SPAN * 2.0 / GROUND_CELL)
	_heights.resize(cells * cells)
	_heights.fill(0.0)
	var w: float = _middle().w
	for path in ["World/Hills", "World/CaveHill"]:
		var hill := _room.get_node_or_null(path) as MeshInstance4D
		if hill == null or not (hill.mesh is ArrayTetraMesh4D):
			continue
		var basis: Projection = hill.global_basis
		var origin: Vector4 = hill.global_position
		for v in (hill.mesh as ArrayTetraMesh4D).get_vertex_positions():
			var p: Vector4 = basis * v + origin
			if absf(p.w - w) > 2.5:
				continue
			var cx: int = int((p.x + GROUND_SPAN) / GROUND_CELL)
			var cz: int = int((p.z + GROUND_SPAN) / GROUND_CELL)
			if cx < 0 or cz < 0 or cx >= cells or cz >= cells:
				continue
			var k: int = cz * cells + cx
			if p.y > _heights[k]:
				_heights[k] = p.y


## The hills' height under (x, z), the highest of this cell and its neighbours.
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


## [param eye] raised until it is above the ground and nothing stands between it and
## [param look].
func _clear(eye: Vector4, look: Vector4) -> Vector4:
	var out: Vector4 = eye
	out.y = maxf(out.y, _ground(out.x, out.z) + 2.0)
	for _pass in 3:
		var worst: float = 0.0
		for k in range(1, 8):
			var t: float = float(k) / 8.0
			var at: Vector4 = out.lerp(look, t)
			var short: float = _ground(at.x, at.z) + 1.0 - at.y
			# Raising the eye by d lifts this point by d * (1 - t).
			worst = maxf(worst, short / maxf(1.0 - t, 0.1))
		if worst <= 0.0:
			break
		out.y += worst
	return out


# --- Running it -------------------------------------------------------------------------------

func _process(scaled: float) -> void:
	if not _playing:
		return
	var d: float = scaled / maxf(Engine.time_scale, 0.01)
	_t += d
	var title_end: float = TITLE_IN + TITLE_HOLD + TITLE_OUT
	# The title, on black.
	var title_a: float = 0.0
	if _t < TITLE_IN + 0.4:
		title_a = clampf((_t - 0.4) / TITLE_IN, 0.0, 1.0)
	elif _t < title_end:
		title_a = clampf((title_end - _t) / TITLE_OUT, 0.0, 1.0)
	_title_box.modulate.a = title_a
	# The sound comes up with the title; the picture after it.
	var sound_up: float = clampf(_t / 3.0, 0.0, 1.0)
	var picture_up: float = clampf((_t - title_end) / REVEAL, 0.0, 1.0)
	# The shots run from the moment the black starts to lift.
	if _t >= title_end:
		_shot_t += d
		if _shot < 0 or (_shot < SHOTS.size() and _shot_t >= float(SHOTS[_shot][2])):
			if _shot < SHOTS.size() - 1:
				_shot += 1
				_shot_t = 0.0
				_start_shot()
		# The fade out starts so it is black as the last shot ends.
		if _shot == SHOTS.size() - 1 and _ending < 0.0 and _shot_t >= float(SHOTS[_shot][2]) - END_FADE:
			_end_length = END_FADE
			_ending = 0.0
	var down: float = 1.0
	if _ending >= 0.0:
		_ending += d
		down = clampf(1.0 - _ending / _end_length, 0.0, 1.0)
	_black.modulate.a = 1.0 - picture_up * down
	var level: float = sound_up * down
	_music.volume_db = music_db + linear_to_db(maxf(level, 0.001))
	var flock_bus: int = _saved.get("flock_bus", -1)
	if flock_bus >= 0:
		AudioServer.set_bus_volume_db(flock_bus, flock_db + linear_to_db(maxf(level * picture_up, 0.001)))
	_hide_hud()
	if _shot >= 0:
		var length: float = float(SHOTS[_shot][2])
		var caption_a: float = clampf(minf((_shot_t - 0.4) / 0.6, (length - _shot_t - 0.3) / 0.6), 0.0, 1.0)
		_caption.modulate.a = caption_a * down
		_cue.modulate.a = _caption.modulate.a
		_frame_camera(_shot, clampf(_shot_t / length, 0.0, 1.0), d)
	else:
		_frame_camera(0, 0.0, d)
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
			(child as CanvasItem).visible = child.name == "FlockStats" and _shot == 0
	(_room.get_node("Player/StateLabel") as CanvasItem).visible = false


func _start_shot() -> void:
	_caption_title.text = String(SHOTS[_shot][0])
	_caption_line.text = String(SHOTS[_shot][1])
	Engine.time_scale = 0.5 if _shot == 4 else 1.0
	_cam.set("field_of_view_3d", 1.15 if _shot == 1 else (1.05 if _shot == 3 else 0.96))
	# A cut, not a swoop: start each shot where it wants to be.
	_eye = Vector4.ZERO


func _middle() -> Vector4:
	return _flock.get("_middle")


func _heading() -> Vector4:
	var h: Vector4 = _flock.get("_mean_heading")
	var flat := Vector4(h.x, 0.0, h.z, 0.0)
	return flat.normalized() if flat.length() > 0.05 else Vector4(1, 0, 0, 0)


## Where each shot puts the camera, [param k] from 0 to 1 through it.
func _frame_camera(shot: int, k: float, d: float) -> void:
	var m: Vector4 = _middle()
	var ahead: Vector4 = _heading()
	var side := Vector4(ahead.z, 0.0, -ahead.x, 0.0)
	var up := Vector4(0, 1, 0, 0)
	var eye := Vector4.ZERO
	var look: Vector4 = m
	var follow: float = 2.0
	var w_step: float = 0.0
	var turn: float = 0.0
	match shot:
		0:
			# From beside the farm towards the roost, low, the farm in the foreground. Four
			# seconds now, so it covers the first part of the old nine-second move.
			eye = Vector4(lerpf(9.0, 5.0, k), lerpf(2.0, 2.6, k), lerpf(10.0, 1.0, k), m.w)
			look = m + Vector4(0.0, -2.0, 0.0, 0.0)
			follow = 6.0
		1:
			# On the ground below the flock, circling slowly, looking up.
			var a: float = k * 1.2
			eye = Vector4(m.x + cos(a) * 7.0, 1.7, m.z + sin(a) * 7.0, m.w)
			follow = 1.2
		2:
			# Alongside and a little below, so the birds are against the sky, not the hills.
			eye = m + side * 16.0 - ahead * 5.0 - up * 5.0
			look = m + ahead * 6.0
			follow = 1.6
		3:
			# In among them, just behind the middle, looking the way they fly.
			eye = m - ahead * 3.0 + up * 0.6
			look = m + ahead * 30.0
			follow = 2.5
		4:
			# On the pen's side of the flock, low and close, looking up: the flock and the hawk
			# against the sunset glow, which is the way the hawk comes in from (it enters on the
			# far side from the camera). Level with the flock it was dark birds on dark hills.
			var to_pen := Vector4(-m.x, 0.0, -m.z, 0.0)
			to_pen = to_pen.normalized() if to_pen.length() > 1.0 else -ahead
			eye = m + to_pen * 18.0
			eye.y = maxf(m.y - 10.0, 2.5)
			look = m + up * 2.0
			follow = 1.4
		5:
			# Across the flock, one slow step half a metre along W and back. The flock is
			# thin in W, so about half its birds shrink away to nothing and come back; the
			# rest shrink and stay. Ramon, 1 Oct, of the first version, which also turned the
			# slice 65 degrees into W: "it rotated fast, and the flock was gone quickly,
			# showing nothing" - a turn that size leaves a sliver of a flock this thin.
			eye = m + side * 26.0 - up * 4.0
			follow = 1.4
			w_step = smoothstep(0.0, 1.0, sin(k * PI)) * 0.5
	eye = _clear(eye, look)
	if _eye == Vector4.ZERO:
		_eye = eye
		_look = look
	else:
		_eye = _eye.lerp(eye, minf(d * follow, 1.0))
		_look = _look.lerp(look, minf(d * follow * 1.5, 1.0))
		# Easing in from where it was must not dip it into a hill either.
		_eye.y = maxf(_eye.y, _ground(_eye.x, _eye.z) + 1.5)
	var at: Vector4 = _eye + Vector4(0.0, 0.0, 0.0, w_step)
	_cam.global_basis = Projection.IDENTITY
	_cam.global_position = at
	_cam.look_at(_look + Vector4(0.0, 0.0, 0.0, w_step))
	if turn != 0.0:
		_cam.global_basis = _cam.global_basis * Basis4D.from_xw(turn)
	_cam.make_current()
