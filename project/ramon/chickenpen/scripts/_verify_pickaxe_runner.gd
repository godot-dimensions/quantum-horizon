extends SceneTree

## Is there a rock, is the pickaxe in the belt, can it be chosen, and does swinging it
## actually take a bite out of the rock?
##
## The last one is the only one that proves anything. The block, the per-voxel colliders
## and the carve all come from project/ramon/VoxelMining/ unchanged; what is new is the
## part that belongs to this scene - which tool is in hand and where the swing starts from
## - so the test aims a real raycast at the real rock and counts colliders either side.

var _root: Node
var _f := 0
var _step := 0
var _fails: Array = []
var _before := 0
var _shell_before: Array = []


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/chickenpen.tscn").instantiate()
	root.add_child(_root); current_scene = _root


func _check(label: String, ok: bool, detail: String) -> void:
	print("   %s %-36s %s" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_fails.append(label)


## The middle of the rock, from its own colliders rather than from an assumption about
## where the node's origin sits inside the grid.
func _rock_middle(voxels: Node) -> Vector4:
	var sum := Vector4.ZERO
	var n: int = 0
	for shape in voxels.get_children():
		if shape is CollisionShape4D:
			sum += (shape as CollisionShape4D).global_position
			n += 1
	return sum / maxf(float(n), 1.0)


func _count(voxels: Node) -> int:
	var n: int = 0
	for shape in voxels.get_children():
		if shape is CollisionShape4D:
			n += 1
	return n


## The SET of voxels, not how many there are. A bite removes surface voxels and exposes
## the ones behind them, so the count can come out the same on both sides of a carve that
## definitely happened - it did, 544 either way, which is what this test first believed.
func _shell(voxels: Node) -> Array:
	var out: Array = []
	for shape in voxels.get_children():
		if shape is CollisionShape4D:
			var at: Vector4 = (shape as CollisionShape4D).global_position
			out.append("%.2f,%.2f,%.2f,%.2f" % [at.x, at.y, at.z, at.w])
	out.sort()
	return out


func _process(_d) -> bool:
	_f += 1
	if _f < 70: return false
	var rock: Node4D = _root.get_node_or_null("World/MiningRock") as Node4D
	if rock == null:
		print("   FAIL there is no rock in the scene")
		quit(1); return true
	var voxels: Node = rock.get_node("Voxels")
	var belt: Node = _root.get_node("UI/Inventory")
	var pick: Node = _root.get_node("Systems/Pickaxe")
	var player: Node4D = _root.get_node("Player")
	var rig: Node4D = _root.get_node("Player/CameraRig")

	match _step:
		0:
			print("\n--- the rock ---")
			_check("it generated itself", _count(voxels) > 0,
				"%d per-voxel colliders" % _count(voxels))
			_check("and it has a mesh",
				(rock.get_node("Ground") as MeshInstance4D).mesh != null, "contoured")

			print("\n--- the belt ---")
			_check("the pickaxe is in it", bool(belt.call("has_item", "found_pickaxe")),
				"items: %s" % [belt.get("items")])
			_check("nothing is in hand to start", String(belt.call("selected_effect")) == "",
				"selected %d" % belt.get("selected"))
			belt.call("_choose", 0)
			_check("choosing slot one takes it",
				String(belt.call("selected_effect")) == "found_pickaxe",
				"in hand: %s" % belt.call("selected_effect"))
			belt.call("_choose", 0)
			_check("choosing it again puts it away",
				String(belt.call("selected_effect")) == "", "hand is empty")
			belt.call("_choose", 0)

			# Stand in front of the rock and look straight at it.
			var middle: Vector4 = _rock_middle(voxels)
			player.position = Vector4(middle.x, 1.2, middle.z + 2.2, middle.w)
			player.set("linear_velocity", Vector4.ZERO)
			var to: Vector4 = middle - player.global_position
			rig.set("yaw", atan2(-to.x, -to.z))
			rig.set("pitch", 0.0)
			rig.call("_apply")
			# Level the swing on the rock's middle rather than tilting the camera to it.
			pick.set("chest_height", middle.y - player.global_position.y)
			_before = _count(voxels)
			_shell_before = _shell(voxels)
			print("\n--- one swing ---")
			print("   rock middle %v, standing %.2f away" % [middle, to.length()])
		1:
			var hit: bool = bool(pick.call("_swing"))
			_check("the swing connected", hit, "raycast reached the rock")
		_:
			if _f < 110: return false
			var after: int = _count(voxels)
			var shell_after: Array = _shell(voxels)
			var gone: int = 0
			for at in _shell_before:
				if not shell_after.has(at):
					gone += 1
			var fresh: int = 0
			for at in shell_after:
				if not _shell_before.has(at):
					fresh += 1
			_check("it took a bite out of it", gone > 0,
				"%d voxels gone, %d newly exposed behind them (%d colliders before, %d after)"
					% [gone, fresh, _before, after])
			print("\n%d FAIL(s)" % _fails.size())
			quit(1 if _fails.size() > 0 else 0)
			return true
	_step += 1
	_f = 65
	return false
