# CARRIED OVER from res://ramon/chickenpen/lookout/heron_4d.gd on 4 Oct 2026, so the lab owns this copy: the original can change without breaking the lab, and the other way round (LabKit/carried/README.md).
@tool
extends Node4D

## A grey heron that fishes in the ana marsh, out at w +8: the third secret, and the
## balloon ride's payoff.
##
## BUILT FOR POSES THAT COST NOTHING. A heron is its neck: drawn in to an S at rest, shot out
## to strike, folded back in flight. Lofting the neck as one chain would mean re-lofting it
## every frame it moves (about 11 microseconds a tetrahedron - milliseconds a frame). So the
## neck is three short lofted segments on a chain of pivots, the legs are two bars each on
## a hip and a heel pivot, and the wings are boxes on shoulder and wrist pivots; every pose
## is a few rotations. Only the body is one loft, and it never changes.
##
## DRESSED FROM THE FIELD GUIDES (the Heron Specialist Group's and eBird's grey heron): grey
## above, a white head and neck, a broad black brow running back into the black plumes, two
## lines of black streaks down the front of the neck to the breast, black shoulder patches and
## black on the flanks over white thighs, a yellow dagger of a bill; in flight the neck pulled
## in to a bulge, the legs trailing, the flight feathers dark. Round joints at every bend of
## the neck and at the heels, so the segments read as one neck, not a chain of tubes.
##
## MOVES FROM A STUDY OF HOW HERONS MOVE (follow_up/heron_motion_study.md; Ramon, 2 Oct: "it
## flies with the feet stretched out in front ... make a proper case study"). What it changed:
##   - Flight: neck folded right back, a bulge under the chest and the head on the shoulders;
##     legs straight out BEHIND, past the tail, toes in line; slow, deep, bowed beats, the
##     downstroke the longer part of the beat.
##   - Take-off: a crouch, a jump, a few hard beats with the legs dangling, then the legs
##     swing back and the neck folds in.
##   - Landing: a glide in, neck stretched out, legs swung down and forward, the body tipped
##     upright, then braking flaps; wings held up a moment after touching down.
##   - Wading: one slow step at a time, each foot lifted high and its toes closed so it
##     slips out of the water, then set down and opened. The body moves in pulses but the
##     head does not: the neck draws in while the body catches up and stretches out while
##     it waits, so the head glides. Feet are planted - the legs are solved from where each
##     foot is (two-bone IK), so nothing slides.
##   - The strike: freeze, coil the neck back, then the stab, straight out and down, bill
##     into the water; up again, and a fish swallowed bill-up, or a shake of the head.
##   - Rest: on one leg, the other folded up into the belly, head sunk on the shoulders.
##
## THICK IN W, like the owl, so the ring has a fair width to find it in: the balls are
## stretched along W and the bars and boxes are as deep in W as the body is.
##
## WHAT IT DOES (the journal's stars):
##   STAND / ALERT  1  standing in the shallows, neck drawn in; ALERT, neck up straight,
##                     when something whistles
##   ONE_LEG        2  resting on one leg, the other folded up under it
##   STALK, STRIKE  3  wading slowly, neck out and low; then the stab, and now and then a fish
##   TAKE_OFF, FLY  4  put up - by someone walking close, or the camera's first good photo of
##                     it (the payoff) - it lifts off on slow, deep wingbeats with its legs
##                     trailing and flies to the far bank

enum State { STAND, ALERT, ONE_LEG, STALK, STRIKE, TAKE_OFF, FLY, LAND }

const RIG := preload("res://ramon/LabKit/carried/chickenpen/scripts/loft_rig_4d.gd")
const BALL := preload("res://ramon/LabKit/carried/chickenpen/scripts/loft_ball_4d.gd")

## Neck poses: [segment 1, 2, 3, head], each a tilt from the one before. A segment at a summed
## angle a points along (y, z) = (cos a, sin a): 0 straight up, PI/2 straight ahead. The bill
## is the head's own +z, so it points along (-sin h, cos h) for the summed head angle h: 0 is
## level, + is down.
const POSES := {
	# Standing: an easy S, the head well up.
	"rest": [-0.35, 1.25, -1.1, 0.2],
	# Resting: the head sunk onto the shoulders, bill a little down.
	"hunch": [-0.6, 2.6, -1.7, -0.1],
	# Something heard: straight up and tall.
	"alert": [-0.08, 0.05, 0.0, -0.05],
	# Wading: neck out level, bill down at the water. "in" is the same head place with the
	# neck drawn in (it moves 13 cm, what the body moves in a step), for the gliding head.
	"stalk_out": [1.5, 0.1, 0.1, -0.83],
	"stalk_in": [0.6, 2.0, -1.1, -0.63],
	# Coiled to strike, and the strike: straight out and down, bill in line with the neck.
	"cocked": [0.4, 2.2, -1.2, -0.44],
	"strike": [2.5, 0.0, 0.0, -1.57],
	# Bill up, gulping a fish down.
	"swallow": [-0.1, 0.2, 0.2, -0.8],
	# Flight: the neck in a bulge under the chest, the head back on the shoulders.
	"fly": [2.5, -2.8, 1.2, -0.9],
	# Taking off and coming in: neck out ahead.
	"reach": [0.9, 0.3, 0.1, -0.9],
}

## Where the leg bones bend, along the leg: the hip to the heel, and the heel to the foot.
const THIGH := 0.27
const SHANK := 0.29
## The hip, in the bird's own space; the body leans about it so the hips stay put.
const HIP := Vector4(0.0, 0.56, -0.03, 0.0)

