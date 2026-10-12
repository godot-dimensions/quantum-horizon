extends Node4D

## The Voxel Lab: one specimen, in the engine's own voxel world (VoxelWorld4D, 4Denthusiast's), cut
## live, with every cost measured.
##
## WHAT THE ENGINE DOES. The world is filled from the recipe's generators on worker threads (a load
## trigger keeps its chunks loaded), and meshed by dual contouring in C++ in chunks of 8 voxels a side,
## up to 16 chunks a frame, on the main thread. A cut is an edit (a 4D ball, box or slab of air): the
## chunks it touches are meshed again the next frame. Each new chunk mesh then needs its draw buffers:
## the renderer turns its tetrahedra into the 3D mesh it really draws, on the frame it is first seen.
## That last step is most of the pause after a cut (Crosswise measured a hidden mesh's first frame at
## 110 ms against 80 to 140 for a whole cut).
##
## WHAT THIS ADDS: THE SWAP (`swap = true`). Before the cut, the chunks it will touch are hidden and a
## stand-in showing each one's old mesh takes its place. The engine meshes them again while hidden (a
## hidden mesh never has its draw buffers built), and when it has, those buffers are built on a worker
## thread (Mesh4D.get_proxy_mesh_3d, the pen's far-room trick). Then all of them are shown at once and
## the stand-ins go. The cut lands a few frames later instead of freezing one. Off, the cut is shown
## the engine's own way, in the frame after.
##
## AND THE BOOKKEEPING: the recipe and every cut in our own copy (vl_recipe.gd), since GDScript cannot
## read the engine's voxels; a record per cut (the call, the worst frame, how long until it showed,
## the worker's time, the chunks, the tetrahedra, the voxels it removed); chunk outlines that flash on
## the chunks a cut remeshed.
##
## THE WORLD'S TYPE NAME IS NEVER WRITTEN: the sandbox's terrain script still claims the class name in
## the global class cache (engine_gotchas.md), so ClassDB.instantiate and untyped variables.
##
## NO class_name (engine_gotchas.md).

signal built(stats: Dictionary)
signal cut_done(record: Dictionary)

const Recipe := preload("res://ramon/VoxelLab/specimen/vl_recipe.gd")
const Cut := preload("res://ramon/VoxelLab/specimen/vl_cut.gd")

## Build the new chunks' draw buffers on a worker thread before showing them (see the header).
var swap: bool = true
## Build hidden and show only when every chunk's draw buffers are ready (a spare, or a specimen built
## while the room is in view): no frame pays for them.
var hidden_build: bool = false
## Give up waiting for a chunk that never changed after this many quiet frames.
var settle_frames: int = 3
## Seconds over which a hidden build's load radius grows to its full reach.
var stagger: float = 3.0
var _full_reach: float = 0.0
## Specimens with a cut on its way to the screen, room-wide. While any has one, every hidden build
## (a spare, a rebuild) stops its world: the engine meshes on the main thread, and a spare meshing in
## the frames of a cut made the first cut after a story's reset cost 126 ms (6 Oct).
static var _cutting: Dictionary = {}
## Runners set this to have every slow frame during a cut explained in the log.
static var debug_spikes: bool = false

var recipe: Dictionary = {}
var voxel: float = 0.1
var world
var cuts: Array = []
var records: Array = []
## "idle", "loading", "meshing", "proxies", "ready"
var phase: String = "idle"
var stats: Dictionary = {}

var _trigger
var _standins: Node4D
var _probe: Array = []
var _t0: int = 0
var _frames: int = 0
## Frames a hidden build stood still for a cut elsewhere in the room.
var _held_frames: int = 0
var _stable: int = 0
var _last_tets: int = -1
var _last_us: int = 0
var _frame_ms: float = 0.0
var _tets_of: Dictionary = {}
## The swap in flight: {keys: {key: true}, old: {key: mesh}, changed: {key: node}, quiet: frames,
## task: id, meshes: [...], prepared: {key: mesh}, record: {...}, worst: ms, start: usec}
var _pending: Dictionary = {}
var _queued_records: Array = []
var _flash: Array = []
var _build_record: Dictionary = {}
## A material every chunk wears instead of the world's own (the grid view), or null.
var chunk_material: Material4D = null


func _ready() -> void:
	_standins = Node4D.new()
	_standins.name = "StandIns"


