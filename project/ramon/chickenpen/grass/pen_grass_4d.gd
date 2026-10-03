extends Node4D

## Grass over the pen's field: a few hundred thousand blades round you, built and blown about
## entirely on the GPU (pen_grass.gdshader), cut by the slice like everything else.
## follow_up/grass_study.md is the case study it comes from.
##
## WHAT THIS NODE DOES, AND ALL IT DOES. The blades have no stored positions: the shader makes
## each from its tile and its cell. So this script only
##   - builds the BANDS round you (band_radii): each a mesh of one tile's blades, simpler than
##     the band inside it (band_vertices), and a MultiMesh of tiles, drawn by RenderingServer
##     into the Cross-section engine's own World3D, as the flock is;
##   - lists, when you have moved half a metre, the world-snapped tiles each band covers, and
##     every render keeps only those in the camera's view and hands them to the shader with the
##     camera's frame (pre_render, as the flock does) and the people and animals that push the
##     grass aside;
##   - once, after the scene is up, builds the MASK: for each half metre of the field, up to two
##     stretches of W where something stands on the ground - a floor, a pond, a hill - so no
##     blade grows inside it. From the real geometry: every tetrahedron of every still thing that
##     touches the ground marks the cells under it with its W reach; the hills come from the
##     Lookout's height map (lookout_ground_4d.gd). It runs a few thousand cells at a time, and
##     the grass grows in when it is done.
##
## COST, by design: a few hundred tile tests and a dozen uniforms a frame on the CPU; the GPU
## does the tiles in view x cells^2 x layers x the band's vertices (see _measure_grass_runner.gd).

const SHADER := preload("res://ramon/chickenpen/grass/pen_grass.gdshader")
const LOOKS := preload("res://ramon/chickenpen/grass/pen_grass_looks.gd")
const PANEL := preload("res://ramon/chickenpen/grass/pen_grass_panel_4d.gd")
const PAINT := preload("res://ramon/chickenpen/grass/pen_ground_paint_4d.gd")
const BITS_SHADER := preload("res://ramon/chickenpen/grass/pen_wind_bits.gdshader")
## Leaves and bits on the wind, at most (pen_wind_bits.gdshader): how many are up follows the
## wind, from none in still air to all of them in a gale.
const MAX_BITS := 6000
const GROUND := preload("res://ramon/chickenpen/lookout/lookout_ground_4d.gd")
## Tiles a band can draw at once (the shader's tiles[] array is this long).
const MAX_TILES := 384

@export var enabled: bool = true:
	set(v):
		enabled = v
		_set_visible()
		enabled_changed.emit(v)
## The look to start in, from pen_grass_looks.gd (1 Pasture, 2 Hay meadow, 3 Hay meadow II -
## the default since 3 Oct); 0 keeps the values set on this node. The grass panel (and O)
## switches between them while playing.
@export_range(0, 9) var start_preset: int = 3
## The see-through HUD panel of looks, at the right edge.
@export var show_panel: bool = true
## THE GROUND, PAINTED (pen_ground_paint_4d.gd), and reversible: a broad glow of green in the
## middle of the farm falling off to the pen's own dark green far out, and a sandy yard round
## the chicken pen. Ramon, 3 Oct, after a flat lighter ground (tried and dropped: "the original,
## darker green still makes more sense in regards to the dusk or dawn mood"): "some kind of
## huge falloff, brighter green like the grass but a tiny bit darker for the center of the whole
## scene", and "keep the surface of the pen inside, and a little beyond 'sandy'". Only in memory
## while the scene runs: off puts the pen's own mesh and material back. The grass panel's
## Ground buttons (and Shift+O) switch it.
@export var ground_paint: bool = true:
	set(v):
		ground_paint = v
		if is_inside_tree():
			_apply_ground()
@export var ground_path: NodePath = ^"World/Ground/GroundMesh"
## The glow: its middle (x, z; the farm's buildings are round it), full out to glow_in, the
## pen's own green by glow_out; along W it is gone by glow_w. ground_glow switches it alone,
## the sand staying (3 Oct: "can you make a toggle for me for the subtle brighter center
## falloff?"; the panel's Centre glow button, Ctrl+O): the ground is painted again, ~30 ms.
##
## WHAT IT IS FOR (Ramon, 3 Oct): "the centre glow was intended to fix the hard cutoff of the
## grass in the distance. right now, the center glow is not a gradient and cuts directly into
## the mountains" - and "the green of the painted floor looks better". Two faults, both fixed:
## glow_out was 85 m, past the field's edge (46 m north of the middle), so the glow was still
## half on where the ground meets the hills and stopped there in a line; now it is gone by
## glow_out 40 m, the pen's own green from there to the hills. And the grass's far edge faded
## to the pen's own dark green whatever the ground under it was, so over the glow it ended in a
## dark ring: the grass shader now works the glow out too and fades to the ground actually there.
@export var ground_glow: bool = true:
	set(v):
		ground_glow = v
		if is_inside_tree() and not _ground_painted.is_empty():
			_paint_ground()
		_glow_to_grass()
		glow_changed.emit(v)
@export var glow_centre: Vector2 = Vector2(-4.0, -14.0)
@export var glow_colour: Color = Color(0.25, 0.31, 0.095)
@export_range(0.0, 60.0, 0.5, "suffix:m") var glow_in: float = 12.0
@export_range(5.0, 150.0, 0.5, "suffix:m") var glow_out: float = 40.0
@export_range(3.0, 60.0, 0.5, "suffix:m") var glow_w: float = 30.0
## Sand round these (node name: how far past what stands on the ground; for clearing_fill
## names, past their whole outline), at their own w, the edge broken by sand_ragged of noise.
## The pen's yard, and the marsh's banks (3 Oct: "just water, sand ... place the sand from the
## pen also here surrounding it").
@export var sand_round: Dictionary = {"Pen": 1.8, "AnaMarsh": 2.4}
@export var sand_colour: Color = Color(0.54, 0.44, 0.28)
## The paint layer, all of it (the field's green, the falloff, the sand), this much darker and
## this much less saturated (3 Oct: "make it slightly darker and a touch less saturated"); the
## grass's far edge fades to the same.
@export_range(0.3, 1.5, 0.01) var paint_brightness: float = 0.88
@export_range(0.0, 1.5, 0.01) var paint_saturation: float = 0.85
@export_range(0.0, 4.0, 0.05, "suffix:m") var sand_ragged: float = 1.0

signal ground_changed(painted: bool)
## The grass switched on or off (the panel's Grass button, Alt+O: 3 Oct, "i also need a toggle
## for turning the grass off").
signal enabled_changed(on: bool)
signal glow_changed(on: bool)
signal wind_changed(scale: float)

@export_group("Leaves and bits")
## Leaves and bits on the wind (3 Oct: "i want some flying leaves in the sky, but in a way that
## is natural. more wind would mean more leaves and bits"). At the wind below bits_calm none
## are up; by bits_gale, all MAX_BITS. Leaves are leaf_share of them.
@export var bits_enabled: bool = true:
	set(v):
		bits_enabled = v
		_set_bits_visible()
@export_range(0.0, 10.0, 0.1, "suffix:m/s") var bits_calm: float = 0.8
@export_range(1.0, 30.0, 0.5, "suffix:m/s") var bits_gale: float = 9.0
@export_range(0.0, 1.0, 0.01) var leaf_share: float = 0.3

signal preset_changed(index: int)

@export_group("Field")
## The gap between blades at your feet and at the field's edge. It starts widening this far
## out and grows smoothly (as a power of the distance) out to the edge.
@export_range(0.04, 0.5, 0.005, "suffix:m") var spacing: float = 0.075
@export_range(0.04, 1.0, 0.01, "suffix:m") var spacing_far: float = 0.27
@export_range(0.5, 20.0, 0.5, "suffix:m") var spacing_from: float = 3.0
## How far round you the grass reaches.
@export_range(10.0, 80.0, 1.0, "suffix:m") var radius: float = 44.0
## The far field goes over to the ground's colour from this share of the radius out to its
## edge, far_fade of the way: so it has no edge to see.
@export_range(0.0, 1.0, 0.01) var far_fade_from: float = 0.5
@export_range(0.0, 1.0, 0.01) var far_fade: float = 1.0
## The bands of simpler blades: where each ends (the last one ends at the radius), and the
## vertices a blade has in each, from your feet out. Same blade, fewer bends.
@export var band_radii: PackedFloat32Array = PackedFloat32Array([5.0, 10.0, 18.0, 28.0])
@export var band_vertices: PackedInt32Array = PackedInt32Array([11, 9, 7, 5, 3])
## Blades stacked along W at each spot, and how far apart.
@export_range(1, 5) var layers: int = 3
@export_range(0.05, 1.0, 0.01, "suffix:m") var layer_spacing: float = 0.22
## How thick in W a blade is: within this of the slice, some of it shows.
@export_range(0.05, 1.0, 0.01, "suffix:m") var w_radius: float = 0.3

