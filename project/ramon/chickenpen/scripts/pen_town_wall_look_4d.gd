extends Node

## THE TOWN WALL'S STONE (10 Oct 2026, Ramon's walkthrough). Item 29 asked for "a subtle stone-wall texture or ... a
## gentle color gradient"; a gradient with course lines was tried that afternoon, and items 34 and 44 took it back: "The
## lines appear thick, blurry, and visually distracting ... Use a consistent medium-gray stone as the dominant wall
## color. Bring the protruding posts and main wall surfaces much closer together in brightness ... a simple, cohesive
## medium-gray stone wall whose form is defined primarily by geometry rather than strong material contrasts."
##
## So this only sets the wall's three materials (Andrew's FenceGenerator4D, World/TownWall) to plain colours when the pen
## loads: the wall a medium gray, the posts and ribs a touch darker, nothing else. Art only (the dev look lays its own
## colour over it). NO class_name (engine_gotchas.md).

@export var wall_path: NodePath = ^"../../World/TownWall"
@export var wall_colour: Color = Color(0.56, 0.56, 0.57)
@export var post_colour: Color = Color(0.51, 0.51, 0.52)


func _ready() -> void:
	var wall: Node = get_node_or_null(wall_path)
	if wall == null:
		return
	for prop in ["beam_material", "rib_material", "post_material"]:
		var m := TetraMaterial4D.new()
		m.albedo_color = wall_colour if prop == "beam_material" else post_colour
		wall.set(prop, m)
	if not bool(wall.get("update_automatically")) and wall.has_method("update_fence_mesh_now"):
		wall.call("update_fence_mesh_now")