## Builds the world from `r` (vl_recipe.gd). `built` fires when every chunk is meshed (and, with
## hidden_build, drawable).
func build(r: Dictionary) -> void:
	_free_world()
	recipe = r
	voxel = float(r["voxel"])
	cuts = []
	records = []
	var c: Vector4 = r["center"]
	world = ClassDB.instantiate("VoxelWorld4D")
	world.name = "World"
	world.set("generator", Recipe.generator(r))
	world.set("material_palette", Recipe.palette(r, r.get("colors", Recipe.COLORS)))
	var b: Array = Recipe.bounds(r)
	world.set("world_bounds_enabled", true)
	world.set("world_bounds_position", b[0])
	world.set("world_bounds_size", b[1])
	world.set("scale", Vector4.ONE * voxel)
	world.set("position", -c * voxel)
	world.connect("child_entered_tree", _on_chunk_added)
	add_child(world)
	if _standins.get_parent() != null:
		_standins.get_parent().remove_child(_standins)
	world.add_child(_standins)
	_trigger = ClassDB.instantiate("VoxelLoadTrigger4D")
	_trigger.name = "Trigger"
	_trigger.set("position", c)
	var size: Vector4i = b[1]
	_full_reach = Vector4(size).length() * 0.5 + 10.0
	# A specimen built hidden (a spare, a rebuild) loads its chunks a few at a time: its load radius grows
	# from its middle over `stagger` seconds. Loaded all at once, the engine meshed 16 of its chunks a
	# frame on the main thread and the frames after a reset ran to 120 ms (6 Oct).
	_trigger.set("load_distance", 4.0 if (hidden_build and stagger > 0.0) else _full_reach)
	world.add_child(_trigger)
	_trigger.set("voxel_world_path", NodePath(".."))
	var lo: Vector4i = b[0]
	var hi: Vector4i = lo + size - Vector4i.ONE
	_probe = [lo, hi, Vector4i(c.floor()), Vector4i(lo.x, hi.y, lo.z, hi.w), Vector4i(hi.x, lo.y, hi.z, lo.w), Vector4i(lo.x, lo.y, hi.z, hi.w)]
	phase = "loading"
	_t0 = Time.get_ticks_usec()
	_frames = 0
	_stable = 0
	_last_tets = -1
	_tets_of = {}
	_pending = {}
	_build_record = {}


func _free_world() -> void:
	if world != null and is_instance_valid(world):
		if _standins.get_parent() == world:
			world.remove_child(_standins)
		world.queue_free()
	world = null
	for s in _standins.get_children():
		s.queue_free()
	phase = "idle"


func _exit_tree() -> void:
	_cutting.erase(get_instance_id())
	# A worker task never waited on keeps its meshes past the renderer's exit (a spare still building
	# when the scene closed leaked 107 of them, 6 Oct).
	for k in ["task", "build_task"]:
		if not _pending.is_empty() and int(_pending.get(k, -1)) >= 0:
			WorkerThreadPool.wait_for_task_completion(int(_pending[k]))
			_pending[k] = -1
	if _standins != null and _standins.get_parent() == null:
		_standins.free()


func is_ready() -> bool:
	return phase == "ready"


func busy() -> bool:
	return not _pending.is_empty()


# -- coordinates ---------------------------------------------------------------------------------------

## A point in the world to the specimen's voxel coordinates.
func to_voxel(g: Vector4) -> Vector4:
	var local: Vector4 = global_basis.inverse() * (g - global_position)
	return local / voxel + (recipe["center"] as Vector4)


## A direction in the world to the specimen's voxel coordinates (not normalised).
func dir_to_voxel(d: Vector4) -> Vector4:
	return (global_basis.inverse() * d) / voxel


## A point in the specimen's voxel coordinates to the world.
func to_global(p: Vector4) -> Vector4:
	return global_position + global_basis * ((p - (recipe["center"] as Vector4)) * voxel)


## A direction in voxel coordinates to the world (not normalised).
func dir_to_global(d: Vector4) -> Vector4:
	return global_basis * (d * voxel)


# -- the chunks ----------------------------------------------------------------------------------------

## The engine's chunk meshes (the world's own MeshInstance4D children, not our stand-ins).
func chunk_nodes() -> Array:
	var out: Array = []
	if world == null:
		return out
	for ch in world.get_children():
		if ch is MeshInstance4D and (ch as MeshInstance4D).mesh != null:
			out.append(ch)
	return out


static func _key_of(n: Node4D) -> Vector4i:
	return Vector4i(roundi(n.position.x), roundi(n.position.y), roundi(n.position.z), roundi(n.position.w))


