extends SceneTree

## Does the Arboretum's new door actually open onto the walkway?
##
##   godot --path project --rendering-method forward_plus --resolution 640x400 \
##       --script res://sandbox/water4d/_probe_arboretum_annex_runner.gd
##
## Two things have to line up and neither is visible from the scene file: the walkway has to
## START at the wall the door is cut in, and its deck has to be at the room's floor level. A
## metre out either way and the player walks into a wall or steps off a ledge into the pool -
## and the second one reads as "the door is broken" rather than "the annex is offset".

var _frames: int = 0
var _root: Node = null


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		_root = (load("res://ramon/Arboretum/arboretum.tscn") as PackedScene).instantiate()
		root.add_child(_root)
		current_scene = _root
		return false
	if _frames < 6:
		return false

	var ok := true
	# THE HALL, not the grove: the door is in the first room the player walks into, on its
	# right-hand wall. Its walls are a polygon, so the wall's position has to be read out of
	# the built outline rather than from a size.
	var hall: Node4D = _root.get_node_or_null(^"Hall") as Node4D
	var annex: Node4D = _root.get_node_or_null(^"WaterAnnex") as Node4D
	if hall == null or annex == null:
		print("  FAIL - no Hall or no WaterAnnex")
		quit(1)
		return true
	var names: PackedStringArray = hall.get(&"wall_names")
	var outline: PackedVector2Array = hall.get(&"outline")
	var edge: int = -1
	for i in names.size():
		if names[i] == "right":
			edge = i
			break
	if edge < 0 or outline.size() < 2:
		print("  FAIL - the hall has no wall named 'right'")
		quit(1)
		return true
	var wall_x: float = hall.position.x + outline[edge].x
	var doors: Array = hall.get(&"doorways")
	var water_door: Array = []
	for door in doors:
		if (door as Array)[0] == "right":
			water_door = door as Array
	if water_door.is_empty():
		print("  FAIL - the hall has no doorway in its right-hand wall")
		quit(1)
		return true
	# Along the edge from its first corner, which is the BACK end of that wall.
	var start: Vector2 = outline[edge]
	var centre_along: float = (float(water_door[1]) + float(water_door[2])) * 0.5
	var door_z: float = hall.position.z + start.y + centre_along
	print("  hall right wall at x = %.2f, water door centred at z = %.2f" % [wall_x, door_z])

	var deck: Node4D = annex.get_node_or_null(^"Walkway/Deck") as Node4D
	if deck == null:
		print("  FAIL - the annex built no Walkway/Deck")
		quit(1)
		return true
	# `_box` builds a StaticBody4D with the MeshInstance4D as its CHILD, so the deck node
	# itself has no mesh - casting it to MeshInstance4D gave null and the probe then read a
	# property off nothing.
	var instance: MeshInstance4D = null
	for child in deck.get_children():
		if child is MeshInstance4D:
			instance = child as MeshInstance4D
			break
	if instance == null:
		print("  FAIL - the deck body has no mesh instance under it")
		quit(1)
		return true
	var mesh := instance.mesh as BoxTetraMesh4D
	var size: Vector4 = mesh.size
	var centre: Vector4 = deck.get_global_position()
	var near_x: float = centre.x - size.x * 0.5
	var far_x: float = centre.x + size.x * 0.5
	var top_y: float = centre.y + size.y * 0.5
	print("  walkway deck from x = %.2f to %.2f, top at y = %.2f" % [near_x, far_x, top_y])
	print("  deck through W from %.2f to %.2f, through Z from %.2f to %.2f" % [
			centre.w - size.w * 0.5, centre.w + size.w * 0.5,
			centre.z - size.z * 0.5, centre.z + size.z * 0.5])

	if absf(near_x - wall_x) > 0.75:
		print("  FAIL - the walkway starts %.2f m from the wall; the door opens onto nothing"
				% absf(near_x - wall_x))
		ok = false
	if absf(top_y) > 0.2:
		print("  FAIL - the deck is at y = %.2f, not the room floor's 0" % top_y)
		ok = false
	if absf(centre.z - door_z) > 0.6:
		print("  FAIL - the walkway is centred on z = %.2f but the door is at z = %.2f"
				% [centre.z, door_z])
		ok = false

	# WHERE THE SEA STOPS. A 120 m patch centred on the annex reached back to x = -18, which
	# put a sea surface under the hall and under the spawn point - the floor had water running
	# through it everywhere the player stood. The patch has to end at the wall the door is in.
	var water: Node4D = annex.get_node_or_null(^"Water") as Node4D
	if water == null:
		print("  FAIL - the annex has no Water")
		quit(1)
		return true
	# THE NODE'S POSITION IS NOT WHERE THE SEA IS. water4d_surface.gd never sets a transform
	# on its RenderingServer instance - it creates it with `ignore_culling` and a 10000 unit
	# AABB - so the surface's height is the `water_level` uniform alone and its horizontal
	# placement is the shader's own world anchoring. Moving the Water node does nothing at
	# all, which is why an earlier version of this probe passed while the sea still ran
	# through the entrance floor: it was measuring the node.
	var level: float = water.get(&"water_level")
	print("  water line at y = %.2f (from `water_level`, not from the node)" % level)
	var clearance: float = -level
	if clearance < 1.5:
		print("  FAIL - only %.2f m of freeboard; wave crests will break through the floor"
				% clearance)
		ok = false

	var creature: Node = annex.get_node_or_null(^"Plesiosaur")
	print("  creature in the annex: %s" % ("yes" if creature != null else "NO"))
	if creature == null:
		ok = false
	if annex.get_node_or_null(^"Player") != null:
		print("  FAIL - the annex spawned a second player")
		ok = false

	print("")
	print("  %s" % ("PASS - the door opens onto the walkway." if ok else "see above."))
	quit(0 if ok else 1)
	return true
