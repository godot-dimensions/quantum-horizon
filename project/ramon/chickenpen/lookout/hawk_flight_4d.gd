extends Node

## U: fly as the hawk (Ramon, 2 Oct: "can you also introduce the fly as a hawk mode?").
##
## IT IS THE FLOCK'S OWN HAWK. The sparrowhawk that comes through the murmuration every half
## minute is handed to you (pen_flock_4d.gd pilot_hawk / fly_hawk): its hunt stands down and
## it goes where you fly it. The starlings flee it and roll away from it exactly as they do
## from the hunting hawk - the hole that opens round you and the dark band that runs across
## the flock are the flock's own answer to your flying, worked out by the same rules
## (Hemelrijk's agitation waves), not an animation played for you.
##
## THE 4D PART. The flock is thin along W (half a metre deep) and you are not: E and Q slide
## you ana and kata through it, the camera's slice going with you. A metre or so out of their
## W and the birds vanish from the picture - and stop fleeing, because a hawk a metre ana of
## them is not near them at all, whatever the screen says. The HUD gives your W against the
## flock's, and P draws the flock as a ghost when you are out of its slice.
##
## FLIGHT, KEPT SIMPLE. Mouse steers (turn and climb), W flaps (faster), S brakes, Space
## climbs, Shift folds the wings - the stoop: no flapping, and gravity takes you as fast as
## the dive is steep. Speed follows a target with gravity along the flight path added in, so a
## climb bleeds speed and a dive builds it. It cannot fly into the ground (lookout_ground_4d).
## A third-person chase camera, its view widening with speed.
##
## While you fly, the pen's HUD is put away and the player stands where they were, still and
## visible below. U or Esc gives the hawk back: it flies on out, and you are on the ground.

const STYLE := preload("res://ramon/Menu/style/menu_final_style.tres")
const G := 9.81

@export var key: Key = KEY_U
@export_range(4.0, 30.0, 0.5, "suffix:m/s") var cruise_speed: float = 12.0
@export_range(4.0, 40.0, 0.5, "suffix:m/s") var flap_speed: float = 18.0
@export_range(2.0, 20.0, 0.5, "suffix:m/s") var slow_speed: float = 7.0
@export_range(10.0, 60.0, 0.5, "suffix:m/s") var stoop_speed: float = 32.0
@export_range(0.0005, 0.01, 0.0001) var mouse_sensitivity: float = 0.0028
@export_range(0.5, 10.0, 0.1, "suffix:m/s") var w_speed: float = 2.5
@export_range(2.0, 20.0, 0.1, "suffix:m") var chase_distance: float = 4.5
@export_range(0.0, 6.0, 0.1, "suffix:m") var chase_height: float = 1.0
@export_range(0.5, 10.0, 0.1, "suffix:m") var min_height: float = 2.0

var lookout: Node
var flock: Node4D
var camera: Camera4D
var flying: bool = false
## The hawk as flown: where it is, its heading as yaw and pitch, speed, bank, how hard it is
## flapping (0 to 1), and whether the wings are folded.
var at: Vector4
var yaw: float = 0.0
var pitch: float = 0.0
var speed: float = 12.0
var bank: float = 0.0
var flapping: float = 0.0
var stooping: bool = false
## The metrics, refreshed four times a second.
var stats: Dictionary = {}
var cards: bool = true

var _turn: Vector2 = Vector2.ZERO
var _yaw_rate: float = 0.0
var _saved: Dictionary = {}
var _t: float = 0.0
var _from_pos: Vector4
var _from_basis: Projection
var _eye: Vector4
var _stats_t: float = 0.0
var _chase: float = 6.0
var _hud: Control
var _layer: CanvasLayer


func setup(owner_lookout: Node) -> void:
	lookout = owner_lookout
	flock = lookout.get("room").get_node_or_null("World/Flock") as Node4D
	_chase = chase_distance
	_layer = CanvasLayer.new()
	_layer.name = "HawkHUD"
	_layer.layer = 6
	add_child(_layer)
	_hud = Hud.new()
	_hud.set("flight", self)
	_layer.add_child(_hud)
	_hud.visible = false


## On foot, with nothing else going on.
func can_fly() -> bool:
	if flock == null or flying or not flock.has_method("pilot_hawk"):
		return false
	var station: Node = lookout.get("station")
	if station != null and (int(station.get("mode")) != 0 or bool(station.call("_talking"))):
		return false
	if bool(lookout.call("story_busy")):
		return false
	var book: Control = lookout.get("book")
	return book == null or not book.visible