## The chunks (their lowest corners, voxels) a region touches: the engine remeshes the chunks
## overlapping the change grown by one voxel; this grows it by two to be safe.
static func chunk_keys(lo: Vector4, hi: Vector4) -> Array:
	var out: Array = []
	var a := Vector4i((lo - Vector4.ONE * 2.0).floor())
	var b := Vector4i((hi + Vector4.ONE * 2.0).floor())
	var k: int = Recipe.CHUNK
	for w in range(_down(a.w, k), b.w + 1, k):
		for z in range(_down(a.z, k), b.z + 1, k):
			for y in range(_down(a.y, k), b.y + 1, k):
				for x in range(_down(a.x, k), b.x + 1, k):
					out.append(Vector4i(x, y, z, w))
	return out


static func _down(v: int, k: int) -> int:
	return v - posmod(v, k)


func tets() -> int:
	var n: int = 0
	for ch in chunk_nodes():
		n += _tets(ch.mesh)
	return n


func _tets(m: Resource) -> int:
	var id: int = m.get_instance_id()
	if not _tets_of.has(id):
		_tets_of[id] = (m as TetraMesh4D).get_simplex_cell_vertex_indices().size() / 4
	return int(_tets_of[id])


## Every chunk (and every chunk made later) wears `m` instead of the world's own material; null puts
## the world's back (the grid view, room/vl_grid_view.gd).
func set_chunk_material(m: Material4D) -> void:
	if m == chunk_material:
		return
	chunk_material = m
	for ch in chunk_nodes():
		(ch as MeshInstance4D).material_override = m
	for s in _standins.get_children():
		(s as MeshInstance4D).material_override = m


func _on_chunk_added(n: Node) -> void:
	if not (n is MeshInstance4D) or n.get_parent() != world:
		return
	if chunk_material != null:
		(n as MeshInstance4D).material_override = chunk_material
	# A chunk that had no surface before (a solid or empty block of voxels) gets its first mesh:
	# hidden like the rest while a swap is on, or while a hidden build is under way.
	if (not _pending.is_empty()) or (hidden_build and phase != "ready"):
		(n as MeshInstance4D).visible = false
		if not _pending.is_empty():
			(_pending["keys"] as Dictionary)[_key_of(n)] = true


# -- cutting -------------------------------------------------------------------------------------------

## Cuts `cut` (vl_cut.gd) into the specimen. Returns the record so far; `cut_done` carries the whole
## record once the cut is on screen.
func apply_cut(cut: Dictionary) -> Dictionary:
	if world == null or phase != "ready":
		return {}
	var rec: Dictionary = {"label": String(cut.get("label", cut["kind"])), "kind": String(cut["kind"]), "swap": swap, "fill": int(cut.get("fill", Cut.AIR))}
	var t_count: int = Time.get_ticks_usec()
	# Our copy can only count what it can follow: a recipe built from noise (Andrew's landscape and
	# caves) says "mirror": false, and its cuts count no voxels.
	# A cut that knows its own count (Build it's bricks: a whole cell each) says so.
	if cut.has("voxels"):
		rec["voxels"] = int(cut["voxels"])
	else:
		rec["voxels"] = Recipe.voxels_removed(recipe, cuts, cut) if bool(recipe.get("mirror", true)) else -1
	rec["count_ms"] = float(Time.get_ticks_usec() - t_count) / 1000.0
	var b: Array = cut["aabb"]
	var keys: Array = chunk_keys(b[0], b[1])
	rec["chunks_touched"] = keys.size()
	if swap:
		_hide_for(keys)
	var t: int = Time.get_ticks_usec()
	for ed in Cut.engine_edits(cut):
		world.call("apply_edit", ed)
	rec["call_ms"] = float(Time.get_ticks_usec() - t) / 1000.0
	cuts.append(cut)
	_cutting[get_instance_id()] = true
	rec["start"] = Time.get_ticks_usec()
	rec["worst_ms"] = 0.0
	rec["frames"] = 0
	if swap:
		var p: Dictionary = _pending
		var list: Array = p.get("records", [])
		list.append(rec)
		p["records"] = list
		p["quiet"] = 0
	else:
		_queued_records.append(rec)
	return rec


