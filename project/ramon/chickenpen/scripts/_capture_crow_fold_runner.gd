extends SceneTree

## A crow perched, from four sides, then flying, then caught halfway through folding as it
## lands - Ramon, 30 Sept: "when they sit the wings are not rotated adjacent to the body.
## they stay rotated in upright position, meaning the side of the wings are facing upward,
## not flat to the body mass." Saves res://smoke_test_output/crowfold_<n>_<view>.png.
##
##   godot... --path project --windowed --resolution 1280x720 --position 40,40
##       --script res://ramon/chickenpen/scripts/_capture_crow_fold_runner.gd

const PERCHED := ["side", "front", "rear_above", "top"]

var _root: Node
var _crow: Node4D
var _cam: Camera4D
var _f := 0
var _t := 0.0
var _step := 0
var _view := 0
var _n := 0
var _pending := ""


func _initialize() -> void:
	root.unfocusable = true
	_root = load("res://ramon/chickenpen/chickenpen.tscn").instantiate()
	root.add_child(_root)
	current_scene = _root


func _hide_hud(node: Node) -> void:
	for child in node.get_children():
		if child is CanvasItem:
			(child as CanvasItem).visible = false
		_hide_hud(child)


func _aim(view: String) -> void:
	var at: Vector4 = _crow.global_position + Vector4(0, 0.25, 0, 0)
	var ahead: Vector4 = (_crow.global_basis * Vector4(0, 0, 1, 0)).normalized()
	var side: Vector4 = (_crow.global_basis * Vector4(1, 0, 0, 0)).normalized()
	var up := Vector4(0, 1, 0, 0)
	match view:
		"front":
			# A little below the bird, so a black crow is seen against the sky.
			_cam.global_position = at + ahead * 1.0 + side * 0.6 - up * 0.08
		"rear_above":
			_cam.global_position = at - ahead * 1.0 - side * 0.45 + up * 0.7
		"top":
			_cam.global_position = at + up * 1.4 - ahead * 0.25
		_:
			_cam.global_position = at + side * 1.15 - up * 0.1
	_cam.look_at(at)
	_cam.make_current()


func _process(d: float) -> bool:
	_f += 1
	if _pending != "":
		root.get_texture().get_image().save_png("res://smoke_test_output/crowfold_%d_%s.png" % [_n, _pending])
		print("   saved crowfold_%d_%s.png" % [_n, _pending])
		_n += 1
		_pending = ""
		return false
	if _f < 60:
		return false
	_t += d
	match _step:
		0:
			_hide_hud(_room_ui())
			_crow = _root.get_node("World/Crow") as Node4D
			_root.get_node("Player").position = Vector4(40.0, 1.3, 40.0, 0.0)
			_cam = Camera4D.new()
			_cam.name = "CrowCamera"
			_cam.set("rendering_engine_name", "Cross-section")
			_root.add_child(_cam)
			# Sat still where it can be seen against the sky, for as long as this takes. The shrug
			# is held at its very start (0.45 s left, which opens the wings by nothing), so no
			# picture catches one by chance.
			# On a perch it would choose itself - a fence post or a roof - rather than in the air.
			_crow.position = _crow.call("_pick_perch")
			_crow.set("_mood", 0)
			_crow.set("_mood_left", 999.0)
			_crow.set("_shrug", 0.45)
			_step = 1; _t = 0.0
		1:
			_crow.set("_shrug", 0.45)
			_aim(PERCHED[_view])
			if _t > (1.0 if _view == 0 else 0.4):
				_pending = "perched_" + PERCHED[_view]
				_view += 1
				_t = 0.0
				if _view >= PERCHED.size():
					# Up and away.
					_crow.set("_to", _crow.position + Vector4(20.0, 3.0, 0.0, 0.0))
					_crow.set("_mood", 2)
					_crow.set("_mood_left", 999.0)
					_step = 2
		2:
			_aim("side")
			if _t > 1.2:
				_pending = "flying_side"
				_step = 3; _t = 0.0
		3:
			_aim("rear_above")
			if _t > 0.3:
				_pending = "flying_rear"
				_step = 4; _t = 0.0
		4:
			# Settle it: perched again, and photographed while the wings are still folding.
			_crow.set("_mood", 0)
			_crow.set("_mood_left", 999.0)
			_crow.set("_shrug", 0.45)
			_step = 5; _t = 0.0
		5:
			_crow.set("_shrug", 0.45)
			_aim("side")
			if _t > 0.12:
				_pending = "folding"
				_step = 6; _t = 0.0
		6:
			if _t > 0.3:
				print("CROW FOLD: done")
				quit()
				return true
	return false


func _room_ui() -> Node:
	return _root.get_node("UI")
