extends SceneTree

## How far above the coop does a thrown cat end up sitting?
##
## The same trap the crate had: perch_top is measured from the COOP'S OWN ORIGIN, not from
## the floor, and reading it as a world height floats the cat by however high the coop's
## origin already is. Measured here from the coop's real roof and the cat's real lowest
## point, so the number is a correction rather than a guess.

var _root: Node
var _f := 0


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/playable_world.tscn").instantiate()
	root.add_child(_root); current_scene = _root


## The highest solid surface of a built prop, from its own meshes.
func _roof(of: Node) -> float:
	var top: float = -1e9
	for child in of.get_children():
		if child is MeshInstance4D and (child as MeshInstance4D).mesh is BoxTetraMesh4D:
			var m: MeshInstance4D = child
			top = maxf(top, m.global_position.y + (m.mesh as BoxTetraMesh4D).size.y * 0.5)
		top = maxf(top, _roof(child))
	return top


func _lowest(of: Node4D) -> float:
	var low: float = 1e9
	for child in of.get_children():
		if child is MeshInstance4D:
			low = minf(low, (child as MeshInstance4D).global_position.y)
		low = minf(low, _lowest(child as Node4D) if child is Node4D else 1e9)
	return low


func _process(_d) -> bool:
	_f += 1
	if _f < 70: return false
	var coop: Node4D = _root.get_node("Pen/Coop")
	var cat: Node4D = _root.get_node("World/Cat")
	var roof: float = _roof(coop)
	print("\n   the coop's origin sits at y %.2f, its roof at y %.2f" % [coop.global_position.y, roof])
	print("   perch_top is %.2f, so the cat is put at y %.2f"
		% [cat.get("perch_top"), coop.global_position.y + float(cat.get("perch_top"))])
	# Where the cat's feet are relative to its own origin, from its rest pose.
	var belly: float = _lowest(cat) - cat.global_position.y
	print("   the cat's lowest part is %.2f below its own origin" % -belly)
	var want: float = roof - coop.global_position.y - belly
	print("\n   perch_top should be %.2f to stand it on the roof" % want)
	quit(0)
	return true
