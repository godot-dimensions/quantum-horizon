extends Node4D

## BOTANY LAB, round 3: THE FLOWER ROOM (follow_up/arboretum.md section 9, steps 16-32; Ramon, 10 Oct:
## "another room with botanical flowers, butterflies. many different types. the center is clean when you
## walk in the square room, but all the walls are filled with flowers and these pants that climb walls.
## try to make most 4d ... only the folowers oscilate when rotating, not the presentation pockets";
## "the flower room should be its own tscn with transporter door").
##
## A 20 m SQUARE GLASSHOUSE, its roof open to the sky through a light frame of beams. The middle is a
## clean pale floor with one ring inlaid in it; nothing stands there. The light is a warm sun from high
## on one side, a cool fill, and each pocket's own glow.
##
## ALL FOUR WALLS ARE FLOWERS. A facade of pale stone stands in front of each wall, 0.85 m deep (and deep
## through W, so stepping through W never thins it), with three rows of pockets:
##   row A   knee to head height, the tall flowers: sunflower, foxglove, allium, lily, iris, rose
##   row B   at the camera's height, the small ones: tulip, poppy, daisy, dandelion, bluebell,
##           passionflower
##   row C   up high, trailing foliage spilling out
## One species a pocket, two to five plants in soil, a plate under it with its name; each wall's order
## turned on by two, so no wall repeats another. Every pocket flower is a true 4D loft (flora/
## flower_4d.gd); the room's caption names the one in front of you.
## THE CLIMBERS: woody vines twisting up the corners and up the piers between pockets, true 4D tubes,
## with clematis and passionflower blooms (true 4D) along them; ivy over the bands, the piers and the
## wall above, wisteria hanging from the cornice and the wall's top, and grass and little wildflowers
## along the foot of every wall: those leaves, blades and florets are the pen's trick (flora_sprigs_4d:
## drawn where your slice crosses them, each with a home in W).
## AND IN THE AIR: 32 butterflies of eight species (flora/butterflies_4d.gd) landing on the flowers,
## petals and pollen drifting (flora/flora_drift_4d.gd).
##
## TURNING (Ramon: "only the flowers oscillate when rotating, not the presentation pockets"): a right drag
## turns every flower through W about its own stem, the hall's floor-only turn (Ground.sliced/cleaned),
## in each flower's own frame (its sideways and its front, as you see it on its wall), so a flower on any
## wall turns the same way to you; the pockets, the walls and the room never move. R levels them.
##
## The way back: the holographic doorway in the south wall, the hall's side door (botany_lab.tscn).
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
const PenWalk := preload("res://ramon/Arboretum/botany_lab/pen_walk.gd")
const Wind := preload("res://ramon/Arboretum/botany/wind_4d.gd")
const Ground := preload("res://ramon/Arboretum/botany_lab/carried/LabKit/carried/chickenpen/scripts/ground_basis_4d.gd")
const Loft := preload("res://ramon/Arboretum/botany_lab/carried/chickenpen/scripts/loft_builder_4d.gd")
const Kit := preload("res://ramon/Arboretum/botany_lab/flora/flora_kit.gd")
const Flower := preload("res://ramon/Arboretum/botany_lab/flora/flower_4d.gd")
const Species := preload("res://ramon/Arboretum/botany_lab/flora/flora_species.gd")
const Butterflies := preload("res://ramon/Arboretum/botany_lab/flora/butterflies_4d.gd")
const Drift := preload("res://ramon/Arboretum/botany_lab/flora/flora_drift_4d.gd")
const Sprigs := preload("res://ramon/Arboretum/botany_lab/flora/flora_sprigs_4d.gd")
const Air := preload("res://ramon/Arboretum/botany_lab/flora/flora_air_4d.gd")
const Bake := preload("res://ramon/Arboretum/botany/bake_store.gd")

const HALL := "res://ramon/Arboretum/botany_lab.tscn"
const ARRIVE_META := "botany_arrive"

## The pocket rows (bottom, top) and the solid bands between them, metres up.
const ROWS_Y := [[0.45, 2.05], [2.45, 3.85], [4.2, 5.2]]
const BANDS_Y := [[0.0, 0.45], [2.05, 2.45], [3.85, 4.2], [5.2, 5.6]]
## The pockets' middles along each wall (from the wall's middle, as you face it), their width.
const COLS := [-6.0, -3.6, -1.2, 1.2, 3.6, 6.0]
const POCKET_W := 1.8
const ROW_A := ["sunflower", "foxglove", "allium", "lily", "iris", "rose"]
const ROW_B := ["tulip", "poppy", "daisy", "dandelion", "bluebell", "passionflower"]
## Each wall: the way it faces from the middle (forward) and its right as you face it.
const WALLS := {
	"n": [Vector4(0, 0, -1, 0), Vector4(1, 0, 0, 0)],
	"e": [Vector4(1, 0, 0, 0), Vector4(0, 0, 1, 0)],
	"s": [Vector4(0, 0, 1, 0), Vector4(-1, 0, 0, 0)],
	"w": [Vector4(-1, 0, 0, 0), Vector4(0, 0, -1, 0)],
}
const WALL_ORDER := ["n", "e", "w", "s"]
const UP := Vector4(0, 1, 0, 0)
const ANA := Vector4(0, 0, 0, 1)

@export_group("Room")
## Half the room's inside, its height, the facade's depth and its half depth through W.
@export var half: float = 10.0
@export var height: float = 9.0
@export var depth: float = 0.85
@export var w_half: float = 1.5
@export var door_half: float = 1.6
@export var door_height: float = 4.4
@export var seed_value: int = 2610

@export_group("Life")
@export var butterflies: int = 32
@export var drift_amount: int = 450
## Pockets on walls behind the camera are hidden (no culling by view in the engine: every visible 4D
## mesh is cut every frame).
@export var cull_behind: bool = true

@export_group("Visit")
@export var start_at: Vector2 = Vector2(0.0, 5.4)
@export var camera_distance: float = 3.0
@export var camera_height: float = 2.0
@export var camera_pitch_degrees: float = -8.0

