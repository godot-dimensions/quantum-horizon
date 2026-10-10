extends Node4D

## BOTANY LAB, THE SECOND ROOM: TWO VOXEL WORLDS (section 7's plan steps 66-76; Ramon, 9 Oct: "A
## side-by-side comparison of two voxel vegetation systems ... Divide the room into two major showcase
## areas ... one on the left and one on the right. Keep a central path ... The left half of the room
## should present a deliberately square, blocky voxel aesthetic ... The right half should contrast ...
## smooth or dual-contouring-style voxel terrain ... lofted tree structures ... more realistic foliage
## ... different rendering or generation approaches applied to comparable environmental content").
##
## THE SAME LAND, TWICE. One height over the floor, h(x, z, w): FastNoiseLite's noise over the
## display's own x, z and W (so the hills change as you step through W), 0.6 to 2.8 m. Two square
## ground displays, one each side of the path, 14 x 26 m, the same hills on both:
##   LEFT, THE BLOCKY WAY   the land written into 4D cells of 0.5 m (a column of cells under every
##                          height, five cells deep in W, the top one grass) and drawn one box per
##                          cell with only the faces no neighbour hides: the same box mesher as the
##                          Botany Lab's pedestal 01 (botany/voxel_tree_builder.gd mesh()). Its
##                          trees are the voxel trees (25 cm cells, the bake's grove_vx_*). Square
##                          everywhere: ground, trunks, crowns.
##   RIGHT, THE SMOOTH WAY  the same heights in Andrew's native voxel world (VoxelWorld4D): a column
##                          of soil under every height and a ball of grass at its top, voxels of
##                          0.3 m; the engine runs one dual-contoured surface through them all, so
##                          the columns and balls melt into rounded hills. Its trees are lofted oaks
##                          (the bake's grove_ok_*) with leaves the graphics card draws.
## The trees stand on the same spots on both sides, so the difference is only the method.
##
## AROUND THEM: a path down the middle (the carried PathCreator, its graph made here), a ring at each
## side's middle and one at the far end; each side's blue wall explains its method (a page printed into
## the wall: a heading, three lines, a diagram); a floating panel by each ring with the live numbers.
## A loading board while the land and the trees are built; the holographic doorway in the near wall
## leads back to the hall (botany_lab.tscn), which puts you at its back door.
##
## TURNING THROUGH W (round 2, Ramon: "the player currently cannot manipulate W using the mouse ... Reuse
## the established slice-control approach ... works for both environmental showcases"): each side's land
## and its trees stand on a turntable about the display's middle, and a right drag turns both together
## (the hall's pedestals' turn: only the floor's x, z and W, so trees never lean), so the two methods are
## always cut the same way. R levels them; Q and E still step you through W. The land is 2.5 m deep in W
## (`w_half`), so a turned slice crosses it in a band that narrows as the turn grows: no stop, the band
## is shown and said (the strip, a toast, the walls).
##
## ROUND 3 (follow_up/arboretum.md section 9, steps 48-54; Ramon, 10 Oct: "the split halfs are cool, but
## look carefully how to improve it ... think how to guide the eye"): ONE LAND, SPLIT BY YOUR PATH. The two
## displays close in on a sunken walkway 4.2 m wide, and the land is one valley mirrored across it (the
## right half samples the noise at minus its x), so the hills run on across the cut and the two methods
## still build the very same hills. The land stands on banks at eye level (0.9 m of layered soil, its cut
## faces showing stone, clay and topsoil). At the far end a low warm sun and a painted horizon; leaves
## blow down the cut toward you. A turn keeps the mirror: the right half turns as the left's reflection.
##
## ROUND 4 (section 10; Ramon's walkthrough parts 3 and 4): named TWO GARDENS; the room cropped to the
## slabs (the entrance 3 m before them, the side walls on their outer edges); the banks deep in W and the
## walk through W held to the land, so a slice can never empty the room (16); the smooth half a voxel level
## calmer (20); the doors' shimmer centred in the wall.
##
## ROUND 5 (section 11; Ramon: "The Gardens room requires more care because the last round of changes
## significantly altered things that were already working ... do not shorten the terraces, replace the
## sunset backdrop, or change the smooth terrace from green to sandy"): the far wall 3 m past the slabs'
## end (round 4 had put it 3 m inside them, which cut the terraces); the sunset one print over the whole
## far wall, the sign drawn into its sky (a wall piece carries one print, and round 4's sign had taken the
## middle piece, so between the terraces the wall showed plain blue); the smooth land green again, its
## balls overlapping and kept inside the edges; fewer leaves; the birches plain grey.
##
## NO class_name (engine_gotchas.md).

const KitPlayer := preload("res://ramon/Arboretum/botany_lab/carried/kit/kit_player.gd")
const Style := preload("res://ramon/Arboretum/botany_lab/carried/kit/kit_style.gd")
const Hud := preload("res://ramon/Arboretum/botany_lab/carried/scripts/rd_hud.gd")
const LabGrid := preload("res://ramon/Arboretum/botany_lab/carried/LabKit/lab_grid.gd")
const LabPrint := preload("res://ramon/Arboretum/botany_lab/carried/LabKit/lab_print.gd")
const Mats := preload("res://ramon/Arboretum/botany_lab/carried/LabKit/lab_materials.gd")
const Shimmer := preload("res://ramon/Arboretum/botany_lab/carried/voxel_lab/vl_shimmer_4d.gd")
const LoadBoard := preload("res://ramon/Arboretum/botany_lab/carried/voxel_lab/vl_load_board.gd")
const Graph := preload("res://ramon/Arboretum/botany_lab/carried/PathCreator/graph/path_graph.gd")
const PenWalk := preload("res://ramon/Arboretum/botany_lab/pen_walk.gd")
const LightEditor := preload("res://ramon/Arboretum/botany_lab/room/bl_light_editor.gd")
const Voxel := preload("res://ramon/Arboretum/botany/voxel_tree_builder.gd")
const Bake := preload("res://ramon/Arboretum/botany/bake_store.gd")
const BStyle := preload("res://ramon/Arboretum/botany/botany_style.gd")
const Pivots := preload("res://ramon/Arboretum/botany/tree_pivots.gd")
const Leaves := preload("res://ramon/Arboretum/botany/leaf_field_4d.gd")
const Wind := preload("res://ramon/Arboretum/botany/wind_4d.gd")
const Species := preload("res://ramon/Arboretum/botany/tree_species.gd")
const Ground := preload("res://ramon/Arboretum/botany_lab/carried/LabKit/carried/chickenpen/scripts/ground_basis_4d.gd")
const Drift := preload("res://ramon/Arboretum/botany_lab/flora/flora_drift_4d.gd")
const Gardens := preload("res://ramon/Arboretum/botany_lab/compare/bl_gardens_4d.gd")
## The mirror across the walkway (x to -x): the right half's turn is the left's reflected.
const BANK_W := 120.0
## The kit's walls' thickness (kit_room_4d.gd rebuild: t).
const WALL_T := 0.5
const MIRROR := Projection(Vector4(-1, 0, 0, 0), Vector4(0, 1, 0, 0), Vector4(0, 0, 1, 0), Vector4(0, 0, 0, 1))

