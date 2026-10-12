extends SceneTree

## THE EXPLODER IS STABLE (WTools/PLAN.md step 53): its copies' dice come from each plant's name and the
## layer, so moving one plant must change only that plant's copies. The exploder lab twice: as it is, then
## with Oak05 moved a metre and Bush12 (if there) gone; every other copy must be where it was, the same bake,
## the same turn. And the same planting twice must be the same.
##
##   lab_run.sh headless wt_stable res://ramon/WTools/tests/_verify_exploder_stable_runner.gd

const LAB := "res://ramon/WTools/tests/exploder_lab.tscn"

var _fails: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, what: String, detail: String = "") -> void:
	print("  %s  %s  %s" % ["PASS" if ok else "FAIL", what, detail])
	if not ok:
		_fails += 1


func _frames(n: int) -> void:
	for i in n:
		await process_frame


## {copy name: [position, bake, basis]} for one planting, with [param change] applied before it starts.
func _planting(change: bool) -> Dictionary:
	var lab: Node = (load(LAB) as PackedScene).instantiate()
	lab.set("readout", false)
	var trees: Node = lab.get_node("Trees")
	if change:
		var moved := trees.get_node_or_null("Oak05") as Node4D
		if moved != null:
			moved.position += Vector4(1.0, 0.0, 0.0, 0.0)
		var gone: Node = trees.get_node_or_null("Bush12")
		if gone != null:
			trees.remove_child(gone)
			gone.free()
	root.add_child(lab)
	await _frames(10)
	var out: Dictionary = {}
	for c in trees.get_children():
		if c.has_meta(&"w_copy"):
			out[String(c.name)] = [(c as Node4D).position, String(c.get("bake")), (c as Node4D).basis]
	root.remove_child(lab)
	lab.free()
	await _frames(3)
	return out


func _run() -> void:
	var a: Dictionary = await _planting(false)
	var a2: Dictionary = await _planting(false)
	var same: bool = a.size() == a2.size()
	for k in a:
		if not a2.has(k) or not (a[k][0] as Vector4).is_equal_approx(a2[k][0]) or a[k][1] != a2[k][1]:
			same = false
	_check(same and a.size() > 0, "the same planting twice is the same", "%d copies" % a.size())
	var b: Dictionary = await _planting(true)
	var changed: Array = []
	for k in a:
		var own: bool = String(k).begins_with("Oak05_") or String(k).begins_with("Bush12_")
		if own:
			continue
		if not b.has(k) or not (a[k][0] as Vector4).is_equal_approx(b[k][0]) or a[k][1] != b[k][1] or a[k][2] != b[k][2]:
			changed.append(k)
	_check(changed.is_empty(), "moving Oak05 and taking Bush12 away changes no other plant's copies", "%d changed%s" % [changed.size(),
		(": " + ", ".join(PackedStringArray(changed.slice(0, 5)))) if not changed.is_empty() else ""])
	var oak05_moved: bool = false
	for k in a:
		if String(k).begins_with("Oak05_") and b.has(k) and not (a[k][0] as Vector4).is_equal_approx(b[k][0]):
			oak05_moved = true
	_check(oak05_moved or not a.keys().any(func(k): return String(k).begins_with("Oak05_")), "and Oak05's own copies moved with it")
	print("EXPLODER STABLE: %s (%d failed)" % ["PASS" if _fails == 0 else "FAIL", _fails])
	quit(1 if _fails > 0 else 0)
