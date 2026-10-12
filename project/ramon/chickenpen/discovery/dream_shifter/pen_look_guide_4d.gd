extends Node

## THE LOOK GUIDE (Systems/LookGuide; 9 Oct 2026, Ramon's onboarding brief for the dev and art looks,
## follow_up/pen_dream_shifter.md). Everything that teaches the I key, the one switch the pen has between its prototype
## greybox (DEV MODE) and its art (ART MODE), look/pen_look_4d.gd:
##
## 1. THE SHIFT, LIVE. When the Dream Shifter's talk ends on "Check it out." (pen_dream_shifter_talk_4d.gd calls
##    shift_from), the crystal flares and the world switches in front of you through the real Look (set_dev), with the
##    HUD out of the way: the frame just before is frozen over the screen and a line of light sweeps across it, the
##    new look live behind the line. "First, they should see it happen." The two frames, before and after, are kept for
##    the explainer.
## 2. THE EXPLAINER (pen_look_explainer.gd): a moment after, the Dev Logs' slider played over your own two frames and
##    three places of the valley, with the words for each mode. Not skippable for five seconds.
## 3. YOUR TURN: the big prompt (pen_look_prompt.gd) arrives in the middle of the screen and docks by the Look row on
##    the left-hand panel, pointing at the Dev and Art buttons, until you switch.
## 4. THE PRAISE: the first time you switch yourself after the explainer, "Well done. Now you are starting to understand
##    how we work." Once a session.
##
## AND IF YOU WALK PAST THE ORB: the prompt still comes (Ramon wanted it in the main scene, impossible to miss), once
## you have walked on past the pillar without touching it, or after prompt_after seconds of play without switching.
## It goes at the first switch, whatever made it.
##
## Switches this node makes itself (the shift) are not yours: they never count as your first press.
## Session state is static (a new launch, or Ctrl+R, starts over). NO class_name (engine_gotchas.md).

const Look := preload("res://ramon/chickenpen/look/pen_look_4d.gd")
const Explainer := preload("res://ramon/chickenpen/discovery/dream_shifter/pen_look_explainer.gd")
const Prompt := preload("res://ramon/chickenpen/discovery/dream_shifter/pen_look_prompt.gd")

@export var player_path: NodePath = ^"../../Player"
@export var shifter_path: NodePath = ^"../../World/DreamShifter"
@export var tutor_path: NodePath = ^"../Tutor"
@export var crossing_paths: Array[NodePath] = [^"../../Crossing", ^"../../CaveCrossing"]
## Seconds of play without a switch before the prompt comes anyway (0: from the start).
@export_range(0.0, 600.0, 5.0) var prompt_after: float = 75.0
## Past the pillar: near it (this close), then this far on without touching it, and the prompt comes.
@export_range(2.0, 20.0, 0.5) var near_m: float = 8.0
@export_range(5.0, 60.0, 0.5) var past_m: float = 16.0
## The valley's own places for the explainer, after your two frames: [file stem, caption]. The files are
## views/<stem>_dev.jpg and views/<stem>_art.jpg (captured from the game: _capture_views_runner.gd).
@export var views: Array = [["watchstone", "The Watchstone"], ["cave", "The way into the hill"], ["camp", "The research camp"]]
## THE SHOT the shift is seen in: the talk camera (World/TalkCam), placed from the Dream Shifter, looking past it down
## the first road to Trym's house, the crystal near, the valley behind. Offsets in metres from the pillar's foot.
@export var shot_camera_path: NodePath = ^"../../World/TalkCam"
@export var main_camera_path: NodePath = ^"../../Player/CameraRig/Pitch/Camera4D"
@export var shot_from: Vector4 = Vector4(2.3, 2.2, -4.6, 0.0)
@export var shot_at: Vector4 = Vector4(1.6, 1.3, 7.0, 0.0)
@export var verbose: bool = false

const VIEW_DIR := "res://ramon/chickenpen/discovery/dream_shifter/views/"

## This session: the explainer has been seen; the praise has been given; the player has switched by themselves.
static var seen: bool = false
static var praised: bool = false
static var switched: bool = false