const HALL := "res://ramon/Arboretum/botany_lab.tscn"
const ARRIVE_META := "botany_arrive"

@export_group("Land")
## The two displays' middles (x, z) and their size (x, z), metres.
@export var left_at: Vector2 = Vector2(-8.6, -2.0)
@export var right_at: Vector2 = Vector2(8.6, -2.0)
## (First run, 9 Oct: 14 m wide with a 4 m gap, and facing one side from the path put the camera over
## the other side's land; now a 6 m gap, the hills a little lower, the camera a metre closer.)
@export var display_size: Vector2 = Vector2(13.0, 26.0)
## The display's slab (its top, where the land starts), and the land's heights over it.
@export var slab_height: float = 0.9
@export var height_range: Vector2 = Vector2(0.4, 2.0)
## How deep in W the land is (metres either side of the slice).
@export var w_half: float = 1.25
## The blocky side's cells and the smooth side's voxels (m).
@export var block_cell: float = 0.5
@export var smooth_voxel: float = 0.4
@export var seed: int = 4242
## The trees' spots, the same on both sides (x, z from the display's middle).
## (Round 5: the fifth back at round 3's spot, the terraces whole again.)
@export var tree_spots: Array = [Vector2(-3.4, 8.0), Vector2(3.0, 3.6), Vector2(-2.2, -2.4), Vector2(3.4, -7.4), Vector2(-3.0, -10.6)]
## Round 4: the smooth half's edits on a coarser grid and its voxels a level larger (Ramon: "Reduce the
## terrain's geometric complexity by approximately one level ... broader, more coherent ground planes").
@export var smooth_cell: float = 1.0
## How far through W you can walk (the land is `w_half` deep each way): never past it (round 4, 16).
@export var w_walk_limit: float = 1.05

@export_group("Visit")
## (Round 4: inside the cropped room, far enough in that the camera behind you is too.)
@export var start_at: Vector2 = Vector2(0.0, 10.0)
@export var camera_distance: float = 3.6
@export var camera_height: float = 2.6
@export var camera_pitch_degrees: float = -10.0

var player: CharacterBody4D
var hud: Control
var light_editor: Control
var noise := FastNoiseLite.new()
## What was built, for the board, the panels and the runners.
var stats: Dictionary = {"blocky": {}, "smooth": {}, "trees": {}}
var loading: bool = true
var _board: Control
var _board_t: float = 0.0
var _world: Node4D
var _trigger: Node4D
var _edits: Array = []
var _sent: int = 0
var _phase: String = "idle"
var _stable: int = 0
var _last_tets: int = -1
var _smooth_t0: int = 0
var _trees_done: bool = false
var _leaving: bool = false
var _door_z: float = 0.0
## Both lands' turn through W (a ground basis: the floor only), and their turntables.
var turn_basis: Projection = Projection.IDENTITY
var _turn_blocky: Node4D
var _turn_smooth: Node4D
var _band_said: bool = false
## Round 4: the two gardens' dressing (bl_gardens_4d.gd), made once the trees stand.
var gardens: Node4D
var _strip_tilt: int = -1


func _ready() -> void:
	noise.seed = seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.085
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 3
	var room: Node = get_node_or_null("Room")
	if room != null:
		# Round 3: the low warm sun at the far end (the Sun node aims it), a warmer ambient.
		var light: Dictionary = Style.ROOM_LIGHT.duplicate(true)
		var b: Dictionary = light["bright"]
		b["key_color"] = Color(1.0, 0.74, 0.48)
		b["key_energy"] = 0.9
		b["ambient"] = Color(0.26, 0.26, 0.32)
		b["fill_color"] = Color(0.55, 0.65, 0.95)
		b["fill_energy"] = 0.14
		room.set("mood_overrides", light)
		room.call("set_mood", "bright", true, false)
		room.set("mood_key", KEY_NONE)
	Style.apply("bright")
	# The land's two lab-grid colours: grass on the top cells, soil under them (lines a little darker,
	# the kit's contrast).
	LabGrid.set_swatch("botany_grass", Color(0.36, 0.55, 0.22), Color(0.29, 0.46, 0.17), Color(0.33, 0.51, 0.20), 0.6)
	LabGrid.set_swatch("botany_soil", Color(0.45, 0.36, 0.27), Color(0.37, 0.29, 0.21), Color(0.42, 0.33, 0.25), 0.6)
	LabGrid.set_swatch("strata_stone", Color(0.36, 0.33, 0.3), Color(0.3, 0.27, 0.24), Color(0.34, 0.31, 0.28), 0.35)
	LabGrid.set_swatch("strata_clay", Color(0.56, 0.4, 0.26), Color(0.48, 0.33, 0.2), Color(0.53, 0.37, 0.24), 0.3)
	LabGrid.set_swatch("strata_soil", Color(0.24, 0.17, 0.12), Color(0.19, 0.13, 0.09), Color(0.22, 0.15, 0.11), 0.3)
	_build_slabs()
	_build_drift()
	_turn_blocky = _turntable("TurnBlocky", left_at)
	_turn_smooth = _turntable("TurnSmooth", right_at)
	_build_blocky()
	_start_smooth()
	_build_route()
	_build_walls()
	player = KitPlayer.make()
	player.name = "Player"
	PenWalk.apply(player)
	add_child(player)
	var rig: Node = player.get_node_or_null("CameraRig")
	if rig != null:
		rig.set("slice_turning", false)
		rig.set("pitch", deg_to_rad(camera_pitch_degrees))
		rig.set("distance", camera_distance)
		rig.set("_zoom_target", camera_distance)
		rig.set("_rest_distance", camera_distance)
		rig.set("pivot_height", camera_height)
		rig.set("_home_pivot", camera_height)
		rig.call("_apply")
	go_to(Vector4(start_at.x, 0.05, start_at.y, 0.0), 0.0)
	get_tree().root.remove_meta(ARRIVE_META)
	for pn in [get_node_or_null("PanelBlocky"), get_node_or_null("PanelSmooth")]:
		if pn != null:
			pn.set("player", player)
	_build_hud()
	_build_door()
	_open_board()


