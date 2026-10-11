extends Node4D
## THE ANNEX (Maze Remake 2): the game. A first-person walk through a building that goes on in W.
##
## This root owns what lasts across levels: the light (world/mr2_light_4d.gd), the player
## (player/mr2_player_4d.gd), the HUD (hud/mr2_hud.gd), the sound (audio/mr2_sound.gd), the Esc guard
## (hud/mr2_escape.gd) and the film camera. It loads one level at a time as a child scene
## (levels/level_N.tscn, each built in code as it enters the tree) and frees the last.
##
## EACH FRAME it asks the level to tick, looks for the lift out, picks what V would finish (the door or
## relic you face, once it is open enough), measures how far you could shift each way from where you
## stand (a test move along W through the physics, so the gizmo's stops are the real ones), and hands
## the HUD one state dictionary.
##
## KEYS (the walking, looking and W keys are the player's own):
##   V          finish the reveal you face (door, relic, or in level 3 the turn)
##   R          level a turned view; on a level view, back to this room's own W
##   Backspace  back to this room's way in
##   B          dark or bright (as in the labs)
##   1 2 3      a level
##   G          the next gizmo design (the trial of PLAN.md section 9)
##   F1         the HUD on or off
##   Tab (F2)   the tuning panel (mouse, W speed, view, light, torch, sound; SAVE)
##   Esc        the guard: closes a film or the end card's question, otherwise asks before leaving
## Design notes and the plan: PLAN.md beside this file. Handover: follow_up/maze_remake_2.md.

const KitStyle := preload("res://ramon/MazeRemake2/carried/kit_style.gd")
const Light := preload("res://ramon/MazeRemake2/world/mr2_light_4d.gd")
const Player := preload("res://ramon/MazeRemake2/player/mr2_player_4d.gd")
const Hud := preload("res://ramon/MazeRemake2/hud/mr2_hud.gd")
const Escape := preload("res://ramon/MazeRemake2/hud/mr2_escape.gd")
const Sound := preload("res://ramon/MazeRemake2/audio/mr2_sound.gd")
const Build := preload("res://ramon/MazeRemake2/world/mr2_build.gd")
const Level := preload("res://ramon/MazeRemake2/levels/mr2_level_4d.gd")
const D := preload("res://ramon/MazeRemake2/hud/mr2_draw.gd")
const Ground := preload("res://ramon/MazeRemake2/carried/ground_basis_4d.gd")
const Tuning := preload("res://ramon/MazeRemake2/hud/mr2_tuning_panel.gd")

## The lore logs across the three levels.
const LOG_TOTAL := 6

const LEVELS := [
	"res://ramon/MazeRemake2/levels/level_1.tscn",
	"res://ramon/MazeRemake2/levels/level_2.tscn",
	"res://ramon/MazeRemake2/levels/level_3.tscn",
]
const SETTINGS := "user://maze_remake_2.cfg"

## Which level the scene opens on (1 to 3).
@export_range(1, 3) var start_level: int = 1
## Off for runners that drive the mouse themselves.
@export var capture_mouse: bool = true
## The popup explainers (each level's controls, the first Tall One). Runners turn them off.
@export var popups: bool = true

var light: Node4D
var player: CharacterBody4D
var hud: CanvasLayer
var tuning: CanvasLayer
var sound: Node
var level: Node4D
var level_index: int = -1
var film_camera: Camera4D
## "play", "lift", "respawn", "film", "end", "loading"
var mode: String = "loading"
var _popup_seen: Dictionary = {}
var _popup_done: Callable = Callable()
## The total time played, and per level.
var clock: float = 0.0
## The Lens (end of level 2): the turn into W.
var has_lens: bool = false
## Skills seen used, for the teaching cards: "shift", "align", "turn".
var learned: Dictionary = {}
var target: Dictionary = {}
var _escape: CanvasLayer
var _taught: Dictionary = {}
var _w_moved: float = 0.0
var _turned: float = 0.0
var _face_door_t: float = 0.0
var _since_level: float = 0.0
var _film: Dictionary = {}
var _relic_total: int = 0
var _relics_found: int = 0
var _stop_kata: float = -INF
var _stop_ana: float = INF
var _door_open_last: Dictionary = {}
var _since_nag: float = 99.0
## The Tall Ones: seen once (the first-sighting film plays once a game), deaths, logs read.
var sighted: bool = false
var deaths: int = 0
var logs_read: Dictionary = {}
var _told_escape: bool = false


func _enter_tree() -> void:
	# The kit's swatches before anything builds (lab_kit.md: otherwise the blue walls come out white).
	KitStyle.apply("bright")


