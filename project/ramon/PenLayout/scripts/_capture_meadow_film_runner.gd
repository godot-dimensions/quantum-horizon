extends SceneTree

## Pen layout A (6 Oct 2026, PenLayout/PLAN_A.md step 12): the meadow film played on the pen as it
## now stands, a frame every 4 s, to see whether the cave hill (now just south-west of the meadow)
## gets into its shots. Frames: res://smoke_test_output/pen_layout/meadow_film/.
##
##   CreationLab/scripts/lab_run.sh windowed pl_film res://ramon/PenLayout/scripts/_capture_meadow_film_runner.gd

const FILM := preload("res://ramon/chickenpen/cinematics/cinematic_meadow_4d.gd")
const OUT := "res://smoke_test_output/pen_layout/meadow_film/"


func _initialize() -> void:
	root.unfocusable = true
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var room: Node = (load("res://ramon/chickenpen/playable_world.tscn") as PackedScene).instantiate()
	root.add_child(room)
	current_scene = room
	for i in 60:
		await process_frame
	var film: Node = FILM.new()
	room.add_child(film)
	film.call("play", room)
	var t: float = 0.0
	var next: float = 6.0
	var n: int = 0
	while bool(film.call("is_playing")) and t < 95.0:
		await process_frame
		t += get_root().get_process_delta_time()
		if t >= next:
			root.get_texture().get_image().save_png(OUT + "%02d.png" % n)
			print("FRAME %d at %.1f s" % [n, t])
			n += 1
			next += 4.0
	print("FILM DONE: %d frames" % n)
	quit(0)
