extends Node
## Walk cycle for rigged_creature.tscn, driven through the project's own FABRIK solver.
##
## THIS SCRIPT ONLY MOVES FOOT TARGETS. Every leg carries an ik_chain_controller.gd,
## which self-solves in _physics_process at priority 1; this driver runs at priority -1
## so the targets for the frame are in place before any chain reads them. That ordering
## is the same one gait_controller.gd sets for itself, and for the same reason: a leg's
## solve must see THIS frame's target, not scene-tree declaration order's guess at it.
##
## It replaces an earlier hand-rolled two-bone solve. That version worked, but the
## project's FABRIK was written specifically because closed-form two-bone solving had
## measured failure modes - a sustained multi-frame tracking residual growing to ~2.7
## units, confirmed uncorrelated with knee-branch or pole-vector flips, so a genuine
## convergence-rate problem rather than a bug either could patch. Using the real solver
## also brings hinge limits and plane-alignment twist, which a bespoke solve would have
## had to grow on its own.
##
## WHAT IS REUSED FROM THE EXISTING SYSTEM: the gait numbers and the foot-path shape.
## duty_factor and the phase offsets come from gait_controller.gd PRESETS["walk"],
## including its warning that the offsets are NOT ascending - a leg fires at
## phase_progress = duty_factor - offset, so ascending offsets give the wrong footfall
## order. The stance/swing split and raised-apex Bezier are strider_walker's shape.
##
## gait_controller.gd itself is still not instantiated: it is quadruped-shaped (a
## four-element phase_offsets) and reads `halted` off limb_prototype_body.gd, neither of
## which fits an eight-legged 4D creature. Its numbers travel; its coupling does not.

@export var creature_path: NodePath = NodePath("../Creature")

@export var stride_length: float = 1.1
@export var step_height: float = 0.42
@export var body_bob: float = 0.09

## Set from the active preset rather than edited directly - see apply_preset().
var period_seconds: float = 2.2
var duty_factor: float = 0.6

## Which gait to start in, and which one the number keys switch away from.
@export_enum("walk", "trot", "hop", "canter_right", "canter_left") var preset: String = "walk"

## Number-key switching, the same 1-5 plus 0 mapping gait_controller.gd uses, so the
## two behave alike for anyone who has driven that one.
@export var standalone_input: bool = true

## Halted means the gait clock stops and the feet ease home; idle_layer.gd then has the
## creature to itself. It is a held state, not a pause - phase resets so the next gait
## starts from the top rather than mid-stride.
var halted: bool = false

## The two W copies of each leg are the SAME leg displaced along the axis you cannot
## see, so by default they step together. Nonzero puts the ana and kata halves out of
## phase - a gait with no three-dimensional equivalent.
@export_range(0.0, 0.5, 0.01) var w_pair_phase_offset: float = 0.0

@export var show_label: bool = true

## Lifted verbatim from gait_controller.gd's own PRESETS, offsets ordered FL, FR, BL,
## BR. Copied rather than imported because that script is quadruped-shaped and reads
## `halted` off limb_prototype_body.gd; these are just the numbers, which are the part
## that took tuning.
##
## WALK'S OFFSETS ARE NOT ASCENDING, and that is deliberate: a leg fires at
## phase_progress = duty_factor - offset, so the "obvious" [0, 0.25, 0.5, 0.75] gives a
## footfall order matching no real quadruped. That file confirmed it with a dedicated
## runner; this inherits the finding rather than rediscovering it.
const PRESETS := {
	"walk": {"period": 4.0, "duty": 0.6, "offsets": [0.25, 0.75, 0.5, 0.0]},
	"trot": {"period": 1.2, "duty": 0.5, "offsets": [0.0, 0.5, 0.5, 0.0]},
	"hop": {"period": 1.0, "duty": 0.5, "offsets": [0.0, 0.0, 0.0, 0.0]},
	"canter_right": {"period": 2.2, "duty": 0.4, "offsets": [0.0, 0.35, 0.35, 0.65]},
	"canter_left": {"period": 2.2, "duty": 0.4, "offsets": [0.35, 0.0, 0.65, 0.35]},
}

## Key order matches gait_controller.gd's label: 1=walk 2=trot 3=hop 4=canter_r 5=canter_l.
const KEY_PRESETS: PackedStringArray = ["walk", "trot", "hop", "canter_right", "canter_left"]

## Added by idle_layer.gd while halted, so breathing and the gait bob share one writer
## instead of fighting over the body's height.
var breath_offset: float = 0.0

## Per-leg offsets, keyed by tag ("HindLA" and so on), added to whatever the gait asks
## for. head_attention.gd uses it to brace a leg out while the creature twists round to
## look behind itself. Empty by default, so it costs nothing when unused.
var target_offsets: Dictionary = {}

var _creature: Node4D = null
var _body: Node4D = null
var _body_rest_y: float = 0.0
var _feet: Array[Dictionary] = []
## Read by spine_neck_solver.gd, which needs the same cycle the feet are on. Public
## rather than passed in, matching how gait_controller.gd exposes phase_progress.
var phase: float = 0.0
var _label: Label = null


