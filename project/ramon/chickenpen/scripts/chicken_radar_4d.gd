extends Control

## The Shooting Range's slice radar, pointed at chickens (items 50, 52, 65).
##
## THIS IS THE INSTRUMENT THE BRIEF ASKED FOR. Items 50 and 52 say to inspect the Range
## and reuse its target-location logic AND its UI language. The locator readout reused the
## logic - `bearing_utility_4d.gd`, the same file the Range's radar reads - but described
## the answer in words instead of drawing it, which is only half of what was asked and the
## less legible half: "nearby, to your right, it is ana of you" is a sentence you parse,
## where the radar is a picture you glance at.
##
## WHY IT IS REBUILT RATHER THAN INSTANCED. `project/scripts/slice_radar.gd` is the real
## thing and instancing it would have been the correct move, but it is welded to the
## gallery's scene - it reaches for `$"../../FlatPlane/Player"`, a target spawner, a duck
## spawner and a contest player by path, and tracks ducks and targets specifically. It is
## also shared with a scene CLAUDE.md puts out of bounds, so widening it is not mine to do.
## What is reused is the thing that actually matters: the same bearing utility, the same
## oblique projection, the same stem-for-W convention, the same exponential distance
## mapping. A player who has used one can read the other.
##
## HOW TO READ IT. The ellipse is the slice you are standing in, seen from above and
## tilted. You are the dot at its centre. Every loose chicken is a grey dot projected onto
## that plane - where it is, ignoring W - with a stem rising or falling to a coloured dot
## at its true position off the plane. A chicken with no stem is in your slice and can be
## picked up. A long stem is a chicken you would walk straight through.
##
## The ellipse never rotates with your slice-rotation. It is the fixed reference the world
## is described against, exactly as the Range draws it.
##
## TWO THINGS COPIED FROM THE RANGE HAD TO BE UNCOPIED, and both were silent - the dial
## looked right and answered wrong, which is worse than a dial that is obviously broken.
##
## FORWARD IS UP, so screen Y is the NEGATIVE of the frame's z. The Range maps +Z to
## screen-down and is correct to, because its player faces -Z - the ordinary Godot
## looking_at convention. Nothing in this scene uses it: every figure here is posed with
## Basis4D.from_zx(facing), so +Z is forward. Copying the projection without copying the
## convention drew everything ahead of you at the BOTTOM of the dial, and the radar sent
## you away from chickens as reliably as it sent you towards them.
##
## WHICH WAY IS WHICH IS LABELLED. The Range draws labelled axes; this did not, and an
## unlabelled dial of identical dots is four guesses about its orientation rather than one
## glance. Only "ahead" and "behind" are marked, because left and right were never in
## doubt.
##
## THE PEN IS ON IT TOO. Half of what you do here is carry a bird back, and an instrument
## that plots the chickens but not the place they go answers only the first half of the
## question.

const BearingUtility4D = preload("res://scripts/bearing_utility_4d.gd")

## The Range's own constants, kept identical so the two instruments read alike.
const ELLIPSE_SEGMENTS: int = 96
## Distance at which an object sits halfway to the rim. The rim is infinity, so nothing
## ever falls off the edge and a distant chicken still has a bearing you can follow.
##
## THIS WAS CHANGED AND CHANGED BACK. A fixed 30m rim with a gentler curve looked like the
## obvious fix for a dial that "does not budge", and measured against one chicken being
## walked in on it was WORSE: 3m to 20m spans 0.23-0.82 of the radius here against
## 0.19-0.71 there, and that band is where the game is played. What did not budge was the
## MEAN over twelve chickens scattered all round you, which closes on one side as it opens
## on the other and would not budge under any mapping. The scale was never the fault.
const HALFWAY_METERS: float = 8.0
const NAT_LOG_2: float = 0.6931471805599453094
const W_IS_UP: bool = false

@export var player_path: NodePath
@export var manager_path: NodePath
@export var locator_path: NodePath
## Whose basis defines the slice being drawn - the camera rig here, not the body. See the
## same note on chicken_locator_4d.gd: the rig carries the slice rotation, so reading the
## body left this dial completely static while the player rotated their slice.
@export var slice_frame_path: NodePath