var player: CharacterBody4D
var hud: Control
var wind: Node
var loading: bool = true
## Every pocket: {wall, row, key, holder, plants: [[mi, offset, base basis, scale]], centre, n_in, a}.
var pockets: Array = []
var vines: Array = []
var stats: Dictionary = {}
## Every flower's turn through W (a ground basis: the floor only), in its own frame.
var turn_basis: Projection = Projection.IDENTITY
var _applied_turn: Projection = Projection.IDENTITY
var _board: Control
var _board_t: float = 0.0
var _built: bool = false
var _labels_done: bool = false
var _leaving: bool = false
var _flies: Node4D
var _drift: Node4D
var _sprigs: Node4D
var _rng := RandomNumberGenerator.new()
var _cull_t: float = 0.0
var _caption_key: String = ""
var _turn_said: bool = false
var _strip_tilt: int = -1
var _perch_t: float = 0.0
var _materials: Dictionary = {}


func _ready() -> void:
	_rng.seed = seed_value
	var room: Node = get_node_or_null("Room")
	if room != null:
		var light: Dictionary = Style.ROOM_LIGHT.duplicate(true)
		light["bright"] = {
			"sky_top": Color(0.26, 0.43, 0.72), "sky_horizon": Color(0.9, 0.82, 0.74), "sky_bottom": Color(0.5, 0.47, 0.45),
			"ambient": Color(0.32, 0.34, 0.38), "ambient_sky": 0.2,
			"tonemap": 2, "exposure": 1.0, "white": 4.0,
			"key_color": Color(1.0, 0.88, 0.7), "key_energy": 0.85, "key_elevation": 58.0, "key_azimuth": 35.0,
			"fill_color": Color(0.70, 0.80, 1.0), "fill_energy": 0.2, "fill_elevation": 25.0, "fill_azimuth": -140.0,
		}
		room.set("mood_overrides", light)
		room.call("set_mood", "bright", true, false)
		room.set("mood_key", KEY_NONE)
	Style.apply("bright")
	# (The first frames, 10 Oct: a pale stone under bright light washed the room white. A warm sandstone, a
	# sage wall above it, a darker floor: the flowers' colours carry the room.)
	LabGrid.set_swatch("flora_stone", Color(0.64, 0.56, 0.46), Color(0.58, 0.5, 0.41), Color(0.62, 0.54, 0.44), 0.22)
	LabGrid.set_swatch("kit_wall", Color(0.52, 0.56, 0.54), Color(0.46, 0.5, 0.48), Color(0.5, 0.54, 0.52), 0.3)
	LabGrid.set_swatch("kit_floor", Color(0.56, 0.52, 0.46), Color(0.5, 0.46, 0.4), Color(0.54, 0.5, 0.44), 0.25)
	LabGrid.set_swatch("flora_niche", Color(0.10, 0.17, 0.2), Color(0.07, 0.12, 0.15), Color(0.09, 0.15, 0.18), 0.4)
	LabGrid.set_swatch("flora_soil", Color(0.24, 0.17, 0.12), Color(0.18, 0.12, 0.08), Color(0.21, 0.15, 0.1), 0.5)
	LabGrid.set_swatch("flora_plate", Color(0.13, 0.15, 0.18), Color(0.13, 0.15, 0.18), Color(0.13, 0.15, 0.18), 0.0)
	LabGrid.set_swatch("flora_beam", Color(0.2, 0.22, 0.24), Color(0.15, 0.16, 0.18), Color(0.18, 0.2, 0.22), 0.3)
	wind = Wind.of(get_tree())
	if wind != null:
		wind.set("speed", 2.4)
		wind.set("gust_every", 16.0)
	var t0: int = Time.get_ticks_usec()
	_build_facades()
	_build_roof_frame()
	var t1: int = Time.get_ticks_usec()
	_plant_pockets()
	var t2: int = Time.get_ticks_usec()
	_build_climbers()
	var t3: int = Time.get_ticks_usec()
	_build_sprigs()
	var t4: int = Time.get_ticks_usec()
	_flies = Node4D.new()
	_flies.name = "Butterflies"
	_flies.set_script(Butterflies)
	_flies.set("count", butterflies)
	_flies.set("bounds_lo", Vector3(-half + 1.4, 0.7, -half + 1.4))
	_flies.set("bounds_hi", Vector3(half - 1.4, 6.2, half - 1.4))
	_flies.set("perch_source", perch_points)
	_flies.set("wind", wind)
	add_child(_flies)
	_drift = Node4D.new()
	_drift.name = "Drift"
	_drift.set_script(Drift)
	_drift.set("amount", drift_amount)
	_drift.set("box_size", Vector2(half * 1.9, half * 1.9))
	_drift.set("floor_y", 0.3)
	_drift.set("top_y", 7.5)
	_drift.set("leaf_size", 0.04)
	_drift.set("bit_size", 0.012)
	_drift.set("wind", wind)
	add_child(_drift)
	var t5: int = Time.get_ticks_usec()
	_warm()
	stats["ms"] = {"facades": (t1 - t0) / 1000.0, "plants": (t2 - t1) / 1000.0, "climbers": (t3 - t2) / 1000.0, "sprigs": (t4 - t3) / 1000.0,
		"life": (t5 - t4) / 1000.0, "warm": (Time.get_ticks_usec() - t5) / 1000.0}
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
	var from_hall: bool = String(get_tree().root.get_meta(ARRIVE_META, "")) == "hall"
	get_tree().root.remove_meta(ARRIVE_META)
	_build_hud()
	_build_door()
	if from_hall:
		Shimmer.flash_in(self)
	var air := Node.new()
	air.name = "Air"
	air.set_script(Air)
	air.set("wind", wind)
	add_child(air)
	_built = true
	_open_board()
	_print_labels.call_deferred()


# -- the walls ---------------------------------------------------------------------------------------

## A point on wall `side`: `u` along it (its right as you face it), `y` up, `d` out from it into the room.
func wall_point(side: String, u: float, y: float, d: float) -> Vector4:
	var f: Array = WALLS[side]
	return (f[0] as Vector4) * (half - d) + (f[1] as Vector4) * u + UP * y


## A box's frame on wall `side`: its x along the wall, y up, +z into the room.
func wall_frame(side: String) -> Projection:
	var f: Array = WALLS[side]
	return Projection(f[1], UP, -(f[0] as Vector4), ANA)


