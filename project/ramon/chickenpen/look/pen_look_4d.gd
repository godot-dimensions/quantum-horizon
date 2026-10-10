@tool
extends Node

## THE PEN'S TWO LOOKS (6 Oct 2026; PenLayout/PLAN_DEV_LOOK.md, the case study DEV_LOOK_STUDY.md).
## Ramon: "toggle the entire pen scene, to an R&D scene ... instantly swappable with the press of a
## button while keep the pen scene working in all its operational power"; "the first time you will
## see the pen, it will be the white dev look. with the toggle just as an option button".
##
## DEV: the lab's white grid floor, light grey mountains and round hills, the Creation Lab's bright
## sky and light, the paths' arrows alone on the floor, and every landmark by its rule (below). ART:
## the pen exactly as it is. I (and the Look row on the left-hand panel) switches; it takes a few
## milliseconds.
##
## ONE WORLD, NOT TWO SCENES. A landmark and its dev look are the same node, so moving either in the
## editor moves both (the 4D editor selects an instanced unit's root when any of its meshes is
## clicked), and every mechanic keeps running in either look.
##
## IT NEVER HIDES A NODE. The rune stone, the laptops, the Lookout's photo subjects, the tutor's
## markers and the slice dial's outlines all stop when their node is hidden. A landmark's art has
## its mesh taken off (kept, and put back) or a flat material laid over it; only the picture changes.
##
## THE RULES, per landmark ([member rules]: its node's name, or a name's start ending in * for every
## copy, "Oak*" for every oak; the nearest one up from a mesh wins):
##   "block"  simple shapes instead (look/pen_blockouts_4d.gd: the Watchstone a cylinder or three
##            blocks, the oak, the rock pile; anything else a box over its art). The stone wall is clay: drawn from its colliders it stood full height where
##            the ruin is broken down, which misled. Trym's shed is clay too: its walls go so you can
##            look inside while he talks, and a blockout would stand in front of that (Ramon).
##   "clay"   its own shapes in one flat colour (the default, for anything not named)
##   "art"    left as it is
##   {"keep": [names], "drop": [names]}  parts kept as art, parts taken away, the rest in clay; a name
##            ending in * matches its start. Also "keep_colour"/"drop_colour" (parts by their colour:
##            pieces merged by colour are named after it) and "drop_green" (anything plant-green).
##            "landmark"/"landmark_colour" and "foundation"/"foundation_colour" lay parts orange or
##            blue, and "rest": "drop" takes away whatever no key names.
##            The marsh: an orange ring and a blue fill, nothing else (Ramon, 7 Oct: "its not orange
##            with the dev blue inside as water. so just a ring and a fill"): its sand rim orange,
##            its water blue, the ripples and glints blue on it (by name: they are often hidden when
##            the look goes on, and a hidden part cannot be taken off), the rest gone. Until 7 Oct
##            its water and rim stayed as art (Ramon, 6 Oct: "the marsh water, you can keep it").
##   {"low_mesh": path}  the landmark's own shape baked coarser, in clay. The cave's hill had one until
##            7 Oct (Ramon, 6 Oct: "keep the original cave in the greybox version. just lower res"):
##            terrain/baked/cave_hill_low.res, from look/_bake_low_cave_runner.gd. Its arch came out lumpy
##            at every W, so the cave is clay on its own art mesh now (Ramon, 7 Oct: "the dev look mesh
##            seems to struggle because its lower in res maybe. just make it same resolution as art look").
## Animals and characters are never touched (Ramon: "the animals and the npc's those can stay as they
## are in dev mode"); what you use (the rune stone, laptops, pickups) is red.
##
## ART IS HELD for films (they play in the art), in the cave's tunnel and the rooms behind the two
## crossings (Ramon: "leave the cave interior and the cinema alone"), and returns to the chosen look
## after.
##
## THE FIRST SWITCH: a mesh builds its draw buffers the first time it is drawn, so a pen opened in DEV
## would freeze 1.7 s the first time it showed its art. It opens with the art drawn for a few frames
## behind a black curtain, then goes to DEV.
##
## NO class_name (engine_gotchas.md): preloaded by what uses it.

const Blockouts := preload("res://ramon/chickenpen/look/pen_blockouts_4d.gd")
const LabGrid := preload("res://ramon/CreationLab/LabKit/lab_grid.gd")
const PathSpec := preload("res://ramon/CreationLab/PathCreator/path_spec.gd")
const PathDraw := preload("res://ramon/CreationLab/PathCreator/render/path_draw.gd")
## Ours: blockouts, the pen's frame, the curtain.
const OWN := &"_look_own"
const FLOOR_SWATCH := "pen_dev_floor"

