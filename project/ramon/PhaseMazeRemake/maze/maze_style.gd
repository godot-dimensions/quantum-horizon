@tool
extends RefCounted

## The Phase Maze remake's look in one place (PLAN.md steps 21 to 31): the Creation Lab's light grid in
## the maze's own swatches, the lab's bright sky and sun, and the kit's colour code: yellow where you start,
## green where you finish, cyan for anything about W.
##
## The kit keeps swatch colours in static state, so apply() sets the maze's and remember() / restore() put
## back whatever was there before: nothing here outlives the scene (the range's range_style.gd does the
## same).
##
## NO class_name (engine_gotchas.md): preload it.

const LabGrid := preload("res://ramon/PhaseMazeRemake/carried/LabKit/lab_grid.gd")
const GlowShader := preload("res://ramon/PhaseMazeRemake/carried/LabKit/shaders/lab_glow.gdshader")

## [surface, line, subline, grid strength] per swatch, sRGB.
##
## THE CREATION LAB'S OWN (round 2, Ramon 9 Oct: "look again at creationlabs ... to be sure the vibes are
## accurate"): its kit swatches (carried/kit/kit_style.gd, bright) under its own light (lab_room_4d.gd's
## bright mood), not the range's pale open look round 1 borrowed. Blue-grey tile, the lab's code blue,
## and the pool of light on the walker doing the work (study2/lab_0_spawn.png).
const SWATCHES := {
	"kit_wall": [Color(0.70, 0.71, 0.72), Color(0.58, 0.59, 0.61), Color(0.66, 0.67, 0.68), 0.6],
	"kit_floor": [Color(0.64, 0.65, 0.66), Color(0.52, 0.53, 0.55), Color(0.60, 0.61, 0.62), 0.5],
	"kit_code_blue": [Color(0.13, 0.40, 0.86), Color(0.20, 0.48, 0.93), Color(0.16, 0.44, 0.90), 0.5],
	# Maze walls that stand across x or z: the lab's wall tile.
	"maze_wall": [Color(0.72, 0.73, 0.75), Color(0.58, 0.59, 0.61), Color(0.67, 0.68, 0.70), 0.6],
	# Maze walls that stand across W: the pen's dev blue, softened, so a wall that only a turn shows you
	# says so (Ramon, 9 Oct: "instead of cyan and green ... the dev colors from the pen. this orange and blue").
	"maze_wall_w": [Color(0.46, 0.60, 0.88), Color(0.31, 0.45, 0.76), Color(0.40, 0.54, 0.84), 0.6],
	# What you climb: the pen's landmark orange (its walkplanes: "the walkplanes ... should be orange. so
	# its clear", Ramon 7 Oct), softened onto the tile, for the stairs and the overlook.
	"maze_climb": [Color(0.90, 0.56, 0.42), Color(0.76, 0.42, 0.29), Color(0.85, 0.50, 0.36), 0.55],
	# The maze floor, a little darker than the walls so wall feet read.
	"maze_floor": [Color(0.62, 0.63, 0.64), Color(0.50, 0.51, 0.53), Color(0.58, 0.59, 0.60), 0.55],
	# Roofs over the indoor stretches: the kit's ceiling.
	"maze_roof": [Color(0.80, 0.81, 0.83), Color(0.70, 0.71, 0.73), Color(0.76, 0.77, 0.79), 0.3],
	# The corner posts where walls meet (Ramon, 9 Oct: "the corners of the wall still clip in to each
	# other"): walls stop short of every corner and a post fills it, one material, a frame like the kit's
	# edge lines.
	"maze_post": [Color(0.52, 0.53, 0.56), Color(0.44, 0.45, 0.48), Color(0.49, 0.50, 0.53), 0.4],
	# Wall caps: the kit's dark edge line along every wall top.
	"maze_cap": [Color(0.30, 0.32, 0.36), Color(0.30, 0.32, 0.36), Color(0.30, 0.32, 0.36), 0.0],
	# The console's plate and glass (the kit's bezel and screen).
	"maze_bezel": [Color(0.90, 0.91, 0.92), Color(0.90, 0.91, 0.92), Color(0.90, 0.91, 0.92), 0.0],
	"maze_screen": [Color(0.035, 0.042, 0.055), Color(0.035, 0.042, 0.055), Color(0.035, 0.042, 0.055), 0.0],
}

