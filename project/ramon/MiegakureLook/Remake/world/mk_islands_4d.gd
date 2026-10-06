extends Node4D
## Crosswise: the four islands (PLAN.md part G), built in code from the vocabulary in
## mk_build.gd. Each island is one idea; see PLAN.md's table for what each teaches.
##
## THE WORLD'S AXES. Y is up. The islands run along -Z, one after another, so the way on is "up the
## screen". Every island is 12 m across in X and 8 m deep in W, in five lanes of 1.6 m (-2 .. +2,
## lane 0 at W 0). The floor is banded by lane (warm ana, cool kata; mk_surface.gdshader).
##
## YOU ONLY BUMP INTO WHAT YOU SEE. In the normal view you move in X and Z, and everything that can
## stop you exists at your W, so it is on screen; turned, you move in X and W, and everything that
## can stop you exists at your Z. Railings follow that: along the X edges they span Z and W (seen in
## both views: they are the islands' landmarks, Miegakure's "plane that never changes"); at the W
## edges they stand across W (only seen when turned, which is the only time you can walk into them);
## at the Z ends they stand across X (seen in the normal view). Their colliders are taller than the
## railings (1.3 m, over the jump), so a railing is a railing and not a step off the world.
##
## Each island registers itself with the game: its name, number, Z range, arrival point (the
## checkpoint), its crates, rocks, plates and bridges, a hint, and a framing centre for the camera.
##
## NO class_name (engine_gotchas.md).

const Build := preload("res://ramon/MiegakureLook/Remake/world/mk_build.gd")
const Mats := preload("res://ramon/MiegakureLook/Remake/world/mk_materials.gd")
const Crate := preload("res://ramon/MiegakureLook/Remake/world/mk_crate_4d.gd")
const Plate := preload("res://ramon/MiegakureLook/Remake/world/mk_plate_4d.gd")
const Bridge := preload("res://ramon/MiegakureLook/Remake/world/mk_bridge_4d.gd")
const Plug := preload("res://ramon/MiegakureLook/Remake/world/mk_plug_4d.gd")
const Sign := preload("res://ramon/MiegakureLook/Remake/world/mk_sign_4d.gd")

const LANE := 1.6
const W_MIN := -4.0
const W_MAX := 4.0
const X_HALF := 6.0
const THICK := 2.6
const RAIL_H := 0.75
const RAIL_COLLIDE_H := 1.3

const LANE_TINTS := [Color(0.72, 0.83, 1.0), Color(0.86, 0.92, 1.0), Color(1.0, 1.0, 1.0), Color(1.0, 0.94, 0.84), Color(1.0, 0.86, 0.68)]
const PATH_TEAL := Color(0.30, 0.80, 0.76)
const FLOOR_TINT := Color(1.0, 1.0, 1.0)
const SIDE := Color(0.62, 0.64, 0.72)

## The heights of the floors: island 1, its terrace, and the islands after it.
const Y1 := 0.0
const Y_TERRACE := 1.35
const Y2 := 1.35
const SHRINE_Y := Y2 + 1.6

var solids: Array = []
var islands: Array = []
var crates: Array = []
var plugs: Array = []


## Lane `i`'s W range (-2 .. 2).
static func lane(i: int) -> Vector2:
	var c: float = float(i) * LANE
	return Vector2(c - LANE * 0.5, c + LANE * 0.5)


static func lane_w(i: int) -> float:
	return float(i) * LANE


## The lanes on the blue platform: the same code, gentler, with white seams (multiplying the lab blue
## by the grey floor's warm and cool tints turned it muddy).
func blue_lanes(mark: int = 99) -> Dictionary:
	return {"width": LANE, "zero_w": 0.0, "tints": [Color(0.82, 0.93, 1.1), Color(0.91, 0.97, 1.05), Color(1, 1, 1), Color(1.1, 1.0, 0.93), Color(1.22, 1.02, 0.86)],
		"seam": Color(1, 1, 1, 0.9), "mark_lane": mark, "mark_color": Color(0.30, 0.86, 0.82), "mark_mix": 0.32}


func lanes(mark: int = 99) -> Dictionary:
	return {"width": LANE, "zero_w": 0.0, "tints": LANE_TINTS, "seam": Color(0.50, 0.56, 0.72, 0.85), "mark_lane": mark, "mark_color": PATH_TEAL, "mark_mix": 0.3}


func build() -> void:
	_island_1()
	_island_2()
	_island_3()
	_island_4()


# ---------------------------------------------------------------------------------------------
# Pieces

## A floor piece in the Creation Lab's grid (mid-grey 1 m tiles, Ramon's choice of look, 6 Oct), banded
## by lane, its sides darker.
func _floor(name: String, x: Vector2, z: Vector2, w: Vector2, top_y: float, mark: int = 99, extra: Dictionary = {}) -> Node4D:
	var opts: Dictionary = {"lanes": lanes(mark), "grid": "floor", "tint": FLOOR_TINT, "side_tint": SIDE}
	opts.merge(extra, true)
	return Build.slab(self, name, x, z, w, top_y, THICK, "white", solids, opts)


