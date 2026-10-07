extends Node4D

## The W tools' test room: the Creation Lab's floor, sky and light (LabKit/lab_room_4d.gd), its player
## (kit/kit_player.gd: walk, hold the right mouse button and drag to turn the slice through W, R back to
## the flat slice), and a readout of what the slice cuts: the slice's turn, the plants it cuts within 40 m
## (with their trunks, crowns alone), and the W tools' own numbers. Built as the scene starts, so the scene
## file holds only what is being tested (exploder_lab.tscn: a hand-placed wood; optimiser_lab.tscn: units).
## P steps every W Exploder in the room through its presets (exploder/presets, and "off"), planted again.

const Room := preload("res://ramon/CreationLab/LabKit/lab_room_4d.gd")
const KitPlayer := preload("res://ramon/CreationLab/kit/kit_player.gd")
const SliceAngles := preload("res://ramon/chickenpen/scripts/slice_angles_4d.gd")
const PRESETS := "res://ramon/WTools/exploder/presets/"

@export var ground: Vector4 = Vector4(260.0, 1.0, 260.0, 260.0)
@export var player_at: Vector4 = Vector4(0.0, 1.0, 12.0, 0.0)
@export var player_yaw_degrees: float = 0.0
@export var readout: bool = true

var player: CharacterBody4D
var rig: Node4D
var _label: Label
var _preset_names: Array = []
var _preset_at: int = -1


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var room := Node4D.new()
	room.name = "Room"
	room.set_script(Room)
	room.set("ground_size", ground)
	add_child(room)
	player = KitPlayer.make()
	player.name = "Player"
	add_child(player)
	player.global_position = player_at
	rig = player.get_node_or_null("CameraRig") as Node4D
	if rig != null:
		SliceAngles.tilt(rig, 0.0, 0.0, deg_to_rad(player_yaw_degrees))
	if readout:
		var layer := CanvasLayer.new()
		add_child(layer)
		_label = Label.new()
		_label.position = Vector2(24, 20)
		_label.add_theme_font_size_override("font_size", 18)
		_label.add_theme_color_override("font_color", Color(0.05, 0.08, 0.14))
		layer.add_child(_label)


func _process(_d: float) -> void:
	if _label == null or rig == null:
		return
	var a: Vector3 = SliceAngles.angles(rig.basis)
	var lines := PackedStringArray()
	if _preset_at >= 0:
		lines.append("preset  %s   (P: next)" % _preset_names[_preset_at])
	lines.append("slice turned  xw %.0f   zw %.0f    W %.2f" % [rad_to_deg(a.x), rad_to_deg(a.y), player.global_position.w])
	for tool in find_children("*", "Node4D", true, false):
		if "echo_count" in tool and "cull_usec" in tool:
			lines.append("%s: placed %d, copies %d, refused %d, made in %d ms, cull %d us" % [tool.name, int(tool.get("placed")),
				int(tool.get("echo_count")), int(tool.get("refused")), int(tool.get("build_msec")), int(tool.get("cull_usec"))])
	_label.text = "\n".join(lines)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or key.keycode != KEY_P:
		return
	if _preset_names.is_empty():
		_preset_names = ["off"]
		for f in DirAccess.get_files_at(PRESETS):
			if f.ends_with(".tres"):
				_preset_names.append(f.get_basename())
	_preset_at = (_preset_at + 1) % _preset_names.size()
	var pick: String = _preset_names[_preset_at]
	for tool in find_children("*", "Node4D", true, false):
		if tool.has_method("replant"):
			tool.set("enabled", pick != "off")
			if pick != "off":
				tool.set("preset", load(PRESETS + pick + ".tres"))
			tool.call("replant")
	get_viewport().set_input_as_handled()