# -- the land ------------------------------------------------------------------------------------------------

## The height of the land over the slab at (x, z, w), display-local metres.
func height_at(x: float, z: float, w: float) -> float:
	var n: float = noise.get_noise_3d(x, z, w * 1.6) * 0.5 + 0.5
	return lerpf(height_range.x, height_range.y, pow(clampf(n, 0.0, 1.0), 1.35))


## A side's turntable: the display's middle at the slab's top. Its land and its trees are built under it.
func _turntable(nm: String, at: Vector2) -> Node4D:
	var n := Node4D.new()
	n.name = nm
	n.position = Vector4(at.x, slab_height, at.y, 0.0)
	add_child(n)
	return n


## The two banks the land stands on (round 3: at eye level, 0.9 m): layered soil, stone at the foot, clay,
## dark topsoil under the land, so the walkway's cut faces read as the ground cut open.
func _build_slabs() -> void:
	var layers: Array = [["Stone", 0.0, 0.36, "strata_stone"], ["Clay", 0.36, 0.66, "strata_clay"], ["Soil", 0.66, 1.0, "strata_soil"]]
	for side in [["SlabBlocky", left_at], ["SlabSmooth", right_at]]:
		var at: Vector2 = side[1]
		for ly in layers:
			var y0: float = float(ly[1]) * slab_height
			var y1: float = float(ly[2]) * slab_height
			# Round 4 (16): the brown base deep in W, so whatever slice you stand in cuts it (the land
			# above is only 2.5 m deep; the Voxel Lab's ground is endless in W, which is why slicing there
			# never empties).
			var size := Vector4(display_size.x + 0.4, y1 - y0, display_size.y + 0.4, BANK_W)
			var m := MeshInstance4D.new()
			m.name = String(side[0]) + String(ly[0])
			m.mesh = Mats.box_mesh(size)
			m.position = Vector4(at.x, (y0 + y1) * 0.5, at.y, 0.0)
			m.material_override = LabGrid.material(String(ly[3]), size, m.position)
			add_child(m)
	# The banks are solid: one box each (box-only physics).
	for at in [left_at, right_at]:
		var body := StaticBody4D.new()
		body.position = Vector4(at.x, slab_height * 0.5, at.y, 0.0)
		var cs := CollisionShape4D.new()
		var bs := BoxShape4D.new()
		bs.size = Vector4(display_size.x + 0.4, slab_height, display_size.y + 0.4, BANK_W)
		cs.shape = bs
		body.add_child(cs)
		add_child(body)


## Leaves on the wind down the cut, from the far end toward you (the pen's flying leaves, carried).
func _build_drift() -> void:
	var d := Node4D.new()
	d.name = "Leaves"
	d.set_script(Drift)
	d.set("stream", true)
	# Round 4 (30): from higher, drifting down rather than out of the middle of the room. Round 5 (42: "Significantly
	# reduce the particle count ... a restrained finishing effect"): a quarter of them, a smaller gust.
	d.set("source", Vector3(0.0, 7.2, -11.0))
	d.set("source_radius", 6.5)
	d.set("reach", 28.0)
	d.set("floor_y", 0.04)
	d.set("amount", 60)
	d.set("gust_extra", 1.5)
	d.set("leaf_share", 0.7)
	d.set("leaf_size", 0.06)
	d.set("colours", PackedColorArray([Color(0.48, 0.6, 0.2), Color(0.86, 0.66, 0.22), Color(0.72, 0.38, 0.15), Color(1.0, 0.88, 0.62)]))
	d.set("wind", Wind.of(get_tree()))
	add_child(d)


## LEFT: the land in 0.5 m cells, a box each (the pedestal 01 mesher), the top cell grass.
func _build_blocky() -> void:
	var t0: int = Time.get_ticks_usec()
	var c: float = block_cell
	var nx: int = int(round(display_size.x / c))
	var nz: int = int(round(display_size.y / c))
	var nw: int = int(round(w_half * 2.0 / c))
	var soil: Dictionary = {}
	var grass: Dictionary = {}
	for ix in nx:
		for iz in nz:
			for iw in nw:
				var x: float = (float(ix) + 0.5) * c - display_size.x * 0.5
				var z: float = (float(iz) + 0.5) * c - display_size.y * 0.5
				var w: float = (float(iw) + 0.5) * c - w_half
				var top: int = maxi(1, int(round(height_at(x, z, w) / c)))
				for iy in top:
					var k := Vector4i(ix - nx / 2, iy, iz - nz / 2, iw - nw / 2)
					if iy == top - 1:
						grass[k] = Vector3(0.0, 0.0, 0.0)
					else:
						soil[k] = Vector3(0.0, 0.0, 0.0)
	var all: Dictionary = soil.duplicate()
	all.merge(grass)
	var holder := Node4D.new()
	holder.name = "LandBlocky"
	# Cells centred on the slice in W (an odd count: the middle one straddles w 0, so the slice never
	# runs along a cell's face), and in x and z on the display.
	var at: Vector4 = Vector4(left_at.x - float(nx % 2) * c * 0.5, slab_height, left_at.y - float(nz % 2) * c * 0.5, -float(nw % 2) * c * 0.5 + c * 0.5 * float(1 - nw % 2))
	holder.position = at - _turn_blocky.position
	_turn_blocky.add_child(holder)
	var tets: int = 0
	for part in [["Grass", grass, "botany_grass"], ["Soil", soil, "botany_soil"]]:
		var mesh: ArrayTetraMesh4D = Voxel.mesh(all, c, part[1])
		var mi := MeshInstance4D.new()
		mi.name = String(part[0])
		mi.mesh = mesh
		var bounds := Vector4(display_size.x, height_range.y, display_size.y, w_half * 2.0)
		mi.material_override = LabGrid.material(String(part[2]), bounds, at)
		holder.add_child(mi)
		tets += mesh.get_simplex_cell_vertex_indices().size() / 4
	stats["blocky"] = {"cells": all.size(), "tets": tets, "ms": (Time.get_ticks_usec() - t0) / 1000.0}


