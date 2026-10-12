@tool
extends Node4D

## The Voxel Lab's bench: a pad painted on the floor in front of a specimen's pedestal. Stand on it and
## press E (or click) and you sit down to cut: the camera leaves your shoulder and circles the
## specimen, the mouse shows, and the room's keys are the bench's until you stand up (F or Esc).
##
## AT THE BENCH
##   the mouse    its ray finds the surface in our own copy of the specimen (vl_recipe.gd raycast:
##                the engine keeps its voxels to itself); the tool's outline is drawn there, with what
##                lies under it and at which W
##   click        cuts (the saw: press, drag and let go for a channel)
##   1 to 4, Q/E  the tool and its size (vl_cutter.gd)
##   wheel        slides the specimen through W (the showcase's slice), right drag turns it in 4D
##   WASD         circles round it, Shift and the wheel come closer or go back
##   R            whole again (a spare swapped in, at once)
##   T            where a new chunk's draw buffers are built: a worker thread (the lab's swap) or the
##                frame itself (the engine's way), to feel and read the difference
##   C            the chunk outlines that flash on what a cut made the engine mesh again
##   V            the volume view (the room's): the whole 4D specimen, faintly
## Each cut throws chips in the colours it went through and makes a short crunch (room/vl_sound.gd).
##
## AT A BUILDER (round 4, Build it: an exhibit with build_cut()) the bench hands it the aiming, the
## outline and the edit, since it knows its grid: 1 to 3 brick, through W, take away; Q/E the colour;
## Z takes the last one back; Space levels the slice again; R starts again from the doorway.
## Round 5 (Ramon, 9 Oct, #40: "use left mouse drag to orbit the camera around the voxel construction
## ... make the orbit direction intuitive rather than inverted ... rotate freely without feeling
## locked"): at a builder a LEFT drag orbits and a left click with no drag places, both directions turn
## as if you held the build and turned it (the middle drag's up and down was the other way round from
## its left and right), the camera goes from nearly straight down to a little under the top of the
## grid, and it is kept inside `camera_bounds` (the room's walls, in the corner) by coming closer.
##
## AT A STEPPER (Overlapping geometry: an exhibit with add_next()) sitting down empties it, 1 puts the next
## piece back, and once the last is in the bench stands you up by itself (RELEASE_AFTER later); standing up
## before then puts the rest back. A left drag orbits, as at a builder; there is nothing to aim at.
##
## Faces its own +Z: the pad lies in front of the station, and you sit looking from it to the specimen.
##
## NO class_name (engine_gotchas.md).

signal docked_changed(on: bool)

const Build := preload("res://ramon/VoxelLab/carried/scripts/chamber_build.gd")
const RD := preload("res://ramon/VoxelLab/carried/scripts/rd_build.gd")
const LabPrint := preload("res://ramon/VoxelLab/carried/LabKit/lab_print.gd")
const Style := preload("res://ramon/VoxelLab/carried/kit/kit_style.gd")
const Recipe := preload("res://ramon/VoxelLab/specimen/vl_recipe.gd")
## The menu's sounds in the labs: the Frontier Map's cues (Ramon, 11 Oct).
const LabSounds := preload("res://ramon/Menu/scripts/menu_lab_sounds.gd")
const Cutter := preload("res://ramon/VoxelLab/specimen/vl_cutter.gd")
const Overlay := preload("res://ramon/VoxelLab/room/vl_bench_overlay.gd")
const Chips := preload("res://ramon/VoxelLab/room/vl_chips_4d.gd")
const Sound := preload("res://ramon/VoxelLab/room/vl_sound.gd")
const TetRay := preload("res://ramon/VoxelLab/specimen/vl_tet_ray.gd")

@export_tool_button("Rebuild") var _rebuild_action: Callable = rebuild
## The showcase (carried/kit/kit_showcase_4d.gd) whose specimen this bench cuts.
@export var station: NodePath
@export var title: String = "THE BENCH":
	set(v):
		title = v
		_later()
@export var subtitle: String = "CUT IT YOURSELF":
	set(v):
		subtitle = v
		_later()
## The pad on the floor (m): across, and toward you.
## Paint a pad on the floor. Off in the lab since 9 Oct (Ramon: "this whole bracket of the bench, cut
## yourself, I don't really like it"): you sit from the choice at the exhibit's ring instead.
@export var pad: bool = true:
	set(v):
		pad = v
		_later()