@export_group("Blades")
@export_range(0.05, 2.0, 0.01, "suffix:m") var blade_height: float = 0.38
## A blade's width at its root; where that would be under min_pixels on screen, it is
## min_pixels wide instead (thinner, and a far field flickers and goes bare).
@export_range(0.002, 0.2, 0.001, "suffix:m") var blade_width: float = 0.011
## How the blade narrows to its point: 1 straight from root to tip, less stays broad longer.
@export_range(0.2, 2.0, 0.05) var taper: float = 0.5
@export_range(0.0, 3.0, 0.05) var min_pixels: float = 0.8
@export_range(0.3, 5.0, 0.05, "suffix:m") var clump_size: float = 1.3
@export var colour_root: Color = Color(0.11, 0.17, 0.07)
## The field's main colour: sap green.
@export var colour_base: Color = Color(0.31, 0.49, 0.16)
@export var colour_lush: Color = Color(0.27, 0.47, 0.18)
@export var colour_dry: Color = Color(0.47, 0.44, 0.22)
@export var colour_tip: Color = Color(0.48, 0.62, 0.26)
## The field's own colour (the pen's ground material): what the field's edge turns into.
@export var ground_colour: Color = Color(0.16, 0.22, 0.11)
## The painted look: broad regions over the field, about region_size across - sap green
## (colour_base) the most of it, and two offsets of it, deeper and cooler, lighter and warmer,
## each over region_share of the field - the field going region_strength of the way to them;
## and each blade's hue nudged by up to hue_jitter towards yellow or blue.
@export var region_deep: Color = Color(0.21, 0.40, 0.19)
@export var region_bright: Color = Color(0.40, 0.56, 0.17)
@export_range(2.0, 40.0, 0.5, "suffix:m") var region_size: float = 13.0
@export_range(0.0, 0.45, 0.01) var region_share: float = 0.25
@export_range(0.0, 1.0, 0.01) var region_strength: float = 1.0
@export_range(0.0, 0.2, 0.005) var hue_jitter: float = 0.05
## The blade's shape in the field: how far each leans its own way (share of its height), the
## share of clumps left long and how much taller, and a flower stem's height against a blade's.
@export_range(0.0, 0.6, 0.01) var splay: float = 0.08
@export_range(0.0, 0.6, 0.01) var tuft_share: float = 0.0
@export_range(1.0, 4.0, 0.05) var tuft_height: float = 1.9
@export_range(0.3, 3.0, 0.05) var flower_height: float = 1.5
@export_range(0.0, 0.1, 0.001) var flower_share: float = 0.012
## Flowers in patches this big (0: scattered evenly), drawn as dots this big (0: stems with
## heads), this share of them white.
@export_range(0.0, 30.0, 0.5, "suffix:m") var flower_patch_size: float = 0.0
@export_range(0.0, 0.05, 0.001, "suffix:m") var flower_dot: float = 0.0
@export_range(0.0, 1.0, 0.01) var flower_white: float = 0.5
## How light the blades are, all their colours together, so they sit with the ground between
## and beyond them (in linear light: 0.7 is about 0.85 on the colour numbers).
@export_range(0.2, 1.5, 0.01) var shade: float = 0.7
## A TEST, from the grass panel's Darkness slider (3 Oct: "can we make a darkness toggle slider
## so i can test and tell you later which number to pick?"): when 0 or more, the shade every
## look uses, over the look's own, and kept when the look changes. Darkness on the slider is
## 1 - this.
## THE WIND, ALL OF IT, from the grass panel's Wind slider (3 Oct: "can we add a windstrength
## slide or toggle?"): 1 is each look's own wind; the breeze, its gusts and their speed, the
## rolling waves, the big fronts and the leaves in the air all follow it. Kept across looks.
var wind_scale: float = 1.0:
	set(v):
		wind_scale = v
		for band in _bands:
			_wind_to(band.material)
		wind_changed.emit(v)
var shade_test: float = -1.0:
	set(v):
		shade_test = v
		for band in _bands:
			band.material.set_shader_parameter("shade", _shade())

## How dark a blade is at its root (1 the full ramp from colour_root and the shadow there; 0
## none, the blade one colour root to tip).
@export_range(0.0, 1.0, 0.01) var root_dark: float = 1.0
## How far sap green, the bright offset, the lush clumps and the tips go towards ground_colour
## (0 none, 1 all of it); the deep region stays put, as it already merges with the ground.
@export_range(0.0, 1.0, 0.01) var toward_ground: float = 0.18
## How saturated the blades are (1 as the colours say; more is greener, at the same brightness).
@export_range(0.0, 2.0, 0.01) var saturation: float = 1.45

@export_group("Light")
## Haze with distance: the far field fades towards this colour. Off (2 Oct): at 0.5 it washed
## the field grey while the bare ground and buildings beside it stayed clear.
@export var haze_colour: Color = Color(0.62, 0.56, 0.45)
@export_range(5.0, 300.0, 1.0, "suffix:m") var haze_distance: float = 45.0
@export_range(0.0, 1.0, 0.01) var haze_amount: float = 0.0
## Cloud shadows drifting over the field with the wind (0 off), about cloud_size across.
@export_range(0.0, 1.0, 0.01) var cloud_shadows: float = 0.0
@export_range(5.0, 200.0, 1.0, "suffix:m") var cloud_size: float = 40.0

@export_group("Wind")
@export var wind_direction: Vector2 = Vector2(0.82, 0.57)
## The mean wind, m/s (3 is a light breeze), and how gusty (0 steady, 1 squally).
@export_range(0.0, 15.0, 0.1, "suffix:m/s") var wind_speed: float = 3.0
@export_range(0.0, 1.0, 0.01) var gustiness: float = 0.55
## A gust band's length down the wind and across it.
@export_range(1.0, 40.0, 0.5, "suffix:m") var gust_length: float = 7.0
@export_range(1.0, 60.0, 0.5, "suffix:m") var gust_width: float = 18.0
## How far over the strongest gust lays a blade, and the wind pressure ((m/s)^2) that lays it
## half way.
@export_range(0.0, 0.95, 0.01) var bend_max: float = 0.42
@export_range(1.0, 200.0, 0.5) var stiffness: float = 30.0
@export_range(0.0, 1.0, 0.01) var sheen: float = 0.2
## BARLEY WAVES (0 off, 1 full): long soft crests lying across the wind that roll downwind
## through the field, in sets, as over a field of barley; wave_length between crests,
## wave_speed they travel at, wave_width how long a crest is across the wind before it breaks.
@export_range(0.0, 2.0, 0.01) var wave_strength: float = 0.0
@export_range(2.0, 40.0, 0.5, "suffix:m") var wave_length: float = 8.0
@export_range(0.5, 15.0, 0.1, "suffix:m/s") var wave_speed: float = 3.2
@export_range(2.0, 80.0, 0.5, "suffix:m") var wave_width: float = 22.0
## BIG GUSTS (0 off): now and then one broad front sweeping the whole field round you, adding
## big_gust_strength m/s; a chance every big_gust_every seconds, taken big_gust_chance of the
## time; big_gust_width deep, at big_gust_speed.
@export_range(0.0, 20.0, 0.1, "suffix:m/s") var big_gust_strength: float = 0.0
@export_range(4.0, 120.0, 0.5, "suffix:s") var big_gust_every: float = 18.0
@export_range(0.0, 1.0, 0.01) var big_gust_chance: float = 0.6
@export_range(2.0, 40.0, 0.5, "suffix:m") var big_gust_width: float = 9.0
@export_range(1.0, 30.0, 0.5, "suffix:m/s") var big_gust_speed: float = 9.0
## How much further over a big gust lays the grass than the wind's own limit.
@export_range(0.0, 0.6, 0.01) var big_gust_lean: float = 0.3

@export_group("Trampling")
## Grass the player walks through lies the way they went, stays down a moment and comes up
## again slowly over this far behind them (a trail point every trail_spacing); standing still,
## the trail comes up over trail_seconds.
@export_range(0.0, 10.0, 0.1, "suffix:m") var trail_length: float = 3.0
@export_range(0.1, 1.0, 0.05, "suffix:m") var trail_spacing: float = 0.3
@export_range(0.5, 30.0, 0.5, "suffix:s") var trail_seconds: float = 6.0
## Whether anything walking through pushes the grass aside at all (off for Pasture: 3 Oct,
## "when you walk over it, it should stay as is, and not have the walkthrough mechanic").
@export var trample: bool = true

@export_group("Clearings")
## No grass round these (node name: how far out from what stands on the ground, m), the edge
## broken up by noise (clearing_ragged) with a fringe of thinner, trodden grass outside it.
## Names in clearing_fill are cleared inside their whole outline too (the pen's run, the
## ground under the tower).
@export var clearings: Dictionary = {"AnaMarsh": 1.2, "Lookout": 2.5, "Pen": 1.5}
@export var clearing_fill: PackedStringArray = PackedStringArray(["Pen", "Lookout"])
@export_range(0.0, 4.0, 0.05, "suffix:m") var clearing_ragged: float = 1.2
@export_range(0.1, 5.0, 0.05, "suffix:m") var clearing_fringe: float = 1.5

