@tool
extends Node4D

## Trym, at a desk behind the pen, who stands up when you come and talk to him.
##
## SEATED IS A POSE, NOT A MODEL. He is the same block_avatar_4d as everybody else in this
## scene, with his hips and knees folded and the figure dropped to the height of the stool.
## That means he inherits every proportion fix the others get, and standing up is the same
## pose played backwards rather than a second model swapped in for the first.
##
## THE JOINT SIGNS ARE BORROWED, NOT REASONED. Basis4D.from_yz turns the opposite way to
## the obvious reading - block_gait_4d.gd has the note, having been caught by it - so a
## NEGATIVE hip angle swings the thigh forward and a POSITIVE knee angle folds the shin
## back under it. Sitting is thigh forward, shin down: -1.40 and +1.40, and their sum is
## what the ankle undoes to keep the boot flat.
##
## THE GET-UP IS EXPOSED, NOT OWNED. He rises when you press the talk key beside him, and
## `stand_up()`/`sit_down()` are public. The conversation itself belongs to the dialogue
## system, which is being written elsewhere; this watches the key without consuming it, so
## when a real conversation lands on him it drives the same get-up and nothing here has to
## change. Watching rather than handling is also why he cannot steal the key from the
## catcher - he never claims it at all.

const AVATAR := preload("res://ramon/chickenpen/scripts/block_avatar_4d.gd")

@export_tool_button("Rebuild") var _rebuild_action: Callable = rebuild

@export var player_path: NodePath
@export var shirt: Color = Color(0.10, 0.11, 0.13): set = _set_shirt
@export var skin: Color = Color(0.91, 0.76, 0.63): set = _set_skin
@export var hair: Color = Color(0.13, 0.10, 0.08): set = _set_hair
@export var timber: Color = Color(0.21, 0.16, 0.15): set = _set_timber
## Trousers. The shared avatar paints legs, face and hands from ONE colour, so a figure in
## a black shirt comes out bare-legged; rather than split that colour for every character
## in the scene, his legs get a dark block sleeved over them here.
@export var trousers: Color = Color(0.19, 0.21, 0.27): set = _set_trousers

@export_group("Standing up")
## How close before he is worth talking to, and how far through W he can still hear you.
@export_range(0.5, 12.0, 0.5) var notice_within: float = 3.2
@export_range(0.5, 10.0, 0.5) var notice_within_w: float = 2.5
## How long the whole get-up takes. Slow enough to read as effort, not a snap.
@export_range(0.2, 4.0, 0.05) var rise_seconds: float = 0.85
@export_range(0.5, 20.0, 0.5) var turn_speed: float = 5.0
## He also gets up if you simply stand there long enough, so the character is not invisible
## to anyone who never presses the key.
## Zero disables it: he stays at his desk until the key is actually pressed, so getting up
## is the beat that opens the conversation rather than something that already happened
## while you were walking over.
@export_range(0.0, 10.0, 0.5) var rises_anyway_after: float = 0.0

@export_group("Bookshelf")
## A case of books beside the desk. Offsets are in HIS frame, not the world's, so turning
## him to face a different doorway carries his furniture round with him.
## Y is the shed floor's own thickness, so the case stands ON the boards rather than
## sinking through them.
@export var shelf_offset: Vector4 = Vector4(1.37, 0.06, -0.06, 0.0): set = _set_shelf_at
## Turned to stand along the back wall instead of across it.
@export_range(-180.0, 180.0, 5.0) var shelf_yaw_degrees: float = -90.0: set = _set_shelf_yaw
@export var shelf_size: Vector3 = Vector3(1.15, 1.55, 0.32): set = _set_shelf_size
@export_range(2, 6, 1) var shelf_rows: int = 3: set = _set_shelf_rows
## Books are drawn as spines of varying width and height, in a fixed palette rather than
## random colours - random reads as noise, a palette reads as a shelf somebody filled.
@export var book_colors: PackedColorArray = PackedColorArray([
	Color(0.40, 0.17, 0.15), Color(0.21, 0.29, 0.21), Color(0.19, 0.24, 0.35),
	Color(0.63, 0.53, 0.38), Color(0.34, 0.25, 0.19), Color(0.25, 0.35, 0.34),
	Color(0.75, 0.69, 0.55), Color(0.45, 0.31, 0.17), Color(0.30, 0.20, 0.22),
	Color(0.55, 0.45, 0.24),
]): set = _set_books

