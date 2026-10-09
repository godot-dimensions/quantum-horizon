@tool
extends Node4D

## WATER LAB: the koi showcase in the corner (Ramon, 9 Oct: "a small information pedestal in a corner of
## the room ... a round platform with a big koi above it, 3 or 5 times the size of normal ... even more
## premium and detailed. and let it swim without moving forward in that holo field. and with one of
## the floating panels from voxel lab so that when you activate it, you can see some infos on it").
##
##   THE PEDESTAL  the kit's round one (kit_pedestal.gd), and over its deck the kit's blue holographic
##                 column, wide enough for the koi to turn in.
##   THE KOI       a Kohaku about four times life size, drawn as the tank's koi are (life/koi.gdshader,
##                 a body wave on the graphics card) from the fine mesh (koi_mesh.gd detail 2) with the
##                 shader's detail on: the gill cover, the lateral line, the nostrils, a wet eye.
##                 It swims ON THE SPOT, the way a koi holds station in a current: slow tail beats
##                 that never carry it anywhere, the pectorals sculling to hold it, and every so often
##                 a slow turn round, a glide, a gulp.
##   IN YOUR HANDS the wheel slides it through W (the slice cuts it smaller, then away: it is a 4D
##                 body), a right drag turns it to see it from any side; let go and it swims on.
##   THE PANEL     the Voxel Lab's floating panel (carried/voxel_lab/float_panel_4d.gd) on its spring:
##                 a summary, and E for pages of more (face(), panel_pages()).
##
## NO class_name (engine_gotchas.md).

const Build := preload("res://ramon/WaterLab/carried/scripts/chamber_build.gd")
const LabGrid := preload("res://ramon/WaterLab/carried/LabKit/lab_grid.gd")
const Pedestal := preload("res://ramon/WaterLab/carried/kit/kit_pedestal.gd")
const Herd := preload("res://ramon/WaterLab/shared/slice_herd_4d.gd")
const KoiMesh := preload("res://ramon/WaterLab/life/koi_mesh.gd")
const SHADER := preload("res://ramon/WaterLab/life/koi.gdshader")
const FloatPanel := preload("res://ramon/WaterLab/carried/voxel_lab/float_panel_4d.gd")
const GENERATED := "showcase_generated"
const VARIETIES := ["Kohaku", "Taisho Sanke", "Showa", "Tancho", "Ogon", "Platinum Ogon", "Asagi", "Chagoi"]

@export_tool_button("Rebuild") var _rebuild_action: Callable = rebuild
@export_range(1.0, 4.0, 0.05) var radius: float = 1.85:
	set(v):
		radius = v
		_later()
@export_range(0.3, 2.0, 0.05) var height: float = 0.9:
	set(v):
		height = v
		_later()
@export_range(1.0, 6.0, 0.05) var holo_height: float = 3.1:
	set(v):
		holo_height = v
		_later()
## The koi, metres snout to tail: about four times a tank koi.
@export_range(1.0, 5.0, 0.05) var koi_length: float = 2.8
@export_range(0, 7) var variety: int = 0
@export var long_fins: bool = false
@export var pattern_seed: float = 0.37
## The floating panel: where it floats (x, z from the pedestal's middle), and the point it turns its
## face to (where you stand to read it).
@export var panel_at: Vector2 = Vector2(-1.5, 2.6)
@export var panel_face: Vector2 = Vector2(0.0, 3.0)

## The pedestal's deck height (the room's prompt sits over it).
var deck_h: float = 0.9
var herd: Node4D
var panel: Node4D
var player: Node4D
## Your hands on it: how far it is slid through W, and how far turned (yaw, pitch).
var slide_w: float = 0.0
var turn := Vector2.ZERO
var _ped: Dictionary = {}
var _holo: MeshInstance4D
var _queued: bool = false
var _t: float = 0.0
var _phase: float = 0.0
var _amp: float = 0.05
var _yaw: float = 0.0
var _yaw_rate: float = 0.0
var _bend: float = 0.0
var _gulp: float = 0.0
var _touched: float = -100.0
var _stroke: float = 0.0
var _next_turn: float = 6.0
var _swim_us: float = 0.0


func _ready() -> void:
	rebuild()


func _later() -> void:
	if _queued or not is_inside_tree():
		return
	_queued = true
	(func() -> void:
		_queued = false
		rebuild()).call_deferred()


