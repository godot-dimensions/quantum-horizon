extends SceneTree
## The feet deform oddly. Vertices below the last IK ball should be carried RIGIDLY by
## the shank - full attachment weight, full shank blend. Are they?
var _root: Node
var _f := 0
func _initialize() -> void:
	_root = load("res://ramon/Model/animation_test.tscn").instantiate()
	root.add_child(_root); current_scene = _root
func _process(_d) -> bool:
	_f += 1
	if _f < 40: return false
	var walker: Node = null
	var stack: Array = [_root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n.get_script() != null and n.name.findn("walk") >= 0: walker = n
		for c in n.get_children(): stack.append(c)
	var legs: Array = walker.get("_legs")
	var rest: PackedVector4Array = walker.get("_rest_verts")
	var idx: PackedInt32Array = walker.get("_skin_index")
	var w: PackedFloat32Array = walker.get("_skin_weight")
	var sh: PackedFloat32Array = walker.get("_skin_shank")
	var lg: PackedInt32Array = walker.get("_skin_leg")
	var foot_y: float = (legs[0]["rest_foot"] as Vector4).y
	print("foot ball at y %.3f" % foot_y)
	# Everything below the foot ball, bound or not.
	var below := 0
	var below_bound := 0
	var partial := 0
	var weakest := 1.0
	for i in rest.size():
		if rest[i].y > foot_y: continue
		below += 1
		var pos := idx.find(i)
		if pos < 0: continue
		below_bound += 1
		if w[pos] < 0.95 or sh[pos] < 0.95:
			partial += 1
			weakest = minf(weakest, minf(w[pos], sh[pos]))
	print("vertices below the foot ball: %d" % below)
	print("  bound at all:            %d" % below_bound)
	print("  bound only PARTIALLY:    %d (weakest weight %.2f)" % [partial, weakest])
	print("  unbound (will stay put): %d" % (below - below_bound))
	return true
