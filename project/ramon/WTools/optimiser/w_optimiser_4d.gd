@tool
extends Node4D

## THE W OPTIMISER (WTools/PLAN.md; Ramon, 7 Oct: "for the landmark hero objects, can't we make a W
## optimizer ... so that we can manipulate the W wrap length. The logic of understanding what to wrap in 4D
## and how, based on the assets"). Put it beside a landmark (a unit instance: the Watchstone, the camp) and
## point `target` at it: as the scene starts it reads the landmark as it is and makes it hold in view when
## the slice turns, by its settings or a profile (optimiser/profiles/*.tres). Nothing it makes is saved, and
## the landmark is changed only while it runs: its own scene (units/...) stays the one to edit, and every load
## follows it. Analyse fills in the report; Preview shows the result in the editor (taken away for a save and
## put back after); Clear takes it away.
##
## WHAT IT DOES, AND WHY (WTools/research/experiments.md):
## - THE ANALYSIS. Every drawn mesh of the landmark (not an animal's or a character's) is a part: its size,
##   its W depth either side, its tetrahedra, and a class: ground (low and flat), detail (small), thin
##   (shallower in W than the minimum) or body. The report says what each class holds and how far the slice
##   can turn before the landmark leaves it, seen from 10, 20 and 40 m, before and after.
## - THIN PARTS DEEPER. Each part shallower in W than `min_w_half` either side is made that deep, scaled in W
##   about its own middle. W scale is an exact extrude (the engine probe: the same picture as a mesh built
##   deeper, at any turn), and an extruded part in a turned slice looks like itself, a little longer the way
##   the slice is turned (1 / cos t). Its solid colliders are made as deep (boxes resized, other shapes
##   scaled), never an Area4D's. Near, this is what keeps a landmark: the Watchstone from 10 m kept 53k pixels
##   at 40 degrees of turn, against 3.7k. Far, no depth is enough (d tan t outgrows any W). A part with the
##   metadata `w_keep` is left as it is, and so is a part that sits at another W than the landmark's middle.
## - BUILT IN W. A landmark laid out through W by hand (the range: its boards at W -4 to +4, walls across W
##   that keep you in its yard) is left exactly as it is (`respect_w_layout`): its meshes are merged, so a
##   scale in W would stretch the whole layout (the yard's W walls pushed out among the boards, and as solid
##   blocks 12 m deep across the yard: the optimiser lab found both). It is told by its parts and solid
##   colliders: any whose W middle is off the landmark's (Trym's shed: its walls across W at +-1.7), or any
##   collider that is a wall across W (thin in W, wide in x and z). The wrap still applies (its copy is the
##   landmark whole, turned).
## - THE WRAP, for what is seen from afar (`wrap`). The mountains are a ring round the pen, so one of them is
##   always in a slice; a landmark can do better than a ring. ONE copy of it is drawn where it would be on the
##   flat slice through the camera: lifted to the camera's W, then turned about the camera by the least turn
##   that takes W to the slice's normal. It stays where it was, the same size, the same
##   bearing, at any turn and in any plane, from any W within `wrap_length` (the W wrap length: how far
##   through W either side it follows you) and up to `wrap_arc` of turn. Walk and it comes nearer as anything
##   on the flat slice would. With the slice flat at the landmark's own W, it is the landmark itself. The copy
##   has no collision and stays out of the volume view's projection; within `near_margin` of the landmark it
##   is always the landmark itself: what you see there is what you touch. How it got here (experiments.md):
##   a fan of copies at fixed angles round the area's middle dipped between copies and doubled where two were
##   cut; one copy turned round the middle held a landmark straight ahead exactly, but moved one off to the
##   side across the view (the range slid toward the middle; in the pen the Watchstone slid out of frame when
##   the slice turned across the line to it).
##
## THE PEN'S DEV / ART LOOK (look/pen_look_4d.gd) swaps meshes and adds blockouts on the same landmark: when it
## changes, the Optimiser works the landmark again from what it then draws, so the copy shows the same look.
## The copy's meshes carry the look's own mark (it leaves them alone), and a landmark mesh hidden while its
## copy shows carries `w_hidden`, so the look still strips and measures it as drawn.
##
## No class_name (engine_gotchas.md).

const PROFILE := preload("res://ramon/WTools/optimiser/w_profile.gd")
const Blockouts := preload("res://ramon/chickenpen/look/pen_blockouts_4d.gd")
const Look := preload("res://ramon/chickenpen/look/pen_look_4d.gd")
const VIEWS := [10.0, 20.0, 40.0]

