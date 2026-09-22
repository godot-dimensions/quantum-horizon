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
## THE CHICKENS STAND ON IT TOO, each at its own (x, z) on a stem up to its own w. That
## turns the level from a way home into a way to ANY slice: a bird is catchable when your
## plane passes through its head, and because a bird far down the field needs a different
## rotation from one at your feet, its position on the ground matters as much as its
## height. A row of heights alone - which is what the ruler is - cannot say that.
##
## Their heights are scaled by THE SAME factor as the plane's, which matters more than it
## sounds: the picture shrinks itself to stay on the panel, and scaling the plane without
## scaling the birds would draw them aligned when they are not, or apart when they touch.
## Everything goes through _fitted together for exactly that reason.
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
## The flock, so the birds can stand on the diagram. Optional - without it this is still
## a way home, just not a way to anywhere else.
@export var manager_path: NodePath
## Which bird the locator is talking about, so the words and the picture agree.
@export var locator_path: NodePath
## The people, and the cat. Each is drawn as a blob at its own place and its own w, with
## its node's name beside it - so "which slice is Nessa on" is a glance rather than a
## walk. Named from the node, so adding somebody to this list is the whole job.
@export var people_paths: Array[NodePath] = []

@export_group("Reading")
## How close counts as home. The same figure the catch uses, so "the diagram says home"
## and "the game lets me act" cannot disagree.
@export_range(0.05, 2.0, 0.05) var home_tolerance: float = 0.35
## Pixels per world unit of w. The pen is far enough down the z axis that a small zw
## rotation lifts its far corners a long way, so this stays small and the quad is clamped.
## How much of the panel's HEIGHT one world unit of w takes. A fraction rather than a
## pixel count, so the diagram is the same diagram at any window size - at a fixed pixel
## scale it drew the same small picture in the middle of a panel twice the size.
@export_range(0.005, 0.2, 0.001) var w_fraction: float = 0.05
## How much of the panel's WIDTH one world unit across the ground takes.
##
## SIZED FOR THE FIELD, NOT THE PEN. On its own the pen would happily take the whole
## panel, and then every chicken would be off the edge of it - and a bird you cannot see
## is a bird you cannot line up on.
@export_range(0.005, 0.12, 0.0005) var ground_fraction: float = 0.025
## How far past the pen the SHEET of your slice is drawn, as a multiple of the pen's own
## half-extents. The white outline stays the pen's true size and is what you match; the
## sheet is your slice, which is infinite, and drawing only the pen-sized patch of it left
## every chicken standing outside the one thing they had to be judged against.
@export_range(1.0, 4.0, 0.05) var sheet_spread: float = 1.75
## What the diagram is centred on, as an offset from the pen.
##
## It used to be a long way north, because the whole flock lived on that side and centring
## on the pen left half the panel empty. Half of them ring the pen now, so the centre of
## what has to be shown has moved back towards it - and at the old offset the sheet's far
## corner ran off the edge of the panel.
@export var view_offset := Vector2(1.0, 3.0)