func _ready() -> void:
	# Only when there is none (the menu's stopgap; replacing one prints "scenario is null").
	if get_tree().root.world_3d == null:
		get_tree().root.world_3d = World3D.new()
	light = Light.new()
	light.name = "Light"
	add_child(light)
	player = Player.new()
	player.name = "Player"
	add_child(player)
	light.call("attach_torch", player.get("camera"))
	film_camera = Camera4D.new()
	film_camera.name = "FilmCamera"
	film_camera.set("rendering_engine_name", "Cross-section")
	film_camera.set("view_angle_type", 1)
	film_camera.set("field_of_view_4d", deg_to_rad(80.0))
	add_child(film_camera)
	hud = Hud.new()
	hud.name = "Hud"
	add_child(hud)
	sound = Sound.new()
	sound.name = "Sound"
	add_child(sound)
	player.connect("w_knock", _on_knock)
	tuning = Tuning.new()
	tuning.name = "Tuning"
	tuning.set("game", self)
	add_child(tuning)
	tuning.call("apply_saved")
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS) == OK:
		hud.call("set_gizmo", int(cfg.get_value("view", "gizmo", 0)))
	if not Engine.is_editor_hint():
		_escape = Escape.guard(self)
	if capture_mouse:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	load_level(start_level - 1, true)


func _exit_tree() -> void:
	if is_instance_valid(_escape):
		_escape.queue_free()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Loads level `i` (0-based) behind a fade, puts you at its spawn, shows its title.
func load_level(i: int, instant: bool = false) -> void:
	mode = "loading"
	player.set("input_enabled", false)
	if not instant:
		hud.call("fade_to", 1.0, 2.6)
		for k in 120:
			if bool(hud.call("is_faded")):
				break
			await get_tree().process_frame
	if is_instance_valid(level):
		remove_child(level)
		level.queue_free()
		level = null
	level_index = clampi(i, 0, LEVELS.size() - 1)
	var packed: PackedScene = load(LEVELS[level_index])
	level = packed.instantiate() as Node4D
	level.set("game", self)
	add_child(level)
	level.connect("relic_taken", _on_relic)
	_relic_total = (level.get("relics") as Array).size()
	light.set("dark_ambient_gain", float(level.get("dark_lift")))
	light.call("apply")
	_relics_found = 0
	player.set("turn_enabled", has_lens or level_index >= 2)
	var sp: Vector4 = level.get("spawn")
	player.call("place", sp, float(level.get("spawn_yaw")))
	_since_level = 0.0
	_face_door_t = 0.0
	if sound != null:
		sound.call("set_level", level_index)
	await get_tree().physics_frame
	await get_tree().physics_frame
	hud.call("fade_to", 0.0, 1.4)
	hud.call("show_title")
	mode = "play"
	player.set("input_enabled", true)
	if level.has_method("on_arrive"):
		level.call("on_arrive")
	# Once a session per level: what you can do with W here, and what is still to come.
	var key: String = "level%d" % level_index
	if not _popup_seen.has(key):
		_popup_seen[key] = true
		show_popup("controls", _controls_card(level_index))


func _process(delta: float) -> void:
	if not is_instance_valid(level):
		return
	level.call("tick", player, delta)
	if mode == "play":
		_since_level += delta
	if mode == "film":
		_step_film(delta)
	if mode == "play":
		clock += delta
		_w_moved += absf(float(player.get("w_rate"))) * delta
		if _w_moved > 0.6:
			learned["shift"] = true
		if Level.in_box(player.call("feet") + Vector4(0, 0.1, 0, 0), level.get("lift_out")):
			if not level.has_method("lift_ready") or bool(level.call("lift_ready")):
				_ride_lift()
			elif _since_nag > 3.0:
				_since_nag = 0.0
				hud.call("toast", "THE LIFT WAITS FOR THE LENS", Color(0.55, 0.85, 1.0), 2.2)
		_since_nag += delta
		if player.global_position.y < -8.0:
			respawn("You fell. Back to this room's way in.")
		target = _pick_target()
		_teach(delta)
		level.call("tick_logs", player)
		if not sighted:
			_check_sighting()
	else:
		target = {}
	_measure_stops()
	_feed_hud()
	_feed_sound(delta)


## The sound follows your W speed and the doors moving near you.
func _feed_sound(delta: float) -> void:
	if sound == null or not is_instance_valid(level):
		return
	var f: Vector4 = player.call("feet")
	var rate: float = 0.0
	for d in level.call("doors"):
		var at: Vector3 = d["at"]
		if Vector2(at.x - f.x, at.z - f.z).length() > 9.0:
			continue
		var o: float = Build.openness(d, f.w)
		var key: String = String(d["name"])
		var was: float = float(_door_open_last.get(key, o))
		_door_open_last[key] = o
		rate = maxf(rate, absf(o - was) / maxf(delta, 0.0001))
	sound.call("feed", float(player.get("w_rate")) if mode == "play" else 0.0, rate, delta)