## Animals and characters, never touched: Blockouts.CHARACTER.
## What you use, drawn red.
const USED := ["pen_rune_stone", "pen_laptop", "pen_pickup", "pen_pickaxe", "journal_book"]
## Under World and left alone here: the ground, the paths, the grass (each has its own switch), the
## terrain (laid grey), the lights.
const NOT_ART := ["Ground", "Paths", "Grass", "Flock", "Hills", "WestHill", "TowerHill", "MoundA", "MoundB", "MoundC", "MoundD", "MoundE"]
## Laid grey: the mountains, the round hills and layout B's mounds (PenLayout/PLAN_B.md step 39).
const TERRAIN := ["Hills", "WestHill", "TowerHill", "MoundA", "MoundB", "MoundC", "MoundD", "MoundE"]

signal look_changed(dev: bool)
## The dev look laid or lifted, whatever the reason (the player's choice, the art held in the cinema or the
## cave's tunnel, before a save): for what paints itself (lookout/balloon_4d.gd), sent as it happens.
signal applied_changed(on: bool)
## The foundation or the landmark colour changed (set_colours): the NPC rings follow the landmark colour
## (scripts/pen_npc_markers_4d.gd).
signal colours_changed(foundation: Color, landmark: Color)

## THE TWO COLOURS, FROM THE PANEL (Ramon, 7 Oct: "can you add two options in the dev panel that makes me controll
## the orange and the blue in the scene? colorwise", "also add save function so that color gets stored"): the
## FOUNDATION colour (the blue: what the world is built of, rocks, walls, trees, the blockouts) and the LANDMARK colour
## (the orange: the places you go and what you walk on), named so on 7 Oct ("instead of blue and orange, lets do
## 'foundation color' 'landmark color'"); set live (set_colours, the grass panel's swatches, shown in the dev look)
## and kept in look_saved.cfg by the panel's Save settings, beside the grass's; the pen opens with what is saved.
const SAVED := "res://ramon/chickenpen/look/look_saved.cfg"

## Off: the pen exactly as it was, no switch.
@export var enabled: bool = true
## I, not F8: the editor's Stop is F8, and it stopped the game when the game window had focus
## (Ramon, 6 Oct). I is free in the pen and in the editor.
@export var key: Key = KEY_I
## How the pen opens the first time in a session (then it keeps what was last chosen).
@export var opens_in_dev: bool = true
## What the editor shows when the pen is open in it.
@export var editor_dev: bool = false:
	set(v):
		editor_dev = v
		if Engine.is_editor_hint() and is_inside_tree():
			_set_applied(v)
## The Watchstone as three stacked blocks rather than a cylinder.
@export var tower_three_blocks: bool = false:
	set(v):
		tower_three_blocks = v
		_blockouts.clear()
		if _applied:
			_set_applied(false)
			_set_applied(true)
## Per landmark, by node name (see the header).
@export var rules: Dictionary = {
	"Lookout": "block", "CaveHill": "clay", "Oak*": "block", "RockPileSpot": "block", "Bush*": "block", "Shed": "clay",
	"AnaMarsh": {"landmark_colour": [Color(0.64, 0.47, 0.29)],
		"foundation_colour": [Color(0.24, 0.34, 0.36), Color(0.312, 0.394, 0.378), Color(0.16, 0.25, 0.28)],
		"foundation": ["Ring*", "Inner*", "Glint*"], "rest": "drop"},
	"EggCamp": "clay", "Range": "clay", "TrymCabin": "clay", "KataWood": "clay", "OwlTree": "clay", "Scenery": "clay",
	"Pen": "clay", "EggCairn": "clay", "KeeperPost": "clay", "ProfessorPost": "clay",
}

