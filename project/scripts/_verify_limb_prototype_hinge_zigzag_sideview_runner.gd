extends Node
## TEMPORARY - single screenshot of the FL leg from a camera looking along Z
## (face-on to the hinge bend plane, which is spanned by world up and the
## chain's root_forward_local = +X for this scene) instead of along the
## LEG_OUTWARD_DIR used by the main lift/swing screenshot script (which for
## FL points mostly along +X - i.e. EDGE-ON to the X-Y bend plane, likely
## flattening any real zigzag into what looks like a near-straight line).
## Isolates FL, freezes the chain mid-plant, freezes body wander. Not part
## of the shipped scene - wired in as a temporary autoload with
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

	body.speed = 0.0
	for i in range(4):
		_set_mesh_visibility(anchors[i], i == 0) # Isolate FL only.

	# Let the FL leg's own gait cycle run for a while so it settles into a
	# real planted/lifting/swinging pose (not the identity spawn pose), then
	# capture from the side.
	for i in range(120):
		await get_tree().physics_frame

	var anchor_pos: Vector4 = anchors[0].global_position
	player.global_position = anchor_pos + Vector4(0, 2.5, -8, 0) # Along -Z, facing +Z - face-on to the X-Y bend plane.
	player.global_basis = Basis4D.looking_at(anchor_pos - player.global_position)
	await get_tree().physics_frame
	await _screenshot("limb_prototype_hinge_zigzag_sideview_1.png")

	for i in range(60):
		await get_tree().physics_frame
		anchor_pos = anchors[0].global_position
		player.global_position = anchor_pos + Vector4(0, 2.5, -8, 0)
		player.global_basis = Basis4D.looking_at(anchor_pos - player.global_position)
	await _screenshot("limb_prototype_hinge_zigzag_sideview_2.png")

	print("DONE")
	get_tree().quit()
