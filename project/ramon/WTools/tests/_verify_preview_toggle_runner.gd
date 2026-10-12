extends SceneTree

## THE PREVIEW BUTTONS TOGGLE (Ramon, 7 Oct: "when i press it again it would be nice if it turns off"): the
## method behind the Preview button, called as the button calls it. The Exploder in its lab: copies on at
## the start, off at the first press, on again at the second (as many as before).
##
##   lab_run.sh windowed wt_toggle res://ramon/WTools/tests/_verify_preview_toggle_runner.gd

var _fails: int = 0


func _initialize() -> void:
	root.unfocusable = true
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _check(ok: bool, what: String, detail: String = "") -> void:
	print("  %s  %s  %s" % ["PASS" if ok else "FAIL", what, detail])
	if not ok:
		_fails += 1


func _copies(trees: Node) -> int:
	return trees.get_children().filter(func(c: Node) -> bool: return c.has_meta(&"w_copy")).size()


func _run() -> void:
	# The Exploder.
	var lab: Node = (load("res://ramon/WTools/tests/exploder_lab.tscn") as PackedScene).instantiate()
	lab.set("readout", false)
	root.add_child(lab)
	await _frames(20)
	var trees: Node = lab.get_node("Trees")
	var first: int = _copies(trees)
	trees.call("toggle_preview")
	await _frames(3)
	var off: int = _copies(trees)
	trees.call("toggle_preview")
	await _frames(3)
	var again: int = _copies(trees)
	_check(first > 0 and off == 0 and again == first, "Exploder: on, a press takes the copies away, a press brings them back",
		"%d, %d, %d" % [first, off, again])
	root.remove_child(lab)
	lab.free()
	print("PREVIEW TOGGLE: %s (%d failed)" % ["PASS" if _fails == 0 else "FAIL", _fails])
	quit(1 if _fails > 0 else 0)
