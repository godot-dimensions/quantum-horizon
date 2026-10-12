extends SceneTree

## BOTANY LAB, round 8's checks (follow_up/arboretum.md section 13): the oak's round solid measured by rays
## and walked into, its height after the dev panel's load and the pedestals' rebuild, the wall panels and the
## signs where they belong, the dark mode's spots, then the second room: it opens grey whatever the hall was,
## B and the switch toggle it, the SKY AND SUN page, the grass colour from the saved file, the hall's palette
## given back. Windowed and unfocusable, the player's input off and the mouse left free. Frames in
## smoke_test_output/botany_lab/round8/. Saves nothing (no SAVE is pressed).

const HALL := "res://ramon/Arboretum/botany_lab.tscn"
const GARDENS := "res://ramon/Arboretum/botany_lab/compare/botany_compare.tscn"
const OUT := "res://smoke_test_output/botany_lab/round8/"
const Style := preload("res://ramon/Arboretum/botany_lab/carried/kit/kit_style.gd")

var _room: Node4D
var _deadline: int = 0
var _passed: int = 0
var _failed: int = 0


func _initialize() -> void:
	root.unfocusable = true
	_deadline = Time.get_ticks_msec() + 300000
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	(func() -> void: _run()).call_deferred()


func _process(_d: float) -> bool:
	if Time.get_ticks_msec() > _deadline:
		print("R8 TIMEOUT")
		quit(2)
		return true
	return false


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _check(ok: bool, what: String) -> void:
	if ok:
		_passed += 1
		print("R8 PASS " + what)
	else:
		_failed += 1
		print("R8 FAIL " + what)


func _free_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var p: Node = _room.get("player")
	if p != null:
		p.set("input_enabled", false)


## Yaw 0 looks toward -z; forward is (-sin yaw, 0, -cos yaw).
func _go(x: float, z: float, yaw_deg: float, pitch_deg: float = -9.0) -> void:
	_room.call("go_to", Vector4(x, 0.05, z, 0.0), deg_to_rad(yaw_deg))
	var rig: Node = (_room.get("player") as Node).get_node_or_null("CameraRig")
	if rig != null:
		rig.set("pitch", deg_to_rad(pitch_deg))
		rig.call("_apply")
	_free_mouse()


func _shoot(name: String) -> void:
	root.get_texture().get_image().save_png(OUT + name + ".png")
	print("R8 shot " + name)


func _key(code: Key) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = down
		Input.parse_input_event(e)


func _run() -> void:
	await _hall()
	await _gardens()
	print("R8 %s: %d passed, %d failed" % ["PASS" if _failed == 0 else "FAIL", _passed, _failed])
	quit(0 if _failed == 0 else 1)


# -- the hall ---------------------------------------------------------------------------------------------------