func _box(nm: String, side: String, u0: float, u1: float, y0: float, y1: float, d0: float, d1: float, swatch: String, parent: Node = null) -> MeshInstance4D:
	var size := Vector4(absf(u1 - u0), absf(y1 - y0), absf(d1 - d0), w_half * 2.0)
	if size.x < 0.005 or size.y < 0.005 or size.z < 0.005:
		return null
	var m := MeshInstance4D.new()
	m.name = nm
	m.mesh = Mats.box_mesh(size)
	m.position = wall_point(side, (u0 + u1) * 0.5, (y0 + y1) * 0.5, (d0 + d1) * 0.5)
	m.basis = wall_frame(side)
	m.material_override = LabGrid.material(swatch, size, m.position)
	(parent if parent != null else self).add_child(m)
	return m


## The columns a wall has pockets in (the south wall loses the two either side of its door).
func columns(side: String) -> Array:
	var out: Array = []
	for c in COLS:
		if side == "s" and absf(float(c)) < door_half + POCKET_W * 0.5 + 0.2:
			continue
		out.append(c)
	return out


## The stretches of `side` along which the facade stands, cut at the door.
func _spans(side: String) -> Array:
	if side == "s":
		return [[-half, -(door_half + 0.4)], [door_half + 0.4, half]]
	return [[-half, half]]


## Each wall's facade: its bands across, its piers between the pockets, and inside each pocket a dark
## lining, a bed of soil (rows A and B) and a warm strip of light under its top.
func _build_facades() -> void:
	var holder := Node4D.new()
	holder.name = "Facades"
	add_child(holder)
	var glow: TetraMaterial4D = Mats.glow(Color(1.0, 0.84, 0.6), 1.6)
	for side in WALL_ORDER:
		var wall := Node4D.new()
		wall.name = "Facade_" + side
		holder.add_child(wall)
		var cols: Array = columns(side)
		for span in _spans(side):
			_solid(side, float(span[0]), float(span[1]), wall)
			for bi in BANDS_Y.size():
				var b: Array = BANDS_Y[bi]
				_box("Band%d_%.0f" % [bi, span[0]], side, span[0], span[1], b[0], b[1], 0.0, depth, "flora_stone", wall)
			# The piers: what is left of each row between the pockets.
			for ri in ROWS_Y.size():
				var r: Array = ROWS_Y[ri]
				var edges: Array = [span[0]]
				for c in cols:
					var cu: float = float(c)
					if cu > span[0] and cu < span[1]:
						edges.append(cu - POCKET_W * 0.5)
						edges.append(cu + POCKET_W * 0.5)
				edges.append(span[1])
				for k in range(0, edges.size(), 2):
					_box("Pier%d_%.1f" % [ri, edges[k]], side, edges[k], edges[k + 1], r[0], r[1], 0.0, depth, "flora_stone", wall)
		for c in cols:
			for ri in ROWS_Y.size():
				var r: Array = ROWS_Y[ri]
				var cu: float = float(c)
				_box("Lining%d_%.1f" % [ri, cu], side, cu - POCKET_W * 0.5, cu + POCKET_W * 0.5, r[0], r[1], 0.0, 0.06, "flora_niche", wall)
				if ri < 2:
					_box("Soil%d_%.1f" % [ri, cu], side, cu - POCKET_W * 0.5 + 0.02, cu + POCKET_W * 0.5 - 0.02, r[0], r[0] + 0.16, 0.06, depth - 0.04, "flora_soil", wall)
				var strip := _box("Glow%d_%.1f" % [ri, cu], side, cu - POCKET_W * 0.5 + 0.06, cu + POCKET_W * 0.5 - 0.06, r[1] - 0.045, r[1] - 0.01, depth - 0.12, depth - 0.06, "flora_stone", wall)
				if strip != null:
					strip.material_override = glow


## A facade run is solid: one box, in the world's axes (the physics is boxes along the axes only, so an
## east or west wall's box has its size turned rather than its basis).
func _solid(side: String, u0: float, u1: float, parent: Node) -> void:
	var f: Array = WALLS[side]
	var along: Vector4 = f[1]
	var c: Vector4 = wall_point(side, (u0 + u1) * 0.5, 2.8, depth * 0.5)
	var len_: float = absf(u1 - u0)
	var size := Vector4(absf(along.x) * len_ + absf((f[0] as Vector4).x) * depth, 5.6, absf(along.z) * len_ + absf((f[0] as Vector4).z) * depth, w_half * 2.0)
	var body := StaticBody4D.new()
	body.name = "Solid_%s_%.0f" % [side, u0]
	body.position = c
	var cs := CollisionShape4D.new()
	var bs := BoxShape4D.new()
	bs.size = size
	cs.shape = bs
	body.add_child(cs)
	parent.add_child(body)


## The glasshouse's frame overhead: the roof is open to the sky, crossed by a light grid of dark beams
## on the walls' tops (a glasshouse with its glass taken out: the engine draws no glass).
func _build_roof_frame() -> void:
	var holder := Node4D.new()
	holder.name = "RoofFrame"
	add_child(holder)
	for k in 5:
		var x: float = lerpf(-half, half, float(k) / 4.0)
		for pair in [[Vector4(x, height, 0.0, 0.0), Vector4(0.14, 0.22, half * 2.0, w_half * 2.0)], [Vector4(0.0, height + 0.01, x, 0.0), Vector4(half * 2.0, 0.2, 0.14, w_half * 2.0)]]:
			var m := MeshInstance4D.new()
			m.mesh = Mats.box_mesh(pair[1])
			m.position = pair[0]
			m.material_override = LabGrid.material("flora_beam", pair[1], pair[0])
			holder.add_child(m)


# -- the flowers -------------------------------------------------------------------------------------

