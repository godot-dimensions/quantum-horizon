extends Node4D

## The Arboretum's grove (Ramon, 5 Oct: "finish with a small grove showing how that method looks when
## repeated at an environmental scale ... maybe there's a second room"): the room behind the oak, cut
## into four plots, each a small wood of one method's trees. Not the pedestal trees: lighter ones,
## because a wood multiplies everything (25 cm voxels instead of 12.5, the loft at its fewest sides,
## smaller oaks with fewer leaves), three shapes per method from three seeds, each shape ONE mesh that
## every tree of it shares (a mesh's video memory is held once, however many trees draw it), each tree
## turned, sized and placed at its own W. It is a 4D wood: trees stand ana and kata of you too, so
## walking through W (Q and E, here only) brings others in.
##
## LOADING (plan step 90): nothing of the grove is loaded with the room. When you come within
## `load_from` metres of its door the shapes are requested from disk on threads
## (ResourceLoader.load_threaded_request), and the trees are placed as each arrives, so the hall never
## pays for the grove and the grove is there by the time you walk in. The tour asks for it early.
## Every number on its signs is measured here or by the bake, and says which.
##
## NO class_name (engine_gotchas.md).

const Bake := preload("res://ramon/Arboretum/botany/bake_store.gd")
const Style := preload("res://ramon/Arboretum/botany/botany_style.gd")
const Pivots := preload("res://ramon/Arboretum/botany/tree_pivots.gd")
const Leaves := preload("res://ramon/Arboretum/botany/leaf_field_4d.gd")
const Wind := preload("res://ramon/Arboretum/botany/wind_4d.gd")
const Sign := preload("res://ramon/Arboretum/grove/grove_sign_4d.gd")
const Species := preload("res://ramon/Arboretum/botany/tree_species.gd")

## The room's floor (x, z), metres, centred on this node.
@export var area: Vector2 = Vector2(40, 36)
## Trees per plot, how far ana and kata the outlying ones stand (m), and the room's W bounds for
## walking. Two in three trees stand within 0.3 m of your slice and the rest between 0.5 m and
## w_spread: a squashed tree is only about 1.4 m deep in W, so a grove spread 2.4 m through W (the
## first version) showed you two or three trees of seven (case study 5). The outlying ones show as
## thinner cuts, and they grow and shrink as you walk through W.
@export_range(1, 16, 1) var trees_per_plot: int = 7
@export_range(0.0, 4.0, 0.1) var w_spread: float = 0.9
@export_range(0.5, 4.0, 0.1) var w_walk: float = 3.0
## How near the door (m) the grove starts loading.
@export_range(4.0, 60.0, 1.0) var load_from: float = 22.0
## How near the door (m) the loaded grove is drawn. Loaded is not drawn: the cross-section renderer
## cuts every tetrahedron it is given each frame, seen or not, and the grove's 870,000 cost the hall
## about 5 ms of GPU from wherever it was loaded (case study 5).
@export_range(2.0, 60.0, 1.0) var show_from: float = 12.0
## Shown height of the trees (m): the specimen tree and the oak.
@export var tree_height: float = 3.9
@export var oak_height: float = 5.8

## The plots: method, the shapes it draws from, the corner its sign stands at.
const PLOTS := [
	{"key": "voxel", "name": "Voxels", "shapes": ["grove_vx_0", "grove_vx_1", "grove_vx_2"], "skel": ["grove_sk_0_skeleton", "grove_sk_1_skeleton", "grove_sk_2_skeleton"], "cell": "25 cm cells"},
	{"key": "dc", "name": "Smooth voxels", "shapes": ["grove_dc_0", "grove_dc_1", "grove_dc_2"], "skel": ["grove_sk_0_skeleton", "grove_sk_1_skeleton", "grove_sk_2_skeleton"], "cell": "25 cm cells"},
	{"key": "loft", "name": "Lofted", "shapes": ["grove_lf_0", "grove_lf_1", "grove_lf_2"], "extra": ["grove_lfc_0", "grove_lfc_1", "grove_lfc_2"], "skel": ["grove_sk_0_skeleton", "grove_sk_1_skeleton", "grove_sk_2_skeleton"], "cell": "fewest sides"},
	{"key": "oak", "name": "Oaks", "shapes": ["grove_ok_0", "grove_ok_1"], "skel": ["grove_oak_0_skeleton", "grove_oak_1_skeleton"], "cell": "leaves on the GPU"},
]

var state: String = "idle"
var _requests: Array = []
var _loaded: Dictionary = {}
var _plots: Array = []
var _player_inside: bool = false
var _player: Node4D
var _load_ms: float = 0.0
var _t0: int = 0
var _leaf_src: Dictionary = {}


