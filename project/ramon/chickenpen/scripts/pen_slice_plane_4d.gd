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
##
## LANDMARKS, AND SOMEWHERE ELSE TO STAND. Anything in the group "slice_dial_landmark" is
## drawn like a person - its own (x, z), a stem up to its own w, a rung where your slice
## passes, a ring when your slice goes through it - with an archway for a figure, or a cube
## if its "dial_icon" says so, and its "dial_label" beside it (metadata, with "dial_color"
## and "dial_tolerance"). The cave's way through W is one, and the cube on the plinth (Ramon, 28 Sept: "the doorway should also be visible on the map so
## you can align to it and find it"). And a node in "slice_dial_anchor" takes the pen's
## place as what the dial is centred on and levels against, while it is in the tree: the
## cave hangs a kilometre from the pen, and anchored on the pen the dial pushed you out to
## its rim and everything round you with you.

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
## its node's name beside it - so "which slice is Mithra on" is a glance rather than a
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
@export_range(0.005, 0.12, 0.0005) var ground_fraction: float = 0.020
## How much of the dial's radius the SHEET of your slice fills. It is drawn concentric
## with the dial rather than over the pen, because your slice is infinite and the pen is
## not a natural middle for it - and at a fixed share of the dial it is always the same
## size and always centred, which makes "does it land on its frame" a sharper read than
## judging a rectangle that wandered about.
@export_range(0.3, 0.98, 0.01) var sheet_fill: float = 0.8
## How far out you may walk, as a share of the dial's radius, before the view starts
## following you.
##
## NOT ZERO, AND NOT ONE. Centred on you the whole time, the pen slides about constantly
## and the diagram loses the one fixed landmark it exists to provide. Anchored on the pen
## the whole time, you walk off your own instrument. Held until you reach this ring and
## following after it, the picture is still while you work near home and scrolls while you
## are out hunting - and you can never leave it.
@export_range(0.0, 0.95, 0.05) var dead_zone: float = 0.7
## Markers fade out over the last of the dial rather than popping off at the rim.
@export_range(0.0, 0.4, 0.01) var edge_fade: float = 0.14

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
@export var you_color: Color = Color(1.0, 1.0, 1.0, 0.95)
## How far the view wedge reaches on the map, in metres, and how strong its red is where
## it starts, under you; it fades to nothing at its far edge.
@export_range(1.0, 30.0, 0.5) var view_cone_length: float = 7.0
@export_range(0.0, 1.0, 0.02) var view_cone_alpha: float = 0.32
## How quickly the red dies away along the wedge: 1 is an even fade to its edge, higher is
## most of it gone in the first part (Ramon, 29 Sept: "make the gradient falloff fade
## sooner, it's very red from the start").
@export_range(1.0, 5.0, 0.1) var view_cone_falloff: float = 2.6
## The wedge is drawn this much narrower than the lens really sees (Ramon, 29 Sept: "a bit
## less than perfect 90 degrees cutout ... less wide"): at the pen's 16:9 and its real 77.3-degree
## lens the true sweep is 110 degrees, a third of a pie rather than a look; 0.59 draws it at
## 65, the width it was tuned to when the lens was thought to be 55.
@export_range(0.3, 1.0, 0.01) var view_cone_narrowing: float = 0.59
@export var view_cone_color: Color = Color(1.0, 0.24, 0.2)
## How big the birds are drawn, on top of the panel's own scaling.
@export_range(0.4, 2.0, 0.05) var bird_size: float = 0.9
@export var toggle_key: Key = KEY_N
## THE WAY BACK, WRITTEN ON THE INSTRUMENT THAT SHOWS YOU ARE LOST. The key that flattens
## the slice lives on the camera rig and was only ever named on the controls card in the
## other corner - which is the wrong corner. This dial is the thing that tells you your
## plane is tilted, so it is the thing that should tell you how to un-tilt it.
##
## It is read off the rig's own `home_key` rather than printed, the same as every other
## key named anywhere in this prototype: a printed key stops being true the moment
## somebody rebinds it.
##
## It sits there whether or not the slice is tilted: a key you only learn about once you
## are already lost is a key you learn too late.
@export var rig_path: NodePath = NodePath("../../Player/CameraRig")
@export var hint_color: Color = Color(1.0, 1.0, 1.0, 0.42)