## THE RAILINGS: walls between pylons (Ramon, 6 Oct: "change fence parameters so the outside platform
## fences become more like walls between pilons. every once in a while a basic fence is fine. for
## variety"). Aaron's FenceGenerator4D bent that way: chunky posts 1.1 m tall and 0.34 m thick, every
## 2.4 m, with one solid beam between them (coverage 1) to 0.7 m, in the lab's wall grid; every
## fourth railing is the plain rail fence instead, for variety.
var _rail_count: int = 0

func _railing(name: String):
	_rail_count += 1
	if _rail_count % 4 == 0:
		var post := Build.fence_material("white", Color(0.95, 0.95, 0.97))
		var rail := Build.fence_material("grey", Color(1.0, 1.0, 1.0))
		return Build.fence(name, RAIL_H, 0.12, 2, 0.35, 1.6, post, rail, rail)
	var pylon := Mats.surface("white", Vector4(1, 1, 1, 1), 1.0, {"grid": "ceiling", "wface": Build.WFACE})
	var panel := Mats.surface("white", Vector4(1, 1, 1, 1), 1.0, {"grid": "wall", "wface": Build.WFACE, "tint": Color(0.92, 0.93, 0.96)})
	var f = Build.fence(name, 1.1, 0.34, 1, 1.0, 2.4, pylon, panel, panel)
	f.set("rib_height_ratio", 0.82)
	f.set("rib_thickness_ratio", 0.7)
	f.set("beam_max_height_ratio", 0.78)
	f.set("beam_thickness_ratio", 0.8)
	return f


## A railing along an X edge (at world x, spanning z and w): seen in both views.
func _rail_x_edge(x: float, z: Vector2, w: Vector2, y: float) -> void:
	var f = _railing("RailX")
	Build.fence_wall_z(self, f, x, z, w, y)
	Build.collider(self, "RailXBody", Vector4(x, y + RAIL_COLLIDE_H * 0.5, (z.x + z.y) * 0.5, (w.x + w.y) * 0.5), Vector4(0.2, RAIL_COLLIDE_H, z.y - z.x, w.y - w.x), solids)


## A railing at a Z end (at world z, spanning x and w): seen in the normal view.
func _rail_z_end(z: float, x: Vector2, w: Vector2, y: float) -> void:
	if x.y - x.x < 0.3 or w.y - w.x < 0.3:
		return
	var f = _railing("RailZ")
	Build.fence_wall_x(self, f, z, x, w, y)
	Build.collider(self, "RailZBody", Vector4((x.x + x.y) * 0.5, y + RAIL_COLLIDE_H * 0.5, z, (w.x + w.y) * 0.5), Vector4(x.y - x.x, RAIL_COLLIDE_H, 0.2, w.y - w.x), solids)


## A railing at a W edge (at world w, spanning x and z): seen only once turned into W.
func _rail_w_edge(w: float, x: Vector2, z: Vector2, y: float) -> void:
	if z.y - z.x < 0.3:
		return
	var f = _railing("RailW")
	Build.fence_wall_w(self, f, w, x, z, y)
	Build.collider(self, "RailWBody", Vector4((x.x + x.y) * 0.5, y + RAIL_COLLIDE_H * 0.5, (z.x + z.y) * 0.5, w), Vector4(x.y - x.x, RAIL_COLLIDE_H, z.y - z.x, 0.2), solids)


## Railings round a rectangular floor piece: both X edges, both W edges, and Z ends except where
## `open_z_ends` (a list of [z, Vector2 x-gap, Vector2 w-gap]) leave a way through.
func _fence_round(x: Vector2, z: Vector2, w: Vector2, y: float, open_z_ends: Array = []) -> void:
	_rail_x_edge(x.x + 0.1, z, w, y)
	_rail_x_edge(x.y - 0.1, z, w, y)
	_rail_w_edge(w.x + 0.1, x, z, y)
	_rail_w_edge(w.y - 0.1, x, z, y)
	for z_end in [z.x + 0.1, z.y - 0.1]:
		var gaps: Array = []
		for g in open_z_ends:
			if absf(float(g[0]) - z_end) < 0.6:
				gaps.append(g)
		if gaps.is_empty():
			_rail_z_end(z_end, Vector2(x.x + 0.2, x.y - 0.2), w, y)
		else:
			# Railing pieces either side of the gap (in X), and above / below it in W.
			var g: Array = gaps[0]
			var gx: Vector2 = g[1]
			var gw: Vector2 = g[2]
			_rail_z_end(z_end, Vector2(x.x + 0.2, gx.x), w, y)
			_rail_z_end(z_end, Vector2(gx.y, x.y - 0.2), w, y)
			_rail_z_end(z_end, gx, Vector2(w.x, gw.x), y)
			_rail_z_end(z_end, gx, Vector2(gw.y, w.y), y)


func _crate(name: String, at: Vector4) -> Node4D:
	var c := CharacterBody4D.new()
	c.name = name
	c.set_script(Crate)
	add_child(c)
	c.global_position = at
	c.set("home", at)
	c.add_to_group(&"mk_ghost")
	crates.append(c)
	return c


