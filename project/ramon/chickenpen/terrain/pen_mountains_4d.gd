@tool
extends "res://ramon/chickenpen/terrain/baked_ground_4d.gd"

## The mountains round the pen, with every number out where it can be changed: pick the
## node (World/Hills), change what you like below, press Bake. It takes a few seconds,
## writes baked/mountains.res and shows it. Nothing is generated when the pen runs.
##
## STYLE switches between this and the first version ("Classic", baked/hills.res, from
## pen_hills_4d.gd), which is kept exactly as it was so it can be gone back to.
##
## How the peaks are made - one Voronoi cell a mountain - is in pen_peaks_4d.gd.
##
## Three bands, each a ring of separate mountains at its own distance:
##   RIM: low hills close in, the first skyline.
##   MEDIUM: a middle range behind them.
##   LARGE: the big mountains far off, the only ones high enough for snow.
## For each:
##   distance - how far out its crests are, in metres from the pen's centre.
##   depth - how far either side of that a mountain runs out, along the ray from the pen.
##   spacing_degrees - how far apart the mountains are round the sky; smaller is more.
##   height - the tallest one, in metres.
##   variation - 0 all as tall as that; 1 anything from nothing to that.
##   coverage - the share of places that get a mountain; the rest is sky between.
##
## WHY THE NUMBERS ARE BIGGER THAN THEY LOOK. The mountains are spread over the whole
## sphere of directions, W included, and the slice you stand in usually passes beside a
## summit rather than through it - so what you see of most of them is a shoulder. First
## tried at a third of these heights and coverages, the home slice was nearly flat.
##   width - how much of its place a mountain fills. Past about 0.7 neighbours meet, in a
##     saddle rather than a cliff.
##   sharpness - 1 a straight cone; higher a sharper summit on broader shoulders.

const PenPeaks := preload("res://ramon/chickenpen/terrain/pen_peaks_4d.gd")
const MainGreen := preload("res://ramon/chickenpen/terrain/main_green_4d.gd")
const CLASSIC_MESH := "res://ramon/chickenpen/terrain/baked/hills.res"
const PEAKS_MESH := "res://ramon/chickenpen/terrain/baked/mountains.res"
## THE EVEN GREEN (6 Oct; the pen's field one green, grass/pen_grass_4d.gd even_green): the same
## mountains baked a second time with their foot in that green, so the field runs on into them.
## Measured across the join first: the field (61, 83, 45) on screen, then the mountains' first stretch,
## baked in the old field green, a darker (44, 66, 39). Bake writes both; even_green picks which shows,
## and the Grass node's switch (Ctrl+Shift+O) sets it with the field's.
const EVEN_MESH := "res://ramon/chickenpen/terrain/baked/mountains_even.res"

enum Style { CLASSIC, PEAKS }

@export var style: Style = Style.PEAKS: set = _set_style
@export_tool_button("Bake", "Reload") var _bake_action: Callable = bake
@export var mountain_seed: int = 4
## The foot in the pen's even green (EVEN_MESH), or in the old field green (PEAKS_MESH).
@export var even_green: bool = true: set = _set_even

## The valley's size: where the hills start, metres from this node (50 in layout A, 62 in layout B,
## PenLayout/PLAN_B.md step 8). The node stands at the valley's centre. Rebake after changing it.
@export_range(30.0, 120.0, 0.5, "suffix:m") var valley_radius: float = 50.0
@export_group("Ground")
## Cells along each edge of the cube-sphere's six faces. More is finer and costs video
## memory: every tetrahedron is about 1.25 KB whether it is on screen or not.
@export_range(8, 32, 2) var face_cells: int = 16
## How much the ground climbs per metre away from the pen, under everything.
@export_range(0.0, 0.2, 0.005) var rise: float = 0.025
## Rolling foothills: how tall where they start, and how much taller per metre out.
@export_range(0.0, 30.0, 0.5) var foothills: float = 5.0
@export_range(0.0, 0.2, 0.005) var foothills_growth: float = 0.04
## Where bare rock takes over, and where the snow starts, in metres above the field.
@export_range(0.0, 300.0, 1.0) var rock_from: float = 40.0
@export_range(0.0, 400.0, 1.0) var snow_from: float = 90.0
## How much the distance fades toward the sky's colour, and how quickly.
@export_range(0.0, 1.0, 0.01) var haze: float = 0.8
@export_range(20.0, 1000.0, 5.0) var haze_distance: float = 240.0