## THE PALETTE (6 Oct, from three measured variants, PenLayout/scripts/_capture_pen_runner.gd lookpalette):
## the pen's light is gentle (its sun 0.34), and the lab's (1.75) clipped a white floor, the mountains
## and the grid to one white. So the light stays at the pen's strength, neutral, and the floor and
## mountains sit a little under white so the grid and the horizon read.
@export_group("Palette")
@export var foundation_colour: Color = Color(0.13, 0.40, 0.86)
@export var used_colour: Color = Color(0.86, 0.24, 0.20)
@export var door_colour: Color = Color(0.05, 0.08, 0.16)
## The LANDMARK COLOUR: what you walk or climb on where a landmark's art is kept in the dev look (the Watchstone's decks, ramps and
## ladder; Ramon, 7 Oct: "the walkplanes for the tower in dev mode should be orange. so its clear").
@export var landmark_colour: Color = Color(0.95, 0.36, 0.10)
## Landmarks drawn in the landmark colour instead of the foundation colour, as a test (Ramon, 7 Oct: "make the pen hut
## orange ... can you make the whole shooting range orange as test, and the chicken pen too. and the campsite that
## gets revealed, and trym's house"), by the name their rule is found on.
@export var orange_units: PackedStringArray = PackedStringArray(["Range", "Pen", "EggCamp", "TrymCabin", "Shed"])
## Parts of a character drawn as one blockout box in the dev look, by path under World, though characters are
## otherwise never touched (Ramon, 9 Oct: "lets make the dev version one box instead of the detailed shelve").
## Trym's bookcase is the 4D shelf, 345 meshes (336 books), and with projection (P) on, the dev look drew more
## meshes than the engine holds ("Too many instances using shader instance variables"). Its art is left as it
## is: the dev look only takes its meshes off and puts them back.
@export var boxed_in_dev: PackedStringArray = PackedStringArray(["TrymCabin/Trym/Bookshelf"])
@export var terrain_colour: Color = Color(0.62, 0.64, 0.67)
@export var floor_colour: Color = Color(0.74, 0.75, 0.77)
@export var floor_line: Color = Color(0.62, 0.63, 0.66)
@export var floor_subline: Color = Color(0.69, 0.70, 0.72)
@export var sky_top: Color = Color(0.56, 0.66, 0.80)
@export var sky_horizon: Color = Color(0.86, 0.88, 0.91)
@export var sky_bottom: Color = Color(0.74, 0.75, 0.76)
@export var ambient: Color = Color(0.38, 0.40, 0.44)
@export_range(0.0, 1.0, 0.01) var ambient_sky: float = 0.25
@export var key_colour: Color = Color(1.0, 0.97, 0.92)
@export_range(0.0, 4.0, 0.01) var key_energy: float = 0.4
@export var key_angles: Vector2 = Vector2(50.0, -35.0)
@export var fill_colour: Color = Color(0.80, 0.87, 1.0)
@export_range(0.0, 2.0, 0.01) var fill_energy: float = 0.18
@export var fill_angles: Vector2 = Vector2(25.0, 145.0)
@export_range(0.2, 3.0, 0.01) var exposure: float = 1.0

## The look chosen this session ("" until one is), kept across the pen being loaded again.
static var session: String = ""
## The Look in charge, for others to go through (assign_mesh).
static var current = null

## The look the player chose (true DEV).
var dev: bool = false
var _applied: bool = false
var _hold: String = ""
var _room: Node
var _world: Node4D
var _saved_mesh: Dictionary = {}
var _saved_mat: Dictionary = {}
var _saved_on: Dictionary = {}
var _saved_env: Dictionary = {}
var _blockouts: Dictionary = {}
var _block_nodes: Array = []
var _pen_frame: MeshInstance4D
var _mats: Dictionary = {}
## The coarse meshes "low_mesh" rules show, by path.
var _lows: Dictionary = {}
var _note: Label
var _note_left: float = 0.0
var _ready_done: bool = false


func _ready() -> void:
	_room = owner if owner != null else get_parent().get_parent()
	_world = _room.get_node_or_null("World") as Node4D
	if _world == null or not enabled:
		return
	if Engine.is_editor_hint():
		if editor_dev:
			_set_applied.call_deferred(true)
		return
	current = self
	_load_colours()
	# Awake while the crossings put the pen to sleep (they switch Systems off), so the art is put back
	# for the rooms behind them and the dev look laid again on the way home.
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_on_node_added)
	dev = _start_dev()
	_note_layer()
	if dev:
		_warm_then_dev()
	else:
		_ready_done = true


## The foundation and the landmark colour, now: everything already laid in them recoloured in place (they share
## materials).
func set_colours(foundation: Color, landmark: Color) -> void:
	foundation_colour = foundation
	landmark_colour = landmark
	for key in _mats:
		var m := _mats[key] as TetraMaterial4D
		if String(key) in ["foundation", "blue"]:
			m.albedo_color = foundation
		elif String(key) in ["landmark", "orange"]:
			m.albedo_color = landmark
	colours_changed.emit(foundation, landmark)


## The two colours into look_saved.cfg. OK or the error.
func save_colours() -> int:
	var cfg := ConfigFile.new()
	cfg.set_value("look", "foundation", foundation_colour)
	cfg.set_value("look", "landmark", landmark_colour)
	return cfg.save(SAVED)


## Whether what is saved is what shows (nothing saved: false).
func colours_match_saved() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(SAVED) != OK:
		return false
	return cfg.get_value("look", "foundation", foundation_colour) == foundation_colour and cfg.get_value("look", "landmark", landmark_colour) == landmark_colour


func _load_colours() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVED) != OK:
		return
	foundation_colour = cfg.get_value("look", "foundation", foundation_colour)
	landmark_colour = cfg.get_value("look", "landmark", landmark_colour)


## The look to open in: PEN_LOOK in the environment or look= on the command line (tests), art for a
## film asked for by the menu, the session's last choice, else opens_in_dev.
func _start_dev() -> bool:
	var asked: String = OS.get_environment("PEN_LOOK")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("look="):
			asked = a.substr(5)
	if asked == "dev" or asked == "art":
		return asked == "dev"
	if get_tree().root.has_meta(&"pen_cinematic") and String(get_tree().root.get_meta(&"pen_cinematic")) != "":
		return false
	if session != "":
		return session == "dev"
	return opens_in_dev