@export_group("Ground")
## The pen's ground slab reaches this far in x, z and w (chickenpen.tscn: 120 m a side).
@export var ground_extent: float = 59.0
## Things whose subtree is never part of the mask: they move, or they are the ground itself.
@export var mask_skip: PackedStringArray = PackedStringArray(["Ground", "Hills", "CaveHill", "Flock", "Chickens", "Player", "Mithra",
	"Nike", "Cat", "RedCat", "Crow", "Crow2", "Crow3", "Trym", "Professor", "Keeper", "RangeMaster", "Wren", "AnaOwl", "AnaHeron",
	"Chipmunk0", "Chipmunk1", "Chipmunk2", "Balloon", "Grass", "UI"])

var mask_ready: bool = false
## Mask cells marked, and how long the mask took, for runners.
var mask_cells: int = 0
var mask_msec: int = 0
## How long painting the ground took, for runners.
var paint_msec: int = 0
## Cells inside a clearing, and how long the clearings took, for runners.
var clearing_cells: int = 0
var clearing_msec: int = 0
## The script's own time in the last pre_render, microseconds, for runners.
var prerender_usec: int = 0
## The look in use (pen_grass_looks.gd), 0 for the node's own values.
var preset: int = 0


## One band of the field: a ring round you with its own grid gap and its own blade.
class Band:
	var inner: float
	var outer: float
	var inner_fade: float
	var outer_fade: float
	var last: bool
	var spacing: float
	var cells: int
	var vertices: int
	var material: ShaderMaterial
	## The tiles (world-snapped indices) that reach this band round the centre, nearest first,
	## their middles, and the ones in view this frame.
	var tiles := PackedVector2Array()
	var middles := PackedVector2Array()
	var shown := PackedVector2Array()
	var multimesh := RID()

	func tile_size() -> float:
		return float(cells) * spacing


var _bands: Array[Band] = []
var _meshes: Array = []
var _multimeshes: Array = []
var _instances: Array = []
var _scenario := RID()
var _tiles_centre := Vector2(INF, INF)
var _drawn: int = 0
var _region_cuts := Vector4(0.36, 0.46, 0.55, 0.65)
var _mask_image: Image
var _mask_texture: ImageTexture
var _clearing_texture: ImageTexture
## The outlines of the clearing_fill names (x0, x1, z0, z1, group, w0, w1), from the mask.
var _outlines: Dictionary = {}
## Per sand_round name: the mask cells its footprint covers and its reach along W.
var _sand_cells: Dictionary = {}
var _marking_sand: String = ""
## The ground as the pen has it, and painted: [mesh, material] each.
var _ground_own: Array = []
var _ground_painted: Array = []
## The player's trail: [where (grass space), the way they went, when], newest first.
var _trail: Array = []
## Per pusher: [where it was when its way was last taken, its way].
var _ways: Dictionary = {}
var _pushers: Array[Node4D] = []
var _room: Node
var _noise_image: Image
var _wind_texture: ImageTexture
var _clearing_w := Vector3(0.0, 8.0, -8.0)

const MASK_CELL := 0.5
const MASK_CELLS := 240


func _ready() -> void:
	_room = owner if owner != null else get_parent().get_parent()
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.012
	noise.fractal_octaves = 3
	# Made here, not by a NoiseTexture2D (which makes it on a thread, later), so the regions'
	# cuts can be read off it now.
	_noise_image = noise.get_seamless_image(256, 256)
	_wind_texture = ImageTexture.create_from_image(_noise_image)
	_mask_image = Image.create_empty(MASK_CELLS, MASK_CELLS, false, Image.FORMAT_RGBAF)
	_mask_image.fill(Color(1e4, -1e4, 1e4, -1e4))
	_mask_texture = ImageTexture.create_from_image(_mask_image)
	var clear_image := Image.create_empty(MASK_CELLS, MASK_CELLS, false, Image.FORMAT_RGBF)
	clear_image.fill(Color(-10.0, -10.0, -10.0))
	_clearing_texture = ImageTexture.create_from_image(clear_image)
	if start_preset > 0:
		_take(start_preset)
	_build_bands()
	_build_bits()
	if not RenderingServer4D.pre_render.is_connected(_on_pre_render):
		RenderingServer4D.pre_render.connect(_on_pre_render)
	_set_visible()
	_find_pushers.call_deferred()
	_build_mask.call_deferred()
	if show_panel:
		_add_panel.call_deferred()


## Switches to look [param n] from pen_grass_looks.gd, rebuilding the bands (their grids and
## blades depend on the gaps and heights); the mask and the clearings stay as they are.
func apply_preset(n: int) -> void:
	if not LOOKS.PRESETS.has(n):
		return
	_take(n)
	_free_bands()
	_build_bands()
	_tiles_centre = Vector2(INF, INF)
	_scenario = RID()
	_set_visible()
	preset_changed.emit(n)


## Sets look [param n]'s values on this node: BASE's for anything it does not name.
func _take(n: int) -> void:
	for look in [LOOKS.BASE, LOOKS.PRESETS[n]]:
		for key in look:
			if key != "name" and key in self:
				var value: Variant = look[key]
				# (A constant cannot hold packed arrays, so the looks list plain ones.)
				if value is Array:
					value = PackedInt32Array(value) if get(key) is PackedInt32Array else PackedFloat32Array(value)
				set(key, value)
	preset = n


## The pen's ground as it has it, or painted (once the painting is done).
func _apply_ground() -> void:
	var node := _room.get_node_or_null(ground_path) as MeshInstance4D if _room != null else null
	if node == null:
		return
	if _ground_own.is_empty():
		_ground_own = [node.mesh, node.material_override]
	var use: Array = _ground_painted if ground_paint and not _ground_painted.is_empty() else _ground_own
	if node.mesh != use[0]:
		node.mesh = use[0]
		node.material_override = use[1]
	_glow_to_grass()
	ground_changed.emit(ground_paint)


## The look's wind times wind_scale onto a material. The bend follows the speed by itself; the
## waves and the big fronts' extra lean are capped a little past the look's own so a gale does
## not fold the field flat.
func _wind_to(m: ShaderMaterial) -> void:
	m.set_shader_parameter("wind_speed", wind_speed * wind_scale)
	m.set_shader_parameter("wave_strength", wave_strength * minf(wind_scale, 1.6))
	m.set_shader_parameter("big_gust_strength", big_gust_strength * wind_scale)
	m.set_shader_parameter("big_gust_lean", big_gust_lean * minf(wind_scale, 1.5))


## The shade in use: the Darkness slider's test value when it is set, else the look's.
func _shade() -> float:
	return shade_test if shade_test >= 0.0 else shade


## The glow, for the grass's far edge to fade to the ground actually under it.
func _glow_to(m: ShaderMaterial) -> void:
	var on: bool = ground_glow and ground_paint
	var glow: Color = _paint_adjust(glow_colour)
	# The far edge fades to the ground as it is drawn: the paint layer's colour when it is on.
	var edge: Color = _paint_adjust(ground_colour) if ground_paint else ground_colour
	m.set_shader_parameter("glow_area", Vector4(glow_centre.x, glow_centre.y, glow_in, glow_out))
	m.set_shader_parameter("glow_colour", Vector3(glow.r, glow.g, glow.b))
	m.set_shader_parameter("glow_on", 1.0 if on else 0.0)
	m.set_shader_parameter("edge_colour", Vector3(edge.r, edge.g, edge.b))


## A paint layer colour (sRGB) made paint_brightness as bright and paint_saturation as
## saturated, in linear light (so it is the same as adjusting the painted ground itself: the
## painting only mixes these colours).
func _paint_adjust(c: Color) -> Color:
	var lin: Color = c.srgb_to_linear()
	var grey: float = lin.r * 0.2126 + lin.g * 0.7152 + lin.b * 0.0722
	var out := Color(lerpf(grey, lin.r, paint_saturation), lerpf(grey, lin.g, paint_saturation), lerpf(grey, lin.b, paint_saturation)) * paint_brightness
	out.a = 1.0
	return out.linear_to_srgb()


func _glow_to_grass() -> void:
	for band in _bands:
		_glow_to(band.material)