var _player: Node4D
var _shifter: Node
var _tutor: Node
var _look: Node
var _layer: CanvasLayer
var _top: CanvasLayer
var _prompt: Control
var _explainer: Control
var _sweep: Control
var _sound: AudioStreamPlayer
var _chime: AudioStreamWAV
var _whoosh: AudioStreamWAV
var _busy: bool = false
var _self_switch: bool = false
var _played: float = 0.0
var _was_near: bool = false
var _panel_check: float = 0.0
var _live: Dictionary = {}
var _sweep_tex: Texture2D
var _sweep_x: float = 0.0


func _ready() -> void:
	add_to_group(&"discovery_reset")
	_player = get_node_or_null(player_path) as Node4D
	_shifter = get_node_or_null(shifter_path)
	_tutor = get_node_or_null(tutor_path)
	_layer = CanvasLayer.new()
	_layer.name = "LookPromptLayer"
	_layer.layer = 66
	add_child(_layer)
	_prompt = Prompt.new()
	_prompt.name = "LookPrompt"
	_layer.add_child(_prompt)
	_top = CanvasLayer.new()
	_top.name = "LookShowLayer"
	_top.layer = 96
	add_child(_top)
	_sweep = Control.new()
	_sweep.name = "Sweep"
	_sweep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sweep.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sweep.visible = false
	_sweep.draw.connect(_draw_sweep)
	_top.add_child(_sweep)
	_explainer = Explainer.new()
	_explainer.name = "Explainer"
	_top.add_child(_explainer)
	_explainer.connect("closed", _on_explained)
	_sound = AudioStreamPlayer.new()
	_sound.volume_db = -6.0
	add_child(_sound)
	_chime = _make_tone([880.0, 1318.5, 1760.0], 1.1, 4.0)
	_whoosh = _make_shift()


## True once the explainer has been seen this session (the orb talks differently after).
func onboarded() -> bool:
	return seen


## True while the shift or the explainer is running.
func busy() -> bool:
	return _busy


func _find_look() -> void:
	if _look != null and is_instance_valid(_look):
		return
	var look: Node = Look.current
	if look == null or not is_instance_valid(look):
		return
	_look = look
	_look.connect("look_changed", _on_look_changed)
	_prompt.set("key", OS.get_keycode_string(_look.get("key")))


## The Dev and Art buttons on the left-hand panel, for the prompt to point at (the panel comes up after the scene).
func _find_buttons() -> void:
	var panel: Node = get_tree().root.find_child("GrassPanel", true, false)
	if panel == null:
		return
	var buttons: Variant = panel.get("_look_buttons")
	if buttons is Array and not (buttons as Array).is_empty():
		_prompt.set("buttons", buttons)


func _on_look_changed(_dev: bool) -> void:
	if _self_switch:
		return
	switched = true
	if verbose:
		print("LOOKGUIDE: the player switched (seen %s, praised %s)" % [str(seen), str(praised)])
	if bool(_prompt.call("showing")):
		_prompt.call("hide_prompt", true)
	if seen and not praised:
		praised = true
		_prompt.call("praise")
		_play(_chime)
		if _shifter != null and _shifter.has_method("flare"):
			_shifter.call("flare", 0.8)


func _process(delta: float) -> void:
	_find_look()
	_panel_check -= delta
	if _panel_check <= 0.0:
		_panel_check = 1.0
		_find_buttons()
	if _player == null:
		return
	var quiet: bool = _quiet()
	_prompt.call("set_hush", quiet and not _busy)
	if _busy or switched or seen or bool(_prompt.call("showing")):
		return
	if not quiet:
		_played += delta
	var past: bool = false
	if _shifter != null and _shifter is Node4D:
		var gap: Vector4 = (_shifter as Node4D).global_position - _player.global_position
		var d: float = Vector2(gap.x, gap.z).length()
		if d <= near_m:
			_was_near = true
		elif _was_near and d >= past_m:
			past = true
	if not quiet and (past or (prompt_after > 0.0 and _played >= prompt_after) or prompt_after == 0.0):
		if verbose:
			print("LOOKGUIDE: the prompt, unasked (%s)" % ("walked past the orb" if past else "%.0f s of play" % _played))
		_prompt.call("show_prompt", true)


