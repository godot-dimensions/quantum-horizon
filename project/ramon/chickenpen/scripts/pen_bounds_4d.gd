extends Node

## Keeps people on the field: nobody walks further than [member radius] from the valley's
## centre ([member centre], x and z, at W 0) in (x, z, w), in any direction, including along W.
##
## WHY NOT A WALL. The hills around the pen are for looking at. Physics here is bounding
## boxes only (hub_demo_lessons.md), so a slope cannot be stood on, and a ring of box walls
## in four dimensions would be hundreds of boxes that still leave gaps between them. A
## sphere in (x, z, w) is one line of arithmetic and has no gaps. It is also exactly the
## shape of the land: the hills are a shell over the same sphere, starting at 50 m.
##
## Soft rather than hard: past the edge the body is put back on it and loses only the part
## of its velocity that points outward, so walking along the edge slides rather than sticks.

@export var bodies: Array[NodePath] = [NodePath("../../Player"), NodePath("../../Mithra")]
## The hills' foot is at 50 m and they clear the field by 58; this leaves the orbit camera
## room behind the player before it would reach a slope.
@export_range(10.0, 80.0, 0.5) var radius: float = 46.0
## The valley's centre, x and z (layout B moved it 6 m south with the hills: PenLayout/PLAN_B.md step 7).
@export var centre: Vector2 = Vector2.ZERO

var _bodies: Array[Node4D] = []


func _ready() -> void:
	for path in bodies:
		var b := get_node_or_null(path) as Node4D
		if b != null:
			_bodies.append(b)


func _physics_process(_delta: float) -> void:
	for b in _bodies:
		var p: Vector4 = b.global_position
		var flat := Vector3(p.x - centre.x, p.z - centre.y, p.w)
		var r: float = flat.length()
		if r <= radius:
			continue
		var out: Vector3 = flat / r
		flat = out * radius
		b.global_position = Vector4(flat.x + centre.x, p.y, flat.y + centre.y, flat.z)
		if b is CharacterBody4D:
			var body := b as CharacterBody4D
			var v: Vector4 = body.linear_velocity
			var along: float = v.x * out.x + v.z * out.y + v.w * out.z
			if along > 0.0:
				body.linear_velocity = v - Vector4(out.x, 0.0, out.y, out.z) * along