@export_group("Look")
@export var ground_color: Color = Color(1.0, 1.0, 1.0, 0.45)
@export var coop_color: Color = Color(1.0, 1.0, 1.0, 0.3)
@export var home_color: Color = Color(0.45, 0.95, 0.5, 0.95)
@export var near_color: Color = Color(1.0, 0.85, 0.25, 0.95)
@export var far_color: Color = Color(0.95, 0.45, 0.35, 0.95)
## White, like the birds themselves.
@export var chicken_color: Color = Color(1.0, 1.0, 0.97, 0.95)
## Only a fallback now - each blob takes its own character's colour. Set an entry in
## people_overrides to force one.
@export var people_color: Color = Color(0.93, 0.32, 0.36, 0.95)
## Index-matched to people_paths. Any entry with alpha above zero wins outright, which is
## the escape hatch for when the guess below picks the wrong one.
@export var people_overrides: Array[Color] = []
@export var target_color: Color = Color(1.0, 0.85, 0.25, 0.95)
## How big the birds are drawn, on top of the panel's own scaling.
@export_range(0.4, 2.0, 0.05) var bird_size: float = 0.9
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
var _manager: Node
var _locator: Node
var _people: Array[Node4D] = []
## Resolved once: a character's colours do not change, and hunting for them every frame
## for every marker would be work done sixty times a second for no reason.
var _people_colors: Array[Color] = []
## Whether each one is drawn as a person or as a cat. Settled once, off the same property
## that gives the cat its colour, rather than by matching its node's name - a name is a
## label somebody can change and a `fur` export is what the thing actually is.
var _people_are_cats: Array[bool] = []
## Where a name has already been written this frame, so the next one can step around it.
var _tags: Array[Vector3] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_player = get_node_or_null(player_path) as Node4D
	_pen = get_node_or_null(pen_path) as Node4D
	_fence = get_node_or_null(fence_path)
	_coop = get_node_or_null(coop_path) as Node4D
	_frame = get_node_or_null(slice_frame_path) as Node4D
	_manager = get_node_or_null(manager_path)
	_locator = get_node_or_null(locator_path)
	for path in people_paths:
		var who: Node4D = get_node_or_null(path) as Node4D
		if who != null:
			_people.append(who)
			_people_colors.append(_colour_of(who, _people.size() - 1))
			_people_are_cats.append(who.get("fur") is Color)
	# A bird well down the field projects outside the panel. Clipped, it simply is not
	# shown; unclipped it would be drawn across the rest of the screen.
	clip_contents = true
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


## The three scales, all derived from the panel rather than written in pixels, so the
## whole diagram grows and shrinks with the window instead of sitting at one size in the
## corner of whatever it is given.
func _ground_px() -> float:
	return maxf(size.x, 1.0) * ground_fraction


func _w_px() -> float:
	return maxf(size.y, 1.0) * w_fraction


## For the things that should grow with the panel but not linearly - dots, rings and
## lettering, which have a size below which they stop being readable and above which they
## start being shouty. 560 is the width this was drawn at.
func _ui() -> float:
	return clampf(size.x / 560.0, 0.85, 1.7)


## World (x, z, w) to a point on the panel.
func _plan(x: float, z: float, w: float, origin: Vector2, mid: Vector2) -> Vector2:
	var scale: float = _ground_px()
	var dx: float = (x - mid.x) * scale
	var dz: float = (z - mid.y) * scale
	return origin + Vector2(dx - dz, (dx + dz) * ISO_RISE - w * _w_px())


