extends SceneTree

## THE PREVIEW BUTTONS TOGGLE (Ramon, 7 Oct: "when i press it again it would be nice if it turns off"): the
## method behind each Preview button, called as the button calls it. The Exploder in its lab: copies on at
## the start, off at the first press, on again at the second (as many as before). The Optimiser on the
## Watchstone in its lab: worked at the start, put back exactly at the first press (every part where it was,
## nothing hidden, no copy), worked again at the second.
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


## Every mesh's place, turn and whether it shows, under [param node], by its path (or its place in the tree).
func _state(node: Node) -> Dictionary:
	var out: Dictionary = {}
	for mi in node.find_children("*", "MeshInstance4D", true, false):
		# By its place in the tree: generated parts get new names in each copy of the lab (@FenceGenerator4D@461).
		var key: String = String(node.get_path_to(mi))
		if key.contains("@"):
			key = "#%d %s" % [out.size(), (mi as Node).get_parent().get_class()]
		out[key] = [(mi as Node4D).position, (mi as Node4D).basis, (mi as Node4D).visible, (mi as Node).has_meta(&"w_hidden")]
	return out


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
	await _frames(5)
	# The Optimiser. The Watchstone untouched: the lab with its Optimiser off.
	lab = (load("res://ramon/WTools/tests/optimiser_lab.tscn") as PackedScene).instantiate()
	lab.set("readout", false)
	lab.get_node("WatchstoneW").set("enabled", false)
	root.add_child(lab)
	await _frames(20)
	var plain: Dictionary = _state(lab.get_node("Watchstone"))
	root.remove_child(lab)
	lab.free()
	await _frames(5)
	lab = (load("res://ramon/WTools/tests/optimiser_lab.tscn") as PackedScene).instantiate()
	lab.set("readout", false)
	var stone: Node4D = lab.get_node("Watchstone")
	root.add_child(lab)
	await _frames(20)
	var opt: Node = lab.get_node("WatchstoneW")
	var on_at_start: bool = bool(opt.get("applied"))
	opt.call("toggle_preview")
	await _frames(3)
	var back: Dictionary = _state(stone)
	var same: int = 0
	var off_list := PackedStringArray()
	for k in plain:
		var ok: bool = back.has(k) and (plain[k][0] as Vector4).is_equal_approx(back[k][0]) and plain[k][2] == back[k][2] and plain[k][3] == back[k][3]
		var bp: Projection = plain[k][1]
		var bb: Projection = back[k][1] if back.has(k) else Projection.IDENTITY
		for c in 4:
			ok = ok and Vector4(bp[c]).is_equal_approx(Vector4(bb[c]))
		same += 1 if ok else 0
		if not ok and off_list.size() < 5:
			off_list.append(k)
	_check(on_at_start and not bool(opt.get("applied")) and opt.get_node_or_null("WrapCopy") == null and back.size() == plain.size() and same == plain.size(),
		"Optimiser: worked at the start, a press puts the Watchstone back exactly", "%d of %d parts as they were%s" % [same, plain.size(),
		(" (off: " + ", ".join(off_list) + ")") if not off_list.is_empty() else ""])
	opt.call("toggle_preview")
	await _frames(3)
	_check(bool(opt.get("applied")) and int(opt.get("parts_deepened")) > 0 and opt.get_node_or_null("WrapCopy") != null, "and a press works it again")
	print("PREVIEW TOGGLE: %s (%d failed)" % ["PASS" if _fails == 0 else "FAIL", _fails])
	quit(1 if _fails > 0 else 0)
