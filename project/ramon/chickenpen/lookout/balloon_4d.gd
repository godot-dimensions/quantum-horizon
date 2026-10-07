@tool
extends Node4D

## Wren's balloon: the Lookout's set piece. Moored beside the tower once you have earned it,
## it takes you up on a ride Wren and the wind choose - over the farm, through the
## murmuration, and then slowly ANA, out of the farm's slice altogether, to a marsh that is
## only there along W, and back.
##
## A RAIL, AS POKEMON SNAP'S IS, because a rail solves the hardest problem a 4D game has:
## steering through W. The ride's path is (x, y, z AND w), planned (RIDE below), and the
## camera's slice rides with the basket - so as the balloon drifts ana the farm thins and
## goes, not because anything moved but because you did. You look, zoom, focus and shoot:
## 36 shots, no reloads up there. X whistles, and what can hear it looks up.
##
## TWO SAYS IN IT (Ramon, 2 Oct: "more say in the balloon"), both inside the rail's safety:
##   height  SPACE works the burner: held, you rise, up to [member lift_max] over the rail;
##           let go and the air cools and you sink back, down to [member lift_min] under it,
##           never lower than [member ground_clearance] over the ground. The offset fades out
##           near the take-off and the landing, so those stay as planned.
##   the fork  as you leave the farm, Wren asks which way: ANA to the marsh (the heron), or
##           KATA to a wood that is only there on the other side (the chipmunks). The focus
##           ring decides - wherever it is pointing when the moment comes - so the choice is
##           made with the same control that has been finding things in W all along. The
##           kata leg is the ana leg mirrored in W, so it is as safe as the planned one.
##
## BUILT FROM THE SAME PARTS AS EVERYTHING ELSE:
##   the envelope  a loft of balls stacked up a teardrop (loft_rig_4d.gd), coloured per ball
##                 (use_ball_colors) - two balls a centimetre apart at every band's edge, so
##                 the bands are crisp rather than a fade. It is a 4D solid of revolution:
##                 off its W-middle it shows a smaller balloon, like everything round here
##   the basket    a closed 4D room, eight walls (follow_up/4d_enclosure_rule.md): floor,
##                 four sides and two W walls, open on top. Wicker, with a leather rim
##   the burner    on four rods over the basket; its flame is two boxes that flicker
##   the ropes     thin bars from the mouth ring to the basket's corners
##   moored        a tether to a stake, and sandbags
##
## INFLATES when the story makes it ready (set_ready): the envelope swells from the mouth
## over a few seconds, which you can watch from the cab.

signal ride_finished

const RIG := preload("res://ramon/chickenpen/scripts/loft_rig_4d.gd")
const BALL := preload("res://ramon/chickenpen/scripts/loft_ball_4d.gd")
const Look := preload("res://ramon/chickenpen/look/pen_look_4d.gd")

