extends SceneTree

## The team film: cinematic 1 (cinematics/cinematic_murmuration_4d.gd) played in the pen
## and recorded by the movie writer, which steps at a fixed rate, so the film is smooth
## whatever the machine does. Everything you see and hear - letterbox, title, shots, captions,
## the music and the flock - is the cinematic's own; this only starts it and stops recording
## when it ends, so the film and the menu's "1" cannot drift apart.
##
##   godot... --path project --resolution 1920x1080 --write-movie <out>.avi --fixed-fps 30
##       --script res://ramon/chickenpen/scripts/_film_flock_runner.gd
##
## Then encode the .avi to an .mp4 (no mixing needed - the sound is the game's); finished
## films go in res://smoke_test_output/video/, which git ignores.

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
		if not bool(cinematics.call("play", "murmuration")):
			print("FILM: could not start the cinematic")
			quit()
	return false
