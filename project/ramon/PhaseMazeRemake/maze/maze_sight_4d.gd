extends Node

## 4D sight, G (PLAN.md steps 61 to 66): the Combined renderer, which draws the slice as usual plus a
## faint projection of what lies ana and kata of it, with only the cells beside yours along the hidden
## axis allowed into that projection, and of them only the walls that stand across what you see.
##
## WHY SO FEW. Everything allowed to project is drawn, faded by its distance in W, over the whole view.
## A whole layer's walls would be a fog; your own walls coincide with themselves; and the walls between
## you and the next cell (the ones across your hidden axis) project as a box filling the cell. What is
## useful is what the next step would show you: the walls you would see there.
##
## THE COLOUR. Each wall's material albedo is the ghost colour (maze_builder_4d.gd): the slice shows the
## wall in its own grid colours and the projection shows it cyan. The camera's hue-shift fade would have
## done this, but the engine reads it only in the wireframe renderer (RESEARCH.md section 5).
##
## The renderer switch needs the root's World3D first: a Cross-section scene followed by a Combined one in
## one run crashes the engine otherwise (the 30 Sept engine bug; Crosswise does the same).
##
## NO class_name (engine_gotchas.md).

const Lattice := preload("res://ramon/PhaseMazeRemake/maze/maze_lattice.gd")
const Style := preload("res://ramon/PhaseMazeRemake/maze/maze_style.gd")

var camera: Camera4D
var body: Node4D
## The maze view (maze_view_4d.gd): which axis is hidden.
var view: Node
var lattice: RefCounted
## What the builder returned for this level ({"cell_walls", "walls", "beacon", ...}).
var built: Dictionary = {}
var on: bool = false
## The projection's strength (Camera4D.projection_opacity_base: lower is stronger).
var strength: float = 0.3
## The renderer F1 asks for: "Cross-section", "Combined", "Projected" or "Wireframe Canvas".
var renderer: String = "Cross-section"

var _key: Vector4i = Vector4i(-99, -99, -99, -1)


func set_on(v: bool) -> void:
	on = v
	_apply_renderer()
	_key = Vector4i(-99, -99, -99, -1)
	refresh()


func set_renderer(r: String) -> void:
	renderer = r
	_apply_renderer()
	_colour_walls()
	_key = Vector4i(-99, -99, -99, -1)
	refresh()


func set_level(lv: RefCounted, b: Dictionary) -> void:
	lattice = lv
	built = b
	_colour_walls()
	_key = Vector4i(-99, -99, -99, -1)
	refresh()


## The walls' albedo: the ghost cyan, which only the projection uses, except in the R&D renderers
## (Projected, Wireframe), which draw the whole maze through the projection: there each wall keeps its
## own colour, or everything would be cyan.
func _colour_walls() -> void:
	if built.is_empty():
		return
	var whole: bool = renderer == "Projected" or renderer == "Wireframe Canvas"
	for w in built["walls"]:
		var m: TetraMaterial4D = (w["mesh"] as MeshInstance4D).material_override
		if whole:
			m.albedo_color = Style.SWATCHES["maze_wall_w" if int(w["axis"]) == 2 else "maze_wall"][0]
		else:
			m.albedo_color = Style.role("ghost")


func _apply_renderer() -> void:
	var r: String = renderer
	if on and r == "Cross-section":
		r = "Combined"
	if r != "Cross-section" and get_tree().root.world_3d == null:
		get_tree().root.world_3d = World3D.new()
	camera.set("rendering_engine_name", r)
	camera.set("projection_opacity_base", strength)


func _process(_d: float) -> void:
	if lattice == null or body == null:
		return
	var c: Vector3i = lattice.cell_at(body.global_position)
	var h: int = int(view.get("hidden_axis")) if view != null else 2
	var key := Vector4i(c.x, c.y, c.z, h)
	if key != _key:
		_key = key
		refresh()


## Who may project, now: nothing with sight off; the next cells' walls across your view with it on; all
## of them for the R&D renderers (Projected and Wireframe show the whole maze).
func refresh() -> void:
	if built.is_empty():
		return
	var all: bool = renderer == "Projected" or renderer == "Wireframe Canvas"
	var allowed: Dictionary = {}
	if on and not all and lattice != null and body != null:
		var c: Vector3i = lattice.cell_at(body.global_position)
		var h: int = int(view.get("hidden_axis")) if view != null else 2
		var mine: int = c[h]
		for w in built["walls"]:
			if int(w["axis"]) == h:
				continue
			var at: int = (w["cells"][0] as Vector3i)[h]
			if absi(at - mine) == 1:
				allowed[w["mesh"]] = true
	for w in built["walls"]:
		var mi: MeshInstance4D = w["mesh"]
		mi.set("allow_projection", all or allowed.has(mi))
