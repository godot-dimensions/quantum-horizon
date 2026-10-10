@tool
extends Node4D

## THE PHASE MAZE, REMADE (Ramon, 8 Oct 2026: "phaze maze remake ... rethink the gameplay, and rethink
## what's possible with the tech we have now ... build in a new tscn"). The plan, its 80 steps and the
## evening research are PLAN.md and RESEARCH.md beside this file; the handover is
## follow_up/phase_maze_remake.md. The old Phase Maze (ramon/PhaseMaze/) is untouched.
##
## THE IDEA. The old maze was flat, with three gaps hidden at certain W values: W as a combination lock.
## Here the cells run along x, z AND w, and every view through a cell is an ordinary flat maze. Level, you
## see the x-z maze; turn what is ahead into W (F) and you see another flat maze, with the corridors that
## were hidden running straight ahead of you. Stepping through W without turning (Q, E) works too, but
## slowly and blind: Andrew's step, at 0.3 of the run. The difference is the lesson.
##
## THIS NODE: the lobby (the console and the teaching wall), the levels (built in code, freed on the next
## one), the clock and the counts, breadcrumbs, hints, the finish, and the keys. The walker and his camera
## are maze/maze_walker_build.gd and maze/maze_view_4d.gd; 4D sight is maze/maze_sight_4d.gd.
##
## NO class_name (engine_gotchas.md).

const Style := preload("res://ramon/PhaseMazeRemake/maze/maze_style.gd")
const Lattice := preload("res://ramon/PhaseMazeRemake/maze/maze_lattice.gd")
const Builder := preload("res://ramon/PhaseMazeRemake/maze/maze_builder_4d.gd")
const WalkerBuild := preload("res://ramon/PhaseMazeRemake/maze/maze_walker_build.gd")
const View := preload("res://ramon/PhaseMazeRemake/maze/maze_view_4d.gd")
const Sight := preload("res://ramon/PhaseMazeRemake/maze/maze_sight_4d.gd")
const Console := preload("res://ramon/PhaseMazeRemake/maze/maze_console_4d.gd")
const Hud := preload("res://ramon/PhaseMazeRemake/hud/maze_hud.gd")
const MapPanel := preload("res://ramon/PhaseMazeRemake/hud/maze_map.gd")
const DevPanel := preload("res://ramon/PhaseMazeRemake/hud/maze_dev_panel.gd")
const PanelSource := preload("res://ramon/PhaseMazeRemake/maze/maze_panel_source.gd")
const Journey := preload("res://ramon/PhaseMazeRemake/maze/maze_journey_4d.gd")
const GB := preload("res://ramon/PhaseMazeRemake/carried/walker/ground_basis_4d.gd")
const LabRoom := preload("res://ramon/PhaseMazeRemake/carried/LabKit/lab_room_4d.gd")
const ReturnButton := preload("res://ramon/Demo/return_button.tscn")
const LabPrint := preload("res://ramon/PhaseMazeRemake/carried/LabKit/lab_print.gd")
const LabGrid := preload("res://ramon/PhaseMazeRemake/carried/LabKit/lab_grid.gd")
const LabBatch := preload("res://ramon/PhaseMazeRemake/carried/LabKit/lab_batch.gd")
const LabMaterials := preload("res://ramon/PhaseMazeRemake/carried/LabKit/lab_materials.gd")
const Kit := preload("res://ramon/PhaseMazeRemake/carried/kit/kit_style.gd")
const Escape := preload("res://ramon/PhaseMazeRemake/hud/maze_escape.gd")
const KeyCard := preload("res://ramon/PhaseMazeRemake/hud/maze_key_card.gd")

const CELL := 6.0
const BESTS := "user://phase_maze_remake_bests.cfg"
const LEVELS := [
	{"file": "res://ramon/PhaseMazeRemake/levels/level_1.txt", "glyph": "step", "reward": "chickens",
		"intro": "Find the dead end with the blue mark. Hold E there to step through W."},
	{"file": "res://ramon/PhaseMazeRemake/levels/level_2.txt", "glyph": "turn", "reward": "chickens",
		"intro": "A shaft runs three cells through W. Press F to turn it ahead of you."},
	{"file": "res://ramon/PhaseMazeRemake/levels/level_3.txt", "glyph": "both", "reward": "wolves",
		"intro": "F turns what is ahead into W. Face another way first and a turn shows another maze."},
	{"file": "res://ramon/PhaseMazeRemake/levels/level_4.txt", "glyph": "sealed", "reward": "wolves",
		"intro": "The exit's room is closed on every side. G shows the cells next door in W as ghosts."},
	{"file": "res://ramon/PhaseMazeRemake/levels/level_5.txt", "glyph": "cube", "reward": "dreamer",
		"intro": "Everything together. M opens the map."},
	{"generated": [4, 4, 3], "glyph": "generated", "name": "Generated", "reward": "",
		"intro": "A new maze every run."},
]
## The lobby: its middle, where you stand on arrival, where the console waits. Well away from the maze.
## 18 m wide like the Creation Lab's rooms, so its two live walls stand 9 m from the middle, as far as the
## lab's walls from its exhibit (the range measured the same distance for the same type sizes).
const LOBBY := Vector4(0.0, 0.0, 40.0, 0.0)
const LOBBY_SPAWN := Vector4(0.0, 0.1, 44.6, 0.0)
## The console's fixed places (round 3: it stands still). In the lobby: the back left corner, between
## the Phase Maze wall (west) and the back wall, 2.6 m off the one and 3 m off the other, out of the
## line from where you arrive to the back wall, turned to face where you arrive. In the hall: ahead and
## to the right of where you arrive, facing you.
const CONSOLE_HOME := Vector4(-6.4, 0.0, 35.0, 0.0)
const CONSOLE_HALL := Vector4(3.0, 0.0, -214.6, 0.0)
const RENDERERS := ["Cross-section", "Combined", "Projected", "Wireframe Canvas"]

var player: CharacterBody4D
var rig: Node4D
var camera: Camera4D
var avatar: Node4D
var view: Node
var sight: Node
var console: Node4D
var hud: Control
var map: Control
var dev_panel: PanelContainer
## Esc's confirm box, on the root (hud/maze_escape.gd says why).
var escape: CanvasLayer
## The blue plate's key card (hud/maze_key_card.gd), and the glow that lights the plate you stand on.
var key_card: Control
var _plate_glow: MeshInstance4D
## How many times the big card has been shown this session: the first few plates get it, later ones
## only the lit F row on the keys strip.
var _cards_shown: int = 0
var _card_cell := Vector3i(-1, -1, -1)
var _glow_cell := Vector3i(-1, -1, -1)
const CARD_TIMES := 3
var tuning: Dictionary = {}
## Every colour in force (Tab, Colours; hud/maze_dev_panel.gd COLOURS), saved with the numbers.
var colours: Dictionary = {}
## Runners switch this off so a bot's times never become your bests.
var keep_bests: bool = true

