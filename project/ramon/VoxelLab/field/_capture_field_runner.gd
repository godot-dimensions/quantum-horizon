extends SceneTree
## Voxel Lab, the open world on its own (9 Oct): arrive (nothing on screen, the view), step into the
## helm's ring (its choice), take off as the bird; turn the slice, fly to the circle's edge (its
## hologram, and it holds), dive at the land (it never goes under the ground), the slice back home with
## R, back on the deck; Tab and the sea panel (a number changed, not saved). Round 5: the sea one graded mesh
## (no square), the Aquatic Lab's water to compare, the shore foam set; the grass patches made, drawn, seen
## up close and from the platform. Frames to
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
var _out: bool = false
var _out_t: float = 0.0
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
	if _total > 320.0:
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
				var sea: Node = _f.get("water")
				_check(float(sea.get("reach")) >= 800.0 and float(sea.get("far_extent")) == 0.0, "the sea is one graded mesh to %.0f m, no far ring" % float(sea.get("reach")))
				_check(float(sea.get("shore_foam")) < 0.9, "the shore foam under the Aquatic Lab's 0.9 (%.2f)" % float(sea.get("shore_foam")))
				_save("01_arrive")
				# Round 3: the blue platform first.
				_f.get("player").global_position = _f.call("platform_spot")
				_to(30)
		30:
			if _t > 1.2:
				var rig: Node4D = _f.get("player").get_node("CameraRig")
				_check(String(_f.get("site")) == "platform" and bool(rig.get("slice_turning")), "in the platform's ring, the slice turns")
				_check(bool(_f.get("tutorial").get("shown")), "and the mouse card shows how")
				_save("01b_platform")
				_to(31)
		31:
			# A right drag as the rig takes it, a little each frame, further than the limit allows.
			var rig2: Node4D = _f.get("player").get_node("CameraRig")
			rig2.call("drag_slice", Vector2(0.006, 0.002))
			# Near the platform's edge as well: the slice stays turned there (round 4).
			if _t > 1.2 and _t - delta <= 1.2:
				var c: Vector4 = _f.call("platform_spot")
				_f.get("player").global_position = c + Vector4(3.6, 0.0, -1.5, 0.0)
			if _t > 2.0 and _t - delta <= 2.0:
				_check(String(_f.get("site")) == "platform" and bool(rig2.get("slice_turning")), "near the platform's edge the slice still turns")
			if _t > 2.5:
				var deg: float = rad_to_deg(acos(clampf((rig2.basis as Projection).w.w, -1.0, 1.0)))
				_check(deg > 40.0, "turned through W as far as you drag, no stop (%.0f°)" % deg)
				var set: Node4D = _f.get("_set")
				_check(bool(_f.get("_turned_here")) and (set.global_basis as Projection).w.w < 0.99, "the platform turned with it, so it stays level to you")
				_save("01c_platform_turned")
				_key(KEY_R)
				_to(32)
		32:
			if _t > 1.2:
				var rig3: Node4D = _f.get("player").get_node("CameraRig")
				var deg3: float = rad_to_deg(acos(clampf((rig3.basis as Projection).w.w, -1.0, 1.0)))
				_check(deg3 < 1.0, "R levels it again (%.1f°)" % deg3)
				# Turned again, then out of the ring: level by itself.
				rig3.call("drag_slice", Vector2(0.25, 0.0))
				_to(33)
		33:
			if _t > 0.6 and _t - delta <= 0.6:
				_save("01d_turned_again")
			# Walk out the way you would: into the gap toward the pier, in the turned platform's frame (the
			# platform levels the slice there, then you walk on).
			if _t > 0.6 and not _out:
				var c: Vector4 = (_f.call("platform_spot") as Vector4) - Vector4(0, 0.25, 0, 0)
				var rig5: Node4D = _f.get("player").get_node("CameraRig")
				if bool(_f.get("_turned_here")):
					var q := Vector4(c.x, rig5.global_position.y, c.z + 4.9, 0.0)
					var pv: Vector4 = _f.get("_pivot")
					var world: Vector4 = pv + (_f.call("_world_tilt") as Projection) * (q - pv)
					_f.get("player").global_position = world - (rig5.global_position - _f.get("player").global_position)
				elif _t > 0.8:
					# Level: walk on, to the right station.
					_out = true
					_out_t = _t
					print("FIELD levelled at the gap in %.2f s" % (_t - 0.6))
					_f.get("player").global_position = _f.call("station_spot", "world")
			if _out and _t > _out_t + 1.4:
				var rig4: Node4D = _f.get("player").get_node("CameraRig")
				var deg4: float = rad_to_deg(acos(clampf((rig4.basis as Projection).w.w, -1.0, 1.0)))
				var loc4: Vector4 = (_f.get("player") as Node4D).global_position - (_f.get("raft") as Node4D).position
				_check(String(_f.get("site")) == "" and not bool(rig4.get("slice_turning")) and deg4 < 1.0, "out of the ring the slice goes level (%.1f°; site '%s', turning %s, turned_here %s, at %s)" % [deg4,
					String(_f.get("site")), str(rig4.get("slice_turning")), str(_f.get("_turned_here")), str(loc4)])
				_check(not bool(_f.get("tutorial").get("shown")), "and the card goes")
				_to(1)
		1:
			if _t > 1.2:
				_check(bool(_f.get("choice").get("shown")) and String(_f.get("at_station")) == "world", "at the right station's ring, Change the world")
				_save("02_world_station")
				_key(KEY_1)
				_to(40)
		40:
			if bool(_f.get("loading")):
				_since = 0.0
			else:
				_since += delta
			if _t > 1.0 and not bool(_f.get("loading")) and _since > 1.5:
				_check(int(_f.get("biome")) == 1, "1 there changes the world (biome %d)" % int(_f.get("biome")))
				_save("02b_desert")
				# Back to green for the rest (desert to lava is a repaint, lava to green builds again).
				_f.call("_on_choice", 1)
				_f.call("_on_choice", 1)
				_to(41)
			elif _t > 40.0:
				_check(false, "the land was never built again")
				return true
		41:
			if bool(_f.get("loading")):
				_since = 0.0
			else:
				_since += delta
			if _t > 1.0 and not bool(_f.get("loading")) and _since > 1.5:
				_check(int(_f.get("biome")) == 0, "and back to green")
				_f.get("player").global_position = _f.call("station_spot", "fly")
				_to(42)
			elif _t > 40.0:
				_check(false, "the green land was never built again")
				return true
		42:
			if _t > 1.0:
				_check(bool(_f.get("choice").get("shown")) and String(_f.get("at_station")) == "fly", "at the left station's ring, Take off")
				_save("02c_fly_station")
				_key(KEY_1)
				_to(2)
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
				_check(deg > 15.0, "a right drag turns the slice (%.0f°)" % deg)
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
				# The Aquatic Lab's water, then ours again (round 5, #47).
				var wl: Dictionary = panel.call("water_lab")
				if not wl.is_empty():
					panel.call("_load", wl, "test")
					_check(int(_f.get("water").get("preset_index")) == int(wl["preset"]) and absf(float(_f.get("water").get("detail_strength")) - float(wl["detail_strength"])) < 0.001,
						"THE AQUATIC LAB'S puts its water on this sea (preset %d)" % int(wl["preset"]))
					panel.call("_load", panel.call("saved"), "ours")
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
				# The grass (round 5, #49): made once the ground was mapped, its heights baked on a worker.
				var g: Node = _f.get("grass")
				_check(g != null, "the grass patches are made (in %.0f ms)" % float(_f.get("grass_ms")))
				if g == null:
					print("FIELD done, %d failed" % _fails)
					return true
				var ps: Array = g.get("patches")
				print("FIELD grass: %d patches %s" % [ps.size(), str(ps)])
				# Close to the first patch, looking down at it.
				var p: Vector4 = ps[0]
				var y: float = float(_f.call("ground_at", p.x, p.y, 0.0))
				_top.global_position = Vector4(p.x + 9.0, y + 4.5, p.y, 0.0)
				_top.global_basis = Basis4D.from_zx(atan2(9.0, 0.0)) * Basis4D.from_yz(deg_to_rad(-22.0))
				_next()
		11:
			if _t > 1.5:
				_check(int(_f.get("grass").call("blade_count")) > 0, "and drawn (%d blades handed to the GPU)" % int(_f.get("grass").call("blade_count")))
				_save("11_grass_close")
				# From the platform, as you stand there.
				(_f.get("player").get_node("CameraRig/Pitch/Camera4D") as Camera4D).make_current()
				_f.get("player").global_position = _f.call("platform_spot")
				_next()
		12:
			if _t > 2.0:
				_save("12_grass_from_platform")
				_f.call("set_grass", false, 2.2)
				_next()
		13:
			if _t > 1.0:
				_check(int(_f.get("grass").call("blade_count")) == 0 or not bool(_f.get("grass").get("enabled")), "Tab's switch takes the grass away")
				_save("13_grass_off")
				_f.call("set_grass", true, 2.2)
				print("FIELD done, %d failed" % _fails)
				return true
	return false


func _to(step: int) -> void:
	_step = step
	_t = 0.0


func _next() -> void:
	_step += 1
	_t = 0.0


func _save(name: String) -> void:
	var image: Image = root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
	print("FIELD saved %s" % name)
