extends Node4D

## A lab explanation as a sequence of bays you ride through W.
##
## THE IDEA (follow_up/creation_lab_plan.md): every step of an explanation is a bay, a small test
## cell with one rig, one lectern card and one task, and all the bays stand at the same place in
## the room, stacked along W. You only ever see the bay you are in, because the others are in other
## slices; finishing a step lights the W-lift, and riding it slides you through W to the next bay,
## the one you leave thinning away as the next grows in around you. No overwhelm, by construction,
## and by the end you have moved through W a dozen times without being told to.
##
## THE BEAT of every bay: arrive (the slide ends, the guide panel shows the step), show (the one
## idea), try (the one task, its keys as chips), unlock (the task ticks, a chime, the lectern's card
## opens its detail, the lift lights), next (N rides on; Shift+N goes back; M lists every floor).
##
## THE AXIS is one setting. W by default; if playtests show that riding through W confuses people,
## the same bays stand side by side along X (`axis` (1,0,0,0), `spacing` about 20) and the lift is
## simply a door: nothing else changes.
##
## WHAT IT OWNS: the bays (LabKit/lab_bay_4d.gd shells, each step's content scene, a lectern), the
## HUD (LabKit/lab_hud.gd), the lift, the task beat, the keys, and a leash that keeps you within
## the bay's slab of W. The steps are LabKit/lab_step.gd resources.
##
## NO class_name (engine_gotchas.md).

const Bay := preload("res://ramon/LabKit/lab_bay_4d.gd")
const Lectern := preload("res://ramon/LabKit/lab_lectern_4d.gd")
const Hud := preload("res://ramon/LabKit/lab_hud.gd")
const LabMath := preload("res://ramon/LabKit/lab_math.gd")
const Style := preload("res://ramon/LabKit/lab_style.gd")
const Overlay := preload("res://ramon/LabKit/lab_overlay_4d.gd")
const Mats := preload("res://ramon/LabKit/lab_materials.gd")
## Where the camera stands when you arrive on a pad, found by eye (CreationLab/scripts/
## _framing_runner.gd, 4 Oct). The orbit camera always centres the avatar, so from straight behind
## it the exhibit sits right behind the avatar's head; from 30 degrees to the left it stands clear
## beside the avatar, with the lectern and its card on the other side.
const ARRIVAL_YAW := -0.52
const ARRIVAL_PITCH := -0.28
const ARRIVAL_DISTANCE := 4.2

signal step_changed(index: int)
signal task_completed(index: int)
signal lift_started(from_index: int, to_index: int)

@export var steps: Array[Resource] = []
## Metres between bays along the axis.
@export_range(4.0, 60.0, 0.5) var spacing: float = 12.0
## The direction the bays are stacked in: W by default, X as the fallback.
@export var axis: Vector4 = Vector4(0.0, 0.0, 0.0, 1.0)
## guided: steps unlock in order. explore: every floor is open from the start. (watch: the
## autopilot, which drives the guided route by itself.)
@export_enum("guided", "watch", "explore") var mode: String = "guided"
@export var player_path: NodePath
@export_range(0.2, 6.0, 0.1) var lift_seconds: float = 1.4
@export_range(8.0, 60.0, 0.5) var bay_size: float = 14.0
## Metres you may stray along the axis from the bay's own position (turning the slice and
## walking moves you through W).
@export_range(0.5, 6.0, 0.1) var leash: float = 2.0
@export var start_index: int = 0
## Pixels (at 1080 p) the HUD keeps free along the bottom, for the shared back-to-menu prompt.
@export var hud_bottom_reserve: float = 0.0

var bays: Array = []
var current: int = -1
var hud: CanvasLayer
var player: CharacterBody4D
var _lift: Dictionary = {}
var _metrics_t: float = 0.0
var _slow: bool = false
## The controls card shows the step's own keys and the lift; C opens the rest (the rig's keys,
## the curious rows, the lab's), which at 720 p otherwise filled two thirds of the screen's height.
var all_controls: bool = false
var _frame_parts: Array = []   # [MeshInstance4D, size, "post" or "glow"]
var _mood: String = "bright"


func _enter_tree() -> void:
	add_to_group(Overlay.GROUP_DRAWER)
	add_to_group("lab_mood_listener")


