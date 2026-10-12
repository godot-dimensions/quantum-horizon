extends Node4D

## A SMALL BURST OF CONFETTI, ANYWHERE (discovery, 9 Oct 2026): the pen's celebration throw
## (scripts/pen_celebration_4d.gd _burst) made placeable, for a secret found. That one is hung over the pen's fence and
## private to the end of the chicken quest, so this is a copy of its idea, not a call into it.
##
## Pieces as deep through W as they are wide, thrown up and out in x, z and W (so some land on slices you are not
## on), tumbling only in the three ordinary planes (a scrap turning through W changes its own cross-section as it
## falls, and reads as a bug), slowed by air, resting on the ground, then gone. Frees itself.
##
## NO class_name (engine_gotchas.md).

## The pieces' colours.
var colours: Array = [Color(1.0, 0.82, 0.30), Color(0.40, 0.78, 1.0), Color(1.0, 1.0, 1.0), Color(0.95, 0.45, 0.30)]
var pieces: int = 70
var piece_size: float = 0.09
var up: float = 5.5
var out: float = 2.2
var w_out: float = 1.4
var gravity: float = 9.0
var linger_seconds: float = 1.5

var _pieces: Array = []
var _linger: float = 0.0
var _rng := RandomNumberGenerator.new()


## Thrown from [param at] (global). Make it (Confetti.new()), add it under something in the world, then call this.
func throw(at: Vector4) -> void:
	global_position = at
	_throw()


func _throw() -> void:
	_rng.randomize()
	for i in pieces:
		var mesh := BoxTetraMesh4D.new()
		var w: float = piece_size * _rng.randf_range(0.7, 1.5)
		mesh.size = Vector4(w, piece_size * 0.35, w * 0.7, w)
		var node := MeshInstance4D.new()
		node.name = "Piece%d" % i
		node.mesh = mesh
		var mat := TetraMaterial4D.new()
		mat.albedo_color = colours[_rng.randi() % maxi(colours.size(), 1)]
		node.material_override = mat
		# The dev look leaves it be: it is a flash of colour, not a landmark.
		node.set_meta(&"_look_own", true)
		add_child(node)
		node.position = Vector4(_rng.randf_range(-0.2, 0.2), _rng.randf_range(-0.1, 0.1), _rng.randf_range(-0.2, 0.2), _rng.randf_range(-0.1, 0.1))
		_pieces.append({
			"node": node,
			"v": Vector4(_rng.randf_range(-out, out), up * _rng.randf_range(0.55, 1.0), _rng.randf_range(-out, out), _rng.randf_range(-w_out, w_out)),
			"spin": Vector3(_rng.randf_range(-7.0, 7.0), _rng.randf_range(-7.0, 7.0), _rng.randf_range(-7.0, 7.0)),
			"down": false,
		})


func _process(delta: float) -> void:
	var still_up: bool = false
	var floor_y: float = 0.02 - global_position.y
	for piece in _pieces:
		var node: MeshInstance4D = piece["node"]
		if not is_instance_valid(node) or piece["down"]:
			continue
		var v: Vector4 = piece["v"]
		v.y -= gravity * delta
		v.x *= 0.985
		v.z *= 0.985
		v.w *= 0.985
		piece["v"] = v
		node.position += v * delta
		var spin: Vector3 = piece["spin"]
		node.basis = node.basis * Basis4D.from_xy(spin.x * delta) * Basis4D.from_yz(spin.y * delta) * Basis4D.from_zx(spin.z * delta)
		if node.position.y <= floor_y:
			node.position.y = floor_y
			piece["down"] = true
		else:
			still_up = true
	if still_up:
		return
	_linger += delta
	if _linger >= linger_seconds:
		queue_free()