func _draw() -> void:
	if _player == null or _pen == null:
		return
	var pen: Rect2 = _footprint()
	var mid: Vector2 = pen.position + pen.size * 0.5 + view_offset
	var pen_mid: Vector2 = pen.position + pen.size * 0.5
	# The sheet: the same rectangle grown about the pen's centre.
	var sheet := Rect2(pen_mid - pen.size * 0.5 * sheet_spread, pen.size * sheet_spread)
	var sheet_corners: Array = [Vector2(sheet.position.x, sheet.position.y),
		Vector2(sheet.end.x, sheet.position.y), Vector2(sheet.end.x, sheet.end.y),
		Vector2(sheet.position.x, sheet.end.y)]
	var origin := Vector2(size.x * 0.5, size.y * 0.55)
	var font: Font = ThemeDB.fallback_font

	# The radar has its dark ellipse to sit on; this had nothing, and a diagram made
	# entirely of thin lines is unreadable over a sunlit field.
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.42), true)
	_tags.clear()

	var corners: Array = [Vector2(pen.position.x, pen.position.y),
		Vector2(pen.end.x, pen.position.y), Vector2(pen.end.x, pen.end.y),
		Vector2(pen.position.x, pen.end.y)]

	# The pen's own ground, flat at w = 0. This is the thing you are matching.
	var flat := PackedVector2Array()
	for c in corners:
		flat.append(_plan(c.x, c.y, 0.0, origin, mid))
	flat.append(flat[0])
	draw_polyline(flat, ground_color, 1.5, true)

	# THE FRAME THE SHEET LANDS ON. The sheet of your slice is drawn wider than the pen so
	# the flock stands under it, and that cost the thing the diagram was built around: two
	# shapes of the same size coming together. This is that shape - the sheet's own
	# footprint, lying flat at w = 0 - so being home is the coloured quad sitting exactly
	# on it rather than a judgement about a smaller rectangle somewhere inside it.
	var frame := PackedVector2Array()
	for c in sheet_corners:
		frame.append(_plan(c.x, c.y, 0.0, origin, mid))
	frame.append(frame[0])
	draw_polyline(frame, Color(ground_color.r, ground_color.g, ground_color.b,
		ground_color.a * 0.75), 1.5, true)
	if _coop != null:
		# A small square at the coop's end, so one end of the pen is tellable from the
		# other and the direction of a tilt can be read.
		var at: Vector4 = _coop.global_position
		var coop := PackedVector2Array()
		for d in [Vector2(-2.0, -2.0), Vector2(2.0, -2.0), Vector2(2.0, 2.0), Vector2(-2.0, 2.0)]:
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

	# Your slice, over the same four corners, shrunk as a WHOLE if it would leave the
	# panel. Clamping each corner on its own was the obvious way to keep it in frame and
	# it stops the picture being a plane: a corner that hits the limit is pinned while
	# the other three carry on, so the quad buckles and the one thing the instrument is
	# for - reading a flat plane against a tilted one - is the thing it stops showing.
	# Scaling every height by the same factor keeps it planar and keeps the tilt's
	# direction; only its steepness is compressed, and the caption carries the real
	# number anyway.
	# Everything that will be drawn, gathered before anything is fitted, because it all
	# has to share one scale. THE READING above stays on the pen's own corners - that is
	# what "am I on the pen's slice" means - while the sheet below is what gets drawn.
	var birds: Array = _flock()
	var folk: Array = _folk()
	var sheet_heights: Array = []
	for c in sheet_corners:
		sheet_heights.append(_w_above(c.x, c.y))
	var everything: Array = sheet_heights.duplicate()
	for bird in birds:
		everything.append(bird[2])
	for who in folk:
		everything.append(who[2])
	var fitted_all: Array = _fitted(everything)
	var drawn: Array = fitted_all.slice(0, sheet_corners.size())

	var live := PackedVector2Array()
	for i in sheet_corners.size():
		var c: Vector2 = sheet_corners[i]
		var w: float = drawn[i]
		var point: Vector2 = _plan(c.x, c.y, w, origin, mid)
		live.append(point)
		# A drop line to the ground below it, which is what makes a small gap visible.
		draw_line(_plan(c.x, c.y, 0.0, origin, mid), point,
			Color(colour.r, colour.g, colour.b, 0.4), 1.0)
	# FILLED AS TWO TRIANGLES, not as one quad. A strong tilt can fold the projected
	# corners into a bow-tie, and draw_colored_polygon cannot triangulate one of those -
	# it fails with "Invalid polygon data" and the fill vanishes. Triangles always
	# triangulate, and a folded shape still shades sensibly.
	var wash := Color(colour.r, colour.g, colour.b, 0.14)
	draw_colored_polygon(PackedVector2Array([live[0], live[1], live[2]]), wash)
	draw_colored_polygon(PackedVector2Array([live[0], live[2], live[3]]), wash)
	live.append(live[0])
	draw_polyline(live, colour, 2.0, true)

	# The shrink the picture actually applied, read back off a corner rather than
	# recomputed, so the rungs below cannot drift out of step with the quad.
	var shrink: float = 1.0
	for i in sheet_heights.size():
		if absf(sheet_heights[i]) > 0.001:
			shrink = drawn[i] / sheet_heights[i]
			break
	var at: int = sheet_corners.size()
	for i in birds.size():
		var bird: Array = birds[i]
		_draw_bird(bird[0], bird[1], fitted_all[at + i], bool(bird[3]), shrink,
			colour, origin, mid)
	at += birds.size()
	# BLOBS FIRST, NAMES AFTER. Drawn one person at a time, the next person's blob lands
	# on top of the last person's name - which is what put the cat over "Nessa". Two
	# passes keeps every name above every marker.
	var tags: Array = []
	for i in folk.size():
		var who: Array = folk[i]
		tags.append(_draw_person(who[0], who[1], fitted_all[at + i], who[4],
			bool(who[5]), shrink, colour, origin, mid))
	for i in folk.size():
		_name_tag(font, String(folk[i][3]), tags[i], folk[i][4])

	_label(font, "the pen's ground, and your slice over it", Vector2(10.0, 22.0 * _ui()),
		Color(1.0, 1.0, 1.0, 0.75))
	_label(font, _reading(heights, worst, home), Vector2(10.0, size.y - 10.0), colour)


