extends SceneTree

## LANDMARK REACH (WTools/PLAN.md steps 26-31): what each treatment does to a whole landmark as the slice
## turns. One unit at a time on the lab floor, the camera d metres off looking at it (10, 20, 40 m), the
## slice turned in the plane of the view (zw: what moves a thing straight ahead out of the slice) 0 to 60
## degrees. The landmark's area on screen is measured as the pixels that change when it is shown (a frame
## with it, one without). Treatments, all on copies of the unit's own meshes (sharing them):
##   none      the unit as built
##   extrude   the unit scaled in W about itself, to `EXTRUDE_HW` half-depth (W scale is exact: probe step 9)
##   quarter   plus a copy turned a quarter in X and W about its own vertical axis
##   repeat    plus copies every 4.5 m through W, out to +-18
##   wrap      plus copies swept round the viewer in the plane of (the way to the landmark, W), every 7.5
##             degrees out to +-60: the mountains' way, at the landmark's own distance
##   p_<name>  the W Optimiser with optimiser/profiles/<name>.tres (its wrap centred on the viewer)
## Frames: res://smoke_test_output/wtools/reach/<unit>_<treatment>_<d>m_<turn>.png at 0, 20, 40, 60 degrees.
##
##   lab_run.sh windowed wt_reach res://ramon/WTools/tests/_reach_landmarks_runner.gd [unit names]

const Room := preload("res://ramon/CreationLab/LabKit/lab_room_4d.gd")
const OPT := preload("res://ramon/WTools/optimiser/w_optimiser_4d.gd")
const PROFILES := "res://ramon/WTools/optimiser/profiles/"
const OUT := "res://smoke_test_output/wtools/reach/"
const UNITS := {
	"range": ["res://ramon/chickenpen/units/rune_range/rune_range.tscn", {"RangeYard:enclosed_in_w": false}],
	"range_hand4d": ["res://ramon/chickenpen/units/rune_range/rune_range.tscn", {"RangeYard:enclosed_in_w": true}],
	"watchstone": ["res://ramon/chickenpen/units/watchstone/watchstone.tscn", {}],
	"camp": ["res://ramon/chickenpen/units/camp/camp.tscn", {}],
}
const TREATMENTS := ["none", "extrude", "quarter", "repeat", "wrap", "extrude_parts", "wrap_nearest"]
## For the per-part extrude: every mesh at least this deep in W, either side (none made shallower).
const PART_HW := 6.0
const DISTANCES := [10.0, 20.0, 40.0]
const TURNS := [0.0, 10.0, 20.0, 30.0, 40.0, 60.0]
const SHOTS := [0.0, 20.0, 40.0, 60.0]
const EXTRUDE_HW := 9.0

var _cam: Camera4D
var _t0: int = 0


func _initialize() -> void:
	root.unfocusable = true
	_t0 = Time.get_ticks_msec()
	_run.call_deferred()


func _process(_d: float) -> bool:
	if Time.get_ticks_msec() - _t0 > 1500000:
		print("REACH: gave up")
		return true
	return false


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var world := Node4D.new()
	root.add_child(world)
	var room := Node4D.new()
	room.set_script(Room)
	room.set("ground_size", Vector4(400.0, 1.0, 400.0, 400.0))
	world.add_child(room)
	_cam = Camera4D.new()
	_cam.rendering_engine_name = "Cross-section"
	world.add_child(_cam)
	_cam.make_current()
	var want: PackedStringArray = OS.get_cmdline_user_args()
	# only=a,b: just these treatments.
	var treatments: Array = TREATMENTS
	for w in want:
		if w.begins_with("only="):
			treatments = Array(w.substr(5).split(","))
	want = PackedStringArray(Array(want).filter(func(w: String) -> bool: return not w.begins_with("only=")))
	var names: Array = UNITS.keys() if want.is_empty() else Array(want)
	for u in names:
		var unit: Node4D = (load(UNITS[u][0]) as PackedScene).instantiate()
		for k in UNITS[u][1]:
			# "child:property" sets it on a child (the range's yard is its own node).
			var target: Node = unit.get_node(String(k).get_slice(":", 0)) if String(k).contains(":") else unit
			target.set(String(k).get_slice(":", 1) if String(k).contains(":") else k, UNITS[u][1][k])
		world.add_child(unit)
		await _frames(30)
		var r: PackedVector4Array = unit.get_rect_bounds_global_recursive(Projection.IDENTITY, Vector4.ZERO) if unit.has_method("get_rect_bounds_global_recursive") else PackedVector4Array([Vector4(-5, 0, -5, -1), Vector4(10, 5, 10, 2)])
		var mid: Vector4 = r[0] + r[1] * 0.5
		unit.set_meta(&"mid", mid)
		var tall: float = r[1].y
		print("REACH %s: bounds %s, %.1f m tall, W %.1f deep" % [u, str(r[1]), tall, r[1].w])
		for d in DISTANCES:
			var eye := Vector4(mid.x, 1.7, mid.z + d, 0.0)
			for treat in treatments:
				var extra: Array[Node4D] = _treat(unit, treat, eye, mid)
				var line := PackedStringArray()
				for turn in TURNS:
					_cam.position = eye
					_cam.basis = Basis4D.from_zw(deg_to_rad(turn)) * Basis4D.from_yz(-atan2(1.7 - mid.y, d))
					if treat == "wrap_nearest":
						_nearest_only(unit, extra, mid)
					var area: int = await _area(unit, extra, "%s_%s_%dm_%02d" % [u, treat, int(d), int(turn)] if SHOTS.has(turn) else "")
					line.append("%6d" % area)
				print("REACH %s %-8s %2dm  %s" % [u, treat, int(d), " ".join(line)])
				_untreat(unit, extra)
		unit.queue_free()
		await _frames(5)
	print("REACH: turns %s (zw); landmark pixels on screen" % str(TURNS))
	quit(0)


