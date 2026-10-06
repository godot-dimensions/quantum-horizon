extends Node4D

## The Voxel Lab's field: through the gallery's back door, Andrew's landscape (4Denthusiast's test
## scene, his generators and numbers) generated round you as you fly over it. Plan steps 67 to 72
## (VoxelLab/PLAN.md, part H; Ramon, 6 Oct: "maybe we can explore seeing an open world option").
##
## You arrive on a blue survey pad above the landscape, as a camera that flies: no walking, because the
## engine's voxels have no collision yet. The numbers stay on screen: how far the world loads round you,
## how many chunks and tetrahedra that is, the memory, the frame time and the chunks still waiting to be
## drawable. Change the radius and watch what it costs.
##
##   mouse        look (the cursor is held while you fly; Tab frees it)
##   WASD         fly, Space and C up and down, Shift faster
##   Q / E        through W (the world is a band of W either side of 0)
##   wheel        turn the slice into W and back
##   click        a crater: a 4D ball of air where you look
##   [ / ]        the load radius, smaller or larger
##   T            new chunks drawable from a worker thread (the lab's swap), or the engine's own way
##   V            the volume view: everything ana and kata of you, faintly
##   H or Esc     back to the lab
##
## NO class_name (engine_gotchas.md).

const Stream := preload("res://ramon/VoxelLab/field/vl_stream_4d.gd")
const TetRay := preload("res://ramon/VoxelLab/specimen/vl_tet_ray.gd")
const Style := preload("res://ramon/VoxelLab/carried/kit/kit_style.gd")
const Hud := preload("res://ramon/VoxelLab/field/vl_field_hud.gd")
const Chips := preload("res://ramon/VoxelLab/room/vl_chips_4d.gd")
const Sound := preload("res://ramon/VoxelLab/room/vl_sound.gd")

const LAB := "res://ramon/VoxelLab/voxel_lab.tscn"
const RADII := [16.0, 24.0, 32.0, 40.0, 48.0, 64.0]

@export var start_at: Vector4 = Vector4(0, 30, 34, 0)
## Metres a second (Shift: two and a half times). Slow on purpose: the engine meshes new ground on the
## main thread, 16 chunks a frame at about 8 ms each (measured 6 Oct), so fast flight is a slideshow.
@export var fly_speed: float = 6.0
## The radius grows to its setting over this many seconds after you arrive, so the first chunks come in
## a few at a time rather than all in the same frames.
@export var warm_up: float = 8.0

var stream: Node4D
var cam: Camera4D
var hud: Control
var yaw: float = 0.0
var pitch: float = -0.62
var slice_turn: float = 0.0
var volume_view: bool = false
var input_enabled: bool = true
var _radius_i: int = 1
var _age: float = 0.0
var _frames: Array = []
var _last_us: int = 0
var _audio: AudioStreamPlayer
var _craters: int = 0
var _crater_hold: Array = []


func _ready() -> void:
	var env := WorldEnvironment4D.new()
	var sky := GradientSkyMaterial4D.new()
	sky.top_color = Color(0.32, 0.52, 0.80)
	sky.horizon_color = Color(0.78, 0.86, 0.94)
	sky.bottom_color = Color(0.30, 0.34, 0.40)
	env.sky_material = sky
	# Andrew lights his scene with a 0.3 sun and nothing else; at 0.8 with a lighter ambient his grass
	# went lime and his hills lost their shape (6 Oct).
	env.ambient_light_color = Color(0.17, 0.19, 0.23)
	env.ambient_light_sky_contribution = 0.0
	env.tonemap_mode = 2
	add_child(env)
	env.make_current()
	var sun := DirectionalLight4D.new()
	sun.basis = Basis4D.from_zx(deg_to_rad(35.0)) * Basis4D.from_yz(deg_to_rad(-50.0))
	sun.light_energy = 0.42
	add_child(sun)
	stream = Node4D.new()
	stream.name = "Stream"
	stream.set_script(Stream)
	stream.set("radius", 8.0)
	stream.set("y_range", Vector2i(-16, 16))
	add_child(stream)
	_pad()
	cam = Camera4D.new()
	cam.name = "SurveyCamera"
	cam.rendering_engine_name = "Cross-section"
	# The ground fades into the sky toward the edge of what is loaded, instead of ending in a cliff.
	cam.set("depth_fade_mode", 1)
	cam.set("depth_fade_start", float(RADII[_radius_i]) * 0.55)
	cam.position = start_at
	add_child(cam)
	cam.make_current()
	stream.set("follow", cam)
	_place_cam()
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Control.new()
	hud.set_script(Hud)
	hud.set("field", self)
	layer.add_child(hud)
	_audio = AudioStreamPlayer.new()
	_audio.volume_db = -4.0
	add_child(_audio)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## The survey pad: a blue disc under where you arrive, the lab's teaching blue in the open.
func _pad() -> void:
	var pad := MeshInstance4D.new()
	pad.name = "SurveyPad"
	var box := BoxTetraMesh4D.new()
	box.size = Vector4(6, 0.3, 6, 6)
	pad.mesh = box
	pad.position = start_at - Vector4(0, 2.2, 0, 0)
	var m := TetraMaterial4D.new()
	m.albedo_color = Style.pick(Style.CODE_BLUE)
	pad.material_override = m
	add_child(pad)


func _place_cam() -> void:
	cam.global_basis = Basis4D.from_zx(yaw) * Basis4D.from_yz(pitch) * Basis4D.from_zw(slice_turn)


