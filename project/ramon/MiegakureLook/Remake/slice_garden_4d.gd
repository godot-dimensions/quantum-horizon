extends Node4D
## SLICE GARDEN: the Miegakure remake (PLAN.md, RESEARCH.md). A little walker on four floating
## islands, each one 4D idea: the Wall, the Cage, the Seam, the Shrine.
##
## THIS NODE builds the scene in code (the garden, the walker, the camera, the light, the HUD, the dev
## panel) and runs the sequence: which island you are on (by your Z), its arrival ring as the
## checkpoint, its title card, the camera leaning to frame it, falls and restarts, hints, and the
## finale at the shrine door. It also answers the hands' questions: which crates and rocks there
## are, and whether a box would overlap anything (there is no shape query in PhysicsServer4D).
##
## KEYS: WASD walk (in the world you see), Space jump, right mouse or Tab turn the view into W, E lift
## or put down, left mouse strike, R restart the island, F a hint, V 4D sight, F1 the artist dev
## panel, H back to the menu (the shared Demo/return_button.tscn).
##
## 4D SIGHT (V; PLAN.md step 55): the Combined renderer, which draws a faint projection of what lies
## ana and kata of your slice over it. Everything is switched out of that projection
## (MeshInstance4D.allow_projection, godot-4d 6875f37) except the things a puzzle turns on: the
## crates, the cage, the rocks, the shrine and the tower, so you see where they are in the worlds
## beside yours and nothing else. Off by default: Miegakure's rule is that you see one slice.
##
## FORGIVING (PLAN.md decision 11): a fall fades to white and puts you on the island's arrival ring
## with whatever you carried sent home; R does the same and also puts the island's crates and rocks
## back. Neither takes more than a second.
##
## NO class_name (engine_gotchas.md).

const Env := preload("res://ramon/MiegakureLook/Remake/world/mk_env_4d.gd")
const Garden := preload("res://ramon/MiegakureLook/Remake/world/mk_garden_4d.gd")
const Cam := preload("res://ramon/MiegakureLook/Remake/scripts/mk_camera_4d.gd")
const WalkerBuild := preload("res://ramon/MiegakureLook/Remake/character/mk_walker_build.gd")
const Hands := preload("res://ramon/MiegakureLook/Remake/character/mk_hands_4d.gd")
const Feet := preload("res://ramon/MiegakureLook/Remake/character/mk_feet_4d.gd")
const Onlooker := preload("res://ramon/MiegakureLook/Remake/character/mk_onlooker_4d.gd")
const Hud := preload("res://ramon/MiegakureLook/Remake/hud/mk_hud.gd")
const Tuner := preload("res://ramon/MiegakureLook/Remake/hud/mk_tuner.gd")
const Build := preload("res://ramon/MiegakureLook/Remake/world/mk_build.gd")
const Fx := preload("res://ramon/MiegakureLook/Remake/world/mk_fx_4d.gd")
const Sound := preload("res://ramon/MiegakureLook/Remake/world/mk_sound_4d.gd")
const ReturnButton := preload("res://ramon/Demo/return_button.tscn")

signal island_entered(number: int)
signal finished

## Start on this island (1-4): for testing, and for a runner that wants to begin later.
@export_range(1, 4) var start_island: int = 1
## The opening shot down the garden to the tower (island 1 only). Runners switch it off.
@export var play_intro: bool = true

var env: Node4D
var garden: Node4D
var walker: CharacterBody4D
var camera: Camera4D
var hands: Node4D
var hud: Control
var tuner: Control
var onlooker: Node4D
var sound: Node

var island: int = 0
var falls: int = 0
var elapsed: float = 0.0
var done: bool = false
var _reached: Dictionary = {}
var _respawning: bool = false
var _intro_hold: bool = false
var sight: bool = false
## Seconds since anything moved the puzzle on (a turn, a lift, a put-down, a strike, a new island).
## After AUTO_HINT_SECONDS the island's hint shows by itself, once per island (PLAN.md step 54).
const AUTO_HINT_SECONDS := 45.0
var _idle_progress: float = 0.0
var _hinted: Dictionary = {}


