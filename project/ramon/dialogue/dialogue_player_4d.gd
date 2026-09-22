extends Node
class_name DialoguePlayer4D

## Walks a dialogue script and drives a DialogueBox4D with it.
##
## The split is deliberate. The box knows how to show a line and collect a pick; this knows
## what comes next; the script file knows the words. Adding a second character means a
## second script file and nothing else, and rewriting the keeper's lines never risks the
## state machine.
##
## EFFECTS ARE ANNOUNCED, NOT PERFORMED. A node carrying `do` emits `effect` and moves on.
## This node has no idea what a gauntlet is, and the locator has no idea a conversation
## exists - they meet in whoever wired them together. That is what keeps the dialogue
## reusable for a prototype that has not decided what it contains yet.
##
## FLAGS ARE SET FROM OUTSIDE. Whoever handles an effect calls set_flag, and choices with
## `needs` consult those flags. The script therefore describes conditions without owning
## any game state.

signal effect(name: String)
signal started
signal ended

@export var box_path: NodePath
## The script to play: any class exposing NODES, START and fill(). Left as a plain
## reference so a second character does not need this file changed.
@export var handle_input: bool = true

## Show the reply you picked, in your own voice, before he answers it.
##
## Without this, choosing feels like operating a menu: the option vanishes the instant it
## is pressed and the only voice in the scene is his. Monkey Island's whole texture comes
## from hearing your own line land first, and it costs one extra beat.
@export var echo_player_line: bool = true
## How long your line stays up once it has finished arriving. Tap through it to skip.
@export_range(0.0, 3.0, 0.05) var echo_hold_seconds: float = 0.55

## Held longer than this, the advance key is a fast-forward rather than a tap. Short enough
## that a deliberate press never feels like a hold.
@export_range(0.05, 0.6, 0.01) var tap_seconds: float = 0.18

## Filled in by the game so lines can say "{returned} in, {remaining} still out".
var returned: int = 0
var total: int = 12

var _box: DialogueBox4D
var _script_nodes: Dictionary = {}
var _start_key: String = ""
var _fill: Callable = Callable()

var _key: String = ""
var _lines: Array = []
var _at: int = 0
var _running: bool = false
var _pending_choices: Array = []
var _visited: Dictionary = {}
var _flags: Dictionary = {}
## True once the player has asked about anything, ever - across conversations, not just
## this one. It is what lets a sign-off mean "goodbye" the first time and "back to the
## list" once somebody has shown they want to talk.
var _asked_any: bool = false
## An effect waiting for its line. See `do_on_line`.
var _pending_effect: String = ""
var _echoing: bool = false
var _echo_goto: String = ""
var _echo_held: float = 0.0
var _holding: bool = false
var _hold_time: float = 0.0
## Whether there was anything left to hurry when the key went down. See _advance_key.
var _hold_had_text: bool = false


func _ready() -> void:
	_box = get_node_or_null(box_path) as DialogueBox4D
	if _box == null:
		push_warning("DialoguePlayer4D: no box at '%s' - nothing will ever be shown." % box_path)
		return
	_box.chose.connect(_on_chose)
	_box.line_finished.connect(_on_line_finished)
	set_process_unhandled_input(handle_input)


## Hand over a script class, e.g. use_script(KeeperScript.NODES, KeeperScript.START,
## KeeperScript.fill). Kept as plain values rather than a base class so a script file stays
## a file of writing rather than a subclass of something.
func use_script(nodes: Dictionary, start_key: String, fill: Callable = Callable()) -> void:
	_script_nodes = nodes
	_start_key = start_key
	_fill = fill


func is_running() -> bool:
	return _running


func begin(key: String = "") -> void:
	if _box == null or _script_nodes.is_empty():
		push_warning("DialoguePlayer4D: begin() with no box or no script.")
		return
	_running = true
	started.emit()
	_enter(key if key != "" else _start_key)