## The art drawn for a few frames under a black curtain, then DEV (see the header).
func _warm_then_dev() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 120
	layer.set_meta(OWN, true)
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(black)
	add_child(layer)
	for k in 4:
		await get_tree().process_frame
	_ready_done = true
	_update()
	await get_tree().process_frame
	await get_tree().process_frame
	layer.queue_free()


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not enabled or _world == null or not _ready_done:
		return
	_update()
	if _note_left > 0.0:
		_note_left -= delta
		if _note_left <= 0.0 and _note != null:
			_note.visible = false


## Why the art is held now, or "": a film, the cave's tunnel, the rooms behind the crossings.
func _hold_reason() -> String:
	var films: Node = _room.get_node_or_null("Cinematics")
	if films != null and films.has_method("is_playing") and bool(films.call("is_playing")):
		return "film"
	for path in ["Crossing", "CaveCrossing"]:
		var c: Node = _room.get_node_or_null(path)
		if c != null and c.has_method("is_away") and bool(c.call("is_away")):
			return "away"
	var fade: Node = _room.get_node_or_null("Systems/CaveFade")
	if fade != null and fade.has_method("_into_the_hill") and fade.get("_player") != null and fade.get("_hill") != null \
			and float(fade.call("_into_the_hill")) > 0.12:
		return "cave"
	return ""


func _update() -> void:
	_hold = _hold_reason()
	var want: bool = dev and _hold == ""
	if want != _applied:
		_set_applied(want)


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not enabled or not (event is InputEventKey):
		return
	var k := event as InputEventKey
	if not k.pressed or k.echo or k.keycode != key or k.ctrl_pressed or k.alt_pressed or k.shift_pressed:
		return
	set_dev(not dev)
	get_viewport().set_input_as_handled()


## The player's choice (the key and the panel's Look row): true the dev look.
func set_dev(on: bool) -> void:
	dev = on
	session = "dev" if on else "art"
	_update()
	_say(("Dev Mode   " if on else "Art Mode   ") + OS.get_keycode_string(key) + ("   (art held: " + _hold + ")" if on and _hold != "" else ""))
	look_changed.emit(on)


## The dev look built again (after a palette or rule change), if it is on.
func reapply() -> void:
	if _applied:
		_blockouts.clear()
		_set_applied(false)
		_set_applied(true)


## Sets [param mi]'s mesh, or, while the dev look has taken it off, the one it puts back
## (pen_grass_4d.gd swapping the terrain's bakes goes through here).
static func assign_mesh(mi: MeshInstance4D, mesh: Mesh4D) -> void:
	if current != null and is_instance_valid(current) and current._saved_mesh.has(mi):
		current._saved_mesh[mi] = mesh
	else:
		mi.mesh = mesh


## The mesh a node really has, while the dev look has taken it off.
static func own_mesh(mi: MeshInstance4D) -> Mesh4D:
	if current != null and is_instance_valid(current) and current._saved_mesh.has(mi):
		return current._saved_mesh[mi]
	return mi.mesh


## The material a node really has, under any the dev look laid over it.
static func own_material(mi: MeshInstance4D) -> Material4D:
	if current != null and is_instance_valid(current) and current._saved_mat.has(mi):
		return current._saved_mat[mi]
	return mi.material_override


# --- Applying -------------------------------------------------------------------------------------

func _set_applied(on: bool) -> void:
	if _world == null:
		return
	var started: int = Time.get_ticks_usec()
	if on:
		_apply_dev()
	else:
		_restore()
	_applied = on
	applied_changed.emit(on)
	if not Engine.is_editor_hint():
		print("LOOK %s: %.1f ms%s" % ["dev" if on else "art", (Time.get_ticks_usec() - started) / 1000.0, (" (held: %s)" % _hold) if _hold != "" else ""])


func _apply_dev() -> void:
	var runtime: bool = not Engine.is_editor_hint()
	if runtime:
		_environment(true)
		_ground(true)
		_paths(true)
		_switches(true)
		_frame_pen(true)
	for t in TERRAIN:
		var hill := _world.get_node_or_null(t) as MeshInstance4D
		if hill != null:
			_lay(hill, _mat("terrain", terrain_colour))
	# The blockouts first, while the art they stand for still has its meshes to measure.
	var meshes: Array = _art_meshes()
	for mi in meshes:
		var r: Array = _rule_of(mi)
		if r[0] is String and String(r[0]) == "block" and _role(mi) == "landmark":
			_blockout(r[1])
	for part in _boxed_parts():
		_blockout(part)
	for mi in meshes:
		_take(mi)


