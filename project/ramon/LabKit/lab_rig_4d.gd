@tool
extends Node4D

## The lab's test rig: a treadmill drum under a boom, the way robotics labs test legged machines
## (on treadmills, under an overhead harness). The animal walks on the spot, tethered, and the
## drum's belt runs under its feet at the speed its planted feet slide back, so walking in place
## reads as walking. Flyers rise and fall in a column marked by two halo rings; perchers sit on a
## stand.
##
## WHAT IT IS MADE OF, all generated (nothing is saved into the scene file):
##   drum      a cubinder (a disc in XZ swept through height and W), Ramon's dev texture, stepped:
##             a body, and a slightly smaller deck on top
##   rim       a thin glowing ring at the deck's edge, in the part's colour (build, motion, ...)
##   contact   a dark disc under the animal, since the engine casts no shadows
##   belt      bars across the deck that scroll along the animal's walking direction
##   boom      one chamfered post behind the animal and an arm over its back, so the side, front
##             and three-quarter views stay clear; the tether drops from the arm's tip
##   column    two halo rings for flyers; a stand for perchers
##   pool      a light from the boom tip, on in the dark mood
##
## The animal is a lab creature (CreationLab/scripts/lab_creature_4d.gd or anything with the same
## duck-typed surface: footprint_radius, height, tether, column_height, front_axis, belt_speed(),
## set_paused(), walker()). Give the rig its scene in `animal_scene` and it stands the animal on
## its deck, or leave that empty and add the animal as a child called "Animal" yourself.
##
## W SPIN: `set_w_spin(degrees)` turns the animal through the fourth axis (an XW rotation of the
## animal's root), eased, so the slice cuts it differently. The rig itself does not turn.
##
## SLEEP: a rig further than `sleep_distance` from the current camera, or behind it, pauses its
## animal (it holds its pose); bending joints run only within `joint_distance`.
##
## NO class_name (engine_gotchas.md): preload this file.

const Style := preload("res://ramon/LabKit/lab_style.gd")
const Mats := preload("res://ramon/LabKit/lab_materials.gd")
const LabMath := preload("res://ramon/LabKit/lab_math.gd")
const Views := preload("res://ramon/LabKit/lab_views_4d.gd")
const GENERATED := "lab_generated"
const GROUP := "lab_rig"

## The animal to stand on the deck (a lab creature scene).
@export var animal_scene: PackedScene:
	set(v):
		animal_scene = v
		_later()
## The drum's radius in metres; 0 sizes it from the animal's footprint.
@export_range(0.0, 20.0, 0.05) var radius: float = 0.0:
	set(v):
		radius = v
		_later()
## The part of the lab this rig belongs to, for the rim's colour: "build", "motion", "w" or
## "neutral".
@export_enum("neutral", "build", "motion", "w") var part: String = "neutral":
	set(v):
		part = v
		_later()
@export var show_boom: bool = true:
	set(v):
		show_boom = v
		_later()
@export var show_belt: bool = true:
	set(v):
		show_belt = v
		_later()
## Metres between belt bars.
@export_range(0.05, 2.0, 0.01) var belt_spacing: float = 0.24
## Beyond this distance from the camera the animal holds its pose.
@export_range(5.0, 200.0, 1.0) var sleep_distance: float = 40.0
## Within this distance the animal's bending joints are posed.
@export_range(1.0, 100.0, 0.5) var joint_distance: float = 14.0
## The light pool's strength in the dark mood.
@export_range(0.0, 10.0, 0.1) var pool_energy: float = 2.6

var animal: Node4D
var deck_height: float = 0.3
var _r: float = 1.0
var _mood: String = "bright"
var _parts: Dictionary = {}       # name -> [MeshInstance4D, size, surface role]
var _glows: Array = []            # MeshInstance4D with a glow, recoloured per mood
var _bars: Array = []             # [MeshInstance4D, offset along the belt]
var _belt_offset: float = 0.0
var _tether: MeshInstance4D
var _arm_tip: Vector4 = Vector4.ZERO
var _pool: OmniLight4D
var _spin_now: float = 0.0
var _spin_goal: float = 0.0
var _asleep: bool = false
var _built: bool = false
var views: Node

