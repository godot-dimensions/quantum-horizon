extends Node4D

## WATER LAB: the gull's test bed (gull_test.tscn; Ramon, 9 Oct: "Design the seagull in a separate
## TSCN"). A little pier in the lab look (a code-blue deck on a white lab floor) with posts and a rail
## along both sides and a tall pole; a harbour of six gulls (gull_flock_4d.gd) wheeling round it,
## landing on the post tops, the rails and the pole, looking round, calling, flying off; and on a
## plinth, one gull held in a pose to look at the wings.
##
## KEYS  1 glide  2 flap  3 flare  4 folded  (the plinth gull)
##       F follow a gull (again: the next one; Esc: back)   T slow motion   - / + fewer / more gulls
##       right drag: turn round   wheel: nearer / further   H this help
##
## NO class_name (engine_gotchas.md).

const Harbour := preload("res://ramon/WaterLab/gull/gull_flock_4d.gd")
const Gull := preload("res://ramon/WaterLab/gull/gull_4d.gd")
const LabGrid := preload("res://ramon/WaterLab/carried/LabKit/lab_grid.gd")
const Mats := preload("res://ramon/WaterLab/carried/LabKit/lab_materials.gd")

const DECK_Y := 1.2
const DECK_LEN := 14.0
const DECK_W := 2.4
const RAIL_H := 1.0
const POLE_AT := Vector4(4.0, 0.0, -5.0, 0.0)
const POLE_H := 4.0
const PLINTH_AT := Vector4(-4.5, 0.0, -4.0, 0.0)
const POSES := ["glide", "flap", "flare", "folded"]

var harbour: Node4D
var model: Node4D
var cam: Camera4D
var _yaw: float = 0.6
var _pitch: float = 0.32
var _dist: float = 16.0
var _target := Vector4(0.0, 2.5, 0.0, 0.0)
var _follow: int = -1
var _slow: bool = false
var _help: Label
var _status: Label


func _ready() -> void:
	_build_world()
	_build_pier()
	harbour = Node4D.new()
	harbour.name = "Harbour"
	harbour.set_script(Harbour)
	harbour.set("count", 6)
	harbour.set("home", Vector4(0.0, 6.0, 0.0, 0.0))
	harbour.set("roam_radius", 14.0)
	harbour.set("altitude", Vector2(4.0, 9.0))
	harbour.set("wind", Vector4(1.0, 0.0, 0.0, 0.0))
	_perches()
	add_child(harbour)
	harbour.set("listener_4d", cam)
	model = Node4D.new()
	model.name = "PlinthGull"
	model.set_script(Gull)
	model.set("p", PLINTH_AT + Vector4(0.0, 1.0 + Gull.FOOT, 0.0, 0.0))
	model.set("forward", Vector4(0.0, 0.0, 1.0, 0.0))
	model.set("forced", "glide")
	add_child(model)
	_build_hud()


func _build_world() -> void:
	var env := WorldEnvironment4D.new()
	var sky := GradientSkyMaterial4D.new()
	sky.set("horizon_color", Color(0.70, 0.76, 0.82))
	sky.set("top_color", Color(0.25, 0.45, 0.72))
	sky.set("bottom_color", Color(0.10, 0.13, 0.18))
	env.set("sky_material", sky)
	env.set("ambient_light_sky_contribution", 0.25)
	env.set("ambient_light_color", Color(0.45, 0.50, 0.58))
	env.set("tonemap_mode", 2)
	env.set("current", true)
	add_child(env)
	var sun := DirectionalLight4D.new()
	sun.basis = Projection(Vector4(0.8192, 0, -0.5736, 0), Vector4(-0.3214, 0.8192, -0.4589, 0), Vector4(0.4698, 0.5736, 0.671, 0), Vector4(0, 0, 0, 1))
	sun.set("light_energy", 1.1)
	add_child(sun)
	var size := Vector4(48.0, 1.0, 48.0, 8.0)
	var floor_at := Vector4(0.0, -0.5, 0.0, 0.0)
	var floor := MeshInstance4D.new()
	floor.name = "Floor"
	floor.mesh = Mats.box_mesh(size)
	floor.position = floor_at
	floor.material_override = LabGrid.material("floor", size, floor_at)
	add_child(floor)
	cam = Camera4D.new()
	cam.name = "Camera"
	cam.set("rendering_engine_name", "Cross-section")
	add_child(cam)
	cam.make_current()
	_place_camera()


func _box(nm: String, at: Vector4, size: Vector4, mat: TetraMaterial4D) -> void:
	var m := MeshInstance4D.new()
	m.name = nm
	m.mesh = Mats.box_mesh(size)
	m.position = at
	m.material_override = mat
	add_child(m)


