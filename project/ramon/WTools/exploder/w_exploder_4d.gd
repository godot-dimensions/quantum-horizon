@tool
extends Node4D

## THE W EXPLODER (WTools/PLAN.md; Ramon, 7 Oct: "a W exploder tool/script. effectively pushing the tree in
## more W slices above and below depending on settings. and each tree would have its own way to offset
## parameters so it works in 4D"). Put it over a container of hand-placed plants (its children with the oak
## script, pen_oak_4d.gd): as the scene starts it stands them again through W, by its settings or a preset
## (exploder/presets/*.tres), and culls the whole planting in one pass a frame. Nothing it makes is saved:
## the scene holds only what was placed by hand, so the farm's own slice is exactly that. Preview shows the
## copies in the editor (the wood only; leaves grow at play), Clear takes them away.
##
## WHAT IT DOES, AND WHY (WTools/research/experiments.md):
## - LAYERS. Every plant again at W steps of `layer_spacing` out to `w_reach` either side, each copy a pace
##   or two to one side, turned about its trunk and in X and W (another cut of the same 4D tree), a little
##   bigger or smaller, now and then the other size; `w_jitter` breaks the layers so a turned slice does not
##   show them as stripes. A turned slice then passes through some layer everywhere it looks: with layers to
##   18 m, the lab's wood kept 26-31 of its 33 crowns from 10 to 60 degrees of turn, where it had kept 5.
## - HOW MANY. A turned slice shows share x 2h / spacing times the hand-placed density (h: a crown's W reach),
##   so share = spacing / 2h keeps a turned slice as full as the flat one: `auto_share`.
## - HOW FAR. A layer at W w is cut by a slice turned t at w / tan t along the ground: layers out to w_reach
##   fill a turned slice out to (w_reach + h) / tan t. The Aim settings say which reach a view needs.
## - THE TRUNKS. A thin trunk leaves a turned slice long before its crown, and the crowns float (24 of 30 at
##   20 degrees). Each plant's trunk is made one depth in W up to where its branches start, `trunk_w_slab` of
##   its crown's W reach: cut whenever its crown is, full height, never as a stump (a taper toward the ground
##   left stumps: experiments.md). The flat slice is untouched (W only).
## - THE VOLUME VIEW. The copies are left out of the projection (they smeared it white); `copies_projected`.
## - STABLE. Each copy's dice come from its plant's name and its layer: moving or adding one plant changes only
##   that plant's copies.
## - ONE PASS. Every plant's cull box in packed arrays; one loop of arithmetic a frame shows or hides them
##   (cull_usec), instead of a call per plant.
##
## PER PLANT (metadata on a placed plant): `w_copies` "none", "fewer" (half the share) or "more" (half again);
## `w_reach` its own reach.
##
## WHERE NOT, in every W: the paths (`paths_path`: a network with a `graph`), landmarks (any node with a
## footprint() taking nothing), walls (nodes with from, to and gaps), hills (the grass's baked heights), the
## valley (`valley_radius` round `valley_centre`), and any node in the group "w_exclude" with
## excludes(point) (w_exclude_4d.gd: a ball or a box in x, z, W).
##
## No class_name (engine_gotchas.md).

const OAK := preload("res://ramon/chickenpen/scripts/pen_oak_4d.gd")
const Heights := preload("res://ramon/chickenpen/grass/grass_heights_4d.gd")
const PRESET := preload("res://ramon/WTools/exploder/w_exploder_preset.gd")

@export_tool_button("Preview copies") var _preview_action: Callable = preview
@export_tool_button("Clear copies") var _clear_action: Callable = clear
@export_tool_button("Save as preset") var _save_action: Callable = save_preset

@export var enabled: bool = true
## A preset (exploder/presets): set, it puts its numbers here (change them after if you like).
@export var preset: Resource:
	set(v):
		preset = v
		if v != null and v.has_method("apply_to"):
			v.call("apply_to", self)