## Hides the chunks a cut will touch behind stand-ins showing their old meshes.
func _hide_for(keys: Array) -> void:
	if _pending.is_empty():
		_pending = {"keys": {}, "old": {}, "records": [], "quiet": 0, "task": -1, "ready": {}}
	var want: Dictionary = {}
	for k in keys:
		want[k] = true
	var old: Dictionary = _pending["old"]
	for ch in chunk_nodes():
		var key: Vector4i = _key_of(ch)
		if not want.has(key):
			continue
		(_pending["keys"] as Dictionary)[key] = true
		if old.has(key):
			continue   # already standing in from an earlier cut in this swap
		old[key] = ch.mesh
		if (ch as MeshInstance4D).visible:
			var s := MeshInstance4D.new()
			s.name = "StandIn"
			s.mesh = ch.mesh
			s.material_override = (ch as MeshInstance4D).material_override
			s.position = ch.position
			s.set_meta("key", key)
			_standins.add_child(s)
		(ch as MeshInstance4D).visible = false


func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_usec()
	_frame_ms = float(now - _last_us) / 1000.0 if _last_us > 0 else 0.0
	_last_us = now
	if world == null:
		return
	_frames += 1
	if phase == "ready":
		if _pending.is_empty() and _queued_records.is_empty():
			_cutting.erase(get_instance_id())
	elif hidden_build and (phase == "loading" or phase == "meshing" or phase == "proxies"):
		var hold: bool = not _cutting.is_empty()
		if world.is_processing() == hold:
			world.set_process(not hold)
		if hold:
			_held_frames += 1
			return
		if _frames > 2:
			_build_record["worst_frame_ms"] = maxf(float(_build_record.get("worst_frame_ms", 0.0)), _frame_ms)
	match phase:
		"loading":
			_wait_loaded()
		"meshing":
			_wait_meshed()
		"proxies":
			_wait_proxies()
		"ready":
			_track_cuts()
	_fade_flash(_delta)


func _wait_loaded() -> void:
	if hidden_build and stagger > 0.0 and _trigger != null:
		var k: float = clampf(float(Time.get_ticks_usec() - _t0) / 1000000.0 / stagger, 0.0, 1.0)
		_trigger.set("load_distance", lerpf(4.0, _full_reach, k))
	var data = world.call("get_voxel_data")
	for c in _probe:
		if not bool(data.call("is_voxel_defined", c)):
			return
	_build_record["load_ms"] = float(Time.get_ticks_usec() - _t0) / 1000.0
	var t: int = Time.get_ticks_usec()
	for e in Recipe.recipe_edits(recipe):
		var ed = ClassDB.instantiate("SphereVoxelEdit4D")
		ed.set("center", e[0])
		ed.set("radius", float(e[1]))
		ed.set("fill_material", int(e[2]))
		world.call("apply_edit", ed)
	# Cuts the recipe arrives with (the shelf's pre-cut specimens): made now, while it loads, and kept
	# in our copy so aiming and counting see them.
	for cut in recipe.get("pre_cuts", []):
		for ed in Cut.engine_edits(cut):
			world.call("apply_edit", ed)
		cuts.append(cut)
	_build_record["recipe_edit_ms"] = float(Time.get_ticks_usec() - t) / 1000.0
	phase = "meshing"
	_t0 = Time.get_ticks_usec()
	_stable = 0
	_last_tets = -1


func _wait_meshed() -> void:
	var n: int = tets()
	_stable = _stable + 1 if (n == _last_tets and n > 0) else 0
	_last_tets = n
	if _stable < 4:
		return
	_build_record["mesh_ms"] = float(Time.get_ticks_usec() - _t0) / 1000.0
	if hidden_build:
		var meshes: Array = []
		for ch in chunk_nodes():
			meshes.append(ch.mesh)
		_t0 = Time.get_ticks_usec()
		_pending = {"build_task": WorkerThreadPool.add_task(_prepare.bind(meshes), false, "voxel lab spare"), "meshes": meshes}
		phase = "proxies"
	else:
		_finish_build()


func _wait_proxies() -> void:
	var task: int = int(_pending.get("build_task", -1))
	if task >= 0 and not WorkerThreadPool.is_task_completed(task):
		return
	if task >= 0:
		WorkerThreadPool.wait_for_task_completion(task)
		# A task's id is spent once it has been waited for (asking again is an engine error).
		_pending["build_task"] = -1
	if not _pending.has("proxy_ms"):
		_pending["proxy_ms"] = float(Time.get_ticks_usec() - _t0) / 1000.0
	# Shown a few chunks a frame: even with their draw buffers built, a whole specimen's worth handed to
	# the GPU in one frame cost 127 ms (the first room, 6 Oct).
	var shown: int = 0
	for ch in chunk_nodes():
		if not (ch as MeshInstance4D).visible:
			(ch as MeshInstance4D).visible = true
			shown += 1
			if shown >= 12:
				return
	_build_record["proxy_ms"] = float(_pending.get("proxy_ms", 0.0))
	_pending = {}
	_finish_build()


