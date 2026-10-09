extends SceneTree
## Voxel Lab (9 Oct): the Tab panel's windows, their sizes printed and the screen saved (a probe).
##   VoxelLab/run.sh windowed probe_tab res://ramon/VoxelLab/field/_probe_tab_runner.gd

var _f: Node
var _t: float = 0.0
var _done: bool = false


func _initialize() -> void:
	root.unfocusable = true
	_open.call_deferred()


func _open() -> void:
	_f = (load("res://ramon/VoxelLab/field/voxel_field.tscn") as PackedScene).instantiate()
	root.add_child(_f)
	current_scene = _f


func _dump(n: Node, depth: int) -> void:
	if depth > 4:
		return
	if n is Control:
		var c := n as Control
		print("TAB %s%s %s pos %s size %s min %s visible %s" % ["  ".repeat(depth), c.name, c.get_class(), str(c.position), str(c.size), str(c.get_combined_minimum_size()), c.visible])
	for ch in n.get_children():
		_dump(ch, depth + 1)


func _process(delta: float) -> bool:
	_t += delta
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _f == null or _f.get("player") == null or bool(_f.get("loading")):
		return _t > 90.0
	var p: Control = _f.get("sea_panel")
	if not p.visible:
		p.call("toggle")
		_t = 0.0
		return false
	if _t > 1.0 and not _done:
		_done = true
		_dump(p, 0)
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://smoke_test_output/voxel_lab/field_play/tab_probe.png"))
		print("TAB done")
		return true
	return false