func _plug(name: String, at: Vector4, size: Vector4, dent_face: Vector4 = Vector4(0, 0, 1, 0)) -> Node4D:
	var p := Node4D.new()
	p.name = name
	p.set_script(Plug)
	p.set("size", size)
	p.set("dent_face", dent_face)
	add_child(p)
	p.global_position = at
	p.add_to_group(&"mk_ghost")
	plugs.append(p)
	return p


## A gate frame (a torii) across X at world z, standing in the W range: two posts and a lintel.
func _torii(z: float, x: Vector2, w: Vector2, y: float, color_tex: String = "red") -> void:
	var m := Build.fence_material(color_tex, Color(1.0, 0.86, 0.82))
	var f = Build.fence("Torii", 2.4, 0.24, 1, 0.14, 0.0, m, m, m)
	f.set("rib_height_ratio", 0.999)
	f.set("beam_max_height_ratio", 0.999)
	Build.fence_wall_x(self, f, z, x, w, y)


## A faceted crystal (an orthoplex, flat-shaded: the Miegakure crystal our renderer draws for free),
## off the routes, with no collider.
func _crystal(at: Vector4, size: Vector4, tex: String, tint: Color) -> void:
	var m := MeshInstance4D.new()
	m.name = "Crystal"
	var o := OrthoplexTetraMesh4D.new()
	o.size = size
	m.mesh = o
	m.material_override = Mats.surface(tex, size, 1.0, {"tint": tint, "wface": Build.WFACE})
	add_child(m)
	m.global_position = at


## A painted outline on the floor (a footprint frame, a "put it here" mark): four thin glowing bars,
## round a square of `size` at world `at`, `depth_w` deep in W.
func _outline(at: Vector4, half: float, depth_w: float, color: Color, dashed: bool = true) -> void:
	var t := 0.06
	var parts: Array = []
	if dashed:
		var n := 4
		for i in n:
			var a: float = -half + (float(i) + 0.25) * (2.0 * half / float(n))
			var len: float = (2.0 * half / float(n)) * 0.5
			parts.append([Vector4(a + len * 0.5, 0, -half, 0), Vector4(len, 0.02, t, depth_w)])
			parts.append([Vector4(a + len * 0.5, 0, half, 0), Vector4(len, 0.02, t, depth_w)])
			parts.append([Vector4(-half, 0, a + len * 0.5, 0), Vector4(t, 0.02, len, depth_w)])
			parts.append([Vector4(half, 0, a + len * 0.5, 0), Vector4(t, 0.02, len, depth_w)])
	else:
		parts = [[Vector4(0, 0, -half, 0), Vector4(half * 2 + t, 0.02, t, depth_w)], [Vector4(0, 0, half, 0), Vector4(half * 2 + t, 0.02, t, depth_w)],
			[Vector4(-half, 0, 0, 0), Vector4(t, 0.02, half * 2 + t, depth_w)], [Vector4(half, 0, 0, 0), Vector4(t, 0.02, half * 2 + t, depth_w)]]
	for p in parts:
		Build.glow_box(self, "Outline", at + Vector4(0, 0.012, 0, 0) + p[0], p[1], color)


## An arrival ring (a checkpoint): a breathing teal ring of segments on the floor, as deep in W as
## a lane.
func _arrival(at: Vector4) -> void:
	for i in 12:
		var a: float = float(i) / 12.0 * TAU
		var c := Vector4(cos(a) * 0.75, 0.012, sin(a) * 0.75, 0)
		var seg := Build.glow_box(self, "Ring", at + c, Vector4(0.22, 0.02, 0.22, LANE * 0.8), PATH_TEAL, 0.8)
		seg.basis = Basis4D.from_zx(-a)


## A sign painted on the floor (key caps and a few words; world/mk_sign_4d.gd), `size` (x, z) in
## metres, in one lane's depth of W unless told otherwise.
func _sign(at: Vector4, size: Vector2, sign_lines: Array, depth_w: float = LANE * 0.9, ink: Color = Color(0.09, 0.31, 0.80), align: String = "center") -> void:
	var s := Node4D.new()
	s.name = "Sign"
	s.set_script(Sign)
	s.set("lines", sign_lines)
	s.set("ink", ink)
	s.set("align", align)
	s.set("size", size)
	s.set("depth_w", depth_w)
	add_child(s)
	s.global_position = at


func _register(info: Dictionary) -> void:
	islands.append(info)


# ---------------------------------------------------------------------------------------------
# 1. THE WALL. A gate wall across the island stands in every lane but +2. Go round it through W
# (turn, walk ana two lanes, turn back, walk through). Then, in plain 3D, a terrace too high to
# jump, and a crate at its foot in lane 0: lift, place, climb. The onlooker stands in lane 0.

const I1_Z := Vector2(-7.0, 6.5)
const I1_WALL_Z := Vector2(-0.6, 0.4)
const I1_TERRACE_Z := Vector2(-7.0, -4.2)