## Extents used if the fence cannot be read.
const FALLBACK := Rect2(-5.0, -4.5, 10.0, 9.0)
const LANDMARK_GROUP := &"slice_dial_landmark"
const ANCHOR_GROUP := &"slice_dial_anchor"
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
var _rig: Node


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_player = get_node_or_null(player_path) as Node4D
	_pen = get_node_or_null(pen_path) as Node4D
	_fence = get_node_or_null(fence_path)
	_coop = get_node_or_null(coop_path) as Node4D
	_frame = get_node_or_null(slice_frame_path) as Node4D
	_manager = get_node_or_null(manager_path)
	_locator = get_node_or_null(locator_path)
	_rig = get_node_or_null(rig_path)
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


## A place standing in for the pen can set its own (metadata "dial_w_fraction"): the cave's
## way through W is nearly nine metres off in W, and at the pen's scale - set for chickens a
## metre or two off - it stood at the top of the dial.
func _w_px() -> float:
	var fraction: float = w_fraction
	var elsewhere: Node4D = _local_anchor() if is_inside_tree() else null
	if elsewhere != null and elsewhere.has_meta(&"dial_w_fraction"):
		fraction = float(elsewhere.get_meta(&"dial_w_fraction"))
	return maxf(size.y, 1.0) * fraction


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
	var font: Font = ThemeDB.fallback_font
	var u: float = _ui()
	var origin: Vector2 = size * 0.5
	var radius: float = minf(size.x, size.y) * 0.5 - 12.0 * u
	_tags.clear()

	# ROUND, and the roundness is not decoration: the dial scrolls now, so what is on it
	# changes as you walk, and a circle has no corners for a marker to hide in and no
	# direction that shows more than another. A rectangle would quietly favour whatever
	# lay along its diagonal.
	draw_circle(origin, radius, Color(0.0, 0.0, 0.0, 0.45))
	draw_arc(origin, radius, 0.0, TAU, 96, Color(1.0, 1.0, 1.0, 0.28), 1.5, true)

	var pen: Rect2 = _footprint()
	var anchor: Vector2 = pen.position + pen.size * 0.5
	# What the reading levels against: the pen, or the place standing in for it.
	var level: Rect2 = pen
	var elsewhere: Node4D = _local_anchor()
	if elsewhere != null:
		anchor = Vector2(elsewhere.global_position.x, elsewhere.global_position.z)
		level = Rect2(anchor - pen.size * 0.5, pen.size)
	var mid: Vector2 = _view_centre(anchor, origin, radius)

	# The sheet, sized to a share of the dial and concentric with it.
	var reach: float = radius * sheet_fill / maxf(_ground_px(), 0.0001)
	var span: float = maxf(pen.size.x + pen.size.y, 0.001)
	var half := Vector2(reach * pen.size.x / span, reach * pen.size.y / span)
	var sheet_corners: Array = [mid + Vector2(-half.x, -half.y), mid + Vector2(half.x, -half.y),
		mid + Vector2(half.x, half.y), mid + Vector2(-half.x, half.y)]

	var corners: Array = [Vector2(pen.position.x, pen.position.y),
		Vector2(pen.end.x, pen.position.y), Vector2(pen.end.x, pen.end.y),
		Vector2(pen.position.x, pen.end.y)]

	# The pen's own ground, flat at w = 0. Wherever it happens to be on the dial, this is
	# the landmark.
	var flat := PackedVector2Array()
	for c in corners:
		flat.append(_plan(c.x, c.y, 0.0, origin, mid))
	flat.append(flat[0])
	draw_polyline(flat, ground_color, 1.5, true)
	if _coop != null:
		# A small square at the coop's end, so one end of the pen is tellable from the
		# other and the direction of a tilt can be read.
		var coop_at: Vector4 = _coop.global_position
		var coop := PackedVector2Array()
		for d in [Vector2(-2.0, -2.0), Vector2(2.0, -2.0), Vector2(2.0, 2.0), Vector2(-2.0, 2.0)]:
			coop.append(_plan(coop_at.x + d.x, coop_at.z + d.y, 0.0, origin, mid))
		coop.append(coop[0])
		draw_polyline(coop, coop_color, 1.0, true)

	# THE FRAME THE SHEET LANDS ON, at w = 0 and the same size and place as the sheet, so
	# home is one shape sitting exactly on another rather than a judgement about a
	# rectangle somewhere inside it.
	var frame := PackedVector2Array()
	for c in sheet_corners:
		frame.append(_plan(c.x, c.y, 0.0, origin, mid))
	frame.append(frame[0])
	draw_polyline(frame, Color(ground_color.r, ground_color.g, ground_color.b,
		ground_color.a * 0.75), 1.5, true)

	# THE READING STAYS ON THE PEN'S OWN CORNERS. "Am I on the pen's slice" is the
	# question worth answering, and it is asked about the pen, not about whatever patch
	# of slice happens to be under the dial. (Or the anchor's, where there is one.)
	var heights: Array = []
	var worst: float = 0.0
	var level_corners: Array = [Vector2(level.position.x, level.position.y),
		Vector2(level.end.x, level.position.y), Vector2(level.end.x, level.end.y),
		Vector2(level.position.x, level.end.y)]
	for c in level_corners:
		var pen_w: float = _w_above(c.x, c.y)
		if is_nan(pen_w):
			_label(font, "your slice is edge-on to W - drag back",
				Vector2(origin.x - radius, origin.y + radius - 38.0 * u), far_color,
				radius * 2.0, 15.0)
			return
		heights.append(pen_w)
		worst = maxf(worst, absf(pen_w))

	var home: bool = worst <= home_tolerance
	var colour: Color = home_color if home else (near_color if worst < 2.0 else far_color)

	# Everything that will be drawn, gathered before anything is fitted, because it all
	# has to share one scale - scaling the sheet without scaling the birds would draw them
	# aligned when they are not.
	var birds: Array = _flock()
	var folk: Array = _folk()
	var marks: Array = _landmarks()
	var sheet_heights: Array = []
	for c in sheet_corners:
		sheet_heights.append(_w_above(c.x, c.y))
	var everything: Array = sheet_heights.duplicate()
	for bird in birds:
		everything.append(bird[2])
	for who in folk:
		everything.append(who[2])
	for mark in marks:
		everything.append(mark[2])
	var fitted_all: Array = _fitted(everything)
	var drawn: Array = fitted_all.slice(0, sheet_corners.size())

	var live := PackedVector2Array()
	for i in sheet_corners.size():
		var c: Vector2 = sheet_corners[i]
		var point: Vector2 = _plan(c.x, c.y, drawn[i], origin, mid)
		live.append(point)
		# A drop line to the ground below it, which is what makes a small gap visible.
		draw_line(_plan(c.x, c.y, 0.0, origin, mid), point,
			Color(colour.r, colour.g, colour.b, 0.4), 1.0)
	# FILLED AS TWO TRIANGLES, not as one quad. A strong tilt can fold the projected
	# corners into a bow-tie, and draw_colored_polygon cannot triangulate one of those.
	var wash := Color(colour.r, colour.g, colour.b, 0.14)
	draw_colored_polygon(PackedVector2Array([live[0], live[1], live[2]]), wash)
	draw_colored_polygon(PackedVector2Array([live[0], live[2], live[3]]), wash)
	live.append(live[0])
	draw_polyline(live, colour, 2.0, true)

	# The shrink the picture actually applied, read back off a corner rather than
	# recomputed, so the rungs cannot drift out of step with the quad.
	var shrink: float = 1.0
	for i in sheet_heights.size():
		if absf(sheet_heights[i]) > 0.001:
			shrink = drawn[i] / sheet_heights[i]
			break

	var at: int = sheet_corners.size()
	for i in birds.size():
		var bird: Array = birds[i]
		var fade: float = _fade(Vector2(bird[0], bird[1]), origin, mid, radius)
		if fade > 0.01:
			_draw_bird(bird[0], bird[1], fitted_all[at + i], bool(bird[3]), shrink,
				colour, origin, mid, fade)
	at += birds.size()
	# BLOBS FIRST, NAMES AFTER. Drawn one at a time, the next figure lands on top of the
	# last figure's name.
	var tags: Array = []
	var fades: Array = []
	for i in folk.size():
		var who: Array = folk[i]
		var fade: float = _fade(Vector2(who[0], who[1]), origin, mid, radius)
		fades.append(fade)
		tags.append(_draw_person(who[0], who[1], fitted_all[at + i], who[4],
			bool(who[5]), shrink, colour, origin, mid, fade) if fade > 0.01 else Vector2.ZERO)
	at += folk.size()
	for i in marks.size():
		var mark: Array = marks[i]
		var fade: float = _fade(Vector2(mark[0], mark[1]), origin, mid, radius)
		fades.append(fade)
		tags.append(_draw_landmark(mark[0], mark[1], fitted_all[at + i], mark[4], mark[5],
			mark[6], shrink, colour, origin, mid, fade) if fade > 0.01 else Vector2.ZERO)
	for i in folk.size():
		if fades[i] > 0.4:
			_name_tag(font, String(folk[i][3]), tags[i], folk[i][4])
	for i in marks.size():
		if fades[folk.size() + i] > 0.4:
			_name_tag(font, String(marks[i][3]), tags[folk.size() + i], marks[i][4], _icon_clearance(font, String(marks[i][6])))

	_draw_you(shrink, origin, mid, u)

	# SET IN FROM THE RIM, not level with it. draw_string places a BASELINE, so a caption
	# put level with the top of the circle draws entirely above it - and the chord that
	# close to the rim is narrower than the words are long, so it would spill out of the
	# sides as well. This band, between the sheet at 80% and the rim, is the clear ring.
	_label(font, "your slice, and the pen",
		Vector2(origin.x - radius, origin.y - radius + 52.0 * u),
		Color(1.0, 1.0, 1.0, 0.75), radius * 2.0, 15.0)
	_label(font, _reading(heights, worst, home, elsewhere != null),
		Vector2(origin.x - radius, origin.y + radius - 38.0 * u), colour, radius * 2.0, 15.0)
	# Under the reading, smaller and dimmer. See the note on rig_path.
	var back: String = _home_key()
	if back != "":
		_label(font, "%s  flatten the slice" % back,
			Vector2(origin.x - radius, origin.y + radius - 19.0 * u),
			hint_color, radius * 2.0, 12.5)