func start() -> void:
	if not can_fly():
		return
	flying = true
	var room: Node = lookout.get("room")
	var player: Node4D = lookout.get("player")
	var farm: Camera4D = lookout.call("current_camera")
	# Up behind the player and above, heading the way they were looking.
	var look: Vector4 = farm.global_basis * Vector4(0.0, 0.0, -1.0, 0.0)
	yaw = atan2(-look.x, -look.z)
	pitch = -0.12
	speed = cruise_speed
	bank = 0.0
	at = player.global_position + Vector4(0.0, 10.0, 0.0, 0.0) - _flat_ahead() * 4.0
	# The pen put away: its HUD, the player's legs, the cursor.
	var hud: Dictionary = {}
	for child in room.get_node("UI").get_children():
		if child is CanvasItem:
			hud[child] = (child as CanvasItem).visible
			(child as CanvasItem).visible = false
	_saved = {"hud": hud, "input": player.get("input_enabled"), "mode": player.process_mode, "mouse": Input.mouse_mode, "farm": farm}
	player.set("input_enabled", false)
	player.process_mode = Node.PROCESS_MODE_DISABLED
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	camera = Camera4D.new()
	camera.name = "HawkCamera"
	camera.set("rendering_engine_name", "Combined" if bool(lookout.get("projection")) else "Cross-section")
	camera.set("projection_opacity", float(lookout.get("projection_opacity")))
	camera.set("projection_opacity_base", float(lookout.get("projection_opacity_base")))
	camera.set("field_of_view_4d", 1.2)
	camera.set("w_fade_distance", 6.0)
	room.add_child(camera)
	camera.global_position = farm.global_position
	camera.global_basis = farm.global_basis
	camera.make_current()
	_from_pos = farm.global_position
	_from_basis = farm.global_basis
	_eye = _chase_eye()
	_t = 0.0
	flock.call("pilot_hawk", true)
	_fly_flock()
	_hud.visible = true


func stop() -> void:
	if not flying:
		return
	flying = false
	flock.call("pilot_hawk", false)
	var room: Node = lookout.get("room")
	var player: Node4D = lookout.get("player")
	var hud: Dictionary = _saved.get("hud", {})
	for item in hud:
		if is_instance_valid(item):
			(item as CanvasItem).visible = hud[item]
	player.set("input_enabled", _saved.get("input", true))
	player.process_mode = _saved.get("mode", Node.PROCESS_MODE_INHERIT)
	Input.mouse_mode = _saved.get("mouse", Input.MOUSE_MODE_CAPTURED)
	var farm: Camera4D = _saved.get("farm") as Camera4D
	if is_instance_valid(farm):
		farm.make_current()
	elif room.get_node_or_null("Player/CameraRig/Pitch/Camera4D") != null:
		(room.get_node("Player/CameraRig/Pitch/Camera4D") as Camera4D).make_current()
	if is_instance_valid(camera):
		camera.queue_free()
	camera = null
	_hud.visible = false


func _exit_tree() -> void:
	if flying and flock != null and is_instance_valid(flock):
		flock.call("pilot_hawk", false)


