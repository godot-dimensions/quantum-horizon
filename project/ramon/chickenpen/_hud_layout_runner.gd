extends SceneTree

## Where the HUD's panels are, and which overlap: the pen's cards, the dial, the camera picker,
## the Lookout card and the grass panel, on the farm and then at the tower (where the Lookout card
## shows). Prints each visible panel's rect in pixels and every pair that overlaps, and saves a
## frame of each. Run it at the window sizes that matter (2560 x 1440 is Ramon's). Gives up after
## 90 s. Saves res://smoke_test_output/hud_<w>_<where>.png.
##
##   godot... --path project --windowed --resolution 2560x1440 --position 0,0
##       --script res://ramon/chickenpen/_hud_layout_runner.gd -- scene=res://ramon/chickenpen/chickenpen.tscn

const PANELS := ["Debug", "FlockStats", "GrassPanel", "Quests", "Inventory", "Controls", "Cinematics", "Journal", "CameraPicker", "SlicePlane"]

var _room: Node
var _path: String = "res://ramon/chickenpen/playable_world.tscn"
var _t: float = 0.0
var _step: int = -1
var _wait: float = 0.0
var _overlaps: int = 0


func _initialize() -> void:
	root.unfocusable = true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("scene="):
			_path = arg.substr(6)
	_room = load(_path).instantiate()
	var lookout: Node = _room.get_node_or_null("Systems/Lookout")
	if lookout != null:
		lookout.set("journal_path", "user://lookout_journal_hud_test.cfg")
	root.add_child(_room)
	current_scene = _room


func _rect(c: Control) -> Rect2:
	# On screen, in window pixels (the UI may be scaled: pen_ui_scale_4d.gd).
	return c.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, c.size)


func _report(where: String) -> void:
	var ui: Node = _room.get_node("UI")
	var rects: Dictionary = {}
	for name in PANELS:
		var c := ui.get_node_or_null(name) as Control
		if c == null or not c.is_visible_in_tree() or c.modulate.a < 0.05:
			continue
		var r: Rect2 = _rect(c)
		if r.size.x < 2.0 or r.size.y < 2.0:
			continue
		rects[name] = r
		print("      %-6s %-12s x %5d..%5d  y %5d..%5d" % [where, name, roundi(r.position.x), roundi(r.end.x), roundi(r.position.y), roundi(r.end.y)])
	if root.size.x <= 1920 and where == "farm":
		# Everything else on screen too: what a placed panel has to keep clear of.
		for child in ui.get_children():
			var c := child as Control
			if c == null or PANELS.has(String(c.name)) or not c.is_visible_in_tree() or c.modulate.a < 0.05:
				continue
			var r: Rect2 = _rect(c)
			if r.size.x >= 2.0 and r.size.y >= 2.0:
				print("      %-6s (other) %-14s x %5d..%5d  y %5d..%5d" % [where, c.name, roundi(r.position.x), roundi(r.end.x), roundi(r.position.y), roundi(r.end.y)])
	var names: Array = rects.keys()
	for i in names.size():
		for j in range(i + 1, names.size()):
			var a: Rect2 = rects[names[i]]
			var b: Rect2 = rects[names[j]]
			var cut: Rect2 = a.intersection(b)
			if cut.size.x > 4.0 and cut.size.y > 4.0:
				# The dial is a circle in a square: an overlap only with its square's corner may not show.
				print("      %-6s OVERLAP %s and %s: %d x %d px" % [where, names[i], names[j], roundi(cut.size.x), roundi(cut.size.y)])
				_overlaps += 1
	root.get_texture().get_image().save_png("res://smoke_test_output/hud_%d_%s.png" % [root.size.x, where])


func _process(d: float) -> bool:
	_t += d
	if _t > 90.0:
		print("HUD FAIL: timed out")
		return true
	_wait -= d
	if _wait > 0.0:
		return false
	match _step:
		-1:
			var grass: Node = _room.get_node_or_null("World/Grass")
			if (grass != null and not bool(grass.get("mask_ready"))) or _t < 6.0:
				return false
			print("      window %d x %d" % [root.size.x, root.size.y])
			_report("farm")
			var lookout: Node = _room.get_node_or_null("Systems/Lookout")
			if lookout == null:
				print("HUD DONE (%d overlaps)" % _overlaps)
				return true
			for f in ["approached", "met_wren"]:
				lookout.get("journal").call("set_flag", f, true)
			var player := _room.get_node("Player") as Node4D
			var tower: Vector4 = (_room.get_node("World/LookoutSite/Lookout") as Node4D).global_position
			player.global_position = tower + Vector4(4.0, 0.05, 6.0, 0.0)
			_step = 0
			_wait = 2.0
		0:
			_report("tower")
			print("HUD DONE (%d overlaps)" % _overlaps)
			if FileAccess.file_exists("user://lookout_journal_hud_test.cfg"):
				DirAccess.remove_absolute(ProjectSettings.globalize_path("user://lookout_journal_hud_test.cfg"))
			return true
	return false