@export_group("Distribution")
@export_range(1.0, 20.0, 0.25, "suffix:m") var layer_spacing: float = 4.5
## How far through W the copies reach either side.
@export_range(0.0, 80.0, 0.5, "suffix:m") var w_reach: float = 18.0
@export_range(0.0, 4.0, 0.05, "suffix:m") var w_jitter: float = 0.8
## The share of the plants that stand again in each layer (when auto_share is off).
@export_range(0.0, 1.0, 0.01) var share: float = 0.62
## The share from the spacing and the crowns' reach, spacing / 2h: a turned slice as full as the flat one.
@export var auto_share: bool = true
## How far in W a crown reaches either side of its plant (rounded oaks: about 3.6 m).
@export_range(0.5, 10.0, 0.1, "suffix:m") var crown_w_reach: float = 3.6

@export_group("Aim")
## What a view needs: to keep the wood out to view_distance with the slice turned target_angle, the reach
## must be at least view_distance x tan(target_angle) - crown_w_reach (shown in reach_needed).
@export_range(1.0, 80.0, 1.0, "suffix:deg") var target_angle: float = 30.0
@export_range(5.0, 120.0, 1.0, "suffix:m") var view_distance: float = 40.0
var reach_needed: float:
	get:
		return maxf(view_distance * tan(deg_to_rad(target_angle)) - crown_w_reach, 0.0)

@export_group("Each copy")
## How far to one side (nearest, furthest).
@export var shift: Vector2 = Vector2(0.8, 2.2)
@export_range(0.0, 0.4, 0.01) var size_jitter: float = 0.12
@export_range(0.0, 1.0, 0.01) var swap_share: float = 0.3
@export var turn_zx: bool = true
@export var turn_xw: bool = true
@export var turn_zw: bool = false
@export var seed_salt: int = 47

@export_group("Trunks")
## The trunk one depth in W to its branches, this share of its crown's W reach; 0 leaves it as baked.
@export_range(0.0, 1.2, 0.05) var trunk_w_slab: float = 0.9
## Where the branches start, as a share of the tree's height (the slab eases back to the wood's own above).
@export_range(0.05, 1.0, 0.05) var taper_top: float = 0.45

## Copies have trunks you bump into, as the plants do. Off, you walk through the copies' trunks.
@export var copies_solid: bool = true
## The one who walks among the copies (the player). Set, a copy's trunk is in the physics only while they
## are within solid_w_margin of its W: every body costs every move a check (the engine's physics looks at
## them all), about 1.7 us a frame each, and the pen's 458 copies cost 0.7 ms solid all the time.
@export var solid_near_path: NodePath
@export_range(0.5, 20.0, 0.5, "suffix:m") var solid_w_margin: float = 3.0

@export_group("Volume view")
@export var copies_projected: bool = false

@export_group("Exclusions")
@export_range(0.0, 8.0, 0.1, "suffix:m") var clear_of_paths: float = 2.4
@export_range(0.0, 8.0, 0.1, "suffix:m") var clear_of_frames: float = 1.5
@export_range(0.0, 8.0, 0.1, "suffix:m") var clear_of_walls: float = 2.0
@export var valley_centre: Vector2 = Vector2(0.0, 6.0)
@export_range(5.0, 200.0, 0.5, "suffix:m") var valley_radius: float = 54.0
@export var paths_path: NodePath = ^"../Paths"
## Where to look for landmarks and walls (the parent's subtree by default).
@export var scan_path: NodePath = ^".."
@export var use_hill_heights: bool = true

@export_group("Presets")
@export_dir var preset_folder: String = "res://ramon/WTools/exploder/presets"

## For runners and the lab: placed by hand, made here, spots refused, the last cull's time, how long making took.
var placed: int = 0
var echo_count: int = 0
var refused: int = 0
var cull_usec: int = 0
var build_msec: int = 0