## What V would finish now: the door or relic you face, with how open it is, its colour, where it is on
## screen; offered once it is open enough (PLAN.md step 38).
func _pick_target() -> Dictionary:
	var f: Vector4 = player.call("feet")
	var fwd: Vector4 = player.call("forward")
	var fwd2 := Vector2(fwd.x, fwd.z)
	if fwd2.length() < 0.2:
		fwd2 = Vector2(0, -1)
	fwd2 = fwd2.normalized()
	var best: Dictionary = {}
	var best_score: float = INF
	for d in level.call("doors"):
		var at: Vector3 = d["at"]
		var rel := Vector2(at.x - f.x, at.z - f.z)
		var dist: float = rel.length()
		if dist > 12.0 or f.w < float(d["w_lo"]) or f.w > float(d["w_hi"]):
			continue
		var facing: float = fwd2.dot(rel / maxf(dist, 0.001)) if dist > 0.3 else 1.0
		if facing < 0.55 and dist > 2.2:
			continue
		var open: float = Build.openness(d, f.w)
		var score: float = dist * (2.0 - facing)
		if score < best_score:
			best_score = score
			var aw: float = Build.align_for(d, f.w)
			var offered: bool = open >= 0.6 and open < 0.995 and absf(f.w - aw) > 0.04 and dist < 10.0
			best = {"kind": "door", "name": d["name"], "open": open, "offered": offered, "color": Build.color_for(d, f.w),
				"w": aw, "label": "OPEN", "verb": "ALIGN", "door": d}
			var sr: Variant = _door_screen(d, f.w)
			if sr != null:
				best["screen"] = sr
	for rec in level.get("relics"):
		if bool(rec["taken"]):
			continue
		var at4: Vector4 = rec["at"]
		var rel4 := Vector2(at4.x - f.x, at4.z - f.z)
		var dist4: float = rel4.length()
		if dist4 > 9.0:
			continue
		var facing4: float = fwd2.dot(rel4 / maxf(dist4, 0.001)) if dist4 > 0.3 else 1.0
		if facing4 < 0.7:
			continue
		var share: float = Level.relic_share(rec, f.w)
		if share <= 0.0:
			continue
		var score4: float = dist4 * (2.0 - facing4) - 1.0
		if score4 < best_score:
			best_score = score4
			best = {"kind": "relic", "name": rec["name"], "open": share, "offered": share >= 0.5 and share < 0.97,
				"color": rec["color"], "w": at4.w, "label": "IN VIEW", "verb": "ALIGN"}
			var sr4: Variant = _box_screen(Vector3(at4.x, at4.y, at4.z), Vector3(0.45, 0.55, 0.45), f.w)
			if sr4 != null:
				best["screen"] = sr4
	if level.has_method("extra_target"):
		var extra: Dictionary = level.call("extra_target", player)
		if not extra.is_empty():
			best = extra
	return best


func _door_screen(d: Dictionary, w: float) -> Variant:
	var at: Vector3 = d["at"]
	var hw: float = float(d["width"]) * 0.5
	var h: float = float(d["height"])
	var half: Vector3 = Vector3(hw, h * 0.5, 0.05) if String(d["along"]) == "x" else Vector3(0.05, h * 0.5, hw)
	return _box_screen(at, half, w)


## The screen rectangle (canvas units) round a box at `c` with half-size `half`, cut at W `w`; null when
## any corner is behind the camera.
func _box_screen(c: Vector3, half: Vector3, w: float) -> Variant:
	var cam: Camera4D = player.get("camera")
	if cam == null:
		return null
	var canvas: Vector2 = get_viewport().get_visible_rect().size
	var vp := Vector2(get_viewport().get_size())
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var p := Vector4(c.x + half.x * sx, c.y + half.y * sy, c.z + half.z * sz, w)
				var rel: Vector4 = p - cam.global_position
				if rel.dot(cam.global_basis.z) > -0.15:
					return null
				var s: Vector2 = cam.world_to_viewport(p) * canvas / vp
				lo = lo.min(s)
				hi = hi.max(s)
	return Rect2(lo, hi - lo)


## How far you could shift each way along W from where you stand (a test move through the physics).
func _measure_stops() -> void:
	_stop_kata = -INF
	_stop_ana = INF
	if player == null or not player.is_inside_tree():
		return
	var w: float = player.global_position.w
	var reach: float = 9.0
	var hit: KinematicCollision4D = player.move_and_collide(Vector4(0, 0, 0, reach), true)
	if hit != null:
		_stop_ana = w + hit.get_travel_ratio() * reach
	hit = player.move_and_collide(Vector4(0, 0, 0, -reach), true)
	if hit != null:
		_stop_kata = w - hit.get_travel_ratio() * reach