@export_group("Furniture")
@export_range(0.15, 1.2, 0.01) var seat_height: float = 0.42
## Where the stool sits in front of the desk, and how far back he steps to stand.
@export_range(0.2, 1.5, 0.01) var seat_offset: float = 0.62
@export_range(0.0, 1.0, 0.01) var stand_back: float = 0.33

## Sitting folds the leg into a right angle at the hip and another at the knee. Under 90
## degrees at the hip, so the thigh declines slightly rather than sticking straight out.
const THIGH_SIT: float = -1.40
const SHIN_SIT: float = 1.40
## What that pose costs in height: thigh 0.32 at 1.40 off vertical, then a vertical shin
## and the sole of the boot. Dropping the figure by this much puts his feet on the floor
## instead of dangling or sinking.
const SIT_DROP: float = 0.25

var _figure: Node4D
var _player: Node4D
var _rise: float = 0.0
var _facing: float = PI
var _rest_facing: float = PI
var _dwell: float = 0.0
var _roused: bool = false
## The invitation borrows him: while it has him he ignores proximity entirely, and the
## figure walks out of the shed WITHOUT the desk, stool and bookshelf coming too. Which is
## why the walk is an offset on the figure and not a move of this node - this node is the
## furniture.
var _taken: bool = false
var _walk := Vector4.ZERO
var _walk_facing: float = 0.0
var _stride: float = 0.0
var _moving: bool = false


func _set_shirt(v: Color) -> void: shirt = v; _later()
func _set_skin(v: Color) -> void: skin = v; _later()
func _set_hair(v: Color) -> void: hair = v; _later()
func _set_timber(v: Color) -> void: timber = v; _later()
func _set_shelf_at(v: Vector4) -> void: shelf_offset = v; _later()
func _set_shelf_yaw(v: float) -> void: shelf_yaw_degrees = v; _later()
func _set_shelf_size(v: Vector3) -> void: shelf_size = v; _later()
func _set_shelf_rows(v: int) -> void: shelf_rows = v; _later()
func _set_books(v: PackedColorArray) -> void: book_colors = v; _later()
func _set_trousers(v: Color) -> void: trousers = v; _later()


func _ready() -> void:
	_player = get_node_or_null(player_path) as Node4D
	rebuild()


func _later() -> void:
	if is_node_ready():
		rebuild()


func rebuild() -> void:
	for child in get_children():
		child.free()

	var desk_top: float = 0.62
	_box(self, "DeskTop", Vector4(0.0, desk_top, 0.0, 0.0), Vector3(1.05, 0.07, 0.56), timber)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_box(self, "DeskLeg%s%s" % ["P" if sx > 0.0 else "N", "P" if sz > 0.0 else "N"],
				Vector4(sx * 0.46, desk_top * 0.5, sz * 0.22, 0.0),
				Vector3(0.07, desk_top, 0.07), timber)
	_box(self, "Stool", Vector4(0.0, seat_height * 0.5, seat_offset, 0.0),
		Vector3(0.40, seat_height, 0.40), timber)

	_bookshelf()

	# The laptop. The lid is hinged at the back of the base and the screen is a CHILD of
	# the lid, so tipping the lid carries the screen with it - two boxes rotated separately
	# about their own origins would have come apart at the hinge.
	var deck: float = desk_top + 0.05
	_box(self, "LaptopBase", Vector4(0.0, deck, 0.02, 0.0), Vector3(0.40, 0.03, 0.28),
		Color(0.21, 0.22, 0.25))
	var lid := _box(self, "LaptopLid", Vector4(0.0, deck + 0.01, -0.13, 0.0),
		Vector3(0.40, 0.27, 0.025), Color(0.19, 0.20, 0.23))
	# Negative, so the lid leans AWAY from the stool and its face turns towards whoever is
	# sitting there. The hinge is at the far edge; leaning the other way folds it shut.
	lid.basis = Basis4D.from_yz(-0.30)
	lid.position += Vector4(0.0, 0.12, 0.0, 0.0)
	_box(lid, "Screen", Vector4(0.0, 0.0, 0.017, 0.0), Vector3(0.35, 0.22, 0.004),
		Color(0.40, 0.66, 0.58))

	# Him. Properties BEFORE add_child: the avatar builds itself in _ready, which fires the
	# moment it is parented, and anything set afterwards arrives too late to affect it.
	var figure := Node4D.new()
	figure.name = "Figure"
	figure.set_script(AVATAR)
	figure.set("build", 2)
	figure.set("skin", shirt)
	figure.set("accent", skin)
	figure.set("hair", hair)
	figure.set("wear_cap", false)
	# Set wide and a shade narrow: level, unhurried, listening.
	figure.set("eyes", true)
	figure.set("eye_colour", Color(0.11, 0.12, 0.16))
	figure.set("eye_spacing", 0.080)
	figure.set("eye_height", 0.035)
	figure.set("eye_width", 0.040)
	figure.set("eye_tall", 0.044)
	add_child(figure)
	_own(figure)
	_figure = figure

	# Sleeved over each leg segment, a shade wider so it reads as cloth over the limb
	# rather than fighting with it - the same shade wider through W (the thigh is 0.2575
	# through W, the shin 0.2325: block_avatar_4d.gd W_SIZES). Parented to the joints, so it
	# bends with the pose.
	for tag in ["L", "R"]:
		var hip: Node4D = figure.get_node_or_null("Hip%s" % tag) as Node4D
		var knee: Node4D = figure.get_node_or_null("Hip%s/Knee%s" % [tag, tag]) as Node4D
		if hip != null:
			_box(hip, "Trouser%s" % tag, Vector4(0.0, -0.16, 0.0, 0.0),
				Vector3(0.145, 0.33, 0.155), trousers, 0.2725)
		if knee != null:
			_box(knee, "TrouserLower%s" % tag, Vector4(0.0, -0.16, 0.0, 0.0),
				Vector3(0.135, 0.33, 0.145), trousers, 0.2475)

	_facing = _rest_facing
	_dwell = 0.0
	_roused = false
	_apply(0.0)