var _oaks: Array[Node] = []
var _segments: Array = []
var _rounds: Array = []
var _heights: Image
# The packed cull: per plant its tree node, the middle of its cull box and the box's four half-axes.
var _cull_trees: Array[Node4D] = []
var _cull_mid := PackedVector4Array()
var _cull_ax := PackedVector4Array()
var _cull_ay := PackedVector4Array()
var _cull_az := PackedVector4Array()
var _cull_aw := PackedVector4Array()
var _cull_r := PackedFloat32Array()
var _cull_on := PackedByteArray()
var _cull_ready: bool = false
# The copies' trunks kept in the physics only near the player's W: [body, its oak, W low, W high, in].
var _solid: Array = []
var _solid_near: Node4D
## For runners: copies' trunks in the physics now.
var solid_in: int = 0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_plant_all()
	for child in get_children():
		if child.has_method("set_managed"):
			child.call("set_managed", true)
			_oaks.append(child)
	RenderingServer4D.pre_render.connect(_on_pre_render)
	_build_cull.call_deferred()


func _exit_tree() -> void:
	if RenderingServer4D.pre_render.is_connected(_on_pre_render):
		RenderingServer4D.pre_render.disconnect(_on_pre_render)
	_free_solid()


## Trunks taken out of the physics are out of the tree: their oaks will not free them.
func _free_solid() -> void:
	for rec in _solid:
		if not bool(rec[4]) and is_instance_valid(rec[0]):
			(rec[0] as Node).free()
	_solid.clear()
	solid_in = 0


## Plants again from the settings as they are now, while playing (the lab's preset key): the copies made
## anew, the cull built again once they have settled.
func replant() -> void:
	_cull_ready = false
	clear()
	_plant_all()
	_oaks.clear()
	for child in get_children():
		if child.has_method("set_managed"):
			child.call("set_managed", true)
			_oaks.append(child)
	_build_cull.call_deferred()


## The copies, made now (in the editor: shown, not saved).
func preview() -> void:
	clear()
	_plant_all()


func clear() -> void:
	_free_solid()
	for child in get_children():
		if child.has_meta(&"w_copy"):
			remove_child(child)
			child.queue_free()
	echo_count = 0
	refused = 0


## These numbers as a new preset in preset_folder, named for the time.
func save_preset() -> void:
	var p: Resource = PRESET.new()
	p.call("take_from", self)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(preset_folder))
	var path: String = preset_folder.path_join("custom_%s.tres" % Time.get_datetime_string_from_system().replace(":", "-"))
	var err: int = ResourceSaver.save(p, path)
	print("W Exploder: preset saved to %s (%s)" % [path, error_string(err)])


func _plant_all() -> void:
	var started: int = Time.get_ticks_msec()
	var authored: Array[Node4D] = []
	for child in get_children():
		if child.get_script() == OAK and not child.has_meta(&"w_copy"):
			authored.append(child as Node4D)
	placed = authored.size()
	if enabled and not authored.is_empty():
		_keep_outs()
		_heights = null
		if use_hill_heights and ResourceLoader.exists(Heights.BAKED):
			_heights = load(Heights.BAKED) as Image
		_plant_layers(authored)
	if trunk_w_slab > 0.0 and not Engine.is_editor_hint():
		for child in get_children():
			if child.get_script() == OAK:
				_slab(child)
	build_msec = Time.get_ticks_msec() - started


# --- The layers -------------------------------------------------------------------------------------------

## The W's of the layers out to [param reach]: every step either side (not 0: that is the placed one).
func layer_ws(reach: float = -1.0) -> PackedFloat32Array:
	var r: float = w_reach if reach < 0.0 else reach
	var out := PackedFloat32Array()
	var k: int = 1
	while float(k) * layer_spacing <= r + 0.001:
		out.append(float(k) * layer_spacing)
		out.append(-float(k) * layer_spacing)
		k += 1
	return out


func effective_share() -> float:
	return clampf(layer_spacing / (2.0 * crown_w_reach), 0.0, 1.0) if auto_share else share


## How far along the ground a slice turned [param degrees] keeps the copies' wood (the layers' reach).
func reach_at(degrees: float) -> float:
	var t: float = tan(deg_to_rad(maxf(degrees, 0.5)))
	return (w_reach + crown_w_reach) / t