func _island_1() -> void:
	var w_all := Vector2(W_MIN, W_MAX)
	var x_all := Vector2(-X_HALF, X_HALF)
	# The start platform, in front of the wall, is the lab's code blue (a teaching wall laid flat, with
	# white paint on it); behind the wall the grey floor (Ramon, 6 Oct).
	_floor("I1FloorBlue", x_all, Vector2(I1_WALL_Z.y, I1_Z.y), w_all, Y1, 2, {"grid": "blue", "lanes": blue_lanes(2)})
	_floor("I1Floor", x_all, Vector2(I1_Z.x, I1_WALL_Z.y), w_all, Y1, 2)
	# The terrace at the far end: lanes -1..+1 only (so the way on is back in the middle worlds).
	var tw: Vector2 = Vector2(lane(-1).x, lane(1).y)
	_floor("I1Terrace", Vector2(-2.5, 2.5), I1_TERRACE_Z, tw, Y_TERRACE, 99, {"tint": Color(0.86, 0.86, 0.88)})
	# The gate wall: lanes -2..+1, the whole width, 2 m high. Its look is a fence sheet in X-W with
	# solid beams (a islands wall with posts); its collision one box.
	var wall_w := Vector2(W_MIN, lane(1).y)
	var stone := Build.fence_material("grey", Color(0.96, 0.96, 1.0))
	var cap := Build.fence_material("dark_grey", Color(1, 1, 1))
	var f = Build.fence("GateWall", 2.1, 0.5, 1, 1.0, 2.0, cap, stone, stone)
	f.set("rib_thickness_ratio", 0.8)
	f.set("beam_thickness_ratio", 0.9)
	f.set("beam_max_height_ratio", 0.95)
	Build.fence_wall_x(self, f, (I1_WALL_Z.x + I1_WALL_Z.y) * 0.5, Vector2(-X_HALF + 0.2, X_HALF - 0.2), wall_w, Y1)
	Build.collider(self, "GateWallBody", Vector4(0, 1.2, (I1_WALL_Z.x + I1_WALL_Z.y) * 0.5, (wall_w.x + wall_w.y) * 0.5),
		Vector4(X_HALF * 2.0, 2.4, I1_WALL_Z.y - I1_WALL_Z.x, wall_w.y - wall_w.x), solids)
	# The open lane's gate frame: the torii stands where the wall is not.
	_torii((I1_WALL_Z.x + I1_WALL_Z.y) * 0.5, Vector2(-1.4, 1.4), Vector2(lane(2).x + 0.25, lane(2).y - 0.25), Y1)
	# Railings: round the island, with the terrace's bridge gap at the far end.
	_fence_round(x_all, I1_Z, w_all, Y1)
	_rail_z_end(I1_TERRACE_Z.x + 0.1, Vector2(-2.3, -0.9), tw, Y_TERRACE)
	_rail_z_end(I1_TERRACE_Z.x + 0.1, Vector2(0.9, 2.3), tw, Y_TERRACE)
	# The crate at the terrace's foot, in lane 0, to the side so you see the step it makes.
	var crate := _crate("I1Crate", Vector4(-1.6, Y1 + 0.02, -2.9, 0))
	# Where it should go (a dashed outline against the terrace face).
	_outline(Vector4(0, Y1, -3.75, 0), 0.38, LANE * 0.7, Color(1.0, 0.85, 0.35))
	# Crystals off the route.
	_crystal(Vector4(-4.9, Y1 + 0.9, 5.4, 0), Vector4(1.1, 1.8, 1.1, 1.4), "violet", Color(0.9, 0.85, 1.0))
	_crystal(Vector4(4.7, Y1 + 0.6, -5.4, lane_w(-2)), Vector4(0.9, 1.2, 0.9, 1.2), "cyan", Color(0.85, 0.95, 1.0))
	_arrival(Vector4(0, Y1, 5.05, 0))
	# The explainer, painted on the blue like the lab's teaching walls: a header line, the title, two
	# lines, and the controls row, in white.
	_sign(Vector4(-0.6, Y1, 2.75, 0), Vector2(9.6, 2.7), [
		[["small", "01  /  CROSSWISE"]],
		[["title", "The Wall"]],
		[["body", "You see one slice of a 4D world. The wall is not in every slice."]],
		[["key", "W"], ["key", "A"], ["key", "S"], ["key", "D"], ["small", "walk"], ["key", "SPACE"], ["small", "jump"], ["mouse", "right"], ["small", "turn into W"]]],
		LANE * 0.9, Color.WHITE, "left")
	_sign(Vector4(0, Y1, 0.9, 0), Vector2(4.4, 0.7), [[["mouse", "right"], ["text", "turn into W"], ["dots", 2, "warm"]]], LANE * 0.9, Color.WHITE)
	_sign(Vector4(0, Y1, -1.7, lane_w(2)), Vector2(3.4, 0.8), [[["text", "back"], ["dots", 2, "cool"]]])
	_sign(Vector4(1.6, Y1, -1.7, 0), Vector2(2.6, 0.8), [[["key", "E"], ["text", "lift, put down"]]])
	_register({
		"number": 1, "name": "THE WALL", "z": I1_Z, "spawn": Vector4(0, Y1 + 0.05, 5.05, 0), "facing": PI,
		"centre": Vector4(0, Y1, -0.5, 0), "crates": [crate], "plugs": [], "hint":
			"The wall is not in every world. Turn into W (right mouse), walk to the warm lane with the gate, turn back, walk through.",
		"goal": Vector4(0, Y_TERRACE, -6.0, 0)})


