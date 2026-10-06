extends SceneTree

## The ref stage: renders a unit the way a reference sheet shows it, so the two can be laid over
## each other (PenLayout/PLAN_REF_LOCK.md, steps 3-6; Ramon, 6 Oct: "IS there a way to be more
## accurate? ... analyse deeper and measure if you have to").
##
## Each view is drawn into its own SubViewport at the sheet panel's exact pixel size, from the
## camera fitted to that panel (PenLayout/tools/ref_fit.py writes the presets), on a plain sky in
## the sheet's grey, so the compare tool (tools/ref_compare.py) can cut the build out of its
## background exactly as it cuts the painting out of its own.
##
## TWO LIGHTS. "neutral" is a white key from the front-left above and a soft fill, like the
## sheets' studio light, for judging shape and colour against the painting. "pen" is the pen's own
## low warm sun and blue sky fill, for judging what the albedo becomes out in the field.
##
## THE PLAYER as the scale bar: the chibi avatar (block_avatar_4d.gd, build 2, as the pen's
## Player has it) stands where the preset's "player" says, as it stands in the sheets.
##
## MARKERS: every named point in the preset is projected through the engine's own camera
## (Camera4D.world_to_viewport) and printed, so ref_fit.py's camera model can be checked against
## the engine's to the pixel.
##
##   lab_run.sh windowed reflock_<name> res://ramon/PenLayout/RefLock/ref_stage_runner.gd \
##       unit=res://ramon/chickenpen/units/watchstone/watchstone.tscn \
##       cams=res://ramon/PenLayout/RefLock/specs/watchstone_cameras.json \
##       out=res://smoke_test_output/reflock/watchstone/build light=neutral [views=front,right]
##       [hide=Crag,Timber_x] [noplayer=1] [w=0.0]

const AVATAR := preload("res://ramon/chickenpen/scripts/block_avatar_4d.gd")
const SUN := preload("res://ramon/chickenpen/scripts/pen_sun_4d.gd")

var _args: Dictionary = {}
var _t0: int = 0


func _initialize() -> void:
	root.unfocusable = true
	_t0 = Time.get_ticks_msec()
	for a in OS.get_cmdline_user_args():
		var i: int = a.find("=")
		if i > 0:
			_args[a.substr(0, i)] = a.substr(i + 1)
	_run.call_deferred()


func _process(_d: float) -> bool:
	if Time.get_ticks_msec() - _t0 > 120000:
		print("REF STAGE: gave up after 120 s")
		return true
	return false


