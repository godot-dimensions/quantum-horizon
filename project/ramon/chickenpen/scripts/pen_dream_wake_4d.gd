extends Node

## Leaving the dreamer: a flash, and you come to on the grass in front of the cave, lying on
## your back; you sit up, shake your head, and stand (Ramon, 28 Sept: "after you say you
## leave you can get transported to the pen, with a flash .. and you arrive at the floor in
## front of the cave, you shake your head and stand up").
##
## IN THE PEN, NOT IN THE CAVE. The far room the dreamer lives in is let go the moment you
## are out of the cave, and the cave with it leaves the tree, so whatever runs the waking has
## to be somewhere that stays: here. The dreamer's conversation calls [method wake].
##
## The flash is its own layer above everything, the fade's included. You are carried home
## at its brightest, by the cave's own crossing, and set down a few metres out from the
## arch, on the flat slice, looking back at it - the camera behind you, the cave in front,
## which is the right thing to be staring at while asking what that was. The avatar is
## tipped onto its back and brought up again, turning only its head to shake it; the camera
## starts low and rises with you, since the rig eases its own height back.
##
## THE PLAYER'S OWN KNOCK-DOWN IS NOT USED: it falls forward and gets up at its own pace.
## This one lies on its back for as long as the flash takes to clear, so it holds the body
## still itself (physics off) and poses the avatar the way the knock-down does, turned to
## the body's own heading.

const CaveHill := preload("res://ramon/chickenpen/terrain/pen_cave_hill_4d.gd")

@export var crossing_path: NodePath = NodePath("../../CaveCrossing")
@export var player_path: NodePath = NodePath("../../Player")
@export var box_path: NodePath = NodePath("../../UI/ThoughtBox")
@export var flash: Color = Color(0.86, 0.93, 1.0)
@export_range(0.05, 2.0, 0.05) var rise_seconds: float = 0.35
@export_range(0.0, 3.0, 0.05) var hold_seconds: float = 0.55
@export_range(0.1, 5.0, 0.05) var clear_seconds: float = 1.6
@export_range(0.3, 6.0, 0.1) var lie_seconds: float = 1.0
@export_range(0.3, 5.0, 0.1) var stand_seconds: float = 1.5
@export var line: String = "...What was that?"
## How far in front of the arch you come to.
@export_range(1.0, 12.0, 0.5) var in_front: float = 4.5

var _layer: CanvasLayer
var _rect: ColorRect
var _t := -1.0
var _carried := false
var _avatar: Node4D
var _head: Node4D
var _head_rest: Projection = Projection.IDENTITY
var _facing: float = PI
var _thought_hold := -1.0
## The HUD, kept off screen until you are home - see [method hold_hud].
var _held: Array[CanvasItem] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_layer = CanvasLayer.new()
	_layer.layer = 60
	_layer.visible = false
	add_child(_layer)
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.color = Color(flash, 0.0)
	_layer.add_child(_rect)


## Whether the waking is still going on - for the tests.
func is_waking() -> bool:
	return _t >= 0.0


## Keeps [param items] hidden until the flash has carried you home, then gives them back:
## the conversation that ends in the flash gives its HUD back as it closes, a moment before
## the white is up, and the dial and the rest would blink in over the last shot.
func hold_hud(items: Array) -> void:
	for item in items:
		var c := item as CanvasItem
		if c != null and is_instance_valid(c) and c.visible:
			c.visible = false
			_held.append(c)


func wake() -> void:
	if _t >= 0.0:
		return
	_t = 0.0
	_carried = false
	_layer.visible = true


func _process(delta: float) -> void:
	if _thought_hold >= 0.0:
		var box: Node = get_node_or_null(box_path)
		if box != null and not bool(box.call("is_typing")):
			_thought_hold -= delta
			if _thought_hold <= 0.0:
				_thought_hold = -1.0
				box.call("close")
	if _t < 0.0:
		return
	_t += delta
	var player := get_node_or_null(player_path) as CharacterBody4D
	# Up to white, carried home at its brightest, held, then cleared.
	var alpha := 0.0
	if _t < rise_seconds:
		alpha = smoothstep(0.0, 1.0, _t / rise_seconds)
	elif _t < rise_seconds + hold_seconds:
		alpha = 1.0
		if not _carried:
			_carried = true
			_carry_home(player)
	else:
		alpha = 1.0 - smoothstep(0.0, 1.0, (_t - rise_seconds - hold_seconds) / clear_seconds)
	_rect.color = Color(flash, alpha)
	# Lying there, then up: from the flash's clearing on.
	if _carried and player != null and _avatar != null:
		var up_from: float = rise_seconds + hold_seconds + lie_seconds
		var k: float = clampf((_t - up_from) / stand_seconds, 0.0, 1.0)
		var tip: float = -PI * 0.5 * (1.0 - smoothstep(0.0, 1.0, k))
		_avatar.basis = Basis4D.from_zx(_facing) * Basis4D.from_yz(tip)
		# The shake of the head, while sitting up: a few quick turns, dying away.
		if _head != null:
			var shaking: float = clampf((k - 0.15) / 0.6, 0.0, 1.0)
			var shake: float = 0.35 * sin(shaking * PI * 5.0) * sin(shaking * PI)
			_head.basis = _head_rest * Basis4D.from_zx(shake)
		player.linear_velocity = Vector4.ZERO
		if k >= 1.0:
			_avatar.basis = Basis4D.from_zx(_facing)
			if _head != null:
				_head.basis = _head_rest
			player.set_physics_process(true)
			_think()
			_t = -1.0
			_layer.visible = false


## Home by the cave's own crossing, then set down in front of the arch, on your back.
func _carry_home(player: CharacterBody4D) -> void:
	var crossing: Node = get_node_or_null(crossing_path)
	if crossing != null and bool(crossing.call("is_away")):
		crossing.call("come_back")
	for item in _held:
		if is_instance_valid(item):
			item.visible = true
	_held.clear()
	if player == null:
		return
	var parent := player.get_parent() as Node4D
	var spot: Vector4 = CaveHill.MOUTH + Vector4(0.0, 0.05, in_front, 0.0)
	player.position = parent.global_basis.inverse() * (spot - parent.global_position) if parent != null else spot
	player.linear_velocity = Vector4.ZERO
	player.set_physics_process(false)
	# Facing the cave, which is -z from its mouth; the walker picks up from this heading.
	_facing = PI
	player.set("_facing", _facing)
	_avatar = player.get_node_or_null("Avatar") as Node4D
	_head = _avatar.get("head") as Node4D if _avatar != null else null
	if _head != null:
		_head_rest = _head.basis
	var rig: Node = player.get_node_or_null("CameraRig")
	if rig != null:
		# Back on the flat slice - you walked here through W - and looking at the cave.
		rig.set("_slice_xw", 0.0)
		rig.set("_slice_zw", 0.0)
		rig.set("_homing", 0.0)
		rig.set("yaw", 0.0)
		# The camera starts low, by your head on the grass, and the rig eases it back up.
		rig.set("pivot_height", 0.35)
		rig.set("pitch", deg_to_rad(-4.0))
		if rig.has_method("_apply"):
			rig.call("_apply")


func _think() -> void:
	var box: Node = get_node_or_null(box_path)
	if box == null or line == "":
		return
	box.call("say", String(box.get("player_name")), line)
	_thought_hold = 3.0