static var _mesh_cache: Dictionary = {}


func _enter_tree() -> void:
	add_to_group(GROUP)
	add_to_group("lab_mood_listener")


func _ready() -> void:
	_build()


func _later() -> void:
	if is_node_ready():
		_build()


# -- building ----------------------------------------------------------------------------------

func _build() -> void:
	for c in get_children():
		if c.has_meta(GENERATED):
			remove_child(c)
			c.free()
	_parts.clear()
	_glows.clear()
	_bars.clear()
	_tether = null
	_pool = null
	animal = null
	if animal_scene != null:
		var a: Node = animal_scene.instantiate()
		a.name = "Animal"
		a.set_meta(GENERATED, true)
		animal = a as Node4D
	else:
		animal = get_node_or_null("Animal") as Node4D
	var foot: float = float(animal.get("footprint_radius")) if animal != null else 0.8
	var tall: float = float(animal.get("height")) if animal != null else 1.0
	var tether: String = String(animal.get("tether")) if animal != null else "ground"
	var column: float = float(animal.get("column_height")) if animal != null else 2.0
	_r = radius if radius > 0.0 else maxf(foot * 1.15, 0.5)
	deck_height = clampf(0.16 + _r * 0.06, 0.2, 0.55)
	var thick: float = maxf(_r * 1.6, 1.2)           # through W: enough to stay in a turned slice
	var segs: int = clampi(int(_r * 14.0), 24, 72)

	# The drum: a body and a deck a step smaller on top (the chamfer).
	var body_h: float = deck_height - 0.04
	_cubinder("Drum", _r, body_h, thick, segs, Vector4(0.0, body_h * 0.5, 0.0, 0.0), "rig")
	_cubinder("Deck", _r - 0.06, 0.04, thick * 0.96, segs, Vector4(0.0, deck_height - 0.02, 0.0, 0.0), "rig_top")
	# The rim: a thin glowing band at the top of the drum body, proud of it.
	_glow_cubinder("Rim", _r + 0.012, 0.022, thick * 0.97, segs, Vector4(0.0, body_h - 0.03, 0.0, 0.0))
	# The contact disc, under the animal.
	_cubinder("Contact", maxf(foot * 0.8, 0.2), 0.004, thick * 0.9, segs, Vector4(0.0, deck_height + 0.002, 0.0, 0.0), "contact")

	# Solid, so the player cannot walk through and the animals that find the ground stand on it.
	var body := StaticBody4D.new()
	body.name = "DrumBody"
	body.set_meta(GENERATED, true)
	var shape := CollisionShape4D.new()
	var cyl := CubinderShape4D.new()
	cyl.radius = _r
	cyl.height = deck_height
	cyl.thickness = thick
	shape.shape = cyl
	shape.position = Vector4(0.0, deck_height * 0.5, 0.0, 0.0)
	body.add_child(shape)
	add_child(body)

	var front: Vector4 = _front()
	var side := Vector4(front.z, 0.0, -front.x, 0.0)
	if show_belt and tether == "ground":
		var n: int = int(floor(_r * 2.0 / belt_spacing))
		for i in n:
			var bar := MeshInstance4D.new()
			bar.name = "Belt%d" % i
			bar.mesh = _box_mesh_unit()
			bar.set_meta(GENERATED, true)
			add_child(bar)
			_bars.append([bar, float(i) * belt_spacing])

	# The stand for a percher.
	var stand_top: float = 0.0
	if tether == "perch":
		stand_top = clampf(tall * 1.4, 0.7, 1.6)
		_box("StandPost", Vector4(0.07, stand_top, 0.07, 0.3), Vector4(0.0, deck_height + stand_top * 0.5, 0.0, 0.0), "metal")
		var bar_len: float = maxf(foot, 0.25) * 1.2
		var bar_size: Vector4 = Vector4(bar_len, 0.05, 0.08, 0.3) if absf(front.z) > 0.5 else Vector4(0.08, 0.05, bar_len, 0.3)
		_box("StandBar", bar_size, Vector4(0.0, deck_height + stand_top - 0.025, 0.0, 0.0), "metal")

	# The column for a flyer: two halo rings.
	if tether == "column":
		_ring("HaloLow", maxf(foot * 0.9, 0.35), deck_height + 0.06)
		_ring("HaloHigh", maxf(foot * 0.9, 0.35), deck_height + column + 0.1)

	# The boom: one post behind the animal, an arm forward over its back.
	var top_y: float = deck_height + (column + tall * 0.6 if tether == "column" else stand_top + tall) + 0.55
	if show_boom:
		var post_at: Vector4 = -front * (_r + 0.22)
		_box("BoomPost", Vector4(0.14, top_y, 0.14, 0.4), post_at + Vector4(0.0, top_y * 0.5, 0.0, 0.0), "metal")
		var arm_len: float = _r + 0.22 + 0.07
		var arm_mid: Vector4 = post_at + front * (arm_len * 0.5) + Vector4(0.0, top_y - 0.06, 0.0, 0.0)
		var arm_size: Vector4 = Vector4(0.12, 0.12, arm_len, 0.4) if absf(front.z) > 0.5 else Vector4(arm_len, 0.12, 0.12, 0.4)
		_box("BoomArm", arm_size, arm_mid, "metal")
		# A light strip under the arm.
		var strip_size: Vector4 = Vector4(0.035, 0.012, arm_len * 0.9, 0.3) if absf(front.z) > 0.5 else Vector4(arm_len * 0.9, 0.012, 0.035, 0.3)
		_glow_box("BoomStrip", strip_size, arm_mid - Vector4(0.0, 0.066, 0.0, 0.0))
		_arm_tip = Vector4(0.0, top_y - 0.12, 0.0, 0.0)
		if tether == "ground":
			_tether = MeshInstance4D.new()
			_tether.name = "Tether"
			_tether.mesh = _box_mesh_unit()
			_tether.set_meta(GENERATED, true)
			add_child(_tether)
		_pool = OmniLight4D.new()
		_pool.name = "Pool"
		_pool.set_meta(GENERATED, true)
		_pool.position = Vector4(0.0, top_y - 0.2, 0.0, 0.0)
		_pool.light_color = Color(0.93, 0.96, 1.0)
		_pool.set("omni_range_meters", top_y + _r * 1.2 + 2.0)
		add_child(_pool)

	if animal != null:
		animal.position = Vector4(0.0, deck_height + stand_top, 0.0, 0.0)
		if animal.get_parent() == null:
			add_child(animal)
	views = Node.new()
	views.set_script(Views)
	views.name = "Views"
	views.set_meta(GENERATED, true)
	add_child(views)
	_built = true
	apply_mood(_mood, true)