func _box(parent: Node, part: String, at: Vector4, size: Vector3, colour: Color,
		w: float = 0.0) -> MeshInstance4D:
	var node := MeshInstance4D.new()
	node.name = part
	var mesh := BoxTetraMesh4D.new()
	# A real extent through W, or it disappears the moment the player slices off it.
	mesh.size = Vector4(size.x, size.y, size.z,
		w if w > 0.0 else maxf(maxf(size.x, size.z), 0.45))
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


## Public, so a conversation can drive the get-up properly once the dialogue lands.
func stand_up() -> void:
	_roused = true


func sit_down() -> void:
	_roused = false
	_dwell = 0.0


## Hands him to something that wants to stage a scene with him. He stays up whether or not
## the player is standing near, because a man who sits back down mid-sentence is a bug.
func take_over() -> void:
	_taken = true
	_roused = true


func release() -> void:
	_taken = false
	_moving = false
	_walk = Vector4.ZERO


## Puts him back where he started: at the desk, sitting, visible, facing his laptop. Used
## when the player comes home from somewhere he went ahead to - the alternative is a farm
## with an empty stool in it and a character you can never speak to again.
func return_to_desk() -> void:
	release()
	_stride = 0.0
	_rise = 0.0
	_roused = false
	_dwell = 0.0
	_facing = _rest_facing
	_walk_facing = 0.0
	if _figure != null:
		_figure.visible = true
	_apply(0.0)


## One step of a walk towards a point in WORLD space. True once he is there.
##
## He will not move until he is on his feet - the get-up has to finish, or he slides out of
## the shed still folded into the shape of the stool.
func walk_towards(target: Vector4, speed: float, delta: float) -> bool:
	if _figure == null:
		return true
	var here: Vector4 = _figure.global_position
	var to := Vector4(target.x - here.x, 0.0, target.z - here.z, 0.0)
	var flat: float = Vector2(to.x, to.z).length()
	if flat <= 0.12:
		_moving = false
		return true
	if not is_standing():
		_moving = false
		return false
	var dir: Vector4 = to / flat
	var step: float = minf(speed * delta, flat)
	_walk += dir * step
	_stride += step * 3.6
	_moving = true
	# Into HIS frame: _facing is applied to the figure as a local basis, and this node is
	# turned to face along the shed.
	var local: Vector4 = global_basis.inverse() * dir
	_walk_facing = atan2(local.x, local.z)
	return false