## Every catchable bird, as [x, z, w, is_the_target].
func _flock() -> Array:
	if _manager == null:
		return []
	var target: Node = _locator.get("target") if _locator != null else null
	var out: Array = []
	for agent in (_manager.get("agents") as Array):
		if not bool(agent.call("can_be_caught")):
			continue
		var body: Node4D = agent.get_parent() as Node4D
		if body == null:
			continue
		var at: Vector4 = body.global_position
		out.append([at.x, at.z, at.w, agent == target])
	return out


## What colour a character is, taken from the character rather than from a list here -
## so recolouring somebody in the scene recolours their blob and the two cannot drift.
##
## THE HARD PART IS THAT THERE IS NO ONE PROPERTY. The chibi avatar paints a tunic from
## `skin` and the head, arms and legs from `accent`, and which of the two IS the character
## depends on the character: Nessa is her red tunic (skin), while the keeper reads as
## purple, and his purple is the accent - his tunic is tan.
##
## So: skip whatever looks like flesh, and take the rest. A hue between 15 and 45 degrees
## at less than 60% saturation is a skin tone, and no character is identified by one.
## That picks Nessa's red (hue 358) over her accent (hue 27), and the keeper's purple
## (hue 290) over his tan (hue 26) - the two cases that pull in opposite directions.
## When it guesses wrong, people_overrides settles it without changing any of this.
func _colour_of(who: Node4D, index: int) -> Color:
	if index < people_overrides.size() and people_overrides[index].a > 0.0:
		return people_overrides[index]
	# A character with a colour of its own says so plainly.
	for named in ["fur", "cloth", "shirt"]:
		var own: Variant = who.get(named)
		if own is Color:
			return _visible(own)
	# Otherwise it is a block avatar, either here or one node down.
	var avatar: Node = who if who.get("accent") is Color else who.get_node_or_null("Avatar")
	if avatar == null or not (avatar.get("accent") is Color):
		return people_color
	var tunic: Color = avatar.get("skin")
	var trim: Color = avatar.get("accent")
	if _is_flesh(tunic) and not _is_flesh(trim):
		return _visible(trim)
	if _is_flesh(trim) and not _is_flesh(tunic):
		return _visible(tunic)
	# Neither or both: take the more colourful of the two.
	return _visible(tunic if _saturation(tunic) >= _saturation(trim) else trim)


func _saturation(c: Color) -> float:
	var high: float = maxf(c.r, maxf(c.g, c.b))
	if high < 0.0001:
		return 0.0
	return (high - minf(c.r, minf(c.g, c.b))) / high


func _is_flesh(c: Color) -> bool:
	var hue: float = c.h * 360.0
	return hue >= 15.0 and hue <= 45.0 and _saturation(c) < 0.6


## TRUE TO THE CHARACTER, including the dark ones. Lightening the cat until it stood out
## against the panel was the obvious thing and it was wrong: the cat is black, and a grey
## blob for it is a worse marker than a black one, because the colour IS the name. Dark
## blobs get a pale outline when they are drawn instead, which costs a ring and keeps
## them honest.
func _visible(c: Color) -> Color:
	return Color(c.r, c.g, c.b, 0.95)


## The people and the cat, as [x, z, w, name].
func _folk() -> Array:
	var out: Array = []
	for who in _people:
		if not is_instance_valid(who):
			continue
		var at: Vector4 = who.global_position
		var slot: int = _people.find(who)
		out.append([at.x, at.z, at.w, who.name, _people_colors[slot],
			_people_are_cats[slot]])
	return out


