extends Node4D

## WATER LAB: the sea's school of sardines, a fish murmuration (Ramon, 9 Oct: "create schools of fish like
## the pen's starling murmuration"). The pen's flock itself, carried (carried/flock/school_flock_4d.gd),
## a sardine mesh and shader (school_fish.gdshader) in place of the starling's.
##
## WHY SARDINES (the research in follow_up/water_lab.md): the classic bait-ball fish, 15 to 20 cm, a
## clear look from a pier (blue-green back, silver flanks, a row of spots), schooling a body length
## apart; driven up toward the surface by predators, the school balls up, splits round an attacker
## (the fountain effect) and flashes as the fish roll.
##
## THE FLOCK AT A FIFTH OF ITS SIZE. The flock's rules are tuned in starling metres (seven neighbours,
## a couple of metres apart, ten metres a second). This node scales the flock node by 0.2: the same
## rules, unchanged, then make a school of fish 20 cm long, a body length or so apart, at two metres a
## second, in a ball a few metres across. Its roost is under the water off pier 1; its height band
## 1 to 4 m down (deeper, the water swallowed them: 9 Oct).
##
## THE PLESIOSAUR IS ITS HAWK: the flock's piloted hawk (pilot_hawk, fly_hawk), undrawn, flown each
## frame at the plesiosaur's head. Fish near it flee and roll, the roll runs through the school as a
## wave, the silver flanks flash.
##
## NO class_name (engine_gotchas.md).

const Flock := preload("res://ramon/WaterLab/carried/flock/school_flock_4d.gd")
const SHADER := preload("res://ramon/WaterLab/seascape/school_fish.gdshader")
const SCALE := 0.2

@export var count: int = 3000
## The plesiosaur (its body node), whose head is the school's hunter.
var hunter: Node4D = null
var flock: Node4D


func _ready() -> void:
	flock = Node4D.new()
	flock.name = "Flock"
	flock.set_script(Flock)
	flock.set("body_mesh", _fish_mesh())
	flock.set("body_shader", SHADER)
	flock.set("hawk_drawn", false)
	flock.set("hawk_enabled", false)
	flock.set("count", count)
	# In the flock's own (starling) units: a fifth of each in the world.
	flock.set("bird_scale", 1.0)
	flock.set("bird_w_radius", 1.0)
	flock.set("cruise_speed", 8.0)
	flock.set("min_speed", 5.0)
	flock.set("max_speed", 16.0)
	flock.set("roost", Vector4(0.0, 0.0, 0.0, 0.0))
	flock.set("roost_radius", 22.0)
	flock.set("height_low", -20.0)
	flock.set("height_high", -5.0)
	flock.set("altitude_pull", 0.12)
	flock.set("w_half_depth", 1.2)
	flock.set("scare_radius", 30.0)
	flock.basis = Projection(Vector4(SCALE, 0, 0, 0), Vector4(0, SCALE, 0, 0), Vector4(0, 0, SCALE, 0), Vector4(0, 0, 0, SCALE))
	add_child(flock)
	flock.call("pilot_hawk", true)


func _process(_delta: float) -> void:
	if hunter == null or not is_instance_valid(hunter) or flock == null:
		return
	var ahead: Vector4 = (hunter.global_basis * Vector4(0, 0, 1, 0)).normalized()
	var head: Vector4 = hunter.global_position + ahead * 6.0
	flock.call("fly_hawk", head, ahead, 1.5, 0.0, 0.0)


## A sardine, about 1.2 flock units long (24 cm in the world), +Z ahead: a slim body of rings, a forked
## tail, a little dorsal fin. UV.x how far back (the tail's swing), UV.y how high round the body.
static func _fish_mesh() -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var L: float = 1.0
	var rings: int = 12
	var sides: int = 8
	var ring_start: Array = []
	for k in rings:
		var s: float = float(k) / float(rings - 1)
		var z: float = (0.5 - s) * L
		var r: float = 0.11 * L * pow(sin(PI * clampf(s * 0.92 + 0.04, 0.0, 1.0)), 0.7)
		ring_start.append(verts.size())
		for j in sides:
			var a: float = TAU * float(j) / float(sides)
			var dir := Vector3(cos(a) * 0.62, sin(a), 0.0)
			verts.append(Vector3(dir.x * r, dir.y * r, z))
			normals.append(Vector3(cos(a) * 0.62, sin(a), 0.0).normalized())
			uvs.append(Vector2(s * 0.85, sin(a)))
	for k in rings - 1:
		var r0: int = ring_start[k]
		var r1: int = ring_start[k + 1]
		for j in sides:
			var j1: int = (j + 1) % sides
			idx.append_array([r0 + j, r0 + j1, r1 + j1, r0 + j, r1 + j1, r1 + j])
	# Caps.
	for end in [0, rings - 1]:
		var c: int = verts.size()
		var z2: float = (0.5 - float(end) / float(rings - 1)) * L
		verts.append(Vector3(0.0, 0.0, z2 + (0.02 if end == 0 else -0.01)))
		normals.append(Vector3(0, 0, 1 if end == 0 else -1))
		uvs.append(Vector2(0.0 if end == 0 else 0.85, 0.0))
		var r2: int = ring_start[end]
		for j in sides:
			var j1: int = (j + 1) % sides
			if end == 0:
				idx.append_array([c, r2 + j1, r2 + j])
			else:
				idx.append_array([c, r2 + j, r2 + j1])
	# The forked tail and the dorsal fin, flat.
	var tail_root: float = -0.5 * L + 0.02
	var fins: Array = [
		[Vector3(0.0, 0.0, tail_root), Vector3(0.0, 0.16, tail_root - 0.22), Vector3(0.0, 0.02, tail_root - 0.12), 1.0],
		[Vector3(0.0, 0.0, tail_root), Vector3(0.0, 0.02, tail_root - 0.12), Vector3(0.0, -0.15, tail_root - 0.21), 1.0],
		[Vector3(0.0, 0.08, 0.05), Vector3(0.0, 0.16, -0.02), Vector3(0.0, 0.08, -0.12), 0.45],
	]
	for f in fins:
		for p in [f[0], f[1], f[2]]:
			verts.append(p)
			normals.append(Vector3(1, 0, 0))
			var back: float = clampf(0.5 - (p as Vector3).z / L, 0.0, 1.0)
			uvs.append(Vector2(back if float(f[3]) > 0.9 else 0.45, 0.6))
		idx.append_array([verts.size() - 3, verts.size() - 2, verts.size() - 1])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var col := PackedColorArray()
	col.resize(verts.size())
	col.fill(Color.WHITE)
	arrays[Mesh.ARRAY_COLOR] = col
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.custom_aabb = AABB(Vector3(-5000, -5000, -5000), Vector3(10000, 10000, 10000))
	return mesh
