extends SceneTree

## Frames of the menu (design A), no launches: white and dark, list and route, with a few
## prototypes selected, saved to res://smoke_test_output/menu_review/final/<tag>_<palette>_<view>_<n>.png.
## Changes nothing on disk. Runs the master (menu_final.tscn) by default; scene=<path> runs another
## (menu_variations.tscn, with its design set to A) so the two can be compared pixel for pixel.
##
## Arguments after `--`: scene=<res path>, tag=<name> (default "final").
##
##   godot.windows.editor.double.x86_64.console.exe --path project --windowed
##       --resolution 1920x1080 --position 40,40 --script res://ramon/Menu/_capture_menu_final_runner.gd

const OUT := "res://smoke_test_output/menu_review/final/"
const SELECTS: PackedStringArray = ["Shooting Range", "Creature Lab", "The World"]

var _menu: Node
var _t := 0.0
var _f := 0
var _jobs: Array = []
var _job := 0
var _phase := 0
var _tag := "final"
var _route_selects: PackedStringArray = []
var _selects: PackedStringArray = SELECTS


func _initialize() -> void:
	root.unfocusable = true
	# Nor clickable: a stray click on the test window must not launch anything.
	root.gui_disable_input = true
	var scene := "res://ramon/menu_final.tscn"
	for argument in OS.get_cmdline_user_args():
		var pair: PackedStringArray = String(argument).split("=", true, 1)
		if pair.size() != 2:
			continue
		match pair[0]:
			"scene":
				scene = pair[1]
			"tag":
				_tag = pair[1]
			"selects":
				# A "|" separated list of titles: the route view in white for each (the details pane
				# there has one fixed height, so every entry's text has to fit it).
				_route_selects = pair[1].split("|")
	# The variations menu reads its design from here; the master ignores it.
	root.set_meta(&"menu_design", 40)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_menu = load(scene).instantiate()
	root.add_child(_menu)
	current_scene = _menu
	if not _route_selects.is_empty():
		_selects = _route_selects
		for k in _selects.size():
			_jobs.append([true, true, k])
		return
	for light in [true, false]:
		for route in [false, true]:
			for k in SELECTS.size():
				if not route and k > 0:
					continue
				_jobs.append([light, route, k])


## The entry's index, -1 (the menu's HERO) for the world, which is not one of the entries, or
## -2 when nothing has that title.
func _index_of(title: String) -> int:
	var entries: Array = _menu.call("_entries")
	for i in entries.size():
		if String((entries[i] as Resource).get("title")) == title:
			return i
	var hero: Resource = (_menu.get("catalogue") as Resource).get("hero")
	if hero != null and String(hero.get("title")) == title:
		return -1
	return -2


func _process(d: float) -> bool:
	_f += 1
	_t += d
	if _job >= _jobs.size():
		print("MENU FINAL FRAMES: done, %d frames" % _jobs.size())
		quit()
		return true
	var job: Array = _jobs[_job]
	match _phase:
		0:
			if _t > 0.8:
				_menu.set("_light", bool(job[0]))
				# The master calls the view `_route_view`; the frozen variations `_a_route`.
				if _menu.get("_route_view") != null:
					_menu.set("_route_view", bool(job[1]))
				else:
					_menu.set("_a_route", bool(job[1]))
				_menu.call("_apply_palette")
				_menu.call("rebuild")
				_phase = 1
				_t = 0.0
		1:
			if _t > 0.5:
				var i: int = _index_of(_selects[int(job[2])])
				if i >= -1:
					_menu.call("_select", i)
				_phase = 2
				_t = 0.0
		2:
			if _t > 1.2:
				var name := "%s%s_%s_%s_%d.png" % [OUT, _tag, "white" if bool(job[0]) else "dark", "route" if bool(job[1]) else "list", int(job[2])]
				root.get_texture().get_image().save_png(name)
				print("   saved ", name)
				_job += 1
				_phase = 0
				_t = 0.0
	if _f > 20000:
		print("MENU FINAL FRAMES: TIMED OUT at job %d" % _job)
		quit()
		return true
	return false