## "lobby", "playing" or "finished".
var state: String = "lobby"
var level_index: int = 0
var sel: int = 0
var lattice: RefCounted
var built: Dictionary = {}
var level_node: Node4D
var generated_seed: int = 1
var time: float = 0.0
var running: bool = false
var w_moves: int = 0
var turns: int = 0
var visited: Dictionary = {}
var done: Dictionary = {}
var bests: Dictionary = {}
## Each level's last run, for the research wall: {index: {time, w_moves, turns, hints}}.
var results: Dictionary = {}
var hints_used: int = 0
var panel_source: Node
var _art: Array = []
## The journey (round 2): the overlook and its lift, the reward hall, the stage-complete beat.
var overlook: Dictionary = {}
var on_overlook: bool = false
var _lift_wait: float = 0.0
var _lifting: bool = false
var hall: Dictionary = {}
var _reward: Node4D
var _reward_t: float = 0.0
## Seconds into the stage-complete beat (negative: none).
var _cinema: float = -1.0
## After the beat, the camera keeps circling slowly until you move (Ramon, 9 Oct: "the camera in a new
## shot also rotates like this little game moment. docile, but still cool for reading the stats as
## transparent overlay").
var _orbit: bool = false
var _orbit_out: float = 0.0

var _visit_count: int = 0
var _last_cell := Vector3i.ZERO
var _hint_tier: int = 0
var _hint_node: Node4D
var _hint_left: float = 0.0
var _busy: bool = false
var _w_step: float = 0.3
var _par: int = 0
var _names: Dictionary = {}
## Prompts already shown in this level (PLAN.md step 60: the first time something is useful, not again).
var _prompted: Dictionary = {}


func _enter_tree() -> void:
	Style.remember()
	# The saved colours before anything is built (the walker's are painted once he exists).
	apply_colours(DevPanel.load_saved_colours())
	Style.apply()
	var light: Node = get_node_or_null("Light")
	if light != null:
		light.set("mood_overrides", {"bright": Style.LIGHT.duplicate(true)})


func _exit_tree() -> void:
	Style.restore()


func _ready() -> void:
	var light: Node = get_node_or_null("Light")
	if light != null:
		# B switches bright and dark, as in the Creation Lab; the choice is the viewer's, remembered.
		light.call("set_mood", String(light.get("mood")), true, false)
		light.connect("mood_changed", func(m: String) -> void:
			Style.apply_mood(m)
			_apply_spot())
		Style.apply_mood(String(light.get("mood")))
	if Engine.is_editor_hint():
		return
	var w: Dictionary = WalkerBuild.make(self, LOBBY_SPAWN)
	player = w["body"]
	rig = w["rig"]
	camera = w["camera"]
	avatar = w["avatar"]
	view = Node.new()
	view.name = "View"
	view.set_script(View)
	view.set("body", player)
	view.set("rig", rig)
	view.set("camera", camera)
	view.set("avatar", avatar)
	add_child(view)
	view.connect("turn_started", func(kind: String) -> void:
		if kind == "into_w" and state == "playing":
			turns += 1
			_prompt("turn", "Turned into W. What was ahead is W now, and the blue walls stand across it. F turns back."))
	sight = Node.new()
	sight.name = "Sight"
	sight.set_script(Sight)
	sight.set("camera", camera)
	sight.set("body", player)
	sight.set("view", view)
	add_child(sight)
	console = Node4D.new()
	console.name = "Console"
	console.set_script(Console)
	console.set("home", CONSOLE_HOME)
	console.set("player", player)
	console.set("frame", view)
	var hall_arrive: Vector4 = Journey.HALL_AT + Vector4(0.0, 0.0, 8.0, 0.0)
	console.set("spots", {
		"lobby": [CONSOLE_HOME, atan2(LOBBY_SPAWN.x - CONSOLE_HOME.x, LOBBY_SPAWN.z - CONSOLE_HOME.z)],
		"near": [CONSOLE_HALL, atan2(hall_arrive.x - CONSOLE_HALL.x, hall_arrive.z - CONSOLE_HALL.z)],
	})
	add_child(console)
	var layer := CanvasLayer.new()
	layer.name = "HUD"
	add_child(layer)
	hud = Control.new()
	hud.name = "Hud"
	hud.set_script(Hud)
	hud.set("view", view)
	hud.set("body", player)
	layer.add_child(hud)
	hud.set("camera", camera)
	key_card = Control.new()
	key_card.name = "KeyCard"
	key_card.set_script(KeyCard)
	layer.add_child(key_card)
	map = Control.new()
	map.name = "Map"
	map.set_script(MapPanel)
	map.set("view", view)
	map.set("body", player)
	layer.add_child(map)
	dev_panel = PanelContainer.new()
	dev_panel.name = "DevPanel"
	dev_panel.set_script(DevPanel)
	dev_panel.set("maze_root", self)
	layer.add_child(dev_panel)
	# The lobby's two walls read the game live (the kit's panel source contract).
	panel_source = Node.new()
	panel_source.name = "PanelSource"
	panel_source.set_script(PanelSource)
	panel_source.set("maze", self)
	add_child(panel_source)
	var pair: Node = get_node_or_null("WallPanels")
	if pair != null:
		pair.set("source", pair.get_path_to(panel_source))
	var rb: Node = ReturnButton.instantiate()
	rb.name = "ReturnButton"
	add_child(rb)
	# Esc asks before it leaves (round 3). On the root, after the menu, so it hears Esc first.
	escape = CanvasLayer.new()
	escape.name = "PhaseMazeEscape"
	escape.set_script(Escape)
	escape.set("maze_root", self)
	get_tree().root.add_child.call_deferred(escape)
	tree_exiting.connect(func() -> void:
		if is_instance_valid(escape):
			escape.queue_free())
	_load_bests()
	WalkerBuild.recolour(avatar, _walker_colours())
	hall = Journey.hall(self)
	apply_tuning(DevPanel.load_saved())
	go_lobby(true)
	_paint_lobby_wall()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# -- the lobby and the levels --------------------------------------------------------------------------

func go_lobby(instant: bool = false) -> void:
	if _busy:
		return
	_busy = true
	if not instant:
		await _fade_to(1.0, 0.22)
	_clear_level()
	state = "lobby"
	hud.set("result", {})
	_place_player(LOBBY_SPAWN, Vector4(0, 0, -1, 0))
	# Looking at the wall and the console, not down at the floor.
	rig.set("pitch", deg_to_rad(-7.0))
	rig.call("_apply")
	player.set("w_speed_scale", 0.0)
	console.visible = true
	console.set("room", [])
	console.call("show_data", _console_data("lobby"))
	console.call("snap")
	if not instant:
		await _fade_to(0.0, 0.3)
	_busy = false


