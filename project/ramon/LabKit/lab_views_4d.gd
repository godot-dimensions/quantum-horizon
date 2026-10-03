extends Node

## The view switch every rig carries: Skin, Blocks, Lines and Balls, the same four on every
## animal, so a visitor learns them once.
##
##   skin    the animal as it is
##   blocks  every rigid piece in its own colour: what moves as a whole, and where the joints are
##   lines   the skin hidden; bones as lines and joints as dots, as Etienne-Jules Marey drew
##           motion (a black suit with white stripes on the limbs and dots on the joints, photographed
##           as lines and dots). Planted feet are filled dots, swinging ones hollow, and each foot's
##           path through a whole cycle is a loop. Drawn by LabKit/lab_overlay_4d.gd.
##   balls   the loft rig's own balls (each one cross-section of the body) with the skin hidden.
##           On a strider the ball nodes never move by themselves (the walker moves the cut pieces),
##           so here they are carried along with the pieces they belong to, and put back after.
##
## Works on anything with the lab creature's surface: pieces(), legs(), balls(), rig(), walker().
## Lives as a child of the rig; the rig's `animal` is the creature. NO class_name.

const Style := preload("res://ramon/LabKit/lab_style.gd")
const Mats := preload("res://ramon/LabKit/lab_materials.gd")
const Overlay := preload("res://ramon/LabKit/lab_overlay_4d.gd")

const VIEWS := ["skin", "blocks", "lines", "balls"]
## The colours the Blocks view gives the pieces, by role first, then cycling per leg.
const BLOCK_BODY := Color(0.86, 0.87, 0.89)
const BLOCK_LEGS := [Color(0.27, 0.40, 0.92), Color(0.54, 0.36, 0.92), Color(0.18, 0.66, 0.74), Color(0.86, 0.62, 0.20),
	Color(0.88, 0.36, 0.42), Color(0.40, 0.70, 0.38), Color(0.62, 0.48, 0.34), Color(0.50, 0.52, 0.58)]
## Samples kept per foot for its path (about one cycle at 60 Hz for the slower gaits).
const TRAIL := 160

var view: String = "skin"
var mood: String = "bright"
var _rig: Node
var _saved_materials: Dictionary = {}   # MeshInstance4D -> material_override
var _hidden: Array = []                 # nodes this switch hid, to show again
var _stripped: Dictionary = {}          # MeshInstance4D -> its mesh, taken off to bare its children
var _balls: Array = []                  # [ball, rest local position, rest rig position, piece name or ""]
var _trails: Array = []                 # per foot: Array of Vector4 in the creature root's space
var _last_phase: float = -1.0


func _enter_tree() -> void:
	add_to_group("lab_mood_listener")


func _ready() -> void:
	_rig = get_parent()


func animal() -> Node:
	return _rig.get("animal") if _rig != null else null


## The views this animal has: Skin and Blocks always; Lines when it has legs a walker solves;
## Balls when it was lofted from ball nodes (the owl, the heron and the chipmunk are lofted in
## code, with no balls to show).
func available() -> PackedStringArray:
	var out := PackedStringArray(["skin", "blocks"])
	var a: Node = animal()
	if a == null:
		return out
	if not (a.call("legs") as Array).is_empty() or ["strider", "trym", "chicken"].has(String(a.get("driver"))):
		out.append("lines")
	if not (a.call("balls") as Array).is_empty():
		out.append("balls")
	return out


func set_view(v: String) -> void:
	if not VIEWS.has(v) or v == view or not available().has(v):
		return
	_leave(view)
	view = v
	_enter(v)


func next_view() -> void:
	var have: PackedStringArray = available()
	set_view(have[(have.find(view) + 1) % have.size()])


func apply_mood(m: String, _instant: bool = false) -> void:
	mood = m
	if view == "balls":
		_colour_balls()


# -- entering and leaving ----------------------------------------------------------------------

