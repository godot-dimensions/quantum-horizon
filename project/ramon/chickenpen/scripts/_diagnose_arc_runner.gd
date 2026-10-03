extends SceneTree

## Does the arm swing to the FRONT or to the back?
##
## Measured on the hand rather than on the tool, so the answer does not depend on how the
## pickaxe happens to be gripped. Basis4D.from_yz(0) hangs the arm straight down and
## POSITIVE angles carry it towards -Z - which is BEHIND a character that faces +Z, the
## convention everything in this scene is posed with. That is the trap: the number that
## reads as "swing forwards" swings backwards.

var _root: Node
var _f := 0


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/playable_world.tscn").instantiate()
	root.add_child(_root); current_scene = _root


func _process(_d) -> bool:
	_f += 1
	if _f < 70: return false
	var pick: Node = _root.get_node("Systems/Pickaxe")
	var avatar: Node4D = _root.get_node("Player/Avatar")
	var player: Node4D = _root.get_node("Player")
	player.set("_facing", 0.0)
	_root.get_node("UI/Inventory").call("_choose", 0)
	pick.call("_hang_it")
	var shoulder: Node4D = avatar.get("shoulder_right")
	var hand: Node4D = _root.get_node("Player/Avatar/ShoulderR/ElbowR/HandR")
	var fwd: Vector4 = (avatar.global_basis * Vector4(0.0, 0.0, 1.0, 0.0)).normalized()

	print("\n   %6s %10s %10s" % ["t", "ahead", "height"])
	var earliest: float = 0.0
	var latest: float = 0.0
	for i in 11:
		var t: float = float(i) / 10.0
		pick.call("_pose", t)
		var rel: Vector4 = hand.global_position - shoulder.global_position
		var ahead: float = rel.dot(fwd)
		if i == 2: earliest = ahead
		if i == 9: latest = ahead
		print("   %6.2f %+10.3f %+10.3f" % [t, ahead, rel.y])
	print("\n   wind-up is %+.3f ahead, the strike lands %+.3f ahead" % [earliest, latest])
	print("   %s" % ("GOOD: it comes from behind and finishes in front" if latest > earliest
		else "WRONG WAY: it finishes further back than it started"))
	quit(0)
	return true