## The room hands the player's place every frame: load on approach, W walking inside.
func update_player(p: Vector4) -> void:
	var door := Vector2(global_position.x, global_position.z + area.y * 0.5)
	if state == "idle" and Vector2(p.x, p.z).distance_to(door) < load_from:
		preload_all()
	var inside: bool = is_inside(p)
	var show: bool = inside or Vector2(p.x, p.z).distance_to(door) < show_from
	if visible != show:
		visible = show
	if inside != _player_inside:
		_player_inside = inside
		_walk_w(inside)
	if inside and _player != null:
		# The room's walls are only so deep in W: keep the walker within them.
		var pp: Vector4 = _player.global_position
		if absf(pp.w) > w_walk:
			pp.w = clampf(pp.w, -w_walk, w_walk)
			_player.global_position = pp


## How far into the grove `p` is from its door (m; negative outside, toward the hall).
func depth_inside(p: Vector4) -> float:
	return global_position.z + area.y * 0.5 - p.z


func is_inside(p: Vector4) -> bool:
	var l: Vector4 = p - global_position
	return absf(l.x) < area.x * 0.5 and absf(l.z) < area.y * 0.5


## Q and E walk through W in the grove (the pen's way); in the hall the lab keeps you in your slice.
func _walk_w(on: bool) -> void:
	if _player == null:
		var room: Node = get_parent()
		_player = room.get("player") if room != null else null
	if _player != null:
		_player.set("w_speed_scale", 0.3 if on else 0.0)
		if not on:
			var pp: Vector4 = _player.global_position
			pp.w = 0.0
			_player.global_position = pp


## Asks for every shape on threads; the trees are placed as they arrive (_process).
func preload_all() -> void:
	if state != "idle":
		return
	state = "loading"
	_t0 = Time.get_ticks_usec()
	for plot in PLOTS:
		var names: Array = (plot["shapes"] as Array) + (plot.get("extra", []) as Array) + (plot["skel"] as Array)
		for n in names:
			if _requests.has(n):
				continue
			var p: String = Bake.path(String(n))
			if ResourceLoader.exists(p):
				ResourceLoader.load_threaded_request(p)
				_requests.append(n)


func _process(_d: float) -> void:
	if state != "loading":
		return
	var pending: int = 0
	for n in _requests:
		if _loaded.has(n):
			continue
		var p: String = Bake.path(String(n))
		var st: int = ResourceLoader.load_threaded_get_status(p)
		if st == ResourceLoader.THREAD_LOAD_LOADED:
			_loaded[n] = ResourceLoader.load_threaded_get(p)
		elif st == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			pending += 1
	if pending == 0:
		_load_ms = (Time.get_ticks_usec() - _t0) / 1000.0
		_place_all()
		state = "ready"


