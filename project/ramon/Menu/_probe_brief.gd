extends SceneTree
## Presses VIEW CONTRIBUTION BRIEF in the drawer and reports whether the error
## cue actually reached an audio player.
##
## Exists because the button LOOKS correctly wired - the signal is declared, the
## lambda emits it, the map connects it to `_refused()` - and no sound comes out.
## Reading the code has not found it, so this walks the live tree instead and
## prints what is really connected and what really plays.
##
##   godot.windows.editor.double.x86_64.console.exe --path project \
##       --script res://ramon/Menu/_probe_brief.gd

var _map: Node = null
var _frames: int = 0


func _initialize() -> void:
	_map = (load("res://ramon/FrontierMap.tscn") as PackedScene).instantiate()
	root.add_child(_map)
	set_current_scene(_map)


func _find(node: Node, text: String) -> Button:
	for child in node.get_children():
		if child is Button and (child as Button).text == text:
			return child
		var found: Button = _find(child, text)
		if found != null:
			return found
	return null


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 3:
		_map.call("_open_activity", "October Gate", 0)
	if _frames < 8:
		return false

	var drawer: Node = _map.get("_drawer")
	var audio: Node = _map.get("_audio")
	print("drawer open:       %s" % str(drawer.get("visible")))
	print("brief connections: %d" % drawer.get_signal_connection_list("brief_requested").size())

	var button: Button = _find(drawer, "VIEW CONTRIBUTION BRIEF")
	print("button found:      %s" % str(button != null))
	if button != null:
		print("button disabled:   %s  visible: %s" % [str(button.disabled), str(button.visible)])
		button.pressed.emit()

	# Whether a player actually started is the only answer that matters.
	for player in audio.get_children():
		if player is AudioStreamPlayer:
			var stream: AudioStream = (player as AudioStreamPlayer).stream
			print("  player playing=%-5s db=%-6s stream=%s" % [
				str((player as AudioStreamPlayer).playing),
				str((player as AudioStreamPlayer).volume_db),
				"null" if stream == null else stream.get_class()])
	quit(0)
	return true