func _feed_hud() -> void:
	if not is_instance_valid(level):
		return
	var f: Vector4 = player.call("feet")
	var fwd: Vector4 = player.call("forward")
	var fwd2 := Vector2(fwd.x, fwd.z).normalized() if Vector2(fwd.x, fwd.z).length() > 0.2 else Vector2(0, -1)
	var doors: Array = []
	for d in level.call("doors"):
		var at: Vector3 = d["at"]
		var rel := Vector2(at.x - f.x, at.z - f.z)
		var dist: float = rel.length()
		if dist > 16.0 or f.w < float(d["w_lo"]) - 0.5 or f.w > float(d["w_hi"]) + 0.5:
			continue
		if dist > 2.5 and fwd2.dot(rel / dist) < 0.3:
			continue
		var lit: bool = target.get("door", {}) == d
		var o: float = Build.openness(d, f.w)
		if String(d.get("kind", "door")) == "passage":
			for r in d["open"]:
				doors.append({"align_w": (float(r[0]) + float(r[1])) * 0.5, "color": r[2], "open": o, "targeted": lit})
		else:
			doors.append({"align_w": float(d["align_w"]), "color": d["color"], "open": o, "targeted": lit})
	var strip: Array = [["WASD", "Move"], ["Mouse", "Look"], ["Q  E", "Shift W", absf(float(player.get("w_input"))) > 0.1]]
	if bool(target.get("offered", false)):
		strip.append(["V", "Align", true])
	if bool(player.get("turn_enabled")):
		strip.append(["Right drag", "Turn into W", float(player.call("tilt")) > 0.02])
		if float(player.call("tilt")) > 0.02:
			strip.append(["R", "Level the view"])
	strip.append(["B", "Dark"])
	var relics: String = ""
	if _relic_total > 0:
		relics = "RELICS  %d / %d" % [_relics_found, _relic_total]
	relics += ("     " if relics != "" else "") + "LOGS  %d / %d" % [logs_read.size(), LOG_TOTAL]
	hud.call("update_state", {
		"w": player.global_position.w,
		"w_min": float(level.get("w_min")),
		"w_max": float(level.get("w_max")),
		"bands": level.get("bands"),
		"w_input": float(player.get("w_input")),
		"w_blocked": bool(player.get("w_blocked")),
		"stop_kata": _stop_kata,
		"stop_ana": _stop_ana,
		"doors": doors,
		"target": target,
		"tilt": float(player.call("tilt")),
		"turn_enabled": bool(player.get("turn_enabled")),
		"level": level_index + 1,
		"title": String(level.get("title")),
		"relics": relics,
		"dark": bool(light.get("dark")),
		"strip": strip,
		"walkers": _walker_marks(),
		"rooms": level.get("rooms"),
		"player_pos": player.global_position,
		"ground": player.get("ground"),
		"level_doors": level.call("doors"),
	})
	(hud.get("card") as Node).set("bands", level.get("bands"))


## The teaching cards, the first times they matter (and never again once the skill is used).
func _teach(delta: float) -> void:
	var card: Node = hud.get("card")
	if level_index == 0 and not learned.has("shift"):
		var looking: bool = target.get("kind", "") == "door"
		_face_door_t = _face_door_t + delta if looking else maxf(0.0, _face_door_t - delta)
		var due: bool = (_face_door_t > 1.2 or _since_level > 5.0) and not _taught.has("shift")
		var again: bool = _taught.has("shift") and _since_level > 20.0 and not _taught.has("shift2")
		if due or again:
			_taught["shift2" if _taught.has("shift") else "shift"] = true
			card.call("play", "shift", 8.0, "STEP THROUGH W", "Hold E to shift ana. Q shifts back.")
	elif learned.has("shift") and bool(card.call("is_playing")) and String(card.get("kind")) == "shift":
		card.call("stop")
	if float(player.call("tilt")) > 0.6:
		learned["turn"] = true
	if level_index == 2 and not learned.has("turn") and _since_level > 4.0 and not _taught.has("turn3"):
		_taught["turn3"] = true
		teach("turn")
	if bool(target.get("offered", false)) and not learned.has("align") and not _taught.has("align"):
		_taught["align"] = true
		card.call("play", "align", 6.0, "FINISH THE REVEAL", "V takes you to where it opens.")


## Teach a skill now (a level asks: the turn, once you hold the Lens).
func teach(kind: String) -> void:
	var card: Node = hud.get("card")
	match kind:
		"turn":
			card.call("play", "turn", 9.0, "TURN INTO W", "Hold the right mouse button and drag up.")
		"shift":
			card.call("play", "shift", 7.0, "STEP THROUGH W", "Hold E to shift ana. Q shifts back.")


## A popup explainer in the middle of the screen; you are held still until Space, Enter or a click.
func show_popup(kind: String, d: Dictionary, done: Callable = Callable()) -> void:
	if not popups:
		if done.is_valid():
			done.call()
		return
	mode = "popup"
	player.set("input_enabled", false)
	_popup_done = done
	(hud.get("popup") as Node).call("open", kind, d)