# ---------------------------------------------------------------------------------------------
# 2. THE CAGE. A crate sits in a cage that is closed in X and Z but open along W, and a yellow
# plate waits at a chasm. Stand on the cage's painted footprint in another lane, turn, walk into the
# cage through W, lift the crate, carry it out, put it on the plate: a bridge slides out over the
# chasm in lane 0.

const I2_NEAR_Z := Vector2(-21.0, -10.5)
const I2_FAR_Z := Vector2(-31.0, -25.0)
const I2_BRIDGE_Z := Vector2(-10.5, -7.0)
const I2_CAGE := Vector4(-2.4, Y2, -14.6, 0.0)
const I2_PLATE := Vector4(2.2, Y2, -19.6, 0.0)

func _island_2() -> void:
	var w_all := Vector2(W_MIN, W_MAX)
	var x_all := Vector2(-X_HALF, X_HALF)
	var mid := Vector2(lane(-1).x, lane(1).y)
	# The bridge from the terrace (lanes -1..+1, 2 m wide).
	_floor("I2Bridge", Vector2(-0.9, 0.9), I2_BRIDGE_Z, mid, Y2, 99, {"tint": Color(0.92, 0.9, 0.86)})
	_rail_x_edge(-1.0, I2_BRIDGE_Z, mid, Y2)
	_rail_x_edge(1.0, I2_BRIDGE_Z, mid, Y2)
	_rail_w_edge(mid.x + 0.1, Vector2(-0.9, 0.9), I2_BRIDGE_Z, Y2)
	_rail_w_edge(mid.y - 0.1, Vector2(-0.9, 0.9), I2_BRIDGE_Z, Y2)
	_floor("I2Near", x_all, I2_NEAR_Z, w_all, Y2, 0)
	_floor("I2Far", x_all, I2_FAR_Z, w_all, Y2, 0)
	_fence_round(x_all, I2_NEAR_Z, w_all, Y2, [[I2_NEAR_Z.y - 0.1, Vector2(-0.9, 0.9), mid], [I2_NEAR_Z.x + 0.1, Vector2(-1.1, 1.1), lane(0)]])
	_fence_round(x_all, I2_FAR_Z, w_all, Y2, [[I2_FAR_Z.y - 0.1, Vector2(-1.1, 1.1), lane(0)], [I2_FAR_Z.x + 0.1, Vector2(-0.9, 0.9), lane(0)]])
	# The cage: 1.8 m square in X-Z, lane 0 deep in W, 1.6 m tall, bars every 0.4 m; closed in X and
	# Z, open along W. Its collision: four thin walls.
	var half := 0.9
	# Mid-grey bars on dark posts: black_metal read as one black block from the diorama camera, the
	# crate inside lost behind it (6 Oct frames).
	var bars := Build.fence_material("grey", Color(1.15, 1.15, 1.2))
	var cage_posts := Build.fence_material("dark_grey", Color(1, 1, 1))
	var f = Build.fence("Cage", 1.6, 0.16, 3, 0.16, 0.42, cage_posts, bars, bars)
	Build.fence_tube_w(self, f, I2_CAGE, half, half, LANE)
	f.add_to_group(&"mk_ghost")
	var cw: Vector2 = lane(0)
	for side in [-1.0, 1.0]:
		Build.collider(self, "CageX", I2_CAGE + Vector4(side * half, 0.9, 0, 0), Vector4(0.2, 1.8, half * 2.0, LANE), solids)
		Build.collider(self, "CageZ", I2_CAGE + Vector4(0, 0.9, side * half, 0), Vector4(half * 2.0, 1.8, 0.2, LANE), solids)
	var crate := _crate("I2Crate", I2_CAGE + Vector4(0, 0.02, 0, 0))
	# The cage's footprint painted in every OTHER lane: "it stands here, in another world".
	for i in [-2, -1, 1, 2]:
		_outline(Vector4(I2_CAGE.x, Y2, I2_CAGE.z, lane_w(i)), half, LANE * 0.85, Color(0.42, 0.40, 0.60))
	# The plate, and the bridge it lays across the chasm (lane 0, from the near lip toward -Z).
	var plate := Node4D.new()
	plate.name = "I2Plate"
	plate.set_script(Plate)
	add_child(plate)
	plate.global_position = I2_PLATE
	var bridge := Node4D.new()
	bridge.name = "I2ChasmBridge"
	bridge.set_script(Bridge)
	bridge.set("length", I2_NEAR_Z.x - I2_FAR_Z.y)
	bridge.set("width", 2.0)
	bridge.set("depth_w", LANE)
	bridge.set("planks", 6)
	add_child(bridge)
	bridge.global_position = Vector4(0, Y2, I2_NEAR_Z.x, 0)
	plate.connect("pressed_changed", func(p: bool) -> void: bridge.call("set_open", p))
	# Crystals.
	_crystal(Vector4(4.6, Y2 + 0.8, -12.0, lane_w(2)), Vector4(1.0, 1.6, 1.0, 1.2), "violet", Color(0.92, 0.88, 1.0))
	_crystal(Vector4(-4.8, Y2 + 0.7, -28.5, 0), Vector4(1.0, 1.4, 1.0, 1.4), "cyan", Color(0.85, 0.95, 1.0))
	_arrival(Vector4(0, Y2, -11.6, 0))
	_sign(Vector4(-2.4, Y2, -12.6, lane_w(-1)), Vector2(3.2, 0.8), [[["text", "stand inside, turn"], ["mouse", "right"]]])
	_register({
		"number": 2, "name": "THE CAGE", "z": Vector2(-31.0, -7.0), "spawn": Vector4(0, Y2 + 0.05, -11.6, 0), "facing": PI,
		"centre": Vector4(0, Y2, -18.5, 0), "crates": [crate], "plugs": [], "plates": [plate], "bridges": [bridge], "hint":
			"The cage is only closed in 3D. Stand on its outline in another lane, turn into W, and walk in from the side W opens.",
		"goal": Vector4(0, Y2, -28.0, 0)})