func _plant_pockets() -> void:
	var holder := Node4D.new()
	holder.name = "Pockets"
	add_child(holder)
	var mat: TetraMaterial4D = Flower.material()
	var meshes: Dictionary = {}
	var n_plants: int = 0
	var tets: int = 0
	for wi in WALL_ORDER.size():
		var side: String = WALL_ORDER[wi]
		var cols: Array = columns(side)
		for ri in 2:
			var keys: Array = ROW_A if ri == 0 else ROW_B
			var r: Array = ROWS_Y[ri]
			for ci in cols.size():
				var cu: float = float(cols[ci])
				var ki: int = (COLS.find(cols[ci]) + wi * 2 + ri * 3) % keys.size()
				var key: String = keys[ki]
				var sp: Dictionary = Species.by_key(key)
				var ph := Node4D.new()
				ph.name = "Pocket_%s_%d_%d" % [side, ri, ci]
				ph.position = wall_point(side, cu, float(r[0]) + 0.16, 0.0)
				holder.add_child(ph)
				var pocket: Dictionary = {"wall": side, "row": ri, "key": key, "holder": ph, "plants": [], "u": cu,
					"centre": wall_point(side, cu, float(r[0]) + 0.6, depth * 0.5), "n_in": -(WALLS[side][0] as Vector4), "a": WALLS[side][1]}
				# (One more than the species' count, a little bigger: the first frames' pockets read empty.)
				var n: int = clampi(int(sp.get("plants", 3)) + 1, 3, 6)
				var disp: float = float(Species.DISPLAY.get(key, 1.4)) * 1.12
				for i in n:
					var variant: int = (i + ci) % Flower.VARIANTS
					var mk: String = "%s_%d" % [key, variant]
					if not meshes.has(mk):
						meshes[mk] = Flower.mesh(key, variant)
					var mesh: ArrayTetraMesh4D = meshes[mk]
					if mesh == null:
						continue
					var f: float = (float(i) + 0.5) / float(n)
					var u: float = lerpf(-POCKET_W * 0.5 + 0.24, POCKET_W * 0.5 - 0.24, f) + _rng.randf_range(-0.06, 0.06)
					var d: float = depth * (0.42 if i % 2 == 0 else 0.62) + _rng.randf_range(-0.05, 0.05)
					var off: Vector4 = (WALLS[side][1] as Vector4) * u - (WALLS[side][0] as Vector4) * d
					var yaw: float = _rng.randf_range(-0.45, 0.45)
					var base: Projection = wall_frame(side) * Basis4D.from_zx(yaw)
					var s: float = disp * _rng.randf_range(0.93, 1.06)
					var mi := MeshInstance4D.new()
					mi.name = "%s_%d" % [key, i]
					mi.mesh = mesh
					mi.material_override = mat
					mi.position = off
					mi.basis = _scaled(base, s)
					ph.add_child(mi)
					(pocket["plants"] as Array).append([mi, off, base, s])
					n_plants += 1
					tets += mesh.get_simplex_cell_vertex_indices().size() / 4
				pockets.append(pocket)
	stats["plants"] = {"pockets": pockets.size(), "plants": n_plants, "tets": tets, "meshes": meshes.size()}


static func _scaled(b: Projection, s: float) -> Projection:
	return Projection(b.x * s, b.y * s, b.z * s, b.w * s)


## Every flower posed by the turn: its own frame, then the turn (in that frame: its sideways and its front
## as you see it), then its size. The pockets never move.
func _apply_turn() -> void:
	for p in pockets:
		for pl in p["plants"]:
			(pl[0] as MeshInstance4D).basis = _scaled((pl[2] as Projection) * turn_basis, pl[3])
	for v in vines:
		for bl in v.get("blooms", []):
			(bl[0] as MeshInstance4D).basis = _scaled((bl[1] as Projection) * turn_basis, bl[2])
	_applied_turn = turn_basis
	if _flies != null:
		_flies.call("refresh_perches")


## Where a butterfly may land (world), every flower's perches as it stands now.
func perch_points() -> PackedVector4Array:
	var out := PackedVector4Array()
	for p in pockets:
		var ph: Node4D = p["holder"]
		for pl in p["plants"]:
			var mi: MeshInstance4D = pl[0]
			var per: PackedVector4Array = (mi.mesh as Resource).get_meta("perches", PackedVector4Array())
			for q in per:
				out.append(ph.position + mi.position + mi.basis * q)
	for v in vines:
		for bl in v.get("blooms", []):
			var mi: MeshInstance4D = bl[0]
			out.append(mi.position + mi.basis * Vector4(0, 0.01, 0, 0))
	return out


# -- the climbers ------------------------------------------------------------------------------------

## Woody vines, true 4D tubes: two twisting up each corner, one up every other pier; clematis and
## passionflower blooms along them (true 4D), facing into the room.
func _build_climbers() -> void:
	var holder := Node4D.new()
	holder.name = "Climbers"
	add_child(holder)
	var bark: TetraMaterial4D = Kit.flat(Color(0.33, 0.26, 0.19))
	var vine_green: TetraMaterial4D = Kit.flat(Color(0.24, 0.34, 0.16))
	var mat: TetraMaterial4D = Flower.material()
	var blooms: Dictionary = {"clematis": Flower.bloom_mesh("clematis"), "passionflower": Flower.bloom_mesh("passionflower")}
	var tets: int = 0
	var n_blooms: int = 0
	for side in WALL_ORDER:
		# The corners: at each end of the wall, a trunk twisting from the floor to the top.
		for end in [-1.0, 1.0]:
			var u0: float = end * (half - 1.4)
			var pts := PackedVector4Array()
			var radii := PackedFloat32Array()
			var ph: float = _rng.randf() * TAU
			for k in 16:
				var t: float = float(k) / 15.0
				var y: float = t * (height - 0.3)
				var u: float = u0 + sin(ph + t * 7.0) * 0.45 + end * t * 0.6
				var dd: float = 0.18 + 0.12 * (0.5 + 0.5 * cos(ph + t * 7.0))
				pts.append(wall_point(side, u, y, dd))
				radii.append(lerpf(0.035, 0.012, t))
			var m: ArrayTetraMesh4D = _tube(pts, radii)
			tets += _add_mesh(holder, "Trunk_%s_%d" % [side, int(end)], m, bark)
			vines.append({"pts": pts, "side": side, "blooms": []})
		# The piers: every other one, a thin green vine from the plinth to the cornice, with blooms.
		var cols: Array = columns(side)
		var piers: Array = []
		for i in cols.size() - 1:
			if absf(float(cols[i + 1]) - float(cols[i])) < 2.5:
				piers.append((float(cols[i]) + float(cols[i + 1])) * 0.5)
		for pi in piers.size():
			if pi % 2 == 1:
				continue
			var pu: float = piers[pi]
			var pts := PackedVector4Array()
			var radii := PackedFloat32Array()
			var ph: float = _rng.randf() * TAU
			for k in 9:
				var t: float = float(k) / 8.0
				pts.append(wall_point(side, pu + sin(ph + t * 9.0) * 0.18, 0.45 + t * 4.9, depth + 0.03 + 0.02 * cos(ph + t * 9.0)))
				radii.append(lerpf(0.009, 0.005, t))
			var m: ArrayTetraMesh4D = _tube(pts, radii)
			tets += _add_mesh(holder, "Vine_%s_%d" % [side, pi], m, vine_green)
			var v: Dictionary = {"pts": pts, "side": side, "blooms": []}
			var key: String = "clematis" if (pi / 2 + WALL_ORDER.find(side)) % 2 == 0 else "passionflower"
			var bm: ArrayTetraMesh4D = blooms[key]
			for k in [2, 4, 6, 7]:
				var at: Vector4 = pts[k] + (-(WALLS[side][0] as Vector4)) * 0.03
				var base: Projection = _facing_out(side, _rng.randf_range(0.9, 1.3), _rng.randf_range(-0.5, 0.5))
				var s: float = float(Species.DISPLAY.get(key, 1.6)) * _rng.randf_range(0.9, 1.08)
				var mi := MeshInstance4D.new()
				mi.name = "%s_%s_%d_%d" % [key, side, pi, k]
				mi.mesh = bm
				mi.material_override = mat
				mi.position = at
				mi.basis = _scaled(base, s)
				holder.add_child(mi)
				(v["blooms"] as Array).append([mi, base, s])
				n_blooms += 1
				tets += bm.get_simplex_cell_vertex_indices().size() / 4 if bm != null else 0
			vines.append(v)
	stats["climbers"] = {"vines": vines.size(), "blooms": n_blooms, "tets": tets}