func _enter(v: String) -> void:
	var a: Node = animal()
	if a == null:
		return
	match v:
		"blocks":
			var leg_i: int = 0
			var last_leg: String = ""
			for p in a.call("pieces"):
				var mi: MeshInstance4D = p["mesh"]
				_saved_materials[mi] = mi.material_override
				var role: String = p["role"]
				var c: Color = BLOCK_BODY
				if role != "body" and role != "part":
					var leg_key: String = String(p["name"]).left(4)
					if leg_key != last_leg:
						last_leg = leg_key
						leg_i += 1
					c = BLOCK_LEGS[(leg_i - 1) % BLOCK_LEGS.size()]
					if role == "lower" or role == "foot":
						c = c.lightened(0.25)
					elif role == "joint":
						c = c.darkened(0.2)
				elif role == "part":
					c = BLOCK_LEGS[leg_i % BLOCK_LEGS.size()]
					leg_i += 1
				mi.material_override = Mats.flat(c)
		"lines":
			_hide_meshes(a.get("animal"))
			_gather_balls(a)
			add_to_group(Overlay.GROUP_DRAWER)
			Overlay.ensure(get_tree())
			_trails.clear()
		"balls":
			_hide_meshes(a.get("animal"))
			_gather_balls(a)
			for b in _balls:
				(b[0] as Node4D).visible = true
			_colour_balls()
			add_to_group(Overlay.GROUP_DRAWER)
			Overlay.ensure(get_tree())


func _leave(v: String) -> void:
	match v:
		"blocks":
			for mi in _saved_materials:
				if is_instance_valid(mi):
					(mi as MeshInstance4D).material_override = _saved_materials[mi]
			_saved_materials.clear()
		"lines":
			_balls.clear()
			_show_hidden()
			remove_from_group(Overlay.GROUP_DRAWER)
		"balls":
			for b in _balls:
				var ball: Node4D = b[0]
				if is_instance_valid(ball):
					ball.position = b[1]
					ball.visible = false
					if b[4] != null:
						ball.set("preview_color", b[4])
					if ball is MeshInstance4D:
						(ball as MeshInstance4D).material_override = b[5]
			_balls.clear()
			_show_hidden()
			remove_from_group(Overlay.GROUP_DRAWER)


## Takes the skin off. A mesh whose node carries balls (Trym's segments carry their handles)
## loses its mesh instead of being hidden, or the balls would hide with it: the cinema bares
## Trym's creature the same way (theatre_creature_4d.gd, show_rig).
func _hide_meshes(n: Node) -> void:
	if n == null:
		return
	for c in n.get_children():
		if c is MeshInstance4D and not c.has_method("get_loft_section"):
			var mi: MeshInstance4D = c
			if _carries_balls(mi):
				if mi.mesh != null:
					_stripped[mi] = mi.mesh
					mi.mesh = null
			elif mi.visible:
				mi.visible = false
				_hidden.append(mi)
				continue
		_hide_meshes(c)


func _carries_balls(n: Node) -> bool:
	for c in n.get_children():
		if c.has_method("get_loft_section"):
			return true
	return false


func _show_hidden() -> void:
	for n in _hidden:
		if is_instance_valid(n):
			n.set("visible", true)
	_hidden.clear()
	for mi in _stripped:
		if is_instance_valid(mi):
			(mi as MeshInstance4D).mesh = _stripped[mi]
	_stripped.clear()


## The balls, with where each rests (its own local position, and its place in the rig's space),
## and, on a strider, the cut piece that carries it: Leg{k}Thigh for a hip and a knee,
## Leg{k}Shank for a foot and anything below it.
func _gather_balls(a: Node) -> void:
	_balls.clear()
	var rig: Node4D = a.call("rig")
	if rig == null:
		return
	var inv: Projection = rig.global_basis.inverse()
	var carriers: Dictionary = {}
	var w: Node = a.call("walker")
	if String(a.get("driver")) == "strider" and w != null:
		var legs: Array = w.get("_legs")
		for k in legs.size():
			var leg: Dictionary = legs[k]
			carriers[leg["hip"]] = "Leg%dThigh" % k
			carriers[leg["knee"]] = "Leg%dThigh" % k
			carriers[leg["foot"]] = "Leg%dShank" % k
			for extra in (leg["foot"] as Node).get_children():
				if extra.has_method("get_loft_section"):
					carriers[extra] = "Leg%dShank" % k
	for b in a.call("balls"):
		var ball: Node4D = b
		var rest_rig: Vector4 = inv * (ball.global_position - rig.global_position)
		var colour = ball.get("preview_color") if "preview_color" in ball else null
		_balls.append([ball, ball.position, rest_rig, carriers.get(ball, ""), colour, (ball as MeshInstance4D).material_override if ball is MeshInstance4D else null])


