@tool
extends Node4D

## THE FITTING CIRCLE, beside Trym's house: where you change what you wear (follow_up/outfit.md).
##
## TRYM'S TECH, NOT A SHOP. It is built in the language of the arch he raises out of the field
## (theatre/theatre_arch_4d.gd): a dark navy frame with cyan edges, a blue field, lamps of its own, a
## two-note chime, and the same manners. It grows rather than appearing: walk up and its frame comes
## up out of the plate, first the posts, then the ring; walk away and it lifts off into the air. And
## it is thick through W, so a turned slice still finds it.
##
## THE PLATE IS ALWAYS THERE. Unlike the arch, which is put up for one trip, the circle is a place
## you are meant to find, so its plate stays in the grass, a dark disc with a cyan ring you can see
## from the path. Only the frame comes and goes.
##
## STEP IN, AND IT LOOKS AT YOU. Standing in the middle switches your walking off, turns you to face
## the camera and brings the camera in (the conversation framing): a mirror. A ring of light sweeps up
## you from the boots to the hat, each part lighting cyan as it passes, and leaves a strip of choices
## at the height of each thing it changes (outfit_strips_4d.gd). At the top it reads out your size in
## all four directions, how thick you are in W included: the one number no 3D fitting room has.
##
## EVERY CHANGE IS ON YOU AT ONCE, with no confirm (the research: live preview on the real character,
## a way back to what you came in wearing, and then a "surprise me" is safe to press). F saves it to
## disk (outfit_4d.gd) and gives you back your feet; the outfit then goes with you into the cave, the
## far room and the cinema (outfit_keeper_4d.gd), and is there next time you play.
##
## A SUBGAME THAT STAYS LOCAL (Ramon, 2 Oct, the Lookout). Its keys work only while you stand in it,
## with your walking off, so nothing it takes is taken anywhere else; its words fade with distance.

signal dressed
signal opened

const Outfit := preload("res://ramon/chickenpen/outfit/outfit_4d.gd")
const Keeper := preload("res://ramon/chickenpen/outfit/outfit_keeper_4d.gd")
const Strips := preload("res://ramon/chickenpen/outfit/outfit_strips_4d.gd")
const Wearer := preload("res://ramon/chickenpen/outfit/outfit_wearer_4d.gd")
const Trip := preload("res://ramon/chickenpen/outfit/outfit_room_trip_4d.gd")
## Ramon's version (outfit/PLAN_FITTING_ROOM.md): the same outfit, changed in a room of its own.
const ROOM := "res://ramon/chickenpen/outfit/fitting_room.tscn"

enum State { ASLEEP, READY, SCANNING, DRESSING, CLOSING }

@export_tool_button("Rebuild") var _rebuild_action: Callable = rebuild

## RAMON'S VERSION AS THE ONLY WAY. Off: you dress here, in the strips, and Enter takes you to the
## fitting room if you want it. On: the scan ends straight in the fitting room (fitting_room.tscn).
@export var opens_room: bool = false

@export var player_path: NodePath = NodePath("../../Player")

@export_group("Shape")
@export_range(0.4, 1.5, 0.01) var radius: float = 0.75
## Tall enough for the chicken: its comb stands 2.1 m up.
@export_range(1.6, 3.0, 0.05) var frame_height: float = 2.35
@export_range(0.2, 2.0, 0.05) var w_depth: float = 0.9
@export var frame_color: Color = Color(0.16, 0.19, 0.27)
@export var edge_color: Color = Color(0.32, 0.86, 1.0)
@export var field_color: Color = Color(0.20, 0.62, 0.95)

