extends Node4D
## Slice Garden: a pressure plate that wants a crate (PLAN.md step 42).
##
## A low yellow pad (yellow is "use this", the lab kit's code) with a crate's outline glowing on it,
## so it says what it is for before you know the word. It POLLS for a crate resting on it rather
## than using an Area4D: an Area4D never fires for something that arrives by being set in place
## (engine_gotchas.md, the teleport trap), and a crate put down is exactly that.
##
## Pressed: the pad sinks a few centimetres, its outline turns from warm white to green, and
## `pressed_changed(true)` goes out. Lift the crate off and it all goes back.
##
## The pad spans one lane of W (`size.w`), so it is only there in the world it belongs to.
##
## NO class_name (engine_gotchas.md).

signal pressed_changed(pressed: bool)

const Build := preload("res://ramon/MiegakureLook/Remake/world/mk_build.gd")
const Mats := preload("res://ramon/MiegakureLook/Remake/world/mk_materials.gd")

const IDLE := Color(1.0, 0.95, 0.82)
const ON := Color(0.35, 0.95, 0.55)
const SINK := 0.05

## The pad's size in x, (thickness), z and w.
@export var size: Vector4 = Vector4(1.4, 0.14, 1.4, 1.4)

var pressed: bool = false
var _pad: Node4D
var _marks: Array = []
var _sink: float = 0.0


func _ready() -> void:
	var at: Vector4 = global_position + Vector4(0, size.y * 0.5, 0, 0)
	# A real box (so a crate rests ON it and he steps up onto it), but not one of the island's solids:
	# a crate may be put down on it.
	_pad = Build.box(self, "Pad", at, size, Build.surface("yellow", at, size, 1.4, {"tint": Color(1.0, 0.9, 0.55)}), null, true)
	# The crate's outline on the pad: four thin glowing bars, as the crate's own footprint.
	var c: float = 0.7 * 0.5
	var t := 0.05
	for spec in [[Vector4(0, 0, -c, 0), Vector4(0.7 + t, 0.02, t, size.w * 0.8)], [Vector4(0, 0, c, 0), Vector4(0.7 + t, 0.02, t, size.w * 0.8)],
			[Vector4(-c, 0, 0, 0), Vector4(t, 0.02, 0.7 + t, size.w * 0.8)], [Vector4(c, 0, 0, 0), Vector4(t, 0.02, 0.7 + t, size.w * 0.8)]]:
		var m := Build.glow_box(_pad, "Mark", global_position + Vector4(0, size.y + 0.012, 0, 0) + spec[0], spec[1], IDLE)
		m.material_override = Mats.glow(IDLE, 1.0, 0.0, true)
		_marks.append(m)


## The box a crate must rest in: the pad's footprint (x, z, w), with its foot near the pad's top.
func _resting(crate: Node) -> bool:
	if crate.call("is_carried"):
		return false
	var p: Vector4 = (crate as Node4D).global_position
	var d: Vector4 = p - global_position
	return absf(d.x) < size.x * 0.5 and absf(d.z) < size.z * 0.5 and absf(d.w) < size.w * 0.5 \
		and d.y > -0.2 and d.y < size.y + 0.25


func _physics_process(delta: float) -> void:
	var now: bool = false
	for crate in get_tree().get_nodes_in_group(&"mk_crate"):
		if _resting(crate):
			now = true
			break
	if now != pressed:
		pressed = now
		for m in _marks:
			((m as MeshInstance4D).material_override as TetraMaterial4D).get_cross_section_material_3d() \
				.set_shader_parameter("glow_color", ON if pressed else IDLE)
		pressed_changed.emit(pressed)
	var want: float = SINK if pressed else 0.0
	if not is_equal_approx(_sink, want):
		_sink = move_toward(_sink, want, delta * 0.4)
		_pad.position.y = size.y * 0.5 - _sink