func _process(delta: float) -> void:
	var now: int = Time.get_ticks_usec()
	if _last_us > 0:
		_frames.append(float(now - _last_us) / 1000.0)
		if _frames.size() > 240:
			_frames.remove_at(0)
	_last_us = now
	_age += delta
	if _age <= warm_up + 0.5:
		var target: float = float(RADII[_radius_i])
		stream.set("radius", lerpf(8.0, target, clampf(_age / maxf(warm_up, 0.1), 0.0, 1.0)))
	if not input_enabled:
		return
	var f: Vector4 = -(cam.global_basis * Vector4(0, 0, 1, 0))
	var r: Vector4 = cam.global_basis * Vector4(1, 0, 0, 0)
	f.y = 0.0
	r.y = 0.0
	f = f.normalized() if f.length() > 0.0 else Vector4(0, 0, -1, 0)
	r = r.normalized() if r.length() > 0.0 else Vector4(1, 0, 0, 0)
	var mv := Vector4.ZERO
	if Input.is_key_pressed(KEY_W):
		mv += f
	if Input.is_key_pressed(KEY_S):
		mv -= f
	if Input.is_key_pressed(KEY_D):
		mv += r
	if Input.is_key_pressed(KEY_A):
		mv -= r
	if Input.is_key_pressed(KEY_SPACE):
		mv.y += 1.0
	if Input.is_key_pressed(KEY_C):
		mv.y -= 1.0
	if Input.is_key_pressed(KEY_E):
		mv.w += 0.5
	if Input.is_key_pressed(KEY_Q):
		mv.w -= 0.5
	var speed: float = fly_speed * (2.5 if Input.is_key_pressed(KEY_SHIFT) else 1.0)
	var p: Vector4 = cam.global_position + mv * speed * delta
	var band: float = float(stream.get("w_chunks")) * 8.0 * float(stream.get("voxel")) - 2.0
	p.w = clampf(p.w, -band, band)
	cam.global_position = p


func _input(event: InputEvent) -> void:
	if not input_enabled:
		return
	var mm := event as InputEventMouseMotion
	if mm != null and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= mm.relative.x * 0.0035
		pitch = clampf(pitch - mm.relative.y * 0.0035, -1.45, 1.2)
		_place_cam()
		return
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed:
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			slice_turn = clampf(slice_turn + (0.12 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else -0.12), -PI * 0.5, PI * 0.5)
			_place_cam()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			else:
				crater_ahead()
		return
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	match k.keycode:
		KEY_TAB:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
		KEY_BRACKETLEFT:
			set_radius_index(_radius_i - 1)
		KEY_BRACKETRIGHT:
			set_radius_index(_radius_i + 1)
		KEY_T:
			stream.set("swap", not bool(stream.get("swap")))
			hud.call("toast", "New chunks drawable from a worker thread" if bool(stream.get("swap")) else "New chunks built in the frame: the engine's way")
		KEY_V:
			set_volume_view(not volume_view)
		KEY_H, KEY_ESCAPE:
			back_to_lab()


func set_radius_index(i: int) -> void:
	_radius_i = clampi(i, 0, RADII.size() - 1)
	_age = warm_up + 1.0
	stream.set("radius", float(RADII[_radius_i]))
	cam.set("depth_fade_start", float(RADII[_radius_i]) * 0.55)
	hud.call("toast", "Load radius %.0f m" % (float(RADII[_radius_i]) * float(stream.get("voxel"))))


func set_volume_view(on: bool) -> void:
	volume_view = on
	var tree: SceneTree = get_tree()
	if tree.root.world_3d == null:
		tree.root.world_3d = World3D.new()
	cam.set("rendering_engine_name", "Combined" if on else "Cross-section")
	cam.set("projection_opacity_base", 0.12)
	hud.call("toast", "Volume view" if on else "Slice view")


## A crater where you look: a 4D ball of air, 4 m round, at the first surface the view's middle meets.
func crater_ahead() -> Dictionary:
	var o: Vector4 = cam.global_position
	var d: Vector4 = -(cam.global_basis * Vector4(0, 0, 1, 0))
	var v: float = float(stream.get("voxel"))
	var hit: Dictionary = TetRay.raycast(stream, stream.call("to_voxel", o), d, 300.0 / v)
	if hit.is_empty():
		hud.call("toast", "Nothing there to cut")
		return {}
	stream.call("crater", hit["point"], 4.0 / v)
	_craters += 1
	var at: Vector4 = stream.call("to_global", hit["point"])
	Chips.spawn(self, at, Vector4(0, 1, 0, 0), [Color(0.40, 0.74, 0.22), Color(0.56, 0.32, 0.12), Color(0.34, 0.34, 0.34)], 30, 0.5, 9.0)
	_audio.stream = Sound.crunch(1.0, 0.55)
	_audio.play()
	return hit


func frame_numbers() -> Dictionary:
	if _frames.is_empty():
		return {"median": 0.0, "worst": 0.0}
	var s: Array = _frames.duplicate()
	s.sort()
	return {"median": float(s[s.size() / 2]), "worst": float(s[-1]), "p95": float(s[int(s.size() * 0.95)])}


func back_to_lab() -> void:
	input_enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# The lab places you at the gallery's back door when you come back from here.
	var lab = load("res://ramon/VoxelLab/voxel_lab_4d.gd")
	lab.arrive_from = "field"
	get_tree().change_scene_to_file(LAB)
