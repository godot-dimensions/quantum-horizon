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
## screen but the view. At the deck's front left floats a panel, the helm, a ring on the floor in front
## of it; stand in the ring and it asks: 1 takes off, 2 changes the land.
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
## THE SEA: Trym's moving sea (carried/water4d/), a kilometre out, over open seabed (the green land's
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
const WaterSurface := preload("res://ramon/VoxelLab/carried/water4d/water4d_surface.gd")
const LabGrid := preload("res://ramon/VoxelLab/carried/LabKit/lab_grid.gd")
const Mats := preload("res://ramon/VoxelLab/carried/LabKit/lab_materials.gd")
const Build := preload("res://ramon/VoxelLab/carried/scripts/chamber_build.gd")
const FloatPanel := preload("res://ramon/VoxelLab/room/vl_float_panel_4d.gd")
const Bird := preload("res://ramon/VoxelLab/field/vl_bird_4d.gd")
const SeaPanel := preload("res://ramon/VoxelLab/field/vl_sea_panel.gd")

const LAB := "res://ramon/VoxelLab/voxel_lab.tscn"
## What is built round the deck, metres (a 4D ball, cut to the band of W and of height), and how many
## 8 m chunks either side of W 0. Changed in code only: every metre more is more to build and keep.
const BUILT_RADIUS := 40.0
const W_CHUNKS := 2
## The bird's band of W, either side of 0, metres: inside the built band with room to see past it.
const BIRD_W := 6.0
## The height map's cells in W, metres (1 m in x and z).
const H_W := 2.0

## Where the survey deck floats (a little above where you stand on it): low enough that the hills stand
## round you (at 30 m the land was below the deck's edge and you saw only sky, 9 Oct).
@export var start_at: Vector4 = Vector4(0, 21, 34, 0)
## The bird's circle is this much short of the edge of what is built, so there is land beyond you
## whichever way you look.
@export var fly_margin: float = 14.0

var stream: Node4D
var hud: Control
var volume_view: bool = false
var input_enabled: bool = true
## "deck" (walking on the survey deck) or "fly" (the bird).
var mode: String = "deck"
## The deck and everything on it (top, lip, rails, the helm, the door home).
var raft: Node4D
var helm: Node4D
var at_helm: bool = false
var _top_mat: TetraMaterial4D
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
## Trym's sea (carried/water4d/), a little above the land's sea level, so the islands stand in a sea
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
	_deck_at = start_at - Vector4(0, 2.2, 0, 0)
	_centre = Node4D.new()
	_centre.name = "Centre"
	_centre.position = Vector4(_deck_at.x, 0.0, _deck_at.z, 0.0)
	add_child(_centre)
	stream = _new_stream(254)
	# The lab's colours, as the lab left them; opened on its own, the bright ones (else the deck's blue
	# is the grid's default grey).
	if not LabGrid._values.has("kit_code_blue"):
		Style.apply("bright")
	_make_sea(float(SeaPanel.saved()["reach"]))
	SeaPanel.apply_all(water, SeaPanel.saved())
	_deck()
	# On the deck, walking: the kit's player, its camera behind you.
	player = KitPlayer.make()
	add_child(player)
	helm.set("player", player)
	# Out of the door and a few steps on (the camera behind you stays on the deck's side of the shimmer),
	# looking out over the front rail, the helm off to the left: you look first.
	player.global_position = _deck_at + Vector4(0, 0.25, ARRIVE_Z, 0)
	player.set("_facing", PI)
	var rig: Node = player.get_node_or_null("CameraRig")
	if rig != null:
		rig.set("slice_turning", false)
		rig.set("yaw", 0.0)
		# Looking out more than down: the first thing you see is the land, not the deck.
		rig.set("pitch", deg_to_rad(-12.0))
		rig.call("_apply")
	var pc: Camera4D = _walker_cam()
	if pc != null:
		# The land fades into the sky toward the edge of what is built, instead of ending in a cliff.
		pc.set("depth_fade_mode", 1)
		pc.set("depth_fade_start", BUILT_RADIUS * 0.55)
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
	_open_board("VOXEL LAB  ·  THROUGH THE DOOR", "Our landscape, an island of it, built round a deck in the sea",
		["A deck over the land, the door back behind you", "At the helm: fly over it as a bird, or change the land",
			"Turn the slice while you fly: the hills change shape through W"])
	_audio = AudioStreamPlayer.new()
	_audio.volume_db = -4.0
	add_child(_audio)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## The landscape round the deck: built once, not streamed (the trigger stays at the middle).
