extends SceneTree

## Probe for the town wall's stone (Ramon's walkthrough item 29): what the wall's materials and meshes are once the pen
## has loaded, and a frame of it with a loud test texture, to see whether a 3D texture reaches the wall at all.
##
##   lab_run.sh windowed wall_probe res://ramon/chickenpen/discovery/_probe_wall_runner.gd

var _room: Node


func _initialize() -> void:
	root.unfocusable = true
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	OS.set_environment("PEN_LOOK", "art")
	_room = (load("res://ramon/chickenpen/playable_world.tscn") as PackedScene).instantiate()
	root.add_child(_room)
	current_scene = _room
	await _frames(150)
	var wall: Node = _room.get_node("World/TownWall")
	print("WALL output_mesh_type %s  updating %s  auto %s" % [str(wall.get("output_mesh_type")), str(wall.call("is_updating")), str(wall.get("update_automatically"))])
	for prop in ["beam_material", "rib_material", "post_material"]:
		var m: Resource = wall.get(prop)
		print("WALL %s: %s source %s tex %s scale %s" % [prop, str(m), str(m.get("albedo_source")) if m != null else "-", str(m.get("albedo_texture_3d")) if m != null else "-", str(m.get("albedo_texture_map_scale")) if m != null else "-"])
	var mesh: Resource = wall.get("mesh")
	print("WALL mesh %s" % str(mesh))
	print("WALL material_override %s" % str(wall.get("material_override")))
	if mesh != null and mesh.has_method("get_surface_count"):
		print("WALL surfaces %d" % int(mesh.call("get_surface_count")))
	for m in ["get_surface_mesh", "get_surface_material"]:
		print("WALL has %s: %s" % [m, str(mesh != null and mesh.has_method(m))])
	if mesh != null and mesh.has_method("get_simplex_cell_texture_map_indices"):
		print("WALL texture map indices %d" % (mesh.call("get_simplex_cell_texture_map_indices") as PackedInt32Array).size())
	# The real stone first, close.
	var player0: Node = _room.get_node("Player")
	player0.set("input_enabled", false)
	var cam0 := _room.get_node("World/TalkCam") as Node4D
	cam0.global_position = Vector4(-6.0, 2.6, 18.5, 0.0)
	var g0: Vector3 = Vector3(-5.5, -0.2, -6.9).normalized()
	var z0: Vector3 = -g0
	var x0: Vector3 = Vector3(0.0, 1.0, 0.0).cross(z0).normalized()
	var y0: Vector3 = z0.cross(x0)
	cam0.global_basis = Projection(Vector4(x0.x, x0.y, x0.z, 0.0), Vector4(y0.x, y0.y, y0.z, 0.0), Vector4(z0.x, z0.y, z0.z, 0.0), Vector4(0, 0, 0, 1))
	cam0.set("current", true)
	for node in _room.find_children("*", "CanvasItem", true, false):
		if not ((node as CanvasItem).get_parent() is CanvasItem):
			(node as CanvasItem).visible = false
	for node in _room.find_children("*", "CanvasLayer", true, false):
		(node as CanvasLayer).visible = false
	await _frames(30)
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://smoke_test_output/feedback_10oct/"))
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://smoke_test_output/feedback_10oct/probe_wall_stone.png"))
	# A loud texture: red bottom, green top, so a frame shows whether texture coordinates reach the wall.
	var layers: Array[Image] = []
	for z in 8:
		var img := Image.create_empty(8, 8, false, Image.FORMAT_RGBA8)
		for y in 8:
			for x in 8:
				img.set_pixel(x, y, Color(1.0 - float(y) / 7.0, float(y) / 7.0, float(x) / 7.0))
		layers.append(img)
	var tex := ImageTexture3D.new()
	tex.create(Image.FORMAT_RGBA8, 8, 8, 8, false, layers)
	var loud := TetraMaterial4D.new()
	loud.albedo_source = TetraMaterial4D.TETRA_COLOR_SOURCE_TEXTURE3D_CELL_UVW_ONLY
	loud.albedo_texture_3d = tex
	wall.set("beam_material", loud)
	await _frames(60)
	var player: Node = _room.get_node("Player")
	player.set("input_enabled", false)
	var cam := _room.get_node("World/TalkCam") as Node4D
	cam.global_position = Vector4(-6.0, 3.0, 20.0, 0.0)
	var gap: Vector3 = Vector3(-5.5, -0.6, -8.4).normalized()
	var zc: Vector3 = -gap
	var xc: Vector3 = Vector3(0.0, 1.0, 0.0).cross(zc).normalized()
	var yc: Vector3 = zc.cross(xc)
	cam.global_basis = Projection(Vector4(xc.x, xc.y, xc.z, 0.0), Vector4(yc.x, yc.y, yc.z, 0.0), Vector4(zc.x, zc.y, zc.z, 0.0), Vector4(0, 0, 0, 1))
	cam.set("current", true)
	await _frames(30)
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://smoke_test_output/feedback_10oct/"))
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://smoke_test_output/feedback_10oct/probe_wall_loud.png"))
	print("WALL after loud: mesh %s" % str(wall.get("mesh")))
	print("WALL: DONE")
	quit(0)
