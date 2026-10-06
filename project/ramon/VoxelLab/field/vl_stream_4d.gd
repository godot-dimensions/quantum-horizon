extends Node4D

## The Voxel Lab's field: one of Andrew's landscapes generated round a moving point, as far as a radius
## (Ramon, 6 Oct: "maybe we can explore seeing an open world option").
##
## THE ENGINE DOES the loading: a VoxelLoadTrigger4D on the survey camera keeps the chunks within its
## radius loaded, generating new ones on worker threads and letting far ones go, and the world meshes
## each new chunk on the main thread (16 a frame). What it does not do is build a new chunk's draw
## buffers off the main thread: that happens the first frame the chunk is on screen, and flying into
## new ground means many such frames.
##
## THIS ADDS THE SWAP, for streaming (`swap`): every new chunk mesh is hidden the moment it appears,
## handed to a worker thread to have its draw buffers built, and shown when they are ready, a batch at a
## time. With it off, the engine's own way, the stutter can be seen and measured.
##
## The world is bounded to a band of W and of height (`w_chunks`, `y_range`): the landscape is the same
## everywhere ana and kata, and a 4D ball of chunks round the camera, unbounded, grows as the fourth
## power of the radius (the first look at Andrew's scene: 2,085 chunk meshes in 20 s at 48 voxels).
##
## NO class_name (engine_gotchas.md).

const Recipe := preload("res://ramon/VoxelLab/specimen/vl_recipe.gd")

## The voxel size (m): Andrew's own scale.
@export var voxel: float = 1.0
## How far round the camera chunks load (voxels).
@export var radius: float = 40.0:
	set(v):
		radius = v
		if _trigger != null:
			_trigger.set("load_distance", radius)
## How many chunks deep through W the world goes either side of W 0, and its height band (voxels).
@export var w_chunks: int = 1
@export var y_range: Vector2i = Vector2i(-16, 16)
## Build new chunks' draw buffers on a worker thread before showing them.
@export var swap: bool = true
@export var seed: int = 2

var world
var _trigger
var follow: Node4D
## Chunk meshes waiting to be drawable: [MeshInstance4D, ...]; the batch on a worker now.
var _waiting: Array = []
var _batch: Array = []
var _task: int = -1
var _task_start: int = 0
## Measured: per batch [count, ms], and the frame times.
var batches: Array = []
var shown_total: int = 0
var _tets_of: Dictionary = {}
## Chunks a crater hid behind stand-ins: node instance id -> [node, old mesh, stand-in, frames waited].
var _held: Dictionary = {}


func _ready() -> void:
	world = ClassDB.instantiate("VoxelWorld4D")
	world.name = "Landscape"
	world.set("generator", _generator())
	var pal = ClassDB.instantiate("VoxelMaterialPalette4D")
	pal.set("colors", PackedColorArray([Color(0.40, 0.74, 0.22), Color(0.56, 0.32, 0.12), Color(0.34, 0.34, 0.34), Color(0.25, 0.47, 1.0)]))
	world.set("material_palette", pal)
	var k: int = Recipe.CHUNK
	world.set("world_bounds_enabled", true)
	world.set("world_bounds_position", Vector4i(-100000, y_range.x, -100000, -k * w_chunks))
	world.set("world_bounds_size", Vector4i(200000, y_range.y - y_range.x, 200000, k * w_chunks * 2))
	world.set("scale", Vector4.ONE * voxel)
	world.set("allow_projection", true)
	world.connect("child_entered_tree", _on_chunk)
	add_child(world)
	_trigger = ClassDB.instantiate("VoxelLoadTrigger4D")
	_trigger.name = "Trigger"
	_trigger.set("load_distance", radius)
	world.add_child(_trigger)
	_trigger.set("voxel_world_path", NodePath(".."))