## Turns him on the spot to look at a point in world space.
func face_towards(target: Vector4) -> void:
	if _figure == null:
		return
	var to: Vector4 = target - _figure.global_position
	var local: Vector4 = global_basis.inverse() * Vector4(to.x, 0.0, to.z, 0.0)
	if Vector2(local.x, local.z).length() > 0.01:
		_walk_facing = atan2(local.x, local.z)


func set_figure_visible(shown: bool) -> void:
	if _figure != null:
		_figure.visible = shown


## Puts the figure down at a point in WORLD space, without walking him there. For the end
## of a trip he did not walk back from.
func place_at(target: Vector4) -> void:
	if _figure == null:
		return
	var here: Vector4 = _figure.global_position
	_walk += Vector4(target.x - here.x, 0.0, target.z - here.z, 0.0)
	_stride = 0.0
	_moving = false


## Is he on his way somewhere? True from the moment he sets off until he arrives.
##
## Asked by his talk driver, which refuses to open a conversation while he is walking.
## Talking stages a shot and slides the player onto a marker beside him, and that marker
## is a fixed node back at the shed - so catching him halfway across the field put you in
## the shed while he carried on walking away from you.
func is_walking() -> bool:
	return _moving


## Where his head is now, for anything that has to point at him while he is moving - his
## speech tag is anchored to a fixed marker at the desk, which stops being where he is the
## moment he stands up and walks off.
func head_position() -> Vector4:
	if _figure == null:
		return global_position
	return _figure.global_position + Vector4(0.0, 1.5, 0.0, 0.0)


## True once he is on his feet, for anything that wants to wait for him.
func is_standing() -> bool:
	return _rise > 0.95


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _figure == null:
		return
	var near: bool = false
	var want: float = _rest_facing
	if _taken:
		# Borrowed: no proximity, no dwell, no sitting back down. He faces where he walks.
		_rise = minf(_rise + delta / maxf(rise_seconds, 0.01), 1.0)
		_facing = rotate_toward(_facing, _walk_facing, turn_speed * delta)
		_apply(_rise)
		return
	if _player != null:
		var gap: Vector4 = _player.global_position - global_position
		near = Vector2(gap.x, gap.z).length() <= notice_within \
			and absf(gap.w) <= notice_within_w
		if near:
			# In the node's OWN frame, because _facing is applied to the figure as a local
			# basis. Turning this node - which is how the shed aims him - rotates that
			# frame, and a world-space angle would then be wrong by exactly that much.
			# And from where the FIGURE stands, not the node: standing, he has stepped back
			# from the stool, and from a couple of metres away aiming from the stool put him
			# 20 degrees off you (6 Oct). face_towards() already aims from the figure.
			var local: Vector4 = global_basis.inverse() * (_player.global_position - _figure.global_position)
			want = atan2(local.x, local.z)

	if not near:
		_dwell = 0.0
		_roused = false
	else:
		_dwell += delta
		# Addressed, or simply stood next to for long enough that ignoring you would read
		# as a broken character rather than a busy one.
		if Input.is_action_just_pressed(&"catch_target") \
				or (rises_anyway_after > 0.0 and _dwell >= rises_anyway_after):
			_roused = true

	var step: float = delta / maxf(rise_seconds, 0.01)
	_rise = clampf(_rise + (step if _roused else -step), 0.0, 1.0)
	# He only turns once he is off the stool. Swivelling in the seat would be a different,
	# less deliberate character.
	_facing = rotate_toward(_facing, want if _rise > 0.55 else _rest_facing,
		turn_speed * delta)
	_apply(_rise)