func _front() -> Vector4:
	var f: Vector4 = animal.get("front_axis") if animal != null else Vector4(0, 0, 1, 0)
	f = Vector4(f.x, 0.0, f.z, 0.0)
	return f.normalized() if f.length() > 0.5 else Vector4(0.0, 0.0, 1.0, 0.0)


static func _cubinder_mesh(r: float, h: float, t: float, segs: int) -> Mesh4D:
	var key: String = "%.3f|%.3f|%.3f|%d" % [r, h, t, segs]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var c := CubinderShape4D.new()
	c.radius = r
	c.height = h
	c.thickness = t
	var m: Mesh4D = c.to_tetra_mesh({"segments": segs})
	_mesh_cache[key] = m
	return m


static func _box_mesh_unit() -> Mesh4D:
	if _mesh_cache.has("unitbox"):
		return _mesh_cache["unitbox"]
	var m := Mats.box_mesh(Vector4.ONE)
	_mesh_cache["unitbox"] = m
	return m


func _cubinder(nm: String, r: float, h: float, t: float, segs: int, at: Vector4, role: String) -> void:
	var m := MeshInstance4D.new()
	m.name = nm
	m.mesh = _cubinder_mesh(r, h, t, segs)
	m.position = at
	m.set_meta(GENERATED, true)
	add_child(m)
	_parts[nm] = [m, Vector4(r * 2.0, h, r * 2.0, t), role]