## Andrew's landscape (project/sandbox/voxel_test.tscn) as he composed it: an ocean plane under the
## landscape clipped against the caves, his numbers.
func _generator():
	var ocean = ClassDB.instantiate("PlaneVoxelGenerator4D")
	ocean.set("material_over", 254)
	ocean.set("material_under", 3)
	var land = ClassDB.instantiate("LandscapeVoxelGenerator4D")
	land.set("seed", seed)
	land.set("intensity", 12.32)
	land.set("materials", PackedInt32Array([2, 1, 0, 255]))
	land.set("material_cutoffs", PackedFloat32Array([-6.0, -1.5, 0.0]))
	var caves = ClassDB.instantiate("CaveVoxelGenerator4D")
	caves.set("seed", 1)
	caves.set("persistence", 0.4)
	caves.set("diameter", 6.18)
	var clipped = ClassDB.instantiate("ClippedVoxelGenerator4D")
	clipped.set("base", land)
	clipped.set("modifier", caves)
	var layered = ClassDB.instantiate("LayeredVoxelGenerator4D")
	layered.set("layers", [ocean, clipped])
	return layered


func _on_chunk(n: Node) -> void:
	if not (n is MeshInstance4D) or n.get_parent() != world:
		return
	if swap:
		(n as MeshInstance4D).visible = false
		_waiting.append(n)
	else:
		shown_total += 1


func _process(_delta: float) -> void:
	if follow != null and _trigger != null:
		# Loaded round the ground under the camera, a little ahead of where it looks: a trigger at the
		# camera itself, 30 m up, reached nothing but air (6 Oct). In voxels (a child of the scaled world).
		var at: Vector4 = follow.global_position
		var ahead: Vector4 = -(follow.global_basis * Vector4(0, 0, 1, 0))
		ahead.y = 0.0
		if ahead.length() > 0.01:
			at += ahead.normalized() * radius * voxel * 0.35
		at.y = 0.0
		_trigger.set("position", at / voxel)
	_check_held()
	if not swap:
		for n in _waiting:
			if is_instance_valid(n):
				(n as MeshInstance4D).visible = true
		_waiting.clear()
		return
	if _task >= 0:
		if not WorkerThreadPool.is_task_completed(_task):
			return
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		var ms: float = float(Time.get_ticks_usec() - _task_start) / 1000.0
		batches.append([_batch.size(), ms])
		if batches.size() > 200:
			batches.remove_at(0)
		for pair in _batch:
			var n: Node = pair[0]
			# Shown only if it still holds the mesh that was made drawable (a chunk meshed again
			# meanwhile goes back in the queue).
			if is_instance_valid(n) and (n as MeshInstance4D).mesh == pair[1]:
				(n as MeshInstance4D).visible = true
				shown_total += 1
				_shown(n)
			elif is_instance_valid(n):
				_waiting.append(n)
		_batch = []
	_waiting = _waiting.filter(func(n: Node) -> bool: return is_instance_valid(n))
	if _waiting.is_empty():
		return
	# A batch of the nearest first: what is in front of you arrives first.
	if follow != null:
		var at: Vector4 = follow.global_position
		_waiting.sort_custom(func(a: Node, b: Node) -> bool:
			return (a as Node4D).global_position.distance_squared_to(at) < (b as Node4D).global_position.distance_squared_to(at))
	var take: int = mini(_waiting.size(), 24)
	_batch = []
	var meshes: Array = []
	for i in take:
		var n: MeshInstance4D = _waiting[i]
		_batch.append([n, n.mesh])
		meshes.append(n.mesh)
	_waiting = _waiting.slice(take)
	_task_start = Time.get_ticks_usec()
	_task = WorkerThreadPool.add_task(_prepare.bind(meshes), false, "voxel field")


static func _prepare(meshes: Array) -> void:
	for m in meshes:
		var mesh: Mesh4D = m
		if mesh == null:
			continue
		mesh.is_mesh_data_valid()
		mesh.get_proxy_mesh_3d()


func _exit_tree() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1