## Where the dial is looking: the pen while you are near it, you once you are not.
##
## The dead zone is measured on the PANEL, not in the world. The projection is not
## isotropic - a step along x moves you across the dial twice as far as a step along z
## moves you down it - so a circle measured in world units draws as an ellipse, and "you
## cannot leave the dial" would hold in one direction and fail in the other.
func _view_centre(anchor: Vector2, origin: Vector2, radius: float) -> Vector2:
	var here := Vector2(_player.global_position.x, _player.global_position.z)
	var on_panel: Vector2 = _plan(here.x, here.y, 0.0, origin, anchor) - origin
	var keep: float = radius * dead_zone
	if on_panel.length() <= keep or on_panel.length() < 0.0001:
		return anchor
	# Push the view along until you are back on the ring, turning the shift on the panel
	# back into a shift in the world.
	return anchor + _unplan(on_panel - on_panel.normalized() * keep)


## The projection, run backwards, on the w = 0 plane. u = (dx - dz) * s and
## v = (dx + dz) * ISO_RISE * s, which is two equations in two unknowns.
func _unplan(screen: Vector2) -> Vector2:
	var s: float = maxf(_ground_px(), 0.0001)
	var a: float = screen.x / s
	var b: float = screen.y / (ISO_RISE * s)
	return Vector2((a + b) * 0.5, (b - a) * 0.5)


