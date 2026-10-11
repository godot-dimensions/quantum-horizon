extends Node

## The twelfth chicken lands: confetti over the pen, and every bird in it goes berserk.
##
## CONFETTI IS BUILT, NOT EMITTED. There is no particle system in 4D - no GPUParticles4D,
## no CPUParticles4D, nothing that takes a material and throws copies of it about. So each
## piece is a real MeshInstance4D with a real BoxTetraMesh4D on it, and this node moves
## every one of them by hand each frame. Two hundred nodes sounds like a lot and is not:
## they carry no collision, no script and no children, and the whole update is four adds
## and a basis multiply per piece.
##
## EVERY PIECE HAS W EXTENT AND W SPREAD, which is the one thing about this that is not
## ordinary confetti. A piece as thin through W as it is wide would vanish the instant the
## player rotated their slice - the fence did exactly that, and it is the mistake this
## project keeps re-learning. So each piece is as deep through W as it is across, and the
## burst is spread through W as well, which means turning the slice during the celebration
## reveals confetti that was always there rather than emptying the sky.
##
## THE BIRDS GET A FLAG, NOT A STATE. chicken_agent_4d.celebrate() rides on top of PENNED
## rather than replacing it - see the note there. This node only decides who and when.
##
## AND IT NEVER STOPS. The ask was that they keep going, so nothing here expires: the
## confetti falls and is cleared away, but the pen is still bouncing when you walk off to
## the theatre and still bouncing when you come back. Only a restart ends it.

@export var game_path: NodePath = NodePath("../Game")
@export var manager_path: NodePath = NodePath("../../Chickens")
@export var fence_path: NodePath = NodePath("../../Pen/Fence")

@export_group("Confetti")
@export var confetti_enabled: bool = true
@export_range(10, 600, 10) var pieces: int = 220
## Where the burst comes from, above the middle of the pen.
@export_range(0.5, 12.0, 0.25) var burst_height: float = 3.2
## How hard it goes up, and how far out. Up is bigger than out on purpose: a burst that
## is mostly sideways reads as an explosion, and one that is mostly upward reads as a
## celebration, which is the difference between a bomb and a party popper.
@export_range(0.5, 20.0, 0.5) var burst_up: float = 6.4
@export_range(0.5, 20.0, 0.5) var burst_out: float = 3.6
## Spread through the fourth axis, so a slice rotation finds confetti rather than a gap.
@export_range(0.0, 4.0, 0.1) var burst_w: float = 1.1
@export_range(1.0, 30.0, 0.5) var gravity: float = 9.2
@export_range(0.02, 0.6, 0.01) var piece_size: float = 0.115
## How long a piece lives after it lands. They are cleared rather than left, because two
## hundred nodes that never go away is a leak with a nice colour.
@export_range(0.5, 20.0, 0.5) var linger_seconds: float = 4.0
@export var colours: Array[Color] = [
	Color(0.94, 0.26, 0.32), Color(0.98, 0.76, 0.18), Color(0.30, 0.68, 0.94),
	Color(0.36, 0.80, 0.42), Color(0.86, 0.44, 0.86), Color(0.99, 0.99, 0.99),
]

@export_group("Testing")
## A shortcut for looking at all this without catching twelve chickens first.
##
## PRESS ONCE: every loose bird is put in the pen, which drives the real count through
## the real return volume and fires the real completion - this does not call the
## celebration directly, because a shortcut that skips the thing it is testing tests
## nothing. PRESS AGAIN: a clean restart, the same one Ctrl+R does.
@export var test_key_enabled: bool = true
## F7, not M (11 Oct): M is the way to the menu everywhere launched from it.
@export var test_key: Key = KEY_F7

var _game: Node
var _manager: Node
var _fence: Node
var _pieces: Array[Dictionary] = []
var _root: Node4D
var _linger: float = 0.0
var _rng := RandomNumberGenerator.new()
var _thrown: bool = false


func _ready() -> void:
	_game = get_node_or_null(game_path)
	_manager = get_node_or_null(manager_path)
	_fence = get_node_or_null(fence_path)
	if _game == null or _manager == null:
		push_warning("PenCelebration: no game or no manager, so nothing happens when the pen fills.")
		return
	if _game.has_signal("completed"):
		_game.connect("completed", _on_completed)
	else:
		push_warning("PenCelebration: the game has no `completed` signal to listen to.")
	set_process_unhandled_input(test_key_enabled)


## Everything is in. Two things happen, and neither of them ends.
func _on_completed() -> void:
	for agent in _penned():
		agent.call("celebrate", true)
	if confetti_enabled:
		_burst()


## Every chicken that counts as home. Asked of the manager rather than walked out of the
## tree, so a bird that is in the pen but not counted - mid-landing, say - does not join
## in before the game agrees it has arrived.
func _penned() -> Array:
	var out: Array = []
	for agent in _manager.get("agents"):
		if agent != null and bool(agent.get("returned")):
			out.append(agent)
	return out


