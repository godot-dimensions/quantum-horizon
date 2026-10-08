extends SceneTree

## Can you actually see the plesiosaur from the walkway?
##
##   godot --path project --rendering-method forward_plus --resolution 1100x620 \
##       --script res://sandbox/water4d/_capture_pool_creature_runner.gd
##
## `_probe_pilot_runner.gd` proves it swims where it should and is in the player's slice
## better than half the time. Neither fact means it can be SEEN: it swims between 10 and 32 m
## down, and the water absorbs 0.30 per metre in red, so at 20 m the red channel is down to
## 0.2% and at 32 m there is essentially nothing left of it. An animal that is in frame and
## indistinguishable from the dark is not in the showcase.
##
## So this parks a camera on the walkway, steps the simulation until the animal is somewhere
## worth photographing, and takes its picture - plus one from directly above at close range as
## a control, to tell "too deep to see" apart from "not being drawn at all".

const SCENE := "res://sandbox/water4d/pool_room.tscn"
const SETTLE_STEPS := 6
const STEP := 1.0 / 60.0

var _root: Node = null
var _creature: Node4D = null
var _pilot: Node = null
var _camera: Camera4D = null
var _frames: int = 0
var _shot: int = 0
var _posed: bool = false


func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		_root = (load(SCENE) as PackedScene).instantiate()
		root.add_child(_root)
		current_scene = _root
		return false
	if _frames < 4:
		return false
	if _frames == 4:
		_creature = _root.get_node_or_null(^"Plesiosaur") as Node4D
		_pilot = _root.get_node_or_null(^"Plesiosaur/Pilot")
		if _creature == null or _pilot == null:
			print("  FAIL - the pool has no Plesiosaur or no Pilot in it")
			quit(1)
			return true
		_camera = Camera4D.new()
		_camera.rendering_engine_name = "Cross-section"
		_root.add_child(_camera)
		_camera.current = true
		return false

	if not _posed:
		_bring_into_view()
		_aim()
		_posed = true
		return false

	var at: Vector4 = _creature.position
	root.get_texture().get_image().save_png("user://poolcreature_%d.png" % _shot)
	print("  shot %d: animal at (%.1f, %.1f, %.1f, %.1f), %.1f m down"
			% [_shot, at.x, at.y, at.z, at.w, -at.y])
	_posed = false
	_shot += 1
	if _shot >= 4:
		quit(0)
		return true
	return false


## PLACES the animal for the first two shots rather than waiting for it to swim somewhere
## photogenic. Waiting took twenty thousand simulated steps in one frame, which stalled the
## frame so badly the HUD read 1 fps - and that number then looked like a performance problem
## with the creature rather than with this probe. These two shots are a VISIBILITY test, and
## teleporting the subject is a legitimate way to set one up; the behaviour is tested
## properly in `_probe_pilot_runner.gd`.
func _bring_into_view() -> void:
	if _shot < 2:
		# Just off the walkway, in the player's own slice: shallow first, then deep, so the
		# pair brackets the depth band the pilot actually uses.
		_creature.position = Vector4(7.0, -10.5 if _shot == 0 else -28.0, 15.0, 0.0)
	else:
		_creature.position = Vector4(0.0, -20.0, 0.0, 0.0)
	for _i in range(SETTLE_STEPS):
		_pilot.call(&"_physics_process", STEP)
	# Put it back where it was asked to be: a few pilot steps are needed to pose the swimmer,
	# and they also move it.
	_creature.position = Vector4(7.0, -10.5 if _shot == 0 else -28.0, 15.0, 0.0) if _shot < 2 			else Vector4(0.0, -20.0, 0.0, 0.0)


func _aim() -> void:
	var at: Vector4 = _creature.position
	if _shot >= 2:
		# Control: close and underwater, where it must be clearly visible. If it is missing
		# HERE the fault is the cut or the pilot, not the water.
		var from: Vector4 = at + Vector4(-14.0, 4.0, 0.0, 0.0)
		_camera.position = from
		_camera.basis = Basis4D.looking_at(at - from)
		return
	# From the walkway, where the player stands, looking down at it.
	# Where the player's head is on the walkway, close enough to the animal that the line of
	# sight goes STEEPLY down. At a grazing angle the surface reads as opaque white - the
	# first version of this shot looked along the walkway at an animal 32 m away and 15 m
	# down, about 25 degrees below horizontal, and photographed a white sheet. That is true
	# of the water and says nothing about the creature.
	# AT THE RAIL AND OUTSIDE IT. An eye on the walkway's centre line looking steeply down at
	# something off to the side has the DECK in the way - the first attempt photographed the
	# planking from underneath and the trigger markers through it. The walkway is 3.4 m wide,
	# so the viewpoint goes to its edge and the animal further out.
	var eye := Vector4(0.0, 1.9, 1.65, 0.0)
	_camera.position = eye
	_camera.basis = Basis4D.looking_at(at - eye)