## One person: a blob rather than a head, so they cannot be mistaken for livestock, with
## their name beside them and the same rung the birds get.
## Returns where the blob landed, so the name can be written in a later pass.
func _draw_person(x: float, z: float, w: float, tint: Color, is_cat: bool, shrink: float,
		plane_colour: Color, origin: Vector2, mid: Vector2) -> Vector2:
	var u: float = _ui()
	var foot: Vector2 = _plan(x, z, 0.0, origin, mid)
	var head: Vector2 = _plan(x, z, w, origin, mid)
	var true_w: float = _w_above(x, z)
	var on_slice: bool = false
	if not is_nan(true_w):
		var rung: Vector2 = _plan(x, z, true_w * shrink, origin, mid)
		draw_line(rung - Vector2(7.0 * u, 0.0), rung + Vector2(7.0 * u, 0.0),
			Color(plane_colour.r, plane_colour.g, plane_colour.b, 0.5), 1.0)
		on_slice = absf(true_w - w / maxf(shrink, 0.0001)) <= home_tolerance
	# THE BLOB KEEPS ITS OWN COLOUR. Repainting it green when it lands on your slice made
	# every marker the same colour at the default slice, which is where the game starts -
	# so the one thing the blobs are for, telling people apart at a glance, was gone
	# exactly when you first look at it. Being on your slice is a RING instead.
	var colour: Color = tint
	draw_line(foot, head, Color(colour.r, colour.g, colour.b, 0.35), 1.0)
	draw_circle(foot, 2.0 * u, Color(colour.r, colour.g, colour.b, 0.4))
	var scale: float = u * bird_size
	var middle: Vector2 = _cat_icon(head, colour, scale) if is_cat \
		else _person_icon(head, colour, scale)
	if on_slice:
		draw_arc(middle, 12.0 * scale, 0.0, TAU, 22, home_color, 2.0, true)
	return middle


## One bird: a stem on the pen's ground level, a head at its w, and a RUNG at the height
## your slice passes through at that spot.
##
## The rung is what makes the birds usable at all. The quad is only drawn over the pen's
## own footprint, and the flock stands well outside it - so without a mark at the bird's
## own position there is nothing to judge its head against, and the diagram shows you
## twelve heights against a plane that is somewhere else on the panel. Your slice is
## infinite; the rung is the bit of it that is under that bird.
func _draw_bird(x: float, z: float, w: float, is_target: bool, shrink: float,
		plane_colour: Color, origin: Vector2, mid: Vector2) -> void:
	var u: float = _ui()
	var foot: Vector2 = _plan(x, z, 0.0, origin, mid)
	var head: Vector2 = _plan(x, z, w, origin, mid)
	var true_w: float = _w_above(x, z)
	var on_slice: bool = false
	if not is_nan(true_w):
		var rung: Vector2 = _plan(x, z, true_w * shrink, origin, mid)
		draw_line(rung - Vector2(7.0 * u, 0.0), rung + Vector2(7.0 * u, 0.0),
			Color(plane_colour.r, plane_colour.g, plane_colour.b, 0.5), 1.0)
		on_slice = absf(true_w - w / maxf(shrink, 0.0001)) <= home_tolerance
	var colour: Color = target_color if is_target else chicken_color
	draw_line(foot, head, Color(colour.r, colour.g, colour.b, 0.35), 1.0)
	draw_circle(foot, 2.0 * u, Color(colour.r, colour.g, colour.b, 0.4))
	var middle: Vector2 = _chicken_icon(head, colour, u * bird_size)
	if is_target:
		draw_arc(middle, 13.0 * u * bird_size, 0.0, TAU, 24, target_color, 1.5, true)
	if on_slice:
		# It stands in your slice: this is the bird you can walk up to and take.
		draw_arc(middle, 10.5 * u * bird_size, 0.0, TAU, 22, home_color, 2.0, true)


