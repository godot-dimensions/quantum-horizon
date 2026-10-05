extends Node4D
## Slice Garden: a small rock that breaks in exactly two strikes (PLAN.md steps 44-45).
##
## IT IS THE ENGINE'S OWN VOXELS: small VoxelWorld4Ds (dual contouring in C++, cut by the slice like
## any mesh), a lilac-grey crust over a gold core.
##
## THE DENT IS BUILT AT LOAD, NOT CARVED AT THE STRIKE. A sphere edit at strike time costs nothing to
## call (0.5 ms) but the remesh it queues took 80 to 140 ms the next frame (measured 6 Oct,
## scripts/_perf_runner.gd: a visible freeze on every first strike). So each rock is built twice when
## the garden loads, whole and already dented (a notch of air in its generator's layers, on the face you
## come at it from, `dent_face`, deep enough to show the gold), and the first strike swaps one for the
## other. The dented one is NOT hidden while it waits: a hidden mesh has no draw buffers until it is
## first shown, and building them cost the same 110 ms at the strike. It waits drawn, PARKED far below
## the island, so its buffers are built while the garden loads, and the strike only moves it.
##
## TWO STRIKES, CLEARLY. Two small amber pips stand on its top. The first strike shows the dent and the
## gold inside, throws chips, and puts one pip out: it is visibly half broken. The second shatters it (a big burst of chips) and it is gone, collider and
## all. Nothing else can hurt it, and it never heals by itself; `reset()` (R, or a fall) puts it back.
##
## Its collider is one box the size of the rock (physics is boxes only), registered with the
## island's solids so a crate cannot be put down inside it.
##
## The world's type name is never written in code (the sandbox's terrain4d script still claims it in
## the global class cache): ClassDB.instantiate and untyped variables.
##
## NO class_name (engine_gotchas.md).

signal struck(hits: int)
signal broken

const Build := preload("res://ramon/MiegakureLook/Remake/world/mk_build.gd")
const Mats := preload("res://ramon/MiegakureLook/Remake/world/mk_materials.gd")
const Fx := preload("res://ramon/MiegakureLook/Remake/world/mk_fx_4d.gd")

const VOXEL := 0.2
const AIR := 254
const UNDEFINED := 255
const CRUST := Color(0.55, 0.52, 0.66)
const CORE := Color(1.0, 0.74, 0.22)
const PIP_ON := Color(1.0, 0.62, 0.20)
const PIP_OFF := Color(0.30, 0.28, 0.34)
## Where the dented rock waits (drawn, out of sight below the island) until the first strike.
const PARKED := Vector4(0, -300, 0, 0)

## The rock in metres (x, y, z, w), its foot at this node.
@export var size: Vector4 = Vector4(1.6, 1.8, 1.6, 1.2)
@export var hits_needed: int = 2
## The face the dent is on: the way you come at it (a unit axis, from the rock's middle outward).
@export var dent_face: Vector4 = Vector4(0, 0, 1, 0)

var hits: int = 0
var solids: Array = []
var _world
var _dented
var _body: StaticBody4D
var _pips: Array = []


func _ready() -> void:
	add_to_group(&"mk_plug")
	_build()


func is_broken() -> bool:
	return hits >= hits_needed


## The box a strike can land on: [centre, size] in the world.
func bounds() -> Array:
	return [global_position + Vector4(0, size.y * 0.5, 0, 0), size]


func _build() -> void:
	hits = 0
	_world = _make_world("Rock", false)
	_dented = _make_world("RockDented", true)
	_dented.set("position", (_dented.get("position") as Vector4) + PARKED)
	_body = Build.collider(self, "Body", global_position + Vector4(0, size.y * 0.5, 0, 0), size, solids)
	# The pips: two small lamps on its top, as deep in W as the rock so they share its slice.
	_pips.clear()
	for i in hits_needed:
		var x: float = (float(i) - float(hits_needed - 1) * 0.5) * 0.34
		var pip := Build.glow_box(self, "Pip%d" % i, global_position + Vector4(x, size.y + 0.07, 0, 0), Vector4(0.2, 0.14, 0.2, minf(size.w * 0.9, 0.8)), PIP_ON)
		pip.material_override = Mats.glow(PIP_ON, 1.0, 0.6, true)
		_pips.append(pip)


