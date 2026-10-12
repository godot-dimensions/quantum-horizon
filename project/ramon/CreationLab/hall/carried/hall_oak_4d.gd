@tool
extends Node4D

## CARRIED into the Creature Lab's hall (9 Oct 2026) from chickenpen/scripts/pen_oak_4d.gd, unchanged below:
## the pen's oak in its bakes, for the trees on low pedestals between the stations. Never edit the pen's own.
##

## An oak for the pen, the Arboretum's (6 Oct 2026, Ramon: "add the big oak tree from arberetum with
## the leaves next to tryms house"), in any of four bakes, to be copied about the pen.
##
## THE ARBORETUM'S OWN OAK, NOT A COPY: its baked wood and skeleton (Arboretum/baked/), its material,
## its leaves grown and placed by the graphics card in your slice every frame
## (Arboretum/botany/leaf_field_4d.gd, the grass's route). Rebake there and this one follows. It
## needs a wind to move: the Arboretum's (botany/wind_4d.gd), one made here if the scene has none.
##
## LIGHT OAKS FOR PLACING ABOUT (Ramon, 6 Oct: "heavily optimised so i can start placing them in the
## pen without problems. this level of fidelity was great for the arboretum, but not so much for in the
## pen"). [member bake] picks the tree: "oak", the Arboretum's (2,400 branch nodes, 132,000
## tetrahedra, 44 leaves a node); "oak_lite1" to "oak_lite3", the same oak grown with coarser steps and
## lofted with fewer sides (scripts/_bake_oak_lite_runner.gd: 68,000, 21,000 and 7,700 tetrahedra),
## with fewer, larger leaves. Copies of one bake share one wood mesh and one set of leaves.
##
## FOR MANY (6 Oct, layout B: "make sure trees are optimized to handle the placement of many. and make
## then dance in the wind a bit"). Four tiers of bake (LEAVES): the light oaks for the big trees, a
## lighter one for the medium, bushes. Copies of one bake and leaf seed share one set of leaves.
## Drawn only when in front of the camera too ([member view_cull]): the renderer cuts every mesh it
## draws whether it is on screen or not. Stood on the ground under it when the game starts
## ([member snap_to_ground]: on a hill or a mound).
##
## DRAWN ONLY WHEN YOUR SLICE CUTS IT ([member slice_cull]). The cross-section renderer cuts every
## tetrahedron of every drawn mesh each frame, whether the cut finds anything or not, so a tree stood
## three metres ana cost as much as one in front of you. Before each render the tree's box is tested
## against the camera's slice (the hyperplane through the camera across its W axis, turned slices
## too) and the tree is drawn only if the slice passes through it. Volume view (Combined, Projected)
## draws everything, as it shows what lies off the slice.
##
## In the editor the wood alone is built, so it can be placed by eye; nothing built is saved (no owner).
## Solid only at the trunk: physics here is boxes, and the crown is leaves nothing can touch.

const Bake := preload("res://ramon/Arboretum/botany/bake_store.gd")
const Style := preload("res://ramon/Arboretum/botany/botany_style.gd")
const Species := preload("res://ramon/Arboretum/botany/tree_species.gd")
const Leaves := preload("res://ramon/Arboretum/botany/leaf_field_4d.gd")
const Wind := preload("res://ramon/Arboretum/botany/wind_4d.gd")
## Every oak, for the dev look (it turns their leaves off) and anything else that wants them all.
const GROUP := &"pen_oak"
## Per bake: leaves a node and their size (fewer, larger leaves as the tree gets coarser, so the crown
## still reads full).
const LEAVES := {
	"oak": [44, 0.22],
	"oak_lite1": [14, 0.24],
	"oak_lite2": [22, 0.28],
	"oak_lite3": [24, 0.30],
	"oak_lite4": [16, 0.28],
	"bush_1": [22, 0.24],
	"bush_2": [22, 0.24],
	"bush_3": [22, 0.24],
}

## Which oak (see the header): the Arboretum's, or a lighter bake of it.
@export_enum("oak", "oak_lite1", "oak_lite2", "oak_lite3", "oak_lite4", "bush_1", "bush_2", "bush_3") var bake: String = "oak":
	set(v):
		bake = v
		if is_node_ready():
			_build()
## How tall it stands (the Arboretum shows its oak at 7.4 m).
@export_range(3.0, 14.0, 0.1, "suffix:m") var height: float = 7.4:
	set(v):
		height = v
		if is_node_ready():
			_build()