@export var pad_size: Vector2 = Vector2(3.0, 1.3):
	set(v):
		pad_size = v
		_later()
## How near the pad's middle counts as standing on it (m, on the floor).
@export var reach: float = 1.5
## The camera at the bench: how far from the specimen, how far down it looks (degrees), and how high
## above the floor the point it circles is.
@export_range(1.5, 12.0, 0.1) var camera_distance: float = 4.6
@export_range(-60.0, 20.0, 0.5) var camera_pitch: float = -16.0
@export_range(0.0, 6.0, 0.05) var look_height: float = 1.8
## Which tools this bench offers (vl_cutter.gd TOOLS).
@export var tools: PackedStringArray = PackedStringArray(["ball", "block", "drill", "saw"])
## Where the camera may be, on the floor (x, z, world): it comes closer rather than leave it. Empty: anywhere.
@export var camera_bounds: Rect2 = Rect2()

var docked: bool = false
var room: Node
var tool: String = "ball"
var size_index: int = 1
var hover: Dictionary = {}
var records: Array = []

var _plate: MeshInstance4D
var _rec: Dictionary = {}
var _queued: bool = false
var _cam: Camera4D
var _layer: CanvasLayer
var _overlay: Control
var _yaw: float = 0.0
var _pitch: float = 0.0
var _mdrag: bool = false
## A builder's left button: down, and how far it has moved since (pixels); past DRAG_PX it orbits.
var _ldown: bool = false
var _lmoved: float = 0.0
const DRAG_PX := 5.0
var _dist: float = 4.6
var _drag_from: Dictionary = {}
var _rdrag: bool = false
var _audio: AudioStreamPlayer
var _sounds: Array = []
var _spec_seen: Node
var _autoplay_was: bool = true
## A screen point (window pixels) to aim at instead of the mouse: the runners set it, so a test never
## moves the real cursor (it is the user's).
var aim_override: Vector2 = Vector2.INF
## Seconds a stepper's last piece stays on show before the bench stands you up.
const RELEASE_AFTER := 1.5
## Counts sittings, so a release timed for one never stands up the next.
var _sitting: int = 0


func _enter_tree() -> void:
	add_to_group("vl_bench")
	add_to_group("lab_mood_listener")


func _ready() -> void:
	rebuild()


func _later() -> void:
	if not is_inside_tree() or _queued:
		return
	_queued = true
	(func() -> void:
		_queued = false
		rebuild()).call_deferred()


# -- the pad -------------------------------------------------------------------------------------------

func rebuild() -> void:
	Build.clear(self)
	_rec = {}
	if not pad:
		return
	_plate = Build.box(self, "Pad", Vector3(0, 0.006, 0), Vector3(pad_size.x, 0.012, pad_size.y), "kit_floor", false)
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	_rec = await RD.print_box(tree, _plate, Vector4(0, 1, 0, 0), pad_size, _paint, {"bright": 0.25, "dark": 0.4}, 220.0)
	apply_mood(Style.mood)


func apply_mood(m: String, _instant: bool = false) -> void:
	if not _rec.is_empty():
		RD.apply(_rec, m if m in ["bright", "dark"] else "bright")


## The pad's paint, in the wall blue: a frame with corner brackets, the bench's name and what it does,
## and the key. It reads from the pad's +Z side (you walk up to it from there).
func _paint(c: Control, _ink: Dictionary) -> void:
	var w: float = c.size.x
	var h: float = c.size.y
	var blue: Color = Style.pick(Style.CODE_BLUE)
	var lw: float = maxf(2.0, h * 0.035)
	c.draw_rect(Rect2(Vector2(lw, lw), Vector2(w - lw * 2.0, h - lw * 2.0)), blue, false, lw)
	var arm: float = h * 0.22
	for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		var p := Vector2(lw * 3.0 + corner.x * (w - lw * 6.0), lw * 3.0 + corner.y * (h - lw * 6.0))
		var dx: float = arm * (1.0 if corner.x == 0.0 else -1.0)
		var dy: float = arm * (1.0 if corner.y == 0.0 else -1.0)
		c.draw_line(p, p + Vector2(dx, 0), blue, lw * 1.6)
		c.draw_line(p, p + Vector2(0, dy), blue, lw * 1.6)
	var fb: Font = LabPrint.font("black")
	var fs: Font = LabPrint.font("bold")
	var cap := Rect2(Vector2(h * 0.22, h * 0.3), Vector2(h * 0.4, h * 0.4))
	c.draw_rect(cap, blue, false, lw)
	c.draw_string(fb, Vector2(cap.position.x, cap.position.y + h * 0.31), "E", HORIZONTAL_ALIGNMENT_CENTER, cap.size.x, int(h * 0.28), blue)
	var x: float = cap.end.x + h * 0.2
	c.draw_string(fb, Vector2(x, h * 0.5), title, HORIZONTAL_ALIGNMENT_LEFT, w - x - h * 0.2, int(h * 0.26), blue)
	c.draw_string(fs, Vector2(x, h * 0.76), subtitle, HORIZONTAL_ALIGNMENT_LEFT, w - x - h * 0.2, int(h * 0.15), blue)


