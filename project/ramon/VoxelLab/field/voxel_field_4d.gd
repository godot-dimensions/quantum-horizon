extends Node4D

## The Voxel Lab's field: through the gallery's back door, our landscape (adapted from 4Denthusiast's
## test scene, his generators and numbers), an island of it built round a survey deck in a moving sea.
## Plan steps 67 to 72 (VoxelLab/PLAN.md, part H; Ramon, 6 Oct: "maybe we can explore seeing an open
## world option").
##
## A ROOM YOU WALK INTO (Ramon, 8 Oct: "a completely new TSCN that you walk into ... a sci-fi door that
## you can go through to teleport back ... this blue shimmer that you walk through to get there. Keep the
## design minimal and basic"). Through the shimmer in the gallery's far door you step out on a survey
## deck floating over the land, the shimmer behind you to go back. On the deck you walk; it has railings
## (the engine's fence generator) and the lab's blue.
##
## LOOK FIRST, THEN FLY (Ramon, 9 Oct: "how will the flying work even? think of a way that makes sense
## ... maybe look first, and then with a panel it can ask you to fly"). You arrive with nothing on
## screen but the view. Round 4: two matching stations at the front of the grey deck, either side of the
## walkway, the route branching to each: Take off on the left, Change the world on the right, each the
## lab's floating panel with a ring before it; stand in a ring and 1 does it.
##
## THE DECK (round 4): the grey deck, a 4 m pier on to a round blue platform after the Water Lab
## harbour's (TURN THE SLICE printed in it, a lighter ring turning on it). Anywhere on the blue the right
## mouse turns the slice (the world turns round you, the platform stays level, as in the harbour), R
## levels it again, and a card shows the mouse doing it for ten seconds (the Water Lab's mouse tutorial,
## carried). No limit, nothing levels it by itself while you stand on the blue: off the platform it goes
## level. No turning gizmo (round 3, item 20: the blue and the card say it).
##
## THE WALKER AND THE TURNING ARE THE PLAYABLE WORLD'S (round 4): the pen's walker and camera rig (the
## carried scripts, line for line), its step through W (Q / E), its camera preset (8 m back), the wheel
## zooming freely.
##
## THE LIGHT AND SKY ARE THE HARBOUR'S (round 3: "reuse that overall lighting and atmospheric setup"):
## its saved tuning (WaterLab/seascape/seascape_tuning.cfg, 9 Oct), the low sun, the gradient sky and
## the volumetric clouds; Tab has the sun, the light and the sea, and SAVE keeps them.
##
## AS A BIRD, IN A CIRCLE (Ramon, 9 Oct: "this flying over seems a bit weird though, how it builds as
## you're moving ... rather just fly as a bird or something and have a collision so its limited in a
## circle of flying, and you can rotate the slice while flying"). Nothing is streamed round you any
## more: the world is built once, round the deck, behind the loading board (BUILT_RADIUS round it and
## W_CHUNKS of 8 m either side of W 0, so a turned slice still has land in it), and nothing builds while
## you fly. You fly from a bird's eyes (vl_bird_4d.gd, the Lookout hawk's feel) inside a circle
## `fly_margin` metres short of the edge of what is built; near the edge a hologram shows the wall and
## you are turned back. The ground is read off the built meshes into a height map while the board is up
## (the voxels have no collision), so you cannot fly into a hill. 1, H or Esc: back on the deck.
##
## THE SEA: Trym's moving sea as the Water Lab has it (used from there), a kilometre out, over open seabed (the green land's
## voxel sea is air; the desert's salt flats and the lava field keep the generator's own sea). Tab: its
## settings (vl_sea_panel.gd), saved, and read back as the field starts.
##
## The numbers stay on screen: how much is built, the chunks and tetrahedra, the memory, the frame time.
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
## Trym's sea as the Water Lab has it now (round 4: "bring its water presets ... avoid maintaining
## unnecessary duplicated systems"): used from there, not copied again.
const WaterSurface := preload("res://ramon/WaterLab/carried/water4d/water4d_surface.gd")
## The same water, one graded mesh instead of a square and a ring, the shore foam patched to be set
## (round 5, #46 and #48).
const Sea := preload("res://ramon/VoxelLab/field/vl_sea_4d.gd")
## The pen's grass on a few patches of the island (round 5, #49), carried.
const Grass := preload("res://ramon/VoxelLab/carried/grass/vl_grass_4d.gd")
const GRASS_PATCHES := 6
const GRASS_W_REACH := 6.0
const LabGrid := preload("res://ramon/VoxelLab/carried/LabKit/lab_grid.gd")
const Mats := preload("res://ramon/VoxelLab/carried/LabKit/lab_materials.gd")
const Build := preload("res://ramon/VoxelLab/carried/scripts/chamber_build.gd")
const FloatPanel := preload("res://ramon/VoxelLab/room/vl_float_panel_4d.gd")
const Bird := preload("res://ramon/VoxelLab/field/vl_bird_4d.gd")
const SeaPanel := preload("res://ramon/VoxelLab/field/vl_sea_panel.gd")
const MouseTutorial := preload("res://ramon/VoxelLab/field/vl_mouse_tutorial.gd")
const Ground := preload("res://ramon/VoxelLab/carried/LabKit/carried/chickenpen/scripts/ground_basis_4d.gd")
const LandShader := preload("res://ramon/VoxelLab/shaders/vl_voxel_land.gdshader")
const WallPanel := preload("res://ramon/VoxelLab/carried/kit/panels/kit_wall_panel_4d.gd")
const RoomInfo := preload("res://ramon/VoxelLab/carried/kit/panels/kit_room_info.gd")
const PanelSpec := preload("res://ramon/VoxelLab/carried/kit/panels/kit_panel_spec.gd")
const PathNet := preload("res://ramon/VoxelLab/carried/PathCreator/graph/path_network_4d.gd")
const PathGraph := preload("res://ramon/VoxelLab/carried/PathCreator/graph/path_graph.gd")

const LAB := "res://ramon/VoxelLab/voxel_lab.tscn"
## What is built round the deck, metres (a 4D ball, cut to the band of W and of height), and how many
## 8 m chunks either side of W 0. Changed in code only: every metre more is more to build and keep.
## Each voxel 1.6 m (round 4: "scale up the existing island meshes uniformly rather than generating
## higher-resolution geometry"): the same voxel counts as before, the land 1.6 times larger.
const VOXEL_M := 1.6
const BUILT_RADIUS := 40.0 * VOXEL_M
const W_CHUNKS := 2
## The island: land within this many voxels of the middle, stepping down to the seabed past it (the
## stream's rings), all inside what is built (40 voxels); and the land's height (Andrew's 12.32, lower).
const ISLAND_VOXELS := 21.0
const LAND_INTENSITY := 6.5
## The distant birds: the Water Lab's gulls, a few, far out and high (round 4: "a few small birds in
## the distance ... lightweight"; ~25 us of script a gull).
const Gulls := preload("res://ramon/WaterLab/gull/gull_flock_4d.gd")
const GULLS := 6
## The playable world's walker settings (round 4, Ramon: "make sure we're using Andrew's walker and W
## rotation settings from the playable world"): its step through W (Q / E) at the walker's own 0.3, and
## its camera preset 2 (8 m back, pivot 1.5 m, 15 degrees down; playable_world.tscn CameraRig
## start_preset 1), the wheel zooming freely (round 4: "keep the existing middle-mouse-button zoom"),
## its camera's W fade at 6 m. The walker and rig scripts are the pen's own (carried, line for line).
const PEN_W_STEP := 0.3
const PEN_PRESET := 1
const PEN_W_FADE := 6.0
## The bird's band of W, either side of 0, metres: inside the built band with room to see past it.
const BIRD_W := 6.0
## The height map's cells in W, metres (1 m in x and z).
const H_W := 2.0

## Where the survey deck floats (a little above where you stand on it): low enough that the hills stand
## round you (at 30 m the land was below the deck's edge and you saw only sky, 9 Oct).
@export var start_at: Vector4 = Vector4(0, 21, 34, 0)
## The bird's circle is this much short of the edge of what is built, so there is land beyond you
## whichever way you look.
@export var fly_margin: float = 9.0