## Someone else has the screen: a conversation, a film, a crossing, the player held still, a tutor hint up.
func _quiet() -> bool:
	if not _player.is_visible_in_tree() or _player.get("input_enabled") == false:
		return true
	for talk in get_tree().get_nodes_in_group(&"npc_talk"):
		var player: Variant = talk.get("_talk")
		if player is Node and is_instance_valid(player) and (player as Node).has_method("is_running") and bool((player as Node).call("is_running")):
			return true
	for path in crossing_paths:
		var c: Node = get_node_or_null(path)
		if c != null and c.has_method("is_away") and bool(c.call("is_away")):
			return true
	var films: Node = get_node_or_null(^"../../Cinematics")
	if films != null and films.has_method("is_playing") and bool(films.call("is_playing")):
		return true
	return false


# --- 1. The shift, live -------------------------------------------------------------------------

## The world shifted in front of the player, from the Dream Shifter [param shifter]: then the explainer.
func shift_from(shifter: Node) -> void:
	if _busy:
		return
	_find_look()
	if _look == null:
		return
	_busy = true
	if bool(_prompt.call("showing")):
		_prompt.call("hide_prompt", false)
	_hold_player(true)
	if shifter != null:
		shifter.set("hold_awake", true)
		if shifter.has_method("flare"):
			shifter.call("flare", 1.6)
	var staged: bool = _stage(shifter, true)
	_play(_whoosh)
	await get_tree().create_timer(0.75 if staged else 0.55).timeout
	var was_dev: bool = bool(_look.get("dev"))
	var hidden: Array = _hud(false)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var before: Texture2D = _grab()
	# The frame just before, frozen over the screen; the look switched under it; the line sweeps it away.
	_sweep_tex = before
	_sweep_x = 0.0
	_sweep.visible = before != null
	_sweep.queue_redraw()
	_self_switch = true
	_look.call("set_dev", not was_dev)
	_self_switch = false
	await get_tree().process_frame
	var t: float = 0.0
	# Capped (feedback_bounded_loops): about a second of frames, never more than 600 of them.
	for i in 600:
		if t >= 1.0:
			break
		await get_tree().process_frame
		t += maxf(get_process_delta_time(), 0.001) / 1.05
		_sweep_x = clampf(t, 0.0, 1.0)
		_sweep_x = _sweep_x * _sweep_x * (3.0 - 2.0 * _sweep_x)
		_sweep.queue_redraw()
	_sweep.visible = false
	await RenderingServer.frame_post_draw
	var after: Texture2D = _grab()
	_live = {}
	if before != null and after != null:
		_live = {"dev": before if was_dev else after, "art": after if was_dev else before, "label": "Here, just now"}
	if verbose:
		print("LOOKGUIDE: shifted to %s (frames %s)" % ["dev" if not was_dev else "art", "kept" if not _live.is_empty() else "missing"])
	# A breath of the new look, live, before the words.
	await get_tree().create_timer(1.7).timeout
	if shifter != null:
		shifter.set("hold_awake", false)
	_stage(shifter, false)
	_hud(true, hidden)
	_open_explainer(true)


## The shot on ([param on]: the talk camera placed from the Dream Shifter and made current) or off (the player's own
## camera again). False when there is no shot to stage.
func _stage(shifter: Node, on: bool) -> bool:
	var cam := get_node_or_null(shot_camera_path) as Node4D
	var main := get_node_or_null(main_camera_path) as Node4D
	if cam == null or main == null or not (shifter is Node4D):
		return false
	if not on:
		main.set("current", true)
		return true
	var foot: Vector4 = (shifter as Node4D).global_position
	var from: Vector4 = foot + shot_from
	var gap: Vector4 = (foot + shot_at) - from
	cam.global_position = from
	cam.global_basis = _look_basis(gap)
	cam.set("current", true)
	return true