## Leaves a node; -1 for the bake's own (LEAVES).
@export_range(-1, 60, 1) var leaves_per_node: int = -1
@export var leaf_seed: int = 5
## ROUND IN W (Ramon, 7 Oct: "more trees have to be placed in the W ... now they just dissapear instant
## when you rotate the slice"). Every bake is about half as deep in W as it is wide (the light oak's
## crown 6.65 m across in x, 3.68 m in W, measured with PenLayout/scratch/tests/probe_oak_w_runner.gd),
## so a turned slice left it twice as fast as its width suggests, and all at once. Stretched in W by
## this, the crown is as round in W as across, and as the slice moves off it it draws in and goes.
@export_range(1.0, 3.0, 0.05) var w_stretch: float = 1.8:
	set(v):
		w_stretch = v
		if is_node_ready():
			_build()
## Drawn only while the slice passes through it (see the header).
@export var slice_cull: bool = true
## Drawn only while it is in front of the camera and within its view (see the header).
@export var view_cull: bool = true
## At the start of play, stood on whatever static ground is under its trunk.
@export var snap_to_ground: bool = true
## The wind made for it when the scene has none: a field breeze, gentler than the room's.
@export_range(0.0, 20.0, 0.1) var wind_speed: float = 3.5
@export var wind_direction: Vector4 = Vector4(1.0, 0.0, 0.3, 0.25)
## The trunk's box: how wide (x, z and W) and how tall.
@export var trunk: Vector2 = Vector2(0.9, 2.6)
## RED (Ramon, 7 Oct: "make the tree on the tower red in artlook"): the leaves in their autumn, its two
## colours made reds. The leaf shader's autumn alone is rust and orange, and leaves part green. Only the
## art has leaves; in the dev look the tree is its blue block.
@export var red: bool = false:
	set(v):
		red = v
		_redden()
@export var red_a: Color = Color(0.74, 0.13, 0.09)
@export var red_b: Color = Color(0.52, 0.06, 0.05)

## The first oak's leaves for each bake, seed and density: later copies share them.
static var _leaf_sources: Dictionary = {}

var leaves: Node4D
var _tree: Node4D
## Whether the projection draws the tree (_projects): -1 not looked yet.
var _projected: int = -1
var _body: StaticBody4D
## The tree's box in its own frame (wood plus a margin for the leaves): centre and half size.
var _centre := Vector4.ZERO
var _half := Vector4.ZERO
## Culled by whoever holds the whole planting (World/Trees, pen_trees_4d.gd: one loop a frame for
## every tree instead of a call each), not by itself.
var managed: bool = false


func _ready() -> void:
	add_to_group(GROUP)
	_build()


func _enter_tree() -> void:
	if not Engine.is_editor_hint() and not managed and not RenderingServer4D.pre_render.is_connected(_on_pre_render):
		RenderingServer4D.pre_render.connect(_on_pre_render)


## Culled by someone else from now on (true), or by itself again.
func set_managed(on: bool) -> void:
	managed = on
	var hooked: bool = RenderingServer4D.pre_render.is_connected(_on_pre_render)
	if on and hooked:
		RenderingServer4D.pre_render.disconnect(_on_pre_render)
	elif not on and not hooked and is_inside_tree() and not Engine.is_editor_hint():
		RenderingServer4D.pre_render.connect(_on_pre_render)


func _exit_tree() -> void:
	if RenderingServer4D.pre_render.is_connected(_on_pre_render):
		RenderingServer4D.pre_render.disconnect(_on_pre_render)