func _input(event: InputEvent) -> void:
	var press := event as InputEventKey
	if not flying:
		if press != null and press.pressed and not press.echo and press.keycode == key and can_fly():
			get_viewport().set_input_as_handled()
			start()
		return
	if event is InputEventMouseMotion:
		_turn += (event as InputEventMouseMotion).relative * mouse_sensitivity
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var button: int = (event as InputEventMouseButton).button_index
		if button == MOUSE_BUTTON_WHEEL_UP:
			_chase = clampf(_chase / 1.15, 3.0, 20.0)
		elif button == MOUSE_BUTTON_WHEEL_DOWN:
			_chase = clampf(_chase * 1.15, 3.0, 20.0)
		get_viewport().set_input_as_handled()
	elif press != null and press.pressed and not press.echo:
		if press.keycode == key or press.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			stop()
		elif press.keycode == KEY_F3:
			cards = not cards
			get_viewport().set_input_as_handled()
		elif press.keycode == KEY_P or press.keycode == KEY_F4:
			# The projection and the overlay are the Lookout's; let them through.
			pass
		else:
			# Everything else is the hawk's while you fly: the belt and the pen's keys wait.
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not flying:
		return
	_t += delta
	var dt: float = minf(delta, 1.0 / 20.0)
	# Steering: the mouse turns and climbs; the turn rate is what banks it.
	var before: float = yaw
	yaw -= _turn.x
	stooping = Input.is_physical_key_pressed(KEY_SHIFT)
	pitch = clampf(pitch - _turn.y, -1.4 if stooping else -1.0, 0.9)
	_turn = Vector2.ZERO
	_yaw_rate = lerpf(_yaw_rate, (yaw - before) / maxf(dt, 0.0001), clampf(dt * 6.0, 0.0, 1.0))
	bank = lerpf(bank, clampf(atan(_yaw_rate * speed / G), -1.1, 1.1), clampf(dt * 4.0, 0.0, 1.0))
	# Speed: a target from the keys, with gravity along the path added in.
	var flap_key: bool = Input.is_physical_key_pressed(KEY_W)
	var brake: bool = Input.is_physical_key_pressed(KEY_S)
	var climb: bool = Input.is_physical_key_pressed(KEY_SPACE)
	var target: float = cruise_speed
	if flap_key:
		target = flap_speed
	if brake:
		target = slow_speed
	if stooping:
		target = lerpf(cruise_speed, stoop_speed, clampf(-sin(pitch) * 1.4, 0.0, 1.0))
	speed += (target - speed) * (0.5 if stooping else 1.1) * dt - G * sin(pitch) * 0.55 * dt
	speed = clampf(speed, 5.0, stoop_speed + 6.0)
	# Flapping: on W or Space, and on its own when it is slower than it likes; never stooping.
	var want_flap: float = 0.0
	if not stooping:
		want_flap = 1.0 if (flap_key or climb) else (0.6 if speed < cruise_speed - 1.0 or pitch > 0.25 else 0.0)
	flapping = lerpf(flapping, want_flap, clampf(dt * 5.0, 0.0, 1.0))
	var heading: Vector4 = _heading()
	at += heading * (speed * dt)
	if climb and not stooping:
		at.y += 4.5 * dt
	# Along W: E ana, Q kata, the camera's slice going with you.
	var w_in: float = (1.0 if Input.is_physical_key_pressed(KEY_E) else 0.0) - (1.0 if Input.is_physical_key_pressed(KEY_Q) else 0.0)
	at.w += w_in * w_speed * dt
	# Not into the ground, not off into space, not out of the world.
	var ground: RefCounted = lookout.get("ground")
	var floor_y: float = float(ground.call("height", at.x, at.z)) if ground != null else 0.0
	if at.y < floor_y + min_height:
		at.y = floor_y + min_height
		pitch = maxf(pitch, 0.05)
	at.y = minf(at.y, 140.0)
	var out := Vector2(at.x, at.z)
	if out.length() > 200.0:
		# Turned back in, gently.
		yaw = lerp_angle(yaw, atan2(at.x, at.z), clampf(dt * 0.8, 0.0, 1.0))
	_fly_flock()
	_place_camera(dt)
	_stats_t -= delta
	if _stats_t <= 0.0:
		_stats_t = 0.25
		_measure()


func _heading() -> Vector4:
	return Vector4(-sin(yaw) * cos(pitch), sin(pitch), -cos(yaw) * cos(pitch), 0.0)


func _flat_ahead() -> Vector4:
	return Vector4(-sin(yaw), 0.0, -cos(yaw), 0.0)


func _fly_flock() -> void:
	flock.call("fly_hawk", at, _heading(), speed, bank, flapping)


func _chase_eye() -> Vector4:
	return at - _flat_ahead() * _chase + Vector4(0.0, chase_height + _chase * 0.12, 0.0, 0.0) - Vector4(0.0, sin(pitch) * _chase * 0.5, 0.0, 0.0)


## Behind and a little above, easing after the hawk; swooping in from the farm camera at first.
func _place_camera(dt: float) -> void:
	_eye = _eye.lerp(_chase_eye(), clampf(dt * 5.0, 0.0, 1.0))
	_eye.w = at.w
	# A little ahead of the hawk and above it, so the hawk sits low in the frame with the
	# flock ahead of it.
	var look_at: Vector4 = at + _heading() * 5.0 + Vector4(0.0, 0.6, 0.0, 0.0)
	var d: Vector4 = look_at - _eye
	var basis: Projection = Basis4D.from_zx(atan2(-d.x, -d.z)) * Basis4D.from_yz(atan2(d.y, Vector2(d.x, d.z).length())) * Basis4D.from_xy(-bank * 0.25)
	var k: float = smoothstep(0.0, 1.3, _t)
	camera.global_position = _from_pos.lerp(_eye, k)
	camera.global_basis = basis if k >= 1.0 else _blend_basis(_from_basis, basis, k)
	# Wider the faster: the sense of speed in a stoop.
	camera.set("field_of_view_4d", lerpf(1.15, 1.5, clampf((speed - cruise_speed) / (stoop_speed - cruise_speed), 0.0, 1.0)))