## Whether `p` (world) stands on the pad.
func near(p: Vector4) -> bool:
	return Vector2(p.x - global_position.x, p.z - global_position.z).length() < reach


# -- what it holds -------------------------------------------------------------------------------------

func showcase() -> Node:
	return get_node_or_null(station)


func exhibit() -> Node:
	var s: Node = showcase()
	return s.get("exhibit") if s != null else null


func specimen() -> Node:
	var e: Node = exhibit()
	return e.get("specimen") if e != null else null


## The exhibit when it builds rather than being cut (Build it), else null.
func builder() -> Node:
	var e: Node = exhibit()
	return e if e != null and e.has_method("build_cut") else null


## The exhibit when it is put together a piece at a time (Overlapping geometry), else null.
func stepper() -> Node:
	var e: Node = exhibit()
	return e if e != null and e.has_method("add_next") else null


## A builder or a stepper: a left drag orbits.
func _orbits() -> bool:
	return builder() != null or stepper() != null


## The point the camera circles: the specimen's middle as it stands, in your slice (W 0).
func _centre() -> Vector4:
	var sp: Node4D = specimen() as Node4D
	var c: Vector4 = sp.global_position if sp != null else global_position + Vector4(0, look_height, -3.0, 0)
	return Vector4(c.x, maxf(c.y, look_height * 0.6), c.z, 0.0)


# -- sitting down and standing up ------------------------------------------------------------------------

## Sits `r` (the room) down at this bench.
func dock(r: Node) -> void:
	if docked or specimen() == null:
		return
	_sound("swipe")
	room = r
	docked = true
	var sc: Node = showcase()
	# Sitting down ends the pedestal's story: it went on playing behind the bench, its own cuts and its
	# reset landing among yours (6 Oct). A story that cut the specimen hands it back whole first.
	if bool(sc.get("armed")) or int(sc.get("seq_index")) >= 0:
		sc.call("_finish")
	_autoplay_was = bool(sc.get("autoplay"))
	sc.set("autoplay", false)
	sc.call("step_slice", 0)
	var ex: Node = exhibit()
	ex.set("held", true)
	var player_cam: Camera4D = r.call("camera") as Camera4D if r != null and r.has_method("camera") else null
	_cam = Camera4D.new()
	_cam.name = "BenchCamera"
	_cam.rendering_engine_name = player_cam.rendering_engine_name if player_cam != null else "Cross-section"
	if player_cam != null:
		_cam.set("field_of_view_4d", player_cam.get("field_of_view_4d"))
		_cam.set("projection_opacity_base", player_cam.get("projection_opacity_base"))
	add_child(_cam)
	var c: Vector4 = _centre()
	var from: Vector4 = global_position - c
	_yaw = atan2(from.x, from.z)
	_pitch = deg_to_rad(camera_pitch)
	_dist = camera_distance
	_place_camera(1.0)
	_cam.make_current()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_layer = CanvasLayer.new()
	_layer.name = "BenchLayer"
	_layer.layer = 4
	add_child(_layer)
	_overlay = Control.new()
	_overlay.set_script(Overlay)
	_overlay.set("camera", _cam)
	_layer.add_child(_overlay)
	if _audio == null:
		_audio = AudioStreamPlayer.new()
		_audio.volume_db = -6.0
		add_child(_audio)
		for i in 4:
			_sounds.append(Sound.crunch(float(i) / 3.0, 0.2 + 0.03 * float(i)))
	if not tool in tools:
		tool = tools[0]
	if builder() != null:
		size_index = clampi(size_index, 0, _sizes() - 1)
	_sitting += 1
	if stepper() != null:
		stepper().call("begin")
	_sync_overlay()
	docked_changed.emit(true)


