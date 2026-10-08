extends Node4D

## The Voxel Lab's field: through the gallery's back door, Andrew's landscape (4Denthusiast's test
## scene, his generators and numbers) generated round you as you fly over it. Plan steps 67 to 72
## (VoxelLab/PLAN.md, part H; Ramon, 6 Oct: "maybe we can explore seeing an open world option").
##
## A ROOM YOU WALK INTO (Ramon, 8 Oct: "a completely new TSCN that you walk into ... a sci-fi door that
## you can go through to teleport back ... this blue shimmer that you walk through to get there. Keep the
## design minimal and basic"). Through the shimmer in the gallery's far door you step out on a survey
## deck floating over his landscape, the shimmer behind you to go back. On the deck you walk (the deck
## has railings; the voxels have no collision yet, so the land is for looking and flying): 1 flies you
## over it, 2 changes the land (green, a Nevada desert, a lava field). The numbers stay on screen: how
## far the world loads round you, how many chunks and tetrahedra that is, the memory, the frame time and
## the chunks still waiting to be drawable. Change the radius and watch what it costs.
##
## FLYING (1 on the deck; H or Esc lands you back on it):
##   mouse        look (the cursor is held while you fly; Tab frees it)
##   WASD         fly, Space and C up and down, Shift faster
##   Q / E        through W (the world is a band of W either side of 0)
##   wheel        turn the slice into W and back
##   click        a crater: a 4D ball of air where you look
##   [ / ]        the load radius, smaller or larger
##   T            new chunks drawable from a worker thread (the lab's swap), or the engine's own way
##   V            the volume view: everything ana and kata of you, faintly
##   H or Esc     land on the deck
##
## NO class_name (engine_gotchas.md).

const Stream := preload("res://ramon/VoxelLab/field/vl_stream_4d.gd")
const TetRay := preload("res://ramon/VoxelLab/specimen/vl_tet_ray.gd")
const Style := preload("res://ramon/VoxelLab/carried/kit/kit_style.gd")
const Hud := preload("res://ramon/VoxelLab/field/vl_field_hud.gd")
const Chips := preload("res://ramon/VoxelLab/room/vl_chips_4d.gd")
const Sound := preload("res://ramon/VoxelLab/room/vl_sound.gd")
const KitPlayer := preload("res://ramon/VoxelLab/carried/kit/kit_player.gd")
const Shimmer := preload("res://ramon/VoxelLab/room/vl_shimmer_4d.gd")
const Choice := preload("res://ramon/VoxelLab/room/vl_choice.gd")
const Case := preload("res://ramon/VoxelLab/stations/vl_case_exhibit_4d.gd")
const LoadBoard := preload("res://ramon/VoxelLab/room/vl_load_board.gd")

const LAB := "res://ramon/VoxelLab/voxel_lab.tscn"
const RADII := [16.0, 24.0, 32.0, 40.0, 48.0, 64.0]

