@tool
extends Node4D

## WATER LAB: the showcase (Ramon, 9 Oct: "a small information pedestal in a corner of the room ... a
## round platform with a big koi above it ... let it swim without moving forward in that holo field.
## and with one of the floating panels from voxel lab").
##
## ROUND 2 AND 3, A SWAP DISPLAY ("similar to the floating panel at the shooter range ... the icons that
## you can select of the different animals ... showcased in the middle when you click an icon with
## the arrow keys ... it gets from small to large every time you select it ... and we can see the
## separate models in detail and swimming around. So putting the eel there would be cool too"; the
## pedestal bigger, the panel always facing you, no cyan lines on it):
##
##   THE PEDESTAL  the kit's round one (kit_pedestal.gd), and over its deck the kit's blue holographic
##                 column, wide enough for the biggest of them to turn in.
##   THE CREATURES four, one at a time, each in detail and in place:
##                   the koi         a Kohaku five times life size, the fine mesh with the shader's
##                                   detail on (gill cover, lateral line, nostrils, a wet eye),
##                                   holding station: slow beats, sculling pectorals, slow turns;
##                   the hammerhead  the tank's lofted shark (life/shark_4d.gd), its pieces posed in
##                                   place, its tail sweeping, half again life size;
##                   the crab        four times life size on the deck, walking on the spot, its claws
##                                   picking;
##                   the eel         its anguilliform wave running down it, holding station.
##                 The koi, the crab and the eel are drawn as the tank draws them (a slice herd each,
##                 bent on the graphics card); the hammerhead is 4D meshes.
##   THE SWAP      choosing another (the arrow keys or 1 to 4, at the panel): the one there shrinks
##                 away, the new one grows in from its own life size to the showcase's.
##   IN YOUR HANDS the wheel slides it through W, a right drag turns it; let go and it carries on.
##   THE PANEL     the Voxel Lab's floating panel (carried/voxel_lab/float_panel_4d.gd), a selector
##                 now: the four as tiles across its top (their glyphs, kit_glyphs.gd), the chosen
##                 one's card under them, E for pages of more. Always turned to you; solid.
##
## NO class_name (engine_gotchas.md).

const Build := preload("res://ramon/WaterLab/carried/scripts/chamber_build.gd")
const LabGrid := preload("res://ramon/WaterLab/carried/LabKit/lab_grid.gd")
const Pedestal := preload("res://ramon/WaterLab/carried/kit/kit_pedestal.gd")
const Herd := preload("res://ramon/WaterLab/shared/slice_herd_4d.gd")
const KoiMesh := preload("res://ramon/WaterLab/life/koi_mesh.gd")
const KOI_SHADER := preload("res://ramon/WaterLab/life/koi.gdshader")
const Eel := preload("res://ramon/WaterLab/life/eel_4d.gd")
const EEL_SHADER := preload("res://ramon/WaterLab/life/eel.gdshader")
const Crab := preload("res://ramon/WaterLab/life/crab_4d.gd")
const CRAB_SHADER := preload("res://ramon/WaterLab/life/crab.gdshader")
const Shark := preload("res://ramon/WaterLab/life/shark_4d.gd")
const FloatPanel := preload("res://ramon/WaterLab/carried/voxel_lab/float_panel_4d.gd")
const GENERATED := "showcase_generated"

## The four: the key, the tile's name and glyph, the card, how big it is in life and here (metres,
## nose to tail or across), where it holds (over the deck: a share of the column's height; 0 on
## the deck), and its half depth through W (body lengths: its shader's w_radius; the shark's 0.05).
const SPECIES := [
	{"key": "koi", "name": "Koi", "glyph": "koi", "title": "Kohaku", "kicker": "A KOI, FIVE TIMES LIFE SIZE", "life": 0.7, "size": 3.4, "hold": 0.5, "w": 0.21},
	{"key": "hammerhead", "name": "Hammerhead", "glyph": "hammerhead", "title": "Scalloped hammerhead", "kicker": "LOFTED IN 4D, HALF AGAIN LIFE SIZE",
		"life": 2.4, "size": 3.6, "hold": 0.5, "w": 0.05},
	{"key": "crab", "name": "Crab", "glyph": "crab", "title": "Edible crab", "kicker": "WALKS SIDEWAYS, AND THROUGH W", "life": 0.34, "size": 1.8, "hold": 0.0, "w": 0.6},
	{"key": "eel", "name": "Eel", "glyph": "eel", "title": "European eel", "kicker": "A WAVE DOWN ITS WHOLE LENGTH", "life": 1.4, "size": 3.4, "hold": 0.45, "w": 0.06},
]