## RIGHT: the same heights in the engine's voxel world: a column of soil under every height and a ball
## of grass at its top, written once the world's chunks there are defined (an edit into an undefined
## chunk is lost: engine_capabilities.md), then meshed by the engine.
func _start_smooth() -> void:
	_smooth_t0 = Time.get_ticks_usec()
	var v: float = smooth_voxel
	_world = ClassDB.instantiate("VoxelWorld4D")
	_world.name = "LandSmooth"
	var gen = ClassDB.instantiate("BoxVoxelGenerator4D")
	gen.set("material_inner", 254)
	gen.set("material_outer", 254)
	_world.set("generator", gen)
	var pal = ClassDB.instantiate("VoxelMaterialPalette4D")
	pal.set("colors", PackedColorArray([Color(0.5, 0.5, 0.5), Color(0.42, 0.33, 0.24), Color(0.36, 0.55, 0.22)]))
	_world.set("material_palette", pal)
	_world.set("scale", Vector4(v, v, v, v))
	_turn_smooth.add_child(_world)
	# The trigger beside the world, at its middle in metres (as the smooth tree's builder places it);
	# its reach in voxels.
	_trigger = ClassDB.instantiate("VoxelLoadTrigger4D")
	_trigger.name = "LandSmoothTrigger"
	add_child(_trigger)
	_trigger.set("voxel_world_path", _trigger.get_path_to(_world))
	# (On the turntable's axis, so a turn never moves it relative to the world.)
	_trigger.set("position", _turn_smooth.position + Vector4(0.0, height_range.y * 0.5, 0.0, 0.0))
	var reach: float = Vector4(display_size.x * 0.5, height_range.y, display_size.y * 0.5, w_half).length()
	_trigger.set("load_distance", reach / v + 12.0)
	# The edits, in voxels from the world's origin (the display's middle at the slab's top). Round 4: on
	# the coarser `smooth_cell` grid.
	var c: float = smooth_cell
	var nx: int = int(round(display_size.x / c))
	var nz: int = int(round(display_size.y / c))
	var nw: int = maxi(int(round(w_half * 2.0 / c)), 2)
	# A small offset off the sample rows, as the Voxel Lab's bricks have (vl_recipe.gd JITTER): faces on
	# a sample row fray.
	var jit := Vector4(0.031, 0.027, 0.023, 0.019)
	for ix in nx:
		for iz in nz:
			for iw in nw:
				var x: float = (float(ix) + 0.5) * c - display_size.x * 0.5
				var z: float = (float(iz) + 0.5) * c - display_size.y * 0.5
				var w: float = (float(iw) + 0.5) * (w_half * 2.0 / float(nw)) - w_half
				# The mirror: this half's x is the other's minus x (the walkway between them).
				var h: float = height_at(-x, z, w)
				# Round 4 (17; Ramon: "a large green surface that looks like a mattress hanging over the
				# underlying brown geometry"): the grass ball kept inside the land's footprint, none hanging over
				# an edge. ROUND 5 (40: "The smooth terrain on the right used to have an attractive green
				# surface. It has now become a sandy-looking landscape with strange raised green patches"): round
				# 4 also cut the balls to under half a cell and wrote the soil up to 10 cm under the surface, so
				# the soil showed between balls that read as lumps. Now each ball is 0.85 of a cell, so its
				# neighbours overlap into one continuous green skin, and its middle is moved in from an edge
				# rather than the ball shrunk. The soil column stops 0.6 m under the surface, under the skin
				# everywhere, and shows only on the cut faces.
				var r: float = c * 0.85
				var bx: float = clampf(x, -display_size.x * 0.5 + r + 0.03, display_size.x * 0.5 - r - 0.03)
				var bz: float = clampf(z, -display_size.y * 0.5 + r + 0.03, display_size.y * 0.5 - r - 0.03)
				var ball = ClassDB.instantiate("SphereVoxelEdit4D")
				ball.set("center", (Vector4(bx, h - r * 0.85, bz, w) + jit) / v)
				ball.set("radius", r / v)
				ball.set("fill_material", 2)
				_edits.append(ball)
				var col_top: float = maxf(h - 0.6, 0.05)
				var box = ClassDB.instantiate("BoxVoxelEdit4D")
				box.set("position", (Vector4(x - c * 0.5, 0.0, z - c * 0.5, w - c * 0.5) + jit) / v)
				box.set("size", Vector4(c, col_top, c, c) / v)
				box.set("fill_material", 1)
				_edits.append(box)
	_phase = "loading"


func _feed_smooth() -> void:
	match _phase:
		"loading":
			var probe: Array = [Vector4(-display_size.x * 0.5, 0.0, -display_size.y * 0.5, -w_half), Vector4(display_size.x * 0.5, height_range.y, display_size.y * 0.5, w_half),
				Vector4.ZERO, Vector4(-display_size.x * 0.5, height_range.y, display_size.y * 0.5, w_half), Vector4(display_size.x * 0.5, 0.0, -display_size.y * 0.5, -w_half)]
			var data = _world.call("get_voxel_data")
			var ready: bool = data != null
			if ready:
				for p in probe:
					var k := Vector4i(int(floor(p.x / smooth_voxel)), int(floor(p.y / smooth_voxel)), int(floor(p.z / smooth_voxel)), int(floor(p.w / smooth_voxel)))
					if not bool(data.call("is_voxel_defined", k)):
						ready = false
						break
			if ready:
				_phase = "editing"
		"editing":
			var n: int = mini(1500, _edits.size() - _sent)
			for i in n:
				_world.call("apply_edit", _edits[_sent + i])
			_sent += n
			if _sent >= _edits.size():
				_phase = "meshing"
		"meshing":
			var t: int = smooth_tets()
			if t == _last_tets and t > 0:
				_stable += 1
			else:
				_stable = 0
			_last_tets = t
			if _stable >= 30:
				_phase = "ready"
				stats["smooth"] = {"edits": _edits.size(), "tets": t, "voxel": smooth_voxel, "ms": (Time.get_ticks_usec() - _smooth_t0) / 1000.0}


## The smooth land's tetrahedra as meshed so far (every chunk mesh under the world).
func smooth_tets() -> int:
	var n: int = 0
	if _world == null:
		return 0
	for m in _world.find_children("*", "MeshInstance4D", true, false):
		var mesh: Mesh4D = (m as MeshInstance4D).mesh
		if mesh is TetraMesh4D:
			n += (mesh as TetraMesh4D).get_simplex_cell_vertex_indices().size() / 4
	return n


# -- the trees ---------------------------------------------------------------------------------------------------

