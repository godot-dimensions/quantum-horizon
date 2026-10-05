@tool
extends Node4D

## Kit: the path system's test bed, laid out on Room 2's floor (Ramon, 4 Oct: "show me in the
## second room a test case that it can do many things"). Every case is a kit_path_4d.gd or a
## kit_pivot_4d.gd, built here round this node, each with a number painted beside it that the wall
## sign explains:
##   1  arrows through an S-bend            the chevrons follow any curve
##   2  blocks on a spiral                  tight curves; each block turns with the curve
##   3  an arrival pad                      a chopped ring round a blue disc: stand here
##   4  a path that leaves the slice        it bends through W and is gone, then comes back
##   5  a loop drifting through W           only the part at your W is there; turn the slice
##   6  a figure of eight                   a line with pulses, crossing itself
##   7  two speeds, two ways                blocks running back against arrows
##
## NO class_name (engine_gotchas.md).

const Path := preload("res://ramon/CreationLab/kit/kit_path_4d.gd")
const Pivot := preload("res://ramon/CreationLab/kit/kit_pivot_4d.gd")
const Mats := preload("res://ramon/CreationLab/LabKit/lab_materials.gd")


@export_tool_button("Rebuild") var _rebuild_action: Callable = rebuild


func _ready() -> void:
	rebuild()


func rebuild() -> void:
	for c in get_children():
		c.free()
	# 1. Arrows through an S-bend, down the left side.
	_path("Case1Bend", "arrows", [Vector4(-11, 0, 12, 0), Vector4(-11, 0, 8, 0), Vector4(-7.5, 0, 4.5, 0), Vector4(-11, 0, 0.5, 0),
		Vector4(-7.5, 0, -3.5, 0), Vector4(-11, 0, -7.5, 0), Vector4(-11, 0, -11, 0)], {})
	_number(1, Vector2(-13.2, 12.0))
	# 2. Dots on a spiral.
	var spiral := PackedVector4Array()
	for i in 46:
		var a: float = float(i) * 0.36
		var r: float = 0.5 + float(i) * 0.075
		spiral.append(Vector4(-2.5 + sin(a) * r, 0, 6.5 + cos(a) * r, 0))
	_path("Case2Spiral", "blocks", spiral, {"width": 0.55, "spacing": 0.5, "speed": 0.5})
	_number(2, Vector2(-6.4, 10.4))
	# 3. An arrival pad, and arrows arriving at it.
	var piv := Node4D.new()
	piv.name = "Case3Pad"
	piv.set_script(Pivot)
	piv.set("ring_radius", 1.6)
	piv.set("ring_width", 0.28)
	piv.set("disc_radius", 0.6)
	piv.position = Vector4(6.0, 0.0, 6.5, 0.0)
	add_child(piv)
	_path("Case3In", "arrows", [Vector4(6.0, 0, 12.5, 0), Vector4(6.0, 0, 8.3, 0)], {"width": 0.9})
	_number(3, Vector2(9.0, 9.4))
	# 4. A path that leaves the slice: out through W in the middle, back again at the end.
	_path("Case4Leaves", "arrows", [Vector4(-4, 0, -1, 0), Vector4(-1, 0, -1, 0), Vector4(1.5, 0, -1, 1.3), Vector4(4.5, 0, -1, 1.3),
		Vector4(7, 0, -1, 0), Vector4(10, 0, -1, 0)], {"width": 0.9, "smooth": true})
	_number(4, Vector2(-5.6, -1.0))
	# 5. A loop drifting through W.
	var drift := PackedVector4Array()
	for i in 40:
		var a2: float = TAU * float(i) / 40.0
		drift.append(Vector4(6.5 + sin(a2) * 2.6, 0, -7.5 + cos(a2) * 2.6, sin(a2 * 2.0) * 0.9))
	_path("Case5Drift", "arrows", drift, {"closed": true, "width": 0.8, "spacing": 1.8, "speed": 0.8})
	_number(5, Vector2(10.2, -4.4))
	# 6. A figure of eight.
	var eight := PackedVector4Array()
	for i in 48:
		var t: float = TAU * float(i) / 48.0
		eight.append(Vector4(-2.0 + sin(t) * 3.2, 0, -8.5 + sin(t) * cos(t) * 2.4, 0))
	_path("Case6Eight", "line", eight, {"closed": true, "width": 0.6, "spacing": 2.4, "speed": 1.2})
	_number(6, Vector2(-6.2, -11.6))
	# 7. Two speeds, two ways: gold dots back, blue arrows on.
	_path("Case7On", "arrows", [Vector4(-13, 0, -13, 0), Vector4(13, 0, -13, 0)], {"width": 0.8, "speed": 1.6})
	_path("Case7Back", "blocks", [Vector4(-13, 0, -14.1, 0), Vector4(13, 0, -14.1, 0)], {"width": 0.6, "spacing": 0.7, "speed": -0.5})
	_number(7, Vector2(-14.2, -12.2))


func _path(nm: String, st: String, pts: PackedVector4Array, props: Dictionary) -> Node4D:
	var p := Node4D.new()
	p.name = nm
	p.set_script(Path)
	p.set("style", st)
	for k in props:
		p.set(k, props[k])
	if not pts.is_empty():
		p.set("points", pts)
	add_child(p)
	return p


## A case's number: a short glowing post with a numbered block on it.
func _number(n: int, at: Vector2) -> void:
	var post := MeshInstance4D.new()
	post.name = "Number%d" % n
	post.mesh = Mats.box_mesh(Vector4(0.08, 0.6, 0.08, 0.3))
	post.material_override = _paint()
	post.position = Vector4(at.x, 0.3, at.y, 0.0)
	add_child(post)
	# A seven-segment figure on top of the post: segments top, upper left, upper right, middle,
	# lower left, lower right, bottom.
	var digits := {1: [2, 5], 2: [0, 2, 3, 4, 6], 3: [0, 2, 3, 5, 6], 4: [1, 2, 3, 5], 5: [0, 1, 3, 5, 6], 6: [0, 1, 3, 4, 5, 6], 7: [0, 2, 5]}
	var places := [Vector3(0, 0.36, 0), Vector3(-0.15, 0.18, 0), Vector3(0.15, 0.18, 0), Vector3(0, 0.0, 0), Vector3(-0.15, -0.18, 0), Vector3(0.15, -0.18, 0), Vector3(0, -0.36, 0)]
	for idx in digits.get(n, []):
		var m := MeshInstance4D.new()
		var horizontal: bool = idx == 0 or idx == 3 or idx == 6
		m.mesh = Mats.box_mesh(Vector4(0.28 if horizontal else 0.06, 0.06 if horizontal else 0.3, 0.06, 0.3))
		m.material_override = _paint()
		var pl: Vector3 = places[idx]
		m.position = Vector4(at.x + pl.x, 1.25 + pl.y, at.y, 0.0)
		add_child(m)


## The wall's blue, painted.
func _paint() -> TetraMaterial4D:
	var m := TetraMaterial4D.new()
	m.albedo_color = Color(0.13, 0.40, 0.86)
	return m