@export_range(0.4, 2.5, 0.01, "suffix:m") var size: float = 1.0:
	set(v):
		size = v
		_changed()
@export_range(1.0, 4.0, 0.05) var w_stretch: float = 2.2:
	set(v):
		w_stretch = v
		_changed()
## Blue-grey: a plain grey lit by the pen's sunset reads as beige.
@export var grey: Color = Color(0.38, 0.43, 0.52)
@export var pale: Color = Color(0.86, 0.87, 0.86)
@export var dark: Color = Color(0.13, 0.13, 0.15)
@export var bill: Color = Color(0.86, 0.62, 0.22)
@export var leg: Color = Color(0.62, 0.52, 0.30)

@export_group("Life")
## Only stand and look about: for the creature showcase (Ramon, 2 Oct: "just doing an idle
## animation standing"). No wading, no striking, no flying off.
@export var idle_only: bool = false
## The marsh it lives in (ana_marsh_4d.gd): its fishing spot and its refuge.
@export var marsh_path: NodePath
## Who can put it up by walking close.
@export var player_path: NodePath
@export var lookout_path: NodePath
@export_range(2.0, 30.0, 0.5, "suffix:m") var flush_within: float = 8.0
## A heron's flight is slow: about 4 m/s on a short hop like this one, from the take-off's
## jump to the landing's last braking flap.
@export_range(1.0, 12.0, 0.5, "suffix:m/s") var flight_speed: float = 4.0
@export var croak: AudioStream = preload("res://ramon/chickenpen/audio/sfx/lookout_heron.wav")
@export var wingbeats: AudioStream = preload("res://ramon/chickenpen/audio/sfx/lookout_wings.wav")

var state: int = State.STAND

var _neck: Array[Node4D] = []
var _head: Node4D
var _hips: Array[Node4D] = []
var _heels: Array[Node4D] = []
var _feet: Array[Node4D] = []
var _toes: Array = [[], []]
var _folded: Array[Node4D] = []
var _spread: Array[Node4D] = []
var _wing_pivots: Array[Node4D] = []
var _wrists: Array[Node4D] = []
var _fish: Node4D
var _body: Node4D
var _pose: Array = [-0.35, 1.25, -1.1, 0.2]
var _t: float = 0.0
var _state_t: float = 0.0
var _state_len: float = 8.0
var _rng := RandomNumberGenerator.new()
var _home: Vector4
var _at_refuge: bool = false
var _cool: float = 0.0
var _voice: AudioStreamPlayer
var _wing_voice: AudioStreamPlayer
var _head_yaw: float = 0.0
var _head_yaw_goal: float = 0.0
var _next_look: float = 2.0
## As the owl's: posed only while a camera could see it (it lives at w +8).
var _seen: bool = true
var _seen_check: float = 0.0
## The body's lean (+ tips the head down), drop and sideways shift, as they are now.
var _lean: float = 0.0
var _drop: float = 0.0
var _shift: float = 0.0
## Each leg as world angles [thigh, shank, foot], as they are now (see _leg_ik), and where
## each foot is planted along the bird's own z, from the hip.
var _legs: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _foot_z: Array[float] = [0.0, 0.0]
var _toe_open: Array[float] = [1.0, 1.0]
## The wingbeat: how far through a beat, 0 to 1.
var _wing_phase: float = 0.0
## Wings held spread after a landing, for this much longer.
var _settle: float = 0.0
## The flight: a curve from where it took off to where it lands, and how long it takes.
var _path: Array[Vector4] = []
var _flight_len: float = 4.0
## Stalking: left to turn before it walks on, and whether this strike catches a fish.
var _turn_left: float = 0.0
var _catch: bool = false


func _changed() -> void:
	if is_node_ready():
		rebuild()


func _ready() -> void:
	_rng.seed = 77
	rebuild()
	if Engine.is_editor_hint():
		set_process(false)
		return
	_home = position
	_voice = _player(croak)
	_wing_voice = _player(wingbeats)


func _player(stream: AudioStream) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.bus = &"SFX" if AudioServer.get_bus_index(&"SFX") >= 0 else &"Master"
	add_child(p)
	return p


