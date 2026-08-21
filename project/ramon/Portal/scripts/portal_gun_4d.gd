extends Node
## Fires the two portal colours wherever you are aiming.
##
## Blue on the fire action (left mouse), yellow on F. F rather than right mouse
## because right mouse is rotate_4d, which this project cannot give up - and
## rather than a new input action, because project.godot is shared and an action
## added there would leak this scene's controls into every other scene, the same
## reasoning hub_slice_reset.gd gives for binding its own key by raw keycode.
##
## A refusal always says why. Valve's rule is that an invalid surface answers
## visibly rather than doing nothing, or the player reads the refusal as a bug.

const RANGE := 80.0

@onready var _player: CharacterBody4D = $"../Player"
@onready var _player_head: Node4D = $"../Player/PlayerHead"
@onready var _link: Node = $"../PortalLink"

var last_shot_status: String = "no shots yet"


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"fire"):
		_shoot(&"blue")
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F:
		_shoot(&"yellow")


func _shoot(colour: StringName) -> void:
	var ray_params := RaycastParameters4D.new()
	ray_params.global_ray_origin = _player_head.global_position
	ray_params.global_ray_direction = -_player_head.global_basis.z
	ray_params.set_exclude_nodes([_player])
	var result: Dictionary = PhysicsServer4D.raycast_physics_objects(ray_params)

	if not result.get("hit", false):
		last_shot_status = "%s: nothing hit" % colour
		return
	if result.get("global_distance", INF) > RANGE:
		last_shot_status = "%s: out of range" % colour
		return

	var hit_body: Object = result.get("body")
	if hit_body == null:
		last_shot_status = "%s: nothing solid" % colour
		return
	# A portalable surface owns a "Solid" StaticBody4D holding its pieces, so the
	# surface itself is that body's parent. Anything else is ordinary wall.
	var surface: Object = hit_body.get_parent()
	if surface == null or not surface.has_method("open_hole"):
		last_shot_status = "%s: that surface will not take a portal" % colour
		return

	var hit_point: Vector4 = result.get("global_point", Vector4.ZERO)
	# Shots that graze the back of a surface would place a portal facing into
	# solid wall, so require the surface to actually be facing the shooter.
	if surface.normal.dot(ray_params.global_ray_direction) > 0.0:
		last_shot_status = "%s: you are behind that surface" % colour
		return

	if _link.place(surface, hit_point, colour):
		last_shot_status = "%s: %s" % [colour, _link.last_event]
	else:
		last_shot_status = "%s: %s" % [colour, _link.last_event]
