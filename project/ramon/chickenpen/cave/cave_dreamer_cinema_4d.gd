extends Node

## Talking to the dreamer is a scene, not a chat (Ramon, 28 Sept: "When you press F, I want
## a cinematic to start, one where you can choose things to say, sure, but a cinematic
## nonetheless ... close ups ... a sideshot ... a closeup of the mouth of the entity
## showing the detailed insides, and a closeup of the main character ... a panshot, slowly
## moving from left to right, and showing the scale of the character in relation to the
## creature").
##
## ONE CAMERA, CUT BETWEEN SHOTS. The conversation's own staging (PenNpcTalk4D) stands you
## on a mark ten metres in front of it and makes a camera of the far room's current; this
## moves that camera every frame, into whichever shot the line on screen is written for
## (SHOTS). A new line in a new shot is a cut; a line that keeps the shot keeps it moving,
## so a slow pan carries across two lines of speech without starting over. When you are
## choosing what to say, the camera is behind you, low, looking up past your shoulder at it.
##
## EVERY SHOT MOVES, AND SLOWLY. A locked-off frame of a creature this size reads as a
## screenshot. Each one drifts, pushes or pans over about as long as a line takes to read,
## and never fast - the scale is the subject, and fast movement makes big things small.
##
## ON THE FLAT SLICE, AT THE ROOM'S W. The camera's fourth axis is the world's, and the mark
## is at the room's own w, so the shots are composed in one ordinary 3D cross-section of the
## room, and the slice is turned flat for the length of the scene - otherwise the creature,
## which faces your slice, would face a slice the camera is not showing. Turning the slice
## is locked while it plays; the dial is put away with the rest of the HUD.
##
## ITS LIGHT ON YOUR FACE. The room's lamps are pitched for a hall; at ten metres a face is
## a dark shape. A soft light rides just above you on its side for the length of the scene,
## the colour of its heart - blue, and red when it is - so the close-ups read, and read as
## lit by it.
##
## Letterboxed, with the words on the lower bar - under everything else on screen, so the
## subtitles sit on top of it.

## Which shot each line is framed in, by node: one per line, the last kept for the rest.
## "choices" is the shot while replies are on screen.
const SHOTS := {
	"intro": ["wide_pan", "mouth"],
	"greet_after_strike": ["low", "mouth_push"],
	"menu": ["shoulder"],
	"menu_two": ["mouth"],
	"menu_three": ["low"],
	"topic_what": ["mouth", "wide_pan", "face"],
	"topic_cube": ["side", "mouth"],
	"topic_where": ["side", "wide_pan"],
	"topic_music": ["mouth", "face"],
	"topic_you": ["face", "side"],
	"topic_wake": ["low", "mouth_push"],
	"topic_end": ["low", "mouth_push"],
	"end_flinch": ["face"],
	"end_after": ["mouth", "side"],
	"topic_what_again": ["mouth"],
	"topic_cube_again": ["side"],
	"topic_where_again": ["wide_pan"],
	"topic_music_again": ["mouth"],
	"topic_you_again": ["face"],
	"topic_wake_again": ["low"],
	"topic_end_again": ["mouth"],
	"bye": ["rise"],
}
const CHOOSING := "shoulder"

@export var talk_path: NodePath = NodePath("../DreamerTalk")
@export var box_path: NodePath = NodePath("../../UI/DreamerBox")
@export var dreamer_path: NodePath = NodePath("../../Dreamer")
@export var camera_path: NodePath = NodePath("../../CinemaCamera")
@export var player_path: NodePath = NodePath("../../../../Player")
@export var rig_path: NodePath = NodePath("../../../../Player/CameraRig")
## Each of the letterbox bars, as a share of the screen's height.
@export_range(0.0, 0.25, 0.005) var bars: float = 0.1
## How far you take a step back when it threatens everything.
@export_range(0.0, 1.5, 0.05) var flinch_step: float = 0.4

var _talk: Node
var _box: Node
var _dreamer: Node4D
var _mouth: Node4D
var _camera: Camera4D
var _player: Node4D
var _rig: Node
var _far: Node4D
var _layer: CanvasLayer
var _top: ColorRect
var _bottom: ColorRect
var _on := false
var _bars_k := 0.0
var _shot := ""
var _u := 0.0
var _slice_was := Vector2.ZERO
var _flinch := -1.0
var _flinch_from := Vector4.ZERO
var _glow: OmniLight4D
var _heart: OmniLight4D


func _ready() -> void:
	_talk = get_node_or_null(talk_path)
	_box = get_node_or_null(box_path)
	_dreamer = get_node_or_null(dreamer_path) as Node4D
	_camera = get_node_or_null(camera_path) as Camera4D
	_player = get_node_or_null(player_path) as Node4D
	_rig = get_node_or_null(rig_path)
	_far = get_node_or_null("../..") as Node4D
	_layer = CanvasLayer.new()
	# Under the subtitles, which are on the default layer; over the world.
	_layer.layer = -1
	add_child(_layer)
	_top = _bar()
	_bottom = _bar()
	_glow = OmniLight4D.new()
	_glow.name = "FaceGlow"
	_glow.omni_range_meters = 4.0
	_glow.light_energy = 0.0
	_glow.visible = false
	if _far != null:
		_far.add_child.call_deferred(_glow)