func _glow_cubinder(nm: String, r: float, h: float, t: float, segs: int, at: Vector4) -> void:
	var m := MeshInstance4D.new()
	m.name = nm
	m.mesh = _cubinder_mesh(r, h, t, segs)
	m.position = at
	m.set_meta(GENERATED, true)
	add_child(m)
	_glows.append(m)


func _box(nm: String, size: Vector4, at: Vector4, role: String) -> void:
	var m := MeshInstance4D.new()
	m.name = nm
	m.mesh = Mats.box_mesh(size)
	m.position = at
	m.set_meta(GENERATED, true)
	add_child(m)
	_parts[nm] = [m, size, role]


func _glow_box(nm: String, size: Vector4, at: Vector4) -> void:
	var m := MeshInstance4D.new()
	m.name = nm
	m.mesh = Mats.box_mesh(size)
	m.position = at
	m.set_meta(GENERATED, true)
	add_child(m)
	_glows.append(m)


## A halo ring of short glowing segments round the column.
func _ring(nm: String, r: float, y: float) -> void:
	var n: int = 28
	for i in n:
		var a0: float = TAU * float(i) / float(n)
		var a1: float = TAU * float(i + 1) / float(n)
		var p0 := Vector4(cos(a0) * r, y, sin(a0) * r, 0.0)
		var p1 := Vector4(cos(a1) * r, y, sin(a1) * r, 0.0)
		var mid: Vector4 = (p0 + p1) * 0.5
		var seg := MeshInstance4D.new()
		seg.name = "%s%d" % [nm, i]
		seg.mesh = Mats.box_mesh(Vector4((p1 - p0).length() * 1.05, 0.02, 0.02, 0.35))
		seg.position = mid
		seg.basis = Basis4D.from_zx(atan2(p1.x - p0.x, p1.z - p0.z) - PI * 0.5)
		seg.set_meta(GENERATED, true)
		add_child(seg)
		_glows.append(seg)


# -- the mood ----------------------------------------------------------------------------------

func apply_mood(mood: String, _instant: bool = false) -> void:
	_mood = mood
	if not _built:
		return
	for nm in _parts:
		var entry: Array = _parts[nm]
		var role: String = entry[2]
		var mi: MeshInstance4D = entry[0]
		if role == "contact":
			mi.material_override = Mats.flat(Color(0.30, 0.31, 0.33) if mood == Style.BRIGHT else Color(0.03, 0.032, 0.04))
		else:
			mi.material_override = Mats.surface(Style.surface(role, mood), entry[1], 1.0 if entry[1].x < 3.0 else 2.0)
	var accent: Color = Style.code(part + "_fill", mood) if part != "neutral" else (Color(0.85, 0.87, 0.9) if mood == Style.BRIGHT else Color(0.72, 0.78, 0.86))
	if part == "neutral" and mood == Style.BRIGHT:
		accent = Color(0.62, 0.64, 0.68)
	for g in _glows:
		var gm: MeshInstance4D = g
		var is_ring: bool = String(gm.name).begins_with("Halo")
		var c: Color = Style.code("w_fill", mood) if is_ring else accent
		gm.material_override = Mats.glow(c, 1.0 if mood == Style.DARK else 0.92)
	var bar_mat: TetraMaterial4D = Mats.flat(Color(0.50, 0.51, 0.54)) if mood == Style.BRIGHT else Mats.glow(Color(0.24, 0.28, 0.34), 1.0)
	for b in _bars:
		(b[0] as MeshInstance4D).material_override = bar_mat
	if _tether != null:
		_tether.material_override = Mats.flat(Color(0.12, 0.13, 0.15)) if mood == Style.BRIGHT else Mats.glow(Color(0.55, 0.62, 0.72), 0.8)
	if _pool != null:
		_pool.visible = mood == Style.DARK
		_pool.light_energy = pool_energy


