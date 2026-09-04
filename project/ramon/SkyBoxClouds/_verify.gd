extends SceneTree

## Throwaway: proves the skydome and cloud field build valid meshes headless,
## and reports how much of the sky is actually filled AT THE CURRENT SLICE -
## which is the number that matters and the one you cannot read off a
## screenshot. Delete once the look is settled.

const SKYDOME_PATH := "res://ramon/SkyBoxClouds/scripts/skydome_4d.gd"
const CLOUDS_PATH := "res://ramon/SkyBoxClouds/scripts/cloud_field_4d.gd"


func _init() -> void:
	_check_dome()
	print("")
	_check_clouds()
	quit()


func _check_dome() -> void:
	var dome = load(SKYDOME_PATH).new()
	dome.radius = 500.0
	dome.generate()
	var mesh: ArrayTetraMesh4D = dome.mesh as ArrayTetraMesh4D
	if mesh == null:
		print("DOME FAIL: no mesh")
		return
	print("DOME  tets %d  texmap %d/%d" % [
		mesh.get_simplex_cell_vertex_indices().size() / 4,
		mesh.simplex_cell_texture_map.size(),
		mesh.get_simplex_cell_vertex_indices().size()])
	dome.free()


func _check_clouds() -> void:
	var script: GDScript = load(CLOUDS_PATH)
	var clouds = script.new()
	clouds.generate()
	var mesh: ArrayTetraMesh4D = clouds.mesh as ArrayTetraMesh4D
	if mesh == null:
		print("CLOUDS FAIL: no mesh")
		clouds.free()
		return

	var vertices: PackedVector4Array = mesh.get_vertex_positions()
	var min_y := 1e20
	var max_y := -1e20
	var max_w := 0.0
	# A vertex only contributes visible geometry near the current slice, so
	# count how much of the mesh sits within a thin band around w = 0. This is
	# the honest measure of "how full does the sky look right now" - total tet
	# count says nothing about it, because most of the deck is off-slice.
	var near_slice := 0
	for v in vertices:
		min_y = minf(min_y, v.y)
		max_y = maxf(max_y, v.y)
		max_w = maxf(max_w, absf(v.w))
		if absf(v.w) < 40.0:
			near_slice += 1

	print("  base_altitude    %.0f" % clouds.base_altitude)
	print("  y range          %.0f .. %.0f" % [min_y, max_y])
	print("  max |w|          %.0f" % max_w)
	print("  vertices         %d" % vertices.size())
	print("  within |w|<40    %d  (%.0f%% - this is what you SEE at one slice)" % [
		near_slice, 100.0 * float(near_slice) / float(maxi(1, vertices.size()))])

	# Horizon reach: a deck at altitude H extending R sideways bottoms out at
	# atan(H/R) above the horizon. Below ~15 degrees it reads as sky-filling.
	var elevation: float = rad_to_deg(atan(clouds.base_altitude / clouds.field_extent))
	print("  deck edge sits   %.1f deg above the horizon (lower = fuller sky)" % elevation)
	clouds.free()
