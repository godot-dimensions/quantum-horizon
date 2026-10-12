extends SceneTree

## The light oaks (scripts/_bake_oak_lite_runner.gd, pen_oak_4d.gd "bake"; Ramon, 6 Oct: "generate a few
## in lower quality and test"): the three lite bakes stood beside the pen's oak, then
##   1. frames: the four together, each close, the slice turned, and the dev look
##   2. what each costs: frame and GPU time with only that oak drawn (vsync off), against none
##   3. the slice culling: an oak three metres ana of the slice is not drawn and costs nothing; one in
##      the slice is drawn; turned slices are tested on the tree's box
##   4. copies of one bake share their leaves
##
##   PEN_LOOK=art lab_run.sh windowed oak_lite res://ramon/chickenpen/scripts/_verify_oak_lite_runner.gd

const Oak := preload("res://ramon/chickenpen/scripts/pen_oak_4d.gd")
const SliceAngles := preload("res://ramon/chickenpen/scripts/slice_angles_4d.gd")
const OUT := "res://smoke_test_output/pen_layout/oak_lite/"
## A row in the open field north of the pen, ten metres apart: the Arboretum's oak and the three lite
## ones, a second lite 2 behind to share leaves. COPIES of each are stood about for the cost (one
## tree's cost is under the frame's noise for the lighter ones).
const SPOTS := {"oak": Vector4(6.0, 0.0, -28.0, 0.0), "oak_lite1": Vector4(16.0, 0.0, -28.0, 0.0), "oak_lite2": Vector4(26.0, 0.0, -28.0, 0.0),
	"oak_lite3": Vector4(36.0, 0.0, -28.0, 0.0)}
const COPIES := 10
const VIEW := Vector4(21.0, 1.2, -10.0, 0.0)

var _room: Node
var _fails: int = 0
var _t0: int = 0
var _player: CharacterBody4D
var _rig: Node4D
var _oaks: Dictionary = {}


func _initialize() -> void:
	root.unfocusable = true
	_t0 = Time.get_ticks_msec()
	_run.call_deferred()


