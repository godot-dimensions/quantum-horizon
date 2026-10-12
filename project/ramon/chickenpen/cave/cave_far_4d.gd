extends Node4D

## The far room at the end of the way through W, and the tunnel to it (cave_rock_4d.gd,
## "THE FAR ROOM"): its baked rock, its lamps, and the standing stones' colliders. A scene
## of its own so that it is only in memory while it can be seen - cave_far_stream_4d.gd
## loads it and lets it go. It sits at the cave's own origin, so everything in it is in
## the cave's frame.

const CaveRock := preload("res://ramon/chickenpen/cave/cave_rock_4d.gd")


## THE TRAIL TO THE DREAMER: glowing dots down the tunnel's floor, wandering a little from
## side to side rather than ruled straight (Ramon, 28 Sept: "i rather have a dotted line ...
## slightly wavey, not a perfect straight dotted line"). Each dot is wide in x - the way
## the tunnel is wide in x, so it shows from anywhere the tunnel does - and small in z and
## w, which are what you see of it walking along W.
const TRAIL_FROM := 9.6
const TRAIL_TO := 27.5
const TRAIL_STEP := 0.6
const TRAIL_GLOW := Color(0.45, 0.65, 1.0)


func _ready() -> void:
	_lay_trail()
	var body := StaticBody4D.new()
	body.name = "Solid"
	add_child(body)
	# Its own floor: the room is wider than the cave's floor box reaches.
	var lo: Vector3 = CaveRock.FAR_FLOOR_LO
	var hi: Vector3 = CaveRock.FAR_FLOOR_HI
	var boxes: Array = [[Vector4((lo.x + hi.x) * 0.5, -0.5, (lo.y + hi.y) * 0.5, (lo.z + hi.z) * 0.5), Vector4(hi.x - lo.x, 1.0, hi.y - lo.y, hi.z - lo.z)]]
	boxes.append_array(CaveRock.new().far_solid_boxes())
	for box in boxes:
		var shape := BoxShape4D.new()
		shape.size = box[1]
		var holder := CollisionShape4D.new()
		holder.shape = shape
		holder.position = box[0]
		body.add_child(holder)


func _lay_trail() -> void:
	var dot := BoxTetraMesh4D.new()
	dot.size = Vector4(CaveRock.W_PASSAGE_REACH * 2.0, 0.015, 0.08, 0.08)
	var glow := TetraMaterial4D.new()
	glow.albedo_color = TRAIL_GLOW
	var w: float = TRAIL_FROM
	var i := 0
	while w <= TRAIL_TO:
		var sway: float = 0.35 * sin(w * 0.55) + 0.15 * sin(w * 1.7 + 0.8)
		var m := MeshInstance4D.new()
		m.name = "Trail%d" % i
		m.mesh = dot
		m.material_override = glow
		add_child(m)
		m.position = Vector4(0.0, 0.02, CaveRock.W_DOOR.y + sway, w)
		w += TRAIL_STEP
		i += 1
