@tool
extends RefCounted

## The Arboretum's specimen colours and the material every tree wears (shaders/botany_bark.gdshader),
## in one place, so the four methods stay comparable: the same bark, the same greens, only the
## construction differs. The room's own look (walls, floor, panels) is the carried kit's
## (carried/kit/kit_style.gd); this is only the trees.
##
## Sap green (#507D2A) is the leaves' main colour, as in the pen's meadow (Ramon, 2 Oct: "sapgreen
## as main"), with a lighter, warmer offset for the second clump colour.
##
## NO class_name (engine_gotchas.md): preload it.

const BarkShader := preload("res://ramon/Arboretum/shaders/botany_bark.gdshader")
const Pivots := preload("res://ramon/Arboretum/botany/tree_pivots.gd")

const BARK := Color(0.45, 0.39, 0.33)
const BARK_ROOT := Color(0.27, 0.23, 0.20)
const OAK_BARK := Color(0.40, 0.36, 0.31)
const OAK_ROOT := Color(0.22, 0.19, 0.17)
const LEAF := Color("#507D2A")
const LEAF_ALT := Color("#6a8f2f")
const GOLD := Color(1.0, 0.78, 0.30)

## The materials a tree mesh's texture coordinates name (tree_pivots.gd uvw()).
const WOOD := 1
const LEAVES := 2
const SKELETON := 3
const BALL := 4

## The four methods: code, name, short name, the pedestal it stands on.
const METHODS := [
	{"key": "voxel", "code": "VX-01", "name": "Voxels", "short": "VOXELS", "pedestal": "box"},
	{"key": "dc", "code": "DC-02", "name": "Smooth voxels", "short": "SMOOTH", "pedestal": "round"},
	{"key": "loft", "code": "LF-03", "name": "Lofted", "short": "LOFTED", "pedestal": "round"},
	{"key": "oak", "code": "OK-04", "name": "The oak", "short": "OAK", "pedestal": "round"},
]


## A tree's material: the bark shader with the tree's own branches for the wind. `height` sets how
## far up the bark's darkening runs.
## `pivots`: the skeleton's pivot texture when the caller already has it (the grove shares one per
## shape across its trees).
static func tree_material(sk: Resource, height: float, oak: bool = false, pivots: Texture2D = null) -> TetraMaterial4D:
	var m := TetraMaterial4D.new()
	var cs: ShaderMaterial = m.get_cross_section_material_3d()
	# The shader before anything else: Material4D only fills an empty slot with its own.
	cs.shader = BarkShader
	m.albedo_color = Color.WHITE
	cs.set_shader_parameter("bark_color", OAK_BARK if oak else BARK)
	cs.set_shader_parameter("bark_root", OAK_ROOT if oak else BARK_ROOT)
	cs.set_shader_parameter("leaf_color", LEAF)
	cs.set_shader_parameter("leaf_alt", LEAF_ALT)
	cs.set_shader_parameter("gold_color", GOLD)
	cs.set_shader_parameter("tree_height", height)
	if sk != null:
		cs.set_shader_parameter("pivot_tex", pivots if pivots != null else Pivots.texture(sk))
		cs.set_shader_parameter("pivot_count", (sk.get("branches") as Array).size())
	return m


## The shader material inside a tree material, where the wind writes.
static func shader_of(m: Resource) -> ShaderMaterial:
	var tm := m as TetraMaterial4D
	return tm.get_cross_section_material_3d() if tm != null else null
