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
const ReturnButton := preload("res://ramon/Demo/return_button.tscn")
const LabPrint := preload("res://ramon/PhaseMazeRemake/carried/LabKit/lab_print.gd")
const LabGrid := preload("res://ramon/PhaseMazeRemake/carried/LabKit/lab_grid.gd")
const LabBatch := preload("res://ramon/PhaseMazeRemake/carried/LabKit/lab_batch.gd")
const LabMaterials := preload("res://ramon/PhaseMazeRemake/carried/LabKit/lab_materials.gd")
const Kit := preload("res://ramon/PhaseMazeRemake/carried/kit/kit_style.gd")

const CELL := 6.0
const BESTS := "user://phase_maze_remake_bests.cfg"
const LEVELS := [
	{"file": "res://ramon/PhaseMazeRemake/levels/level_1.txt", "glyph": "step",
		"intro": "Find the dead end with the cyan mark. Hold E there to step through W."},
	{"file": "res://ramon/PhaseMazeRemake/levels/level_2.txt", "glyph": "turn",
		"intro": "A shaft runs three cells through W. Press F to turn it ahead of you."},
	{"file": "res://ramon/PhaseMazeRemake/levels/level_3.txt", "glyph": "both",
		"intro": "F turns what is ahead into W. Face another way first and a turn shows another maze."},
	{"file": "res://ramon/PhaseMazeRemake/levels/level_4.txt", "glyph": "sealed",
		"intro": "The exit's room is closed on every side. G shows the cells next door in W as ghosts."},
	{"file": "res://ramon/PhaseMazeRemake/levels/level_5.txt", "glyph": "cube",
		"intro": "Everything together. M opens the map."},
	{"generated": [4, 4, 3], "glyph": "generated", "name": "Generated",
		"intro": "A new maze every run."},
]
## The lobby: its middle, where you stand on arrival, where the console waits. Well away from the maze.
## 18 m wide like the Creation Lab's rooms, so its two live walls stand 9 m from the middle, as far as the
## lab's walls from its exhibit (the range measured the same distance for the same type sizes).
const LOBBY := Vector4(0.0, 0.0, 40.0, 0.0)
const LOBBY_SPAWN := Vector4(0.0, 0.1, 44.6, 0.0)
const CONSOLE_HOME := Vector4(0.0, 0.0, 39.0, 0.0)
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
var tuning: Dictionary = {}
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
	Style.apply()
	var light: Node = get_node_or_null("Light")
	if light != null:
		light.set("mood_overrides", {"bright": Style.LIGHT.duplicate(true), "dark": Style.LIGHT.duplicate(true)})


func _exit_tree() -> void:
	Style.restore()


func _ready() -> void:
	var light: Node = get_node_or_null("Light")
	if light != null:
		light.call("set_mood", "bright", true, false)
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
			_prompt("turn", "Turned into W. What was ahead is W now, and the cyan walls stand across it. F turns back."))
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
	_load_bests()
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
	lattice.cell = CELL
	lattice.origin = Vector4(-float(lattice.nx - 1) * CELL * 0.5, 0.0, -float(lattice.nz - 1) * CELL - CELL * 0.5, 0.0)
	level_node = Node4D.new()
	level_node.name = "Level"
	add_child(level_node)
	built = Builder.build(level_node, lattice)
	_par = lattice.par_w()
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
	_place_player(lattice.cell_centre(lattice.start) + Vector4(0.0, 0.1, 0.0, 0.0), face)
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


func _clear_level() -> void:
	_clear_hint()
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
	if state == "playing" and lattice != null:
		_play(delta)
	if _hint_left > 0.0:
		_hint_left -= delta
		if _hint_left <= 0.0 and _hint_tier >= 3:
			_clear_hint()
	if console.visible:
		console.call("show_data", _console_data("near" if state == "finished" else "lobby"))
	hud.set("crosshair", console.visible and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)
	hud.set("info", {"state": state, "number": level_index + 1, "name": _level_name(level_index) if lattice != null else "",
		"time": time, "running": running, "w_moves": w_moves, "par": _par,
		"best": float(bests.get(level_index, 0.0)), "sight": bool(sight.get("on")), "first_person": String(view.get("mode")) == "first"})
	var spot: Node = get_node_or_null("Spot")
	if spot != null:
		var p: Vector4 = player.global_position
		spot.set("position", p + Vector4(0.0, 10.0, 1.5, 0.0))
		spot.set("aim", Vector3(p.x, 0.0, p.z))


