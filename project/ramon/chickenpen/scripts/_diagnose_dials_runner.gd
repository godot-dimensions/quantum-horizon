extends SceneTree

## Do the two instruments actually move when the world under them changes?
##
## The complaint is that they barely help. This does not ask whether they LOOK right - it
## asks whether the numbers they draw from change by a useful amount when the player
## walks, rotates their slice, and steps through W. A dial that answers the same thing in
## every state is a decoration however well drawn it is.

const SliceAngles := preload("res://ramon/chickenpen/scripts/slice_angles_4d.gd")
const Bearing = preload("res://scripts/bearing_utility_4d.gd")
const NAT_LOG_2: float = 0.6931471805599453094
const HALFWAY_METERS: float = 8.0

var _root: Node
var _f := 0
var _step := 0
var _rows: Array = []


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/playable_world.tscn").instantiate()
	root.add_child(_root); current_scene = _root


## The radar plots every catchable chicken at this screen offset from its centre, in
## fractions of the dial's radius. Recomputed here exactly as chicken_radar_4d draws it.
func _radar_points(player: Node4D, frame: Node4D, manager: Node) -> Array:
	var radar: Node = _root.get_node("UI/Radar")
	var basis: Projection = (frame.global_basis if frame != null else player.global_basis).inverse()
	var out: Array = []
	for agent in (manager.get("agents") as Array):
		if not bool(agent.call("can_be_caught")):
			continue
		var body: Node4D = agent.get_parent() as Node4D
		if body == null:
			continue
		var rel: Vector4 = basis * (body.global_position - player.global_position)
		var span: float = rel.length()
		if span < 0.0001:
			continue
		var squashed: float = 1.0 - exp(-span * (NAT_LOG_2 / HALFWAY_METERS))
		var s: Vector4 = rel * (squashed / span)
		out.append(Vector2(s.x, -s.z))
	return out


func _spread(points: Array) -> float:
	# How far the nearest and furthest dots are from the centre. If everything is pinned
	# near the rim, this is small and the dial cannot tell one chicken from another.
	if points.is_empty():
		return 0.0
	var lo: float = 9.0
	var hi: float = 0.0
	for p in points:
		var r: float = (p as Vector2).length()
		lo = minf(lo, r); hi = maxf(hi, r)
	return hi - lo


func _snapshot(label: String) -> void:
	var player: Node4D = _root.get_node("Player")
	var rig: Node4D = _root.get_node("Player/CameraRig")
	var manager: Node = _root.get_node("Chickens")
	var gizmo: Node = _root.get_node("UI/SliceGizmo")
	var points: Array = _radar_points(player, rig, manager)
	var mean: float = 0.0
	for p in points:
		mean += (p as Vector2).length()
	if points.size() > 0:
		mean /= float(points.size())
	# What the gizmo's prism is showing: the target's offset off your slice.
	var gap: float = float(gizmo.call("_target_w")) if gizmo.has_method("_target_w") else NAN
	_rows.append([label, points.size(), mean, _spread(points), gap])
	print("   %-26s %2d dots  mean radius %.3f  spread %.3f  prism gap %+.3f"
		% [label, points.size(), mean, _spread(points), gap])


func _process(_d) -> bool:
	_f += 1
	if _f < 70: return false
	var player: Node4D = _root.get_node("Player")
	var rig: Node4D = _root.get_node("Player/CameraRig")

	match _step:
		0:
			player.position = Vector4(0.0, 1.3, 8.0, 0.0)
			player.set("linear_velocity", Vector4.ZERO)
			print("\n--- the two dials, as the world under them changes ---")
			_snapshot("at spawn")
		1:
			player.position = Vector4(0.0, 1.3, 2.0, 0.0)
			_snapshot("walked six units north")
		2:
			player.position = Vector4(0.0, 1.3, -6.0, 0.0)
			_snapshot("walked eight more")
		3:
			SliceAngles.tilt(rig, 0.6, 0.0)
			rig.call("_apply")
			_snapshot("slice-rotated 34 deg")
		4:
			SliceAngles.tilt(rig, 1.2, 0.0)
			rig.call("_apply")
			_snapshot("slice-rotated 69 deg")
		5:
			SliceAngles.tilt(rig, 0.0, 0.0)
			rig.call("_apply")
			player.position = Vector4(0.0, 1.3, -6.0, 1.0)
			_snapshot("stepped one unit through W")
		6:
			player.position = Vector4(0.0, 1.3, -6.0, 2.0)
			_snapshot("two units through W")
		_:
			print("\n--- how much each control moved the dials ---")
			print("   walking (rows 1-3):        mean radius %.3f -> %.3f"
				% [_rows[0][2], _rows[2][2]])
			print("   slice rotation (rows 4-5): mean radius %.3f -> %.3f, prism %+.3f -> %+.3f"
				% [_rows[2][2], _rows[4][2], _rows[2][4], _rows[4][4]])
			print("   stepping through W (6-7):  mean radius %.3f -> %.3f, prism %+.3f -> %+.3f"
				% [_rows[2][2], _rows[6][2], _rows[2][4], _rows[6][4]])
			print("\n   worst spread seen: %.3f of the dial's radius"
				% [_rows.map(func(r): return r[3]).min()])
			# THE NUMBER THAT MATTERS. A mean over twelve chickens scattered all round you
			# barely moves whatever you do - they close on one side as they open on the other.
			# What a player actually watches is ONE dot while walking at it, so that is what
			# this compares: the old fixed-8m exponential against the new fixed-30m curve.
			print("")
			print("--- one chicken's dot, as you walk in on it ---")
			print("   %8s %10s %10s" % ["away", "was", "now"])
			var ln2: float = 0.6931471805599453094
			for d in [30.0, 20.0, 12.0, 6.0, 3.0]:
				var was: float = 1.0 - exp(-d * (ln2 / 8.0))
				var now: float = pow(clampf(d / 30.0, 0.0, 1.0), 0.7) * 0.94
				print("   %6.0f m %10.3f %10.3f" % [d, was, now])
			print("   (fractions of the dial radius - wider gaps between rows is the point)")
			quit(0)
			return true
	_step += 1
	_f = 0
	return false