## How solidly a marker at (x, z) is drawn: full inside the dial, fading over the last of
## it, gone outside. Popping off at the rim reads as a bug; fading reads as distance.
func _fade(at: Vector2, origin: Vector2, mid: Vector2, radius: float) -> float:
	var d: float = (_plan(at.x, at.y, 0.0, origin, mid) - origin).length()
	var edge: float = radius - 16.0 * _ui()
	if edge <= 0.0:
		return 0.0
	return clampf((edge - d) / maxf(edge * edge_fade, 1.0), 0.0, 1.0)


## You, on your own slice - which you always are, so the marker sits on the sheet by
## construction and is a check on the rest of the picture as much as a position.
##
## AN ARROW, NOT A DOT. The dial does not turn with you, so without something that points
## there is nothing on it to say which way you are facing, and "the chicken is over there"
## cannot be acted on.
func _draw_you(shrink: float, origin: Vector2, mid: Vector2, u: float) -> void:
	var here: Vector4 = _player.global_position
	var w: float = _w_above(here.x, here.z)
	if is_nan(w):
		return
	var spot: Vector2 = _plan(here.x, here.z, w * shrink, origin, mid)
	# NEGATIVE Z, and it was drawn positive and pointed exactly backwards.
	#
	# The rig's +Z is where the CAMERA sits - behind you, looking back - so the way you
	# actually go is its negative. The walker agrees without ever saying so: it reads
	# Input.get_axis("move_forward", "move_back"), which returns MINUS one for forward,
	# and multiplies that through the same basis. So the arrow is built from the same
	# expression the movement is, rather than from a guess about which way +Z points.
	var facing: Projection = _frame.get("movement_basis").call() if _frame != null \
		and _frame.has_method("movement_basis") else _player.global_basis
	var ahead: Vector4 = (facing * Vector4(0.0, 0.0, -1.0, 0.0)).normalized()
	var tip: Vector2 = _plan(here.x + ahead.x * 2.6, here.z + ahead.z * 2.6, w * shrink,
		origin, mid)
	var along: Vector2 = tip - spot
	if along.length() < 0.5:
		along = Vector2(0.0, -1.0)
	along = along.normalized()
	var side: Vector2 = Vector2(-along.y, along.x)
	_draw_view_cone(here, ahead, w * shrink, origin, mid)
	draw_colored_polygon(PackedVector2Array([spot + along * 9.0 * u,
		spot - along * 5.0 * u + side * 5.0 * u,
		spot - along * 2.0 * u,
		spot - along * 5.0 * u - side * 5.0 * u]), you_color)
	draw_arc(spot, 11.0 * u, 0.0, TAU, 20, Color(0.0, 0.0, 0.0, 0.45), 3.0, true)
	draw_arc(spot, 11.0 * u, 0.0, TAU, 20, you_color, 1.2, true)