func _hall() -> void:
	Style.palette = "grey"
	_room = (load(HALL) as PackedScene).instantiate()
	root.add_child(_room)
	# The dev panel's saved values load, and the saved pedestal height rebuilds every showcase.
	await _frames(150)
	_free_mouse()
	var st: Node4D = _room.get_node_or_null("Station04") as Node4D
	var ex: Node = st.get("exhibit") if st != null else null
	_check(ex != null and absf(float(ex.get("tree_height")) - 9.6) < 0.01,
		"the oak is 9.6 m after the panel's load and the rebuild (%s)" % (str(ex.get("tree_height")) if ex != null else "no exhibit"))
	await _frames(90)
	ex = st.get("exhibit")
	var tree: Node4D = ex.get("tree") as Node4D if ex != null else null
	_check(ex != null and absf(float(ex.get("tree_height")) - 9.6) < 0.01 and tree != null and tree.scale.x > 0.5,
		"still 9.6 m 90 frames on (tree scale %s)" % (str(tree.scale.x) if tree != null else "?"))
	_check(st != null and absf(st.position.z + 14.5) < 0.01, "the oak's showcase stands at z -14.5")

	# The solid: rays in toward the trunk from 5.5 m out, all round, a hand's height up.
	var c: Vector4 = st.global_position
	var r_lo: float = INF
	var r_hi: float = 0.0
	var misses: int = 0
	for i in 96:
		var a: float = TAU * float(i) / 96.0
		var d := Vector4(cos(a), 0.0, sin(a), 0.0)
		var params := RaycastParameters4D.new()
		params.global_ray_origin = c + d * 5.5 + Vector4(0.0, 0.25, 0.0, 0.0)
		params.global_ray_direction = -d
		params.max_distance = 5.5
		var hit: Dictionary = PhysicsServer4D.raycast_physics_objects(params)
		if hit.is_empty() or not hit.has("global_point"):
			misses += 1
			if i == 0:
				print("R8 ray 0 result: %s" % str(hit))
			continue
		var p: Vector4 = hit["global_point"]
		var r: float = Vector2(p.x - c.x, p.z - c.z).length()
		r_lo = minf(r_lo, r)
		r_hi = maxf(r_hi, r)
	print("R8 oak solid: rays hit between %.3f and %.3f m from the middle (%d of 96 missed); the rim is at 4.03" % [r_lo, r_hi, misses])
	_check(misses == 0 and r_lo >= 4.03 and r_hi < 4.2, "the oak's solid follows its circle, never inside the rim (%.3f to %.3f m; the square reached 5.87 at its corners)" % [r_lo, r_hi])

	# Walked into: the body pushed in toward the trunk along a diagonal (where the square's corner stood) and
	# along the side, by the physics alone.
	var pl: CharacterBody4D = _room.get("player") as CharacterBody4D
	pl.set_physics_process(false)
	for deg in [45.0, 135.0, 0.0, 200.0]:
		var a2: float = deg_to_rad(deg)
		var d2 := Vector4(cos(a2), 0.0, sin(a2), 0.0)
		pl.global_position = c + d2 * 6.5 + Vector4(0.0, 0.05, 0.0, 0.0)
		for f in 150:
			pl.set("linear_velocity", -d2 * 3.0)
			pl.call("move_and_slide")
			await physics_frame
		var q: Vector4 = pl.global_position
		var rr: float = Vector2(q.x - c.x, q.z - c.z).length()
		print("R8 walk at %.0f degrees: stopped %.2f m from the trunk" % [deg, rr])
		_check(rr < 4.9 and rr > 4.0, "walking in at %.0f degrees stops at the rim (%.2f m)" % [deg, rr])
	pl.set("linear_velocity", Vector4.ZERO)
	pl.set_physics_process(true)

	# The panels and the signs.
	var intro: Node = _room.get_node_or_null("IntroPanel")
	var board: Node = _room.get_node_or_null("ResearchBoard")
	var im: Array = intro.call("plan_mark") if intro != null else []
	var bm: Array = board.call("plan_mark") if board != null else []
	print("R8 intro %s, research %s" % [str(im.slice(1)), str(bm.slice(1))])
	_check(String(intro.get("wall_name")) == "right" and im.size() == 4, "the introduction hangs on the right wall")
	_check(String(board.get("wall_name")) == "left" and bm.size() == 4, "Branches Grow hangs on the left wall")
	if bm.size() == 4:
		# Along the left wall from the entrance corner: 03's specimen text ends at room_front + 7 + 2.4.
		var spec_end: float = float(_room.get("room_front")) + 7.0 + 2.4
		var wall_len: float = float(_room.get("room_front")) + float(_room.get("room_back"))
		_check(float(bm[2]) > spec_end + 0.5 and float(bm[3]) < wall_len - 0.5,
			"Branches Grow sits past 03's text and short of the corner (%.2f to %.2f of %.2f; 03 ends %.2f)" % [float(bm[2]), float(bm[3]), wall_len, spec_end])
	var hall: Node = _room.get_node_or_null("Hall")
	var ds: Node = hall.get_node_or_null("DoorSign")
	var es: Node = hall.get_node_or_null("Sign")
	var dm: float = float(_room.get("door_from_left")) + float(_room.get("door_width")) * 0.5
	var dal: Vector2 = ds.get("along")
	_check(int(ds.get("edge")) == 1 and absf((dal.x + dal.y) * 0.5 - dm) < 0.05, "TWO GARDENS is on the back wall, centred on the door (%s, door middle %.2f)" % [str(dal), dm])
	var eal: Vector2 = es.get("along")
	_check(int(es.get("edge")) == 3 and absf((eal.x + eal.y) * 0.5 - float(_room.get("room_right_width"))) < 0.05, "BOTANY LAB is over the entrance, centred on the spine (%s)" % str(eal))

	# Frames: the oak, the two walls, the two signs.
	_go(-2.0, -8.4, 0.0, 10.0)
	await _frames(40)
	_shoot("h01_oak_from_its_ring")
	_go(0.0, -0.5, 8.4, 8.0)
	await _frames(40)
	_shoot("h02_oak_from_the_spine")
	_go(0.0, 0.6, -90.0, 6.0)
	await _frames(40)
	_shoot("h03_right_wall_intro")
	_go(-1.0, -15.4, 90.0, 6.0)
	await _frames(40)
	_shoot("h04_left_wall_research_close")
	_go(0.0, -6.0, 51.5, 6.0)
	await _frames(40)
	_shoot("h05_left_wall_research_from_the_path")
	_go(-10.5, -17.0, -35.4, 16.0)
	await _frames(40)
	_shoot("h06_back_door_sign")
	_go(-5.0, -19.6, -20.0, 22.0)
	await _frames(40)
	_shoot("h07_back_door_sign_under")
	_go(0.0, 17.0, 0.0, 14.0)
	await _frames(40)
	_shoot("h08_entrance_sign")

	# Dark mode: the spots 40% up, and only there.
	var lt: Node = _room.get_node_or_null("Light04Oak")
	var sl: Node = lt.get("_light") if lt != null else null
	var e_grey: float = float(sl.get("light_energy")) if sl != null else -1.0
	_room.call("toggle_palette")
	await _frames(5)
	var e_black: float = float(sl.get("light_energy")) if sl != null else -1.0
	print("R8 oak spot: grey %.3f, black %.3f (x%.3f)" % [e_grey, e_black, e_black / maxf(e_grey, 0.0001)])
	_check(Style.palette == "black" and absf(e_black / maxf(e_grey, 0.0001) - 1.4) < 0.01, "in dark mode the hall's spots are 40% brighter")
	_go(0.0, -0.5, 8.4, 8.0)
	await _frames(40)
	_shoot("h09_dark_oak_from_the_spine")
	_room.call("toggle_palette")
	await _frames(5)
	_check(absf(float(sl.get("light_energy")) - e_grey) < 0.001, "back in grey the spots are as they were")
	# Leave the hall in dark mode, as Ramon did before walking through.
	_room.call("toggle_palette")
	await _frames(5)
	_room.queue_free()
	await _frames(10)


