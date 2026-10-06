extends SceneTree

## How much of your own character survives a slice rotation?
##
## In third person you are looking at yourself the whole time, so you see your own body
## cut. How badly depends on one number: the avatar's extent through W against how far
## the slice's w drifts across the avatar's own width. A part whose w range misses the
## slice entirely is simply not drawn.

const SliceAngles := preload("res://ramon/chickenpen/scripts/slice_angles_4d.gd")

var _root: Node
var _f := 0


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/playable_world.tscn").instantiate()
	root.add_child(_root); current_scene = _root


## Every block of the avatar, and whether the slice passes through it.
func _survey(node: Node, player: Node4D, rig: Node4D, out: Array) -> void:
	if node is MeshInstance4D and (node as MeshInstance4D).mesh is BoxTetraMesh4D:
		var m: MeshInstance4D = node
		var half_w: float = ((m.mesh as BoxTetraMesh4D).size.w) * 0.5
		var n: Vector4 = rig.global_basis.w
		# How far this block's centre is off the slice, against how thick it is through W.
		var off: float = (m.global_position - player.global_position).dot(n)
		out.append([m.name, off, half_w * absf(n.w)])
	for child in node.get_children():
		_survey(child, player, rig, out)


func _report(player: Node4D, rig: Node4D, label: String) -> void:
	var blocks: Array = []
	_survey(_root.get_node("Player/Avatar"), player, rig, blocks)
	var gone: Array = []
	for b in blocks:
		if absf(b[1]) > b[2]:
			gone.append(b[0])
	print("   %-22s %2d of %2d blocks not in your slice%s"
		% [label, gone.size(), blocks.size(),
			("   " + str(gone.slice(0, 6))) if gone.size() > 0 else ""])


func _process(_d) -> bool:
	_f += 1
	if _f < 60: return false
	var player: Node4D = _root.get_node("Player")
	var rig: Node4D = _root.get_node("Player/CameraRig")
	player.position = Vector4(0.0, 1.3, 0.0, 0.0)
	print("\n--- your own body, as you rotate the slice ---")
	for deg in [0.0, 10.0, 20.0, 30.0, 45.0, 60.0]:
		SliceAngles.tilt(rig, deg_to_rad(deg), 0.0)
		rig.call("_apply")
		_report(player, rig, "xw %.0f deg" % deg)
	quit(0)
	return true
