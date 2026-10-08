extends Node4D
## The water test's scene root: builds the floating bodies, and owns the keys.
##
## The bodies are here for three reasons, in order of how much they matter: they give the eye
## something fixed to judge the wave motion against while the slice turns, they are what the
## intersection foam has to bite into, and they are spread through W so that turning the
## slice visibly changes which of them exist. Without them a turning slice just looks like
## the water changing its mind.

const Surface := preload("res://sandbox/water4d/water4d_surface.gd")

## Bodies as (x, z, w, y, size, colour). y is the centre height, so a size of 1.6 at y = 0.1
## sits a little over half out of the water.
const BODIES := [
	[6.0, -4.0, 0.0, 0.10, 1.8, Color(0.86, 0.33, 0.20)],
	[-7.5, 3.0, 0.0, -0.15, 2.2, Color(0.90, 0.72, 0.25)],
	[2.0, 9.0, 1.4, 0.25, 1.5, Color(0.35, 0.72, 0.45)],
	[-3.0, -9.5, -1.6, 0.00, 1.7, Color(0.40, 0.55, 0.88)],
	[12.0, 5.0, 3.2, 0.30, 2.4, Color(0.78, 0.40, 0.72)],
	[-13.0, -6.0, -3.4, -0.20, 2.0, Color(0.30, 0.74, 0.76)],
	[0.0, 17.0, 6.0, 0.40, 2.6, Color(0.92, 0.55, 0.30)],
	[16.0, -14.0, -6.5, 0.10, 2.2, Color(0.62, 0.62, 0.68)],
	[-19.0, 10.0, 9.0, 0.35, 2.8, Color(0.85, 0.85, 0.40)],
	[9.0, 20.0, -9.5, -0.10, 2.3, Color(0.50, 0.45, 0.80)],
]

@export var surface_path: NodePath = ^"Water"
@export var camera_path: NodePath = ^"FlyCamera"

var _surface: Node4D = null
var _camera: Camera4D = null


func _ready() -> void:
	_surface = get_node_or_null(surface_path) as Node4D
	_camera = get_node_or_null(camera_path) as Camera4D
	_build_bodies()


func _build_bodies() -> void:
	var holder := Node4D.new()
	holder.name = "Bodies"
	add_child(holder)
	for entry in BODIES:
		var size: float = entry[4]
		var material := TetraMaterial4D.new()
		material.albedo_color = entry[5]
		var mesh := BoxTetraMesh4D.new()
		# Equal on all four axes, so each one genuinely leaves the slice as you move through
		# W rather than being a prism that is always there.
		mesh.size = Vector4(size, size, size, size)
		var instance := MeshInstance4D.new()
		instance.mesh = mesh
		instance.material_override = material
		instance.position = Vector4(entry[0], entry[3], entry[1], entry[2])
		holder.add_child(instance)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or _surface == null:
		return
	match key.keycode:
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8:
			_surface.call(&"set_preset", key.keycode - KEY_1)
		KEY_F:
			_surface.set(&"debug_jacobian", not bool(_surface.get(&"debug_jacobian")))
		KEY_G:
			# Flip between the full Gerstner solve and plain sine heights, which is the
			# comparison the iteration count exists to make.
			var n: int = int(_surface.get(&"solve_iterations"))
			_surface.set(&"solve_iterations", 0 if n > 0 else 2)
		KEY_N:
			# Detail noise on and off, so it can be seen for what it contributes.
			var d: float = float(_surface.get(&"detail_strength"))
			_surface.set(&"detail_strength", 0.0 if d > 0.0 else 0.085)