## The ride: [seconds, position of the basket floor (x, y, z, w)]. Wren's line for the
## moment, if any, is in RADIO. The marsh is at w +8, west of the tower (ana_marsh_4d.gd).
const RIDE := [
	[0.0, Vector4(0.0, 0.0, 0.0, 0.0)],
	[10.0, Vector4(1.5, 9.0, 1.5, 0.0)],
	[24.0, Vector4(9.0, 18.0, 9.0, 0.0)],
	[38.0, Vector4(20.0, 21.0, 17.0, 0.0)],
	[54.0, Vector4(27.0, 20.0, -6.0, 0.0)],
	[70.0, Vector4(24.0, 19.0, -34.0, 0.0)],
	[86.0, Vector4(8.0, 17.0, -26.0, 1.5)],
	[102.0, Vector4(-4.0, 13.0, -12.0, 5.5)],
	[116.0, Vector4(-5.0, 7.5, 1.0, 8.0)],
	[130.0, Vector4(-3.0, 5.5, 7.0, 8.0)],
	[144.0, Vector4(-1.0, 6.0, 4.0, 4.0)],
	[156.0, Vector4(-0.3, 2.0, 1.0, 0.8)],
	[164.0, Vector4(0.0, 0.0, 0.0, 0.0)],
]
## [seconds, Wren's lines, and her lines instead if the fork went kata].
const RADIO := [
	[1.0, ["Off we go. Mind your head on the burner. Space if you want more of it."]],
	[30.0, ["There's the pen. Everything's in it, for once."]],
	[50.0, ["Starlings, dead ahead. Into them. Thirty six shots, don't spend them all."]],
	[62.0, ["Next we leave the farm. Which way, ana or kata?", "Turn the ring the way you want to go. E for ana, Q for kata. I'll take us there."]],
	[84.0, ["Now we go ana. Don't worry, the farm's still there.", "We just aren't."],
		["Now we go kata. Don't worry, the farm's still there.", "We just aren't."]],
	[108.0, ["There. Water. I told you.", "Something's standing in it. Quiet, now. X if you want it to look up."],
		["There. Trees. Nobody planted them, nobody's ever cut them.", "Chipmunks, if you're lucky. Quiet, now. X if you want them to look up."]],
	[142.0, ["Back we come. Kata, and down."], ["Back we come. Ana, and down."]],
	[158.0, ["And down. Gently."]],
]
## When the fork is taken: the rail's w is 0 there, so either way is smooth.
const FORK_AT := 70.0
## WHERE THE PEN WAS WHEN THE RIDE WAS DRAWN, from the mooring, in the ride's own frame: the pen at
## (0, -11), the mooring at (-23.5, -30). Since 6 Oct the Lookout is a unit that can be put anywhere,
## so the stretch over the farm bends toward wherever the pen really is from the mooring (see
## _pen_shift): "There's the pen" still has the pen below. Take-off, landing and the W legs over
## the marsh and the wood stay as drawn; with the Lookout where it was drawn the bend is nothing.
const DRAWN_PEN := Vector4(23.5, 0.0, 19.0, 0.0)
## How much of that bend each moment of the ride takes: none until take-off is done, all of it over
## the farm (the pen at 30 s, the starlings at 50 s), none again by the fork.
const PEN_BEND_IN := Vector2(10.0, 26.0)
const PEN_BEND_OUT := Vector2(44.0, 64.0)
## WHERE THE MARSH WAS WHEN THE RIDE WAS DRAWN, from the mooring (the site's MarshSpot at (-14, 12) and
## MooringSpot at (-14, 4)). Layout B moved the marsh 36 m east within the site (6 Oct), and the ride went
## on flying to the old spot, 41 m off it (7 Oct, lookout/_verify_site_runner.gd). So the ana leg bends
## toward wherever the marsh is, as the farm's stretch bends toward the pen: none until the fork is
## behind, all of it over the marsh, none again by the way home. Kata's wood has not moved.
const DRAWN_MARSH := Vector4(0.0, 0.0, 8.0, 0.0)
const MARSH_BEND_IN := Vector2(76.0, 100.0)
const MARSH_BEND_OUT := Vector2(134.0, 154.0)

## Desaturated light browns, close enough to read as one balloon (Ramon, 6 Oct, layout B: "make the
## balloon desaturated light brown, so it doesnt standout too much"; before it, "a range of red").
@export var envelope_colours: Array[Color] = [Color(0.66, 0.58, 0.47), Color(0.73, 0.65, 0.53), Color(0.60, 0.53, 0.43),
	Color(0.69, 0.61, 0.50), Color(0.64, 0.56, 0.46), Color(0.57, 0.50, 0.41)]
@export var wicker: Color = Color(0.62, 0.47, 0.28)
## Whether it is up and ready by the tower, or not here at all yet.
@export var ready_now: bool = false
@export_range(1.0, 20.0, 0.5, "suffix:s") var inflate_seconds: float = 6.0
## Faster than real, for tests: 1 is the ride as planned.
@export_range(0.1, 10.0, 0.1) var ride_speed: float = 1.0
@export var burner_key: Key = KEY_SPACE
## How far over and under the rail the burner can take you, and how fast.
@export_range(0.0, 30.0, 0.5, "suffix:m") var lift_max: float = 10.0
@export_range(-15.0, 0.0, 0.5, "suffix:m") var lift_min: float = -5.0
@export_range(0.1, 5.0, 0.05, "suffix:m/s") var rise_rate: float = 1.4
@export_range(0.05, 3.0, 0.05, "suffix:m/s") var sink_rate: float = 0.45
@export_range(1.0, 10.0, 0.5, "suffix:m") var ground_clearance: float = 3.0

