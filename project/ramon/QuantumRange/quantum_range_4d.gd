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
const Director := preload("res://ramon/QuantumRange/scripts/range_director_4d.gd")
const Console := preload("res://ramon/QuantumRange/scripts/range_console_4d.gd")
const Sfx := preload("res://ramon/QuantumRange/scripts/range_sfx.gd")
const PanelSource := preload("res://ramon/QuantumRange/scripts/range_panel_source.gd")
const DevPanel := preload("res://ramon/QuantumRange/scripts/range_dev_panel.gd")

var player: CharacterBody4D
var gun: Node4D
var weapon: Node
var hud: Control
## Where targets and effects live (everything spawned during play).
var targets: Node4D
var fx: Node4D
var props: Node4D
var director: Node
var console: Node4D
var sfx: Node
var panel_source: Node
var dev_panel: PanelContainer
## The tuning in force (F1; scripts/range_dev_panel.gd).
var tuning: Dictionary = {}
## The room holds still when you turn your slice; only the targets, their props and the shots change
## (Ramon, 6 Oct: "I don't remember the walls of the range being slidable, just the inside happenings").
## The old range's walls slid just the same, but 44 m off, black on black, they read as nothing; these are
## 11.5 m off and gridded. So the room's visible pieces turn WITH your slice, round you, and look as if
## the slice had not turned. Their collision does not: the bodies are moved out first and stay square to
## the world (a box turned through W collides as its square, which for a wall 24 m deep in W would reach
## metres into the room). Off by default: the room stays honest 4D, as the game will be, and its slide is
## the plainest cue of how far you have turned; F1 "Room ignores the slice" switches it on to compare.
var room_still: bool = false
## What turns with you: the room's own nodes, each with where it stood.
const ROOM_NODES := ["Hall", "Corridor", "Furniture", "ExplainerWing", "MetricsWing", "WallPanels"]
var _room_rest: Dictionary = {}
var _room_turn: Projection = Projection.IDENTITY
var _room_pivot: Vector4 = Vector4.ZERO


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
	if Engine.is_editor_hint():
		return
	player = PlayerScript.make()
	add_child(player)
	player.call("place", Layout.SPAWN, 0.0)
	player.set("min_z", Layout.line_hold())
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
	props = Node4D.new()
	props.name = "Props"
	add_child(props)
	sfx = Node.new()
	sfx.name = "Sfx"
	sfx.set_script(Sfx)
	add_child(sfx)
	console = Node4D.new()
	console.name = "Console"
	console.set_script(Console)
	console.set("player", player)
	add_child(console)
	weapon = Node.new()
	weapon.name = "Weapon"
	weapon.set_script(Weapon)
	weapon.set("player", player)
	weapon.set("camera", player.get("camera"))
	weapon.set("gun", gun)
	weapon.set("fx_parent", fx)
	weapon.set("sfx", sfx)
	weapon.set("console", console)
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
	director = Node.new()
	director.name = "Director"
	director.set_script(Director)
	director.set("range_root", self)
	director.set("player", player)
	director.set("weapon", weapon)
	director.set("hud", hud)
	director.set("console", console)
	director.set("sfx", sfx)
	director.set("targets_parent", targets)
	director.set("props", props)
	add_child(director)
	# The metrics wall reads the director live (the kit's panel source contract).
	panel_source = Node.new()
	panel_source.name = "PanelSource"
	panel_source.set_script(PanelSource)
	panel_source.set("director", director)
	add_child(panel_source)
	var pair: Node = get_node_or_null("WallPanels")
	if pair != null:
		pair.set("source", pair.get_path_to(panel_source))
	dev_panel = PanelContainer.new()
	dev_panel.name = "DevPanel"
	dev_panel.set_script(DevPanel)
	dev_panel.set("range_root", self)
	layer.add_child(dev_panel)
	director.set("spot", get_node_or_null("Spot"))
	director.set("dev_panel", dev_panel)
	apply_tuning(DevPanel.load_saved())
	# The shared back-to-menu prompt (H), and the pen's way home when the pen sent you here.
	var rb: Node = ReturnButton.instantiate()
	rb.name = "ReturnButton"
	add_child(rb)
	var home := Node.new()
	home.name = "WayHome"
	home.set_script(WayHome)
	add_child(home)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_settle_room.call_deferred()