## WHAT YOU CAN SEE, AS A WEDGE ON THE MAP. Trym, 25 Sept: the "minimap camera angle
## highlight cone thing". The arrow already says which way you face; this says how much of
## the field that facing takes in, which is the question you are actually asking when a
## chicken is on the dial and not on your screen - is it in front of me and off to one
## side, or behind me altogether.
##
## The real field of view, not a pretty angle: the one the camera renders with, which under
## the default projection is `field_of_view_4d` (it used to read `field_of_view_3d`, 55
## degrees, which the renderer ignores; the narrowing was cut from 0.76 to 0.59 at the same
## time, so the wedge on the map is the same width it always was). It is the vertical angle,
## so it is widened by the viewport's aspect into the horizontal one the eye actually sweeps. Drawn flat on the ground at your
## own w, under the arrow, faint enough that the birds on top of it still read first.
func _draw_view_cone(here: Vector4, ahead: Vector4, w: float, origin: Vector2, mid: Vector2) -> void:
	var cam: Camera4D = _frame.get("_camera") as Camera4D if _frame != null else null
	var vertical: float = deg_to_rad(77.3)
	if cam != null:
		vertical = cam.field_of_view_4d if cam.projection_type == Camera4D.PROJECTION4D_PERSPECTIVE_4D else cam.field_of_view_3d
	var view: Vector2 = get_viewport_rect().size
	var aspect: float = view.x / maxf(view.y, 1.0)
	var half: float = atan(tan(vertical * 0.5) * aspect) * view_cone_narrowing
	var forward := Vector2(ahead.x, ahead.z)
	if forward.length() < 0.001:
		return
	forward = forward.normalized()
	# A RED GRADIENT, NO LINES (Ramon, 29 Sept): strongest under you, gone at the far edge.
	# Drawn as rings of quads, each ring's colour its distance out, so the fade is even from
	# the point outward rather than stretched along the sides of one fan of triangles.
	var strong := Color(view_cone_color.r, view_cone_color.g, view_cone_color.b, view_cone_alpha)
	var gone := Color(view_cone_color.r, view_cone_color.g, view_cone_color.b, 0.0)
	var centre: Vector2 = _plan(here.x, here.z, w, origin, mid)
	var rings: int = 8
	var spokes: int = 12
	for r in rings:
		var near: float = float(r) / float(rings)
		var far: float = float(r + 1) / float(rings)
		var inner: Color = strong.lerp(gone, 1.0 - pow(1.0 - near, view_cone_falloff))
		var outer: Color = strong.lerp(gone, 1.0 - pow(1.0 - far, view_cone_falloff))
		for i in spokes:
			var a0: float = lerpf(-half, half, float(i) / float(spokes))
			var a1: float = lerpf(-half, half, float(i + 1) / float(spokes))
			var d0: Vector2 = forward.rotated(a0) * view_cone_length
			var d1: Vector2 = forward.rotated(a1) * view_cone_length
			var p00: Vector2 = centre if r == 0 else _plan(here.x + d0.x * near, here.z + d0.y * near, w, origin, mid)
			var p01: Vector2 = centre if r == 0 else _plan(here.x + d1.x * near, here.z + d1.y * near, w, origin, mid)
			var p10: Vector2 = _plan(here.x + d0.x * far, here.z + d0.y * far, w, origin, mid)
			var p11: Vector2 = _plan(here.x + d1.x * far, here.z + d1.y * far, w, origin, mid)
			if r == 0:
				draw_polygon(PackedVector2Array([centre, p10, p11]), PackedColorArray([inner, outer, outer]))
			else:
				draw_polygon(PackedVector2Array([p00, p10, p11, p01]), PackedColorArray([inner, outer, outer, inner]))


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
## depends on the character: Mithra is her red tunic (skin), while the keeper reads as
## purple, and his purple is the accent - his tunic is tan.
##
## So: skip whatever looks like flesh, and take the rest. A hue between 15 and 45 degrees
## at less than 60% saturation is a skin tone, and no character is identified by one.
## That picks Mithra's red (hue 358) over her accent (hue 27), and the keeper's purple
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