func close_popup() -> void:
	if mode != "popup":
		return
	(hud.get("popup") as Node).call("close")
	mode = "play"
	player.set("input_enabled", true)
	sound.call("tick")
	var done: Callable = _popup_done
	_popup_done = Callable()
	if done.is_valid():
		done.call()


## Each level's controls card: every slicing control, YOURS, NEW here, or LATER.
func _controls_card(i: int) -> Dictionary:
	var kicker: String = "THE ANNEX  ·  %d  %s" % [i + 1, String(level.get("title"))]
	match i:
		0:
			return {"kicker": kicker, "title": "WHAT YOU CAN DO HERE", "rows": [
				["E / Q", "Move through W, ana and kata", "new"],
				["V", "Finish a door once it is mostly open", "new"],
				["RIGHT DRAG", "Turn your view into W", "later"]],
				"line": "Each level gives you one more way to slice the building. Turning comes with the Lens, in level 2."}
		1:
			return {"kicker": kicker, "title": "NEW HERE: THE LENS", "rows": [
				["E / Q", "Move through W", "yours"],
				["V", "Finish a door", "yours"],
				["RIGHT DRAG", "Find the Lens, then turn your view into W", "new"]],
				"line": "Here the same doorway leads to a different room at every W."}
	return {"kicker": kicker, "title": "NEW HERE: TURNING", "rows": [
		["E / Q", "Move through W", "yours"],
		["V", "Finish a door, or a turn", "yours"],
		["RIGHT DRAG", "Turn your view into W", "new"],
		["R", "Level your view again", "new"]],
		"line": "Some places you cannot walk to. You can only turn toward them."}


func _unhandled_input(event: InputEvent) -> void:
	if mode == "popup":
		var mb := event as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			close_popup()
			get_viewport().set_input_as_handled()
			return
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if mode == "popup":
		if k.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
			close_popup()
			get_viewport().set_input_as_handled()
		return
	if bool(tuning.call("is_open")):
		if k.keycode == KEY_TAB or k.keycode == KEY_F2:
			tuning.call("close")
		get_viewport().set_input_as_handled()
		return
	if (k.keycode == KEY_TAB or k.keycode == KEY_F2) and mode in ["play", "end"]:
		tuning.call("open")
		get_viewport().set_input_as_handled()
		return
	if mode == "end":
		if k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER or k.keycode == KEY_SPACE:
			restart_game()
			get_viewport().set_input_as_handled()
		return
	if mode == "film":
		if k.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
			skip_film()
			get_viewport().set_input_as_handled()
		return
	match k.keycode:
		KEY_V:
			if mode == "play":
				align()
		KEY_R:
			if mode == "play":
				reset_view()
		KEY_BACKSPACE:
			if mode == "play":
				respawn("Back to this room's way in.")
		KEY_B:
			light.call("toggle", true)
			sound.call("tick")
		KEY_1, KEY_2, KEY_3:
			if mode == "play":
				load_level(int(k.keycode - KEY_1))
		KEY_G:
			hud.call("set_gizmo", int(hud.get("gizmo_index")) + 1)
			var name: String = Hud.GIZMOS[int(hud.get("gizmo_index"))]
			hud.call("toast", "GIZMO  ·  " + name, D.ACCENT, 1.6)
			var cfg := ConfigFile.new()
			cfg.load(SETTINGS)
			cfg.set_value("view", "gizmo", int(hud.get("gizmo_index")))
			cfg.save(SETTINGS)
		KEY_F1:
			hud.call("set_hud_visible", not bool(hud.get("hud_visible")))
		_:
			return
	get_viewport().set_input_as_handled()


## V: finish what you face.
func align() -> void:
	if not bool(target.get("offered", false)) or bool(player.call("is_aligning")):
		return
	learned["align"] = true
	(hud.get("card") as Node).call("stop")
	match String(target.get("kind", "")):
		"door", "relic":
			player.call("align_w", float(target["w"]), 0.4)
		"turn":
			var fr: Projection = target["frame"]
			player.call("align_frame", fr, 0.55, float(target.get("w", NAN)))
	sound.call("align")


## R: a turned view comes back level; a level one goes back to this room's own W.
func reset_view() -> void:
	if float(player.call("tilt")) > 0.01:
		player.call("level", 0.45)
		sound.call("align")
		return
	var c: Dictionary = level.call("checkpoint_for", player.call("feet"))
	var home: float = (c["at"] as Vector4).w
	if absf(player.global_position.w - home) > 0.05:
		player.call("align_w", home, 0.5)
		hud.call("toast", "BACK TO THIS ROOM'S W", Color.WHITE, 1.6)
		sound.call("align")