# ---------------------------------------------------------------------------------------------
# 3. THE SEAM. First a small rock across the way in from the bridge (lane 0 only, so there is no
# going round it): two strikes, in plain 3D. Then the island: a fence stands ACROSS W between lane +1
# and lane +2, the whole island long, and the bridge on is in lane +2. Its one door is plugged by a
# rock. A striped band across the floor marks the door's Z: stand on it, turn, and the fence and its
# rock are right there.

const I3_BRIDGE_Z := Vector2(-35.0, -31.0)
const I3_LANDING_Z := Vector2(-37.6, -35.0)
const I3_Z := Vector2(-50.0, -37.6)
const I3_SEAM_W := 2.4
const I3_DOOR_Z := Vector2(-45.2, -43.2)
const I3_DOOR_X := Vector2(-0.8, 0.8)

func _island_3() -> void:
	var w_all := Vector2(W_MIN, W_MAX)
	var x_all := Vector2(-X_HALF, X_HALF)
	# The bridge and the landing: lane 0 only.
	_floor("I3Bridge", Vector2(-0.9, 0.9), I3_BRIDGE_Z, lane(0), Y2, 99, {"tint": Color(0.92, 0.9, 0.86)})
	_rail_x_edge(-1.0, I3_BRIDGE_Z, lane(0), Y2)
	_rail_x_edge(1.0, I3_BRIDGE_Z, lane(0), Y2)
	_floor("I3Landing", Vector2(-1.4, 1.4), I3_LANDING_Z, lane(0), Y2, 99, {"tint": Color(0.92, 0.9, 0.86)})
	_rail_x_edge(-1.5, I3_LANDING_Z, lane(0), Y2)
	_rail_x_edge(1.5, I3_LANDING_Z, lane(0), Y2)
	# The first rock: across the landing, at its far end.
	var rock_a := _plug("I3RockA", Vector4(0, Y2, I3_LANDING_Z.x + 0.7, 0), Vector4(2.8, 1.8, 1.2, LANE))
	# The island.
	_floor("I3Floor", x_all, I3_Z, w_all, Y2, 2, {"hazard": I3_DOOR_Z})
	_fence_round(x_all, I3_Z, w_all, Y2, [[I3_Z.y - 0.1, Vector2(-1.4, 1.4), lane(0)], [I3_Z.x + 0.1, Vector2(-0.9, 0.9), lane(2)]])
	# The seam: a fence across W at w 2.4, everywhere on the island but the door. Four sheets round
	# the door, each a fence with its face in X-Z; collision the same four boxes.
	var seam := Build.fence_material("violet", Color(0.95, 0.92, 1.0))
	var posts := Build.fence_material("dark_grey", Color(1, 1, 1))
	var pieces: Array = [
		[Vector2(-X_HALF + 0.2, I3_DOOR_X.x), Vector2(I3_Z.x + 0.2, I3_Z.y - 0.2)],
		[Vector2(I3_DOOR_X.y, X_HALF - 0.2), Vector2(I3_Z.x + 0.2, I3_Z.y - 0.2)],
		[I3_DOOR_X, Vector2(I3_Z.x + 0.2, I3_DOOR_Z.x)],
		[I3_DOOR_X, Vector2(I3_DOOR_Z.y, I3_Z.y - 0.2)]]
	for p in pieces:
		var px: Vector2 = p[0]
		var pz: Vector2 = p[1]
		if px.y - px.x < 0.3 or pz.y - pz.x < 0.3:
			continue
		var f = Build.fence("Seam", 2.0, 0.3, 2, 0.8, 1.8, posts, seam, seam)
		Build.fence_wall_w(self, f, I3_SEAM_W, px, pz, Y2)
		Build.collider(self, "SeamBody", Vector4((px.x + px.y) * 0.5, Y2 + 1.2, (pz.x + pz.y) * 0.5, I3_SEAM_W), Vector4(px.y - px.x, 2.4, pz.y - pz.x, 0.3), solids)
	# The rock in the door.
	# Dented on its kata face: you come at it walking ana, turned into W.
	var rock_b := _plug("I3RockB", Vector4(0, Y2, (I3_DOOR_Z.x + I3_DOOR_Z.y) * 0.5, I3_SEAM_W), Vector4(I3_DOOR_X.y - I3_DOOR_X.x, 2.0, I3_DOOR_Z.y - I3_DOOR_Z.x, 0.8), Vector4(0, 0, 0, -1))
	_crystal(Vector4(-4.4, Y2 + 0.8, -40.0, 0), Vector4(1.2, 1.6, 1.2, 1.4), "violet", Color(0.9, 0.86, 1.0))
	_crystal(Vector4(4.6, Y2 + 0.7, -48.2, lane_w(-1)), Vector4(1.0, 1.4, 1.0, 1.2), "cyan", Color(0.86, 0.95, 1.0))
	_arrival(Vector4(0, Y2, -35.9, 0))
	_sign(Vector4(0, Y2, -36.5, 0), Vector2(2.6, 0.7), [[["mouse", "left"], ["text", "strike"]]])
	_sign(Vector4(0, Y2, -42.4, 0), Vector2(3.6, 0.8), [[["text", "on the stripes"], ["mouse", "right"]]])
	_register({
		"number": 3, "name": "THE SEAM", "z": Vector2(-50.0, -31.0), "spawn": Vector4(0, Y2 + 0.05, -35.9, 0), "facing": PI,
		"centre": Vector4(0, Y2, -43.0, 0), "crates": [], "plugs": [rock_a, rock_b], "hint":
			"Stand on the striped band and turn into W: a fence crosses the worlds there, and its door has a rock in it. Two strikes.",
		"goal": Vector4(0, Y2, -49.0, lane_w(2))})