@export_tool_button("Rebuild") var _rebuild_action: Callable = rebuild
@export_range(1.0, 4.5, 0.05) var radius: float = 3.0:
	set(v):
		radius = v
		_later()
@export_range(0.3, 2.0, 0.05) var height: float = 0.9:
	set(v):
		height = v
		_later()
@export_range(1.0, 6.0, 0.05) var holo_height: float = 3.8:
	set(v):
		holo_height = v
		_later()
@export var pattern_seed: float = 0.37
## The floating panel: where it floats (x, z from the pedestal's middle), toward the route's end. It
## turns to face you.
@export var panel_at: Vector2 = Vector2(-2.1, -3.5)

## The pedestal's deck height (the room's prompt sits over it).
var deck_h: float = 0.9
var panel: Node4D
var player: Node4D
## The chosen one, and the one on the pedestal now.
var chosen: int = 0
var _shown: int = -1
## The one there going (1 to 0), the new one coming (0 to 1).
var _out: float = 0.0
var _in: float = 1.0
## Your hands on it: how far it is slid through W, and how far turned (yaw, pitch).
var slide_w: float = 0.0
var turn := Vector2.ZERO
var _ped: Dictionary = {}
var _holo: MeshInstance4D
var _herds: Dictionary = {}
var _shark: Node4D = null
var _queued: bool = false
var _t: float = 0.0
var _phase: float = 0.0
var _amp: float = 0.05
var _yaw: float = 2.2
var _yaw_rate: float = 0.0
var _bend: float = 0.0
var _gulp: float = 0.0
var _touched: float = -100.0
var _stroke: float = 0.0
var _next_turn: float = 18.0
var _side: float = 1.0
## The heading that shows it side on to you coming along the route (radians: sin, cos of x, z).
@export var side_on: float = 2.2
var _pinch: float = 0.0
var _swim_us: float = 0.0
## Frames left of the warm-up: all four drawn tiny for a few frames after building, so none of
## their shaders compiles the first time it is chosen (round 4: the hammerhead's first appearance).
var _warm: int = 0


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
	_herds = {}
	_shark = null
	_shown = -1
	_ped = Pedestal.build(self, radius, height, "round")
	deck_h = float(_ped["deck_h"])
	_build_holo()
	if Engine.is_editor_hint():
		return
	_herds["koi"] = _herd("KoiHerd", KoiMesh.build(2), KOI_SHADER, 0.21, {&"detail": 1.0, &"fin_flutter": 1.3})
	_herds["eel"] = _herd("EelHerd", Eel.build_mesh(), EEL_SHADER, 0.06, {})
	_herds["crab"] = _herd("CrabHerd", Crab.build_mesh(), CRAB_SHADER, 0.6, {})
	_shark = Node4D.new()
	_shark.name = "Hammerhead"
	_shark.set_meta(GENERATED, true)
	_shark.set_script(Shark)
	_shark.set("half_extents", Vector4(30, 30, 30, 30))
	add_child(_shark)
	_shark.set_process(false)
	_shark.visible = false
	_warm = 4
	panel = Node4D.new()
	panel.name = "Panel"
	panel.set_meta(GENERATED, true)
	panel.set_script(FloatPanel)
	panel.position = Vector4(panel_at.x, 0.0, panel_at.y, 0.0)
	panel.set("width", 2.2)
	panel.set("depth", 0.95)
	panel.set("number", 0)
	panel.set("face_point", Vector2(panel_at.x * 2.0, panel_at.y * 2.0))
	panel.set("face_always", true)
	panel.set("underglow", false)
	add_child(panel)
	panel.set("source", panel.get_path_to(self))
	panel.set("player", player)