var lookout: Node
## The Lookout site's turn: the ride's planned path is turned with it, so it still reaches the
## marsh and the wood wherever the site is put.
var ride_basis: Projection = Projection.IDENTITY
var riding: bool = false
var ride_time: float = 0.0
## The burner's offset over the rail, now.
var lift: float = 0.0
## The fork: +1 ana (the marsh), -1 kata (the wood), and whether it has been taken yet.
var branch: float = 1.0
var forked: bool = false

var _envelope: Node4D
var _flame: Array[Node4D] = []
var _basket_body: StaticBody4D
var _tether: Array[Node4D] = []
## The burner's four rods: hidden while you ride, because from the middle of the basket
## they pass right by your eye and cut across every picture; nobody sees them from outside
## then.
var _rods: Array[Node4D] = []
var _moor: Vector4
var _inflate: float = 1.0
var _burn: float = 0.0
var _burner_sound: AudioStreamPlayer
var _said: int = 0
var _hurry: float = 0.0
var _t: float = 0.0
var _dev_look: bool = false


func _ready() -> void:
	rebuild()
	_moor = position
	if Engine.is_editor_hint():
		return
	_inflate = 1.0 if ready_now else 0.0
	visible = ready_now
	_apply_inflation()
	_follow_look.call_deferred()


## BLUE IN THE DEV LOOK (Ramon, 7 Oct: "wrens baloon should be blue in dev mode"). The Look leaves the
## balloon alone, as it leaves every character and vehicle (look/pen_blockouts_4d.gd CHARACTER): the
## envelope is a lofted skin coloured by its rings, and the Look's one shared material would not
## survive it. So the balloon follows the switch itself: every part in the Look's landmark blue, lighter
## or darker as the part was in the art, the envelope's bands rebuilt in blues; and back. Repainted in
## place, never rebuilt, so it can switch mid-ride. The flame keeps its fire.
func _follow_look() -> void:
	var look: Node = Look.current
	if look == null or not is_instance_valid(look):
		return
	# Laid or lifted, not chosen: the art is held in the cinema, the cave and before a save (7 Oct, the
	# look test's check 8 found the balloon still blue there).
	if not look.is_connected("applied_changed", _on_look):
		look.connect("applied_changed", _on_look)
	_on_look(bool(look.get("_applied")))


func _on_look(dev: bool) -> void:
	if dev == _dev_look:
		return
	_dev_look = dev
	var look: Node = Look.current
	var blue: Color = look.get("landmark_colour") if look != null and is_instance_valid(look) else Color(0.13, 0.40, 0.86)
	var skin: Node = _envelope.get_node_or_null("Skin") if _envelope != null else null
	for node in find_children("*", "MeshInstance4D", true, false):
		var mi := node as MeshInstance4D
		if mi == skin or mi.get_parent() == skin or String(mi.name).begins_with("Flame"):
			continue
		var m := mi.material_override as TetraMaterial4D
		if m == null:
			continue
		if not mi.has_meta(&"art_colour"):
			mi.set_meta(&"art_colour", m.albedo_color)
		var art: Color = mi.get_meta(&"art_colour")
		m.albedo_color = _in_blue(blue, art) if dev else art
	if skin != null and skin.has_method("build"):
		# The envelope's art mesh is kept and put back as it was, the same object: the dev look's own test
		# checks that switching back leaves every mesh exactly as it was (look/_verify_look_runner.gd). The
		# blue one is built once and kept too.
		# (Its colours are a ramp texture on its material, loft_rig_4d.gd: kept and put back with the mesh.)
		var mi := skin as MeshInstance4D
		var mat: Material4D = mi.material_override
		if not skin.has_meta(&"art_mesh"):
			skin.set_meta(&"art_mesh", mi.mesh)
			skin.set_meta(&"art_ramp", mat.get("albedo_texture_3d") if mat != null else null)
		if not dev:
			mi.mesh = skin.get_meta(&"art_mesh")
			if mat != null:
				mat.set("albedo_texture_3d", skin.get_meta(&"art_ramp"))
		elif skin.has_meta(&"dev_mesh"):
			mi.mesh = skin.get_meta(&"dev_mesh")
			if mat != null:
				mat.set("albedo_texture_3d", skin.get_meta(&"dev_ramp"))
		else:
			for ball in skin.get_children():
				if not ("color" in ball):
					continue
				if not ball.has_meta(&"art_colour"):
					ball.set_meta(&"art_colour", ball.get("color"))
				ball.set("color", _in_blue(blue, ball.get_meta(&"art_colour")))
			skin.call("build", false)
			skin.set_meta(&"dev_mesh", mi.mesh)
			skin.set_meta(&"dev_ramp", mat.get("albedo_texture_3d") if mat != null else null)
			for ball in skin.get_children():
				if ball.has_meta(&"art_colour"):
					ball.set("color", ball.get_meta(&"art_colour"))