## Everything under World and the pen enclosure that draws, but not this look's own.
func _art_meshes() -> Array:
	var out: Array = []
	var roots: Array = [_world]
	var pen: Node = _room.get_node_or_null("Pen")
	if pen != null:
		roots.append(pen)
	for r in roots:
		if r is MeshInstance4D:
			out.append(r)
		for node in (r as Node).find_children("*", "MeshInstance4D", true, false):
			if not node.has_meta(OWN):
				out.append(node)
	return out


## A mesh into the dev look by its rule: taken off, laid over, or left.
func _take(mi: MeshInstance4D) -> void:
	if mi.has_meta(OWN) or _saved_mesh.has(mi) or _saved_mat.has(mi):
		return
	# Under a part boxed in the dev look (boxed_in_dev): its box shows instead, whatever its owner.
	for part in _boxed_parts():
		if part == mi or part.is_ancestor_of(mi):
			_strip(mi)
			return
	var role: String = _role(mi)
	if role == "" or role == "art":
		return
	if role == "used":
		_lay(mi, _mat("used", used_colour))
		return
	var r: Array = _rule_of(mi)
	var rule: Variant = r[0]
	if rule is Dictionary:
		if rule.has("low_mesh") and mi == r[1]:
			var low: Mesh4D = _low(String(rule["low_mesh"]))
			if low != null and mi.visible:
				_saved_mesh[mi] = mi.mesh
				mi.mesh = low
			_lay(mi, _mat("foundation", foundation_colour))
			return
		var part: String = String(mi.name)
		var c: Color = _albedo(mi)
		if _matches(part, rule.get("keep", [])) or _colour_in(c, rule.get("keep_colour", [])):
			return
		if _matches(part, rule.get("landmark", [])) or _colour_in(c, rule.get("landmark_colour", [])):
			_lay(mi, _mat("landmark", landmark_colour))
			return
		if _matches(part, rule.get("foundation", [])) or _colour_in(c, rule.get("foundation_colour", [])):
			_lay(mi, _mat("foundation", foundation_colour))
			return
		if String(rule.get("rest", "")) == "drop":
			_strip(mi)
			return
		if _matches(part, rule.get("drop", [])) or _colour_in(c, rule.get("drop_colour", [])) \
				or (bool(rule.get("drop_green", false)) and _plant_green(c)):
			_strip(mi)
			return
		_lay(mi, _mat("foundation", foundation_colour))
		return
	match String(rule):
		"art":
			return
		"block":
			# Art the landmark keeps under its blockout, tagged by its builder (the Watchstone's timber,
			# lookout/watchstone_4d.gd): the walkways, the ladder and the scaffold.
			# All of it orange since 7 Oct (Ramon: "make all scaffold orange on the tower").
			if mi.has_meta(&"dev_walk") or mi.has_meta(&"dev_frame"):
				_lay(mi, _mat("landmark", landmark_colour))
			elif _blockouts.has(r[1]):
				_strip(mi)
			else:
				_lay(mi, _mat("foundation", foundation_colour))
		_:
			if r[1] is Node and String((r[1] as Node).name) in orange_units:
				_lay(mi, _mat("landmark", landmark_colour))
			else:
				_lay(mi, _mat("foundation", foundation_colour))


## The parts [member boxed_in_dev] names that are in the pen.
func _boxed_parts() -> Array:
	var out: Array = []
	for path in boxed_in_dev:
		var part := _world.get_node_or_null(NodePath(path)) as Node4D
		if part != null:
			out.append(part)
	return out


## "character" (never touched), "used" (red), "landmark", or "" for what is not art at all.
func _role(mi: Node) -> String:
	var n: Node = mi
	var used: bool = false
	while n != null and n != _room:
		if n is CharacterBody4D or n is RigidBody4D:
			return ""
		if n.get_parent() == _world and String(n.name) in NOT_ART:
			return ""
		var tags: String = n.scene_file_path.get_file()
		if n.get_script() != null:
			tags += " " + (n.get_script() as Script).resource_path.get_file()
		for c in Blockouts.CHARACTER:
			if tags.contains(c):
				return ""
		for u in USED:
			if tags.contains(u):
				used = true
		n = n.get_parent()
	return "used" if used else "landmark"


## [rule, the node it was found on]: the nearest node up from [param mi] named in [member rules],
## else clay and the mesh's unit.
func _rule_of(mi: Node) -> Array:
	var n: Node = mi
	var unit: Node = mi
	while n != null and n != _room and n != _world:
		var key: String = _rule_key(String(n.name))
		if key != "":
			return [rules[key], n]
		unit = n
		n = n.get_parent()
	return ["clay", unit]


## The [member rules] key for a node called [param name]: its own name, or a key ending in * that its
## name starts with (copies: Oak, Oak2, OakLite), or "" for none.
func _rule_key(name: String) -> String:
	if rules.has(name):
		return name
	for k in rules:
		var s: String = String(k)
		if s.ends_with("*") and name.begins_with(s.trim_suffix("*")):
			return s
	return ""