@export_tool_button("Analyse") var _analyse_action: Callable = analyse
@export_tool_button("Preview") var _preview_action: Callable = preview
@export_tool_button("Clear") var _clear_action: Callable = clear
@export_tool_button("Save as profile") var _save_action: Callable = save_profile

## The landmark: a node (a unit instance) whose drawn meshes and colliders are worked.
@export var target: NodePath
@export var enabled: bool = true
## A profile (optimiser/profiles): set, it puts its numbers here (change them after if you like).
@export var profile: Resource:
	set(v):
		profile = v
		if v != null and v.has_method("apply_to"):
			v.call("apply_to", self)

@export_group("Thin parts")
## Every part at least this deep in W either side (0: leave the parts alone).
@export_range(0.0, 80.0, 0.25, "suffix:m") var min_w_half: float = 6.0
@export var deepen_colliders: bool = true
## Leave a landmark built in W (parts or colliders at other W's, walls across W) as it is: only the wrap applies.
@export var respect_w_layout: bool = true
## How far off the landmark's middle W a part or collider may sit and still count as centred.
@export_range(0.0, 2.0, 0.05, "suffix:m") var layout_tolerance: float = 0.3

@export_group("Wrap")
@export var wrap: bool = false
## Up to this much turn of the slice the landmark follows it (past it, only the landmark itself).
@export_range(0.0, 89.0, 1.0, "suffix:deg") var wrap_arc: float = 60.0
## The W wrap length: how far through W either side of the landmark it follows you.
@export_range(0.0, 200.0, 0.5, "suffix:m") var wrap_length: float = 40.0
## Within this of the landmark's bounds (in x, z and W) the landmark itself is drawn, never a copy.
@export_range(0.0, 40.0, 0.5, "suffix:m") var near_margin: float = 8.0
@export var copies_projected: bool = false

@export_group("Readout")
@export_custom(PROPERTY_HINT_MULTILINE_TEXT, "", PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY) var report: String = ""
@export_dir var profile_folder: String = "res://ramon/WTools/optimiser/profiles"

## For runners and the lab.
var parts: Array = []
var parts_deepened: int = 0
var colliders_deepened: int = 0
var wrap_copies: int = 0
## The angle the wrap's copy is turned to now (degrees), for runners.
var wrap_angle: float = 0.0
var cull_usec: int = 0
var build_msec: int = 0
var landmark_w_half: float = 0.0
## The parts' typical W depth either side (the middle of them).
var parts_w_half: float = 0.0
var applied: bool = false
## Solid colliders off the landmark's middle W, and walls across W, as last read (built in W if either).
var off_middle_colliders: int = 0
var w_walls: int = 0
## Drawn parts off the landmark's middle W (a shed's walls across W): built in W too.
var off_middle_parts: int = 0

var _saved: Array = []
var _land_meshes: Array = []
var _land_mid := Vector4.ZERO
var _land_half := Vector4.ZERO
var _shown: int = -2
var _holder: Node4D
var _resave: bool = false


func _ready() -> void:
	if Engine.is_editor_hint() or not enabled:
		return
	# After the landmark has built itself (units make their meshes as they start).
	await get_tree().process_frame
	await get_tree().process_frame
	if is_inside_tree():
		apply()


func _exit_tree() -> void:
	if RenderingServer4D.pre_render.is_connected(_on_pre_render):
		RenderingServer4D.pre_render.disconnect(_on_pre_render)


func _notification(what: int) -> void:
	if not Engine.is_editor_hint():
		return
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		_resave = applied
		clear()
	elif what == NOTIFICATION_EDITOR_POST_SAVE and _resave:
		_resave = false
		apply()


func _landmark() -> Node4D:
	return get_node_or_null(target) as Node4D if not target.is_empty() else null


## The landmark worked anew in the editor (shown, never saved).
func preview() -> void:
	apply()


## Reads the landmark into the report without changing it.
func analyse() -> void:
	clear()
	var land: Node4D = _landmark()
	if land == null:
		report = "No target."
		notify_property_list_changed()
		return
	var meshes: Array = _drawn(land)
	_measure(meshes)
	var before: float = landmark_w_half
	var hu: float = maxf(_land_half.x, _land_half.z)
	_read_layout(land, meshes)
	parts = _classify(meshes)
	report = _report(before, hu, false)
	notify_property_list_changed()


