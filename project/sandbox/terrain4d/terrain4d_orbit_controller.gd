extends Node4D
## Ana-kata (4D) rotation of the terrain object itself - right-click-drag
## rotates it in the xw/zw planes, matching this project's established
## convention (see player.gd/bearing_utility_4d.gd). Applied as an
## incremental WORLD-space delta (`basis = delta * basis`, not
## `basis *= delta`) so it always rotates around the same fixed world xw/zw
## planes regardless of the object's current orientation.
##
## The 3D viewing angle used to live here too (left-click), but moved to
## terrain4d_orbit_camera.gd - orbiting the fixed camera around the object
## instead of spinning the object itself, since a free 3D orientation could
## still end up upside-down, which wasn't wanted. See that script's header
## for the full reasoning. 4D stays here because there's no obvious
## "camera" analogue for an ana-kata orbit, and this feel was already
## confirmed correct.
##
## Reads the `rotate_4d` input action (bound to right mouse button in
## project.godot) rather than a raw MOUSE_BUTTON_RIGHT check - matches
## player.gd's own convention for the same action, so a project-wide
## rebind actually takes effect here too instead of silently only moving
## half of the drag-rotate behavior.

const MOUSE_SENSITIVITY := 0.006

func _input(input_event: InputEvent) -> void:
	if not (input_event is InputEventMouseMotion):
		return
	if not Input.is_action_pressed(&"rotate_4d"):
		return
	var rel: Vector2 = input_event.relative * MOUSE_SENSITIVITY
	basis = Basis4D.orthonormalized(Basis4D.from_xw(-rel.x) * Basis4D.from_zw(rel.y) * basis)
