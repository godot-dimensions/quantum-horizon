extends SceneTree

## Andrew's walker and the W rotation, as the playable world has them (Ramon, 9 Oct: "make sure we're
## using andrews walker and w rotation settings from the playable world"). For every setting of the
## walker, its camera rig, the camera, the gait, the avatar and the capsule, the pen's value (what
## playable_world.tscn sets on its Player, else the pen script's own default) against the maze's, in a
## level. Nothing of the pen is opened or changed: its scene is read as text, its scripts only
## instanced to read their defaults.
## Prints a table: SAME, KEPT (a difference on purpose, with why) or DIFF, then "WALKER: PASS" when there
## is no DIFF.
##   run.sh headless walker res://ramon/PhaseMazeRemake/scripts/_check_walker_settings_runner.gd

const PEN := "res://ramon/chickenpen/playable_world.tscn"
const PEN_SCRIPTS := {
	"walker": "res://ramon/chickenpen/scripts/block_walker_character_4d.gd",
	"rig": "res://ramon/chickenpen/scripts/pen_orbit_rig_4d.gd",
	"gait": "res://ramon/chickenpen/scripts/block_gait_4d.gd",
	"avatar": "res://ramon/chickenpen/scripts/block_avatar_4d.gd",
}
const NODES := {"walker": "Player", "rig": "Player/CameraRig", "gait": "Player/Gait", "avatar": "Player/Avatar", "camera": "Player/CameraRig/Pitch/Camera4D"}
const CHECK := {
	"walker": ["run_speed", "walk_speed", "sprint_speed", "jump_velocity", "acceleration", "turn_speed", "w_speed_scale", "step_height", "step_reach"],
	"rig": ["mouse_sensitivity", "home_seconds", "pitch_min_degrees", "pitch_max_degrees", "max_distance", "zoom_speed", "collision_margin", "min_distance", "distance", "pivot_height"],
	"camera": ["rendering_engine_name", "w_fade_distance", "field_of_view_4d"],
	"gait": ["run_speed", "stride_length", "step_height", "arm_swing", "body_bob"],
	"avatar": ["build", "shorts_length", "eyes", "eye_spacing", "eye_height", "eye_width", "eye_tall", "skin", "accent"],
}
## Differences on purpose, and why.
const KEPT := {
	"rig.min_distance": "the arm comes all the way in, for 6 m corridors",
	"rig.distance": "the maze's chase framing (3.6 m), made for corridors; the pen's is an open-field preset",
	"rig.pivot_height": "the maze's chase framing (2.1 m)",
	"avatar.skin": "the maze's walker is dark blue (Ramon, 9 Oct)",
	"avatar.accent": "the maze's walker is dark blue (Ramon, 9 Oct)",
}
## Set by the running walker itself, not by a setting: the same avatar gives the same value in the pen.
const MEASURED := {
	"gait.stride_length": "capped at startup to what the legs reach (block_gait_4d.gd _measure); the pen's export is 0.95 in both",
}
const SCENE := "res://ramon/PhaseMazeRemake/phase_maze_remake.tscn"

var _t0: int = 0


func _initialize() -> void:
	_t0 = Time.get_ticks_msec()
	_run.call_deferred()


func _process(_x: float) -> bool:
	if Time.get_ticks_msec() - _t0 > 90000:
		print("WALKER: gave up after 90 s")
		return true
	return false


## The pen scene's property lines per node path, read as text.
func _pen_overrides() -> Dictionary:
	var out: Dictionary = {}
	var text: String = FileAccess.get_file_as_string(PEN)
	var current: String = ""
	for line in text.split("\n"):
		if line.begins_with("[node "):
			var nm: String = line.get_slice("name=\"", 1).get_slice("\"", 0)
			var parent: String = line.get_slice("parent=\"", 1).get_slice("\"", 0) if line.contains("parent=") else ""
			current = nm if parent == "." else (parent + "/" + nm if parent != "" else "")
			continue
		if line.begins_with("["):
			current = ""
			continue
		if current != "" and line.contains(" = "):
			if not out.has(current):
				out[current] = {}
			out[current][line.get_slice(" = ", 0)] = str_to_var(line.substr(line.find(" = ") + 3))
	return out