@export_group("Behaviour")
## Walk this close and the frame comes up: from Trym's sand, as you arrive at his house (at 5 m it
## stayed down until you were nearly on it, hidden by the grass and Bush06).
@export_range(1.0, 15.0, 0.5) var wakes_within: float = 8.0
## Stand this close to the middle, in your slice, and the scan starts.
@export_range(0.15, 0.7, 0.01) var step_in_within: float = 0.42
@export_range(0.2, 4.0, 0.05) var open_seconds: float = 1.2
## The first scan of a visit takes its time; later ones in the same run are quicker (the research:
## about a second and a half is the most a wait can take before it breaks your train of thought).
@export_range(0.5, 4.0, 0.05) var scan_seconds: float = 1.6
@export_range(0.3, 4.0, 0.05) var rescan_seconds: float = 0.9
## WHITE, NOT THE ARCH'S CYAN. The lamps light YOU, and a cyan light turned an orange shirt mustard and
## yellow trousers lime: no use in a place for choosing colours. A fitting room's light is plain.
@export var glow_color: Color = Color(1.0, 0.97, 0.92)
@export_range(0.0, 8.0, 0.1) var glow_energy: float = 0.9
@export_range(1.0, 30.0, 0.5, "suffix:m") var glow_range: float = 6.0
@export_range(-40.0, 6.0, 0.5) var sound_db: float = -11.0
## How far the camera stands while you dress: nearer than a conversation's 2.9 m, as the pen's lens is
## wide (77 degrees) and at 2.9 the figure was a small thing in the middle of a field.
@export_range(1.5, 4.0, 0.05) var mirror_distance: float = 2.3

var state: State = State.ASLEEP

var _player: Node4D
var _camera: Camera4D
var _rig: Node4D
var _frame: Node4D
var _pad: MeshInstance4D
var _hoop: Node4D
var _lamps: Array[OmniLight4D] = []
var _chime: AudioStreamPlayer
var _sweep: AudioStreamPlayer
var _tick: AudioStreamPlayer
var _open: float = 0.0
var _shutting: bool = false
var _lit: float = 0.0
var _t: float = 0.0
var _scanned_once: bool = false
var _scan_time: float = 0.0
var _scan_length: float = 1.6
var _row_hit: Array[bool] = []
var _strips: Node4D
var _ui: Control
var _tag: Label
var _hint: Label
var _readout: Label
var _readout_left: float = 0.0
var _said: String = ""
var _said_left: float = 0.0
var _came_in: Dictionary = {}
var _we_stopped_walking: bool = false
var _slide_from: Vector4
var _slide: float = 1.0
## The way the circle looks out (its +Z, flat), and how long the camera has left to come round to it.
var _front: Vector4 = Vector4(0.0, 0.0, 1.0, 0.0)
var _camera_turn: float = 0.0
var _needs_step_out: bool = false
var _refused: bool = false
var _rng := RandomNumberGenerator.new()
var _font: Font


func _ready() -> void:
	rebuild()
	if Engine.is_editor_hint():
		# In the editor it stands open, so it can be placed by eye.
		_open = 1.0
		_lay_frame()
		return
	_rng.randomize()
	_player = get_node_or_null(player_path) as Node4D
	if _player != null:
		_rig = _player.get_node_or_null("CameraRig") as Node4D
		_camera = _player.get_node_or_null("CameraRig/Pitch/Camera4D") as Camera4D
	else:
		push_warning("OutfitCircle: player_path resolves to nothing - the circle will never wake.")
	_font = load("res://ramon/Demo/fonts/Montserrat/static/Montserrat-SemiBold.ttf") as Font
	add_to_group(&"outfit_circle")
	_build_ui()
	_lay_frame()


func _enter_tree() -> void:
	if Engine.is_editor_hint():
		return
	# Every time the pen comes back into the tree (a laptop trip, the range, a reload), make sure the
	# keeper is there: it is what dresses the player in every scene.
	var root: Window = get_tree().root
	if root.get_node_or_null(NodePath(String(Keeper.NAME))) == null:
		var keeper: Node = Keeper.new()
		keeper.name = Keeper.NAME
		root.add_child.call_deferred(keeper)


func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return
	# Parked or freed in the middle of dressing: give the player back whatever was taken.
	if state == State.SCANNING or state == State.DRESSING:
		_finish(false)


# --- Building --------------------------------------------------------------------------------------