## [param blue], as light or dark as [param art] is: a pale part a pale blue, a dark one deep.
static func _in_blue(blue: Color, art: Color) -> Color:
	var l: float = art.get_luminance()
	return blue.darkened(clampf(0.42 - l, 0.0, 0.45)).lightened(clampf(l - 0.5, 0.0, 0.35))


## Up by the tower or gone. [param instant] skips the inflating, for a journal that was
## already this far when the scene loaded.
func set_ready(on: bool, instant: bool = false) -> void:
	if on == ready_now and not instant:
		return
	ready_now = on
	visible = on
	_inflate = (1.0 if instant else 0.02) if on else 0.0
	_apply_inflation()


func rebuild() -> void:
	for child in get_children():
		child.free()
	_flame.clear()
	_tether.clear()
	_rods.clear()
	_build_envelope()
	_build_basket()
	_build_burner_and_ropes()
	_build_mooring()


func _build_envelope() -> void:
	_envelope = Node4D.new()
	_envelope.name = "Envelope"
	add_child(_envelope)
	_own(_envelope)
	_envelope.position = Vector4(0.0, 3.0, 0.0, 0.0)
	var hide := MeshInstance4D.new()
	hide.name = "Skin"
	hide.set_script(RIG)
	var m := TetraMaterial4D.new()
	m.albedo_color = Color.WHITE
	hide.material_override = m
	_envelope.add_child(hide)
	hide.set("profile_sides", 16)
	hide.set("profile_rings", 4)
	hide.set("smoothing", 2)
	hide.set("verbose", false)
	hide.set("live_rebuild", false)
	hide.set("use_ball_colors", true)
	_own(hide)
	# The teardrop, as radius by height above the mouth.
	var profile: Array = [[0.0, 0.55], [0.8, 1.5], [1.8, 2.5], [3.0, 3.2], [4.4, 3.55], [5.8, 3.5], [7.0, 3.0], [7.9, 2.1], [8.4, 1.0], [8.56, 0.3]]
	var bands: Array = [0.0, 1.8, 3.4, 5.0, 6.4, 7.6, 9.0]
	var heights: Array = []
	for p in profile:
		heights.append(float(p[0]))
	for k in range(1, bands.size() - 1):
		heights.append(float(bands[k]) - 0.006)
		heights.append(float(bands[k]) + 0.006)
	heights.sort()
	var i: int = 0
	for y in heights:
		var band: int = 0
		while band < bands.size() - 2 and float(y) >= float(bands[band + 1]):
			band += 1
		var ball := MeshInstance4D.new()
		ball.name = "Ring%02d" % i
		ball.set_script(BALL)
		hide.add_child(ball)
		ball.position = Vector4(0.0, float(y), 0.0, 0.0)
		ball.set("radius", _radius_at(profile, float(y)))
		ball.set("color", envelope_colours[band % envelope_colours.size()])
		_own(ball)
		i += 1
	hide.call("build", false)
	# The mouth's ring, dark, and the scoop of fabric below it.
	for k in 4:
		var a: float = float(k) * PI * 0.5
		_box(_envelope, "Mouth%d" % k, Vector4(cos(a) * 0.55, -0.02, sin(a) * 0.55, 0.0), Vector4(0.12 if k % 2 == 0 else 1.1, 0.08, 1.1 if k % 2 == 0 else 0.12, 1.1), Color(0.15, 0.12, 0.1))


func _radius_at(profile: Array, y: float) -> float:
	for k in range(profile.size() - 1):
		var a: Array = profile[k]
		var b: Array = profile[k + 1]
		if y <= float(b[0]):
			var u: float = (y - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.0001)
			return lerpf(float(a[1]), float(b[1]), smoothstep(0.0, 1.0, u))
	return float(profile[-1][1])


