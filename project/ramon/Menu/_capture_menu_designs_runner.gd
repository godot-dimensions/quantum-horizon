extends SceneTree

## The design review's frames (8 Oct): every design in menu_final, in the grey palette and the
## LAB one, with the same prototype selected, saved to
## res://smoke_test_output/menu_review/designs/d<n>_<grey|lab|white|black>.png (0 to 9 grey and
## LAB, 10 to 19 white and near black). Changes nothing on disk.
##
## Arguments after `--`: select=<title> (default Shooting Range), only=<n> (one design),
## tag=<suffix> for the file names, hud=1 to show the design HUD (Tab), group=1 to group by the
## RFP's questions (G) instead of the map's systems, route=1 for "A" in its route view.
##
##   godot.windows.editor.double.x86_64.console.exe --path project --windowed
##       --resolution 1920x1080 --position 40,40 --script res://ramon/Menu/_capture_menu_designs_runner.gd

## Since 9 Oct the designs live only in the frozen reference menu (menu_final is A alone).
const MENU := "res://ramon/menu_variations.tscn"
const OUT := "res://smoke_test_output/menu_review/designs/"

var _menu: Node
var _t := 0.0
var _f := 0
var _jobs: Array = []
var _job := 0
var _phase := 0
var _select := "Shooting Range"
var _tag := ""
var _hud := false
var _group := 0


func _initialize() -> void:
	root.unfocusable = true
	# Nor clickable: a stray click on the test window (PLAY THE WORLD) once swapped the menu out mid-run.
	root.gui_disable_input = true
	var only := -1
	for argument in OS.get_cmdline_user_args():
		var pair: PackedStringArray = String(argument).split("=", true, 1)
		if pair.size() != 2:
			continue
		match pair[0]:
			"select":
				_select = pair[1]
			"only":
				only = int(pair[1])
			"tag":
				_tag = "_" + pair[1]
			"hud":
				_hud = pair[1] == "1"
			"group":
				_group = int(pair[1])
			"route":
				root.set_meta(&"menu_a_route", pair[1] == "1")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_menu = load(MENU).instantiate()
	root.add_child(_menu)
	current_scene = _menu
	var count: int = (_menu.get("DESIGN_NAMES") as PackedStringArray).size()
	for d in range(0, count):
		if only >= 0 and d != only:
			continue
		if not bool(_menu.call("_design_available", d)):
			continue
		for bright in [false, true]:
			_jobs.append([d, bright])


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
		print("MENU DESIGNS: done, %d frames" % _jobs.size())
		quit()
		return true
	var job: Array = _jobs[_job]
	match _phase:
		0:
			if _t > 1.0:
				_menu.set("_hud_open", _hud)
				_menu.set("_taxonomy", _group)
				# The design first: the palette depends on it (designs 0 to 9: grey or LAB;
				# 10 to 19: near black or white).
				_menu.set("design", int(job[0]))
				_menu.set("_bright", bool(job[1]))
				_menu.set("_light", bool(job[1]))
				_menu.call("_apply_palette")
				_phase = 1
				_t = 0.0
		1:
			if _t > 0.4:
				_menu.call("rebuild")
				var i: int = _index_of(_select)
				if i >= 0:
					_menu.call("_select", i)
				_phase = 2
				_t = 0.0
		2:
			if _t > 0.9:
				var palette_name: String = ("white" if bool(job[1]) else "black") if int(job[0]) >= 10 else ("lab" if bool(job[1]) else "grey")
				if int(_menu.get("design")) != int(job[0]):
					print("   (design %d did not take)" % int(job[0]))
				var path := "%sd%d_%s%s.png" % [OUT, int(job[0]), palette_name, _tag]
				root.get_texture().get_image().save_png(path)
				var scroll = _menu.get("_list_scroll")
				var fits := ""
				if is_instance_valid(scroll) and scroll.get_child_count() > 0:
					fits = "list %.0f of %.0f px" % [scroll.size.y, (scroll.get_child(0) as Control).size.y]
				print("   saved %s   %s" % [path, fits])
				_job += 1
				_phase = 0
				_t = 0.0
	if _f > 20000:
		print("MENU DESIGNS: TIMED OUT")
		quit()
		return true
	return false