## Backspace (and a fall): back to the way in of the room you are in, behind a quick fade.
func respawn(why: String = "") -> void:
	if mode != "play":
		return
	var c: Dictionary = level.call("checkpoint_for", player.call("feet"))
	mode = "respawn"
	player.set("input_enabled", false)
	hud.call("fade_to", 1.0, 5.0)
	for k in 60:
		if bool(hud.call("is_faded")):
			break
		await get_tree().process_frame
	player.call("place", c["at"], float(c.get("yaw", 0.0)))
	level.call("reset_walkers")
	await get_tree().physics_frame
	hud.call("fade_to", 0.0, 3.0)
	if why != "":
		hud.call("toast", why, Color.WHITE, 2.4)
	mode = "play"
	player.set("input_enabled", true)


func _ride_lift() -> void:
	mode = "lift"
	player.set("input_enabled", false)
	sound.call("lift")
	hud.call("toast", "GOING ON", Color(0.55, 0.85, 1.0), 1.6)
	await get_tree().create_timer(1.0).timeout
	if level_index + 1 < LEVELS.size():
		load_level(level_index + 1)
	else:
		finish_game()


func _on_relic(rec: Dictionary) -> void:
	_relics_found += 1
	hud.call("toast", "RELIC  ·  %s  ·  %d of %d" % [String(rec["name"]).to_upper(), _relics_found, _relic_total], (rec["color"] as Color).lerp(Color.WHITE, 0.3), 3.0)
	sound.call("relic")


func _on_knock(_dir: float) -> void:
	sound.call("knock")


## A film: shots of the film camera, then control back. Each shot: {"eye": Vector4, "basis": Projection,
## "eye2", "basis2" (optional end), "seconds", "caption"}. `done` is called after (skipped or not).
func play_film(shots: Array, done: Callable = Callable()) -> void:
	if shots.is_empty():
		return
	_film = {"shots": shots, "i": 0, "t": 0.0, "done": done}
	mode = "film"
	player.set("input_enabled", false)
	hud.call("film", true)
	film_camera.current = true
	_apply_shot(0, 0.0)


func _step_film(delta: float) -> void:
	if _film.is_empty():
		return
	var shots: Array = _film["shots"]
	var i: int = _film["i"]
	_film["t"] = float(_film["t"]) + delta
	var s: Dictionary = shots[i]
	var dur: float = float(s.get("seconds", 3.0))
	if float(_film["t"]) >= dur:
		_film["i"] = i + 1
		_film["t"] = 0.0
		if int(_film["i"]) >= shots.size():
			_end_film()
			return
		i = int(_film["i"])
		dur = float((shots[i] as Dictionary).get("seconds", 3.0))
	_apply_shot(i, clampf(float(_film["t"]) / dur, 0.0, 1.0))


func _apply_shot(i: int, t: float) -> void:
	var shots: Array = _film["shots"]
	var s: Dictionary = shots[i]
	var e: float = t * t * (3.0 - 2.0 * t)
	var eye: Vector4 = s["eye"]
	var eye2: Vector4 = s.get("eye2", eye)
	film_camera.global_position = eye.lerp(eye2, e)
	var b0: Projection = s["basis"]
	var b1: Projection = s.get("basis2", b0)
	if b1 != b0:
		var rel: Quaternion = Ground._to_3d(Basis4D.transposed(b0) * b1).get_rotation_quaternion()
		if rel.w < 0.0:
			rel = -rel
		film_camera.global_basis = Basis4D.orthonormalized(b0 * Ground._from_3d(Basis(Quaternion.IDENTITY.slerp(rel, e))))
	else:
		film_camera.global_basis = b0
	if t <= 0.001 and String(s.get("caption", "")) != "":
		hud.call("say", String(s["caption"]), float(s.get("seconds", 3.0)) + 0.6)


func skip_film() -> void:
	if mode == "film":
		_end_film()


func _end_film() -> void:
	var done: Callable = _film.get("done", Callable())
	_film = {}
	hud.call("film", false)
	hud.call("say", "", 0.0)
	(player.get("camera") as Camera4D).current = true
	mode = "play"
	player.set("input_enabled", true)
	if done.is_valid():
		done.call()


## The Lens (end of level 2): its film, then the turn is yours.
func take_lens() -> void:
	sound.call("relic")
	var shots: Array = level.call("lens_film", player) if level.has_method("lens_film") else []
	var after := func() -> void:
		has_lens = true
		player.set("turn_enabled", true)
		hud.call("toast", "THEY ARE COMING. GO HOME, THEN TO THE LIFT.", Color(1.0, 0.36, 0.3), 3.6)
		teach("turn")
		if level.has_method("after_lens"):
			level.call("after_lens")
	if shots.is_empty():
		after.call()
	else:
		play_film(shots, after)