## The trees on both sides, on the same spots: voxel trees left, lofted oaks with GPU leaves right.
func _place_trees() -> void:
	var t0: int = Time.get_ticks_usec()
	var vx: Array = []
	var vsk: Array = []
	for i in 3:
		vx.append(Bake.load_res("grove_vx_%d" % i))
		vsk.append(Bake.load_res("grove_sk_%d_skeleton" % i))
	var ok: Array = [Bake.load_res("grove_ok_0"), Bake.load_res("grove_ok_1")]
	var osk: Array = [Bake.load_res("grove_oak_0_skeleton"), Bake.load_res("grove_oak_1_skeleton")]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed + 7
	var drawn := {"blocky": 0, "smooth": 0, "leaves": 0}
	var leaf_src: Dictionary = {}
	var mats_v: Dictionary = {}
	var mats_o: Dictionary = {}
	for i in tree_spots.size():
		var spot: Vector2 = tree_spots[i]
		var yaw: float = rng.randf() * TAU
		var scale_k: float = rng.randf_range(0.9, 1.1)
		# Left: a voxel tree, standing on the top of its column of cells.
		var si: int = i % 3
		if vx[si] != null and vsk[si] != null:
			var top: float = maxf(1.0, round(height_at(spot.x, spot.y, 0.0) / block_cell)) * block_cell
			var t: Node4D = _tree(_turn_blocky, vx[si], vsk[si], Vector4(spot.x, top - 0.1, spot.y, 0.0), yaw, 3.9 * scale_k, false, mats_v, si)
			t.name = "BlockyTree%d" % i
			drawn["blocky"] = int(drawn["blocky"]) + (vx[si] as TetraMesh4D).get_simplex_cell_vertex_indices().size() / 4
		# Right: an oak, on the rounded land (its height there, a little sunk).
		var oi: int = i % 2
		if ok[oi] != null and osk[oi] != null:
			var h: float = height_at(spot.x, spot.y, 0.0)
			var o: Node4D = _tree(_turn_smooth, ok[oi], osk[oi], Vector4(-spot.x, h - 0.15, spot.y, 0.0), -yaw, 5.2 * scale_k, true, mats_o, oi)
			o.name = "SmoothTree%d" % i
			drawn["smooth"] = int(drawn["smooth"]) + (ok[oi] as TetraMesh4D).get_simplex_cell_vertex_indices().size() / 4
			var lf := Node4D.new()
			lf.name = "Leaves"
			lf.set_script(Leaves)
			Species.oak_leaves(lf, true)
			o.add_child(lf)
			if leaf_src.has(oi):
				lf.call("share_from", leaf_src[oi])
			else:
				lf.call("grow_leaves", osk[oi], 60 + oi)
				leaf_src[oi] = lf
			drawn["leaves"] = int(drawn["leaves"]) + int(lf.get("count"))
	stats["trees"] = {"count": tree_spots.size(), "blocky_tets": drawn["blocky"], "smooth_tets": drawn["smooth"], "leaves": drawn["leaves"],
		"ms": (Time.get_ticks_usec() - t0) / 1000.0}
	gardens = Node4D.new()
	gardens.name = "Gardens"
	gardens.set_script(Gardens)
	gardens.set("room", self)
	add_child(gardens)
	gardens.call("build")
	gardens.call("start_grass")
	stats["gardens"] = gardens.get("stats")
	_trees_done = true


## A tree on `table` (its turntable), at `at` there.
func _tree(table: Node4D, mesh: Resource, sk: Resource, at: Vector4, yaw: float, height: float, oak: bool, mats: Dictionary, si: int) -> Node4D:
	var tree := Node4D.new()
	table.add_child(tree)
	var summ: Dictionary = sk.call("summary")
	var s: float = height / maxf(float(summ["height"]), 0.5)
	tree.position = at
	tree.basis = Basis4D.from_zx(yaw)
	tree.scale = Vector4(s, s, s, s)
	if not mats.has(si):
		mats[si] = Pivots.texture(sk)
	var mi := MeshInstance4D.new()
	mi.mesh = mesh
	var mat: TetraMaterial4D = BStyle.tree_material(sk, float(summ["height"]), oak, mats[si])
	mi.material_override = mat
	tree.add_child(mi)
	var wind: Node = Wind.of(get_tree())
	if wind != null:
		wind.call("register", BStyle.shader_of(mat), tree)
	return tree


# -- the route, the walls, the HUD, the door ------------------------------------------------------------------

## Down the middle: from the door to the far end, a ring at each side's middle (facing it) and one at
## the end.
func _build_route() -> void:
	var net: Node = get_node_or_null("Paths/Center")
	if net == null:
		return
	var g: Resource = Graph.new()
	var b := {"band": 8.0}
	var s: int = g.call("add_node", "start", Vector4(0.0, 0.0, 12.6, 0.0), b)
	var j1: int = g.call("add_node", "junction", Vector4(0.0, 0.0, 4.2, 0.0), b)
	var dl: int = g.call("add_node", "destination", Vector4(-1.2, 0.0, 3.0, 0.0), {"band": 8.0, "state": "available", "target": "Blocky", "frame": "none", "approach": Vector2(1, 0)})
	var j2: int = g.call("add_node", "junction", Vector4(0.0, 0.0, -1.0, 0.0), b)
	var dr: int = g.call("add_node", "destination", Vector4(1.2, 0.0, -2.2, 0.0), {"band": 8.0, "state": "arrival", "target": "Smooth", "frame": "none", "approach": Vector2(-1, 0)})
	# (Round 5: the walkway's end, past the slabs' end at -15.2, before the far wall at -18.2.)
	var e: int = g.call("add_node", "destination", Vector4(0.0, 0.0, -16.0, 0.0), {"band": 8.0, "state": "arrival", "target": "End", "frame": "none", "approach": Vector2(0, 1)})
	g.call("add_edge", s, j1, "primary", "static", 8.0)
	g.call("add_edge", j1, dl, "primary", "static", 8.0)
	g.call("add_edge", j1, j2, "primary", "static", 8.0)
	g.call("add_edge", j2, dr, "primary", "static", 8.0)
	g.call("add_edge", j2, e, "primary", "static", 8.0)
	net.set("graph", g)


