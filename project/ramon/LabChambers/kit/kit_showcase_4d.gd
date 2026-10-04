@tool
extends Node4D

## Kit: a showcase. A round plinth with a lit rim and a coloured deck, the exhibit standing on it
## (built from `exhibit_script`, e.g. scripts/rd_goat_4d.gd), the W slices it can be cut at shown
## as thin frames behind it, and a floating WATCH button in front. Move the node and it all moves.
##
## IN PLAY (the scene drives it, goat_room_4d.gd):
##   slicing   step_slice(+/-1) moves the exhibit through W in nine steps (the lit frame follows);
##             turn_by(dx, dy) turns it through W. The room never moves.
##   watching  begin_cinematic, play(shot, t) per frame, end_cinematic; shot(i) gives each of the
##             exhibit's shots as [eye, look, lens] in the world, kept inside `bounds`.
##   acting    action() is the exhibit's one key (add a ball).
##   swapping  set_exhibit(script) puts another animal on the plinth (the room's 1 to 6 keys): the
##             old one goes at once, the new one grows in from its real size, and `serial` counts up
##             so the panels reading the exhibit start again from the new one.
##
## NO class_name (engine_gotchas.md).

const Build := preload("res://ramon/LabChambers/scripts/chamber_build.gd")
const RD := preload("res://ramon/LabChambers/scripts/rd_build.gd")
const LabGrid := preload("res://ramon/LabKit/lab_grid.gd")
const LabPrint := preload("res://ramon/LabKit/lab_print.gd")
const Mats := preload("res://ramon/LabKit/lab_materials.gd")
const Batch := preload("res://ramon/LabKit/lab_batch.gd")
const Style := preload("res://ramon/LabChambers/kit/kit_style.gd")
const Pedestal := preload("res://ramon/LabChambers/kit/kit_pedestal.gd")
const Glyphs := preload("res://ramon/LabChambers/kit/kit_glyphs.gd")
const Presentation := preload("res://ramon/LabChambers/kit/kit_presentation.gd")

const SLICES := 9

@export_tool_button("Rebuild") var _rebuild_action: Callable = rebuild
@export var exhibit_script: Script:
	set(v):
		exhibit_script = v
		if not _swapping:
			_later()
@export_range(1.0, 8.0, 0.05) var radius: float = 3.0:
	set(v):
		radius = v
		_rebuild_pedestal()
@export_range(0.2, 2.0, 0.05) var height: float = 0.9:
	set(v):
		height = v
		_later()
## The slice frames behind the exhibit: the first one's centre (relative to the plinth), the step
## to the next, and each frame's size.
@export var frames_at: Vector3 = Vector3(-0.4, 2.7, -3.4):
	set(v):
		frames_at = v
		_later()
@export var frames_step: Vector3 = Vector3(0.22, 0.0, -0.34):
	set(v):
		frames_step = v
		_later()
@export var frame_size: Vector2 = Vector2(3.0, 3.6):
	set(v):
		frame_size = v
		_later()
## The WATCH button, floating, relative to the plinth.
@export var watch_at: Vector3 = Vector3(-2.6, 1.3, 3.8):
	set(v):
		watch_at = v
		_later()
## Where the cinematic's camera may stand (world x, z).
@export var bounds: Rect2 = Rect2(-10, -18, 20, 18)
## The floating WATCH button (for a camera cinematic; off while the exhibit simply loops).
## The row of slice frames standing behind the exhibit (Ramon, 4 Oct: "remove the slices behind
## him, they distract"). Off; the W-slice wall panel still shows the slice.
@export var slice_frames: bool = false:
	set(v):
		slice_frames = v
		_later()
@export var watch_button: bool = false:
	set(v):
		watch_button = v
		_later()
## Plays the exhibit's own sequence in place, over and over (Ramon, 4 Oct: "just the actual
## animation playing over and over again"); the camera is never taken. Touching it (the wheel, a
## right drag, its key) pauses the loop until you have let it be for `resume_after` seconds.
@export var autoplay: bool = true
@export_range(1.0, 60.0, 0.5) var resume_after: float = 8.0

