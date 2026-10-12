extends SceneTree

## Plan step 70: the two old ranges still open and run beside the new one (nothing of theirs was changed
## to build it). Each scene is opened, run for two seconds and freed; the log is grepped for errors.
##
##   range_run.sh windowed regress res://ramon/QuantumRange/scripts/_regress_runner.gd

const SCENES := [
	"res://sandbox/shooting_gallery/shooting_gallery.tscn",
	"res://ramon/ShootingGalleryRamon/shooting_gallery_ramon.tscn",
	"res://ramon/QuantumRange/quantum_range_final.tscn",
]

var _t0: int = 0


func _initialize() -> void:
	root.unfocusable = true
	_t0 = Time.get_ticks_msec()
	_run.call_deferred()


func _process(_x: float) -> bool:
	if Time.get_ticks_msec() - _t0 > 90000:
		print("REGRESS: gave up after 90 s")
		return true
	return false


func _run() -> void:
	for path in SCENES:
		var ps: PackedScene = load(path) as PackedScene
		if ps == null:
			print("FAIL  ", path, " does not load")
			continue
		var n: Node = ps.instantiate()
		root.add_child(n)
		current_scene = n
		await create_timer(2.0).timeout
		print("PASS  ", path, " ran 2 s (", n.get_child_count(), " children)")
		n.queue_free()
		await process_frame
		await process_frame
	print("REGRESS: done")
	quit()
