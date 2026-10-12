@tool
extends Node4D

## Kit: an arrival pad, where a path asks you to stop and turn (Ramon, 4 Oct: "a ball for rotation
## point, and a bigger rotating circle for highlight point"; 5 Oct: "3 is pretty good as an arrival
## pad ... make a blue circle inside the chopped circle, and remove the green balls, also remove the
## floating ball for now"). A chopped ring turning slowly on the floor round a solid blue disc, all
## in the wall's blue, painted, not glowing.
##
## Both are 4D: the ring is a kit_path_4d.gd circle (zebra), the disc a flat cubinder as deep through
## W as the ring, so the slice cuts them like the floor marks round them. `ball` brings back the
## floating ball over it (lofted, also 4D).
##
## NO class_name (engine_gotchas.md).

const LoftBuilder := preload("res://ramon/CreationLab/LabKit/carried/chickenpen/scripts/loft_builder_4d.gd")
const Path := preload("res://ramon/CreationLab/kit/kit_path_4d.gd")

## The chopped ring's radius and width, and the disc's radius, m.
@export_range(0.3, 4.0, 0.05) var ring_radius: float = 1.0:
	set(v):
		ring_radius = v
		_later()
@export_range(0.05, 1.0, 0.01) var ring_width: float = 0.22:
	set(v):
		ring_width = v
		_later()
@export_range(0.05, 2.0, 0.01) var disc_radius: float = 0.42:
	set(v):
		disc_radius = v
		_later()
@export var color: Color = Color(0.13, 0.40, 0.86):
	set(v):
		color = v
		_later()
## The chopped ring; off for a corner ball, the disc alone, where paths meet (Ramon, 5 Oct: "at
## important intersections a corner ball should happen").
@export var ring: bool = true:
	set(v):
		ring = v
		_later()
## The solid disc inside the ring; off for a crossroad, where the marker is the turning ring alone
## (Ramon, 5 Oct: "with ball as corner point, I always meant rotating circle").
@export var disc: bool = true:
	set(v):
		disc = v
		_later()
## The floating ball over the pad (off for now).
@export var ball: bool = false:
	set(v):
		ball = v
		_later()
@export_range(0.05, 1.0, 0.01) var ball_radius: float = 0.16
@export_range(0.2, 3.0, 0.05) var float_height: float = 1.45
@export_range(0.0, 0.3, 0.01) var bob: float = 0.06

var _ball: MeshInstance4D
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
	_ball = null
	if ring:
		var rn := Node4D.new()
		rn.name = "Ring"
		rn.set_meta("kit_pivot_generated", true)
		rn.set_script(Path)
		rn.set("shape", "circle")
		rn.set("radius", ring_radius)
		rn.set("style", "zebra")
		rn.set("width", ring_width)
		rn.set("spacing", 0.55)
		rn.set("speed", 0.3)
		rn.set("color", color)
		add_child(rn)
	if not disc:
		return
	var dm := MeshInstance4D.new()
	dm.name = "Disc"
	dm.set_meta("kit_pivot_generated", true)
	var cub := CubinderShape4D.new()
	cub.radius = disc_radius
	cub.height = 0.012
	cub.thickness = 0.6
	dm.mesh = cub.to_tetra_mesh({"segments": 64})
	dm.position = Vector4(0.0, 0.008, 0.0, 0.0)
	var m := TetraMaterial4D.new()
	m.albedo_color = color
	dm.material_override = m
	add_child(dm)
	if not ball:
		return
	var secs: Array[Dictionary] = []
	for f in [-0.86, -0.5, 0.0, 0.5, 0.86]:
		secs.append({"center": Vector4(0.0, f * ball_radius, 0.0, 0.0), "radius": ball_radius * sqrt(maxf(1.0 - f * f, 0.05)),
			"v_scale": 1.0, "w_scale": 1.0, "roll": 0.0, "squareness": 0.0, "color": color, "basis": Projection.IDENTITY})
	_ball = MeshInstance4D.new()
	_ball.name = "Ball"
	_ball.set_meta("kit_pivot_generated", true)
	_ball.mesh = LoftBuilder.build(secs, 6, 12, true, false, false, 1, false)
	var bm := TetraMaterial4D.new()
	bm.albedo_color = color
	_ball.material_override = bm
	_ball.position = Vector4(0.0, float_height, 0.0, 0.0)
	add_child(_ball)


func _process(delta: float) -> void:
	_clock += delta
	if is_instance_valid(_ball):
		_ball.position = Vector4(0.0, float_height + sin(_clock * 1.6) * bob, 0.0, 0.0)
