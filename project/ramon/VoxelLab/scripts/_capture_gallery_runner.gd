extends SceneTree
## Voxel Lab, round 2 (9 Oct): the gallery and the field, played and photographed. The terrain's ring
## (the choice: cut it, change the land), its three looks, a cut at its bench; a rung of the ladder and
## its pop-up; the two blue walls; the far door's shimmer; through it to the field's deck (nothing on
## screen as you arrive; a station's choice in its ring; change the land, built again behind the board;
## flying as the bird, and back on the deck); back through the deck's shimmer to the gallery's far door. Frames to
## smoke_test_output/voxel_lab/gallery/, checks printed as PASS or FAIL.
##
## Keys go in as events; the mouse is never moved or held (the cursor is the user's).
##   VoxelLab/run.sh windowed gallery res://ramon/VoxelLab/scripts/_capture_gallery_runner.gd

const OUT := "res://smoke_test_output/voxel_lab/gallery/"

var _t: float = 0.0
var _total: float = 0.0
var _step: int = 0
var _fails: int = 0
var _biomes: Array = []
var _board_saved: bool = false
var _since: float = 0.0
var _board_saved2: bool = false
var _deck0: Vector4


func _initialize() -> void:
	root.unfocusable = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_open.call_deferred()


func _open() -> void:
	var s: Node = (load("res://ramon/VoxelLab/voxel_lab.tscn") as PackedScene).instantiate()
	root.add_child(s)
	current_scene = s


func _lab() -> Node:
	return current_scene if current_scene != null and current_scene.has_method("go_to") else null


func _field() -> Node:
	return current_scene if current_scene != null and current_scene.has_method("fly") else null


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
	print("GALLERY %s %s" % ["PASS" if ok else "FAIL", what])


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = pressed
		Input.parse_input_event(e)


func _place(x: float, z: float, yaw_deg: float) -> void:
	_lab().call("go_to", Vector4(x, 0.05, z, 0.0), deg_to_rad(yaw_deg))


func _ex(nm: String) -> Node:
	return _lab().get_node(nm).get("exhibit")


func _spot_name() -> String:
	var sp: Dictionary = _lab().get("spot")
	return String((sp["node"] as Node).name) if not sp.is_empty() else ""