func rebuild() -> void:
	for child in get_children():
		if not (child is AudioStreamPlayer):
			child.free()
	_neck.clear()
	_hips.clear()
	_heels.clear()
	_feet.clear()
	_toes = [[], []]
	_folded.clear()
	_spread.clear()
	_wing_pivots.clear()
	_wrists.clear()
	var u: float = size
	var ws: float = w_stretch
	var deep: float = 0.26 * u * ws
	_body = Node4D.new()
	_body.name = "Body"
	add_child(_body)
	_own(_body)
	var plumage := _rig(_body, "Plumage", grey)
	_ball(plumage, "Tail", Vector4(0.0, 0.62 * u, -0.31 * u, 0.0), 0.045 * u, ws * 0.7)
	_ball(plumage, "Back", Vector4(0.0, 0.66 * u, -0.16 * u, 0.0), 0.115 * u, ws)
	_ball(plumage, "Breast", Vector4(0.0, 0.665 * u, 0.02 * u, 0.0), 0.12 * u, ws)
	_ball(plumage, "Chest", Vector4(0.0, 0.72 * u, 0.12 * u, 0.0), 0.075 * u, ws)
	plumage.call("build", false)
	# The pale breast plumes hanging below the chest, and the black shoulder patches.
	_box(_body, "Plumes", Vector4(0.0, 0.6 * u, 0.12 * u, 0.0), Vector4(0.08 * u, 0.12 * u, 0.03 * u, deep), pale)
	for side in [-1.0, 1.0]:
		_box(_body, "Shoulder%d" % int(side), Vector4(side * 0.085 * u, 0.73 * u, 0.07 * u, 0.0), Vector4(0.03 * u, 0.05 * u, 0.06 * u, deep), dark)
		_box(_body, "Flank%d" % int(side), Vector4(side * 0.1 * u, 0.6 * u, -0.02 * u, 0.0), Vector4(0.03 * u, 0.07 * u, 0.16 * u, deep), dark)
		_box(_body, "ThighCover%d" % int(side), Vector4(side * 0.055 * u, 0.55 * u, -0.03 * u, 0.0), Vector4(0.05 * u, 0.06 * u, 0.06 * u, deep * 0.7), pale)
	# Wings: folded along the back, or spread wide in flight - two sets, one shown at a time.
	# Spread, each is an inner wing on the shoulder and a hand on the wrist, so the beat can
	# bow: the hand hangs below the line of the arm, as a heron's does.
	for side in [-1.0, 1.0]:
		var pivot := Node4D.new()
		pivot.name = "Wing%d" % int(side)
		_body.add_child(pivot)
		_own(pivot)
		pivot.position = Vector4(side * 0.09 * u, 0.72 * u, 0.03 * u, 0.0)
		# Folded: mostly inside the body, the long flight feathers showing down the back.
		var fold := _box(pivot, "Folded", Vector4(0.0, 0.0, -0.16 * u, 0.0), Vector4(0.022 * u, 0.09 * u, 0.32 * u, deep), grey.darkened(0.1))
		_box(fold, "Primaries", Vector4(side * 0.002 * u, -0.012 * u, -0.16 * u, 0.0), Vector4(0.024 * u, 0.05 * u, 0.12 * u, deep), dark.lightened(0.2))
		_folded.append(fold)
		var arm := _box(pivot, "Arm", Vector4(side * 0.2 * u, 0.0, -0.03 * u, 0.0), Vector4(0.4 * u, 0.025 * u, 0.28 * u, deep), grey)
		arm.visible = false
		_spread.append(arm)
		var wrist := Node4D.new()
		wrist.name = "Wrist"
		pivot.add_child(wrist)
		_own(wrist)
		wrist.position = Vector4(side * 0.4 * u, 0.0, -0.02 * u, 0.0)
		_box(wrist, "Hand", Vector4(side * 0.17 * u, 0.0, 0.0, 0.0), Vector4(0.34 * u, 0.022 * u, 0.24 * u, deep), grey.darkened(0.12))
		for f in 4:
			var finger := _box(wrist, "Primary%d" % f, Vector4(side * (0.3 + 0.03 * float(f)) * u, 0.0, (0.06 - 0.055 * float(f)) * u, 0.0), Vector4(0.2 * u, 0.02 * u, 0.045 * u, deep), dark)
			finger.basis = Basis4D.from_zx(side * (0.1 + 0.12 * float(f)))
		wrist.visible = false
		_spread.append(wrist)
		_wing_pivots.append(pivot)
		_wrists.append(wrist)
	# Legs: a hip and a heel pivot each - the "knee" that bends backwards is the heel (the
	# real knee is up inside the body). Every bone hangs straight down its own pivot's -y, so
	# the leg can be solved from where its foot is.
	for i in 2:
		var side: float = -1.0 if i == 0 else 1.0
		var hip := Node4D.new()
		hip.name = "Hip%d" % int(side)
		_body.add_child(hip)
		_own(hip)
		hip.position = Vector4(side * 0.05 * u, HIP.y * u, HIP.z * u, 0.0)
		_box(hip, "Thigh", Vector4(0.0, -THIGH * 0.5 * u, 0.0, 0.0), Vector4(0.026 * u, THIGH * u, 0.026 * u, deep * 0.6), leg)
		var heel := Node4D.new()
		heel.name = "Heel"
		hip.add_child(heel)
		_own(heel)
		heel.position = Vector4(0.0, -THIGH * u, 0.0, 0.0)
		_sphere(heel, "HeelJoint", Vector4.ZERO, 0.02 * u, leg.darkened(0.1), ws * 0.6)
		_box(heel, "Shank", Vector4(0.0, -SHANK * 0.5 * u, 0.0, 0.0), Vector4(0.022 * u, SHANK * u, 0.022 * u, deep * 0.6), leg)
		var foot := Node4D.new()
		foot.name = "Foot"
		heel.add_child(foot)
		_own(foot)
		foot.position = Vector4(0.0, -SHANK * u, 0.0, 0.0)
		for k in 3:
			var toe := _box(foot, "Toe%d" % k, Vector4((float(k) - 1.0) * 0.012 * u, 0.0, 0.05 * u, 0.0), Vector4(0.012 * u, 0.01 * u, 0.1 * u, deep * 0.5), leg.darkened(0.15))
			toe.basis = Basis4D.from_zx((float(k) - 1.0) * 0.35)
			(_toes[i] as Array).append(toe)
		_box(foot, "Hind", Vector4(0.0, 0.0, -0.03 * u, 0.0), Vector4(0.01 * u, 0.01 * u, 0.06 * u, deep * 0.5), leg.darkened(0.15))
		_hips.append(hip)
		_heels.append(heel)
		_feet.append(foot)
	# The neck: three lofted segments on a chain of pivots, then the head.
	var base := Node4D.new()
	base.name = "Neck0"
	_body.add_child(base)
	_own(base)
	base.position = Vector4(0.0, 0.74 * u, 0.15 * u, 0.0)
	var parent: Node4D = base
	var lengths: Array = [0.15, 0.14, 0.12]
	var radii: Array = [[0.048, 0.042], [0.042, 0.037], [0.037, 0.033]]
	for k in 3:
		var seg := _rig(parent, "Segment%d" % k, pale if k > 0 else pale.lerp(grey, 0.5))
		_ball(seg, "A", Vector4.ZERO, float(radii[k][0]) * u, ws * 0.85)
		_ball(seg, "B", Vector4(0.0, float(lengths[k]) * u, 0.0, 0.0), float(radii[k][1]) * u, ws * 0.85)
		seg.call("build", false)
		# A round joint where this segment meets the last, so the neck bends rather than breaks.
		_sphere(parent, "Joint%d" % k, Vector4.ZERO, float(radii[k][0]) * u * 1.04, pale if k > 0 else pale.lerp(grey, 0.5), ws * 0.85)
		# Two lines of black streaks down the front of the neck, to the breast.
		if k < 2:
			for j in 3:
				for side in [-1.0, 1.0]:
					_box(parent, "Streak%d_%d_%d" % [k, j, int(side)], Vector4(side * 0.011 * u, (0.03 + 0.045 * float(j)) * u, float(radii[k][0]) * u * 0.9, 0.0),
						Vector4(0.006 * u, 0.022 * u, 0.006 * u, deep * 0.5), dark)
		_neck.append(parent)
		var next := Node4D.new()
		next.name = "Neck%d" % (k + 1)
		parent.add_child(next)
		_own(next)
		next.position = Vector4(0.0, float(lengths[k]) * u, 0.0, 0.0)
		parent = next
	_head = parent
	_sphere(_head, "HeadJoint", Vector4.ZERO, 0.034 * u, pale, ws * 0.8)
	var head := _rig(_head, "Skull", pale)
	_ball(head, "Back", Vector4(0.0, 0.01 * u, -0.025 * u, 0.0), 0.035 * u, ws * 0.8)
	_ball(head, "Front", Vector4(0.0, 0.012 * u, 0.025 * u, 0.0), 0.03 * u, ws * 0.8)
	head.call("build", false)
	_box(_head, "Crown", Vector4(0.0, 0.04 * u, -0.01 * u, 0.0), Vector4(0.05 * u, 0.012 * u, 0.07 * u, deep * 0.5), dark)
	_box(_head, "Bill", Vector4(0.0, 0.005 * u, 0.1 * u, 0.0), Vector4(0.024 * u, 0.022 * u, 0.1 * u, deep * 0.45), bill)
	_box(_head, "BillTip", Vector4(0.0, 0.004 * u, 0.18 * u, 0.0), Vector4(0.014 * u, 0.012 * u, 0.07 * u, deep * 0.4), bill.darkened(0.15))
	for side in [-1.0, 1.0]:
		var eye := _box(_head, "Eye%d" % int(side), Vector4(side * 0.026 * u, 0.018 * u, 0.03 * u, 0.0), Vector4(0.01 * u, 0.014 * u, 0.014 * u, deep * 0.4), Color(0.95, 0.85, 0.2))
		_box(eye, "Pupil", Vector4(side * 0.002 * u, 0.0, 0.0, 0.0), Vector4(0.008 * u, 0.007 * u, 0.007 * u, deep * 0.4), Color(0.02, 0.02, 0.02))
		# The broad black brow, from over the eye back to the plumes.
		_box(_head, "Brow%d" % int(side), Vector4(side * 0.025 * u, 0.032 * u, -0.025 * u, 0.0), Vector4(0.012 * u, 0.014 * u, 0.085 * u, deep * 0.4), dark)
	for k in 2:
		var plume := _box(_head, "Plume%d" % k, Vector4((float(k) - 0.5) * 0.012 * u, 0.03 * u, -0.1 * u, 0.0), Vector4(0.006 * u, 0.006 * u, 0.15 * u, deep * 0.3), dark)
		plume.basis = Basis4D.from_yz(-0.45 - 0.12 * float(k))
	_fish = _box(_head, "Fish", Vector4(0.0, 0.0, 0.2 * u, 0.0), Vector4(0.02 * u, 0.012 * u, 0.08 * u, deep * 0.3), Color(0.78, 0.82, 0.84))
	_fish.basis = Basis4D.from_zx(PI * 0.5)
	_fish.visible = false
	_drop = -0.012 * u
	for i in 2:
		_legs[i] = _stance(i, 0.0, 0.0)
	_apply_neck(_pose)
	_apply_body()
	_apply_legs()