func _colour_balls() -> void:
	var c: Color = Style.code("build", mood)
	for b in _balls:
		var ball: Node = b[0]
		if is_instance_valid(ball) and "preview_color" in ball:
			ball.set("preview_color", c)


# -- every frame -------------------------------------------------------------------------------

func _process(_delta: float) -> void:
	var a: Node = animal()
	if a == null:
		return
	if view == "balls":
		_carry_balls(a)
	elif view == "lines":
		_sample_trails(a)


func _carry_balls(a: Node) -> void:
	var rig: Node4D = a.call("rig")
	if rig == null:
		return
	for b in _balls:
		var carrier: String = b[3]
		if carrier.is_empty():
			continue
		var piece: Node4D = rig.get_node_or_null(carrier) as Node4D
		var ball: Node4D = b[0]
		if piece == null or not is_instance_valid(ball):
			continue
		var now_rig: Vector4 = piece.basis * (b[2] as Vector4) + piece.position
		ball.global_position = rig.global_basis * now_rig + rig.global_position


func _sample_trails(a: Node) -> void:
	var legs: Array = a.call("legs")
	if legs.is_empty():
		return
	var phase: float = float(a.call("get_phase"))
	if is_equal_approx(phase, _last_phase):
		return
	_last_phase = phase
	var root: Node4D = a as Node4D
	var inv: Projection = root.global_basis.inverse()
	while _trails.size() < legs.size():
		_trails.append([])
	for i in legs.size():
		var local: Vector4 = inv * ((legs[i]["foot"] as Vector4) - root.global_position)
		var t: Array = _trails[i]
		t.append(local)
		if t.size() > TRAIL:
			t.pop_front()


