extends SceneTree
## Voxel Lab, the open world on its own (9 Oct): arrive (nothing on screen, the view), step into the
## helm's ring (its choice), take off as the bird; turn the slice, fly to the circle's edge (its
## hologram, and it holds), dive at the land (it never goes under the ground), the slice back home with
## R, back on the deck; Tab and the sea panel (a number changed, not saved). Frames to
## smoke_test_output/voxel_lab/field_play/, checks printed as PASS or FAIL.
##
## Keys go in as events; the mouse is never moved or held (the cursor is the user's).
##   VoxelLab/run.sh windowed field_play res://ramon/VoxelLab/field/_capture_field_runner.gd

const OUT := "res://smoke_test_output/voxel_lab/field_play/"
const FIELD := "res://ramon/VoxelLab/field/voxel_field.tscn"

var _f: Node
var _t: float = 0.0
var _total: float = 0.0
var _step: int = 0
var _fails: int = 0
var _since: float = 0.0
var _start: Vector4
var _lowest: float = 1000.0
var _widest: float = 0.0
var _edge_seen: bool = false
var _edge_saved: bool = false
var _top: Camera4D


func _initialize() -> void:
	root.unfocusable = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_open.call_deferred()


func _open() -> void:
	_f = (load(FIELD) as PackedScene).instantiate()
	root.add_child(_f)
	current_scene = _f


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
	print("FIELD %s %s" % ["PASS" if ok else "FAIL", what])


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = pressed
		Input.parse_input_event(e)


func _bird() -> Node:
	return _f.get("bird")


## While flying: how close to the ground it ever came, and how far out.
func _watch() -> void:
	var b: Node = _bird()
	if not bool(b.get("flying")):
		return
	var at: Vector4 = b.get("at")
	var floor_y: float = maxf(float(b.get("sea_level")), float(_f.call("ground_at", at.x, at.z, at.w)))
	_lowest = minf(_lowest, at.y - floor_y)
	var c: Vector4 = b.get("centre")
	_widest = maxf(_widest, Vector2(at.x - c.x, at.z - c.z).length())
	if (_f.get("_edge") as MeshInstance4D).visible:
		_edge_seen = true


func _process(delta: float) -> bool:
	_total += delta
	if _total > 200.0:
		print("FIELD FAIL: timed out at step %d" % _step)
		return true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _f == null or not _f.is_inside_tree() or _f.get("player") == null:
		return false
	_t += delta
	_watch()
	match _step:
		0:
			if bool(_f.get("loading")):
				_since = 0.0
			else:
				_since += delta
			if not bool(_f.get("loading")) and _since > 1.5:
				var st: Dictionary = _f.get("stream").call("stats")
				print("FIELD built: %d chunks, %d tetrahedra, ~%.0f MB, in %.1f s; ground mapped in %.0f ms" % [int(st["chunks"]), int(st["tets"]), float(st["mb"]),
					float(_f.get("build_seconds")), float(_f.get("height_map_ms"))])
				_check(not bool(_f.get("choice").get("shown")), "you look first: nothing asks you anything")
				_check(not (_f.get("_heights") as PackedFloat32Array).is_empty(), "the ground is mapped before the board goes")
				_save("01_arrive")
				_f.get("player").global_position = _f.call("helm_spot")
				_next()
		1:
			if _t > 1.2:
				_check(bool(_f.get("choice").get("shown")), "in the helm's ring, its choice")
				_save("02_helm")
				_key(KEY_1)
				_next()
		2:
			if _t < 0.1:
				_bird().set("drive", {"flap": true, "pitch": 0.0})
			if _t > 2.6 and _t - delta <= 2.6:
				_check(String(_f.get("mode")) == "fly" and bool(_bird().get("flying")), "1 at the helm: you fly as a bird")
				_save("03_flying")
			if _t > 3.0:
				_start = _bird().get("at")
				# The slice, turned sideways through W while it flies on.
				_bird().set("drive", {"slice": Vector2(0.3, 0.0), "pitch": -0.05})
				_next()
		3:
			if _t > 2.5:
				var deg: float = float(_bird().call("slice_degrees"))
				_check(deg > 15.0 and deg <= float(_bird().get("slice_limit")) + 0.5, "a right drag turns the slice, never past the limit (%.0f°)" % deg)
				_save("04_slice_turned")
				_bird().set("drive", {"flap": true, "pitch": 0.0})
				_next()
		4:
			# Straight on to the edge of the circle.
			if _t > 9.0:
				var circle: float = float(_bird().get("circle"))
				_check(_edge_seen, "near the edge, the hologram wall")
				_check(_widest <= circle + 0.05, "the circle holds (furthest %.1f m of %.0f m)" % [_widest, circle])
				_save("05_edge")
				# Down at the land.
				_bird().set("drive", {"pitch": -0.9, "turn": 0.4})
				_next()
			elif not _edge_saved and _widest > float(_bird().get("circle")) - 4.5:
				# As near the edge as it comes: the wall at its strongest.
				_edge_saved = true
				var e: MeshInstance4D = _f.get("_edge")
				print("FIELD edge: shown %s at %s, bird at %s, cover %.2f" % [e.visible, str(e.global_position), str(_bird().get("at")),
					float((_f.get("_edge_cs") as ShaderMaterial).get_shader_parameter("holo_base"))])
				_save("05a_edge_near")
		5:
			if _t > 5.0:
				_check(_lowest >= float(_bird().get("clearance")) - 0.05, "it never went under the ground or the sea (closest %.2f m)" % _lowest)
				_save("06_low")
				_bird().set("drive", {"pitch": 0.0})
				_key(KEY_R)
				_next()
		6:
			if _t > 1.5:
				_check(float(_bird().call("slice_degrees")) < 1.0, "R takes the slice home (%.1f°)" % float(_bird().call("slice_degrees")))
				_save("07_slice_home")
				_key(KEY_1)
				_next()
		7:
			if _t > 1.5:
				var pc: Camera4D = _f.get("player").get_node("CameraRig/Pitch/Camera4D")
				_check(String(_f.get("mode")) == "deck" and pc.current, "1 brings you back to the deck")
				_save("08_back_on_deck")
				_key(KEY_TAB)
				_next()
		8:
			if _t > 1.0:
				var panel: Control = _f.get("sea_panel")
				_check(panel.visible, "Tab opens the sea's settings")
				var before: float = float(_f.get("water").get("wave_scale"))
				panel.call("_set_row", "wave_scale", 0.8)
				panel.call("_apply", false)
				_check(absf(float(_f.get("water").get("wave_scale")) - 0.8) < 0.001 and before != 0.8, "a slider changes the sea (wave size %.2f to 0.80)" % before)
				_save("09_sea_panel")
				_key(KEY_TAB)
				_next()
		9:
			if _t > 0.6:
				_check(not (_f.get("sea_panel") as Control).visible, "Tab closes it")
				# The island from above: the deck, the circle, the land and the sea.
				_top = Camera4D.new()
				_top.rendering_engine_name = "Cross-section"
				_f.add_child(_top)
				var c: Vector4 = _f.get("_centre").global_position
				_top.global_position = Vector4(c.x, 95.0, c.z, 0.0)
				_top.global_basis = Basis4D.from_yz(-PI * 0.5)
				_top.make_current()
				_next()
		10:
			if _t > 1.5:
				_save("10_top")
				print("FIELD done, %d failed" % _fails)
				return true
	return false


func _next() -> void:
	_step += 1
	_t = 0.0


func _save(name: String) -> void:
	var image: Image = root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
	print("FIELD saved %s" % name)