@export_group("Shape")
@export var ellipse_squash_factor: float = 0.55
@export var ellipse_line_color: Color = Color(1.0, 1.0, 1.0, 0.5)
## Darker than the Range's. That dial sits over an indoor gallery; this one sits over a
## sunlit field, and at the Range's alpha the whole instrument washed out.
@export var ellipse_fill_color: Color = Color(0.0, 0.0, 0.0, 0.5)
@export var ring_count: int = 3

@export_group("Markers")
@export var player_marker_radius: float = 6.0
@export var player_marker_color: Color = Color(1.0, 1.0, 1.0, 0.95)
## Where the chicken is on your plane, ignoring W.
@export var projected_point_radius: float = 4.0
@export var projected_point_color: Color = Color(0.65, 0.65, 0.65, 0.85)
## And where it actually is, off the plane.
@export var off_plane_dot_radius: float = 6.0
@export var chicken_color: Color = Color(0.95, 0.95, 0.92, 0.95)
## The one the locator is pointing at, ringed so "which is nearest" survives a crowd.
@export var target_color: Color = Color(1.0, 0.85, 0.25, 0.95)
@export var stem_alpha: float = 0.55
@export var toggle_key: Key = KEY_M

@export_group("The pen")
## Where the chickens go. Plotted like everything else, so "carry it home" is a bearing
## you can follow rather than a landmark you have to have memorised.
@export var pen_path: NodePath
@export var pen_color: Color = Color(0.45, 0.9, 0.5, 0.95)

var _player: Node4D
var _manager: Node
var _locator: Node
var _frame: Node4D
var _pen: Node4D
var _pulse: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_player = get_node_or_null(player_path) as Node4D
	_manager = get_node_or_null(manager_path)
	_locator = get_node_or_null(locator_path)
	_frame = get_node_or_null(slice_frame_path) as Node4D
	_pen = get_node_or_null(pen_path) as Node4D
	if _player == null or _manager == null:
		push_warning("ChickenRadar: player or manager missing, so the radar has nothing to plot (item 82).")


func _process(delta: float) -> void:
	_pulse += delta
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and (event as InputEventKey).keycode == toggle_key:
		visible = not visible
		get_viewport().set_input_as_handled()


func _draw() -> void:
	if _player == null or _manager == null:
		return
	var centre: Vector2 = size * 0.5
	var radii := Vector2(centre.x * 0.9, centre.x * 0.9 * ellipse_squash_factor)
	centre.y = size.y * 0.5

	_draw_plane(centre, radii)
	# Labelled, because an unexplained dial is a decoration. One line, above the rim.
	var font: Font = ThemeDB.fallback_font
	draw_string(font, Vector2(centre.x - radii.x, centre.y - radii.y - 10.0),
		"your slice - stems show what is off it", HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
		Color(1.0, 1.0, 1.0, 0.85))
	draw_circle(centre, player_marker_radius, player_marker_color)
	# WHICH WAY IS WHICH. The Range labels its axes; this did not, and an unlabelled dial
	# is four guesses. Just the two that are easy to get wrong.
	var faint := Color(1.0, 1.0, 1.0, 0.8)
	draw_string(font, Vector2(centre.x - 18.0, centre.y - radii.y + 22.0), "ahead",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, faint)
	draw_string(font, Vector2(centre.x - 20.0, centre.y + radii.y - 4.0), "behind",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, faint)

	var target: Node = _locator.get("target") if _locator != null else null
	# The player's own frame, so "right" and "ahead" on the dial mean right and ahead to
	# the character - read from the BODY, which is what bearing_utility_4d exists to insist
	# on: the head carries pitch and would tilt the whole dial with a glance upward.
	var frame: Projection = (_frame.global_basis if _frame != null else _player.global_basis).inverse()

	# EVERYTHING IS GATHERED BEFORE ANYTHING IS DRAWN, because the scale depends on the
	# furthest of them and a dot cannot be placed until the scale is known.
	var plots: Array = []
	for agent in (_manager.get("agents") as Array):
		if not bool(agent.call("can_be_caught")):
			continue
		var body: Node4D = agent.get_parent() as Node4D
		if body == null:
			continue
		plots.append([frame * (body.global_position - _player.global_position),
			agent == target, false])
	if _pen != null:
		plots.append([frame * (_pen.global_position - _player.global_position), false, true])

	for plot in plots:
		_draw_chicken(plot[0], centre, radii, plot[1], plot[2])