func rebuild() -> void:
	for child in get_children():
		if child.has_meta(&"outfit_built"):
			child.free()
	_lamps.clear()
	# THE PLATE: a dark disc on a slightly wider cyan one, so a ring of light shows round its edge;
	# both cubinders, round in x and z and square in y and W (CubinderShape4D), the marsh's trick.
	_disc("Rim", radius + 0.05, 0.025, w_depth + 0.04, edge_color, 0.0125)
	_disc("Plate", radius, 0.045, w_depth, frame_color, 0.0225)
	_pad = _disc("Pad", radius * 0.6, 0.05, w_depth * 0.9, field_color.darkened(0.45), 0.025)

	_frame = _built(Node4D.new(), "Frame") as Node4D
	# THREE POSTS, none in front: one behind, two at the front corners, so you walk in between two of
	# them and the camera sees you through the open side.
	for i in 3:
		var angle: float = PI + i * TAU / 3.0
		var at := Vector4(sin(angle) * radius, frame_height * 0.5, cos(angle) * radius, 0.0)
		_box(_frame, "Post%d" % i, at, Vector4(0.07, frame_height, 0.07, w_depth), frame_color)
		var inward := Vector4(-sin(angle), 0.0, -cos(angle), 0.0) * 0.045
		_box(_frame, "PostEdge%d" % i, at + inward, Vector4(0.025, frame_height * 0.94, 0.025, w_depth), edge_color)
	_ring(_frame, "Crown", radius, frame_height, 0.06, 0.07, frame_color)
	_ring(_frame, "CrownEdge", radius - 0.035, frame_height - 0.045, 0.02, 0.025, edge_color)

	# THE SCAN: a ring of light that sweeps up you. Hidden until it runs.
	_hoop = _built(Node4D.new(), "Scan") as Node4D
	_ring(_hoop, "Hoop", radius * 0.82, 0.0, 0.03, 0.05, edge_color.lerp(Color.WHITE, 0.25))
	_hoop.visible = false

	for side in [-1.0, 1.0]:
		var lamp := OmniLight4D.new()
		lamp.name = "Glow%d" % int(side)
		lamp.light_color = glow_color
		lamp.light_energy = 0.0
		lamp.omni_range_meters = glow_range
		_built(lamp, lamp.name)
		lamp.position = Vector4(0.0, 1.1, side * 1.0, 0.0)
		_lamps.append(lamp)

	_chime = _sound("Chime", _make_chime(660.0, 990.0, 0.7))
	_sweep = _sound("Sweep", _make_sweep(scan_seconds))
	_tick = _sound("Tick", _make_chime(1760.0, 2640.0, 0.09))


func _built(node: Node, part: String) -> Node:
	node.name = part
	node.set_meta(&"outfit_built", true)
	add_child(node)
	return node


func _disc(part: String, r: float, height: float, thickness: float, colour: Color, y: float) -> MeshInstance4D:
	var shape := CubinderShape4D.new()
	shape.radius = r
	shape.height = height
	shape.thickness = thickness
	var node := MeshInstance4D.new()
	node.mesh = shape.to_tetra_mesh({"segments": 32})
	node.material_override = _material(colour)
	node.set_meta(&"_look_own", true)
	_built(node, part)
	node.position = Vector4(0.0, y, 0.0, 0.0)
	return node


func _box(parent: Node, part: String, at: Vector4, size: Vector4, colour: Color) -> MeshInstance4D:
	var node := MeshInstance4D.new()
	node.name = part
	var mesh := BoxTetraMesh4D.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = _material(colour)
	node.set_meta(&"_look_own", true)
	parent.add_child(node)
	node.position = at
	return node


## A ring of [param segments] boxes merged into one mesh: one 4D instance rather than twenty-four
## (every instance takes shader instance variables, LabKit/lab_bay_4d.gd).
func _ring(parent: Node, part: String, r: float, y: float, height: float, depth: float, colour: Color) -> MeshInstance4D:
	var segments: int = 28
	var length: float = TAU * r / segments * 1.04
	var merged := ArrayTetraMesh4D.new()
	for i in segments:
		var angle: float = i * TAU / segments
		var piece := BoxTetraMesh4D.new()
		piece.size = Vector4(length, height, depth, w_depth)
		merged.merge_with(piece.to_array_tetra_mesh(), Vector4(sin(angle) * r, 0.0, cos(angle) * r, 0.0),
			Basis4D.from_zx(angle))
	var node := MeshInstance4D.new()
	node.name = part
	node.mesh = merged
	node.material_override = _material(colour)
	node.set_meta(&"_look_own", true)
	parent.add_child(node)
	node.position = Vector4(0.0, y, 0.0, 0.0)
	return node


func _material(colour: Color) -> TetraMaterial4D:
	var material := TetraMaterial4D.new()
	material.albedo_color = colour
	return material


func _sound(part: String, stream: AudioStream) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = sound_db
	_built(player, part)
	return player


