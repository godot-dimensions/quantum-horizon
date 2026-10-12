extends RefCounted

## THE MAIN GREEN: one colour for the pen's greens (6 Oct, Ramon: "make a color picker in the UI, so i
## can change all green together, and with a rebake button under it ... it would be good if the green
## also effects the green on top of the stones, and the rock tower"). It is:
##   the field's paint, all of it (grass/pen_grass_4d.gd, even_green),
##   the mountains' foot (pen_mountains_4d.gd, mountains_even.res),
##   the cave's hill and the two round hills, their turf (cave_hill_even.res, hill_west_even.res,
##   hill_tower_even.res),
##   the moss on the cut stones' tops (baked/stones/<kind>_moss_<n>_even.res): the Watchstone's, the
##   range's outcrop,
##   the Watchstone's turf (scripts/pen_crag_4d.gd, recoloured, nothing baked).
## Picked in the grass panel (Main green, on the left while you play): the field and the turf follow as
## you drag; Rebake greens bakes the rest (about 15 s, the cave's hill most of it) and saves the colour
## in SAVED, so the pen opens in it next time and the bakes on disk match it.
##
## ON OR OFF (the Grass node's even_green, Ctrl+Shift+O): on, the pen shows all of the above; off, the
## greens from before them (the field's falloff, the old bakes, the old moss), which the picker never
## touches. [member on] is that switch for the pieces that are not the Grass node's own.
##
## NO class_name (engine_gotchas.md): preloaded by what uses it.

const TerrainBake := preload("res://ramon/chickenpen/terrain/terrain_bake_4d.gd")
const CutStone := preload("res://ramon/chickenpen/terrain/cut_stone_4d.gd")
const CaveHill := preload("res://ramon/chickenpen/terrain/pen_cave_hill_4d.gd")
const RoundHill := preload("res://ramon/chickenpen/terrain/pen_round_hill_4d.gd")
const SAVED := "res://ramon/chickenpen/terrain/main_green.cfg"
const BAKED := "res://ramon/chickenpen/terrain/baked/"
## What the main green recolours or rebuilds: nodes in this group with main_green_changed(colour,
## baked), baked true when the bakes are new (stones to build again), false while the picker drags.
const GROUP := &"main_green"

## The pen showing the main green (the Grass node's even_green).
static var on: bool = true
## The colour being picked, not yet baked; unset (alpha 0) when there is none.
static var preview: Color = Color(0, 0, 0, 0)
static var _colour: Color = TerrainBake.MAIN_GREEN
static var _loaded: bool = false


## The main green as baked and saved (TerrainBake.MAIN_GREEN until one is).
static func colour() -> Color:
	if not _loaded:
		_loaded = true
		var cfg := ConfigFile.new()
		if cfg.load(SAVED) == OK:
			_colour = cfg.get_value("green", "main", TerrainBake.MAIN_GREEN)
	return _colour


## The first main green, the field's glow as it was painted (the panel's First main green).
static func default_colour() -> Color:
	return TerrainBake.MAIN_GREEN


## What to show now: the colour being picked, else the saved one.
static func shown() -> Color:
	return preview if preview.a > 0.0 else colour()


## The moss's two colours in [param c]: the green where it starts, a little lighter where it is
## thickest on top, so a mossy top still reads as a rounded pad rather than a flat sticker.
static func moss(c: Color) -> Array:
	return [c, c.lightened(0.12)]


static func save(c: Color) -> int:
	_colour = Color(c.r, c.g, c.b, 1.0)
	_loaded = true
	preview = Color(0, 0, 0, 0)
	var cfg := ConfigFile.new()
	cfg.set_value("green", "main", _colour)
	return cfg.save(SAVED)


## Bakes every main-green piece in [param c] and saves each over its file; the new meshes take their
## files' paths, so whatever loads those paths from here on gets them. [param hills] is the pen's
## mountains node (World/Hills), whose bake parameters live on it. Returns the lines to print.
static func bake_all(c: Color, hills: Node) -> Array:
	var lines: Array = []
	var started: int = Time.get_ticks_msec()
	if hills != null and hills.has_method("bake_even"):
		lines.append(String(hills.call("bake_even", c)))
	CaveHill.grass = c
	CaveHill.grass_high = c
	var pieces: Dictionary = {
		"cave_hill": func() -> TerrainBake.Builder: return CaveHill.new().bake(),
		"hill_west": func() -> TerrainBake.Builder: return RoundHill.new("hill_west").bake(),
		"hill_tower": func() -> TerrainBake.Builder: return RoundHill.new("hill_tower").bake(),
		# Layout B's mounds (PenLayout/PLAN_B.md step 36).
		"mound_a": func() -> TerrainBake.Builder: return RoundHill.new("mound_a").bake(),
		"mound_b": func() -> TerrainBake.Builder: return RoundHill.new("mound_b").bake(),
		"mound_c": func() -> TerrainBake.Builder: return RoundHill.new("mound_c").bake(),
		"mound_d": func() -> TerrainBake.Builder: return RoundHill.new("mound_d").bake(),
		"mound_e": func() -> TerrainBake.Builder: return RoundHill.new("mound_e").bake(),
	}
	for name in pieces:
		var t0: int = Time.get_ticks_msec()
		var b: TerrainBake.Builder = (pieces[name] as Callable).call()
		var path: String = BAKED + name + "_even.res"
		lines.append("%s: %d tetrahedra, %.1f s -> %s (%s)" % [name, b.tet_count(), (Time.get_ticks_msec() - t0) / 1000.0, path,
			error_string(_save(TerrainBake.mesh_of(b, false), path))])
	CaveHill.grass = CaveHill.GRASS
	CaveHill.grass_high = CaveHill.GRASS_HIGH
	var greens: Array = moss(c)
	CutStone.moss_top = greens[0]
	CutStone.moss_tip = greens[1]
	var t1: int = Time.get_ticks_msec()
	var count: int = 0
	for kind in CutStone.KINDS:
		for n in CutStone.VARIANTS:
			_save(CutStone.bake_stone(kind, n, true), BAKED + "stones/%s_moss_%d_even.res" % [kind, n])
			count += 1
	CutStone.moss_top = CutStone.MOSS_TOP
	CutStone.moss_tip = CutStone.MOSS_TIP
	lines.append("mossy stones: %d, %.1f s" % [count, (Time.get_ticks_msec() - t1) / 1000.0])
	lines.append("GREENS BAKED in %s, %.1f s" % [c.to_html(false), (Time.get_ticks_msec() - started) / 1000.0])
	return lines


static func _save(mesh: Resource, path: String) -> int:
	var err: int = ResourceSaver.save(mesh, path, ResourceSaver.FLAG_COMPRESS)
	if err == OK:
		mesh.take_over_path(path)
	return err
