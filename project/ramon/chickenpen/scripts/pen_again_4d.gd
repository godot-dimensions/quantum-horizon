extends Control

## "Restart game? Y / N", five seconds after the last chicken is in.
##
## WHY IT WAITS. The completion already has an ending: confetti over the pen and every
## bird in it going berserk, and it never stops - the header on pen_celebration_4d says so
## plainly, that was the ask. Putting a menu on top of that the instant it fires would
## interrupt the one thing the whole round is building towards. Five seconds is long enough
## to watch what you did and short enough that you are not left wondering what happens now.
##
## AND IT IS TWO KEYS, NOT A MENU. Y and N, handled here, with nothing to move a cursor
## through. The round is over; the only two things anybody wants at that moment are "again"
## and "leave me alone", so those are the only two things offered.
##
## N REALLY MEANS NO. It does not come back on a timer and it does not reappear the next
## time you walk past the pen - the celebration carries on and the level is yours to wander.
## Only a real restart puts it back, which is also what makes it safe to dismiss by
## accident: the round you finished is not going anywhere.

## The game, which announces completion and owns the restart.
@export var game_path: NodePath = NodePath("../../Systems/Game")
## The celebration, so a restart clears the confetti and calms the birds down. Its own
## _reset does both and then calls the game - the same thing its test key does - so this
## goes through that rather than reimplementing half of it.
@export var celebration_path: NodePath = NodePath("../../Systems/Celebration")

@export var question: String = "Restart game?"
@export_range(0.0, 30.0, 0.5) var after_seconds: float = 5.0
## How long it takes to fade up once it is due.
@export_range(0.0, 2.0, 0.05) var fade_seconds: float = 0.45

@export_group("Look")
@export var panel_color: Color = Color(0.09, 0.11, 0.15, 0.90)
@export var edge_color: Color = Color(0.62, 0.78, 0.95, 0.75)
@export var text_color: Color = Color(0.95, 0.97, 1.0)
@export var key_color: Color = Color(1.0, 0.93, 0.62)
@export_range(12, 60, 1) var question_size: int = 28
@export_range(10, 48, 1) var answer_size: int = 20

var _game: Node
var _celebration: Node
var _wait: float = -1.0
var _shown: float = 0.0
var _answered: bool = false


func _ready() -> void:
	# It draws nothing and answers nothing until the round ends.
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_game = get_node_or_null(game_path)
	_celebration = get_node_or_null(celebration_path)
	if _game == null or not _game.has_signal("completed"):
		push_warning("PenAgain: nothing announces the end at game_path - no restart prompt.")
		return
	_game.connect("completed", _on_completed)


func _on_completed() -> void:
	if _answered:
		return
	_wait = after_seconds


## A restart has to take this with it, or the second round begins with last round's
## question still on the screen.
func reset() -> void:
	_wait = -1.0
	_shown = 0.0
	_answered = false
	visible = false


func _process(delta: float) -> void:
	if _wait >= 0.0:
		_wait -= delta
		if _wait <= 0.0:
			_wait = -1.0
			visible = true
	if not visible:
		return
	if _shown < 1.0:
		_shown = minf(_shown + delta / maxf(fade_seconds, 0.01), 1.0)
		queue_redraw()


## _input, NOT _unhandled_input. N is also the slice dial's key, and the dial listens in
## _unhandled_input too and is reached first - so with the prompt up, N toggled the dial,
## marked itself handled, and the prompt never heard it. Trym: "the N button is already
## bound to toggling the dial and doesn't get rid of the prompt". Taking input one stage
## earlier, and only while the question is on screen, means the answer to the question
## always goes to the question. The rewatch prompt does the same for the same reason.
func _input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	if key.keycode == KEY_Y:
		_answered = true
		visible = false
		get_viewport().set_input_as_handled()
		# Through the celebration, which clears the confetti and calls the game's own
		# restart. Calling the game directly would leave two hundred pieces of paper in
		# the air over a pen that had just been emptied.
		if _celebration != null and _celebration.has_method("_reset"):
			_celebration.call("_reset")
		elif _game != null and _game.has_method("restart"):
			_game.call("restart")
		reset()
	elif key.keycode == KEY_N or key.keycode == KEY_ESCAPE:
		_answered = true
		visible = false
		get_viewport().set_input_as_handled()
		queue_redraw()


func _draw() -> void:
	var font: Font = get_theme_default_font()
	if font == null:
		return
	var alpha: float = _shown
	var screen: Vector2 = get_viewport_rect().size
	var answer: String = "Y  restart          N  stay here"
	var q_wide: float = font.get_string_size(question, HORIZONTAL_ALIGNMENT_LEFT, -1,
		question_size).x
	var a_wide: float = font.get_string_size(answer, HORIZONTAL_ALIGNMENT_LEFT, -1,
		answer_size).x
	var pad: float = 34.0
	var box_w: float = maxf(q_wide, a_wide) + pad * 2.0
	var box_h: float = float(question_size) + float(answer_size) + pad * 2.0 + 14.0
	# Above the middle rather than on it: the pen, the confetti and the birds are what you
	# are meant to still be looking at, and a panel across the centre of the screen covers
	# exactly that.
	var box := Rect2(Vector2((screen.x - box_w) * 0.5, screen.y * 0.26),
		Vector2(box_w, box_h))
	draw_rect(box, Color(panel_color, panel_color.a * alpha), true)
	draw_rect(box, Color(edge_color, edge_color.a * alpha), false, 2.0)
	var y: float = box.position.y + pad + font.get_ascent(question_size)
	draw_string(font, Vector2(box.position.x + (box_w - q_wide) * 0.5, y), question,
		HORIZONTAL_ALIGNMENT_LEFT, -1, question_size, Color(text_color, alpha))
	y += float(answer_size) + 18.0
	draw_string(font, Vector2(box.position.x + (box_w - a_wide) * 0.5, y), answer,
		HORIZONTAL_ALIGNMENT_LEFT, -1, answer_size, Color(key_color, alpha))
