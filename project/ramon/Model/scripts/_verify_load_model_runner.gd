extends SceneTree
## The gallery still has to open after the brachiosaurus moved out of it.
func _initialize() -> void:
	var s := load("res://ramon/Model/model.tscn")
	var n: Node = s.instantiate() if s else null
	print("model.tscn loaded: %s, top-level models: %s" % [n != null,
		str(n.get_node("Models").get_children().map(func(c): return c.name)) if n and n.has_node("Models") else "?"])
	quit()
