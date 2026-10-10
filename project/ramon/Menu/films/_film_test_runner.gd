extends SceneTree

## Smoke test for the film kit: records 1 s of the menu (no 4D), so film_run.sh and film_kit.gd can be
## checked in a minute.  film_run.sh _test res://ramon/Menu/films/_film_test_runner.gd

const Kit := preload("res://ramon/Menu/films/film_kit.gd")

var _kit: RefCounted


func _initialize() -> void:
	var out: String = ""
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("out="):
			out = String(a).substr(4)
	_kit = Kit.new(self, out)
	_kit.calm_window()
	var menu: Node = load("res://ramon/menu_final.tscn").instantiate()
	root.add_child(menu)
	_run.call_deferred()


func _run() -> void:
	await _kit.skip(20)
	_kit.recording = true
	await _kit.hold(30)
	print("FILM test: %d frames" % _kit.count)
	quit()