func _new_stream(sea: int) -> Node4D:
	var s := Node4D.new()
	s.name = "Stream"
	s.set_script(Stream)
	s.set("radius", 8.0)
	s.set("y_range", Vector2i(-16, 16))
	s.set("w_chunks", W_CHUNKS)
	s.set("ahead", 0.0)
	s.set("sea_material", sea)
	add_child(s)
	s.set("follow", _centre)
	return s


## The sea, `reach` metres out from wherever you are: even 0.8 m squares for the first 100 m, growing
## to the reach (water4d_surface.gd, the graded grid), the waves calmed toward the far edge.
func _make_sea(reach: float) -> void:
	water = Node4D.new()
	water.name = "Sea"
	water.set_script(WaterSurface)
	# Set before it enters the tree: its grid is built once, in its _ready, and follows the camera.
	water.set("extent", reach)
	water.set("fine_extent", minf(100.0, reach * 0.5))
	water.set("grid_resolution", 384)
	add_child(water)
	water.visible = biome == 0


## A sea of a new reach (the sea panel's slider), the panel's numbers on it.
func remake_sea(reach: float) -> void:
	var old: Node4D = water
	_make_sea(reach)
	SeaPanel.apply_all(water, sea_panel.call("values") if sea_panel != null else SeaPanel.saved())
	old.queue_free()


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


static func _thousands(v: int) -> String:
	var s: String = str(v)
	var out: String = ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out


## The survey deck, in the lab's style (Ramon, 9 Oct: "make sure the pedestal he walks out on is
## labstyle, with railings using the 4d generator fence tech"): a pedestal's blue gridded top, a white
## lip, dark sides and a warm glow under the lip; railings from the engine's FenceGenerator4D (as the
## Water prototype's piers: three thin beams, the footprint railed through W as well), open at the back
## where the door stands; and boxes you cannot walk through behind every rail. All of it on one node,
## `raft`; the grid shader works in each box's own frame.
const DECK := Vector4(8.0, 0.5, 11.0, 6.0)
const DOOR_GAP := 2.6
const RAIL_HEIGHT := 1.05
## Where you arrive, metres ahead of the deck's middle (negative is ahead, toward the front rail).
const ARRIVE_Z := -0.6
## The helm: the floating panel at the front left, and the ring you stand in to use it, on the deck.
const HELM := Vector4(-1.9, 0.0, -4.0, 0.0)
const HELM_SPOT := Vector2(-1.9, -2.8)
const HELM_REACH := 0.95

