extends SceneTree

## Does pressing G whip the sea up, and does it settle again?
##
##   godot --path project --rendering-method forward_plus --resolution 640x400 \
##       --script res://sandbox/water4d/_probe_gust_runner.gd
##
## The gust is a thing you set and then forget for sixteen seconds, which is exactly the shape
## of change that gets shipped half-working: the blow is obvious the moment you press the key,
## and the settling back is not noticed until somebody wonders why the sea has been a storm
## for ten minutes. So both halves are checked, with the wait shortened to a second.

const SHORT_GUST := 1.0

var _frames: int = 0
var _root: Node = null
var _annex: Node = null
var _water: Node = null
var _waited: float = 0.0
var _stage: int = 0
var _settled: int = 1
var _seen: Array[int] = []


func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)


func _process(delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		_root = (load("res://ramon/Arboretum/arboretum.tscn") as PackedScene).instantiate()
		root.add_child(_root)
		current_scene = _root
		return false
	if _frames < 8:
		return false

	if _stage == 0:
		_annex = _root.get_node_or_null(^"WaterAnnex")
		_water = _root.get_node_or_null(^"WaterAnnex/Water")
		if _annex == null or _water == null:
			print("  FAIL - no WaterAnnex or no Water under it")
			quit(1)
			return true
		_settled = int(_annex.get(&"start_preset"))
		print("  settled sea: preset %d" % _settled)
		_annex.set(&"gust_seconds", SHORT_GUST)
		# SIX TAPS over a list of five, so the wrap is covered too - a cycle that runs off the
		# end of its array is the half of this that a single press would never show.
		for tap in 6:
			var raised: String = String(_annex.call(&"gust"))
			_seen.append(int(_water.get(&"preset_index")))
			print("    tap %d -> preset %d (%s)" % [tap + 1, _seen[tap], raised])
		_stage = 2
		return false

	# THE WAIT. An earlier edit to this probe replaced the block that held it, so the check
	# ran on the same frame as the taps and reported the sea had not settled 0.0 seconds
	# after a 1 second gust. The failure was in the probe, not the feature.
	_waited += delta
	if _waited < SHORT_GUST + 2.0:
		return false

	var after: int = int(_water.get(&"preset_index"))
	print("  after %.1f s: preset %d" % [_waited, after])
	var ok := true
	var wanted: PackedInt32Array = _annex.get(&"gust_presets")
	for tap in _seen.size():
		if _seen[tap] != wanted[tap % wanted.size()]:
			print("  FAIL - tap %d raised preset %d, expected %d"
					% [tap + 1, _seen[tap], wanted[tap % wanted.size()]])
			ok = false
	var distinct: Dictionary = {}
	for seen in _seen:
		distinct[seen] = true
	if distinct.size() < 2:
		print("  FAIL - every tap raised the same sea; the cycle is not advancing")
		ok = false
	if after != _settled:
		print("  FAIL - the sea did not settle back to %d" % _settled)
		ok = false
	print("")
	print("  %s" % ("PASS - G whips the sea up and it settles again." if ok else "see above."))
	quit(0 if ok else 1)
	return true