var exhibit: Node4D
var slice_index: int = 4
var turn: Vector2 = Vector2.ZERO
var cinematic: bool = false
var watched: bool = false
var _slice_node: Node4D
## The pedestal's parts (kit_pedestal.gd), and whether its side text is printed yet.
var _ped: Dictionary = {}
var _band_done: bool = false
var _frames: Array = []
var _button: MeshInstance4D
var _button_frame: MeshInstance4D
var _prints: Array = []
var _near: bool = false
var _slice_w: float = 0.0
var _extent: float = -1.0
var _cine_slice: float = -3.0
var _t: float = 0.0
var _loop_t: float = 0.0
var _looping: bool = false
var _touched_at: float = -1000.0
var _queued: bool = false
## Counts the exhibits put on the plinth: the research panel, the slice view and the data panel
## drop what they read from the old one when it changes.
var serial: int = 0
var _swapping: bool = false
var _wait_grow: bool = false
## The part of the exhibit's loop playing now (-1 when it is in your hands or arriving), how far
## into it, and how long it is: the research wall turns its pages by these.
var seq_index: int = -1
var seq_t: float = 0.0
var seq_len: float = 0.0


func _enter_tree() -> void:
	add_to_group("lab_mood_listener")
	add_to_group("kit_showcase")


func _ready() -> void:
	rebuild()


func _later() -> void:
	if not is_inside_tree() or _queued:
		return
	_queued = true
	(func() -> void:
		_queued = false
		rebuild()).call_deferred()


## A new radius: the pedestal alone is rebuilt (the exhibit on it stays, it is costly to make).
func _rebuild_pedestal() -> void:
	if _ped.is_empty() or not is_inside_tree():
		_later()
		return
	for c in get_children():
		if String(c.name).begins_with("Pedestal"):
			c.free()
	_ped = Pedestal.build(self, radius, height)
	_band_done = false
	_apply_mood_now()


func rebuild() -> void:
	Build.clear(self)
	_frames = []
	_prints = []
	_ped = Pedestal.build(self, radius, height)
	_band_done = false
	var deck_h: float = float(_ped["deck_h"])
	_slice_node = Node4D.new()
	_slice_node.name = "Slice"
	_slice_node.position = Vector4(0, deck_h, 0, 0)
	_slice_node.set_meta(Build.GENERATED, true)
	add_child(_slice_node)
	exhibit = null
	if exhibit_script != null:
		exhibit = Node4D.new()
		exhibit.name = "Exhibit"
		exhibit.set_script(exhibit_script)
		_slice_node.add_child(exhibit)
	for i in (SLICES if slice_frames else 0):
		var fb := Batch.new()
		var c: Vector3 = frames_at + frames_step * float(i)
		var at := Vector4(c.x, c.y, c.z, 0.0)
		var w: float = Build.W_DEPTH * 0.25
		var bar: float = 0.03
		fb.box("f", Vector4(frame_size.x, bar, bar, w), at + Vector4(0, frame_size.y * 0.5, 0, 0))
		fb.box("f", Vector4(frame_size.x, bar, bar, w), at - Vector4(0, frame_size.y * 0.5, 0, 0))
		fb.box("f", Vector4(bar, frame_size.y, bar, w), at + Vector4(frame_size.x * 0.5, 0, 0, 0))
		fb.box("f", Vector4(bar, frame_size.y, bar, w), at - Vector4(frame_size.x * 0.5, 0, 0, 0))
		var fm: MeshInstance4D = fb.instance("f")
		fm.name = "Frame%d" % i
		fm.set_meta(Build.GENERATED, true)
		add_child(fm)
		_frames.append(fm)
	if not watch_button:
		_apply_mood_now()
		return
	_button = Build.box(self, "WatchButton", watch_at, Vector3(1.5, 0.62, 0.08), "kit_screen", false)
	var bb := Batch.new()
	var bw: float = 0.03
	var bc := Vector4(watch_at.x, watch_at.y, watch_at.z + 0.045, 0.0)
	bb.box("f", Vector4(1.62, bw, bw, 0.5), bc + Vector4(0, 0.37, 0, 0))
	bb.box("f", Vector4(1.62, bw, bw, 0.5), bc - Vector4(0, 0.37, 0, 0))
	bb.box("f", Vector4(bw, 0.74, bw, 0.5), bc + Vector4(0.81, 0, 0, 0))
	bb.box("f", Vector4(bw, 0.74, bw, 0.5), bc - Vector4(0.81, 0, 0, 0))
	_button_frame = bb.instance("f")
	_button_frame.set_meta(Build.GENERATED, true)
	add_child(_button_frame)
	_apply_mood_now()
	var tree: SceneTree = get_tree()
	if tree != null:
		_prints.append(await RD.print_box(tree, _button, Vector4(0, 0, 1, 0), Vector2(1.5, 0.62), _paint_button, {"bright": 0.85, "dark": 0.95}))
		_apply_mood_now()


