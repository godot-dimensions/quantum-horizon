extends SceneTree

## Does Trym actually give the talk, or does he stand there?
##
## Three things separate a presenter from a mannequin, and this checks all three: he starts
## off in the wings and walks on, he changes where he stands between stating a finding and
## demonstrating it, and his arm goes out when the demonstration does.

var _root: Node
var _f := 0
var _fails: Array = []
var _show: Node
var _p: Node4D
var _wings := Vector4.ZERO
var _on_at := Vector4.ZERO
var _claim_at := Vector4.ZERO
var _reach := 0.0
var _rest := 0.0
var _stage := 0


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/theatre/theatre.tscn").instantiate()
	root.add_child(_root); current_scene = _root


func _check(label: String, ok: bool, detail: String) -> void:
	print("   %s %-38s %s" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_fails.append(label)


## How far his pointing arm is raised, whichever one it is.
func _arm() -> float:
	var most: float = 0.0
	for side in ["left", "right"]:
		var s: Node4D = _p.get("shoulder_%s" % side) as Node4D
		if s != null:
			most = maxf(most, absf(asin(clampf(-s.basis.y.z, -1.0, 1.0))))
	return most


func _process(_d) -> bool:
	_f += 1
	if _f < 40:
		return false
	if _show == null:
		_show = _root.get_node("Show")
		_p = _root.get_node("Presenter")
		_wings = _show.get("wings")
		_show.set("opening_seconds", 3.0)
		_show.set("act_seconds", 6.0)
		return false

	var act: int = int(_show.call("current_act"))
	var t: float = float(_show.get("_phase"))
	match _stage:
		0:
			if _p.position.distance_to(_wings) > 0.3:
				_on_at = _p.position
				print("\n--- he walks on ---")
				_check("he starts in the wings", true, "left them at %.2f, %.2f" % [_on_at.x, _on_at.z])
				_stage = 1
		1:
			# Out front for the claim.
			if act == 0 and t > 1.0:
				_claim_at = _p.position
				_rest = _arm()
				_check("and comes out to make the claim",
					_claim_at.distance_to(_wings) > 1.5,
					"at %.2f, %.2f - %.1f m from the wings" % [_claim_at.x, _claim_at.z,
						_claim_at.distance_to(_wings)])
				_stage = 2
		2:
			# Then in on the drum to demonstrate it, arm out.
			if act == 0 and t > 5.2:
				_reach = _arm()
				print("\n--- and works the exhibit ---")
				_check("he moves in for the demonstration",
					_p.position.distance_to(_claim_at) > 0.5,
					"%.2f m in from his mark" % _p.position.distance_to(_claim_at))
				_check("his arm goes out with it", _reach > _rest + 0.5,
					"shoulder %.2f rad, was %.2f" % [_reach, _rest])
				_check("and he is nearer the drum than he was",
					Vector2(_p.position.x, _p.position.z).length()
						< Vector2(_claim_at.x, _claim_at.z).length(),
					"%.2f m out, was %.2f" % [Vector2(_p.position.x, _p.position.z).length(),
						Vector2(_claim_at.x, _claim_at.z).length()])
				print("\n%d FAIL(s)" % _fails.size())
				quit(1 if _fails.size() > 0 else 0)
				return true
	if _f > 40000:
		print("   FAIL stuck at stage %d, act %d" % [_stage, act])
		quit(1)
		return true
	return false