func _blend_basis(a: Projection, b: Projection, k: float) -> Projection:
	var out := Projection(a.x.lerp(b.x, k), a.y.lerp(b.y, k), a.z.lerp(b.z, k), a.w.lerp(b.w, k))
	return Basis4D.orthonormalized(out)


func _measure() -> void:
	var s: Dictionary = flock.call("stats")
	var middle: Vector4 = flock.global_position + flock.global_basis * (flock.get("_middle") as Vector4)
	var gap: Vector4 = middle - at
	var ground: RefCounted = lookout.get("ground")
	var floor_y: float = float(ground.call("height", at.x, at.z)) if ground != null else 0.0
	var half: float = float(flock.get("w_half_depth"))
	stats = {
		"speed": speed, "height": at.y - floor_y, "w": at.w, "flock_w": middle.w, "flock_half": half,
		"flock_far": Vector3(gap.x, gap.y, gap.z).length(), "in_slice": absf(gap.w) <= half + 0.6,
		"rolling": int(s.get("rolling", 0)), "birds": int(s.get("birds", 0)), "scare": float(flock.get("scare_radius")),
	}


## The HUD while you fly: a strip across the top, and two cards in the pen's style - the
## numbers on the left, every key on the right. F3 hides the cards.
class Hud extends Control:
	const STYLE := preload("res://ramon/Menu/style/menu_final_style.tres")
	const KEYS := [["Mouse", "steer: turn and climb"], ["W", "flap: faster"], ["S", "brake"], ["Space", "climb"],
		["Shift", "fold the wings: stoop"], ["E  Q", "slide ana / kata, through W"], ["Wheel", "camera nearer / further"],
		["P", "projection on / off"], ["U  Esc", "land: give the hawk back"], ["F3", "hide the cards"], ["F4", "developer overlay"]]
	var flight: Node
	var _font: Font
	var _card: StyleBoxFlat
	var _chip: StyleBoxFlat

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_font = get_theme_default_font()
		_card = StyleBoxFlat.new()
		_card.bg_color = Color(0.04, 0.05, 0.08, 0.34)
		_card.border_color = Color(1.0, 1.0, 1.0, 0.07)
		_card.set_border_width_all(1)
		_card.set_corner_radius_all(9)
		_chip = StyleBoxFlat.new()
		_chip.bg_color = Color(1.0, 1.0, 1.0, 0.11)
		_chip.border_color = Color(1.0, 1.0, 1.0, 0.20)
		_chip.set_border_width_all(1)
		_chip.set_corner_radius_all(4)

	func _process(_delta: float) -> void:
		if visible:
			queue_redraw()

	func _draw() -> void:
		if flight == null or not bool(flight.get("flying")):
			return
		var s: Vector2 = get_viewport_rect().size
		# The strip: what you are, in the camera's red-dot manner.
		draw_rect(Rect2(0, 0, s.x, 40.0), Color(0.0, 0.0, 0.0, 0.45))
		draw_circle(Vector2(30.0, 20.0), 5.0, STYLE.accent.lightened(0.2))
		draw_string(_font, Vector2(44.0, 26.0), "FLYING AS THE HAWK", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.9))
		var st: Dictionary = flight.get("stats")
		var note: String = "stooping" if bool(flight.get("stooping")) else ("flapping" if float(flight.get("flapping")) > 0.5 else "gliding")
		var nw: float = _font.get_string_size(note, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		draw_string(_font, Vector2(s.x - 30.0 - nw, 26.0), note, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.8))
		if not bool(flight.get("cards")) or st.is_empty():
			return
		var in_slice: bool = bool(st["in_slice"])
		var rows: Array = [
			["speed", "%d km/h  ·  %.0f m/s" % [int(round(float(st["speed"]) * 3.6)), float(st["speed"])]],
			["height", "%d m above the ground" % int(round(float(st["height"])))],
			["your W", "%+.1f m  ·  the flock at %+.1f, %.1f m deep" % [float(st["w"]), float(st["flock_w"]), float(st["flock_half"]) * 2.0]],
			["flock", "%d m off  ·  %s" % [int(round(float(st["flock_far"]))), "in your slice" if in_slice else "out of your slice: they can't see you"]],
			["rolling", "%d of %d birds, rolling away from you" % [int(st["rolling"]), int(st["birds"])]],
			["fear", "birds within %d m flee and roll (a 4D distance)" % int(st["scare"])],
		]
		var ts: int = 12
		var step: float = float(ts) + 7.0
		var w: float = 330.0
		var top := Vector2(16.0, 56.0)
		var h: float = 12.0 + step * float(rows.size() + 1)
		draw_style_box(_card, Rect2(top, Vector2(w, h)))
		draw_rect(Rect2(top + Vector2(14.0, -6.0), Vector2(34.0, 3.0)), STYLE.accent.lightened(0.3))
		var asc: float = _font.get_ascent(ts)
		var y: float = top.y + 12.0
		draw_string(_font, Vector2(top.x + 14.0, y + asc), "Hawk  ·  the flock's own, flown by you", HORIZONTAL_ALIGNMENT_LEFT, -1, ts, Color(1, 1, 1, 0.55))
		y += step
		for row in rows:
			draw_string(_font, Vector2(top.x + 14.0, y + asc), String(row[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, ts, Color(1, 1, 1, 0.45))
			var value_c := Color(1, 1, 1, 0.9)
			if String(row[0]) == "flock" and not in_slice:
				value_c = STYLE.accent.lightened(0.45)
			draw_string(_font, Vector2(top.x + 80.0, y + asc), String(row[1]), HORIZONTAL_ALIGNMENT_LEFT, w - 96.0, ts, value_c)
			y += step
		# The keys.
		var chip_w: float = 0.0
		var label_w: float = 0.0
		for k in KEYS:
			chip_w = maxf(chip_w, _font.get_string_size(String(k[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, ts - 1).x + 14.0)
			label_w = maxf(label_w, _font.get_string_size(String(k[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, ts).x)
		var kw: float = 14.0 + chip_w + 10.0 + label_w + 16.0
		var kh: float = 12.0 + step * float(KEYS.size() + 1)
		var kat := Vector2(s.x - 16.0 - kw, 56.0)
		draw_style_box(_card, Rect2(kat, Vector2(kw, kh)))
		y = kat.y + 12.0
		draw_string(_font, Vector2(kat.x + 14.0, y + asc), "Hawk keys", HORIZONTAL_ALIGNMENT_LEFT, -1, ts, Color(1, 1, 1, 0.55))
		y += step
		for k in KEYS:
			var chip := Rect2(Vector2(kat.x + 14.0, y - 1.0), Vector2(chip_w, float(ts) + 5.0))
			draw_style_box(_chip, chip)
			var cw: float = _font.get_string_size(String(k[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, ts - 1).x
			draw_string(_font, Vector2(chip.position.x + (chip.size.x - cw) * 0.5, y + asc), String(k[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, ts - 1, Color(1, 1, 1, 0.9))
			draw_string(_font, Vector2(chip.end.x + 10.0, y + asc), String(k[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, ts, Color(1, 1, 1, 0.82))
			y += step
		# Where the flock is, when it is off screen: an arrow at the edge.
		var cam: Camera4D = flight.get("camera")
		var flock: Node4D = flight.get("flock")
		if cam == null or flock == null:
			return
		var middle: Vector4 = flock.global_position + flock.global_basis * (flock.get("_middle") as Vector4)
		var rel: Vector4 = cam.global_basis.inverse() * (middle - cam.global_position)
		if rel.z < -1.0:
			var p: Vector2 = Vector2(rel.x, -rel.y) / -rel.z
			var on_screen: bool = absf(p.x) < 0.9 and absf(p.y) < 0.5
			if on_screen:
				return
		var dir := Vector2(rel.x, -rel.y).normalized()
		if dir.length() < 0.5:
			dir = Vector2(0, 1)
		var c := s * 0.5
		var edge: Vector2 = c + dir * minf(s.x, s.y) * 0.42
		var col: Color = STYLE.accent.lightened(0.35)
		draw_colored_polygon(PackedVector2Array([edge + dir * 14.0, edge + dir.orthogonal() * 8.0, edge - dir.orthogonal() * 8.0]), col)
		draw_string(_font, edge - dir * 26.0 - Vector2(24.0, -4.0), "flock", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col)
