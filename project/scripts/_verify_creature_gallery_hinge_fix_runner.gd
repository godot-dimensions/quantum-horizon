extends Node
## TEMPORARY - side-on screenshots of Steed1 in creature_gallery.tscn after
## the generous-hinge-range fix (joint_hinge_min/max_deg = [-100,100] on all
## 3 joints of every leg, added to creature_template.tscn), to check whether
## it resolves the visually-reported "feet curled upward" look without
## reproducing the earlier tight-range ground-sinking failure. Also logs
## each foot's height above its own locked_position's ground contact so a
## sinking regression would show up numerically, not just by eye. Not part
## of the shipped scene - wired in as a temporary autoload with
## creature_gallery.tscn set as the main scene.

const SETTLE_FRAMES := 300 # 5s - long enough to see multiple full gait cycles.


func _screenshot(image_name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://smoke_test_output/" + image_name)


func _ready() -> void:
	await get_tree().process_frame
	_run()


func _run() -> void:
	var scene: Control = get_tree().current_scene
	var flat_plane: Node4D = scene.get_node("FlatPlane")
	var player: CharacterBody4D = flat_plane.get_node("Player")
	var creature: Node = flat_plane.get_node("Steed1")
	var body: Node4D = creature.get_node("Body")

	player.global_basis = Projection()
	player.global_position = body.global_position + Vector4(9, 4, -11, 0)
	player.global_basis = Basis4D.looking_at(body.global_position - player.global_position)
	await get_tree().physics_frame
	await _screenshot("creature_gallery_hinge_fix_spawn_3q.png")

	for i in range(SETTLE_FRAMES):
		await get_tree().physics_frame
		player.global_position = body.global_position + Vector4(9, 4, -11, 0)
		player.global_basis = Basis4D.looking_at(body.global_position - player.global_position)

	print("=== per-leg foot height above ground check ===")
	for leg_name in ["FL", "FR", "BL", "BR"]:
		var ft = creature.get_node("FootTarget%s" % leg_name)
		var ik_chain = creature.get_node("Body/LimbAnchor%s/IKChain" % leg_name)
		var effector_pos: Vector4 = ik_chain._end_effector_position()
		print("  %s: foot_target.y=%.3f effector.y=%.3f state=%s" % [leg_name, ft.global_position.y, effector_pos.y, ft.state])

	await _screenshot("creature_gallery_hinge_fix_walking_3q.png")

	print("DONE")
	get_tree().quit()