func _rig(parent: Node, part: String, colour: Color) -> MeshInstance4D:
	var hide := MeshInstance4D.new()
	hide.name = part
	hide.set_script(RIG)
	var m := TetraMaterial4D.new()
	m.albedo_color = colour
	hide.material_override = m
	parent.add_child(hide)
	hide.set("profile_sides", 12)
	hide.set("profile_rings", 4)
	hide.set("verbose", false)
	hide.set("live_rebuild", false)
	_own(hide)
	return hide


## A round knob: a loft of two balls a hair apart.
func _sphere(parent: Node, part: String, at: Vector4, radius: float, colour: Color, w_scale: float) -> void:
	var knob := _rig(parent, part, colour)
	knob.position = at
	_ball(knob, "A", Vector4(0.0, -radius * 0.15, 0.0, 0.0), radius, w_scale)
	_ball(knob, "B", Vector4(0.0, radius * 0.15, 0.0, 0.0), radius, w_scale)
	knob.call("build", false)


func _ball(parent: Node, part: String, at: Vector4, radius: float, w_scale: float) -> void:
	var node := MeshInstance4D.new()
	node.name = part
	node.set_script(BALL)
	parent.add_child(node)
	node.position = at
	node.set("radius", radius)
	node.set("w_scale", w_scale)
	_own(node)