func start_level(i: int, new_seed: bool = true) -> void:
	if _busy:
		return
	_busy = true
	# Playing looks with the mouse; choosing a level may have freed the cursor (round 3). Only here, the
	# player's way in: runners load levels with _load_level and keep the mouse free.
	if dev_panel == null or not dev_panel.visible:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await _fade_to(1.0, 0.22)
	_load_level(i, new_seed)
	await _fade_to(0.0, 0.3)
	_busy = false


## Builds level `i` at once (no fade): runners call this.
func _load_level(i: int, new_seed: bool = true) -> void:
	_clear_level()
	level_index = i
	sel = i
	var spec: Dictionary = LEVELS[i]
	if spec.has("generated"):
		if new_seed:
			generated_seed = randi() % 100000
		var g: Array = spec["generated"]
		lattice = Lattice.generate(int(g[0]), int(g[1]), int(g[2]), generated_seed)
	else:
		lattice = Lattice.load_file(String(spec["file"]))
	lattice.fit_origin()
	level_node = Node4D.new()
	level_node.name = "Level"
	add_child(level_node)
	built = Builder.build(level_node, lattice)
	_par = lattice.par_w()
	hud.set("beacon_top", built.get("beacon_top", Vector4.INF))
	# The glow that lights the blue plate you stand on (parked under the floor until then).
	var pg := BoxTetraMesh4D.new()
	pg.size = Vector4(2.5, 0.04, 2.5, 1.0)
	_plate_glow = MeshInstance4D.new()
	_plate_glow.name = "PlateGlow"
	_plate_glow.mesh = pg
	_plate_glow.material_override = Style.glow_material("w", 1.6)
	_plate_glow.set("allow_projection", false)
	_plate_glow.position = Vector4(0.0, Builder.PARKED_Y, 0.0, 0.0)
	level_node.add_child(_plate_glow)
	_card_cell = Vector3i(-1, -1, -1)
	_glow_cell = Vector3i(-1, -1, -1)
	# Level 6, generated: landmarks high over a few cells, each only in its own W layer (round 3,
	# Ramon: "Level 6 was particularly confusing because almost everything looked identical").
	if spec.has("generated"):
		Builder.landmarks(level_node, lattice, generated_seed)
	sight.call("set_level", lattice, built)
	hud.set("lattice", lattice)
	map.set("lattice", lattice)
	# Facing the way on, if it is in the level view; otherwise down the maze (-z).
	var r: Array = lattice.route()
	var face := Vector4(0, 0, -1, 0)
	if r.size() > 1:
		var d: Vector3i = r[1] - r[0]
		if d.z == 0:
			face = Vector4(float(d.x), 0.0, float(d.y), 0.0)
	# The journey's start: high on the overlook over the start cell, looking down over the maze.
	overlook = Journey.overlook(level_node, lattice)
	on_overlook = true
	_lifting = false
	_lift_wait = 0.0
	_place_player(overlook["spawn"], Vector4(0, 0, -1, 0))
	_overlook_framing(true)
	player.set("w_speed_scale", _w_step)
	state = "playing"
	time = 0.0
	running = false
	w_moves = 0
	turns = 0
	visited = {}
	done = {}
	_visit_count = 0
	_last_cell = lattice.start
	_visit(lattice.start)
	_hint_tier = 0
	hints_used = 0
	_prompted = {}
	console.visible = false
	hud.set("result", {})
	var intro: String = String(spec.get("intro", ""))
	if spec.has("generated"):
		intro += " Seed %d." % generated_seed
	hud.call("toast", "%02d  %s.  %s" % [i + 1, _level_name(i), intro], Color.WHITE, 6.0)
	hud.call("show_hint", "The whole maze below. F turns it into another one. Stand in the ring to go down.", 8.0)


func _clear_level() -> void:
	_clear_hint()
	_orbit = false
	_orbit_out = 0.0
	rig.set("collide_with_world", true)
	hud.set("result_glass", 0.86)
	if _reward != null and is_instance_valid(_reward):
		_reward.free()
	_reward = null
	_cinema = -1.0
	on_overlook = false
	_lifting = false
	hud.set("title", {})
	hud.set("plate", {})
	hud.set("beacon_top", Vector4.INF)
	if key_card != null:
		key_card.set("shown", false)
	_plate_glow = null
	if level_node != null:
		level_node.free()
		level_node = null
	built = {}
	lattice = null
	sight.call("set_level", null, {})
	hud.set("lattice", null)
	map.set("lattice", null)
	map.visible = false


func _place_player(at: Vector4, face: Vector4) -> void:
	player.global_position = at
	player.set("linear_velocity", Vector4.ZERO)
	var yaw: float = atan2(-face.x, -face.z)
	rig.basis = Basis4D.from_zx(yaw)
	rig.call("_apply")
	player.set("_facing", atan2(face.x, face.z))
	view.set("_target", null)
	player.set("input_enabled", true)


func _level_name(i: int) -> String:
	if _names.has(i):
		return String(_names[i])
	var spec: Dictionary = LEVELS[i]
	var nm: String = "Level %d" % (i + 1)
	if spec.has("name"):
		nm = String(spec["name"])
	else:
		var f := FileAccess.open(String(spec["file"]), FileAccess.READ)
		if f != null:
			for line in f.get_as_text().split("\n"):
				if line.begins_with("name"):
					nm = line.split("=")[1].strip_edges()
					break
	_names[i] = nm
	return nm


## LEVELS through a call: a const is not a property, so get("LEVELS") from outside comes back null.
func levels() -> Array:
	return LEVELS


## A level's facts for the research wall: name, lesson, size, par (the generated one's only once built).
var _facts: Dictionary = {}


## The research wall's specimen takes one short word (the kit never shrinks it).
const SHORT := ["Step", "Turn", "Both", "Sealed", "Cube", "Random"]


func level_facts(i: int) -> Dictionary:
	var spec: Dictionary = LEVELS[i]
	if spec.has("generated"):
		var g: Array = spec["generated"]
		var cells: String = "%d × %d × %d" % [int(g[0]), int(g[1]), int(g[2])]
		var par: int = _par if (lattice != null and i == level_index) else 0
		return {"name": _level_name(i), "short": SHORT[i], "lesson": "A new maze every run.", "cells": cells, "par": par,
			"meta": "%s CELLS  ·  %s" % [cells, ("PAR W %d  ·  SEED %d" % [par, generated_seed]) if par > 0 else "NEW EACH RUN"]}
	if not _facts.has(i):
		var lv = Lattice.load_file(String(spec["file"]))
		var cells: String = "%d × %d × %d" % [lv.nx, lv.nz, lv.nw]
		_facts[i] = {"name": _level_name(i), "short": SHORT[i], "lesson": String(lv.meta.get("lesson", "")), "cells": cells, "par": lv.par_w(),
			"meta": "%s CELLS  ·  PAR W %d" % [cells, lv.par_w()]}
	return _facts[i]


