extends Node
## TEMPORARY - isolates FL (front) and BL (back) one at a time, camera
## aimed face-on to each leg's own bend plane (matching the technique
## confirmed necessary during the hinge investigation - an edge-on camera
## flattens a real zigzag into what looks like a smooth curve), for an
## unambiguous look at the anatomical seed's bend shape on each leg type.
## Not part of the shipped scene - wired in as a temporary autoload with
## limb_prototype_treadmill.tscn set as the main scene.


func _screenshot(image_name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://smoke_test_output/" + image_name)


func _set_mesh_visibility(node: Node, vis: bool) -> void:
	if node is MeshInstance4D:
		node.visible = vis
	for child in node.get_children():
		_set_mesh_visibility(child, vis)


func _ready() -> void:
	await get_tree().process_frame
	_run()


func _run() -> void:
	var scene: Control = get_tree().current_scene
	var flat_plane: Node4D = scene.get_node("FlatPlane")
	var player: CharacterBody4D = flat_plane.get_node("Player")
	var body: Node4D = flat_plane.get_node("Body")
	var anchors: Array = [
		flat_plane.get_node("Body/LimbAnchorFL"),
		flat_plane.get_node("Body/LimbAnchorFR"),
		flat_plane.get_node("Body/LimbAnchorBL"),
		flat_plane.get_node("Body/LimbAnchorBR"),
	]

	var foot_targets: Array = [
		flat_plane.get_node("FootTargetFL"),
		flat_plane.get_node("FootTargetFR"),
		flat_plane.get_node("FootTargetBL"),
		flat_plane.get_node("FootTargetBR"),
	]
	player.global_basis = Projection()
	body.speed = 0.0

	# Isolate FL (index 0), view along Z (face-on to the X-Y bend plane).
	# Wait for a confirmed PLANTED state so this is a fair rest-pose look,
	# not a mid-swing snapshot.
	for i in range(4):
		_set_mesh_visibility(anchors[i], i == 0)
	while foot_targets[0].state != foot_targets[0].FootState.PLANTED:
		await get_tree().physics_frame
	var anchor_pos: Vector4 = anchors[0].global_position
	var fl_chain: Node = anchors[0].get_node("IKChain")
	print("FL state=%s locked_position=%s anchor=%s" % [foot_targets[0].state, foot_targets[0].locked_position, anchor_pos])
	for j in range(fl_chain.joints.size()):
		print("  FL joint%d pos=%s dir=%s" % [j, fl_chain.joints[j].global_position, fl_chain.joints[j].global_basis.y])
	print("  FL effector=%s" % [fl_chain._end_effector_position()])
	player.global_position = anchor_pos + Vector4(0, 2.5, -8, 0)
	player.global_basis = Basis4D.looking_at(anchor_pos - player.global_position)
	await get_tree().physics_frame
	await _screenshot("limb_prototype_anatomy_FL_isolated.png")

	# Isolate BL (index 2), same PLANTED wait.
	for i in range(4):
		_set_mesh_visibility(anchors[i], i == 2)
	while foot_targets[2].state != foot_targets[2].FootState.PLANTED:
		await get_tree().physics_frame
	anchor_pos = anchors[2].global_position
	var bl_chain: Node = anchors[2].get_node("IKChain")
	print("BL state=%s locked_position=%s anchor=%s" % [foot_targets[2].state, foot_targets[2].locked_position, anchor_pos])
	for j in range(bl_chain.joints.size()):
		print("  BL joint%d pos=%s dir=%s" % [j, bl_chain.joints[j].global_position, bl_chain.joints[j].global_basis.y])
	print("  BL effector=%s" % [bl_chain._end_effector_position()])
	player.global_position = anchor_pos + Vector4(0, 2.5, -8, 0)
	player.global_basis = Basis4D.looking_at(anchor_pos - player.global_position)
	await get_tree().physics_frame
	await _screenshot("limb_prototype_anatomy_BL_isolated.png")

	print("DONE")
	get_tree().quit()