# ---------------------------------------------------------------------------------------------
# 4. THE SHRINE. You arrive in lane +2. The shrine stands on a terrace 1.6 m high at the far end,
# with the tower behind it. The terrace has a railing on top everywhere but lane 0, and the crate
# waits in lane +2. Between them lane +1 has no floor near the terrace: carry the crate back from
# the terrace to where lane +1 has floor, cross it through W, place the crate at the marked spot in
# lane 0, climb crate then terrace, and walk to the shrine door.

const I4_BRIDGE_Z := Vector2(-54.0, -50.0)
const I4_Z := Vector2(-63.0, -54.0)
const I4_TERRACE_Z := Vector2(-69.0, -63.0)
const I4_GAP_Z := Vector2(-63.0, -56.4)
const I4_DOOR := Vector4(0.0, SHRINE_Y, -64.9, 0.0)

var shrine_door: Vector4 = I4_DOOR
var tower_lamps: Array = []

func _island_4() -> void:
	var w_all := Vector2(W_MIN, W_MAX)
	var x_all := Vector2(-X_HALF, X_HALF)
	# The bridge from island 3's lane +2.
	_floor("I4Bridge", Vector2(-0.9, 0.9), I4_BRIDGE_Z, lane(2), Y2, 99, {"tint": Color(0.92, 0.9, 0.86)})
	_rail_x_edge(-1.0, I4_BRIDGE_Z, lane(2), Y2)
	_rail_x_edge(1.0, I4_BRIDGE_Z, lane(2), Y2)
	# The floor: lanes -2..0 and +2 the whole way; lane +1 only for the first 2.4 m (the W gap).
	_floor("I4FloorKata", x_all, I4_Z, Vector2(W_MIN, lane(0).y), Y2, 0)
	_floor("I4FloorAna", x_all, I4_Z, lane(2), Y2, 0)
	_floor("I4FloorStrip", x_all, Vector2(I4_GAP_Z.y, I4_Z.y), lane(1), Y2, 0)
	# Railings round the whole island floor. Also along the gap's edges: in lane 0 and lane +2 at
	# the gap's W faces (stand across W, seen when turned), so the gap is a railed drop, not a trap.
	# No railing at the far end: the terrace's face is the edge there (a railing at its foot blocked
	# the crate's mark and the climb, found by the solver bot, 6 Oct).
	_fence_round(x_all, I4_Z, w_all, Y2, [[I4_Z.y - 0.1, Vector2(-1.1, 1.1), lane(2)], [I4_Z.x + 0.1, Vector2(-X_HALF, X_HALF), w_all]])
	_rail_w_edge(lane(1).x + 0.1, x_all, I4_GAP_Z, Y2)
	_rail_w_edge(lane(1).y - 0.1, x_all, I4_GAP_Z, Y2)
	# The terrace: all lanes, 1.6 m up.
	_floor("I4Terrace", x_all, I4_TERRACE_Z, w_all, SHRINE_Y, 0, {"tint": Color(0.88, 0.88, 0.9)})
	_rail_x_edge(-X_HALF + 0.1, I4_TERRACE_Z, w_all, SHRINE_Y)
	_rail_x_edge(X_HALF - 0.1, I4_TERRACE_Z, w_all, SHRINE_Y)
	_rail_w_edge(W_MIN + 0.1, x_all, I4_TERRACE_Z, SHRINE_Y)
	_rail_w_edge(W_MAX - 0.1, x_all, I4_TERRACE_Z, SHRINE_Y)
	_rail_z_end(I4_TERRACE_Z.x + 0.1, Vector2(-X_HALF + 0.2, X_HALF - 0.2), w_all, SHRINE_Y)
	# The terrace's front railing: everywhere but lane 0 (where the climb is).
	_rail_z_end(I4_TERRACE_Z.y - 0.1, Vector2(-X_HALF + 0.2, X_HALF - 0.2), Vector2(W_MIN, lane(0).x), SHRINE_Y)
	_rail_z_end(I4_TERRACE_Z.y - 0.1, Vector2(-X_HALF + 0.2, X_HALF - 0.2), Vector2(lane(0).y, W_MAX), SHRINE_Y)
	_rail_z_end(I4_TERRACE_Z.y - 0.1, Vector2(-X_HALF + 0.2, -1.2), lane(0), SHRINE_Y)
	_rail_z_end(I4_TERRACE_Z.y - 0.1, Vector2(1.2, X_HALF - 0.2), lane(0), SHRINE_Y)
	# The torii over the climb.
	_torii(I4_TERRACE_Z.y - 0.25, Vector2(-1.15, 1.15), Vector2(lane(0).x + 0.2, lane(0).y - 0.2), SHRINE_Y)
	# Where the crate goes.
	_outline(Vector4(0, Y2, I4_TERRACE_Z.y + 0.5, 0), 0.38, LANE * 0.7, Color(1.0, 0.85, 0.35))
	var crate := _crate("I4Crate", Vector4(2.2, Y2 + 0.02, -57.6, lane_w(2)))
	_build_shrine()
	_crystal(Vector4(-4.6, Y2 + 0.8, -55.6, lane_w(-1)), Vector4(1.1, 1.6, 1.1, 1.4), "violet", Color(0.9, 0.86, 1.0))
	_arrival(Vector4(0, Y2, -55.2, lane_w(2)))
	_register({
		"number": 4, "name": "THE SHRINE", "z": Vector2(-69.0, -50.0), "spawn": Vector4(0, Y2 + 0.05, -55.2, lane_w(2)), "facing": PI,
		"centre": Vector4(0, Y2, -61.0, 0), "crates": [crate], "plugs": [], "hint":
			"Only lane 0 has no railing on the terrace. Carry the crate across W where lane +1 has floor, put it on the mark, climb.",
		"goal": I4_DOOR})


