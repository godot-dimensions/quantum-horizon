extends SceneTree
## Does the display case now turn through W on a right drag, and in the slice on a left drag?
var _f := 0
var _held := 0.0
var _root: Node = null
func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
func _process(d: float) -> bool:
	_f += 1
	if _f == 1:
		_root = (load("res://ramon/WaterLab/water_lab.tscn") as PackedScene).instantiate()
		root.add_child(_root); current_scene = _root
		return false
	_held += d
	if _held < 3.0:
		return false
	var case: Node = _root.get_node_or_null(^"Showcase")
	if case == null:
		print("  FAIL - no Showcase node"); quit(1); return true
	var has_w: bool = case.has_method("turn_w_by")
	var has_3d: bool = case.has_method("turn_by")
	print("  turn_w_by (4D, right drag): %s" % has_w)
	print("  turn_by   (3D, left drag):  %s" % has_3d)
	# Put the player at the case so the lab makes it active, then check the lab routes drags.
	var player: Node4D = _root.get("player")
	player.global_position = Vector4(10.0, player.global_position.y, 0.0, 0.0)
	_root.call(&"_find_active", player.global_position)
	var active: Node = _root.get("active")
	print("  standing at the case -> active = %s" % ("the Showcase" if active == case else str(active)))
	var before_w: Vector2 = case.get(&"turn_w")
	var before_3d: Vector2 = case.get(&"turn")
	var right := InputEventMouseMotion.new()
	right.relative = Vector2(40.0, 0.0)
	right.button_mask = MOUSE_BUTTON_MASK_RIGHT
	_root.call(&"_input", right)
	var left := InputEventMouseMotion.new()
	left.relative = Vector2(40.0, 0.0)
	left.button_mask = MOUSE_BUTTON_MASK_LEFT
	_root.call(&"_input", left)
	var dw: Vector2 = (case.get(&"turn_w") as Vector2) - before_w
	var d3: Vector2 = (case.get(&"turn") as Vector2) - before_3d
	print("  after a right drag: turn_w moved %s" % dw)
	print("  after a left drag:  turn   moved %s" % d3)
	var ok: bool = has_w and has_3d and active == case and dw.length() > 0.0001 and d3.length() > 0.0001
	print("")
	print("  %s" % ("PASS - right drag turns it through W, left drag turns it in the slice."
			if ok else "FAIL - see above."))
	quit(0 if ok else 1)
	return true
