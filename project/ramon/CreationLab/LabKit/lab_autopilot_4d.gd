extends Node4D

## Watch mode: the route plays itself, as a guided film (follow_up/creation_lab_plan.md, step 67).
##
## For every bay in turn: a wide shot while the caption says the step's idea; the bay's own
## demo(t) performs its task (every bay content has one, LabKit/lab_bay_content_4d.gd) while the
## camera moves in; a closer shot while the caption says what just happened; then the lift, filmed
## from beside the pad so the bay you leave thins away through W and the next grows in. The Hall
## ends it with the reveal. Esc hands control back wherever you are, standing on that bay's pad.
##
## THE SHOTS are worked out from each bay's shell (the rig's spot) and its arrival framing, so a
## bay with a big exhibit gets wider shots without saying so; a content may give its own with
## film_marks() -> {"wide": [eye, look], ...} in its own space.
##
## FILM (the film runner): no HUD, no lectern cards, no avatar, from black and back to black.
## Plain Watch keeps none of the HUD either: the captions carry the words.
##
## NO class_name (engine_gotchas.md).

const Style := preload("res://ramon/CreationLab/LabKit/lab_style.gd")
const Overlay := preload("res://ramon/CreationLab/LabKit/lab_overlay_4d.gd")
const Mark := preload("res://ramon/CreationLab/LabKit/lab_mark_4d.gd")

signal finished

const INTRO := 3.2
const OUTRO := 3.4
const END_HOLD := 4.5
const FOLLOW := 1.6          # how quickly the camera eases to its next mark (per second)

var sequence: Node
var film: bool = false
var _cam: Camera4D
var _state: String = ""
var _t: float = 0.0
var _demo_len: float = 0.0
var _caption: Array = ["", "", ""]   # kicker, title, text
var _caption_t: float = 0.0
var _eye: Vector4
var _look: Vector4
var _placed: bool = false
var _total: float = 0.0
var _mood: String = "bright"


func _enter_tree() -> void:
	add_to_group(Overlay.GROUP_DRAWER)
	add_to_group("lab_mood_listener")


func apply_mood(m: String, _instant: bool = false) -> void:
	_mood = m


## Takes over: the film camera, the HUD and the avatar out of the way, the sequence's keys locked.
func start(seq: Node) -> void:
	sequence = seq
	_mood = Style.mood_of(get_tree())
	_cam = Camera4D.new()
	_cam.name = "FilmCamera"
	_cam.set("rendering_engine_name", "Cross-section")
	add_child(_cam)
	_cam.make_current()
	_cam.set("field_of_view_4d", 1.0)
	var player: Node4D = sequence.get("player")
	if player != null:
		player.visible = false
		player.set("input_enabled", false)
	(sequence.get("hud") as CanvasLayer).visible = false
	sequence.set("locked", true)
	var overlay: Node = Overlay.ensure(get_tree())
	overlay.set("film", true)
	# The shared back-to-menu prompt stays for Watch (H still works), not in the film.
	if film:
		var ret: Node = get_tree().current_scene.get_node_or_null("ReturnButton") if get_tree().current_scene != null else null
		if ret is CanvasLayer:
			(ret as CanvasLayer).visible = false
	_enter_bay()


## Gives control back: the player's camera, the HUD, the keys; the autopilot leaves.
func stop() -> void:
	var player: Node4D = sequence.get("player")
	if player != null:
		player.visible = true
		player.set("input_enabled", true)
		var pc: Camera4D = player.get_node_or_null("CameraRig/Pitch/Camera4D")
		if pc != null:
			pc.make_current()
	(sequence.get("hud") as CanvasLayer).visible = true
	sequence.set("locked", false)
	sequence.set("mode", "explore")
	var overlay: Node = Overlay.ensure(get_tree())
	overlay.set("film", false)
	_show_lift_frame(true)
	queue_free()


## The lift frame stands in front of every exhibit shot from the side, so it is shown only while
## the lift is riding, which is when it is the subject.
func _show_lift_frame(on: bool) -> void:
	var frame: Node4D = sequence.get_node_or_null("LiftFrame") as Node4D
	if frame != null and frame.visible != on:
		frame.visible = on