func _same(a: Variant, b: Variant) -> bool:
	if a is float or b is float:
		return absf(float(a) - float(b)) < 0.0005
	if a is Color and b is Color:
		return (a as Color).is_equal_approx(b)
	return a == b


func _run() -> void:
	var over: Dictionary = _pen_overrides()
	var pen: Dictionary = {}
	for part in PEN_SCRIPTS:
		var o: Object = (load(String(PEN_SCRIPTS[part])) as Script).new()
		var vals: Dictionary = {}
		for k in CHECK[part]:
			vals[k] = o.get(k)
		var node_over: Dictionary = over.get(NODES[part], {})
		for k in node_over:
			vals[k] = node_over[k]
		# The pen's rig opens on a preset that sets its framing and lens (use_preset).
		if part == "rig" and int(node_over.get("start_preset", -1)) >= 0:
			var p: Array = (o.call("presets") as Array)[int(node_over["start_preset"])]
			vals["distance"] = float(p[2])
			vals["pivot_height"] = float(p[3])
			pen["camera.field_of_view_4d"] = deg_to_rad(float(p[1]))
		for k in vals:
			pen["%s.%s" % [part, k]] = vals[k]
		if o is Node:
			(o as Node).free()
	var cam_over: Dictionary = over.get(NODES["camera"], {})
	for k in ["rendering_engine_name", "w_fade_distance"]:
		pen["camera." + k] = cam_over.get(k, Camera4D.new().get(k))
	# The maze, in level 2 (the walker's W step is on in a level).
	var m: Node = (load(SCENE) as PackedScene).instantiate()
	m.set("keep_bests", false)
	root.add_child(m)
	for i in 10:
		await process_frame
	m.call("_load_level", 1)
	for i in 10:
		await process_frame
	var maze_nodes := {"walker": m.get("player"), "rig": m.get("rig"), "gait": (m.get("player") as Node).get_node("Gait"), "avatar": m.get("avatar"), "camera": m.get("camera")}
	var diffs: int = 0
	for part in CHECK:
		for k in CHECK[part]:
			var key: String = "%s.%s" % [part, k]
			var a: Variant = pen.get(key)
			var b: Variant = (maze_nodes[part] as Object).get(k)
			var verdict: String = "SAME"
			if not _same(a, b):
				if MEASURED.has(key):
					verdict = "RUN"
				elif KEPT.has(key):
					verdict = "KEPT"
				else:
					verdict = "DIFF"
					diffs += 1
			var why: String = KEPT.get(key, "") if verdict == "KEPT" else (MEASURED.get(key, "") if verdict == "RUN" else "")
			print("WALKER: %-5s %-28s pen %-22s maze %-22s %s" % [verdict, key, str(a), str(b), why])
	# The capsule.
	var shape: CapsuleShape4D = ((m.get("player") as Node).get_node("CollisionShape4D") as CollisionShape4D).shape
	var pen_text: String = FileAccess.get_file_as_string(PEN)
	var pen_r: float = float(pen_text.get_slice("id=\"body_shape\"]", 1).get_slice("radius = ", 1).get_slice("\n", 0))
	var pen_h: float = float(pen_text.get_slice("id=\"body_shape\"]", 1).get_slice("full_height = ", 1).get_slice("\n", 0))
	for pair in [["capsule.radius", pen_r, shape.radius], ["capsule.full_height", pen_h, shape.full_height]]:
		var ok: bool = _same(pair[1], pair[2])
		if not ok:
			diffs += 1
		print("WALKER: %-5s %-28s pen %-22s maze %-22s" % ["SAME" if ok else "DIFF", pair[0], str(pair[1]), str(pair[2])])
	print("WALKER: %s" % ("PASS" if diffs == 0 else "FAIL, %d settings differ" % diffs))
	quit()