var stream: Node4D
var hud: Control
var volume_view: bool = false
var input_enabled: bool = true
## "deck" (walking on the survey deck) or "fly" (the bird).
var mode: String = "deck"
## The deck and everything on it (the grey deck, the pier, the platform, the stations, the door home).
var raft: Node4D
var env: WorldEnvironment4D
var sun: DirectionalLight4D
var tutorial: Control
## The platform's level frame (the disc and its rail), held level while the slice turns (_hold_set).
var _set: Node4D
## "platform" while you stand inside the platform's ring, else "".
var site: String = ""
var _turned_here: bool = false
var _pivot: Vector4
var _visual: Vector4
## The land look (shaders/vl_voxel_land.gdshader) and the palette it was made from.
var _land_mat: TetraMaterial4D
var _land_tex: Texture3D
var _land_check: float = 0.0
var player: CharacterBody4D
var choice: Control
var biome: int = 0
var _deck_at: Vector4
var _leaving: bool = false
## The loading board while the world round the deck is built (vl_load_board.gd); true until it is gone.
var loading: bool = true
var _board: Control
var _board_t: float = 0.0
var _board_read: float = 0.0
var _board_chunks: int = -1
var _board_still: float = 0.0
## Trym's sea (the Water Lab's), a little above the land's sea level, so the islands stand in a sea
## that moves (Ramon, 9 Oct: "fake the water in an amazing way"). Only with the green land.
var water: Node4D
var sea_panel: Control
## The bird (vl_bird_4d.gd) and its eyes.
var bird: Node
var bird_cam: Camera4D
## The middle of what is built and of the bird's circle: under the deck.
var _centre: Node4D
## The hologram at the circle's edge, shown as you come near it.
var _edge: MeshInstance4D
var _edge_cs: ShaderMaterial
## The height map: the top of the land in 1 m columns (x, z) and H_W m bands of W, read off the built
## meshes on a worker thread while the board is up.
var _heights := PackedFloat32Array()
var _hx0: float = 0.0
var _hz0: float = 0.0
var _hw0: float = 0.0
var _hn := Vector3i.ZERO
var _grid_task: int = -1
var _grid_jobs: Array = []
var _grid_out := PackedFloat32Array()
var height_map_ms: float = 0.0
var _grid_t0: int = 0
## Seconds the board took to build the world, for the numbers.
var build_seconds: float = 0.0
## The grass patches (carried/grass/vl_grass_4d.gd): made once the ground is mapped, its heights baked on a
## worker thread from the chunks under the patches; on or off and its blade width from Tab.
var grass: Node4D
var grass_ms: float = 0.0
var _grass_task: int = -1
var _grass_jobs: Array = []
var _grass_out := PackedFloat32Array()
var _grass_plan: Dictionary = {}
var _grass_on: bool = true
var _grass_width: float = 2.2
var _grass_height: float = 0.7
var _grass_colour: Color = Color(0, 0, 0, 0)
var _frames: Array = []
var _last_us: int = 0
var _audio: AudioStreamPlayer
var _craters: int = 0
var _crater_hold: Array = []


func _ready() -> void:
	_light()
	_deck_at = start_at - Vector4(0, 2.2, 0, 0)
	_centre = Node4D.new()
	_centre.name = "Centre"
	_centre.position = Vector4(_deck_at.x, 0.0, _deck_at.z, 0.0)
	add_child(_centre)
	stream = _new_stream(254)
	_paint_land()
	# The lab's colours, as the lab left them; opened on its own, the bright ones (else the deck's blue
	# is the grid's default grey).
	if not LabGrid._values.has("kit_code_blue"):
		Style.apply("bright")
	_make_sea(900.0)
	_seabed()
	SeaPanel.apply_all(water, SeaPanel.saved())
	apply_light(SeaPanel.saved())
	apply_land(SeaPanel.saved())
	var sv: Dictionary = SeaPanel.saved()
	set_grass(float(sv.get("grass", 1.0)) > 0.5, float(sv.get("grass_width", 2.2)), float(sv.get("grass_height", 0.7)),
		Color(float(sv.get("grass_r", 0.31)), float(sv.get("grass_g", 0.49)), float(sv.get("grass_b", 0.16))))
	_birds()
	_deck()
	# On the deck, walking: the kit's player, its camera behind you.
	player = KitPlayer.make()
	player.set("w_speed_scale", PEN_W_STEP)
	var prig: Node = player.get_node_or_null("CameraRig")
	if prig != null:
		# Set before it enters the tree: the rig takes its preset in its _ready. Tab is the settings
		# panel here, and T the worker switch, so neither cycles or locks the camera (the pen: lock_key 0).
		prig.set("start_preset", PEN_PRESET)
		prig.set("cycle_key", KEY_NONE)
		prig.set("lock_key", KEY_NONE)
	add_child(player)
	for st in stations:
		(st as Node).set("player", player)
	# Out of the door and a few steps on (the camera behind you stays on the deck's side of the shimmer),
	# looking out over the platform: you look first.
	player.global_position = _deck_at + Vector4(0, 0.25, ARRIVE_Z, 0)
	player.set("_facing", PI)
	var rig: Node = player.get_node_or_null("CameraRig")
	if rig != null:
		rig.set("slice_turning", false)
		rig.set("yaw", 0.0)
		rig.call("_apply")
	var pc: Camera4D = _walker_cam()
	if pc != null:
		# The land fades into the sky toward the edge of what is built, instead of ending in a cliff.
		pc.set("depth_fade_mode", 1)
		pc.set("depth_fade_start", BUILT_RADIUS * 0.55)
		pc.set("w_fade_distance", PEN_W_FADE)
		pc.make_current()
	bird_cam = Camera4D.new()
	bird_cam.name = "BirdEye"
	bird_cam.rendering_engine_name = "Cross-section"
	bird_cam.set("depth_fade_mode", 1)
	bird_cam.set("depth_fade_start", BUILT_RADIUS * 0.55)
	add_child(bird_cam)
	bird = Node.new()
	bird.name = "Bird"
	bird.set_script(Bird)
	bird.set("camera", bird_cam)
	bird.set("field", self)
	add_child(bird)
	_make_edge()
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Control.new()
	hud.set_script(Hud)
	hud.set("field", self)
	layer.add_child(hud)
	choice = Control.new()
	choice.set_script(Choice)
	layer.add_child(choice)
	choice.set("heading", "THE OPEN WORLD  ·  OUR LANDSCAPE, AN ISLAND OF IT")
	choice.connect("chosen", _on_choice)
	sea_panel = PanelContainer.new()
	sea_panel.set_script(SeaPanel)
	sea_panel.set("field", self)
	layer.add_child(sea_panel)
	tutorial = Control.new()
	tutorial.set_script(MouseTutorial)
	tutorial.set("gestures", [["drag_h", "TURN THE SLICE"], ["drag_v", "TURN IT THE OTHER WAY"]])
	tutorial.set("footer", "R  ·  LEVEL AGAIN")
	layer.add_child(tutorial)
	if not RenderingServer4D.pre_render.is_connected(_on_pre_render):
		RenderingServer4D.pre_render.connect(_on_pre_render)
	_open_board("VOXEL LAB  ·  THROUGH THE DOOR", "Our landscape, an island of it, built round a deck in the sea",
		["A deck over the land, the door back behind you", "On the blue platform, turn the slice: the world turns round you",
			"Two stations: take off as a bird, or change the world"])
	_audio = AudioStreamPlayer.new()
	_audio.volume_db = -4.0
	add_child(_audio)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## The Water Lab harbour's light and sky (seascape.tscn and its saved tuning, seascape_tuning.cfg, as
## of 9 Oct): a gradient sky with volumetric clouds over it, a cool ambient half from the sky, a low
## warm sun. The sun, the ambient and the exposure are the Tab panel's (apply_light).
func _light() -> void:
	env = WorldEnvironment4D.new()
	env.name = "Environment"
	var sky := GradientSkyMaterial4D.new()
	sky.horizon_color = Color(0.62, 0.69, 0.76)
	sky.top_color = Color(0.17, 0.35, 0.62)
	sky.top_curve = 0.18
	sky.bottom_color = Color(0.08, 0.12, 0.18)
	sky.bottom_curve = 0.05
	sky.sun_curve = 0.121
	sky.set("sun_angle_max", deg_to_rad(30.0))
	sky.set("energy_multiplier", 1.0)
	env.sky_material = sky
	var clouds = ClassDB.instantiate("VolumetricCloudMaterial4D")
	if clouds != null:
		for kv in [["sampling_method", 1], ["sampling_steps", 64], ["bottom_height", 850.0], ["vertical_thickness", 951.0],
				["maximum_ray_distance", 20000.0], ["distance_fade_curve", 0.25], ["distance_fade_start", 0.0], ["coverage", 0.56],
				["density", 0.951], ["shape_scale", 2400.0], ["shape_fractal_strength", 0.701], ["detail_scale", 300.0],
				["detail_strength", 0.48], ["animation_enabled", true], ["wind_velocity", Vector4(12, 0, 3.7, 2.1)], ["evolution_speed", 0.004],
				["albedo_color", Color(0.95, 0.95, 0.94)], ["ambient_color", Color(0.44, 0.51, 0.62)], ["ambient_intensity", 0.48],
				["sun_intensity", 1.001], ["phase_anisotropy", 0.5], ["affect_radiance", true], ["extinction_coefficient", 0.0019],
				["shadow_distance", 600.0], ["shadow_strength", 0.548]]:
			clouds.set(String(kv[0]), kv[1])
		env.set("cloud_material", clouds)
	env.ambient_light_sky_contribution = 0.225
	env.tonemap_mode = 2
	env.set("tonemap_white", 1.0)
	add_child(env)
	env.make_current()
	sun = DirectionalLight4D.new()
	sun.name = "Sun"
	sun.light_color = Color(1.0, 0.976, 0.934)
	sun.set("angular_radius_degrees", 0.0811)
	add_child(sun)