func _finish_build() -> void:
	phase = "ready"
	stats = _build_record.duplicate()
	stats["chunks"] = chunk_nodes().size()
	stats["tets"] = tets()
	stats["mb"] = float(stats["tets"]) * 1.25 / 1024.0
	built.emit(stats)


## On a worker thread: makes each mesh drawable (validated, its draw buffers built).
static func _prepare(meshes: Array) -> void:
	for m in meshes:
		var mesh: Mesh4D = m
		if mesh == null:
			continue
		mesh.is_mesh_data_valid()
		mesh.get_proxy_mesh_3d()


func _track_cuts() -> void:
	# Records of cuts shown the engine's way (no swap): the frame after is the cost.
	for rec in _queued_records:
		rec["frames"] = int(rec["frames"]) + 1
		rec["worst_ms"] = maxf(float(rec["worst_ms"]), _frame_ms)
	while not _queued_records.is_empty() and int(_queued_records[0]["frames"]) >= 4:
		var rec: Dictionary = _queued_records.pop_front()
		_close(rec, [])
	if _pending.is_empty():
		return
	for rec in _pending["records"]:
		rec["frames"] = int(rec["frames"]) + 1
		rec["worst_ms"] = maxf(float(rec["worst_ms"]), _frame_ms)
	if debug_spikes and _frame_ms > 60.0:
		print("VL spike %.0f ms on %s: swap keys %d, task %d, quiet %d, frames into the cut %d, stand-ins %d" % [_frame_ms, String(get_parent().get_parent().name if get_parent() != null and get_parent().get_parent() != null else name),
			(_pending.get("keys", {}) as Dictionary).size(), int(_pending.get("task", -1)), int(_pending.get("quiet", 0)),
			int((_pending["records"] as Array)[-1]["frames"]) if not (_pending["records"] as Array).is_empty() else -1, _standins.get_child_count()])
	var ready_set: Dictionary = _pending["ready"]
	var task: int = int(_pending.get("task", -1))
	if task >= 0:
		if not WorkerThreadPool.is_task_completed(task):
			return
		WorkerThreadPool.wait_for_task_completion(task)
		_pending["task"] = -1
		_pending["worker_ms"] = float(_pending.get("worker_ms", 0.0)) + float(Time.get_ticks_usec() - int(_pending["task_start"])) / 1000.0
		for m in _pending["task_meshes"]:
			ready_set[(m as Object).get_instance_id()] = true
	# Waiting for the engine to mesh the hidden chunks. A chunk may be shown only with its old mesh
	# (drawable already) or a new mesh whose draw buffers a worker has built: anything else would be
	# built on this thread the frame it shows. Cuts made meanwhile join this swap, so the state is
	# read afresh each frame, and only shown after `settle_frames` frames with nothing changing.
	var old: Dictionary = _pending["old"]
	var by_key: Dictionary = {}
	for ch in chunk_nodes():
		by_key[_key_of(ch)] = ch
	var sig: Array = []
	var unprepared: Array = []
	var still_old: bool = false
	for key in (_pending["keys"] as Dictionary):
		var ch: Node = by_key.get(key)
		var m: Resource = ch.mesh if ch != null else null
		sig.append(m.get_instance_id() if m != null else 0)
		if m == null:
			continue
		if m == old.get(key):
			still_old = true
			continue
		if not ready_set.has(m.get_instance_id()):
			unprepared.append(m)
	var s: String = str(sig)
	if s != String(_pending.get("sig", "")):
		_pending["sig"] = s
		_pending["quiet"] = 0
	else:
		_pending["quiet"] = int(_pending["quiet"]) + 1
	var q: int = int(_pending["quiet"])
	if q < settle_frames or (still_old and q < settle_frames * 3):
		return
	if not unprepared.is_empty():
		if not _pending.has("mesh_frames") and not (_pending["records"] as Array).is_empty():
			_pending["mesh_frames"] = int((_pending["records"] as Array)[-1]["frames"])
		_pending["task_meshes"] = unprepared
		_pending["task_start"] = Time.get_ticks_usec()
		_pending["task"] = WorkerThreadPool.add_task(_prepare.bind(unprepared), false, "voxel lab cut")
		return
	_show_all(by_key)


