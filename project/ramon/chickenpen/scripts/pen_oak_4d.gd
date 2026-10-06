@tool
extends Node4D

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
	"oak_lite3": [7, 0.32],
}

## Which oak (see the header): the Arboretum's, or a lighter bake of it.
@export_enum("oak", "oak_lite1", "oak_lite2", "oak_lite3") var bake: String = "oak":
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
## Drawn only while the slice passes through it (see the header).
@export var slice_cull: bool = true
## The wind made for it when the scene has none: a field breeze, gentler than the room's.
@export_range(0.0, 20.0, 0.1) var wind_speed: float = 3.5
@export var wind_direction: Vector4 = Vector4(1.0, 0.0, 0.3, 0.25)
## The trunk's box: how wide (x, z and W) and how tall.
@export var trunk: Vector2 = Vector2(0.9, 2.6)

## The first oak's leaves for each bake, seed and density: later copies share them.
static var _leaf_sources: Dictionary = {}

var leaves: Node4D
var _tree: Node4D
var _body: StaticBody4D
## The tree's box in its own frame (wood plus a margin for the leaves): centre and half size.
var _centre := Vector4.ZERO
var _half := Vector4.ZERO


func _ready() -> void:
	add_to_group(GROUP)
	_build()


func _enter_tree() -> void:
	if not Engine.is_editor_hint() and not RenderingServer4D.pre_render.is_connected(_on_pre_render):
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
	add_child(_tree)
	var summ: Dictionary = sk.call("summary")
	var h: float = maxf(float(summ["height"]), 0.5)
	var s: float = height / h
	_tree.scale = Vector4(s, s, s, s)
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
	var key: String = "%s:%d:%d:%.2f" % [bake, leaf_seed, per, height]
	var first: Variant = _leaf_sources.get(key)
	if first != null and is_instance_valid(first) and int((first as Node).get("count")) > 0:
		leaves.call("share_from", first)
	else:
		leaves.call("grow_leaves", sk, leaf_seed)
		_leaf_sources[key] = leaves
	_body = StaticBody4D.new()
	_body.name = "Trunk"
	var holder := CollisionShape4D.new()
	var box := BoxShape4D.new()
	box.size = Vector4(trunk.x, trunk.y, trunk.x, trunk.x)
	holder.shape = box
	holder.position = Vector4(0.0, trunk.y * 0.5, 0.0, 0.0)
	_body.add_child(holder)
	add_child(_body)


## Before each render: drawn if the camera's slice passes through the tree's box, or in volume view.
func _on_pre_render(camera: Camera4D, viewport: Viewport, engine: RenderingEngine4D) -> void:
	if _tree == null or viewport != get_viewport():
		return
	var on: bool = true
	if slice_cull and camera != null and (engine == null or engine.get_friendly_name() == "Cross-section"):
		on = is_cut_by(camera)
	if _tree.visible != on:
		_tree.visible = on


## Whether [param camera]'s slice (through it, across its W axis) passes through the tree's box.
func is_cut_by(camera: Node4D) -> bool:
	if _tree == null:
		return false
	var n: Vector4 = camera.global_basis.w.normalized()
	var b: Projection = _tree.global_basis
	var c: Vector4 = _tree.global_position + b * _centre
	var reach: float = absf(b.x.dot(n)) * _half.x + absf(b.y.dot(n)) * _half.y + absf(b.z.dot(n)) * _half.z + absf(b.w.dot(n)) * _half.w
	return absf((c - camera.global_position).dot(n)) <= reach