## The two blue walls' pages: the room claims each side wall's stretch beside its display, code blue,
## and prints a page of its own into it (a heading, three lines, a diagram), as the Aquatic Lab's fish
## wall prints its cards.
func _build_walls() -> void:
	var hall: Node = get_node_or_null("Hall")
	if hall == null:
		return
	for side in ["w", "e"]:
		var holder := Node4D.new()
		holder.name = "Wall_" + side
		add_child(holder)
		hall.call("claim_wall", side, "blue", holder, -17.0, 17.0)
	# Round 3: the far wall, the horizon the walkway runs toward. Round 5: its whole face is the backdrop's
	# print (the claim is for its swatch under it).
	var far := Node4D.new()
	far.name = "Wall_n"
	add_child(far)
	hall.call("claim_wall", "n", "blue", far, -16.0, 16.0)
	(func() -> void: _print_walls()).call_deferred()


func _print_walls() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var hall: Node = get_node_or_null("Hall")
	for side in ["w", "e"]:
		var blocky: bool = side == "w"
		var tex: Texture2D = await LabPrint.render(get_tree(), Vector2i(2800, 1000), func(c: Control) -> void: _page(c, blocky))
		if tex == null:
			continue
		# 14 x 5 m, the page's own shape (2800 x 1000), centred on the display.
		# (Along the wall from the room's middle, z -2 since round 5, the displays' own: the page on them.)
		var mid_z: float = (hall as Node4D).position.z
		for tg in hall.call("print_targets", side, -9.0 - mid_z, 5.0 - mid_z, 5.2, 10.2):
			var m: TetraMaterial4D = (tg[0] as MeshInstance4D).material_override as TetraMaterial4D
			if m != null:
				LabGrid.set_print(m, tex, tg[1], tg[2], Color.WHITE, 0.2)
				LabGrid.set_print_strength(m, 1.0)
				m.get_cross_section_material_3d().set_shader_parameter("print_aa", 1.0)
	var sky_top: Color = LabGrid.values("kit_code_blue")[0]
	var hs: Vector3 = hall.get("size")
	# Round 4 (26): a metre more sky (the warm band's top at 7.4 m), drawn crisp. Round 5 (38, 39): over the
	# whole far wall, floor to ceiling, at 160 px a metre (4,832 x 1,920), the sky deepening above the band
	# and the room's name in it.
	var htex: Texture2D = await LabPrint.render(get_tree(), Vector2i(int(hs.x * 160.0), int(hs.y * 160.0)), func(c: Control) -> void: _horizon(c, sky_top))
	if htex != null:
		for tg in hall.call("print_targets", "n", -hs.x * 0.5, hs.x * 0.5, 0.0, hs.y):
			var m: TetraMaterial4D = (tg[0] as MeshInstance4D).material_override as TetraMaterial4D
			if m != null:
				LabGrid.set_print(m, htex, tg[1], tg[2], Color.WHITE, 0.55)
				LabGrid.set_print_strength(m, 1.0)


## Round 3: the far wall's horizon: the walkway runs toward a low warm sun setting between layers of distant
## hills, the sky going up into blue. Round 4 kept it (a metre more sky, the brown triangle gone, crisper).
## Round 5: over the whole far wall: the same band, sun and hills (the warm band 2.9 to 7.4 m up, as round 4
## had it), and above it the sky going on up, deepening toward the ceiling, with the room's name in it.
func _horizon(c: Control, top: Color) -> void:
	var sz: Vector2 = c.size
	var px: float = sz.y / 12.0
	var hy: float = sz.y - 2.9 * px
	var band_top: float = sz.y - 7.4 * px
	# Above the band: the evening sky, from a deep blue at the ceiling down to the band's own top colour.
	var night := Color(0.05, 0.1, 0.3)
	c.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(sz.x, 0), Vector2(sz.x, band_top + 1.0), Vector2(0, band_top + 1.0)]), PackedColorArray([night, night, top, top]))
	var bands: Array = [[0.0, top], [0.35, Color(0.52, 0.42, 0.66)], [0.62, Color(0.92, 0.56, 0.42)], [0.86, Color(1.0, 0.74, 0.44)], [1.0, Color(1.0, 0.88, 0.62)]]
	for i in bands.size() - 1:
		var y0: float = band_top + float(bands[i][0]) * (hy - band_top)
		var y1: float = band_top + float(bands[i + 1][0]) * (hy - band_top)
		var c0: Color = bands[i][1]
		var c1: Color = bands[i + 1][1]
		c.draw_polygon(PackedVector2Array([Vector2(0, y0), Vector2(sz.x, y0), Vector2(sz.x, y1), Vector2(0, y1)]), PackedColorArray([c0, c0, c1, c1]))
	# The room's name in the sky (it was the kit's wall sign on this wall, which took the wall's middle piece).
	var fb: Font = LabPrint.font("black")
	var fs: Font = LabPrint.font("bold")
	var ty: float = sz.y - 10.0 * px
	c.draw_string(fb, Vector2(0.0, ty), "TWO GARDENS", HORIZONTAL_ALIGNMENT_CENTER, sz.x, int(1.15 * px), Color(1, 1, 1, 0.96))
	c.draw_string(fs, Vector2(0.0, ty + 0.62 * px), "BLOCKY ON THE LEFT  ·  SMOOTH ON THE RIGHT", HORIZONTAL_ALIGNMENT_CENTER, sz.x, int(0.32 * px), Color(1, 1, 1, 0.8))
	# The sun, low and half-hidden, at the walkway's end; its halo.
	var sun := Vector2(sz.x * 0.5, hy - 0.24 * px)
	for k in 6:
		var r: float = (1.2 + float(k) * 0.6) * px
		c.draw_circle(sun, r, Color(1.0, 0.86, 0.6, 0.09), true, -1.0, true)
	c.draw_circle(sun, 1.1 * px, Color(1.0, 0.95, 0.78), true, -1.0, true)
	# The hills: three ranges, farther ones paler (atmosphere), each a rolling line of sines.
	var ranges: Array = [[Color(0.66, 0.5, 0.62), 0.7, 0.4, 1.3], [Color(0.46, 0.34, 0.5), 0.52, 0.7, 2.9], [Color(0.28, 0.21, 0.34), 0.34, 1.1, 4.7]]
	for rg in ranges:
		var pts := PackedVector2Array()
		var n: int = 360
		for i in n + 1:
			var x: float = sz.x * float(i) / float(n)
			var f: float = float(rg[2]) / px
			var ph: float = float(rg[3])
			var y: float = hy - float(rg[1]) * px * (0.55 + 0.3 * sin(x * f + ph) + 0.15 * sin(x * f * 2.7 + ph * 1.9))
			pts.append(Vector2(x, y))
		pts.append(Vector2(sz.x, sz.y))
		pts.append(Vector2(0.0, sz.y))
		c.draw_colored_polygon(pts, rg[0])
	# The ground under the hills, dark (round 4: the walkway's brown triangle gone).
	c.draw_rect(Rect2(0.0, hy + 0.08 * px, sz.x, sz.y - hy - 0.08 * px), Color(0.16, 0.12, 0.18))