## The sun, the ambient and the exposure from the Tab panel's values (vl_sea_panel.gd).
func apply_light(v: Dictionary) -> void:
	if sun == null or env == null:
		return
	var h: float = deg_to_rad(float(v.get("sun_up", 10.5)))
	var t: float = deg_to_rad(float(v.get("sun_turn", 137.5)))
	var dir := Vector4(cos(h) * sin(t), sin(h), cos(h) * cos(t), 0.0)
	# The sun sits along its +Z; the light travels along -Z (seascape_hud.gd set_sun_angles).
	sun.basis = Basis4D.looking_at(-dir)
	sun.light_energy = float(v.get("sun", 0.064))
	var amb: float = float(v.get("ambient", 1.0))
	env.ambient_light_color = Color(0.565, 0.639, 0.742) * amb
	env.set("tonemap_exposure", float(v.get("exposure", 0.99)))


## The camera's 4D frame into the land look's shader (it works out where each fragment is in the
## world from it), just before each frame of the main view is drawn.
func _on_pre_render(camera: Camera4D, viewport: Viewport, _engine: RenderingEngine4D) -> void:
	if _land_mat == null or viewport != get_viewport() or not camera.current:
		return
	var cs: ShaderMaterial = _land_mat.get_cross_section_material_3d()
	var b: Projection = camera.global_basis
	cs.set_shader_parameter("cam_origin", camera.global_position)
	cs.set_shader_parameter("cam_x", b.x)
	cs.set_shader_parameter("cam_y", b.y)
	cs.set_shader_parameter("cam_z", b.z)
	cs.set_shader_parameter("cam_w", b.w)


## The land look on the stream's chunks, made from the palette the engine draws them with; made again
## when that palette changes (another land).
func _land_look(delta: float) -> void:
	_land_check -= delta
	if _land_check > 0.0 or stream == null:
		return
	_land_check = 0.5
	var tex: Texture3D = null
	for ch in stream.call("chunk_nodes"):
		var mesh: Mesh4D = (ch as MeshInstance4D).mesh as Mesh4D
		var mat: Resource = mesh.get("material") if mesh != null else null
		if mat is TetraMaterial4D and mat.get("albedo_texture_3d") != null:
			tex = mat.get("albedo_texture_3d")
			break
	if tex == null or (tex == _land_tex and stream.get("chunk_material") == _land_mat):
		return
	_land_tex = tex
	_land_mat = TetraMaterial4D.new()
	_land_mat.albedo_source = TetraMaterial4D.TETRA_COLOR_SOURCE_TEXTURE3D_CELL_UVW_ONLY
	# The shader before the texture (engine_gotchas.md, as vl_grid_view.gd).
	_land_mat.get_cross_section_material_3d().shader = LandShader
	_land_mat.albedo_texture_3d = tex
	stream.call("set_chunk_material", _land_mat)


## The landscape round the deck: built once, not streamed (the trigger stays at the middle).
func _new_stream(sea: int) -> Node4D:
	var s := Node4D.new()
	s.name = "Stream"
	s.set_script(Stream)
	s.set("voxel", VOXEL_M)
	s.set("radius", 8.0)
	s.set("y_range", Vector2i(-16, 16))
	s.set("w_chunks", W_CHUNKS)
	s.set("island_radius", ISLAND_VOXELS)
	s.set("island_centre", Vector4(_deck_at.x, 0.0, _deck_at.z, 0.0) / VOXEL_M)
	s.set("land_intensity", LAND_INTENSITY)
	s.set("ahead", 0.0)
	s.set("sea_material", sea)
	add_child(s)
	s.set("follow", _centre)
	return s


## The sea: the Water Lab's water, as one graded mesh out to `reach` (field/vl_sea_4d.gd: the square
## edge of its 120 m grid showed from the deck).
func _make_sea(reach: float) -> void:
	water = Node4D.new()
	water.name = "Sea"
	water.set_script(Sea)
	water.set("reach", reach)
	add_child(water)
	water.visible = biome == 0


## A plain seabed under the whole sea, a little under the built one (round 5: from the air the built
## square showed through the clear water, its seabed lighter than the nothing past it). The stream's own
## seabed is a plane of stone `rings + 3` ring drops down (vl_stream_4d.gd); this one lies 0.4 m under it,
## so where the land is built the voxel seabed covers it, and past it this one does. With the green land
## only, as the moving sea.
var _bed: MeshInstance4D


func _seabed() -> void:
	var drop: float = float(int(stream.get("rings")) + 3) * float(stream.get("ring_drop")) * VOXEL_M
	_bed = MeshInstance4D.new()
	_bed.name = "Seabed"
	_bed.mesh = Mats.box_mesh(Vector4(1800.0, 1.0, 1800.0, 400.0))
	_bed.position = Vector4(_deck_at.x, -drop - 0.4 - 0.5, _deck_at.z, 0.0)
	_bed.material_override = Mats.flat((Case.BIOMES[0]["colors"] as Dictionary)[2])
	_bed.visible = biome == 0
	add_child(_bed)


## The land's own colour from the Tab panel (round 4: "adjust the island's primary terrain color ...
## hues, saturation, and brightness ... save the selected colors as defaults").
func apply_land(v: Dictionary) -> void:
	_grass = Color.from_hsv(float(v.get("land_h", 0.27)), float(v.get("land_s", 0.5)), float(v.get("land_v", 0.36)))
	if stream != null and stream.get("world") != null:
		_paint_land()


var _grass: Color = Color.from_hsv(0.27, 0.5, 0.36)


## The distant gulls (the Water Lab's flock, no perches, no calls): roaming 40 to 80 m round the
## island's middle, 20 to 40 m up.
func _birds() -> void:
	var flock := Node4D.new()
	flock.name = "Gulls"
	flock.set_script(Gulls)
	flock.set("count", GULLS)
	flock.set("home", Vector4(_deck_at.x, 30.0, _deck_at.z, 0.0))
	flock.set("roam_radius", 80.0)
	flock.set("altitude", Vector2(20.0, 40.0))
	flock.set("start_perched", 0.0)
	flock.set("sound_on", false)
	add_child(flock)


## The hologram at the edge of the circle: the shimmer's, a wall of it in front of you.
func _make_edge() -> void:
	var size := Vector4(22.0, 16.0, 0.05, 3.0)
	_edge = MeshInstance4D.new()
	_edge.name = "Edge"
	_edge.mesh = Mats.box_mesh(size)
	var m: TetraMaterial4D = LabGrid.material("kit_code_blue", size, Vector4.ZERO)
	_edge_cs = m.get_cross_section_material_3d()
	_edge_cs.set_shader_parameter("holo_on", 1.0)
	_edge_cs.set_shader_parameter("holo_base", 0.0)
	_edge_cs.set_shader_parameter("holo_falloff", 0.6)
	_edge_cs.set_shader_parameter("holo_color", Color(0.32, 0.66, 1.0))
	_edge_cs.set_shader_parameter("holo_glow", 0.9)
	_edge_cs.set_shader_parameter("holo_scan", 0.7)
	_edge_cs.set_shader_parameter("holo_scan_density", 0.6)
	_edge_cs.set_shader_parameter("holo_scan_speed", 0.3)
	_edge_cs.set_shader_parameter("holo_fine", 1.0)
	_edge.material_override = m
	_edge.visible = false
	add_child(_edge)


## Through the door: the board, while the world builds behind it at full speed (its frame spikes are on
## nobody's screen) and then the ground is mapped; then white, then the deck.
func _open_board(kicker: String, subtitle: String, coming: Array) -> void:
	loading = true
	_board_t = 0.0
	_board_read = 0.0
	_board_chunks = -1
	_board_still = 0.0
	_heights = PackedFloat32Array()
	_drop_grass()
	_board = LoadBoard.open(self)
	_board.set("kicker", kicker)
	_board.set("title", "THE OPEN WORLD")
	_board.set("subtitle", subtitle)
	_board.set("credit", "Landscape generators adapted from the work of Andrew (4Denthusiast)")
	_board.set("coming", coming)
	_board.set("diagram_title", "CHUNKS ROUND THE DECK, AS THE ENGINE BUILDS THEM")
	_board.connect("finished", func() -> void:
		loading = false
		_board = null
		player.set("input_enabled", mode == "deck"))
	player.set("input_enabled", false)
	stream.set("radius", BUILT_RADIUS / float(stream.get("voxel")))


## The probe measures without the board: it goes at once (the ground is still mapped when built).
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
	var c: Vector4 = _centre.global_position
	var dots: Array = []
	for ch in stream.call("chunk_nodes"):
		var at: Vector4 = (ch as Node4D).global_position + Vector4(4, 0, 4, 0) * float(stream.get("voxel"))
		dots.append([Vector2((at.x - c.x) / r, (at.z - c.z) / r), (ch as MeshInstance4D).visible])
	_board.set("dots", dots)
	_board.set("numbers", [["Chunks built", str(n)], ["Tetrahedra", _thousands(int(st.get("tets", 0)))], ["Video memory", "%.0f MB" % float(st.get("mb", 0.0))],
		["Built round the deck", "%.0f m" % (r * float(stream.get("voxel")))]])
	var built: bool = (_board_t > 3.0 and n > 0 and int(st.get("waiting", 0)) == 0 and _board_still >= 1.2) or _board_t > 60.0
	_board.set("progress", clampf(_board_t / 16.0, 0.0, 0.9) if not built else 0.95)
	_map_ground(built)
	if not _heights.is_empty():
		_board.set("progress", 1.0)
		_board.call("finish")