func _ready() -> void:
	env = Node4D.new()
	env.name = "Env"
	env.set_script(Env)
	add_child(env)
	garden = Node4D.new()
	garden.name = "Garden"
	garden.set_script(Garden)
	add_child(garden)
	garden.call("build")
	walker = WalkerBuild.make()
	add_child(walker)
	camera = Camera4D.new()
	camera.name = "Camera"
	camera.set_script(Cam)
	add_child(camera)
	camera.set("target_path", camera.get_path_to(walker))
	camera.set("env_path", camera.get_path_to(env))
	walker.set("camera_path", walker.get_path_to(camera))
	hands = Node4D.new()
	hands.name = "Hands"
	hands.set_script(Hands)
	walker.add_child(hands)
	hands.set("game", self)
	var feet := Node4D.new()
	feet.name = "Feet"
	feet.set_script(Feet)
	walker.add_child(feet)
	env.set("follow", walker)
	onlooker = Node4D.new()
	onlooker.name = "Onlooker"
	onlooker.set_script(Onlooker)
	add_child(onlooker)
	onlooker.global_position = Vector4(4.7, 0.0, 1.9, 0.0)
	onlooker.set("watched", walker)
	var layer := CanvasLayer.new()
	layer.name = "HudLayer"
	add_child(layer)
	hud = Control.new()
	hud.name = "Hud"
	hud.set_script(Hud)
	hud.set("game", self)
	hud.set("camera", camera)
	hud.set("walker", walker)
	hud.set("hands", hands)
	layer.add_child(hud)
	tuner = PanelContainer.new()
	tuner.name = "Tuner"
	tuner.set_script(Tuner)
	tuner.set("env", env)
	tuner.set("camera", camera)
	layer.add_child(tuner)
	add_child(ReturnButton.instantiate())
	sound = Node.new()
	sound.name = "Sound"
	sound.set_script(Sound)
	sound.set("listener", walker)
	# Quiet in test runs (a runner's window must not play music over Ramon's work), unless the run
	# is a film being recorded.
	# (Movie Maker mode is the "movie" feature: --write-movie never shows in the script's arguments.)
	if "--script" in OS.get_cmdline_args() and not OS.has_feature("movie"):
		sound.set("muted", true)
	add_child(sound)
	if bool(sound.get("muted")):
		sound.call("set_bed", false)
	_wire_sounds()
	camera.connect("turn_started", func(_t: bool) -> void: _progress())
	hands.connect("lifted", func(_c: Node) -> void: _progress())
	hands.connect("placed", func(_c: Node) -> void: _progress())
	for p in plugs():
		p.connect("struck", func(_h: int) -> void: _progress())
	walker.connect("fell", _on_fell)
	hands.connect("refused", func(reason: String) -> void: hud.call("show_note", reason))
	for c in crates():
		c.connect("went_home", func() -> void: hud.call("show_note", "the crate went home"))
	_setup_sight()
	_start_on(start_island)
	if play_intro and start_island == 1:
		camera.call("start_intro")
		walker.set("input_enabled", false)
		_intro_hold = true


## Every event that makes a sound, in one place (world/mk_sound_4d.gd; events in other worlds are
## quieter by their distance in W).
## Anything that moves a puzzle on resets the auto-hint's clock.
func _progress() -> void:
	_idle_progress = 0.0


func _wire_sounds() -> void:
	camera.connect("turn_started", func(_t: bool) -> void: sound.call("play", "turn"))
	hands.connect("lifted", func(_c: Node) -> void: sound.call("play", "lift"))
	hands.connect("placed", func(_c: Node) -> void: sound.call("play", "place"))
	hands.connect("refused", func(_r: String) -> void: sound.call("play", "refuse"))
	for p in plugs():
		var plug: Node4D = p
		plug.connect("struck", func(hits: int) -> void:
			if hits < int(plug.get("hits_needed")):
				sound.call("play", "strike", plug.global_position))
		plug.connect("broken", func() -> void:
			sound.call("play", "strike", plug.global_position)
			sound.call("play", "shatter", plug.global_position))
	for info in islands():
		for pl in info.get("plates", []):
			var plate: Node4D = pl
			plate.connect("pressed_changed", func(on: bool) -> void:
				if on:
					sound.call("play", "plate", plate.global_position))
		for br in info.get("bridges", []):
			var bridge: Node4D = br
			bridge.connect("laid", func() -> void: sound.call("play", "bridge", bridge.global_position))


