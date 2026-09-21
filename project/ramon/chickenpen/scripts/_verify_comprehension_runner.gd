extends SceneTree

## Item 66: comprehension, not correctness.
##
## The test deliberately knows NOTHING about how W works. It boots the scene cold, reads
## the locator's own words, extracts the key those words name, presses that key, and checks
## whether the readout reaches its success state. If the advice is wrong - if it names a
## control that does not move the player through W, which it did until just now - this
## fails even though every number behind it is correct. That is the whole point of the
## item: an indicator nobody can act on is not an indicator.

var _root: Node
var _f: int = 0
var _player: Node4D
var _loc: Node
var _cues: Node
var _pressed: String = ""
var _start_w: float = 0.0
var _locked_at: int = -1
var _first_text: String = ""


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/chickenpen.tscn").instantiate()
	root.add_child(_root)
	current_scene = _root


func _process(_d) -> bool:
	_f += 1
	if _f < 60:
		return false
	if _player == null:
		_player = _root.get_node("Player")
		_loc = _root.get_node("Systems/Locator")
		_cues = _root.get_node("Systems/Cues")
		print("--- what a new player is told, before knowing anything ---")
		print("   objective: %s" % (_root.get_node("UI/Objective") as Label).text)
		print("   locator:   %s" % (_root.get_node("UI/Locator") as Label).text)

	var text: String = (_root.get_node("UI/Locator") as Label).text

	# Step one: take the advice literally. Find the key the readout names.
	if _pressed == "":
		_first_text = text
		var named: String = _named_key(text)
		if named == "":
			print("FAIL: the readout names no control, so there is nothing to act on.")
			return true
		var code: int = OS.find_keycode_from_string(named)
		if code == 0:
			print("FAIL: the readout says press '%s', which is not a key." % named)
			return true
		_pressed = named
		_start_w = _player.global_position.w
		print("\n--- following that advice blind ---")
		print("   readout names '%s' - pressing that key and holding it" % named)
		# The KEY, not an action. Resolving the name back to an action would mean guessing
		# which of the several actions bound to E the readout meant, and a player does no
		# such thing: they press E and watch what the character does.
		var down := InputEventKey.new()
		down.physical_keycode = code
		down.keycode = code
		down.pressed = true
		Input.parse_input_event(down)
		return false

	# Step two: did doing what it said actually work?
	if _locked_at < 0 and text.contains("LOCKED"):
		_locked_at = _f
		_release()
		print("   after %d frames: %s" % [_locked_at - 60, text])
		print("   player moved through W from %.2f to %.2f" % [_start_w, _player.global_position.w])
		print("   PASS: the control the readout named is the one that reaches the chicken.")
		_report_cues()
		return true

	if _f > 500:
		_release()
		print("   still: %s" % text)
		print("FAIL: pressing the named key for %d frames never reached the locked state." % (_f - 60))
		print("      first reading was: %s" % _first_text)
		return true
	return false


## Items 54 and 55: the supporting cues exist and are bounded, not beacons.
func _report_cues() -> void:
	print("\n--- supporting cues ---")
	var markers: Dictionary = _cues.get("_markers")
	var band: float = float(_cues.get("reveal_band"))
	var near_enough: int = 0
	var in_band: int = 0
	for m in markers.values():
		var node: MeshInstance4D = m as MeshInstance4D
		if not node.visible:
			continue
		near_enough += 1
		# Enabled is not the same as seen: the node being visible only means the chicken is
		# within range in ordinary space. Whether anything is DRAWN is decided by the
		# orthoplex's cross-section, which is empty outside the band.
		if absf(node.position.w - _player.global_position.w) < band:
			in_band += 1
	print("   glimpse markers: %d built, %d within %.0f units, %d of those actually drawn" % [
		markers.size(), near_enough, float(_cues.get("reveal_distance")), in_band])
	var mesh: OrthoplexTetraMesh4D = null
	for m in markers.values():
		mesh = (m as MeshInstance4D).mesh as OrthoplexTetraMesh4D
		break
	if mesh != null:
		print("   marker W half-extent %.2f - its cross-section is empty beyond that, so the" % mesh.half_extents.w)
		print("     glimpse cannot be seen from a slice the chicken is not nearly in.")
	for named in ["Cluck", "Confirm", "Chorus"]:
		var player: AudioStreamPlayer = _cues.get_node_or_null(named) as AudioStreamPlayer
		if player == null:
			print("   %s: NOT present" % named)
			continue
		var wav: AudioStreamWAV = player.stream as AudioStreamWAV
		print("   %-8s %.2f s synthesised at %.0f dB" % [
			named + ":", float(wav.data.size() / 2) / float(wav.mix_rate), player.volume_db])


func _release() -> void:
	var up := InputEventKey.new()
	var code: int = OS.find_keycode_from_string(_pressed)
	up.physical_keycode = code
	up.keycode = code
	up.pressed = false
	Input.parse_input_event(up)


## Pull the control out of the readout's own text, the way a player reads it off the screen.
func _named_key(text: String) -> String:
	var marker: String = "press "
	var at: int = text.find(marker)
	if at < 0:
		return ""
	return text.substr(at + marker.length()).strip_edges()