func undock() -> void:
	if not docked:
		return
	_sound("swipe")
	docked = false
	_drag_from = {}
	_ldown = false
	var sc: Node = showcase()
	if sc != null:
		sc.set("autoplay", _autoplay_was)
	var ex: Node = exhibit()
	if ex != null:
		ex.set("held", false)
	if stepper() != null:
		stepper().call("end")
	if is_instance_valid(_layer):
		_layer.queue_free()
	_layer = null
	_overlay = null
	if is_instance_valid(_cam):
		_cam.queue_free()
	_cam = null
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	docked_changed.emit(false)


func camera() -> Camera4D:
	return _cam


# -- each frame ------------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not docked:
		return
	var sp: Node = specimen()
	if sp != _spec_seen:
		_spec_seen = sp
		if sp != null and not sp.is_connected("cut_done", _on_cut):
			sp.connect("cut_done", _on_cut)
	var ex: Node = exhibit()
	if ex != null and ex.has_method("face_front"):
		ex.call("face_front", 1.0 - exp(-4.0 * delta))
	# Whatever else happens (a story's camera, a room's view switch), the bench's camera is the one in use
	# while you sit: once another took over and the view froze while the cuts went on (Ramon, 8 Oct).
	if is_instance_valid(_cam) and not _cam.current:
		_cam.make_current()
	# WASD circles the specimen; so does a middle drag (_input).
	var turn: float = (1.0 if Input.is_key_pressed(KEY_D) else 0.0) - (1.0 if Input.is_key_pressed(KEY_A) else 0.0)
	var lift: float = (1.0 if Input.is_key_pressed(KEY_W) else 0.0) - (1.0 if Input.is_key_pressed(KEY_S) else 0.0)
	_yaw += turn * delta * 1.1
	_pitch = _clamp_pitch(_pitch - lift * delta * 0.8)
	_place_camera(1.0 - exp(-10.0 * delta))
	_update_hover()
	_sync_overlay()


## Up and down: a builder's orbit reaches from nearly straight down to a little under level; a cutting
## bench keeps its old reach.
func _clamp_pitch(p: float) -> float:
	if _orbits():
		return clampf(p, deg_to_rad(-85.0), deg_to_rad(8.0))
	return clampf(p, deg_to_rad(-70.0), deg_to_rad(15.0))


func _place_camera(_k: float) -> void:
	if _cam == null:
		return
	var c: Vector4 = _centre()
	var dir := Vector4(sin(_yaw) * cos(_pitch), -sin(_pitch), cos(_yaw) * cos(_pitch), 0.0)
	var dist: float = _dist
	# Inside the walls (and over the floor): closer, never through them.
	if camera_bounds.size != Vector2.ZERO:
		for axis in [0, 2]:
			var lo: float = camera_bounds.position.x if axis == 0 else camera_bounds.position.y
			var hi: float = camera_bounds.end.x if axis == 0 else camera_bounds.end.y
			if dir[axis] > 1e-4:
				dist = minf(dist, (hi - c[axis]) / dir[axis])
			elif dir[axis] < -1e-4:
				dist = minf(dist, (lo - c[axis]) / dir[axis])
		if dir.y < -1e-4:
			dist = minf(dist, (0.35 - c.y) / dir.y)
		dist = maxf(dist, 1.2)
	_cam.global_position = c + dir * dist
	_cam.global_basis = Basis4D.from_zx(_yaw) * Basis4D.from_yz(_pitch)


## The mouse in the window's pixels (what the camera's ray wants), from the viewport's canvas units.
func _mouse_px() -> Vector2:
	if aim_override != Vector2.INF:
		return aim_override
	var vp: Viewport = get_viewport()
	var m: Vector2 = vp.get_mouse_position()
	var vs := Vector2(vp.get_size())
	var vr: Vector2 = vp.get_visible_rect().size
	return m * (vs / vr) if vr.x > 0.0 else m


