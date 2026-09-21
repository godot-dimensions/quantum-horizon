extends Control

## A spirit level for the fourth axis: the pen's ground, and your slice hovering over it.
##
## WHAT IT IS FOR. Once you start slicing, the world stops looking like itself - the fence
## comes apart into slivers, the coop cuts at an angle, and there is no landmark left to
## steer by. The prism tells you how far a chicken is off your slice, and the ruler tells
## you your w, but neither answers "which way is home" - because home is not one number.
##
## HOME IS THREE NUMBERS AND THIS IS ONE PICTURE OF THEM. Your slice can be wrong in
## three ways: your position along w, and the two rotations, xw and zw. The prism folds
## the rotations into a single "tilt" figure, so it can tell you that something is off
## without telling you which control fixes it.
##
## Drop the height and your slice is literally a PLANE in (x, z, w) space, and the pen is
## flat at w = 0. So the whole question becomes "is my plane flat, and level with theirs",
## which is one shape against another:
##
##   flat and together ....... home
##   flat but floating ....... your w is off - E and Q
##   tilted across the short  . xw is off - drag through W left or right
##   tilted down its length .. zw is off - drag through W up or down
##
## Measured, those really are distinct: 20 degrees of xw puts the four corners at
## -1.8/+1.8/+1.8/-1.8, and 20 degrees of zw puts them at -5.7/-5.7/-2.4/-2.4. You can
## read which one is wrong off the shape without a number anywhere near it.
##
## THE HEIGHTS COME FROM THE RIG'S BASIS, NOT FROM THE TWO ANGLES. A point Q is on your
## slice when (Q - P) dot W is zero, so the w your slice sits at above any (x, z) falls
## straight out of that one line. Deriving it from sin and cos of the slice angles instead
## would mean assuming which order from_xw and from_zw compose in, which is one more thing
## to get backwards silently.
##
## IT READS, IT DOES NOT DRIVE. No snap-home button, for the same reason the prism has
## none: arriving on a slice is the thing you are meant to have done.

@export var player_path: NodePath
## The pen, whose footprint is the fixed half of the picture.
@export var pen_path: NodePath
## Its fence, for the extents. Without it the defaults below are used.
@export var fence_path: NodePath
## The coop, drawn small at its end of the pen. It is there to break the rectangle's
## symmetry - without something to tell one end from the other, a quad tilted forwards
## and a quad tilted backwards are the same picture.
@export var coop_path: NodePath
## Whose basis carries the slice rotation. The camera rig, as everywhere else here.
@export var slice_frame_path: NodePath

@export_group("Reading")
## How close counts as home. The same figure the catch uses, so "the diagram says home"
## and "the game lets me act" cannot disagree.
@export_range(0.05, 2.0, 0.05) var home_tolerance: float = 0.35
## Pixels per world unit of w. The pen is far enough down the z axis that a small zw
## rotation lifts its far corners a long way, so this stays small and the quad is clamped.
@export_range(2.0, 60.0, 0.5) var w_pixels: float = 22.0
## Pixels per world unit across the ground. The pen is ten units by nine, so this is what
## decides how much of the panel the footprint fills.
@export_range(1.0, 48.0, 0.5) var ground_scale: float = 18.0

@export_group("Look")
@export var ground_color: Color = Color(1.0, 1.0, 1.0, 0.45)
@export var coop_color: Color = Color(1.0, 1.0, 1.0, 0.3)
@export var home_color: Color = Color(0.45, 0.95, 0.5, 0.95)
@export var near_color: Color = Color(1.0, 0.85, 0.25, 0.95)
@export var far_color: Color = Color(0.95, 0.45, 0.35, 0.95)
@export var toggle_key: Key = KEY_N

## Extents used if the fence cannot be read.
const FALLBACK := Rect2(-5.0, -4.5, 10.0, 9.0)
## ISOMETRIC, AND NOT THE OBLIQUE VIEW THIS STARTED WITH.
##
## Any fixed projection from three dimensions to two collapses one direction, and every
## plane containing that direction draws as a LINE. The first attempt put x along the
## screen, z receding up-and-right, and w straight up - which shares the vertical between
## z and w, and collapsed at a compound tilt of about 17 degrees by 14. That is not an
## exotic corner of the space, it is where you actually are, and the instrument turned
## into a red sliver exactly when it was needed.
##
## Here x and z fall away to opposite sides and w alone is vertical, so the collapse only
## happens when the slice rises by about 0.8 for every unit along BOTH axes at once -
## roughly 39 degrees each way together, which takes some doing.
const ISO_RISE: float = 0.5
## Below this the slice is nearly edge-on to W and the heights run away to infinity.
const EDGE_ON: float = 0.05

var _player: Node4D
var _pen: Node4D
var _fence: Node
var _coop: Node4D
var _frame: Node4D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_player = get_node_or_null(player_path) as Node4D
	_pen = get_node_or_null(pen_path) as Node4D
	_fence = get_node_or_null(fence_path)
	_coop = get_node_or_null(coop_path) as Node4D
	_frame = get_node_or_null(slice_frame_path) as Node4D
	if _player == null or _pen == null:
		push_warning("PenSlicePlane: player or pen missing - the level has nothing to level against.")


func _process(_delta: float) -> void:
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and (event as InputEventKey).keycode == toggle_key:
		visible = not visible
		get_viewport().set_input_as_handled()


