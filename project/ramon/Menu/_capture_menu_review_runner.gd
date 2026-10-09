extends SceneTree

## Frames of a menu for review (8 Oct). Changes nothing: it opens the menu, selects the banner
## and then each listed entry in turn, scrolls its row into view, and saves what is on screen
## to res://smoke_test_output/menu_review/<tag>_<n>_<what>.png.
##
## Also prints the list's height against its window, and what each shown entry has as its
## preview (clip, sprite sheet or none).
##
## Arguments after `--`: scene=<res path> (default menu_final), tag=<name> (default "final").
## The same run on menu_final_temp.tscn gives the before frames.
##
## Small, never focused:
##   godot.windows.editor.double.x86_64.console.exe --path project --windowed
##       --resolution 1920x1080 --position 40,40 --script res://ramon/Menu/_capture_menu_review_runner.gd
##       -- scene=res://ramon/menu_final_temp.tscn tag=temp

const OUT := "res://smoke_test_output/menu_review/"
const SHOTS := ["Crosswise", "Shooting Range", "Voxel Lab", "Botany Lab", "Creation Lab", "Flight of the 4D Starlings"]

var _menu: Node
var _scene := "res://ramon/menu_final.tscn"
var _tag := "final"
var _t := 0.0
var _f := 0
var _step := 0
var _shot := 0
var _n := 0


func _initialize() -> void:
	root.unfocusable = true
	# Nor clickable: a stray click on the test window (PLAY THE WORLD) once swapped the menu out mid-run.
	root.gui_disable_input = true
	for argument in OS.get_cmdline_user_args():
		var pair: PackedStringArray = String(argument).split("=", true, 1)
		if pair.size() == 2 and pair[0] == "scene":
			_scene = pair[1]
		elif pair.size() == 2 and pair[0] == "tag":
			_tag = pair[1]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_menu = load(_scene).instantiate()
	root.add_child(_menu)
	current_scene = _menu


func _save(what: String) -> void:
	var path := "%s%s_%d_%s.png" % [OUT, _tag, _n, what.to_lower().replace(" ", "_")]
	root.get_texture().get_image().save_png(path)
	print("   saved %s" % path)
	_n += 1


func _scroll() -> ScrollContainer:
	var found: Array[Node] = _menu.find_children("*", "ScrollContainer", true, false)
	return found[0] as ScrollContainer if not found.is_empty() else null


## Selects the entry by title, scrolled into view. False when the menu does not list it.
func _show(title: String) -> bool:
	var entries: Array = _menu.call("_entries")
	for i in entries.size():
		if String((entries[i] as Resource).get("title")) == title:
			_menu.call("_select", i)
			var rows: Array = _menu.get("_rows")
			var scroll := _scroll()
			if scroll != null and i < rows.size() and rows[i] != null:
				scroll.ensure_control_visible(rows[i])
			return true
	return false


func _report() -> void:
	var scroll := _scroll()
	if scroll != null:
		var content := scroll.get_child(0) as Control
		print("  list window %.0f px tall, list content %.0f px: %.0f%% visible without scrolling"
			% [scroll.size.y, content.size.y, 100.0 * scroll.size.y / maxf(1.0, content.size.y)])
	var dir := "res://ramon/Menu/thumbs/"
	var titles: Array[String] = []
	for i in (_menu.get("_order") as Array):
		var entry: Resource = _menu.call("_entry", i)
		var clip := String(entry.get("clip"))
		var what := "no video"
		if clip != "" and FileAccess.file_exists("%s%s.ogv" % [dir, clip]):
			what = "clip %s.ogv" % clip
		elif clip != "" and FileAccess.file_exists("%s%s_loop.png" % [dir, clip]):
			what = "sprite sheet"
		var category = entry.get("category")
		print("  %-28s %-20s %s" % [String(entry.get("title")), String(category) if category != null else "-", what])
		titles.append(String(entry.get("title")))
	print("  screen order: %s" % [titles])


func _process(d: float) -> bool:
	_f += 1
	_t += d
	match _step:
		0:
			if _t > 2.0:
				_report()
				_save("banner")
				_step = 1; _t = 0.0
		1:
			if _shot >= SHOTS.size():
				print("MENU REVIEW %s: done, %d frames" % [_tag, _n])
				quit()
				return true
			if _show(SHOTS[_shot]):
				_step = 2; _t = 0.0
			else:
				print("  (%s is not on this menu)" % SHOTS[_shot])
				_shot += 1
		2:
			if _t > 1.2:
				_save(SHOTS[_shot])
				_shot += 1
				_step = 1; _t = 0.0
	if _f > 8000:
		print("MENU REVIEW %s: TIMED OUT at step %d" % [_tag, _step])
		quit()
		return true
	return false
