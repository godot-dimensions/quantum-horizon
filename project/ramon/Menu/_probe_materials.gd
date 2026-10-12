extends SceneTree
## Dumps what is ACTUALLY bound to every 4D material in the shooting gallery,
## loaded either directly or via the menu's launch path, so the two can be
## compared side by side.
##
## The question it answers: when the gallery is launched from Menu2 some
## surfaces render and most do not. Reading the material back tells us whether
## the ones that fail differ in material CLASS, in which shader is bound, or in
## the albedo they were given - which are three completely different bugs.
##
##   ... --script res://ramon/Menu/_probe_materials.gd -- direct
##   ... --script res://ramon/Menu/_probe_materials.gd -- menu

const GALLERY := "res://ramon/ShootingGalleryRamon/shooting_gallery_ramon.tscn"
const MENU := "res://ramon/Menu2.tscn"
const GALLERY_ENTRY := 7

var _mode: String = "direct"
var _frames: int = 0
var _root_node: Node = null
var _launched: bool = false


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_mode = args[0]

	if _mode == "direct":
		_root_node = (load(GALLERY) as PackedScene).instantiate()
		root.add_child(_root_node)
		set_current_scene(_root_node)
	else:
		_root_node = (load(MENU) as PackedScene).instantiate()
		root.add_child(_root_node)
		set_current_scene(_root_node)
	print("MODE: ", _mode)


func _process(_delta: float) -> bool:
	_frames += 1

	if _mode == "menu" and _frames == 40 and not _launched:
		_launched = true
		_root_node.call("_launch", GALLERY_ENTRY)
		return false

	var dump_at: int = 90 if _mode == "direct" else 200
	if _frames < dump_at:
		return false

	var target: Node = _root_node if _mode == "direct" else root.get_child(0)
	var counts: Dictionary = {}
	_walk(target, counts)
	print("--- summary for ", _mode, " ---")
	for key in counts:
		print("  %4d  %s" % [counts[key], key])
	quit(0)
	return true


## Groups every MeshInstance4D by (material class, bound shader), because the
## interesting question is not one node's state but whether the failing surfaces
## form a class of their own.
func _walk(node: Node, counts: Dictionary) -> void:
	if node is MeshInstance4D:
		var material = node.material_override
		var key: String
		if material == null:
			key = "no material_override"
		else:
			var class_name_str: String = material.get_class()
			var shader_desc: String = "n/a"
			if material.has_method("get_cross_section_material_3d"):
				var cs = material.get_cross_section_material_3d()
				if cs == null:
					shader_desc = "cross-section material NULL"
				elif cs.shader == null:
					shader_desc = "shader NULL"
				else:
					var path: String = cs.shader.resource_path
					shader_desc = path.get_file() if path != "" else "ENGINE BUILT-IN"
			key = "%s  ->  %s" % [class_name_str, shader_desc]
		counts[key] = counts.get(key, 0) + 1
	for child in node.get_children():
		_walk(child, counts)
