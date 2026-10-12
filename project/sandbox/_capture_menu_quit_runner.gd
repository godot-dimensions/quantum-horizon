extends SceneTree
## Is the QUIT button actually on screen, and does it sit clear of the deck?
var _f := 0
var _held := 0.0
var _menu: Node = null
func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
func _process(d: float) -> bool:
	_f += 1
	if _f == 1:
		_menu = (load("res://ramon/menu_final.tscn") as PackedScene).instantiate()
		root.add_child(_menu); current_scene = _menu
		return false
	_held += d
	if _held < 2.5:
		return false
	var b: Button = _menu.find_child("QuitButton", true, false) as Button
	if b == null:
		print("  FAIL - no QuitButton in the menu")
		quit(1); return true
	print("  QUIT button: visible=%s  rect=%s  window=%s" % [
			b.is_visible_in_tree(), b.get_global_rect(), root.size])
	root.get_texture().get_image().save_png("user://menu_quit.png")
	quit(0)
	return true
