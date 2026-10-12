extends SceneTree
func _initialize() -> void:
	var packed := load("res://ramon/Model/animation_test.tscn") as PackedScene
	if packed == null:
		print("FAILED to load"); quit(1); return
	var n := packed.instantiate()
	var names: Array = []
	for c in n.get_children(): names.append("%s (%s)" % [c.name, c.get_class()])
	print("animation_test.tscn loads: %s" % [", ".join(names)])
	quit()
