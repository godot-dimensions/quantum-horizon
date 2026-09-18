extends SceneTree
func _initialize() -> void:
	var p := load("res://ramon/Model/rigged_creature_ramon.tscn")
	print("loaded: %s" % (p != null))
	quit()