## Aims at a window pixel (the runners) and returns what is under it.
func aim_at_screen(px: Vector2) -> Dictionary:
	aim_override = px
	_update_hover()
	_sync_overlay()
	return hover


## Where the mouse's ray meets the specimen now.
func _update_hover() -> void:
	hover = {}
	var sp: Node = specimen()
	if sp == null or _cam == null or not bool(sp.call("is_ready")) or stepper() != null:
		return
	var px: Vector2 = _mouse_px()
	var o: Vector4 = _cam.viewport_to_world_ray_origin(px)
	var d: Vector4 = _cam.viewport_to_world_ray_direction(px)
	var ov: Vector4 = sp.call("to_voxel", o)
	var dv: Vector4 = (sp.call("dir_to_voxel", d) as Vector4).normalized()
	var r: Dictionary = sp.get("recipe")
	# A builder aims through its own grid. A recipe our copy can follow is aimed at through it (and the
	# cuts it knows); one built from noise (Andrew's landscape and caves) through the engine's own chunk
	# meshes.
	var b: Node = builder()
	var hit: Dictionary
	if b != null:
		hit = b.call("raycast", ov, dv)
	elif bool(r.get("mirror", true)):
		hit = Recipe.raycast(r, sp.get("cuts"), ov, dv, 400.0)
	else:
		hit = TetRay.raycast(sp, ov, dv, 400.0)
	if hit.is_empty():
		return
	hover = hit
	hover["ray"] = dv
	hover["world"] = sp.call("to_global", hit["point"])


func _sync_overlay() -> void:
	if _overlay == null:
		return
	var sp: Node = specimen()
	_overlay.set("tool", tool)
	_overlay.set("tools", tools)
	_overlay.set("size_index", size_index)
	_overlay.set("records", records)
	_overlay.set("swap", bool(sp.get("swap")) if sp != null else true)
	var b: Node = builder()
	_overlay.set("build", b.call("overlay_info", tool, size_index) if b != null else {})
	var stp: Node = stepper()
	_overlay.set("step", stp.call("overlay_info") if stp != null else {})
	if sp != null:
		var st: Dictionary = sp.get("stats")
		var n: int = int(sp.call("tets"))
		var r: Dictionary = sp.get("recipe")
		_overlay.set("totals", {"tets": Overlay._thousands(n), "mb": "%.0f MB" % (float(n) * 1.25 / 1024.0),
			"voxel": "%.0f cm, %d chunk meshes" % [float(r.get("voxel", 0.1)) * 100.0, int((sp.call("chunk_nodes") as Array).size())]})
	if hover.is_empty():
		_overlay.set("outline", [])
		_overlay.set("hit_world", Vector4.INF)
		return
	_overlay.set("hit_world", hover["world"])
	if b != null:
		_overlay.set("hit_text", b.call("hit_text", hover))
		_overlay.set("outline", b.call("outline", sp, hover, tool))
		return
	var r: Dictionary = sp.get("recipe")
	var v: float = float(r.get("voxel", 0.1))
	var w_m: float = ((hover["point"] as Vector4).w - (r["center"] as Vector4).w) * v
	_overlay.set("hit_text", "%s  ·  W %+.2f m" % [Overlay.MATERIAL_NAMES.get(int(hover.get("material", 0)), "?"), w_m])
	_overlay.set("outline", _outline())