## A look-at that keeps the slice the world's (W column pinned), as PenNpcTalk4D's.
static func _look_basis(gap: Vector4) -> Projection:
	var forward: Vector3 = Vector3(gap.x, gap.y, gap.z).normalized()
	var zc: Vector3 = -forward
	var xc: Vector3 = Vector3(0.0, 1.0, 0.0).cross(zc)
	if xc.length_squared() < 0.000001:
		xc = Vector3(1.0, 0.0, 0.0)
	xc = xc.normalized()
	var yc: Vector3 = zc.cross(xc)
	return Projection(Vector4(xc.x, xc.y, xc.z, 0.0), Vector4(yc.x, yc.y, yc.z, 0.0), Vector4(zc.x, zc.y, zc.z, 0.0), Vector4(0.0, 0.0, 0.0, 1.0))


## The explainer again, without the shift (the orb's "Tell me again").
func explain(with_live: bool = false) -> void:
	if _busy:
		return
	_busy = true
	_hold_player(true)
	_open_explainer(with_live)


func _open_explainer(with_live: bool) -> void:
	var shown: Array = []
	# Your own two frames first, whenever there are some (the shift's, or the last shift's when the orb is asked again).
	if not _live.is_empty() and (with_live or seen):
		shown.append(_live)
	for v in views:
		var dev: Texture2D = _texture(VIEW_DIR + String(v[0]) + "_dev.jpg")
		var art: Texture2D = _texture(VIEW_DIR + String(v[0]) + "_art.jpg")
		if dev != null and art != null:
			shown.append({"dev": dev, "art": art, "label": String(v[1])})
	if shown.is_empty():
		_on_explained()
		return
	_explainer.call("open", shown, OS.get_keycode_string(_look.get("key")) if _look != null else "I")
	_play(_chime)


func _on_explained() -> void:
	_hold_player(false)
	_busy = false
	seen = true
	if verbose:
		print("LOOKGUIDE: explained; your turn")
	# Your turn: the big prompt, until you switch (and then the praise).
	if not praised:
		_prompt.call("show_prompt", true)


## While the explainer is up every key and click is its own: Space, Enter, F, Esc or a click close it once it may be
## skipped. During the shift nothing gets through either (not I, not Esc: the rig would free the mouse or quit).
func _input(event: InputEvent) -> void:
	if not _busy:
		return
	if not (event is InputEventKey or event is InputEventMouseButton or event is InputEventMouseMotion):
		return
	if bool(_explainer.call("is_open")) and bool(_explainer.call("can_skip")):
		var go: bool = false
		if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
			var k: Key = (event as InputEventKey).keycode
			go = k in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE] or event.is_action_pressed(&"catch_target")
		elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
			go = (event as InputEventMouseButton).button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]
		if go:
			_explainer.call("close")
	get_viewport().set_input_as_handled()


func _hold_player(hold: bool) -> void:
	if _player != null:
		_player.set("input_enabled", not hold)
		if hold:
			_player.set("velocity", Vector4.ZERO)


## The HUD off (returns what it hid) or back on (what was hidden): the scene's canvas layers by `visible`, and every
## top-level piece of its 2D by `modulate` (made clear, then given back), because some re-show themselves every frame
## (the catcher's "Catch [F]"). This node's own pieces are left alone.
func _hud(on: bool, hidden: Array = []) -> Array:
	if on:
		for entry in hidden:
			var item: Object = entry[0]
			if not is_instance_valid(item):
				continue
			if item is CanvasLayer:
				(item as CanvasLayer).visible = true
			else:
				(item as CanvasItem).modulate = entry[1]
		return []
	var out: Array = []
	var room: Node = owner if owner != null else get_parent().get_parent()
	for node in room.find_children("*", "CanvasLayer", true, false):
		if is_ancestor_of(node) or not (node as CanvasLayer).visible:
			continue
		(node as CanvasLayer).visible = false
		out.append([node, null])
	for node in room.find_children("*", "CanvasItem", true, false):
		if is_ancestor_of(node):
			continue
		var item := node as CanvasItem
		if item.get_parent() is CanvasItem:
			continue
		var layer_parent: Node = item.get_parent()
		for depth in 64:
			if layer_parent == null or layer_parent is CanvasLayer or layer_parent == room:
				break
			layer_parent = layer_parent.get_parent()
		if layer_parent is CanvasLayer:
			continue
		out.append([item, item.modulate])
		item.modulate = Color(item.modulate, 0.0)
	return out