func _fade_to(v: float, seconds: float) -> void:
	var from: float = float(hud.get("fade"))
	var t: float = 0.0
	while t < seconds:
		await get_tree().process_frame
		t += get_process_delta_time()
		hud.set("fade", lerpf(from, v, clampf(t / seconds, 0.0, 1.0)))
	hud.set("fade", v)


# -- play ----------------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if Engine.is_editor_hint() or player == null:
		return
	_hold_for_panel()
	if state == "playing" and lattice != null:
		_play(delta)
	if _cinema >= 0.0:
		_cinema_step(delta)
	_orbit_step(delta)
	if _reward != null and is_instance_valid(_reward):
		_reward_t += delta
		Journey.circle(_reward, _reward_t)
	if _hint_left > 0.0:
		_hint_left -= delta
		if _hint_left <= 0.0 and _hint_tier >= 3:
			_clear_hint()
	if console.visible:
		_hover = _console_hit().get("button", -1)
		console.call("show_data", _console_data("near" if state == "finished" else "lobby"))
	hud.set("crosshair", console.visible and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)
	hud.set("menu", _menu_prompt())
	var light: Node = get_node_or_null("Light")
	if light != null:
		hud.set("mood", String(light.get("mood")))
	hud.set("info", {"state": state, "number": level_index + 1, "name": _level_name(level_index) if lattice != null else "",
		"time": time, "running": running, "w_moves": w_moves, "par": _par,
		"best": float(bests.get(level_index, 0.0)), "sight": bool(sight.get("on")), "first_person": String(view.get("mode")) == "first"})
	var spot: Node = get_node_or_null("Spot")
	if spot != null and float(tuning.get("spot_follows", 1.0)) > 0.5:
		var p: Vector4 = player.global_position
		# Straight above: an offset along z lit the walker from the hidden side in a turned view.
		spot.set("position", p + Vector4(0.0, float(tuning.get("spot_height", 10.0)), 0.0, 0.0))
		spot.set("aim", Vector3(p.x, p.y, p.z))


func _play(delta: float) -> void:
	var p: Vector4 = player.global_position
	if on_overlook:
		_ride(delta)
		return
	var cell: Vector3i = lattice.cell_at(p)
	var v: Vector4 = player.get("linear_velocity")
	if not running and (Vector3(v.x, v.z, v.w).length() > 0.3 or cell != lattice.start):
		running = true
	if running:
		time += delta
	# Out of the maze or fallen: back to the last cell you were in.
	if p.y < -3.0 or not lattice.inside(cell):
		_place_player(lattice.cell_centre(_last_cell) + Vector4(0.0, 0.1, 0.0, 0.0), -rig.basis.z)
		return
	if cell != _last_cell:
		var d: Vector3i = cell - _last_cell
		if absi(d.x) + absi(d.y) + absi(d.z) == 1 and d.z != 0:
			w_moves += 1
		if d.z != 0 and lattice.inside(cell):
			# A move through W, said where you will see it (round 3: "clearer feedback when a meaningful
			# spatial transition occurs"): the layer's name in its floor colour; the ruler flashes too.
			var note: String = "W LAYER %d OF %d" % [cell.z + 1, lattice.nw]
			if cell.z == lattice.exit.z:
				note += "  ·  THE EXIT'S LAYER"
			hud.call("toast", note, Style.layer_colour(cell.z).lightened(0.35), 2.2)
		var others: Array = lattice.neighbours(_last_cell)
		others.erase(cell)
		var all_done: bool = true
		for o in others:
			if not done.has(o):
				all_done = false
		if all_done and _last_cell != lattice.start:
			done[_last_cell] = true
		_last_cell = cell
		_visit(cell)
		_door_prompt(cell)
		if _hint_tier < 3:
			_clear_hint()
		_hint_tier = 0
	_plate_step(cell, delta)
	_stair_settle(cell)
	var e: Vector4 = lattice.cell_centre(lattice.exit)
	if cell == lattice.exit and Vector2(p.x - e.x, p.z - e.z).length() < 2.2 and absf(p.w - e.w) < 1.6:
		_finish()


## LEVEL AGAIN ON A STAIR THROUGH W (round 3, Ramon: "pressing R while airborne on a descending platform
## can leave the player stuck in mid-air"). A stair through W is a run of steps along W; the walker's
## body has some depth in W, so half way between two steps he rests on the higher one while the level
## slice, cut at his middle, shows the lower: he hangs in the air over a step you cannot see, and the
## way off it is no clearer. When the view comes back level (R, or F back) on such a stair, his W is
## put on the middle of the step he stands on, at most half a step away inside the same cell, so the
## slice shows what holds him up.
var _was_level: bool = true


func _stair_settle(cell: Vector3i) -> void:
	var level_now: bool = int(view.get("hidden_axis")) == 2 and not bool(view.call("is_turning"))
	var arrived: bool = level_now and not _was_level
	_was_level = level_now
	if not arrived or not lattice.inside(cell) or not lattice.stairs.has(cell):
		return
	var st: Array = lattice.stairs[cell]
	if int(st[0]) != 2:
		return
	var e: Vector2 = lattice.stair_ends(cell)
	var n: int = maxi(1, roundi((e.y - e.x) / Builder.STEP))
	var span: float = lattice.size_of(cell).z
	var y: float = player.global_position.y
	var best: int = 0
	var best_d: float = INF
	for q in n:
		var top: float = e.x + (e.y - e.x) * float(q + 1) / float(n)
		if absf(top - y) < best_d:
			best_d = absf(top - y)
			best = q
	var d0: float = span * float(best) / float(n)
	var d1: float = span * float(best + 1) / float(n)
	if int(st[1]) < 0:
		var t0: float = span - d1
		d1 = span - d0
		d0 = t0
	var p: Vector4 = player.global_position
	player.global_position = Vector4(p.x, p.y, p.z, lattice.cell_min(cell).w + (d0 + d1) * 0.5)


