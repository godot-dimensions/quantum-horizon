extends Node4D

## The gun in your hands: Trym's and Ramon's design (a barrel, a stock and a 600-cell core turning in the
## xw and yz planes between them), rebuilt in the lab palette: a white body, a dark grip, and a core that
## glows. The core is the weapon's state at a glance: pale while idle, warming to amber as a shot
## charges (amber is the range's "needs a charge" colour), white-hot at full charge, grey when the charge
## has vented, and it spins up for a moment with every shot.
##
## Hung under the camera; the weapon (range_weapon_4d.gd) sets `charge`, `vented` and calls pulse().
##
## NO class_name (engine_gotchas.md).

const Mats := preload("res://ramon/QuantumRange/scripts/range_mats.gd")
const Style := preload("res://ramon/QuantumRange/scripts/range_style.gd")
const Core600 := preload("res://models/primitives/platonic/600_cell/600_cell.g4b")

const IDLE := Color(0.70, 0.86, 0.95)
const VENTED := Color(0.45, 0.47, 0.50)
const FULL := Color(1.0, 0.95, 0.80)

## 0 to 1 while a shot charges.
var charge: float = 0.0
var vented: bool = false

var _core: MeshInstance4D
var _core_mat: TetraMaterial4D
var _spin: float = 1.0
var _kick: float = 0.0
var _angle: float = 0.0


func _ready() -> void:
	position = Vector4(0.28, -0.24, -0.46, 0.0)
	var body := Mats.lit(Color(0.93, 0.94, 0.95))
	var dark := Mats.lit(Color(0.22, 0.23, 0.26))
	_part("Barrel", Mats.box(Vector4(0.045, 0.045, 0.34, 0.045)), Vector4(0, 0.035, -0.23, 0), body)
	_part("Rail", Mats.box(Vector4(0.02, 0.012, 0.30, 0.02)), Vector4(0, 0.064, -0.21, 0), dark)
	_part("Stock", Mats.box(Vector4(0.06, 0.09, 0.22, 0.06)), Vector4(0, -0.035, 0.15, 0), body)
	_part("Grip", Mats.box(Vector4(0.045, 0.12, 0.05, 0.045)), Vector4(0, -0.11, 0.07, 0), dark)
	_core = MeshInstance4D.new()
	_core.name = "Core"
	_core.mesh = Core600
	_core.position = Vector4(0, 0.0, -0.02, 0)
	_core.basis = Basis4D.from_scale_uniform(0.045)
	_core_mat = Mats.glow(IDLE)
	_core.material_override = _core_mat
	add_child(_core)


func _part(nm: String, mesh: Mesh4D, at: Vector4, mat: Material4D) -> void:
	var m := MeshInstance4D.new()
	m.name = nm
	m.mesh = mesh
	m.position = at
	m.material_override = mat
	add_child(m)


func pulse() -> void:
	_spin = 7.0
	_kick = 1.0


func _process(delta: float) -> void:
	_spin = 1.0 + (_spin - 1.0) * exp(-4.0 * delta)
	_kick *= exp(-14.0 * delta)
	# An angle kept, not a basis multiplied up frame after frame: it never drifts.
	_angle = fmod(_angle + 1.4 * (_spin + charge * 3.0) * delta, TAU)
	_core.basis = Basis4D.from_scale_uniform(0.045) * Basis4D.from_xw(_angle) * Basis4D.from_yz(_angle)
	var c: Color = IDLE
	if vented:
		c = VENTED
	elif charge > 0.0:
		c = IDLE.lerp(Style.glow("armour"), clampf(charge * 1.4, 0.0, 1.0))
		if charge >= 0.999:
			c = FULL
	c = c.lerp(Color.WHITE, clampf(_kick, 0.0, 1.0) * 0.6)
	Mats.set_glow(_core_mat, c, 1.0)
	position = Vector4(0.28, -0.24, -0.46 + _kick * 0.035, 0.0)