func _herd(nm: String, mesh: Mesh, shader: Shader, w_radius: float, params: Dictionary) -> Node4D:
	var h := Node4D.new()
	h.name = nm
	h.set_meta(GENERATED, true)
	h.set_script(Herd)
	h.set("mesh", mesh)
	h.set("shader", shader)
	h.set("w_radius", w_radius)
	h.set("params", params)
	h.set("count", 0)
	add_child(h)
	return h


## The kit's holographic column (kit_showcase_4d.gd _build_holo), wide enough for them to turn in.
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


# -- choosing ---------------------------------------------------------------------------------------------------

func select(i: int) -> void:
	i = clampi(i, 0, SPECIES.size() - 1)
	if i == chosen:
		return
	chosen = i
	slide_w = 0.0
	turn = Vector2.ZERO
	if panel != null:
		panel.set("page_index", -1)
		panel.call("_read")


func select_step(d: int) -> void:
	select(wrapi(chosen + d, 0, SPECIES.size()))


# -- in place -----------------------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _herds.is_empty():
		return
	var t0: int = Time.get_ticks_usec()
	var dt: float = minf(delta, 0.05)
	_t += dt
	# The swap: the one there shrinks away, then the chosen one grows in.
	if _shown != chosen:
		_out = move_toward(_out, 0.0, dt / 0.35)
		if _out <= 0.0 or _shown < 0:
			_show(chosen)
	else:
		_in = move_toward(_in, 1.0, dt / 1.8)
	_swim(dt)
	_draw_now()
	if _warm > 0:
		_warm_up()
	if panel != null and player != null and is_instance_valid(player):
		panel.call("set_near", near_panel(player.global_position))
	_swim_us = lerpf(_swim_us, float(Time.get_ticks_usec() - t0), 0.05)


func _show(i: int) -> void:
	for k in _herds:
		(_herds[k] as Node4D).call("set_count", 0)
	if _shark != null:
		_shark.visible = false
	_shown = i
	_in = 0.0
	_out = 1.0
	var key: String = SPECIES[i]["key"]
	if _herds.has(key):
		(_herds[key] as Node4D).call("set_count", 1)
	elif key == "hammerhead" and _shark != null:
		_shark.visible = true


## How big it is now: from nothing to its life size in the first quarter second, then growing to the
## display's size (eased), times the shrink when it goes. (Round 4: the hammerhead, life size two
## thirds of its display size, had jumped straight in at two thirds after the koi shrank away.)
func _grow() -> float:
	var sp: Dictionary = SPECIES[maxi(_shown, 0)]
	var small: float = float(sp["life"]) / float(sp["size"])
	var appear: float = smoothstep(0.0, 0.14, _in)
	return lerpf(small, 1.0, ease(_in, -2.2)) * appear * (_out if _shown != chosen else 1.0)


## The warm-up: the ones not on the pedestal drawn a millimetre long inside the deck, then put away.
func _warm_up() -> void:
	_warm -= 1
	var at := Vector4(0.0, deck_h * 0.5, 0.0, 0.0)
	var shown_key: String = SPECIES[maxi(_shown, 0)]["key"]
	for k in _herds:
		if k == shown_key:
			continue
		var herd: Node4D = _herds[k]
		herd.call("set_count", 0 if _warm == 0 else 1)
		if _warm > 0:
			herd.call("write", 0, at, Vector4(0, 0, 1, 0), Vector4(1, 0, 0, 0), Color(0, 0, 0.5, 0), Vector4(0.0, 0.0, 0.001, 0.0))
			herd.call("upload")
	if _shark != null and shown_key != "hammerhead":
		_shark.visible = _warm > 0
		if _warm > 0:
			var s: float = 0.001
			_shark.basis = Projection(Vector4(s, 0, 0, 0), Vector4(0, s, 0, 0), Vector4(0, 0, s, 0), Vector4(0, 0, 0, s))
			_shark.set("p", at / s)
			_shark.set("frame", Projection.IDENTITY)
			_shark.call("_pose")