## The shrine and its tower, on the terrace in lane 0, spanning every lane so the tower is in view
## from the whole islands in the normal view. Fence-built: the shrine's walls (solid, with posts), a
## pyramid roof (a box footprint leaning to a point), the tower (a box footprint leaning in, rings of
## rails), its lamps (glowing).
func _build_shrine() -> void:
	var at := Vector4(0, SHRINE_Y, -66.4, 0)
	var white := Build.fence_material("white", Color(0.97, 0.97, 0.98))
	var dark := Build.fence_material("dark_grey", Color(1, 1, 1))
	var red := Build.fence_material("red", Color(1.0, 0.86, 0.82))
	var walls = Build.fence("ShrineWalls", 1.9, 0.24, 1, 1.0, 1.3, dark, white, white)
	Build.fence_box(self, walls, at, Vector3(2.8, 2.6, 2.8))
	walls.add_to_group(&"mk_ghost")
	var roof = Build.fence("ShrineRoof", 1.5, 0.14, 1, 1.0, 0.0, red, red, red)
	roof.set("top_footprint_ratio", 0.05)
	roof.set("rib_height_ratio", 0.999)
	roof.set("beam_max_height_ratio", 0.999)
	Build.fence_box(self, roof, at + Vector4(0, 1.9, 0, 0), Vector3(3.4, 3.2, 3.4))
	var tower = Build.fence("Tower", 9.0, 0.26, 6, 0.2, 0.0, dark, white, white)
	tower.set("top_footprint_ratio", 0.5)
	Build.fence_box(self, tower, Vector4(0, SHRINE_Y, -68.0, 0), Vector3(2.4, 1.6, 8.0))
	tower.add_to_group(&"mk_ghost")
	roof.add_to_group(&"mk_ghost")
	Build.collider(self, "ShrineBody", at + Vector4(0, 1.2, 0, 0), Vector4(2.8, 2.4, 2.6, 2.8), solids)
	# The door: a dark opening on the shrine's front, and the lamps on the tower's top (lit at the end).
	Build.box(self, "Door", at + Vector4(0, 0.75, 1.3, 0), Vector4(0.9, 1.5, 0.12, 1.4), Mats.flat(Color(0.12, 0.12, 0.16)), null, false)
	for i in 4:
		var lamp := Build.glow_box(self, "Lamp%d" % i, Vector4((float(i % 2) - 0.5) * 1.0, SHRINE_Y + 8.6, -68.0 + (float(i / 2) - 0.5) * 0.6, 0), Vector4(0.3, 0.3, 0.3, 7.6), Color(0.55, 0.55, 0.6))
		lamp.material_override = Mats.glow(Color(0.55, 0.55, 0.6), 1.0, 0.0, true)
		tower_lamps.append(lamp)
