extends "res://ramon/QuantumRange/scripts/range_target_4d.gd"

## SHELL: a red core sealed inside a grey shell that nothing breaks. In your slice the shell is a closed
## sphere round the core and every shot pings off it. But the shell is a torisphere, a sphere's surface
## thickened only a little through W: it is solid within `shell_w` of its middle slice and simply not
## there beyond that. The core reaches further through W than the shell does. So step ana or kata past
## the shell (Q / E) and the core is in the open: in 4D a box has no lid along W, the way a circle drawn
## round a point on paper does not trap it in 3D.

const Shapes := preload("res://ramon/QuantumRange/scripts/range_shapes.gd")

## The shell's radius; its thickness through W either side of its middle (the torisphere's minor radius).
var shell_r: float = 0.8
var shell_w: float = 0.2
var core_r: float = 0.3
## How far the core reaches through W either side.
var core_w: float = 0.7


func build() -> void:
	family = "shell"
	add_part("Core", "core", Shapes.ball(), Vector4(core_r * 1.8, core_r * 1.8, core_r * 1.8, core_w * 2.0),
		{"basis": Basis4D.from_scale(Vector4(core_r, core_r, core_r, core_w))})
	var big: float = (shell_r + shell_w) * 2.0
	add_part("Shell", "shell", Shapes.torisphere(), Vector4(big, big, big, shell_w * 2.0),
		{"basis": _shell_basis(0.0), "radar": false})


## The primitive (models/primitives/torisphere) has its sphere of radius 2 in x, z and w and its minor
## radius, 0.5, along y (measured, _probe_primitives_runner.gd): a quarter turn in the w/y plane puts the
## sphere in your x, y and z and the thinness along W, then it is scaled to shell_r and shell_w.
func _shell_basis(turn: float) -> Projection:
	return Basis4D.from_scale(Vector4(shell_r / 2.0, shell_r / 2.0, shell_r / 2.0, shell_w / 0.5)) * Basis4D.from_zx(turn) * Basis4D.from_wy(PI * 0.5)


func animate(t: float, _dt: float) -> void:
	if age > 0.35 and bool(parts[1]["alive"]):
		(parts[1]["mesh"] as MeshInstance4D).basis = _shell_basis(t * 0.25)