## The basket: a room in four dimensions, open on top.
func _build_basket() -> void:
	var s: float = 1.3
	var wd: float = 1.3
	var h: float = 1.05
	var t: float = 0.06
	_box(self, "Floor", Vector4(0.0, 0.04, 0.0, 0.0), Vector4(s, 0.08, s, wd), wicker.darkened(0.25))
	for side in [-1.0, 1.0]:
		_box(self, "WallX%d" % int(side), Vector4(side * (s - t) * 0.5, h * 0.5, 0.0, 0.0), Vector4(t, h, s, wd), wicker)
		_box(self, "WallZ%d" % int(side), Vector4(0.0, h * 0.5, side * (s - t) * 0.5, 0.0), Vector4(s, h, t, wd), wicker)
		_box(self, "WallW%d" % int(side), Vector4(0.0, h * 0.5, 0.0, side * (wd - t) * 0.5), Vector4(s, h, s, t), wicker)
		# The leather rim round the top, and the weave as darker bands.
		_box(self, "RimX%d" % int(side), Vector4(side * (s - t) * 0.5, h, 0.0, 0.0), Vector4(t * 1.8, 0.07, s + 0.04, wd), Color(0.28, 0.17, 0.10))
		_box(self, "RimZ%d" % int(side), Vector4(0.0, h, side * (s - t) * 0.5, 0.0), Vector4(s + 0.04, 0.07, t * 1.8, wd), Color(0.28, 0.17, 0.10))
		for b in 3:
			var y: float = 0.22 + 0.27 * float(b)
			_box(self, "WeaveX%d_%d" % [int(side), b], Vector4(side * (s * 0.5 + 0.004), y, 0.0, 0.0), Vector4(0.01, 0.05, s, wd), wicker.darkened(0.2))
			_box(self, "WeaveZ%d_%d" % [int(side), b], Vector4(0.0, y, side * (s * 0.5 + 0.004), 0.0), Vector4(s, 0.05, 0.01, wd), wicker.darkened(0.2))
	_basket_body = StaticBody4D.new()
	_basket_body.name = "BasketBody"
	add_child(_basket_body)
	var shape := CollisionShape4D.new()
	var box := BoxShape4D.new()
	box.size = Vector4(s, h, s, wd)
	shape.shape = box
	shape.position = Vector4(0.0, h * 0.5, 0.0, 0.0)
	_basket_body.add_child(shape)


func _build_burner_and_ropes() -> void:
	var steel := Color(0.35, 0.36, 0.36)
	var top := Vector4(0.0, 2.3, 0.0, 0.0)
	for cx in [-1.0, 1.0]:
		for cz in [-1.0, 1.0]:
			var corner := Vector4(cx * 0.6, 1.05, cz * 0.6, 0.0)
			_rods.append(_strut(self, "Rod", corner, top + Vector4(cx * 0.25, 0.0, cz * 0.25, 0.0), 0.022, 0.3, steel))
			# The ropes, from the basket corners up to the mouth ring.
			_strut(self, "Rope", corner, Vector4(cx * 0.42, 3.0, cz * 0.42, 0.0), 0.025, 0.25, Color(0.55, 0.48, 0.36))
	_box(self, "BurnerFrame", top, Vector4(0.56, 0.05, 0.56, 0.5), steel)
	_box(self, "Burner", top + Vector4(0, 0.14, 0, 0), Vector4(0.24, 0.24, 0.24, 0.24), Color(0.55, 0.56, 0.55))
	_box(self, "Coil", top + Vector4(0, 0.29, 0, 0), Vector4(0.3, 0.06, 0.3, 0.3), Color(0.2, 0.2, 0.2))
	var outer := _box(self, "Flame", top + Vector4(0, 0.62, 0, 0), Vector4(0.24, 0.6, 0.24, 0.24), Color(1.0, 0.55, 0.12))
	var inner := _box(self, "FlameCore", top + Vector4(0, 0.5, 0, 0), Vector4(0.12, 0.4, 0.12, 0.12), Color(1.0, 0.92, 0.55))
	_flame = [outer, inner]
	for f in _flame:
		f.visible = false
	# A gas bottle in the corner.
	_box(self, "Tank", Vector4(0.42, 0.3, -0.42, 0.0), Vector4(0.2, 0.5, 0.2, 0.2), Color(0.72, 0.72, 0.68))