## The height map: started once the world is built, swapped in when the worker is done.
func _map_ground(built: bool) -> void:
	if built and _grid_task < 0 and _heights.is_empty():
		build_seconds = _board_t
		_start_height_map()
	if _grid_task >= 0 and WorkerThreadPool.is_task_completed(_grid_task):
		WorkerThreadPool.wait_for_task_completion(_grid_task)
		_grid_task = -1
		_heights = _grid_out
		_grid_jobs = []
		height_map_ms = float(Time.get_ticks_usec() - _grid_t0) / 1000.0
		_start_grass()


# -- the grass ----------------------------------------------------------------------------------------------

## On or off, the blades' width against the pen's, their height (m) and the grass's colour (the Tab panel).
func set_grass(on: bool, width: float, height: float = -1.0, colour: Color = Color(0, 0, 0, 0)) -> void:
	_grass_on = on
	_grass_width = width
	if height > 0.0:
		_grass_height = height
	if colour.a > 0.0:
		_grass_colour = colour
	if grass != null:
		grass.set("enabled", on)
		grass.set("width_scale", width)
		grass.set("height_m", _grass_height)
		if _grass_colour.a > 0.0:
			grass.set("colour", _grass_colour)


## Where the patches go: a 3 m grid over the island read off the height map, kept where the ground is
## grass height (over the sea, not a peak), level enough, and clear of the deck and the platform; then the
## nearest to the platform, at least 14 m apart, so they are in sight from it. Vector4(x, z, w, radius).
func _choose_patches() -> Array:
	var c: Vector4 = _centre.global_position
	var sea: float = float(water.get("water_level")) if water != null else 1.1
	var deck: Vector4 = raft.global_position if raft != null else c
	var plat: Vector4 = deck + (raft.global_basis * PLAT_AT if raft != null else Vector4.ZERO)
	var cands: Array = []
	for iz in range(-18, 19):
		for ix in range(-18, 19):
			var x: float = c.x + float(ix) * 3.0
			var z: float = c.z + float(iz) * 3.0
			var g: float = ground_at(x, z, 0.0)
			if g < sea + 1.2 or g > sea + 24.0:
				continue
			var level: bool = true
			for o in [Vector2(3, 0), Vector2(-3, 0), Vector2(0, 3), Vector2(0, -3)]:
				if absf(ground_at(x + o.x, z + o.y, 0.0) - g) > 2.2:
					level = false
					break
			if not level:
				continue
			if Vector2(x - deck.x, z - deck.z).length() < 12.0 or Vector2(x - plat.x, z - plat.z).length() < PLAT_R + 6.0:
				continue
			cands.append([Vector2(x - plat.x, z - plat.z).length(), Vector2(x, z), g])
	cands.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var out: Array = []
	var ys: float = 0.0
	for cd in cands:
		var at: Vector2 = cd[1]
		var apart: bool = true
		for q in out:
			if Vector2((q as Vector4).x, (q as Vector4).y).distance_to(at) < 14.0:
				apart = false
				break
		if not apart:
			continue
		out.append(Vector4(at.x, at.y, 0.0, 4.5 + 1.5 * float(out.size() % 3)))
		ys += float(cd[2])
		if out.size() >= GRASS_PATCHES:
			break
	_grass_plan["ground_y"] = ys / float(maxi(out.size(), 1))
	return out


## The patches chosen, the chunk meshes under them copied, the heights baked on a worker.
func _start_grass() -> void:
	if grass != null or _grass_task >= 0 or biome != 0:
		return
	_grass_plan = {}
	var patch_list: Array = _choose_patches()
	if patch_list.is_empty():
		push_warning("voxel_field_4d: no ground for the grass patches")
		return
	var g: Array = Grass.grid_for(patch_list, GRASS_W_REACH)
	var rect: Vector4 = g[0]
	var wl: Vector3 = g[1]
	var boxes: Array = []
	for p in patch_list:
		var q: Vector4 = p
		boxes.append([Vector3(q.x - q.w - 1.0, q.y - q.w - 1.0, q.z - GRASS_W_REACH - 1.0), Vector3(q.x + q.w + 1.0, q.y + q.w + 1.0, q.z + GRASS_W_REACH + 1.0)])
	var size: float = 8.0 * float(stream.get("voxel"))
	_grass_jobs = []
	for ch in stream.call("chunk_nodes"):
		var m := ch as MeshInstance4D
		var tm := m.mesh as TetraMesh4D
		if tm == null:
			continue
		var o: Vector4 = m.global_position
		var near: bool = false
		for box in boxes:
			var bl: Vector3 = box[0]
			var bh: Vector3 = box[1]
			if o.x <= bh.x and o.x + size >= bl.x and o.z <= bh.y and o.z + size >= bl.y and o.w <= bh.z and o.w + size >= bl.z:
				near = true
				break
		if not near:
			continue
		var am = tm if tm is ArrayTetraMesh4D else tm.to_array_tetra_mesh()
		_grass_jobs.append([o, m.global_basis, tm.get_vertex_positions(), tm.get_simplex_cell_vertex_indices(),
			am.call("get_texture_map_values"), am.call("get_simplex_cell_texture_map_indices")])
	var sea: float = float(water.get("water_level")) if water != null else 1.1
	_grass_plan.merge({"patches": patch_list, "rect": rect, "wl": wl, "t0": Time.get_ticks_usec()}, true)
	var jobs: Array = _grass_jobs
	_grass_task = WorkerThreadPool.add_task(func() -> void: _grass_out = Grass.bake_heights(jobs, rect, wl, boxes, sea), false, "field grass")


## The bake done: the grass made and started.
func _poll_grass() -> void:
	if _grass_task < 0 or not WorkerThreadPool.is_task_completed(_grass_task):
		return
	WorkerThreadPool.wait_for_task_completion(_grass_task)
	_grass_task = -1
	_grass_jobs = []
	if biome != 0 or _heights.is_empty():
		return
	grass_ms = float(Time.get_ticks_usec() - int(_grass_plan["t0"])) / 1000.0
	grass = Node4D.new()
	grass.name = "Grass"
	grass.set_script(Grass)
	add_child(grass)
	grass.set("player", player)
	grass.call("start", _grass_plan["patches"], _grass_out, _grass_plan["rect"], _grass_plan["wl"], float(_grass_plan.get("ground_y", 0.0)))
	set_grass(_grass_on, _grass_width)


func _drop_grass() -> void:
	if grass != null:
		grass.queue_free()
		grass = null


static func _thousands(v: int) -> String:
	var s: String = str(v)
	var out: String = ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out


## THE DECK (rounds 3 and 4; the header). All of it on one node, `raft`; the grid shader works in each
## box's own frame. In order as you walk it:
##   the grey deck   a lab floor with a white lip, dark sides and a warm underglow, railed (the engine's
##                   FenceGenerator4D, three thin beams, through W as well); the door home at its back;
##                   two stations at its front, either side of the walkway (round 4: "left side: Takeoff,
##                   right side: Change the World ... matching elements of the same system"), each the
##                   lab's floating panel with a ring before it on the route.
##   the pier        4 m wide and 4 m on, railed both sides (round 4: "a more deliberate approach
##                   sequence before reaching the main interactive platform").
##   the platform    the Water Lab harbour's (seascape_4d.gd _build_platform): a cubinder in the lab's
##                   blue, TURN THE SLICE printed into it by a kit panel page, a lighter ring turning
##                   slowly, its rail a ring open to the pier; held level while the slice turns.
## The route (the Path Creator): from the door down the middle, a branch at the stations to each, on
## along the pier to the platform.
const GREY := Vector4(8.0, 0.5, 13.0, 6.0)
const GREY_AT := Vector4(0.0, 0.0, 5.0, 0.0)
const DOOR_GAP := 2.6
const PIER := Vector2(4.0, 4.0)
const RAIL_HEIGHT := 1.05
const PLAT_R := 5.2
## The pier from the grey deck's front (z -1.5) to z -5.5; the platform overlaps its end by 0.6 m.
const PIER_Z0 := -1.5
const PIER_Z1 := -5.5
const PLAT_AT := Vector4(0.0, 0.0, PIER_Z1 - PLAT_R + 0.6, 0.0)
const RING_R := PLAT_R - 0.95
const PLAT_W := 6.0
## Where you arrive, metres from the deck's middle along z (positive is back, toward the door): with
## the pen's camera 8 m behind you, still on the deck's side of the door.
const ARRIVE_Z := 3.0
## The two stations: their panels at the deck's front corners, their rings before them.
const STATIONS := [["fly", -2.9, "Take off"], ["world", 2.9, "Change the world"]]
const STATION_PANEL_Z := -0.5
const STATION_RING_Z := 1.1
const STATION_REACH := 0.95
## The deck's W, either side of W 0, you can step to (Q / E) before the rails' ends.
const DECK_W := 2.4