## THE BLUE PLATES (round 3, Ramon: "the intended solution essentially requires the player to rotate
## using F, and only while standing on a blue square ... make the blue squares more obviously
## interactive ... provide visual feedback when rotation is available or unavailable"). Standing on one
## (a cell with a door through W) in the level view: the plate under you pulses, F's row on the keys
## strip lights and says the way is here, and the first few times the key card acts it out (F, or Q / E).
## Turned, the card goes: the way through W is ahead. Off a plate, F's row says no door is here.
## Holding Q or E presses its cap on the ruler.
func _plate_step(cell: Vector3i, _delta: float) -> void:
	var up: bool = lattice.inside(cell) and not lattice.stairs.has(cell) and lattice.is_open(cell, 2, 1)
	var down: bool = lattice.inside(cell) and not lattice.stairs.has(cell) and lattice.is_open(cell, 2, -1)
	var on: bool = up or down
	var level_view: bool = int(view.get("hidden_axis")) == 2 and not bool(view.call("is_turning"))
	hud.set("plate", {"up": up, "down": down, "level": level_view} if on else {})
	var ana: float = Input.get_axis(&"move_kata", &"move_ana") if bool(player.get("input_enabled")) else 0.0
	hud.set("stepping", 0 if absf(ana) < 0.1 else (1 if ana > 0.0 else -1))
	if _plate_glow != null:
		if on:
			if cell != _glow_cell:
				_glow_cell = cell
				var at: Vector4 = lattice.cell_centre(cell)
				(_plate_glow.mesh as BoxTetraMesh4D).size = Vector4(2.5, 0.04, 2.5, lattice.size_of(cell).z - 1.0)
				_plate_glow.position = Vector4(at.x, at.y + 0.05, at.z, at.w)
			var pulse: float = 1.0 + 0.9 * (0.5 + 0.5 * sin(float(Time.get_ticks_msec()) / 1000.0 * 5.0))
			(_plate_glow.material_override as TetraMaterial4D).get_cross_section_material_3d().set_shader_parameter("glow_energy", pulse)
		elif _glow_cell.x >= 0:
			_glow_cell = Vector3i(-1, -1, -1)
			_plate_glow.position = Vector4(0.0, Builder.PARKED_Y, 0.0, 0.0)
	# The card: on arriving on a plate in the level view, the first CARD_TIMES times.
	if on and level_view and cell != _card_cell and _cards_shown < CARD_TIMES:
		_card_cell = cell
		_cards_shown += 1
		key_card.set("gestures", [["f_turn", "PRESS F"], ["qe_step", "OR HOLD %s" % ("E" if up else "Q")]])
		key_card.set("line", "F turns it ahead of you. Then walk on.")
	if not on:
		_card_cell = Vector3i(-1, -1, -1)
	key_card.set("shown", on and level_view and cell == _card_cell)


## The overlook: standing in the lift's ring a moment lowers it (and you) into the start cell; the
## clock starts once you are down.
func _ride(delta: float) -> void:
	var lift: Node4D = overlook["lift"]
	var c: Vector4 = lift.global_position
	var p: Vector4 = player.global_position
	if not _lifting:
		var near: bool = Vector2(p.x - c.x, p.z - c.z).length() < 1.3 and player.is_on_floor()
		_lift_wait = _lift_wait + delta if near else 0.0
		if _lift_wait > 0.6:
			_lifting = true
			hud.call("clear_messages")
			_overlook_framing(false)
		return
	var bottom: float = float(overlook["bottom"])
	lift.position.y = move_toward(lift.position.y, bottom, delta * 3.2)
	if lift.position.y <= bottom + 0.001:
		on_overlook = false
		_lifting = false
		_overlook_framing(false)


## Up on the overlook the camera stands high and well back, looking down over the rails at the whole
## maze (the chase framing showed the platform and little else); on the way down it comes back.
func _overlook_framing(on: bool) -> void:
	if String(view.get("mode")) != "chase":
		return
	rig.set("collide_with_world", not on)
	rig.set("_zoom_target", 9.0 if on else float(tuning.get("chase_distance", 3.6)))
	rig.set("_home_pivot", 3.5 if on else float(tuning.get("chase_height", 2.1)))
	rig.set("pitch", deg_to_rad(-31.0 if on else float(tuning.get("chase_pitch", -24.0))))
	rig.call("_apply")


## A visited cell's tile comes up out of the floor, and every tile is recoloured by how recently you
## were there (Ruddle 2005: a trail helps on the first search, then its clutter costs; so old visits fade
## and finished dead ends go grey).
func _visit(cell: Vector3i) -> void:
	visited[cell] = _visit_count
	_visit_count += 1
	var tiles: Dictionary = built.get("tiles", {})
	var floor_col: Color = Style.SWATCHES["maze_floor"][0]
	var trail: Dictionary = {}
	for c in visited:
		var mi: MeshInstance4D = tiles.get(c)
		if mi == null:
			continue
		var age: int = _visit_count - 1 - int(visited[c])
		var f: float = clampf(1.0 - float(age) / 10.0, 0.25, 1.0)
		trail[c] = f
		var at: Vector4 = lattice.cell_centre(c)
		mi.position = Vector4(at.x, at.y + Builder.TILE_Y, at.z, at.w)
		var col: Color = Style.role("done") if done.has(c) else floor_col.lerp(Style.role("trail"), f)
		(mi.material_override as TetraMaterial4D).albedo_color = col
	map.set("trail", trail)
	map.set("done", done)


## Once per level and kind: a toast, the first time it is useful.
func _prompt(kind: String, text: String) -> void:
	if _prompted.has(kind):
		return
	_prompted[kind] = true
	hud.call("toast", text, Style.role("w"), 5.0)


## Standing on a door through W, in the level view: which key takes you through it.
func _door_prompt(cell: Vector3i) -> void:
	if int(view.get("hidden_axis")) != 2:
		return
	var up: bool = lattice.is_open(cell, 2, 1)
	var down: bool = lattice.is_open(cell, 2, -1)
	if up and down:
		_prompt("door", "A door through W, both ways. Hold E to step ana, Q to step kata.")
	elif up:
		_prompt("door", "A door through W. Hold E to step ana.")
	elif down:
		_prompt("door", "A door through W. Hold Q to step kata.")


func _finish() -> void:
	state = "finished"
	running = false
	_clear_hint()
	var best: float = float(bests.get(level_index, 0.0))
	var new_best: bool = best <= 0.0 or time < best
	if new_best and keep_bests:
		bests[level_index] = time
		_save_bests()
	view.call("level")
	results[level_index] = {"time": time, "w_moves": w_moves, "turns": turns, "hints": hints_used}
	var next: int = (level_index + 1) % LEVELS.size()
	sel = next
	hud.set("result", {"title": "%02d  %s" % [level_index + 1, _level_name(level_index)], "time": time,
		"best": float(bests.get(level_index, time)), "new_best": new_best, "w_moves": w_moves, "par": _par,
		"next": "NEXT: %02d  %s" % [next + 1, _level_name(next).to_upper()]})
	_to_hall()