## Shows every chunk of the swap (their draw buffers are ready) and lets the stand-ins go, in one
## frame.
func _show_all(by_key: Dictionary) -> void:
	var old: Dictionary = _pending["old"]
	var flashed: Array = []
	for key in (_pending["keys"] as Dictionary):
		var ch: Node = by_key.get(key)
		if ch == null:
			continue
		(ch as MeshInstance4D).visible = true
		if ch.mesh != old.get(key):
			flashed.append(key)
	for st in _standins.get_children():
		st.queue_free()
	var p: Dictionary = _pending
	_pending = {}
	for rec in p["records"]:
		rec["worker_ms"] = float(p.get("worker_ms", 0.0))
		rec["mesh_frames"] = int(p.get("mesh_frames", 0))
		_close(rec, flashed)


func _close(rec: Dictionary, flashed: Array) -> void:
	rec["latency_ms"] = float(Time.get_ticks_usec() - int(rec["start"])) / 1000.0
	rec["chunks"] = flashed.size() if swap else int(rec.get("chunks_touched", 0))
	rec["tets"] = tets()
	records.append(rec)
	if not flashed.is_empty():
		flash(flashed)
	cut_done.emit(rec)


# -- the chunk flash -----------------------------------------------------------------------------------

## Outlines the chunks at `keys` for a moment (the chunk view): the engine's 8-voxel blocks that a cut
## made it mesh again. Set `flash_on` false to skip.
var flash_on: bool = false
var flash_color: Color = Color(0.25, 0.75, 1.0)


func flash(keys: Array) -> void:
	if not flash_on or world == null:
		return
	# Our own nodes never hang straight off the world: its direct MeshInstance4D children are its chunks.
	var holder: Node4D = world.get_node_or_null("Flashes")
	if holder == null:
		holder = Node4D.new()
		holder.name = "Flashes"
		world.add_child(holder)
	if _flash_mat == null:
		_flash_mat = TetraMaterial4D.new()
		_flash_mat.albedo_color = flash_color
	for key in keys:
		if holder.get_child_count() > 48:
			break
		var box := MeshInstance4D.new()
		box.name = "Flash"
		# One outline mesh for every flash: drawable after the first, so a burst of cuts costs nothing
		# (60 quick cuts with a new mesh each built 1,600 of them and froze 2.5 s, 6 Oct).
		box.mesh = _chunk_outline()
		box.position = Vector4(key) + Vector4.ONE * float(Recipe.CHUNK) * 0.5
		box.material_override = _flash_mat
		holder.add_child(box)
		_flash.append([box, 0.9])


static var _outline_cache: ArrayTetraMesh4D
var _flash_mat: TetraMaterial4D


static func _chunk_outline() -> ArrayTetraMesh4D:
	if _outline_cache == null:
		_outline_cache = _frame_mesh(Vector4.ONE * float(Recipe.CHUNK), 0.12)
	return _outline_cache


func _fade_flash(delta: float) -> void:
	for i in range(_flash.size() - 1, -1, -1):
		_flash[i][1] = float(_flash[i][1]) - delta
		if float(_flash[i][1]) <= 0.0:
			(_flash[i][0] as Node).queue_free()
			_flash.remove_at(i)


## The twelve edges of a cube `size` across (x, y, z), as deep in W as the cube, `bar` thick: the
## outline of a chunk in every slice that crosses it.
static func _frame_mesh(size: Vector4, bar: float) -> ArrayTetraMesh4D:
	var out := ArrayTetraMesh4D.new()
	var h: Vector4 = size * 0.5
	var bars: Array = []
	for sy in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			bars.append([Vector4(0, sy * h.y, sz * h.z, 0), Vector4(size.x + bar, bar, bar, size.w)])
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			bars.append([Vector4(sx * h.x, 0, sz * h.z, 0), Vector4(bar, size.y, bar, size.w)])
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			bars.append([Vector4(sx * h.x, sy * h.y, 0, 0), Vector4(bar, bar, size.z, size.w)])
	for b in bars:
		var box := BoxTetraMesh4D.new()
		box.size = b[1]
		var piece: ArrayTetraMesh4D = box.to_array_tetra_mesh()
		out.merge_with(piece, b[0])
	return out
