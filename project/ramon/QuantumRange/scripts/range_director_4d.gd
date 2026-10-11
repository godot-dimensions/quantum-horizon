extends Node

## Runs the range: which experiment is chosen, its four stages one after another, the clock, the score,
## the restarts, and what the HUD, the console and the metrics wall say about it.
##
##   lobby      nothing running; choose at the console (shoot a number, or 1 to 6) and START (shoot it,
##              or F)
##   intro      a stage's card ("STAGE B · STEP THROUGH W"); the first stage gets a 3 2 1 countdown
##   stage      its targets are out; the experiment's tick() says when it is done (or failed)
##   cleared    a moment's pause and a chime, then the next stage
##   results    the results card, the console marks it done, the metrics wall fills in its row; F (or
##              START) goes on to the next experiment, R plays it again
##   failed     strict mode stopped the round: R restarts the stage
##   gallery    F2: every target family on show, nothing scored (the free range)
##
## R restarts the stage, Shift+R the whole experiment, at any time. The bests are kept per viewer in
## user://quantum_range.cfg.
##
## NO class_name (engine_gotchas.md).

const Layout := preload("res://ramon/QuantumRange/scripts/range_layout.gd")
const Style := preload("res://ramon/QuantumRange/scripts/range_style.gd")
const SAVE := "user://quantum_range.cfg"
const EXPERIMENTS := [
	"res://ramon/QuantumRange/scripts/experiments/exp_locate.gd",
	"res://ramon/QuantumRange/scripts/experiments/exp_charge.gd",
	"res://ramon/QuantumRange/scripts/experiments/exp_reveal.gd",
	"res://ramon/QuantumRange/scripts/experiments/exp_incoming.gd",
	"res://ramon/QuantumRange/scripts/experiments/exp_skeet.gd",
	"res://ramon/QuantumRange/scripts/experiments/exp_wolf.gd",
]

signal changed

var range_root: Node
var player: CharacterBody4D
var weapon: Node
var hud: Control
var console: Node
var sfx: Node
var targets_parent: Node4D
## An experiment's own furniture (lanes, trap houses), cleared when the experiment changes.
var props: Node4D
## The one spot (Ramon: "only one spot when it matters"): on over the stage area while a stage runs.
var spot: Node
var dev_panel: Control
var _spot_k: float = 0.0
## F2's free range: every family on show, each back a moment after it is shot.
const GALLERY := [
	["Pip", "res://ramon/QuantumRange/scripts/targets/target_pip.gd", {}, Vector3(-4.5, 2.0, 9.5)],
	["Amber block", "res://ramon/QuantumRange/scripts/targets/target_block.gd", {}, Vector3(-1.5, 2.0, 9.5)],
	["Armoured core", "res://ramon/QuantumRange/scripts/targets/target_armoured.gd", {}, Vector3(1.5, 2.0, 9.5)],
	["Shell", "res://ramon/QuantumRange/scripts/targets/target_shell.gd", {}, Vector3(4.5, 2.0, 9.5)],
	["Cluster", "res://ramon/QuantumRange/scripts/targets/target_cluster.gd", {}, Vector3(-6.0, 2.6, 15.0)],
	["Capsule", "res://ramon/QuantumRange/scripts/targets/target_capsule.gd", {}, Vector3(-2.0, 2.4, 15.0)],
	["Sentinel", "res://ramon/QuantumRange/scripts/targets/target_sentinel.gd", {}, Vector3(2.0, 2.6, 15.0)],
	["Ring gate", "res://ramon/QuantumRange/scripts/targets/target_ring.gd", {"ring_at": Vector4(0, 0, 0, 0)}, Vector3(6.0, 2.4, 15.0)],
	["Drone", "res://ramon/QuantumRange/scripts/targets/target_drone.gd", {"kind": "red"}, Vector3(-5.0, 3.2, 21.0)],
	["Heavy drone", "res://ramon/QuantumRange/scripts/targets/target_drone.gd", {"kind": "heavy"}, Vector3(-1.6, 3.2, 21.0)],
	["Friendly", "res://ramon/QuantumRange/scripts/targets/target_drone.gd", {"kind": "friendly"}, Vector3(1.8, 3.2, 21.0)],
	["Chicken", "res://ramon/QuantumRange/scripts/targets/target_chicken.gd", {}, Vector3(5.2, 2.8, 21.0)],
	["Wolf", "res://ramon/QuantumRange/scripts/targets/target_wolf.gd", {"route": [{"wait": 9999.0}]}, Vector3(0.0, 0.0, 25.0)],
]
var _gallery_back: Array = []