func rebuild() -> void:
	for c in get_children():
		if c.has_meta(GENERATED) or c.has_meta(Build.GENERATED):
			remove_child(c)
			c.queue_free()
	_ped = Pedestal.build(self, radius, height, "round")
	deck_h = float(_ped["deck_h"])
	_build_holo()
	if Engine.is_editor_hint():
		return
	herd = Node4D.new()
	herd.name = "KoiHerd"
	herd.set_meta(GENERATED, true)
	herd.set_script(Herd)
	herd.set("mesh", KoiMesh.build(2))
	herd.set("shader", SHADER)
	herd.set("w_radius", 0.21)
	herd.set("params", {&"detail": 1.0, &"fin_flutter": 1.3})
	herd.set("count", 1)
	add_child(herd)
	panel = Node4D.new()
	panel.name = "Panel"
	panel.set_meta(GENERATED, true)
	panel.set_script(FloatPanel)
	panel.position = Vector4(panel_at.x, 0.0, panel_at.y, 0.0)
	panel.set("width", 1.6)
	panel.set("depth", 0.62)
	panel.set("number", 1)
	panel.set("title", "The showcase koi")
	panel.set("kicker", "%s  ·  FOUR TIMES LIFE SIZE" % String(VARIETIES[variety]).to_upper())
	panel.set("face_point", panel_face)
	add_child(panel)
	panel.set("source", panel.get_path_to(self))
	panel.set("player", player)


## The kit's holographic column (kit_showcase_4d.gd _build_holo), wide enough for the koi to turn in.
func _build_holo() -> void:
	var r: float = radius - Pedestal.DECK_IN
	_holo = MeshInstance4D.new()
	_holo.name = "Hologram"
	_holo.mesh = Build._cubinder(r, holo_height, 96)
	_holo.position = Vector4(0.0, deck_h + holo_height * 0.5, 0.0, 0.0)
	_holo.material_override = LabGrid.material("kit_code_blue", Vector4(r * 2.0, holo_height, r * 2.0, Build.W_DEPTH), global_position if is_inside_tree() else Vector4.ZERO)
	_holo.set_meta(GENERATED, true)
	add_child(_holo)
	var cs: ShaderMaterial = (_holo.material_override as TetraMaterial4D).get_cross_section_material_3d()
	# Light: the column is a dither (the renderer has no translucency), and at the kit's density a
	# third of the koi's pixels were blue (frames of 9 Oct). Dense at the foot, a haze at the koi.
	cs.set_shader_parameter("holo_on", 1.0)
	cs.set_shader_parameter("holo_base", 0.5)
	cs.set_shader_parameter("holo_falloff", 2.4)
	cs.set_shader_parameter("holo_color", Color(0.25, 0.60, 1.0))
	cs.set_shader_parameter("holo_fine", 1.0)


func apply_mood(_m: String, _instant: bool = false) -> void:
	if not _ped.is_empty():
		Pedestal.apply_mood(_ped)


# -- swimming on the spot ----------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if Engine.is_editor_hint() or herd == null:
		return
	var t0: int = Time.get_ticks_usec()
	var dt: float = minf(delta, 0.05)
	_t += dt
	var held: bool = _t - _touched < 4.0
	# Strokes and glides: a few slow beats, then the tail almost still.
	_stroke -= dt
	if _stroke < -2.2:
		_stroke = randf_range(2.0, 3.6)
	var beating: bool = _stroke > 0.0
	_amp = lerpf(_amp, 0.085 if beating else 0.03, 1.0 - exp(-(3.0 if beating else 1.5) * dt))
	var freq: float = 0.85 if beating else 0.45
	_phase = fmod(_phase + TAU * freq * dt, TAU * 64.0)
	# Now and then a slow turn round, the body bending into it; held, it waits.
	_next_turn -= dt
	if _next_turn <= 0.0 and not held:
		_next_turn = randf_range(7.0, 12.0)
		_yaw_rate = (1.0 if randf() < 0.5 else -1.0) * randf_range(0.35, 0.6)
	if absf(_yaw_rate) > 0.0:
		_yaw += _yaw_rate * dt
		_yaw_rate = move_toward(_yaw_rate, 0.0, dt * 0.09)
	_bend = lerpf(_bend, clampf(_yaw_rate * 0.35, -0.22, 0.22), 1.0 - exp(-3.0 * dt))
	if randf() < dt * 0.06 and _gulp <= 0.0:
		_gulp = 2.4
	_gulp = maxf(_gulp - dt, 0.0)
	var gulp_open: float = (0.5 + 0.5 * sin(_t * 6.0)) if _gulp > 0.0 else 0.0
	_draw_koi(gulp_open)
	if panel != null and player != null and is_instance_valid(player):
		panel.call("set_near", near_panel(player.global_position))
	_swim_us = lerpf(_swim_us, float(Time.get_ticks_usec() - t0), 0.05)


