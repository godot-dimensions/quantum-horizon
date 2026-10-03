extends SceneTree

## The Lookout's HUD card is only there at the Lookout ("tower subgame should change the hud,
## but it should never carry over"): the player in the pen, by the tower, by Wren, back in the
## pen. Prints whether the card shows at each, and saves the HUD: res://smoke_test_output/
## card_local_<n>_<where>.png.
##
##   godot... --path project --windowed --resolution 2560x1440 --position 0,0
##       --script res://ramon/chickenpen/lookout/_verify_card_local_runner.gd

var _room: Node
var _grass: Node
var _player: Node4D
var _card: Control
var _t: float = 0.0
var _step: int = -1
var _fails: int = 0
var _spots: Array = []


func _initialize() -> void:
	root.unfocusable = true
	_room = load("res://ramon/chickenpen/chickenpen.tscn").instantiate()
	_room.get_node("Systems/Lookout").set("journal_path", "user://lookout_journal_card_local_test.cfg")
	_grass = _room.get_node("World/Grass")
	root.add_child(_room)
	current_scene = _room


func _process(d: float) -> bool:
	_t += d
	if _step < 0:
		if not bool(_grass.get("mask_ready")) or _t < 5.0:
			return false
		_player = _room.get_node("Player") as Node4D
		_card = _room.get_node("UI/Journal") as Control
		# Met Wren already, so walking up to the tower plays no cutscene.
		for f in ["approached", "met_wren"]:
			_room.get_node("Systems/Lookout").get("journal").call("set_flag", f, true)
		var tower: Vector4 = (_room.get_node("World/LookoutSite/Lookout") as Node4D).global_position
		var wren: Vector4 = (_room.get_node("World/LookoutSite/Wren") as Node4D).global_position
		_spots = [["pen", _player.global_position, false], ["tower", tower + Vector4(4.0, 0.05, 6.0, 0.0), true],
			["wren", wren + Vector4(1.5, 0.05, 2.0, 0.0), true], ["pen_again", Vector4(2.0, 0.05, 4.0, 0.0), false]]
		_step = 0
		_go()
		return false
	if _t < 1.4:
		return false
	var spot: Array = _spots[_step]
	var shown: bool = _card.visible and _card.modulate.a > 0.5
	var ok: bool = shown == bool(spot[2])
	if not ok:
		_fails += 1
	print("      %-10s card %s (want %s)  %s" % [spot[0], "shown" if shown else "hidden", "shown" if spot[2] else "hidden", "ok" if ok else "FAIL"])
	root.get_texture().get_image().save_png("res://smoke_test_output/card_local_%d_%s.png" % [_step, spot[0]])
	_step += 1
	if _step >= _spots.size():
		print("CARD LOCAL %s" % ("PASS" if _fails == 0 else "FAIL (%d)" % _fails))
		if FileAccess.file_exists("user://lookout_journal_card_local_test.cfg"):
			DirAccess.remove_absolute(ProjectSettings.globalize_path("user://lookout_journal_card_local_test.cfg"))
		return true
	_go()
	return false


func _go() -> void:
	_player.global_position = _spots[_step][1]
	_t = 0.0