## A bloom's frame on wall `side`: its up (the bloom's axis) tipped `tip` from straight up toward the
## room, turned `yaw` across.
func _facing_out(side: String, tip: float, yaw: float) -> Projection:
	var n_in: Vector4 = -(WALLS[side][0] as Vector4)
	var a: Vector4 = WALLS[side][1]
	var ax: Vector4 = (UP * cos(tip) + (n_in * cos(yaw) + a * sin(yaw)) * sin(tip)).normalized()
	var x: Vector4 = (a - ax * a.dot(ax)).normalized()
	var z: Vector4 = n_in - ax * n_in.dot(ax) - x * n_in.dot(x)
	z = z.normalized() if z.length() > 0.05 else Vector4(0, 0, 1, 0)
	var f := Projection(x, ax, z, ANA)
	if f.determinant() < 0.0:
		f = Projection(-x, ax, z, ANA)
	return f


## A vine: the flowers' light loft (no span splitting: a corner trunk was 6,000 cells, now a few hundred).
func _tube(pts: PackedVector4Array, radii: PackedFloat32Array) -> ArrayTetraMesh4D:
	var sections: Array = []
	for i in pts.size():
		sections.append({"center": pts[i], "radius": radii[i], "v_scale": 1.0, "w_scale": 1.0})
	var m: ArrayTetraMesh4D = Flower.light_loft(sections, 2, 5)
	if m != null:
		m.calculate_boundary_normals(false)
	return m


func _add_mesh(holder: Node, nm: String, m: ArrayTetraMesh4D, mat: Material4D) -> int:
	if m == null:
		return 0
	return Kit.add_mesh(holder, nm, m, mat)


# -- the small foliage (the pen's trick) ---------------------------------------------------------------

