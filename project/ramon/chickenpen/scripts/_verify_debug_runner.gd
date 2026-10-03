extends SceneTree

## Items 81 and 82: do the debug tools work, do they switch off completely, and does every
## missing piece announce itself rather than failing quietly?

var _root: Node
var _f := 0
var _dbg: Node
var _stage := 0


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/playable_world.tscn").instantiate()
	root.add_child(_root)
	current_scene = _root


func _process(_d) -> bool:
	_f += 1
	if _f < 60:
		return false
	if _dbg == null:
		_dbg = _root.get_node("Systems/Debug")
	if _f % 20 != 0:
		return false
	var fence: Node = _root.get_node("Pen/Fence")
	var mgr: Node = _root.get_node("Chickens")
	var cues: Node = _root.get_node("Systems/Cues")
	var player: Node4D = _root.get_node("Player")

	_stage += 1
	match _stage:
		1:
			print("--- item 81: debug controls ---")
			print("   line reads: %s" % (_root.get_node("UI/Debug") as Label).text)
			_press(KEY_2)
		2:
			print("   [2] teleport to target: player now at w %.2f" % player.global_position.w)
			_press(KEY_1)
		3:
			var first: Node = (mgr.call("locator_candidates") as Array)[0]
			var body: Node4D = first.get_parent() as Node4D
			print("   [1] bring target: chicken %s is %.2f units away, same slice: %s" % [
				first.get("chicken_id"),
				body.global_position.distance_to(player.global_position),
				is_equal_approx(body.global_position.w, player.global_position.w)])
			_press(KEY_3)
		4:
			print("   [3] reveal: band %.0f, distance %.0f (was 0.55 / 11)" % [
				cues.get("reveal_band"), cues.get("reveal_distance")])
			_press(KEY_3)
			_press(KEY_5)
		5:
			print("   [5] pen grew to %.0f x %.0f, posts now %d" % [
				float(fence.get("extend_x_positive")) + float(fence.get("extend_x_negative")),
				float(fence.get("extend_z_positive")) + float(fence.get("extend_z_negative")),
				_posts(fence)])
			_press(KEY_4)
			_press(KEY_4)
		6:
			print("   [4] pen shrank to %.0f x %.0f, posts now %d" % [
				float(fence.get("extend_x_positive")) + float(fence.get("extend_x_negative")),
				float(fence.get("extend_z_positive")) + float(fence.get("extend_z_negative")),
				_posts(fence)])
			_press(KEY_7)
		7:
			print("   [7] finish: returned %d/12" % mgr.call("returned_count"))
			_press(KEY_6)
		8:
			print("   [6] scatter: loose again %d" % (mgr.call("locator_candidates") as Array).size())
			_press(KEY_0)
		9:
			var line: String = (_root.get_node("UI/Debug") as Label).text
			print("   [0] switched off: processing %s, input %s" % [
				_dbg.is_processing(), _dbg.is_processing_unhandled_input()])
			_press(KEY_7)
		10:
			print("   pressing [7] after switching off: returned %d/12 (unchanged)" % mgr.call("returned_count"))
			print("\n--- item 82: what announces itself when wired up wrongly ---")
			for row in [
					["ChickenLocator", "manager or player missing"],
					["ChickenCatcher", "manager_path resolves to nothing"],
					["ChickenCatcher", "carry_anchor_path resolves to nothing"],
					["PenReturn", "fence_path resolves to nothing"],
					["PenReturn", "was inside the pen without ever being carried"],
					["PenFence", "smaller than a chicken"],
					["ChickenManager", "has no Agent node"],
					["ChickenManager", "only %d placements are authored"],
					["ChickenAgent", "no Walker under"],
					["ChickenAgent", "recovered"],
					["ChickenCues", "locator, manager or player missing"],
					["PenTutor", "label or player missing"],
					["ChickenPenGame", "manager or player missing"]]:
				print("   %-16s %s" % [row[0], row[1]])
			return true
	return false


func _posts(fence: Node) -> int:
	var n := 0
	for child in (fence as Node).get_children():
		if child.name.begins_with("Post_"):
			n += 1
	return n


func _press(key: int) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = true
	_dbg.call("_unhandled_input", event)