func _build_ui() -> void:
	# On the pen's own UI layer, so the crossings that put the farm to sleep (the cinema) hide these
	# words with the rest of its HUD; a layer of its own only when there is none (a bare test scene).
	var layer: Node = null
	var at: Node = get_parent()
	while at != null and layer == null:
		var ui: Node = at.get_node_or_null("UI")
		if ui is CanvasLayer:
			layer = ui
		at = at.get_parent()
	if layer == null:
		layer = CanvasLayer.new()
		layer.name = "OutfitUI"
		_built(layer, "OutfitUI")
	_ui = Control.new()
	_ui.name = "OutfitCircleUI"
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_ui)
	_tag = _label("Tag", 21)
	_hint = _label("Hint", 20)
	_readout = _label("Readout", 20)


func _label(part: String, font_size: int) -> Label:
	var label := Label.new()
	label.name = part
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _font != null:
		label.add_theme_font_override("font", _font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.74))
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.10, 0.13, 0.78)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 5.0
	style.content_margin_bottom = 5.0
	style.set_corner_radius_all(4)
	label.add_theme_stylebox_override("normal", style)
	label.visible = false
	_ui.add_child(label)
	return label


# --- Every frame -----------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _player == null or _frame == null:
		return
	_t += delta
	var gap: float = _flat_gap()
	var near: bool = gap <= wakes_within and _in_my_slice(1.2)
	# Asleep, with nobody near and nothing to say: nothing to move, light or write this frame.
	if not near and state == State.ASLEEP and _open <= 0.0 and _lit <= 0.0 and _said_left <= 0.0:
		if _tag.visible or _hint.visible or _readout.visible:
			_tag.visible = false
			_hint.visible = false
			_readout.visible = false
		return
	# Up when you are near or using it; away into the air when you leave.
	var want: float = 1.0 if (near or state != State.READY and state != State.ASLEEP) else 0.0
	if want > 0.5 and _open < 0.01:
		_shutting = false
		_chime.play()
	elif want < 0.5 and _open > 0.99:
		_shutting = true
	_open = move_toward(_open, want, delta / maxf(open_seconds, 0.05))
	if _open <= 0.0:
		_shutting = false
	state = State.READY if _open > 0.99 and state == State.ASLEEP else state
	if _open < 0.99 and state == State.READY:
		state = State.ASLEEP
	_lay_frame()

	match state:
		State.READY:
			if _needs_step_out:
				_needs_step_out = gap < step_in_within + 0.5
			elif gap <= step_in_within and _in_my_slice(0.45):
				_try_begin()
			else:
				_refused = false
		State.SCANNING:
			_run_scan(delta)
		State.CLOSING:
			_run_close(delta)
	if state == State.SCANNING or state == State.DRESSING:
		_keep_in_place(delta)
		if _camera_turn > 0.0 and _rig != null and _rig.has_method("face_toward"):
			_camera_turn = maxf(_camera_turn - delta, 0.0)
			_rig.call("face_toward", -_front, 1.0 if _camera_turn <= 0.0 else clampf(delta * 7.0, 0.0, 1.0))

	# The lamps and the pad follow one number, as the arch's lamps and field do.
	var want_lit: float = 0.0
	if _open > 0.0:
		want_lit = 0.35
	if state == State.SCANNING:
		want_lit = 1.0
	elif state == State.DRESSING:
		want_lit = 0.6
	_lit = move_toward(_lit, want_lit, delta * 1.6)
	for lamp in _lamps:
		lamp.light_energy = glow_energy * _lit * 0.5
	var shimmer: float = 0.5 + 0.5 * sin(_t * (2.5 + 3.0 * _lit))
	(_pad.material_override as TetraMaterial4D).albedo_color = field_color.darkened(0.45).lerp(
		field_color.lerp(Color(0.85, 0.97, 1.0), shimmer * 0.4), clampf(_lit * 1.2, 0.0, 1.0))
	_update_words(delta, gap)


## The frame at its current height: up out of the plate on the way in, up into the air on the way out.
func _lay_frame() -> void:
	if _frame == null:
		return
	var up: float = clampf(_open * 1.25, 0.0, 1.0)
	_frame.visible = _open > 0.005
	var away: float = frame_height * (1.0 - up) * (1.0 if _shutting else -1.0)
	_frame.position = Vector4(0.0, away, 0.0, 0.0)


# --- Stepping in -----------------------------------------------------------------------------------

func _try_begin() -> void:
	if not bool(_player.get("input_enabled")):
		return
	var catcher: Node = _catcher()
	if catcher != null and catcher.get("carried") != null:
		if not _refused:
			_say("Put the chicken down first.", 2.5)
			_refused = true
		return
	begin()