var experiments: Array = []
var sel: int = 0
## The stage the chosen experiment starts from (0 is A): every stage of every experiment can be played from
## the start, this being an R&D range rather than a game to unlock (Ramon, 6 Oct). Press the experiment's
## number again, or shoot its tile again, for the next.
var sel_stage: int = 0
## The stage the run under way began at: a run from A is a whole run, and only whole runs keep a best.
var run_from: int = 0
## Whether anything has been started yet: the console waits in the middle of the bay until then.
var started_once: bool = false
var state: String = "lobby"
var stage: int = 0
var strict: bool = false
## Seconds in the current state, in the current stage, and in the whole run.
var t_state: float = 0.0
var t_stage: float = 0.0
var t_run: float = 0.0
var stage_times: Array = []
## The last results per experiment id, and the best times.
var results: Dictionary = {}
var bests: Dictionary = {}
## Off for the test runners, so the bot's times are never saved as yours.
var keep_bests: bool = true
## Things the director says once per run (a first ping off a shell...).
var _said: Dictionary = {}
var _count_step: int = -1
var _fail_reason: String = ""


func _ready() -> void:
	for path in EXPERIMENTS:
		var e: RefCounted = (load(path) as Script).new()
		e.set("d", self)
		experiments.append(e)
	var cfg := ConfigFile.new()
	if cfg.load(SAVE) == OK:
		for e in experiments:
			var id: String = String(e.get("id"))
			if cfg.has_section_key("best", id):
				bests[id] = float(cfg.get_value("best", id))
	if weapon != null:
		weapon.set("on_button", press_button)
		weapon.connect("shot", _on_shot)
	_to_lobby()


func current() -> RefCounted:
	return experiments[sel] if sel >= 0 and sel < experiments.size() else null


# -- targets -------------------------------------------------------------------------------------------

## Spawns a target family (a script path or Script) at `at`, with `props` set on it first.
func spawn(script: Variant, at: Vector4, props: Dictionary = {}) -> Node4D:
	var s: Script = load(script) if script is String else script
	var t := Node4D.new()
	t.set_script(s)
	for k in props:
		t.set(String(k), props[k])
	if t.get("camera") == null and "camera" in t:
		t.set("camera", player.get("camera"))
	t.position = at
	targets_parent.add_child(t)
	t.connect("part_hit", _on_part_hit)
	return t


## The live targets (still to be dealt with), those with tag `tag` if given.
func alive(tag: String = "") -> Array:
	var out: Array = []
	for t in targets_parent.get_children():
		if t.has_method("hit") and bool(t.get("alive")):
			if tag.is_empty() or String((t.get("tag") as Dictionary).get("kind", "")) == tag:
				out.append(t)
	return out


func alive_count(tag: String = "") -> int:
	return alive(tag).size()


## Live targets that count towards finishing (not friendlies).
func hostile_count() -> int:
	var n: int = 0
	for t in alive():
		if not String(t.get("family")).contains("friendly"):
			n += 1
	return n


func clear_targets() -> void:
	for t in targets_parent.get_children():
		if t.has_method("leave"):
			t.call("leave")


func clear_props() -> void:
	if props == null:
		return
	for c in props.get_children():
		props.remove_child(c)
		c.queue_free()


# -- the flow ------------------------------------------------------------------------------------------

func select(i: int) -> void:
	if i < 0 or i >= experiments.size():
		return
	if state in ["intro", "stage", "cleared", "failed"] and i != sel:
		clear_targets()
		clear_props()
		state = "lobby"
	if state in ["intro", "stage", "cleared"] and i == sel:
		return
	if state == "results":
		hud.call("hide_results")
		state = "lobby"
	if state == "lobby" and i == sel:
		sel_stage = (sel_stage + 1) % int(experiments[i].call("stage_count"))
	else:
		sel = i
		sel_stage = 0
	if sfx != null:
		sfx.call("play", "click", 1.2 + 0.08 * float(sel_stage), -6.0)
	_refresh()