## Out of the maze, into the hall: behind a fade, the stage's reward, then the stage-complete beat (the
## camera pulls up and back so you are small, the title over it), then the card and the console.
func _to_hall() -> void:
	_busy = true
	result_hold = hud.get("result")
	hud.set("result", {})
	await _fade_to(1.0, 0.25)
	hud.call("clear_messages")
	view.call("set_mode", "chase", true)
	_place_player(hall["spawn"], Vector4(0, 0, -1, 0))
	player.set("input_enabled", false)
	var name: String = String(LEVELS[level_index].get("reward", ""))
	if name == "":
		name = ["chickens", "wolves", "dreamer"][generated_seed % 3]
	if _reward != null and is_instance_valid(_reward):
		_reward.free()
	_reward = Journey.reward(self, name, player, rig, camera)
	_reward_t = 0.0
	var next: int = (level_index + 1) % LEVELS.size()
	var next_reward: String = String(LEVELS[next].get("reward", ""))
	Journey.teaser(get_node("Hall"), "%02d  %s" % [next + 1, _level_name(next).to_upper()], next_reward if next_reward != "" else "dreamer")
	console.set("room", hall["room"])
	console.visible = false
	for k in 3:
		await get_tree().process_frame
	await _fade_to(0.0, 0.4)
	_cinema = 0.0
	hud.set("title", {"kicker": "%02d  %s" % [level_index + 1, _level_name(level_index).to_upper()], "text": "STAGE COMPLETE",
		"sub": String(Journey.REWARDS[name]["title"]), "left": 4.5})
	_busy = false


var result_hold: Dictionary = {}


## The beat: 4 s of the camera rising and pulling back, then control, the card and the console.
func _cinema_step(delta: float) -> void:
	_cinema += delta
	var k: float = smoothstep(0.0, 1.0, clampf(_cinema / 3.6, 0.0, 1.0))
	rig.set("_zoom_target", lerpf(3.6, 12.0, k))
	rig.set("distance", lerpf(3.6, 12.0, k))
	rig.set("_home_pivot", lerpf(2.1, 5.0, k))
	rig.set("pitch", lerpf(deg_to_rad(-24.0), deg_to_rad(-11.0), k))
	rig.set("collide_with_world", false)
	rig.call("_apply")
	if _cinema >= 4.2:
		_cinema = -1.0
		player.set("input_enabled", true)
		hud.set("result", result_hold)
		hud.set("result_glass", 0.55)
		console.visible = true
		console.call("show_data", _console_data("near"))
		console.call("snap")
		_orbit = true


## The slow circle after the beat, and handing the camera back once you move.
func _orbit_step(delta: float) -> void:
	if _orbit:
		rig.basis = GB.turned(rig.basis, delta * 0.16)
		rig.call("_apply")
		var moving: bool = false
		for a in [&"move_forward", &"move_back", &"move_left", &"move_right", &"move_ana", &"move_kata"]:
			if Input.is_action_pressed(a):
				moving = true
		if moving:
			_end_orbit()
	elif _orbit_out > 0.0:
		_orbit_out -= delta
		if _orbit_out <= 0.0:
			rig.set("collide_with_world", true)


func _end_orbit() -> void:
	if not _orbit:
		return
	_orbit = false
	_orbit_out = 1.0
	rig.set("_zoom_target", float(tuning.get("chase_distance", 3.6)))
	rig.set("_home_pivot", float(tuning.get("chase_height", 2.1)))
	rig.set("pitch", deg_to_rad(float(tuning.get("chase_pitch", -24.0))))
	rig.call("_apply")
	hud.set("result_glass", 0.86)


func _console_data(anchor: String) -> Dictionary:
	var tiles: Array = []
	for i in LEVELS.size():
		var best: float = float(bests.get(i, 0.0))
		var par: String = "NEW EACH RUN" if LEVELS[i].has("generated") else ""
		tiles.append([str(i + 1), _level_name(i).to_upper(), Hud.clock(best) if best > 0.0 else "", best > 0.0, String(LEVELS[i]["glyph"]), par])
	return {"sel": sel, "tiles": tiles, "start": "NEXT" if state == "finished" else "START", "hover": _hover, "anchor": anchor,
		"live": true, "hint": "PRESS 1 TO 6 OR CLICK A LEVEL, THEN START" if state != "finished" else "WELL DONE. ENTER FOR THE NEXT ONE"}


## The console tile under the crosshair (mouse captured, looking) or under the cursor (mouse free,
## round 3), or {}.
var _hover: int = -1


func _console_hit() -> Dictionary:
	if console == null or not console.visible or camera == null:
		return {}
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		return console.call("pick", camera.global_position, -(camera.global_basis.z).normalized())
	return _pointer_pick(get_viewport().get_mouse_position())


func _pointer_pick(at: Vector2) -> Dictionary:
	var origin: Vector4 = camera.viewport_to_world_ray_origin(at)
	var dir: Vector4 = camera.viewport_to_world_ray_direction(at)
	return console.call("pick", origin, dir)


## The line under the console, in the HUD (round 3, Ramon: "make the action required to start the level
## immediately obvious"): which level is chosen and how to play it, or {} when there is no console.
func _menu_prompt() -> Dictionary:
	if console == null or not console.visible or state == "playing":
		return {}
	var free: bool = Input.mouse_mode != Input.MOUSE_MODE_CAPTURED
	return {"number": sel + 1, "name": _level_name(sel).to_upper(), "next": state == "finished",
		"click": "CLICK START" if free else "AIM AT START AND CLICK", "flash": _sel_flash}


## When the choice last changed, for the prompt's flash.
var _sel_flash: float = -10.0
## A free-cursor click that missed the console (see _input).
var _free_click: InputEvent


# -- hints (T) -----------------------------------------------------------------------------------------

## Three steps, asked for, never offered, and never counted against you (RESEARCH.md section 6): which
## way the way on hides; the next cell lit on the floor and the map; the route for five seconds.
func hint() -> void:
	if state != "playing" or lattice == null:
		return
	var cell: Vector3i = lattice.cell_at(player.global_position)
	var r: Array = lattice.route(cell)
	if r.size() < 2:
		return
	_hint_tier = mini(_hint_tier + 1, 3)
	hints_used += 1
	var next: Vector3i = r[1]
	var axis: int = Lattice.axis_of(cell, next)
	var b: Projection = rig.basis
	var dir := Vector4(float(next.x - cell.x), 0.0, float(next.y - cell.y), float(next.z - cell.z))
	var hidden: int = int(view.get("hidden_axis"))
	_clear_hint()
	match _hint_tier:
		1:
			var text: String
			if axis == hidden:
				var key: String = "E" if dir.dot(b.w) > 0.0 else "Q"
				text = "The way on is through %s, hidden from this view. Turn with F, or step with %s." % [String(Lattice.AXES[axis]).to_upper(), key]
			else:
				var side: float = dir.dot(b.x)
				var ahead: float = dir.dot(-b.z)
				var where: String = "ahead" if ahead > 0.7 else ("behind you" if ahead < -0.7 else ("to your right" if side > 0.0 else "to your left"))
				text = "The way on is %s, in the maze you can see." % where
			hud.call("show_hint", text, 7.0)
		2:
			_mark_cells([next])
			hud.call("show_hint", "The next cell is lit, on the floor and on the map (M).", 6.0)
		3:
			_mark_cells(r.slice(1, mini(r.size(), 10)))
			_hint_left = 5.0
			hud.call("show_hint", "The way out, for five seconds.", 5.0)