func _paint_button(c: Control, ink: Dictionary) -> void:
	var s: float = c.size.y
	RD.icon(c, "play", Rect2(Vector2(s * 0.18, s * 0.15), Vector2(s * 0.7, s * 0.7)), ink["on_accent"])
	c.draw_string(LabPrint.font("black"), Vector2(s * 1.0, s * 0.62), "WATCH AGAIN" if watched else "WATCH", HORIZONTAL_ALIGNMENT_LEFT, -1, int(s * 0.36), ink["on_accent"])
	c.draw_string(LabPrint.font("bold"), Vector2(s * 1.0, s * 0.86), "CLICK", HORIZONTAL_ALIGNMENT_LEFT, -1, int(s * 0.17), Color(ink["on_accent"], 0.75))


func apply_mood(_m: String, _instant: bool = false) -> void:
	_apply_mood_now()


func _apply_mood_now() -> void:
	for rec in _prints:
		RD.apply(rec, Style.mood)
	if not _ped.is_empty():
		Pedestal.apply_mood(_ped)
	_show_slice()
	_show_button()


func _show_slice() -> void:
	for i in _frames.size():
		(_frames[i] as MeshInstance4D).material_override = Mats.glow(Style.pick(Style.FRAME_LIT) if i == slice_index else Style.pick(Style.FRAME_DIM), 1.0)


func _show_button() -> void:
	if is_instance_valid(_button_frame):
		_button_frame.material_override = Mats.glow(Style.pick(Style.FRAME_LIT) if _near else Style.pick(Style.FRAME_DIM), 1.0)


# -- in play ---------------------------------------------------------------------------------------

## Another animal on the plinth (Ramon, 4 Oct: "goat ends, disappears when you click the button.
## chicken grows from small to big on the pedestal and keeps rotating"): the old exhibit goes at
## once, the new one arrives at its real size and grows while the plinth turns, and its loop starts
## a few seconds after it has grown. The same script again does nothing.
func set_exhibit(script: Script) -> void:
	if script == null or script == exhibit_script or _slice_node == null:
		return
	_swapping = true
	exhibit_script = script
	_swapping = false
	if exhibit != null:
		_slice_node.remove_child(exhibit)
		exhibit.queue_free()
	serial += 1
	exhibit = Node4D.new()
	exhibit.name = "Exhibit%d" % serial
	exhibit.set_script(script)
	exhibit.set("grow_in", true)
	_slice_node.add_child(exhibit)
	_looping = false
	cinematic = false
	_cine_slice = -3.0
	turn = Vector2.ZERO
	slice_index = SLICES / 2
	_extent = -1.0
	_wait_grow = true
	seq_index = -1
	_band_done = false
	_show_slice()


func near_button(p: Vector4) -> bool:
	if not watch_button:
		return false
	var b: Vector4 = global_position + Vector4(watch_at.x, 0, watch_at.z, 0)
	return Vector2(p.x - b.x, p.z - b.z).length() < 4.0


func set_near(on: bool) -> void:
	if on != _near:
		_near = on
		_show_button()


func step_slice(d: int) -> void:
	_touch()
	slice_index = clampi(slice_index + d, 0, SLICES - 1)
	_show_slice()


func turn_by(dx: float, dy: float) -> void:
	_touch()
	turn += Vector2(dx, dy)