## START: the chosen experiment from the chosen stage, from the lobby or again from the results.
func start_pressed() -> void:
	match state:
		"lobby", "gallery", "results":
			start(sel, sel_stage)
		"failed":
			restart_stage()


func press_button(i: int) -> void:
	if i == experiments.size():
		start_pressed()
	else:
		select(i)


func start(i: int, from_stage: int = 0) -> void:
	clear_targets()
	clear_props()
	sel = i
	run_from = clampi(from_stage, 0, int(experiments[i].call("stage_count")) - 1)
	started_once = true
	hud.call("hide_results")
	stage = run_from
	t_run = 0.0
	stage_times = []
	_said = {}
	weapon.call("reset_stats")
	player.call("reset_counters")
	if sfx != null:
		sfx.call("play", "click", 0.9, -4.0)
	_begin_stage(run_from)


func _begin_stage(i: int) -> void:
	clear_targets()
	# Still in the entrance corridor when it starts (1 to 6 and F work anywhere): to the line, facing
	# downrange.
	if player != null and player.global_position.z > Layout.BAY_BACK:
		player.call("place", Layout.STAND, 0.0)
	stage = i
	state = "intro"
	t_state = 0.0
	t_stage = 0.0
	_count_step = -1
	var e: RefCounted = current()
	var st: Dictionary = e.get("stages")[i]
	hud.call("stage_card", String(st.get("title", "")).to_upper(), "%02d  %s   ·   STAGE %s OF %d" % [int(e.get("number")), String(e.get("title")).to_upper(), char(65 + i), int(e.call("stage_count"))], 1.8 if i == run_from else 1.3)
	_refresh()


func restart_stage() -> void:
	if state in ["intro", "stage", "cleared", "failed"]:
		_begin_stage(stage)


func restart_run() -> void:
	if state != "lobby" or current() != null:
		start(sel, run_from)


func _go() -> void:
	state = "stage"
	t_stage = 0.0
	var e: RefCounted = current()
	e.call("begin", stage)
	if sfx != null:
		sfx.call("play", "whoosh", 1.0, -8.0)
	_refresh()


func _finish() -> void:
	var e: RefCounted = current()
	var id: String = String(e.get("id"))
	var st: Dictionary = weapon.get("stats")
	var shots: int = int(st["shots"])
	var useful: int = int(st["pops"]) + int(st["breaks"]) + int(st["chips"])
	var acc: float = 100.0 * float(useful) / float(shots) if shots > 0 else 0.0
	var wasted: int = int(st["scuffs"]) + int(st["pings"]) + int(st["vents"])
	var par: float = 0.0
	var all_stages: Array = e.get("stages")
	for j in range(run_from, all_stages.size()):
		par += float((all_stages[j] as Dictionary).get("par", 0.0))
	var best_before: float = float(bests.get(id, INF))
	# Only a whole run, from A, can set a best.
	var is_best: bool = run_from == 0 and t_run < best_before
	if is_best:
		bests[id] = t_run
	if is_best and keep_bests:
		var cfg := ConfigFile.new()
		cfg.load(SAVE)
		cfg.set_value("best", id, t_run)
		cfg.save(SAVE)
	var r := {"time": t_run, "par": par, "stage_times": stage_times.duplicate(), "shots": shots, "accuracy": acc, "wasted": wasted,
		"penalties": int(st["penalties"]), "w": float(player.get("w_travelled")), "slice": float(player.get("slice_turned")),
		"ray_us": float(st["ray_us"]) / maxf(1.0, float(st["rays"])), "best": bests.get(id, t_run), "new_best": is_best}
	results[id] = r
	state = "results"
	t_state = 0.0
	clear_targets()
	clear_props()
	if sfx != null:
		sfx.call("play", "done", 1.0, -6.0)
	var rows: Array = [["Time", _clock(t_run), is_best], ["Par", _clock(par)], ["Shots", str(shots)], ["Accuracy", "%d%%" % int(round(acc))],
		["Wasted (scuffs, pings, vents)", str(wasted)], ["W travelled", "%.1f m" % r["w"]], ["Slice turned", "%d°" % int(round(float(r["slice"])))]]
	if int(st["penalties"]) > 0:
		rows.append(["Friendlies hit", str(int(st["penalties"]))])
	if e.has_method("extra_rows"):
		rows.append_array(e.call("extra_rows"))
	var from_text: String = "" if run_from == 0 else "   ·   FROM STAGE %s" % char(65 + run_from)
	hud.call("show_results", {"kicker": "%02d  %s   ·   COMPLETE%s" % [int(e.get("number")), String(e.get("title")).to_upper(), from_text],
		"title": "New best" if is_best and best_before < INF else String(e.get("tagline")), "rows": rows,
		"hint": "F OR R  AGAIN      1 TO 6  CHOOSE, AGAIN FOR A STAGE"})
	_refresh()


