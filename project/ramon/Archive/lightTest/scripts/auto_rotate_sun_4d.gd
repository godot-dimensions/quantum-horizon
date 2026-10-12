extends DirectionalLight4D
## Continuously sweeps this light's direction through an isoclinic-style
## double rotation (xw plane + yz plane) so it drifts in and out of the
## visible 3D slice on its own - no player interaction needed to see the
## effect. GradientSkyMaterial4D and the cross-section renderer's light()
## shader both derive that fade from this node's own 4D orientation each
## frame, so rotating the node is all that's needed (see sun_4d.gd in
## project/ramon/IsoclynicSun for the non-auto-rotating version of this).

@export var rate_1_degrees: float = 18.0 ## xw plane
@export var rate_2_degrees: float = 8.0 ## yz plane

var _angle_1: float = 0.0
var _angle_2: float = 0.0


func _process(delta: float) -> void:
	_angle_1 = wrapf(_angle_1 + rate_1_degrees * delta, -180.0, 180.0)
	_angle_2 = wrapf(_angle_2 + rate_2_degrees * delta, -180.0, 180.0)
	var rotor: Rotor4D = Rotor4D.from_xw(deg_to_rad(_angle_1)).rotate_rotor(Rotor4D.from_yz(deg_to_rad(_angle_2)))
	var direction: Vector4 = rotor.rotate_vector(Vector4(0.0, 1.0, 0.3, 0.0).normalized())
	var up_hint: Vector4 = Vector4(0, 0, 1, 0) if absf(direction.y) > 0.999 else Vector4(0, 1, 0, 0)
	look_at(-direction, up_hint)
