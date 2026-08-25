extends Node4D
## Contest mode: plays a fixed, authored ContestSequence one pair at a time.
## Advances to the next pair only once every target in the current pair has
## resolved (hit or expired) - never on a fixed global clock, so a slower
## player is never rushed into overlapping pairs and a faster one never sits
## through dead time.
##
## Self-disables in Free mode (see _ready()) - GameMode is the only signal
## available for this, since change_scene_to_file() can't pass parameters.
## Targets are plain gallery_target.tscn instances (same look as free mode's
## red target) with the appropriate movement-archetype script attached as a
## child - composition over one big per-target archetype switch, same
## reasoning as a hazard FSM: the archetype list is clearly going to grow.
##
## try_hit_target() is a third fallback in hitscan_weapon.gd's resolution
## chain (after the free-mode spawner and duck row), and get_active_targets()
## is read by w_targeting.gd/slice_radar.gd the same way they already read
## the other two spawners - contest targets are cyclable and trackable like
## any other target, no special-casing needed on their end.

signal sequence_completed

@export var sequence: ContestSequence

const ContestTargetScene := preload("res://sandbox/shooting_gallery/gallery_target.tscn")
const PopHoldRetract := preload("res://sandbox/shooting_gallery/contest/archetypes/pop_hold_retract.gd")
const VerticalToss := preload("res://sandbox/shooting_gallery/contest/archetypes/vertical_toss.gd")
const ConstantVelocityCrossing := preload("res://sandbox/shooting_gallery/contest/archetypes/constant_velocity_crossing.gd")

var _active_targets: Array = [] # Array of Node4D, currently-live contest targets.
var _current_pair_index: int = -1
var _pair_elapsed_sec: float = 0.0
var _pair_spawned_indices: Array = [] # Indices (within the current pair) already spawned.
var _pair_pending_count: int = 0 # How many of the current pair's targets are still unresolved.


func _ready() -> void:
	set_process(false)
	if GameMode.selected_mode == GameMode.Mode.CONTEST:
		start()


## Public entry point, callable directly regardless of GameMode - _ready()
## uses this for the real automatic case, but tests (or a future "replay")
## need to be able to (re)start a sequence without reloading the scene.
func start() -> void:
	for target in _active_targets:
		if is_instance_valid(target):
			target.queue_free()
	_active_targets = []
	_current_pair_index = -1
	_start_next_pair()


func _process(delta: float) -> void:
	if _current_pair_index < 0 or _current_pair_index >= sequence.pairs.size():
		return
	_pair_elapsed_sec += delta
	var pair: ContestPair = sequence.pairs[_current_pair_index]
	for i in pair.events.size():
		if i in _pair_spawned_indices:
			continue
		if pair.events[i].spawn_delay_sec <= _pair_elapsed_sec:
			_spawn_event(pair.events[i])
			_pair_spawned_indices.append(i)


func _start_next_pair() -> void:
	_current_pair_index += 1
	if sequence == null or _current_pair_index >= sequence.pairs.size():
		set_process(false)
		# Deferred, not emitted directly: this can be reached synchronously
		# from inside try_hit_target(), still one call frame above the
		# caller's own CombatEvents.shot_fired emission for that same shot
		# (see hitscan_weapon.gd). Listeners like the results overlay read
		# the stats HUD's totals when this fires, so it must happen after
		# that final shot's stats update, not before.
		call_deferred("_emit_sequence_completed")
		return
	_pair_elapsed_sec = 0.0
	_pair_spawned_indices = []
	_pair_pending_count = sequence.pairs[_current_pair_index].events.size()
	set_process(true)

func _emit_sequence_completed() -> void:
	sequence_completed.emit()


func _spawn_event(event: ContestSpawnEvent) -> void:
	var target: Node4D = ContestTargetScene.instantiate()
	add_child(target)
	target.position = event.spawn_position

	var behavior := Node.new()
	match event.archetype:
		ContestSpawnEvent.Archetype.POP_HOLD_RETRACT:
			behavior.set_script(PopHoldRetract)
			target.add_child(behavior)
			behavior.hold_duration_sec = event.hold_duration_sec
		ContestSpawnEvent.Archetype.VERTICAL_TOSS:
			behavior.set_script(VerticalToss)
			target.add_child(behavior)
			behavior.flight_duration_sec = event.flight_duration_sec
			behavior.toss_height = event.toss_height
		ContestSpawnEvent.Archetype.CONSTANT_VELOCITY_CROSSING:
			behavior.set_script(ConstantVelocityCrossing)
			target.add_child(behavior)
			behavior.velocity = event.velocity
			behavior.travel_distance = event.travel_distance

	behavior.expired.connect(_on_target_resolved.bind(target))
	_active_targets.append(target)


## Called by hitscan_weapon.gd with the raycast/projectile hit's "body"
## result, after the free-mode spawner and duck row have already been
## checked and missed. Returns whether the hit body was actually one of the
## active contest targets, and resolves it (same path as an expiry) if so.
func try_hit_target(hit_body: Object) -> bool:
	if not _active_targets.has(hit_body):
		return false
	_on_target_resolved(hit_body)
	return true


## Shared by both a hit (try_hit_target) and a timeout (an archetype's
## expired signal) - guarded by array membership, not is_instance_valid(),
## since queue_free() doesn't take effect until end of frame and both could
## fire in the same one (e.g. hit right as an archetype's own timeout ticks
## over); membership is removed immediately, making the second call a no-op
## regardless of exactly when the deferred free actually happens.
func _on_target_resolved(target: Node4D) -> void:
	if not _active_targets.has(target):
		return
	_active_targets.erase(target)
	if is_instance_valid(target):
		target.queue_free()
	_pair_pending_count -= 1
	if _pair_pending_count <= 0:
		set_process(false)
		_start_next_pair()


func get_active_targets() -> Array:
	return _active_targets
