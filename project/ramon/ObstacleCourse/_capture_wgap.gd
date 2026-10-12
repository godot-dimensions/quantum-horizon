extends SceneTree

## Captures the controlled pair for the deck's "the verbs survive" claim, from the
## w_gap room: a gap too wide to jump, and a bridge that exists only elsewhere
## along w.
##
##   godot.windows.editor.double.x86_64.console.exe --path project \
##       --resolution 1920x1080 \
##       --script res://ramon/ObstacleCourse/_capture_wgap.gd
##
## NOT with --headless.
##
##   1  gap_no_bridge   Standing one metre back from the near lip in the grey
##                      band. The gap is open: 7 m against a measured 4.592 m
##                      walk-jump reach, so it cannot be jumped.
##   2  gap_bridge      Identical position and facing, w moved to the bridge
##                      band. The crossing is simply there.
##
## Every dimension is read off the builder at runtime - gap_width, ledge_length,
## band_centres, bridge_band - so if those exports are retuned the capture
## follows rather than silently framing the wrong thing.
##
## The room's long axis is X: `_build` places the near ledge centred at
## -(gap/2) - ledge/2 and the far ledge opposite, with the walkway spanning z.

const OUT_DIR := "D:/temp_docs/deck_shots/"
const SETTLE_SECONDS := 1.6
const AFTER_TELEPORT := 0.7
## Far enough back that the near lip, the whole 7 m gap and the far ledge all sit
## in frame together - at one metre the lip is under your feet and the gap simply
## is not in shot.
const STAND_BACK := 5.0

## player.gd keeps pitch in `_head_pitch` and applies it to the PlayerHead child
## only inside its mouse handler, so a scripted capture must set both and will
## not have them overwritten. Negative looks down. At eye height 0.875 m this
## puts the gaze on the middle of the gap rather than the horizon.
const HEAD_PITCH := -0.30

var _root_node: Node = null
var _player: Node = null
var _course: Node = null
var _stand_x: float = 0.0
var _stand_y: float = 1.0
var _yaw: float = 0.0
var _plain_w: float = 0.0
var _bridge_w: float = 0.0
var _gap_width: float = 0.0
var _elapsed: float = 0.0
var _step: int = 0
var _step_started: float = 0.0
var _shots: PackedStringArray = PackedStringArray()


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)

	var packed: PackedScene = load("res://ramon/ObstacleCourse/w_gap.tscn")
	if packed == null:
		printerr("CAPTURE: could not load w_gap.tscn")
		quit(1)
		return
	_root_node = packed.instantiate()
	root.add_child(_root_node)
	set_current_scene(_root_node)

	_player = _root_node.get_node_or_null("Player")
	_course = _root_node.get_node_or_null("Course")
	if _player == null or _course == null:
		printerr("CAPTURE: expected Player and Course nodes")
		quit(1)
		return

	var rb: Node = _root_node.get_node_or_null("ReturnButton")
	if rb != null and "visible" in rb:
		rb.visible = false

	_gap_width = float(_course.get("gap_width"))
	var bands: PackedFloat32Array = _course.get("band_centres")
	var bridge_index: int = int(_course.get("bridge_band"))

	_bridge_w = float(bands[bridge_index])
	# The control band: any band that is NOT the bridge. Prefer the one at 0 so
	# the frame matches where a player actually starts.
	_plain_w = float(bands[0])
	for b in bands:
		if absf(float(b) - _bridge_w) > 0.01 and absf(float(b)) < absf(_plain_w):
			_plain_w = float(b)

	# One metre back from the near lip, looking along +X across the gap.
	_stand_x = -_gap_width * 0.5 - STAND_BACK
	_yaw = atan2(-1.0, 0.0)

	print("CAPTURE: gap=%.2f m, control band w=%+.1f, bridge band w=%+.1f, standing x=%.2f" % [
		_gap_width, _plain_w, _bridge_w, _stand_x])


func _process(delta: float) -> bool:
	_elapsed += delta
	var in_step: float = _elapsed - _step_started

	match _step:
		0: # Let the player settle onto whatever ledge it spawned on, and reuse
			# that height so the teleport does not drop it through the world.
			if in_step >= SETTLE_SECONDS:
				_stand_y = _player.global_position.y
				print("CAPTURE: settled standing height y=%.3f" % _stand_y)
				_place(_plain_w)
				_advance()
		1:
			if in_step >= AFTER_TELEPORT:
				_shot("06_gap_no_bridge.png")
				_advance()
		2:
			_place(_bridge_w)
			_advance()
		3:
			if in_step >= AFTER_TELEPORT:
				_shot("07_gap_bridge.png")
				_advance()
		4:
			print("CAPTURE: wrote %d shots to %s" % [_shots.size(), OUT_DIR])
			quit(0)
			return true

	return false


func _advance() -> void:
	_step += 1
	_step_started = _elapsed


func _place(w: float) -> void:
	_player.global_position = Vector4(_stand_x, _stand_y, 0.0, w)
	_player.global_basis = Basis4D.from_zx(_yaw)
	if "velocity" in _player:
		_player.velocity = Vector4()
	_player.set("_head_pitch", HEAD_PITCH)
	var head: Node = _player.get_node_or_null("PlayerHead")
	if head != null:
		head.basis = Basis4D.from_yz(HEAD_PITCH)


func _shot(file_name: String) -> void:
	var texture: ViewportTexture = root.get_texture()
	if texture == null:
		printerr("CAPTURE: no viewport texture - headless by mistake?")
		return
	var image: Image = texture.get_image()
	if image == null:
		printerr("CAPTURE: null image for " + file_name)
		return
	image.save_png(OUT_DIR + file_name)
	_shots.append(file_name)
	var p: Vector4 = _player.global_position
	print("CAPTURE: %s | %dx%d | player=(%.2f %.2f %.2f %+.2f) floor=%s" % [
		file_name, image.get_width(), image.get_height(), p.x, p.y, p.z, p.w,
		"Y" if (_player.has_method("is_on_floor") and _player.is_on_floor()) else "N"])