## Ivy over the bands, the piers and the wall above the cornice; leaves and trailing stems spilling from
## the top row of pockets; leaves along the vines; wisteria hanging from the cornice and the wall's top;
## grass and wildflowers along every wall's foot.
func _build_sprigs() -> void:
	_sprigs = Node4D.new()
	_sprigs.name = "Sprigs"
	_sprigs.set_script(Sprigs)
	_sprigs.set("w_radius", 0.75)
	_sprigs.set("wind", wind)
	add_child(_sprigs)
	var s: Node4D = _sprigs
	var n_ivy: int = 0
	for side in WALL_ORDER:
		var f: Array = WALLS[side]
		var n_in: Vector3 = _v3(-(f[0] as Vector4))
		var a: Vector3 = _v3(f[1])
		var cols: Array = columns(side)
		# IVY: stems that wander up from points on the bands and the wall above, leaves on short stalks
		# either side, facing out and hanging a little.
		var starts: Array = []
		for span in _spans(side):
			var len_: float = float(span[1]) - float(span[0])
			for k in int(len_ / 0.8):
				starts.append([float(span[0]) + _rng.randf() * len_, BANDS_Y[_rng.randi() % BANDS_Y.size()][1] - 0.05, depth + 0.01, 1.4])
			for k in int(len_ / 0.6):
				starts.append([float(span[0]) + _rng.randf() * len_, 5.65 + _rng.randf() * 0.4, 0.015, 3.2])
		for st in starts:
			var u: float = st[0]
			var y: float = st[1]
			var d: float = st[2]
			var reach: float = st[3]
			var dir := Vector2(_rng.randf_range(-0.5, 0.5), 1.0).normalized()
			var home: float = _rng.randf_range(-w_half, w_half)
			var steps: int = int(reach / 0.07)
			for k in mini(steps, 80):
				dir = (dir + Vector2(_rng.randf_range(-0.35, 0.35), 0.05)).normalized()
				u += dir.x * 0.07
				y += dir.y * 0.07
				if y > height - 0.2 or absf(u) > half - 0.1:
					break
				# Over a pocket's opening the stem would hang in the air: stop there.
				if d > 0.1 and _in_pocket(side, cols, u, y):
					break
				var at: Vector3 = _v3(wall_point(side, u, y, d))
				s.call("add", Sprigs.STEM, at, a * dir.x + Vector3.UP * dir.y, n_in, 0.075, _rng.randf(), 0.0, home + _rng.randf_range(-0.1, 0.1))
				if k % 2 == 0:
					var sideways: float = 1.0 if (k / 2) % 2 == 0 else -1.0
					var leaf_along: Vector3 = (a * sideways * 0.8 + Vector3.UP * _rng.randf_range(-0.6, 0.2)).normalized()
					var face: Vector3 = (n_in + Vector3.UP * 0.3 + a * _rng.randf_range(-0.3, 0.3)).normalized()
					s.call("add", Sprigs.LEAF, at + n_in * 0.01, leaf_along, face, _rng.randf_range(0.055, 0.09), _rng.randf(), 0.6, home + _rng.randf_range(-0.15, 0.15))
					n_ivy += 1
		# TRAILING from the top row of pockets: stems hanging over the sill with leaves and little white
		# and yellow flowers.
		for c in cols:
			var cu: float = float(c)
			_underplant(side, cu, n_in, a)
			for k in 26:
				var u: float = cu + _rng.randf_range(-0.85, 0.85)
				var y: float = float(ROWS_Y[2][0]) + 0.05
				var home: float = _rng.randf_range(-w_half, w_half)
				var len_: int = _rng.randi_range(8, 20)
				for j in len_:
					var at: Vector3 = _v3(wall_point(side, u + sin(float(j) * 0.7 + float(k)) * 0.03, y - float(j) * 0.06, depth + 0.02 + float(j) * 0.004))
					s.call("add", Sprigs.STEM, at, Vector3.DOWN, n_in, 0.065, _rng.randf(), 0.3, home)
					s.call("add", Sprigs.LEAF, at, (Vector3.DOWN + a * (1.0 if j % 2 == 0 else -1.0)).normalized(), n_in, _rng.randf_range(0.045, 0.07), _rng.randf(), 0.7, home)
					if j % 4 == 2:
						s.call("add", Sprigs.PETAL, at + n_in * 0.02, Vector3.UP, n_in, 0.028, 0.25 if _rng.randf() < 0.6 else 0.8, 0.4, home)
		# WISTERIA: racemes hanging from the cornice and from the wall's top, a chain of florets each,
		# lilac at the top to white at the tip, and their pale leaves.
		for span in _spans(side):
			var u: float = float(span[0]) + 0.2
			# (Bounded: at most 200 steps, each at least 0.18 m along.)
			for step in 200:
				if u >= float(span[1]) - 0.2:
					break
				for top in [[5.6, depth + 0.05], [height - 0.15, 0.08]]:
					if _rng.randf() < 0.7:
						var home: float = _rng.randf_range(-w_half, w_half)
						var L: int = _rng.randi_range(14, 30)
						var uu: float = u + _rng.randf_range(-0.12, 0.12)
						for j in L:
							var t: float = float(j) / float(L)
							var at: Vector3 = _v3(wall_point(side, uu + sin(t * 3.0) * 0.02, float(top[0]) - float(j) * 0.025, float(top[1]) + 0.03 + t * 0.02))
							for q in 2:
								var out: Vector3 = (n_in + a * (0.8 if q == 0 else -0.8) + Vector3.UP * 0.3).normalized()
								s.call("add", Sprigs.FLORET, at, out, n_in, lerpf(0.05, 0.028, t), clampf(t * 1.2 + _rng.randf_range(-0.1, 0.1), 0.0, 1.0), 0.8, home)
						for q in 4:
							var at: Vector3 = _v3(wall_point(side, uu + _rng.randf_range(-0.15, 0.15), float(top[0]) + 0.02, float(top[1]) + 0.04))
							s.call("add", Sprigs.LEAF, at, (Vector3.DOWN + a * _rng.randf_range(-0.8, 0.8)).normalized(), n_in, 0.07, 0.8, 0.5, home)
				u += _rng.randf_range(0.18, 0.32)
		# GRASS AND WILDFLOWERS along the wall's foot, in front of the plinth.
		for span in _spans(side):
			var len_: float = float(span[1]) - float(span[0])
			for k in int(len_ * 110.0):
				var u: float = float(span[0]) + _rng.randf() * len_
				var dd: float = depth + 0.02 + pow(_rng.randf(), 1.6) * 0.5
				var at: Vector3 = _v3(wall_point(side, u, 0.0, dd))
				var lean: Vector3 = (Vector3.UP + n_in * _rng.randf_range(0.0, 0.5) + a * _rng.randf_range(-0.3, 0.3)).normalized()
				s.call("add", Sprigs.BLADE, at, lean, a, _rng.randf_range(0.14, 0.38) * (1.0 - dd * 0.6), _rng.randf(), 1.0, _rng.randf_range(-w_half, w_half))
			for k in int(len_ * 6.0):
				var u: float = float(span[0]) + _rng.randf() * len_
				var dd: float = depth + 0.05 + _rng.randf() * 0.35
				var y: float = _rng.randf_range(0.1, 0.24)
				var at: Vector3 = _v3(wall_point(side, u, y, dd))
				var home: float = _rng.randf_range(-w_half, w_half)
				var pick: float = 0.2 if _rng.randf() < 0.6 else 0.8
				s.call("add", Sprigs.STEM, _v3(wall_point(side, u, 0.0, dd)), Vector3.UP, n_in, y, 0.6, 0.6, home)
				for q in 5:
					var ang: float = TAU * float(q) / 5.0
					s.call("add", Sprigs.PETAL, at, (a * cos(ang) + Vector3.UP * sin(ang)).normalized(), n_in, 0.016, pick, 0.6, home)
	# Leaves along the vines.
	for v in vines:
		var pts: PackedVector4Array = v["pts"]
		var side: String = v["side"]
		var n_in: Vector3 = _v3(-(WALLS[side][0] as Vector4))
		var a: Vector3 = _v3(WALLS[side][1])
		for i in pts.size() - 1:
			for k in 6:
				var t: float = float(k) / 6.0
				var at: Vector3 = _v3(pts[i].lerp(pts[i + 1], t))
				var sideways: float = 1.0 if k % 2 == 0 else -1.0
				s.call("add", Sprigs.LEAF, at + n_in * 0.02, (a * sideways + Vector3.UP * 0.2).normalized(), (n_in + Vector3.UP * 0.2).normalized(), _rng.randf_range(0.06, 0.1), _rng.randf(), 0.6, _rng.randf_range(-w_half, w_half))
	s.call("commit")
	stats["sprigs"] = {"pieces": s.call("count"), "ivy_leaves": n_ivy}