func _build_mooring() -> void:
	# A stake, a tether to it, and sandbags on the rim.
	var stake := Vector4(2.6, 0.0, 1.4, 0.0)
	_tether.append(_box(self, "Stake", stake + Vector4(0, 0.25, 0, 0), Vector4(0.08, 0.5, 0.08, 0.3), Color(0.3, 0.22, 0.14)))
	_tether.append(_strut(self, "Tether", Vector4(0.65, 0.9, 0.3, 0.0), stake + Vector4(0, 0.4, 0, 0), 0.03, 0.25, Color(0.55, 0.48, 0.36)))
	for k in 3:
		_tether.append(_box(self, "Sandbag%d" % k, Vector4(-0.72, 0.55 + 0.0 * float(k), -0.4 + 0.4 * float(k), 0.0), Vector4(0.12, 0.22, 0.16, 0.2), Color(0.66, 0.58, 0.42)))


func _box(parent: Node, part: String, at: Vector4, size: Vector4, colour: Color, basis: Projection = Projection.IDENTITY) -> MeshInstance4D:
	var node := MeshInstance4D.new()
	node.name = part
	var mesh := BoxTetraMesh4D.new()
	mesh.size = size
	node.mesh = mesh
	var material := TetraMaterial4D.new()
	material.albedo_color = colour
	node.material_override = material
	parent.add_child(node, true)
	node.position = at
	if basis != Projection.IDENTITY:
		node.basis = basis
	_own(node)
	return node


func _strut(parent: Node, part: String, a: Vector4, b: Vector4, thick: float, wd: float, colour: Color) -> MeshInstance4D:
	var d: Vector4 = b - a
	var length: float = d.length()
	var y: Vector4 = d / maxf(length, 0.0001)
	return _box(parent, part, (a + b) * 0.5, Vector4(thick, length, thick, wd), colour, _frame_along(y))


func _own(node: Node) -> void:
	if Engine.is_editor_hint() and get_tree() != null and get_tree().edited_scene_root != null:
		node.owner = get_tree().edited_scene_root


# --- For the camera --------------------------------------------------------------------------

## Where the eye is, standing in the basket.
func eye() -> Vector4:
	return global_position + Vector4(0.0, 1.55, 0.0, 0.0)


## Makes it do [param what] now - for the portrait runner: "burn".
func perform(what: String) -> void:
	if what == "burn":
		_burn = 2.5


func _apply_inflation() -> void:
	if _envelope == null:
		return
	var k: float = smoothstep(0.0, 1.0, clampf(_inflate, 0.0, 1.0))
	# Swelling from the mouth: wide first, then tall, as hot air fills it.
	var wide: float = lerpf(0.25, 1.0, smoothstep(0.0, 0.6, k))
	var tall: float = lerpf(0.08, 1.0, k)
	_envelope.basis = Basis4D.from_scale(Vector4(wide, tall, wide, wide))


# --- The ride ---------------------------------------------------------------------------------

## Climb in: the camera to the basket, the burner lit, the tether off.
func board() -> void:
	if riding or not ready_now or lookout == null:
		return
	riding = true
	ride_time = 0.0
	lift = 0.0
	branch = 1.0
	forked = false
	_said = 0
	_hurry = 0.0
	position = _moor
	for t in _tether:
		t.visible = false
	for r in _rods:
		r.visible = false
	_basket_body.process_mode = Node.PROCESS_MODE_DISABLED
	var station: Node = lookout.get("station")
	station.call("ride", Callable(self, "eye"), 36, 0.0, PI)
	station.call("look_along", Vector4(0.6, 0.35, 1.0, 0.0))
	lookout.call("on_ride_started")
	_burn = 3.0


## Escape in the basket: the first press is Wren telling you how to get down, the second
## brings her straight down.
func hurry() -> void:
	if not riding:
		return
	if _hurry > 0.0:
		ride_time = maxf(ride_time, float(RIDE[-3][0]))
		_said = maxi(_said, RADIO.size() - 2)
		_hurry = 0.0
		lookout.get("radio").call("say", ["Right you are. Taking her down."])
		return
	_hurry = 4.0
	lookout.get("radio").call("say", ["We'll be down in a couple of minutes. Escape again and I'll bring her straight down."])


