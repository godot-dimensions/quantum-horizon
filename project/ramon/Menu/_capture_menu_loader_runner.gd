extends SceneTree

## Frames of the menu's loading screen (menu_load_board.gd) without launching anything: the menu's
## own _show_overlay() for a few entries, at a loading percentage and at BUILDING THE SCENE, then the
## white of its finish; and, for the style beside it, the Voxel Lab's own board drawn on its own (its
## drawing only, the lab is not loaded). Saved to res://smoke_test_output/menu_review/loader/.
##
##   godot.windows.editor.double.x86_64.console.exe --path project --windowed
##       --resolution 1920x1080 --position 40,40 --script res://ramon/Menu/_capture_menu_loader_runner.gd

const OUT := "res://smoke_test_output/menu_review/loader/"
const LAB_BOARD := "res://ramon/VoxelLab/room/vl_load_board.gd"

var _menu: Node
var _t := 0.0
var _f := 0
var _jobs: Array = []
var _job := 0
var _phase := 0
var _lab: Control = null


func _initialize() -> void:
	root.unfocusable = true
	root.gui_disable_input = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_menu = load("res://ramon/menu_final.tscn").instantiate()
	root.add_child(_menu)
	current_scene = _menu
	# [title, progress, stage, name]
	_jobs = [
		["Shooting Range", 0.42, "LOADING", "shooting_range_loading"],
		["Voxel Lab", 1.0, "BUILDING THE SCENE", "voxel_lab_building"],
		["Creature Lab", 0.7, "LOADING", "creature_lab_loading"],
		["The World", 0.15, "LOADING", "world_loading"],
		["Shooting Range", 1.0, "WHITE", "shooting_range_white"],
		["", 0.0, "LAB", "voxel_lab_own_board"],
	]


func _index_of(title: String) -> int:
	var entries: Array = _menu.call("_entries")
	for i in entries.size():
		if String((entries[i] as Resource).get("title")) == title:
			return i
	return -1


func _process(d: float) -> bool:
	_f += 1
	_t += d
	if _job >= _jobs.size():
		print("MENU LOADER FRAMES: done, %d frames" % _jobs.size())
		quit()
		return true
	var job: Array = _jobs[_job]
	var board: Control = _menu.get("_overlay")
	match _phase:
		0:
			if _t > 0.8:
				if String(job[2]) == "LAB":
					board.call("close_now")
					var layer := CanvasLayer.new()
					layer.layer = 30
					root.add_child(layer)
					_lab = Control.new()
					_lab.set_script(load(LAB_BOARD))
					layer.add_child(_lab)
					_lab.set("kicker", "QUANTUM HORIZON  ·  THE ENGINE'S OWN VOXELS")
					_lab.set("title", "VOXEL LAB")
					_lab.set("subtitle", "Cutting 4D matter")
					_lab.set("coming", ["A block of 4D rock: watch it cut, or cut it yourself", "Sections, a 4D builder, the numbers of every cut", "Behind it: how our world is made, and the door into it"])
					_lab.set("diagram_title", "SPECIMENS, BUILT BY THE ENGINE AS YOU WAIT")
					_lab.set("bars", [["Block", 1.0, "212k"], ["Sections", 0.6, "88k"], ["Builder", 0.25, "40k"]])
					_lab.set("numbers", [["Specimens built", "1 of 3"], ["Tetrahedra", "340,112"], ["Video memory", "415 MB"]])
					_lab.set("progress", 0.33)
				else:
					var i: int = _index_of(String(job[0]))
					_menu.call("_select", i if i >= 0 else -1)
					_menu.call("_show_overlay", _menu.call("_selected_entry"), "")
					board.set("progress", float(job[1]))
					if String(job[2]) != "WHITE":
						board.set("stage", String(job[2]))
				_phase = 1
				_t = 0.0
		1:
			if String(job[2]) == "WHITE" and _t > 0.3 and _t < 0.35:
				board.call("finish")
			if _t > (0.62 if String(job[2]) == "WHITE" else 0.6):
				var name := "%s%s.png" % [OUT, String(job[3])]
				root.get_texture().get_image().save_png(name)
				print("   saved ", name)
				board.call("close_now")
				_job += 1
				_phase = 0
				_t = 0.0
	if _f > 20000:
		print("MENU LOADER FRAMES: TIMED OUT at job %d" % _job)
		quit()
		return true
	return false