## Starts the scan with the player where they stand. Public for tests.
func begin() -> void:
	if state == State.SCANNING or state == State.DRESSING or _player == null:
		return
	var wearer: Node = _wearer()
	_came_in = Outfit.snapshot()
	_we_stopped_walking = bool(_player.get("input_enabled"))
	_player.set("input_enabled", false)
	if _player is CharacterBody4D:
		(_player as CharacterBody4D).linear_velocity = Vector4.ZERO
	_slide_from = _player.global_position
	_slide = 0.0
	# THE MIRROR HAS A PLACE TO STAND. The camera comes round to the circle's open front, whichever way
	# you walked in, as a fitting-room mirror is where it is: so the view is one chosen to be clear (the
	# first try came in from the path, through a bush), with the house behind you, and you turn to face it.
	var front: Vector4 = global_basis * Vector4(0.0, 0.0, 1.0, 0.0)
	_front = Vector4(front.x, 0.0, front.z, 0.0).normalized()
	_camera_turn = 0.8
	if _player.has_method("face_towards"):
		_player.call("face_towards", global_position + _front * 4.0)
	if _rig != null and _rig.has_method("set_talking"):
		# The conversation framing (the pivot down at the waist), then nearer still. Ending it gives
		# back the distance you had, as a conversation's end does.
		_rig.call("set_talking", true)
		_rig.set("_zoom_target", mirror_distance)
	_open = 1.0
	state = State.SCANNING
	_scan_time = 0.0
	_scan_length = rescan_seconds if _scanned_once else scan_seconds
	_row_hit.clear()
	for i in Outfit.ROWS.size():
		_row_hit.append(false)
	_make_strips()
	_hoop.visible = true
	_sweep.pitch_scale = scan_seconds / _scan_length
	_sweep.play()
	_said_left = 0.0
	if wearer == null:
		push_warning("OutfitCircle: no wearer on the player yet - the outfit will show once the keeper finds them.")
	opened.emit()


func _make_strips() -> void:
	if _strips != null and is_instance_valid(_strips):
		_strips.free()
	var strips: Node4D = Strips.new()
	strips.name = "Strips"
	strips.set("frame_color", frame_color)
	strips.set("edge_color", edge_color)
	strips.set("w_depth", minf(w_depth, 0.6))
	strips.set("camera", _camera)
	strips.set("ui", _ui)
	strips.set("font", _font)
	strips.set_meta(&"outfit_built", true)
	add_child(strips)
	# Facing the mirror (the circle's front, where the camera comes round to): +Z toward it, +X to its
	# right, so the strips stand on your right as you look at yourself.
	var yaw: float = atan2(_front.x, _front.z)
	# On the circle's own middle, where you end up, not where you were the moment you stepped in.
	strips.global_position = global_position
	strips.global_basis = Basis4D.from_zx(yaw)
	_strips = strips


## The player eased to the middle, and held there: the walk is off, but a body still slides on.
func _keep_in_place(delta: float) -> void:
	_slide = minf(_slide + delta / 0.35, 1.0)
	var mid := Vector4(global_position.x, _slide_from.y, global_position.z, global_position.w)
	var at: Vector4 = _slide_from.lerp(mid, smoothstep(0.0, 1.0, _slide))
	_player.global_position = Vector4(at.x, _player.global_position.y, at.z, at.w)
	if _player is CharacterBody4D:
		(_player as CharacterBody4D).linear_velocity = Vector4.ZERO


# --- The scan --------------------------------------------------------------------------------------

func _run_scan(delta: float) -> void:
	_scan_time += delta
	var k: float = clampf(_scan_time / _scan_length, 0.0, 1.0)
	# Up into the frame's own top ring, so the sweep ends where the frame does, over any hat.
	var top: float = frame_height - 0.06
	var y: float = lerpf(0.04, top, ease(k, -1.6))
	_hoop.position = Vector4(0.0, y, 0.0, 0.0)
	var wearer: Node = _wearer()
	# Each row prints as the ring passes its part (the strip's height), boots first.
	for i in range(Outfit.ROWS.size() - 1, -1, -1):
		if not _row_hit[i] and y >= float(Strips.HEIGHTS[i]) - 0.06:
			_row_hit[i] = true
			_tick.play()
			if wearer != null:
				wearer.call("flash", i)
	for i in Outfit.ROWS.size():
		if _row_hit[i] and _strips != null:
			_strips.call("set_print", i, float(_strips.call("get_print", i)) + delta / 0.45)
	if k >= 1.0 and _all_printed():
		_scanned_once = true
		state = State.DRESSING
		_hoop.visible = false
		_show_readout()
		if opens_room:
			open_room()