func _process(_d: float) -> bool:
	if Time.get_ticks_msec() - _t0 > 300000:
		print("OAK LITE TEST: gave up")
		return true
	return false


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		_fails += 1


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_room = (load("res://ramon/chickenpen/playable_world.tscn") as PackedScene).instantiate()
	for node in _room.find_children("*", "", true, false):
		if "debug_key_enabled" in node:
			node.set("debug_key_enabled", false)
	root.add_child(_room)
	current_scene = _room
	var world: Node4D = _room.get_node("World")
	# The pen's own oaks out of the way (the big one is up the Lookout rock now): only the test's count.
	for o in get_nodes_in_group(&"pen_oak"):
		(o as Node4D).visible = false
	for bake in SPOTS:
		var o := Node4D.new()
		o.set_script(Oak)
		o.set("bake", bake)
		o.name = "Oak_" + bake
		world.add_child(o)
		o.global_position = SPOTS[bake]
		_oaks[bake] = o
	var twin := Node4D.new()
	twin.set_script(Oak)
	twin.set("bake", "oak_lite2")
	twin.name = "Oak_twin"
	world.add_child(twin)
	twin.global_position = Vector4(26.0, 0.0, -38.0, 0.0)
	twin.visible = false
	# The copies, for the cost: a block of them on the field behind the row.
	var copies: Dictionary = {}
	for bake in SPOTS:
		copies[bake] = []
		for k in COPIES:
			var c := Node4D.new()
			c.set_script(Oak)
			c.set("bake", bake)
			c.name = "Copy_%s_%d" % [bake, k]
			world.add_child(c)
			c.global_position = (SPOTS[bake] as Vector4) + Vector4(float(k % 5) * 1.5 - 3.0, 0.0, -12.0 - float(k / 5) * 4.0, 0.0)
			c.visible = false
			(copies[bake] as Array).append(c)
	await _frames(60)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	_player = _room.get_node("Player") as CharacterBody4D
	_player.set("input_enabled", false)
	_rig = _player.get_node("CameraRig") as Node4D
	for c in _room.get_node("UI").get_children():
		if c is CanvasItem:
			(c as CanvasItem).visible = false
	var panel: Node = _room.get_node_or_null("UI/GrassPanel")
	if panel != null:
		panel.process_mode = Node.PROCESS_MODE_DISABLED
	# 4. Shared leaves.
	for bake in _oaks:
		var lv: Node = _oaks[bake].get("leaves")
		print("   %s: %s leaves" % [bake, str(lv.get("count")) if lv != null else "none"])
	var a: Node = (_oaks["oak_lite2"] as Node).get("leaves")
	var b: Node = twin.get("leaves")
	_check(a != null and b != null and int(a.get("count")) > 0 and int(a.get("count")) == int(b.get("count")), "4 two lite-2 oaks share one set of leaves")
	# 1. Frames.
	await _shot("lineup", VIEW, 0.0, 4.0, 12.0)
	for bake in _oaks:
		var p: Vector4 = (_oaks[bake] as Node4D).global_position
		await _shot("close_" + bake, p + Vector4(0.0, 1.2, 8.0, 0.0), 0.0, 10.0, 8.0)
	await _shot("lineup_turned", VIEW, 0.0, 4.0, 12.0, Vector2(30.0, 0.0))
	# 2. Cost: the row's oak and its copies of each bake drawn, nothing else of the trees.
	_place(VIEW, 0.0, 4.0, 12.0)
	var all: Array = _oaks.values()
	for o in all:
		(o as Node4D).visible = false
	var none: Array = await _measure("no oak")
	for bake in _oaks:
		(_oaks[bake] as Node4D).visible = true
		var one: Array = await _measure(bake + " x1")
		for c in copies[bake]:
			(c as Node4D).visible = true
		var many: Array = await _measure(bake + " x%d" % (COPIES + 1))
		print("COST %s: one +%.2f ms GPU (+%.2f frame); %d of them +%.2f ms GPU (+%.2f frame), %.3f ms GPU a tree" % [bake, one[1] - none[1],
			one[0] - none[0], COPIES + 1, many[1] - none[1], many[0] - none[0], (many[1] - none[1]) / float(COPIES + 1)])
		for c in copies[bake]:
			(c as Node4D).visible = false
		(_oaks[bake] as Node4D).visible = false
	# 3. The slice culling, on lite 2: three metres ana it is not drawn, and costs nothing.
	var lite: Node4D = _oaks["oak_lite2"]
	lite.visible = true
	var cam: Camera4D = _player.get_node("CameraRig/Pitch/Camera4D") as Camera4D
	await _frames(3)
	_check(bool(lite.call("is_cut_by", cam)) and (lite.get_node("Tree") as Node4D).visible, "3 in the slice: drawn")
	# The oak is squashed through W, not thin: its wood reaches about 2.2 m ana and kata, so a slice 3 m
	# out still grazes its box; 5 m out it does not.
	print("   lite 2's box reaches %.2f m through W" % float((lite.get("_half") as Vector4).w * (lite.get_node("Tree") as Node4D).scale.w))
	var big: Array = copies["oak"]
	_oaks["oak"].visible = true
	for c in big:
		(c as Node4D).visible = true
	_player.global_position = VIEW + Vector4(0.0, 0.0, 0.0, 5.0)
	await _frames(30)
	_check(not bool(lite.call("is_cut_by", cam)) and not (lite.get_node("Tree") as Node4D).visible, "3 five metres ana: not drawn")
	var culled: Array = await _measure("the Arboretum's oak x%d and lite 2, 5 m ana, culled" % (COPIES + 1))
	for o in [_oaks["oak"], lite] + big:
		o.set("slice_cull", false)
		(o.get_node("Tree") as Node4D).visible = true
	var drawn: Array = await _measure("the same, drawn anyway")
	for o in [_oaks["oak"], lite] + big:
		o.set("slice_cull", true)
	print("CULL 5 m ana: GPU %.2f ms culled, %.2f ms drawn anyway (no oak %.2f)" % [culled[1], drawn[1], none[1]])
	_check(culled[1] <= none[1] + 0.2 and drawn[1] > culled[1] + 1.0, "3 culled, %d heavy oaks off the slice cost nothing (%.2f against %.2f ms GPU; %.2f drawn)" % [
		COPIES + 1, culled[1], none[1], drawn[1]])
	for c in big:
		(c as Node4D).visible = false
	# A slice turned a quarter into W from 5 m ana runs across x through the camera: it cuts the trees
	# whose x is within their box of the camera's.
	SliceAngles.tilt(_rig, deg_to_rad(90.0), 0.0, 0.0)
	await _frames(10)
	print("   turned a quarter (xw) from 5 m ana: lite 2 (x 26, the camera's x 21) cut %s" % str(lite.call("is_cut_by", cam)))
	# 1. The dev look: every oak its blockout.
	all.append(twin)
	for o in all:
		(o as Node4D).visible = true
	_player.global_position = VIEW
	SliceAngles.tilt(_rig, 0.0, 0.0, 0.0)
	_room.get_node("Systems/Look").call("set_dev", true)
	await _frames(10)
	var blocks: int = 0
	for o in all:
		blocks += (o as Node).find_children("DevBlockout_*", "MeshInstance4D", true, false).size()
		var lv: Node = (o as Node).get("leaves")
		_check(lv == null or not bool(lv.get("enabled")), "1 dev look: %s's leaves off" % (o as Node).name)
	_check(blocks >= all.size(), "1 dev look: every oak has its blockout (%d blockouts, %d oaks)" % [blocks, all.size()])
	await _shot("lineup_dev", VIEW, 0.0, 4.0, 12.0)
	_room.get_node("Systems/Look").call("set_dev", false)
	await _frames(5)
	print("OAK LITE TEST: %s (%d failed)" % ["PASS" if _fails == 0 else "FAIL", _fails])
	quit(0)