func stop() -> void:
	_running = false
	_key = ""
	_lines = []
	_pending_choices = []
	_echoing = false
	_holding = false
	_pending_effect = ""
	if _box != null:
		_box.fast_forward = false
	if _box != null:
		_box.close()
	ended.emit()


func set_flag(name: String, value: bool) -> void:
	_flags[name] = value


func get_flag(name: String) -> bool:
	return bool(_flags.get(name, false))


## Forget which topics have been asked, so a restart gets the whole conversation back.
func reset() -> void:
	_visited.clear()
	_flags.clear()
	_asked_any = false


# ------------------------------------------------------------------ walking

func _enter(key: String) -> void:
	if key == "":
		stop()
		return
	if not _script_nodes.has(key):
		push_warning("DialoguePlayer4D: no node named '%s' in the script." % key)
		stop()
		return

	var node: Dictionary = _script_nodes[key]

	# A node that has been through once and names an alternative sends you there instead.
	# This is how the keeper answers a second insult without repeating his whole speech.
	if _visited.has(key) and node.has("instead"):
		_enter(String(node["instead"]))
		return

	if bool(node.get("topic", false)):
		_asked_any = true
	_visited[key] = true
	_key = key
	_lines = node.get("lines", [])
	_at = 0
	_pending_choices = _visible_choices(node)

	# `do_on_line` holds the effect back until the line that announces it has finished
	# being said. Without it the effect fires the moment the node is entered, so the
	# keeper's gauntlet flew to your wrist while he was still two lines away from
	# offering it. Absent, effects fire on entry as before.
	_pending_effect = ""
	if node.has("do"):
		if node.has("do_on_line"):
			_pending_effect = String(node["do"])
		else:
			effect.emit(String(node["do"]))

	if _lines.is_empty():
		# A hub with no line of its own: go straight to the replies, keeping whatever the
		# previous node said on screen so the panel does not blink between beats.
		_show_choices()
	else:
		_speak()


func _speak() -> void:
	var speaker: String = String(_script_nodes[_key].get("speaker", ""))
	var line: String = String(_lines[_at])
	if _fill.is_valid():
		line = String(_fill.call(line, returned, total))
	_box.say(speaker, line)


func _on_line_finished() -> void:
	if _pending_effect != "" and _at >= int(_script_nodes[_key].get("do_on_line", 0)):
		var announced: String = _pending_effect
		_pending_effect = ""
		effect.emit(announced)
	# Replies only appear once the last line has fully arrived, so reading and choosing
	# never compete for the same moment.
	if _at >= _lines.size() - 1 and not _pending_choices.is_empty():
		_show_choices()


func _show_choices() -> void:
	var texts: Array = []
	for choice in _pending_choices:
		texts.append(String(choice["text"]))
	_box.offer(texts)


func _advance() -> void:
	# A tap can outlive the conversation - the key is released after stop(), or a stray
	# press arrives before begin(). Neither should index the script with an empty key.
	if _key == "" or not _script_nodes.has(_key):
		return
	if _box.is_typing():
		_box.finish_line()
		return
	if _box.has_choices():
		return
	if _at < _lines.size() - 1:
		_at += 1
		_speak()
		return
	if not _pending_choices.is_empty():
		return
	_enter(_exit_of(_script_nodes[_key]))


## Where a node goes when it runs out of lines. `goto_if_asked` overrides `goto` for a
## player who has already asked about something: a goodbye should close the conversation
## when it is the whole of what you said, and hand you back the list when you were in the
## middle of browsing it.
func _exit_of(node: Dictionary) -> String:
	if _asked_any and node.has("goto_if_asked"):
		return String(node["goto_if_asked"])
	return String(node.get("goto", ""))


func _on_chose(index: int) -> void:
	if index < 0 or index >= _pending_choices.size():
		return
	var choice: Dictionary = _pending_choices[index]
	if bool(choice.get("once", false)):
		_visited["choice:" + String(choice["text"])] = true
	_pending_choices = []
	var goto: String = String(choice.get("goto", ""))
	if echo_player_line:
		_echoing = true
		_echo_goto = goto
		_echo_held = 0.0
		_box.say(_box.player_name, String(choice["text"]))
	else:
		_enter(goto)