func _all_printed() -> bool:
	if _strips == null:
		return true
	for i in Outfit.ROWS.size():
		if float(_strips.call("get_print", i)) < 1.0:
			return false
	return true


## THE 4D BEAT: your size in all four directions, measured from the figure's own parts as it stands,
## hat and all. The fourth is the one a 3D fitting room cannot give you.
func _show_readout() -> void:
	var size: Vector4 = measure_figure()
	if size == Vector4.ZERO:
		return
	_readout.text = "SCANNED   %.2f m tall    %.2f wide    %.2f deep    %.2f thick in W" % [size.y, size.x, size.z, size.w]
	_readout_left = 6.0


## The figure's extent in its own frame (x wide, y tall, z deep, w thick), from every box in it.
func measure_figure() -> Vector4:
	var figure: Node4D = _player.get_node_or_null("Avatar") as Node4D if _player != null else null
	if figure == null:
		return Vector4.ZERO
	var low := Vector4(INF, INF, INF, INF)
	var high := Vector4(-INF, -INF, -INF, -INF)
	var inverse: Projection = figure.global_basis.inverse()
	for node in figure.find_children("*", "MeshInstance4D", true, false):
		var part := node as MeshInstance4D
		if not (part.mesh is BoxTetraMesh4D) or not part.is_visible_in_tree():
			continue
		var half: Vector4 = (part.mesh as BoxTetraMesh4D).size * 0.5
		var centre: Vector4 = inverse * (part.global_position - figure.global_position)
		low = Vector4(minf(low.x, centre.x - half.x), minf(low.y, centre.y - half.y), minf(low.z, centre.z - half.z), minf(low.w, centre.w - half.w))
		high = Vector4(maxf(high.x, centre.x + half.x), maxf(high.y, centre.y + half.y), maxf(high.z, centre.z + half.z), maxf(high.w, centre.w + half.w))
	return high - low if high.x > low.x else Vector4.ZERO


# --- Dressing --------------------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or state != State.DRESSING:
		return
	var key := event as InputEventKey
	if key == null or not key.pressed:
		return
	var row: int = int(_strips.get("active_row")) if _strips != null else 3
	var handled: bool = true
	var code: Key = key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
	if event.is_action_pressed(&"move_forward", true) or code == KEY_UP:
		_choose_row(row - 1)
	elif event.is_action_pressed(&"move_back", true) or code == KEY_DOWN:
		_choose_row(row + 1)
	elif event.is_action_pressed(&"move_left", true) or code == KEY_LEFT:
		change_colour(-1)
	elif event.is_action_pressed(&"move_right", true) or code == KEY_RIGHT:
		change_colour(1)
	elif event.is_action_pressed(&"move_kata", true):
		change_style(-1)
	elif event.is_action_pressed(&"move_ana", true):
		change_style(1)
	elif code == KEY_X and not key.echo:
		surprise()
	elif code == KEY_BACKSPACE and not key.echo:
		undo()
	elif event.is_action_pressed(&"catch_target") and not key.echo:
		done()
	elif (code == KEY_ENTER or code == KEY_KP_ENTER) and not key.echo:
		open_room()
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()


func _choose_row(row: int) -> void:
	if _strips == null:
		return
	_strips.set("active_row", clampi(row, 0, Outfit.ROWS.size() - 1))
	_tick.play()


## The active row's colour, one tile left or right. Public for tests.
func change_colour(step: int) -> void:
	var row: int = int(_strips.get("active_row")) if _strips != null else 3
	Outfit.step(Outfit.ROWS[row][1], step)
	_changed(row)


## The active row's style (the hat, or the trousers' length), one along. Rows without styles say so.
func change_style(step: int) -> void:
	var row: int = int(_strips.get("active_row")) if _strips != null else 3
	var key: String = Outfit.ROWS[row][2]
	if key == "":
		_say("%s has one style. Q and E change the hat and the trousers." % Outfit.ROWS[row][0].capitalize(), 2.5)
		return
	Outfit.step(key, step)
	_changed(row)


func surprise() -> void:
	Outfit.randomise(_rng)
	_changed(-1)