## A pocket's underplanting (rows A and B), the pen's trick: grass and low leaves over its soil, a few small
## white and yellow flowers, so a pocket is a bed and not a box with stems in it.
func _underplant(side: String, cu: float, n_in: Vector3, a: Vector3) -> void:
	var s: Node4D = _sprigs
	for ri in 2:
		var y0: float = float(ROWS_Y[ri][0]) + 0.16
		for k in 150:
			var u: float = cu + _rng.randf_range(-POCKET_W * 0.5 + 0.06, POCKET_W * 0.5 - 0.06)
			var d: float = _rng.randf_range(0.1, depth - 0.08)
			var at: Vector3 = _v3(wall_point(side, u, y0, d))
			var lean: Vector3 = (Vector3.UP + n_in * _rng.randf_range(0.0, 0.5) + a * _rng.randf_range(-0.4, 0.4)).normalized()
			s.call("add", Sprigs.BLADE, at, lean, a, _rng.randf_range(0.1, 0.26), _rng.randf(), 0.8, _rng.randf_range(-w_half, w_half))
		for k in 36:
			var u: float = cu + _rng.randf_range(-POCKET_W * 0.5 + 0.08, POCKET_W * 0.5 - 0.08)
			var d: float = _rng.randf_range(0.12, depth - 0.1)
			var at: Vector3 = _v3(wall_point(side, u, y0 + 0.01, d))
			var along: Vector3 = (Vector3(_rng.randf_range(-1, 1), 0.35, _rng.randf_range(-1, 1))).normalized()
			s.call("add", Sprigs.LEAF, at, along, (Vector3.UP + n_in * 0.3).normalized(), _rng.randf_range(0.05, 0.09), _rng.randf(), 0.5, _rng.randf_range(-w_half, w_half))
		for k in 6:
			var u: float = cu + _rng.randf_range(-POCKET_W * 0.5 + 0.12, POCKET_W * 0.5 - 0.12)
			var d: float = _rng.randf_range(0.15, depth - 0.12)
			var hgt: float = _rng.randf_range(0.08, 0.16)
			var base: Vector3 = _v3(wall_point(side, u, y0, d))
			var home: float = _rng.randf_range(-w_half, w_half)
			var pick: float = 0.2 if _rng.randf() < 0.6 else 0.8
			s.call("add", Sprigs.STEM, base, Vector3.UP, n_in, hgt, 0.6, 0.6, home)
			for q in 5:
				var ang: float = TAU * float(q) / 5.0
				s.call("add", Sprigs.PETAL, base + Vector3.UP * hgt, (a * cos(ang) + Vector3.UP * 0.2 + n_in * sin(ang)).normalized(), Vector3.UP, 0.016, pick, 0.6, home)


func _in_pocket(side: String, cols: Array, u: float, y: float) -> bool:
	for r in ROWS_Y:
		if y > float(r[0]) and y < float(r[1]):
			for c in cols:
				if absf(u - float(c)) < POCKET_W * 0.5:
					return true
	return false


static func _v3(v: Vector4) -> Vector3:
	return Vector3(v.x, v.y, v.z)


## Every 4D mesh's 3D proxy built now, while the board is up, not on its first draw (round 2: the
## hall's first-draw hitches were the proxies).
func _warm() -> void:
	var seen: Dictionary = {}
	for mi in find_children("*", "MeshInstance4D", true, false):
		var m: Mesh4D = (mi as MeshInstance4D).mesh
		if m != null and not seen.has(m.get_instance_id()):
			seen[m.get_instance_id()] = true
			m.get_proxy_mesh_3d()
	stats["warmed"] = seen.size()


# -- the labels -----------------------------------------------------------------------------------------

## A plate under every flower pocket, its name and Latin name printed into it (one print a species,
## shared by its plates).
func _print_labels() -> void:
	await get_tree().process_frame
	var by_key: Dictionary = {}
	for p in pockets:
		var key: String = p["key"]
		if not by_key.has(key):
			var sp: Dictionary = Species.by_key(key)
			var tex: Texture2D = await LabPrint.render(get_tree(), Vector2i(900, 180), func(c: Control) -> void: _plate(c, sp))
			var m: TetraMaterial4D = LabGrid.material("flora_plate", Vector4(0.9, 0.18, 0.03, w_half * 2.0), Vector4.ZERO)
			if tex != null:
				LabGrid.set_print(m, tex, Vector4(0, 0, 1, 0), Rect2(0.0, 0.0, 0.9, 0.18), Color.WHITE, 0.25)
				LabGrid.set_print_strength(m, 1.0)
			by_key[key] = m
		var side: String = p["wall"]
		var r: Array = ROWS_Y[int(p["row"])]
		var y1: float = float(r[0]) - 0.07
		var plate := _box("Plate_%s" % key, side, float(p["u"]) - 0.45, float(p["u"]) + 0.45, y1 - 0.18, y1, depth, depth + 0.03, "flora_plate", p["holder"].get_parent())
		if plate != null:
			plate.material_override = by_key[key]
	_labels_done = true


