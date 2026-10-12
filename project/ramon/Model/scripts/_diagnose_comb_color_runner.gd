extends SceneTree

## Traces where the comb's red is being lost: the rig's toggle, the ball colours,
## the material identity, or the array that gets written to it.

var _instance: Node
var _done: bool = false


func _initialize() -> void:
	_instance = (load("res://ramon/Model/model.tscn") as PackedScene).instantiate()
	root.add_child(_instance)


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	var rig: Node = _instance.get_node("Models/Chicken/NeckHead")
	print("use_ball_colors = %s" % rig.use_ball_colors)

	var index: int = 0
	for child in rig.get_children():
		if child.has_method("get_loft_section"):
			index += 1
			var c: Color = child.color
			print("   Ball%d colour = (%.2f, %.2f, %.2f)" % [index, c.r, c.g, c.b])

	var material: Material4D = rig.material_override
	print("material = %s  (is TetraMaterial4D: %s)" % [
		material.get_class() if material != null else "none", material is TetraMaterial4D])
	if material != null:
		print("albedo_source = %s  (3 = Texture3D cell UVW only)" % material.get("albedo_source"))
		var mesh: ArrayTetraMesh4D = rig.mesh
		var texture: Texture3D = material.get("albedo_texture_3d")
		print("ramp texture = %s" % ("none" if texture == null else "%d texels" % texture.get_width()))
		var ramp: PackedColorArray = mesh.get_meta("loft_ramp", PackedColorArray()) if mesh != null else PackedColorArray()
		var coords: int = mesh.get_texture_map_values().size() if mesh != null else 0
		print("ramp = %d colours for %d texture coordinates" % [ramp.size(), coords])
		var seen := {}
		for color in ramp:
			seen["%.2f,%.2f,%.2f" % [color.r, color.g, color.b]] = true
		print("distinct colours in the ramp: %s" % [seen.keys()])
	return true