func _deck() -> void:
	_deck_at = start_at - Vector4(0, 2.2, 0, 0)
	raft = Node4D.new()
	raft.name = "Deck"
	raft.position = _deck_at
	add_child(raft)
	var holder: Node4D = raft
	# The top: the lab's blue, with its grid, and the helm's ring in it.
	var top_size := Vector4(DECK.x, 0.06, DECK.z, DECK.w)
	var top := MeshInstance4D.new()
	top.name = "Top"
	top.mesh = Mats.box_mesh(top_size)
	top.position = Vector4(0, -0.03, 0, 0)
	_top_mat = LabGrid.material("kit_code_blue", top_size, top.position)
	top.material_override = _top_mat
	LabGrid.set_ring(_top_mat, HELM_SPOT, 0.55, 1.0, Color(0.86, 0.94, 1.0))
	holder.add_child(top)
	# The white lip round its edge, the dark body under it, a warm glow under the lip.
	var lip := Style.lip()
	for e in [[Vector4(0, -0.08, DECK.z * 0.5, 0), Vector4(DECK.x + 0.12, 0.16, 0.12, DECK.w)], [Vector4(0, -0.08, -DECK.z * 0.5, 0), Vector4(DECK.x + 0.12, 0.16, 0.12, DECK.w)],
			[Vector4(DECK.x * 0.5, -0.08, 0, 0), Vector4(0.12, 0.16, DECK.z, DECK.w)], [Vector4(-DECK.x * 0.5, -0.08, 0, 0), Vector4(0.12, 0.16, DECK.z, DECK.w)]]:
		_flat(holder, "Lip", e[0], e[1], lip)
	_flat(holder, "Body", -Vector4(0, 0.16 + DECK.y * 0.5, 0, 0), Vector4(DECK.x - 0.3, DECK.y, DECK.z - 0.3, DECK.w), Style.pick(Style.PLINTH))
	for g in [[Vector4(0, -0.19, DECK.z * 0.5 - 0.2, 0), Vector4(DECK.x - 0.6, 0.03, 0.05, DECK.w)], [Vector4(0, -0.19, -DECK.z * 0.5 + 0.2, 0), Vector4(DECK.x - 0.6, 0.03, 0.05, DECK.w)],
			[Vector4(DECK.x * 0.5 - 0.2, -0.19, 0, 0), Vector4(0.05, 0.03, DECK.z - 0.6, DECK.w)], [Vector4(-DECK.x * 0.5 + 0.2, -0.19, 0, 0), Vector4(0.05, 0.03, DECK.z - 0.6, DECK.w)]]:
		var glow := MeshInstance4D.new()
		glow.name = "Underglow"
		glow.mesh = Mats.box_mesh(g[1])
		glow.position = g[0]
		glow.material_override = Mats.glow(Style.pick(Style.GLOW_WARM), 1.6)
		holder.add_child(glow)
	# What you stand on, and what keeps you on it.
	_wall(holder, "Floor", -Vector4(0, 0.25, 0, 0), Vector4(DECK.x, 0.5, DECK.z, DECK.w))
	var h := RAIL_HEIGHT
	var side: float = (DECK.x - DOOR_GAP) * 0.5
	for r in [[Vector4(0, h * 0.5, -DECK.z * 0.5, 0), Vector4(DECK.x, h, 0.1, DECK.w)], [Vector4(-DECK.x * 0.5, h * 0.5, 0, 0), Vector4(0.1, h, DECK.z, DECK.w)],
			[Vector4(DECK.x * 0.5, h * 0.5, 0, 0), Vector4(0.1, h, DECK.z, DECK.w)],
			[Vector4(-(DOOR_GAP * 0.5 + side * 0.5), h * 0.5, DECK.z * 0.5, 0), Vector4(side, h, 0.1, DECK.w)],
			[Vector4(DOOR_GAP * 0.5 + side * 0.5, h * 0.5, DECK.z * 0.5, 0), Vector4(side, h, 0.1, DECK.w)]]:
		_wall(holder, "RailStop", r[0], r[1])
	_rail(holder)
	# The helm: the lab's floating panel (the one beside the block), turned to face back down the deck.
	helm = Node4D.new()
	helm.name = "Helm"
	helm.set_script(FloatPanel)
	helm.set("width", 1.0)
	helm.set("number", 0)
	helm.set("source", self)
	helm.set("face_point", Vector2(HELM.x, HELM.z + 3.0))
	helm.position = HELM
	holder.add_child(helm)
	# The way back, at the back of the deck, in the gap of the railing: it flies with you.
	var sh := Node4D.new()
	sh.name = "Shimmer"
	sh.set_script(Shimmer)
	sh.set("width", DOOR_GAP - 0.2)
	sh.set("height", 3.0)
	sh.position = Vector4(0, 0, DECK.z * 0.5, 0)
	holder.add_child(sh)


## The railing: the fence generator round the deck's footprint in x, z and W, with the doorway's span
## of the back side left out (a face left out is an opening that keeps its posts).
func _rail(holder: Node4D) -> void:
	var hx: float = DECK.x * 0.5 - 0.06
	var hz: float = DECK.z * 0.5 - 0.06
	var hw: float = DECK.w * 0.5
	var g: float = DOOR_GAP * 0.5
	var mesh := ArrayPolyMesh4D.new()
	var v := {}
	for p in [["a", -hx, -hz], ["b", hx, -hz], ["c", hx, hz], ["d", g, hz], ["e", -g, hz], ["f", -hx, hz]]:
		for k in 2:
			v["%s%d" % [p[0], k]] = mesh.append_vertex(Vector4(float(p[1]), 0.0, float(p[2]), hw if k == 1 else -hw), true)
	# Each face a quad spanning W: the far side, the two sides, and the back either side of the door.
	for f in [["a", "b"], ["b", "c"], ["c", "d"], ["e", "f"], ["f", "a"]]:
		var q: Array = [v[f[0] + "0"], v[f[1] + "0"], v[f[1] + "1"], v[f[0] + "1"]]
		var edges := PackedInt32Array()
		for n in 4:
			edges.append(mesh.append_edge_indices(int(q[n]), int(q[(n + 1) % 4]), true))
		mesh.append_poly_cell(2, edges, true)
	mesh.calculate_face_normals(Vector4(0.0, 1.0, 0.0, 0.0), false)
	var fence := FenceGenerator4D.new()
	fence.name = "Rail"
	fence.update_automatically = false
	fence.input_shape_type = FenceGenerator4D.INPUT_SHAPE_SEED_MESH_4D
	fence.seed_mesh_4d = mesh
	fence.output_mesh_type = FenceGenerator4D.OUTPUT_MESH_TETRA
	# A third of W apart, so no rib ever lands at W 0 (a rib there is a solid wall in your slice).
	fence.desired_spacing_meters = DECK.w / 3.0
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
	holder.add_child(fence)
	fence.update_fence_mesh_now()


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
	else:
		choice.set("shown", false)
		_show_edge()


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