## The node standing in for the pen as the dial's middle, if one is in the tree.
func _local_anchor() -> Node4D:
	for node in get_tree().get_nodes_in_group(ANCHOR_GROUP):
		var n := node as Node4D
		if n != null and n.is_inside_tree():
			return n
	return null


## The landmarks, as [x, z, w, label, colour, tolerance, icon].
func _landmarks() -> Array:
	var out: Array = []
	for node in get_tree().get_nodes_in_group(LANDMARK_GROUP):
		var n := node as Node4D
		if n == null or not n.is_inside_tree():
			continue
		var at: Vector4 = n.global_position
		out.append([at.x, at.z, at.w, String(n.get_meta(&"dial_label", n.name)),
			n.get_meta(&"dial_color", Color(0.62, 0.82, 1.0, 0.95)),
			float(n.get_meta(&"dial_tolerance", home_tolerance)),
			String(n.get_meta(&"dial_icon", "arch"))])
	return out


## A landmark: drawn like a person - stem, rung, a ring once your slice goes through it -
## with an archway for the figure. Returns where it landed, for its name.
func _draw_landmark(x: float, z: float, w: float, tint: Color, tolerance: float, icon: String,
		shrink: float, plane_colour: Color, origin: Vector2, mid: Vector2, fade: float = 1.0) -> Vector2:
	var u: float = _ui()
	var foot: Vector2 = _plan(x, z, 0.0, origin, mid)
	var head: Vector2 = _plan(x, z, w, origin, mid)
	var true_w: float = _w_above(x, z)
	var on_slice: bool = false
	if not is_nan(true_w):
		var rung: Vector2 = _plan(x, z, true_w * shrink, origin, mid)
		draw_line(rung - Vector2(7.0 * u, 0.0), rung + Vector2(7.0 * u, 0.0),
			Color(plane_colour.r, plane_colour.g, plane_colour.b, 0.5), 1.0)
		on_slice = absf(true_w - w / maxf(shrink, 0.0001)) <= tolerance
	var colour: Color = tint
	colour.a *= fade
	draw_line(foot, head, Color(colour.r, colour.g, colour.b, 0.35), 1.0)
	draw_circle(foot, 2.0 * u, Color(colour.r, colour.g, colour.b, 0.4))
	var middle: Vector2
	if icon == "cube":
		middle = _cube_icon(head, colour, u * bird_size)
	elif icon == "anomaly":
		middle = _anomaly_icon(head, colour, u * bird_size)
	else:
		middle = _arch_icon(head, colour, u * bird_size)
	if on_slice:
		draw_arc(middle, 13.0 * u * bird_size, 0.0, TAU, 24, home_color, 2.0, true)
	return middle


