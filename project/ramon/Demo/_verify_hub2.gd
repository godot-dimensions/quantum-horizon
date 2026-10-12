extends SceneTree

## Headless structural check for hub2, mirroring _verify_hub.gd's approach for
## hub1: hub2's gates, platforms and ramps are generated at runtime and
## deliberately not saved into the scene, so this instantiates it, walks the
## resulting tree, and prints enough to confirm the ring actually built the
## tiered structure rather than a flat arc.
##
## Headless has no renderer, so this proves structure only - not whether a
## slope reads as climbable, whether the ramp's w-band is wide enough in
## practice, or how any of it looks. Those need eyes, with the editor closed:
## see HUB2_README.md's Open questions.
##
## Run with the editor CLOSED - two Godot processes touching the same project's
## .godot cache is what silently breaks @tool buttons in a running editor:
##
##   engine/godot/bin/godot.windows.editor.double.x86_64.console.exe \
##       --headless --path project --script res://ramon/Demo/_verify_hub2.gd

const HUB_PATH := "res://ramon/Demo/hub2.tscn"

var _hub: Node = null
var _failed: bool = false


func _initialize() -> void:
	print("checking: ", HUB_PATH)
	var packed: PackedScene = load(HUB_PATH)
	if packed == null:
		printerr("VERIFY: could not load ", HUB_PATH)
		_failed = true
		return
	_hub = packed.instantiate()
	root.add_child(_hub)


func _process(_delta: float) -> bool:
	if _failed or _hub == null:
		quit(1)
		return true

	var ring: Node = _hub.get_node_or_null("GateRing")
	if ring == null:
		printerr("VERIFY: no GateRing node")
		quit(1)
		return true

	print("\n===== catalogue =====")
	print("gates: ", ring.gates.size(), "   tiers: ", ring.tiers.size())

	var slots := ring.get_children()
	print("\n===== slots =====")
	var owned_leaks := 0
	var ground_count := 0
	var platform_count := 0
	var ramp_count := 0
	var frame_segment_total := 0

	for slot in slots:
		if slot.owner != null:
			owned_leaks += 1
		var gate: Node = slot.get_node_or_null("Gate")
		var platform: Node = slot.get_node_or_null("Platform")
		var ramp: Node = slot.get_node_or_null("Ramp")
		if gate == null:
			printerr("VERIFY: FAILED - %s has no Gate" % slot.name)
			quit(1)
			return true
		if gate.owner != null:
			owned_leaks += 1

		var frame: Node = gate.get_node_or_null("Frame")
		var frame_segments := frame.get_child_count() if frame != null else 0
		frame_segment_total += frame_segments

		var line := "  %-28s height=%.2f  frame_segments=%d" % [slot.name, gate.position.y, frame_segments]

		if platform == null and ramp == null:
			ground_count += 1
			line += "  [ground]"
		elif platform != null and ramp != null:
			var platform_shape: Shape4D = platform.get_node("Collider").shape
			var ramp_shape: Shape4D = ramp.get_node("Collider").shape
			platform_count += 1
			ramp_count += 1
			if platform.owner != null:
				owned_leaks += 1
			if ramp.owner != null:
				owned_leaks += 1
			line += "  [tiered] platform_size=%s  ramp_size=%s  ramp_w_offset=%.1f" % [
				str(platform_shape.size), str(ramp_shape.size), ramp.position.w
			]
		else:
			printerr("VERIFY: FAILED - %s has only one of Platform/Ramp" % slot.name)
			quit(1)
			return true

		print(line)

	print("\n===== summary =====")
	print("slots: %d   ground: %d   tiered (platform+ramp): %d/%d" % [slots.size(), ground_count, platform_count, ramp_count])
	print("frame segments total: ", frame_segment_total)
	print("generated nodes wrongly owned by the scene: ", owned_leaks)

	var floor_mesh: Node = _hub.get_node_or_null("Floor/Mesh")
	var wall_mesh: Node = _hub.get_node_or_null("BackWall/Mesh")
	print("floor mesh present: ", floor_mesh != null, "   wall mesh present: ", wall_mesh != null)

	if slots.size() != ring.gates.size():
		printerr("VERIFY: FAILED - expected %d slots, got %d" % [ring.gates.size(), slots.size()])
		quit(1)
		return true
	if ground_count == 0 or platform_count == 0:
		printerr("VERIFY: FAILED - expected both a ground gate and at least one tiered gate")
		quit(1)
		return true
	if owned_leaks > 0:
		printerr("VERIFY: FAILED - generated nodes would be serialised into the scene")
		quit(1)
		return true

	print("VERIFY: OK")
	quit(0)
	return true