## A crater: a 4D ball of air at `center` (voxels), `r` voxels round. The chunks it touches are hidden
## behind stand-ins of their old meshes until their new ones are drawable (the lab's swap, as for a
## cut), so the ground never blinks.
func crater(center: Vector4, r: float) -> void:
	var lo: Vector4 = center - Vector4.ONE * (r + 2.0)
	var hi: Vector4 = center + Vector4.ONE * (r + 2.0)
	var k: float = float(Recipe.CHUNK)
	for ch in chunk_nodes():
		var at: Vector4 = (ch as Node4D).position
		var inside: bool = true
		for axis in 4:
			if at[axis] + k < lo[axis] or at[axis] > hi[axis]:
				inside = false
		if not inside or not (ch as MeshInstance4D).visible or not swap:
			continue
		var s := MeshInstance4D.new()
		s.name = "StandIn"
		s.mesh = (ch as MeshInstance4D).mesh
		s.position = at
		var holder: Node = world.get_node("StandIns") if world.has_node("StandIns") else _standins_holder()
		holder.add_child(s)
		(ch as MeshInstance4D).visible = false
		_held[ch.get_instance_id()] = [ch, (ch as MeshInstance4D).mesh, s, 0]
	var ed = ClassDB.instantiate("SphereVoxelEdit4D")
	ed.set("center", center)
	ed.set("radius", r)
	ed.set("fill_material", 254)
	world.call("apply_edit", ed)


func _standins_holder() -> Node4D:
	var h := Node4D.new()
	h.name = "StandIns"
	world.add_child(h)
	return h


## Chunks behind stand-ins: a new mesh joins the queue to be made drawable; one that never changes is
## shown again after a while; one the engine let go takes its stand-in with it.
func _check_held() -> void:
	for id in _held.keys():
		var rec: Array = _held[id]
		var n: Node = rec[0]
		if not is_instance_valid(n):
			(rec[2] as Node).queue_free()
			_held.erase(id)
			continue
		rec[3] = int(rec[3]) + 1
		if (n as MeshInstance4D).mesh != rec[1]:
			if not n in _waiting and not _batch.any(func(pair: Array) -> bool: return pair[0] == n):
				_waiting.append(n)
			rec[1] = (n as MeshInstance4D).mesh
		elif int(rec[3]) > 90 and not n in _waiting:
			(n as MeshInstance4D).visible = true
			(rec[2] as Node).queue_free()
			_held.erase(id)


## A chunk was shown: its stand-in, if it had one, goes.
func _shown(n: Node) -> void:
	var id: int = n.get_instance_id()
	if _held.has(id):
		(_held[id][2] as Node).queue_free()
		_held.erase(id)


## The world's chunk meshes (shown or waiting).
func chunk_nodes() -> Array:
	var out: Array = []
	if world == null:
		return out
	for ch in world.get_children():
		if ch is MeshInstance4D and (ch as MeshInstance4D).mesh != null:
			out.append(ch)
	return out


func stats() -> Dictionary:
	var n: int = 0
	var shown: int = 0
	var t: int = 0
	for ch in chunk_nodes():
		n += 1
		var m: Resource = (ch as MeshInstance4D).mesh
		var id: int = m.get_instance_id()
		if not _tets_of.has(id):
			_tets_of[id] = (m as TetraMesh4D).get_simplex_cell_vertex_indices().size() / 4
		t += int(_tets_of[id])
		if (ch as MeshInstance4D).visible:
			shown += 1
	if _tets_of.size() > 6000:
		_tets_of.clear()
	return {"chunks": n, "shown": shown, "waiting": _waiting.size() + _batch.size(), "tets": t, "mb": float(t) * 1.25 / 1024.0}


## For the bench-style tools (a crater from the air): voxels from the world.
func to_voxel(g: Vector4) -> Vector4:
	return (g - global_position) / voxel


func to_global(p: Vector4) -> Vector4:
	return global_position + p * voxel