## Once the room has built itself (the kit pieces finish over a frame or two): its collision bodies moved
## out to RoomBodies, where they stay, and where each room node stands remembered.
func _settle_room() -> void:
	for i in 3:
		await get_tree().process_frame
	var bodies := Node4D.new()
	bodies.name = "RoomBodies"
	add_child(bodies)
	for nm in ROOM_NODES:
		var n: Node4D = get_node_or_null(String(nm))
		if n == null:
			continue
		for b in n.find_children("*", "StaticBody4D", true, false):
			var body: Node4D = b
			var gp: Vector4 = body.global_position
			var gb: Projection = body.global_basis
			body.get_parent().remove_child(body)
			bodies.add_child(body)
			body.global_position = gp
			body.global_basis = gb
		_room_rest[nm] = [n.position, n.basis]


func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or player == null or _room_rest.is_empty():
		return
	room_view()


## The room's turn round you: your basis times the inverse of the one you would have unturned, so the
## room seen through your turned slice looks as it does through the level one. Identity when the slice is
## level, or when room_still is off.
func room_view() -> void:
	var r: Projection = Projection.IDENTITY
	# A level slice is no turn at all, rounding included, so a level room is never touched.
	if room_still and float(player.call("slice_angle")) > 0.001:
		var b: Projection = player.global_basis
		r = b * (player.call("level_basis") as Projection).inverse()
	var e: Vector4 = player.global_position
	if r == _room_turn and (r == Projection.IDENTITY or e == _room_pivot):
		return
	_room_turn = r
	_room_pivot = e
	for nm in _room_rest:
		var n: Node4D = get_node_or_null(String(nm))
		if n == null:
			continue
		var rest: Array = _room_rest[nm]
		n.basis = r * (rest[1] as Projection)
		n.position = r * ((rest[0] as Vector4) - e) + e
	if console != null:
		console.set("view", [] if r == Projection.IDENTITY else [r, e])


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	# Escape lets the mouse go, and a second Escape quits, as in the pen (pen_orbit_rig_4d.gd): opened on
	# its own, nothing else got you out (Ramon, 6 Oct). From the menu the menu takes Escape first, and on a
	# trip from the pen the way home does (range_way_home_4d.gd). A click takes the mouse back.
	var k := event as InputEventKey
	if k != null and k.pressed and not k.echo and k.keycode == KEY_ESCAPE:
		if dev_panel != null and dev_panel.visible:
			dev_panel.call("toggle")
		elif Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		elif get_tree().root.has_node(^"WayHome"):
			# Launched from the menu (11 Oct): Esc never quits; M is the way to the menu
			# (Menu/scripts/menu_way_home.gd) and QUIT is on the menu.
			pass
		else:
			get_tree().quit()
		get_viewport().set_input_as_handled()
		return
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()


## The F1 panel's values, applied: the light's numbers over the range's own, the spot's strength (the
## director fades it to this while a stage runs) and cone, how far you can step through W.
func apply_tuning(v: Dictionary) -> void:
	tuning = v.duplicate()
	var light: Node = get_node_or_null("Light")
	if light != null:
		var l: Dictionary = Style.LIGHT.duplicate(true)
		for k in ["key_energy", "key_elevation", "key_azimuth", "fill_energy", "exposure"]:
			if v.has(k):
				l[k] = float(v[k])
		var amb: Color = Style.LIGHT["ambient"]
		var ka: float = float(v.get("ambient_k", 1.0))
		l["ambient"] = Color(amb.r * ka, amb.g * ka, amb.b * ka)
		light.set("mood_overrides", {"bright": l, "dark": l})
		light.call("set_mood", "bright", true, false)
	var spot: Node = get_node_or_null("Spot")
	if spot != null:
		spot.set("angle", float(v.get("spot_angle", 28.0)))
	if player != null:
		player.set("w_limit", float(v.get("w_limit", Layout.W_LIMIT)))
	if hud != null:
		hud.set("w_limit", float(v.get("w_limit", Layout.W_LIMIT)))
	room_still = float(v.get("room_still", 0.0)) > 0.5
