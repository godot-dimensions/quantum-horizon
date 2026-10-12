extends Node
## Routes the SAME number-key gait bindings gait_controller.gd already
## established (1=walk, 2=trot, 3=hop, 4=canter_right, 5=canter_left,
## 0=halt toggle) to whichever ONE creature the player is nearest to or
## looking at, instead of every creature in the scene responding to the
## same key press at once. Each creature's own GaitController has
## standalone_input=false (see that field's own comment) specifically so
## this router is the ONLY thing calling apply_preset()/toggling
## body.halted - no double-handling.
##
## "Nearest to OR looking at": prefer the closest creature that's also
## within a forward-facing cone from the player's own view direction (a
## real "which one are they looking at" heuristic, not just proximity);
## fall back to plain nearest-by-distance if the player isn't currently
## facing any of them (e.g. looking at the sky, or walking between
## clusters) - matching the "OR" in the request literally rather than
## picking only one interpretation.

@export var player_path: NodePath
@export var player_head_path: NodePath # Node4D whose -global_basis.z is "forward" - same convention already used by area_capture_controller.gd's own aim-forward raycast.
@export var creature_container_path: NodePath # Any Node - every child with a "GaitController" and "Body" child is treated as one creature.
@export var looking_at_cos_threshold: float = 0.5 # cos(60 degrees) - "within a 60-degree forward cone."
@export var info_label_path: NodePath

@onready var player: Node4D = get_node(player_path)
@onready var player_head: Node4D = get_node(player_head_path)
@onready var info_label: Label = get_node(info_label_path) if not info_label_path.is_empty() else null

var _creatures: Array = []


func _ready() -> void:
	var container: Node = get_node(creature_container_path)
	for child in container.get_children():
		if child.has_node("GaitController") and child.has_node("Body"):
			_creatures.append(child)


func _process(_delta: float) -> void:
	if info_label == null:
		return
	var target: Node = _find_target_creature()
	if target == null:
		info_label.text = "No creature in range."
		return
	var body: Node4D = target.get_node("Body")
	var gait: Node = target.get_node("GaitController")
	var halt_suffix: String = " [HALTED]" if body.halted else ""
	info_label.text = "Targeting: %s (%s) | Gait: %s%s (1=walk 2=trot 3=hop 4=canter_r 5=canter_l 0=halt)" % [
		body.get_node("BodyPOI").display_name, body.creature_class, gait.preset, halt_suffix,
	]


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed:
		return
	var target: Node = _find_target_creature()
	if target == null:
		return
	var gait: Node = target.get_node("GaitController")
	var body: Node4D = target.get_node("Body")
	var key_event: InputEventKey = event
	if key_event.keycode == KEY_1:
		gait.apply_preset("walk")
	elif key_event.keycode == KEY_2:
		gait.apply_preset("trot")
	elif key_event.keycode == KEY_3:
		gait.apply_preset("hop")
	elif key_event.keycode == KEY_4:
		gait.apply_preset("canter_right")
	elif key_event.keycode == KEY_5:
		gait.apply_preset("canter_left")
	elif key_event.keycode == KEY_0:
		body.halted = not body.halted


## Among creatures within looking_at_cos_threshold of the player's forward
## direction, the nearest one; if none are within that cone, the nearest
## creature overall instead.
func _find_target_creature() -> Node:
	var player_pos: Vector4 = player.global_position
	var forward: Vector4 = -player_head.global_basis.z

	var nearest_creature: Node = null
	var nearest_distance: float = INF
	var looked_at_creature: Node = null
	var looked_at_distance: float = INF

	for creature in _creatures:
		var body: Node4D = creature.get_node("Body")
		var to_creature: Vector4 = body.global_position - player_pos
		var distance: float = to_creature.length()
		if distance < 0.001:
			continue

		if distance < nearest_distance:
			nearest_distance = distance
			nearest_creature = creature

		var cos_angle: float = to_creature.normalized().dot(forward)
		if cos_angle >= looking_at_cos_threshold and distance < looked_at_distance:
			looked_at_distance = distance
			looked_at_creature = creature

	return looked_at_creature if looked_at_creature != null else nearest_creature
