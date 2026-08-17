extends Area4D
## Prototype for the hub's still-unbuilt gate interaction model (see the
## "Next" section of project/ramon/Demo/README.md): Option A, requiring the
## player to actually cross the gate's full depth rather than just touch the
## threshold pad, combined with Option C, a short Rotor4D-driven spin of the
## player's own basis on commit instead of a hard scene cut.
##
## Sibling of a HubGate4D instance, sized to its aperture. Matches that
## script's own convention that local -Z points radially outward ("through"
## the gate, away from the hub) - see hub_gate_4d.gd's _build_gate note.
## Fires only when the player EXITS through the far (-Z) face, not when they
## walk up to the frame and back out the way they came.

@export var target_scene: PackedScene
@export var gate_name: String = "Demo"
@export_range(0.1, 3.0, 0.05, "suffix:s") var spin_duration: float = 0.6
@export var spin_turns_xw: float = 1.0 ## Full turns in the xw plane over the spin.
@export var spin_turns_yz: float = 0.35 ## Full turns in the yz plane over the spin.

var _player: CharacterBody4D
var _transitioning: bool = false
var _spin_elapsed: float = 0.0
var _start_basis: Projection


func _ready() -> void:
	body_entered_self.connect(_on_body_entered_self)
	body_exited_self.connect(_on_body_exited_self)


func _on_body_entered_self(body: PhysicsBody4D) -> void:
	if body is CharacterBody4D:
		_player = body


## Only the far-side exit counts as "went through" - a player who steps in
## and backs out again exits on the near (+Z) side instead and nothing fires.
func _on_body_exited_self(body: PhysicsBody4D) -> void:
	if _transitioning or not (body is CharacterBody4D):
		return
	var local_z: float = (body.global_position - global_position).dot(global_basis.z.normalized())
	if local_z < 0.0:
		_begin_transition(body)


func _begin_transition(body: CharacterBody4D) -> void:
	_transitioning = true
	_spin_elapsed = 0.0
	_player = body
	_start_basis = body.basis
	body.linear_velocity = Vector4.ZERO
	body.set_physics_process(false)
	body.set_process_input(false)
	print("GateTransitionProbe: entering '%s'" % gate_name)


func _process(delta: float) -> void:
	if not _transitioning:
		return
	_spin_elapsed += delta
	var t: float = clampf(_spin_elapsed / spin_duration, 0.0, 1.0)
	var eased: float = smoothstep(0.0, 1.0, t)
	var rotor: Rotor4D = Rotor4D.from_xw(spin_turns_xw * TAU * eased).rotate_rotor(Rotor4D.from_yz(spin_turns_yz * TAU * eased))
	_player.basis = Basis4D.orthonormalized(Projection(
		rotor.rotate_vector(_start_basis.x),
		rotor.rotate_vector(_start_basis.y),
		rotor.rotate_vector(_start_basis.z),
		rotor.rotate_vector(_start_basis.w),
	))
	if t >= 1.0:
		_finish_transition()


func _finish_transition() -> void:
	if target_scene:
		get_tree().change_scene_to_packed(target_scene)
		return
	# No destination wired up (probe mode) - undo the spin's orientation and
	# hand control back where the player ended up, past the gate.
	_player.basis = _start_basis
	_player.linear_velocity = Vector4.ZERO
	_player.set_physics_process(true)
	_player.set_process_input(true)
	_transitioning = false
	print("GateTransitionProbe: no target_scene set, handing control back.")