## A person, front on, standing on the point. Returns the middle of them, for the ring
## and for where their name is hung.
##
## FRONT ON, WHERE THE CHICKENS AND THE CAT ARE IN PROFILE. That is the whole reason the
## silhouettes are tellable apart at fifteen pixels: a side-on animal and a face-on person
## do not share an outline, so the difference survives being small far better than any
## amount of detail would.
##
## EVERY ONE OF THEM GETS A PALE EDGE. Two of these characters are dressed in near-black
## - the cat's fur and Trym's shirt - and on a dark panel the edge is not decoration, it
## is the entire silhouette. It is drawn on all of them so they look like one set.
func _person_icon(at: Vector2, colour: Color, u: float) -> Vector2:
	var edge := Color(1.0, 1.0, 1.0, 0.5)
	draw_line(at + Vector2(-2.0, 0.0) * u, at + Vector2(-2.0, -5.0) * u, colour, 2.0 * u)
	draw_line(at + Vector2(2.0, 0.0) * u, at + Vector2(2.0, -5.0) * u, colour, 2.0 * u)
	# A torso that narrows towards the shoulders, which is most of what makes a blocky
	# figure read as a person rather than as a box on legs.
	var torso := PackedVector2Array([at + Vector2(-3.7, -4.6) * u,
		at + Vector2(3.7, -4.6) * u, at + Vector2(3.0, -12.2) * u,
		at + Vector2(-3.0, -12.2) * u])
	draw_colored_polygon(torso, colour)
	draw_line(at + Vector2(-3.4, -11.4) * u, at + Vector2(-5.6, -5.8) * u, colour, 1.8 * u)
	draw_line(at + Vector2(3.4, -11.4) * u, at + Vector2(5.6, -5.8) * u, colour, 1.8 * u)
	var skull: Vector2 = at + Vector2(0.0, -15.4) * u
	draw_circle(skull, 3.5 * u, colour)
	draw_arc(skull, 3.5 * u, 0.0, TAU, 18, edge, 1.0, true)
	var outline := PackedVector2Array(torso)
	outline.append(outline[0])
	draw_polyline(outline, edge, 1.0, true)
	return at + Vector2(0.0, -9.5) * u


## The cat, in profile like the birds, with the tail up - which is the pose that reads as
## a cat from across a room, and at this size reading is all there is.
func _cat_icon(at: Vector2, colour: Color, u: float) -> Vector2:
	var edge := Color(1.0, 1.0, 1.0, 0.5)
	for leg in [-3.0, 2.6]:
		draw_line(at + Vector2(leg, 0.0) * u, at + Vector2(leg, -3.4) * u, colour, 1.8 * u)
	# The tail, up and curling back over itself.
	var tail := PackedVector2Array()
	for i in 7:
		var t: float = float(i) / 6.0
		tail.append(at + Vector2(-5.4 - sin(t * 2.2) * 2.6, -6.6 - t * 8.4) * u)
	draw_polyline(tail, colour, 1.8 * u, true)
	var body: Vector2 = at + Vector2(0.0, -6.0) * u
	draw_colored_polygon(_oval(body, 6.0 * u, 3.3 * u), colour)
	draw_polyline(_closed(_oval(body, 6.0 * u, 3.3 * u)), edge, 1.0, true)
	var skull: Vector2 = at + Vector2(6.0 * u, -9.4 * u)
	draw_line(at + Vector2(3.6, -7.4) * u, skull, colour, 2.6 * u)
	draw_circle(skull, 3.0 * u, colour)
	draw_arc(skull, 3.0 * u, 0.0, TAU, 16, edge, 1.0, true)
	# Two ears, which is the other half of reading as a cat.
	for ear in [-1.9, 1.7]:
		draw_colored_polygon(PackedVector2Array([
			skull + Vector2(ear - 1.2, -1.8) * u, skull + Vector2(ear, -5.0) * u,
			skull + Vector2(ear + 1.3, -1.6) * u]), colour)
	return at + Vector2(0.6, -7.4) * u


## The same points again with the first repeated, for drawing an outline round a shape
## that was filled as a polygon.
func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var loop := PackedVector2Array(points)
	loop.append(loop[0])
	return loop