func _to_lobby() -> void:
	state = "lobby"
	t_state = 0.0
	_refresh()


func _process(delta: float) -> void:
	if current() == null or hud == null:
		return
	t_state += delta
	match state:
		"intro":
			# The first stage counts you in; later ones go once their card has had its moment.
			if stage == run_from:
				var step: int = int((t_state - 1.0) / 0.6)
				if t_state >= 1.0 and step != _count_step and step <= 3:
					_count_step = step
					hud.call("countdown", ["3", "2", "1", "GO"][step], 0.55)
					if sfx != null:
						sfx.call("play", "click", 1.0 if step < 3 else 1.5, -4.0)
				if t_state >= 1.0 + 0.6 * 3.0:
					_go()
			elif t_state >= 1.0:
				_go()
		"stage":
			t_stage += delta
			t_run += delta
			var res: String = String(current().call("tick", stage, delta))
			if res == "done":
				stage_times.append(t_stage)
				state = "cleared"
				t_state = 0.0
				hud.call("toast", "STAGE %s CLEARED   %s" % [char(65 + stage), _clock(t_stage)], Color(0.45, 1.0, 0.62), 1.0)
				if sfx != null:
					sfx.call("play", "pop", 0.8, -2.0)
			elif res == "fail":
				state = "failed"
				t_state = 0.0
				_fail_reason = String(current().call("fail_reason"))
				if sfx != null:
					sfx.call("play", "error", 1.0, -4.0)
		"cleared":
			if t_state >= 1.1:
				if stage + 1 < int(current().call("stage_count")):
					_begin_stage(stage + 1)
				else:
					_finish()
	# The spot: up while a stage runs, down otherwise.
	var want: float = 1.0 if state in ["stage", "cleared"] else 0.0
	_spot_k = move_toward(_spot_k, want, delta / 0.6)
	if spot != null and range_root != null:
		var e2: float = _spot_k * float((range_root.get("tuning") as Dictionary).get("spot_energy", 12.0))
		spot.set("energy", {"bright": e2, "dark": e2})
	if state == "gallery":
		_gallery_tick(delta)
	_feed_hud()
	_feed_console()


# -- input ---------------------------------------------------------------------------------------------

func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	var used: bool = true
	match k.keycode:
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6:
			select(int(k.keycode - KEY_1))
		KEY_F, KEY_ENTER, KEY_KP_ENTER:
			# F while looking at a console button presses that button.
			var hb: int = int(weapon.get("hover_button")) if weapon != null else -1
			if hb >= 0:
				press_button(hb)
			elif current() != null and current().has_method("action") and state == "stage":
				current().call("action")
			else:
				start_pressed()
		KEY_R:
			if k.shift_pressed:
				restart_run()
			elif state == "results":
				start(sel, run_from)
			else:
				restart_stage()
		KEY_F1:
			if dev_panel != null:
				dev_panel.call("toggle")
		KEY_F2:
			toggle_gallery()
		KEY_F3:
			hud.set("show_hitboxes", not bool(hud.get("show_hitboxes")))
			hud.call("toast", "HITBOXES  %s" % ("ON: EVERY PART, DASHED WHEN OFF YOUR SLICE" if bool(hud.get("show_hitboxes")) else "OFF"), Color.WHITE, 1.6)
		KEY_T:
			if current() != null and bool(current().get("has_strict")):
				strict = not strict
				hud.call("toast", "STRICT MODE  %s" % ("ON: A MISS PAUSES THE ROUND" if strict else "OFF"), Color.WHITE, 1.6)
		_:
			used = false
	if used:
		get_viewport().set_input_as_handled()