## Paints the ground, after the mask (the footprints of what gets sand come from it).
func _paint_ground() -> void:
	var node := _room.get_node_or_null(ground_path) as MeshInstance4D
	if node == null:
		return
	if _ground_own.is_empty():
		_ground_own = [node.mesh, node.material_override]
	# The pen's own box, not whatever is on the node: painted once, it is the painted mesh, and
	# checking that (as this did) made every repaint after the first - the glow toggle - quit.
	var box := _ground_own[0] as BoxTetraMesh4D
	if box == null:
		return
	var own: Color = Color(0.16, 0.22, 0.11)
	if _ground_own[1] != null and _ground_own[1].get("albedo_color") != null:
		own = _ground_own[1].get("albedo_color")
	var started: int = Time.get_ticks_msec()
	var sands: Array = []
	for key in sand_round:
		if _sand_cells.has(key):
			sands.append(_sand_field(key, float(sand_round[key])))
	_ground_painted = PAINT.build(box.size, {
		"centre": glow_centre, "glow_in": glow_in, "glow_out": glow_out, "glow_w": glow_w,
		"own": _paint_adjust(own), "glow": _paint_adjust(glow_colour if ground_glow else own), "sand": _paint_adjust(sand_colour), "sand_ragged": sand_ragged,
		"sands": sands, "grid_cell": MASK_CELL, "grid_cells": MASK_CELLS, "grid_half": MASK_CELL * MASK_CELLS * 0.5,
	})
	paint_msec = Time.get_ticks_msec() - started
	_apply_ground()


## For sand round [param key]: on the mask's grid, how far inside the sand each cell is (m,
## > 0 inside), [param beyond] past its footprint (and its outline, for a clearing_fill name),
## spread by two sweeps; with its reach along W and the box of cells near it.
func _sand_field(key: String, beyond: float) -> Dictionary:
	var n: int = MASK_CELLS
	var half: float = MASK_CELL * n * 0.5
	var rec: Dictionary = _sand_cells[key]
	var field := PackedFloat32Array()
	field.resize(n * n)
	field.fill(-10.0)
	for cell in rec["cells"]:
		field[cell] = beyond
	if clearing_fill.has(key) and _outlines.has(key):
		var o: Array = _outlines[key]
		for j in range(clampi(int(floor((o[2] + half) / MASK_CELL)), 0, n - 1), clampi(int(floor((o[3] + half) / MASK_CELL)), 0, n - 1) + 1):
			for i in range(clampi(int(floor((o[0] + half) / MASK_CELL)), 0, n - 1), clampi(int(floor((o[1] + half) / MASK_CELL)), 0, n - 1) + 1):
				field[j * n + i] = beyond
	var i0: int = n
	var i1: int = -1
	var j0: int = n
	var j1: int = -1
	for c in n * n:
		if field[c] > -10.0:
			i0 = mini(i0, c % n)
			i1 = maxi(i1, c % n)
			j0 = mini(j0, c / n)
			j1 = maxi(j1, c / n)
	var margin: int = int(ceil((beyond + sand_ragged * 1.5 + 1.0) / MASK_CELL))
	i0 = maxi(i0 - margin, 0)
	i1 = mini(i1 + margin, n - 1)
	j0 = maxi(j0 - margin, 0)
	j1 = mini(j1 + margin, n - 1)
	var diag: float = MASK_CELL * 1.41421
	for j in range(j0, j1 + 1):
		for i in range(i0, i1 + 1):
			var c: int = j * n + i
			var v: float = field[c]
			if i > i0:
				v = maxf(v, field[c - 1] - MASK_CELL)
			if j > j0:
				v = maxf(v, field[c - n] - MASK_CELL)
				if i > i0:
					v = maxf(v, field[c - n - 1] - diag)
				if i < i1:
					v = maxf(v, field[c - n + 1] - diag)
			field[c] = v
	for j in range(j1, j0 - 1, -1):
		for i in range(i1, i0 - 1, -1):
			var c: int = j * n + i
			var v: float = field[c]
			if i < i1:
				v = maxf(v, field[c + 1] - MASK_CELL)
			if j < j1:
				v = maxf(v, field[c + n] - MASK_CELL)
				if i < i1:
					v = maxf(v, field[c + n + 1] - diag)
				if i > i0:
					v = maxf(v, field[c + n - 1] - diag)
			field[c] = v
	return {"field": field, "w0": rec["w0"], "w1": rec["w1"], "box": [i0, i1, j0, j1]}


## The name in [param names] that [param node] is part of (itself or a parent), or "".
func _owner_in(node: Node, names: Dictionary) -> String:
	var n: Node = node
	while n != null and n != _room:
		if names.has(String(n.name)):
			return String(n.name)
		n = n.get_parent()
	return ""


func _add_panel() -> void:
	var ui: Node = _room.get_node_or_null("UI")
	var panel := PANEL.new()
	panel.grass = self
	if ui != null:
		panel.above = ui.get_node_or_null("Quests") as Control
	if ui == null:
		var layer := CanvasLayer.new()
		add_child(layer)
		ui = layer
	ui.add_child(panel)


func _free_bands() -> void:
	for inst in _instances:
		RenderingServer.free_rid(inst)
	for mm in _multimeshes:
		RenderingServer.free_rid(mm)
	_instances.clear()
	_multimeshes.clear()
	_meshes.clear()
	_bands.clear()
	_drawn = 0


func _build_bands() -> void:
	_region_cuts = _cuts(_noise_image)
	var wind: Texture2D = _wind_texture
	var bounds: Array[float] = [0.0]
	for r in band_radii:
		if r > bounds.back() + 0.5 and r < radius - 0.5:
			bounds.append(r)
	bounds.append(radius)
	for i in bounds.size() - 1:
		var band := Band.new()
		band.inner = bounds[i]
		band.outer = bounds[i + 1]
		band.last = i == bounds.size() - 2
		band.inner_fade = _fade(band.inner) if i > 0 else 0.0
		band.outer_fade = band.outer * 0.35 if band.last else _fade(band.outer)
		# As fine as the gap wanted where its cross-fade starts, so it is never too coarse.
		band.spacing = _wanted(maxf(band.inner - band.inner_fade, 0.0))
		var reach: float = band.outer + (0.0 if band.last else band.outer_fade)
		# Tiles of about 2 m near you to about 7 m at the edge: fine enough to cull well, few
		# enough to test every frame.
		band.cells = clampi(roundi((1.5 + 0.12 * reach) / band.spacing), 6, 40)
		band.vertices = band_vertices[mini(i, band_vertices.size() - 1)] if not band_vertices.is_empty() else 7
		band.material = _material(wind, band, float(i) * 37.1)
		_add_band(band)
		_bands.append(band)


## Where the regions' noise turns deep and bright: its quantiles, so each offset covers
## region_share of the field (half-way into its soft edge), sap green the rest.
func _cuts(image: Image) -> Vector4:
	var grey: Image = image.duplicate()
	grey.convert(Image.FORMAT_L8)
	var values: PackedByteArray = grey.get_data()
	values.sort()
	var n: int = values.size()
	var at := func(f: float) -> float: return float(values[clampi(int(f * float(n)), 0, n - 1)]) / 255.0
	var soft: float = 0.06
	return Vector4(at.call(region_share - soft), at.call(region_share + soft), at.call(1.0 - region_share - soft), at.call(1.0 - region_share + soft))


## How wide the cross-fade between two bands is, where they meet at [param r].
func _fade(r: float) -> float:
	return 0.75 + 0.03 * r


## The power the gap grows by: spacing at spacing_from, spacing_far at the radius.
func _power() -> float:
	return maxf(log(maxf(spacing_far, spacing) / spacing) / log(radius / spacing_from), 0.0)


## The gap wanted between blades [param d] from you (the shader's own curve).
func _wanted(d: float) -> float:
	return spacing if d <= spacing_from else spacing * pow(d / spacing_from, _power())