var stations: Array = []
## The station whose ring you stand in: "fly", "world" or "".
var at_station: String = ""

func _deck() -> void:
	_deck_at = start_at - Vector4(0, 2.2, 0, 0)
	raft = Node4D.new()
	raft.name = "Deck"
	raft.position = _deck_at
	add_child(raft)
	var holder: Node4D = raft
	var z0: float = GREY_AT.z - GREY.z * 0.5
	var z1: float = GREY_AT.z + GREY.z * 0.5
	# The grey deck and the pier: the lab's floor, its grid.
	_floor_box(holder, "Top", GREY_AT, Vector2(GREY.x, GREY.z))
	_floor_box(holder, "PierTop", Vector4(0, 0, (PIER_Z0 + PIER_Z1) * 0.5, 0), PIER)
	# The white lip round the outer edges, just proud of the floor (round 4: the lip's top was level with
	# the floor's and the two fought), the dark body under it, a warm glow under the lip.
	var lip := Style.lip()
	var lw: float = 0.12
	for e in [[Vector4(0, -0.075, z1 + lw * 0.5, 0), Vector4(GREY.x + lw * 2.0, 0.17, lw, GREY.w)],
			[Vector4(GREY.x * 0.5 + lw * 0.5, -0.075, GREY_AT.z, 0), Vector4(lw, 0.17, GREY.z, GREY.w)],
			[Vector4(-GREY.x * 0.5 - lw * 0.5, -0.075, GREY_AT.z, 0), Vector4(lw, 0.17, GREY.z, GREY.w)],
			[Vector4(-(PIER.x * 0.5 + (GREY.x - PIER.x) * 0.25), -0.075, z0 - lw * 0.5, 0), Vector4((GREY.x - PIER.x) * 0.5 + lw, 0.17, lw, GREY.w)],
			[Vector4(PIER.x * 0.5 + (GREY.x - PIER.x) * 0.25, -0.075, z0 - lw * 0.5, 0), Vector4((GREY.x - PIER.x) * 0.5 + lw, 0.17, lw, GREY.w)],
			[Vector4(PIER.x * 0.5 + lw * 0.5, -0.075, (PIER_Z0 + PIER_Z1) * 0.5, 0), Vector4(lw, 0.17, PIER.y, GREY.w)],
			[Vector4(-PIER.x * 0.5 - lw * 0.5, -0.075, (PIER_Z0 + PIER_Z1) * 0.5, 0), Vector4(lw, 0.17, PIER.y, GREY.w)]]:
		_flat(holder, "Lip", e[0], e[1], lip)
	_flat(holder, "Body", GREY_AT - Vector4(0, 0.16 + GREY.y * 0.5, 0, 0), Vector4(GREY.x - 0.3, GREY.y, GREY.z - 0.3, GREY.w), Style.pick(Style.PLINTH))
	_flat(holder, "PierBody", Vector4(0, -0.16 - GREY.y * 0.5, (PIER_Z0 + PIER_Z1) * 0.5, 0), Vector4(PIER.x - 0.3, GREY.y, PIER.y + 0.3, GREY.w), Style.pick(Style.PLINTH))
	for g in [[Vector4(0, -0.19, z1 - 0.2, 0), Vector4(GREY.x - 0.6, 0.03, 0.05, GREY.w)],
			[Vector4(GREY.x * 0.5 - 0.2, -0.19, GREY_AT.z, 0), Vector4(0.05, 0.03, GREY.z - 0.6, GREY.w)], [Vector4(-GREY.x * 0.5 + 0.2, -0.19, GREY_AT.z, 0), Vector4(0.05, 0.03, GREY.z - 0.6, GREY.w)]]:
		var glow := MeshInstance4D.new()
		glow.name = "Underglow"
		glow.mesh = Mats.box_mesh(g[1])
		glow.position = g[0]
		glow.material_override = Mats.glow(Style.pick(Style.GLOW_WARM), 1.6)
		holder.add_child(glow)
	# What you stand on, and what keeps you on it (boxes; the platform's round rail is kept in code).
	_wall(holder, "Floor", GREY_AT - Vector4(0, 0.25, 0, 0), Vector4(GREY.x, 0.5, GREY.z, GREY.w))
	_wall(holder, "PierFloor", Vector4(0, -0.25, (PIER_Z0 + PIER_Z1) * 0.5, 0), Vector4(PIER.x, 0.5, PIER.y, GREY.w))
	var h := RAIL_HEIGHT
	var back_side: float = (GREY.x - DOOR_GAP) * 0.5
	var front_side: float = (GREY.x - PIER.x) * 0.5
	for r in [[Vector4(-GREY.x * 0.5, h * 0.5, GREY_AT.z, 0), Vector4(0.1, h, GREY.z, GREY.w)],
			[Vector4(GREY.x * 0.5, h * 0.5, GREY_AT.z, 0), Vector4(0.1, h, GREY.z, GREY.w)],
			[Vector4(-(DOOR_GAP * 0.5 + back_side * 0.5), h * 0.5, z1, 0), Vector4(back_side, h, 0.1, GREY.w)],
			[Vector4(DOOR_GAP * 0.5 + back_side * 0.5, h * 0.5, z1, 0), Vector4(back_side, h, 0.1, GREY.w)],
			[Vector4(-(PIER.x * 0.5 + front_side * 0.5), h * 0.5, z0, 0), Vector4(front_side, h, 0.1, GREY.w)],
			[Vector4(PIER.x * 0.5 + front_side * 0.5, h * 0.5, z0, 0), Vector4(front_side, h, 0.1, GREY.w)],
			[Vector4(-PIER.x * 0.5, h * 0.5, (PIER_Z0 + PIER_Z1) * 0.5, 0), Vector4(0.1, h, PIER.y, GREY.w)],
			[Vector4(PIER.x * 0.5, h * 0.5, (PIER_Z0 + PIER_Z1) * 0.5, 0), Vector4(0.1, h, PIER.y, GREY.w)]]:
		_wall(holder, "RailStop", r[0], r[1])
	_rail(holder)
	_platform()
	_stations(holder)
	_route(holder)
	# The way back, at the back of the deck, in the gap of the railing.
	var sh := Node4D.new()
	sh.name = "Shimmer"
	sh.set_script(Shimmer)
	sh.set("width", DOOR_GAP - 0.2)
	sh.set("height", 3.0)
	sh.position = Vector4(0, 0, z1, 0)
	holder.add_child(sh)


## A floor box `size` (x, z) across, its top at y 0 of `at`, on the lab's grey floor grid.
func _floor_box(holder: Node4D, nm: String, at: Vector4, size: Vector2) -> void:
	var s4 := Vector4(size.x, 0.06, size.y, GREY.w)
	var top := MeshInstance4D.new()
	top.name = nm
	top.mesh = Mats.box_mesh(s4)
	top.position = at - Vector4(0, 0.03, 0, 0)
	top.material_override = LabGrid.material("kit_floor", s4, top.position)
	holder.add_child(top)


## The round blue platform (the Water Lab harbour's, seascape_4d.gd _build_platform): a cubinder in the
## lab's blue, a ring of lighter blue turning slowly on it, TURN THE SLICE printed in its middle, its rail
## a 32-sided ring open toward the pier; collision a box deep in W (walking while the slice is turned
## carries you through W).
func _platform() -> void:
	var c: Vector4 = PLAT_AT
	_wall(raft, "PlatformBody", c - Vector4(0, 0.25, 0, 0) + Vector4(0, 0.04, 0, 0), Vector4(PLAT_R * 2.0, 0.5, PLAT_R * 2.0, 80.0))
	_set = Node4D.new()
	_set.name = "PlatformSet"
	_set.position = c
	raft.add_child(_set)
	var shape := CubinderShape4D.new()
	shape.radius = PLAT_R
	shape.height = 0.3
	shape.thickness = PLAT_W
	var disc := MeshInstance4D.new()
	disc.name = "Platform"
	disc.mesh = shape.to_tetra_mesh()
	# Four centimetres proud of the pier, as the harbour's, so the two never fight.
	disc.position = Vector4(0.0, -0.15 + 0.04, 0.0, 0.0)
	var size := Vector4(PLAT_R * 2.0, 0.3, PLAT_R * 2.0, PLAT_W)
	var m: TetraMaterial4D = LabGrid.material(Style.code_swatch("blue"), size, Vector4.ZERO)
	disc.material_override = m
	_set.add_child(disc)
	LabGrid.set_ring(m, Vector2.ZERO, RING_R, 1.0, Color(0.52, 0.74, 1.0), 0.05)
	var r: float = PLAT_R - 0.15
	var gap: float = asin(clampf((PIER.x * 0.5 + 0.3) / r, 0.0, 1.0))
	_fence(_set, "PlatformRail", _ring_seed(r, 32, PLAT_W, gap, PI * 0.5), Vector4(0.0, 0.04, 0.0, 0.0), PLAT_W)
	# TURN THE SLICE, a kit panel page drawn out of sight and printed into the deck (the harbour's).
	var info: Resource = RoomInfo.new()
	info.set("number", 4)
	info.set("title", "Turn the slice")
	info.set("status", "THE PLATFORM  /  IT STAYS SET")
	info.set("lead", "Stand on the blue and right-drag.")
	info.set("description", "Anywhere on the blue, a right drag turns your slice through W. The land and the sea are cut a new way: every hill is a 4D hill, and its shape changes as the slice turns. The platform stays set, drawn as if nothing had turned, so you keep your footing while the world changes round you.")
	info.set("interactions", [["rdrag", "Turn the slice"], ["key:R", "Level it again"], ["key:E", "Step through W (Q, E)"]])
	info.set("controls_heading", "CONTROLS")
	var page := Node4D.new()
	page.name = "PlatformPage"
	page.set_script(WallPanel)
	page.set("kind", "intro")
	page.set("info", info)
	page.set("scale_factor", PAGE_SCALE)
	page.position = Vector4(0, -30.0, 0, 0)
	raft.add_child(page)
	_print_page_later(disc, page)