func _ready() -> void:
	Overlay.ensure.call_deferred(get_tree())
	_mood = Style.mood_of(get_tree())
	_build()
	hud = CanvasLayer.new()
	hud.set_script(Hud)
	hud.name = "HUD"
	hud.set("bottom_reserve", hud_bottom_reserve)
	add_child(hud)
	# Deferred, so the scene's own _ready (which adds the player and picks the mode) runs first.
	_start.call_deferred()


func _start() -> void:
	if player == null:
		player = get_node_or_null(player_path) as CharacterBody4D
	enter(clampi(start_index, 0, maxi(steps.size() - 1, 0)), true)


func axis_n() -> Vector4:
	return axis.normalized() if axis.length() > 0.001 else Vector4(0.0, 0.0, 0.0, 1.0)


func bay_origin(i: int) -> Vector4:
	return axis_n() * spacing * float(i)


func _shell_part(part: String) -> String:
	return part if part in ["build", "motion"] else "neutral"


func _build() -> void:
	var along_w: bool = absf(axis_n().w) > 0.9
	for i in steps.size():
		var st: Resource = steps[i]
		var root := Node4D.new()
		root.name = "Bay%02d" % i
		root.position = bay_origin(i)
		add_child(root)
		var size: float = float(st.get("shell_size")) if st.get("shell_size") != null and float(st.get("shell_size")) > 0.0 else bay_size
		var shell := Node4D.new()
		shell.set_script(Bay)
		shell.name = "Shell"
		shell.set("size", size)
		shell.set("numeral", int(st.get("number")))
		shell.set("part", _shell_part(String(st.get("part"))))
		shell.set("floor_w", spacing * 0.97 if along_w else 6.0)
		root.add_child(shell)
		if st.get("show_shell") != null and not bool(st.get("show_shell")):
			shell.visible = false
		var content: Node = null
		if st.get("content") != null:
			content = (st.get("content") as PackedScene).instantiate()
			content.set("shell", shell)
			root.add_child(content)
		var lectern := Node4D.new()
		lectern.set_script(Lectern)
		lectern.name = "Lectern"
		lectern.set("part", _shell_part(String(st.get("part"))))
		lectern.position = shell.call("spot", "lectern")
		# Turned to face whoever stands on the pad.
		var to_pad: Vector4 = shell.call("spot", "pad") - lectern.position
		lectern.basis = Basis4D.from_zx(atan2(to_pad.x, to_pad.z))
		root.add_child(lectern)
		lectern.call("set_step", st, false)
		bays.append({"root": root, "shell": shell, "content": content, "lectern": lectern, "step": st, "done": false})
		_sleep(i)
	if along_w and not bays.is_empty():
		_build_lift_frame()


## THE LIFT FRAME: four slim posts around the pad, one object spanning the whole stack in W, so
## it is the one thing that stays put while the bays thin away and grow in around you during a
## ride (every bay's own pieces end within a few metres of it). The posts light in the W colour
## when the lift will take you on.
func _build_lift_frame() -> void:
	var frame := Node4D.new()
	frame.name = "LiftFrame"
	var n: int = bays.size()
	var span: float = spacing * float(n)
	var pad: Vector4 = (bays[0]["shell"] as Node).call("spot", "pad")
	frame.position = Vector4(pad.x, 0.0, pad.z, 0.0) + axis_n() * spacing * float(n - 1) * 0.5
	add_child(frame)
	# Two posts each side of the pad, like a gate you stand in: kept off the line from the
	# arrival camera (behind and to the left) to the exhibit.
	var height: float = 2.4
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var at := Vector4(sx * 1.55, 0.0, sz * 0.6, 0.0)
			_frame_box(frame, Vector4(0.05, height, 0.05, span), at + Vector4(0.0, height * 0.5, 0.0, 0.0), "post")
			# A strip of light on the face towards the pad, and a cap.
			var inward := Vector4(-sx * 0.045, 0.0, 0.0, 0.0)
			_frame_box(frame, Vector4(0.025, height * 0.86, 0.025, span * 0.999), at + inward + Vector4(0.0, height * 0.5, 0.0, 0.0), "glow")
			_frame_box(frame, Vector4(0.11, 0.03, 0.11, span * 0.999), at + Vector4(0.0, height + 0.015, 0.0, 0.0), "glow")
	apply_mood(_mood, true)