## Where the survey deck floats (a little above where you stand on it): low enough that his hills stand
## round you (at 30 m the land was below the deck's edge and you saw only sky, 9 Oct).
@export var start_at: Vector4 = Vector4(0, 21, 34, 0)
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
## "deck" (walking on the survey deck) or "fly" (the survey camera).
var mode: String = "deck"
var player: CharacterBody4D
var choice: Control
var biome: int = 0
var _deck_at: Vector4
var _leaving: bool = false
## The loading board while the ground round the deck is built (vl_load_board.gd); true until it is gone.
var loading: bool = true
var _board: Control
var _board_t: float = 0.0
var _board_read: float = 0.0
var _board_chunks: int = -1
var _board_still: float = 0.0
## 40 m to start: from the deck you look out over the rails, and at 24 m the land you could see was all
## hidden under the deck itself (9 Oct). The lab is let go while you are here, so its memory is free.
var _radius_i: int = 3
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
	_deck()
	cam = Camera4D.new()
	cam.name = "SurveyCamera"
	cam.rendering_engine_name = "Cross-section"
	# The ground fades into the sky toward the edge of what is loaded, instead of ending in a cliff.
	cam.set("depth_fade_mode", 1)
	cam.set("depth_fade_start", float(RADII[_radius_i]) * 0.55)
	cam.position = start_at
	add_child(cam)
	_place_cam()
	# On the deck, walking: the kit's player, its camera behind you.
	player = KitPlayer.make()
	add_child(player)
	# Out of the door and a few steps on: the camera behind you stays on the deck's side of the shimmer.
	player.global_position = _deck_at + Vector4(0, 0.25, -2.0, 0)
	player.set("_facing", PI)
	var rig: Node = player.get_node_or_null("CameraRig")
	if rig != null:
		rig.set("slice_turning", false)
		rig.set("yaw", 0.0)
		rig.set("pitch", deg_to_rad(-24.0))
		rig.call("_apply")
	var pc: Camera4D = player.get_node_or_null("CameraRig/Pitch/Camera4D") as Camera4D
	if pc != null:
		pc.set("depth_fade_mode", 1)
		pc.set("depth_fade_start", float(RADII[_radius_i]) * 0.55)
		pc.make_current()
	stream.set("follow", player)
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Control.new()
	hud.set_script(Hud)
	hud.set("field", self)
	layer.add_child(hud)
	choice = Control.new()
	choice.set_script(Choice)
	layer.add_child(choice)
	choice.set("heading", "THE OPEN WORLD  ·  OUR LANDSCAPE, WITHOUT EDGES")
	choice.connect("chosen", _on_choice)
	_open_board()
	_audio = AudioStreamPlayer.new()
	_audio.volume_db = -4.0
	add_child(_audio)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Through the door: the board, while the world builds behind it at full speed (no warm-up: its
## frame spikes are on nobody's screen), then white, then the deck.
func _open_board() -> void:
	_board = LoadBoard.open(self)
	_board.set("kicker", "VOXEL LAB  ·  THROUGH THE DOOR")
	_board.set("title", "THE OPEN WORLD")
	_board.set("subtitle", "Our landscape, without edges, generated as you go")
	_board.set("credit", "Landscape generators adapted from the work of Andrew (4Denthusiast)")
	_board.set("coming", ["A deck over the landscape, the door back behind you",
		"1 flies you over it, 2 changes the land",
		"The numbers stay with you: what it costs to see this far"])
	_board.set("diagram_title", "CHUNKS ROUND THE DECK, AS THE ENGINE BUILDS THEM")
	_board.connect("finished", func() -> void:
		loading = false
		_board = null
		player.set("input_enabled", true))
	player.set("input_enabled", false)
	warm_up = 0.0
	_age = 1.0
	stream.set("radius", float(RADII[_radius_i]))


## The probe flies at once and measures from the first frame.
func close_board() -> void:
	if _board != null:
		_board.call("close_now")


func _feed_board(delta: float) -> void:
	_board_t += delta
	_board_read -= delta
	if _board_read > 0.0:
		return
	_board_read = 0.2
	var st: Dictionary = stream.call("stats")
	var n: int = int(st.get("chunks", 0))
	_board_still = _board_still + 0.2 if n == _board_chunks else 0.0
	_board_chunks = n
	var r: float = float(stream.get("radius"))
	var p: Vector4 = player.global_position
	var dots: Array = []
	for ch in stream.call("chunk_nodes"):
		var c: Vector4 = (ch as Node4D).global_position + Vector4(4, 0, 4, 0) * float(stream.get("voxel"))
		dots.append([Vector2((c.x - p.x) / r, (c.z - p.z) / r), (ch as MeshInstance4D).visible])
	_board.set("dots", dots)
	_board.set("numbers", [["Chunks built", str(n)], ["Tetrahedra", _thousands(int(st.get("tets", 0)))], ["Video memory", "%.0f MB" % float(st.get("mb", 0.0))],
		["Load radius", "%.0f m" % (r * float(stream.get("voxel")))]])
	_board.set("progress", clampf(_board_t / 9.0, 0.0, 0.95) if _board_still < 1.2 else 1.0)
	if (_board_t > 3.0 and n > 0 and int(st.get("waiting", 0)) == 0 and _board_still >= 1.2) or _board_t > 25.0:
		_board.set("progress", 1.0)
		_board.call("finish")


static func _thousands(v: int) -> String:
	var s: String = str(v)
	var out: String = ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out


## The survey deck: a blue floor floating over the land, railings round it that you cannot walk
## through, and the shimmer back to the lab at its back edge.
func _deck() -> void:
	_deck_at = start_at - Vector4(0, 2.2, 0, 0)
	var size := Vector4(8.0, 0.4, 8.0, 6.0)
	_solid("Deck", _deck_at - Vector4(0, 0.2, 0, 0), size, Style.pick(Style.CODE_BLUE))
	var rail := Color(0.85, 0.92, 1.0)
	for r in [[Vector4(0, 0.55, -4.0, 0), Vector4(8.0, 1.1, 0.08, 6.0)], [Vector4(-4.0, 0.55, 0, 0), Vector4(0.08, 1.1, 8.0, 6.0)],
			[Vector4(4.0, 0.55, 0, 0), Vector4(0.08, 1.1, 8.0, 6.0)], [Vector4(-2.6, 0.55, 4.0, 0), Vector4(2.8, 1.1, 0.08, 6.0)],
			[Vector4(2.6, 0.55, 4.0, 0), Vector4(2.8, 1.1, 0.08, 6.0)]]:
		_solid("Rail", _deck_at + (r[0] as Vector4), r[1], Color(rail, 1.0), true)
	# The way back, at the back of the deck, between the two short rails.
	var sh := Node4D.new()
	sh.name = "Shimmer"
	sh.set_script(Shimmer)
	sh.set("width", 2.4)
	sh.set("height", 3.0)
	sh.position = _deck_at + Vector4(0, 0, 4.0, 0)
	add_child(sh)


## A box you cannot walk through: a mesh and a static body.
func _solid(nm: String, at: Vector4, size: Vector4, col: Color, thin: bool = false) -> void:
	var body := StaticBody4D.new()
	body.name = nm
	body.position = at
	add_child(body)
	var shape := CollisionShape4D.new()
	var bs := BoxShape4D.new()
	bs.size = size
	shape.shape = bs
	body.add_child(shape)
	var mi := MeshInstance4D.new()
	var box := BoxTetraMesh4D.new()
	box.size = Vector4(size.x, 0.04 if thin else size.y, size.z, size.w) if thin else size
	mi.mesh = box
	if thin:
		mi.position = Vector4(0, size.y * 0.5, 0, 0)
	var m := TetraMaterial4D.new()
	m.albedo_color = col
	mi.material_override = m
	body.add_child(mi)


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
	if _board != null:
		_feed_board(delta)
		choice.set("shown", false)
		return
	if mode == "deck":
		_on_deck()
		return
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


## On the deck: the choice while you stand on it, and the shimmer behind you back to the lab.
func _on_deck() -> void:
	choice.set("shown", input_enabled)
	choice.set("options", [{"key": "1", "id": "fly", "icon": "fly", "label": "Fly over it"},
		{"key": "2", "id": "biome", "icon": "globe", "label": "Change the land (now %s)" % String(Case.BIOMES[biome]["name"])}])
	var p: Vector4 = player.global_position
	if not _leaving and p.z > _deck_at.z + 3.7 and absf(p.x - _deck_at.x) < 1.2:
		_leaving = true
		get_node("Shimmer").call("flash_out", self, back_to_lab)
	# Fallen off somehow: back on the deck.
	if p.y < _deck_at.y - 6.0:
		player.global_position = _deck_at + Vector4(0, 0.25, 0, 0)


func _on_choice(i: int) -> void:
	if i == 0:
		fly()
	else:
		biome = (biome + 1) % Case.BIOMES.size()
		var colors: Dictionary = Case.BIOMES[biome]["colors"]
		var list := PackedColorArray()
		for m in 5:
			list.append(colors.get(m, Color.WHITE))
		var pal = ClassDB.instantiate("VoxelMaterialPalette4D")
		pal.set("colors", list)
		stream.get("world").set("material_palette", pal)
		hud.call("toast", "The land: " + String(Case.BIOMES[biome]["name"]))


## From the deck into the air: the survey camera, where your view was.
func fly() -> void:
	var pc: Camera4D = player.get_node_or_null("CameraRig/Pitch/Camera4D") as Camera4D
	if pc != null:
		cam.global_position = pc.global_position
		var f: Vector4 = -(pc.global_basis * Vector4(0, 0, 1, 0))
		yaw = atan2(-f.x, -f.z)
		pitch = clampf(atan2(f.y, Vector2(f.x, f.z).length()), -1.45, 1.2)
	_place_cam()
	cam.make_current()
	player.set("input_enabled", false)
	stream.set("follow", cam)
	mode = "fly"
	choice.set("shown", false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hud.call("toast", "Flying. H lands you on the deck.")


## Back on the deck, as you were.
func land() -> void:
	mode = "deck"
	player.set("input_enabled", true)
	stream.set("follow", player)
	var pc: Camera4D = player.get_node_or_null("CameraRig/Pitch/Camera4D") as Camera4D
	if pc != null:
		pc.make_current()
	if volume_view:
		set_volume_view(false)


func _input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if mode == "deck":
		# On the deck only the radius and the worker switch; the rest is the walker's.
		var kd := event as InputEventKey
		if kd != null and kd.pressed and not kd.echo:
			match kd.keycode:
				KEY_BRACKETLEFT:
					set_radius_index(_radius_i - 1)
				KEY_BRACKETRIGHT:
					set_radius_index(_radius_i + 1)
				KEY_T:
					stream.set("swap", not bool(stream.get("swap")))
					hud.call("toast", "New chunks drawable from a worker thread" if bool(stream.get("swap")) else "New chunks built in the frame: the engine's way")
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
			land()


func set_radius_index(i: int) -> void:
	_radius_i = clampi(i, 0, RADII.size() - 1)
	_age = warm_up + 1.0
	stream.set("radius", float(RADII[_radius_i]))
	cam.set("depth_fade_start", float(RADII[_radius_i]) * 0.55)
	var pc: Camera4D = player.get_node_or_null("CameraRig/Pitch/Camera4D") as Camera4D if player != null else null
	if pc != null:
		pc.set("depth_fade_start", float(RADII[_radius_i]) * 0.55)
	hud.call("toast", "Load radius %.0f m" % (float(RADII[_radius_i]) * float(stream.get("voxel"))))


func set_volume_view(on: bool) -> void:
	volume_view = on
	var tree: SceneTree = get_tree()
	if tree.root.world_3d == null:
		tree.root.world_3d = World3D.new()
	cam.set("rendering_engine_name", "Combined" if on else "Cross-section")
	cam.set("projection_opacity_base", 0.12)
	if not on:
		cam.set("depth_fade_mode", 1)
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
