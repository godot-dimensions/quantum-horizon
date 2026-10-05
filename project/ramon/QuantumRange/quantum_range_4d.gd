@tool
extends Node4D

## THE QUANTUM RANGE, final (Ramon, 5 Oct 2026: "Make a new tscn that signifies you're working on a
## final of it"; the plan and its 75 steps are follow_up/quantum_range_final.md). The consolidated
## shooting range: Trym's gallery and Ramon's _ramon fork, their working mechanics kept (real 4D
## raycasts, the W radar, the alignment glow, the charge shot), rebuilt around experiments with rules,
## target roles and the lab look. Neither old range is changed.
##
## THIS NODE: the range's palette on the kit's swatches while it is open (scripts/range_style.gd), the
## light, and (as the plan's steps land) the player, the HUD and the director.
##
## NO class_name (engine_gotchas.md).

const Style := preload("res://ramon/QuantumRange/scripts/range_style.gd")
const Layout := preload("res://ramon/QuantumRange/scripts/range_layout.gd")
const PlayerScript := preload("res://ramon/QuantumRange/scripts/range_player_4d.gd")
const Gun := preload("res://ramon/QuantumRange/scripts/range_gun_4d.gd")
const ReturnButton := preload("res://ramon/Demo/return_button.tscn")
const WayHome := preload("res://ramon/QuantumRange/scripts/range_way_home_4d.gd")
const Weapon := preload("res://ramon/QuantumRange/scripts/range_weapon_4d.gd")
const Hud := preload("res://ramon/QuantumRange/scripts/range_hud.gd")

var player: CharacterBody4D
var gun: Node4D
var weapon: Node
var hud: Control
## Where targets and effects live (everything spawned during play).
var targets: Node4D
var fx: Node4D


func _enter_tree() -> void:
	# Before any child builds: the kit's swatches in the range's colours, put back when it closes.
	Style.remember()
	Style.apply()
	var light: Node = get_node_or_null("Light")
	if light != null:
		light.set("mood_overrides", {"bright": Style.LIGHT.duplicate(true), "dark": Style.LIGHT.duplicate(true)})


func _exit_tree() -> void:
	Style.restore()


func _ready() -> void:
	var light: Node = get_node_or_null("Light")
	if light != null:
		light.call("set_mood", "bright", true, false)
	_place_wings()
	if Engine.is_editor_hint():
		return
	player = PlayerScript.make()
	add_child(player)
	player.call("place", Layout.SPAWN, 0.0)
	player.set("min_z", Layout.LINE_Z + Layout.COUNTER.z * 0.5 + 0.3)
	player.set("w_limit", Layout.W_LIMIT)
	gun = Node4D.new()
	gun.name = "Gun"
	gun.set_script(Gun)
	player.get_node("Head/Camera").add_child(gun)
	targets = Node4D.new()
	targets.name = "Targets"
	add_child(targets)
	fx = Node4D.new()
	fx.name = "Fx"
	add_child(fx)
	weapon = Node.new()
	weapon.name = "Weapon"
	weapon.set_script(Weapon)
	weapon.set("player", player)
	weapon.set("camera", player.get("camera"))
	weapon.set("gun", gun)
	weapon.set("fx_parent", fx)
	add_child(weapon)
	var layer := CanvasLayer.new()
	layer.name = "HUD"
	add_child(layer)
	hud = Control.new()
	hud.name = "Hud"
	hud.set_script(Hud)
	hud.set("player", player)
	hud.set("weapon", weapon)
	hud.set("w_limit", Layout.W_LIMIT)
	layer.add_child(hud)
	# The shared back-to-menu prompt (H), and the pen's way home when the pen sent you here.
	var rb: Node = ReturnButton.instantiate()
	rb.name = "ReturnButton"
	add_child(rb)
	var home := Node.new()
	home.name = "WayHome"
	home.set_script(WayHome)
	add_child(home)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	# Escape lets the mouse go (the menu, when it launched the range, takes Escape before this does);
	# a click takes it back.
	var k := event as InputEventKey
	if k != null and k.pressed and not k.echo and k.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_viewport().set_input_as_handled()
		return
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()


## The two wings stand where the layout says, each turned to face the firing position.
func _place_wings() -> void:
	for pair in [["ExplainerWing", Layout.WING], ["MetricsWing", Vector2(-Layout.WING.x, Layout.WING.y)]]:
		var wing: Node4D = get_node_or_null(String(pair[0])) as Node4D
		if wing == null:
			continue
		var at: Vector2 = pair[1]
		wing.position = Vector4(at.x, 0.0, at.y, 0.0)
		wing.basis = Basis4D.from_zx(Layout.wing_yaw(at))
