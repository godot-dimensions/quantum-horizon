extends SceneTree

## Bakes the grass's ground heights (grass/grass_heights_4d.gd) from the pen's terrain as it stands, to
## grass/baked/grass_heights.res. Again after any hill or mound is moved (the grass says so when one has).
##
##   lab_run.sh headless grass_heights res://ramon/chickenpen/grass/_bake_grass_heights_runner.gd

const Heights := preload("res://ramon/chickenpen/grass/grass_heights_4d.gd")

var _t0: int = 0


func _initialize() -> void:
	_t0 = Time.get_ticks_msec()
	_run.call_deferred()


func _process(_d: float) -> bool:
	if Time.get_ticks_msec() - _t0 > 600000:
		print("GRASS HEIGHTS: gave up")
		return true
	return false


func _run() -> void:
	var room: Node = (load("res://ramon/chickenpen/playable_world.tscn") as PackedScene).instantiate()
	for node in room.find_children("*", "", true, false):
		if "debug_key_enabled" in node:
			node.set("debug_key_enabled", false)
	root.add_child(room)
	current_scene = room
	# The terrain's even-green meshes go on a frame or two in (pen_grass_4d.gd _even_to_terrain).
	for i in 30:
		await process_frame
	var pieces: Array = Heights.meshes(room)
	print("GRASS HEIGHTS: %d terrain meshes" % pieces.size())
	for mi in pieces:
		print("   %s" % room.get_path_to(mi))
	var started: int = Time.get_ticks_msec()
	var image: Image = Heights.bake(room)
	var took: float = (Time.get_ticks_msec() - started) / 1000.0
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(Heights.BAKED.get_base_dir()))
	var err: int = ResourceSaver.save(image, Heights.BAKED, ResourceSaver.FLAG_COMPRESS)
	# How much of each layer stands above the flat ground, and the highest point.
	var data: PackedFloat32Array = image.get_data().to_float32_array()
	var top: float = 0.0
	var per_layer := PackedStringArray()
	for l in Heights.LAYERS:
		var raised: int = 0
		for k in range(l * Heights.CELLS * Heights.CELLS, (l + 1) * Heights.CELLS * Heights.CELLS):
			if data[k] > 0.05:
				raised += 1
				top = maxf(top, data[k])
		per_layer.append("W%+.0f %d%%" % [Heights.W0 + l * Heights.DW, 100 * raised / (Heights.CELLS * Heights.CELLS)])
	print("GRASS HEIGHTS: baked in %.1f s, %d tops written, highest %.1f m, saved %s (%s)" % [took, int(image.get_meta(&"tops")), top,
		Heights.BAKED, error_string(err)])
	print("   raised ground by layer: %s" % ", ".join(per_layer))
	var back: Dictionary = Heights.load_for(room)
	print("GRASS HEIGHTS: reads back %s" % ("fine" if back.has("tex") else str(back)))
	quit(0)
