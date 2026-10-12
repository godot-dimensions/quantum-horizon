extends Node
class_name AscentCheckpoints4D

## Checkpoints, falls and telemetry for THE 4D ASCENT.
##
## The brief asks for a checkpoint to restore "player transform, slice basis,
## obstacle states and moving-platform phase". Phase 1 has no obstacle states and
## no moving platforms yet, so this restores the two that exist - and restoring
## the SLICE BASIS matters as much as the position. Respawning someone at the
## right place in the wrong slice would drop them straight back through the
## reset plane, which reads as the checkpoint being broken rather than as a
## rotation they still had applied.
##
## Not a @tool script. It only ever runs during play, and connecting physics
## signals in the editor would fire callbacks while authoring.

## Emitted whenever the player is returned to a checkpoint, so a future HUD can
## react without polling.
signal player_reset(checkpoint_id: String, falls: int)

## Emitted the first time each checkpoint is reached.
signal checkpoint_reached(checkpoint_id: String)

@export var player_path: NodePath = ^"../Player"

## Where the generated checkpoint and reset volumes live.
@export var course_path: NodePath = ^"../Course"

## Printed to the console on every reset. Off once there is a real HUD.
@export var log_telemetry: bool = true

var _player: CharacterBody4D = null
var _spawn_position: Vector4 = Vector4()
var _spawn_basis: Projection = Projection()
var _current_checkpoint: String = "spawn"
var _reached: Dictionary = {}

# Telemetry the brief asks to instrument: time, falls, slice attempts, retries.
var _falls: int = 0
var _started_at_ms: int = 0


func _ready() -> void:
	_player = get_node_or_null(player_path) as CharacterBody4D
	if _player == null:
		push_warning("AscentCheckpoints4D: no CharacterBody4D at '%s'." % str(player_path))
		return
	_spawn_position = _player.position
	_spawn_basis = _player.basis
	_started_at_ms = Time.get_ticks_msec()

	var course := get_node_or_null(course_path)
	if course == null:
		push_warning("AscentCheckpoints4D: no course at '%s'." % str(course_path))
		return
	_connect_volumes(course)


## The builder regenerates its Area4Ds on every rebuild, so they are found by
## walking the tree at _ready rather than wired up in the scene file - a
## NodePath to a generated node would break the moment anything is re-tuned.
func _connect_volumes(course: Node) -> void:
	for child in course.get_children():
		var area := child as Area4D
		if area == null:
			continue
		var area_name := String(area.name)
		if area_name.begins_with("Checkpoint_"):
			var id := area_name.trim_prefix("Checkpoint_")
			area.body_entered_self.connect(_on_checkpoint_entered.bind(id))
		elif area_name.begins_with("TierReset_"):
			area.body_entered_self.connect(_on_reset_entered)


func _on_checkpoint_entered(body: PhysicsBody4D, checkpoint_id: String) -> void:
	if body != _player:
		return
	if _current_checkpoint == checkpoint_id:
		return
	_current_checkpoint = checkpoint_id
	# The basis is captured as well as the position, so a player who reaches a
	# checkpoint mid-rotation is returned to the slice they actually arrived in
	# rather than to an arbitrary home slice they never chose.
	_spawn_position = _player.position
	_spawn_basis = _player.basis
	if not _reached.has(checkpoint_id):
		_reached[checkpoint_id] = true
		checkpoint_reached.emit(checkpoint_id)
		if log_telemetry:
			print("ASCENT: checkpoint %s reached at %.1f s" % [checkpoint_id, _elapsed_seconds()])


func _on_reset_entered(body: PhysicsBody4D) -> void:
	if body != _player:
		return
	_falls += 1
	# DEFERRED, not direct. This fires from inside the physics step, while the
	# solver is still iterating over the body being moved; the Demo hub learned
	# the same lesson the hard way with change_scene_to_packed.
	_respawn.call_deferred()


func _respawn() -> void:
	if _player == null:
		return
	_player.position = _spawn_position
	_player.basis = _spawn_basis
	_player.linear_velocity = Vector4()
	player_reset.emit(_current_checkpoint, _falls)
	if log_telemetry:
		print("ASCENT: fall %d, returned to '%s' at %.1f s" % [_falls, _current_checkpoint, _elapsed_seconds()])


func _elapsed_seconds() -> float:
	return float(Time.get_ticks_msec() - _started_at_ms) / 1000.0


## Snapshot for a future HUD or an end-of-run summary.
func get_telemetry() -> Dictionary:
	return {
		"elapsed_seconds": _elapsed_seconds(),
		"falls": _falls,
		"checkpoint": _current_checkpoint,
		"checkpoints_reached": _reached.keys(),
	}