func _input(event: InputEvent) -> void:
	if film or sequence == null:
		return
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		stop()


func _bay() -> Dictionary:
	return sequence.get("bays")[int(sequence.get("current"))]


func _enter_bay() -> void:
	_state = "intro"
	_t = 0.0
	var st: Resource = _bay()["step"]
	var part: String = String(st.get("part"))
	_set_caption(String(st.get("code")) + "   " + part.to_upper(), String(st.get("title")), String(st.get("idea")))


func _set_caption(kicker: String, title: String, text: String) -> void:
	_caption = [kicker, title, text]
	_caption_t = 0.0


# -- the shots -------------------------------------------------------------------------------------

## A mark for the current bay, in the world: [eye, look].
func _mark(which: String) -> Array:
	var b: Dictionary = _bay()
	var root: Node4D = b["root"]
	var shell: Node = b["shell"]
	var content: Node = b["content"]
	var o: Vector4 = root.global_position
	if content != null and content.has_method("film_marks"):
		var own: Dictionary = content.call("film_marks")
		if own.has(which):
			return [o + (own[which][0] as Vector4), o + (own[which][1] as Vector4)]
	var rig: Vector4 = shell.call("spot", "rig")
	var pad: Vector4 = shell.call("spot", "pad")
	var arrival: Dictionary = sequence.call("arrival", int(sequence.get("current")))
	var k: float = clampf(float(arrival["distance"]) / 4.2, 1.0, 2.2)
	match which:
		"wide":
			return [o + rig + Vector4(-4.4, 2.7, 7.2, 0.0) * k, o + rig + Vector4(0.0, 0.9 * k, 0.0, 0.0)]
		"medium":
			return [o + rig + Vector4(-2.7, 1.7, 4.4, 0.0) * k, o + rig + Vector4(0.0, 0.8 * k, 0.0, 0.0)]
		"close":
			return [o + rig + Vector4(-1.7, 1.25, 2.9, 0.0) * k, o + rig + Vector4(0.0, 0.7 * k, 0.0, 0.0)]
		"lift":
			return [o + pad + Vector4(-4.0, 2.3, 4.2, 0.0), o + pad + Vector4(0.0, 1.0, -0.6, 0.0)]
	return [o + Vector4(0.0, 3.0, 8.0, 0.0), o]


func _aim(which: String, delta: float, snap: bool = false) -> void:
	var m: Array = _mark(which)
	if snap or not _placed:
		_eye = m[0]
		_look = m[1]
		_placed = true
	else:
		var k: float = 1.0 - exp(-FOLLOW * delta)
		_eye = _eye.lerp(m[0], k)
		_look = _look.lerp(m[1], k)
	_cam.global_position = _eye
	_cam.global_basis = Mark.basis_looking(_eye, _look)


# -- every frame -----------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if sequence == null or _cam == null:
		return
	_t += delta
	_total += delta
	_caption_t += delta
	var content: Node = _bay()["content"]
	_show_lift_frame(_state == "ride")
	match _state:
		"intro":
			_aim("wide", delta)
			if _t >= INTRO:
				_state = "demo"
				_t = 0.0
				_demo_len = float(content.call("demo", 0.0)) if content != null and content.has_method("demo") else 2.0
		"demo":
			_aim("medium", delta)
			if content != null and content.has_method("demo"):
				content.call("demo", _t)
			if _t >= _demo_len:
				sequence.call("complete_current")
				var st: Resource = _bay()["step"]
				var after: String = String(st.get("after"))
				if not after.is_empty():
					_set_caption(_caption[0], _caption[1], after)
				_state = "outro"
				_t = 0.0
		"outro":
			_aim("close", delta)
			if _t >= OUTRO:
				var i: int = int(sequence.get("current"))
				if i >= (sequence.get("bays") as Array).size() - 1:
					_state = "end"
					_t = 0.0
					_set_caption("THE CREATION LAB", "Built from balls, brought to life by a clock.", "Press Esc to walk the Hall yourself: every view you saw works on every animal here.")
				else:
					_state = "ride"
					_t = 0.0
					sequence.call("ride", i + 1)
		"ride":
			# The lift from beside the pad, riding along W with it: the bays dissolve around it.
			var player: Node4D = sequence.get("player")
			var m: Array = _mark("lift")
			_eye = _eye.lerp(m[0], 1.0 - exp(-FOLLOW * 2.0 * delta))
			_look = _look.lerp(m[1], 1.0 - exp(-FOLLOW * 2.0 * delta))
			if player != null:
				_eye.w = player.global_position.w
				_look.w = player.global_position.w
			_cam.global_position = _eye
			_cam.global_basis = Mark.basis_looking(_eye, _look)
			if not bool(sequence.call("lifting")) and _t > 0.5:
				_enter_bay()
		"end":
			_aim("wide", delta)
			if _t >= END_HOLD:
				_state = "done"
				finished.emit()
				if not film:
					stop()


