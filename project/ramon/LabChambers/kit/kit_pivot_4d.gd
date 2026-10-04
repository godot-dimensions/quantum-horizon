@tool
extends Node4D

## Kit: a pivot point, where a path asks you to stop and turn (Ramon, 4 Oct: "a ball for rotation
## point, and a bigger rotating circle for highlight point"). A glowing ball floating at eye level
## over a small ring of dots on the floor, bobbing slowly. Put a highlight (a kit_path_4d.gd circle)
## round it for a place to stand, or face it towards what to look at with `look`.
##
## The ball is a real 4D ball, lofted by the loft builder from round sections, as deep through W as
## it is wide, so it is sliced like everything else: it shrinks and goes as the slice leaves it. The
## floor ring is a small dotted circle path.
##
## NO class_name (engine_gotchas.md).

const LoftBuilder := preload("res://ramon/LabKit/carried/chickenpen/scripts/loft_builder_4d.gd")
const Mats := preload("res://ramon/LabKit/lab_materials.gd")
const Path := preload("res://ramon/LabChambers/kit/kit_path_4d.gd")

@export_range(0.05, 1.0, 0.01) var ball_radius: float = 0.16:
	set(v):
		ball_radius = v
		_later()
## How high the ball floats, m, and how far it bobs.
@export_range(0.2, 3.0, 0.05) var float_height: float = 1.45
@export_range(0.0, 0.3, 0.01) var bob: float = 0.06
@export var color: Color = Color(0.45, 0.78, 1.0):
	set(v):
		color = v
		_later()
## A point to face (world x, z); a small arrow on the floor ring turns to it. Zero for none.
@export var look: Vector3 = Vector3.ZERO:
	set(v):
		look = v
		_later()

var _ball: MeshInstance4D
var _ring: Node4D
var _clock: float = 0.0
var _queued: bool = false


func _ready() -> void:
	rebuild()


func _later() -> void:
	if _queued or not is_inside_tree():
		return
	_queued = true
	(func() -> void:
		_queued = false
		rebuild()).call_deferred()


func rebuild() -> void:
	for c in get_children():
		if c.has_meta("kit_pivot_generated"):
			c.free()
	# The ball: five round sections up through it, lofted into a ball.
	var secs: Array[Dictionary] = []
	for f in [-0.86, -0.5, 0.0, 0.5, 0.86]:
		secs.append({"center": Vector4(0.0, f * ball_radius, 0.0, 0.0), "radius": ball_radius * sqrt(maxf(1.0 - f * f, 0.05)),
			"v_scale": 1.0, "w_scale": 1.0, "roll": 0.0, "squareness": 0.0, "color": color, "basis": Projection.IDENTITY})
	var mesh: ArrayTetraMesh4D = LoftBuilder.build(secs, 6, 12, true, false, false, 1, false)
	_ball = MeshInstance4D.new()
	_ball.name = "Ball"
	_ball.set_meta("kit_pivot_generated", true)
	_ball.mesh = mesh
	_ball.material_override = Mats.glow(color, 1.4)
	_ball.position = Vector4(0.0, float_height, 0.0, 0.0)
	add_child(_ball)
	# The floor ring: a small dotted circle, the dots running round it.
	_ring = Node4D.new()
	_ring.name = "Ring"
	_ring.set_meta("kit_pivot_generated", true)
	_ring.set_script(Path)
	_ring.set("shape", "circle")
	_ring.set("radius", 0.5)
	_ring.set("style", "dots")
	_ring.set("width", 0.22)
	_ring.set("spacing", 0.3)
	_ring.set("speed", 0.25)
	_ring.set("color", color)
	_ring.set("glow", 0.6)
	add_child(_ring)


func _process(delta: float) -> void:
	_clock += delta
	if is_instance_valid(_ball):
		_ball.position = Vector4(0.0, float_height + sin(_clock * 1.6) * bob, 0.0, 0.0)