func _material(wind: Texture2D, band: Band, hash_seed: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("spacing", band.spacing)
	m.set_shader_parameter("tile_cells", band.cells)
	m.set_shader_parameter("seed", hash_seed)
	m.set_shader_parameter("layers", layers)
	m.set_shader_parameter("layer_spacing", layer_spacing)
	m.set_shader_parameter("w_radius", w_radius)
	m.set_shader_parameter("band_in", band.inner)
	m.set_shader_parameter("band_in_fade", band.inner_fade)
	m.set_shader_parameter("band_out", band.outer)
	m.set_shader_parameter("band_out_fade", band.outer_fade)
	m.set_shader_parameter("last_band", band.last)
	m.set_shader_parameter("far_from", radius * far_fade_from)
	m.set_shader_parameter("far_to", radius)
	m.set_shader_parameter("far_amount", far_fade)
	m.set_shader_parameter("spacing_near", spacing)
	m.set_shader_parameter("spacing_from", spacing_from)
	m.set_shader_parameter("spacing_power", _power())
	m.set_shader_parameter("blade_height", blade_height)
	m.set_shader_parameter("blade_width", blade_width)
	m.set_shader_parameter("min_pixels", min_pixels)
	m.set_shader_parameter("ground_extent", ground_extent)
	m.set_shader_parameter("clump_size", clump_size)
	m.set_shader_parameter("mask", _mask_texture)
	m.set_shader_parameter("clearing", _clearing_texture)
	m.set_shader_parameter("clearing_w", _clearing_w)
	m.set_shader_parameter("clearing_ragged", clearing_ragged)
	m.set_shader_parameter("clearing_fringe", clearing_fringe)
	m.set_shader_parameter("taper", taper)
	m.set_shader_parameter("mask_rect", Vector4(-MASK_CELL * MASK_CELLS * 0.5, -MASK_CELL * MASK_CELLS * 0.5, MASK_CELL, float(MASK_CELLS)))
	m.set_shader_parameter("wind_noise", wind)
	m.set_shader_parameter("wind_dir", wind_direction.normalized())
	_wind_to(m)
	m.set_shader_parameter("gustiness", gustiness)
	m.set_shader_parameter("gust_length", gust_length)
	m.set_shader_parameter("gust_width", gust_width)
	m.set_shader_parameter("bend_max", bend_max)
	m.set_shader_parameter("stiffness", stiffness)
	m.set_shader_parameter("sheen", sheen)

	m.set_shader_parameter("wave_length", wave_length)
	m.set_shader_parameter("wave_speed", wave_speed)
	m.set_shader_parameter("wave_width", wave_width)

	m.set_shader_parameter("big_gust_every", big_gust_every)
	m.set_shader_parameter("big_gust_chance", big_gust_chance)
	m.set_shader_parameter("big_gust_width", big_gust_width)
	m.set_shader_parameter("big_gust_speed", big_gust_speed)

	m.set_shader_parameter("region_size", region_size)
	m.set_shader_parameter("region_cuts", _region_cuts)
	m.set_shader_parameter("region_strength", region_strength)
	m.set_shader_parameter("hue_jitter", hue_jitter)
	m.set_shader_parameter("splay", splay)
	m.set_shader_parameter("tuft_share", tuft_share)
	m.set_shader_parameter("tuft_height", tuft_height)
	m.set_shader_parameter("flower_height", flower_height)
	m.set_shader_parameter("flower_share", flower_share)
	m.set_shader_parameter("flower_patch_size", flower_patch_size)
	m.set_shader_parameter("flower_dot", flower_dot)
	m.set_shader_parameter("flower_white", flower_white)
	m.set_shader_parameter("blade_levels", maxi((band.vertices - 1) / 2, 1))
	m.set_shader_parameter("shade", _shade())
	m.set_shader_parameter("root_dark", root_dark)
	m.set_shader_parameter("toward_ground", toward_ground)
	m.set_shader_parameter("saturation", saturation)
	m.set_shader_parameter("haze_distance", haze_distance)
	m.set_shader_parameter("haze_amount", haze_amount)
	m.set_shader_parameter("cloud_shadows", cloud_shadows)
	m.set_shader_parameter("cloud_size", cloud_size)
	m.set_shader_parameter("edge_colour", Vector3(ground_colour.r, ground_colour.g, ground_colour.b))
	_glow_to(m)
	for key in ["colour_root", "colour_base", "colour_lush", "colour_dry", "colour_tip", "ground_colour", "region_deep", "region_bright", "haze_colour"]:
		var c: Color = get(key)
		m.set_shader_parameter(key, Vector3(c.r, c.g, c.b))
	return m


## One tile's blades: [param cells]^2 x layers of them, each pairs of vertices up its length,
## closer together towards the tip where it bends, and the tip. UV is (side -1 / +1 / 0, t from
## root to tip); UV2 is the blade's cell in the tile, (i + layer x cells, j). The shader does the
## rest.
func _tile_mesh(vertices: int, cells: int) -> ArrayMesh:
	var levels: int = maxi((vertices - 1) / 2, 1)
	var per: int = levels * 2 + 1
	var blade_uv := PackedVector2Array()
	for i in levels:
		var t: float = 1.0 - pow(1.0 - float(i) / float(levels), 1.25)
		blade_uv.append(Vector2(-1.0, t))
		blade_uv.append(Vector2(1.0, t))
	blade_uv.append(Vector2(0.0, 1.0))
	var blade_index := PackedInt32Array()
	for i in levels - 1:
		var a: int = i * 2
		blade_index.append_array([a, a + 1, a + 2, a + 1, a + 3, a + 2])
	var last: int = (levels - 1) * 2
	blade_index.append_array([last, last + 1, per - 1])
	var count: int = cells * cells * layers
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var pos := PackedVector3Array()
	var index := PackedInt32Array()
	uv.resize(count * per)
	uv2.resize(count * per)
	pos.resize(count * per)
	index.resize(count * blade_index.size())
	var b: int = 0
	for k in layers:
		for j in cells:
			for i in cells:
				var cell := Vector2(float(i + k * cells), float(j))
				var v0: int = b * per
				for v in per:
					uv[v0 + v] = blade_uv[v]
					uv2[v0 + v] = cell
					pos[v0 + v] = Vector3(blade_uv[v].x * 0.02, blade_uv[v].y * 0.4, 0.0)
				var i0: int = b * blade_index.size()
				for n in blade_index.size():
					index[i0 + n] = v0 + blade_index[n]
				b += 1
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = pos
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	arrays[Mesh.ARRAY_INDEX] = index
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _add_band(band: Band) -> void:
	var mesh := _tile_mesh(band.vertices, band.cells)
	var mm := RenderingServer.multimesh_create()
	RenderingServer.multimesh_set_mesh(mm, mesh.get_rid())
	RenderingServer.multimesh_allocate_data(mm, MAX_TILES, RenderingServer.MULTIMESH_TRANSFORM_3D, false, false)
	RenderingServer.multimesh_set_visible_instances(mm, 0)
	var inst := RenderingServer.instance_create()
	RenderingServer.instance_set_base(inst, mm)
	RenderingServer.instance_geometry_set_material_override(inst, band.material.get_rid())
	RenderingServer.instance_geometry_set_cast_shadows_setting(inst, RenderingServer.SHADOW_CASTING_SETTING_OFF)
	# Its transforms are unused - the shader places every blade - so its bounds are anywhere.
	RenderingServer.instance_set_ignore_culling(inst, true)
	RenderingServer.instance_set_custom_aabb(inst, AABB(Vector3(-5000, -5000, -5000), Vector3(10000, 10000, 10000)))
	RenderingServer.instance_set_visible(inst, false)
	band.multimesh = mm
	_meshes.append(mesh)
	_multimeshes.append(mm)
	_instances.append(inst)


## The blades handed to the GPU last frame (the tiles in view, whole), for runners.
func blade_count() -> int:
	return _drawn


## Per band: [inner, outer, gap, cells per tile side, tile size, vertices, tiles in view].
func band_report() -> Array:
	var out: Array = []
	for band in _bands:
		out.append([band.inner, band.outer, band.spacing, band.cells, band.tile_size(), band.vertices, band.shown.size()])
	return out


func _set_visible() -> void:
	for inst in _instances:
		RenderingServer.instance_set_visible(inst, enabled and mask_ready and _scenario.is_valid() and is_visible_in_tree())
	_set_bits_visible()


# --- Leaves and bits on the wind --------------------------------------------------------------

var _bits_instance := RID()
var _bits_multimesh := RID()
var _bits_mesh: ArrayMesh
var _bits_material: ShaderMaterial
## How far the air has gone (m), added up a frame at a time, and the wind now, smoothed: the
## shader moves them by these, so a change of wind changes their speed, not where they are.
var _bits_travel: float = 0.0
var _bits_wind: float = -1.0
var _bits_msec: int = 0


## One diamond (base, two sides, tip), drawn MAX_BITS times; the shader shapes, places and turns
## each.
func _build_bits() -> void:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(0, 0, 0), Vector3(-0.02, 0.02, 0), Vector3(0.02, 0.02, 0), Vector3(0, 0.04, 0)])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0.0, 0.0), Vector2(-1.0, 0.45), Vector2(1.0, 0.45), Vector2(0.0, 1.0)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 3, 0, 3, 2])
	_bits_mesh = ArrayMesh.new()
	_bits_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_bits_material = ShaderMaterial.new()
	_bits_material.shader = BITS_SHADER
	_bits_material.set_shader_parameter("wind_noise", _wind_texture)
	_bits_material.set_shader_parameter("leaf_share", leaf_share)
	_bits_multimesh = RenderingServer.multimesh_create()
	RenderingServer.multimesh_set_mesh(_bits_multimesh, _bits_mesh.get_rid())
	RenderingServer.multimesh_allocate_data(_bits_multimesh, MAX_BITS, RenderingServer.MULTIMESH_TRANSFORM_3D, false, false)
	RenderingServer.multimesh_set_visible_instances(_bits_multimesh, 0)
	_bits_instance = RenderingServer.instance_create()
	RenderingServer.instance_set_base(_bits_instance, _bits_multimesh)
	RenderingServer.instance_geometry_set_material_override(_bits_instance, _bits_material.get_rid())
	RenderingServer.instance_geometry_set_cast_shadows_setting(_bits_instance, RenderingServer.SHADOW_CASTING_SETTING_OFF)
	RenderingServer.instance_set_ignore_culling(_bits_instance, true)
	RenderingServer.instance_set_custom_aabb(_bits_instance, AABB(Vector3(-5000, -5000, -5000), Vector3(10000, 10000, 10000)))
	RenderingServer.instance_set_visible(_bits_instance, false)


func _set_bits_visible() -> void:
	if _bits_instance.is_valid():
		RenderingServer.instance_set_visible(_bits_instance, bits_enabled and _scenario.is_valid() and is_visible_in_tree())


