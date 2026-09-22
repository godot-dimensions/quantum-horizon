@tool
extends Node4D

## A door that is not in a wall: an arch with a field across it, used both for the one
## Trym raises in the field and the one that brings you back.
##
## ONE SCRIPT FOR BOTH ENDS. They are the same object doing the same job in opposite
## directions - a frame, a field, a trigger and a destination - and writing the exit
## separately would mean two places to get the crossing wrong.
##
## IT GROWS RATHER THAN APPEARING. A door that exists on one frame and not the previous
## one reads as a loading error; the same door unfolding over a second and a half reads as
## somebody switching it on. The frame comes up first and the field fills in after, because
## that order is the one that looks deliberate.
##
## IT RISES OUT OF THE GROUND AND LEAVES THROUGH THE AIR. Opening, the frame comes up from
## under the floor; shutting, it lifts away upward instead of sinking back where it came
## from. Same animation, opposite direction, and the difference is the whole read: one is
## a thing being built, the other is a thing being taken away.
##
## AND WHEN IT IS SHUT IT IS NOT THERE AT ALL. Hidden, not merely lowered - a closed door
## parked under the floor still has its lintel at ground level, which is a mystery beam
## lying in a field from the moment the scene loads.
##
## THE FIELD IS THICK THROUGH W. It is a doorway in four dimensions and a player who has
## turned their slice must still be able to walk into it - a thin one would be a door that
## only exists on the slice it was built on, which is a joke this scene has already made
## once and should not make by accident.

signal entered

@export_tool_button("Rebuild") var _rebuild_action: Callable = rebuild

@export var player_path: NodePath
## Off until something switches it on. The one Trym raises in the field starts off; the
## one at the head of the theatre's walkway is simply standing when you get there.
@export var armed: bool = true: set = _set_armed
## Open the moment it is built, for a door that is meant to be already standing.
@export var starts_open: bool = false

@export_group("Shape")
@export_range(0.8, 6.0, 0.1) var width: float = 2.2
@export_range(1.4, 8.0, 0.1) var height: float = 3.1
@export_range(0.1, 1.0, 0.05) var frame_thickness: float = 0.26
@export_range(0.5, 12.0, 0.5) var w_depth: float = 5.0
@export var frame_color: Color = Color(0.16, 0.19, 0.27)
@export var edge_color: Color = Color(0.32, 0.86, 1.0)
@export var field_color: Color = Color(0.20, 0.62, 0.95)

@export_group("Opening")
@export_range(0.2, 6.0, 0.1) var open_seconds: float = 1.5
## How deep the doorway's trigger is, measured along the way through it. The trigger is
## the SHAPE OF THE DOOR, not a circle around its middle - it is two metres wide and a
## circle of this radius leaves both outer thirds of it untriggered, so you could walk
## clean through the arch and nothing would happen. Which is what did happen.
@export_range(0.3, 4.0, 0.1) var enter_within: float = 1.15
## Brightened when something wants the way out noticed - at the end of the presentation,
## for instance. It is usable either way; this is an announcement, not a lock.
@export_range(0.0, 1.0, 0.05) var highlight: float = 0.0
## And it notices YOU. Walk up to it at any point in the talk and it lights and chimes,
## because a door that only acknowledges you when a script says so is a door you have to
## be told about. Zero turns this off.
@export_range(0.0, 12.0, 0.5) var wakes_within: float = 4.5
## Its own sound, because the farm's sfx system lives in the farm and is switched off
## while you are in here. A file if one is given, and a generated chime if not - so this
## works out of the box and can still be replaced with a real recording later.
@export_file("*.wav") var sound_file: String = ""
@export_range(-40.0, 6.0, 0.5) var sound_db: float = -9.0

var _player: Node4D
var _frame: Node4D
var _field: MeshInstance4D
var _open: float = 0.0
var _used: bool = false
var _shutting: bool = false
var _lit: float = 0.0
var _near: bool = false
var _chime: AudioStreamPlayer


func _set_armed(v: bool) -> void:
	armed = v
	if not is_node_ready():
		return
	if armed:
		_shutting = false
	elif _open > 0.05:
		# It was standing. Take it away upward rather than snapping it off.
		_shutting = true
	else:
		_open = 0.0
		_used = false


func _ready() -> void:
	_player = get_node_or_null(player_path) as Node4D
	rebuild()
	_open = 1.0 if starts_open else 0.0
	visible = _open > 0.005


