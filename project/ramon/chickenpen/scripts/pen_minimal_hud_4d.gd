extends Node

## THE MINIMAL HUD (Systems/MinimalHud, F1; 10 Oct 2026, Ramon's walkthrough item 11: "Add a toggle that hides all
## nonessential interface elements. When enabled, only the following should remain visible: The bottom-right W-slice
## locator gizmo. The bottom-left inventory. The new Art/Dev Mode indicator ... The toggle should be reversible without
## resetting the scene.").
##
## Hides every card under UI except the kept ones (the dial, the belt, the mode badge) and the ones that come and go
## with the play itself (the talk prompts and dialogue boxes, the catch prompt, the lock-on readout, the toasts on their
## own layers): those keep doing their job. The grass panel, the paths panel and the controls' hint, which are made at
## run time, are hidden too. Only what was showing is hidden, and only that is shown again ("restore only what you
## hid", as the conversations do), so a card something else had put away stays away. While it is on, anything that
## shows itself again (the grass panel re-shows itself, the cards re-place themselves) is put back down each frame.
##
## F1 is free in the pen (every letter is someone's). NO class_name (engine_gotchas.md).

@export var key: Key = KEY_F1
@export var ui_path: NodePath = ^"../../UI"
## Kept on screen.
@export var keep: PackedStringArray = PackedStringArray(["SlicePlane", "Inventory", "LookBadge"])
## Left alone: they show and hide with the play (prompts, conversations, readouts).
@export var leave: PackedStringArray = PackedStringArray(["CatchPrompt", "LockOn", "Hint", "Again", "Searcher", "ThoughtBox"])
## HUD pieces that are not under UI (the player's speed readout hangs off the player).
@export var extra_paths: Array[NodePath] = [^"../../Player/StateLabel"]

## On (true: minimal). Static so a reload of the pen keeps the choice this session.
static var on: bool = false

var _hid: Array = []


func _ready() -> void:
	if on:
		_apply.call_deferred(true)


func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo or k.keycode != key:
		return
	set_minimal(not on)
	get_viewport().set_input_as_handled()


func set_minimal(minimal: bool) -> void:
	on = minimal
	_apply(minimal)


func _hideable(c: Node) -> bool:
	var n: String = String(c.name)
	if n in keep or n in leave:
		return false
	if n.ends_with("Tag") or n.ends_with("Box"):
		return false
	return c is CanvasItem


## Everything it may hide: the UI's cards and the extra pieces.
func _candidates() -> Array:
	var out: Array = []
	var ui: Node = get_node_or_null(ui_path)
	if ui != null:
		out.append_array(ui.get_children())
	for path in extra_paths:
		var n: Node = get_node_or_null(path)
		if n != null:
			out.append(n)
	return out


func _apply(minimal: bool) -> void:
	if not minimal:
		for item in _hid:
			if is_instance_valid(item):
				(item as CanvasItem).visible = true
		_hid.clear()
		return
	for c in _candidates():
		if _hideable(c) and (c as CanvasItem).visible:
			(c as CanvasItem).visible = false
			_hid.append(c)


func _process(_delta: float) -> void:
	if not on:
		return
	# Whatever shows itself again while minimal (the grass panel, the paths panel, a card that came up) goes back down.
	for c in _candidates():
		if _hideable(c) and (c as CanvasItem).visible:
			(c as CanvasItem).visible = false
			if not _hid.has(c):
				_hid.append(c)