func _draw_koi(gulp_open: float) -> void:
	var yaw: float = _yaw + turn.x
	var pitch: float = clampf(turn.y, -1.2, 1.2) + sin(_t * 0.37) * 0.04
	var h := Vector4(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch), 0.0)
	var right := Vector4(cos(yaw), 0.0, -sin(yaw), 0.0)
	# It holds its place, its middle (a third of the way back, where a koi pivots) over the deck's
	# middle, bobbing a little.
	var centre := Vector4(0.0, deck_h + holo_height * 0.5 + sin(_t * 0.6) * 0.05, 0.0, slide_w)
	var kind := Color((float(variety) + (8.0 if long_fins else 0.0)) / 16.0, pattern_seed, 0.75, gulp_open)
	herd.call("write", 0, centre, h, right, kind, Vector4(_phase, _amp, koi_length, _bend))
	herd.call("upload")


# -- in your hands ---------------------------------------------------------------------------------------------

## The wheel: through W, a fifth of its depth a step, as far as its edge.
func step_slice(d: int) -> void:
	_touched = _t
	var reach: float = 0.21 * koi_length
	slide_w = clampf(slide_w + float(d) * reach * 0.2, -reach, reach)


## A right drag turns it round (x) and tips it (y).
func turn_by(dx: float, dy: float) -> void:
	_touched = _t
	turn += Vector2(dx, dy)
	turn.y = clampf(turn.y, -1.2, 1.2)


## R: level and whole again.
func reset() -> void:
	slide_w = 0.0
	turn = Vector2.ZERO


func set_player(p: Node4D) -> void:
	player = p
	if panel != null:
		panel.set("player", p)


func near_panel(p: Vector4) -> bool:
	if panel == null:
		return false
	var at: Vector4 = (panel as Node4D).global_position
	return Vector2(p.x - at.x, p.z - at.z).length() < 2.4


func activate() -> void:
	if panel != null:
		panel.call("activate")


# -- what the panel says ----------------------------------------------------------------------------------------

func face() -> Array:
	var reach: float = 0.21 * koi_length
	var cut: float = sqrt(maxf(1.0 - (slide_w * slide_w) / (reach * reach), 0.0))
	return [["Length", "%.1f m" % koi_length], ["Cut by your slice", "%d%%" % int(round(cut * 100.0))], ["Through W", "%+.2f m" % slide_w]]


func panel_pages() -> Array:
	var tris: int = 0
	if herd != null and herd.get("mesh") != null:
		tris = int(((herd.get("mesh") as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3)
	return [
		{"title": "The showcase koi", "kicker": "A %s, FOUR TIMES LIFE SIZE" % String(VARIETIES[variety]).to_upper(),
			"text": "It swims on the spot, as a koi holds station in a current: slow tail beats that carry it nowhere, the pectoral fins sculling to keep it still, now and then a slow turn round. Scroll to slide it through W; right drag to turn it."},
		{"title": "How it swims", "kicker": "A WAVE DOWN THE BODY",
			"text": "The spine bends as a wave that runs from head to tail: a fiftieth of the body at the head, least just behind it, a tenth at the tail, as measured on swimming koi. Each point turns with the bent spine, so it bends like a fish, not a flag."},
		{"title": "How it is drawn", "kicker": "A 4D BODY, CUT BY YOUR SLICE",
			"text": "Its shape is stretched through W as a 4D ellipsoid, so your slice cuts the whole koi when it is on the slice and a smaller one off it. It is drawn the way the pen's starlings are: one draw call, bent on the graphics card every frame."},
		{"title": "What it costs", "kicker": "MEASURED ON THIS MACHINE, NOW",
			"rows": [["Triangles", _thousands(tris)], ["Its swim, a frame", "%.3f ms" % (_swim_us / 1000.0)], ["Draw calls", "1"]]},
	]


static func _thousands(n: int) -> String:
	var s: String = str(n)
	var out: String = ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out
