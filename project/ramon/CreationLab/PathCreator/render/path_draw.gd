@tool
extends RefCounted

## PathCreator: the pieces the path network is drawn with, each a thin flat 4D box carrying the
## vector shader (path_mark.gdshader) in one of its modes. The symbol libraries are read and packed
## once (path_symbols.gd) and shared by every material; what a box shows is plain per-material
## uniforms (uniform ARRAYS are shared between materials in this engine, so none are used).
##
##   symbols()           the packed libraries: textures and {"07/A": id}
##   sym(lib, slot)      a symbol's id (-1 if that library has no such slot)
##   material(mode)      a new path material, its textures set
##   box(...)            a box mesh instance with a material, laid where asked
##
## NO class_name (engine_gotchas.md).

const Spec := preload("res://ramon/CreationLab/PathCreator/path_spec.gd")
const Symbols := preload("res://ramon/CreationLab/PathCreator/render/path_symbols.gd")
const MarkShader := preload("res://ramon/CreationLab/PathCreator/render/path_mark.gdshader")
## The sand has a shader of its own (6 Oct): it writes its depth, which the marks need not pay for.
const SandShader := preload("res://ramon/CreationLab/PathCreator/render/path_sand.gdshader")
const Mats := preload("res://ramon/CreationLab/LabKit/lab_materials.gd")

const SEGMENT := 0
const NODE := 1
const PIVOT := 2
const FRAME := 3
## The pen's sand under the marks: a soft-edged strip, or a round patch at a node (path_sand.gdshader).
const SAND := 4
## The pen's yard sand (chickenpen/grass/pen_grass_4d.gd sand_colour), which the paths' sand matches.
const YARD_SAND := Color(0.64, 0.47, 0.29)

static var _packed: Dictionary = {}


static func symbols() -> Dictionary:
	if _packed.is_empty():
		var libs: Dictionary = {}
		for lib in Symbols.libraries():
			libs[lib] = Symbols.read_library(lib)
		_packed = Symbols.build(libs)
	return _packed


## Forget the packed libraries (after an SVG changed on disk); the next symbols() reads them again.
static func reload() -> void:
	_packed = {}


static func sym(lib: String, slot: String) -> int:
	return int((symbols()["ids"] as Dictionary).get("%s/%s" % [lib, slot], -1))


## A symbol's size in sheet units.
static func sym_size(id: int) -> Vector2:
	var t: ImageTexture = symbols()["symbols"]
	if id < 0:
		return Vector2.ZERO
	var c: Color = t.get_image().get_pixel((id * 2) % Symbols.SYM_W, (id * 2) / Symbols.SYM_W)
	return Vector2(c.b, c.a) * 2.0


static func material(mode: int) -> TetraMaterial4D:
	var m := TetraMaterial4D.new()
	var cs: ShaderMaterial = m.get_cross_section_material_3d()
	if mode == SAND:
		cs.shader = SandShader
		m.albedo_color = YARD_SAND
		cs.set_shader_parameter("w_soft", Spec.W_SOFT)
		return m
	# The shader before anything else: Material4D only fills an empty slot with its own.
	cs.shader = MarkShader
	# The colour the projected half of the volume view (Combined, Projected) draws these boxes in;
	# the cross-section has its own shader and never reads it. White read as a missing texture,
	# the sheet's blue as a heavy band over the marks: sand, so a route reads there as one path.
	m.albedo_color = Spec.SAND
	var p: Dictionary = symbols()
	cs.set_shader_parameter("seg_tex", p["segments"])
	cs.set_shader_parameter("segcap_tex", p["segcaps"])
	cs.set_shader_parameter("shape_tex", p["shapes"])
	cs.set_shader_parameter("sym_tex", p["symbols"])
	cs.set_shader_parameter("mode", mode)
	cs.set_shader_parameter("unit_m", Spec.UNIT_M)
	cs.set_shader_parameter("col_blue", Spec.TOKENS["blue"])
	cs.set_shader_parameter("col_cyan", Spec.TOKENS["cyan"])
	cs.set_shader_parameter("col_edge", Spec.TOKENS["edge"])
	cs.set_shader_parameter("col_muted", Spec.TOKENS["muted"])
	cs.set_shader_parameter("col_guide", Spec.GUIDE_COLOR)
	cs.set_shader_parameter("sand", Spec.SAND)
	cs.set_shader_parameter("w_soft", Spec.W_SOFT)
	return m


static func set_param(mi: MeshInstance4D, key: String, v: Variant) -> void:
	((mi.material_override as TetraMaterial4D).get_cross_section_material_3d()).set_shader_parameter(key, v)


## A path box: `size` (x along, y thickness, z across, w its W depth), its middle at `at`, turned by
## `basis` (a W shear makes a box that climbs through W along its length).
static func box(parent: Node, nm: String, mode: int, size: Vector4, at: Vector4, basis: Projection = Projection.IDENTITY) -> MeshInstance4D:
	var mi := MeshInstance4D.new()
	mi.name = nm
	mi.mesh = Mats.box_mesh(size)
	mi.material_override = material(mode)
	mi.position = at
	mi.basis = basis
	set_param(mi, "box_size", size)
	set_param(mi, "w_half", size.w * 0.5)
	parent.add_child(mi)
	return mi