func _frame_box(parent: Node4D, size: Vector4, at: Vector4, kind: String) -> void:
	var m := MeshInstance4D.new()
	m.mesh = Mats.box_mesh(size)
	m.position = at
	parent.add_child(m)
	_frame_parts.append([m, size, kind])


func apply_mood(m: String, _instant: bool = false) -> void:
	_mood = m
	var lit: bool = current >= 0 and current < bays.size() - 1 and furthest_open() > current
	var dim: Color = Color(0.62, 0.64, 0.68) if m == Style.BRIGHT else Color(0.22, 0.24, 0.28)
	for p in _frame_parts:
		var mi: MeshInstance4D = p[0]
		if p[2] == "post":
			mi.material_override = Mats.surface(Style.surface("trim" if m == Style.BRIGHT else "metal", m), p[1], 1.0)
		else:
			mi.material_override = Mats.glow(Style.code("w_fill", m) if (lit or not _lift.is_empty()) else dim, 1.0)


func _wake(i: int) -> void:
	var r: Node4D = bays[i]["root"]
	r.visible = true
	r.process_mode = Node.PROCESS_MODE_INHERIT


func _sleep(i: int) -> void:
	var r: Node4D = bays[i]["root"]
	r.visible = false
	r.process_mode = Node.PROCESS_MODE_DISABLED


## Puts you in bay `i`: wakes it, starts its content, fills the HUD. `instant` also stands you on
## its pad facing the exhibit (the lift does that itself on a ride).
func enter(i: int, instant: bool = false) -> void:
	if bays.is_empty():
		return
	var prev: int = current
	if prev >= 0 and prev != i:
		var pc: Node = bays[prev]["content"]
		if pc != null and pc.has_method("end"):
			pc.call("end")
		_sleep(prev)
	current = i
	_wake(i)
	var b: Dictionary = bays[i]
	var c: Node = b["content"]
	if c != null and c.has_method("begin"):
		c.call("begin", self)
	if instant and player != null:
		_stand_on_pad(i)
	_light_lift()
	_refresh_hud()
	step_changed.emit(i)


func _stand_on_pad(i: int) -> void:
	var b: Dictionary = bays[i]
	var shell: Node = b["shell"]
	var pad: Vector4 = (b["root"] as Node4D).global_position + shell.call("spot", "pad") + Vector4(0.0, 0.05, 0.0, 0.0)
	player.global_position = pad
	player.linear_velocity = Vector4.ZERO
	_face_exhibit()


## The avatar towards the rig (-Z from the pad: the walker's facing PI) and the camera at the
## arrival framing (ARRIVAL_YAW and the rest).
func _face_exhibit() -> void:
	player.set("_facing", PI)
	var rig: Node = player.get_node_or_null("CameraRig")
	if rig != null:
		rig.set("yaw", ARRIVAL_YAW)
		rig.set("pitch", ARRIVAL_PITCH)
		rig.set("_zoom_target", ARRIVAL_DISTANCE)
		# The orbit rig only rebuilds its basis on mouse motion; values written from code need this.
		rig.call("_apply")


func _refresh_hud() -> void:
	if hud == null or current < 0:
		return
	var b: Dictionary = bays[current]
	var st: Resource = b["step"]
	hud.call("show_step", st, current, steps.size(), b["done"])
	hud.call("show_controls", _control_rows(), _extra_rows())
	var ladder: Array = []
	for i in bays.size():
		var s2: Resource = bays[i]["step"]
		ladder.append({"number": int(s2.get("number")), "title": String(s2.get("title")), "part": String(s2.get("part")),
			"done": bays[i]["done"], "w": int(round(bay_origin(i).dot(axis_n()))), "short": String(s2.get("part")).left(1).to_upper()})
	hud.call("set_ladder", ladder, current)


func _rig() -> Node:
	var c: Node = bays[current]["content"] if current >= 0 else null
	return c.call("rig") if c != null and c.has_method("rig") else null


func _control_rows() -> Array:
	var rows: Array = []
	var c: Node = bays[current]["content"]
	if c != null and c.has_method("controls"):
		rows.append_array(c.call("controls"))
	var b: Dictionary = bays[current]
	if current < bays.size() - 1:
		rows.append(["N", "ride the lift" if (b["done"] or mode == "explore") else "ride the lift (after the task)"])
	return rows