## A cube standing on the point, drawn the way the dial draws everything: its top a
## diamond, its two near faces below it.
func _cube_icon(at: Vector2, colour: Color, u: float) -> Vector2:
	var s: float = 5.5 * u
	var top: Vector2 = at + Vector2(0.0, -2.0 * s)
	var diamond := PackedVector2Array([top + Vector2(0.0, -s * 0.5), top + Vector2(s, 0.0),
		top + Vector2(0.0, s * 0.5), top + Vector2(-s, 0.0)])
	var left := PackedVector2Array([diamond[3], diamond[2], diamond[2] + Vector2(0.0, 1.4 * s), diamond[3] + Vector2(0.0, 1.4 * s)])
	var right := PackedVector2Array([diamond[2], diamond[1], diamond[1] + Vector2(0.0, 1.4 * s), diamond[2] + Vector2(0.0, 1.4 * s)])
	draw_colored_polygon(left, Color(colour.r, colour.g, colour.b, colour.a * 0.55))
	draw_colored_polygon(right, Color(colour.r, colour.g, colour.b, colour.a * 0.8))
	draw_colored_polygon(diamond, colour)
	for face in [diamond, left, right]:
		draw_polyline(_closed(face), Color(1.0, 1.0, 1.0, 0.5 * colour.a), 1.0, true)
	return top + Vector2(0.0, 0.5 * s)


## Something the instruments cannot account for: a large dot that beats, and an exclamation
## mark beside it.
func _anomaly_icon(at: Vector2, colour: Color, u: float) -> Vector2:
	var beat: float = 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.006)
	var centre: Vector2 = at + Vector2(0.0, -6.0 * u)
	draw_circle(centre, (11.0 + 3.0 * beat) * u, Color(colour.r, colour.g, colour.b, colour.a * 0.25))
	draw_circle(centre, 7.5 * u, colour)
	draw_arc(centre, 7.5 * u, 0.0, TAU, 24, Color(1.0, 1.0, 1.0, 0.6 * colour.a), 1.4, true)
	# The mark, a stroke and a dot, to the dot's left so the name can go to its right.
	var mark: Vector2 = centre + Vector2(-16.0 * u, -2.0 * u)
	draw_line(mark + Vector2(0.0, -8.5 * u), mark + Vector2(0.0, 2.0 * u), colour, 3.0 * u)
	draw_circle(mark + Vector2(0.0, 6.0 * u), 1.8 * u, colour)
	return centre