## Pixels that change when the landmark (and its copies) is shown; a frame saved when [param shot] is set.
func _area(unit: Node4D, extra: Array[Node4D], shot: String) -> int:
	_show(unit, extra, true)
	await _frames(3)
	await RenderingServer.frame_post_draw
	var with: Image = root.get_texture().get_image()
	if shot != "":
		with.save_png(ProjectSettings.globalize_path(OUT + shot + ".png"))
	_show(unit, extra, false)
	await _frames(3)
	await RenderingServer.frame_post_draw
	var without: Image = root.get_texture().get_image()
	_show(unit, extra, true)
	var n: int = 0
	for y in range(0, with.get_height(), 3):
		for x in range(0, with.get_width(), 3):
			var a: Color = with.get_pixel(x, y)
			var b: Color = without.get_pixel(x, y)
			if absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) > 0.06:
				n += 1
	return n


func _show(unit: Node4D, extra: Array[Node4D], on: bool) -> void:
	var pick: Variant = unit.get_meta(&"wrap_pick") if unit.has_meta(&"wrap_pick") else null
	unit.visible = on and (pick == null or pick == unit)
	for e in extra:
		e.visible = on and (pick == null or pick == e)


## The unit's drawn meshes, as [mesh instance, its global transform].
func _meshes(unit: Node4D) -> Array:
	var out: Array = []
	for node in unit.find_children("*", "MeshInstance4D", true, false):
		var mi := node as MeshInstance4D
		if mi.mesh != null and mi.is_visible_in_tree():
			out.append(mi)
	return out


## A copy of every drawn mesh of [param unit], each transform mapped by [param basis] about [param pivot].
func _copy(unit: Node4D, basis: Projection, pivot: Vector4, offset: Vector4 = Vector4.ZERO) -> Node4D:
	var holder := Node4D.new()
	unit.get_parent().add_child(holder)
	var mid: Vector4 = unit.get_meta(&"mid", unit.global_position)
	holder.set_meta(&"centre", pivot + basis * (mid - pivot) + offset)
	for mi: MeshInstance4D in _meshes(unit):
		var c := MeshInstance4D.new()
		c.mesh = mi.mesh
		c.material_override = mi.material_override
		holder.add_child(c)
		c.global_position = pivot + basis * (mi.global_position - pivot) + offset
		c.global_basis = basis * mi.global_basis
	return holder