## The pen's footprint in world x and z, read off the fence so it follows if the pen is
## resized rather than being a second set of numbers that can drift out of step.
func _footprint() -> Rect2:
	if _fence == null:
		return Rect2(_pen.global_position.x + FALLBACK.position.x,
			_pen.global_position.z + FALLBACK.position.y, FALLBACK.size.x, FALLBACK.size.y)
	var west: float = float(_fence.get("extend_x_negative"))
	var east: float = float(_fence.get("extend_x_positive"))
	var south: float = float(_fence.get("extend_z_negative"))
	var north: float = float(_fence.get("extend_z_positive"))
	return Rect2(_pen.global_position.x - west, _pen.global_position.z - south,
		west + east, south + north)


## The world w at which your slice crosses the vertical line through (x, z). See the note
## at the top: this is (Q - P) dot W = 0 rearranged, and nothing else.
func _w_above(x: float, z: float) -> float:
	var p: Vector4 = _player.global_position
	var n: Vector4 = (_frame.global_basis if _frame != null else _player.global_basis).w
	if absf(n.w) < EDGE_ON:
		return NAN
	return p.w - ((x - p.x) * n.x + (0.0 - p.y) * n.y + (z - p.z) * n.z) / n.w


## World (x, z, w) to a point on the panel.
func _plan(x: float, z: float, w: float, origin: Vector2, mid: Vector2) -> Vector2:
	var dx: float = (x - mid.x) * ground_scale
	var dz: float = (z - mid.y) * ground_scale
	return origin + Vector2(dx - dz, (dx + dz) * ISO_RISE - w * w_pixels)


func _draw() -> void:
	if _player == null or _pen == null:
		return
	var pen: Rect2 = _footprint()
	var mid: Vector2 = pen.position + pen.size * 0.5
	var origin := Vector2(size.x * 0.5, size.y * 0.55)
	var font: Font = ThemeDB.fallback_font

	# The radar has its dark ellipse to sit on; this had nothing, and a diagram made
	# entirely of thin lines is unreadable over a sunlit field.
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.42), true)

	var corners: Array = [Vector2(pen.position.x, pen.position.y),
		Vector2(pen.end.x, pen.position.y), Vector2(pen.end.x, pen.end.y),
		Vector2(pen.position.x, pen.end.y)]

	# The pen's own ground, flat at w = 0. This is the thing you are matching.
	var flat := PackedVector2Array()
	for c in corners:
		flat.append(_plan(c.x, c.y, 0.0, origin, mid))
	flat.append(flat[0])
	draw_polyline(flat, ground_color, 1.5, true)
	if _coop != null:
		# A small square at the coop's end, so one end of the pen is tellable from the
		# other and the direction of a tilt can be read.
		var at: Vector4 = _coop.global_position
		var coop := PackedVector2Array()
		for d in [Vector2(-1.2, -1.2), Vector2(1.2, -1.2), Vector2(1.2, 1.2), Vector2(-1.2, 1.2)]:
			coop.append(_plan(at.x + d.x, at.z + d.y, 0.0, origin, mid))
		coop.append(coop[0])
		draw_polyline(coop, coop_color, 1.0, true)

	var heights: Array = []
	var worst: float = 0.0
	for c in corners:
		var w: float = _w_above(c.x, c.y)
		if is_nan(w):
			_label(font, "your slice is edge-on to W - drag back", Vector2(10.0, size.y - 10.0),
				far_color)
			return
		heights.append(w)
		worst = maxf(worst, absf(w))

	var home: bool = worst <= home_tolerance
	var colour: Color = home_color if home else (near_color if worst < 2.0 else far_color)

	# Your slice, over the same four corners. Clamped so a big tilt bends the picture
	# rather than throwing it off the panel - the shape still says which way to go.
	var reach: float = (size.y * 0.42) / w_pixels
	var live := PackedVector2Array()
	for i in corners.size():
		var c: Vector2 = corners[i]
		var w: float = clampf(heights[i], -reach, reach)
		var point: Vector2 = _plan(c.x, c.y, w, origin, mid)
		live.append(point)
		# A drop line to the ground below it, which is what makes a small gap visible.
		draw_line(_plan(c.x, c.y, 0.0, origin, mid), point,
			Color(colour.r, colour.g, colour.b, 0.4), 1.0)
	var fill := PackedVector2Array(live)
	draw_colored_polygon(fill, Color(colour.r, colour.g, colour.b, 0.14))
	live.append(live[0])
	draw_polyline(live, colour, 2.0, true)

	_label(font, "the pen's ground, and your slice over it", Vector2(10.0, 20.0),
		Color(1.0, 1.0, 1.0, 0.75))
	_label(font, _reading(heights, worst, home), Vector2(10.0, size.y - 10.0), colour)


## What the shape is saying, in one line, for when it is nearly matched and the picture
## has run out of resolution.
func _reading(heights: Array, worst: float, home: bool) -> String:
	if home:
		return "home - the pen's own slice"
	var lift: float = 0.0
	for h in heights:
		lift += h
	lift /= float(heights.size())
	# Across the short side against down the long one: whichever bend is larger is the
	# rotation that is most wrong, and the lift is what E and Q fix.
	var across: float = absf((heights[1] + heights[2]) - (heights[0] + heights[3])) * 0.5
	var along: float = absf((heights[2] + heights[3]) - (heights[0] + heights[1])) * 0.5
	var parts: PackedStringArray = []
	if absf(lift) > home_tolerance:
		parts.append("press %s" % ("Q" if lift > 0.0 else "E"))
	if maxf(across, along) > home_tolerance:
		parts.append("level it" if across >= along else "level it lengthways")
	if parts.is_empty():
		parts.append("nearly")
	return "%s   (worst corner %+.1f)" % [" and ".join(parts), worst]


func _label(font: Font, text: String, at: Vector2, colour: Color) -> void:
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, colour)
