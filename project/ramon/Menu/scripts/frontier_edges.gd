@tool
extends Control
class_name FrontierEdges

## The layer under the nodes: the guided route, the category drop ticks and the
## faint band separators.
##
## ONE Control drawing every edge, rather than a Line2D per connector. Nine
## curves as nine nodes would each need their own transform, width curve and
## z-order kept in sync with the node layer; here they are nine polylines in one
## `_draw()`, and moving a node only means recomputing points.
##
## `mouse_filter` is IGNORE so this never eats a click meant for a node sitting
## on top of it - the brief calls this out explicitly, and it is the usual way an
## invisible full-rect overlay silently breaks a UI.
##
## THE CURVE IS RHYTHM, NOT LOGIC. Every edge joins two prototypes that are
## ADJACENT IN THE CATALOGUE, and nothing else. There is no branching, no
## dependency, and no meaning in a curve's height beyond keeping ten circles off
## a single boring horizontal. That claim is printed under the map as well,
## because a reader who assumes the shape encodes dependencies will misread the
## whole screen.

## {from: Vector2, to: Vector2, color: Color, dashed: bool}
var _edges: Array[Dictionary] = []
## {x: float, from_y: float, to_y: float, color: Color}
var _drops: Array[Dictionary] = []
## {x: float, from_y: float, to_y: float}
var _separators: Array[float] = []
var _separator_span: Vector2 = Vector2.ZERO

var style: FrontierStyle = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_geometry(edges: Array[Dictionary], drops: Array[Dictionary],
		separators: Array[float], separator_span: Vector2) -> void:
	_edges = edges
	_drops = drops
	_separators = separators
	_separator_span = separator_span
	queue_redraw()


## Just the route, for the per-frame refresh while nodes are springing back from
## a poke. The ticks and separators never move, so re-sending them every frame
## would be pure waste.
func set_edges(edges: Array[Dictionary]) -> void:
	_edges = edges
	queue_redraw()


func _draw() -> void:
	if style == null:
		return

	for x in _separators:
		_draw_dashed_line(Vector2(x, _separator_span.x), Vector2(x, _separator_span.y),
			style.separator, 1.3, 3.0, 8.0)

	for drop in _drops:
		var x: float = float(drop["x"])
		var color: Color = drop["color"]
		# The tick is dotted and stops in a solid dot, so it reads as "this
		# heading covers what is below" without drawing a line all the way into
		# the nodes and implying a connection to one of them.
		_draw_dashed_line(Vector2(x, float(drop["from_y"])), Vector2(x, float(drop["to_y"])),
			Color(color, 0.55), 1.5, 2.0, 7.0)
		draw_circle(Vector2(x, float(drop["to_y"])), 5.0, Color(color, 0.7))

	for edge in _edges:
		var points: PackedVector2Array = _curve_points(edge["from"], edge["to"],
			float(edge.get("curvature", -1.0)),
			float(edge.get("from_radius", style.node_radius)),
			float(edge.get("to_radius", style.node_radius)))
		var color: Color = edge["color"]
		if bool(edge["dashed"]):
			_draw_dashed_polyline(points, color, style.edge_width)
		else:
			draw_polyline(points, color, style.edge_width, true)


## A cubic bezier whose control points reach HORIZONTALLY out of each end.
##
## Horizontal departure is what gives the reference art its look: every curve
## leaves a node sideways and arrives sideways, so the route reads as one
## continuous ribbon threading through the field rather than as a set of
## straight hops with corners. `edge_curvature` is the single knob.
func _curve_points(from: Vector2, to: Vector2, curvature: float = -1.0,
		from_radius: float = -1.0, to_radius: float = -1.0) -> PackedVector2Array:
	var along: Vector2 = (to - from).normalized()
	# Trimmed by each END'S OWN radius. Sub-maps mix node sizes - a gate node is
	# half again the size of a step - and one shared radius left the line either
	# buried under the big circle or floating away from the small one.
	var start_trim: float = (style.node_radius if from_radius < 0.0 else from_radius) + style.edge_gap
	var end_trim: float = (style.node_radius if to_radius < 0.0 else to_radius) + style.edge_gap
	var p0: Vector2 = from + along * start_trim
	var p3: Vector2 = to - along * end_trim
	var bend: float = style.edge_curvature if curvature < 0.0 else curvature
	var reach: float = (p3.x - p0.x) * bend
	var p1 := Vector2(p0.x + reach, p0.y)
	var p2 := Vector2(p3.x - reach, p3.y)

	var points := PackedVector2Array()
	for i in style.edge_segments + 1:
		var t: float = float(i) / float(style.edge_segments)
		points.append(_cubic(p0, p1, p2, p3, t))
	return points


func _cubic(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var u: float = 1.0 - t
	return p0 * (u * u * u) + p1 * (3.0 * u * u * t) + p2 * (3.0 * u * t * t) + p3 * (t * t * t)


func _draw_dashed_polyline(points: PackedVector2Array, color: Color, width: float) -> void:
	# Walked as segments rather than handed to draw_dashed_line, which would
	# restart its dash pattern on every segment and produce visible clumping
	# where the curve is tightest.
	var carried: float = 0.0
	var on: bool = true
	var dash: float = 7.0
	for i in points.size() - 1:
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		var length: float = a.distance_to(b)
		var travelled: float = 0.0
		while travelled < length:
			var remaining: float = dash - carried
			var step: float = minf(remaining, length - travelled)
			if on:
				draw_line(a.lerp(b, travelled / length), a.lerp(b, (travelled + step) / length),
					color, width, true)
			travelled += step
			carried += step
			if carried >= dash:
				carried = 0.0
				on = not on


func _draw_dashed_line(from: Vector2, to: Vector2, color: Color, width: float,
		dash: float, gap: float) -> void:
	var total: float = from.distance_to(to)
	if total <= 0.0:
		return
	var direction: Vector2 = (to - from) / total
	var at: float = 0.0
	while at < total:
		var end: float = minf(at + dash, total)
		draw_line(from + direction * at, from + direction * end, color, width, true)
		at = end + gap
