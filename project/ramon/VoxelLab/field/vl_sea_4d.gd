extends "res://ramon/WaterLab/carried/water4d/water4d_surface.gd"

## The open world's sea: the Water Lab's water (its script, shader, presets and foam, used from there and
## never copied), with three things the Voxel Lab needs on top. The Water Lab's own files stay as they
## are (another window works in them); everything here is done from this side.
##
## ONE GRADED SEA, NOT A SQUARE AND A RING (round 5, #46: "a large square region around the islands
## contains the detailed water ... beyond that square, the sea suddenly changes appearance"). The
## water builds a 120 m grid of 0.63 m squares round the camera, then a far ring of squares ten to
## twenty-five times bigger from its edge out, while the waves are still at full height there: the
## coarse ring cannot carry them, nor the fine ripple, so the change of mesh showed as a square. Seen
## from the deck, 20 m up, that edge sits in plain view; from the Water Lab's harbour, 7 m up, it lies
## nearly on the horizon. Here the grid is one mesh: the even squares out to `extent`, then every ring
## of squares GROWTH wider than the one inside it, out to `reach` (_build_grid; the far ring is never
## made). Nothing jumps, so nothing draws a line.
##
## THE FINE RIPPLE FADES BEFORE THE SQUARES OUTGROW IT. The detail noise is 4.5 m and 1.5 m across; on
## squares a few metres wide it becomes random tilts. The shader is patched as it loads (_patch) so
## the ripple goes between `extent` and 2.5 times it, where the squares are still small.
##
## THE SHORE FOAM (#48: "too strong ... an exaggerated bright outline"). The water whitens wherever the
## ground is less than intersection_foam_depth under it, at a fixed 0.9, everywhere along every coast,
## and past 65 m its bubbles stop and it is flat white. Patched in: `shore_foam` its strength,
## `shore_breakup` how much of it only shows where a crest comes in (0 a steady band, 1 only on the
## crests), the strength falling to a third by `shore_far` metres, and `shore_width` the depth it
## reaches (the shader's own intersection_foam_depth). All four on Tab (vl_sea_panel.gd).
##
## If the Water Lab's shader changes so a patch no longer finds its line, the sea keeps the plain
## shader (with its square detail and full foam) and says so once in the log.
##
## NO class_name (engine_gotchas.md).

## How far the sea reaches (m from the camera, each way).
var reach: float = 900.0
## Each ring of squares past `extent` this much wider than the one inside it.
const GROWTH := 1.045

var shore_foam: float = 0.4
var shore_breakup: float = 0.65
var shore_width: float = 0.4
var shore_far: float = 160.0
## How far down you see into it, m (the shader's max_path_metres, 40 in the Aquatic Lab). The island's
## seabed lies 18 m under the surface where the land is built and nowhere past it, so through 40 m of clear
## water the built square showed lighter than the open sea round it, seen from the air. At 10 the deep
## colour is reached over the seabed too; the shallows by the coast still show.
var see_depth: float = 10.0

static var _patched: Shader = null
static var _patch_failed: bool = false


func _ready() -> void:
	# No far ring: the one mesh reaches all the way (_build_grid).
	far_extent = 0.0
	super._ready()
	_material.shader = patched_shader()


func _on_pre_render(camera: Camera4D, viewport: Viewport, engine: RenderingEngine4D) -> void:
	super._on_pre_render(camera, viewport, engine)
	if _material == null or _patch_failed:
		return
	_material.set_shader_parameter(&"shore_foam", shore_foam)
	_material.set_shader_parameter(&"shore_breakup", shore_breakup)
	_material.set_shader_parameter(&"shore_far", shore_far)
	_material.set_shader_parameter(&"intersection_foam_depth", shore_width)
	_material.set_shader_parameter(&"max_path_metres", see_depth)


## The grid: lines every extent / (GRID_RESOLUTION / 2) metres out to `extent`, then each gap GROWTH
## times the last out to `reach`, the same both ways and on both axes.
func _build_grid() -> ArrayMesh:
	var half: int = GRID_RESOLUTION >> 1
	var step: float = extent / float(half)
	var line: Array = []
	for k in half + 1:
		line.append(step * float(k))
	var gap: float = step
	while float(line[-1]) < reach:
		gap *= GROWTH
		line.append(minf(float(line[-1]) + gap, reach))
	var coords: Array = []
	for k in range(line.size() - 1, 0, -1):
		coords.append(-float(line[k]))
	coords.append_array(line)
	var n: int = coords.size()
	var verts := PackedVector3Array()
	verts.resize(n * n)
	for j in n:
		for i in n:
			verts[j * n + i] = Vector3(float(coords[i]), 0.0, float(coords[j]))
	var indices := PackedInt32Array()
	indices.resize((n - 1) * (n - 1) * 6)
	var at: int = 0
	for j in n - 1:
		for i in n - 1:
			var a: int = j * n + i
			indices[at] = a
			indices[at + 1] = a + n
			indices[at + 2] = a + 1
			indices[at + 3] = a + 1
			indices[at + 4] = a + n
			indices[at + 5] = a + n + 1
			at += 6
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.custom_aabb = AABB(Vector3(-5000, -5000, -5000), Vector3(10000, 10000, 10000))
	return mesh


## The Water Lab's shader with the ripple fade and the shore foam controls written in, made once.
static func patched_shader() -> Shader:
	if _patched != null:
		return _patched
	var code: String = SHADER.code
	var patches: Array = [
		["uniform float intersection_foam_depth = 0.55;",
			"uniform float intersection_foam_depth = 0.55;\n// VOXEL LAB (vl_sea_4d.gd): the shore foam's strength, how much of it only the crests bring, and\n// where it has fallen to a third.\nuniform float shore_foam = 0.9;\nuniform float shore_breakup = 0.0;\nuniform float shore_far = 160.0;"],
		["\tfloat detail = detail_field(rest, detail_gradient);",
			"\tfloat detail = detail_field(rest, detail_gradient);\n\t// VOXEL LAB: the ripple goes before the graded squares outgrow it.\n\tfloat detail_k = 1.0 - smoothstep(near_extent, near_extent * 2.5, length(VERTEX.xz));\n\tdetail *= detail_k;\n\tdetail_gradient *= detail_k;"],
		["float foam = clamp(max(pinch * foam_opacity, edge * 0.9), 0.0, 1.0);",
			"float shore_k = mix(1.0, smoothstep(-0.1, 0.35, crest_height + surface_detail * 2.0), shore_breakup);\n\t\tshore_k *= mix(1.0, 0.33, smoothstep(shore_far * 0.4, shore_far, length(VERTEX)));\n\t\tfloat foam = clamp(max(pinch * foam_opacity, edge * shore_foam * shore_k), 0.0, 1.0);"],
	]
	for p in patches:
		if code.find(String(p[0])) < 0:
			push_warning("vl_sea_4d: the Water Lab's water4d.gdshader changed, a patch no longer fits: %s" % String(p[0]).strip_edges())
			_patch_failed = true
			_patched = SHADER
			return _patched
		code = code.replace(String(p[0]), String(p[1]))
	var sh := Shader.new()
	sh.code = code
	_patched = sh
	return _patched