## Works the landmark (again, from as it was).
func apply() -> void:
	clear()
	var land: Node4D = _landmark()
	if land == null:
		push_warning("W Optimiser %s: no target." % name)
		return
	var started: int = Time.get_ticks_msec()
	var meshes: Array = _drawn(land)
	_measure(meshes)
	var before: float = landmark_w_half
	var hu: float = maxf(_land_half.x, _land_half.z)
	_read_layout(land, meshes)
	parts = _classify(meshes)
	if min_w_half > 0.0 and not (respect_w_layout and built_in_w()):
		for p in parts:
			if p["deepen"]:
				_deepen(p["node"])
		if deepen_colliders:
			for cs in land.find_children("*", "CollisionShape4D", true, false):
				_deepen_shape(cs as CollisionShape4D, land)
	_measure(meshes)
	_land_meshes = meshes
	if wrap:
		_wrap(meshes)
	applied = true
	if not Engine.is_editor_hint():
		_follow_look()
	build_msec = Time.get_ticks_msec() - started
	report = _report(before, hu, true)
	if Engine.is_editor_hint():
		notify_property_list_changed()


## Puts the landmark back as it was and takes the copies away.
func clear() -> void:
	for i in range(_saved.size() - 1, -1, -1):
		var rec: Array = _saved[i]
		if is_instance_valid(rec[0]):
			(rec[0] as Object).set(rec[1], rec[2])
	_saved.clear()
	for mi in _land_meshes:
		if is_instance_valid(mi):
			(mi as Node4D).visible = true
			(mi as Node).remove_meta(&"w_hidden")
	_land_meshes.clear()
	if _holder != null and is_instance_valid(_holder):
		remove_child(_holder)
		_holder.queue_free()
	_holder = null
	if RenderingServer4D.pre_render.is_connected(_on_pre_render):
		RenderingServer4D.pre_render.disconnect(_on_pre_render)
	parts_deepened = 0
	colliders_deepened = 0
	wrap_copies = 0
	wrap_angle = 0.0
	_shown = -2
	applied = false


## These numbers as a new profile in profile_folder, named for the time.
func save_profile() -> void:
	var p: Resource = PROFILE.new()
	p.call("take_from", self)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(profile_folder))
	var path: String = profile_folder.path_join("custom_%s.tres" % Time.get_datetime_string_from_system().replace(":", "-"))
	var err: int = ResourceSaver.save(p, path)
	print("W Optimiser: profile saved to %s (%s)" % [path, error_string(err)])


# --- The analysis -----------------------------------------------------------------------------------------

## The landmark's drawn meshes, not an animal's or a character's.
func _drawn(land: Node4D) -> Array:
	var out: Array = []
	for node in land.find_children("*", "MeshInstance4D", true, false):
		var mi := node as MeshInstance4D
		if mi.mesh == null or not mi.is_visible_in_tree() or Blockouts.is_character(mi, land):
			continue
		out.append(mi)
	return out


## Each part with its world size, W depth either side, tetrahedra, class, and whether it is deepened.
func _classify(meshes: Array) -> Array:
	var out: Array = []
	var floor_y: float = _land_mid.y - _land_half.y
	for mi: MeshInstance4D in meshes:
		var box: Array = _world_box([mi])
		var size: Vector4 = box[1] - box[0]
		var half_w: float = size.w * 0.5
		var tets: int = 0
		if mi.mesh is TetraMesh4D:
			tets = (mi.mesh as TetraMesh4D).get_simplex_cell_vertex_indices().size() / 4
		var cls: String = "body"
		var mid_w: float = (box[0].w + box[1].w) * 0.5
		if absf(mid_w - _land_mid.w) > layout_tolerance:
			cls = "elsewhere"
		elif size.y < 0.35 and box[0].y <= floor_y + 0.3 and maxf(size.x, size.z) > 1.0:
			cls = "ground"
		elif maxf(size.x, maxf(size.y, size.z)) < 0.5:
			cls = "detail"
		elif half_w < min_w_half:
			cls = "thin"
		var keep: bool = bool(mi.get_meta(&"w_keep", false))
		out.append({"node": mi, "name": String(mi.name), "class": cls, "size": size, "w_half": half_w, "tets": tets,
			"deepen": not keep and cls != "elsewhere" and not (respect_w_layout and built_in_w()) and min_w_half > 0.0 and half_w > 0.0001 and half_w < min_w_half})
	return out