func _play(delta: float) -> void:
	var p: Vector4 = player.global_position
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
	var e: Vector4 = lattice.cell_centre(lattice.exit)
	if cell == lattice.exit and Vector2(p.x - e.x, p.z - e.z).length() < 2.2 and absf(p.w - e.w) < 1.6:
		_finish()


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
		mi.position = Vector4(at.x, Builder.TILE_Y, at.z, at.w)
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
	var e: Vector4 = lattice.cell_centre(lattice.exit)
	var inset: float = CELL * 0.5 - 1.1
	console.set("room", [e - Vector4(inset, 0, inset, 0), e + Vector4(inset, 0, inset, 0)])
	console.visible = true
	console.call("show_data", _console_data("near"))
	console.call("snap")
	hud.call("toast", "Out of the maze in %s." % Hud.clock(time), Style.role("exit"), 3.0)


func _console_data(anchor: String) -> Dictionary:
	var tiles: Array = []
	for i in LEVELS.size():
		var best: float = float(bests.get(i, 0.0))
		var par: String = "NEW EACH RUN" if LEVELS[i].has("generated") else ""
		tiles.append([str(i + 1), _level_name(i).to_upper(), Hud.clock(best) if best > 0.0 else "", best > 0.0, String(LEVELS[i]["glyph"]), par])
	return {"sel": sel, "tiles": tiles, "start": "NEXT" if state == "finished" else "START", "hover": -1, "anchor": anchor,
		"live": true, "hint": "PRESS 1 TO 6 OR CLICK A LEVEL, THEN START" if state != "finished" else "WELL DONE. ENTER FOR THE NEXT ONE"}


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
		batch.ring("hint", at + Vector4(0.0, 0.05, 0.0, 0.0), 1.0, 0.16, 0.05, CELL - 1.2, 32)
	_hint_node = batch.instance("hint")
	_hint_node.name = "HintMarks"
	(_hint_node as MeshInstance4D).material_override = LabMaterials.glow(Style.glow("w"), 1.4)
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
	# Escape closes the dev panel first (the rig would otherwise take it as "let the mouse go, then quit").
	var k := event as InputEventKey
	if k != null and k.pressed and not k.echo and k.keycode == KEY_ESCAPE and dev_panel != null and dev_panel.visible:
		dev_panel.call("toggle")
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	var mb := event as InputEventMouseButton
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
	elif k.keycode == KEY_F1:
		dev_panel.call("toggle")
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


# -- tuning (F1) ---------------------------------------------------------------------------------------

func apply_tuning(v: Dictionary) -> void:
	var old: Dictionary = tuning
	tuning = v.duplicate()
	var chase := {"distance": float(v.get("chase_distance", 3.6)), "pivot": float(v.get("chase_height", 2.1)), "pitch": float(v.get("chase_pitch", -24.0))}
	view.set("chase", chase)
	if String(view.get("mode")) == "chase" and (old.is_empty() or old.get("chase_distance") != v.get("chase_distance") or old.get("chase_height") != v.get("chase_height") or old.get("chase_pitch") != v.get("chase_pitch")):
		view.call("set_mode", "chase", old.is_empty())
	view.set("turn_seconds", float(v.get("turn_seconds", 0.35)))
	view.set("settle_on", float(v.get("settle", 1.0)) > 0.5)
	_w_step = float(v.get("w_step", 0.3))
	if state != "lobby":
		player.set("w_speed_scale", _w_step)
	sight.set("strength", float(v.get("ghost", 0.3)))
	var wv: Array = Style.SWATCHES["maze_wall_w" if float(v.get("w_cyan", 1.0)) > 0.5 else "maze_wall"]
	LabGrid.set_swatch("maze_wall_w", wv[0], wv[1], wv[2], float(wv[3]))
	sight.call("set_renderer", RENDERERS[clampi(int(v.get("renderer", 0.0)), 0, 3)])
	var light: Node = get_node_or_null("Light")
	if light != null:
		var l: Dictionary = Style.LIGHT.duplicate(true)
		for key in ["key_energy", "exposure"]:
			if v.has(key):
				l[key] = float(v[key])
		var amb: Color = Style.LIGHT["ambient"]
		var ka: float = float(v.get("ambient_k", 1.0))
		l["ambient"] = Color(amb.r * ka, amb.g * ka, amb.b * ka)
		light.set("mood_overrides", {"bright": l, "dark": l})
		light.call("set_mood", "bright", true, false)
	var spot: Node = get_node_or_null("Spot")
	if spot != null:
		var e: float = float(v.get("spot_energy", 3.0))
		spot.set("energy", {"bright": e, "dark": e})
		spot.set("angle", float(v.get("spot_angle", 34.0)))


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