## A frame of the leaves and bits: the air moved on, how many are up, the camera's frame.
func _bits_frame(frame: PackedVector4Array) -> void:
	if not _bits_instance.is_valid():
		return
	var now: int = Time.get_ticks_msec()
	var delta: float = clampf(float(now - _bits_msec) / 1000.0, 0.0, 0.1) if _bits_msec > 0 else 0.0
	_bits_msec = now
	var wind: float = wind_speed * wind_scale
	_bits_wind = wind if _bits_wind < 0.0 else lerpf(_bits_wind, wind, clampf(delta * 1.5, 0.0, 1.0))
	_bits_travel += _bits_wind * delta
	var amount: float = clampf((_bits_wind - bits_calm) / maxf(bits_gale - bits_calm, 0.1), 0.0, 1.0)
	RenderingServer.multimesh_set_visible_instances(_bits_multimesh, roundi(float(MAX_BITS) * amount))
	_bits_material.set_shader_parameter("frame", frame)
	_bits_material.set_shader_parameter("wind_dir", wind_direction.normalized())
	_bits_material.set_shader_parameter("wind_now", _bits_wind)
	_bits_material.set_shader_parameter("travel", _bits_travel)


## How many leaves and bits are up now, for runners.
func bits_count() -> int:
	return RenderingServer.multimesh_get_visible_instances(_bits_multimesh) if _bits_multimesh.is_valid() else 0