## The sky and the sun: the Creation Lab's bright mood as it is (carried/LabKit/lab_room_4d.gd MOODS).
const LIGHT := {
	"sky_top": Color(0.66, 0.74, 0.84), "sky_horizon": Color(0.93, 0.94, 0.95), "sky_bottom": Color(0.84, 0.84, 0.83),
	"ambient": Color(0.50, 0.53, 0.59), "ambient_sky": 0.25,
	"tonemap": 2, "exposure": 1.0, "white": 6.0,
	"key_color": Color(1.0, 0.965, 0.91), "key_energy": 1.75, "key_elevation": 50.0, "key_azimuth": -35.0,
	"fill_color": Color(0.80, 0.87, 1.0), "fill_energy": 0.32, "fill_elevation": 25.0, "fill_azimuth": 145.0,
}

## The colour code, one colour, one meaning: the pen's dev blue and orange (pen_look_4d.gd foundation and
## landmark, Ramon's saved orange). Round 2 had a warm cream for "stand here" and the breadcrumbs; round 3
## (Ramon, 10 Oct: "I'm not convinced by the current yellow floor markers or the soft orange lighting")
## makes them a cool white, so the floor marks no longer read yellow.
const ROLE := {
	"start": Color(0.93, 0.96, 1.0),    # cool white: stand here (the start, the lift's ring, roof lights)
	"exit": Color(0.95, 0.46, 0.30),    # the pen's landmark orange: where you are going, what you climb
	"w": Color(0.36, 0.58, 1.0),        # the pen's dev blue, lifted to read on dark glass: anything about W
	"ghost": Color(0.30, 0.52, 1.0),    # 4D sight's ghosts (the material albedo only the ghost pass uses)
	"trail": Color(0.86, 0.91, 1.0),    # breadcrumbs, newest: the cool white
	"done": Color(0.55, 0.57, 0.62),    # a dead end you have finished
	"x": Color(0.95, 0.95, 0.97),       # the badge's x axis: white
	"z": Color(1.0, 0.62, 0.52),        # the badge's z axis: coral (round 2's deeper cream read yellow)
}
const GLOW := {
	"start": Color(1.0, 0.94, 0.82),
	"exit": Color(1.0, 0.52, 0.32),
	"w": Color(0.32, 0.56, 1.0),
}

## THE W LAYERS' FLOORS (round 3, Ramon: "I can't clearly tell where I currently am in W"; Miegakure:
## "texture the ground differently at intervals, to group parallel worlds", RESEARCH.md section 3; the
## Crosswise islands' lane-tinted floors). Each layer of the maze along W has its floor tinted its own
## colour, kata-most first; the HUD's W ruler uses the same colours, so it is the floor's legend. How
## strong the tint is, is "Floor tint by W layer" on Tab.
const LAYER_TINTS := [Color(0.30, 0.52, 1.0), Color(0.22, 0.78, 0.62), Color(0.72, 0.42, 0.98), Color(1.0, 0.46, 0.42), Color(0.55, 0.62, 0.72)]
static var layer_tint: float = 0.4
## Grid line colours set on their own (Tab, Colours): white lines on dark blue cannot be had by scaling
## the surface colour, which is how a surface's lines follow it otherwise.
static var lines: Dictionary = {}


## The floor swatch of W layer `k`.
static func layer_swatch(k: int) -> String:
	return "maze_floor_l%d" % clampi(k, 0, LAYER_TINTS.size() - 1)


## Layer `k`'s colour, full strength, for the HUD.
static func layer_colour(k: int) -> Color:
	return LAYER_TINTS[clampi(k, 0, LAYER_TINTS.size() - 1)]


static func set_layer_tint(k: float) -> void:
	layer_tint = clampf(k, 0.0, 1.0)
	_apply_layers()


