extends SceneTree

## The HUD stays on top of the projection (Ramon, 3 Oct: "when you press P why does the hud
## dissapear?"): P in the pen, then the Combined renderer's own canvas layer checked to be behind
## the HUD's canvas (layer < 0), the HUD still showing, and a frame saved to look at:
## res://smoke_test_output/projection_hud.png. Gives up after 40 s.
##
##   godot... --path project --windowed --resolution 1280x720 --position 40,40
##       --script res://ramon/chickenpen/lookout/_verify_projection_hud_runner.gd

var _room: Node
var _t: float = 0.0
var _step: int = -1
var _fails: int = 0


func _initialize() -> void:
	root.unfocusable = true
	_room = load("res://ramon/chickenpen/playable_world.tscn").instantiate()
	root.add_child(_room)
	current_scene = _room


func _check(what: String, ok: bool, detail: String = "") -> void:
	if not ok:
		_fails += 1
	print("   %s %-46s %s" % ["PASS" if ok else "FAIL", what, detail])


func _process(d: float) -> bool:
	_t += d
	if _t > 40.0:
		print("PROJECTION HUD FAIL: timed out")
		return true
	match _step:
		-1:
			if _t < 9.0:
				return false
			var key := InputEventKey.new()
			key.keycode = KEY_P
			key.physical_keycode = KEY_P
			key.pressed = true
			Input.parse_input_event(key)
			_step = 0
			_t = 0.0
		0:
			if _t < 1.5:
				return false
			_check("P turned the projection on in the pen", bool(_room.get_node("Systems/Lookout").get("projection")))
			var layers: Array = []
			for child in root.get_children():
				if child is CanvasLayer:
					for rect in child.get_children():
						if rect is TextureRect and (rect as TextureRect).texture is ViewportTexture:
							layers.append((child as CanvasLayer).layer)
							break
			_check("the projection's picture is behind the HUD", not layers.is_empty() and layers.max() < 0, "layers %s" % str(layers))
			_check("the HUD is showing", (_room.get_node("UI/Controls") as CanvasItem).is_visible_in_tree())
			root.get_texture().get_image().save_png("res://smoke_test_output/projection_hud.png")
			print("PROJECTION HUD %s" % ("PASS" if _fails == 0 else "FAIL (%d)" % _fails))
			return true
	return false