## The middle of the parts' W depths either side as they are now.
func _typical_w_half() -> float:
	var halves: Array = []
	for p in parts:
		var box: Array = _world_box([p["node"]])
		halves.append((box[1].w - box[0].w) * 0.5)
	if halves.is_empty():
		return landmark_w_half
	halves.sort()
	return float(halves[halves.size() / 2])


## How the landmark sits in W: drawn parts and solid colliders off its middle W (by more than
## layout_tolerance), and walls across W (colliders under 0.35 m deep either side, over 2 m in x and in z).
func _read_layout(land: Node4D, meshes: Array) -> void:
	off_middle_colliders = 0
	w_walls = 0
	off_middle_parts = 0
	for mi: MeshInstance4D in meshes:
		var box: Array = _world_box([mi])
		if absf((box[0].w + box[1].w) * 0.5 - _land_mid.w) > layout_tolerance:
			off_middle_parts += 1
	for cs in land.find_children("*", "CollisionShape4D", true, false):
		var c := cs as CollisionShape4D
		if c.shape == null or not (c.get_parent() is StaticBody4D) or Blockouts.is_character(c, land):
			continue
		var b: Projection = c.global_basis
		var box := c.shape as BoxShape4D
		if box != null:
			var hw: float = box.size.w * 0.5 * Vector4(b.w).length()
			if hw < 0.35 and box.size.x * Vector4(b.x).length() > 2.0 and box.size.z * Vector4(b.z).length() > 2.0:
				w_walls += 1
		if absf(c.global_position.w - _land_mid.w) > layout_tolerance:
			off_middle_colliders += 1


## Laid out through W by hand (see BUILT IN W above).
func built_in_w() -> bool:
	return off_middle_colliders > 0 or w_walls > 0 or off_middle_parts > 0


## The world box [lo, hi] round these meshes.
static func _world_box(meshes: Array) -> Array:
	var lo := Vector4(INF, INF, INF, INF)
	var hi := -lo
	for mi: MeshInstance4D in meshes:
		var r: PackedVector4Array = mi.get_rect_bounds_local()
		for i in 16:
			var corner: Vector4 = r[0] + Vector4(r[1].x * (i & 1), r[1].y * ((i >> 1) & 1), r[1].z * ((i >> 2) & 1), r[1].w * ((i >> 3) & 1))
			var p: Vector4 = mi.global_position + mi.global_basis * corner
			lo = lo.min(p)
			hi = hi.max(p)
	return [lo, hi]


func _measure(meshes: Array) -> void:
	if meshes.is_empty():
		return
	var box: Array = _world_box(meshes)
	_land_mid = (box[0] + box[1]) * 0.5
	_land_half = (box[1] - box[0]) * 0.5
	landmark_w_half = _land_half.w


## How far a slice can turn (degrees) before a landmark this deep in W leaves it, seen from [param distance]
## metres off its middle: it stays while hw >= (d - hu) tan t (hu: its half-size along the view).
static func holds_to(w_half: float, along_half: float, distance: float) -> float:
	return rad_to_deg(atan2(w_half, maxf(distance - along_half, 0.1)))


func _report(before: float, hu: float, worked: bool) -> String:
	var lines := PackedStringArray()
	var land: Node4D = _landmark()
	lines.append("%s: %d parts, %.1f x %.1f x %.1f m, W %.1f m either side%s" % [land.name if land != null else "?", parts.size(),
		_land_half.x * 2.0, _land_half.y * 2.0, _land_half.z * 2.0, before, (" (now %.1f)" % landmark_w_half) if worked else ""])
	var by: Dictionary = {}
	for p in parts:
		var k: String = p["class"]
		if not by.has(k):
			by[k] = [0, 0, 0]
		by[k][0] += 1
		by[k][1] += int(p["tets"])
		by[k][2] += 1 if p["deepen"] else 0
	for k in ["body", "thin", "ground", "detail", "elsewhere"]:
		if by.has(k):
			lines.append("  %-6s %3d parts, %7d tetrahedra, %d to deepen" % [k, by[k][0], by[k][1], by[k][2]])
	if built_in_w():
		lines.append("  built in W (%d colliders and %d parts off its middle W, %d walls across W)%s" % [off_middle_colliders, off_middle_parts, w_walls,
			": kept as it is, only the wrap applies" if respect_w_layout else ": deepened anyway (respect_w_layout is off)"])
	var keep: int = parts.filter(func(p: Dictionary) -> bool: return p["node"].get_meta(&"w_keep", false)).size()
	if keep > 0:
		lines.append("  %d kept as they are (w_keep)" % keep)
	var row := PackedStringArray()
	for d in VIEWS:
		var after: float = maxf(before, min_w_half) if min_w_half > 0.0 and not (respect_w_layout and built_in_w()) else before
		row.append("%d m: %.0f -> %.0f deg" % [int(d), holds_to(before, hu, d), holds_to(after, hu, d)])
	lines.append("holds a turn of  " + ",  ".join(row))
	if wrap:
		lines.append("wrap: where it is on the flat slice, at any turn up to %.0f deg, from %.0f m of W either side; from more than %.0f m off (nearer, the landmark itself)" % [
			wrap_arc, wrap_length, maxf(_land_half.x, _land_half.z) + near_margin])
	if worked:
		lines.append("made: %d parts and %d colliders deepened, %d wrap copies, in %d ms" % [parts_deepened, colliders_deepened, wrap_copies, build_msec])
	return "\n".join(lines)