## The colour a part is drawn in (its material's), or clear when it has none to read.
static func _albedo(mi: MeshInstance4D) -> Color:
	var m := mi.material_override as TetraMaterial4D
	return m.albedo_color if m != null else Color(0, 0, 0, 0)


static func _colour_in(c: Color, colours: Array) -> bool:
	if c.a <= 0.0:
		return false
	for k in colours:
		var o: Color = k
		if absf(c.r - o.r) < 0.02 and absf(c.g - o.g) < 0.02 and absf(c.b - o.b) < 0.02:
			return true
	return false


## Green as plants are: more green than red and clearly more than blue, with some colour to it
## (water's teal and the grey stones are not).
static func _plant_green(c: Color) -> bool:
	return c.a > 0.0 and c.g > c.r * 1.05 and c.g > c.b * 1.1 and maxf(c.r, maxf(c.g, c.b)) - minf(c.r, minf(c.g, c.b)) > 0.08


static func _matches(part: String, patterns: Array) -> bool:
	for p in patterns:
		var s: String = String(p)
		if s.ends_with("*") and part.begins_with(s.trim_suffix("*")):
			return true
		if part == s:
			return true
	return false


## Its mesh taken off, kept to put back. Never a hidden one: hidden parts are what their owners keep
## for later (the Watchstone's stones, merged at run time from their meshes); a hidden part is only
## ever recoloured, so the shed's roof comes back in clay if it was open when the look switched.
func _strip(mi: MeshInstance4D) -> void:
	if not mi.visible:
		return
	_saved_mesh[mi] = mi.mesh
	mi.mesh = null


func _lay(mi: MeshInstance4D, m: Material4D) -> void:
	if _saved_mat.has(mi):
		return
	_saved_mat[mi] = mi.material_override
	mi.material_override = m


## A "low_mesh" rule's mesh, loaded once; null (the art stays, in clay) if it has not been baked.
func _low(path: String) -> Mesh4D:
	if not _lows.has(path):
		_lows[path] = load(path) as Mesh4D if ResourceLoader.exists(path) else null
	return _lows[path]


func _mat(key: String, colour: Color) -> TetraMaterial4D:
	if not _mats.has(key) or (_mats[key] as TetraMaterial4D).albedo_color != colour:
		var m := TetraMaterial4D.new()
		m.albedo_color = colour
		_mats[key] = m
	return _mats[key]


## [param root]'s blockout, built once and shown (look/pen_blockouts_4d.gd), as children of the
## landmark itself: they move with it, and the editor picks the landmark when one is clicked.
## Never saved: they have no owner.
func _blockout(root: Node) -> void:
	if not (root is Node4D):
		return
	if not _blockouts.has(root):
		var shapes: Dictionary = Blockouts.shapes_for(root as Node4D, tower_three_blocks)
		if shapes.is_empty():
			shapes = Blockouts.one_box(root as Node4D)
		_blockouts[root] = Blockouts.bake(shapes)
	var baked: Dictionary = _blockouts[root]
	if baked.is_empty():
		return
	for colour in baked:
		var mi := MeshInstance4D.new()
		mi.name = "DevBlockout_" + String(colour)
		mi.set_meta(OWN, true)
		mi.mesh = baked[colour]
		mi.material_override = _mat(colour, {"blue": foundation_colour, "red": used_colour, "door": door_colour, "orange": landmark_colour}[colour])
		(root as Node).add_child(mi)
		_block_nodes.append(mi)


func _restore() -> void:
	for mi in _saved_mesh:
		if is_instance_valid(mi) and ((mi as MeshInstance4D).mesh == null or (mi as MeshInstance4D).mesh in _lows.values()):
			(mi as MeshInstance4D).mesh = _saved_mesh[mi]
	_saved_mesh.clear()
	for mi in _saved_mat:
		if is_instance_valid(mi) and (mi as MeshInstance4D).material_override in _mats.values():
			(mi as MeshInstance4D).material_override = _saved_mat[mi]
	_saved_mat.clear()
	for b in _block_nodes:
		if is_instance_valid(b):
			(b as Node).get_parent().remove_child(b)
			(b as Node).queue_free()
	_block_nodes.clear()
	if not Engine.is_editor_hint():
		_frame_pen(false)
		_switches(false)
		_paths(false)
		_ground(false)
		_environment(false)


## Meshes that arrive while the dev look is on (rebuilds, the Watchstone's stone merge, a green
## rebake): into the look as they come, once their builder has set them up.
func _on_node_added(node: Node) -> void:
	if not _applied or not (node is MeshInstance4D) or node.has_meta(OWN):
		return
	if not _world.is_ancestor_of(node) and not (_room.get_node_or_null("Pen") != null and _room.get_node("Pen").is_ancestor_of(node)):
		return
	_take_later.call_deferred(node)


func _take_later(node: Node) -> void:
	if _applied and is_instance_valid(node) and node.is_inside_tree():
		_take(node as MeshInstance4D)


