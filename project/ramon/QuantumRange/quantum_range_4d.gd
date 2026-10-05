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


## The two wings stand where the layout says, each turned to face the firing position.
func _place_wings() -> void:
	for pair in [["ExplainerWing", Layout.WING], ["MetricsWing", Vector2(-Layout.WING.x, Layout.WING.y)]]:
		var wing: Node4D = get_node_or_null(String(pair[0])) as Node4D
		if wing == null:
			continue
		var at: Vector2 = pair[1]
		wing.position = Vector4(at.x, 0.0, at.y, 0.0)
		wing.basis = Basis4D.from_zx(Layout.wing_yaw(at))