## Back to what you came in wearing.
func undo() -> void:
	Outfit.restore(_came_in)
	_changed(-1)


func _changed(row: int) -> void:
	_tick.play()
	var wearer: Node = _wearer()
	if wearer == null:
		return
	if row >= 0:
		wearer.call("flash", row, 0.8)
	else:
		for i in Outfit.ROWS.size():
			wearer.call("flash", i, 0.6)


## Enter: off to Trym's fitting room, Ramon's version (outfit_room_trip_4d.gd parks the farm, this
## circle with it; its _exit_tree ends the dressing cleanly, and came_back() greets you on return).
func open_room() -> void:
	if state != State.DRESSING or not is_inside_tree():
		return
	var root: Window = get_tree().root
	if root.get_node_or_null(NodePath(String(Trip.NAME))) != null or not ResourceLoader.exists(ROOM):
		return
	var trip: Node = Trip.new()
	trip.name = Trip.NAME
	root.add_child(trip)
	trip.call("go", ROOM, _camera)


## Back from the fitting room, standing in the circle again.
func came_back(saved: bool) -> void:
	_say("Saved. It goes with you." if saved else "Nothing changed.", 2.6)


## F: save, fold the strips back into the ring, and give the player back their feet. Public for tests.
func done() -> void:
	if state != State.DRESSING and state != State.SCANNING:
		return
	_finish(true)


func _finish(animate: bool) -> void:
	var err: Error = Outfit.save()
	_readout_left = 0.0
	if _we_stopped_walking and _player != null and is_instance_valid(_player):
		_player.set("input_enabled", true)
	_we_stopped_walking = false
	if _player != null and is_instance_valid(_player) and _player.has_method("stop_facing"):
		_player.call("stop_facing")
	if _rig != null and is_instance_valid(_rig) and _rig.has_method("set_talking"):
		_rig.call("set_talking", false)
	_needs_step_out = true
	if not animate or not is_inside_tree():
		if _strips != null and is_instance_valid(_strips):
			_strips.queue_free()
		_strips = null
		state = State.READY
		_hoop.visible = false
		return
	_say("Saved. It goes with you." if err == OK else "Could not save. It stays for this visit.", 2.5)
	_chime.play()
	state = State.CLOSING
	dressed.emit()


func _run_close(delta: float) -> void:
	var left: float = 0.0
	if _strips != null and is_instance_valid(_strips):
		for i in Outfit.ROWS.size():
			var p: float = maxf(float(_strips.call("get_print", i)) - delta / 0.4, 0.0)
			_strips.call("set_print", i, p)
			left = maxf(left, p)
	if left <= 0.0:
		if _strips != null and is_instance_valid(_strips):
			_strips.queue_free()
		_strips = null
		state = State.READY


# --- Words -----------------------------------------------------------------------------------------

func _say(text: String, seconds: float) -> void:
	_said = text
	_said_left = seconds


func _update_words(delta: float, gap: float) -> void:
	if _ui == null:
		return
	_said_left = maxf(_said_left - delta, 0.0)
	_readout_left = maxf(_readout_left - delta, 0.0)
	var awake: bool = is_visible_in_tree() and _camera != null and _player.is_inside_tree()
	# The tag over the frame: what it is from the path, how to use it up close, and anything it has
	# to tell you. Nothing while you are dressing; the strips and the hint do the talking then.
	var tag_text: String = ""
	if _said_left > 0.0:
		tag_text = _said
	elif state == State.READY and _open > 0.99 and not _needs_step_out:
		tag_text = "Step in to change your outfit" if gap < 2.6 else "Outfit scanner"
	_place(_tag, tag_text, global_position + Vector4(0.0, frame_height + 0.35, 0.0, 0.0), awake and gap < wakes_within + 2.0)
	_hint.text = _hint_text()
	_place_bottom(_hint, awake and state == State.DRESSING)
	# The scan's result as a line over the keys, where it can be read for a few seconds without
	# covering you or the strips (over the frame it ran into the HUD's top row).
	_place_bottom(_readout, awake and _readout_left > 0.0 and state == State.DRESSING, _hint.size.y + 10.0)
	_readout.self_modulate.a = clampf(_readout_left / 0.6, 0.0, 1.0)