## The tool's outline at the hover, as world polylines: [points, closed, accent].
func _outline() -> Array:
	var sp: Node = specimen()
	var r: Dictionary = sp.get("recipe")
	var v: float = float(r.get("voxel", 0.1))
	var scale: float = (sp as Node4D).global_basis.x.length()
	var p: Vector4 = hover["world"]
	var nv: Vector4 = hover.get("normal", Vector4(0, 0, 1, 0))
	var n: Vector4 = (sp.call("dir_to_global", nv) as Vector4)
	n.w = 0.0
	n = n.normalized() if n.length() > 0.0 else Vector4(0, 0, 1, 0)
	var a: Vector4 = Cutter.perp(n, Vector4(0, 0, 0, 1), Vector4.ZERO)
	var b: Vector4 = Cutter.perp(n, a, Vector4(0, 0, 0, 1))
	var s: float = float((Cutter.SIZES[tool] as Array)[size_index]) * v * scale
	var out: Array = []
	match tool:
		"ball":
			out.append([_ring(p - n * s * 0.02, a, b, s * 0.94), true, false])
		"block":
			# The notch's square, the specimen's own way up.
			var up: Vector4 = (sp.call("dir_to_global", Vector4(0, 1, 0, 0)) as Vector4)
			up.w = 0.0
			up = (up - n * up.dot(n)).normalized() if (up - n * up.dot(n)).length() > 0.1 else a
			var side: Vector4 = Cutter.perp(n, up, Vector4(0, 0, 0, 1))
			var sq := PackedVector4Array()
			for k in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				sq.append(p + (side * k.x + up * k.y) * s)
			out.append([sq, true, false])
		"drill":
			var dv: Vector4 = hover["ray"]
			var d: Vector4 = (sp.call("dir_to_global", dv) as Vector4)
			d.w = 0.0
			d = d.normalized()
			out.append([_ring(p, a, b, s), true, false])
			var depth: float = float(Cutter.DRILL_DEPTH[size_index]) * v * scale
			out.append([PackedVector4Array([p, p + d * depth]), false, true])
			out.append([_ring(p + d * depth, a, b, s), true, true])
		"saw":
			var kerf: float = Cutter.SAW_KERF_VOXELS * v * scale
			if not _drag_from.is_empty():
				var p0: Vector4 = _drag_from["world"]
				var along: Vector4 = p - p0
				var k: Vector4 = Cutter.perp(along, n, Vector4(0, 0, 0, 1)) * kerf * 0.5
				out.append([PackedVector4Array([p0 - k, p - k, p + k, p0 + k]), true, false])
				out.append([PackedVector4Array([p0, p0 - n * s]), false, true])
			else:
				out.append([PackedVector4Array([p - a * s * 0.5, p + a * s * 0.5]), false, false])
	return out


static func _ring(c: Vector4, a: Vector4, b: Vector4, r: float, n: int = 40) -> PackedVector4Array:
	var out := PackedVector4Array()
	for i in n:
		var t: float = TAU * float(i) / float(n)
		out.append(c + (a * cos(t) + b * sin(t)) * r)
	return out


# -- the keys and the mouse --------------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not docked:
		return
	var mb := event as InputEventMouseButton
	var mm := event as InputEventMouseMotion
	var k := event as InputEventKey
	var sc: Node = showcase()
	if mb != null:
		if mb.button_index == MOUSE_BUTTON_LEFT and _orbits():
			# A builder: a click places on release, a drag orbits (a stepper only orbits).
			if mb.pressed:
				_ldown = true
				_lmoved = 0.0
			elif _ldown:
				_ldown = false
				if _lmoved < DRAG_PX and builder() != null:
					cut_here()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				if tool == "saw":
					if not hover.is_empty():
						_drag_from = hover.duplicate()
				else:
					cut_here()
			elif tool == "saw" and not _drag_from.is_empty():
				cut_here()
				_drag_from = {}
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			_rdrag = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			_mdrag = mb.pressed
		elif mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			var up: bool = mb.button_index == MOUSE_BUTTON_WHEEL_UP
			if mb.shift_pressed:
				_dist = clampf(_dist * (0.9 if up else 1.1), 1.6, 12.0)
			elif sc != null:
				sc.call("step_slice", 1 if up else -1)
		get_viewport().set_input_as_handled()
		return
	if mm != null:
		if _rdrag and sc != null:
			sc.call("turn_by", mm.relative.x * 0.006, mm.relative.y * 0.006)
		elif _ldown and _orbits():
			_lmoved += mm.relative.length()
			if _lmoved >= DRAG_PX:
				orbit(mm.relative)
		elif _mdrag:
			if _orbits():
				orbit(mm.relative)
			else:
				# Orbit, as a middle drag does in Blender.
				_yaw -= mm.relative.x * 0.006
				_pitch = clampf(_pitch + mm.relative.y * 0.005, deg_to_rad(-70.0), deg_to_rad(15.0))
		return
	if k == null or not k.pressed or k.echo:
		return
	var stp: Node = stepper()
	if stp != null and k.keycode in [KEY_1, KEY_2, KEY_3, KEY_4, KEY_Q, KEY_E, KEY_R, KEY_Z, KEY_SPACE]:
		if k.keycode == KEY_1:
			step_next()
		get_viewport().set_input_as_handled()
		return
	match k.keycode:
		KEY_F, KEY_ESCAPE:
			undock()
		KEY_1, KEY_2, KEY_3, KEY_4:
			var i: int = int(k.keycode - KEY_1)
			if i < tools.size():
				tool = tools[i]
				_drag_from = {}
		KEY_Q:
			size_index = maxi(size_index - 1, 0)
		KEY_E:
			size_index = mini(size_index + 1, _sizes() - 1)
		KEY_R:
			var ex: Node = exhibit()
			if ex != null:
				ex.call("reset")
				_say("Start again: the doorway" if builder() != null else "Whole again")
		KEY_Z:
			if builder() != null:
				if undo().is_empty():
					_say("Nothing to take back")
		KEY_SPACE:
			if builder() != null and sc != null:
				sc.set("turn", Vector2.ZERO)
				sc.set("turn_basis", Projection.IDENTITY)
				_say("The slice level again")
		KEY_T:
			var sp: Node = specimen()
			if sp != null:
				sp.set("swap", not bool(sp.get("swap")))
				_say("New chunks drawn from a worker thread" if bool(sp.get("swap")) else "New chunks built in the frame: the engine's way")
		KEY_C:
			var sp2: Node = specimen()
			if sp2 != null:
				sp2.set("flash_on", not bool(sp2.get("flash_on")))
				_say("Chunk outlines on" if bool(sp2.get("flash_on")) else "Chunk outlines off")
		KEY_V:
			if room != null and room.has_method("toggle_volume_view"):
				room.call("toggle_volume_view")
		KEY_G:
			if room != null and room.has_method("toggle_grid_view"):
				room.call("toggle_grid_view")
		_:
			return
	# The bench's own keys click (standing up swipes, in undock(); V and G click in the room's toggles).
	if not (k.keycode in [KEY_F, KEY_ESCAPE, KEY_V, KEY_G]):
		_sound("click")
	get_viewport().set_input_as_handled()