func _plant_layers(authored: Array[Node4D]) -> void:
	for src in authored:
		var mood: String = String(src.get_meta(&"w_copies", ""))
		if mood == "none":
			continue
		var s: float = effective_share() * (0.5 if mood == "fewer" else (1.5 if mood == "more" else 1.0))
		var reach: float = float(src.get_meta(&"w_reach", w_reach))
		for w in layer_ws(reach):
			var rng := _dice(src, w)
			if rng.randf() > s:
				continue
			var w_here: float = src.position.w + w + rng.randf_range(-w_jitter, w_jitter)
			_place_near(src, w_here, rng, String(src.name) + "_%s%s" % ["ana" if w > 0.0 else "kata", str(absf(w)).replace(".", "_")])


## Dice for one copy: from the plant's name and the layer, so the copy stays put while others change.
func _dice(src: Node, w: float) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_salt, String(src.name), snappedf(w, 0.01)])
	return rng


## A copy of [param src] near it, at [param w], if a clear spot is found in six tries.
func _place_near(src: Node4D, w: float, rng: RandomNumberGenerator, copy_name: String) -> void:
	var bush: bool = String(src.get("bake")).begins_with("bush")
	for attempt in 6:
		var a: float = rng.randf() * TAU
		var r: float = rng.randf_range(shift.x, shift.y) * (0.6 if bush else 1.0)
		var p := Vector2(src.position.x + cos(a) * r, src.position.z + sin(a) * r)
		if _clear(p, w, 0.6 if bush else 1.0):
			_spawn(src, p, w, rng, copy_name)
			return
	refused += 1


func _spawn(src: Node4D, p: Vector2, w: float, rng: RandomNumberGenerator, copy_name: String) -> void:
	var bake: String = String(src.get("bake"))
	var height: float = float(src.get("height")) * (1.0 + rng.randf_range(-size_jitter, size_jitter))
	if bake.begins_with("bush"):
		bake = "bush_%d" % rng.randi_range(1, 3)
	elif rng.randf() < swap_share:
		if bake == "oak_lite3":
			bake = "oak_lite4"
			height *= 0.88
		elif bake == "oak_lite4":
			bake = "oak_lite3"
			height *= 1.12
	var oak := Node4D.new()
	oak.set_script(OAK)
	oak.set("bake", bake)
	oak.set("height", clampf(height, 0.8, 14.0))
	oak.set("trunk", src.get("trunk"))
	oak.set("leaf_seed", src.get("leaf_seed"))
	oak.set("w_stretch", src.get("w_stretch"))
	oak.set("managed", true)
	oak.set_meta(&"w_copy", true)
	oak.name = copy_name.validate_node_name()
	oak.position = Vector4(p.x, src.position.y, p.y, w)
	var turn: Projection = Projection.IDENTITY
	if turn_zx:
		turn = turn * Basis4D.from_zx(rng.randf() * TAU)
	if turn_xw:
		turn = turn * Basis4D.from_xw(rng.randf() * TAU)
	if turn_zw:
		turn = turn * Basis4D.from_zw(rng.randf() * TAU)
	oak.basis = turn
	add_child(oak, true)
	if not copies_solid:
		var body: Node = oak.get("_body")
		if body != null:
			oak.remove_child(body)
			body.free()
			oak.set("_body", null)
	if not copies_projected:
		for mi in oak.find_children("*", "MeshInstance4D", true, false):
			(mi as MeshInstance4D).allow_projection = false
	echo_count += 1


# --- The trunk slab ---------------------------------------------------------------------------------------

static var _slabbed: Dictionary = {}