# --- The ground, the paths, the sky ----------------------------------------------------------------

## The floor through the Grass node (it keeps the ground's own mesh and material, and paints it).
func _ground(on: bool) -> void:
	var grass: Node = _world.get_node_or_null("Grass")
	var ground := _world.get_node_or_null("Ground/GroundMesh") as MeshInstance4D
	if grass == null or ground == null or not ("dev_floor" in grass):
		return
	if not on:
		grass.set("dev_floor", null)
		return
	LabGrid.set_swatch(FLOOR_SWATCH, floor_colour, floor_line, floor_subline, 1.0)
	var size := Vector4(120, 2, 120, 120)
	var own: Variant = grass.call("own_ground_mesh") if grass.has_method("own_ground_mesh") else null
	if own is BoxTetraMesh4D:
		size = (own as BoxTetraMesh4D).size
	grass.set("dev_floor", LabGrid.material(FLOOR_SWATCH, size, ground.global_position))


func _paths(on: bool) -> void:
	var paths: Node = _room.get_node_or_null("Systems/Paths")
	if paths == null or not paths.has_method("set_dev"):
		return
	if on:
		_saved_on["paths_dev"] = bool(paths.call("is_dev"))
		paths.call("set_dev", true)
		# Clean arrows on the floor (Ramon, 6 Oct: "the white under the arrows is not white but the dev
		# look"): no sand strips or pads under them, and the marks' soft edges blend into the floor's grey.
		var net: Node = _world.get_node_or_null("Paths")
		if net != null:
			net.set("show_sand", false)
			net.set("under_color", floor_colour)
	elif _saved_on.has("paths_dev"):
		paths.call("set_dev", bool(_saved_on["paths_dev"]))
		_saved_on.erase("paths_dev")
	# Their sand's ground: the dev look's own (pen_paths_4d.gd asks this node), or the field's again.
	if paths.has_method("_ground_to_paths"):
		paths.call_deferred("_ground_to_paths")


## Art that has its own switch: the grass, the oak's leaves. Put back only if nothing else changed it
## meanwhile (the meadow film turns the grass on for itself).
func _switches(on: bool) -> void:
	var targets: Array = []
	var grass: Node = _world.get_node_or_null("Grass")
	if grass != null:
		targets.append(grass)
	for oak in get_tree().get_nodes_in_group(&"pen_oak"):
		if oak.get("leaves") is Node:
			targets.append(oak.get("leaves"))
	for t in targets:
		if not ("enabled" in t):
			continue
		if on:
			_saved_on[t] = bool(t.get("enabled"))
			t.set("enabled", false)
		elif _saved_on.has(t):
			if bool(t.get("enabled")) == false:
				t.set("enabled", _saved_on[t])
			_saved_on.erase(t)


## The sky and the light: the Creation Lab's bright mood, tuned for a white floor; or the pen's own.
func _environment(on: bool) -> void:
	var env := _world.get_node_or_null("Environment") as WorldEnvironment4D
	var sun := _world.get_node_or_null("Sun") as DirectionalLight4D
	var fill := _world.get_node_or_null("SkyFill") as DirectionalLight4D
	if env == null or sun == null or fill == null:
		return
	if not on:
		for k in _saved_env:
			var parts: PackedStringArray = String(k).split(":")
			_world.get_node(parts[0]).set(parts[1], _saved_env[k])
		_saved_env.clear()
		return
	if _saved_env.is_empty():
		for prop in ["sky_material", "cloud_material", "ambient_light_color", "ambient_light_sky_contribution", "tonemap_exposure"]:
			_saved_env["Environment:" + prop] = env.get(prop)
		for light in ["Sun", "SkyFill"]:
			for prop in ["light_color", "light_energy", "elevation_degrees", "azimuth_degrees", "angular_radius_radians"]:
				_saved_env[light + ":" + prop] = _world.get_node(light).get(prop)
	var sky := GradientSkyMaterial4D.new()
	sky.top_color = sky_top
	sky.horizon_color = sky_horizon
	sky.bottom_color = sky_bottom
	# The gradient sky draws a soft halo round each light (30 degrees by default): a grey blob over the
	# pale dev sky. Kept to a degree.
	sky.sun_angle_max = 1.0
	env.sky_material = sky
	env.cloud_material = null
	env.ambient_light_color = ambient
	env.ambient_light_sky_contribution = ambient_sky
	env.tonemap_exposure = exposure
	sun.light_color = key_colour
	sun.light_energy = key_energy
	sun.set("elevation_degrees", key_angles.x)
	sun.set("azimuth_degrees", key_angles.y)
	fill.light_color = fill_colour
	fill.light_energy = fill_energy
	# The pen's fill is a wide soft light (an 8 degree disc), and the sky draws a disc for every light:
	# against the dusk it vanishes, against the pale dev sky it is a grey blob.
	fill.angular_radius_radians = 0.0
	fill.set("elevation_degrees", fill_angles.x)
	fill.set("azimuth_degrees", fill_angles.y)


