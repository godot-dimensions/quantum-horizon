extends SceneTree

## Which way do the picks point, for each of the four quarter turns?
##
## A pickaxe bites along the arc the arm swings through, so the line joining its two
## points has to lie along the character's FORWARD - not across the body. That is a
## number, not an opinion: take the two outer pick blocks, measure the axis between them,
## and compare it to the way the avatar faces. Three rounds of turning it by eye and
## re-photographing did not settle this; one sweep does.

var _root: Node
var _f := 0


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/playable_world.tscn").instantiate()
	root.add_child(_root); current_scene = _root


func _process(_d) -> bool:
	_f += 1
	if _f < 70: return false
	var pick: Node = _root.get_node("Systems/Pickaxe")
	var belt: Node = _root.get_node("UI/Inventory")
	var avatar: Node4D = _root.get_node("Player/Avatar")
	var player: Node4D = _root.get_node("Player")
	player.set("_facing", 0.0)
	belt.call("_choose", 0)

	print("\n   %10s %10s   %8s %8s %8s" % ["haft", "picks", "vs fwd", "vs side", "vs up"])
	var best: float = 999.0
	var best_at: Array = []
	for haft in [0.0, PI * 0.5, PI, -PI * 0.5]:
		for turn in [0.0, PI * 0.5, PI, -PI * 0.5]:
			pick.set("haft_across", haft)
			pick.set("picks_forward", turn)
			# Force a rebuild so the new basis is applied.
			var prop: Node = _root.get_node_or_null("Player/Avatar/ShoulderR/ElbowR/Pickaxe")
			if prop != null:
				prop.free()
			pick.call("_hang_it")
			pick.call("_pose", 0.0)
			var a: Node4D = _root.get_node_or_null(
				"Player/Avatar/ShoulderR/ElbowR/Pickaxe/PickL2") as Node4D
			var b: Node4D = _root.get_node_or_null(
				"Player/Avatar/ShoulderR/ElbowR/Pickaxe/PickR2") as Node4D
			if a == null or b == null:
				continue
			var spread: Vector4 = (b.global_position - a.global_position).normalized()
			var fwd: Vector4 = (avatar.global_basis * Vector4(0.0, 0.0, 1.0, 0.0)).normalized()
			var side: Vector4 = (avatar.global_basis * Vector4(1.0, 0.0, 0.0, 0.0)).normalized()
			var up := Vector4(0.0, 1.0, 0.0, 0.0)
			var off: float = rad_to_deg(acos(clampf(absf(spread.dot(fwd)), 0.0, 1.0)))
			print("   %10.2f %10.2f   %7.0f%% %7.0f%% %7.0f%%"
				% [haft, turn, absf(spread.dot(fwd)) * 100.0,
					absf(spread.dot(side)) * 100.0, absf(spread.dot(up)) * 100.0])
			if off < best:
				best = off
				best_at = [haft, turn]
	print("\n   picks point most nearly forward at haft %.2f, picks %.2f - %.0f degrees off"
		% [best_at[0], best_at[1], best])
	quit(0)
	return true