# -- the free range (F2) -------------------------------------------------------------------------------

func toggle_gallery() -> void:
	if state == "gallery":
		clear_targets()
		_gallery_back = []
		_to_lobby()
		return
	clear_targets()
	clear_props()
	hud.call("hide_results")
	state = "gallery"
	weapon.call("reset_stats")
	for g in GALLERY:
		_gallery_spawn(g)
	hud.call("toast", "TARGET GALLERY: EVERY FAMILY, NOTHING SCORED. F2 TO LEAVE", Color.WHITE, 2.4)


func _gallery_spawn(g: Array) -> void:
	var p: Vector3 = g[3]
	var t: Node4D = spawn(String(g[1]), Vector4(p.x, p.y, Layout.STAND.z - p.z, 0.0), g[2])
	t.set("tag", {"name": String(g[0]), "gallery": g})


func _gallery_tick(delta: float) -> void:
	for t in targets_parent.get_children():
		if t.has_method("hit") and not bool(t.get("alive")) and not t.has_meta("respawn_queued"):
			t.set_meta("respawn_queued", true)
			var g: Variant = (t.get("tag") as Dictionary).get("gallery")
			if g != null:
				_gallery_back.append([1.6, g])
	for b in _gallery_back:
		b[0] = float(b[0]) - delta
	while not _gallery_back.is_empty() and float(_gallery_back[0][0]) <= 0.0:
		_gallery_spawn(_gallery_back.pop_front()[1])


# -- what the hits say ---------------------------------------------------------------------------------

func _on_shot(r: Dictionary) -> void:
	if sfx == null:
		return
	if bool(r.get("vented", false)):
		sfx.call("play", "error", 0.7, -10.0)
		return
	if r.has("button"):
		sfx.call("play", "click", 1.3, -3.0)
		return
	sfx.call("play", "release", 0.8 if bool(r.get("charged", false)) else 1.4, 0.0 if bool(r.get("charged", false)) else -9.0)


func _on_part_hit(t: Node4D, p: Dictionary, outcome: String) -> void:
	if sfx != null:
		match outcome:
			"pop":
				sfx.call("play", "cluck" if String(t.get("family")) == "chicken" else "pop", randf_range(0.95, 1.1) if String(t.get("family")) == "chicken" else 1.6, -4.0)
			"break":
				sfx.call("play", "break", 1.2, -6.0)
			"chip":
				sfx.call("play", "click", 1.6, -8.0)
			"scuff", "ping":
				sfx.call("play", "click", 0.7, -6.0)
			"penalty":
				sfx.call("play", "error", 1.0, -2.0)
	# A few things are worth saying, the first time they happen in a run.
	match outcome:
		"scuff":
			_once("scuff", "AMBER TAKES A CHARGED SHOT: HOLD, THEN RELEASE", Style.glow("armour"))
		"ping":
			if String(p["role"]) == "shell":
				_once("ping_shell", "GREY NEVER BREAKS: STEP PAST IT THROUGH W", Color(0.85, 0.87, 0.9))
			else:
				_once("ping_locked", "LOCKED: CLEAR WHAT GUARDS IT FIRST", Color(0.85, 0.87, 0.9))
		"penalty":
			hud.call("toast", "FRIENDLY HIT", Style.glow("friend"), 1.6)


func _once(key: String, text: String, col: Color) -> void:
	if _said.has(key):
		return
	_said[key] = true
	hud.call("toast", text, col, 2.6)


# -- what it shows -------------------------------------------------------------------------------------

static func _clock(s: float) -> String:
	return "%d:%04.1f" % [int(s) / 60, fmod(s, 60.0)]