func _place_all() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var half := Vector2(area.x * 0.5, area.y * 0.5)
	# Plots: voxels front left, smooth front right, lofted back left, oaks back right; a cross of
	# aisles between them.
	var centres := [Vector2(-half.x * 0.5, half.y * 0.5), Vector2(half.x * 0.5, half.y * 0.5), Vector2(-half.x * 0.5, -half.y * 0.5), Vector2(half.x * 0.5, -half.y * 0.5)]
	var size := Vector2(half.x - 4.0, half.y - 4.0)
	for pi in PLOTS.size():
		var plot: Dictionary = PLOTS[pi]
		var root := Node4D.new()
		root.name = "Plot_" + String(plot["key"])
		add_child(root)
		var c: Vector2 = centres[pi]
		root.position = Vector4(c.x, 0.0, c.y, 0.0)
		var shapes: Array = plot["shapes"]
		var info: Dictionary = {"key": plot["key"], "name": plot["name"], "trees": 0, "drawn": 0, "held": 0, "shapes": 0, "cell": plot["cell"], "leaves": 0}
		var mats: Dictionary = {}
		var held: Dictionary = {}
		var oak: bool = String(plot["key"]) == "oak"
		var count: int = trees_per_plot if not oak else maxi(3, trees_per_plot - 3)
		# A jittered grid over the plot, at several W.
		var cols: int = int(ceil(sqrt(float(count))))
		for k in count:
			var si: int = k % shapes.size()
			var mesh: Resource = _loaded.get(shapes[si])
			var sk: Resource = _loaded.get((plot["skel"] as Array)[si])
			if mesh == null or sk == null:
				continue
			var gx: float = (float(k % cols) + 0.5) / float(cols) - 0.5
			var gz: float = (float(k / cols) + 0.5) / float(cols) - 0.5
			var at := Vector2(gx * size.x + rng.randf_range(-0.9, 0.9), gz * size.y + rng.randf_range(-0.9, 0.9))
			var w: float = rng.randf_range(-0.3, 0.3)
			if k % 3 == 2:
				w = signf(rng.randf() - 0.5) * rng.randf_range(minf(0.5, w_spread), w_spread)
			var tree := Node4D.new()
			tree.name = "Tree%d" % k
			root.add_child(tree)
			var summ: Dictionary = sk.call("summary")
			var s: float = (oak_height if oak else tree_height) / maxf(float(summ["height"]), 0.5) * rng.randf_range(0.85, 1.15)
			tree.position = Vector4(at.x, 0.0, at.y, w)
			tree.basis = Basis4D.from_zx(rng.randf() * TAU)
			tree.scale = Vector4(s, s, s, s)
			if not mats.has(si):
				mats[si] = Pivots.texture(sk)
			var mi := MeshInstance4D.new()
			mi.mesh = mesh
			var mat: TetraMaterial4D = Style.tree_material(sk, float(summ["height"]), oak, mats[si])
			mi.material_override = mat
			tree.add_child(mi)
			var wind: Node = Wind.of(get_tree())
			if wind != null:
				wind.call("register", Style.shader_of(mat), tree)
			var tets: int = (mesh as TetraMesh4D).get_simplex_cell_vertex_indices().size() / 4
			info["drawn"] = int(info["drawn"]) + tets
			held[shapes[si]] = tets
			if plot.has("extra"):
				var ex: Resource = _loaded.get((plot["extra"] as Array)[si])
				if ex != null:
					var mi2 := MeshInstance4D.new()
					mi2.mesh = ex
					mi2.material_override = mat
					tree.add_child(mi2)
					var et: int = (ex as TetraMesh4D).get_simplex_cell_vertex_indices().size() / 4
					info["drawn"] = int(info["drawn"]) + et
					held[(plot["extra"] as Array)[si]] = et
			if oak:
				var lf := Node4D.new()
				lf.name = "Leaves"
				lf.set_script(Leaves)
				Species.oak_leaves(lf, true)
				tree.add_child(lf)
				if _leaf_src.has(si):
					lf.call("share_from", _leaf_src[si])
				else:
					lf.call("grow_leaves", sk, 20 + si)
					_leaf_src[si] = lf
				info["leaves"] = int(info["leaves"]) + int(lf.get("count"))
			info["trees"] = int(info["trees"]) + 1
		var h: int = 0
		for n in held:
			h += int(held[n])
		info["held"] = h
		info["shapes"] = held.size()
		_plots.append(info)
		var sign := Node4D.new()
		sign.name = "Sign"
		sign.set_script(Sign)
		root.add_child(sign)
		# The sign at the plot's corner nearest the aisles' crossing, facing it.
		var to_mid := Vector2(-signf(c.x), -signf(c.y))
		sign.position = Vector4(to_mid.x * (size.x * 0.5 + 0.6), 0.0, to_mid.y * (size.y * 0.5 + 0.6), 0.0)
		sign.basis = Basis4D.from_zx(atan2(to_mid.x, to_mid.y))
		sign.call("show_info", info, _load_ms)
	_place_ana()
	print("GROVE placed in %.0f ms after %.0f ms of loading: %s" % [(Time.get_ticks_usec() - _t0) / 1000.0 - _load_ms, _load_ms, str(_plots)])


## Three lofted trees that stand only ana of you (W +2.2), in the lofted plot, where the grove's
## follow route climbs to (paths/grove.tres "AnaGrove"): from W 0 there is nothing there; walk ana
## (E) and they come in.
func _place_ana() -> void:
	var root := Node4D.new()
	root.name = "Plot_ana"
	add_child(root)
	root.position = Vector4(-9.0, 0.0, -7.0, 2.2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for k in 3:
		var mesh: Resource = _loaded.get("grove_lf_%d" % k)
		var clumps: Resource = _loaded.get("grove_lfc_%d" % k)
		var sk: Resource = _loaded.get("grove_sk_%d_skeleton" % k)
		if mesh == null or sk == null:
			continue
		var tree := Node4D.new()
		tree.name = "AnaTree%d" % k
		root.add_child(tree)
		var a: float = TAU * float(k) / 3.0 + 0.4
		var summ: Dictionary = sk.call("summary")
		var s: float = tree_height / maxf(float(summ["height"]), 0.5) * rng.randf_range(0.9, 1.1)
		tree.position = Vector4(cos(a) * 2.6, 0.0, sin(a) * 2.6, rng.randf_range(-0.2, 0.2))
		tree.basis = Basis4D.from_zx(rng.randf() * TAU)
		tree.scale = Vector4(s, s, s, s)
		var mat: TetraMaterial4D = Style.tree_material(sk, float(summ["height"]))
		for m in [mesh, clumps]:
			if m == null:
				continue
			var mi := MeshInstance4D.new()
			mi.mesh = m
			mi.material_override = mat
			tree.add_child(mi)
		var wind: Node = Wind.of(get_tree())
		if wind != null:
			wind.call("register", Style.shader_of(mat), tree)


## Places every tree again (the dev panel's GROVE rows: more trees, a wider spread through W).
func replace_trees() -> void:
	if state != "ready":
		return
	for c in get_children():
		if String(c.name).begins_with("Plot_"):
			c.queue_free()
	_plots.clear()
	_leaf_src.clear()
	(func() -> void: _place_all()).call_deferred()


## The plots' numbers (the room's research wall and the runners read them).
func plots() -> Array:
	return _plots


func load_ms() -> float:
	return _load_ms