## A builder's orbit by a mouse move (pixels; the runner calls it too): as if you held the build and
## turned it. Right: its front goes right. Down: you look down on it more.
func orbit(rel: Vector2) -> void:
	_yaw -= rel.x * 0.006
	_pitch = _clamp_pitch(_pitch - rel.y * 0.005)


func _say(text: String) -> void:
	if room != null and room.get("hud") != null:
		room.get("hud").call("toast", text)


## Sizes Q/E steps through: a builder's colours, or small, medium, large.
func _sizes() -> int:
	var b: Node = builder()
	return int(b.call("colour_count")) if b != null else 3


## Cuts with the current tool where the mouse is (the runner calls this too). Returns the record so far.
func cut_here() -> Dictionary:
	var sp: Node = specimen()
	# A cut made while the last one is still on its way joins its swap (vl_specimen_4d.gd).
	if sp == null or hover.is_empty():
		return {}
	var bld: Node = builder()
	if bld != null:
		return _build(bld, bld.call("build_cut", tool, size_index, hover))
	var r: Dictionary = sp.get("recipe")
	var v: float = float(r.get("voxel", 0.1))
	var w_dir: Vector4 = (sp.call("dir_to_voxel", Vector4(0, 0, 0, 1)) as Vector4).normalized()
	var w_ext: float = (r["half"] as Vector4).w * 2.0 + 6.0
	var to: Vector4 = hover["point"] if tool == "saw" else Vector4.INF
	var from: Dictionary = _drag_from if (tool == "saw" and not _drag_from.is_empty()) else hover
	var cut: Dictionary = Cutter.make(tool, size_index, from["point"], from.get("normal", Vector4.ZERO), hover["ray"], w_dir, v, to, w_ext)
	var rec: Dictionary = sp.call("apply_cut", cut)
	if rec.is_empty():
		return {}
	var t_fx: int = Time.get_ticks_usec()
	# Chips in the colours under the cut: the surface's, then the core's.
	var colors: Array = [Recipe.COLORS.get(int(hover.get("material", 0)), Color.GRAY), Recipe.COLORS[Recipe.CRUST], Recipe.COLORS[Recipe.CORE]]
	var n_world: Vector4 = (sp.call("dir_to_global", from.get("normal", Vector4(0, 0, 1, 0))) as Vector4).normalized()
	Chips.spawn(get_tree().current_scene if get_tree().current_scene != null else self, hover["world"], n_world, colors, 10 + size_index * 6, 0.05 + 0.02 * float(size_index))
	if _audio != null and not _sounds.is_empty():
		_audio.stream = _sounds[clampi(size_index + randi_range(0, 1), 0, _sounds.size() - 1)]
		_audio.pitch_scale = randf_range(0.92, 1.08)
		_audio.play()
	rec["fx_ms"] = float(Time.get_ticks_usec() - t_fx) / 1000.0
	return rec