## Strokes and glides, slow turns, a gulp now and then; the crab's claws.
func _swim(dt: float) -> void:
	var held: bool = _t - _touched < 4.0
	_stroke -= dt
	if _stroke < -2.2:
		_stroke = randf_range(2.0, 3.6)
	var beating: bool = _stroke > 0.0
	_amp = lerpf(_amp, 0.085 if beating else 0.03, 1.0 - exp(-(3.0 if beating else 1.5) * dt))
	var key: String = SPECIES[maxi(_shown, 0)]["key"]
	var freq: float = 0.85 if beating else 0.45
	if key == "eel":
		freq = 0.7
	elif key == "crab":
		freq = 1.6
	elif key == "hammerhead":
		freq = 0.6 + 0.3 * _amp
	_phase = fmod(_phase + TAU * freq * dt, TAU * 64.0)
	# Side on to the way you come (from the route, the north-west), swinging slowly to three-quarters
	# each way; every 20 s or so it turns round to show its other side.
	_next_turn -= dt
	if _next_turn <= 0.0 and not held:
		_next_turn = randf_range(16.0, 24.0)
		_side = -_side
	var want: float = side_on + (PI if _side < 0.0 else 0.0) + 0.6 * sin(_t * 0.13)
	var before: float = _yaw
	_yaw = lerp_angle(_yaw, want, 1.0 - exp(-0.45 * dt))
	_yaw_rate = (_yaw - before) / maxf(dt, 0.0001)
	_bend = lerpf(_bend, clampf(_yaw_rate * 0.35, -0.22, 0.22), 1.0 - exp(-3.0 * dt))
	if randf() < dt * 0.06 and _gulp <= 0.0:
		_gulp = 2.4
	_gulp = maxf(_gulp - dt, 0.0)
	_pinch = 0.5 + 0.5 * sin(_t * 1.7) if fmod(_t, 6.0) < 2.0 else lerpf(_pinch, 0.0, dt * 3.0)


func _draw_now() -> void:
	if _shown < 0:
		return
	var sp: Dictionary = SPECIES[_shown]
	var key: String = sp["key"]
	var g: float = _grow()
	var size: float = float(sp["size"]) * g
	var yaw: float = _yaw + turn.x
	var pitch: float = clampf(turn.y, -1.2, 1.2) + (sin(_t * 0.37) * 0.04 if key != "crab" else 0.0)
	var h := Vector4(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch), 0.0)
	var right := Vector4(cos(yaw), 0.0, -sin(yaw), 0.0)
	var hold: float = float(sp["hold"])
	var centre := Vector4(0.0, deck_h + holo_height * hold + (sin(_t * 0.6) * 0.05 if hold > 0.0 else 0.0), 0.0, slide_w)
	match key:
		"koi":
			var gulp_open: float = (0.5 + 0.5 * sin(_t * 6.0)) if _gulp > 0.0 else 0.0
			_write("koi", centre, h, right, Color(0.0, pattern_seed, 0.75, gulp_open), Vector4(_phase, _amp, size, _bend))
		"eel":
			_write("eel", centre, h, right, Color(0.0, 0.0, 0.5 + 0.5 * sin(_t * 2.2), 0.0), Vector4(_phase, 0.07, size, _bend))
		"crab":
			var hc := Vector4(sin(yaw), 0.0, cos(yaw), 0.0)
			var rc := Vector4(cos(yaw), 0.0, -sin(yaw), 0.0)
			# Up off the deck (round 4: "the crab sits too low ... raise it slightly").
			_write("crab", Vector4(0.0, deck_h + 0.9, 0.0, slide_w), hc, rc, Color(_pinch, 0.0, 0.0, 1.0), Vector4(_phase, 1.0, size, 0.5 + 0.5 * sin(_t * 0.9)))
		"hammerhead":
			if _shark == null:
				return
			var s: float = size / float(sp["life"])
			_shark.basis = Projection(Vector4(s, 0, 0, 0), Vector4(0, s, 0, 0), Vector4(0, 0, s, 0), Vector4(0, 0, 0, s))
			_shark.set("p", centre / s)
			_shark.set("frame", _shark.call("_frame_for", h))
			_shark.set("_phase", _phase)
			_shark.set("_amp", 0.55 + 0.45 * _amp / 0.085)
			_shark.call("_pose")