func _plate(c: Control, sp: Dictionary) -> void:
	var sz: Vector2 = c.size
	var u: float = sz.y / 180.0
	c.draw_string(LabPrint.font("bold"), Vector2(24.0 * u, 82.0 * u), String(sp.get("name", "")).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, int(60 * u), Color(1, 1, 1, 0.95))
	c.draw_string(LabPrint.font("body"), Vector2(24.0 * u, 146.0 * u), String(sp.get("latin", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, int(42 * u), Color(1, 1, 1, 0.72))


# -- the HUD, the door, the board ----------------------------------------------------------------------

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


func _build_door() -> void:
	var sh := Node4D.new()
	sh.name = "Shimmer"
	sh.set_script(Shimmer)
	sh.set("width", door_half * 2.0)
	sh.set("height", minf(4.1, door_height - 0.3))
	sh.position = Vector4(0.0, 0.0, half - 0.17, 0.0)
	add_child(sh)


func _open_board() -> void:
	loading = true
	player.set("input_enabled", false)
	_board = LoadBoard.open(self)
	_board.set("kicker", "QUANTUM HORIZON  ·  BOTANY LAB")
	_board.set("title", "THE FLOWER ROOM")
	_board.set("subtitle", "Twelve flowers lofted in 4D, and the butterflies that visit them")
	_board.set("coming", ["Every wall a garden: a pocket for each flower, climbers between them",
		"Right drag turns every flower through W; the pockets never move",
		"Eight kinds of butterfly, each a true 4D loft, landing where they like"])
	_board.set("diagram_title", "THE GARDEN, PLANTED AS YOU WAIT")
	_board.connect("finished", func() -> void:
		loading = false
		_board = null
		if player != null:
			player.set("input_enabled", true))


func _feed_board(delta: float) -> void:
	_board_t += delta
	var pl: Dictionary = stats.get("plants", {})
	var cl: Dictionary = stats.get("climbers", {})
	_board.set("bars", [["Flowers", 1.0, "%d" % int(pl.get("plants", 0))], ["Climbers", 1.0, "%d" % int(cl.get("vines", 0))],
		["Butterflies", 1.0, "%d" % butterflies], ["Labels", 1.0 if _labels_done else 0.4, "%d" % pockets.size()]])
	_board.set("numbers", [["Pockets", str(pockets.size())], ["Species", str(Species.POCKET_KEYS.size())],
		["Tetrahedra", Bake.thousands(int(pl.get("tets", 0)) + int(cl.get("tets", 0)))], ["Leaves and florets", Bake.thousands(int(stats.get("sprigs", {}).get("pieces", 0)))]])
	_board.set("progress", 0.8 + (0.2 if _labels_done else 0.0))
	if (_labels_done and _board_t > 1.5) or _board_t > 30.0:
		_board.call("finish")
	if player != null:
		player.set("input_enabled", false)


# -- each frame ------------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not _built:
		return
	if _board != null:
		_feed_board(delta)
	if turn_basis != _applied_turn:
		_apply_turn()
	_cull_t -= delta
	if _cull_t <= 0.0:
		_cull_t = 0.2
		_cull()
	if player == null or loading or _leaving:
		return
	var p: Vector4 = player.global_position
	if p.z > half - 0.45 and absf(p.x) < door_half:
		_leaving = true
		player.set("input_enabled", false)
		var sh: Node = get_node_or_null("Shimmer")
		if sh != null:
			sh.call("flash_out", self, back_to_hall)
		else:
			back_to_hall()
		return
	_caption(p)
	var tilt: int = int(round(rad_to_deg(Ground.tilt(turn_basis))))
	if tilt != _strip_tilt:
		_strip_tilt = tilt
		_strip()


## Pockets on the walls behind the camera hidden, those in front or near shown.
func _cull() -> void:
	var cam: Camera4D = camera()
	if cam == null or not cull_behind:
		return
	var c: Vector4 = cam.global_position
	var fwd: Vector4 = -cam.global_basis.z
	var shown: int = 0
	for p in pockets:
		var to: Vector4 = (p["centre"] as Vector4) - c
		var vis: bool = to.dot(fwd) > -1.0 or Vector2(to.x, to.z).length() < 4.0
		(p["holder"] as Node4D).visible = vis
		if vis:
			shown += 1
	stats["shown_pockets"] = shown


## The caption: the flower in the pocket in front of you, its name, Latin name and what is 4D about it.
func _caption(p: Vector4) -> void:
	var best: Dictionary = {}
	var best_d: float = 3.6
	var cam: Camera4D = camera()
	var fwd: Vector4 = -cam.global_basis.z if cam != null else Vector4(0, 0, -1, 0)
	for pk in pockets:
		var c: Vector4 = pk["centre"]
		var to := Vector2(c.x - p.x, c.z - p.z)
		var dd: float = to.length()
		if dd < best_d and to.normalized().dot(Vector2(fwd.x, fwd.z).normalized()) > 0.55:
			best_d = dd
			best = pk
	var key: String = String(best.get("key", ""))
	if key != _caption_key:
		_caption_key = key
		if key.is_empty():
			hud.call("hide_caption")
		else:
			var sp: Dictionary = Species.by_key(key)
			hud.call("show_caption", String(sp["name"]).to_upper(), String(sp["latin"]), String(sp["line"]))


func _strip() -> void:
	if hud == null:
		return
	var out: Array = [["WASD", "Move"], ["Mouse", "Look"], ["Right drag", "Turn every flower through W"], ["Q / E", "Step through W"], ["G", "Gust of wind"]]
	if _strip_tilt > 0:
		out.insert(3, ["%d°" % _strip_tilt, "turned through W"])
		out.insert(4, ["R", "Level"])
	hud.set("strip", out)


func turn_by(dx: float, dy: float) -> void:
	turn_basis = Ground.cleaned(Ground.sliced(turn_basis, Vector2(dx, dy)))
	if not _turn_said and rad_to_deg(Ground.tilt(turn_basis)) > 12.0:
		_turn_said = true
		hud.call("toast", "Each flower turns through W about its own stem: petals you could not see come round")


func level() -> void:
	turn_basis = Projection.IDENTITY


func _input(event: InputEvent) -> void:
	if player == null or loading or _leaving:
		return
	var mm := event as InputEventMouseMotion
	if mm != null and (mm.button_mask & MOUSE_BUTTON_MASK_RIGHT) != 0 and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		turn_by(mm.relative.x * 0.006, mm.relative.y * 0.006)
		get_viewport().set_input_as_handled()


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo or player == null:
		return
	match k.keycode:
		KEY_G:
			gust()
			get_viewport().set_input_as_handled()
		KEY_R:
			if turn_basis != Projection.IDENTITY:
				level()
				hud.call("toast", "Every flower upright and level again")
				get_viewport().set_input_as_handled()


func gust() -> void:
	if wind == null:
		return
	wind.set("gust_speed", 7.0)
	wind.call("gust", 0.75, 6.0, half + 2.0)
	if hud != null:
		hud.call("toast", "A gust of wind: the flowers bow, petals lift, the butterflies take off")


func back_to_hall() -> void:
	get_tree().root.set_meta(ARRIVE_META, "flowers")
	get_tree().change_scene_to_file(HALL)


# -- for the runners --------------------------------------------------------------------------------------

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
	return _built and _labels_done


func shown_tets() -> int:
	var n: int = 0
	for mi in find_children("*", "MeshInstance4D", true, false):
		if (mi as MeshInstance4D).is_visible_in_tree() and (mi as MeshInstance4D).mesh is TetraMesh4D:
			n += ((mi as MeshInstance4D).mesh as TetraMesh4D).get_simplex_cell_vertex_indices().size() / 4
	return n