func _extra_rows() -> Array:
	var rows: Array = []
	if not all_controls:
		rows.append(["C", "all controls"])
		return rows
	var own: Array = []
	var c: Node = bays[current]["content"]
	if c != null and c.has_method("controls"):
		for r in c.call("controls"):
			own.append(String(r[0]))
	if _rig() != null:
		for r in [["Space", "play / pause"], [".", "step one frame"], [",", "slow motion"], ["V", "view: skin, blocks, lines, balls"], ["U", "turn it through W"]]:
			if not own.has(r[0]):
				rows.append(r)
	var st: Resource = bays[current]["step"]
	for e in st.get("extras"):
		var parts: PackedStringArray = String(e).split("|", true, 1)
		if parts.size() == 2:
			rows.append([parts[0], parts[1]])
	rows.append(["Shift+N", "back one step"])
	rows.append(["M", "every floor"])
	rows.append(["RMB", "hold and move: turn the slice"])
	rows.append(["R", "straighten the slice"])
	rows.append(["B", "bright / dark"])
	rows.append(["P", "projection"])
	rows.append(["F3", "hide every panel"])
	rows.append(["C", "fewer controls"])
	return rows


# -- the lift ------------------------------------------------------------------------------------

## The furthest step you may ride to: in guided mode, the first step whose task is not done yet.
func furthest_open() -> int:
	if mode == "explore":
		return bays.size() - 1
	for i in bays.size():
		if not bays[i]["done"]:
			return i
	return bays.size() - 1


func ride(to: int) -> void:
	if not _lift.is_empty() or to < 0 or to >= bays.size() or to == current:
		return
	if to > furthest_open():
		hud.call("chime", "Do this step's task first", "text", false)
		return
	var b: Dictionary = bays[current]
	var shell: Node = b["shell"]
	var pad_local: Vector4 = shell.call("spot", "pad") + Vector4(0.0, 0.05, 0.0, 0.0)
	_lift = {"from": current, "to": to, "t": 0.0, "phase": "glide",
		"start": player.global_position if player != null else Vector4.ZERO,
		"pad": (b["root"] as Node4D).global_position + pad_local, "pad_local": pad_local}
	if player != null:
		player.set("input_enabled", false)
		player.set_physics_process(false)
		player.linear_velocity = Vector4.ZERO
	_wake(to)
	hud.call("chime", "W " + w_label(to), "w", false)
	apply_mood(_mood, true)
	lift_started.emit(current, to)


func lifting() -> bool:
	return not _lift.is_empty()


func _advance_lift(delta: float) -> void:
	_lift["t"] = float(_lift["t"]) + delta
	var rig: Node = player.get_node_or_null("CameraRig") if player != null else null
	match String(_lift["phase"]):
		"glide":
			# Onto the pad and facing the exhibit, before the ride.
			var k: float = LabMath.ease01(float(_lift["t"]) / 0.45)
			if player != null:
				var s: Vector4 = _lift["start"]
				var p: Vector4 = _lift["pad"]
				player.global_position = Vector4(lerpf(s.x, p.x, k), lerpf(s.y, p.y, k), lerpf(s.z, p.z, k), lerpf(s.w, p.w, k))
			if rig != null:
				rig.set("yaw", lerp_angle(float(rig.get("yaw")), ARRIVAL_YAW, k))
				rig.set("pitch", lerpf(float(rig.get("pitch")), ARRIVAL_PITCH, k))
				rig.set("_zoom_target", ARRIVAL_DISTANCE)
				rig.call("_apply")
			if player != null:
				player.set("_facing", lerp_angle(float(player.get("_facing")), PI, k))
			if float(_lift["t"]) >= 0.45:
				_lift["phase"] = "ride"
				_lift["t"] = 0.0
		"ride":
			var e: float = LabMath.ease01(float(_lift["t"]) / lift_seconds)
			var from_o: Vector4 = global_position + bay_origin(int(_lift["from"]))
			var to_o: Vector4 = global_position + bay_origin(int(_lift["to"]))
			if player != null:
				player.global_position = from_o.lerp(to_o, e) + (_lift["pad_local"] as Vector4)
			hud.call("set_ladder_marker", lerpf(float(_lift["from"]), float(_lift["to"]), e))
			if float(_lift["t"]) >= lift_seconds:
				var to: int = int(_lift["to"])
				_lift = {}
				hud.call("set_ladder_marker", -1.0)
				enter(to, false)
				if player != null:
					player.set("input_enabled", true)
					player.set_physics_process(true)