func _burst() -> void:
	_clear()
	_root = Node4D.new()
	_root.name = "Confetti"
	add_child(_root)
	var at := Vector4(0.0, burst_height, 0.0, 0.0)
	if _fence != null:
		# Over the middle of the pen, taken from the fence's own bounds so it follows a
		# resize instead of hanging over where the pen used to be. interior_bounds()
		# hands back two opposite corners in the fence's own space, not an AABB.
		var b: Array = _fence.call("interior_bounds")
		var mid: Vector4 = (b[0] + b[1]) * 0.5
		at = (_fence as Node4D).global_position + Vector4(mid.x, burst_height, mid.z, 0.0)
	for i in pieces:
		var mesh := BoxTetraMesh4D.new()
		# Flat-ish, but as deep through W as it is wide. See the note at the top.
		var w: float = piece_size * _rng.randf_range(0.7, 1.5)
		mesh.size = Vector4(w, piece_size * 0.35, w * 0.7, w)
		var node := MeshInstance4D.new()
		node.name = "Piece%d" % i
		node.mesh = mesh
		var mat := TetraMaterial4D.new()
		mat.albedo_color = colours[_rng.randi() % maxi(colours.size(), 1)]
		node.material_override = mat
		_root.add_child(node)
		node.position = at + Vector4(_rng.randf_range(-0.3, 0.3), _rng.randf_range(-0.2, 0.2),
			_rng.randf_range(-0.3, 0.3), _rng.randf_range(-0.15, 0.15))
		# Up, and outward in all three of the other directions - including W, which is
		# what puts pieces on slices the player is not standing on.
		_pieces.append({
			"node": node,
			"v": Vector4(_rng.randf_range(-burst_out, burst_out),
				burst_up * _rng.randf_range(0.55, 1.0),
				_rng.randf_range(-burst_out, burst_out),
				_rng.randf_range(-burst_w, burst_w)),
			"spin": Vector3(_rng.randf_range(-7.0, 7.0), _rng.randf_range(-7.0, 7.0),
				_rng.randf_range(-7.0, 7.0)),
			"down": false,
		})
	_linger = 0.0
	_thrown = true


func _process(delta: float) -> void:
	if not _thrown:
		return
	var still_up: bool = false
	for piece in _pieces:
		var node: MeshInstance4D = piece["node"]
		if not is_instance_valid(node):
			continue
		if piece["down"]:
			continue
		var v: Vector4 = piece["v"]
		v.y -= gravity * delta
		# Air drags on a flat scrap much harder than on a stone, which is why confetti
		# drifts rather than falling. Cheaper than a real drag term and reads the same.
		v.x *= 0.985
		v.z *= 0.985
		v.w *= 0.985
		piece["v"] = v
		node.position += v * delta
		var spin: Vector3 = piece["spin"]
		# Tumbling in the three ordinary planes. Not the W planes: a scrap that rotates
		# through W changes its own cross-section as it falls, which looks like a bug
		# rather than like paper.
		node.basis = node.basis * Basis4D.from_xy(spin.x * delta) \
			* Basis4D.from_yz(spin.y * delta) * Basis4D.from_zx(spin.z * delta)
		if node.position.y <= 0.02:
			node.position.y = 0.02
			piece["down"] = true
		else:
			still_up = true
	if still_up:
		return
	_linger += delta
	if _linger >= linger_seconds:
		_clear()


func _clear() -> void:
	_pieces.clear()
	_thrown = false
	if _root != null and is_instance_valid(_root):
		_root.queue_free()
	_root = null


## The test shortcut. Press once to fill the pen for real, press again to start over.
##
## IT DRIVES THE REAL PATH BOTH WAYS. Filling the pen moves the birds and lets the return
## volume, the count and the completion signal do what they always do; the reset is the
## game's own restart, the one Ctrl+R calls. A shortcut that set a flag and played the
## effect would look identical and would prove nothing about whether the twelfth chicken
## actually sets it off.
func _unhandled_input(event: InputEvent) -> void:
	if not test_key_enabled or not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo or key.keycode != test_key:
		return
	if _game != null and bool(_game.get("_finished")):
		_reset()
	else:
		_fill_the_pen()
	get_viewport().set_input_as_handled()


func _fill_the_pen() -> void:
	if _manager == null or _fence == null:
		return
	# The same two calls the catcher makes, so each bird goes through CARRIED and out
	# again and lands in the pen as a caught-and-released chicken rather than being
	# teleported past its own state machine.
	for agent in _manager.call("locator_candidates"):
		var body: Node4D = agent.get_parent() as Node4D
		agent.call("on_caught")
		agent.call("on_released")
		var spot: Vector4 = _fence.call("random_interior_point", _rng)
		var host: Node4D = body.get_parent() as Node4D
		body.position = spot - (host.global_position if host != null else Vector4.ZERO)


func _reset() -> void:
	_clear()
	for agent in _manager.get("agents"):
		if agent != null and agent.has_method("celebrate"):
			agent.call("celebrate", false)
	if _game != null and _game.has_method("restart"):
		_game.call("restart")
