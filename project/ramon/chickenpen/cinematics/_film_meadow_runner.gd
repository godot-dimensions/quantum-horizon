extends SceneTree

## Cinematic 2, the meadow (cinematic_meadow_4d.gd), played in the pen and recorded by the
## movie writer, as _film_flock_runner.gd does the starlings. Started at once, the way the
## menu starts it: the title holds until the grass has grown in.
##
##   godot... --path project --resolution 1920x1080 --write-movie <out>.avi --fixed-fps 30
##       --script res://ramon/chickenpen/cinematics/_film_meadow_runner.gd
##
## Or, for single frames to look at: --write-movie <dir>/meadow.png at a small size.

var _room: Node
var _f: int = 0


func _initialize() -> void:
	root.unfocusable = true
	_room = load("res://ramon/chickenpen/playable_world.tscn").instantiate()
	for node in _room.find_children("*", "", true, false):
		if "debug_key_enabled" in node:
			node.set("debug_key_enabled", false)
	root.add_child(_room)
	current_scene = _room


func _process(_d: float) -> bool:
	_f += 1
	if _f == 2:
		var cinematics: Node = _room.get_node("Cinematics")
		cinematics.connect("finished", func(_id: String) -> void: quit())
		if not bool(cinematics.call("play", "meadow")):
			print("FILM: could not start the cinematic")
			quit()
	return false
