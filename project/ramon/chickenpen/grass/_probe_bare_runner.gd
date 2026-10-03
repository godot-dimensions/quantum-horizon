extends SceneTree

## What keeps the grass off a spot? For a few points round the marsh (in its own frame), prints
## the mask's two W stretches and the clearings' values there, and every mesh with a ground-low
## tetrahedron over it.
##
##   godot... --headless --path project --script res://ramon/chickenpen/grass/_probe_bare_runner.gd

var _room: Node
var _grass: Node
var _t: float = 0.0


func _initialize() -> void:
	_room = load("res://ramon/chickenpen/chickenpen.tscn").instantiate()
	_room.get_node("Systems/Lookout").set("journal_path", "user://lookout_journal_probe_test.cfg")
	_grass = _room.get_node("World/Grass")
	root.add_child(_room)


func _process(d: float) -> bool:
	_t += d
	if not bool(_grass.get("mask_ready")) and _t < 30.0:
		return false
	var marsh: Node4D = _room.get_node("World/AnaMarsh")
	print("marsh at ", marsh.global_position)
	var meshes: Array = []
	_grass.call("_collect", _room, meshes)
	for off in [Vector4(6.0, 0.0, 6.0, 0.0), Vector4(9.0, 0.0, 4.0, 0.0), Vector4(4.0, 0.0, 9.0, 0.0), Vector4(-8.0, 0.0, 8.0, 0.0)]:
		var p: Vector4 = marsh.global_position + off
		var cell := Vector2i(int(floor((p.x + 60.0) / 0.5)), int(floor((p.z + 60.0) / 0.5)))
		var img: Image = (_grass.get("_mask_texture") as ImageTexture).get_image()
		var cimg: Image = (_grass.get("_clearing_texture") as ImageTexture).get_image()
		print("point ", p, " cell ", cell, " mask ", img.get_pixelv(cell), " clearing ", cimg.get_pixelv(cell))
		for mi in meshes:
			var mesh: TetraMesh4D = (mi as MeshInstance4D).mesh as TetraMesh4D
			var cells: PackedVector4Array = mesh.get_simplex_cell_positions()
			var basis: Projection = mi.global_basis
			var origin: Vector4 = mi.global_position
			var k: int = 0
			var hits: int = 0
			while k + 3 < cells.size():
				var a: Vector4 = basis * cells[k] + origin
				var b: Vector4 = basis * cells[k + 1] + origin
				var c: Vector4 = basis * cells[k + 2] + origin
				var e: Vector4 = basis * cells[k + 3] + origin
				k += 4
				var lo: Vector4 = a.min(b).min(c.min(e))
				var hi: Vector4 = a.max(b).max(c.max(e))
				if lo.y > 0.45 or hi.y < 0.0 or hi.y > 1.3:
					continue
				if p.x < lo.x - 0.3 or p.x > hi.x + 0.3 or p.z < lo.z - 0.3 or p.z > hi.z + 0.3:
					continue
				if bool(_grass.call("_shadow_has", Vector2(p.x, p.z), Vector2(a.x, a.z), Vector2(b.x, b.z), Vector2(c.x, c.z), Vector2(e.x, e.z))):
					hits += 1
					if hits == 1:
						print("    ", _room.get_path_to(mi), "  tet w ", lo.w, "..", hi.w, " y ", lo.y, "..", hi.y)
			if hits > 1:
				print("      (", hits, " tetrahedra)")
	if FileAccess.file_exists("user://lookout_journal_probe_test.cfg"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://lookout_journal_probe_test.cfg"))
	return true
