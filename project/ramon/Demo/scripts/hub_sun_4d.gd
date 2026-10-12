@tool
extends DirectionalLight4D

## A [DirectionalLight4D] with usable rotation controls.
##
## WHY THIS EXISTS: [Node4D] does expose rotation, but 4D has six rotation planes
## (xy, xz, yz, xw, yw, zw), and the inspector packs them into an [AABB] widget -
## six unlabelled floats. `basis` is worse: a raw 16-float [Projection]. Neither
## is something you can aim a sun with. This exposes three named angles and
## composes the basis from them, the same approach `sun_4d.gd` takes in the
## Isoclynic Sun scene.
##
## ON ANGULAR RADIUS, which looks broken but is not: [member
## angular_radius_degrees] sets the size of the sun's disc, and the gradient sky
## shader tests `cos(light_angular_radius_radians)` against the view angle. At the
## default 1° the disc is about a degree wide and sits wherever [member
## elevation_degrees] puts it, so you have to be looking almost directly at it to
## see any change. The broad glow around the sun is a SEPARATE control -
## `sun_angle_max` on the [GradientSkyMaterial4D] - and that is the one to reach
## for if the sky looks flat. Angular radius also drives shadow softness, which is
## only visible if something is casting a shadow worth looking at.

@export_tool_button("Apply angles") var _apply_action: Callable = apply_angles

## Height of the sun above the horizon. 90° is directly overhead, which flattens
## everything - low angles read better in greybox because the shading does more
## of the work of describing shape.
@export_range(-10.0, 90.0, 0.5, "suffix:°") var elevation_degrees: float = 55.0:
	set(value):
		elevation_degrees = value
		apply_angles()

## Compass heading of the sun. 0° puts it behind the spawn point (the hub's back
## wall is at +Z, and the player faces -Z), so the gates are lit from behind the
## viewer rather than silhouetted against it.
@export_range(-180.0, 180.0, 1.0, "suffix:°") var azimuth_degrees: float = 25.0:
	set(value):
		azimuth_degrees = value
		apply_angles()

## Tilts the sun out of the current 3D slice, toward ana/kata.
##
## At 0 the sun has no w component, so lighting is identical no matter how far
## the player slice-rotates - which is what a stable hub wants. Turn it up and
## the sun's contribution changes as you rotate, because the light direction is
## partly outside your slice. That is the genuinely 4D behaviour and it is worth
## demonstrating, but it costs the hub its constancy, so it is off by default.
@export_range(-89.0, 89.0, 1.0, "suffix:°") var ana_tilt_degrees: float = 0.0:
	set(value):
		ana_tilt_degrees = value
		apply_angles()


func _ready() -> void:
	apply_angles()


## Rebuilds the node's basis from the three angles.
func apply_angles() -> void:
	if not is_inside_tree():
		return
	var elevation := deg_to_rad(elevation_degrees)
	var azimuth := deg_to_rad(azimuth_degrees)
	var tilt := deg_to_rad(ana_tilt_degrees)

	# Direction from the scene TOWARD the sun, in the 3D slice.
	var horizontal := cos(elevation)
	var toward_sun_3d := Vector3(
		sin(azimuth) * horizontal,
		sin(elevation),
		cos(azimuth) * horizontal
	)
	# Rotate that direction out of the slice by the ana tilt.
	var toward_sun := Vector4(
		toward_sun_3d.x * cos(tilt),
		toward_sun_3d.y * cos(tilt),
		toward_sun_3d.z * cos(tilt),
		sin(tilt)
	)

	# DirectionalLight4D emits along local -Z, so pointing +Z at the sun makes the
	# light travel from the sun into the scene.
	basis = _basis_with_z(toward_sun)


## Builds an orthonormal basis whose z column is [param z_axis].
##
## Handedness of the remaining axes is not controlled and does not need to be:
## a directional light only ever reads its z column, both for the 3D direction and
## for the slice component (`-relative_basis.z.w` in directional_light_4d.cpp).
func _basis_with_z(z_axis: Vector4) -> Projection:
	var forward := z_axis.normalized()
	# 4D has no two-vector cross product, so pick the standard axes least
	# parallel to `forward` and Gram-Schmidt them into place.
	var candidates: Array[Vector4] = [
		Vector4(1.0, 0.0, 0.0, 0.0),
		Vector4(0.0, 1.0, 0.0, 0.0),
		Vector4(0.0, 0.0, 1.0, 0.0),
		Vector4(0.0, 0.0, 0.0, 1.0),
	]
	candidates.sort_custom(
		func(a: Vector4, b: Vector4) -> bool: return absf(a.dot(forward)) < absf(b.dot(forward))
	)

	var axes: Array[Vector4] = []
	for candidate in candidates:
		var v: Vector4 = candidate - forward * candidate.dot(forward)
		for existing in axes:
			v -= existing * v.dot(existing)
		if v.length() > 0.001:
			axes.append(v.normalized())
		if axes.size() == 3:
			break

	if axes.size() < 3:
		push_warning("HubSun4D: could not build a basis, leaving rotation unchanged.")
		return basis
	return Projection(axes[0], axes[1], forward, axes[2])