## On the deck: the helm's choice while you stand in its ring, and the shimmer behind you back to the lab.
func _on_deck() -> void:
	var local: Vector4 = player.global_position - raft.position
	at_helm = Vector2(local.x - HELM_SPOT.x, local.z - HELM_SPOT.y).length() < HELM_REACH
	choice.set("shown", input_enabled and at_helm and not _heights.is_empty())
	choice.set("options", [{"key": "1", "id": "fly", "icon": "fly", "label": "Fly over it as a bird"},
		{"key": "2", "id": "biome", "icon": "globe", "label": "Change the land (now %s)" % String(Case.BIOMES[biome]["name"])}])
	if not _leaving and local.z > DECK.z * 0.5 - 0.3 and absf(local.x) < 1.2:
		_leaving = true
		raft.get_node("Shimmer").call("flash_out", self, back_to_lab)
	# Fallen off somehow: back on the deck.
	if local.y < -6.0:
		player.global_position = raft.position + Vector4(0, 0.25, 0, 0)


## Where you stand to fly, and the door home (the runners).
func helm_spot() -> Vector4:
	return raft.position + Vector4(HELM_SPOT.x, 0.25, HELM_SPOT.y, 0)


func door_spot() -> Vector4:
	return raft.position + Vector4(0, 0.3, DECK.z * 0.5 - 0.1, 0)


## The bird's circle, metres from the middle.
func fly_circle() -> float:
	return maxf(8.0, float(stream.get("radius")) * float(stream.get("voxel")) - fly_margin)


## The helm panel's face: what it offers, and three numbers.
func panel_face() -> Dictionary:
	var st: Dictionary = stream.call("stats") if stream != null else {}
	return {"title": "Take off", "kicker": "STAND IN THE RING. YOU FLY AS A BIRD", "rows": [
		["Circle", "%.0f m across" % (fly_circle() * 2.0)], ["Slice turns", "to %.0f°" % float(bird.get("slice_limit")) if bird != null else ""],
		["Chunks", _thousands(int(st.get("chunks", 0)))]]}


func _on_choice(i: int) -> void:
	if i == 0:
		fly()
		return
	var was_green: bool = biome == 0
	biome = (biome + 1) % Case.BIOMES.size()
	# The moving sea belongs to the green land, over open seabed; the desert's salt flats and the lava
	# field's lava are the generator's own sea. Between the two the landscape is built again, behind
	# the board; between desert and lava only its colours change.
	water.visible = biome == 0
	if was_green != (biome == 0):
		_rebuild_land()
	else:
		_paint_land()
	hud.call("toast", "The land: " + String(Case.BIOMES[biome]["name"]))


func _paint_land() -> void:
	var colors: Dictionary = Case.BIOMES[biome]["colors"]
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


## At the helm: off the front of the deck as a bird, looking where you looked.
func fly() -> void:
	if mode == "fly" or _heights.is_empty():
		return
	mode = "fly"
	player.set("input_enabled", false)
	choice.set("shown", false)
	LabGrid.set_ring(_top_mat, HELM_SPOT, 0.55, 0.0, Color(0.86, 0.94, 1.0))
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


## Back on the deck, at the helm, with a wash of the door's blue.
func land() -> void:
	if mode != "fly":
		return
	bird.call("stop")
	mode = "deck"
	_edge.visible = false
	if volume_view:
		set_volume_view(false)
	player.set("input_enabled", true)
	LabGrid.set_ring(_top_mat, HELM_SPOT, 0.55, 1.0, Color(0.86, 0.94, 1.0))
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
	hud.call("toast", "Volume view" if on else "Slice view")


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
