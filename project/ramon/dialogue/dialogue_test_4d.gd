extends Node4D

## A small 4D world with one keeper in it, for judging the dialogue in the situation it
## will actually be used in.
##
## Not chickenpen: no chickens, no gait, no orbit rig. Just enough world to prove the three
## things a fixed test panel cannot - that the tag sits over his head as you move, that it
## goes away when you step off his slice, and that walking up to someone and pressing a
## key is a reasonable way to start a conversation.
##
## MOVEMENT IS LOCKED WHILE TALKING. Cheaper and far less buggy than letting the player
## wander off mid-sentence, and it leaves room for a camera move later.

@onready var _walker: Node4D = $Walker
@onready var _keeper: Node4D = $World/Keeper
@onready var _camera: Camera4D = $Camera
@onready var _tag: WorldTag4D = $UI/Tag
@onready var _box: DialogueBox4D = $UI/Box
@onready var _talk: DialoguePlayer4D = $Player
@onready var _locator: Label = $UI/Locator
@onready var _help: Label = $UI/Help

## How close, on the ground, before he is worth talking to.
@export_range(1.0, 12.0, 0.5) var talk_range: float = 3.2
## And how far through W. Tighter than the tag's own fade, so the prompt appears slightly
## before you are close enough to be addressed rather than the other way round.
@export_range(0.5, 6.0, 0.5) var talk_range_w: float = 1.6
@export_range(1.0, 12.0, 0.5) var walk_speed: float = 4.0
## A third of walking pace, the same ratio chickenpen settled on: a tap of the W key should
## not carry you past everything in the world.
@export_range(0.2, 6.0, 0.1) var w_speed: float = 1.3

var _has_gauntlet: bool = false


func _ready() -> void:
	for label in [_locator, _help]:
		label.add_theme_font_size_override("font_size", 19)
	_locator.add_theme_color_override("font_color", Color(0.62, 0.86, 0.72))
	_help.add_theme_color_override("font_color", Color(0.72, 0.76, 0.82))
	_help.add_theme_color_override("font_outline_color", Color(0.05, 0.06, 0.09, 0.85))
	_help.add_theme_constant_override("outline_size", 5)
	_help.text = "WASD walk    Q/E ana and kata    F talk, advance, confirm - hold to hurry    1-9 or Up/Down pick    Esc leave    R reset"

	_talk.use_script(KeeperScript.NODES, KeeperScript.START, Callable(KeeperScript, "fill"))
	_talk.returned = 0
	_talk.total = 12
	_talk.effect.connect(_on_effect)
	_refresh_locator()
	_frame_camera()


func _process(delta: float) -> void:
	if not _talk.is_running():
		_walk(delta)
	_frame_camera()
	_tag_text()


func _walk(delta: float) -> void:
	var move := Vector4.ZERO
	if Input.is_key_pressed(KEY_W):
		move.z -= 1.0
	if Input.is_key_pressed(KEY_S):
		move.z += 1.0
	if Input.is_key_pressed(KEY_A):
		move.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		move.x += 1.0
	var flat := Vector2(move.x, move.z)
	if flat.length() > 0.001:
		flat = flat.normalized() * walk_speed * delta
		_walker.position += Vector4(flat.x, 0.0, flat.y, 0.0)
	if Input.is_key_pressed(KEY_E):
		_walker.position.w += w_speed * delta
	if Input.is_key_pressed(KEY_Q):
		_walker.position.w -= w_speed * delta


## A fixed chase camera. It carries the walker's W with it, so stepping through the fourth
## direction takes the whole view with you - which is what makes the keeper fade out rather
## than simply move.
func _frame_camera() -> void:
	var here: Vector4 = _walker.global_position
	# Offset to the shoulder rather than straight behind: dead centre, the walker's own
	# body stands exactly in front of whoever you are trying to talk to.
	var eye := Vector4(here.x + 1.7, here.y + 2.5, here.z + 4.6, here.w)
	var look := Vector4(here.x - 0.4, here.y + 1.1, here.z - 2.4, here.w)
	_camera.global_position = eye
	_camera.global_basis = Basis4D.looking_at(look - eye)


func _tag_text() -> void:
	if _talk.is_running():
		_tag.clear()
		return
	_tag.show_text("Press F to talk") if _in_range() else _tag.clear()


func _in_range() -> bool:
	var gap: Vector4 = _keeper.global_position - _walker.global_position
	return Vector2(gap.x, gap.z).length() <= talk_range and absf(gap.w) <= talk_range_w


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key: int = (event as InputEventKey).keycode
	if key == KEY_R:
		_has_gauntlet = false
		_talk.stop()
		_talk.reset()
		_walker.position = Vector4(0, 0, 1.5, 0)
		_refresh_locator()
	elif key == KEY_F and not _talk.is_running() and _in_range():
		_talk.begin(_entry())
		get_viewport().set_input_as_handled()


## Which greeting he opens with. The first meeting is the scripted one; after that he
## answers the state you turn up in.
func _entry() -> String:
	if not _talk.get_flag("met"):
		_talk.set_flag("met", true)
		return KeeperScript.START
	if not _has_gauntlet:
		return "greet_no_gauntlet"
	return "greet_none"


## The game's half of the contract: the script announces what happened, this decides what
## it means. Here it is one label; in chickenpen it would be the locator waking up.
func _on_effect(name: String) -> void:
	match name:
		"give_gauntlet":
			_has_gauntlet = true
		"withhold_gauntlet":
			_has_gauntlet = false
	_talk.set_flag("gauntlet", _has_gauntlet)
	_refresh_locator()


func _refresh_locator() -> void:
	_locator.text = "4D GAUNTLET  —  tracking" if _has_gauntlet else "4D gauntlet  —  not carried"
