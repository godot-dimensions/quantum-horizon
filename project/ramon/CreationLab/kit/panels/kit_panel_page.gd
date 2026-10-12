@tool
extends Control

## Kit: what both wall panels share, the shell (kit_panel_spec.gd; frame 01's "sibling panel
## containers and the shared header / main / supporting-row tracks"): the running header with its
## two labels and its rule, the lower rule, and the helpers that place an element on the template.
## kit_panel_intro.gd and kit_panel_research.gd extend it; kit_wall_panel_4d.gd hangs one on a wall.
##
## A page is a Control PANEL x k pixels big, every part a child node (kit_panel_elements.gd).
##   refresh(d)   shows what `d` says (the panel's data, see each page); cheap when nothing changed
##   tick(dt)     moves its animations on; true while something is still moving
##   overflowed() the names of texts that ran over their lines (rule 2: never shrunk, reported)
## `warn` draws a red frame round it: its wall is too short for it (kit_wall_panel_4d.gd).
##
## NO class_name (engine_gotchas.md).

const Spec := preload("res://ramon/CreationLab/kit/panels/kit_panel_spec.gd")
const E := preload("res://ramon/CreationLab/kit/panels/kit_panel_elements.gd")

var k: float = Spec.PPU
var warn: bool = false:
	set(v):
		if v != warn:
			warn = v
			queue_redraw()

var header_left: E.Text
var header_right: E.Text


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Builds the page at `px_per_unit`.
func setup(px_per_unit: float = Spec.PPU) -> void:
	k = px_per_unit
	for c in get_children():
		c.free()
	size = Spec.PANEL * k
	var head := group("Running header")
	header_left = text(head, "Section label", "label", "white", Vector2(0, Spec.HEADER_Y), 500.0)
	header_right = text(head, "Status", "label", "muted", Vector2(500, Spec.HEADER_Y), 300.0, 1, HORIZONTAL_ALIGNMENT_RIGHT)
	rule(head, "Shared horizontal rule", Vector2(0, Spec.HEADER_RULE_Y), Vector2(Spec.PANEL.x, 1))
	rule(self, "Lower rule", Vector2(0, Spec.LOWER_RULE_Y), Vector2(Spec.PANEL.x, 1))
	_build()


## The page's own parts (override).
func _build() -> void:
	pass


func refresh(_d: Dictionary) -> void:
	pass


func tick(_dt: float) -> bool:
	return false


func overflowed() -> Array:
	var out: Array = []
	_find_overflow(self, out)
	return out


func _find_overflow(n: Node, out: Array) -> void:
	for c in n.get_children():
		if c is E.Text and (c as E.Text).overflow:
			out.append(String(get_path_to(c)))
		_find_overflow(c, out)


# -- placing elements on the template (units) --------------------------------------------------------

## A plain container for a group of elements, at the page's origin.
func group(nm: String, parent: Node = null) -> Control:
	var g := Control.new()
	g.name = nm
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent != null else self).add_child(g)
	return g


func text(parent: Node, nm: String, role: String, token: String, pos: Vector2, width: float, lines: int = 1,
		align: int = HORIZONTAL_ALIGNMENT_LEFT) -> E.Text:
	var t := E.Text.new(nm, k).setup(role, token, lines, align)
	parent.add_child(t)
	t.place(pos, Vector2(width, Spec.line_of(role) * float(lines)))
	return t


func rule(parent: Node, nm: String, pos: Vector2, sz: Vector2, token: String = "rule") -> E.Rule:
	var r := E.Rule.new(nm, k)
	r.token = token
	parent.add_child(r)
	r.place(pos, sz)
	return r


func surface(parent: Node, nm: String, pos: Vector2, sz: Vector2, token: String = "surface", radius: float = Spec.CHART_RADIUS) -> E.Surface:
	var s := E.Surface.new(nm, k)
	s.token = token
	s.radius = radius
	parent.add_child(s)
	s.place(pos, sz)
	return s


## Brings a group's elements in one after another, `age` seconds after it began; `out` (0..1) fades
## the whole group as it leaves, `dy` units it has risen on its way out.
static func animate(g: Node, age: float, out: float = 1.0, dy: float = 0.0) -> void:
	for c in g.get_children():
		if not (c is E.El):
			continue
		var el: E.El = c
		if el.stagger < 0:
			el.modulate.a = out
			el.rise = dy
			continue
		var e: float = E.ease_out((age - 0.06 * float(el.stagger)) / 0.45)
		el.modulate.a = e * out
		el.rise = dy + 16.0 * (1.0 - e)


func _draw() -> void:
	if warn:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1.0, 0.25, 0.2), false, maxf(2.0, 3.0 * k))
