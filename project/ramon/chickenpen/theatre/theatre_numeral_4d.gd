@tool
extends Node4D

## Big glowing figures hanging in the air over an exhibit.
##
## SEVEN SEGMENTS, because that is the shape of an instrument rather than the shape of
## typography. The captions already carry sentences; what this carries is the one number
## the moment is actually about, at a size you can read from the back of the house, in the
## same language as the rim lights and the beams. A Label floating in 3D space would have
## been less work and would have looked like a spreadsheet in a spaceship.
##
## IT IS BUILT, NOT DRAWN. Each segment is a BoxTetraMesh4D with a real extent through W,
## so the numbers are objects in the room: turn your slice and they thin out and go, the
## same as everything else on the stage. A screen-space overlay would sit outside the
## world's own rules, which in a room whose entire subject is those rules would be a lie.

const GLYPHS := {
	"0": "abcdef", "1": "bc", "2": "abged", "3": "abgcd", "4": "fgbc",
	"5": "afgcd", "6": "afgecd", "7": "abc", "8": "abcdefg", "9": "abcdfg",
	"-": "g", " ": "",
}

@export_tool_button("Rebuild") var _rebuild_action: Callable = rebuild

@export var text: String = "0": set = _set_text
@export var glow: Color = Color(0.45, 0.88, 1.0): set = _set_glow
@export_range(0.2, 4.0, 0.05) var glyph_height: float = 1.0: set = _set_height
@export_range(0.02, 0.4, 0.01) var thickness: float = 0.10
@export_range(0.5, 6.0, 0.1) var w_depth: float = 0.6
## A slow rise and fall, so they read as held up by something rather than nailed on.
@export_range(0.0, 0.4, 0.01) var bob: float = 0.06
@export_range(0.1, 4.0, 0.1) var bob_speed: float = 0.9

@export_group("Hologram")
## A band of brightness travelling up the figure, the way a projected thing is drawn a
## line at a time. Subtle on purpose - it should be something you notice second.
@export_range(0.0, 1.0, 0.05) var scan_strength: float = 0.45
@export_range(0.1, 4.0, 0.1) var scan_speed: float = 0.8
## And the occasional dropout, because nothing in this room is meant to feel solid.
@export_range(0.0, 1.0, 0.05) var flicker: float = 0.18

var _bars: Array[MeshInstance4D] = []
var _base: float = 0.0
var _clock: float = 0.0


func _set_text(v: String) -> void:
	text = v
	if is_node_ready():
		rebuild()


func _set_glow(v: Color) -> void:
	glow = v
	for bar in _bars:
		if is_instance_valid(bar):
			var material := bar.material_override as TetraMaterial4D
			if material != null:
				material.albedo_color = glow


func _set_height(v: float) -> void:
	glyph_height = v
	if is_node_ready():
		rebuild()


func _ready() -> void:
	_base = position.y
	rebuild()


func rebuild() -> void:
	for child in get_children():
		child.free()
	_bars.clear()
	var h: float = glyph_height
	var w: float = h * 0.62
	var step: float = w + h * 0.26
	var total: float = step * float(maxi(text.length(), 1)) - (step - w)
	var x: float = -total * 0.5 + w * 0.5

	for i in text.length():
		var ch: String = text[i]
		if ch == ".":
			# A point is not a glyph; it tucks in beside the one before it.
			_bar("Dot%d" % i, Vector4(x - step * 0.5 + w * 0.15, h * 0.10, 0.0, 0.0),
				Vector3(thickness, thickness, thickness))
			continue
		if ch == "/":
			# The only diagonal, and the reason the slash is worth having: "0 of 3" is the
			# most important number in the room and it wants to be one figure, not three.
			var slash := _bar("Slash%d" % i, Vector4(x, h * 0.5, 0.0, 0.0),
				Vector3(thickness, h * 0.92, thickness))
			slash.basis = Basis4D.from_xy(0.34)
			x += step
			continue
		var segs: String = String(GLYPHS.get(ch, ""))
		for s in segs.length():
			_segment(ch + str(i), segs[s], x, h, w)
		x += step


func _segment(tag: String, seg: String, x: float, h: float, w: float) -> void:
	var across := Vector3(w - thickness, thickness, thickness)
	var down := Vector3(thickness, h * 0.5 - thickness, thickness)
	match seg:
		"a": _bar(tag + "a", Vector4(x, h * 0.96, 0.0, 0.0), across)
		"g": _bar(tag + "g", Vector4(x, h * 0.52, 0.0, 0.0), across)
		"d": _bar(tag + "d", Vector4(x, h * 0.08, 0.0, 0.0), across)
		"f": _bar(tag + "f", Vector4(x - w * 0.5, h * 0.74, 0.0, 0.0), down)
		"b": _bar(tag + "b", Vector4(x + w * 0.5, h * 0.74, 0.0, 0.0), down)
		"e": _bar(tag + "e", Vector4(x - w * 0.5, h * 0.30, 0.0, 0.0), down)
		"c": _bar(tag + "c", Vector4(x + w * 0.5, h * 0.30, 0.0, 0.0), down)


func _bar(part: String, at: Vector4, size: Vector3) -> MeshInstance4D:
	var node := MeshInstance4D.new()
	node.name = part
	var mesh := BoxTetraMesh4D.new()
	mesh.size = Vector4(size.x, size.y, size.z, w_depth)
	node.mesh = mesh
	var material := TetraMaterial4D.new()
	material.albedo_color = glow
	node.material_override = material
	add_child(node)
	node.position = at
	if Engine.is_editor_hint() and get_tree() != null and get_tree().edited_scene_root != null:
		node.owner = get_tree().edited_scene_root
	_bars.append(node)
	return node


func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or bob <= 0.0:
		return
	_clock += _delta
	# Rebuilt rather than assigned into: `position` is a property, and writing one
	# component of a property is a trick worth not relying on.
	var at: Vector4 = position
	position = Vector4(at.x, _base + sin(_clock * bob_speed) * bob, at.z, at.w)
	_project()


## The holographic part: a band of light travelling up the figure, and a wobble in the
## whole thing. Both are done by pushing the albedo around rather than with a shader,
## because the 4D renderer draws cross-sections of tetrahedra and a screen-space effect
## would not survive the slice turning - which is the one thing in here that must.
func _project() -> void:
	if _bars.is_empty():
		return
	# One shared dropout for the whole figure. Mostly 1.0, occasionally much less, so it
	# reads as a signal rather than as a pulse.
	var noise: float = sin(_clock * 11.3) * sin(_clock * 4.7) * sin(_clock * 2.1)
	var dropout: float = 1.0 - flicker * maxf(0.0, noise * 1.6 - 0.55)
	var band: float = fposmod(_clock * scan_speed, 1.6) - 0.3
	for bar in _bars:
		if not is_instance_valid(bar):
			continue
		var material := bar.material_override as TetraMaterial4D
		if material == null:
			continue
		var height: float = bar.position.y / maxf(glyph_height, 0.01)
		var near: float = 1.0 - clampf(absf(height - band) / 0.22, 0.0, 1.0)
		var lift: float = 1.0 + scan_strength * near
		material.albedo_color = Color(
			clampf(glow.r * lift * dropout, 0.0, 1.0),
			clampf(glow.g * lift * dropout, 0.0, 1.0),
			clampf(glow.b * lift * dropout, 0.0, 1.0), glow.a)


func bar_count() -> int:
	return _bars.size()
