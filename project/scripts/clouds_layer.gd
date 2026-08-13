class_name CloudsLayer
extends Node
## Drives clouds.gdshader's per-frame uniforms - a real Environment/Sky
## shader (see that shader's own header for why, and
## ramon/IsoclynicSun/isoclynic_sun.tscn for this project's existing, proven
## WorldEnvironment/Sky wiring), not a mesh. No Node4D/tet-mesh cost.
##
## Real 4D volumetric clouds were explicitly ruled out as too expensive, but
## the cloud pattern should still respond to the current 4D slice rotation
## as a genuine tilted cross-section (not just a uniform shift) - see
## clouds.gdshader's own header for the derivation (it reuses the same
## ana_offset-style projection this project already uses for real 4D points
## elsewhere, e.g. bearing_utility_4d.gd).

## The Sky's ShaderMaterial (clouds.gdshader) to push uniforms onto every
## frame - assign the SAME resource used by the scene's
## WorldEnvironment/Environment/Sky, not a copy.
@export var sky_material: ShaderMaterial
## The Node4D whose basis carries the xw/zw rotation - typically the same
## node right-drag rotates (see voxel_hover_camera_4d.gd's rig_path). This is
## the authoritative "how far has the 4D slice rotated" state; there is no
## separate copy of it to keep in sync.
@export var rig_path: NodePath


func _process(_delta: float) -> void:
	if sky_material == null:
		return

	# Identity default (basis_x=(1,0,0,0), basis_z=(0,0,1,0)) matches the
	# shader's own defaults - the zero-rotation, untilted case.
	var basis_x := Vector4(1.0, 0.0, 0.0, 0.0)
	var basis_z := Vector4(0.0, 0.0, 1.0, 0.0)
	if not rig_path.is_empty():
		var rig: Node4D = get_node_or_null(rig_path)
		if rig != null:
			# rig.basis is a Projection (4x4) built by
			# Basis4D.from_xw(...) * Basis4D.from_zw(...) - pushed wholesale
			# so the shader can compute the FULL local = EYEDIR.x*basis_x +
			# EYEDIR.z*basis_z transform per-pixel (both the in-plane
			# rotation/foreshortening AND the depth-into-volume term - see
			# clouds.gdshader's own header for the derivation).
			var rig_basis: Projection = rig.basis
			basis_x = rig_basis.x
			basis_z = rig_basis.z

	sky_material.set_shader_parameter("basis_x", basis_x)
	sky_material.set_shader_parameter("basis_z", basis_z)
