extends SceneTree

## Loads the pen's scene file and says whether it parses (a check after hand edits to playable_world.tscn).
##   lab_run.sh headless pen_load res://ramon/WTools/tests/_load_pen_check_runner.gd


func _initialize() -> void:
	var s: Resource = load("res://ramon/chickenpen/playable_world.tscn")
	print("PEN LOAD: %s" % ("ok" if s != null else "FAILED"))
	quit(0 if s != null else 1)