## Where the Tall Ones are, for the slice map: [{pos: Vector4, red: float}].
func _walker_marks() -> Array:
	var out: Array = []
	for w in level.get("walkers"):
		if is_instance_valid(w):
			out.append({"pos": (w as Node4D).global_position, "red": float(w.get("red"))})
	return out


## A Tall One's footfall: heavy and slow; heard further than it is seen, muffled when it is in another
## slice (you hear what you cannot see).
func walker_step(w: Node) -> void:
	var p: Vector4 = player.global_position
	var q: Vector4 = (w as Node4D).global_position
	var dist: float = Vector2(p.x - q.x, p.z - q.z).length()
	var dw: float = absf(p.w - q.w)
	if dist > 26.0:
		return
	var db: float = lerpf(-12.0, -40.0, clampf(dist / 26.0, 0.0, 1.0)) - clampf(dw, 0.0, 3.0) * 4.0
	sound.call("step", db, 1.0 if dw < 0.6 else 0.75)


## A Tall One has seen you: the sting, and the first time, what to do.
func walker_noticed(_w: Node) -> void:
	sound.call("sting")
	if not _told_escape:
		_told_escape = true
		hud.call("toast", "IT HAS SEEN YOU. GET INTO ANOTHER SLICE.", Color(1.0, 0.32, 0.26), 3.4)


## A Tall One reached you: a red flash, back to the room's way in, the Tall Ones back at their posts.
func walker_caught(_w: Node) -> void:
	if mode != "play":
		return
	mode = "dead"
	deaths += 1
	player.set("input_enabled", false)
	sound.call("death")
	hud.call("flash", Color(0.75, 0.02, 0.02), 1.4)
	hud.call("fade_to", 1.0, 1.6)
	await get_tree().create_timer(1.1).timeout
	var c: Dictionary = level.call("checkpoint_for", player.call("feet"))
	player.call("place", c["at"], float(c.get("yaw", 0.0)))
	level.call("reset_walkers")
	await get_tree().physics_frame
	hud.call("fade_to", 0.0, 1.6)
	hud.call("toast", "A TALL ONE CAUGHT YOU", Color(1.0, 0.4, 0.34), 2.6)
	mode = "play"
	player.set("input_enabled", true)


## A lore log read.
func log_read(l: Dictionary) -> void:
	if logs_read.has(String(l["name"])):
		return
	logs_read[String(l["name"])] = true
	sound.call("tick")
	hud.call("toast", "%s  ·  LOG %d OF %d" % [String(l["name"]), logs_read.size(), LOG_TOTAL], Color(1.0, 0.74, 0.42), 2.6)


## The first time a Tall One stands in your view, in your slice, close: its film.
func _check_sighting() -> void:
	var cam: Camera4D = player.get("camera")
	if cam == null:
		return
	for w in level.get("walkers"):
		if not is_instance_valid(w):
			continue
		var q: Vector4 = (w as Node4D).global_position
		var p: Vector4 = player.global_position
		if absf(p.w - q.w) > 0.4:
			continue
		var head: Vector4 = q + Vector4(0, 2.6, 0, 0)
		var rel: Vector4 = head - cam.global_position
		var dist: float = Vector2(rel.x, rel.z).length()
		if dist > 14.0 or dist < 2.0:
			continue
		var fwd: Vector4 = -cam.global_basis.z
		if rel.normalized().dot(fwd) < cos(deg_to_rad(26.0)):
			continue
		if not bool(w.call("clear_line_to", player.global_position + Vector4(0, 0.6, 0, 0))):
			continue
		sighted = true
		_sighting_film(w)
		return


func _sighting_film(w: Node) -> void:
	var cam: Camera4D = player.get("camera")
	var e0: Vector4 = cam.global_position
	var b0: Projection = cam.global_basis
	var q: Vector4 = (w as Node4D).global_position
	var head: Vector4 = q + Vector4(0, 2.62, 0, 0)
	var to_head: Vector4 = head - e0
	var e1: Vector4 = e0 + Vector4(to_head.x, 0, to_head.z, 0) * 0.35
	var look1: Projection = _look_basis(e1, head)
	var flat := Vector2(e0.x - q.x, e0.z - q.z).normalized()
	var e2: Vector4 = Vector4(q.x + flat.x * 1.7, 2.05, q.z + flat.y * 1.7, q.w)
	var look2: Projection = _look_basis(e2, head)
	w.call("start_film", film_camera)
	sound.call("sight")
	play_film([
		{"eye": e0, "eye2": e1, "basis": b0, "basis2": look1, "seconds": 2.6, "caption": ""},
		{"eye": e2, "eye2": e2 + Vector4(flat.x, 0, flat.y, 0) * -0.25, "basis": look2, "seconds": 3.2, "caption": ""},
		{"eye": e1, "eye2": e0, "basis": look1, "basis2": b0, "seconds": 1.8, "caption": "It has not seen you. Not yet."},
	], func() -> void:
		w.call("end_film")
		show_popup("walkers", {"kicker": "THE TALL ONES", "title": "THEY HAVE NOT SEEN YOU", "lines": [
			"Each one lives in a single slice of W. It can only see you in its slice.",
			"Keep out of its sight. If its eyes go red, it walks to you.",
			"Then get into another slice: hold E or Q."]}))