const PAGE_SCALE := 0.66

## The page's live picture printed into the platform's top, in its middle; the page's own slab hidden
## (seascape_4d.gd _print_deck_later).
func _print_page_later(disc: MeshInstance4D, page: Node4D) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(page) or not is_instance_valid(disc):
		return
	var vp: SubViewport = page.get("_vp")
	var slab: Node4D = page.get("_slab")
	if slab != null:
		slab.visible = false
	if vp == null:
		return
	var pm: Vector2 = PanelSpec.PANEL * PanelSpec.UNIT_M * PAGE_SCALE
	var m: TetraMaterial4D = disc.material_override as TetraMaterial4D
	LabGrid.set_print(m, vp.get_texture(), Vector4(0, 1, 0, 0), Rect2(Vector2(PLAT_R - pm.x * 0.5, PLAT_R - pm.y * 0.5), pm), Color.WHITE, 0.15)
	LabGrid.set_print_strength(m, 1.0)
	m.get_cross_section_material_3d().set_shader_parameter("print_aa", 1.0)


## The two stations: the lab's floating panel at each front corner of the grey deck, facing back down it.
func _stations(holder: Node4D) -> void:
	for st in STATIONS:
		var panel := Node4D.new()
		panel.name = "Station_" + String(st[0])
		panel.set_script(FloatPanel)
		panel.set("width", 1.0)
		panel.set("number", 0)
		panel.set("source", self)
		panel.set("face_key", String(st[0]))
		panel.set("face_point", Vector2(float(st[1]), STATION_PANEL_Z + 3.0))
		panel.position = Vector4(float(st[1]), 0.0, STATION_PANEL_Z, 0.0)
		holder.add_child(panel)
		stations.append(panel)


## The route on the deck (the Path Creator's network): the door down the middle to a junction at the
## stations, a branch to each ring, on along the pier to the platform.
func _route(holder: Node4D) -> void:
	var g: Resource = PathGraph.new()
	var z1: float = GREY_AT.z + GREY.z * 0.5
	var band: Dictionary = {"band": GREY.w}
	var start: int = g.call("add_node", "start", Vector4(0, 0, z1 - 1.0, 0), band)
	var mid: int = g.call("add_node", "junction", Vector4(0, 0, STATION_RING_Z, 0), band)
	var left: int = g.call("add_node", "destination", Vector4(float(STATIONS[0][1]), 0, STATION_RING_Z, 0), {"band": GREY.w, "state": "available", "approach": Vector2(1, 0)})
	var right: int = g.call("add_node", "destination", Vector4(float(STATIONS[1][1]), 0, STATION_RING_Z, 0), {"band": GREY.w, "state": "available", "approach": Vector2(-1, 0)})
	# The last orb just short of the platform's edge (round 5, #45: "ends just before the large blue platform ...
	# should not overlap or extend into the platform"): the platform reaches PIER_Z1 + 0.6.
	var on: int = g.call("add_node", "destination", Vector4(0, 0, PIER_Z1 + 1.35, 0), {"band": GREY.w, "state": "available", "approach": Vector2(0, 1)})
	g.call("add_edge", start, mid)
	g.call("add_edge", mid, left)
	g.call("add_edge", mid, right)
	g.call("add_edge", mid, on)
	var net := Node4D.new()
	net.name = "Route"
	net.set_script(PathNet)
	net.set("graph", g)
	net.set("under_color", (Style.SWATCHES["bright"]["kit_floor"][0] as Color))
	# In the platform's own blue, lit as it is (round 5, #45).
	net.set("ink_color", (Style.SWATCHES["bright"]["kit_code_blue"][0] as Color))
	holder.add_child(net)


## The railing: the fence generator round the grey deck and along the pier, through W as well; open at
## the door and where the pier meets the platform (a face left out is an opening that keeps its posts).
func _rail(holder: Node4D) -> void:
	var hx: float = GREY.x * 0.5 - 0.06
	var z0: float = GREY_AT.z - GREY.z * 0.5 + 0.06
	var z1: float = GREY_AT.z + GREY.z * 0.5 - 0.06
	var px: float = PIER.x * 0.5 - 0.06
	# Where the pier's rails meet the platform's ring rail.
	var pz: float = PLAT_AT.z + sqrt(maxf(0.0, (PLAT_R - 0.15) * (PLAT_R - 0.15) - px * px))
	var hw: float = GREY.w * 0.5
	var g: float = DOOR_GAP * 0.5
	var mesh := ArrayPolyMesh4D.new()
	var v := {}
	for p in [["a", -px, pz], ["b", -px, z0], ["c", -hx, z0], ["d", -hx, z1], ["e", -g, z1], ["f", g, z1], ["h", hx, z1], ["i", hx, z0], ["j", px, z0], ["k", px, pz]]:
		for k in 2:
			v["%s%d" % [p[0], k]] = mesh.append_vertex(Vector4(float(p[1]), 0.0, float(p[2]), hw if k == 1 else -hw), true)
	for f in [["a", "b"], ["b", "c"], ["c", "d"], ["d", "e"], ["f", "h"], ["h", "i"], ["i", "j"], ["j", "k"]]:
		var q: Array = [v[f[0] + "0"], v[f[1] + "0"], v[f[1] + "1"], v[f[0] + "1"]]
		var edges := PackedInt32Array()
		for n in 4:
			edges.append(mesh.append_edge_indices(int(q[n]), int(q[(n + 1) % 4]), true))
		mesh.append_poly_cell(2, edges, true)
	mesh.calculate_face_normals(Vector4(0.0, 1.0, 0.0, 0.0), false)
	_fence(holder, "Rail", mesh, Vector4.ZERO, GREY.w)


func _fence(parent: Node4D, nm: String, seed: ArrayPolyMesh4D, at: Vector4, w_depth: float) -> void:
	var fence := FenceGenerator4D.new()
	fence.name = nm
	fence.update_automatically = false
	fence.input_shape_type = FenceGenerator4D.INPUT_SHAPE_SEED_MESH_4D
	fence.seed_mesh_4d = seed
	fence.output_mesh_type = FenceGenerator4D.OUTPUT_MESH_TETRA
	# A third of W apart, so no rib ever lands at W 0 (a rib there is a solid wall in your slice).
	fence.desired_spacing_meters = w_depth / 3.0
	fence.post_height_meters = RAIL_HEIGHT
	fence.post_thickness_meters = 0.07
	fence.top_footprint_ratio = 1.0
	fence.rib_height_ratio = 0.95
	fence.rib_thickness_ratio = 0.35
	fence.beam_thickness_ratio = 0.35
	fence.beam_count = 3
	fence.beam_coverage = 0.08
	fence.beam_max_height_ratio = 0.97
	var m := TetraMaterial4D.new()
	m.albedo_color = Color(0.88, 0.89, 0.91)
	fence.post_material = m
	fence.rib_material = m
	fence.beam_material = m
	fence.position = at
	parent.add_child(fence)
	fence.update_fence_mesh_now()


## A ring of `n` faces at radius `r` spanning W, the faces within `gap` of `gap_at` (radians, from +x
## toward +z) left out (seascape_4d.gd _ring_seed).
static func _ring_seed(r: float, n: int, w_depth: float, gap: float, gap_at: float) -> ArrayPolyMesh4D:
	var mesh := ArrayPolyMesh4D.new()
	var lo: Array = []
	var hi: Array = []
	for i in n:
		var a: float = TAU * float(i) / float(n)
		lo.append(mesh.append_vertex(Vector4(cos(a) * r, 0.0, sin(a) * r, -w_depth * 0.5), true))
		hi.append(mesh.append_vertex(Vector4(cos(a) * r, 0.0, sin(a) * r, w_depth * 0.5), true))
	for i in n:
		var j: int = (i + 1) % n
		var mid: float = TAU * (float(i) + 0.5) / float(n)
		if absf(wrapf(mid - gap_at, -PI, PI)) < gap:
			continue
		var corners: Array = [lo[i], lo[j], hi[j], hi[i]]
		var edges := PackedInt32Array()
		for k in 4:
			edges.append(mesh.append_edge_indices(int(corners[k]), int(corners[(k + 1) % 4]), true))
		mesh.append_poly_cell(2, edges, true)
	mesh.calculate_face_normals(Vector4(0.0, 1.0, 0.0, 0.0), false)
	return mesh


