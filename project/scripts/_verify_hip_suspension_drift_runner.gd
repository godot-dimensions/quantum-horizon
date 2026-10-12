extends Node
## TEMPORARY - the visual check showed the body flying far up above its
## legs during a REAL (non-halted) gait cycle - all of hip_suspension_
## runner.gd's own numerical checks froze the gait (body.halted=true),
## never exercising this. Tracks body.position.y, pitch/roll slope, and
## per-leg planted state every few frames through a real walk cycle to
## find exactly when/why it diverges. Wired in as a temporary autoload
## with creature_gallery.tscn set as the main scene.


func _ready() -> void:
	await get_tree().process_frame
	_run()


func _run() -> void:
	var scene: Control = get_tree().current_scene
	var flat_plane: Node4D = scene.get_node("FlatPlane")
	var creature: Node = flat_plane.get_node("Steed1")
	var body: Node4D = creature.get_node("Body")

	print("=== live gait height-drift trace (body NOT halted) ===")
	for i in range(400):
		await get_tree().physics_frame
		if i % 10 == 0:
			var states: Array = []
			for leg_name in ["FL", "FR", "BL", "BR"]:
				var ft = creature.get_node("FootTarget%s" % leg_name)
				states.append(["PLANTED", "LIFTING", "SWINGING"][ft.state])
			var b: Projection = body.global_basis
			var anchor_fl = creature.get_node("Body/LimbAnchorFL")
			print("  frame=%d y=%.4f |x|=%.6f |y|=%.6f |z|=%.6f |w|=%.6f x.y=%.6f x.z=%.6f y.z=%.6f global_pos=%s anchorFL_global=%s states=%s" % [
				i, body.position.y,
				b.x.length(), b.y.length(), b.z.length(), b.w.length(),
				b.x.dot(b.y), b.x.dot(b.z), b.y.dot(b.z),
				body.global_position, anchor_fl.global_position, states,
			])

	print("DONE")
	get_tree().quit()