func _feed_hud() -> void:
	var e: RefCounted = current()
	var base_keys: Array = [["Click", "Shoot"], ["Hold", "Charge"], ["Q  E", "Step through W"], ["RMB", "Turn the slice"], ["X", "Snap it back"]] + _menu_key()
	match state:
		"gallery":
			hud.set("card", {"kicker": "SHOOTING RANGE  ·  TARGET GALLERY", "title": "Every family, nothing scored", "clock": "",
				"line": "Shoot anything; it comes back. The radar\nand the crosshair read every one.", "progress": Vector2.ZERO})
			hud.set("keys", [["F2", "Leave the gallery"], ["F3", "Hitboxes"]] + base_keys)
		"lobby":
			hud.set("card", {"kicker": "SHOOTING RANGE", "title": "Choose an experiment", "clock": "",
				"line": "Press 1 to 6, or shoot a tile on the console.\nAgain for a stage. Then START, or F.", "progress": Vector2.ZERO,
				"note": "%02d  %s   ·   STAGE %s: %s   ·   W: %s" % [int(e.get("number")), String(e.get("title")).to_upper(), char(65 + sel_stage),
					String((e.get("stages")[sel_stage] as Dictionary).get("title", "")).to_upper(), String(e.get("w_load"))]})
			hud.set("keys", [["1 to 6", "Choose, again for a stage"], ["F", "Start"], ["F2", "Target gallery"]] + base_keys)
		"results":
			hud.set("card", {})
			hud.set("keys", [["F  R", "Again"], ["1 to 6", "Choose"]] + _menu_key())
		"failed":
			hud.set("card", {"kicker": "%02d  %s   ·   ROUND PAUSED" % [int(e.get("number")), String(e.get("title")).to_upper()],
				"title": _fail_reason if not _fail_reason.is_empty() else "Round paused", "clock": _clock(t_run),
				"line": "Strict mode: one miss stops the round.\nPress R to run the stage again.", "progress": Vector2.ZERO})
			hud.set("keys", [["R", "Restart the stage"], ["T", "Strict mode off"]] + _menu_key())
		_:
			var st: Dictionary = e.get("stages")[stage]
			var prog: Vector2 = e.call("progress", stage)
			hud.set("card", {"kicker": "%02d  %s   ·   STAGE %s / %d" % [int(e.get("number")), String(e.get("title")).to_upper(), char(65 + stage), int(e.call("stage_count"))],
				"title": String(st.get("title", "")), "line": String(st.get("line", "")), "progress": prog, "clock": _clock(t_run),
				"note": ("STRICT MODE ON" if strict and bool(e.get("has_strict")) else "")})
			var ks: Array = base_keys.duplicate()
			ks.append_array(e.call("keys"))
			ks.append(["R", "Restart the stage"])
			hud.set("keys", ks)


func _feed_console() -> void:
	if console == null:
		return
	var tiles: Array = []
	for e in experiments:
		var id: String = String(e.get("id"))
		# Nothing is locked: a finished one only gains a small green stopwatch and its best.
		var best: String = _clock(float(bests[id])) if bests.has(id) else ""
		tiles.append([str(int(e.get("number"))), String(e.get("short")), best, bests.has(id), String(e.get("glyph"))])
	var label: String = "START"
	if state == "results":
		label = "AGAIN"
	elif state == "failed":
		label = "RETRY"
	elif state in ["intro", "stage", "cleared"]:
		label = "RUNNING"
	console.call("show", {"sel": sel, "stage": sel_stage if state in ["lobby", "gallery", "results"] else stage, "tiles": tiles, "start": label,
		"hover": int(weapon.get("hover_button")) if weapon != null else -1, "hint": "PRESS 1 TO 6, AGAIN FOR A STAGE",
		"anchor": "near" if started_once else "lobby", "live": state not in ["intro", "stage", "cleared"]})


func _refresh() -> void:
	changed.emit()


## The menu's key, listed while this runs from the menu (its way home sits at the root,
## Menu/scripts/menu_way_home.gd; Ramon, 11 Oct: M is the menu everywhere, Esc only stops things).
func _menu_key() -> Array:
	return [["M", "Menu"]] if is_inside_tree() and get_tree().root.has_node(^"WayHome") else []