func _flat(holder: Node4D, nm: String, at: Vector4, size: Vector4, col: Color) -> void:
	var mi := MeshInstance4D.new()
	mi.name = nm
	mi.mesh = Mats.box_mesh(size)
	mi.position = at
	var m := TetraMaterial4D.new()
	m.albedo_color = col
	mi.material_override = m
	holder.add_child(mi)


## A box you cannot walk through, unseen.
func _wall(holder: Node4D, nm: String, at: Vector4, size: Vector4) -> void:
	var body := StaticBody4D.new()
	body.name = nm
	body.position = at
	var shape := CollisionShape4D.new()
	var bs := BoxShape4D.new()
	bs.size = size
	shape.shape = bs
	body.add_child(shape)
	holder.add_child(body)


func _process(delta: float) -> void:
	var now: int = Time.get_ticks_usec()
	if _last_us > 0:
		_frames.append(float(now - _last_us) / 1000.0)
		if _frames.size() > 240:
			_frames.remove_at(0)
	_last_us = now
	_poll_grass()
	if _board != null:
		_feed_board(delta)
		choice.set("shown", false)
		return
	# Without the board (the probe), the ground is mapped as soon as the world stands.
	if _heights.is_empty():
		var st: Dictionary = stream.call("stats")
		_map_ground(int(st.get("chunks", 0)) > 0 and int(st.get("waiting", 0)) == 0)
	if mode == "deck":
		_on_deck()
		_on_platform()
	else:
		choice.set("shown", false)
		tutorial.set("shown", false)
		_show_edge()
	_land_look(delta)


## The top of the land under (x, z) at W `w`: the highest of the height map's cells round it (so a
## slope between two columns never lets you in). Far below everything where nothing is mapped.
func ground_at(x: float, z: float, w: float) -> float:
	if _heights.is_empty():
		return -1000.0
	var ix: int = int(floor(x - _hx0))
	var iz: int = int(floor(z - _hz0))
	var iw: int = int(floor((w - _hw0) / H_W))
	var best: float = -1000.0
	for cw in range(maxi(iw - 1, 0), mini(iw + 2, _hn.z)):
		for cz in range(maxi(iz - 1, 0), mini(iz + 2, _hn.y)):
			var row: int = (cw * _hn.y + cz) * _hn.x
			for cx in range(maxi(ix - 1, 0), mini(ix + 2, _hn.x)):
				best = maxf(best, _heights[row + cx])
	return best


## Every built chunk's vertices into the height map, on a worker thread: the mesh positions are copied
## here, on the main thread, and the work is all arithmetic.
func _start_height_map() -> void:
	var c: Vector4 = _centre.global_position
	var v: float = float(stream.get("voxel"))
	var reach: float = float(stream.get("radius")) * v + 2.0
	var band: float = float(stream.get("w_chunks")) * 8.0 * v
	_hx0 = c.x - reach
	_hz0 = c.z - reach
	_hw0 = -band
	_hn = Vector3i(int(ceil(reach * 2.0)), int(ceil(reach * 2.0)), int(ceil(band * 2.0 / H_W)))
	_grid_jobs = []
	for ch in stream.call("chunk_nodes"):
		var m := ch as MeshInstance4D
		var tm := m.mesh as TetraMesh4D
		if tm != null:
			_grid_jobs.append([m.global_position, m.global_basis, tm.get_vertex_positions()])
	_grid_t0 = Time.get_ticks_usec()
	_grid_task = WorkerThreadPool.add_task(_fill_heights, false, "field ground")


func _fill_heights() -> void:
	var nx: int = _hn.x
	var nz: int = _hn.y
	var nw: int = _hn.z
	var out := PackedFloat32Array()
	out.resize(nx * nz * nw)
	out.fill(-1000.0)
	for job in _grid_jobs:
		var o: Vector4 = job[0]
		var b: Projection = job[1]
		var pos: PackedVector4Array = job[2]
		for p in pos:
			var g: Vector4 = o + b * p
			var ix: int = int(floor(g.x - _hx0))
			var iz: int = int(floor(g.z - _hz0))
			var iw: int = int(floor((g.w - _hw0) / H_W))
			if ix < 0 or iz < 0 or iw < 0 or ix >= nx or iz >= nz or iw >= nw:
				continue
			var i: int = (iw * nz + iz) * nx + ix
			if g.y > out[i]:
				out[i] = g.y
	_grid_out = out


## The hologram wall where the circle ends, in front of you as you come near it.
func _show_edge() -> void:
	var at: Vector4 = bird.get("at")
	var c: Vector4 = _centre.global_position
	var off := Vector2(at.x - c.x, at.z - c.z)
	var d: float = off.length()
	var circle: float = float(bird.get("circle"))
	var k: float = clampf((d - (circle - 9.0)) / 8.0, 0.0, 1.0)
	_edge.visible = k > 0.01 and d > 0.001
	if not _edge.visible:
		return
	var dir: Vector2 = off / d
	_edge.global_position = Vector4(c.x + dir.x * (circle + 0.8), at.y, c.z + dir.y * (circle + 0.8), at.w)
	_edge.global_basis = Basis4D.from_zx(atan2(dir.x, dir.y))
	_edge_cs.set_shader_parameter("holo_base", 0.85 * k)


## On the deck: a station's choice while you stand in its ring, and the shimmer behind you back to the lab.
func _on_deck() -> void:
	var local: Vector4 = player.global_position - raft.position
	at_station = ""
	for st in STATIONS:
		if Vector2(local.x - float(st[1]), local.z - STATION_RING_Z).length() < STATION_REACH:
			at_station = String(st[0])
	choice.set("shown", input_enabled and at_station != "" and not _heights.is_empty())
	if at_station == "fly":
		choice.set("options", [{"key": "1", "id": "fly", "icon": "fly", "label": "Take off: fly over it as a bird"}])
	elif at_station == "world":
		choice.set("options", [{"key": "1", "id": "world", "icon": "globe", "label": "Change the world (now %s)" % String(Case.BIOMES[biome]["name"])}])
	if not _leaving and local.z > GREY_AT.z + GREY.z * 0.5 - 0.3 and absf(local.x) < 1.2:
		_leaving = true
		raft.get_node("Shimmer").call("flash_out", self, back_to_lab)
	# Fallen off somehow: back on the deck.
	if local.y < -6.0:
		player.global_position = raft.position + Vector4(0, 0.25, ARRIVE_Z, 0)


## The platform: anywhere on its blue the slice turns (the rig's own right drag, R levels it), as far as
## you like (round 4: "slice manipulation should feel continuous, immediate, and directly controlled
## ... no hard stops"; past about 30 degrees less of the land is in your slice, which is 4D, not a
## fault), the card shows how for ten seconds, the platform stays level. Off the platform the slice
## goes level. Nothing levels it by itself while you stand on the blue (the harbour levelled it near
## the edge, which here read as the system taking the slice from you).
func _on_platform() -> void:
	var rig: Node4D = player.get_node("CameraRig")
	var now: String = "platform" if _on_blue() and input_enabled else ""
	if now != site:
		site = now
		rig.set("slice_turning", site == "platform")
		if site == "":
			rig.call("go_home")
	tutorial.set("shown", site == "platform")
	_hold_set()


## On the blue: in the turned frame while turned (where you see yourself), else where you are.
func _on_blue() -> bool:
	if _turned_here:
		return Vector2(_visual.x, _visual.z).length() < PLAT_R - 0.2
	var rel: Vector4 = player.global_position - (raft.position + PLAT_AT)
	return absf(rel.y) < 2.5 and Vector2(rel.x, rel.z).length() < PLAT_R - 0.2


## The slice's tilt as a rotation of the world (seascape_4d.gd _world_tilt).
func _world_tilt() -> Projection:
	var rig: Node4D = player.get_node("CameraRig")
	var g: Projection = rig.basis
	var s: Projection = g * Ground.flattened(g).inverse()
	var bp: Projection = (rig.get_parent() as Node4D).global_basis
	return bp * s * bp.inverse()


## The platform drawn as if the slice were level while the world is cut a new way: turned by the
## slice's tilt about where you stood when the turn began (seascape_4d.gd _hold_set_frame, which says
## why: turned about its own centre, from its edge, the platform slid out of the slice).
func _hold_set() -> void:
	var rig: Node4D = player.get_node("CameraRig")
	var c: Vector4 = raft.position + PLAT_AT
	var o: Vector4 = rig.global_position
	var tilted: bool = rad_to_deg(Ground.tilt(rig.basis)) > 0.2
	if tilted and (_turned_here or site == "platform"):
		var t: Projection = _world_tilt()
		if not _turned_here:
			_turned_here = true
			_pivot = o
		_visual = _pivot + t.inverse() * (o - _pivot) - c
		_set.global_basis = t
		_set.global_position = _pivot + t * (c - _pivot)
		return
	if _turned_here:
		_turned_here = false
		var off: Vector4 = o - player.global_position
		player.global_position = Vector4(c.x + _visual.x - off.x, player.global_position.y, c.z + _visual.z - off.z, 0.0)
	_set.global_basis = Projection.IDENTITY
	_set.global_position = c