## A stepper's next piece (1; the runner calls this too), with a knock; after the last, the bench stands you up
## once it has been on show a moment.
func step_next() -> void:
	var stp: Node = stepper()
	if stp == null or not bool(stp.call("add_next")):
		return
	_sound("click")
	if _audio != null and not _sounds.is_empty():
		_audio.stream = _sounds[0]
		_audio.pitch_scale = randf_range(1.35, 1.5)
		_audio.play()
	if bool(stp.call("finished")):
		var sitting: int = _sitting
		get_tree().create_timer(RELEASE_AFTER).timeout.connect(func() -> void:
			if docked and _sitting == sitting:
				undock())


## Takes a builder's last brick back (Z; the runner calls this too).
func undo() -> Dictionary:
	var bld: Node = builder()
	return _build(bld, bld.call("undo_cut")) if bld != null else {}


## A builder's edit: the specimen takes it, the builder's copy follows, a puff in its colours and a
## knock.
func _build(bld: Node, cut: Dictionary) -> Dictionary:
	var sp: Node = specimen()
	if cut.is_empty() or sp == null:
		return {}
	var rec: Dictionary = sp.call("apply_cut", cut)
	if rec.is_empty():
		return {}
	bld.call("commit", cut)
	var at: Vector4 = hover.get("world", (sp as Node4D).global_position) if not hover.is_empty() else (sp as Node4D).global_position
	var n_world: Vector4 = (sp.call("dir_to_global", hover.get("normal", Vector4(0, 1, 0, 0))) as Vector4).normalized()
	Chips.spawn(get_tree().current_scene if get_tree().current_scene != null else self, at, n_world, cut["colors"], 8, 0.04)
	if _audio != null and not _sounds.is_empty():
		_audio.stream = _sounds[0]
		_audio.pitch_scale = randf_range(1.35, 1.5) if int(cut["fill"]) != Recipe.AIR else randf_range(0.95, 1.05)
		_audio.play()
	return rec


func _on_cut(rec: Dictionary) -> void:
	if String(rec.get("label", "")).begins_with("Story"):
		return
	records.append(rec)
	if records.size() > 60:
		records.remove_at(0)


## The control strip while seated.
func strip() -> Array:
	if stepper() != null:
		return [["1", "Add the next"], ["Drag", "Look around"], ["Right drag", "Turn in 4D"], ["Wheel", "Slide through W"], ["F", "Stand up"]]
	if builder() != null:
		return [["Click", "Place"], ["Drag", "Look around"], ["Right drag", "Turn the slice"], ["Wheel", "W layer"], ["1 to 3", "Tool"],
			["Q / E", "Colour"], ["Z", "Undo"], ["Space", "Level"], ["R", "Start again"], ["F", "Stand up"]]
	return [["Click", "Saw: press, drag, let go" if tool == "saw" else "Cut"], ["1 to 4", "Tool"], ["Q / E", "Size"],
		["Wheel", "Slide through W"], ["Right drag", "Sweep through W" if _sweeps() else "Turn in 4D"], ["Middle drag / WASD", "Orbit"], ["R", "Whole again"],
		["F / Esc", "Stand up"]]


## The big landscape's drag sweeps its slice through W instead of turning it (round 6, #61).
func _sweeps() -> bool:
	var e: Node = exhibit()
	return e != null and e.get("sweep_w") == true


## The menu's sounds in the labs (Menu/scripts/menu_lab_sounds.gd): one of the Frontier Map's cues, never in the editor.
func _sound(which: String) -> void:
	if not Engine.is_editor_hint() and is_inside_tree():
		LabSounds.cue(get_tree(), which)
