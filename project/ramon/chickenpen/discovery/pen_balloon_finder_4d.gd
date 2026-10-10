extends Node

## FINDING THE BALLOON (discovery, 9 Oct 2026; follow_up/pen_discovery_plan.md, easter egg 2). The balloon hovers
## off in W, tethered to its stake, until it is found (lookout/balloon_4d.gd parked). Ramon: "When approximately
## 70-80% of the balloon is visible, display a contextual prompt: V - Align to Slice. Pressing V should align the
## player's slice with the balloon" ... "be forgiving and make the v align to slice appear within reason".
##
## HOW MUCH SHOWS is measured on the envelope, as the Aquatic Lab measures its shark: the slice's distance from the
## envelope's middle along the slice's own normal (discovery/w_sense_4d.gd), as a share of its widest cut,
## sqrt(1 - (d / r)^2). Forgiving: from [member show_from] (half of it showing; the brief's 70-80% is the middle of
## the range where it shows), from up to [member reach] away on the ground.
##
## V lays your slice flat at the balloon's W (the rig's align_to, as at the camp and the marsh) and marks it found:
## boarding opens (lookout_4d.gd can_board), and the W guide counts it as an align. V gives way to the camp's and the
## marsh's own V: they are tens of metres from here, and each only takes V when its own prompt is up.
##
## NO class_name (engine_gotchas.md).

const WSense := preload("res://ramon/chickenpen/discovery/w_sense_4d.gd")
const Balloon := preload("res://ramon/chickenpen/lookout/balloon_4d.gd")
const Toast := preload("res://ramon/chickenpen/discovery/pen_discovery_toast.gd")

@export var player_path: NodePath = ^"../../Player"
@export var lookout_path: NodePath = ^"../Lookout"
@export var align_key: Key = KEY_V
## How much of the envelope must show before the prompt comes up (1 cut through the middle).
@export_range(0.1, 1.0, 0.05) var show_from: float = 0.5
## How far away on the ground it can be offered.
@export_range(5.0, 80.0, 1.0) var reach: float = 45.0
## The envelope's widest radius, in W as in x and z (balloon_4d.gd: up to 3.55 m).
@export var radius: float = 3.55

var _player: CharacterBody4D
var _cam: Camera4D
var _lookout: Node
var _anchor: Node4D
var _tag: Node
var _shown: String = ""


func _ready() -> void:
	add_to_group(&"discovery_reset")
	_player = get_node_or_null(player_path) as CharacterBody4D
	_cam = WSense.camera_of(_player)
	_lookout = get_node_or_null(lookout_path)
	_anchor = Node4D.new()
	_anchor.name = "BalloonAlignAnchor"
	var world: Node = _player.get_parent().get_node_or_null("World") if _player != null else null
	if world != null:
		world.add_child.call_deferred(_anchor)
	_tag = WorldTag4D.new()
	_tag.name = "BalloonAlignPrompt"
	_tag.set("anchor_path", NodePath(".."))
	if _cam != null:
		_tag.set("camera_path", _cam.get_path())
	_tag.set("lift", 10.0)
	_tag.set("fade_from", 40.0)
	_tag.set("fade_to", 55.0)
	_tag.set("w_range", 12.0)
	_anchor.add_child(_tag)


func _balloon() -> Node4D:
	return _lookout.get("balloon") as Node4D if _lookout != null else null


## How much of the envelope your slice shows now, 0 to 1.
func shown_share() -> float:
	var b := _balloon()
	if b == null or _cam == null:
		return 0.0
	return WSense.share(WSense.off_slice(_cam, b.call("envelope_centre")), radius)


func can_align() -> bool:
	var b := _balloon()
	if b == null or Balloon.found or not bool(b.get("parked")) or bool(b.get("riding")) or not b.is_visible_in_tree():
		return false
	if _player == null or not _player.is_visible_in_tree() or _player.get("input_enabled") == false:
		return false
	var gap: Vector4 = b.global_position - _player.global_position
	if Vector2(gap.x, gap.z).length() > reach:
		return false
	var share: float = shown_share()
	return share >= show_from and share < 0.995


func _process(_delta: float) -> void:
	if _tag == null or not _anchor.is_inside_tree():
		return
	var text: String = ""
	if can_align():
		var b := _balloon()
		var at: Vector4 = b.call("envelope_centre")
		var w: float = WSense.slice_w_at(_cam, at.x, at.y, at.z)
		at.w = w if w != INF else _player.global_position.w
		_anchor.global_position = at
		text = "%s  Align to slice" % OS.get_keycode_string(align_key)
	if text != _shown:
		_shown = text
		if text == "":
			_tag.call("clear")
		else:
			_tag.call("show_text", text)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == align_key and can_align():
		get_viewport().set_input_as_handled()
		var b := _balloon()
		var rig: Node = _player.get_node_or_null("CameraRig")
		if rig != null and rig.has_method("align_to"):
			rig.call("align_to", b.global_position.w)
		# The first find only (Ramon, 10 Oct, item 18: "Whoa! You discovered a balloon! ... only on the first
		# successful discovery"), with where the ride comes from.
		if not Balloon.found:
			Toast.say(self, "Whoa! You discovered a balloon!", "Tamsin waits by the basket. A ride is 2 azoth.", Color(0.95, 0.62, 0.30))
		Balloon.found = true
		if _lookout != null and _lookout.has_method("sound"):
			_lookout.call("sound", &"secret")


## Ctrl+R (through the W guide): hidden in W again for the next visitor.
func reset() -> void:
	var b := _balloon()
	if b != null and b.has_method("hide_again"):
		b.call("hide_again")
	else:
		Balloon.found = false