## The platform's round rail, kept here (the physics is box only), open toward the pier; turned, the way
## onto the pier levels the slice first (walk into the gap and it goes level, then you walk on). Off the
## platform, your W is kept to the deck's (the pen's Q / E step would carry you off its ends).
func _physics_process(_delta: float) -> void:
	if player == null or raft == null or mode != "deck":
		return
	var rig: Node4D = player.get_node("CameraRig")
	var c: Vector4 = raft.position + PLAT_AT
	var limit: float = PLAT_R - 0.45
	if _turned_here:
		var flat2 := Vector2(_visual.x, _visual.z)
		var rv: float = flat2.length()
		# Once, not every tick: the rig's trip home restarts on each call, and called every tick it only
		# crept level (exponentially), holding you at the gap for seconds.
		if rv > limit - 0.5 and _visual.z > 0.0 and absf(_visual.x) < PIER.x * 0.5 - 0.3 and float(rig.get("_homing")) <= 0.0:
			rig.call("go_home")
		if rv > limit:
			var nv: Vector2 = flat2 * (limit / rv)
			var q := Vector4(c.x + nv.x, rig.global_position.y, c.z + nv.y, 0.0)
			var world: Vector4 = _pivot + _world_tilt() * (q - _pivot)
			player.global_position = world - (rig.global_position - player.global_position)
		return
	var p: Vector4 = player.global_position
	if absf(p.w) > DECK_W:
		player.global_position = Vector4(p.x, p.y, p.z, clampf(p.w, -DECK_W, DECK_W))
		p = player.global_position
	var rel: Vector4 = p - c
	if absf(rel.y) > 2.5:
		return
	var flat := Vector2(rel.x, rel.z)
	var r: float = flat.length()
	# Toward the pier the way is open (the pier's own rails take over).
	if rel.z > 0.0 and absf(rel.x) < PIER.x * 0.5 - 0.3:
		return
	if r > limit and r < PLAT_R + 1.2 and rel.z < PLAT_R - 0.9:
		var nv2: Vector2 = flat * (limit / r)
		player.global_position = Vector4(c.x + nv2.x, p.y, c.z + nv2.y, p.w)


## Where you stand at each station, and the door home (the runners).
func helm_spot() -> Vector4:
	return station_spot("fly")


func station_spot(key: String) -> Vector4:
	for st in STATIONS:
		if String(st[0]) == key:
			return raft.position + Vector4(float(st[1]), 0.25, STATION_RING_Z, 0)
	return raft.position


func door_spot() -> Vector4:
	return raft.position + Vector4(0, 0.3, GREY_AT.z + GREY.z * 0.5 - 0.1, 0)


## The middle of the platform's ring (the runners).
func platform_spot() -> Vector4:
	return raft.position + PLAT_AT + Vector4(0, 0.25, 0, 0)


## The bird's circle, metres from the middle.
func fly_circle() -> float:
	return maxf(8.0, float(stream.get("radius")) * float(stream.get("voxel")) - fly_margin)


## A station panel's face: what it offers, and three numbers.
func panel_face(key: String = "fly") -> Dictionary:
	var st: Dictionary = stream.call("stats") if stream != null else {}
	if key == "world":
		return {"title": "Change the world", "kicker": "GREEN, DESERT, LAVA: EACH ITS OWN GROUND", "rows": [
			["Now", String(Case.BIOMES[biome]["name"])], ["Built in", "%.1f s" % build_seconds], ["Tetrahedra", _thousands(int(st.get("tets", 0)))]]}
	return {"title": "Take off", "kicker": "STAND IN THE RING. YOU FLY AS A BIRD", "rows": [
		["Circle", "%.0f m across" % (fly_circle() * 2.0)], ["Slice", "turns with a right drag"], ["Chunks", _thousands(int(st.get("chunks", 0)))]]}


func _on_choice(_i: int) -> void:
	if at_station == "fly":
		fly()
		return
	if at_station != "world":
		return
	var was_green: bool = biome == 0
	biome = (biome + 1) % Case.BIOMES.size()
	# The moving sea belongs to the green land, over open seabed; the desert's salt flats and the lava
	# field's lava are the generator's own sea. Between the two the landscape is built again, behind
	# the board; between desert and lava only its colours change.
	water.visible = biome == 0
	if _bed != null:
		_bed.visible = biome == 0
	if grass != null:
		grass.visible = biome == 0
	if was_green != (biome == 0):
		_rebuild_land()
	else:
		_paint_land()
	hud.call("toast", "The land: " + String(Case.BIOMES[biome]["name"]))


func _paint_land() -> void:
	var colors: Dictionary = (Case.BIOMES[biome]["colors"] as Dictionary).duplicate()
	if biome == 0:
		colors[0] = _grass
	var list := PackedColorArray()
	for m in 5:
		list.append(colors.get(m, Color.WHITE))
	var pal = ClassDB.instantiate("VoxelMaterialPalette4D")
	pal.set("colors", list)
	stream.get("world").set("material_palette", pal)


## A new landscape with the other kind of sea, built behind the loading board.
func _rebuild_land() -> void:
	var old: Node4D = stream
	var swap: bool = bool(old.get("swap"))
	stream = _new_stream(254 if biome == 0 else 3)
	stream.set("swap", swap)
	old.queue_free()
	_paint_land()
	_open_board("THE OPEN WORLD  ·  CHANGING THE LAND", "The land, built again: " + String(Case.BIOMES[biome]["name"]).to_lower(),
		["The same generators, a different sea", "Green: our moving sea over open seabed",
			"Desert and lava: the generator's own sea, as salt flats or lava"])


## At the Take off station: off the deck as a bird, looking where you looked.
func fly() -> void:
	if mode == "fly" or _heights.is_empty():
		return
	mode = "fly"
	player.set("input_enabled", false)
	choice.set("shown", false)
	tutorial.set("shown", false)
	var level: Projection = (player.get_node("CameraRig") as Node4D).global_basis
	var ahead: Vector4 = level * Vector4(0, 0, -1, 0)
	ahead.y = 0.0
	ahead = ahead.normalized() if ahead.length() > 0.001 else Vector4(0, 0, -1, 0)
	var launch: Vector4 = player.global_position + Vector4(0, 1.7, 0, 0) + ahead * 1.2
	bird.set("centre", _centre.global_position)
	bird.set("circle", fly_circle())
	bird.set("w_limit", BIRD_W)
	bird.set("ceiling", _deck_at.y + 24.0)
	bird.set("sea_level", float(water.get("water_level")) if biome == 0 else -1000.0)
	bird.call("start", _walker_cam(), launch, level)
	hud.call("toast", "Flying. Right drag turns the slice, 1 brings you back to the deck.")


## Back on the deck, at the station, with a wash of the door's blue.
func land() -> void:
	if mode != "fly":
		return
	bird.call("stop")
	mode = "deck"
	_edge.visible = false
	if volume_view:
		set_volume_view(false)
	player.set("input_enabled", true)
	var pc: Camera4D = _walker_cam()
	if pc != null:
		pc.make_current()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Shimmer.flash_in(self)


func _input(event: InputEvent) -> void:
	if not input_enabled or mode != "fly":
		return
	var k := event as InputEventKey
	if k != null and k.pressed and not k.echo:
		match k.keycode:
			KEY_1, KEY_H, KEY_ESCAPE:
				# Esc lands you here, before the walker's camera's own Esc frees the cursor.
				land()
				get_viewport().set_input_as_handled()
			KEY_V:
				set_volume_view(not volume_view)
		return
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		crater_ahead()


func _walker_cam() -> Camera4D:
	return player.get_node_or_null("CameraRig/Pitch/Camera4D") as Camera4D if player != null else null


## What you see through: the bird's eyes in flight, the walker's camera on the deck.
func _view_cam() -> Camera4D:
	return bird_cam if mode == "fly" else _walker_cam()


func set_volume_view(on: bool) -> void:
	volume_view = on
	var tree: SceneTree = get_tree()
	if tree.root.world_3d == null:
		tree.root.world_3d = World3D.new()
	var pc: Camera4D = _view_cam()
	pc.set("rendering_engine_name", "Combined" if on else "Cross-section")
	pc.set("projection_opacity_base", 0.12)
	if not on:
		pc.set("depth_fade_mode", 1)
	hud.call("toast", "Projection view" if on else "Slice view")


## A crater where you look: a 4D ball of air, 4 m round, at the first surface the view's middle meets.
func crater_ahead() -> Dictionary:
	var pc: Camera4D = _view_cam()
	var o: Vector4 = pc.global_position
	var d: Vector4 = -(pc.global_basis * Vector4(0, 0, 1, 0))
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
