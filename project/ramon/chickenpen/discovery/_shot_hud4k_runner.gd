extends SceneTree

## The pen's HUD at Ramon's own setup (3840 x 2160, his saved UI size, 145%): a frame in the art look and the dev look,
## and every card's rect printed, with the pairs that overlap. For the 10 Oct HUD changes (the controls card's two
## groups, the sizes' bracket, the DEV / ART switch at the bottom).
##
##   lab_run.sh windowed hud4k res://ramon/chickenpen/discovery/_shot_hud4k_runner.gd

const OUT := "res://smoke_test_output/feedback_10oct/hud4k/"

var _room: Node


class RunnerGuard extends Node:
	func _input(event: InputEvent) -> void:
		if event is InputEventKey or event is InputEventMouse or event is InputEventJoypadButton or event is InputEventJoypadMotion:
			get_viewport().set_input_as_handled()


func _initialize() -> void:
	root.unfocusable = true
	DisplayServer.window_set_position(Vector2i(0, 0))
	DisplayServer.window_set_size(Vector2i(3840, 2160))
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _rect(c: Control) -> Rect2:
	if c.has_method("belt_rect"):
		return c.call("belt_rect")
	if c.has_method("drawn_rect"):
		var d: Variant = c.call("drawn_rect")
		if d is Rect2 and (d as Rect2).size != Vector2.ZERO:
			return d
	return c.get_global_rect()


func _report() -> void:
	var ui: Node = _room.get_node("UI")
	var screen: Vector2 = root.get_visible_rect().size
	var cards: Array = []
	for c in ui.get_children():
		var cc := c as Control
		if cc == null or not cc.is_visible_in_tree():
			continue
		if cc is Label and (cc as Label).text.strip_edges() == "":
			continue
		var r: Rect2 = _rect(cc)
		if r.size.x < 4.0 or r.size.y < 4.0 or (r.size.x > screen.x * 0.9 and r.size.y > screen.y * 0.9):
			continue
		cards.append([String(cc.name), r])
		print("HUD4K card %-16s %s" % [String(cc.name), str(r)])
	for i in cards.size():
		for j in range(i + 1, cards.size()):
			if (cards[i][1] as Rect2).intersects(cards[j][1] as Rect2):
				print("HUD4K overlap %s / %s" % [cards[i][0], cards[j][0]])


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	OS.set_environment("PEN_LOOK", "art")
	_room = (load("res://ramon/chickenpen/playable_world.tscn") as PackedScene).instantiate()
	root.add_child(_room)
	current_scene = _room
	root.add_child(RunnerGuard.new())
	await _frames(120)
	var player := _room.get_node("Player") as Node4D
	player.set("input_enabled", false)
	player.global_position = Vector4(24.9, 1.2, 21.0, 0.0)
	print("HUD4K: window %s, canvas %s, UI %s%%" % [str(root.size), str(root.get_visible_rect().size), str(_room.get_node("Systems/UiScale").get("percent"))])
	await _frames(60)
	_report()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + "hud_art.png"))
	_room.get_node("Systems/Look").call("set_dev", true)
	await _frames(40)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + "hud_dev.png"))
	print("HUD4K: DONE")
	quit(0)