# -- running -----------------------------------------------------------------------------------

## Skin, blocks, lines or balls (LabKit/lab_views_4d.gd).
func set_view(v: String) -> void:
	if views != null:
		views.call("set_view", v)


func get_view() -> String:
	return String(views.get("view")) if views != null else "skin"


## Turns the animal through W, in degrees, eased.
func set_w_spin(degrees: float) -> void:
	_spin_goal = deg_to_rad(degrees)


func get_w_spin() -> float:
	return rad_to_deg(_spin_now)


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or animal == null:
		return
	_update_sleep()
	# The belt: bars run back along the walking direction at the speed planted feet slide.
	var speed: float = 0.0
	if not _asleep and animal.has_method("belt_speed") and not bool(animal.call("is_paused")):
		speed = float(animal.call("belt_speed"))
		var k: float = 1.0
		var clock: Node = get_tree().get_first_node_in_group("lab_clock")
		if clock != null and animal.get("animal") != null and clock.call("is_adopted", animal.get("animal")):
			k = float(clock.get("time_scale")) * float(clock.call("get_root_scale", animal.get("animal")))
			if bool(clock.get("paused")):
				k = 0.0
		speed *= k
	_belt_offset = fposmod(_belt_offset + speed * delta, belt_spacing)
	var front: Vector4 = _front()
	var side := Vector4(front.z, 0.0, -front.x, 0.0)
	var span: float = _r - 0.08
	for b in _bars:
		var bar: MeshInstance4D = b[0]
		var along: float = fposmod(float(b[1]) - _belt_offset + span, span * 2.0) - span
		var half_chord: float = sqrt(maxf(span * span - along * along, 0.0))
		bar.visible = half_chord > 0.05
		bar.position = front * along + Vector4(0.0, deck_height + 0.003, 0.0, 0.0)
		var p := Projection.IDENTITY
		p.x = side * (half_chord * 2.0 * 0.92)
		p.y = Vector4(0.0, 0.006, 0.0, 0.0)
		p.z = front * 0.035
		p.w = Vector4(0.0, 0.0, 0.0, 0.5)
		bar.basis = p
	# The tether: from the boom tip down to the animal's back.
	if _tether != null:
		var back: Vector4 = animal.position + Vector4(0.0, float(animal.get("height")) * 0.92, 0.0, 0.0)
		var d: Vector4 = _arm_tip - back
		var len: float = maxf(d.length(), 0.01)
		_tether.position = back + d * 0.5
		var tp := Projection.IDENTITY
		tp.x = Vector4(0.018, 0.0, 0.0, 0.0)
		tp.y = d.normalized() * len
		tp.z = Vector4(0.0, 0.0, 0.018, 0.0)
		tp.w = Vector4(0.0, 0.0, 0.0, 0.45)
		_tether.basis = tp
	# The W spin, eased.
	if not is_equal_approx(_spin_now, _spin_goal):
		_spin_now = move_toward(_spin_now, _spin_goal, delta * 1.6 * maxf(absf(_spin_goal - _spin_now), 0.15))
		animal.basis = Basis4D.from_xw(_spin_now)


func _update_sleep() -> void:
	var cam: Camera4D = LabMath.current_camera(get_tree())
	if cam == null:
		return
	var rel: Vector4 = global_position - cam.global_position
	var far: bool = rel.length() > sleep_distance
	var behind: bool = rel.dot(cam.global_basis * Vector4(0.0, 0.0, -1.0, 0.0)) < -_r * 2.0
	var sleep: bool = far or behind
	if sleep != _asleep:
		_asleep = sleep
		if animal.has_method("set_paused"):
			animal.call("set_paused", sleep)
	var w: Node = animal.call("walker") if animal.has_method("walker") else null
	if w != null and "pose_joints" in w:
		w.set("pose_joints", rel.length() < joint_distance)


func is_asleep() -> bool:
	return _asleep
