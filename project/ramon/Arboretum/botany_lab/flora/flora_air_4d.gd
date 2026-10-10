extends Node

## BOTANY LAB, round 3: the air every lofted flower feels. One shared material wears every plant
## (flower_4d.gd material(), flora_plant.gdshader), and that shader needs, each render, the room's wind
## in the camera's space and the camera's frame back to the world (to find where each plant's foot
## stands, for its phase and the gust). Put one of these in a scene with flowers; `wind` is the room's
## wind_4d.gd node (found by its group when not set).
##
## NO class_name (engine_gotchas.md).

const Flower := preload("res://ramon/Arboretum/botany_lab/flora/flower_4d.gd")
const Wind := preload("res://ramon/Arboretum/botany/wind_4d.gd")

var wind: Node = null


func _ready() -> void:
	if wind == null:
		wind = Wind.of(get_tree())
	if not RenderingServer4D.pre_render.is_connected(_on_pre_render):
		RenderingServer4D.pre_render.connect(_on_pre_render)


func _exit_tree() -> void:
	if RenderingServer4D.pre_render.is_connected(_on_pre_render):
		RenderingServer4D.pre_render.disconnect(_on_pre_render)


func _on_pre_render(cam: Camera4D, viewport: Viewport, _engine: RenderingEngine4D) -> void:
	if not is_inside_tree() or viewport != get_viewport() or cam == null:
		return
	var sh: ShaderMaterial = Flower.shader()
	var d := Vector4(1, 0, 0, 0)
	var speed: float = 0.0
	if wind != null and is_instance_valid(wind):
		d = wind.call("world_direction")
		speed = float(wind.get("speed")) if bool(wind.get("enabled")) else 0.0
		var on: bool = bool(wind.get("_gust_on"))
		sh.set_shader_parameter("wind_time", float(wind.get("time")))
		sh.set_shader_parameter("gust_front", float(wind.get("gust_front")) if on else -1000.0)
		sh.set_shader_parameter("gust_width", float(wind.call("_width")))
		sh.set_shader_parameter("gust_strength", float(wind.call("_strength")) if on else 0.0)
	var cb: Projection = cam.global_basis
	sh.set_shader_parameter("wind_view", cb.inverse() * (d * speed))
	sh.set_shader_parameter("wind_world_dir", d)
	sh.set_shader_parameter("view_to_world_x", cb.x)
	sh.set_shader_parameter("view_to_world_y", cb.y)
	sh.set_shader_parameter("view_to_world_z", cb.z)
	sh.set_shader_parameter("view_to_world_w", cb.w)
	sh.set_shader_parameter("view_to_world_origin", cam.global_position)
