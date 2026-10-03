extends SceneTree

## While sitting, does the front-left paw actually rise to the muzzle and come back?

var _root: Node
var _f := 0
var _cat: Node4D
var _paw: Node4D
var _head: Node4D
var _paw_y: Array = []
var _head_y: Array = []
var _sat := 0


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/playable_world.tscn").instantiate()
	root.add_child(_root); current_scene = _root


func _process(_d) -> bool:
	_f += 1
	if _f < 70: return false
	if _cat == null:
		_cat = _root.get_node("World/Cat")
		_root.get_node("Player").position = Vector4(25.0, 1.3, 25.0, 0.0)
		_cat.set("_mood_left", 0.4)
		return false
	if _paw == null:
		_paw = _cat.get_node_or_null("Hide/Chest/FrontHipL/FrontKneeL/FrontFootL") as Node4D
		_head = _cat.get_node_or_null("Hide/Head") as Node4D
		if _paw == null:
			print("paw node not found"); return true
	if int(_cat.get("_mood")) == 3:
		_sat += 1
		# Force a wash now rather than waiting out its own timer.
		if _sat == 3:
			_cat.set("_lick", 0.0)
		if _sat > 3:
			_paw_y.append(_paw.position.y)
			_head_y.append(_head.position.y)
	if _sat < 200:
		return false
	print("front paw local y over the sit: %.4f to %.4f  (moves %.4f)" % [
		_paw_y.min(), _paw_y.max(), _paw_y.max() - _paw_y.min()])
	print("head local y over the sit:      %.4f to %.4f  (dips %.4f)" % [
		_head_y.min(), _head_y.max(), _head_y.max() - _head_y.min()])
	return true