func rebuild() -> void:
	for child in get_children():
		child.free()
	_frame = Node4D.new()
	_frame.name = "Frame"
	add_child(_frame)
	_own(_frame)

	var half: float = width * 0.5
	for side in [-1.0, 1.0]:
		_bar(_frame, "Post%d" % int(side), Vector4(side * half, height * 0.5, 0.0, 0.0),
			Vector3(frame_thickness, height, frame_thickness), frame_color)
		_bar(_frame, "PostEdge%d" % int(side),
			Vector4(side * half, height * 0.5, frame_thickness * 0.55, 0.0),
			Vector3(frame_thickness * 0.35, height * 0.94, frame_thickness * 0.3), edge_color)
	_bar(_frame, "Lintel", Vector4(0.0, height, 0.0, 0.0),
		Vector3(width + frame_thickness, frame_thickness, frame_thickness), frame_color)
	_bar(_frame, "LintelEdge", Vector4(0.0, height, frame_thickness * 0.55, 0.0),
		Vector3(width * 0.96, frame_thickness * 0.3, frame_thickness * 0.3), edge_color)
	_bar(_frame, "Sill", Vector4(0.0, 0.06, 0.0, 0.0),
		Vector3(width + frame_thickness, 0.12, frame_thickness * 1.3), edge_color)

	_field = _bar(self, "Field", Vector4(0.0, height * 0.5, 0.0, 0.0),
		Vector3(width * 0.92, height * 0.92, 0.06), field_color)
	_own(_field)

	# Rebuilt with everything else, because rebuild() frees every child.
	_chime = AudioStreamPlayer.new()
	_chime.name = "Chime"
	_chime.volume_db = sound_db
	_chime.stream = load(sound_file) if sound_file != "" else _make_chime()
	add_child(_chime)
	_own(_chime)


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _frame == null:
		return
	var want: float = 1.0 if armed else 0.0
	_open = move_toward(_open, want, delta / maxf(open_seconds, 0.05))
	# The frame rises first; the field fills in over the back half.
	visible = _open > 0.005
	if not visible:
		return
	var up: float = clampf(_open * 1.6, 0.0, 1.0)
	_frame.basis = Basis4D.from_zx(0.0)
	# Down through the floor on the way in, up into the air on the way out.
	var away: float = height * (1.0 - up) * (1.0 if _shutting else -1.0)
	_frame.position = Vector4(0.0, away, 0.0, 0.0)
	var fill: float = clampf((_open - 0.45) / 0.55, 0.0, 1.0)
	_field.visible = fill > 0.01
	if _field.mesh is BoxTetraMesh4D:
		(_field.mesh as BoxTetraMesh4D).size = Vector4(width * 0.92 * fill,
			height * 0.92 * fill, 0.06, w_depth)
	# Lit by whichever is asking for more: the presentation announcing it at the end, or
	# you standing in front of it.
	var was_near: bool = _near
	_near = wakes_within > 0.0 and _player != null and _flat_gap() <= wakes_within
	var want_lit: float = maxf(highlight, 1.0 if _near else 0.0)
	if _near and not was_near and _lit < 0.5 and _chime != null:
		_chime.play()
	_lit = move_toward(_lit, want_lit, delta * 1.6)
	var glow: TetraMaterial4D = _field.material_override as TetraMaterial4D
	if glow != null:
		# Lit, it breathes faster and further - the same field, turned up, so it reads as
		# the door being switched on rather than as a second door.
		var rate: float = 0.004 + 0.004 * _lit
		var shimmer: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * rate)
		var bright: Color = field_color.lerp(Color(0.45, 0.85, 1.0), _lit)
		glow.albedo_color = bright.lerp(Color(0.85, 0.97, 1.0),
			shimmer * (0.5 + 0.4 * _lit))

	if _used or _open < 0.99 or _player == null:
		return
	# In the DOOR'S own frame, so the trigger is the doorway rather than a circle around
	# its middle: as wide as the opening, as deep as it needs to be to catch somebody
	# walking briskly, and ignoring height because you do not have to be level with the
	# middle of a door to go through it. W is not ignored - a door on another slice is not
	# a door you are standing in.
	var local: Vector4 = global_basis.inverse() * (_player.global_position - global_position)
	var through: bool = absf(local.x) <= width * 0.5 + 0.3
	through = through and absf(local.z) <= enter_within
	through = through and absf(local.w) <= w_depth * 0.5
	if through:
		_used = true
		entered.emit()


## Lets it be walked through again, for a door that is used more than once.
func rearm() -> void:
	_used = false


## How far the player is, ignoring height, in this door's own frame.
func _flat_gap() -> float:
	if _player == null:
		return INF
	var local: Vector4 = global_basis.inverse() * (_player.global_position - global_position)
	return Vector2(local.x, local.z).length()


## A two-note chime, built rather than loaded. A fifth, struck together and decaying, which
## is about the least annoying thing that can be made out of two sine waves.
func _make_chime() -> AudioStreamWAV:
	var rate: int = 22050
	var seconds: float = 0.7
	var count: int = int(rate * seconds)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var t: float = float(i) / float(rate)
		# Struck, not faded in: a few milliseconds of attack, then an exponential tail.
		var envelope: float = minf(t / 0.008, 1.0) * exp(-t * 5.2)
		var wave: float = sin(TAU * 660.0 * t) * 0.6 + sin(TAU * 990.0 * t) * 0.4
		var sample: int = int(clampf(wave * envelope, -1.0, 1.0) * 32000.0)
		data.encode_s16(i * 2, sample)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = data
	return stream


func _bar(parent: Node, part: String, at: Vector4, size: Vector3,
		colour: Color) -> MeshInstance4D:
	var node := MeshInstance4D.new()
	node.name = part
	var mesh := BoxTetraMesh4D.new()
	mesh.size = Vector4(size.x, size.y, size.z, w_depth)
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