func burning() -> bool:
	return _burn > 0.0


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_t += delta
	if ready_now and _inflate < 1.0:
		_inflate = minf(_inflate + delta / inflate_seconds, 1.0)
		_apply_inflation()
		if _inflate < 0.95:
			_burn = maxf(_burn, 0.3)
	if _hurry > 0.0:
		_hurry -= delta
	if riding:
		_ride(delta)
	_burn = maxf(_burn - delta, 0.0)
	var lit: bool = _burn > 0.0
	for f in _flame:
		f.visible = lit
		if lit:
			var flick: float = 0.8 + 0.25 * sin(_t * 31.0) + 0.15 * sin(_t * 17.0)
			f.basis = Basis4D.from_scale(Vector4(1.0, flick, 1.0, 1.0))
	_sound_burner(lit, delta)


func _ride(delta: float) -> void:
	ride_time += delta * ride_speed
	var end: float = float(RIDE[-1][0])
	# The fork, decided by the focus ring when the moment comes.
	if not forked and ride_time >= FORK_AT:
		forked = true
		var focus: float = float(lookout.get("station").get("focus"))
		branch = -1.0 if focus < -0.3 else 1.0
		var view: Node = lookout.get("station").get("view")
		if view != null:
			view.call("flash_note", "Kata it is." if branch < 0.0 else "Ana it is.")
	# The burner: up while held, sinking back while cooling; none of it near the ends.
	var allowed: float = smoothstep(8.0, 16.0, ride_time) * (1.0 - smoothstep(end - 26.0, end - 12.0, ride_time))
	if Input.is_physical_key_pressed(burner_key) and allowed > 0.0:
		lift = minf(lift + rise_rate * delta * ride_speed, lift_max)
		_burn = maxf(_burn, 0.25)
	else:
		lift = move_toward(lift, lift_min if allowed > 0.0 else 0.0, sink_rate * delta * ride_speed * (1.0 if allowed > 0.0 else 3.0))
	var t_now: float = minf(ride_time, end)
	var bend: float = smoothstep(PEN_BEND_IN.x, PEN_BEND_IN.y, t_now) * (1.0 - smoothstep(PEN_BEND_OUT.x, PEN_BEND_OUT.y, t_now))
	var marsh_bend: float = smoothstep(MARSH_BEND_IN.x, MARSH_BEND_IN.y, t_now) * (1.0 - smoothstep(MARSH_BEND_OUT.x, MARSH_BEND_OUT.y, t_now))
	if not forked or branch < 0.0:
		marsh_bend = 0.0
	var on_rail: Vector4 = _moor + ride_basis * (_path(t_now) + _pen_shift() * bend + _marsh_shift() * marsh_bend)
	var floor_y: float = on_rail.y
	var ground: RefCounted = lookout.get("ground")
	if ground != null:
		floor_y = minf(on_rail.y, float(ground.call("height", on_rail.x, on_rail.z)) + ground_clearance)
	position = on_rail + Vector4(0.0, maxf(lift * allowed, floor_y - on_rail.y), 0.0, 0.0)
	# A slow turn, as a basket under a balloon always has.
	basis = Basis4D.from_zx(sin(ride_time * 0.05) * 0.8)
	# Burner bursts while climbing.
	var ahead: Vector4 = _path(minf(ride_time + 1.0, end)) - _path(minf(ride_time, end))
	if ahead.y > 0.25 * ride_speed and _burn <= 0.0:
		_burn = 1.6
	while _said < RADIO.size() and ride_time >= float(RADIO[_said][0]):
		var entry: Array = RADIO[_said]
		lookout.get("radio").call("say", entry[2] if branch < 0.0 and entry.size() > 2 else entry[1])
		_said += 1
	if ride_time >= end:
		_land()


## How far the pen is from where the ride was drawn to find it, in the ride's frame, on the ground
## (x and z only): zero while the Lookout stands where it was drawn.
func _pen_shift() -> Vector4:
	var room: Node = lookout.get("room") if lookout != null else null
	var pen: Node4D = room.get_node_or_null("Pen") as Node4D if room != null else null
	var host: Node4D = get_parent() as Node4D
	if pen == null or host == null:
		return Vector4.ZERO
	var moor: Vector4 = host.global_position + host.global_basis * _moor
	var rel: Vector4 = (host.global_basis * ride_basis).inverse() * (pen.global_position - moor)
	return Vector4(rel.x - DRAWN_PEN.x, 0.0, rel.z - DRAWN_PEN.z, 0.0)