func _treat(unit: Node4D, treat: String, eye: Vector4, mid: Vector4) -> Array[Node4D]:
	var extra: Array[Node4D] = []
	unit.set_meta(&"was_basis", unit.basis)
	unit.set_meta(&"was_position", unit.position)
	if treat.begins_with("p_"):
		var opt := Node4D.new()
		opt.set_script(OPT)
		opt.set("enabled", false)
		unit.get_parent().add_child(opt)
		opt.set("target", opt.get_path_to(unit))
		opt.set("profile", load(PROFILES + treat.substr(2) + ".tres"))
		opt.call("apply")
		print("REACH %s
%s" % [treat, String(opt.get("report"))])
		extra.append(opt)
		return extra
	match treat:
		"extrude":
			var deep: float = maxf(1.0, EXTRUDE_HW / maxf(_w_half(unit), 0.1))
			unit.basis = unit.basis * Basis4D.from_scale(Vector4(1, 1, 1, deep))
		"quarter":
			var axis := Vector4(mid.x, 0.0, mid.z, 0.0)
			extra.append(_copy(unit, Basis4D.from_xw(PI * 0.5), axis))
		"repeat":
			var k: int = 1
			while k * 4.5 <= 18.0:
				for sgn in [-1.0, 1.0]:
					extra.append(_copy(unit, Projection.IDENTITY, Vector4.ZERO, Vector4(0, 0, 0, sgn * k * 4.5)))
				k += 1
		"extrude_parts":
			for mi: MeshInstance4D in _meshes(unit):
				var h: float = _mesh_w_half(mi)
				if h > 0.0 and h < PART_HW:
					mi.set_meta(&"was_part_basis", mi.basis)
					mi.basis = mi.basis * Basis4D.from_scale(Vector4(1, 1, 1, PART_HW / h))
		"wrap", "wrap_nearest":
			# Round the eye, in the plane of (the way from the eye to the landmark, W).
			var u: Vector4 = Vector4(mid.x - eye.x, 0.0, mid.z - eye.z, 0.0).normalized()
			var pivot := Vector4(eye.x, 0.0, eye.z, eye.w)
			var a: float = 7.5
			while a <= 60.0:
				for sgn in [-1.0, 1.0]:
					extra.append(_copy(unit, _plane_turn(u, deg_to_rad(a * sgn)), pivot))
				a += 7.5
	return extra


func _untreat(unit: Node4D, extra: Array[Node4D]) -> void:
	for mi: MeshInstance4D in _meshes(unit):
		if mi.has_meta(&"was_part_basis"):
			mi.basis = mi.get_meta(&"was_part_basis")
			mi.remove_meta(&"was_part_basis")
	for e in extra:
		if e.has_method("clear"):
			e.call("clear")
	unit.visible = true
	unit.basis = unit.get_meta(&"was_basis")
	unit.position = unit.get_meta(&"was_position")
	for e in extra:
		e.queue_free()
	if unit.has_meta(&"wrap_pick"):
		unit.remove_meta(&"wrap_pick")


## Of the landmark and its wrap copies, only the one whose middle the slice passes nearest: the copies
## either side overlap in a turned slice and doubled the scaffold (frames, 7 Oct).
func _nearest_only(unit: Node4D, extra: Array[Node4D], mid: Vector4) -> void:
	var n: Vector4 = _cam.global_basis.w.normalized()
	var best: Node4D = unit
	var best_s: float = absf((mid - _cam.global_position).dot(n))
	for e in extra:
		var c: Vector4 = e.get_meta(&"centre", mid)
		var s: float = absf((c - _cam.global_position).dot(n))
		if s < best_s:
			best_s = s
			best = e
	unit.set_meta(&"wrap_pick", best)
	unit.visible = best == unit
	for e in extra:
		e.visible = e == best


func _mesh_w_half(mi: MeshInstance4D) -> float:
	var r: PackedVector4Array = mi.get_rect_bounds_local()
	return r[1].w * 0.5 * Vector4(mi.basis.w).length()


## A turn by [param angle] in the plane of the horizontal unit vector [param u] and W.
static func _plane_turn(u: Vector4, angle: float) -> Projection:
	var c: float = cos(angle)
	var s: float = sin(angle)
	var cols: Array[Vector4] = []
	for e in [Vector4(1, 0, 0, 0), Vector4(0, 1, 0, 0), Vector4(0, 0, 1, 0), Vector4(0, 0, 0, 1)]:
		var a: float = e.dot(u)
		var b: float = e.w
		var rest: Vector4 = e - u * a - Vector4(0, 0, 0, b)
		cols.append(rest + u * (a * c - b * s) + Vector4(0, 0, 0, a * s + b * c))
	return Projection(cols[0], cols[1], cols[2], cols[3])


## The unit's W half-depth (its drawn meshes' bounds).
func _w_half(unit: Node4D) -> float:
	var lo: float = INF
	var hi: float = -INF
	for mi: MeshInstance4D in _meshes(unit):
		var r: PackedVector4Array = mi.get_rect_bounds_local()
		for i in 16:
			var corner: Vector4 = r[0] + Vector4(r[1].x * (i & 1), r[1].y * ((i >> 1) & 1), r[1].z * ((i >> 2) & 1), r[1].w * ((i >> 3) & 1))
			var p: Vector4 = mi.global_position + mi.global_basis * corner - unit.global_position
			lo = minf(lo, p.w)
			hi = maxf(hi, p.w)
	return (hi - lo) * 0.5