## A case of books. Carcass, shelves, then a row of spines per shelf, packed left to right
## until the shelf runs out - so changing the width changes how many books fit rather than
## stretching the ones that are there.
func _bookshelf() -> void:
	if shelf_size.x < 0.1 or shelf_size.y < 0.1:
		return
	var case := Node4D.new()
	case.name = "Bookshelf"
	add_child(case)
	_own(case)
	case.position = shelf_offset
	case.basis = Basis4D.from_zx(deg_to_rad(shelf_yaw_degrees))

	var wide: float = shelf_size.x
	var tall: float = shelf_size.y
	var deep: float = shelf_size.z
	var panel: float = 0.05

	_box(case, "ShelfBack", Vector4(0.0, tall * 0.5, -deep * 0.5 + panel * 0.5, 0.0),
		Vector3(wide, tall, panel), timber)
	for sx in [-1.0, 1.0]:
		_box(case, "ShelfSide%s" % ("P" if sx > 0.0 else "N"),
			Vector4(sx * (wide * 0.5 - panel * 0.5), tall * 0.5, 0.0, 0.0),
			Vector3(panel, tall, deep), timber)
	_box(case, "ShelfTop", Vector4(0.0, tall - panel * 0.5, 0.0, 0.0),
		Vector3(wide, panel, deep), timber)

	# Rows, and the books standing on each of them.
	var inner: float = wide - panel * 2.0
	# shelf_rows books-bearing boards plus the top, with the first sitting on the floor.
	var gap: float = (tall - panel) / float(shelf_rows)
	for row in shelf_rows + 1:
		var y: float = panel * 0.5 + gap * float(row)
		_box(case, "Shelf%d" % row, Vector4(0.0, y, 0.0, 0.0),
			Vector3(wide, panel, deep), timber)
		if row >= shelf_rows or book_colors.is_empty():
			continue
		var x: float = -inner * 0.5
		var index: int = row * 3
		while x < inner * 0.5 - 0.03:
			# Widths and heights vary by a repeating pattern rather than at random: a shelf
			# of identical books reads as a texture, and a shelf of noise reads as rubble.
			var thick: float = 0.035 + 0.022 * float(index % 4)
			if x + thick > inner * 0.5:
				break
			var height: float = gap * (0.62 + 0.09 * float(index % 3))
			_box(case, "Book%d_%d" % [row, index],
				Vector4(x + thick * 0.5, y + panel * 0.5 + height * 0.5, 0.0, 0.0),
				Vector3(thick, height, deep * 0.78),
				book_colors[index % book_colors.size()])
			x += thick + 0.008
			index += 1


## 0 is seated at the laptop, 1 is standing clear of the stool, and every value between is
## the same pose part-played - which is the whole animation.
func _apply(rise: float) -> void:
	var sat: float = 1.0 - rise
	_figure.position = Vector4(0.0, -SIT_DROP * sat,
		seat_offset + stand_back * rise, 0.0) + global_basis.inverse() * _walk
	_figure.basis = Basis4D.from_zx(_facing)
	var thigh: float = THIGH_SIT * sat
	var shin: float = SHIN_SIT * sat
	# A stride, so he walks out rather than skating out. Same sign convention as the sit:
	# NEGATIVE hip swings the thigh forward, POSITIVE knee folds the shin back under it -
	# so the knee bends on the leg that is travelling backwards, which is the one lifting.
	var swing: float = sin(_stride) * 0.42 if _moving else 0.0
	for side in ["left", "right"]:
		var lead: float = -swing if side == "left" else swing
		var hip: Node4D = _figure.get("hip_%s" % side) as Node4D
		var knee: Node4D = _figure.get("knee_%s" % side) as Node4D
		var ankle: Node4D = _figure.get("ankle_%s" % side) as Node4D
		var hip_angle: float = thigh + lead
		var knee_angle: float = shin + maxf(0.0, lead) * 0.75
		if hip != null:
			hip.basis = Basis4D.from_yz(hip_angle)
		if knee != null:
			knee.basis = Basis4D.from_yz(knee_angle)
		if ankle != null:
			# Rotations compose down the chain, so undoing their sum keeps the boot flat to
			# the floor however the leg is folded.
			ankle.basis = Basis4D.from_yz(-(hip_angle + knee_angle))
	# Arms reaching forward to the keyboard, elbows bent back, and both unfolding to his
	# sides as he rises - then counter-swinging to whichever leg is forward.
	for side in ["left", "right"]:
		var counter: float = swing if side == "left" else -swing
		var shoulder: Node4D = _figure.get("shoulder_%s" % side) as Node4D
		var elbow: Node4D = _figure.get("elbow_%s" % side) as Node4D
		if shoulder != null:
			shoulder.basis = Basis4D.from_yz(-1.05 * sat + counter * 0.6)
		if elbow != null:
			elbow.basis = Basis4D.from_yz(0.45 * sat + absf(counter) * 0.4)
	# A slight lean into the screen while seated, straightening as he gets up.
	var torso: Node4D = _figure.get("torso") as Node4D
	if torso != null:
		torso.basis = Basis4D.from_yz(-0.16 * sat)
