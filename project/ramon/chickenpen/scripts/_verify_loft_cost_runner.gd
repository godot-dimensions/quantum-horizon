extends SceneTree

## How expensive is rebuilding the goat?
##
## The live-build moment re-lofts the whole animal every time a ball lands, and reshaping
## it re-lofts again on every step of the morph. If a rebuild costs a big fraction of a
## frame then "watch it being made" is really "watch it stutter", and the moment would
## need to be built a different way. So this measures it rather than hoping.
##
## Measured in milliseconds of wall clock around the call, which is the number that
## matters here - this is a main-thread rebuild and the frame waits for it.

var _root: Node
var _f := 0
var _fails: Array = []


func _initialize() -> void:
	_root = Node4D.new()
	root.add_child(_root); current_scene = _root
	var goat := Node4D.new()
	goat.name = "Goat"
	goat.set_script(load("res://ramon/chickenpen/theatre/theatre_goat_4d.gd"))
	_root.add_child(goat)


func _check(label: String, ok: bool, detail: String) -> void:
	print("   %s %-40s %s" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_fails.append(label)


func _process(_d) -> bool:
	_f += 1
	if _f < 30:
		return false
	var goat: Node4D = _root.get_node("Goat")

	# A full rebuild, ten times, so one unlucky sample cannot flatter or damn it.
	var worst: float = 0.0
	var total: float = 0.0
	for i in 10:
		var before: int = Time.get_ticks_usec()
		goat.call("set_variation", float(i) / 9.0)
		var took: float = float(Time.get_ticks_usec() - before) / 1000.0
		worst = maxf(worst, took)
		total += took
	var mean: float = total / 10.0

	print("\n--- what a rebuild costs ---")
	print("      mean %.1f ms, worst %.1f ms, for %d tetrahedra"
		% [mean, worst, int(goat.call("tetra_count"))])
	# 16.6 ms is one frame at 60. A rebuild that fits inside a frame can happen while
	# somebody is watching; one that does not has to be spread out or dropped.
	_check("a rebuild fits inside a frame", worst < 16.6,
		"worst %.1f ms against a 16.6 ms budget" % worst)
	_check("so the animal can be assembled live", mean < 12.0,
		"mean %.1f ms, and the build lands one ball at a time" % mean)
	print("\n%d FAIL(s)" % _fails.size())
	quit(1 if _fails.size() > 0 else 0)
	return true