## The plant's wood swapped for a copy whose trunk is one depth in W up to its branches (see trunk_w_slab),
## made once per bake and depth and shared. The depth is set on the plant as metadata (trunk_w_half) for the
## dev look's blockout.
func _slab(oak: Node) -> void:
	var wood := oak.get_node_or_null("Tree/Wood") as MeshInstance4D
	if wood == null or not (wood.mesh is ArrayTetraMesh4D):
		return
	var src := wood.mesh as ArrayTetraMesh4D
	if src.has_meta(&"w_slab_of"):
		return
	var crown: Array = oak.call("crown_box") if oak.has_method("crown_box") else []
	if crown.size() != 2:
		return
	var tree := wood.get_parent() as Node4D
	var s: Vector4 = tree.scale if tree != null else Vector4.ONE
	var crown_w: float = ((crown[1] as Vector4).w - (crown[0] as Vector4).w) * 0.5 / maxf(s.w, 0.0001)
	var key := "%d|%.2f|%.2f|%.2f" % [src.get_instance_id(), trunk_w_slab, taper_top, snappedf(crown_w, 0.05)]
	if not _slabbed.has(key):
		var m := src.duplicate() as ArrayTetraMesh4D
		var verts: PackedVector4Array = m.get_vertex_positions()
		var lo: float = INF
		var hi: float = -INF
		for v in verts:
			lo = minf(lo, v.y)
			hi = maxf(hi, v.y)
		var span: float = maxf(hi - lo, 0.001)
		var base_w: float = 0.0
		for v in verts:
			if v.y <= lo + span * 0.1:
				base_w = maxf(base_w, absf(v.w))
		var k: float = maxf(trunk_w_slab * crown_w / maxf(base_w, 0.001), 1.0)
		for i in verts.size():
			var t: float = (verts[i].y - lo) / span
			var f: float = lerpf(k, 1.0, smoothstep(taper_top * 0.75, taper_top * 1.1, t))
			verts[i] = Vector4(verts[i].x, verts[i].y, verts[i].z, verts[i].w * f)
		m.set_vertex_positions(verts)
		m.calculate_boundary_normals()
		m.set_meta(&"w_slab_of", src.get_instance_id())
		m.set_meta(&"trunk_w_half", base_w * k)
		_slabbed[key] = m
	var made := _slabbed[key] as ArrayTetraMesh4D
	wood.mesh = made
	oak.set_meta(&"trunk_w_half", float(made.get_meta(&"trunk_w_half")) * s.w)
	# The trunk you bump into as deep in W as the slab you see (it was the trunk's width, 0.8 m).
	var body := oak.get("_body") as StaticBody4D
	if body != null and body.get_child_count() > 0:
		var cs := body.get_child(0) as CollisionShape4D
		var box := cs.shape as BoxShape4D if cs != null else null
		if box != null:
			var deeper := box.duplicate() as BoxShape4D
			deeper.size = Vector4(box.size.x, box.size.y, box.size.z, maxf(box.size.w, 2.0 * float(oak.get_meta(&"trunk_w_half"))))
			cs.shape = deeper


# --- One cull pass ----------------------------------------------------------------------------------------

## The plants' cull boxes in packed arrays, once they have stood on the ground (they snap in the first
## physics frames). Static from then on (the wind sways leaves and twigs, not the box).
func _build_cull() -> void:
	for i in 4:
		await get_tree().physics_frame
	_cull_trees.clear()
	_cull_mid.clear()
	_cull_ax.clear()
	_cull_ay.clear()
	_cull_az.clear()
	_cull_aw.clear()
	_cull_r.clear()
	for oak in _oaks:
		var tree: Node4D = oak.get("_tree")
		if tree == null:
			continue
		# The box the plant really fills, in its own frame: its wood (slab trunk and all) and its crown's
		# leaves. The oak's own cull box adds a metre all round for the leaves, and that metre had the layers
		# at 4.5 m counted as cut in the flat slice, their leaves drawn for nothing (GPU 2.7 ms against 1.6).
		var box: Array = _plant_box(oak as Node4D, tree)
		var b: Projection = (oak as Node4D).global_basis
		var centre: Vector4 = ((box[0] as Vector4) + (box[1] as Vector4)) * 0.5
		var half: Vector4 = ((box[1] as Vector4) - (box[0] as Vector4)) * 0.5
		_cull_trees.append(tree)
		_cull_mid.append((oak as Node4D).global_position + b * centre)
		_cull_ax.append(b.x * half.x)
		_cull_ay.append(b.y * half.y)
		_cull_az.append(b.z * half.z)
		_cull_aw.append(b.w * half.w)
		_cull_r.append((b * half).length())
	_cull_on.resize(_cull_trees.size())
	_cull_on.fill(2)
	_cull_ready = true
	_build_solid()