func _bar() -> ColorRect:
	var r := ColorRect.new()
	r.color = Color.BLACK
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(r)
	return r


## The conversation has opened: flat slice, locked, and the first shot.
func begin() -> void:
	_on = true
	_shot = ""
	_u = 0.0
	if _rig != null:
		_slice_was = Vector2(float(_rig.get("_slice_xw")), float(_rig.get("_slice_zw")))
		_rig.set("_slice_xw", 0.0)
		_rig.set("_slice_zw", 0.0)
		_rig.set("_homing", 0.0)
		if _rig.has_method("lock_look"):
			_rig.call("lock_look", true)
		if _rig.has_method("_apply"):
			_rig.call("_apply")


## And closed. [param waking] keeps the scene on screen for the flash that takes you home
## - cutting back to your own camera for the moment before it would be a jolt.
func end(waking: bool) -> void:
	if waking:
		if _camera != null:
			_camera.current = true
		return
	_on = false
	_flinch = -1.0
	_glow.visible = false
	if _rig != null:
		_rig.set("_slice_xw", _slice_was.x)
		_rig.set("_slice_zw", _slice_was.y)
		if _rig.has_method("lock_look"):
			_rig.call("lock_look", false)
		if _rig.has_method("_apply"):
			_rig.call("_apply")


func is_playing() -> bool:
	return _on


## Which shot is on screen - for the tests.
func shot() -> String:
	return _shot


func _process(delta: float) -> void:
	_bars_k = move_toward(_bars_k, 1.0 if _on else 0.0, delta / 0.6)
	var h: float = get_viewport().get_visible_rect().size.y
	var w: float = get_viewport().get_visible_rect().size.x
	var tall: float = h * bars * smoothstep(0.0, 1.0, _bars_k)
	_top.position = Vector2.ZERO
	_top.size = Vector2(w, tall)
	_bottom.position = Vector2(0.0, h - tall)
	_bottom.size = Vector2(w, tall)
	_layer.visible = _bars_k > 0.0
	if not _on or _camera == null or _dreamer == null or _player == null or _far == null:
		return
	if _mouth == null:
		_mouth = _dreamer.get_node_or_null("Mouth") as Node4D
		if _mouth == null:
			return
	var want: String = _wanted()
	if want != _shot:
		_shot = want
		_u = 0.0
	else:
		_u += delta
	_step_back(delta)
	_frame(_shot, _u)
	_light_face(delta)


func _light_face(delta: float) -> void:
	if not _glow.is_inside_tree():
		return
	if _heart == null:
		_heart = _mouth.get_node_or_null("Glow") as OmniLight4D
	_glow.visible = true
	_glow.light_energy = move_toward(_glow.light_energy, 2.4, delta * 3.0)
	if _heart != null:
		_glow.light_color = _heart.light_color.lerp(Color.WHITE, 0.35)
	var p: Vector4 = _local(_player.global_position)
	var d: Vector4 = _local(_dreamer.global_position)
	var f: Vector4 = d - p
	f.y = 0.0
	f.w = 0.0
	f = f.normalized() if f.length() > 0.01 else Vector4(0, 0, -1, 0)
	_glow.position = p + f * 1.1 + Vector4(0, 2.3, 0, 0)


## The shot the moment calls for: replies on screen, or the line being said.
func _wanted() -> String:
	if _talk == null:
		return _shot
	var key: String = String(_talk.get("_key"))
	if key == "":
		return _shot if _shot != "" else "rise"
	if _box != null and bool(_box.call("has_choices")):
		return CHOOSING
	var list: Array = SHOTS.get(key, [CHOOSING])
	var at: int = int(_talk.get("_at"))
	if key == "end_flinch" and _flinch < 0.0:
		_flinch = 0.0
		_flinch_from = _player.global_position
	return String(list[mini(at, list.size() - 1)])


## "(You take a step back.)" - and you do.
func _step_back(delta: float) -> void:
	if _flinch < 0.0 or _flinch >= 1.0:
		return
	_flinch = minf(_flinch + delta / 0.5, 1.0)
	var away: Vector4 = _player.global_position - _dreamer.global_position
	away.y = 0.0
	away.w = 0.0
	if away.length() < 0.01:
		return
	_player.global_position = _flinch_from + away.normalized() * flinch_step * smoothstep(0.0, 1.0, _flinch)


# ------------------------------------------------------------------ the shots

## Everything in the far room's own frame, where the camera lives.
func _local(g: Vector4) -> Vector4:
	return _far.global_basis.inverse() * (g - _far.global_position)


