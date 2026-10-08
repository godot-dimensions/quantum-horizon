extends SceneTree

## What does the plesiosaur actually look like, from the side, above, ahead, and turned?
##
##   godot --path project --rendering-method forward_plus --resolution 1100x620 \
##       --script res://sandbox/water4d/_capture_plesiosaur_runner.gd
##
## `_probe_plesiosaur_runner.gd` proves the numbers landed on the axes they were meant to.
## It cannot tell me the animal reads as a plesiosaur rather than as a sausage with lumps,
## and that is a judgement a picture settles in one frame. The turned shot is the one worth
## looking at twice: the neck wanders through W, so at a turned slice it should curve
## differently and the paddles should change width.
##
## THE CAMERA IS PLACED FROM THE MODEL'S OWN BOUNDS, not from numbers I picked. Two rounds of
## hand-chosen positions gave a frame of flat background, and because the first of those
## rounds DID show the animal - small, low in the frame - I spent the second round blaming
## the sky material and the lighting rather than the thing that had actually changed. Reading
## the built mesh's extent and backing off a multiple of it cannot miss, and it keeps working
## when the model is edited, which hardcoded positions would not.

const SCENE := "res://sandbox/water4d/plesiosaur.tscn"
const SETTLE := 0.8

## name, which way the camera sits from the model's centre, slice turn in degrees.
const SHOTS := [
	["side", Vector3(-1.0, 0.12, 0.0), 0.0],
	["above", Vector3(-0.15, 1.0, 0.0), 0.0],
	["front", Vector3(0.0, 0.12, 1.0), 0.0],
	["turned", Vector3(-1.0, 0.12, 0.0), 38.0],
]

var _root: Node = null
var _camera: Camera4D = null
var _frames: int = 0
var _held: float = 0.0
var _index: int = 0
var _model: Node = null
var _centre := Vector4()
var _reach: float = 10.0


func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)


func _process(delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		_build_room()
		return false

	# The rig coalesces its rebuild into _process, so the mesh is not there on frame one and
	# the bounds have to be read after it has had a turn.
	if _frames == 3:
		if not _measure_model():
			quit(1)
			return true
		_aim(0)
		return false
	if _frames < 3:
		return false

	_held += delta
	if _held < SETTLE:
		return false
	_held = 0.0

	root.get_texture().get_image().save_png("user://plesiosaur_%s.png" % SHOTS[_index][0])
	print("  %-7s saved" % SHOTS[_index][0])
	_index += 1
	if _index >= SHOTS.size():
		quit(0)
		return true
	_aim(_index)
	return false


func _build_room() -> void:
	_root = Node4D.new()
	root.add_child(_root)
	current_scene = _root

	# WorldEnvironment4D HAS NO `ambient_light_energy`. Setting it threw, which aborted this
	# whole function before the model or the camera were ever added - so every shot came out as
	# the empty clear colour. I read that flat grey as "the sky material is painting over the
	# frame" and spent a round removing the sky, which had nothing to do with it. The lesson is
	# that a uniform frame means NOTHING WAS DRAWN, and the first question is whether the scene
	# was built at all, not what it was built with.
	var environment := WorldEnvironment4D.new()
	environment.current = true
	environment.sky_material = GradientSkyMaterial4D.new()
	environment.ambient_light_sky_contribution = 0.35
	environment.ambient_light_color = Color(0.5, 0.56, 0.62)
	environment.tonemap_mode = 2
	_root.add_child(environment)

	var sun := DirectionalLight4D.new()
	sun.basis = Basis4D.from_yz(-0.7) * Basis4D.from_zx(0.5)
	sun.light_color = Color(1.0, 0.97, 0.91)
	sun.light_energy = 1.15
	_root.add_child(sun)
	# A second, dimmer light from the other side, for the capture only. One sun leaves the far
	# flank unreadable, and the far flank is where a branch seam would show.
	var fill := DirectionalLight4D.new()
	fill.basis = Basis4D.from_yz(-0.3) * Basis4D.from_zx(-2.2)
	fill.light_color = Color(0.72, 0.8, 0.88)
	fill.light_energy = 0.5
	_root.add_child(fill)

	# Hold the instance rather than looking it up by name later: add_child can rename a node
	# on a collision, and a name lookup that misses reports "no model" when the model is
	# right there.
	_model = (load(SCENE) as PackedScene).instantiate()
	_root.add_child(_model)
	_camera = Camera4D.new()
	_camera.rendering_engine_name = "Cross-section"
	_root.add_child(_camera)
	_camera.current = true


## Centre and reach of the built mesh, in world terms. Returns false if there is no mesh,
## which is worth failing loudly on rather than photographing an empty room four times.
func _measure_model() -> bool:
	var rig: Node = _model.get_node_or_null(^"Hide") if _model != null else null
	if rig == null:
		print("  FAIL - no Hide under the model (children: %s)"
				% [_model.get_children() if _model != null else "no model at all"])
		return false
	var mesh: Mesh4D = rig.mesh as Mesh4D
	if mesh == null:
		print("  FAIL - the rig has not built a mesh")
		return false
	var points: PackedVector4Array = mesh.get_vertex_positions()
	if points.is_empty():
		print("  FAIL - the built mesh is empty")
		return false
	var low: Vector4 = points[0]
	var high: Vector4 = points[0]
	for p in points:
		low = Vector4(minf(low.x, p.x), minf(low.y, p.y), minf(low.z, p.z), minf(low.w, p.w))
		high = Vector4(maxf(high.x, p.x), maxf(high.y, p.y), maxf(high.z, p.z), maxf(high.w, p.w))
	_centre = (low + high) * 0.5
	var span: Vector4 = high - low
	_reach = maxf(maxf(span.x, span.y), span.z)
	print("  model centred at (%.2f, %.2f, %.2f, %.2f), longest axis %.2f m"
			% [_centre.x, _centre.y, _centre.z, _centre.w, _reach])
	return true


func _aim(index: int) -> void:
	var offset: Vector3 = SHOTS[index][1]
	var direction := Vector4(offset.x, offset.y, offset.z, 0.0).normalized()
	# About 0.85 of the longest axis of standoff is what a default 4D camera frames without
	# clipping the nose or the tail.
	var from: Vector4 = _centre + direction * (_reach * 0.85)
	_camera.position = from
	_camera.basis = Basis4D.looking_at(_centre - from)
	# THE TURN IS APPLIED TO THE ANIMAL, NOT THE CAMERA, and that is not a shortcut - turning
	# the camera's slice does not work at this range. A slice turn pivots about the CAMERA, so
	# at 38 degrees and an 8 m standoff the viewing hyperplane has slid about 5 m through W by
	# the time it reaches the subject. The plesiosaur is only about 1 m deep through W, so it
	# is simply not in the slice any more and the shot came back as empty sky.
	#
	# Worth knowing for the pool: a creature this thin through W disappears when the player
	# turns the slice from across the room. The water does not, because it is unbounded in W.
	# Rotating the model in ZW shows the same thing the player would see standing next to it.
	var turn: float = SHOTS[index][2]
	if _model != null:
		_model.basis = (Basis4D.from_zw(deg_to_rad(turn)) if not is_zero_approx(turn)
				else Projection.IDENTITY)
