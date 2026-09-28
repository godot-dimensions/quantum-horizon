extends MeshInstance4D

## The glowing sheet across the way through W (cave_rock_4d.gd, W_DOOR), which parts as you
## step into it and closes again behind you once you are back in the chamber.
##
## WHY IT PARTS. The camera follows a few metres behind you, so with the sheet standing you
## went through it twice - once yourself, and again a moment later when the camera caught
## up, the light filling the screen a second time (Ramon, 28 Sept: "like you enter it twice,
## one with character and one with the camera"). It opens when either of you reaches it and
## shuts only when both of you are clear of it on the chamber side.
##
## ITS OWN NODE, NOT PART OF THE BAKE, so it can move: a box with the same colour the bake
## would have given it, closing and opening by shrinking across its middle.

const CaveRock := preload("res://ramon/chickenpen/cave/cave_rock_4d.gd")

@export var player_path: NodePath = NodePath("../../Player")
@export var camera_path: NodePath = NodePath("../../Player/CameraRig/Pitch/Camera4D")
## How close to the sheet along w, on the chamber side, either of you has to come for it to
## open, and how far back into the chamber both of you have to be for it to close.
@export_range(0.0, 3.0, 0.05) var open_within: float = 0.9
@export_range(0.5, 6.0, 0.1) var close_beyond: float = 2.0
@export_range(0.5, 20.0, 0.5) var speed: float = 5.0

var _player: Node4D
var _camera: Node4D
var _open := 0.0
var _size := Vector4.ONE


func _ready() -> void:
	_player = get_node_or_null(player_path) as Node4D
	_camera = get_node_or_null(camera_path) as Node4D
	_size = Vector4(CaveRock.W_PASSAGE_REACH * 2.2, 3.9, CaveRock.W_PASSAGE_HALF * 2.2, 0.05)
	var box := BoxTetraMesh4D.new()
	box.size = _size
	mesh = box
	var material := TetraMaterial4D.new()
	# The shade the baked sheet had before it was its own mesh: the bake darkens every face
	# of a prop but its top by a quarter, and the full colour made the chamber a third
	# brighter round the arch (Ramon, 29 Sept: "the mood is changed in the first cave ...
	# too bright").
	material.albedo_color = CaveRock.W_GLOW.darkened(0.25)
	material_override = material
	position = Vector4(CaveRock.W_DOOR.x, 1.9, CaveRock.W_DOOR.y, CaveRock.W_DOOR.z)


## The w of [param node] in the cave's frame.
func _w_of(node: Node4D) -> float:
	var cave := get_parent() as Node4D
	return (cave.global_basis.inverse() * (node.global_position - cave.global_position)).w


## Whether it is open now - for the tests.
func is_open() -> bool:
	return _open > 0.5


func _process(delta: float) -> void:
	if _player == null:
		return
	var door: float = CaveRock.W_DOOR.z
	var nearest: float = _w_of(_player)
	if _camera != null and _camera.is_inside_tree():
		nearest = maxf(nearest, _w_of(_camera))
	var want: float = _open
	if nearest > door - open_within:
		want = 1.0
	elif nearest < door - close_beyond:
		want = 0.0
	_open = move_toward(_open, want, speed * delta)
	# Across its middle, in y and z - the arch you see - so it parts like a curtain drawn
	# to nothing rather than sliding off.
	var k: float = 1.0 - smoothstep(0.0, 1.0, _open)
	visible = k > 0.02
	basis = Projection(Vector4(1, 0, 0, 0), Vector4(0, k, 0, 0), Vector4(0, 0, k, 0), Vector4(0, 0, 0, 1))