func _start_on(number: int) -> void:
	var info: Dictionary = islands()[number - 1]
	walker.call("place_at", info["spawn"], float(info.get("facing", PI)))
	camera.call("snap_focus")
	_enter(number)


func islands() -> Array:
	return garden.get("islands")


## The island you are on, as registered by the garden ({} before the first).
func current_island() -> Dictionary:
	if island <= 0:
		return {}
	return islands()[island - 1]


func crates() -> Array:
	return garden.get("crates")


func plugs() -> Array:
	return garden.get("plugs")


## Would a box ([centre, size]) overlap a wall, a floor, a rock, or a crate (other than `ignore`)?
func blocked(centre: Vector4, size: Vector4, ignore: Node = null) -> bool:
	return blocker(centre, size, ignore) != ""


## What a box would overlap, in words ("" for nothing): for the runners' reports.
func blocker(centre: Vector4, size: Vector4, ignore: Node = null) -> String:
	for s in garden.get("solids"):
		if Build.overlaps(centre, size, s[0], s[1], 0.02):
			return "solid at %s size %s" % [s[0], s[1]]
	for p in plugs():
		if not bool(p.call("is_broken")):
			var b: Array = p.call("bounds")
			if Build.overlaps(centre, size, b[0], b[1], 0.02):
				return "rock %s" % (p as Node).name
	for c in crates():
		if c == ignore or bool(c.call("is_carried")):
			continue
		var cb: Array = c.call("bounds")
		if Build.overlaps(centre, size, cb[0], cb[1], 0.02):
			return "crate %s" % (c as Node).name
	for info in islands():
		for br in info.get("bridges", []):
			if bool(br.call("is_laid")):
				for plank in (br as Node).get_children():
					if plank is StaticBody4D:
						var shape := (plank as Node).get_child(0) as CollisionShape4D
						if shape != null and Build.overlaps(centre, size, (plank as Node4D).global_position, (shape.shape as BoxShape4D).size, 0.02):
							return "bridge plank"
	return ""


func _enter(number: int) -> void:
	if number == island:
		return
	island = number
	var info: Dictionary = current_island()
	camera.set("frame_center", info["centre"])
	camera.set("frame_active", true)
	env.set("island_centre", info["centre"])
	if not _reached.has(number):
		_reached[number] = true
		var subs := ["Go round the wall through W.", "Take the crate out of the cage.", "Find the door in the fence across W.", "Reach the shrine."]
		hud.call("show_title", number, String(info["name"]), subs[number - 1])
	_progress()
	island_entered.emit(number)


func _process(delta: float) -> void:
	if _intro_hold and not bool(camera.call("in_intro")):
		_intro_hold = false
		walker.set("input_enabled", true)
	if not done and not _intro_hold:
		elapsed += delta
	# Which island: by Z (each island owns a Z range; the bridges belong to the island they lead to).
	var z: float = walker.global_position.z
	for info in islands():
		var zr: Vector2 = info["z"]
		if z >= zr.x and z <= zr.y and int(info["number"]) > island:
			_enter(int(info["number"]))
	if not done and not _intro_hold and island > 0:
		_idle_progress += delta
		if _idle_progress > AUTO_HINT_SECONDS and not _hinted.has(island):
			_hinted[island] = true
			hud.call("show_hint", String(current_island()["hint"]))
	if onlooker != null:
		hud.call("set_bubble", onlooker.call("bubble", camera.call("slice_normal"), walker.global_position))
	# The finale: at the shrine door.
	if not done and island == 4:
		var door: Vector4 = garden.get("shrine_door")
		var d: Vector4 = walker.global_position - door
		if Vector3(d.x, d.z, d.w).length() < 1.3 and absf(d.y) < 0.8:
			_finale()


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if k.keycode == KEY_R:
		if done:
			get_tree().reload_current_scene()
		else:
			restart_island()
		get_viewport().set_input_as_handled()
	elif k.keycode == KEY_V:
		set_sight(not sight)
		get_viewport().set_input_as_handled()
	elif k.keycode == KEY_F:
		var info: Dictionary = current_island()
		if not info.is_empty():
			hud.call("show_hint", String(info["hint"]))
		get_viewport().set_input_as_handled()


