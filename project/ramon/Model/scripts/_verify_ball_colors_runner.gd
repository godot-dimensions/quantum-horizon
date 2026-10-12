extends SceneTree

## Checks that ball colours reach the material by the route that actually draws.
##
## Colours go through a generated ramp TEXTURE, not the material's per-cell colour
## array - the array is stored and validated by the engine but has no channel left in
## the 3D proxy mesh, so it never reaches the GPU.
##
## Four things have to hold: the ramp has one texel per section and carries the balls'
## own colours; every cell vertex points at a coordinate inside the ramp; the
## coordinates a given ball's cells point at resolve back to THAT ball's colour rather
## than a neighbour's (the winding pass swaps vertices inside cells it flips, so
## building the indices at the wrong moment silently shifts a fifth of the model); and
## a mirrored branch is coloured too rather than falling off the end of the ramp.

var _rig: Node
var _step: int = 0


func _initialize() -> void:
	var world := Node4D.new()
	root.add_child(world)
	_rig = MeshInstance4D.new()
	_rig.set_script(load("res://ramon/Model/scripts/loft_rig_4d.gd"))
	_rig.name = "ColorRig"
	_rig.material_override = TetraMaterial4D.new()
	world.add_child(_rig)


func _process(_delta: float) -> bool:
	_step += 1
	if _rig.get("verbose") != null:
		_rig.verbose = false

	match _step:
		1:
			_rig.add_ball()
		2:
			_rig.add_ball()
		3:
			_rig.add_ball()
		4:
			var balls: Array = _balls()
			balls[0].color = Color(1, 0, 0)
			balls[1].color = Color(0, 1, 0)
			balls[2].color = Color(0, 0, 1)
			_rig.use_ball_colors = true
		5:
			_report("straight chain")
			# A branch off the middle ball, pushed off the midline so it mirrors.
			_rig.get_children()[1].add_branch_here()
		6:
			_report("with a mirrored branch")
			return true
	return false


func _balls() -> Array:
	var out: Array = []
	for child in _rig.get_children():
		if child.has_method("get_loft_section"):
			out.append(child)
	return out


func _report(label: String) -> void:
	print("--- %s ---" % label)
	var mesh: ArrayTetraMesh4D = _rig.mesh
	var material: TetraMaterial4D = _rig.material_override
	var pool: PackedVector3Array = mesh.get_texture_map_values()
	var indices: PackedInt32Array = mesh.get_simplex_cell_texture_map_indices()
	var cell_vertices: PackedInt32Array = mesh.get_simplex_cell_vertex_indices()
	print("albedo_source = %d  (3 = Texture3D cell UVW only)" % material.albedo_source)

	var texture: Texture3D = material.albedo_texture_3d
	if texture == null:
		print("FAILED: no ramp texture on the material")
		return
	print("ramp texture = %d x %d x %d, texture coordinates in the pool = %d, match = %s" % [
		texture.get_width(), texture.get_height(), texture.get_depth(), pool.size(),
		texture.get_width() == pool.size()])
	print("one texture index per cell vertex: %d of %d, match = %s" % [
		indices.size(), cell_vertices.size(), indices.size() == cell_vertices.size()])

	# The texture itself cannot be read back headlessly - there is no real rendering
	# server - so the ramp is read from the record the rig leaves on the mesh, which is
	# the same array the texture was written from.
	var ramp: PackedColorArray = mesh.get_meta("loft_ramp", PackedColorArray())
	var band: Array = []
	for c in ramp:
		band.append("%.1f,%.1f,%.1f" % [c.r, c.g, c.b])
	print("ramp reads: %s" % [", ".join(band)])

	# Every coordinate must land inside the ramp, and on a texel centre rather than
	# between two - landing between them would blend two balls' colours everywhere.
	var outside: int = 0
	var off_centre: int = 0
	for index in indices:
		if index < 0 or index >= pool.size():
			outside += 1
			continue
		var u: float = pool[index].x
		if u < 0.0 or u > 1.0:
			outside += 1
		if not is_equal_approx(u * float(pool.size()) - floorf(u * float(pool.size())), 0.5):
			off_centre += 1
	print("coordinates outside the ramp: %d, off a texel centre: %d" % [outside, off_centre])

	# The decisive check: pick the cells nearest each ball and confirm the colour the
	# ramp gives them is that ball's own, not a neighbour's.
	var positions: PackedVector4Array = mesh.get_vertex_positions()
	for ball in _balls():
		var wanted: Color = ball.color
		var nearest_error: float = INF
		var found: Color = Color.BLACK
		for slot in range(cell_vertices.size()):
			var distance: float = positions[cell_vertices[slot]].distance_to(ball.position)
			if distance < nearest_error:
				nearest_error = distance
				var u: float = pool[indices[slot]].x
				found = ramp[mini(int(u * float(ramp.size())), ramp.size() - 1)]
		print("   %s wants (%.1f,%.1f,%.1f), nearest geometry reads (%.1f,%.1f,%.1f) -> %s" % [
			ball.name, wanted.r, wanted.g, wanted.b, found.r, found.g, found.b,
			"OK" if found.is_equal_approx(wanted) else "WRONG"])