func _look_basis(eye: Vector4, at: Vector4) -> Projection:
	var d: Vector4 = at - eye
	var flat: float = Vector2(d.x, d.z).length()
	return Basis4D.from_zx(atan2(-d.x, -d.z)) * Basis4D.from_yz(atan2(d.y, maxf(flat, 0.0001)))


## Level 3: a seal light lit (`count` of two). With both, a short film shows the Heart open.
func seal_lit(which: String, count: int) -> void:
	sound.call("relic")
	var col: Color = Build.KATA if which == "kata" else Build.ANA
	hud.call("toast", "SEAL  ·  THE %s LIGHT  ·  %d OF 2" % [which.to_upper(), count], col.lerp(Color.WHITE, 0.3), 3.0)
	if count < 2:
		return
	await get_tree().create_timer(1.2).timeout
	if mode != "play":
		return
	var cz: float = 2.0
	var turned: Projection = _turned_frame(0.0)
	var shots: Array = [
		{"eye": Vector4(0.0, 2.2, 13.0, 0.0), "basis": Basis4D.from_yz(-0.08), "seconds": 2.4, "caption": "Both lights are lit."},
		{"eye": Vector4(0.0, 1.7, cz, 0.4), "basis": Basis4D.from_zx(0.0), "basis2": turned, "seconds": 2.6, "caption": "At the centre, turn into W..."},
		{"eye": Vector4(0.0, 1.7, cz, 0.4), "eye2": Vector4(0.0, 1.7, cz, 1.2), "basis": turned, "seconds": 3.2, "caption": "...the Heart is open. Walk in along W."},
	]
	play_film(shots)


## A frame looking exactly ana, heading `yaw` (0 faces -z before the turn).
func _turned_frame(yaw: float) -> Projection:
	var best: Projection = Basis4D.from_zx(yaw)
	var best_fw: float = -INF
	for sgn in [-1.0, 1.0]:
		var f: Projection = Basis4D.from_zx(yaw) * Basis4D.from_zw(sgn * PI * 0.5)
		if (-f.z).w > best_fw:
			best_fw = (-f.z).w
			best = f
	return best


## A level's one-line hint.
func hint(text: String) -> void:
	hud.call("toast", text, Color.WHITE, 3.0)


## Level 3: shifting ana at the centre stopped dead.
func blocked_by_vault() -> void:
	hud.call("toast", "SOMETHING ANA OF YOU STOPS YOU. TURN TO SEE IT.", Build.DEEP.lerp(Color.WHITE, 0.4), 3.6)
	if not learned.has("turn"):
		teach("turn")


## Level 3: into the Heart. A quiet film, then the end card.
func reach_heart() -> void:
	if mode != "play":
		return
	sound.call("finale")
	await get_tree().create_timer(1.6).timeout
	var shots: Array = [
		{"eye": Vector4(2.6, 1.6, 5.2, 5.2), "eye2": Vector4(1.8, 1.9, 5.4, 5.2), "basis": Basis4D.from_zx(0.45) * Basis4D.from_yz(0.12), "seconds": 4.0, "caption": "The Heart of the Annex."},
		{"eye": Vector4(0.0, 2.4, 2.0, -1.2), "eye2": Vector4(0.0, 3.0, 2.0, -3.2), "basis": _turned_frame(0.0) * Basis4D.from_yz(-0.16), "seconds": 4.6, "caption": "Kata to ana, every band of the Annex, in a row. You walked here through them."},
	]
	play_film(shots, finish_game)


## The finale's card.
func finish_game() -> void:
	mode = "end"
	player.set("input_enabled", false)
	var mins: int = int(clock) / 60
	var secs: int = int(clock) % 60
	hud.set("end_card", {"title": "COMPLETE", "lines": [
		"Time  %d:%02d" % [mins, secs],
		"You walked through rooms that share one place, side by side in W.",
	]})
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	sound.call("finale")


func restart_game() -> void:
	hud.set("end_card", {})
	clock = 0.0
	has_lens = false
	if capture_mouse:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	load_level(0)


## The Esc guard asks this first (hud/mr2_escape.gd): close the top thing open and say so.
func escape_step(key: Key) -> bool:
	if key != KEY_ESCAPE:
		return false
	if bool(tuning.call("is_open")):
		tuning.call("close")
		return true
	if mode == "film":
		skip_film()
		return true
	if mode == "popup":
		close_popup()
		return true
	return false