## A whole chicken, standing on the point, facing right. Returns where its body sits, so
## a ring can be drawn round the bird rather than round its feet.
##
## IT STANDS ON THE MARK RATHER THAN BEING CENTRED ON IT. The mark is the bird's own w,
## and the rung beside it is where your slice passes - so feet meeting rung is the whole
## reading, and a glyph centred on the mark would have half of itself below the line it
## is being judged against.
##
## It used to be a white ball with a beak and a comb stuck on. That reads as a chicken at
## five pixels and as a circle at fifteen, and the panel is big enough now to draw the
## bird properly.
func _chicken_icon(at: Vector2, colour: Color, u: float) -> Vector2:
	# Legs first, so the body covers where they meet it.
	draw_line(at + Vector2(-1.3, 0.0) * u, at + Vector2(-1.3, -3.6) * u, colour, 1.6 * u)
	draw_line(at + Vector2(1.8, 0.0) * u, at + Vector2(1.8, -3.6) * u, colour, 1.6 * u)
	# Tail, behind the body.
	draw_colored_polygon(PackedVector2Array([at + Vector2(-4.6, -9.0) * u,
		at + Vector2(-10.4, -13.4) * u, at + Vector2(-4.9, -6.0) * u]), colour)
	var body: Vector2 = at + Vector2(0.0, -8.0) * u
	draw_colored_polygon(_oval(body, 6.2 * u, 4.5 * u), colour)
	var skull: Vector2 = at + Vector2(5.9, -13.2) * u
	draw_circle(skull, 3.2 * u, colour)
	# A neck, or the head reads as a second bird sitting on the first.
	draw_line(at + Vector2(3.4, -9.4) * u, skull, colour, 2.6 * u)
	# Comb and beak.
	draw_colored_polygon(PackedVector2Array([at + Vector2(4.4, -15.6) * u,
		at + Vector2(6.1, -18.4) * u, at + Vector2(7.5, -15.6) * u]), colour)
	draw_colored_polygon(PackedVector2Array([at + Vector2(8.7, -13.9) * u,
		at + Vector2(12.0, -12.7) * u, at + Vector2(8.7, -11.6) * u]), colour)
	return at + Vector2(1.2, -10.0) * u


## An ellipse as a polygon, because draw_circle cannot be squashed and a chicken drawn
## with a round body is a ball with legs.
func _oval(centre: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 16:
		var a: float = TAU * float(i) / 16.0
		points.append(centre + Vector2(cos(a) * rx, sin(a) * ry))
	return points


## A name beside a blob, kept on the panel and out of its neighbour's way.
##
## The people are not evenly spread - Nessa, the lofted girl and the cat all live in the
## same corner of the field - so their names landed on top of each other and the ones near
## the edge were clipped to nonsense. Each tag is nudged to the side of its blob that has
## more room, and pushed down if the line above is already taken.
func _name_tag(font: Font, who: String, at: Vector2, colour: Color) -> void:
	var letters: int = int(round(13.0 * _ui()))
	var width: float = font.get_string_size(who, HORIZONTAL_ALIGNMENT_LEFT, -1, letters).x
	var left: bool = at.x + 12.0 + width > size.x - 6.0
	var spot := Vector2(at.x - 11.0 - width if left else at.x + 11.0, at.y + 4.0)
	spot.x = clampf(spot.x, 6.0, maxf(6.0, size.x - width - 6.0))
	# Compared as RECTANGLES, not as centres. Comparing centres let a tag clamped to the
	# left edge sit under a longer one whose centre was far enough away to pass, which is
	# how "LoftedGirl" ended up written through "Nessa".
	var settled: bool = false
	var guard: int = 0
	while not settled and guard < 8:
		settled = true
		guard += 1
		for taken in _tags:
			if absf(taken.y - spot.y) < letters + 1.0 \
					and spot.x < taken.x + taken.z and taken.x < spot.x + width:
				spot.y = taken.y + letters + 2.0
				settled = false
				break
	_tags.append(Vector3(spot.x, spot.y, width))
	draw_string(font, spot, who, HORIZONTAL_ALIGNMENT_LEFT, -1, letters,
		Color(colour.r, colour.g, colour.b, 0.95))


## The four heights as they are actually drawn: the true ones, scaled together if the
## steepest would otherwise run off the panel.
##
## A PLANE OVER A RECTANGLE HAS AN INVARIANT, and it is what makes this testable. For
## corners taken in cyclic order the alternating sum h0 - h1 + h2 - h3 is zero for any
## plane at all - the x and z terms cancel in pairs. Uniform scaling keeps it zero;
## clamping corners one at a time does not, which is precisely the bug.
func _fitted(heights: Array) -> Array:
	var reach: float = (size.y * 0.40) / maxf(_w_px(), 0.01)
	var worst: float = 0.0
	for h in heights:
		worst = maxf(worst, absf(h))
	if worst <= reach or worst < 0.0001:
		return heights.duplicate()
	var shrink: float = reach / worst
	return heights.map(func(h): return h * shrink)


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
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1,
		int(round(17.0 * _ui())), colour)