# -- every frame ---------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if bays.is_empty() or current < 0:
		return
	if not _lift.is_empty():
		_advance_lift(delta)
		return
	var b: Dictionary = bays[current]
	var c: Node = b["content"]
	if not b["done"] and c != null and c.has_method("task_done") and bool(c.call("task_done")):
		_complete(current)
	_metrics_t += delta
	if _metrics_t > 0.25 and c != null and c.has_method("metrics"):
		_metrics_t = 0.0
		(b["lectern"] as Node).set("metrics", c.call("metrics"))


func _complete(i: int) -> void:
	var b: Dictionary = bays[i]
	b["done"] = true
	var st: Resource = b["step"]
	hud.call("set_done", true, String(st.get("after")), i < bays.size() - 1)
	hud.call("chime", "")
	(b["lectern"] as Node).call("set_step", st, true)
	_light_lift()
	_refresh_hud()
	task_completed.emit(i)


## Marks a step done from outside (the autopilot, a test).
func complete_current() -> void:
	if current >= 0 and not bays[current]["done"]:
		_complete(current)


func _physics_process(_delta: float) -> void:
	if player == null or not _lift.is_empty() or current < 0:
		return
	# The leash: turning the slice and walking moves you through W; stay within the bay's slab.
	var o: Vector4 = (bays[current]["root"] as Node4D).global_position
	var n: Vector4 = axis_n()
	var along: float = (player.global_position - o).dot(n)
	if absf(along) > leash:
		var excess: float = along - signf(along) * leash
		player.global_position -= n * excess
		var v: Vector4 = player.linear_velocity
		player.linear_velocity = v - n * v.dot(n)


# -- keys ----------------------------------------------------------------------------------------

func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo or not _lift.is_empty():
		return
	if bool(hud.call("floor_list_open")):
		match k.keycode:
			KEY_UP: hud.call("move_floor_selection", -1)
			KEY_DOWN: hud.call("move_floor_selection", 1)
			KEY_ENTER, KEY_KP_ENTER:
				var to: int = int(hud.call("floor_selection"))
				hud.call("close_floor_list")
				ride(to)
			KEY_M, KEY_ESCAPE: hud.call("close_floor_list")
		get_viewport().set_input_as_handled()
		return
	match k.keycode:
		KEY_N:
			ride(current - 1 if k.shift_pressed else current + 1)
			get_viewport().set_input_as_handled()
			return
		KEY_M:
			hud.call("open_floor_list", current)
			get_viewport().set_input_as_handled()
			return
		KEY_P:
			_toggle_projection()
			get_viewport().set_input_as_handled()
			return
		KEY_C:
			all_controls = not all_controls
			hud.call("show_controls", _control_rows(), _extra_rows())
			get_viewport().set_input_as_handled()
			return
		KEY_F3:
			# Every panel and card off, for a clean look or a screenshot; F3 again brings them back.
			var overlay: CanvasLayer = Overlay.ensure(get_tree()) as CanvasLayer
			hud.visible = not hud.visible
			if overlay != null:
				overlay.visible = hud.visible
			get_viewport().set_input_as_handled()
			return
	var c: Node = bays[current]["content"]
	if c != null and c.has_method("handle_key") and bool(c.call("handle_key", k)):
		get_viewport().set_input_as_handled()
		return
	var rig: Node = _rig()
	if rig == null:
		return
	var animal: Node = rig.get("animal")
	match k.keycode:
		KEY_SPACE:
			if animal != null:
				animal.call("set_paused", not bool(animal.call("is_paused")))
		KEY_PERIOD:
			if animal != null:
				animal.call("set_paused", true)
				animal.call("step_frame", 2)
		KEY_COMMA:
			_slow = not _slow
			if animal != null:
				animal.call("set_time_scale", 0.25 if _slow else 1.0)
		KEY_V:
			var views: Node = rig.get("views")
			if views != null:
				views.call("next_view")
		KEY_U:
			var spin: float = float(rig.call("get_w_spin"))
			rig.call("set_w_spin", 0.0 if k.shift_pressed else wrapf(spin + 30.0, -1.0, 181.0))
		_:
			return
	get_viewport().set_input_as_handled()