func _build_pier() -> void:
	var deck_size := Vector4(DECK_LEN, 0.2, DECK_W, 3.0)
	var deck_at := Vector4(0.0, DECK_Y - 0.1, 0.0, 0.0)
	# The lab grid's own blue ("build"): the kit's code blue is only registered by a kit room.
	_box("Deck", deck_at, deck_size, LabGrid.material("build", deck_size, deck_at))
	var white: TetraMaterial4D = Mats.flat(Color(0.92, 0.92, 0.90))
	var dark: TetraMaterial4D = Mats.flat(Color(0.20, 0.22, 0.26))
	var n: int = 8
	for side in [-1.0, 1.0]:
		var z: float = side * (DECK_W * 0.5 - 0.06)
		for i in n + 1:
			var x: float = lerpf(-DECK_LEN * 0.5 + 0.1, DECK_LEN * 0.5 - 0.1, float(i) / float(n))
			_box("Post%d_%d" % [int(side), i], Vector4(x, DECK_Y + RAIL_H * 0.5, z, 0.0), Vector4(0.1, RAIL_H, 0.1, 0.4), dark)
		_box("Rail%d" % int(side), Vector4(0.0, DECK_Y + RAIL_H - 0.03, z, 0.0), Vector4(DECK_LEN, 0.06, 0.07, 0.3), dark)
	# The legs under the deck.
	for x in [-6.0, -2.0, 2.0, 6.0]:
		for side in [-1.0, 1.0]:
			_box("Leg", Vector4(x, DECK_Y * 0.5 - 0.1, side * 1.0, 0.0), Vector4(0.18, DECK_Y - 0.2, 0.18, 0.4), dark)
	_box("Pole", POLE_AT + Vector4(0.0, POLE_H * 0.5, 0.0, 0.0), Vector4(0.36, POLE_H, 0.36, 0.6), white)
	_box("PoleCap", POLE_AT + Vector4(0.0, POLE_H + 0.03, 0.0, 0.0), Vector4(0.44, 0.06, 0.44, 0.6), dark)
	_box("Plinth", PLINTH_AT + Vector4(0.0, 0.5, 0.0, 0.0), Vector4(1.0, 1.0, 1.0, 1.0), white)


func _perches() -> void:
	var top: float = DECK_Y + RAIL_H
	for side in [-1.0, 1.0]:
		var z: float = side * (DECK_W * 0.5 - 0.06)
		harbour.call("add_rail", Vector4(-DECK_LEN * 0.5 + 0.4, top, z, 0.0), Vector4(DECK_LEN * 0.5 - 0.4, top, z, 0.0), 1.4)
	harbour.call("add_perch", POLE_AT + Vector4(0.0, POLE_H + 0.06, 0.0, 0.0))


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.02, 0.03, 0.78)
	sb.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", sb)
	panel.position = Vector2(16, 16)
	layer.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	_help = Label.new()
	_help.text = "GULL TEST BED\n1 glide   2 flap   3 flare   4 folded   (the plinth gull)\nF follow a gull, again for the next, Esc back\nT slow motion   - / + fewer or more gulls\nright drag turns round, wheel nearer or further   H hide"
	box.add_child(_help)
	_status = Label.new()
	_status.modulate = Color(0.55, 0.85, 1.0)
	box.add_child(_status)


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		match e.keycode:
			KEY_1, KEY_2, KEY_3, KEY_4:
				model.set("forced", POSES[e.keycode - KEY_1])
			KEY_F:
				var gulls: Array = harbour.get("gulls")
				if not gulls.is_empty():
					_follow = (_follow + 1) % gulls.size()
					_dist = 4.0
			KEY_ESCAPE:
				_follow = -1
				_dist = 16.0
				_target = Vector4(0.0, 2.5, 0.0, 0.0)
			KEY_T:
				_slow = not _slow
				harbour.set("time_scale", 0.25 if _slow else 1.0)
				model.set("time_scale", 0.25 if _slow else 1.0)
			KEY_MINUS, KEY_KP_SUBTRACT:
				harbour.call("set_count", int(harbour.get("count")) - 1)
			KEY_EQUAL, KEY_PLUS, KEY_KP_ADD:
				harbour.call("set_count", int(harbour.get("count")) + 1)
			KEY_H:
				_help.visible = not _help.visible
	elif e is InputEventMouseMotion and (e.button_mask & MOUSE_BUTTON_MASK_RIGHT) != 0:
		_yaw -= e.relative.x * 0.006
		_pitch = clampf(_pitch + e.relative.y * 0.004, -0.2, 1.3)
	elif e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP:
			_dist = maxf(_dist * 0.9, 1.2)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_dist = minf(_dist * 1.1, 60.0)


func _process(delta: float) -> void:
	var gulls: Array = harbour.get("gulls")
	if _follow >= gulls.size():
		_follow = -1
	if _follow >= 0:
		var g: Node4D = gulls[_follow]
		_target = _target.lerp(g.global_position, 1.0 - exp(-6.0 * delta))
	_place_camera()
	var flying: int = gulls.size() - int(harbour.call("perched_count"))
	var who: String = ""
	if _follow >= 0:
		who = "   following gull %d: %s" % [_follow, String(gulls[_follow].get("state"))]
	_status.text = "%d gulls, %d sitting, %d flying%s%s   plinth: %s" % [gulls.size(), gulls.size() - flying, flying, who, "   SLOW" if _slow else "", String(model.get("forced"))]


func _place_camera() -> void:
	if cam == null:
		return
	var eye: Vector4 = _target + Vector4(sin(_yaw) * cos(_pitch), sin(_pitch), cos(_yaw) * cos(_pitch), 0.0) * _dist
	var d: Vector4 = _target - eye
	var yaw: float = atan2(-d.x, -d.z)
	var pitch: float = atan2(d.y, maxf(Vector2(d.x, d.z).length(), 0.0001))
	cam.global_position = eye
	cam.global_basis = Basis4D.from_zx(yaw) * Basis4D.from_yz(pitch)