## The pen enclosure framed on the floor by the path builder's rectangle (its "H" frame), open on the
## side of the keeper's gate (Ramon: "pen can also stay as is, but then just single color, and
## rectangle icon from the path builder surrounding it").
func _frame_pen(on: bool) -> void:
	if not on:
		if is_instance_valid(_pen_frame):
			_pen_frame.queue_free()
		_pen_frame = null
		return
	var net: Node = _world.get_node_or_null("Paths")
	var pen := _room.get_node_or_null("Pen") as Node4D
	var fence := _room.get_node_or_null("Pen/Fence") as MeshInstance4D
	if net == null or pen == null or fence == null or not net.has_method("sym"):
		return
	var s: int = int(net.call("sym", "H"))
	if s < 0:
		return
	var r: PackedVector4Array = fence.get_rect_bounds_global()
	var centre: Vector4 = r[0] + r[1] * 0.5
	var foot := Vector2(r[1].x, r[1].z)
	var margin: float = 0.35
	var outer: Vector2 = foot + Vector2.ONE * margin * 2.0
	# Drawn at twice the paths' own unit: the frame's corner strokes, sized for a door, are thin round
	# a whole pen seen from across the field.
	var u: float = float(net.call("_u")) * 2.0
	_pen_frame = PathDraw.box(self, "PenFrame", PathDraw.FRAME, Vector4(outer.x + 0.3, PathSpec.BOX_H_M, outer.y + 0.3, 2.4),
		Vector4(centre.x, PathSpec.PROUD_M, centre.z, centre.w))
	_pen_frame.set_meta(OWN, true)
	# On the floor, like the paths: not in the projection's ghost (lookout_4d.gd projection_leaves_out).
	_pen_frame.allow_projection = false
	var ss: Vector2 = PathDraw.sym_size(s)
	PathDraw.set_param(_pen_frame, "frame_sym", s)
	PathDraw.set_param(_pen_frame, "frame_grow", (outer / u - ss) * 0.5)
	PathDraw.set_param(_pen_frame, "frame_round", 0.0)
	# Open toward the keeper, who stands at the gate.
	var keeper := _world.get_node_or_null("KeeperPost") as Node4D
	var to := Vector2(0, 1)
	if keeper != null:
		var d := Vector2(keeper.global_position.x - centre.x, keeper.global_position.z - centre.z)
		to = Vector2(signf(d.x), 0) if absf(d.x) > absf(d.y) else Vector2(0, signf(d.y))
	PathDraw.set_param(_pen_frame, "approach", Vector3(to.x, to.y, 1.6 / u))
	PathDraw.set_param(_pen_frame, "walk", 0.0)
	PathDraw.set_param(_pen_frame, "unit_m", u)
	PathDraw.set_param(_pen_frame, "guide_w", PathSpec.GUIDE_W_M * float(net.get("p_scale")))
	PathDraw.set_param(_pen_frame, "under_color", net.get("under_color"))
	PathDraw.set_param(_pen_frame, "motion", 1.0 if bool(net.get("motion")) else 0.0)
	PathDraw.set_param(_pen_frame, "flow", net.get("flow"))
	# The frame symbol is drawn in the sheet's white edge and grey muted inks, which vanish on the light
	# dev floor: here they are the landmarks' blue.
	PathDraw.set_param(_pen_frame, "col_edge", foundation_colour)
	PathDraw.set_param(_pen_frame, "col_muted", foundation_colour)


# --- The note, and the editor ---------------------------------------------------------------------

func _note_layer() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 60
	layer.set_meta(OWN, true)
	add_child(layer)
	_note = Label.new()
	_note.add_theme_font_size_override("font_size", 15)
	_note.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.92))
	_note.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.7))
	_note.add_theme_constant_override("outline_size", 5)
	_note.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_note.position.y = 96.0
	_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_note.visible = false
	layer.add_child(_note)


func _say(text: String) -> void:
	if _note == null:
		return
	_note.text = text
	_note.visible = true
	_note_left = 1.6


## Saving the scene in the editor never stores the dev look: the art goes back first, the look comes
## back after.
func _notification(what: int) -> void:
	if not Engine.is_editor_hint():
		return
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		before_save()
	elif what == NOTIFICATION_EDITOR_POST_SAVE:
		after_save()


## The art put back for a save (the editor calls it; look/_verify_look_runner.gd too).
func before_save() -> void:
	if _applied:
		_restore()
		_applied = false
		applied_changed.emit(false)
		set_meta(&"_look_resave", true)


func after_save() -> void:
	if has_meta(&"_look_resave"):
		remove_meta(&"_look_resave")
		_set_applied(true)


func _exit_tree() -> void:
	if current == self:
		current = null