## The copies' trunks, each with the W it spans (its box turned with the copy), for _physics_process.
func _build_solid() -> void:
	_free_solid()
	_solid_near = get_node_or_null(solid_near_path) as Node4D if not solid_near_path.is_empty() else null
	if _solid_near == null:
		return
	for oak in _oaks:
		if not oak.has_meta(&"w_copy"):
			continue
		var body := oak.get("_body") as StaticBody4D
		if body == null or body.get_child_count() == 0:
			continue
		var cs := body.get_child(0) as CollisionShape4D
		var box := cs.shape as BoxShape4D if cs != null else null
		if box == null:
			continue
		var b: Projection = cs.global_basis
		var h: Vector4 = box.size * 0.5
		var reach: float = absf(b.x.w) * h.x + absf(b.y.w) * h.y + absf(b.z.w) * h.z + absf(b.w.w) * h.w
		var w: float = cs.global_position.w
		_solid.append([body, oak, w - reach, w + reach, true])
	solid_in = _solid.size()


func _physics_process(_delta: float) -> void:
	if _solid.is_empty() or _solid_near == null or not is_instance_valid(_solid_near):
		return
	var pw: float = _solid_near.global_position.w
	for rec in _solid:
		var near: bool = pw >= float(rec[2]) - solid_w_margin and pw <= float(rec[3]) + solid_w_margin
		if near == bool(rec[4]) or not is_instance_valid(rec[1]):
			continue
		rec[4] = near
		if near:
			(rec[1] as Node).add_child(rec[0])
			solid_in += 1
		else:
			(rec[1] as Node).remove_child(rec[0])
			solid_in -= 1


## [lo, hi] of the plant's wood and crown, in the plant's frame.
func _plant_box(oak: Node4D, tree: Node4D) -> Array:
	var lo := Vector4(INF, INF, INF, INF)
	var hi := -lo
	var wood := tree.get_node_or_null("Wood") as MeshInstance4D
	if wood != null and wood.mesh != null:
		var r: PackedVector4Array = wood.get_rect_bounds_local()
		for i in 16:
			var corner: Vector4 = r[0] + Vector4(r[1].x * (i & 1), r[1].y * ((i >> 1) & 1), r[1].z * ((i >> 2) & 1), r[1].w * ((i >> 3) & 1))
			var p: Vector4 = tree.position + tree.basis * (wood.position + wood.basis * corner)
			lo = lo.min(p)
			hi = hi.max(p)
	var crown: Array = oak.call("crown_box") if oak.has_method("crown_box") else []
	if crown.size() == 2:
		lo = lo.min(crown[0])
		hi = hi.max(crown[1])
	if lo.x > hi.x:
		var half: Vector4 = oak.get("_half")
		var centre: Vector4 = oak.get("_centre")
		return [centre - half, centre + half]
	return [lo, hi]


func _on_pre_render(camera: Camera4D, viewport: Viewport, engine: RenderingEngine4D) -> void:
	if viewport != get_viewport() or camera == null:
		return
	var started: int = Time.get_ticks_usec()
	if not _cull_ready:
		for oak in _oaks:
			oak.call("cull", camera, viewport, engine)
		cull_usec = Time.get_ticks_usec() - started
		return
	var slice: bool = engine == null or engine.get_friendly_name() == "Cross-section"
	var cb: Projection = camera.global_basis
	var n: Vector4 = cb.w.normalized()
	var cx: Vector4 = cb.x.normalized()
	var cy: Vector4 = cb.y.normalized()
	var cz: Vector4 = cb.z.normalized()
	var e: Vector4 = camera.global_position
	var fov: Variant = camera.get("field_of_view_4d")
	var tv: float = tan(float(fov) * 0.5) if fov != null else 0.8
	var size: Vector2 = viewport.get_visible_rect().size
	var th: float = tv * (size.x / maxf(size.y, 1.0))
	for i in _cull_trees.size():
		var d: Vector4 = _cull_mid[i] - e
		var on: bool = true
		if slice:
			# The plant's reach along the slice's normal, as an ellipsoid in its box (a crown is round; a box's
			# corners, turned in X and W as the copies are, reached half as far again and had copies drawn
			# in the flat slice that showed nothing).
			var ax: float = _cull_ax[i].dot(n)
			var ay: float = _cull_ay[i].dot(n)
			var az: float = _cull_az[i].dot(n)
			var aw: float = _cull_aw[i].dot(n)
			var reach: float = sqrt(ax * ax + ay * ay + az * az + aw * aw)
			on = absf(d.dot(n)) <= reach
		if on:
			var r: float = _cull_r[i]
			var depth: float = -d.dot(cz)
			if depth < -r:
				on = false
			else:
				var slack: float = r * 1.5
				var ahead: float = maxf(depth, 0.0)
				on = absf(d.dot(cx)) <= ahead * th + slack and absf(d.dot(cy)) <= ahead * tv + slack
		var bit: int = 1 if on else 0
		if _cull_on[i] != bit:
			_cull_on[i] = bit
			_cull_trees[i].visible = on
	cull_usec = Time.get_ticks_usec() - started