func _box(parent: Node, part: String, at: Vector4, box: Vector4, colour: Color) -> MeshInstance4D:
	var node := MeshInstance4D.new()
	node.name = part
	var mesh := BoxTetraMesh4D.new()
	mesh.size = box
	node.mesh = mesh
	var material := TetraMaterial4D.new()
	material.albedo_color = colour
	node.material_override = material
	parent.add_child(node)
	node.position = at
	_own(node)
	return node


func _own(node: Node) -> void:
	if Engine.is_editor_hint() and get_tree() != null and get_tree().edited_scene_root != null:
		node.owner = get_tree().edited_scene_root


# --- For the camera --------------------------------------------------------------------------

func behaviour() -> Array:
	match state:
		State.ONE_LEG:
			return [2, "On one leg"]
		State.STALK, State.STRIKE:
			return [3, "The strike" if state == State.STRIKE else "Stalking"]
		State.TAKE_OFF, State.FLY, State.LAND:
			return [4, "Heron rising"]
	return [1, "The ana heron"]


## Its middle, in the world.
func centre() -> Vector4:
	return global_position + global_basis * Vector4(0.0, 0.62 * size, 0.0, 0.0)


func perform(what: String) -> void:
	match what:
		"one_leg":
			_enter(State.ONE_LEG, 20.0)
		"stalk":
			_home = position
			_enter(State.STALK, 20.0)
		"strike":
			_strike()
		"take_off":
			_take_off()
		"alert":
			_enter(State.ALERT, 3.0)


## A whistle from somewhere: it stands up straight and looks.
func hear() -> void:
	if state in [State.STAND, State.ONE_LEG, State.STALK]:
		_enter(State.ALERT, 3.2)


# --- Its life ---------------------------------------------------------------------------------

func _enter(s: int, seconds: float) -> void:
	state = s
	_state_t = 0.0
	_state_len = seconds
	_turn_left = 0.0


func _strike() -> void:
	_catch = _rng.randf() < 0.5
	_enter(State.STRIKE, 2.4 if _catch else 1.7)


func _take_off() -> void:
	if state in [State.TAKE_OFF, State.FLY, State.LAND]:
		return
	var marsh := get_node_or_null(marsh_path) as Node4D
	var from: Vector4 = position
	var to: Vector4
	if marsh != null:
		var spot: Vector4 = marsh.call("fishing_spot") if _at_refuge else marsh.call("refuge_spot")
		to = marsh.position + marsh.basis * spot
	else:
		to = _home + Vector4(6.0, 0.0, 2.0, 0.0) * (-1.0 if _at_refuge else 1.0)
	_at_refuge = not _at_refuge
	# A curve that climbs steeply off the water, arcs over, and comes down steeply: a
	# heron gets up and down at a steep angle and is level only in between.
	var d: Vector4 = to - from
	var flat := Vector4(d.x, 0.0, d.z, d.w)
	var ahead: Vector4 = flat.normalized() if flat.length() > 0.1 else (global_basis * Vector4(0.0, 0.0, 1.0, 0.0))
	var up := Vector4(0.0, 1.0, 0.0, 0.0)
	_path = [from, from + up * 2.6 + ahead * 1.2, to + up * 2.4 - ahead * 2.4, to]
	_flight_len = 1.6 + flat.length() / flight_speed + 1.2
	_fish.visible = false
	_enter(State.TAKE_OFF, _flight_len)
	_play(_voice, -4.0)
	_play(_wing_voice, -6.0)


func _play(p: AudioStreamPlayer, db: float) -> void:
	if p == null or p.stream == null:
		return
	var lookout: Node = get_node_or_null(lookout_path)
	var cam: Camera4D = lookout.call("current_camera") if lookout != null else null
	var d: float = 8.0
	if cam != null:
		var g: Vector4 = cam.global_position - global_position
		d = Vector3(g.x, g.y, g.z).length()
	p.volume_db = db - 20.0 * log(maxf(d, 6.0) / 6.0) / log(10.0)
	p.play()


func _process(delta: float) -> void:
	_t += delta
	_state_t += delta
	_cool = maxf(_cool - delta, 0.0)
	_settle = maxf(_settle - delta, 0.0)
	_check_disturbed()
	_seen_check -= delta
	if _seen_check <= 0.0:
		_seen_check = 0.5
		_seen = _visible_to_camera()
	# Looking about while it stands: the head turns, holds, turns back.
	_next_look -= delta
	if _next_look <= 0.0:
		_next_look = _rng.randf_range(2.0, 5.0)
		_head_yaw_goal = _rng.randf_range(-0.9, 0.9) if _rng.randf() < 0.7 else 0.0
	if idle_only:
		state = State.STAND
		_state_t = 0.0
		if _seen:
			_animate(delta)
		return
	match state:
		State.STAND, State.ALERT, State.ONE_LEG:
			if _state_t > _state_len:
				_next_idle()
		State.STALK:
			_wade(delta)
			if _state_t > _state_len and _turn_left <= 0.0 and _swing_leg() < 0:
				_strike()
		State.STRIKE:
			if _state_t > _state_len:
				_fish.visible = false
				_enter(State.STAND, _rng.randf_range(3.0, 6.0))
		State.TAKE_OFF, State.FLY, State.LAND:
			_fly()
	if _seen or state in [State.TAKE_OFF, State.FLY, State.LAND]:
		_animate(delta)


