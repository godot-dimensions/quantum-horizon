extends SceneTree
## Does it go anywhere, and do its planted feet stay put while it does?
var _root: Node
var _f := 0
var _brachio: Node4D
var _start: Vector4
var _dist := 0.0
var _prev: Vector4
var _mesh: ArrayTetraMesh4D
var _skate := 0.0
var _samples := 0
var _prev_low := Vector4.ZERO
var _spine_offset := Vector4.ZERO
var _track := -1
var _planted := 0
func _initialize() -> void:
	_root = load("res://ramon/Model/rigged_creature_ramon.tscn").instantiate()
	root.add_child(_root); current_scene = _root
func _process(_d) -> bool:
	_f += 1
	if _f == 30:
		_brachio = _root.get_node("Brachio")
		_mesh = (_root.get_node("Brachio/Spine") as MeshInstance4D).mesh as ArrayTetraMesh4D
		_spine_offset = (_root.get_node("Brachio/Spine") as Node4D).position
		_start = _brachio.position; _prev = _start
		return false
	if _f < 30: return false
	_dist += _brachio.position.distance_to(_prev)
	_prev = _brachio.position
	# ONE chosen foot vertex, followed by index. Taking "whichever vertex is lowest"
	# swaps between feet as they trade places and reads every swap as a slide.
	var verts: PackedVector4Array = _mesh.get_vertex_positions()
	if _track < 0:
		var low_y := 1e9
		for i in verts.size():
			if verts[i].y < low_y: low_y = verts[i].y; _track = i
	var low: Vector4 = verts[_track]
	# Through the creature's OWN basis: it yaws as it walks, so adding the position
	# alone puts the foot in the wrong place and makes a planted foot look like a skid.
	var world: Vector4 = _brachio.basis * (low + _spine_offset) + _brachio.position
	if _samples > 0:
		var moved: float = Vector2(world.x - _prev_low.x, world.z - _prev_low.z).length()
		_skate += moved
		# A foot is "planted" when it is holding still against a moving body.
		if moved < 0.25 * (_dist / maxf(_samples, 1)): _planted += 1
	_prev_low = world
	_samples += 1
	if _f < 900: return false
	print("travelled %.2f units, now %.2f from the start" % [_dist,
		Vector2(_brachio.position.x - _start.x, _brachio.position.z - _start.z).length()])
	print("planted foot drift: %.4f units/frame (skating if this tracks the body speed)" % (_skate / _samples))
	print("body speed: %.4f units/frame = %.2f units/s" % [_dist / _samples, _dist / _samples * 60.0])
	print("that one foot held still on %d%% of frames (a walk plants each foot most of the cycle)" % (100 * _planted / _samples))
	return true