func _build() -> void:
	for old in [_tree, _body]:
		if old != null and is_instance_valid(old):
			remove_child(old)
			old.queue_free()
	_tree = null
	_body = null
	leaves = null
	var sk: Resource = Bake.load_res(bake + "_skeleton")
	var wood: Resource = Bake.load_res(bake + "_wood")
	if sk == null or wood == null:
		push_warning("PenOak: %s is not baked (Arboretum/baked/%s_skeleton, %s_wood); no tree. Lite oaks: scripts/_bake_oak_lite_runner.gd." % [bake, bake, bake])
		return
	var runtime: bool = not Engine.is_editor_hint()
	_tree = Node4D.new()
	_tree.name = "Tree"
	_projected = -1
	add_child(_tree)
	var summ: Dictionary = sk.call("summary")
	var h: float = maxf(float(summ["height"]), 0.5)
	var s: float = height / h
	_tree.scale = Vector4(s, s, s, s * w_stretch)
	var material: TetraMaterial4D = Style.tree_material(sk, h, true)
	var mi := MeshInstance4D.new()
	mi.name = "Wood"
	mi.mesh = wood as Mesh4D
	mi.material_override = material
	_tree.add_child(mi)
	var r: PackedVector4Array = mi.get_rect_bounds_local()
	# A metre round the wood for the leaves (they reach 0.6 m further through W, and out past the twigs).
	_half = r[1] * 0.5 + Vector4.ONE / s
	_centre = r[0] + r[1] * 0.5
	if not runtime:
		return
	var wind: Node = Wind.of(get_tree())
	if wind == null:
		wind = get_node_or_null("OakWind")
	if wind == null:
		wind = Node.new()
		wind.name = "OakWind"
		wind.set_script(Wind)
		wind.set("speed", wind_speed)
		wind.set("direction", wind_direction)
		add_child(wind)
	wind.call("register", Style.shader_of(material), _tree)
	leaves = Node4D.new()
	leaves.name = "Leaves"
	leaves.set_script(Leaves)
	Species.oak_leaves(leaves)
	var own: Array = LEAVES.get(bake, LEAVES["oak"])
	var per: int = leaves_per_node if leaves_per_node >= 0 else int(own[0])
	leaves.set("per_node", per)
	leaves.set("leaf_size", float(own[1]))
	_tree.add_child(leaves)
	var key: String = "%s:%d:%d" % [bake, leaf_seed, per]
	var first: Variant = _leaf_sources.get(key)
	if first != null and is_instance_valid(first) and int((first as Node).get("count")) > 0:
		leaves.call("share_from", first)
	else:
		leaves.call("grow_leaves", sk, leaf_seed)
		_leaf_sources[key] = leaves
	_redden()
	_body = StaticBody4D.new()
	_body.name = "Trunk"
	var holder := CollisionShape4D.new()
	var box := BoxShape4D.new()
	box.size = Vector4(trunk.x, trunk.y, trunk.x, trunk.x)
	holder.shape = box
	holder.position = Vector4(0.0, trunk.y * 0.5, 0.0, 0.0)
	_body.add_child(holder)
	add_child(_body)
	if snap_to_ground:
		_snap.call_deferred()


## The leaves red, or back to their summer (every leaf its own material: share_from copies it).
func _redden() -> void:
	var m: ShaderMaterial = leaves.get("material") if leaves != null else null
	if m == null:
		return
	# Season 1 is full autumn for most leaves only (the shader holds back up to a third by each leaf's
	# seed, mixed toward its summer green), so the summer colours go red too, kept to be put back.
	var keys: Array[String] = ["leaf_color", "leaf_alt", "leaf_dark", "autumn_a", "autumn_b"]
	if red and not m.has_meta(&"summer"):
		var summer: Dictionary = {}
		for k in keys:
			summer[k] = m.get_shader_parameter(k)
		m.set_meta(&"summer", summer)
	var reds: Dictionary = {"leaf_color": red_a, "leaf_alt": red_a.lightened(0.12), "leaf_dark": red_b.darkened(0.35),
		"autumn_a": red_a, "autumn_b": red_b}
	var back: Dictionary = m.get_meta(&"summer", {})
	for k in keys:
		var v: Variant = reds[k] if red else back.get(k)
		if v != null:
			m.set_shader_parameter(k, v)
	m.set_shader_parameter("season", 1.0 if red else 0.0)


## THE CROWN'S BOX, in this node's frame: [lo, hi] over where the leaves are, or [] before they are
## (Ramon, 7 Oct: "SCALE BLUE TREEBLOCKS a bit larger upward so they match the artlook more"). The dev
## look's block was sized from the wood alone, the leaves being off by then, and the leaves reach out
## and up past the twigs: the blue crowns sat low and squat. The leaf field puts its leaves on the
## skeleton's outer nodes (twigs up to leafy_twigs), out to spread and a little along the shoot, each a
## leaf across, so their box is those nodes' box grown by that much, at the tree's scale.
func crown_box() -> Array:
	var sk: Resource = Bake.load_res(bake + "_skeleton")
	if sk == null or _tree == null or leaves == null:
		return []
	var positions: PackedVector4Array = sk.get("positions")
	var twigs: PackedInt32Array = sk.get("twigs")
	var leafy: int = int(leaves.get("leafy_twigs"))
	var reach: float = float(leaves.get("spread")) * 1.25 + float(leaves.get("leaf_size"))
	var lo := Vector4(INF, INF, INF, INF)
	var hi := -lo
	for i in positions.size():
		if twigs[i] <= leafy:
			lo = lo.min(positions[i])
			hi = hi.max(positions[i])
	if lo.x > hi.x:
		return []
	var s: Vector4 = _tree.scale
	return [_tree.position + (lo - Vector4.ONE * reach) * s, _tree.position + (hi + Vector4.ONE * reach) * s]