@export_group("Rim", "rim_")
@export var rim_enabled: bool = true
@export_range(60.0, 580.0, 1.0) var rim_distance: float = 115.0
@export_range(5.0, 200.0, 1.0) var rim_depth: float = 30.0
@export_range(3.0, 90.0, 0.5) var rim_spacing_degrees: float = 9.0
@export_range(0.0, 300.0, 0.5) var rim_height: float = 27.0
@export_range(0.0, 1.0, 0.01) var rim_variation: float = 0.6
@export_range(0.0, 1.0, 0.01) var rim_coverage: float = 0.85
@export_range(0.05, 1.2, 0.01) var rim_width: float = 0.75
@export_range(0.1, 4.0, 0.05) var rim_sharpness: float = 1.3

@export_group("Medium", "medium_")
@export var medium_enabled: bool = true
@export_range(60.0, 580.0, 1.0) var medium_distance: float = 240.0
@export_range(5.0, 200.0, 1.0) var medium_depth: float = 50.0
@export_range(3.0, 90.0, 0.5) var medium_spacing_degrees: float = 14.0
@export_range(0.0, 300.0, 0.5) var medium_height: float = 84.0
@export_range(0.0, 1.0, 0.01) var medium_variation: float = 0.5
@export_range(0.0, 1.0, 0.01) var medium_coverage: float = 0.8
@export_range(0.05, 1.2, 0.01) var medium_width: float = 0.8
@export_range(0.1, 4.0, 0.05) var medium_sharpness: float = 1.5

@export_group("Large", "large_")
@export var large_enabled: bool = true
@export_range(60.0, 580.0, 1.0) var large_distance: float = 450.0
@export_range(5.0, 200.0, 1.0) var large_depth: float = 80.0
@export_range(3.0, 90.0, 0.5) var large_spacing_degrees: float = 20.0
@export_range(0.0, 400.0, 0.5) var large_height: float = 213.0
@export_range(0.0, 1.0, 0.01) var large_variation: float = 0.45
@export_range(0.0, 1.0, 0.01) var large_coverage: float = 0.6
@export_range(0.05, 1.2, 0.01) var large_width: float = 0.85
@export_range(0.1, 4.0, 0.05) var large_sharpness: float = 1.4


func _ready() -> void:
	super()
	_show()


func _set_style(v: Style) -> void:
	style = v
	if is_node_ready():
		_show()


func _set_even(v: bool) -> void:
	even_green = v
	if is_node_ready():
		_show()


## The bake the style and even_green ask for (the even one only once it has been baked).
func _show(reload: bool = false) -> void:
	var path: String = CLASSIC_MESH
	if style == Style.PEAKS:
		path = EVEN_MESH if even_green and ResourceLoader.exists(EVEN_MESH) else PEAKS_MESH
	if not ResourceLoader.exists(path):
		push_warning("Mountains: nothing baked at %s yet - press Bake." % path)
		return
	if reload or mesh == null or mesh.resource_path != path:
		mesh = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE if reload else ResourceLoader.CACHE_MODE_REUSE) as Mesh4D


## Builds the peaks from the parameters above, saves them and shows them. Returns a line
## saying what was made.
## Bakes both: the foot in the old field green (PEAKS_MESH) and in the main green (EVEN_MESH,
## terrain/main_green_4d.gd's saved colour).
func bake() -> String:
	var lines: Array = [_bake_one(PEAKS_MESH, PenPeaks.FIELD), _bake_one(EVEN_MESH, MainGreen.colour())]
	if String(lines[0]).ends_with("(OK)") and String(lines[1]).ends_with("(OK)"):
		if style != Style.PEAKS:
			style = Style.PEAKS
		_show(true)
	return "\n   ".join(lines)


## Only the main-green one, its foot in [param c] (the grass panel's Rebake greens, through
## terrain/main_green_4d.gd); the new mesh takes the file's path and shows if even_green is on.
func bake_even(c: Color) -> String:
	var line: String = _bake_one(EVEN_MESH, c, true)
	if even_green and style == Style.PEAKS:
		mesh = load(EVEN_MESH) as Mesh4D
	return line


func _bake_one(path: String, foot: Color, take_path: bool = false) -> String:
	var started: int = Time.get_ticks_msec()
	var recipe = PenPeaks.new(self)
	recipe.R_IN = valley_radius
	recipe.field_colour = foot
	var b: TerrainBake.Builder = recipe.bake_shell()
	var made: ArrayTetraMesh4D = TerrainBake.mesh_of(b, false)
	var e: int = ResourceSaver.save(made, path, ResourceSaver.FLAG_COMPRESS)
	if e == OK and take_path:
		made.take_over_path(path)
	var line: String = "mountains: %d layers %s, %d vertices, %d tetrahedra (about %d MB of video memory), %.1f s -> %s (%s)" % [
		recipe.radii().size(), str(Array(recipe.radii()).map(func(r) -> int: return roundi(r))),
		b.positions.size(), b.tet_count(), roundi(b.tet_count() * 1.25 / 1024.0),
		(Time.get_ticks_msec() - started) / 1000.0, path, error_string(e)]
	print(line)
	return line