func action() -> String:
	_touch()
	return String(exhibit.call("action")) if exhibit != null and exhibit.has_method("action") else ""


## Someone is handling it: the loop stops and the exhibit is theirs.
func _touch() -> void:
	_touched_at = _t
	seq_index = -1
	if _looping:
		_looping = false
		cinematic = false
		_cine_slice = -3.0
		slice_index = SLICES / 2
		if exhibit != null:
			exhibit.call("end_cinematic")
		_show_slice()


## The loop: the exhibit's sequences one after another, round and round.
func _run_loop(delta: float) -> void:
	var seqs: Array = sequences()
	if seqs.is_empty():
		return
	if not _looping:
		_looping = true
		_loop_t = 0.0
		cinematic = true
		turn = Vector2.ZERO
	_loop_t += delta
	var total: float = 0.0
	for s in seqs:
		total += float(s["length"])
	var t: float = fposmod(_loop_t, total)
	var i: int = 0
	while i < seqs.size() - 1 and t >= float(seqs[i]["length"]):
		t -= float(seqs[i]["length"])
		i += 1
	seq_index = i
	seq_t = t
	seq_len = float(seqs[i]["length"])
	play(i, t)


func action_label() -> String:
	return String(exhibit.call("action_label")) if exhibit != null and exhibit.has_method("action_label") else ""


func data() -> Dictionary:
	return exhibit.call("data") if exhibit != null and exhibit.has_method("data") else {}


## The pedestal's side text, wrapped round its front: the specimen's tag and its
## measured numbers, in the decal sheet's manner (Ramon's my-own-01 decals: brackets, crosshairs,
## hazard stripes, a serial), in Montserrat.
func _paint_band(c: Control) -> void:
	var h: float = c.size.y
	var w: float = c.size.x
	var ink := Color(0.88, 0.90, 0.94, 0.9)
	var dim := Color(0.88, 0.90, 0.94, 0.55)
	var st: Dictionary = data().get("stats", {})
	var fb: Font = LabPrint.font("black")
	var fs: Font = LabPrint.font("bold")
	var fl: Font = LabPrint.font("body")
	var x: float = h * 0.5
	# Hazard stripes at both ends.
	for side in [0.0, 1.0]:
		var x0: float = h * 0.15 if side == 0.0 else w - h * 1.15
		for k in 4:
			var sx: float = x0 + float(k) * h * 0.26
			c.draw_colored_polygon(PackedVector2Array([Vector2(sx, h * 0.85), Vector2(sx + h * 0.13, h * 0.85), Vector2(sx + h * 0.33, h * 0.15), Vector2(sx + h * 0.2, h * 0.15)]), dim)
	x = h * 1.35
	Glyphs.icon(c, "live", Rect2(Vector2(x, h * 0.25), Vector2(h * 0.5, h * 0.5)), ink)
	x += h * 0.7
	var code: String = String(data().get("code", "XX-01"))
	var tag: String = "SPECIMEN " + code.get_slice("-", 1)
	c.draw_string(fb, Vector2(x, h * 0.66), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, int(h * 0.42), ink)
	x += fb.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, int(h * 0.42)).x + h * 0.4
	c.draw_line(Vector2(x, h * 0.2), Vector2(x, h * 0.8), dim, maxf(1.0, h * 0.03))
	x += h * 0.4
	var line: String = "THE %s  ·  LOFTED FROM %d BALLS  ·  %s TETRAHEDRA  ·  W REACH %.2f M" % [String(data().get("name", "specimen")).to_upper(), int(st.get("balls", 0)), Glyphs.short(int(st.get("tetra", 0))), float(st.get("reach", 0.0))]
	c.draw_string(fs, Vector2(x, h * 0.64), line, HORIZONTAL_ALIGNMENT_LEFT, w - x - h * 1.6, int(h * 0.3), ink)
	var serial_tag: String = "QH-LAB " + code
	c.draw_string(fl, Vector2(w - h * 1.3 - fl.get_string_size(serial_tag, HORIZONTAL_ALIGNMENT_LEFT, -1, int(h * 0.2)).x, h * 0.98), serial_tag, HORIZONTAL_ALIGNMENT_LEFT, -1, int(h * 0.2), dim)
	# Corner brackets round the whole band.
	var t: float = maxf(1.0, h * 0.04)
	var arm: float = h * 0.3
	for cx in [h * 1.2, w - h * 1.3]:
		var dir: float = 1.0 if cx < w * 0.5 else -1.0
		c.draw_line(Vector2(cx, h * 0.08), Vector2(cx + arm * dir, h * 0.08), ink, t)
		c.draw_line(Vector2(cx, h * 0.08), Vector2(cx, h * 0.08 + arm), ink, t)
		c.draw_line(Vector2(cx, h * 0.92), Vector2(cx + arm * dir, h * 0.92), ink, t)
		c.draw_line(Vector2(cx, h * 0.92), Vector2(cx, h * 0.92 - arm), ink, t)


