extends SceneTree
## Does the cinema's goat find its bake on disk, and does the bake carry the coat? ResourceLoader
## .exists only answers for files a resource loader recognises, and a .cfg is not one.
func _initialize() -> void:
	var cfg := "res://ramon/chickenpen/theatre/baked/goat.cfg"
	print("ResourceLoader.exists(cfg) = ", ResourceLoader.exists(cfg))
	print("FileAccess.file_exists(cfg) = ", FileAccess.file_exists(cfg))
	var t0 := Time.get_ticks_usec()
	for i in 11:
		load("res://ramon/chickenpen/theatre/baked/goat_stage_%02d.res" % i)
	var done := load("res://ramon/chickenpen/theatre/baked/goat_finished.res") as ArrayTetraMesh4D
	print("loading all twelve: %.0f ms" % ((Time.get_ticks_usec() - t0) / 1000.0))
	var ramp: PackedColorArray = done.get_meta("loft_ramp", PackedColorArray())
	print("finished: %d tetrahedra, %d texture coordinates, ramp of %d colours" % [
		done.get_simplex_cell_vertex_indices().size() / 4, done.get_texture_map_values().size(), ramp.size()])
	quit()
