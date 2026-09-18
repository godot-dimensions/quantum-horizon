extends SceneTree
## Does the foot actually meet the ground, and does the tail tip trace a figure-8?

var _frame := 0
var _root: Node
var _player: CharacterBody4D
var _feet: Array[Dictionary] = []
var _tip: Node4D
var _tip_track: Array[Vector4] = []
var _tilt_planted: Array[float] = []
var _tilt_lifted: Array[float] = []

func _initialize() -> void:
	_root = load("res://ramon/Model/rigged_creature.tscn").instantiate()
	root.add_child(_root)
	current_scene = _root

func _process(delta: float) -> bool:
	_frame += 1
	if _frame == 1:
		_player = _root.get_node("Player")
		for station in ["Chest", "Rump"]:
			for side in ["L", "R"]:
				for half in ["A", "K"]:
					var tag: String = "%s%s%s" % ["Fore" if station == "Chest" else "Hind", side, half]
					var base: String = "Creature/Barrel/%s/%sIK/Upper/Mid/Lower" % [station, tag]
					var foot: Node4D = _root.get_node_or_null("%s/Foot" % base) as Node4D
					var toe: Node4D = _root.get_node_or_null("%s/Foot/B2" % base) as Node4D
					if foot != null and toe != null:
						_feet.append({"foot": foot, "toe": toe, "tag": tag})
		_tip = _root.get_node_or_null("Creature/Barrel/Rump/Tail1/Tail2/Tail3/Tail4/B2") as Node4D
		print("feet: %d   tail tip: %s" % [_feet.size(), "found" if _tip != null else "MISSING"])
		return false
	var eye := Vector4(5.4, 2.8, 5.4, 0.0)
	_player.global_position = eye
	_player.global_basis = Basis4D.looking_at(Vector4(-0.6, 2.2, 0.0, 0.0) - eye)
	_player.linear_velocity = Vector4.ZERO
	if _frame > 60:
		for f in _feet:
			var ankle: Vector4 = (f["foot"] as Node4D).global_position
			var toe: Vector4 = (f["toe"] as Node4D).global_position
			# Tilt from flat: how much of the ankle->toe vector is vertical.
			var v: Vector4 = toe - ankle
			var tilt: float = rad_to_deg(asin(clampf(absf(v.y) / maxf(v.length(), 0.0001), -1.0, 1.0)))
			if ankle.y < 0.10:
				_tilt_planted.append(tilt)
			elif ankle.y > 0.20:
				_tilt_lifted.append(tilt)
		if _tip != null:
			_tip_track.append(_tip.global_position)
	if _frame >= 340:
		var pm := 0.0
		for t in _tilt_planted:
			pm += t
		var lm := 0.0
		for t in _tilt_lifted:
			lm += t
		print("foot tilt off flat when PLANTED (ankle y < 0.10): mean %.1f deg over %d samples" % [
			pm / maxf(float(_tilt_planted.size()), 1.0), _tilt_planted.size()])
		print("foot tilt off flat when LIFTED  (ankle y > 0.20):  mean %.1f deg over %d samples" % [
			lm / maxf(float(_tilt_lifted.size()), 1.0), _tilt_lifted.size()])
		var lo := Vector4(INF, INF, INF, INF)
		var hi := Vector4(-INF, -INF, -INF, -INF)
		for p in _tip_track:
			lo = Vector4(minf(lo.x, p.x), minf(lo.y, p.y), minf(lo.z, p.z), minf(lo.w, p.w))
			hi = Vector4(maxf(hi.x, p.x), maxf(hi.y, p.y), maxf(hi.z, p.z), maxf(hi.w, p.w))
		print("tail tip swept: x %.2f  y %.2f  z %.2f  w %.2f" % [
			hi.x - lo.x, hi.y - lo.y, hi.z - lo.z, hi.w - lo.w])
		# A figure-8 crosses its own vertical centre twice per horizontal cycle.
		var crossings := 0
		var mid_y: float = (hi.y + lo.y) * 0.5
		for i in range(1, _tip_track.size()):
			if (_tip_track[i - 1].y - mid_y) * (_tip_track[i].y - mid_y) < 0.0:
				crossings += 1
		var z_crossings := 0
		var mid_z: float = (hi.z + lo.z) * 0.5
		for i in range(1, _tip_track.size()):
			if (_tip_track[i - 1].z - mid_z) * (_tip_track[i].z - mid_z) < 0.0:
				z_crossings += 1
		print("centre crossings over the run: vertical %d, horizontal %d  (ratio %.1f, a figure-8 is 2.0)" % [
			crossings, z_crossings, float(crossings) / maxf(float(z_crossings), 1.0)])
		quit(0)
		return true
	return false