# -- the second room ----------------------------------------------------------------------------------------

func _gardens() -> void:
	_check(Style.palette == "black", "the hall was left in dark mode")
	_room = (load(GARDENS) as PackedScene).instantiate()
	root.add_child(_room)
	await _frames(10)
	_check(Style.palette == "grey", "the second room opens bright though the hall was dark")
	_check(String(root.get_meta("botany_hall_palette", "")) == "black", "it keeps the hall's palette to give back")
	_check(is_equal_approx(Style.spot_black, 1.0), "the hall's dark-mode spot gain is not carried in")
	var waited: int = 0
	while not bool(_room.call("ready_to_visit")) and waited < 2400:
		await process_frame
		waited += 1
	while _room.get("_board") != null and waited < 3000:
		await process_frame
		waited += 1
	await _frames(30)
	_free_mouse()
	_shoot("g01_opens_bright")
	# B toggles it here now.
	_key(KEY_B)
	await _frames(10)
	_check(Style.palette == "black", "B turns the second room dark")
	var hud: Node = _room.get("hud")
	_check(String(hud.get("switch_text")).begins_with("GREY"), "its switch offers the way back (%s)" % String(hud.get("switch_text")))
	await _frames(20)
	_shoot("g02_after_b_dark")
	hud.emit_signal("mood_pressed")
	await _frames(10)
	_check(Style.palette == "grey", "the HUD's switch turns it bright again")

	# The SKY AND SUN page.
	var ed: Control = _room.get("light_editor") as Control
	ed.call("open")
	ed.call("_flip_page")
	await _frames(10)
	var box: Control = ed.get("_env_box") as Control
	_check(box != null and box.visible and box.get_child_count() == 12, "the SKY AND SUN page shows its ten rows (%d children)" % (box.get_child_count() if box != null else -1))
	_shoot("g03_sky_and_sun_page")
	var lab: Node = _room.get_node_or_null("Room")
	var before: float = float(_room.call("env_get", "sun"))
	_room.call("env_set", "sun", before + 0.5)
	await _frames(3)
	var key: float = float(((lab.get("mood_overrides") as Dictionary)["bright"] as Dictionary)["key_energy"])
	_check(absf(key - (before + 0.5)) < 0.001, "Sun strength reaches the room's key light (%.2f)" % key)
	_room.call("env_set", "sun", before)
	ed.call("_flip_page")
	await _frames(5)
	_check(not box.visible and (ed.get("_layout") as Control).visible, "LIGHTS brings the lights' page back")
	ed.call("close")
	_free_mouse()

	# The saved grass colour (Ramon's own, from the SKY AND SUN page) on the blades.
	var gd: Node = _room.get("gardens")
	var grass: Node = gd.get("grass") if gd != null else null
	var waited2: int = 0
	while grass == null and waited2 < 900:
		await process_frame
		waited2 += 1
		grass = gd.get("grass") if gd != null else null
	var cf := ConfigFile.new()
	cf.load("res://ramon/Arboretum/botany_lab/botany_lab_lights.cfg")
	var saved: Color = cf.get_value("SkyAndSun", "grass_colour", Color(0, 0, 0, 0))
	var shown: Color = grass.get("colour") if grass != null else Color(0, 0, 0, 0)
	print("R8 grass colour saved %s, on the blades %s" % [str(saved), str(shown)])
	_check(grass != null and saved.a > 0.0 and shown.is_equal_approx(saved), "the grass wears the saved colour")
	_go(6.0, 4.0, 0.0, -8.0)
	await _frames(40)
	_shoot("g04_grass")

	# (The way back, by real scene changes: _bl_roundtrip_runner.gd. Here the room sits under the root, and a scene
	# change would load the hall beside it.)
	_check(Style.palette == "grey", "the second room is bright as you leave")