## The frame on screen now, as a texture (it stalls this frame: only ever at the shift).
func _grab() -> Texture2D:
	var tex: ViewportTexture = get_viewport().get_texture()
	if tex == null:
		return null
	var img: Image = tex.get_image()
	if img == null or img.is_empty():
		return null
	return ImageTexture.create_from_image(img)


func _draw_sweep() -> void:
	if _sweep_tex == null:
		return
	var screen: Vector2 = _sweep.get_viewport_rect().size
	var u: float = screen.y / 1080.0
	var x: float = screen.x * _sweep_x
	var ts: Vector2 = _sweep_tex.get_size()
	var k: float = ts.x / maxf(screen.x, 1.0)
	if x < screen.x:
		_sweep.draw_texture_rect_region(_sweep_tex, Rect2(Vector2(x, 0.0), Vector2(screen.x - x, screen.y)), Rect2(Vector2(x * k, 0.0), Vector2((screen.x - x) * k, ts.y)))
	var c := Color(0.55, 0.85, 1.0)
	_sweep.draw_rect(Rect2(Vector2(x - 60.0 * u, 0.0), Vector2(60.0 * u, screen.y)), Color(c, 0.10))
	_sweep.draw_rect(Rect2(Vector2(x - 16.0 * u, 0.0), Vector2(32.0 * u, screen.y)), Color(c, 0.22))
	_sweep.draw_rect(Rect2(Vector2(x - 3.0 * u, 0.0), Vector2(6.0 * u, screen.y)), Color(1, 1, 1, 0.95))


static func _texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var t: Resource = load(path)
		if t is Texture2D:
			return t
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	if img == null or img.is_empty():
		return null
	return ImageTexture.create_from_image(img)


# --- Sounds, made rather than loaded --------------------------------------------------------------

func _play(stream: AudioStream) -> void:
	if _sound != null and stream != null:
		_sound.stream = stream
		_sound.play()


## Struck notes together, decaying (the praise, the explainer opening).
static func _make_tone(notes: Array, seconds: float, decay: float) -> AudioStreamWAV:
	var rate: int = 22050
	var count: int = int(rate * seconds)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var t: float = float(i) / float(rate)
		var env: float = minf(t / 0.01, 1.0) * exp(-t * decay)
		var wave: float = 0.0
		for n in notes.size():
			var at: float = t - 0.07 * float(n)
			if at > 0.0:
				wave += sin(TAU * float(notes[n]) * at) * exp(-at * decay) / float(notes.size())
		data.encode_s16(i * 2, int(clampf(wave * env * 1.6, -1.0, 1.0) * 30000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = rate
	s.data = data
	return s


## The shift: a rising shimmer, three detuned voices gliding up an octave, swelling and fading.
static func _make_shift() -> AudioStreamWAV:
	var rate: int = 22050
	var seconds: float = 1.9
	var count: int = int(rate * seconds)
	var data := PackedByteArray()
	data.resize(count * 2)
	var phase: Array = [0.0, 0.0, 0.0]
	var detune: Array = [1.0, 1.007, 0.994]
	for i in count:
		var t: float = float(i) / float(rate)
		var k: float = t / seconds
		var f: float = 330.0 * pow(2.0, k * 1.2)
		var wave: float = 0.0
		for v in 3:
			phase[v] = float(phase[v]) + TAU * f * float(detune[v]) / float(rate)
			wave += sin(float(phase[v])) + 0.3 * sin(float(phase[v]) * 2.0)
		var env: float = sin(PI * minf(k * 1.15, 1.0)) * (1.0 - k * 0.4)
		var sparkle: float = sin(TAU * 7.0 * t) * 0.15 + 0.85
		data.encode_s16(i * 2, int(clampf(wave / 3.9 * env * sparkle, -1.0, 1.0) * 26000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = rate
	s.data = data
	return s


## Ctrl+R: a new visitor (WGuide.reset() calls the "discovery_reset" group).
func reset() -> void:
	seen = false
	praised = false
	switched = false
	_played = 0.0
	_was_near = false
	_live = {}
	# The game resets everyone in its own _ready, before this node has built its prompt.
	if _prompt != null and bool(_prompt.call("showing")):
		_prompt.call("hide_prompt", false)