## A wall's page: white on clear (the wall's blue shows).
func _page(c: Control, blocky: bool) -> void:
	var sz: Vector2 = c.size
	var u: float = sz.y / 1000.0
	var white := Color(1, 1, 1, 1)
	var soft := Color(1, 1, 1, 0.85)
	var fb: Font = LabPrint.font("black")
	var fs: Font = LabPrint.font("bold")
	var fl: Font = LabPrint.font("body")
	var x: float = 80.0 * u
	c.draw_string(fs, Vector2(x, 120.0 * u), "THE LEFT HALF" if blocky else "THE RIGHT HALF", HORIZONTAL_ALIGNMENT_LEFT, -1, int(44 * u), soft)
	c.draw_string(fb, Vector2(x, 270.0 * u), "THE BLOCKY WAY" if blocky else "THE SMOOTH WAY", HORIZONTAL_ALIGNMENT_LEFT, -1, int(150 * u), white)
	var lines: Array = ["Space is cut into 4D cells. A cell is full or empty.",
		"Every full cell is drawn as a box: only the faces with an empty neighbour.",
		"Square at every size you can afford: halve the cell, eight times the cost.",
		"Right drag turns both lands through W: here the cut steps, cell by cell."] if blocky else [
		"The same land, written as balls and columns into the engine's voxel world.",
		"Dual contouring: each cell gets one point where the surface really crosses it.",
		"The balls melt into one surface: rounded hills, about the same cost as boxes.",
		"Right drag turns both lands through W: here the cut stays smooth."]
	for i in lines.size():
		c.draw_string(fl, Vector2(x, (420.0 + 90.0 * float(i)) * u), String(lines[i]), HORIZONTAL_ALIGNMENT_LEFT, sz.x * 0.52, int(46 * u), soft)
	# The diagram, on the right: a row of cells and what each method makes of them.
	var d0 := Vector2(sz.x * 0.6, 160.0 * u)
	var cell: float = 70.0 * u
	var heights := [3, 4, 4, 5, 6, 5, 4, 3, 3, 4]
	for i in heights.size():
		for k in int(heights[i]):
			var r := Rect2(d0 + Vector2(float(i) * cell, (7.0 - float(k)) * cell), Vector2(cell, cell))
			if blocky:
				c.draw_rect(r.grow(-3.0 * u), Color(1, 1, 1, 0.9 if k == int(heights[i]) - 1 else 0.45))
			else:
				c.draw_rect(r, Color(1, 1, 1, 0.12), false, 2.0 * u)
	if not blocky:
		var pts := PackedVector2Array()
		for i in heights.size():
			var cx: float = d0.x + (float(i) + 0.5) * cell
			pts.append(Vector2(cx, d0.y + (7.0 - float(heights[i]) + 0.55) * cell))
		var smooth := PackedVector2Array()
		for i in pts.size() - 1:
			for s in 8:
				var f: float = float(s) / 8.0
				var a: Vector2 = pts[maxi(i - 1, 0)]
				var b: Vector2 = pts[i]
				var cc: Vector2 = pts[i + 1]
				var dd: Vector2 = pts[mini(i + 2, pts.size() - 1)]
				smooth.append(0.5 * ((2.0 * b) + (-a + cc) * f + (2.0 * a - 5.0 * b + 4.0 * cc - dd) * f * f + (-a + 3.0 * b - 3.0 * cc + dd) * f * f * f))
		smooth.append(pts[pts.size() - 1])
		c.draw_polyline(smooth, white, 8.0 * u, true)
		for p in pts:
			c.draw_circle(p, 9.0 * u, white)
	c.draw_string(fs, Vector2(d0.x, d0.y + 8.6 * cell), "CELLS TO BOXES" if blocky else "CELLS TO ONE SURFACE", HORIZONTAL_ALIGNMENT_LEFT, -1, int(40 * u), soft)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HUD"
	add_child(layer)
	hud = Control.new()
	hud.set_script(Hud)
	hud.set("glass", true)
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(hud)
	_strip()
	var dlayer := CanvasLayer.new()
	dlayer.name = "Dev"
	dlayer.layer = 5
	add_child(dlayer)
	light_editor = PanelContainer.new()
	light_editor.name = "LightEditor"
	light_editor.set_script(LightEditor)
	light_editor.set("room", self)
	dlayer.add_child(light_editor)


## The way back: the holographic doorway in the near (+z) wall. Round 4 (14): in the middle of the wall's
## thickness (the kit's walls are 0.5 m), the opening's own size, so it sits in the doorway from the front
## and from the side.
func _build_door() -> void:
	var hall: Node4D = get_node_or_null("Hall") as Node4D
	var hs: Vector3 = hall.get("size") if hall != null else Vector3(36, 12, 48)
	_door_z = hs.z * 0.5 + (hall.position.z if hall != null else 0.0)
	var opening: Array = (hall.get("doorways") as Array)[0] if hall != null and not (hall.get("doorways") as Array).is_empty() else ["s", -1.6, 1.6, 4.4]
	var sh := Node4D.new()
	sh.name = "Shimmer"
	sh.set_script(Shimmer)
	sh.set("width", float(opening[2]) - float(opening[1]))
	sh.set("height", float(opening[3]) - 0.01)
	sh.position = Vector4(0.0, 0.0, _door_z + WALL_T * 0.5, 0.0)
	add_child(sh)


# -- each frame -------------------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if _phase != "ready" and _phase != "idle":
		_feed_smooth()
	if _phase == "ready" and not _trees_done:
		_place_trees()
	if _board != null:
		_feed_board(delta)
	if player == null or loading or _leaving:
		return
	var p: Vector4 = player.global_position
	if p.z > _door_z - 0.3 and absf(p.x) < 1.6:
		_leaving = true
		player.set("input_enabled", false)
		var sh: Node = get_node_or_null("Shimmer")
		if sh != null:
			sh.call("flash_out", self, back_to_hall)
		else:
			back_to_hall()
	for pn in [get_node_or_null("PanelBlocky"), get_node_or_null("PanelSmooth")]:
		if pn != null:
			var pp: Vector4 = (pn as Node4D).global_position
			pn.call("set_near", Vector2(p.x - pp.x, p.z - pp.z).length() < 1.7)
	_turn_blocky.basis = turn_basis
	_turn_smooth.basis = MIRROR * turn_basis * MIRROR
	var tilt: int = int(round(rad_to_deg(Ground.tilt(turn_basis))))
	if tilt != _strip_tilt:
		_strip_tilt = tilt
		_strip()