func draw_overlay(canvas: Control, overlay: Node) -> void:
	# Only while its rig is shown: a rig in a bay you have left is hidden, not gone.
	if _rig == null or not (_rig as Node4D).is_visible_in_tree():
		return
	var a: Node = animal()
	if a == null:
		return
	var ink: Color = Color(0.08, 0.09, 0.11) if mood == Style.BRIGHT else Color(0.96, 0.97, 1.0)
	var accent: Color = Style.code("motion", mood)
	var ui: float = clampf(canvas.get_viewport_rect().size.y / 1080.0, 0.7, 2.2)
	if view == "lines":
		var root: Node4D = a as Node4D
		# The foot paths, one loop per foot, in the creature's own frame (on a treadmill a foot
		# traces the same loop under the body every stride).
		for t in _trails:
			var pts := PackedVector2Array()
			for local in t:
				var world: Vector4 = root.global_basis * (local as Vector4) + root.global_position
				var s = overlay.to_screen(world)
				if s != null:
					pts.append(s)
			if pts.size() > 2:
				canvas.draw_polyline(pts, Color(accent, 0.55), 1.6 * ui, true)
		# The body, thinner than the legs: on Trym's creature a bone through each segment (its two
		# handles); on a lofted animal the spine and branches through its balls, skipping the leg
		# balls (the legs are drawn from the walker's solved pose below).
		_draw_skeleton(canvas, overlay, a, Color(ink, 0.85), 2.0 * ui)
		for leg in a.call("legs"):
			var chain: Array = [leg["hip"], leg["knee"]]
			if leg.has("ankle"):
				chain.append(leg["ankle"])
			chain.append(leg["foot"])
			var fade: float = overlay.slice_fade(leg["hip"])
			if fade <= 0.0:
				continue
			var prev = null
			for p in chain:
				var s = overlay.to_screen(p)
				if s != null and prev != null:
					canvas.draw_line(prev, s, Color(ink, fade), 3.0 * ui, true)
				prev = s
			for j in chain.size() - 1:
				var sj = overlay.to_screen(chain[j])
				if sj != null:
					canvas.draw_circle(sj, 4.5 * ui, Color(ink, fade))
			var sf = overlay.to_screen(leg["foot"])
			if sf != null:
				if bool(leg["planted"]):
					canvas.draw_circle(sf, 7.0 * ui, Color(accent, fade))
				else:
					canvas.draw_arc(sf, 7.0 * ui, 0.0, TAU, 20, Color(accent, fade), 2.0 * ui, true)
			# The stepping circle: where a foot in the air will come down, drawn flat on the ground.
			if not bool(leg["planted"]) and leg.has("land"):
				_ground_ring(canvas, overlay, leg["land"], 0.075, Color(accent, 0.9 * fade), 1.6 * ui)
	if view == "balls":
		# The spine: a line through the balls of each chain, in the build colour.
		# A chain is the rig's direct ball children in order (the spine) plus each branch nested
		# ball inside ball, so a ball links to its parent ball, or to the previous sibling ball
		# when it sits straight under the rig.
		var c: Color = Style.code("build", mood)
		var prev_root: Node4D = null
		for b in _balls:
			var ball: Node4D = b[0]
			if not is_instance_valid(ball):
				continue
			var parent: Node = ball.get_parent()
			var from: Node4D = null
			if parent != null and parent.has_method("get_loft_section"):
				from = parent as Node4D
			else:
				from = prev_root
				prev_root = ball
			if from == null:
				continue
			var s0 = overlay.to_screen(from.global_position)
			var s1 = overlay.to_screen(ball.global_position)
			if s0 != null and s1 != null:
				canvas.draw_line(s0, s1, Color(c, 0.75), 2.0, true)


## A dashed ring lying on the ground (the X-Z plane) round `centre`, `r` metres across.
func _ground_ring(canvas: Control, overlay: Node, centre: Vector4, r: float, col: Color, width: float) -> void:
	var n: int = 20
	for i in n:
		if i % 2 == 1:
			continue
		var a0: float = TAU * float(i) / float(n)
		var a1: float = TAU * float(i + 1) / float(n)
		var p0 = overlay.to_screen(centre + Vector4(cos(a0) * r, 0.0, sin(a0) * r, 0.0))
		var p1 = overlay.to_screen(centre + Vector4(cos(a1) * r, 0.0, sin(a1) * r, 0.0))
		if p0 != null and p1 != null:
			canvas.draw_line(p0, p1, col, width, true)


func _draw_skeleton(canvas: Control, overlay: Node, a: Node, ink: Color, width: float) -> void:
	if String(a.get("driver")) == "trym":
		for b in _balls:
			var ball: Node4D = b[0]
			if not is_instance_valid(ball) or String(ball.name) != "B2":
				continue
			var seg: Node = ball.get_parent()
			var b1: Node4D = seg.get_node_or_null("B1") as Node4D
			if b1 == null:
				continue
			var s0 = overlay.to_screen(b1.global_position)
			var s1 = overlay.to_screen(ball.global_position)
			if s0 != null and s1 != null:
				canvas.draw_line(s0, s1, ink, width, true)
				canvas.draw_circle(s0, width + 1.0, ink)
		return
	var prev_root: Node4D = null
	for b in _balls:
		var ball: Node4D = b[0]
		if not is_instance_valid(ball):
			continue
		var parent: Node = ball.get_parent()
		var from: Node4D = null
		if parent != null and parent.has_method("get_loft_section"):
			from = parent as Node4D
		else:
			from = prev_root
			prev_root = ball
		if from == null or not String(b[3]).is_empty():
			continue
		var s0 = overlay.to_screen(from.global_position)
		var s1 = overlay.to_screen(ball.global_position)
		if s0 != null and s1 != null:
			canvas.draw_line(s0, s1, ink, width, true)
			canvas.draw_circle(s1, width + 1.0, ink)
