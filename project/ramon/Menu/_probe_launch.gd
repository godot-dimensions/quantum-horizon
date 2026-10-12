extends SceneTree
## Reproduces a launch FROM THE MENU and screenshots the result.
##
## Exists because the shooting gallery renders correctly when opened directly
## and half black when launched from Menu2 - so the fault is in the launch path,
## not the scene, and neither can be seen by loading the scene on its own.
##
## Captures three things and prints the viewport state alongside each, because
## the two candidate causes both show up there rather than in the picture:
##
##   1. the menu before launching        (baseline)
##   2. the prototype straight after add_child
##   3. the prototype a second later     (after any per-frame settings settle)
##
## Run with the editor CLOSED and WITHOUT --headless:
##
##   godot.windows.editor.double.x86_64.console.exe --path project \
##       --resolution 1280x720 --script res://ramon/Menu/_probe_launch.gd -- 4

const MENU_PATH := "res://ramon/Menu2.tscn"
const OUT_DIR := "res://ramon/Menu/"

var _menu: Node = null
var _entry: int = 4
var _frames: int = 0
var _launched: bool = false


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_entry = int(args[0])
	_menu = (load(MENU_PATH) as PackedScene).instantiate()
	root.add_child(_menu)
	set_current_scene(_menu)


func _report(label: String) -> void:
	var window := root
	print("%s: viewport size %s  transparent_bg %s  scale_mode %d  scale_size %s" % [
		label, str(window.size), str(window.transparent_bg),
		root.content_scale_mode, str(root.content_scale_size)
	])


## Reads back what each material actually has on its cross-section shader.
##
## `uniform vec4 albedo` has no default, so an unset one is vec4(0) - black -
## regardless of what the material's own albedo_color says. This prints the
## value that is really bound, which is the difference between "the shader is
## wrong" and "the shader never got its parameters".
var _dumped: int = 0


func _dump_materials(node: Node, depth: int) -> void:
	if _dumped < 8 and node is MeshInstance4D:
		var material = node.material_override
		if material != null and material.has_method("get_cross_section_material_3d"):
			var cs = material.get_cross_section_material_3d()
			if cs != null:
				var shader_name: String = "none"
				if cs.shader != null:
					shader_name = cs.shader.resource_path.get_file()
				print("  MAT %-26s shader=%-34s albedo=%s" % [
					node.name, shader_name, str(cs.get_shader_parameter("albedo"))
				])
				_dumped += 1
	for child in node.get_children():
		_dump_materials(child, depth + 1)


func _shot(name: String) -> void:
	var image: Image = root.get_texture().get_image()
	if image == null:
		printerr("PROBE: no viewport image")
		return
	image.save_png(ProjectSettings.globalize_path(OUT_DIR + name))
	print("PROBE: wrote ", name)


func _process(_delta: float) -> bool:
	_frames += 1

	if _frames == 40:
		_report("menu    ")
		_shot("probe_1_menu.png")
		return false

	if _frames == 45 and not _launched:
		_launched = true
		print("PROBE: launching entry ", _entry)
		_menu.call("_launch", _entry)
		return false

	# The launch is async - it waits on threaded load - so this has to be well
	# clear of it rather than the next frame.
	if _frames == 140:
		_report("launched")
		_shot("probe_2_after_launch.png")
		return false

	if _frames == 220:
		_report("settled ")
		_shot("probe_3_settled.png")
		_dump_materials(root.get_child(0), 0)
		return false

	# THE EXPERIMENT. Andrew's "Initialize RenderingServer4D and engines at SCENE
	# level" means the rendering server keys off the current scene. The menu adds
	# the prototype as a SIBLING of the current scene rather than becoming it, so
	# the server may still be set up for a 2D menu with no 4D content at all.
	#
	# If promoting the prototype to current_scene fixes the picture, that is the
	# bug and the launch path needs to do it too.
	if _frames == 230:
		var running: Node = root.get_child(0)
		print("PROBE: promoting '%s' to current_scene" % running.name)
		set_current_scene(running)
		return false

	if _frames == 300:
		_report("promoted")
		_shot("probe_4_promoted.png")
		quit(0)
		return true

	return false
