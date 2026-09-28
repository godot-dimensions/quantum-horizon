extends CanvasLayer

## Walking into the dark, and out into the light: the screen fades as you go, so the switch
## between the field and the cave happens while you cannot see it.
##
## Ramon, 28 Sept: "it's like walking into a wall. What could we do to make the teleport
## better, more natural - as entering in darkness and then teleporting." So:
##
## IN: the deeper you are in the hill's tunnel, the darker the screen, black a metre before
## the point where the crossing fires. You are carried over in the black, and it lifts
## again in the cave's own dark tunnel - you arrive already inside it.
##
## OUT: walking toward the daylight at the cave's mouth, the screen goes to a warm white,
## the crossing fires in the white, and it clears on the field - stepping out into the sun.
##
## BY POSITION, NOT BY TIMER. A fade on a clock would run whether or not you kept walking;
## tied to how far in you are, stopping stops it and turning back undoes it, so it feels
## like light and not like a cut. Only the lift afterwards is timed, since there is nothing
## to walk through in the moment after arriving.
##
## Above the HUD (layer 50), so the belt and the checklist go dark with everything else.

const CaveHill := preload("res://ramon/chickenpen/terrain/pen_cave_hill_4d.gd")
const CaveRock := preload("res://ramon/chickenpen/cave/cave_rock_4d.gd")

@export var player_path: NodePath = NodePath("../../Player")
@export var crossing_path: NodePath = NodePath("../../CaveCrossing")
## How far into the hill's tunnel the dark starts, and where it is complete - before the
## crossing, which fires about 9.4 m in (pen_cave_hill_4d.gd, way_in).
@export var dark_from: float = 3.0
@export var dark_at: float = 8.4
## How far from the cave's daylight the white starts, and where it is complete - before
## the way out, which fires 1.3 m short of it (cave_exit_4d.gd).
@export var light_from: float = 5.5
@export var light_at: float = 1.6
@export var dark: Color = Color(0.0, 0.0, 0.0)
@export var light: Color = Color(1.0, 0.95, 0.86)
## How long the screen takes to clear after arriving, either way.
@export_range(0.1, 4.0, 0.05) var clear_seconds: float = 1.3

var _player: Node4D
var _crossing: Node
var _rect: ColorRect
var _hill
var _away := false
var _clearing := 0.0
var _tint := Color.BLACK


func _ready() -> void:
	layer = 50
	_player = get_node_or_null(player_path) as Node4D
	_crossing = get_node_or_null(crossing_path)
	_hill = CaveHill.new()
	_rect = ColorRect.new()
	_rect.name = "Fade"
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.color = Color(0, 0, 0, 0)
	add_child(_rect)


func _process(delta: float) -> void:
	if _player == null or _crossing == null:
		return
	var away: bool = bool(_crossing.call("is_away"))
	if away != _away:
		_away = away
		# Whatever colour the screen went to on the way through is the one it clears from.
		_clearing = clear_seconds
	var want := 0.0
	var tint: Color = _tint
	if not away:
		want = _into_the_hill()
		tint = dark
	else:
		want = _toward_the_daylight()
		tint = light
	if _clearing > 0.0:
		_clearing = maxf(_clearing - delta, 0.0)
		var hold: float = smoothstep(0.0, 1.0, _clearing / clear_seconds)
		if hold > want:
			want = hold
			tint = _tint
	else:
		_tint = tint
	_rect.color = Color(tint.r, tint.g, tint.b, want)
	visible = want > 0.001


## 0 in the open, 1 at the point the dark is complete; only inside the tunnel's own width.
func _into_the_hill() -> float:
	var p: Vector4 = _player.global_position
	var mouth: Vector4 = CaveHill.MOUTH
	var half: float = CaveHill.ARCH_HALF_WIDTH + 0.5
	if absf(p.x - mouth.x) > half or absf(p.w - mouth.w) > half:
		return 0.0
	return smoothstep(dark_from, dark_at, float(_hill.tunnel_into(p)))


func _toward_the_daylight() -> float:
	var cave: Node4D = _crossing.get("_theatre") as Node4D
	if cave == null or not is_instance_valid(cave):
		return 0.0
	var local: Vector4 = cave.global_basis.inverse() * (_player.global_position - cave.global_position)
	if absf(local.x) > CaveRock.TUNNEL_HALF + 1.0 or absf(local.w) > CaveRock.TUNNEL_HALF + 1.0:
		return 0.0
	var gap: float = CaveRock.DAYLIGHT_Z - local.z
	return 1.0 - smoothstep(light_at, light_from, gap)