## Only the puzzle's things project in 4D sight: every other mesh in the garden opts out.
func _setup_sight() -> void:
	var keep: Dictionary = {}
	for g in get_tree().get_nodes_in_group(&"mk_ghost"):
		keep[g] = true
	for m in garden.find_children("*", "MeshInstance4D", true, false):
		var n: Node = m
		var ghost: bool = false
		while n != null and n != garden:
			if keep.has(n):
				ghost = true
				break
			n = n.get_parent()
		(m as MeshInstance4D).set("allow_projection", ghost)
	for m in walker.find_children("*", "MeshInstance4D", true, false):
		(m as MeshInstance4D).set("allow_projection", false)
	if onlooker != null:
		for m in onlooker.find_children("*", "MeshInstance4D", true, false):
			(m as MeshInstance4D).set("allow_projection", false)


## 4D sight on or off. The root gets a 3D world first: switching a camera from Cross-section to
## Combined in one run crashes the engine otherwise (the 30 Sept engine bug; menu_final.gd and
## PathCreator do the same).
func set_sight(on: bool) -> void:
	if get_tree().root.world_3d == null:
		get_tree().root.world_3d = World3D.new()
	sight = on
	camera.set("rendering_engine_name", "Combined" if on else "Cross-section")
	camera.set("projection_opacity_base", 0.06)
	hud.call("show_note", "4D sight on" if on else "4D sight off")


func _on_fell() -> void:
	falls += 1
	_respawn(false)


## R: the island as you found it, you on its arrival ring.
func restart_island() -> void:
	_respawn(true)


func _respawn(reset_island: bool) -> void:
	if _respawning:
		return
	_respawning = true
	walker.set("input_enabled", false)
	hud.call("fade_to", 1.0)
	await get_tree().create_timer(0.32).timeout
	hands.call("drop_carried")
	var info: Dictionary = current_island()
	if reset_island:
		for c in info.get("crates", []):
			c.call("reset_home")
		for p in info.get("plugs", []):
			p.call("reset")
	walker.call("place_at", info["spawn"], float(info.get("facing", PI)))
	camera.call("snap_focus")
	Fx.ring(self, (info["spawn"] as Vector4) - Vector4(0, 0.05, 0, 0), Color(0.30, 0.80, 0.76), 1.4, 1.2, 0.7)
	hud.call("fade_to", 0.0)
	await get_tree().create_timer(0.2).timeout
	walker.set("input_enabled", true)
	_respawning = false


func _finale() -> void:
	done = true
	walker.set("input_enabled", false)
	walker.set("scripted", true)
	walker.set("scripted_move", Vector2.ZERO)
	for lamp in garden.get("tower_lamps"):
		var m := (lamp as MeshInstance4D).material_override as TetraMaterial4D
		m.get_cross_section_material_3d().set_shader_parameter("glow_color", Color(1.0, 0.82, 0.40))
		m.get_cross_section_material_3d().set_shader_parameter("pulse", 0.4)
	var secs: int = int(elapsed)
	hud.call("show_finale", {"time": "%d:%02d" % [secs / 60, secs % 60], "turns": int(camera.get("swaps")), "falls": falls})
	sound.call("play", "finale")
	# A slow pull-out round the tower (PLAN.md step 35): wider, lower, and centred on the shrine.
	camera.set("frame_center", garden.get("shrine_door"))
	camera.set("frame_lean", 0.85)
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var d0: float = float(camera.get("distance"))
	var p0: float = float(camera.get("pitch_degrees"))
	var y0: float = float(camera.get("yaw_degrees"))
	tw.tween_method(func(k: float) -> void:
		camera.set("distance", lerpf(d0, 17.0, k))
		camera.set("pitch_degrees", lerpf(p0, 42.0, k))
		camera.set("yaw_degrees", lerpf(y0, 48.0, k))
		camera.call("refresh_lens"), 0.0, 1.0, 6.0)
	finished.emit()