## Down onto the static ground under the trunk (a hill, a mound), once physics is up.
func _snap() -> void:
	await get_tree().physics_frame
	var params := RaycastParameters4D.new()
	params.global_ray_origin = global_position + Vector4(0.0, 30.0, 0.0, 0.0)
	params.global_ray_direction = Vector4(0.0, -1.0, 0.0, 0.0)
	params.max_distance = 60.0
	var skip: Array[Node4D] = [self]
	if _body != null:
		skip.append(_body)
	params.set_exclude_nodes(skip)
	for i in 6:
		var hit: Dictionary = PhysicsServer4D.raycast_physics_objects(params)
		if hit.is_empty() or not bool(hit.get("hit", false)) or not hit.has("global_point"):
			return
		var body: Object = hit.get("body")
		if body is StaticBody4D:
			var p: Vector4 = global_position
			global_position = Vector4(p.x, (hit["global_point"] as Vector4).y, p.z, p.w)
			return
		if not (body is Node4D):
			return
		skip.append(body as Node4D)
		params.set_exclude_nodes(skip)


## Before each render: drawn if the camera's slice passes through the tree's box, or in volume view.
func _on_pre_render(camera: Camera4D, viewport: Viewport, engine: RenderingEngine4D) -> void:
	cull(camera, viewport, engine)


## Shown or hidden for this render (the planting's loop calls it for a managed tree).
func cull(camera: Camera4D, viewport: Viewport, engine: RenderingEngine4D) -> void:
	if _tree == null or viewport != get_viewport():
		return
	var on: bool = true
	# Under the projection a tree off the slice is still wanted, as a ghost, but only if the projection draws it
	# (the W Exploder's copies are left out of it, and were drawn whole for nothing; 7 Oct).
	var ghost: bool = engine != null and engine.get_friendly_name() != "Cross-section" and _projects()
	if slice_cull and camera != null and not ghost:
		on = is_cut_by(camera)
	if on and view_cull and camera != null:
		on = is_in_view(camera, viewport)
	if _tree.visible != on:
		_tree.visible = on


## Whether the projection draws this tree (its first mesh's allow_projection), looked up once a tree: cull()
## asks every frame, for hundreds of trees.
func _projects() -> bool:
	if _projected < 0:
		_projected = 0
		for mi in _tree.find_children("*", "MeshInstance4D", true, false):
			_projected = 1 if (mi as MeshInstance4D).allow_projection else 0
			break
	return _projected == 1


## Whether the tree's box is in front of [param camera] and within its view, with its whole size as
## margin: a ball round the box, tested against the view's four sides in the camera's own frame.
func is_in_view(camera: Camera4D, viewport: Viewport) -> bool:
	if _tree == null:
		return false
	var b: Projection = _tree.global_basis
	var c: Vector4 = _tree.global_position + b * _centre
	var r: float = (b * _half).length()
	var cb: Projection = camera.global_basis
	var d: Vector4 = c - camera.global_position
	var vx: float = d.dot(cb.x.normalized())
	var vy: float = d.dot(cb.y.normalized())
	var depth: float = -d.dot(cb.z.normalized())
	if depth < -r:
		return false
	var fov: Variant = camera.get("field_of_view_4d")
	var tv: float = tan(float(fov) * 0.5) if fov != null else 0.8
	var size: Vector2 = viewport.get_visible_rect().size if viewport != null else Vector2(16, 9)
	var th: float = tv * (size.x / maxf(size.y, 1.0))
	var slack: float = r * 1.5
	return absf(vx) <= maxf(depth, 0.0) * th + slack and absf(vy) <= maxf(depth, 0.0) * tv + slack


## Whether [param camera]'s slice (through it, across its W axis) passes through the tree's box.
func is_cut_by(camera: Node4D) -> bool:
	if _tree == null:
		return false
	var n: Vector4 = camera.global_basis.w.normalized()
	var b: Projection = _tree.global_basis
	var c: Vector4 = _tree.global_position + b * _centre
	var reach: float = absf(b.x.dot(n)) * _half.x + absf(b.y.dot(n)) * _half.y + absf(b.z.dot(n)) * _half.z + absf(b.w.dot(n)) * _half.w
	return absf((c - camera.global_position).dot(n)) <= reach