func _frame(which: String, u: float) -> void:
	var d: Vector4 = _local(_dreamer.global_position)
	var m: Vector4 = _local(_mouth.global_position)
	var back: Projection = _far.global_basis.inverse()
	var mz: Vector4 = (back * _mouth.global_basis.z).normalized()
	var my: Vector4 = (back * _mouth.global_basis.y).normalized()
	var p: Vector4 = _local(_player.global_position)
	var head: Vector4 = p + Vector4(0, 1.0, 0, 0)
	var avatar: Node = _player.get_node_or_null("Avatar")
	var head_node: Node4D = avatar.get("head") as Node4D if avatar != null else null
	if head_node != null:
		head = _local(head_node.global_position)
	# Toward it across the floor, and your right-hand side as you face it.
	var f: Vector4 = d - p
	f.y = 0.0
	f.w = 0.0
	f = f.normalized() if f.length() > 0.01 else Vector4(0, 0, -1, 0)
	var s := Vector4(-f.z, 0.0, f.x, 0.0)
	var up := Vector4(0, 1, 0, 0)
	var eye: Vector4
	var aim: Vector4
	var fov: float = 55.0
	match which:
		"wide_pan":
			# From well behind you, low, sliding left to right: you small at the bottom of
			# the frame, it filling the top.
			var k: float = smoothstep(0.0, 1.0, u / 16.0)
			eye = p - f * 11.0 + up * 2.0 + s * lerpf(-9.0, 9.0, k)
			aim = p.lerp(d, 0.55) + up * 5.5 + s * lerpf(-2.5, 2.5, k)
			fov = 58.0
		"mouth":
			# Straight down its throat, pushing in: teeth, the swirl, the heart.
			var k: float = smoothstep(0.0, 1.0, u / 10.0)
			eye = m + mz * lerpf(5.2, 4.0, k) + my * 0.15
			aim = m - mz * 0.6
			fov = 32.0
		"mouth_push":
			# The same, from further, and slower - it comes to you.
			var k: float = smoothstep(0.0, 1.0, u / 9.0)
			eye = m + mz * lerpf(8.0, 3.6, k) + my * 0.1
			aim = m - mz * 0.4
			fov = 30.0
		"low":
			# From under it, looking up into it: it looms.
			eye = p.lerp(d, 0.72) + up * 0.5 + s * (1.0 + 0.05 * u)
			aim = m - up * 0.8
			fov = 64.0
		"face":
			# Your face, a three-quarter view from its side, drifting a little.
			# Aimed under the chin, so the face sits in the upper third, clear of the words.
			eye = head + f * 1.5 + s * (0.5 + 0.02 * u)
			aim = head - up * 0.24
			fov = 34.0
		"shoulder":
			# Low behind you, past your LEFT shoulder, up at it - aimed halfway between the
			# two of you, so both hold the frame, and you on the right of it, clear of the
			# replies, which hang down the left.
			eye = head - f * 2.0 - s * 0.7 - up * 0.6 + s * 0.04 * sin(u * 0.4)
			var to_head: Vector4 = (head - eye).normalized()
			var to_mouth: Vector4 = (m - eye).normalized()
			aim = eye + (to_head + to_mouth).normalized()
			fov = 55.0
		"side":
			# In profile, from far out to the side: you on one side of the frame, it high on
			# the other, trucking slowly along the line between you.
			var mid: Vector4 = p.lerp(d, 0.45)
			eye = mid + s * 14.0 + up * 3.2 + f * lerpf(-1.0, 1.0, smoothstep(0.0, 1.0, u / 14.0))
			aim = mid + up * 5.0
			fov = 56.0
		_:
			# "rise": up from behind you as it lets you go.
			var k: float = smoothstep(0.0, 1.0, u / 8.0)
			eye = p - f * 6.0 + up * lerpf(1.5, 5.5, k)
			aim = p.lerp(m, 0.5)
			fov = 55.0
	_camera.position = eye
	_camera.basis = _look(aim - eye)
	_camera.field_of_view_3d = deg_to_rad(fov)


## Looking along [param gap] within x, y and z, the w column left as the world's - the
## same look-at PenNpcTalk4D uses, for the same reason: a free one turns the slice.
static func _look(gap: Vector4) -> Projection:
	var forward := Vector3(gap.x, gap.y, gap.z).normalized()
	var zc: Vector3 = -forward
	var xc: Vector3 = Vector3(0.0, 1.0, 0.0).cross(zc)
	if xc.length_squared() < 0.000001:
		xc = Vector3(1.0, 0.0, 0.0)
	xc = xc.normalized()
	var yc: Vector3 = zc.cross(xc)
	return Projection(Vector4(xc.x, xc.y, xc.z, 0.0), Vector4(yc.x, yc.y, yc.z, 0.0),
		Vector4(zc.x, zc.y, zc.z, 0.0), Vector4(0.0, 0.0, 0.0, 1.0))