func _visible_to_camera() -> bool:
	var lookout: Node = get_node_or_null(lookout_path)
	if lookout == null:
		return true
	var cam: Camera4D = lookout.call("current_camera")
	if cam == null:
		return true
	var rel: Vector4 = global_position - cam.global_position
	return absf(rel.dot(cam.global_basis.w)) < 3.0 and rel.length() < 80.0


func _next_idle() -> void:
	_fish.visible = false
	var roll: float = _rng.randf()
	if state == State.ONE_LEG or state == State.ALERT:
		_enter(State.STAND, _rng.randf_range(4.0, 8.0))
	elif roll < 0.4:
		_enter(State.ONE_LEG, _rng.randf_range(8.0, 15.0))
	elif roll < 0.8:
		_home = position
		_enter(State.STALK, _rng.randf_range(6.0, 11.0))
	else:
		_enter(State.STAND, _rng.randf_range(5.0, 9.0))


func _check_disturbed() -> void:
	if idle_only or _cool > 0.0 or state in [State.TAKE_OFF, State.FLY, State.LAND]:
		return
	var player := get_node_or_null(player_path) as Node4D
	if player == null or not player.is_visible_in_tree():
		return
	var gap: Vector4 = player.global_position - global_position
	if Vector2(gap.x, gap.z).length() < flush_within and absf(gap.w) < 2.0:
		_take_off()


# --- Wading -----------------------------------------------------------------------------------

## The wading walk, one step at a time: [constant STEP_CYCLE] seconds for a step of each foot,
## each foot swinging for [constant SWING] of it while the other stands, and a pause after
## each step. The body moves only while a foot swings.
const STEP_CYCLE := 2.6
const SWING := 0.8
const STEP := 0.30


## Which leg is swinging (0 or 1), or -1 in a pause.
func _swing_leg() -> int:
	var t: float = fmod(_state_t, STEP_CYCLE)
	var half: int = 0 if t < STEP_CYCLE * 0.5 else 1
	return half if t - float(half) * STEP_CYCLE * 0.5 < SWING else -1


## Walks it along its own +z while a foot swings, and turns it round at the end of its beat.
func _wade(delta: float) -> void:
	if _swing_leg() < 0:
		return
	if _turn_left > 0.0:
		# Turning on the spot, stepping as it goes, a quarter turn a step or so.
		var turn: float = minf(_turn_left, 1.6 * delta)
		basis = basis * Basis4D.from_zx(turn)
		_turn_left -= turn
		return
	var ahead: Vector4 = global_basis * Vector4(0.0, 0.0, 1.0, 0.0)
	position += ahead * (STEP * 0.5 * size / SWING * delta)
	var out := Vector4(position.x - _home.x, 0.0, position.z - _home.z, 0.0)
	if out.length() > 1.6 and out.dot(ahead) > 0.0:
		_turn_left = PI


# --- Flight -----------------------------------------------------------------------------------

## Along the curve, eased in and out (slow off the water, slow into the landing).
func _fly() -> void:
	var k: float = clampf(_state_t / _flight_len, 0.0, 1.0)
	if state == State.TAKE_OFF and _state_t > 0.9:
		state = State.FLY
	if state == State.FLY and _state_t > _flight_len - 1.5:
		state = State.LAND
	# Nothing moves for the crouch; then off.
	var go: float = clampf((_state_t - 0.25) / maxf(_flight_len - 0.25, 0.01), 0.0, 1.0)
	var s: float = go * go * (3.0 - 2.0 * go)
	position = _bezier(s)
	var ahead: Vector4 = _bezier(minf(s + 0.02, 1.0)) - _bezier(maxf(s - 0.02, 0.0))
	if Vector2(ahead.x, ahead.z).length() > 0.001:
		basis = Basis4D.from_zx(atan2(ahead.x, ahead.z))
	if k >= 1.0:
		position = _path[3]
		_home = position
		_cool = 8.0
		_settle = 0.5
		_foot_z[0] = 0.03 * size
		_foot_z[1] = -0.03 * size
		_enter(State.STAND, _rng.randf_range(4.0, 7.0))


func _bezier(s: float) -> Vector4:
	var a: float = 1.0 - s
	return _path[0] * (a * a * a) + _path[1] * (3.0 * a * a * s) + _path[2] * (3.0 * a * s * s) + _path[3] * (s * s * s)


# --- Posing -----------------------------------------------------------------------------------