## How far the marsh is from where the ride was drawn to find it, in the ride's frame, on the ground.
func _marsh_shift() -> Vector4:
	var marsh: Node4D = lookout.get("marsh") as Node4D if lookout != null else null
	var host: Node4D = get_parent() as Node4D
	if marsh == null or host == null:
		return Vector4.ZERO
	var moor: Vector4 = host.global_position + host.global_basis * _moor
	var rel: Vector4 = (host.global_basis * ride_basis).inverse() * (marsh.global_position - moor)
	return Vector4(rel.x - DRAWN_MARSH.x, 0.0, rel.z - DRAWN_MARSH.z, 0.0)


## Catmull-Rom through the ride's points, so it drifts rather than turning corners.
func _path(t: float) -> Vector4:
	var i: int = 0
	while i < RIDE.size() - 2 and t > float(RIDE[i + 1][0]):
		i += 1
	var p1: Vector4 = RIDE[i][1]
	var p2: Vector4 = RIDE[i + 1][1]
	var p0: Vector4 = RIDE[maxi(i - 1, 0)][1]
	var p3: Vector4 = RIDE[mini(i + 2, RIDE.size() - 1)][1]
	var u: float = clampf((t - float(RIDE[i][0])) / maxf(float(RIDE[i + 1][0]) - float(RIDE[i][0]), 0.0001), 0.0, 1.0)
	var u2: float = u * u
	var u3: float = u2 * u
	var p: Vector4 = 0.5 * ((2.0 * p1) + (-p0 + p2) * u + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * u2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * u3)
	# Past the fork, kata is the same leg mirrored in W.
	if t >= FORK_AT:
		p.w *= branch
	return p


func _land() -> void:
	riding = false
	position = _moor
	basis = Projection.IDENTITY
	for t in _tether:
		t.visible = true
	for r in _rods:
		r.visible = true
	_basket_body.process_mode = Node.PROCESS_MODE_INHERIT
	var station: Node = lookout.get("station")
	var step_out: Vector4 = _moor + Vector4(1.6, 0.05, 1.2, 0.0)
	var tower: Node4D = lookout.get("tower")
	var facing: Vector4 = Vector4(0.0, 0.0, -1.0, 0.0)
	if tower != null:
		facing = tower.global_position - step_out
	station.call("end_ride", step_out, facing)
	lookout.call("on_ride_ended")
	ride_finished.emit()


func _sound_burner(lit: bool, delta: float) -> void:
	if lookout == null:
		return
	if _burner_sound == null:
		var sounds: Node = lookout.get("sounds")
		if sounds == null or not bool(sounds.call("has", &"burner")):
			return
		_burner_sound = sounds.call("held", &"burner")
		var stream := _burner_sound.stream as AudioStreamWAV
		if stream != null:
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			stream.loop_end = int(stream.get_length() * float(stream.mix_rate))
		_burner_sound.volume_db = -60.0
		_burner_sound.play()
	if not lit and _burner_sound.volume_db <= -59.0:
		return
	# Loud in the basket, distant from the ground.
	var want: float = -60.0
	if lit:
		var cam: Camera4D = lookout.call("current_camera")
		var near: float = 1.0
		if cam != null:
			var d: Vector4 = cam.global_position - global_position
			near = clampf(6.0 / maxf(Vector3(d.x, d.y, d.z).length(), 6.0), 0.05, 1.0)
		want = -4.0 + linear_to_db(near)
	_burner_sound.volume_db = move_toward(_burner_sound.volume_db, want, delta * (160.0 if lit else 60.0))

## An orthonormal frame whose y is [param y]: the other three columns by Gram-Schmidt from
## whichever of x, z, y and w are not along it, in that order, kept right-handed.
##
## THE FIRST VERSION DEGENERATED for a bar lying exactly along x or z: its fallback axis
## Gram-Schmidted to nothing, the basis had a zero column, and every catwalk rail and girt was
## built flat (22 "Basis4D.inverse: zero determinant" errors a load).
static func _frame_along(y: Vector4) -> Projection:
	var picks: Array[Vector4] = []
	for axis in [Vector4(1, 0, 0, 0), Vector4(0, 0, 1, 0), Vector4(0, 1, 0, 0), Vector4(0, 0, 0, 1)]:
		var v: Vector4 = axis - y * y.dot(axis)
		for p in picks:
			v -= p * p.dot(v)
		if v.length() > 0.2:
			picks.append(v.normalized())
		if picks.size() == 3:
			break
	var frame := Projection(picks[0], y, picks[1], picks[2])
	if frame.determinant() < 0.0:
		frame.w = -frame.w
	return frame