func _mark_cells(cells: Array) -> void:
	var batch := LabBatch.new()
	var lit: Dictionary = {}
	for c in cells:
		lit[c] = true
		var at: Vector4 = lattice.cell_centre(c)
		batch.ring("hint", at + Vector4(0.0, 0.05, 0.0, 0.0), 1.0, 0.16, 0.05, lattice.size_of(c).z - 1.2, 32)
	_hint_node = batch.instance("hint")
	_hint_node.name = "HintMarks"
	(_hint_node as MeshInstance4D).material_override = Style.glow_material("w", 1.4)
	_hint_node.set("allow_projection", false)
	level_node.add_child(_hint_node)
	map.set("lit", lit)


func _clear_hint() -> void:
	if _hint_node != null and is_instance_valid(_hint_node):
		_hint_node.free()
	_hint_node = null
	_hint_left = 0.0
	if map != null:
		map.set("lit", {})


# -- keys ----------------------------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	# Esc is hud/maze_escape.gd's: it closes this panel, the map, or asks before leaving.
	# Tab, as in Ramon's other scenes (9 Oct: "sliders and a save mode when i press tab, so i can tweak
	# it"), and F1: open and close, every time. Here, before the panel's own controls can take Tab for
	# moving focus.
	var k := event as InputEventKey
	if k != null and k.pressed and not k.echo and (k.keycode == KEY_TAB or k.keycode == KEY_F1) and dev_panel != null:
		dev_panel.call("toggle")
		get_viewport().set_input_as_handled()
		return
	# A click with the cursor free lands on the console where the cursor is (round 3). Taken here, before
	# the walker's rig, which grabs the mouse back on any free click; a click that misses the console
	# is left to it, so clicking into the room goes back to looking.
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED \
			and console != null and console.visible and (dev_panel == null or not dev_panel.visible):
		var hit: Dictionary = _pointer_pick(mb.position)
		if not hit.is_empty():
			press(int(hit["button"]))
			get_viewport().set_input_as_handled()
		else:
			# A miss is a click back into looking: the crosshair must not take it as a press as well.
			_free_click = event


## While the Tab panel is open the game takes no keys and no clicks, and the walker stands still, so
## tuning can never start, restart or leave a level by accident (round 3). Held on the panel's opening,
## let go on its closing (runners freeze these flags themselves, so nothing here runs every frame).
var _ui_hold: bool = false
var _held_keys: bool = true


func _hold_for_panel() -> void:
	var held: bool = dev_panel != null and dev_panel.visible
	if held:
		player.set("input_enabled", false)
	if held == _ui_hold:
		return
	_ui_hold = held
	if held:
		_held_keys = bool(view.get("keys_on"))
		view.set("keys_on", false)
	else:
		view.set("keys_on", _held_keys)
		player.set("input_enabled", _cinema < 0.0 and float(view.get("_swing_left")) <= 0.0)


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if dev_panel != null and dev_panel.visible:
		return
	var mm := event as InputEventMouseMotion
	if mm != null and _orbit and mm.relative.length() > 3.0 and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_end_orbit()
	var mb := event as InputEventMouseButton
	if mb != null and mb == _free_click:
		_free_click = null
		return
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and console.visible and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var origin: Vector4 = camera.global_position
		var dir: Vector4 = -(camera.global_basis.z).normalized()
		var hit: Dictionary = console.call("pick", origin, dir)
		if not hit.is_empty():
			press(int(hit["button"]))
			get_viewport().set_input_as_handled()
		return
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if k.keycode >= KEY_1 and k.keycode <= KEY_6:
		var i: int = int(k.keycode - KEY_1)
		if state == "playing":
			start_level(i)
		else:
			# Choosing at the console by number frees the cursor, so START can be clicked with it (round 3,
			# Ramon: "after pressing 2 or 3, the player can become stuck with the mouse captured").
			if i != sel:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			press(i)
	elif k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER:
		if state != "playing":
			press(6)
	elif k.keycode == KEY_BACKSPACE:
		if state != "lobby":
			start_level(level_index, false)
	elif k.keycode == KEY_G:
		if state != "lobby":
			sight.call("set_on", not bool(sight.get("on")))
			hud.call("toast", "4D sight on. The cells next door in the hidden direction show as ghosts." if bool(sight.get("on")) else "4D sight off.", Style.role("w"), 3.0)
	elif k.keycode == KEY_M:
		if lattice != null:
			map.visible = not map.visible
	elif k.keycode == KEY_T:
		hint()
	elif k.keycode == KEY_L:
		if state != "lobby":
			go_lobby()
	else:
		return
	get_viewport().set_input_as_handled()


## A console tile pressed (clicked, or its number): a level is chosen, and pressed again (or START) it
## starts.
func press(i: int) -> void:
	if i == 6:
		start_level(sel)
		return
	if i == sel and state != "playing":
		start_level(sel)
		return
	sel = clampi(i, 0, LEVELS.size() - 1)
	_sel_flash = float(Time.get_ticks_msec()) / 1000.0


# -- tuning (F1) ---------------------------------------------------------------------------------------

func apply_tuning(v: Dictionary) -> void:
	var old: Dictionary = tuning
	tuning = v.duplicate()
	var chase := {"distance": float(v.get("chase_distance", 3.6)), "pivot": float(v.get("chase_height", 2.1)), "pitch": float(v.get("chase_pitch", -24.0))}
	view.set("chase", chase)
	if String(view.get("mode")) == "chase" and (old.is_empty() or old.get("chase_distance") != v.get("chase_distance") or old.get("chase_height") != v.get("chase_height") or old.get("chase_pitch") != v.get("chase_pitch")):
		view.call("set_mode", "chase", old.is_empty())
	view.set("turn_seconds", float(v.get("turn_seconds", 0.35)))
	view.set("settle_on", float(v.get("settle", 0.0)) > 0.5)
	_w_step = float(v.get("w_step", 0.3))
	if state != "lobby":
		player.set("w_speed_scale", _w_step)
	sight.set("strength", float(v.get("ghost", 0.3)))
	Style.set_w_plain(float(v.get("w_cyan", 1.0)) < 0.5)
	Style.set_layer_tint(float(v.get("layer_tint", 0.4)))
	sight.call("set_renderer", RENDERERS[clampi(int(v.get("renderer", 0.0)), 0, 3)])
	_apply_light()
	_apply_spot()


