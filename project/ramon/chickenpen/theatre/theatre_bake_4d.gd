extends RefCounted

## What the cinema's three baked exhibits share: knowing whether a bake still matches what it
## was baked from, and dressing a baked loft in its colours without lofting it.
##
## LOFTED ONCE, LOADED AFTER. The goat's stages, the walking creature's 42 segments and the
## carved rock are each a pure function of something authored elsewhere (the goat in
## Model/model.tscn, the creature in Model/rigged_creature_ramon.tscn, the rock's recipe
## here), and building them live cost the talk about 4.5 s, 0.46 s and 0.62 s of frozen
## frames (measured 10 Oct, _measure_talk_frames_runner). So _bake_cinema_runner makes them
## and saves them under baked/, and the cinema reads them back in milliseconds.
##
## A BAKE KNOWS WHAT IT WAS BAKED FROM. Each one stores a fingerprint of its source: every
## stored property of every loft rig and handle in the authored branch, and the scripts that
## turn those into a mesh. If somebody moves a handle or changes the loft builder, the
## fingerprint no longer matches and the exhibit is built live, as it always used to be -
## slow, but showing what was authored rather than last week's copy of it. Re-run the bake
## and it is fast again.

const BAKED := "res://ramon/chickenpen/theatre/baked/"


## A fingerprint of the loft rigs and handles under [param root] (not yet in the tree is
## fine) and of the files in [param scripts]. Objects (materials, meshes, the scripts
## themselves) are left out of the walk: they print as instance ids, which change every
## run. The scripts are counted by their contents instead.
static func fingerprint(root: Node, scripts: PackedStringArray) -> String:
	var parts := PackedStringArray()
	for path in scripts:
		parts.append("%s %s" % [path, FileAccess.get_md5(path)])
	_walk(root, root, parts)
	return "\n".join(parts).md5_text()


static func _walk(root: Node, node: Node, parts: PackedStringArray) -> void:
	if node.has_method("get_loft_section") or node.has_method("build"):
		parts.append(String(root.get_path_to(node)))
		for p in node.get_property_list():
			if int(p["usage"]) & PROPERTY_USAGE_STORAGE == 0 or int(p["type"]) == TYPE_OBJECT:
				continue
			parts.append("%s=%s" % [p["name"], var_to_str(node.get(p["name"]))])
	for child in node.get_children():
		_walk(root, child, parts)


## [param base] with the colours a loft rig would have painted into it for [param mesh]:
## a strip of one texel per section, from the ramp the loft records on its mesh (see
## loft_rig_4d's _apply_ball_colors). [param base] itself if the mesh carries no ramp.
static func coat(mesh: ArrayTetraMesh4D, base: Material4D) -> Material4D:
	var ramp: PackedColorArray = mesh.get_meta("loft_ramp", PackedColorArray()) if mesh != null else PackedColorArray()
	if ramp.is_empty() or not (base is TetraMaterial4D):
		return base
	var image: Image = Image.create(ramp.size(), 1, false, Image.FORMAT_RGBA8)
	for i in ramp.size():
		image.set_pixel(i, 0, ramp[i])
	var texture := ImageTexture3D.new()
	texture.create(Image.FORMAT_RGBA8, ramp.size(), 1, 1, false, [image])
	var dressed := base.duplicate() as TetraMaterial4D
	dressed.set("albedo_source", 3)
	dressed.set("albedo_texture_3d", texture)
	return dressed


## The config a bake was saved with, or null if there is none. Found with FileAccess:
## ResourceLoader.exists says false for a .cfg, which is not a resource (the goat's bake was
## never read for two weeks because of exactly that).
static func read_config(name: String) -> ConfigFile:
	var path: String = BAKED + name + ".cfg"
	if not FileAccess.file_exists(path):
		return null
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return null
	return config


## Builds the draw buffers of [param meshes] now, as their first draw would - for a worker
## thread, so the frame an exhibit first appears in is not the one that pays for it.
static func warm(meshes: Array) -> void:
	for mesh in meshes:
		if mesh != null and (mesh as Object).has_method("get_proxy_mesh_3d"):
			mesh.call("get_proxy_mesh_3d")