## The slice you are in: a squashed disc with range rings.
func _draw_plane(centre: Vector2, radii: Vector2) -> void:
	var outline := PackedVector2Array()
	for i in ELLIPSE_SEGMENTS:
		var angle: float = TAU * float(i) / float(ELLIPSE_SEGMENTS)
		outline.append(centre + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(outline, ellipse_fill_color)
	for ring in range(1, ring_count):
		var scale: float = float(ring) / float(ring_count)
		var inner := PackedVector2Array()
		for i in ELLIPSE_SEGMENTS:
			var angle: float = TAU * float(i) / float(ELLIPSE_SEGMENTS)
			inner.append(centre + Vector2(cos(angle) * radii.x * scale, sin(angle) * radii.y * scale))
		inner.append(inner[0])
		draw_polyline(inner, Color(ellipse_line_color, ellipse_line_color.a * 0.35), 1.0, true)
	outline.append(outline[0])
	draw_polyline(outline, ellipse_line_color, 2.0, true)


## One thing on the dial: a point on your plane, and a stem to where it really is.
##
## The distance mapping is exponential, so the rim stands for infinity: a chicken forty
## units away still has a readable bearing rather than being clipped off the dial.
func _draw_chicken(relative: Vector4, centre: Vector2, radii: Vector2, is_target: bool,
		is_pen: bool = false) -> void:
	var span: float = relative.length()
	if span < 0.0001:
		return
	var squashed: float = 1.0 - exp(-span * (NAT_LOG_2 / HALFWAY_METERS))
	var scaled: Vector4 = relative * (squashed / span)

	# NEGATED. Forward is +Z in this scene, and screen Y grows downward, so without the
	# minus everything ahead of you draws at the bottom of the dial.
	var projected: Vector2 = centre + Vector2(scaled.x * radii.x, -scaled.z * radii.y)
	var through_w: float = -scaled.w if W_IS_UP else scaled.w
	var tip: Vector2 = projected + Vector2(0.0, through_w * radii.y)

	if is_pen:
		# A house, not a dot. It is the one thing on the dial that is not a chicken, and
		# it has to be findable at a glance while you are carrying one.
		draw_line(projected, tip, Color(pen_color.r, pen_color.g, pen_color.b, stem_alpha), 2.0)
		_draw_home(tip)
		return

	draw_circle(projected, projected_point_radius, projected_point_color)
	var colour: Color = target_color if is_target else chicken_color
	draw_line(projected, tip, Color(colour.r, colour.g, colour.b, stem_alpha), 2.0)
	draw_circle(tip, off_plane_dot_radius, colour)

	if is_target:
		# The one the locator is talking about, so the words and the picture agree.
		var pulse: float = (sin(_pulse * 4.0) + 1.0) * 0.5
		draw_arc(tip, off_plane_dot_radius + 4.0 + pulse * 3.0, 0.0, TAU, 24, target_color, 2.0, true)


## A little gabled house for the pen.
func _draw_home(at: Vector2) -> void:
	var w: float = 7.0
	var body := PackedVector2Array([
		at + Vector2(-w, w * 0.9), at + Vector2(w, w * 0.9),
		at + Vector2(w, -w * 0.1), at + Vector2(-w, -w * 0.1)])
	draw_colored_polygon(body, pen_color)
	draw_colored_polygon(PackedVector2Array([
		at + Vector2(-w * 1.25, -w * 0.1), at + Vector2(w * 1.25, -w * 0.1),
		at + Vector2(0.0, -w * 1.1)]), pen_color)
