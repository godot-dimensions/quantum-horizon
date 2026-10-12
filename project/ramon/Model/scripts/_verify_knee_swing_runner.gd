extends SceneTree
## How far do the knees travel? A long stride against a fixed hip height forces the
## mid-joint to flex hard, which reads as the knees swinging about.
var _root: Node
var _f := 0
var _walk: Node
var _lo := []
var _hi := []
var _hilo := []
func _initialize() -> void:
	_root = load("res://ramon/Model/rigged_creature_ramon.tscn").instantiate()
	root.add_child(_root); current_scene = _root
func _process(_d) -> bool:
	_f += 1
	if _f == 30:
		_walk = _root.get_node("Brachio/Walker")
		for i in 4: _lo.append(1e9); _hi.append(-1e9); _hilo.append([1e9, -1e9])
		return false
	if _f < 30: return false
	var legs: Array = _walk.get("_legs")
	for i in mini(legs.size(), 4):
		var k: Vector4 = legs[i].get("knee_now", Vector4.ZERO)
		_lo[i] = minf(_lo[i], k.z); _hi[i] = maxf(_hi[i], k.z)
		_hilo[i][0] = minf(_hilo[i][0], k.y); _hilo[i][1] = maxf(_hilo[i][1], k.y)
	if _f < 700: return false
	var legs2: Array = _walk.get("_legs")
	for i in mini(legs2.size(), 4):
		var upper: float = float(legs2[i]["upper"])
		print("leg %d: knee swings %.2f in Z, %.2f in Y (segment length %.2f -> %.0f%% of it)" % [
			i, _hi[i] - _lo[i], _hilo[i][1] - _hilo[i][0], upper, 100.0 * (_hi[i] - _lo[i]) / upper])
	return true