func _process(delta: float) -> bool:
	_total += delta
	if _total > 300.0:
		print("GALLERY FAIL: timed out at step %d" % _step)
		return true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_t += delta
	var lab: Node = _lab()
	if lab != null and lab.get("player") != null and lab.get("bench") == null:
		lab.get("player").set("input_enabled", false)
	match _step:
		0:
			if lab != null and lab.get("player") != null and _t > 2.0 and not bool(lab.get("loading")) and bool(_ex("Terrain").call("is_ready")) and bool(_ex("Layer3").call("is_ready")):
				var n: Dictionary = _ex("Terrain").call("numbers")
				print("GALLERY terrain: %s" % str(n))
				_place(0.0, -18.0, 0.0)
				_next()
		1:
			if _t > 1.6:
				_save("01_gallery")
				_place(0.0, -24.5, 90.0)
				_next()
		2:
			if _t > 1.4:
				var opts: Array = lab.get("choice").get("options")
				_check(_spot_name() == "Terrain" and opts.size() == 2, "the terrain's ring offers: %s" % str(opts.map(func(o): return o["label"])))
				_save("02_terrain_choice")
				_key(KEY_2)
				_next()
		3, 4, 5:
			# Round 7 (#82): the press is answered at once, GENERATING WORLD at the top while it builds.
			if _step == 3 and _t > 0.25 and _t - delta <= 0.25:
				var gen: Control = lab.get("generating")
				_check(gen != null and bool(gen.get("shown")), "GENERATING WORLD shows while the land builds (%s)" % (String(gen.get("text")) if gen != null else "none"))
				_save("02b_generating")
			if _t > 0.8:
				var b: String = String(_ex("Terrain").call("biome_name"))
				_biomes.append(b)
				_save("%02d_terrain_%s" % [_step, b.to_lower()])
				_key(KEY_2)
				_next()
		6:
			if _t > 0.6:
				_check(_biomes == ["Desert", "Lava", "Green"], "2 changes the land: %s" % str(_biomes))
				_key(KEY_1)
				_next()
		7:
			if _t > 1.4:
				var bench: Node = lab.get("bench")
				_check(bench != null and bench == lab.get_node("TerrainBench"), "1 sits you at the terrain's bench")
				var h: Dictionary = bench.call("aim_at_screen", Vector2(640, 380)) if bench != null else {}
				_check(not h.is_empty(), "the aim finds the land through its meshes")
				if bench != null and not h.is_empty():
					bench.set("tool", "ball")
					bench.set("size_index", 2)
					bench.call("cut_here")
				_next()
		8:
			if _t > 1.6:
				var bench: Node = lab.get("bench")
				var recs: Array = bench.get("records") if bench != null else []
				_check(not recs.is_empty(), "a crater in his landscape (%s)" % ("%.0f ms to show" % float(recs[-1]["latency_ms"]) if not recs.is_empty() else "none"))
				_save("06_terrain_cut")
				_key(KEY_F)
				_next()
		9:
			if _t > 0.8:
				_place(7.2, -21.0, -90.0)
				_next()
		10:
			if _t > 1.2:
				_check(_spot_name() == "Layer1", "the first layer's marker is a spot")
				lab.set("_popup_open", true)
				_next()
		11:
			if _t > 0.6:
				var pd: Dictionary = lab.get("popup").get("data")
				_check(String(pd.get("title", "")) == "The land", "its pop-up: %s" % String(pd.get("title", "")))
				_save("07_layer_popup")
				for i in 3:
					var n: Dictionary = _ex("Layer%d" % (i + 1)).call("numbers")
					print("GALLERY layer %d: %s chunks, %s tetrahedra, %s" % [i + 1, String(n["chunks"]), String(n["tets"]), String(n["mb"])])
				_place(3.5, -24.5, -90.0)
				_next()
		12:
			if _t > 1.4:
				_save("08_layers_wall")
				_place(-1.5, -19.0, 135.0)
				_next()
		13:
			if _t > 1.4:
				_save("09_about_wall")
				_place(0.0, -27.5, 0.0)
				_next()
		14:
			if _t > 1.4:
				_save("10_far_door")
				# Into the shimmer.
				_place(0.0, -32.55, 0.0)
				_next()
		15:
			var f: Node = _field()
			if f != null and bool(f.get("loading")) and not _board_saved and _t > 3.0:
				_board_saved = true
				_save("10b_open_world_board")
			if f != null and bool(f.get("loading")):
				_since = 0.0
			else:
				_since += delta
			# A moment after the board has gone: you look first, nothing on screen.
			if f != null and f.get("player") != null and not bool(f.get("loading")) and _since > 1.5:
				_check(String(f.get("mode")) == "deck", "through the shimmer: on the field's deck")
				_check(not bool(f.get("choice").get("shown")), "you look first: no choice until a station")
				_save("11_field_deck")
				# Round 4: two stations where the helm was; the right one changes the world.
				f.get("player").global_position = f.call("station_spot", "world")
				_next()
			elif _t > 40.0:
				_check(false, "the field never opened")
				return true
		16:
			if _t > 1.2:
				var f: Node = _field()
				_check(String(f.get("at_station")) == "world" and bool(f.get("choice").get("shown")), "in the right station's ring, its choice")
				_save("11b_field_station")
				_key(KEY_1)
				_since = 0.0
				_next()
		17:
			# Green to desert builds the land again (the generator's own sea), behind the board.
			var f: Node = _field()
			if bool(f.get("loading")):
				_since = 0.0
				if not _board_saved2 and _t > 1.5:
					_board_saved2 = true
					_save("12a_field_rebuild_board")
			else:
				_since += delta
			if _t > 1.0 and not bool(f.get("loading")) and _since > 1.5:
				_check(int(f.get("biome")) == 1 and _board_saved2, "1 at the right station changes the land, built again behind the board")
				_check(not (f.get("water") as Node4D).visible, "the moving sea only with the green land")
				_save("12_field_desert")
				f.get("player").global_position = f.call("station_spot", "fly")
				_next()
			elif _t > 40.0:
				_check(false, "the land was never built again")
				return true
		18:
			# At the left station: 1 takes off.
			var f: Node = _field()
			if _t > 1.0 and _fly_t < 0.0:
				_key(KEY_1)
				_fly_t = _t
			# Once it is up (take-off clears whatever was being driven), flap level, as the open world's own
			# runner does, and measure from there.
			if _fly_t >= 0.0 and _t - _fly_t > 0.2 and _t - _fly_t < 0.5:
				f.get("bird").set("drive", {"flap": true, "pitch": 0.0})
				_deck0 = f.get("bird").get("at")
			if _fly_t >= 0.0 and _t - _fly_t > 4.5:
				var b: Node = f.get("bird")
				var moved: Vector4 = (b.get("at") as Vector4) - _deck0
				_check(String(f.get("mode")) == "fly" and bool(b.get("flying")), "1 at the left station: you fly as a bird")
				_check(Vector2(moved.x, moved.z).length() > 6.0, "off the deck and away (%.1f m)" % Vector2(moved.x, moved.z).length())
				_save("13_field_flying")
				b.set("drive", {})
				_key(KEY_1)
				_next()
		19:
			if _t > 2.0:
				var f: Node = _field()
				_check(String(f.get("mode")) == "deck", "1 brings you back to the deck")
				_save("13b_field_back_on_deck")
				# Walk back into the shimmer behind you.
				f.get("player").global_position = f.call("door_spot")
				_next()
		20:
			var l: Node = _lab()
			if l != null and l.get("player") != null and not bool(l.get("loading")) and _t > 1.5:
				var p: Vector4 = l.get("player").global_position
				_check(p.z < -25.0 and p.z > -29.0, "back through the deck's shimmer, inside the gallery's far door (z %.1f)" % p.z)
				_save("14_back_in_gallery")
				print("GALLERY done, %d failed" % _fails)
				return true
			elif _t > 40.0:
				_check(false, "the lab never came back")
				return true
	return false


var _fly_t: float = -1.0


func _next() -> void:
	_step += 1
	_t = 0.0


func _save(name: String) -> void:
	var image: Image = root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
	print("GALLERY saved %s" % name)