## The light in both moods: the numbers from Numbers, the colours from Colours.
func _apply_light() -> void:
	var light: Node = get_node_or_null("Light")
	if light == null:
		return
	var l: Dictionary = Style.LIGHT.duplicate(true)
	var d: Dictionary = {}
	for key in ["key_energy", "exposure"]:
		if tuning.has(key):
			l[key] = float(tuning[key])
	for key in colours:
		var p: PackedStringArray = String(key).split(":")
		if p[0] != "light":
			continue
		if p[1] == "bright":
			l[p[2]] = colours[key]
		else:
			d[p[2]] = colours[key]
	var amb: Color = l["ambient"]
	var ka: float = float(tuning.get("ambient_k", 1.0))
	l["ambient"] = Color(amb.r * ka, amb.g * ka, amb.b * ka)
	light.set("mood_overrides", {"bright": l, "dark": d})
	light.call("set_mood", String(light.get("mood")), true, false)


## Colours from the Tab panel (or the save): each to where it lives. Light colours are taken up by
## _apply_light(); the walker is painted in place.
func apply_colours(c: Dictionary) -> void:
	var walker: Dictionary = {}
	for key in c:
		colours[key] = c[key]
		var p: PackedStringArray = String(key).split(":")
		match p[0]:
			"sw":
				Style.set_surface(p[1], c[key])
			"line":
				Style.set_line(p[1], c[key])
			"role":
				Style.set_role(p[1], c[key])
			"walker":
				walker[p[1]] = c[key]
	if not walker.is_empty() and avatar != null:
		WalkerBuild.recolour(avatar, walker)
	if sight != null:
		sight.call("_colour_walls")
	if is_inside_tree() and tuning.size() > 0:
		_apply_light()


func _walker_colours() -> Dictionary:
	var out: Dictionary = {}
	for key in colours:
		if String(key).begins_with("walker:"):
			out[String(key).substr(7)] = colours[key]
	return out


## The one spot over the walker, every number on the Tab panel (Ramon, 9 Oct: "im not sure about this
## omni light that always follows him around. but its still not a bad idea especially for the dark mode"):
## its strength in each mood apart, its cone, how high it hangs, and whether it follows you at all.
func _apply_spot() -> void:
	var spot: Node = get_node_or_null("Spot")
	if spot != null:
		spot.set("energy", {"bright": float(tuning.get("spot_bright", 3.0)), "dark": float(tuning.get("spot_dark", 9.0))})
		spot.set("angle", float(tuning.get("spot_angle", 30.0)))
		# Round 3 (Ramon, 10 Oct: "there doesn't appear to be a way to control the softness of its
		# edges"): the engine's own angular fall-off (SpotLight4D.spot_angle_attenuation: low a crisp rim,
		# about 1 an even fade, higher a glow bright only in the middle), the fade with distance, and the
		# reach. The kit light passes them straight on.
		spot.set("softness", float(tuning.get("spot_softness", 1.2)))
		spot.set("attenuation", float(tuning.get("spot_falloff", 0.15)))
		spot.set("reach", float(tuning.get("spot_reach", 30.0)))


func _load_bests() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(BESTS) == OK:
		for i in LEVELS.size():
			if cfg.has_section_key("bests", str(i)):
				bests[i] = float(cfg.get_value("bests", str(i)))


func _save_bests() -> void:
	var cfg := ConfigFile.new()
	for i in bests:
		cfg.set_value("bests", str(i), bests[i])
	cfg.save(BESTS)


# -- the lobby's teaching wall -------------------------------------------------------------------------

## The back wall, behind the console: three pictures of one cell of level 3, filmed from the game by
## scripts/_capture_teaching_runner.gd (art/), level, turned facing ahead and turned facing sideways. The
## teaching itself is on the two live kit walls (phase_maze_info.tres, maze/maze_panel_source.gd); this
## one is printed once, because its pictures are pictures.
func _paint_lobby_wall() -> void:
	var size_m := Vector2(10.4, 3.4)
	var at := LOBBY + Vector4(0.0, 1.6 + size_m.y * 0.5, -7.92, 0.0)
	var box := Vector4(size_m.x, size_m.y, 0.08, 3.0)
	var mi := MeshInstance4D.new()
	mi.name = "ViewsWall"
	var mesh := BoxTetraMesh4D.new()
	mesh.size = box
	mi.mesh = mesh
	mi.position = at
	var m: TetraMaterial4D = LabGrid.material("kit_code_blue", box, at)
	mi.material_override = m
	mi.set("allow_projection", false)
	add_child(mi)
	var ppm: float = 200.0
	# The pictures loaded first and held here: a texture made inside the paint call is freed before the
	# canvas draws it, and the frame comes out blank.
	_art = []
	for nm in ["view_level", "view_ahead", "view_side"]:
		var path: String = ProjectSettings.globalize_path("res://ramon/PhaseMazeRemake/art/%s.png" % nm)
		var img: Image = Image.load_from_file(path) if FileAccess.file_exists(path) else null
		_art.append(ImageTexture.create_from_image(img) if img != null else null)
	var tex: Texture2D = await LabPrint.render(get_tree(), Vector2i(int(size_m.x * ppm), int(size_m.y * ppm)), func(c: Control) -> void: _paint_views(c, ppm))
	LabGrid.set_print(m, tex, Vector4(0, 0, 1, 0), Rect2(Vector2.ZERO, size_m), Color.WHITE, 0.35)
	LabGrid.set_print_strength(m, 1.0)


func _paint_views(c: Control, ppm: float) -> void:
	var w: float = c.size.x
	var white := Color(1, 1, 1)
	var soft := Color(1, 1, 1, 0.78)
	var fb: Font = LabPrint.font("black")
	var fs: Font = LabPrint.font("bold")
	var mg: float = 0.4 * ppm
	c.draw_string(fs, Vector2(mg, 0.45 * ppm), "ONE CELL, THREE FLAT MAZES", HORIZONTAL_ALIGNMENT_LEFT, -1, int(0.16 * ppm), soft)
	c.draw_string(fb, Vector2(mg, 0.95 * ppm), "Every view is a flat maze.", HORIZONTAL_ALIGNMENT_LEFT, w - mg * 2.0, int(0.32 * ppm), white)
	var shots := [["view_level", "LEVEL: YOU SEE X AND Z"], ["view_ahead", "F: WHAT WAS AHEAD IS W"], ["view_side", "FACE X, THEN F: Z AND W"]]
	var gap: float = 0.3 * ppm
	var pw: float = (w - mg * 2.0 - gap * 2.0) / 3.0
	var ph: float = pw * 9.0 / 16.0
	var top: float = 1.2 * ppm
	for i in shots.size():
		var r := Rect2(Vector2(mg + float(i) * (pw + gap), top), Vector2(pw, ph))
		var tex: Texture2D = _art[i] if i < _art.size() else null
		if tex != null:
			c.draw_texture_rect(tex, r, false)
		else:
			c.draw_rect(r, Color(1, 1, 1, 0.12), true)
		c.draw_rect(r, Color(1, 1, 1, 0.6), false, 0.012 * ppm)
		c.draw_string(fs, Vector2(r.position.x, r.end.y + 0.26 * ppm), String(shots[i][1]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(0.14 * ppm), white)
