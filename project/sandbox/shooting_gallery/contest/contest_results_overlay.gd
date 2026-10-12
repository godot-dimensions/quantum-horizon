extends Control
## Contest mode's end screen - hidden by default, shown the instant
## ContestSequencePlayer finishes its sequence, with a snapshot of the
## existing stats HUD's own hits/misses/accuracy/time rather than tracking a
## second, parallel copy of the same numbers. Free mode never triggers this
## (ContestSequencePlayer.sequence_completed only fires once ITS own
## sequence finishes, which never starts at all outside contest mode).

@onready var contest_player: Node4D = $"../FlatPlane/ContestSequencePlayer"
@onready var combat_stats_hud: Control = $"../CombatStatsHud"
@onready var summary_label: Label = $Panel/VBoxContainer/SummaryLabel
@onready var menu_button: Button = $Panel/VBoxContainer/MenuButton


func _ready() -> void:
	visible = false
	contest_player.sequence_completed.connect(_on_sequence_completed)
	menu_button.pressed.connect(_on_menu_pressed)


func _on_sequence_completed() -> void:
	var hits: int = combat_stats_hud._hits
	var misses: int = combat_stats_hud._misses
	var total_fired: int = hits + misses
	var accuracy: float = (100.0 * hits / total_fired) if total_fired > 0 else 0.0
	summary_label.text = "Contest Complete!\n\nHits: %d\nMisses: %d\nAccuracy: %.0f%%\nTime: %.1fs" % [
		hits, misses, accuracy, combat_stats_hud._elapsed_sec,
	]
	# Gameplay scenes capture the mouse for look-around - needed here so the
	# return-to-menu button is actually clickable, same reasoning as the
	# main menu's own visibility fix.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	visible = true


func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://menu/main_menu.tscn")
