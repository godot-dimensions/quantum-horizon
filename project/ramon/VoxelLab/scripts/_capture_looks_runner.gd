extends SceneTree
## Voxel Lab, plan steps 29, 30, 42 and 73: the look of the room, in grey and then in black. The same
## views in each: the way in, the shelf up close, the block from the bench pad with its story's title
## cards (each part in turn), the column, the gallery and each of Andrew's specimens. Frames to
## smoke_test_output/voxel_lab/looks/<palette>_<view>.png; then contact sheets are made from them
## (VoxelLab/tools/contact_sheet.py).
##   VoxelLab/run.sh windowed looks res://ramon/VoxelLab/scripts/_capture_looks_runner.gd

const OUT := "res://smoke_test_output/voxel_lab/looks/"
const Style := preload("res://ramon/VoxelLab/carried/kit/kit_style.gd")

## [name, where (x, z), facing (degrees), seconds to settle]
const VIEWS := [
	["entrance", Vector2(0, 21.0), 0.0, 1.6],
	["junction", Vector2(0, 9.0), 0.0, 1.4],
	["shelf", Vector2(6.2, 5.4), -90.0, 1.6],
	["block", Vector2(0, 3.0), 0.0, 1.6],
	["walls", Vector2(0, -4.0), 0.0, 1.6],
	["column", Vector2(-5.1, -5.0), 90.0, 1.6],
	["gallery", Vector2(0, -17.0), 0.0, 1.6],
	["terrain", Vector2(0, -23.5), 90.0, 1.6],
	["ladder", Vector2(4.4, -23.5), -90.0, 1.6],
	["field_door", Vector2(0, -26.5), 0.0, 1.6],
]

var _scene: Node
var _t: float = 0.0
var _total: float = 0.0
var _i: int = 0
var _pass: int = 0
var _phase: String = "wait"
var _part: int = 0


func _initialize() -> void:
	root.unfocusable = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_open.call_deferred()


func _open() -> void:
	_scene = (load("res://ramon/VoxelLab/voxel_lab.tscn") as PackedScene).instantiate()
	root.add_child(_scene)
	current_scene = _scene


func _ready_all() -> bool:
	for s in _scene.get("stations"):
		var ex: Node = s.get("exhibit")
		if ex == null or not bool(ex.call("is_ready")):
			return false
	return true


func _palette() -> String:
	return "grey" if _pass == 0 else "black"


func _process(delta: float) -> bool:
	_total += delta
	if _total > 300.0:
		print("LOOKS FAIL: timed out in %s %d" % [_phase, _i])
		return true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _scene == null or not _scene.is_inside_tree() or _scene.get("player") == null:
		return false
	_scene.get("player").set("input_enabled", false)
	_t += delta
	match _phase:
		"wait":
			if _ready_all() and _t > 2.0 and not bool(current_scene.get("loading")):
				_phase = "views"
				_go()
			elif _t > 120.0:
				print("LOOKS FAIL: not ready")
				return true
		"views":
			var v: Array = VIEWS[_i]
			if _t > float(v[3]):
				_save("%s_%02d_%s" % [_palette(), _i, String(v[0])])
				_i += 1
				if _i >= VIEWS.size():
					# The block's story, from the bench pad, part by part.
					_phase = "story"
					_part = 0
					_scene.call("go_to", Vector4(0, 0.05, 3.0, 0), 0.0)
					_scene.call("watch", _scene.get_node("Hero"))
				else:
					_go()
				_t = 0.0
		"story":
			var hero: Node = _scene.get_node("Hero")
			var seqs: Array = hero.call("sequences")
			if _t > 0.6 and int(hero.get("seq_index")) == _part and float(hero.get("seq_t")) > float(seqs[_part]["length"]) * 0.62:
				_save("%s_story_%d_%s" % [_palette(), _part, String(seqs[_part]["key"])])
				_part += 1
				if _part >= seqs.size():
					_phase = "next"
				_t = 0.0
			elif _t > 40.0:
				print("LOOKS FAIL: the story stalled at part %d (playing %d)" % [_part, int(hero.get("seq_index"))])
				_phase = "next"
		"next":
			if _pass == 0:
				_pass = 1
				_scene.call("toggle_palette")
				_i = 0
				_t = 0.0
				_phase = "views"
				_go()
			else:
				print("LOOKS done")
				return true
	return false


func _go() -> void:
	var v: Array = VIEWS[_i]
	var at: Vector2 = v[1]
	_scene.call("go_to", Vector4(at.x, 0.05, at.y, 0.0), deg_to_rad(float(v[2])))


func _save(name: String) -> void:
	var image: Image = root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
	print("LOOKS saved %s" % name)
