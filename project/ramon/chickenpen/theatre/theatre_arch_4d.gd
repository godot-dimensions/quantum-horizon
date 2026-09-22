@tool
extends Node4D

## A door that is not in a wall: an arch with a field across it, used both for the one
## Trym raises in the field and the one that brings you back.
##
## ONE SCRIPT FOR BOTH ENDS. They are the same object doing the same job in opposite
## directions - a frame, a field, a trigger and a destination - and writing the exit
## separately would mean two places to get the crossing wrong.
##
## IT GROWS RATHER THAN APPEARING. A door that exists on one frame and not the previous
## one reads as a loading error; the same door unfolding over a second and a half reads as
## somebody switching it on. The frame comes up first and the field fills in after, because
## that order is the one that looks deliberate.
##
## IT RISES OUT OF THE GROUND AND LEAVES THROUGH THE AIR. Opening, the frame comes up from
## under the floor; shutting, it lifts away upward instead of sinking back where it came
## from. Same animation, opposite direction, and the difference is the whole read: one is
## a thing being built, the other is a thing being taken away.
##
## AND WHEN IT IS SHUT IT IS NOT THERE AT ALL. Hidden, not merely lowered - a closed door
## parked under the floor still has its lintel at ground level, which is a mystery beam
## lying in a field from the moment the scene loads.
##
## THE FIELD IS THICK THROUGH W. It is a doorway in four dimensions and a player who has
## turned their slice must still be able to walk into it - a thin one would be a door that
## only exists on the slice it was built on, which is a joke this scene has already made
## once and should not make by accident.

signal entered

@export_tool_button("Rebuild") var _rebuild_action: Callable = rebuild

@export var player_path: NodePath
## Off until something switches it on. The one Trym raises in the field starts off; the
## one at the head of the theatre's walkway is simply standing when you get there.
@export var armed: bool = true: set = _set_armed
## Open the moment it is built, for a door that is meant to be already standing.
@export var starts_open: bool = false

@export_group("Shape")
@export_range(0.8, 6.0, 0.1) var width: float = 2.2
@export_range(1.4, 8.0, 0.1) var height: float = 3.1
@export_range(0.1, 1.0, 0.05) var frame_thickness: float = 0.26
@export_range(0.5, 12.0, 0.5) var w_depth: float = 5.0
@export var frame_color: Color = Color(0.16, 0.19, 0.27)
@export var edge_color: Color = Color(0.32, 0.86, 1.0)
@export var field_color: Color = Color(0.20, 0.62, 0.95)

@export_group("Opening")
@export_range(0.2, 6.0, 0.1) var open_seconds: float = 1.5
@export_range(0.3, 4.0, 0.1) var enter_within: float = 1.15

var _player: Node4D
var _frame: Node4D
var _field: MeshInstance4D
var _open: float = 0.0
var _used: bool = false
var _shutting: bool = false


func _set_armed(v: bool) -> void:
	armed = v
	if not is_node_ready():
		return
	if armed:
		_shutting = false
	elif _open > 0.05:
		# It was standing. Take it away upward rather than snapping it off.
		_shutting = true
	else:
		_open = 0.0
		_used = false


func _ready() -> void:
	_player = get_node_or_null(player_path) as Node4D
	rebuild()
	_open = 1.0 if starts_open else 0.0
	visible = _open > 0.005


func rebuild() -> void:
	for child in get_children():
		child.free()
	_frame = Node4D.new()
	_frame.name = "Frame"
	add_child(_frame)
	_own(_frame)

	var half: float = width * 0.5
	for side in [-1.0, 1.0]:
		_bar(_frame, "Post%d" % int(side), Vector4(side * half, height * 0.5, 0.0, 0.0),
			Vector3(frame_thickness, height, frame_thickness), frame_color)
		_bar(_frame, "PostEdge%d" % int(side),
			Vector4(side * half, height * 0.5, frame_thickness * 0.55, 0.0),
			Vector3(frame_thickness * 0.35, height * 0.94, frame_thickness * 0.3), edge_color)
	_bar(_frame, "Lintel", Vector4(0.0, height, 0.0, 0.0),
		Vector3(width + frame_thickness, frame_thickness, frame_thickness), frame_color)
	_bar(_frame, "LintelEdge", Vector4(0.0, height, frame_thickness * 0.55, 0.0),
		Vector3(width * 0.96, frame_thickness * 0.3, frame_thickness * 0.3), edge_color)
	_bar(_frame, "Sill", Vector4(0.0, 0.06, 0.0, 0.0),
		Vector3(width + frame_thickness, 0.12, frame_thickness * 1.3), edge_color)

	_field = _bar(self, "Field", Vector4(0.0, height * 0.5, 0.0, 0.0),
		Vector3(width * 0.92, height * 0.92, 0.06), field_color)
	_own(_field)


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _frame == null:
		return
	var want: float = 1.0 if armed else 0.0
	_open = move_toward(_open, want, delta / maxf(open_seconds, 0.05))
	# The frame rises first; the field fills in over the back half.
	visible = _open > 0.005
	if not visible:
		return
	var up: float = clampf(_open * 1.6, 0.0, 1.0)
	_frame.basis = Basis4D.from_zx(0.0)
	# Down through the floor on the way in, up into the air on the way out.
	var away: float = height * (1.0 - up) * (1.0 if _shutting else -1.0)
	_frame.position = Vector4(0.0, away, 0.0, 0.0)
	var fill: float = clampf((_open - 0.45) / 0.55, 0.0, 1.0)
	_field.visible = fill > 0.01
	if _field.mesh is BoxTetraMesh4D:
		(_field.mesh as BoxTetraMesh4D).size = Vector4(width * 0.92 * fill,
			height * 0.92 * fill, 0.06, w_depth)
	var glow: TetraMaterial4D = _field.material_override as TetraMaterial4D
	if glow != null:
		var shimmer: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.004)
		glow.albedo_color = field_color.lerp(Color(0.85, 0.97, 1.0), shimmer * 0.5)

	if _used or _open < 0.99 or _player == null:
		return
	var gap: Vector4 = _player.global_position - global_position
	# Height is ignored: you walk through a doorway, you do not have to be level with its
	# middle. W is not - a door on another slice is not a door you are standing in.
	if Vector2(gap.x, gap.z).length() <= enter_within and absf(gap.w) <= w_depth * 0.5:
		_used = true
		entered.emit()


## Lets it be walked through again, for a door that is used more than once.
func rearm() -> void:
	_used = false


func _bar(parent: Node, part: String, at: Vector4, size: Vector3,
		colour: Color) -> MeshInstance4D:
	var node := MeshInstance4D.new()
	node.name = part
	var mesh := BoxTetraMesh4D.new()
	mesh.size = Vector4(size.x, size.y, size.z, w_depth)
	node.mesh = mesh
	var material := TetraMaterial4D.new()
	material.albedo_color = colour
	node.material_override = material
	parent.add_child(node)
	node.position = at
	_own(node)
	return node


func _own(node: Node) -> void:
	if Engine.is_editor_hint() and get_tree() != null and get_tree().edited_scene_root != null:
		node.owner = get_tree().edited_scene_root