func _run() -> void:
	var cams_path: String = String(_args.get("cams", ""))
	var text: String = FileAccess.get_file_as_string(cams_path)
	var cams: Variant = JSON.parse_string(text)
	if typeof(cams) != TYPE_DICTIONARY:
		print("REF STAGE: no camera presets at ", cams_path)
		quit(1)
		return
	var out: String = String(_args.get("out", "res://smoke_test_output/reflock/stage"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out.get_base_dir()))
	var views: Dictionary = cams["views"]
	var wanted: PackedStringArray = String(_args.get("views", ",".join(PackedStringArray(views.keys())))).split(",")
	var light: String = String(_args.get("light", "neutral"))
	var bg: Array = cams.get("background", [52, 55, 61])
	for view_name in wanted:
		if not views.has(view_name):
			print("REF STAGE: no view ", view_name)
			continue
		var v: Dictionary = views[view_name]
		var sv := SubViewport.new()
		sv.size = Vector2i(int(v["width"]), int(v["height"]))
		sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		sv.msaa_3d = Viewport.MSAA_4X
		root.add_child(sv)
		var stage := Node4D.new()
		stage.name = "Stage"
		sv.add_child(stage)
		_environment(stage, light, Color8(int(bg[0]), int(bg[1]), int(bg[2])), rad_to_deg(float(v.get("yaw", 0.0))))
		var unit: Node4D = null
		if _args.has("unit"):
			unit = (load(String(_args["unit"])) as PackedScene).instantiate() as Node4D
			stage.add_child(unit)
			for path in String(_args.get("hide", "")).split(",", false):
				var n := unit.get_node_or_null(path) as Node4D
				if n != null:
					n.visible = false
		if not _args.has("noplayer") and cams.has("player"):
			var p: Array = cams["player"]
			var avatar := Node4D.new()
			avatar.set_script(AVATAR)
			avatar.set("build", 2)
			avatar.set("shorts_length", 0.16)
			avatar.set("skin", Color(0.42, 0.62, 0.36))
			avatar.set("accent", Color(0.93, 0.8, 0.62))
			avatar.set("eyes", true)
			stage.add_child(avatar)
			avatar.position = Vector4(float(p[0]), float(p[1]), float(p[2]), 0.0)
			# Facing the sheets' way: toward +z, the front camera.
			if p.size() > 3:
				avatar.basis = Basis4D.from_zx(float(p[3]))
		if unit != null and view_name == wanted[0]:
			# The budget (PLAN_REF_LOCK.md step 20): every mesh in the unit, its tetrahedra.
			var tets: int = 0
			var meshes: int = 0
			for mi in unit.find_children("*", "MeshInstance4D", true, false):
				var m: Variant = (mi as MeshInstance4D).mesh
				if m is TetraMesh4D:
					tets += (m as TetraMesh4D).get_simplex_cell_vertex_indices().size() / 4
					meshes += 1
			print("BUDGET %d meshes, %d tetrahedra" % [meshes, tets])
			if unit.has_method("counts"):
				print("COUNTS ", unit.call("counts"))
		var cam := Camera4D.new()
		cam.name = "RefCam"
		cam.set("rendering_engine_name", String(_args.get("engine", "Cross-section")))
		stage.add_child(cam)
		var pos: Array = v["position"]
		var ax: Array = v["x_axis"]
		var ay: Array = v["y_axis"]
		var az: Array = v["z_axis"]
		var w: float = float(_args.get("w", "0.0"))
		cam.global_position = Vector4(float(pos[0]), float(pos[1]), float(pos[2]), w)
		cam.global_basis = Projection(Vector4(float(ax[0]), float(ax[1]), float(ax[2]), 0.0),
			Vector4(float(ay[0]), float(ay[1]), float(ay[2]), 0.0),
			Vector4(float(az[0]), float(az[1]), float(az[2]), 0.0), Vector4(0.0, 0.0, 0.0, 1.0))
		cam.set("focal_length_4d", float(v["focal"]))
		cam.set("clip_far", 400.0)
		cam.set("clip_near", 0.1)
		cam.make_current()
		for i in 12:
			await process_frame
		await RenderingServer.frame_post_draw
		var img: Image = sv.get_texture().get_image()
		var file: String = "%s_%s.png" % [out, view_name]
		img.save_png(ProjectSettings.globalize_path(file))
		print("REF STAGE saved ", file, " ", sv.size)
		# The engine's own projection of the preset's markers, for checking the fitted model.
		for m in cams.get("markers", {}):
			var q: Array = cams["markers"][m]
			var px: Vector2 = cam.world_to_viewport(Vector4(float(q[0]), float(q[1]), float(q[2]), w))
			print("MARK %s %s %.2f %.2f" % [view_name, m, px.x, px.y])
		sv.queue_free()
		await process_frame
	print("REF STAGE DONE")
	quit(0)


## [param view_yaw]: the camera's yaw in degrees. The sheets light each view from its own upper
## left, so the neutral key turns with the camera (pen_sun_4d.gd's azimuth matches the camera yaw:
## both put 0 at +z).
func _environment(stage: Node4D, light: String, bg: Color, view_yaw: float = 0.0) -> void:
	var env := WorldEnvironment4D.new()
	var sky := PlainSkyMaterial4D.new()
	sky.color = bg
	env.sky_material = sky
	env.ambient_light_sky_contribution = 0.0
	stage.add_child(env)
	env.make_current()
	var key := DirectionalLight4D.new()
	key.set_script(SUN)
	var fill := DirectionalLight4D.new()
	fill.set_script(SUN)
	stage.add_child(key)
	stage.add_child(fill)
	if light == "pen":
		# The pen's (playable_world.tscn, World/Sun, SkyFill, Environment).
		key.set("elevation_degrees", 14.0)
		key.set("azimuth_degrees", 83.0)
		key.light_color = Color(1, 0.82, 0.52)
		key.light_energy = 0.338
		fill.set("elevation_degrees", 68.0)
		fill.set("azimuth_degrees", -97.0)
		fill.light_color = Color(0.2, 0.53, 0.65)
		fill.light_energy = 0.55
		env.ambient_light_color = Color(0.38, 0.4, 0.36)
		env.tonemap_mode = 2
		env.tonemap_exposure = 1.05
	else:
		# The sheets' studio light: a white key high from the front-left, a soft cool fill from the
		# right, a grey ambient. Numbers set against the sheets (PLAN_REF_LOCK.md step 17).
		key.set("elevation_degrees", float(_args.get("key_el", "48")))
		key.set("azimuth_degrees", view_yaw + float(_args.get("key_az", "-35")))
		key.light_color = Color(1.0, 0.97, 0.92)
		key.light_energy = float(_args.get("key_e", "0.9"))
		fill.set("elevation_degrees", 20.0)
		fill.set("azimuth_degrees", view_yaw + 120.0)
		fill.light_color = Color(0.85, 0.9, 1.0)
		fill.light_energy = float(_args.get("fill_e", "0.25"))
		var amb: float = float(_args.get("amb", "0.42"))
		env.ambient_light_color = Color(amb, amb, amb)
		env.tonemap_mode = 0
		env.tonemap_exposure = 1.0