## One voxel world: crust over core, and with `dented` a notch of air on `dent_face`, as layers of the
## generator (no edit, so nothing has to wait for its chunks to load).
func _make_world(world_name: String, dented: bool):
	var world = ClassDB.instantiate("VoxelWorld4D")
	world.name = world_name
	var size_v: Vector4 = size / VOXEL
	var crust = ClassDB.instantiate("BoxVoxelGenerator4D")
	crust.set("size", size_v)
	crust.set("material_inner", 0)
	crust.set("material_outer", AIR)
	var core = ClassDB.instantiate("BoxVoxelGenerator4D")
	core.set("size", size_v - Vector4(3, 3, 3, 2))
	core.set("material_inner", 1)
	core.set("material_outer", UNDEFINED)
	var layers: Array = [crust, core]
	if dented:
		# The notch: as wide as half the face, a third of the height, and deep enough to bite into
		# the core, centred a little above the middle of the face.
		var notch = ClassDB.instantiate("BoxVoxelGenerator4D")
		var across: Vector4 = (Vector4.ONE - dent_face.abs())
		var notch_size: Vector4 = size_v * across * 0.55 + dent_face.abs() * 4.4
		notch_size.y = size_v.y * 0.42
		notch.set("size", notch_size)
		notch.set("center", Vector4(dent_face.x * size_v.x, 0, dent_face.z * size_v.z, dent_face.w * size_v.w) * 0.5 + Vector4(0, size_v.y * 0.08, 0, 0))
		notch.set("material_inner", AIR)
		notch.set("material_outer", UNDEFINED)
		layers.append(notch)
	var layered = ClassDB.instantiate("LayeredVoxelGenerator4D")
	layered.set("layers", layers)
	world.set("generator", layered)
	var pal = ClassDB.instantiate("VoxelMaterialPalette4D")
	pal.set("colors", PackedColorArray([CRUST, CORE]))
	world.set("material_palette", pal)
	world.set("world_bounds_enabled", true)
	var half := Vector4i(ceili(size_v.x * 0.5) + 2, ceili(size_v.y * 0.5) + 2, ceili(size_v.z * 0.5) + 2, ceili(size_v.w * 0.5) + 2)
	world.set("world_bounds_position", -half)
	world.set("world_bounds_size", half * 2)
	world.set("scale", Vector4(VOXEL, VOXEL, VOXEL, VOXEL))
	world.set("position", Vector4(0, size.y * 0.5, 0, 0))
	add_child(world)
	var trigger = ClassDB.instantiate("VoxelLoadTrigger4D")
	trigger.name = "Trigger"
	trigger.set("load_distance", maxf(size_v.x, maxf(size_v.y, size_v.z)) + 8.0)
	world.add_child(trigger)
	trigger.set("voxel_world_path", NodePath(".."))
	return world


## A strike from `from` (the striker's chest), with the view's rotation (for the chips' directions).
## Returns the hits so far.
func strike(from: Vector4, view: Projection) -> int:
	if is_broken() or _world == null:
		return hits
	hits += 1
	var centre: Vector4 = global_position + Vector4(0, size.y * 0.5, 0, 0)
	# The face toward the striker: the axis along which the striker is furthest out, relative to size.
	var d: Vector4 = from - centre
	var rel := Vector4(d.x / size.x, 0.0, d.z / size.z, d.w / size.w)
	var face := Vector4.ZERO
	if absf(rel.x) >= absf(rel.z) and absf(rel.x) >= absf(rel.w):
		face.x = signf(rel.x) * size.x * 0.5
	elif absf(rel.z) >= absf(rel.w):
		face.z = signf(rel.z) * size.z * 0.5
	else:
		face.w = signf(rel.w) * size.w * 0.5
	var hit_at: Vector4 = centre + face + Vector4(0, 0.15, 0, 0)
	if hits < hits_needed:
		# The dented rock was built at load: show it instead of the whole one.
		if _dented != null:
			_dented.set("position", (_dented.get("position") as Vector4) - PARKED)
			_world.set("position", (_world.get("position") as Vector4) + PARKED)
		Fx.chips(get_parent(), hit_at, CRUST, view, 9, 0.11, 3.0)
		Fx.chips(get_parent(), hit_at, CORE, view, 4, 0.08, 2.6)
		var pip: MeshInstance4D = _pips[hits_needed - hits]
		pip.material_override = Mats.glow(PIP_OFF)
		struck.emit(hits)
	else:
		Fx.chips(get_parent(), centre, CRUST, view, 22, 0.16, 4.2, 1.0)
		Fx.chips(get_parent(), centre, CORE, view, 10, 0.12, 3.6, 1.0)
		_world.queue_free()
		_world = null
		if _dented != null:
			_dented.queue_free()
			_dented = null
		_body.queue_free()
		_body = null
		solids.clear()
		for p in _pips:
			(p as Node).queue_free()
		_pips.clear()
		struck.emit(hits)
		broken.emit()
	return hits


## Whole again (R, or the island's reset).
func reset() -> void:
	for c in get_children():
		c.queue_free()
	_world = null
	_dented = null
	_body = null
	solids.clear()
	_build.call_deferred()