func _place(at: Vector4, yaw: float, pitch: float, distance: float, tilt: Vector2 = Vector2.ZERO) -> void:
	_player.global_position = at
	_player.set("linear_velocity", Vector4.ZERO)
	SliceAngles.tilt(_rig, deg_to_rad(tilt.x), deg_to_rad(tilt.y), deg_to_rad(yaw))
	_rig.set("pitch", deg_to_rad(pitch))
	_rig.set("distance", distance)
	_rig.set("_zoom_target", distance)
	if _rig.has_method("_apply"):
		_rig.call("_apply")


func _shot(name: String, at: Vector4, yaw: float, pitch: float, distance: float, tilt: Vector2 = Vector2.ZERO) -> void:
	_place(at, yaw, pitch, distance, tilt)
	await _frames(40)
	root.get_texture().get_image().save_png(OUT + name + ".png")
	print("FRAME %s%s.png" % [OUT, name])


## [frame ms, GPU ms], medians over 150 frames.
func _measure(label: String) -> Array:
	await _frames(20)
	var rid: RID = root.get_viewport_rid()
	var cpu: Array = []
	var gpu: Array = []
	var last: int = Time.get_ticks_usec()
	for k in 150:
		await process_frame
		var now: int = Time.get_ticks_usec()
		cpu.append((now - last) / 1000.0)
		last = now
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
	cpu.sort()
	gpu.sort()
	var out: Array = [cpu[75], gpu[75]]
	print("MEASURE %s: frame %.2f ms, GPU %.2f ms (medians of 150)" % [label, out[0], out[1]])
	return out