# --- Thin parts deeper ------------------------------------------------------------------------------------

## A part made min_w_half deep, scaled in W about its own middle (kept to put back).
func _deepen(mi: MeshInstance4D) -> void:
	var r: PackedVector4Array = mi.get_rect_bounds_local()
	var world_w: float = Vector4(mi.global_basis.w).length()
	var half: float = r[1].w * 0.5 * world_w
	if half <= 0.0001 or half >= min_w_half:
		return
	var k: float = min_w_half / half
	_saved.append([mi, "position", mi.position])
	_saved.append([mi, "basis", mi.basis])
	var mid_local: float = r[0].w + r[1].w * 0.5
	var b: Projection = mi.basis
	mi.basis = b * Basis4D.from_scale(Vector4(1.0, 1.0, 1.0, k))
	# About its own middle: where the middle was, it stays.
	mi.position -= b * Vector4(0.0, 0.0, 0.0, mid_local * (k - 1.0))
	parts_deepened += 1


## A solid collider made as deep: a box resized (a copy of its shape, so a shared one is not changed for
## others), any other shape's node scaled in W. Never an Area4D's (its reach is a rule, not a wall).
func _deepen_shape(cs: CollisionShape4D, land: Node4D) -> void:
	if cs.shape == null or not (cs.get_parent() is StaticBody4D) or Blockouts.is_character(cs, land):
		return
	var world_w: float = Vector4(cs.global_basis.w).length()
	var box := cs.shape as BoxShape4D
	if box != null:
		var half: float = box.size.w * 0.5 * world_w
		if half >= min_w_half:
			return
		_saved.append([cs, "shape", box])
		var deeper := box.duplicate() as BoxShape4D
		deeper.size = Vector4(box.size.x, box.size.y, box.size.z, min_w_half * 2.0 / maxf(world_w, 0.0001))
		cs.shape = deeper
	else:
		var r: PackedVector4Array = cs.shape.get_rect_bounds(Projection.IDENTITY, Vector4.ZERO) if cs.shape.has_method("get_rect_bounds") else PackedVector4Array()
		var half: float = (r[1].w * 0.5 if r.size() == 2 else 0.5) * world_w
		if half >= min_w_half:
			return
		_saved.append([cs, "basis", cs.basis])
		cs.basis = cs.basis * Basis4D.from_scale(Vector4(1.0, 1.0, 1.0, min_w_half / maxf(half, 0.0001)))
	colliders_deepened += 1


# --- The wrap ---------------------------------------------------------------------------------------------

## One copy of the landmark's drawn meshes (sharing them), in a holder: each mesh at its own place, so the
## holder's transform carries the whole landmark at once.
func _wrap(meshes: Array) -> void:
	parts_w_half = _typical_w_half()
	_holder = Node4D.new()
	_holder.name = "WrapCopy"
	add_child(_holder)
	_holder.global_position = Vector4.ZERO
	_holder.global_basis = Projection.IDENTITY
	for mi: MeshInstance4D in meshes:
		var m := MeshInstance4D.new()
		m.mesh = mi.mesh
		m.material_override = mi.material_override
		m.allow_projection = copies_projected
		m.set_meta(Look.OWN, true)
		_holder.add_child(m)
		m.position = mi.global_position
		m.basis = mi.global_basis
	wrap_copies = 1
	# In the editor there is no slice to follow: the copy waits, hidden.
	_holder.visible = false
	if not Engine.is_editor_hint() and not RenderingServer4D.pre_render.is_connected(_on_pre_render):
		RenderingServer4D.pre_render.connect(_on_pre_render)


