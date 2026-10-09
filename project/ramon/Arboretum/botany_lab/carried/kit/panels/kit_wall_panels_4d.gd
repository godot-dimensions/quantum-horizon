@tool
extends Node4D

## Kit: a room's two wall panels as one thing. Point it at the introduction and the research panel
## (two kit_wall_panel_4d.gd nodes, each hung on its own wall or standing on its own) and it keeps
## them a pair (Ramon, 5 Oct: "maybe they can scale relative to a wall if needed, but both panels
## should always stay in alignment and scale together"):
##
##   one scale    both panels are always the same size. "kit size" is the kit's 9.6 x 5.9 m
##                (kit_panel_spec.gd); "fit walls" lets them grow or shrink to their walls, within
##                `min_scale`..`max_scale`, the tighter of the two walls deciding for both
##   one height   both feet at `foot`, so their running headers, lower rules and the line where the
##                controls and the benchmark start are level with each other across the room
##   one source   the room's words (`info`) and its live data (`source`) given to both
##
## It sets those on the two panels every time something changes (and checks twice a second, as a
## room's shape sliders can move a wall), so the panels' own `info`, `source` and `foot` are its.
##
## NO class_name (engine_gotchas.md).

const Spec := preload("res://ramon/Arboretum/botany_lab/carried/kit/panels/kit_panel_spec.gd")

## The introduction panel and the research panel.
@export var intro: NodePath:
	set(v):
		intro = v
		_later()
@export var research: NodePath:
	set(v):
		research = v
		_later()
## The room's words (kit_room_info.gd) for both.
@export var info: Resource:
	set(v):
		info = v
		_later()
## Their live data for both (a node with fill() and research()).
@export var source: NodePath:
	set(v):
		source = v
		_later()
## Both feet above the floor, metres.
@export var foot: float = Spec.FOOT_M:
	set(v):
		foot = v
		_later()
## "kit size": the kit's own size everywhere. "fit walls": as big as both walls allow.
@export_enum("kit size", "fit walls") var size_mode: String = "kit size":
	set(v):
		size_mode = v
		_later()
## When fitting: wall left either side of a panel, and above it, metres.
@export var fit_margin: Vector2 = Vector2(0.5, 0.6):
	set(v):
		fit_margin = v
		_later()
@export_range(0.25, 1.0, 0.01) var min_scale: float = 0.6:
	set(v):
		min_scale = v
		_later()
@export_range(1.0, 3.0, 0.01) var max_scale: float = 1.0:
	set(v):
		max_scale = v
		_later()

var scale_now: float = 1.0
var _queued: bool = false
var _check: float = 0.0


func _ready() -> void:
	apply()


func _later() -> void:
	if not is_inside_tree() or _queued:
		return
	_queued = true
	(func() -> void:
		_queued = false
		apply()).call_deferred()


func panels() -> Array:
	var out: Array = []
	for p in [intro, research]:
		var n: Node = get_node_or_null(p) if not (p as NodePath).is_empty() else null
		if n != null and n.has_method("fit_scale"):
			out.append(n)
	return out


## The scale both panels take now.
func pair_scale() -> float:
	if size_mode != "fit walls":
		return 1.0
	var s: float = max_scale
	for p in panels():
		s = minf(s, float(p.call("fit_scale", fit_margin, foot)))
	return clampf(s, min_scale, max_scale)


## Gives both panels the pair's scale, height, words and data.
func apply() -> void:
	scale_now = pair_scale()
	for p in panels():
		var src: NodePath = NodePath()
		if not source.is_empty() and get_node_or_null(source) != null:
			src = p.get_path_to(get_node(source))
		if p.get("info") != info:
			p.set("info", info)
		if p.get("source") != src:
			p.set("source", src)
		if not is_equal_approx(float(p.get("foot")), foot):
			p.set("foot", foot)
		p.call("set_scale_factor", scale_now)


func _process(delta: float) -> void:
	_check -= delta
	if _check > 0.0:
		return
	_check = 0.5
	if not is_equal_approx(pair_scale(), scale_now):
		apply()


func _get_configuration_warnings() -> PackedStringArray:
	var out := PackedStringArray()
	if panels().size() != 2:
		out.append("Point `intro` and `research` at the room's two wall panels (kit_wall_panel_4d.gd).")
	if info == null:
		out.append("Give it the room's words: a kit_room_info.gd resource in `info`.")
	return out