## P: the plain cut, or the cut plus a faint projection of everything along W (the Combined
## renderer), as the pen's P does (lookout_4d.gd).
func _toggle_projection() -> void:
	var cam: Camera4D = LabMath.current_camera(get_tree())
	if cam == null:
		return
	var on: bool = String(cam.get("rendering_engine_name")) != "Combined"
	cam.set("projection_opacity", 0.55)
	cam.set("projection_opacity_base", 0.05)
	cam.set("rendering_engine_name", "Combined" if on else "Cross-section")


## A bay's place along the axis as signage: "0", "+12", "+132".
func w_label(i: int) -> String:
	var w: int = int(round(bay_origin(i).dot(axis_n())))
	return "0" if w == 0 else "%+d" % w


func _light_lift() -> void:
	if current < 0:
		return
	var shell: Node = bays[current]["shell"]
	shell.call("set_lift_lit", current < bays.size() - 1 and furthest_open() > current)
	apply_mood(_mood, true)


# -- the lift's floor indicator --------------------------------------------------------------------

## A small tag over the pad: where the lift goes from here, or that it waits for the task.
func draw_overlay(canvas: Control, overlay: Node) -> void:
	if current < 0 or player == null:
		return
	var b: Dictionary = bays[current]
	var shell: Node = b["shell"]
	var root: Node4D = b["root"]
	# Beside the pad, to the left of whoever stands on it (the lectern's card is on the right).
	var anchor: Vector4 = root.global_position + shell.call("spot", "pad") + Vector4(-2.0, 0.9, 0.0, 0.0)
	if not _lift.is_empty():
		return
	var at = overlay.to_screen(anchor)
	if at == null:
		return
	var cam: Camera4D = overlay.get("camera")
	var dist: float = (cam.global_position - anchor).length() if cam != null else 5.0
	var fade: float = clampf((14.0 - dist) / 4.0, 0.0, 1.0) * float(overlay.slice_fade(anchor))
	if fade <= 0.01:
		return
	var mood: String = String(get_tree().get_first_node_in_group("lab_mood").get("mood")) if get_tree().get_first_node_in_group("lab_mood") != null else Style.BRIGHT
	var ui: float = clampf(canvas.get_viewport_rect().size.y / 1080.0, 0.7, 2.2)
	var k: float = clampf(5.0 / maxf(dist, 0.5), 0.7, 1.0) * ui
	var w_here: int = int(round(bay_origin(current).dot(axis_n())))
	var line1: String = "W-LIFT   W " + w_label(current)
	var line2: String
	var lit: bool = current < bays.size() - 1 and furthest_open() > current
	if current >= bays.size() - 1:
		line2 = "the last floor.  M lists them all"
	elif lit:
		line2 = "N  rides to W " + w_label(current + 1)
	else:
		line2 = "opens when the task is done"
	var f_kick: Font = Style.font("Bold")
	var f_body: Font = Style.font("SemiBold")
	var fs1: int = int(Style.size(Style.MICRO) * k)
	var fs2: int = int(Style.size(Style.CAPTION) * k)
	var wdt: float = maxf(f_kick.get_string_size(line1, HORIZONTAL_ALIGNMENT_LEFT, -1, fs1).x, f_body.get_string_size(line2, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x) + 24.0 * k
	var hgt: float = fs1 * 1.6 + fs2 * 1.5 + 14.0 * k
	var pos: Vector2 = (at as Vector2) - Vector2(wdt * 0.5, hgt + 6.0 * k)
	var box: StyleBoxFlat = Style.panel_box(mood, k)
	box.bg_color.a *= fade
	box.border_color.a *= fade
	box.shadow_color.a *= fade
	canvas.draw_style_box(box, Rect2(pos, Vector2(wdt, hgt)))
	var wc: Color = Style.code("w", mood) if lit else Style.ui("text_faint", mood)
	wc.a = fade
	canvas.draw_rect(Rect2(pos + Vector2(12.0 * k, -3.0 * k), Vector2(28.0 * k, 3.0 * k)), wc)
	canvas.draw_string(f_kick, pos + Vector2(12.0 * k, 7.0 * k + fs1), line1, HORIZONTAL_ALIGNMENT_LEFT, -1, fs1, wc)
	canvas.draw_string(f_body, pos + Vector2(12.0 * k, 7.0 * k + fs1 * 1.6 + fs2), line2, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, Color(Style.ui("text", mood), fade))
