extends Node

## BOTANY LAB, THE FLOWER ROOM: what its floating panel by the door says (section 9, steps 26 and 67): the
## live numbers on its face (flower_room_4d.gd stats), and on E how a 4D flower is built, why the flowers
## change as they turn while the pockets do not, and the butterflies.
##
## NO class_name (engine_gotchas.md).

const Bake := preload("res://ramon/Arboretum/botany/bake_store.gd")

## The room (flower_room_4d.gd), from this node.
@export var room: NodePath = ^"../.."


func _stats() -> Dictionary:
	var r: Node = get_node_or_null(room)
	return (r.get("stats") as Dictionary) if r != null else {}


func face() -> Array:
	var st: Dictionary = _stats()
	var pl: Dictionary = st.get("plants", {})
	var cl: Dictionary = st.get("climbers", {})
	var sp: Dictionary = st.get("sprigs", {})
	return [["Flowers lofted in 4D", "%d in %d pockets, %d on the vines" % [int(pl.get("plants", 0)), int(pl.get("pockets", 0)), int(cl.get("blooms", 0))]],
		["Tetrahedra", Bake.thousands(int(pl.get("tets", 0)) + int(cl.get("tets", 0)))],
		["Leaves, blades and florets", Bake.thousands(int(sp.get("pieces", 0))) + " on the GPU"]]


func panel_pages() -> Array:
	return [{"title": "A 4D flower", "kicker": "THE FLOWER ROOM  ·  HOW THEY ARE BUILT",
			"text": "Every flower here is lofted in 4D: its stem a tube round in all three directions across it, each petal a thin blade, flat across its face and round through W. Its petals fill a sphere of directions, not a circle: a ring you can see, and more through W."},
		{"title": "The turn", "kicker": "THE FLOWER ROOM  ·  WHY THE FLOWERS CHANGE",
			"text": "A right drag turns every flower through W about its own stem. Petals you could not see come round into your slice while others leave it. The pockets and the walls do not turn, so only the flowers change."},
		{"title": "Butterflies", "kicker": "THE FLOWER ROOM  ·  EIGHT SPECIES",
			"text": "Monarch, blue morpho, swallowtail, peacock, small white, painted lady, red admiral and brimstone, each a true 4D loft: a body and two pairs of wings hinged on it, their patterns painted on. They land on the flowers and bask; a gust lifts them off."}]