func _exit_tree() -> void:
	for inst in _instances:
		RenderingServer.instance_set_visible(inst, false)
	if _bits_instance.is_valid():
		RenderingServer.instance_set_visible(_bits_instance, false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if RenderingServer4D.pre_render.is_connected(_on_pre_render):
			RenderingServer4D.pre_render.disconnect(_on_pre_render)
		for inst in _instances:
			RenderingServer.free_rid(inst)
		for mm in _multimeshes:
			RenderingServer.free_rid(mm)
		if _bits_instance.is_valid():
			RenderingServer.free_rid(_bits_instance)
		if _bits_multimesh.is_valid():
			RenderingServer.free_rid(_bits_multimesh)


## The tiles each band covers round [param centre], nearest first: every world-snapped tile
## that reaches the band (with its cross-fades, and half a metre to spare, so this need only run
## again when you have moved that far).
func _list_tiles(centre: Vector2) -> void:
	_tiles_centre = centre
	for band in _bands:
		var t: float = band.tile_size()
		var lo: float = maxf(band.inner - band.inner_fade - 0.6, 0.0)
		var hi: float = band.outer + (0.0 if band.last else band.outer_fade) + 0.6
		var found: Array = []
		for tz in range(floori((centre.y - hi) / t), floori((centre.y + hi) / t) + 1):
			for tx in range(floori((centre.x - hi) / t), floori((centre.x + hi) / t) + 1):
				var x0: float = float(tx) * t
				var z0: float = float(tz) * t
				var nearest: float = Vector2(clampf(centre.x, x0, x0 + t), clampf(centre.y, z0, z0 + t)).distance_to(centre)
				var fx: float = maxf(absf(centre.x - x0), absf(centre.x - x0 - t))
				var fz: float = maxf(absf(centre.y - z0), absf(centre.y - z0 - t))
				if nearest <= hi and fx * fx + fz * fz >= lo * lo:
					found.append([nearest, Vector2(tx, tz)])
		found.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
		band.tiles.clear()
		band.middles.clear()
		for f in found:
			band.tiles.append(f[1])
			band.middles.append((f[1] + Vector2(0.5, 0.5)) * t)


## The camera's frame for the shader, every render, and the tiles in its view; the instances
## into whichever World3D the cut is drawn in (the Combined renderer's is a SubViewport two deep).
func _on_pre_render(camera: Camera4D, viewport: Viewport, engine: RenderingEngine4D) -> void:
	if viewport != get_viewport() or _instances.is_empty():
		return
	var started: int = Time.get_ticks_usec()
	var world: World3D = viewport.find_world_3d()
	if engine != null and engine.get_friendly_name() == "Combined":
		var inner := viewport.get_node_or_null(^"CombinedProjectedSubViewport4D/CombinedCrossSectionSubViewport4D") as Viewport
		if inner != null:
			world = inner.find_world_3d()
	var scenario: RID = world.scenario if world != null else RID()
	if scenario != _scenario:
		_scenario = scenario
		for inst in _instances:
			RenderingServer.instance_set_scenario(inst, scenario)
		if _bits_instance.is_valid():
			RenderingServer.instance_set_scenario(_bits_instance, scenario)
		_set_visible()
	var inverse: Projection = camera.global_basis.inverse()
	var basis: Projection = inverse * global_basis
	var origin: Vector4 = inverse * (global_position - camera.global_position)
	var here: Vector4 = global_basis.inverse() * (camera.global_position - global_position)
	var normal: Vector4 = (global_basis.inverse() * camera.global_basis.w).normalized()
	# The rings' middle is you: the player, when this is their own camera (the orbit rig, a few
	# metres behind them), so the field spreads out round them and not ahead of the view; else
	# (the hawk, the Lookout's camera, a cutscene) the camera.
	var centre := Vector2(here.x, here.z)
	var player := _room.get_node_or_null("Player") as Node4D
	if player != null and player.is_ancestor_of(camera):
		var at_player: Vector4 = global_basis.inverse() * (player.global_position - global_position)
		centre = Vector2(at_player.x, at_player.z)
	if centre.distance_to(_tiles_centre) > 0.5:
		_list_tiles(centre)
	var pushers := PackedVector4Array()
	var motions := PackedVector4Array()
	_push(pushers, motions, centre)
	# The view's half-width and half-height, as tangents, with a margin; a pixel's angle.
	var view: Vector2 = viewport.get_visible_rect().size
	var fov: float = float(camera.get("field_of_view_4d")) if int(camera.get("projection_type")) == 1 else float(camera.get("field_of_view_3d"))
	var fy: float = tan(fov * 0.5) * 1.15
	var fx: float = fy * view.x / maxf(view.y, 1.0)
	var kx: float = sqrt(1.0 + fx * fx)
	var ky: float = sqrt(1.0 + fy * fy)
	var pixel_angle: float = 2.0 * tan(fov * 0.5) / maxf(view.y, 1.0)
	# Only the tiles in view, tested as balls round their middles at the slice's w there. The
	# slice's w over the ground is linear in x and z, so a middle's place in the camera's frame
	# is too: ax * x + az * z + c0.
	var gx: float = 0.0
	var gz: float = 0.0
	var w0: float = here.w
	if absf(normal.w) > 0.25:
		gx = -normal.x / normal.w
		gz = -normal.z / normal.w
		w0 = here.w + (normal.x * here.x + normal.y * here.y + normal.z * here.z) / normal.w
	var cx: Vector4 = basis.x + basis.w * gx
	var cz: Vector4 = basis.z + basis.w * gz
	var c4: Vector4 = basis.y * 0.3 + basis.w * w0 + origin
	var ax := Vector3(cx.x, cx.y, cx.z)
	var az := Vector3(cz.x, cz.y, cz.z)
	var c0 := Vector3(c4.x, c4.y, c4.z)
	var frame := PackedVector4Array([basis.x, basis.y, basis.z, basis.w, origin, here, normal,
		Vector4(centre.x, centre.y, fx, pixel_angle)])
	_bits_frame(frame)
	_drawn = 0
	for band in _bands:
		var r: float = band.tile_size() * 0.7072 + 0.7
		var rx: float = r * kx
		var ry: float = r * ky
		band.shown.clear()
		var middles: PackedVector2Array = band.middles
		for i in middles.size():
			var m: Vector2 = middles[i]
			var rel: Vector3 = ax * m.x + az * m.y + c0
			var ahead: float = -rel.z
			if ahead > -r and absf(rel.x) - ahead * fx < rx and absf(rel.y) - ahead * fy < ry:
				band.shown.append(band.tiles[i])
		if band.shown.size() > MAX_TILES:
			band.shown.resize(MAX_TILES)
		var n: int = band.shown.size()
		_drawn += n * band.cells * band.cells * layers
		var upload: PackedVector2Array = band.shown.duplicate()
		upload.resize(MAX_TILES)
		var mat: ShaderMaterial = band.material
		mat.set_shader_parameter("tiles", upload)
		mat.set_shader_parameter("frame", frame)
		mat.set_shader_parameter("pushers", pushers)
		mat.set_shader_parameter("pusher_motion", motions)
		mat.set_shader_parameter("pusher_count", pushers.size())
		RenderingServer.multimesh_set_visible_instances(band.multimesh, n)
	prerender_usec = Time.get_ticks_usec() - started


## Whoever walks through the grass near [param centre], as the shader takes them: where
## (x, strength, z, w) and the way they went (x, z, -, reach). The player first, then the
## player's trail behind them, then the rest, 24 at most.
func _push(pushers: PackedVector4Array, motions: PackedVector4Array, centre: Vector2) -> void:
	if not trample:
		_trail.clear()
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	var player := _room.get_node_or_null("Player") as Node4D
	for p in _pushers:
		if pushers.size() >= 24:
			break
		if not is_instance_valid(p) or not p.is_visible_in_tree():
			continue
		var at: Vector4 = global_basis.inverse() * (p.global_position - global_position)
		var way: Vector2 = _way(p, at)
		if p == player:
			_lay_trail(at, way, now)
		if Vector2(at.x - centre.x, at.z - centre.y).length() >= 14.0:
			continue
		pushers.append(Vector4(at.x, 1.0, at.z, at.w))
		motions.append(Vector4(way.x, way.y, 0.0, 0.85))
		if p != player:
			continue
		# The trail: down at first, then up slowly over trail_length behind them, and over
		# trail_seconds if they stand.
		var along: float = 0.0
		var last := at
		for point in _trail:
			if pushers.size() >= 20:
				break
			var where: Vector4 = point[0]
			along += Vector2(where.x - last.x, where.z - last.z).length()
			last = where
			var strength: float = (1.0 - smoothstep(0.4, trail_length, along)) * (1.0 - smoothstep(trail_seconds * 0.4, trail_seconds, now - float(point[2])))
			if strength > 0.03:
				pushers.append(Vector4(where.x, strength, where.z, where.w))
				var w: Vector2 = point[1]
				motions.append(Vector4(w.x, w.y, 0.0, 0.6))


## The way [param node] has been going, from how it has moved since it last went 5 cm.
func _way(node: Node4D, at: Vector4) -> Vector2:
	var id: int = node.get_instance_id()
	var rec: Array = _ways.get(id, [at, Vector2.ZERO])
	var was: Vector4 = rec[0]
	var moved := Vector2(at.x - was.x, at.z - was.z)
	if moved.length() > 2.0:
		rec[0] = at
	elif moved.length() > 0.05:
		var dir: Vector2 = moved.normalized()
		var way: Vector2 = rec[1]
		rec[1] = dir if way == Vector2.ZERO else way.lerp(dir, 0.5).normalized()
		rec[0] = at
	_ways[id] = rec
	return rec[1]


## A trail point where the player is, every trail_spacing they go; the old ones dropped once
## they are past trail_length behind or trail_seconds old. A jump of more than 2 m (a teleport,
## a respawn) starts the trail again.
func _lay_trail(at: Vector4, way: Vector2, now: float) -> void:
	if not _trail.is_empty():
		var newest: Vector4 = _trail[0][0]
		var gap: float = Vector2(at.x - newest.x, at.z - newest.z).length()
		if gap > 2.0:
			_trail.clear()
		elif gap < trail_spacing:
			return
	_trail.push_front([at, way, now])
	var along: float = 0.0
	var keep: int = _trail.size()
	for i in range(1, _trail.size()):
		var a: Vector4 = _trail[i - 1][0]
		var b: Vector4 = _trail[i][0]
		along += Vector2(a.x - b.x, a.z - b.z).length()
		if along > trail_length + trail_spacing or now - float(_trail[i][2]) > trail_seconds:
			keep = i
			break
	_trail.resize(keep)


## The player, the chickens, Nike, the cats, the people: whoever walks through the grass.
func _find_pushers() -> void:
	_pushers.clear()
	for path in ["Player", "Mithra", "World/Nike", "World/Cat", "World/RedCat", "World/Trym", "World/Professor", "World/Keeper",
			"World/LookoutSite/Wren", "World/RangeMaster"]:
		var n := _room.get_node_or_null(path) as Node4D
		if n != null:
			_pushers.append(n)
	var chickens: Node = _room.get_node_or_null("Chickens")
	if chickens != null:
		for c in chickens.get_children():
			if c is Node4D:
				_pushers.append(c)


# --- The mask ----------------------------------------------------------------------------------

## Built once, a slice at a time, after everything is in the scene (the Lookout builds its
## marsh, wood and trees in its _ready). Then the grass grows in.
func _build_mask() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var started: int = Time.get_ticks_msec()
	var data := PackedFloat32Array()
	data.resize(MASK_CELLS * MASK_CELLS * 4)
	for i in MASK_CELLS * MASK_CELLS:
		data[i * 4] = 1e4
		data[i * 4 + 1] = -1e4
		data[i * 4 + 2] = 1e4
		data[i * 4 + 3] = -1e4
	var meshes: Array = []
	_collect(_room, meshes)
	var budget: int = 0
	# The clearings' seeds: per cell and per group (the farm's w, ana, kata), how far out the
	# clearing goes from there; and per filled name, its outline in x and z.
	var seeds := PackedFloat32Array()
	seeds.resize(MASK_CELLS * MASK_CELLS * 3)
	seeds.fill(-10.0)
	var group_w := PackedFloat32Array([0.0, 0.0, 0.0, 0.0, 0.0, 0.0])
	var outlines: Dictionary = {}
	for mi in meshes:
		var owner_name: String = _clearing_owner(mi)
		var radius: float = float(clearings.get(owner_name, 0.0))
		_marking_sand = _owner_in(mi, sand_round)
		budget += _mark_mesh(mi, data, seeds, radius, group_w, outlines, owner_name if clearing_fill.has(owner_name) else "")
		if budget > 6000:
			budget = 0
			await get_tree().process_frame
	var clear_msec: int = Time.get_ticks_msec()
	_build_clearings(seeds, group_w, outlines)
	clearing_msec = Time.get_ticks_msec() - clear_msec
	_outlines = outlines
	# The hills and the cave hill, from the Lookout's height map at the farm's w.
	var ground: RefCounted = GROUND.build(_room, 0.0, 3.0)
	var half: float = MASK_CELL * MASK_CELLS * 0.5
	for j in MASK_CELLS:
		for i in MASK_CELLS:
			var x: float = -half + (float(i) + 0.5) * MASK_CELL
			var z: float = -half + (float(j) + 0.5) * MASK_CELL
			if float(ground.call("height", x, z)) > 0.3:
				_mark(data, i, j, -3.5, 3.5)
	_mask_image = Image.create_from_data(MASK_CELLS, MASK_CELLS, false, Image.FORMAT_RGBAF, data.to_byte_array())
	_mask_texture.update(_mask_image)
	mask_cells = 0
	for i in MASK_CELLS * MASK_CELLS:
		if data[i * 4] < data[i * 4 + 1]:
			mask_cells += 1
	mask_msec = Time.get_ticks_msec() - started
	mask_ready = true
	_set_visible()
	_paint_ground()


func _collect(node: Node, out: Array) -> void:
	if node != _room and (mask_skip.has(String(node.name)) or node is CharacterBody4D):
		return
	if node is MeshInstance4D and (node as MeshInstance4D).mesh is TetraMesh4D and (node as MeshInstance4D).is_visible_in_tree():
		out.append(node)
	for child in node.get_children():
		_collect(child, out)


## The name in [member clearings] that [param node] is part of (itself or a parent), or "".
func _clearing_owner(node: Node) -> String:
	var n: Node = node
	while n != null and n != _room:
		if clearings.has(String(n.name)):
			return String(n.name)
		n = n.get_parent()
	return ""


## The clearings from their seeds: for each group, how far inside a clearing every cell is
## (a seed's reach less the distance to it, the most of any), by two sweeps of the grid, over
## the seeds' bounds and the furthest reach only.
func _build_clearings(seeds: PackedFloat32Array, group_w: PackedFloat32Array, outlines: Dictionary) -> void:
	var half: float = MASK_CELL * MASK_CELLS * 0.5
	var n: int = MASK_CELLS
	for key in outlines:
		var o: Array = outlines[key]
		var radius: float = float(clearings.get(key, 0.0))
		var g: int = o[4]
		for j in range(clampi(int(floor((o[2] + half) / MASK_CELL)), 0, n - 1), clampi(int(floor((o[3] + half) / MASK_CELL)), 0, n - 1) + 1):
			for i in range(clampi(int(floor((o[0] + half) / MASK_CELL)), 0, n - 1), clampi(int(floor((o[1] + half) / MASK_CELL)), 0, n - 1) + 1):
				var s: int = (j * n + i) * 3 + g
				seeds[s] = maxf(seeds[s], radius)
	var reach: float = 0.0
	for r in clearings.values():
		reach = maxf(reach, float(r))
	var margin: int = int(ceil((reach + 1.0) / MASK_CELL))
	var diag: float = MASK_CELL * 1.41421
	for g in 3:
		var i0: int = n
		var i1: int = -1
		var j0: int = n
		var j1: int = -1
		for j in n:
			for i in n:
				if seeds[(j * n + i) * 3 + g] > -10.0:
					i0 = mini(i0, i)
					i1 = maxi(i1, i)
					j0 = mini(j0, j)
					j1 = maxi(j1, j)
		if i1 < 0:
			continue
		i0 = maxi(i0 - margin, 0)
		i1 = mini(i1 + margin, n - 1)
		j0 = maxi(j0 - margin, 0)
		j1 = mini(j1 + margin, n - 1)
		for j in range(j0, j1 + 1):
			for i in range(i0, i1 + 1):
				var s: int = (j * n + i) * 3 + g
				var v: float = seeds[s]
				if i > i0:
					v = maxf(v, seeds[s - 3] - MASK_CELL)
				if j > j0:
					v = maxf(v, seeds[s - n * 3] - MASK_CELL)
					if i > i0:
						v = maxf(v, seeds[s - n * 3 - 3] - diag)
					if i < i1:
						v = maxf(v, seeds[s - n * 3 + 3] - diag)
				seeds[s] = v
		for j in range(j1, j0 - 1, -1):
			for i in range(i1, i0 - 1, -1):
				var s: int = (j * n + i) * 3 + g
				var v: float = seeds[s]
				if i < i1:
					v = maxf(v, seeds[s + 3] - MASK_CELL)
				if j < j1:
					v = maxf(v, seeds[s + n * 3] - MASK_CELL)
					if i < i1:
						v = maxf(v, seeds[s + n * 3 + 3] - diag)
					if i > i0:
						v = maxf(v, seeds[s + n * 3 - 3] - diag)
				seeds[s] = v
	for i in seeds.size():
		seeds[i] = maxf(seeds[i], -10.0)
	var image := Image.create_from_data(n, n, false, Image.FORMAT_RGBF, seeds.to_byte_array())
	_clearing_texture.update(image)
	var ws := Vector3(0.0, 8.0, -8.0)
	for g in 3:
		if group_w[g * 2 + 1] > 0.0:
			ws[g] = group_w[g * 2] / group_w[g * 2 + 1]
	_clearing_w = ws
	for band in _bands:
		band.material.set_shader_parameter("clearing_w", ws)
	clearing_cells = 0
	for j in n:
		for i in n:
			if seeds[(j * n + i) * 3] > 0.0 or seeds[(j * n + i) * 3 + 1] > 0.0 or seeds[(j * n + i) * 3 + 2] > 0.0:
				clearing_cells += 1


## The group of things a w belongs to: the farm's (0), ana (1) or kata (2).
func _group(w: float) -> int:
	return 0 if absf(w) < 4.0 else (1 if w > 0.0 else 2)


## Every tetrahedron of [param mi] that touches the ground and stays low (a floor, a pond, the
## foot of a wall - not a whole leg of the tower) marks the cells under it with its W reach,
## and, when [param radius] is more than 0, seeds a clearing there, in [param seeds] by its
## group (whose mean w goes into [param group_w]); with a [param fill] name, it widens that
## name's outline in [param outlines]. Returns how many tetrahedra it looked at.
func _mark_mesh(mi: MeshInstance4D, data: PackedFloat32Array, seeds: PackedFloat32Array, radius: float,
		group_w: PackedFloat32Array, outlines: Dictionary, fill: String) -> int:
	var mesh: TetraMesh4D = mi.mesh as TetraMesh4D
	var rb: PackedVector4Array = mesh.get_rect_bounds()
	var basis: Projection = mi.global_basis
	var origin: Vector4 = mi.global_position
	var lo_y: float = INF
	var hi_y: float = -INF
	for c in 16:
		var corner := rb[0] + Vector4(rb[1].x if c & 1 else 0.0, rb[1].y if c & 2 else 0.0, rb[1].z if c & 4 else 0.0, rb[1].w if c & 8 else 0.0)
		var p: Vector4 = basis * corner + origin
		lo_y = minf(lo_y, p.y)
		hi_y = maxf(hi_y, p.y)
	if lo_y > 0.45 or hi_y < 0.0:
		return 1
	var cells: PackedVector4Array = mesh.get_simplex_cell_positions()
	var half: float = MASK_CELL * MASK_CELLS * 0.5
	var k: int = 0
	while k + 3 < cells.size():
		var a: Vector4 = basis * cells[k] + origin
		var b: Vector4 = basis * cells[k + 1] + origin
		var c: Vector4 = basis * cells[k + 2] + origin
		var d: Vector4 = basis * cells[k + 3] + origin
		k += 4
		var lo: Vector4 = a.min(b).min(c.min(d))
		var hi: Vector4 = a.max(b).max(c.max(d))
		if lo.y > 0.45 or hi.y < 0.0 or hi.y > 1.3:
			continue
		var i0: int = clampi(int(floor((lo.x + half) / MASK_CELL)), 0, MASK_CELLS - 1)
		var i1: int = clampi(int(floor((hi.x + half) / MASK_CELL)), 0, MASK_CELLS - 1)
		var j0: int = clampi(int(floor((lo.z + half) / MASK_CELL)), 0, MASK_CELLS - 1)
		var j1: int = clampi(int(floor((hi.z + half) / MASK_CELL)), 0, MASK_CELLS - 1)
		# Only the cells its shadow on the ground covers, not its whole bounding box: the
		# marsh's mud is a fan of long thin wedges, whose boxes bared a square in front of it.
		var small: bool = i1 - i0 <= 1 and j1 - j0 <= 1
		var pa := Vector2(a.x, a.z)
		var pb := Vector2(b.x, b.z)
		var pc := Vector2(c.x, c.z)
		var pd := Vector2(d.x, d.z)
		var covered := PackedInt32Array()
		for j in range(j0, j1 + 1):
			for i in range(i0, i1 + 1):
				if small or _shadow_has(Vector2(-half + (float(i) + 0.5) * MASK_CELL, -half + (float(j) + 0.5) * MASK_CELL), pa, pb, pc, pd):
					_mark(data, i, j, lo.w, hi.w)
					covered.append(j * MASK_CELLS + i)
		if _marking_sand != "" and not covered.is_empty():
			var rec: Dictionary = _sand_cells.get(_marking_sand, {"cells": PackedInt32Array(), "w0": INF, "w1": -INF})
			# (A packed array out of a dictionary is a copy: append, then put it back.)
			var under: PackedInt32Array = rec["cells"]
			under.append_array(covered)
			rec["cells"] = under
			rec["w0"] = minf(float(rec["w0"]), lo.w)
			rec["w1"] = maxf(float(rec["w1"]), hi.w)
			_sand_cells[_marking_sand] = rec
		if radius > 0.0 and not covered.is_empty():
			var mid_w: float = (lo.w + hi.w) * 0.5
			var g: int = _group(mid_w)
			group_w[g * 2] += mid_w
			group_w[g * 2 + 1] += 1.0
			for cell in covered:
				var s: int = cell * 3 + g
				seeds[s] = maxf(seeds[s], radius)
			if fill != "":
				var o: Array = outlines.get(fill, [INF, -INF, INF, -INF, g, INF, -INF])
				o[0] = minf(o[0], lo.x)
				o[1] = maxf(o[1], hi.x)
				o[2] = minf(o[2], lo.z)
				o[3] = maxf(o[3], hi.z)
				o[5] = minf(o[5], lo.w)
				o[6] = maxf(o[6], hi.w)
				outlines[fill] = o
	return cells.size() / 4


## Whether [param p] is under a tetrahedron whose corners, seen from above, are [param a] to
## [param d] (in one of the four triangles they make), with a third of a cell to spare.
func _shadow_has(p: Vector2, a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> bool:
	return _triangle_has(p, a, b, c) or _triangle_has(p, a, b, d) or _triangle_has(p, a, c, d) or _triangle_has(p, b, c, d)


func _triangle_has(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> bool:
	var area: float = (b - a).cross(c - a)
	if absf(area) < 1e-6:
		return false
	var turn: float = 1.0 if area > 0.0 else -1.0
	var tol: float = MASK_CELL * 0.35
	for e in [[a, b], [b, c], [c, a]]:
		var e0: Vector2 = e[0]
		var e1: Vector2 = e[1]
		var edge: Vector2 = e1 - e0
		if edge.cross(p - e0) * turn < -tol * edge.length():
			return false
	return true


## Adds the W stretch [param a]..[param b] to cell (i, j): joined to a stretch it touches, or in
## the empty slot, or (both slots taken) to the nearer.
func _mark(data: PackedFloat32Array, i: int, j: int, a: float, b: float) -> void:
	var o: int = (j * MASK_CELLS + i) * 4
	for slot in [0, 2]:
		var lo: float = data[o + slot]
		var hi: float = data[o + slot + 1]
		if lo > hi:
			data[o + slot] = a
			data[o + slot + 1] = b
			return
		if a < hi + 1.0 and b > lo - 1.0:
			data[o + slot] = minf(lo, a)
			data[o + slot + 1] = maxf(hi, b)
			return
	var mid: float = (a + b) * 0.5
	var d0: float = absf(mid - (data[o] + data[o + 1]) * 0.5)
	var d1: float = absf(mid - (data[o + 2] + data[o + 3]) * 0.5)
	var s: int = 0 if d0 <= d1 else 2
	data[o + s] = minf(data[o + s], a)
	data[o + s + 1] = maxf(data[o + s + 1], b)