func _animate(delta: float) -> void:
	var u: float = size
	var flying: bool = state in [State.TAKE_OFF, State.FLY, State.LAND]
	var pose: Array = POSES["rest"]
	var pose_rate: float = 5.0
	var lean: float = 0.0
	var drop: float = -0.012 * u
	var shift: float = 0.0
	var wings_out: bool = flying or _settle > 0.0
	var beat: float = 0.0
	var wrist: float = 0.0
	var beat_rate: float = 0.0
	# Each leg's goal as world angles, from where its foot is (stance) or set outright.
	var goals: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
	var leg_rate: float = 30.0
	var open: Array[float] = [1.0, 1.0]
	match state:
		State.STAND, State.ALERT:
			pose = POSES["alert"] if state == State.ALERT else POSES["rest"]
			for i in 2:
				_foot_z[i] = move_toward(_foot_z[i], 0.0, 0.15 * delta)
				goals[i] = _stance(i, drop, 0.0)
		State.ONE_LEG:
			pose = POSES["hunch"]
			pose_rate = 2.0
			shift = -0.035 * u
			_foot_z[0] = move_toward(_foot_z[0], 0.0, 0.15 * delta)
			goals[0] = _stance(0, drop, 0.0)
			# The other folded up into the belly feathers, toes closed.
			var tuck := _leg_ik(Vector2(-0.16 * u, 0.07 * u))
			goals[1] = Vector3(tuck.x, tuck.y, tuck.y + 1.2)
			open[1] = 0.0
			leg_rate = 3.0
		State.STALK:
			lean = 0.2
			drop = -0.05 * u
			var t: float = fmod(_state_t, STEP_CYCLE)
			var half: int = 0 if t < STEP_CYCLE * 0.5 else 1
			var local: float = t - float(half) * STEP_CYCLE * 0.5
			var sw: float = clampf(local / SWING, 0.0, 1.0)
			var q: float = STEP * 0.25 * u if _turn_left <= 0.0 else 0.0
			var lift_h: float = 0.13 * u if _turn_left <= 0.0 else 0.07 * u
			for i in 2:
				var swinging: bool = i == half and local < SWING
				if swinging:
					_foot_z[i] = lerpf(-q, q, sw * sw * (3.0 - 2.0 * sw))
					var lift: float = sin(sw * PI) * lift_h
					var g := _leg_ik(Vector2(lift - (HIP.y * u + drop), _foot_z[i] - HIP.z * u))
					# Toes droop and close as the foot comes up, and open as it goes down.
					goals[i] = Vector3(g.x, g.y, 0.8 * sin(sw * PI))
					open[i] = 1.0 - smoothstep(0.0, 0.25, sw) * (1.0 - smoothstep(0.75, 1.0, sw))
				else:
					if i != half and local < SWING:
						_foot_z[i] = lerpf(q, -q, sw)
					goals[i] = _stance(i, drop, 0.0)
			# The gliding head: the neck draws in while the body catches up, and stretches out
			# again while it waits, so the head itself moves smoothly.
			var drawn: float = sw * sw * (3.0 - 2.0 * sw) if local < SWING else 1.0 - smoothstep(SWING, STEP_CYCLE * 0.5, local)
			pose = _blend(POSES["stalk_out"], POSES["stalk_in"], drawn)
			pose_rate = 12.0
		State.STRIKE:
			for i in 2:
				goals[i] = _stance(i, drop, 0.0)
			var t: float = _state_t
			if t < 0.45:
				# Frozen, and coiling back.
				var k: float = smoothstep(0.0, 0.45, t)
				pose = _blend(POSES["stalk_in"], POSES["cocked"], k)
				lean = lerpf(0.2, 0.3, k)
			elif t < 0.56:
				# The stab: fast, and fastest at the end.
				var k: float = (t - 0.45) / 0.11
				pose = _blend(POSES["cocked"], POSES["strike"], k * k)
				lean = lerpf(0.3, 0.45, k)
			elif t < 0.85:
				pose = POSES["strike"]
				lean = 0.45
			elif t < 1.3:
				var k: float = smoothstep(0.85, 1.3, t)
				pose = _blend(POSES["strike"], POSES["rest"], k)
				lean = lerpf(0.45, 0.05, k)
				_fish.visible = _catch
			elif _catch:
				# Bill up and down it goes, in gulps.
				var k: float = smoothstep(1.3, 1.6, t)
				pose = _blend(POSES["rest"], POSES["swallow"], k)
				pose[3] = float(pose[3]) + sin(t * 17.0) * 0.08 * k
				_fish.visible = t < 1.95
			else:
				# Missed: a shake of the head.
				pose = POSES["rest"]
				_head_yaw = sin(t * 26.0) * 0.25 * (1.0 - smoothstep(1.3, 1.7, t))
			pose_rate = 60.0
			drop = -0.03 * u
		State.TAKE_OFF:
			var t: float = _state_t
			pose = POSES["reach"]
			pose_rate = 6.0
			wings_out = true
			if t < 0.25:
				# The crouch: down on bent legs, wings opening up over the back.
				var k: float = smoothstep(0.0, 0.25, t)
				drop = lerpf(-0.012, -0.08, k) * u
				lean = 0.25 * k
				for i in 2:
					goals[i] = _stance(i, drop, 0.0)
				beat = 0.9 * k
			else:
				# The jump, and hard beats with the legs dangling.
				lean = 0.15
				beat_rate = 3.0
				for i in 2:
					goals[i] = Vector3(0.35, 0.75, 0.75 + 1.1)
					open[i] = 0.0
				leg_rate = 10.0
		State.FLY:
			pose = POSES["fly"]
			pose_rate = 2.5
			lean = 0.22
			beat_rate = 2.3
			# Straight out behind, past the tail, toes in line.
			for i in 2:
				goals[i] = Vector3(1.38, 1.42, 1.42 + PI * 0.5)
				open[i] = 0.0
			leg_rate = 3.0
		State.LAND:
			var left: float = _flight_len - _state_t
			pose = POSES["reach"]
			pose_rate = 4.0
			# Legs down and forward, toes spread for the ground.
			for i in 2:
				goals[i] = Vector3(-0.45, -0.25, -0.35)
			leg_rate = 4.0
			if left > 0.6:
				# The glide in: wings held out and bowed, the body tipping up.
				lean = lerpf(0.22, -0.4, smoothstep(1.5, 0.6, left))
				beat = -0.12
				wrist = -0.3
			else:
				# Braking: upright, flapping forward against the way it is going.
				lean = -0.6
				beat_rate = 3.2
	if flying and state != State.LAND:
		# Nose up a little climbing, down a little descending.
		var k: float = clampf(_state_t / _flight_len, 0.0, 1.0)
		var climb: Vector4 = _bezier(minf(k + 0.02, 1.0)) - _bezier(maxf(k - 0.02, 0.0))
		lean -= clampf(climb.y / maxf(Vector2(climb.x, climb.z).length(), 0.01), -1.0, 1.0) * 0.25
	if beat_rate > 0.0:
		_wing_phase = fmod(_wing_phase + beat_rate * delta, 1.0)
		var top: float = 0.65 if state != State.FLY else 0.5
		var bottom: float = -0.85 if state != State.FLY else -0.7
		# The downstroke is the power stroke and the longer part of the beat; the hand bows
		# below the arm through it and folds in a little on the way back up.
		if _wing_phase < 0.6:
			var k: float = _wing_phase / 0.6
			beat = lerpf(top, bottom, k * k * (3.0 - 2.0 * k))
			wrist = -0.22
		else:
			var k: float = (_wing_phase - 0.6) / 0.4
			beat = lerpf(bottom, top, k * k * (3.0 - 2.0 * k))
			wrist = -0.22 - 0.35 * sin(k * PI)
	elif _settle > 0.0 and not flying:
		# Just down: wings held up a moment, then folded.
		beat = 0.35
		wrist = -0.4
	# Pose the neck, the body and the legs.
	var k_pose: float = clampf(delta * pose_rate, 0.0, 1.0)
	for i in 4:
		_pose[i] = lerpf(float(_pose[i]), float(pose[i]), k_pose)
	_apply_neck(_pose)
	var k_body: float = clampf(delta * (20.0 if state == State.STRIKE else 6.0), 0.0, 1.0)
	_lean = lerpf(_lean, lean, k_body)
	_drop = lerpf(_drop, drop, k_body)
	_shift = lerpf(_shift, shift, clampf(delta * 3.0, 0.0, 1.0))
	_apply_body()
	var k_leg: float = clampf(delta * leg_rate, 0.0, 1.0)
	for i in 2:
		_legs[i] = _legs[i].lerp(goals[i], k_leg)
		_toe_open[i] = lerpf(_toe_open[i], open[i], clampf(delta * 8.0, 0.0, 1.0))
	_apply_legs()
	# Wings.
	for i in 2:
		_folded[i].visible = not wings_out
		_spread[i * 2].visible = wings_out
		_spread[i * 2 + 1].visible = wings_out
		var side: float = -1.0 if i == 0 else 1.0
		_wing_pivots[i].basis = Basis4D.from_xy(side * beat)
		_wrists[i].basis = Basis4D.from_xy(side * wrist)


