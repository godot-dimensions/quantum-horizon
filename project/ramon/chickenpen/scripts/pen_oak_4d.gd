extends Node4D

## The Arboretum's big oak, beside Trym's shed (6 Oct 2026, Ramon: "add the big oak tree from
## arberetum with the leaves next to tryms house").
##
## THE ARBORETUM'S OWN OAK, NOT A COPY: its baked wood and skeleton (Arboretum/baked/oak_*), its
## material, its leaves grown and placed by the graphics card in your slice every frame
## (Arboretum/botany/leaf_field_4d.gd, the grass's route), at the height the room shows it. Rebake
## the oak there and this one follows. It needs a wind to move: the Arboretum's (botany/wind_4d.gd),
## one made here if the scene has none.
##
## Solid only at the trunk: physics here is boxes, and the crown is leaves nothing can touch.

const Bake := preload("res://ramon/Arboretum/botany/bake_store.gd")
const Style := preload("res://ramon/Arboretum/botany/botany_style.gd")
const Species := preload("res://ramon/Arboretum/botany/tree_species.gd")
const Leaves := preload("res://ramon/Arboretum/botany/leaf_field_4d.gd")
const Wind := preload("res://ramon/Arboretum/botany/wind_4d.gd")

## How tall it stands (the Arboretum shows its oak at 7.4 m).
@export_range(3.0, 14.0, 0.1, "suffix:m") var height: float = 7.4
@export var leaf_seed: int = 5
## The wind made for it when the scene has none: a field breeze, gentler than the room's.
@export_range(0.0, 20.0, 0.1) var wind_speed: float = 3.5
@export var wind_direction: Vector4 = Vector4(1.0, 0.0, 0.3, 0.25)
## The trunk's box: how wide (x, z and W) and how tall.
@export var trunk: Vector2 = Vector2(0.9, 2.6)

var leaves: Node4D


func _ready() -> void:
	var sk: Resource = Bake.load_res("oak_skeleton")
	var wood: Resource = Bake.load_res("oak_wood")
	if sk == null or wood == null:
		push_warning("PenOak: the Arboretum's oak is not baked (Arboretum/baked/oak_skeleton, oak_wood); no tree.")
		return
	var wind: Node = Wind.of(get_tree())
	if wind == null:
		wind = Node.new()
		wind.name = "OakWind"
		wind.set_script(Wind)
		wind.set("speed", wind_speed)
		wind.set("direction", wind_direction)
		add_child(wind)
	var tree := Node4D.new()
	tree.name = "Tree"
	add_child(tree)
	var summ: Dictionary = sk.call("summary")
	var h: float = maxf(float(summ["height"]), 0.5)
	var s: float = height / h
	tree.scale = Vector4(s, s, s, s)
	var material: TetraMaterial4D = Style.tree_material(sk, h, true)
	wind.call("register", Style.shader_of(material), tree)
	var mi := MeshInstance4D.new()
	mi.name = "Wood"
	mi.mesh = wood as Mesh4D
	mi.material_override = material
	tree.add_child(mi)
	leaves = Node4D.new()
	leaves.name = "Leaves"
	leaves.set_script(Leaves)
	Species.oak_leaves(leaves)
	tree.add_child(leaves)
	leaves.call("grow_leaves", sk, leaf_seed)
	var body := StaticBody4D.new()
	body.name = "Trunk"
	var holder := CollisionShape4D.new()
	var box := BoxShape4D.new()
	box.size = Vector4(trunk.x, trunk.y, trunk.x, trunk.x)
	holder.shape = box
	holder.position = Vector4(0.0, trunk.y * 0.5, 0.0, 0.0)
	body.add_child(holder)
	add_child(body)