# --- Where not --------------------------------------------------------------------------------------------

## What stays clear: the paths' stretches and the walls as segments [a, b, clearance], landmarks as circles.
func _keep_outs() -> void:
	_segments.clear()
	_rounds.clear()
	var net: Node = get_node_or_null(paths_path) if not paths_path.is_empty() else null
	var graph: Resource = net.get("graph") if net != null else null
	if graph != null:
		var at: Dictionary = {}
		for nd in graph.get("nodes"):
			var p: Vector4 = nd["pos"]
			at[int(nd["id"])] = Vector2(p.x, p.z)
		for ed in graph.get("edges"):
			var a: Variant = at.get(int(ed["from"]))
			var b: Variant = at.get(int(ed["to"]))
			if a != null and b != null:
				_segments.append([a, b, clear_of_paths])
		for k in at:
			_rounds.append([at[k], clear_of_paths])
	var scan: Node = get_node_or_null(scan_path) if not scan_path.is_empty() else null
	if scan == null:
		return
	for node in scan.find_children("*", "Node4D", true, false):
		if node == self or is_ancestor_of(node):
			continue
		var n4 := node as Node4D
		if n4.has_method("footprint") and n4.get_method_argument_count("footprint") == 0:
			var size: Vector2 = n4.call("footprint")
			_rounds.append([Vector2(n4.global_position.x, n4.global_position.z), size.length() * 0.5 + clear_of_frames])
		elif "from" in n4 and "to" in n4 and "gaps" in n4:
			var b: Projection = n4.global_basis
			var o: Vector4 = n4.global_position
			var f: Vector2 = n4.get("from")
			var t: Vector2 = n4.get("to")
			var fa: Vector4 = o + b * Vector4(f.x, 0.0, f.y, 0.0)
			var ta: Vector4 = o + b * Vector4(t.x, 0.0, t.y, 0.0)
			_segments.append([Vector2(fa.x, fa.z), Vector2(ta.x, ta.z), clear_of_walls])


func _clear(p: Vector2, w: float, scale: float) -> bool:
	if p.distance_to(valley_centre) > valley_radius:
		return false
	for s in _segments:
		if Geometry2D.get_closest_point_to_segment(p, s[0], s[1]).distance_to(p) < float(s[2]) * scale:
			return false
	for r in _rounds:
		if p.distance_to(r[0]) < float(r[1]) * scale:
			return false
	for ex in get_tree().get_nodes_in_group(&"w_exclude"):
		if ex.has_method("excludes") and bool(ex.call("excludes", Vector4(p.x, 0.0, p.y, w))):
			return false
	if _heights != null:
		var i: int = int(floor((p.x + Heights.CELL * Heights.CELLS * 0.5) / Heights.CELL))
		var j: int = int(floor((p.y + Heights.CELL * Heights.CELLS * 0.5) / Heights.CELL))
		var l: int = clampi(int(round((w - Heights.W0) / Heights.DW)), 0, Heights.LAYERS - 1)
		if i >= 0 and j >= 0 and i < Heights.CELLS and j < Heights.CELLS:
			if _heights.get_pixel(i, l * Heights.CELLS + j).r > 0.25:
				return false
	return true