## A foot standing where it is planted, under its hip at [param drop], lifted [param lift].
func _stance(i: int, drop: float, lift: float) -> Vector3:
	var g := _leg_ik(Vector2(lift - (HIP.y * size + drop), _foot_z[i] - HIP.z * size))
	return Vector3(g.x, g.y, 0.0)


## Two-bone IK in the leg's plane: the foot at [param target] from the hip, as (y, z), the
## heel bending backwards as a bird's does. Returns the world angles of the thigh and the
## shank, where a bone at angle a hangs along (y, z) = (-cos a, -sin a): 0 straight down,
## + swung back - the same sense as Basis4D.from_yz.
func _leg_ik(target: Vector2) -> Vector2:
	var l1: float = THIGH * size
	var l2: float = SHANK * size
	var d: float = clampf(target.length(), absf(l1 - l2) + 0.001, l1 + l2 - 0.0005)
	var aim: float = atan2(-target.y, -target.x)
	var bend: float = acos(clampf((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d), -1.0, 1.0))
	var thigh: float = aim + bend
	var heel := Vector2(-cos(thigh), -sin(thigh)) * l1
	var rest: Vector2 = target.normalized() * d - heel
	return Vector2(thigh, atan2(-rest.y, -rest.x))


func _blend(a: Array, b: Array, k: float) -> Array:
	return [lerpf(a[0], b[0], k), lerpf(a[1], b[1], k), lerpf(a[2], b[2], k), lerpf(a[3], b[3], k)]


## The body leans about the hips, so the legs hang from the same place whatever it does.
func _apply_body() -> void:
	if _body == null:
		return
	var turn: Projection = Basis4D.from_yz(_lean)
	var pivot: Vector4 = HIP * size
	_body.basis = turn
	_body.position = pivot - turn * pivot + Vector4(_shift, _drop, 0.0, 0.0)


## World angles back into each pivot's own: every bone's angle is the sum of the pivots above it.
func _apply_legs() -> void:
	for i in mini(_hips.size(), 2):
		var a: Vector3 = _legs[i]
		_hips[i].basis = Basis4D.from_yz(a.x - _lean)
		_heels[i].basis = Basis4D.from_yz(a.y - a.x)
		_feet[i].basis = Basis4D.from_yz(a.z - a.y)
		var toes: Array = _toes[i]
		for k in toes.size():
			(toes[k] as Node4D).basis = Basis4D.from_zx((float(k) - 1.0) * lerpf(0.03, 0.35, _toe_open[i]))


func _apply_neck(pose: Array) -> void:
	for i in mini(_neck.size(), 3):
		_neck[i].basis = Basis4D.from_yz(float(pose[i]))
	if _head != null:
		var looking: bool = state in [State.STAND, State.ONE_LEG, State.ALERT]
		if state != State.STRIKE:
			_head_yaw = lerpf(_head_yaw, _head_yaw_goal if looking else 0.0, 0.08)
		_head.basis = Basis4D.from_zx(_head_yaw) * Basis4D.from_yz(float(pose[3]))