func _write(key: String, at: Vector4, h: Vector4, right: Vector4, colour: Color, custom: Vector4) -> void:
	var herd: Node4D = _herds[key]
	herd.call("write", 0, at, h, right, colour, custom)
	herd.call("upload")


# -- in your hands ------------------------------------------------------------------------------------------------

## How far through W it goes either side of its middle (metres, as shown).
func reach() -> float:
	return float(SPECIES[chosen]["w"]) * float(SPECIES[chosen]["size"])


## The wheel: through W, a sixth of its depth a step, as far as its edge. (Round 4: one step had been
## a fifth of the koi's depth for all four, which took the thin hammerhead out of the slice at once.)
func step_slice(d: int) -> void:
	_touched = _t
	var r: float = reach()
	slide_w = clampf(slide_w + float(d) * r / 6.0, -r, r)


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
	return Vector2(p.x - at.x, p.z - at.z).length() < 2.6


func activate() -> void:
	if panel != null:
		panel.call("activate")


# -- what the panel says ------------------------------------------------------------------------------------------

func tiles() -> Array:
	var out: Array = []
	for i in SPECIES.size():
		out.append([SPECIES[i]["name"], SPECIES[i]["glyph"], i == chosen])
	return out


func card() -> Dictionary:
	return {"title": SPECIES[chosen]["title"], "kicker": SPECIES[chosen]["kicker"]}


func face() -> Array:
	var sp: Dictionary = SPECIES[chosen]
	var r: float = reach()
	var cut: float = sqrt(maxf(1.0 - (slide_w * slide_w) / (r * r), 0.0))
	var size_row: Array = ["Here", "%.1f m" % float(sp["size"])]
	var life_row: Array = ["In life", "%.2f m" % float(sp["life"]) if float(sp["life"]) < 1.0 else "%.1f m" % float(sp["life"])]
	return [size_row, life_row, ["Cut by your slice", "%d%%" % int(round(cut * 100.0))]]


func panel_pages() -> Array:
	match String(SPECIES[chosen]["key"]):
		"koi":
			return [
				{"title": "The koi", "kicker": "HOLDING STATION",
					"text": "It swims on the spot, as a koi holds station in a current: slow tail beats that carry it nowhere, the pectoral fins sculling to keep it still, now and then a slow turn round. Scroll to slide it through W; right drag to turn it."},
				{"title": "How it swims", "kicker": "A WAVE DOWN THE BODY",
					"text": "The spine bends as a wave that runs from head to tail: a fiftieth of the body at the head, least just behind it, a tenth at the tail, as measured on swimming koi. Each point turns with the bent spine, so it bends like a fish, not a flag."},
				{"title": "What it costs", "kicker": "MEASURED ON THIS MACHINE, NOW",
					"rows": [["Its swim, a frame", "%.3f ms" % (_swim_us / 1000.0)], ["Draw calls", "1"]]},
			]
		"hammerhead":
			return [
				{"title": "The hammerhead", "kicker": "THE LOFT TOOL'S SHOWCASE",
					"text": "Lofted in 4D by the tool that builds our animals and cut into six rigid pieces along the body. Each frame only the pieces turn, following the swim wave, so nothing is lofted again while it swims."},
				{"title": "The hammer", "kicker": "A QUARTER OF ITS LENGTH",
					"text": "The cephalofoil spreads its eyes and its sense of the water wide. It is a 4D shape here: slide it through W and the hammer thins away before the body does."},
			]
		"crab":
			return [
				{"title": "The crab", "kicker": "EIGHT LEGS, STEPPING ON THE GPU",
					"text": "Walking on the spot: two sets of four legs stepping in turn, the claws picking. In the tank it wanders through W, so it comes onto your slice in one place and leaves in another."},
			]
		"eel":
			return [
				{"title": "The eel", "kicker": "ANGUILLIFORM",
					"text": "The whole body swims: a wave runs down its length, growing toward the tail, so it pushes the water back along all of it. In the tank it rests in its cave by day and patrols low over the sand."},
			]
	return []
