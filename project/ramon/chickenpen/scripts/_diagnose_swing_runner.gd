extends SceneTree

## Which way does the arm actually go?
##
## Basis4D.from_yz is not readable from its name on this rig - the gauntlet's raised arm
## needed the angle swept and measured before either sign turned out to be up. So rather
## than trusting that 2.4 is "up and back" and -0.9 is "forward and down", this sweeps the
## pose and prints where the head of the pickaxe ends up: its height, and how far in front
## of the shoulder it is.

var _root: Node
var _f := 0


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/chickenpen.tscn").instantiate()
	root.add_child(_root); current_scene = _root


func _process(_d) -> bool:
	_f += 1
	if _f < 70: return false
	var pick: Node = _root.get_node("Systems/Pickaxe")
	var belt: Node = _root.get_node("UI/Inventory")
	var avatar: Node4D = _root.get_node("Player/Avatar")
	belt.call("_choose", 0)
	pick.call("_hang_it")
	var shoulder: Node4D = avatar.get("shoulder_right")
	var head: Node4D = _root.get_node_or_null(
		"Player/Avatar/ShoulderR/ElbowR/Pickaxe/Collar") as Node4D
	if head == null:
		print("   FAIL the pickaxe is not in the hand")
		quit(1); return true

	print("\n   %6s  %8s  %10s" % ["t", "head y", "ahead of you"])
	var fwd: Vector4 = (avatar.global_basis * Vector4(0.0, 0.0, 1.0, 0.0)).normalized()
	for i in 11:
		var t: float = float(i) / 10.0
		pick.call("_pose", t)
		var rel: Vector4 = head.global_position - shoulder.global_position
		print("   %6.2f  %+8.2f  %+10.2f" % [t, rel.y, rel.dot(fwd)])
	print("\n   (a swing wants the head high and behind early, then low and ahead)")
	quit(0)
	return true