## The exhibit's W profile ({"bins", "reach"}), for the research console; empty if it has none.
func profile() -> Dictionary:
	return exhibit.call("w_profile") if exhibit != null and exhibit.has_method("w_profile") else {}


## The slice in the exhibit's own space ([n, d]: a point p is at world W = n.dot(p) + d), for the
## slice view; empty if the exhibit cannot say.
func slice_plane() -> Array:
	return exhibit.call("slice_in_rig") if exhibit != null and exhibit.has_method("slice_in_rig") else []


## The exhibit as a wireframe in 4D (pairs of points), for the slice view; empty if it has none.
func wire() -> PackedVector4Array:
	return exhibit.call("wire") if exhibit != null and exhibit.has_method("wire") else PackedVector4Array()


## The exhibit as a cloud of its 4D points, for the slice view; empty if it has none.
func cloud() -> PackedVector4Array:
	return exhibit.call("cloud") if exhibit != null and exhibit.has_method("cloud") else PackedVector4Array()


## The exhibit drawn flat ({"points", "balls", "bones"}), for the research panel; empty if none.
func shape() -> Dictionary:
	return exhibit.call("shape") if exhibit != null and exhibit.has_method("shape") else {}


## Where the slice you see cuts the exhibit, from -1 (its -W end) to 1 (its +W end): the slice
## node moves the exhibit through W, so what is at your W is the exhibit's own -offset.
func slice_fraction() -> float:
	var ext: float = _extent if _extent > 0.0 else 1.0
	return clampf(-_slice_w / ext, -1.0, 1.0)


## The nine slice stops as fractions (as slice_fraction() reads them), first to last.
func slice_stops() -> Array:
	var out: Array = []
	for i in SLICES:
		out.append(-(float(i) - float(SLICES - 1) * 0.5) / (float(SLICES - 1) * 0.5) * 0.6)
	return out


## What is happening right now, for the data panel: [label, value] rows.
func live() -> Array:
	var rows: Array = [
		["W-slice", "%d / %d" % [slice_index + 1, SLICES]],
		["Offset through W", "%+.2f m" % _slice_w],
		["Turned through W", "swung %.0f°, tilted %.0f°" % [rad_to_deg(turn.x), rad_to_deg(turn.y)]],
		["Playing", "its sequence" if _looping else "in your hands"],
	]
	if exhibit != null and exhibit.has_method("live"):
		rows.append_array(exhibit.call("live"))
	return rows


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or exhibit == null:
		return
	_t += delta
	if not _band_done and _t > 0.5 and not data().is_empty():
		_band_done = true
		Pedestal.print_band(get_tree(), _ped, 2.4, 0.27, 0.49, _paint_band)
	# A new exhibit turns and grows; its loop starts three seconds after it has grown.
	if _wait_grow and (not exhibit.has_method("grown") or bool(exhibit.call("grown"))):
		_wait_grow = false
		_extent = -1.0
		_touched_at = _t - resume_after + 3.0
	if autoplay and not _wait_grow and _t - _touched_at > resume_after and _t > 2.0:
		_run_loop(delta)
	elif not cinematic and exhibit.has_method("idle"):
		exhibit.call("idle", delta)
	if _extent < 0.0 and exhibit.has_method("w_extent") and _t > 1.0 and not _wait_grow:
		_extent = float(exhibit.call("w_extent"))
	var ext: float = maxf(_extent, 0.3)
	var want_w: float = (float(slice_index) - float(SLICES - 1) * 0.5) / (float(SLICES - 1) * 0.5) * ext * 0.6
	if cinematic and _cine_slice > -2.0:
		want_w = _cine_slice * ext
	_slice_w = lerpf(_slice_w, want_w, 1.0 - exp(-8.0 * delta))
	_slice_node.position.w = _slice_w
	# Turned in the goat's own frame (its stand's turn undone, the turn, the stand's turn done
	# again): across swings the slice along its length (z into W), up and down tilts it through
	# its height (y into W) (Ramon, 4 Oct: "why doesn't the slicing work up and down also?").
	var yaw_b: Projection = exhibit.call("stand_basis") if exhibit.has_method("stand_basis") else Projection.IDENTITY
	_slice_node.basis = yaw_b * (Basis4D.from_zw(turn.x) * Basis4D.from_wy(turn.y)) * yaw_b.inverse()
	if is_instance_valid(_button):
		_button.visible = not cinematic
		_button_frame.visible = not cinematic
		_button.position.y = watch_at.y + sin(_t * 1.6) * 0.04
		_button_frame.position.y = sin(_t * 1.6) * 0.04