func _hint_text() -> String:
	return "%s %s  part      %s %s  colour      %s %s  style      X  surprise me      Backspace  undo      Enter  fitting room      %s  done" % [
		_key_of(&"move_forward"), _key_of(&"move_back"), _key_of(&"move_left"), _key_of(&"move_right"),
		_key_of(&"move_kata"), _key_of(&"move_ana"), _key_of(&"catch_target")]


## The first key bound to [param action], read from the InputMap as every prompt in the pen is, so a
## rebind stays true.
func _key_of(action: StringName) -> String:
	if not InputMap.has_action(action):
		return "?"
	for event in InputMap.action_get_events(action):
		var key := event as InputEventKey
		if key != null:
			var code: Key = key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
			return OS.get_keycode_string(code)
	return "?"


func _place(label: Label, text: String, at: Vector4, shown: bool) -> void:
	if not shown or text == "" or _camera == null:
		label.visible = false
		return
	var forward: Vector4 = -_camera.global_basis.z
	if forward.dot(at - _camera.global_position) <= 0.05:
		label.visible = false
		return
	label.text = text
	label.visible = true
	label.size = label.get_combined_minimum_size()
	var screen: Vector2 = _ui.get_viewport_rect().size
	var point: Vector2 = _camera.world_to_viewport(at) * screen / Vector2(_ui.get_viewport().get_size())
	label.position = Vector2(clampf(point.x - label.size.x * 0.5, 16.0, screen.x - label.size.x - 16.0),
		clampf(point.y - label.size.y, 16.0, screen.y - label.size.y - 16.0))


func _place_bottom(label: Label, shown: bool, above: float = 0.0) -> void:
	label.visible = shown
	if not shown:
		return
	label.size = label.get_combined_minimum_size()
	var screen: Vector2 = _ui.get_viewport_rect().size
	label.position = Vector2((screen.x - label.size.x) * 0.5, screen.y - label.size.y - screen.y * 0.06 - above)


# --- Helpers ---------------------------------------------------------------------------------------

## How far the player is from the middle, ignoring height.
func _flat_gap() -> float:
	var gap: Vector4 = _player.global_position - global_position
	return Vector2(gap.x, gap.z).length()


## Whether the player's body is within [param reach] of the circle's own thickness through W: whether
## they are standing in it, not whether it is on screen. (The words over it are measured from the
## camera, in _place, as the world tags do.)
func _in_my_slice(reach: float) -> bool:
	var gap: Vector4 = _player.global_position - global_position
	return absf(gap.w) <= w_depth * 0.5 + reach


func _wearer() -> Node:
	var keeper: Node = get_tree().root.get_node_or_null(NodePath(String(Keeper.NAME)))
	var figure: Node = _player.get_node_or_null("Avatar") if _player != null else null
	if keeper == null or figure == null:
		return null
	return keeper.call("wearer_for", figure)


func _catcher() -> Node:
	for child in _player.get_children():
		if "carried" in child:
			return child
	return null


## A two-note chime, struck and decaying (the arch's, theatre_arch_4d.gd), at any pitch and length.
func _make_chime(low: float, high: float, seconds: float) -> AudioStreamWAV:
	var rate: int = 22050
	var count: int = int(rate * seconds)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var t: float = float(i) / float(rate)
		var envelope: float = minf(t / 0.008, 1.0) * exp(-t * (5.2 / maxf(seconds / 0.7, 0.05)))
		var wave: float = sin(TAU * low * t) * 0.6 + sin(TAU * high * t) * 0.4
		data.encode_s16(i * 2, int(clampf(wave * envelope, -1.0, 1.0) * 32000.0))
	return _wav(data, rate)


## The scan's sound: a soft tone rising with the ring, an octave and a half over its length.
func _make_sweep(seconds: float) -> AudioStreamWAV:
	var rate: int = 22050
	var count: int = int(rate * seconds)
	var data := PackedByteArray()
	data.resize(count * 2)
	var phase: float = 0.0
	for i in count:
		var k: float = float(i) / float(count)
		var freq: float = 330.0 * pow(2.0, 1.5 * k)
		phase += TAU * freq / float(rate)
		var envelope: float = minf(k / 0.06, 1.0) * minf((1.0 - k) / 0.12, 1.0) * 0.45
		var wave: float = sin(phase) * 0.7 + sin(phase * 2.0) * 0.18
		data.encode_s16(i * 2, int(clampf(wave * envelope, -1.0, 1.0) * 32000.0))
	return _wav(data, rate)


func _wav(data: PackedByteArray, rate: int) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = data
	return stream