## Every layer floor's swatch from the floor's own, blended toward the layer's colour. The lines blend
## less, so the grid stays the grid.
static func _apply_layers() -> void:
	var v: Array = swatch_values("maze_floor")
	for k in LAYER_TINTS.size():
		# The layer's colour brought to the floor's own brightness first, so the tint turns the floor's
		# hue without lifting a dark floor (a deep red floor went purple when it blended toward a bright
		# blue).
		var t: Color = _at_luma(LAYER_TINTS[k], _luma(v[0]))
		var a: float = layer_tint * 0.65
		LabGrid.set_swatch(layer_swatch(k), (v[0] as Color).lerp(t, a), (v[1] as Color).lerp(_at_luma(LAYER_TINTS[k], _luma(v[1])), a * 0.6),
			(v[2] as Color).lerp(_at_luma(LAYER_TINTS[k], _luma(v[2])), a * 0.8), float(v[3]))


static func _luma(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b


static func _at_luma(c: Color, luma: float) -> Color:
	var k: float = luma / maxf(_luma(c), 0.001)
	return Color(clampf(c.r * k, 0.0, 1.0), clampf(c.g * k, 0.0, 1.0), clampf(c.b * k, 0.0, 1.0))


static func set_line(k: String, c: Color) -> void:
	if not SWATCHES.has(k):
		return
	# The default line colour means "follow the surface", as round 2 did: only a changed one is drawn
	# crisp and on its own.
	if c.is_equal_approx(SWATCHES[k][1]):
		lines.erase(k)
	else:
		lines[k] = c
	_apply_swatch(k)
	if k == "maze_wall":
		_apply_swatch("maze_wall_w")
	if k == "maze_floor":
		_apply_layers()

static var _saved: Dictionary = {}

## THE LIVE PALETTE (Ramon, 9 Oct: "when pressing tab, can you make a hud and allow me to change all the
## colors used in the scene? and save"). The constants above are the defaults; these hold what is in
## force, set from the Tab panel's Colours page (hud/maze_dev_panel.gd) and saved with it.
##   roles      the colour code (start, exit, w, ghost, trail, done, x, z)
##   surfaces   a swatch's main colour; its grid lines follow in proportion, and its dark-mood twin too
static var roles: Dictionary = ROLE.duplicate()
static var surfaces: Dictionary = {}
static var mood: String = "bright"
## The W walls in the plain wall colours (Tab: "Walls across W in blue" off).
static var w_plain: bool = false
## Every glow made through glow_material(), by role, so a new colour reaches what is already built.
static var _glow_users: Dictionary = {}


static func remember() -> void:
	_saved = {}
	for k in SWATCHES:
		_saved[k] = LabGrid.values(String(k))
	for k in LAYER_TINTS.size():
		_saved[layer_swatch(k)] = LabGrid.values(layer_swatch(k))


static func apply() -> void:
	apply_mood(mood)


static func restore() -> void:
	for k in _saved:
		var v: Array = _saved[k]
		LabGrid.set_swatch(String(k), v[0], v[1], v[2], float(v[3]))
	_saved = {}


## Dark (B, as in the Creation Lab): the kit's own dark swatches for the room, the maze's walls and floor
## a step darker, the glows left as they are, so they carry the dark.
const DARK := {
	"kit_wall": [Color(0.62, 0.63, 0.64), Color(0.50, 0.51, 0.53), Color(0.58, 0.59, 0.60), 0.6],
	"kit_floor": [Color(0.58, 0.59, 0.60), Color(0.46, 0.47, 0.49), Color(0.54, 0.55, 0.56), 0.5],
	"kit_code_blue": [Color(0.08, 0.27, 0.64), Color(0.14, 0.35, 0.74), Color(0.11, 0.31, 0.69), 0.5],
	"maze_wall": [Color(0.60, 0.61, 0.63), Color(0.47, 0.48, 0.51), Color(0.55, 0.56, 0.58), 0.6],
	"maze_floor": [Color(0.50, 0.51, 0.53), Color(0.39, 0.40, 0.43), Color(0.46, 0.47, 0.49), 0.55],
	"maze_climb": [Color(0.80, 0.48, 0.35), Color(0.66, 0.36, 0.24), Color(0.74, 0.43, 0.30), 0.55],
	"maze_post": [Color(0.42, 0.43, 0.46), Color(0.35, 0.36, 0.39), Color(0.39, 0.40, 0.43), 0.4],
}


static func apply_mood(m: String) -> void:
	mood = m
	for k in SWATCHES:
		_apply_swatch(String(k))
	_apply_layers()


## A swatch's four values in the mood in force: the default, or the edited main colour with the lines
## and the dark twin scaled from it channel by channel.
static func swatch_values(k: String) -> Array:
	if k == "maze_wall_w" and w_plain:
		return swatch_values("maze_wall")
	var base: Array = SWATCHES[k]
	var v: Array = DARK[k] if mood == "dark" and DARK.has(k) else base
	if surfaces.has(k):
		var to: Color = surfaces[k]
		var from: Color = base[0]
		v = [_scaled(v[0], from, to), _scaled(v[1], from, to), _scaled(v[2], from, to), v[3]]
	if lines.has(k):
		# A line colour of its own: crisp metre lines in it, the 20 cm lines half way to the surface,
		# and the grid at full strength so the lines read as drawn.
		var ln: Color = lines[k]
		v = [v[0], ln, (v[0] as Color).lerp(ln, 0.35), maxf(float(v[3]), 0.95)]
	return v


static func _scaled(c: Color, from: Color, to: Color) -> Color:
	var r: float = c.r / maxf(from.r, 0.01) * to.r
	var g: float = c.g / maxf(from.g, 0.01) * to.g
	var b: float = c.b / maxf(from.b, 0.01) * to.b
	return Color(clampf(r, 0.0, 1.0), clampf(g, 0.0, 1.0), clampf(b, 0.0, 1.0))


static func _apply_swatch(k: String) -> void:
	var v: Array = swatch_values(k)
	LabGrid.set_swatch(k, v[0], v[1], v[2], float(v[3]))


static func surface(k: String) -> Color:
	return surfaces.get(k, SWATCHES[k][0])


static func set_surface(k: String, c: Color) -> void:
	if not SWATCHES.has(k):
		return
	surfaces[k] = c
	_apply_swatch(k)
	if k == "maze_wall":
		_apply_swatch("maze_wall_w")
	if k == "maze_floor":
		_apply_layers()


static func set_w_plain(on: bool) -> void:
	w_plain = on
	_apply_swatch("maze_wall_w")


static func role(r: String) -> Color:
	return roles.get(r, ROLE.get(r, Color.WHITE))


## A glow's colour: the role's, a touch lighter, so it reads as giving light.
static func glow(r: String) -> Color:
	return role(r).lightened(0.08)


static func set_role(r: String, c: Color) -> void:
	roles[r] = c
	var alive: Array = []
	for u in _glow_users.get(r, []):
		var cs: ShaderMaterial = (u[0] as WeakRef).get_ref()
		if cs != null:
			cs.set_shader_parameter("glow_color", glow(r).darkened(float(u[1])))
			alive.append(u)
	_glow_users[r] = alive


## An unshaded glow in a role's colour (the kit's lab_glow), its own material and registered, so the
## Colours page can recolour it live. `darken` dims it (the W doors' inner square).
static func glow_material(r: String, energy: float = 1.0, darken: float = 0.0) -> TetraMaterial4D:
	var m := TetraMaterial4D.new()
	var cs: ShaderMaterial = m.get_cross_section_material_3d()
	cs.shader = GlowShader
	m.albedo_color = Color.WHITE
	cs.set_shader_parameter("glow_color", glow(r).darkened(darken))
	cs.set_shader_parameter("glow_energy", energy)
	if not _glow_users.has(r):
		_glow_users[r] = []
	(_glow_users[r] as Array).append([weakref(cs), darken])
	return m
