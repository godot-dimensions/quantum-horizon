extends Node
## Motion-lab key bindings: U/I creature size down/up, K/L limb count
## down/up (±1 pair), N/M segments-per-limb down/up, and the SAME digit
## scheme gait_controller.gd's own standalone input already uses elsewhere
## in this project (1=walk 2=trot 4=canter_right 5=canter_left 0=halt
## toggle) - deliberately reusing that exact convention rather than a
## single ambiguous "cycle" key, so every gait is directly, individually
## reachable and the binding is already familiar from the roaming scene.
## 3/hop is deliberately left unbound (motion_lab_creature.gd's own
## FOUR_LEG_GAITS/GENERAL_GAITS no longer include it - hop removed for now
## per explicit request, to keep the gait picture simple) rather than
## renumbering canter onto 3/4, which would break that same shared
## convention instead.
## All confirmed free in this scene (not in project.godot's own [input]
## section, and gait_controller.gd's OWN 0-5 handling is disabled here via
## standalone_input=false, so there's no double-handling). Any change calls
## straight into motion_lab_creature.gd's own setters (which each do a full
## teardown+rebuild for size/limb/segment changes) and refreshes the
## on-screen hint label - same rebuild-string-only-on-change shape as
## gait_controller.gd's own _update_label(), not a per-frame rebuild.

@export var creature_path: NodePath
@export var hint_label_path: NodePath
## Live FPS readout, appended to InfoLabel's own existing text every
## frame (_process, not _physics_process - frame rate is a rendering-
## rate metric, not a physics-tick one). Re-added per explicit request
## after this session's stance-model rework (continuous per-leg
## load_factor, weighted hip-suspension regression) visibly cost more
## than the old hard PLANTED/not filter - this is meant to stay visible
## going forward specifically so further gait-model work doesn't quietly
## trade away performance without anyone noticing.
@export var info_label_path: NodePath

@onready var creature: Node = get_node(creature_path)
@onready var hint_label: Label = get_node(hint_label_path) if not hint_label_path.is_empty() else null
@onready var info_label: Label = get_node(info_label_path) if not info_label_path.is_empty() else null

## Captured once, before any FPS suffix is appended - same reasoning as
## gait_controller.gd's own _base_label_text: lets _process() re-append a
## fresh reading every frame without the label's own original
## description text getting eaten or duplicated.
var _base_info_text: String = ""


func _ready() -> void:
	if info_label != null:
		_base_info_text = info_label.text
	_update_label()


func _process(_delta: float) -> void:
	if info_label != null:
		info_label.text = "%s | FPS: %d" % [_base_info_text, Engine.get_frames_per_second()]


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed:
		return
	var key_event: InputEventKey = event
	match key_event.keycode:
		KEY_U:
			creature.set_body_scale(creature.body_scale - 0.25)
		KEY_I:
			creature.set_body_scale(creature.body_scale + 0.25)
		KEY_K:
			creature.set_limb_count(-1)
		KEY_L:
			creature.set_limb_count(1)
		KEY_N:
			creature.set_segment_count(-1)
		KEY_M:
			creature.set_segment_count(1)
		KEY_1:
			creature.select_gait("walk")
		KEY_2:
			creature.select_gait("trot")
		KEY_4:
			creature.select_gait("canter_right")
		KEY_5:
			creature.select_gait("canter_left")
		KEY_0:
			creature.halted = not creature.halted
		_:
			return
	_update_label()


func _update_label() -> void:
	if hint_label == null:
		return
	var halt_suffix: String = " [HALTED]" if creature.halted else ""
	hint_label.text = "Size: %.2f (U/I)   Limbs: %d (K/L)   Segments/limb: %d (N/M)   Gait: %s%s (1=walk 2=trot 4=canter_r 5=canter_l 0=halt)" % [
		creature.body_scale, creature.limb_count, creature.segment_count, creature.current_gait, halt_suffix,
	]