## The presentation's parts, the same for every exhibit (kit_presentation.gd).
func sequences() -> Array:
	return Presentation.chapters() if exhibit != null else []


## Left click while it plays: on to the start of the next part, the loop going on from there.
func skip() -> void:
	if not _looping or seq_index < 0:
		return
	var seqs: Array = sequences()
	var total: float = 0.0
	for s in seqs:
		total += float(s["length"])
	var start: float = 0.0
	for k in seq_index + 1:
		start += float(seqs[k]["length"])
	_loop_t = floor(_loop_t / total) * total + start + 0.001


func shot(i: int) -> Array:
	var s: Dictionary = sequences()[i]
	var c: Vector4 = global_position + Vector4(0, height, 0, 0)
	var eye: Vector4 = c + (s["eye"] as Vector4)
	eye.x = clampf(eye.x, bounds.position.x + 0.7, bounds.end.x - 0.7)
	eye.z = clampf(eye.z, bounds.position.y + 0.7, bounds.end.y - 0.7)
	return [eye, c + (s["look"] as Vector4), float(s.get("fov", 0.9))]


func begin_cinematic() -> void:
	cinematic = true
	turn = Vector2.ZERO
	slice_index = SLICES / 2
	_show_slice()


func play(i: int, t: float) -> void:
	var s: Dictionary = sequences()[i]
	var r: Dictionary = exhibit.call("play_part", String(s["key"]), t, float(s["length"])) if exhibit.has_method("play_part") else {}
	_cine_slice = float(r.get("slice", -3.0))
	if _cine_slice <= -2.0 and slice_index != SLICES / 2:
		slice_index = SLICES / 2
		_show_slice()
	if _cine_slice > -2.0:
		var idx: int = clampi(int(round((_cine_slice / 0.6 + 1.0) * 0.5 * float(SLICES - 1))), 0, SLICES - 1)
		if idx != slice_index:
			slice_index = idx
			_show_slice()


func end_cinematic() -> void:
	cinematic = false
	_cine_slice = -3.0
	slice_index = SLICES / 2
	exhibit.call("end_cinematic")
	_show_slice()
	if not watched:
		watched = true
		var tree: SceneTree = get_tree()
		if tree != null and _button != null:
			_prints = []
			_prints.append(await RD.print_box(tree, _button, Vector4(0, 0, 1, 0), Vector2(1.5, 0.62), _paint_button, {"bright": 0.85, "dark": 0.95}))
			_apply_mood_now()


## Whether a new exhibit is still growing in.
func arriving() -> bool:
	return _wait_grow


## The exhibit's measured numbers (kit_bench.gd keys); empty if it measures nothing.
func bench() -> Dictionary:
	return exhibit.call("bench") if exhibit != null and exhibit.has_method("bench") else {}
