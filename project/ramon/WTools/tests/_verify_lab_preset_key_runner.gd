extends SceneTree

## THE LAB'S PRESET KEY (WTools/PLAN.md step 50): in the exploder lab, P steps the W Exploder through "off"
## and each preset in exploder/presets, planting again each time. Press P once per preset and back to the
## first: each step's copies must be what that preset makes (none for off), the cull built again (no errors
## from freed copies), and the readout naming it.
##
##   lab_run.sh windowed wt_pkey res://ramon/WTools/tests/_verify_lab_preset_key_runner.gd

const LAB := "res://ramon/WTools/tests/exploder_lab.tscn"
const PRESETS := "res://ramon/WTools/exploder/presets/"

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


func _press_p() -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = KEY_P
		e.physical_keycode = KEY_P
		e.pressed = pressed
		Input.parse_input_event(e)
		await process_frame


func _run() -> void:
	var lab: Node = (load(LAB) as PackedScene).instantiate()
	root.add_child(lab)
	current_scene = lab
	await _frames(30)
	var trees: Node = lab.get_node("Trees")
	var names: Array = ["off"]
	for f in DirAccess.get_files_at(PRESETS):
		if f.ends_with(".tres"):
			names.append(f.get_basename())
	# What each preset makes, from a planting of its own (the same dice, so the same count).
	var want: Dictionary = {"off": 0}
	for n in names.slice(1):
		var probe: Node = (load(LAB) as PackedScene).instantiate()
		probe.set("readout", false)
		probe.get_node("Trees").set("preset", load(PRESETS + n + ".tres"))
		root.add_child(probe)
		await _frames(3)
		want[n] = int(probe.get_node("Trees").get("echo_count"))
		root.remove_child(probe)
		probe.free()
		await _frames(2)
	for i in names.size() + 1:
		await _press_p()
		await _frames(12)
		var n: String = names[i % names.size()]
		var copies: int = trees.get_children().filter(func(c: Node) -> bool: return c.has_meta(&"w_copy")).size()
		var label: String = (lab.get("_label") as Label).text if lab.get("_label") != null else ""
		_check(copies == int(want[n]) and int(trees.get("echo_count")) == int(want[n]) and label.contains(n) and bool(trees.get("_cull_ready")),
			"P %d: %s" % [i + 1, n], "%d copies (want %d), cull ready %s" % [copies, int(want[n]), str(trees.get("_cull_ready"))])
	print("LAB PRESET KEY: %s (%d failed)" % ["PASS" if _fails == 0 else "FAIL", _fails])
	quit(1 if _fails > 0 else 0)