## An archway standing on the point: two jambs and a round top, the opening filled faintly
## with its own colour, the way the real one is filled with light.
func _arch_icon(at: Vector2, colour: Color, u: float) -> Vector2:
	var half: float = 5.5 * u
	var jamb: float = 8.0 * u
	var outline := PackedVector2Array([at + Vector2(-half, 0.0), at + Vector2(-half, -jamb)])
	for i in 9:
		var a: float = PI + PI * float(i) / 8.0
		outline.append(at + Vector2(0.0, -jamb) + Vector2(cos(a), sin(a)) * half)
	outline.append(at + Vector2(half, 0.0))
	draw_colored_polygon(outline, Color(colour.r, colour.g, colour.b, colour.a * 0.45))
	draw_polyline(outline, colour, 1.8 * u, true)
	return at + Vector2(0.0, -jamb * 0.8)


## One person: a blob rather than a head, so they cannot be mistaken for livestock, with
## their name beside them and the same rung the birds get.
## Returns where the blob landed, so the name can be written in a later pass.
func _draw_person(x: float, z: float, w: float, tint: Color, is_cat: bool, shrink: float,
		plane_colour: Color, origin: Vector2, mid: Vector2, fade: float = 1.0) -> Vector2:
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
	colour.a *= fade
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
		plane_colour: Color, origin: Vector2, mid: Vector2, fade: float = 1.0) -> void:
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
	colour.a *= fade
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
## The people are not evenly spread - Mithra, the lofted girl and the cat all live in the
## same corner of the field - so their names landed on top of each other and the ones near
## the edge were clipped to nonsense. Each tag is nudged to the side of its blob that has
## more room, and pushed down if the line above is already taken.
## How far a landmark's name stands off the middle of its icon: past the icon's own edge
## (the anomaly's beating halo is the widest), and one space more (Ramon, 29 Sept: "the
## text is very close by the name of the object ... 1 space to the right").
func _icon_clearance(font: Font, icon: String) -> float:
	var u: float = _ui() * bird_size
	var reach: float = 14.0 * u if icon == "anomaly" else 5.5 * u
	return reach + font.get_string_size(" ", HORIZONTAL_ALIGNMENT_LEFT, -1, int(round(13.0 * _ui()))).x


func _name_tag(font: Font, who: String, at: Vector2, colour: Color, clear: float = 11.0) -> void:
	var letters: int = int(round(13.0 * _ui()))
	var width: float = font.get_string_size(who, HORIZONTAL_ALIGNMENT_LEFT, -1, letters).x
	var left: bool = at.x + clear + 1.0 + width > size.x - 6.0
	var spot := Vector2(at.x - clear - width if left else at.x + clear, at.y + 4.0)
	spot.x = clampf(spot.x, 6.0, maxf(6.0, size.x - width - 6.0))
	# Compared as RECTANGLES, not as centres. Comparing centres let a tag clamped to the
	# left edge sit under a longer one whose centre was far enough away to pass, which is
	# how "LoftedGirl" ended up written through "Mithra".
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
func _reading(heights: Array, worst: float, home: bool, away_from_pen: bool = false) -> String:
	if home:
		return "home - the flat slice" if away_from_pen else "home - the pen's own slice"
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


func _label(font: Font, text: String, at: Vector2, colour: Color, width: float = -1.0,
		letters: float = 17.0) -> void:
	# Centred across the dial when given a width. A round instrument has no left edge to
	# hang a caption off - at the panel's corner it would sit outside the circle entirely.
	draw_string(font, at, text,
		HORIZONTAL_ALIGNMENT_CENTER if width > 0.0 else HORIZONTAL_ALIGNMENT_LEFT,
		width, int(round(letters * _ui())), colour)


## What the camera rig has its way-back bound to, as a key name. Empty if there is no rig
## to ask, so a dial dropped into a scene without one simply does not offer the hint.
func _home_key() -> String:
	if _rig == null:
		return ""
	var code: int = int(_rig.get("home_key"))
	if code == 0:
		return ""
	return OS.get_keycode_string(code)
