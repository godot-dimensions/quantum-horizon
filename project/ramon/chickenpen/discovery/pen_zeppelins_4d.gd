@tool
extends Node4D

## THE AIRSHIP FLEET (discovery, 9 Oct 2026; follow_up/pen_discovery_plan.md). Ramon, mid-build: "maybe we can have in
## the far distance some zeppelins you can slide, right of the tower, in a different slice but noticable. and maybe in
## the default slice you see one, but 3 or 4 in the other. keep in mind it should be budget friendly not too many
## details". Pushed out to 150-175 m on 10 Oct: at 95 m the farm's one read as near, not far.
##
## One airship in the farm's slice, four more [member fleet_w] ana, all far out past the mountains' rim to the right
## of the Watchstone (as seen from the farm, looking north), high enough to stand against the sky. Each hull is as
## round through W as it is across ([member hull_w]), so a ship shows within half that of its own W: step through W
## (or turn the slice a little: at a hundred metres a few degrees is metres of W) and the fleet comes and goes.
##
## BUDGET: a ship is a handful of boxes merged into three meshes (hull, red trim and fins, gondola): five ships, fifteen
## mesh instances, a few hundred tetrahedra. They are kept out of the projection (P): far, big and spread through W,
## they would lay their whole ghosts over the sky (the W Exploder's copies "smeared it white" the same way). They
## drift slowly along x, back and forth, and bob.
##
## Built when it loads (and in the editor, to place it), never saved into the scene. Move this node to move the fleet.
## NO class_name (engine_gotchas.md).

## Each ship: [position (global offsets from this node), length, drift speed (m/s), drift range (m)].
@export var ships: Array = [
	[Vector4(24.0, 60.0, -150.0, 0.0), 30.0, 0.7, 22.0],
	[Vector4(-4.0, 56.0, -158.0, 9.0), 26.0, 0.9, 18.0],
	[Vector4(18.0, 67.0, -170.0, 9.0), 32.0, 0.6, 20.0],
	[Vector4(42.0, 58.0, -152.0, 9.0), 24.0, 1.0, 16.0],
	[Vector4(62.0, 71.0, -174.0, 9.0), 28.0, 0.75, 20.0],
]:
	set(v):
		ships = v
		_later()
## How round a hull is through W, as a share of its height (1: as round in W as across).
@export_range(0.3, 1.5, 0.05) var hull_w: float = 1.0
@export var hull_colour: Color = Color(0.86, 0.84, 0.78)
@export var trim_colour: Color = Color(0.70, 0.20, 0.17)
@export var gondola_colour: Color = Color(0.22, 0.20, 0.19)

var _nodes: Array[Node4D] = []
var _t: float = 0.0


func _later() -> void:
	if is_node_ready():
		rebuild()


func _ready() -> void:
	rebuild()


func rebuild() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			remove_child(n)
			n.free()
	_nodes.clear()
	for i in ships.size():
		var spec: Array = ships[i]
		var ship := Node4D.new()
		ship.name = "Airship%d" % i
		add_child(ship)
		ship.position = spec[0]
		_build(ship, float(spec[1]))
		_nodes.append(ship)


## One airship along x, [param length] long: a hull of three stepped boxes each end round a long middle, a red band
## and four fins, a gondola under it. All as deep in W as they are tall (times hull_w).
func _build(ship: Node4D, length: float) -> void:
	var h: float = length * 0.2
	var hull := ArrayTetraMesh4D.new()
	_add(hull, Vector4(0, 0, 0, 0), Vector4(length * 0.56, h, h, h * hull_w))
	for side in [-1.0, 1.0]:
		_add(hull, Vector4(side * length * 0.33, 0, 0, 0), Vector4(length * 0.12, h * 0.82, h * 0.82, h * 0.82 * hull_w))
		_add(hull, Vector4(side * length * 0.42, 0, 0, 0), Vector4(length * 0.07, h * 0.6, h * 0.6, h * 0.6 * hull_w))
		_add(hull, Vector4(side * length * 0.475, 0, 0, 0), Vector4(length * 0.04, h * 0.34, h * 0.34, h * 0.34 * hull_w))
	var trim := ArrayTetraMesh4D.new()
	_add(trim, Vector4(length * 0.1, 0, 0, 0), Vector4(length * 0.03, h * 1.02, h * 1.02, h * 1.02 * hull_w))
	# Fins at the tail (-x): up, down, and either side in z; the W pair would be the same cut again, so none.
	for fin in [Vector4(0, 1, 0, 0), Vector4(0, -1, 0, 0), Vector4(0, 0, 1, 0), Vector4(0, 0, -1, 0)]:
		var size := Vector4(length * 0.14, h * 0.5 if fin.y != 0.0 else h * 0.06, h * 0.06 if fin.y != 0.0 else h * 0.5, h * 0.06 * hull_w)
		_add(trim, Vector4(-length * 0.4, 0, 0, 0) + fin * h * 0.55, size)
	var gondola := ArrayTetraMesh4D.new()
	_add(gondola, Vector4(length * 0.05, -h * 0.62, 0, 0), Vector4(length * 0.16, h * 0.18, h * 0.22, h * 0.22 * hull_w))
	_mesh(ship, "Hull", hull, hull_colour)
	_mesh(ship, "Trim", trim, trim_colour)
	_mesh(ship, "Gondola", gondola, gondola_colour)


func _add(into: ArrayTetraMesh4D, at: Vector4, size: Vector4) -> void:
	var box := BoxTetraMesh4D.new()
	box.size = size
	into.merge_with(box.to_array_tetra_mesh(), at, Projection.IDENTITY)


func _mesh(ship: Node4D, part: String, mesh: ArrayTetraMesh4D, colour: Color) -> void:
	var node := MeshInstance4D.new()
	node.name = part
	node.mesh = mesh
	var mat := TetraMaterial4D.new()
	mat.albedo_color = colour
	node.material_override = mat
	# Out of the projection (P): far, big and spread through W, their ghosts would cover the sky.
	node.set("allow_projection", false)
	ship.add_child(node)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_t += delta
	for i in mini(_nodes.size(), ships.size()):
		var spec: Array = ships[i]
		var home: Vector4 = spec[0]
		var speed: float = float(spec[2])
		var span: float = float(spec[3])
		# Back and forth along x over its range, slowing at the ends, turning round there; a slow bob.
		var phase: float = _t * speed / maxf(span, 1.0) + float(i) * 1.7
		var along: float = sin(phase) * span
		# Nose along its way: turning round, slowly, as it slows at each end of its range.
		var heading: float = PI * (1.0 - smoothstep(-0.3, 0.3, cos(phase)))
		_nodes[i].position = home + Vector4(along, sin(_t * 0.21 + float(i)) * 0.6, 0.0, 0.0)
		_nodes[i].basis = Basis4D.from_zx(heading)
