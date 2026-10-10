extends SceneTree
## Voxel Lab, round 7 (#85: "The ocean currently looks strange after the latest changes. I'm not yet certain
## which setting or visual effect is causing the problem"): the open world's sea as Ramon saved it, then with
## ONE thing changed at a time (shore foam off, crest foam off, highlights off, the fine ripple off, the Calm
## preset, round 5's bubble size, the Aquatic Lab's own water), each from the platform out to sea and from
## 40 m straight down onto open water. For each, how much of the open water is near white (the blotches).
## Nothing is saved; his file is only read. Frames to smoke_test_output/voxel_lab/sea_probe/.
##   VoxelLab/run.sh windowed sea_probe res://ramon/VoxelLab/field/_probe_sea_runner.gd

const OUT := "res://smoke_test_output/voxel_lab/sea_probe/"
const FIELD := "res://ramon/VoxelLab/field/voxel_field.tscn"
const SeaPanel := preload("res://ramon/VoxelLab/field/vl_sea_panel.gd")

var _f: Node
var _cam: Camera4D
var _t: float = 0.0
var _total: float = 0.0
var _step: int = 0
var _v: int = 0
var _variants: Array = ["saved", "no_shore_foam", "no_crest_foam", "no_highlights", "no_ripple", "calm", "round5_bubbles", "aquatic_lab"]
## The height the overhead frame is taken from: 40 m, then 95 m (where round 6's frame showed white blotches).
var _high: bool = false


func _initialize() -> void:
	root.unfocusable = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_open.call_deferred()


func _open() -> void:
	_f = (load(FIELD) as PackedScene).instantiate()
	root.add_child(_f)
	current_scene = _f


func _water() -> Node:
	return _f.get("water")


## Everything back as he saved it, then the variant's one change.
func _apply(name: String) -> void:
	var w: Node = _water()
	var v: Dictionary = SeaPanel.saved()
	SeaPanel.apply_all(w, v)
	var mat: ShaderMaterial = w.get("_material")
	mat.set_shader_parameter("foam_opacity", 1.0)
	match name:
		"no_shore_foam":
			w.set("shore_foam", 0.0)
		"no_crest_foam":
			mat.set_shader_parameter("foam_opacity", 0.0)
		"no_highlights":
			w.set("specular_strength", 0.0)
		"no_ripple":
			w.set("detail_strength", 0.0)
		"calm":
			w.call("set_preset", 0)
		"round5_bubbles":
			w.set("foam_cell", 0.45)
		"aquatic_lab":
			var wl: Dictionary = SeaPanel.water_lab()
			if not wl.is_empty():
				v.merge(wl, true)
				SeaPanel.apply_all(w, v)
	print("SEA %s: preset %d, wave scale %.3f, detail %.3f, specular %.2f, shore foam %.2f, foam cell %.2f" % [name, int(w.get("preset_index")),
		float(w.get("wave_scale")), float(w.get("detail_strength")), float(w.get("specular_strength")), float(w.get("shore_foam")), float(w.get("foam_cell"))])


## From the platform, out to sea (away from the island's middle), a little down.
func _deck_view() -> void:
	var p: Vector4 = (_f.call("platform_spot") as Vector4) + Vector4(0, 1.7, 0, 0)
	var c: Vector4 = _f.get("_centre").global_position
	var out := Vector2(p.x - c.x, p.z - c.z).normalized()
	_cam.global_position = p
	_cam.global_basis = Basis4D.from_zx(atan2(-out.x, -out.y)) * Basis4D.from_yz(deg_to_rad(-8.0))
	_cam.make_current()


## 40 m over open water, 75 m out from the island's middle, looking straight down.
func _top_view() -> void:
	var c: Vector4 = _f.get("_centre").global_position
	_cam.global_position = Vector4(c.x + 75.0, 95.0 if _high else 40.0, c.z + 20.0, 0.0)
	_cam.global_basis = Basis4D.from_yz(-PI * 0.5)
	_cam.make_current()


## The share of the middle of the frame (clear of the HUD) that is near white.
func _white_share() -> float:
	var img: Image = root.get_texture().get_image()
	var w: int = img.get_width()
	var h: int = img.get_height()
	var n: int = 0
	var hit: int = 0
	for y in range(int(h * 0.38), int(h * 0.72), 3):
		for x in range(int(w * 0.32), int(w * 0.68), 3):
			var c: Color = img.get_pixel(x, y)
			n += 1
			if c.get_luminance() > 0.62:
				hit += 1
	return float(hit) / float(maxi(n, 1))


func _save(name: String) -> void:
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name + ".png"))


func _process(delta: float) -> bool:
	_total += delta
	if _total > 300.0:
		print("SEA FAIL: timed out at step %d" % _step)
		return true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _f == null or not _f.is_inside_tree() or _f.get("player") == null:
		return false
	_f.get("player").set("input_enabled", false)
	_t += delta
	match _step:
		0:
			if not bool(_f.get("loading")) and _t > 2.0:
				_cam = Camera4D.new()
				_cam.rendering_engine_name = "Cross-section"
				_f.add_child(_cam)
				_step = 1
				_t = 0.0
		1:
			# A variant: applied, then the waves given time to settle (a preset blends in over seconds).
			_apply(String(_variants[_v]))
			_deck_view()
			_step = 2
			_t = 0.0
		2:
			if _t > (5.0 if String(_variants[_v]) == "calm" else 2.5):
				_save("%d_%s_deck" % [_v, _variants[_v]])
				_top_view()
				_step = 3
				_t = 0.0
		3:
			if _t > 0.8:
				var share: float = _white_share()
				_save("%d_%s_top%s" % [_v, _variants[_v], "95" if _high else ""])
				print("SEA %s: near-white open water from %d m up %.1f %%" % [_variants[_v], 95 if _high else 40, share * 100.0])
				if not _high:
					_high = true
					_top_view()
					_t = 0.0
					return false
				_high = false
				_v += 1
				if _v >= _variants.size():
					print("SEA done")
					return true
				_step = 1
				_t = 0.0
	return false