## Round 4 (16): never further through W than the land reaches, so the slice always holds it (pressing E
## on and on used to walk you past it into an empty room; only R, which levels the turn, seemed to help).
func _physics_process(_delta: float) -> void:
	if player == null:
		return
	var p: Vector4 = player.global_position
	if absf(p.w) > w_walk_limit:
		p.w = clampf(p.w, -w_walk_limit, w_walk_limit)
		player.global_position = p
		var v: Vector4 = player.get("linear_velocity")
		if v.w * p.w > 0.0:
			v.w = 0.0
			player.set("linear_velocity", v)


## The keys, and how far the lands are turned once they are.
func _strip() -> void:
	if hud == null:
		return
	var out: Array = [["WASD", "Move"], ["Mouse", "Look"], ["Right drag", "Turn both lands through W"], ["Q / E", "Step through W"], ["G", "Gust of wind"]]
	if _strip_tilt > 0:
		out.insert(3, ["%d°" % _strip_tilt, "turned through W"])
		out.insert(4, ["R", "Level"])
	hud.set("strip", out)


## A right drag: both lands turned through W together, about their own middles (the hall's turn: a
## sideways drag tips the width into W, an up and down drag the depth). The first real turn says why
## the land then shows as a band.
func turn_by(dx: float, dy: float) -> void:
	turn_basis = Ground.cleaned(Ground.sliced(turn_basis, Vector2(dx, dy)))
	if not _band_said and rad_to_deg(Ground.tilt(turn_basis)) > 12.0:
		_band_said = true
		hud.call("toast", "Both lands are %.1f m deep in W: turned, your slice crosses them in a band" % (w_half * 2.0))


func level() -> void:
	turn_basis = Projection.IDENTITY


func _input(event: InputEvent) -> void:
	if player == null or loading or _leaving:
		return
	var mm := event as InputEventMouseMotion
	if mm != null and (mm.button_mask & MOUSE_BUTTON_MASK_RIGHT) != 0 and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		turn_by(mm.relative.x * 0.006, mm.relative.y * 0.006)
		get_viewport().set_input_as_handled()


func back_to_hall() -> void:
	get_tree().root.set_meta(ARRIVE_META, "compare")
	get_tree().change_scene_to_file(HALL)


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo or player == null:
		return
	match k.keycode:
		KEY_G:
			var w: Node = Wind.of(get_tree())
			if w != null:
				# Round 2 (Ramon: the Gust of wind "appears to do nothing"): it did run, but it began 8 m out
				# and reached the first tree seconds later, at the room's mild strength. Now it starts at
				# the trees, wide and hard, and crosses the room fast enough to follow.
				w.set("gust_speed", 10.0)
				w.call("gust", 0.6, 7.0, 1.0)
				hud.call("toast", "A gust of wind: blocky or smooth, every tree bends by its own skeleton")
			get_viewport().set_input_as_handled()
		KEY_R:
			if turn_basis != Projection.IDENTITY:
				level()
				hud.call("toast", "Both lands level again")
				get_viewport().set_input_as_handled()
		KEY_E:
			for pn in [get_node_or_null("PanelBlocky"), get_node_or_null("PanelSmooth")]:
				if pn != null and bool(pn.get("near")):
					pn.call("activate")
					get_viewport().set_input_as_handled()


# -- the board -------------------------------------------------------------------------------------------------

func _open_board() -> void:
	loading = true
	player.set("input_enabled", false)
	_board = LoadBoard.open(self)
	_board.set("kicker", "QUANTUM HORIZON  ·  BOTANY LAB")
	_board.set("title", "TWO GARDENS")
	_board.set("subtitle", "One landscape grown two ways, blocky and smooth")
	_board.set("coming", ["The same land built two ways: boxes on the left, one smooth surface on the right",
		"Voxel trees on the blocks, lofted oaks on the hills, on the same spots",
		"Step through W with Q and E: the hills change on both sides"])
	_board.set("diagram_title", "THE LAND, BUILT AS YOU WAIT")
	_board.connect("finished", func() -> void:
		loading = false
		_board = null
		if player != null:
			player.set("input_enabled", true))


func _feed_board(delta: float) -> void:
	_board_t += delta
	var smooth_f: float = {"loading": 0.15, "editing": 0.15 + 0.35 * float(_sent) / maxf(1.0, float(_edits.size())), "meshing": 0.7, "ready": 1.0}.get(_phase, 0.0)
	var bars: Array = [["Blocky land", 1.0, "%dk" % int(round(float(int(stats["blocky"].get("tets", 0))) / 1000.0))],
		["Smooth land", smooth_f, "%dk" % int(round(float(smooth_tets()) / 1000.0))],
		["Trees", 1.0 if _trees_done else 0.0, "%d" % (tree_spots.size() * 2)]]
	_board.set("bars", bars)
	_board.set("numbers", [["Cells, blocky", Bake.thousands(int(stats["blocky"].get("cells", 0)))], ["Edits, smooth", Bake.thousands(_edits.size())],
		["Tetrahedra", Bake.thousands(int(stats["blocky"].get("tets", 0)) + smooth_tets())]])
	_board.set("progress", (1.0 + smooth_f + (1.0 if _trees_done else 0.0)) / 3.0)
	if (_trees_done and _board_t > 2.0) or _board_t > 45.0:
		_board.call("finish")
	if player != null:
		player.set("input_enabled", false)


# -- for the runners and the panels ------------------------------------------------------------------------------

func go_to(at: Vector4, yaw: float = NAN) -> void:
	if player == null:
		return
	player.global_position = at
	player.set("linear_velocity", Vector4.ZERO)
	var rig: Node = player.get_node_or_null("CameraRig")
	if is_nan(yaw):
		yaw = float(rig.get("yaw")) if rig != null else PI
	player.set("_facing", yaw)
	if rig != null:
		rig.set("yaw", yaw)
		rig.call("_apply")


func camera() -> Camera4D:
	return player.get_node_or_null("CameraRig/Pitch/Camera4D") as Camera4D if player != null else null


func ready_to_visit() -> bool:
	return _phase == "ready" and _trees_done