## Drops the topics already asked and the ones whose condition is unmet. `needs` is a flag
## name, optionally prefixed with "!" for "must be false".
func _visible_choices(node: Dictionary) -> Array:
	var out: Array = []
	for choice in node.get("choices", []):
		if bool(choice.get("once", false)) and _visited.has("choice:" + String(choice["text"])):
			continue
		if choice.has("needs"):
			var need: String = String(choice["needs"])
			var want: bool = true
			if need.begins_with("!"):
				want = false
				need = need.substr(1)
			if get_flag(need) != want:
				continue
		out.append(choice)
	return out


func _process(delta: float) -> void:
	if not _running or _box == null:
		return

	# Tap or hold, decided by how long the key has been down. A tap finishes the line it
	# is looking at; a hold runs the reveal fast without skipping any of it.
	if _holding and _hold_had_text:
		_hold_time += delta
		if _hold_time > tap_seconds:
			_box.fast_forward = true

	# Your own line takes itself away. Making the player press twice to get past their own
	# reply is the sort of friction nobody notices while writing it and everybody feels.
	if _echoing and not _box.is_typing():
		_echo_held += delta
		if _echo_held >= echo_hold_seconds:
			_echoing = false
			_box.fast_forward = false
			_enter(_echo_goto)


# ------------------------------------------------------------------ input

## Escape leaves the conversation, immediately, from anywhere in it.
##
## Handled in _input rather than _unhandled_input, and CONSUMED, because the camera rig
## also watches ui_cancel - first press frees the mouse, second quits the game. Sharing
## the key through _unhandled_input meant that escaping a conversation could also release
## the cursor or close the window, depending on which node the event happened to reach
## first. Consuming it here means Escape means one thing while somebody is talking.
func _input(event: InputEvent) -> void:
	if not _running:
		return
	if event.is_action_pressed(&"ui_cancel"):
		stop()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not _running or _box == null:
		return

	# Left mouse does what the advance key does, including the hold. Nobody reaches for a
	# key to get through a line of dialogue if their hand is already on the mouse.
	if event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.button_index == MOUSE_BUTTON_LEFT and not click.double_click:
			_advance_key(click.pressed)
			get_viewport().set_input_as_handled()
		return

	if not (event is InputEventKey) or event.echo:
		return
	var key: int = (event as InputEventKey).keycode

	if key == KEY_SPACE or key == KEY_ENTER or key == KEY_KP_ENTER or key == KEY_F:
		_advance_key(event.pressed)
		get_viewport().set_input_as_handled()
		return

	if not event.pressed:
		return
	match key:
		KEY_UP, KEY_W:
			_box.move_choice(-1)
		KEY_DOWN, KEY_S:
			_box.move_choice(1)
		_:
			if key >= KEY_1 and key <= KEY_9:
				_box.pick_index(key - KEY_1)


## One path for every way of saying "on". A tap is decided on release, so that holding the
## key can run the reveal fast without the initial press having already finished the line.
##
## BUT A HOLD ONLY HAS A JOB WHILE TEXT IS STILL ARRIVING. Once the line has finished
## there is nothing to hurry, so a press that outstayed tap_seconds used to be classified
## as a hold and then do nothing at all on release - the input vanished, and it took
## several increasingly annoyed presses to land one short enough to count. If there was no
## text left to hurry when the key went down, any release advances, however long the
## finger stayed on the key.
func _advance_key(down: bool) -> void:
	if down:
		_holding = true
		_hold_time = 0.0
		_hold_had_text = _box.is_typing()
		return
	if _holding and (not _hold_had_text or _hold_time <= tap_seconds):
		_tap()
	_holding = false
	_box.fast_forward = false


func _tap() -> void:
	if _echoing:
		# Skip the pause on your own line rather than waiting it out.
		_echo_held = echo_hold_seconds
		_box.finish_line()
		return
	if _box.has_choices():
		_box.confirm_choice()
	else:
		_advance()