# -- the captions and, for the film, the fades --------------------------------------------------------

func draw_overlay(canvas: Control, _overlay: Node) -> void:
	if sequence == null:
		return
	var vp: Vector2 = canvas.get_viewport_rect().size
	var ui: float = clampf(vp.y / 1080.0, 0.7, 2.2)
	if not String(_caption[2]).is_empty():
		var a: float = clampf(_caption_t / 0.6, 0.0, 1.0)
		var f_k: Font = Style.font("Bold")
		var f_t: Font = Style.font("SemiBold")
		var f_b: Font = Style.font("Regular")
		var fs_k: int = Style.size(Style.MICRO, ui)
		var fs_t: int = Style.size(Style.SUBTITLE, ui)
		var fs_b: int = Style.size(Style.BODY, ui)
		var width: float = minf(vp.x * 0.62, 860.0 * ui)
		var pad: float = 18.0 * ui
		var inner: float = width - pad * 2.0
		var body_h: float = f_b.get_multiline_string_size(String(_caption[2]), HORIZONTAL_ALIGNMENT_LEFT, inner, fs_b).y
		var h: float = pad * 2.0 + fs_k * 1.6 + fs_t * 1.5 + body_h
		var pos := Vector2(vp.x * 0.5 - width * 0.5, vp.y - h - 40.0 * ui)
		var box: StyleBoxFlat = Style.panel_box(_mood, ui)
		box.bg_color.a *= a
		box.border_color.a *= a
		box.shadow_color.a *= a
		canvas.draw_style_box(box, Rect2(pos, Vector2(width, h)))
		var part_col: Color = Style.code("w", _mood)
		var st: Resource = _bay()["step"]
		if String(st.get("part")) in ["build", "motion"]:
			part_col = Style.code(String(st.get("part")), _mood)
		canvas.draw_rect(Rect2(pos + Vector2(pad, -3.0 * ui), Vector2(40.0 * ui, 3.0 * ui)), Color(part_col, a))
		var y: float = pos.y + pad
		canvas.draw_string(f_k, Vector2(pos.x + pad, y + fs_k), String(_caption[0]), HORIZONTAL_ALIGNMENT_LEFT, inner, fs_k, Color(part_col, a))
		y += fs_k * 1.6
		canvas.draw_string(f_t, Vector2(pos.x + pad, y + fs_t), String(_caption[1]), HORIZONTAL_ALIGNMENT_LEFT, inner, fs_t, Color(Style.ui("text", _mood), a))
		y += fs_t * 1.5
		canvas.draw_multiline_string(f_b, Vector2(pos.x + pad, y + fs_b), String(_caption[2]), HORIZONTAL_ALIGNMENT_LEFT, inner, fs_b, -1, Color(Style.ui("text_dim", _mood), a))
	if film:
		# From black, and back to black at the end.
		var black: float = clampf(1.0 - _total / 1.2, 0.0, 1.0)
		if _state == "end" or _state == "done":
			black = maxf(black, clampf((_t - (END_HOLD - 1.2)) / 1.2, 0.0, 1.0))
		if black > 0.0:
			canvas.draw_rect(Rect2(Vector2.ZERO, vp), Color(0.0, 0.0, 0.0, black))
