extends CanvasLayer

## The lab's drawing layer: one screen-space layer that draws, through the live camera, what the
## cross-section renderer cannot: lines, dots and loops that read as diagrams (the Lines view's
## bones and foot paths, slice markers, rulers). The renderer is opaque and cannot draw lines in
## 4D, so these are drawn in 2D at the points the camera projects them to (Camera4D.
## world_to_viewport), as theatre_pane_4d.gd and world_tag_4d.gd do.
##
## Anything that wants drawing joins the group "lab_overlay_drawer" and has
## `draw_overlay(canvas: Control, overlay: Node)`; inside, `overlay.to_screen(p)` gives a point's
## place on the canvas (or null behind the camera), and `overlay.slice_fade(p)` how far it is
## from the camera's slice (1 on it, fading to 0 by `slice_reach` metres along W).
##
## One per scene; `ensure(tree)` makes it if it is missing. NO class_name (engine_gotchas.md).

const LabMath := preload("res://ramon/LabKit/lab_math.gd")
const GROUP_DRAWER := "lab_overlay_drawer"
const GROUP := "lab_overlay"

## Metres off the camera's slice (along its W) at which a drawn point has faded out.
@export_range(0.05, 5.0, 0.05) var slice_reach: float = 0.9

var canvas: Control
var camera: Camera4D
## True while the autopilot films: the lectern cards and the lift's tag step aside for its captions.
var film: bool = false
var _scale: Vector2 = Vector2.ONE


static func ensure(tree: SceneTree) -> Node:
	var found: Node = tree.get_first_node_in_group(GROUP)
	if found != null:
		return found
	var o := CanvasLayer.new()
	o.set_script(load("res://ramon/LabKit/lab_overlay_4d.gd"))
	o.name = "LabOverlay"
	(tree.current_scene if tree.current_scene != null else tree.root).add_child(o)
	return o


func _enter_tree() -> void:
	add_to_group(GROUP)
	layer = 5


func _ready() -> void:
	canvas = Control.new()
	canvas.name = "Canvas"
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.draw.connect(_on_draw)
	add_child(canvas)


func _process(_delta: float) -> void:
	camera = LabMath.current_camera(get_tree())
	var vp: Viewport = canvas.get_viewport()
	var px: Vector2 = Vector2(vp.get_visible_rect().size)
	var win: Vector2 = Vector2(vp.size) if vp.size.x > 0 else px
	_scale = px / win if win.x > 0.0 else Vector2.ONE
	canvas.queue_redraw()


## Where a 4D point lands on the canvas, or null if it is behind the camera.
func to_screen(p: Vector4):
	if camera == null or camera.is_position_behind(p):
		return null
	return camera.world_to_viewport(p) * _scale


## A panel's rectangle moved clear of the HUD's panels (LabKit/lab_hud.gd `occupied_rects`).
## The HUD sits down the left edge with a gap between its guide and its controls card, so a
## panel first tries that gap (just below the panel it overlaps), and only moves to the right,
## over the world, when the gap is too small.
func clear_of_hud(r: Rect2) -> Rect2:
	var rects: Array = []
	for hud in get_tree().get_nodes_in_group("lab_hud"):
		if hud.has_method("occupied_rects"):
			rects.append_array(hud.call("occupied_rects"))
	var screen_h: float = canvas.get_viewport_rect().size.y
	var out: Rect2 = r
	for o in rects:
		var rect: Rect2 = o
		if not out.intersects(rect):
			continue
		var below := Rect2(Vector2(out.position.x, rect.end.y), out.size)
		var fits: bool = below.end.y < screen_h - 8.0
		for o2 in rects:
			if (o2 as Rect2) != rect and below.intersects(o2):
				fits = false
		if fits:
			out = below
		else:
			out.position.x = rect.end.x
	return out


## 1 on the camera's slice, falling to 0 at `slice_reach` metres off it along its W.
func slice_fade(p: Vector4) -> float:
	if camera == null:
		return 1.0
	var off: float = absf((p - camera.global_position).dot(camera.global_basis.w))
	return clampf(1.0 - off / slice_reach, 0.0, 1.0)


func _on_draw() -> void:
	if camera == null:
		return
	for d in get_tree().get_nodes_in_group(GROUP_DRAWER):
		if d.has_method("draw_overlay"):
			d.call("draw_overlay", canvas, self)