func _ready() -> void:
	# Ahead of ik_chain_controller.gd's own priority 1, so each chain solves against a
	# target this driver has already placed for the frame.
	process_physics_priority = -1
	_creature = get_node_or_null(creature_path) as Node4D
	if _creature == null:
		push_warning("IKGaitDriver: creature_path does not resolve - nothing to drive.")
		set_physics_process(false)
		return
	_body = _creature.get_node_or_null("Barrel") as Node4D
	if _body != null:
		_body_rest_y = _body.position.y
	_collect_feet()
	apply_preset(preset)
	if _feet.is_empty():
		push_warning("IKGaitDriver: found no foot targets - expected names like ForeLAFootTarget.")
		set_physics_process(false)
		return
	if show_label:
		var layer := CanvasLayer.new()
		add_child(layer)
		_label = Label.new()
		_label.position = Vector2(14, 64)
		_label.add_theme_font_size_override("font_size", 19)
		_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
		_label.add_theme_constant_override("shadow_offset_x", 1)
		_label.add_theme_constant_override("shadow_offset_y", 1)
		layer.add_child(_label)


## Switches gait, recomputing every leg's phase offset. Safe to call at any time: the
## cycle position itself is left alone, so a leg that was mid-swing stays mid-swing and
## the change reads as a transition rather than a snap.
func apply_preset(preset_name: String) -> void:
	if not PRESETS.has(preset_name):
		push_warning("IKGaitDriver: no such gait '%s'." % preset_name)
		return
	preset = preset_name
	var data: Dictionary = PRESETS[preset_name]
	period_seconds = float(data["period"])
	duty_factor = float(data["duty"])
	halted = false
	var offsets: Array = data["offsets"]
	for foot in _feet:
		var tag: String = foot["tag"]
		# tag reads like "ForeLA": station, then side, then which W half.
		var index: int = (0 if tag.begins_with("Fore") else 2) + (0 if tag[4] == "L" else 1)
		var value: float = float(offsets[index])
		if tag[5] == "K":
			value = fposmod(value + w_pair_phase_offset, 1.0)
		foot["phase"] = value


func _input(event: InputEvent) -> void:
	if not standalone_input or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key: int = (event as InputEventKey).keycode
	if key == KEY_0:
		halted = true
		phase = 0.0
		return
	var index: int = key - KEY_1
	if index >= 0 and index < KEY_PRESETS.size():
		apply_preset(KEY_PRESETS[index])


## Rest positions are captured ONCE. Every frame's target is expressed as an offset
## from where the creature stands, which is why nothing here needs to know the leg's
## proportions - the solver does.
func _collect_feet() -> void:
	for station in ["Fore", "Hind"]:
		for side in ["L", "R"]:
			for w_half in ["A", "K"]:
				var tag: String = "%s%s%s" % [station, side, w_half]
				var target: Node4D = _creature.get_node_or_null("%sFootTarget" % tag) as Node4D
				if target == null:
					continue
				# Phase is filled in by apply_preset(), called right after this.
				_feet.append({"target": target, "rest": target.position, "phase": 0.0, "tag": tag})


func _physics_process(delta: float) -> void:
	if halted:
		# Ease the feet home rather than cutting to rest, so stopping looks like
		# stopping. The IK keeps solving throughout, so the legs straighten smoothly.
		for foot in _feet:
			var target: Node4D = foot["target"]
			var rest_with_brace: Vector4 = foot["rest"] + _offset_for(foot["tag"])
			target.position = target.position.lerp(rest_with_brace, clampf(delta * 6.0, 0.0, 1.0))
	else:
		phase = fposmod(phase + delta / maxf(period_seconds, 0.01), 1.0)
		for foot in _feet:
			var local_phase: float = fposmod(phase + float(foot["phase"]), 1.0)
			(foot["target"] as Node4D).position = _foot_position(
				foot["rest"], local_phase) + _offset_for(foot["tag"])
	# Twice per cycle, once per diagonal pair. A rig's position is a node transform, so
	# this costs nothing - the same reason the whole creature was split into rigs.
	# breath_offset is the idle layer's contribution, added here so the body's height has
	# exactly one writer.
	if _body != null:
		var bob: float = 0.0 if halted else sin(phase * TAU * 2.0) * body_bob
		_body.position.y = _body_rest_y + bob + breath_offset
	if _label != null:
		_label.text = "%s   phase %.2f   duty %.2f   %d legs   (1-5 gaits, 0 idle)" % [
			"IDLE" if halted else preset, phase, duty_factor, _feet.size()]


func _offset_for(tag: String) -> Vector4:
	return target_offsets.get(tag, Vector4.ZERO)


## STANCE (local_phase < duty): the foot is planted, so on a treadmill it slides
## backward - the ground moving under a creature that stays put.
## SWING: a quadratic Bezier from lift-off to landing with a raised apex, so the leg
## arcs over rather than dragging. Shape from strider_walker._foot_position().
##
## Deliberately a closed-form curve computed fresh each frame: ik_chain_controller's own
## header records that it removed target-stepping precisely because a curve like this
## never jumps, so smoothing it again just adds a second lag to mistune.
func _foot_position(rest: Vector4, local_phase: float) -> Vector4:
	var forward := Vector4(-1.0, 0.0, 0.0, 0.0)  # the creature faces -X
	var lift_off: Vector4 = rest - forward * (stride_length * 0.5)
	var landing: Vector4 = rest + forward * (stride_length * 0.5)
	if local_phase < duty_factor:
		var t: float = local_phase / maxf(duty_factor, 0.0001)
		return landing.lerp(lift_off, t)
	var s: float = (local_phase - duty_factor) / maxf(1.0 - duty_factor, 0.0001)
	var apex: Vector4 = rest + Vector4(0.0, step_height, 0.0, 0.0)
	return lift_off.lerp(apex, s).lerp(apex.lerp(landing, s), s)