## The copy where the landmark is on the flat slice through [param e]: lifted [param dw] in W to the
## camera's W, then turned about the camera by [param r] (flat W to the slice's normal). A part at p goes
## to e + r (p - e - dw W); the holder carries that as a place and a turn.
func _place(e: Vector4, r: Projection, dw: float) -> void:
	_holder.global_basis = r
	_holder.global_position = e - r * (e + Vector4(0.0, 0.0, 0.0, dw))


## Where the copy's middle is now (for runners).
func copy_middle_now() -> Vector4:
	return _holder.global_position + _holder.global_basis * _land_mid if _holder != null else _land_mid


## The least turn taking W to the slice's normal (the W axis of [param b], the camera's basis), in the plane
## of the two, nothing else moved. A rig turns the slice one plane at a time (xw, zw), and for a turn in one
## plane this is that very turn: the copy shows the camera exactly what the landmark showed it on the flat
## slice (the optimiser lab: 0.000 m off the slice, and a quarter of a degree off the flat view at 60, all of
## it the camera coming nearer as the slice turns, it being behind the player). Turned in both at once, it is off by the small turn between the two orders. (The
## flat frame nearest the camera's was tried: with the camera pitched, it drifted 3.7 degrees by 60.)
static func to_slice(b: Projection) -> Projection:
	var n: Vector4 = Vector4(b.w).normalized()
	var a := Vector4(0.0, 0.0, 0.0, 1.0)
	var s: Vector4 = a + n
	var k: float = maxf(1.0 + n.w, 0.0001)
	var cols: Array[Vector4] = []
	for j in 4:
		var ej := Vector4.ZERO
		ej[j] = 1.0
		cols.append(ej - s * (s[j] / k) + n * (2.0 * a[j]))
	return Projection(cols[0], cols[1], cols[2], cols[3])


## The landmark, or its copy where the landmark is on the flat slice through the camera.
func _on_pre_render(camera: Camera4D, viewport: Viewport, engine: RenderingEngine4D) -> void:
	if viewport != get_viewport() or camera == null or _holder == null:
		return
	var started: int = Time.get_ticks_usec()
	var slice: bool = engine == null or engine.get_friendly_name() == "Cross-section"
	var e: Vector4 = camera.global_position
	# At the landmark (on it, in it, beside it) it is always the landmark itself: what you see is what you
	# touch, since the copy has no collision.
	var near: bool = Vector2(e.x - _land_mid.x, e.z - _land_mid.z).length() < maxf(_land_half.x, _land_half.z) + near_margin \
		and absf(e.w - _land_mid.w) < _land_half.w + near_margin
	var pick: int = -1
	if slice and not near:
		var n: Vector4 = camera.global_basis.w.normalized()
		var dw: float = _land_mid.w - e.w
		var turn: float = rad_to_deg(acos(clampf(n.w, -1.0, 1.0)))
		# While the slice still cuts the landmark itself near its middle (within a quarter of its parts'
		# typical depth), it is the landmark itself; past that, its copy, within the arc and the length.
		if absf((_land_mid - e).dot(n)) > 0.25 * parts_w_half and turn <= wrap_arc + 0.01 and absf(dw) <= wrap_length:
			pick = 0
			_place(e, to_slice(camera.global_basis), dw)
			wrap_angle = turn
	if pick != _shown:
		_shown = pick
		for mi in _land_meshes:
			(mi as Node4D).visible = pick == -1
			if pick == -1:
				(mi as Node).remove_meta(&"w_hidden")
			else:
				(mi as Node).set_meta(&"w_hidden", true)
		_holder.visible = pick == 0
	cull_usec = Time.get_ticks_usec() - started


## Follows the pen's look, if there is one (not in the labs).
func _follow_look() -> void:
	var look: Node = Look.current
	if look == null or not is_instance_valid(look) or look.is_connected("applied_changed", _on_look):
		return
	look.connect("applied_changed", _on_look)


func _on_look(_dev: bool) -> void:
	if applied:
		_rework.call_deferred()


func _rework() -> void:
	if applied and is_inside_tree():
		apply()


## Which is drawn: -1 the landmark, 0 its copy (for runners).
func shown() -> int:
	return _shown
