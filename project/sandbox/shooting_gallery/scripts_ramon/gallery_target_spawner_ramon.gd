extends Node4D
## Ramon-only fork of gallery_target_spawner.gd, identical except for the
## TargetScene preload below - keeps this branch's target-shape experiments
## (see gallery_target_ramon.tscn) from also changing the shared
## shooting_gallery.tscn, since that scene's spawner still points at the
## original gallery_target_spawner.gd/gallery_target.tscn.

const TargetScene := preload("res://sandbox/shooting_gallery/gallery_target_ramon.tscn")

const X_RANGE := 8.0 # Widened alongside the blue floor's x extent.
const Z_RANGE := 4.0
const W_RANGE := 4.0
const HOVER_Y_MIN := 1.0
const HOVER_Y_MAX := 2.0

@onready var time_label: Label = $TimeLabel
@onready var result_label: Label = $ResultLabel

var _catch_count: int = 0
var _total_elapsed_sec: float = 0.0
var _spawn_time_msec: int = 0
var _current_target: Node4D = null
var _stopwatch_visible: bool = false

func _ready() -> void:
	time_label.visible = false
	result_label.visible = false
	_spawn_new_target()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_stopwatch_display"):
		_stopwatch_visible = not _stopwatch_visible
		time_label.visible = _stopwatch_visible

func _process(_delta: float) -> void:
	if _stopwatch_visible and _current_target != null:
		var elapsed: float = (Time.get_ticks_msec() - _spawn_time_msec) / 1000.0
		var average: float = (_total_elapsed_sec / _catch_count) if _catch_count > 0 else 0.0
		time_label.text = "Elapsed: %.1fs | Avg: %.1fs (%d catches)" % [elapsed, average, _catch_count]

func try_catch_target(hit_body: Object) -> bool:
	if _current_target == null or hit_body != _current_target:
		return false
	_on_catch()
	return true

func _on_catch() -> void:
	var elapsed: float = (Time.get_ticks_msec() - _spawn_time_msec) / 1000.0
	_catch_count += 1
	_total_elapsed_sec += elapsed
	var average: float = _total_elapsed_sec / _catch_count
	print("Catch #%d: %.2fs (running average: %.2fs)" % [_catch_count, elapsed, average])
	result_label.text = "Last catch: %.2fs | Avg: %.2fs (%d catches)" % [elapsed, average, _catch_count]
	result_label.visible = true
	_current_target.queue_free()
	_spawn_new_target()

func _spawn_new_target() -> void:
	var target: Node4D = TargetScene.instantiate()
	add_child(target)
	target.position = _random_spawn_position()
	_current_target = target
	_spawn_time_msec = Time.get_ticks_msec()

func _random_spawn_position() -> Vector4:
	return Vector4(
		randf_range(-X_RANGE, X_RANGE),
		randf_range(HOVER_Y_MIN, HOVER_Y_MAX),
		randf_range(-Z_RANGE, Z_RANGE),
		randf_range(-W_RANGE, W_RANGE),
	)
