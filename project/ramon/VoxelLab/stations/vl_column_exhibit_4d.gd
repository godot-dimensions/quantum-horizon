extends "res://ramon/VoxelLab/stations/vl_exhibit_4d.gd"

## The Voxel Lab's column: cut its base until it falls (Ramon, 6 Oct: "cutting away a column's base so
## its upper section falls, or cutting a stylised tree trunk so it topples").
##
## TWO PIECES, ONE COLUMN. The base (`specimen`, the one the bench cuts) and the top are separate voxel
## worlds, stacked. Neither has a crust where they meet, so the seam inside is core against core and
## never shows; when the top goes, the base's broken face is orange, as a fresh break should be. The
## column is round in X, Z and W (the engine's cylinder generator is round over the three horizontal
## axes): in any slice a round column, thinner the further its middle is from your slice.
##
## NO SIMULATION. After every cut, our own copy of the base (vl_recipe.gd) is sampled across its
## height, each level a 3D ball of points in X, Z and W: how much of it is left, and where. The
## weakest level decides. It falls when little is left, or when what is left is off to one side; it
## tips over the edge that is left, in the plane of "up" and the way it lost its support, which may
## lean into W. It tips about that edge, slides off, falls, bounces once and lies. If it fell kata or
## ana it leaves your slice: lying along W, a round column shows as a ball.
##
## THE TREE (E at the station): a thinner trunk with bark and pale wood, and a crown of leaf balls on
## the top piece, on the same mechanism.
##
## NO class_name (engine_gotchas.md).

const Chips := preload("res://ramon/VoxelLab/room/vl_chips_4d.gd")
const Sound := preload("res://ramon/VoxelLab/room/vl_sound.gd")

const VOXEL := 0.07
## Gravity for the fall, metres a second squared, and where the floor is under the stand (set from the
## pedestal's height in _ready).
const G := 9.8

## "column" or "tree".
var form: String = "column"
## How much of the base must be left (0 to 1) for the top to stay up, and how far off the axis what is
## left may be (as a fraction of the radius) before it tips anyway.
var hold_fraction: float = 0.22
## A felling notch leaves about 40% of a trunk, all at the back: that tips (6 Oct, the first tree).
var hold_offset: float = 0.38

var top: Node4D
var top_spec: Node4D
var crown_spec: Node4D
## "standing", "falling", "lying"
var state: String = "standing"
## The last support measure: {fraction, offset (x, z, w voxels), level}.
var support: Dictionary = {}
var _recipes: Dictionary = {}
var _fall: Dictionary = {}
var _audio: AudioStreamPlayer
var _done: Dictionary = {}
var _story_cut: bool = false


func _init() -> void:
	code = "CL-02"
	title = "The column"
	display_scale = 1.0
	turn_speed = 4.0


func _ready() -> void:
	super._ready()
	_build_top()
	_audio = AudioStreamPlayer.new()
	_audio.volume_db = -3.0
	add_child(_audio)


func _dims() -> Dictionary:
	if form == "tree":
		return {"r": 0.24, "base_h": 0.9, "top_h": 1.6, "crust": 0.07,
			"colors": {Recipe.CRUST: Color(0.36, 0.25, 0.17), Recipe.CORE: Color(0.86, 0.72, 0.50)}}
	return {"r": 0.42, "base_h": 1.05, "top_h": 1.4, "crust": 0.1, "colors": Recipe.COLORS}


func recipe() -> Dictionary:
	var key: String = form + ":base"
	if not _recipes.has(key):
		var d: Dictionary = _dims()
		var r: Dictionary = Recipe.column(float(d["r"]), float(d["base_h"]), VOXEL, {"open_top": true, "crust_m": float(d["crust"]), "colors": d["colors"]})
		r["voxel_count"] = Recipe.voxel_count(r)
		_recipes[key] = r
	return _recipes[key]


func _top_recipe() -> Dictionary:
	var key: String = form + ":top"
	if not _recipes.has(key):
		var d: Dictionary = _dims()
		_recipes[key] = Recipe.column(float(d["r"]), float(d["top_h"]), VOXEL, {"open_bottom": true, "crust_m": float(d["crust"]), "colors": d["colors"]})
	return _recipes[key]


func _crown_recipe() -> Dictionary:
	if not _recipes.has("crown"):
		var balls: Array = []
		var rng := RandomNumberGenerator.new()
		rng.seed = 11
		for i in 9:
			var a: float = TAU * float(i) / 9.0
			var up: float = rng.randf_range(-0.15, 0.35)
			balls.append([Vector4(cos(a) * 0.45, up, sin(a) * 0.45, rng.randf_range(-0.35, 0.35)), rng.randf_range(0.32, 0.46)])
		balls.append([Vector4(0, 0.45, 0, 0), 0.5])
		balls.append([Vector4(0, 0.05, 0, 0), 0.42])
		var r: Dictionary = Recipe.crown(Vector4(2.0, 1.6, 2.0, 1.6), VOXEL, balls)
		r["colors"] = {Recipe.CROWN: Color(0.30, 0.55, 0.26)}
		_recipes["crown"] = r
	return _recipes["crown"]


## The top piece, standing on the base: its middle half its height above the seam.
func _build_top() -> void:
	if top != null:
		top.queue_free()
	top = Node4D.new()
	top.name = "Top"
	stand.add_child(top)
	var d: Dictionary = _dims()
	var base_r: Dictionary = recipe()
	var seam_y: float = (base_r["half"] as Vector4).y * VOXEL * 2.0 + 0.01
	top.position = Vector4(0, seam_y + float(d["top_h"]) * 0.5, 0, 0)
	top_spec = Node4D.new()
	top_spec.name = "TopPiece"
	top_spec.set_script(Specimen)
	top.add_child(top_spec)
	top_spec.call("build", _top_recipe())
	crown_spec = null
	if form == "tree":
		crown_spec = Node4D.new()
		crown_spec.name = "Crown"
		crown_spec.set_script(Specimen)
		crown_spec.position = Vector4(0, float(d["top_h"]) * 0.5 + 0.35, 0, 0)
		top.add_child(crown_spec)
		crown_spec.call("build", _crown_recipe())
	state = "standing"
	support = {}
	_fall = {}


func _after_make(s: Node4D) -> void:
	s.connect("cut_done", _on_base_cut)


func is_ready() -> bool:
	return super.is_ready() and top_spec != null and bool(top_spec.call("is_ready"))


## Whole again: a fresh base (the spare), the top back on it.
func reset() -> void:
	super.reset()
	_build_top()


## E at the station: the column or the tree.
func action_label() -> String:
	return "A tree instead" if form == "column" else "A column instead"


func action() -> String:
	form = "tree" if form == "column" else "column"
	title = "The tree" if form == "tree" else "The column"
	code = "TR-02" if form == "tree" else "CL-02"
	if spare != null:
		spare.queue_free()
		spare = null
	specimen.call("build", recipe())
	specimen.position = _rest_position(recipe())
	(func() -> void:
		if is_inside_tree():
			spare = _make("Spare", true)).call_deferred()
	_build_top()
	return "A tree: cut its trunk" if form == "tree" else "A column: cut its base"


# -- support -------------------------------------------------------------------------------------------

func _on_base_cut(_rec: Dictionary) -> void:
	if state != "standing":
		return
	support = measure()
	if _should_fall(support):
		_start_fall(support)


## How much of the base is left, level by level (each a 3D ball of points across X, Z and W), and the
## weakest level: {fraction, offset (voxels, x z w), level y}.
func measure() -> Dictionary:
	var r: Dictionary = recipe()
	var col: Dictionary = r["column"]
	var c: Vector4 = col["center"]
	var rad: float = float(col["radius"]) - 0.3
	var y0: float = float(col["y0"])
	var y1: float = float(col["y1"])
	var cuts: Array = specimen.get("cuts") if specimen != null else []
	var worst: Dictionary = {"fraction": 1.0, "offset": Vector3.ZERO, "level": y1}
	var levels: int = 7
	for li in levels:
		var y: float = lerpf(y0 + 1.0, y1 - 0.6, float(li) / float(levels - 1))
		var total: int = 0
		var left: int = 0
		var sum := Vector3.ZERO
		var ri: int = int(ceil(rad))
		for w in range(-ri, ri + 1):
			for z in range(-ri, ri + 1):
				for x in range(-ri, ri + 1):
					var q := Vector3(x, z, w)
					if q.length() > rad:
						continue
					total += 1
					if Recipe.solid(r, cuts, Vector4(c.x + x, y, c.z + z, c.w + w)):
						left += 1
						sum += q
		if total == 0:
			continue
		var f: float = float(left) / float(total)
		if f < float(worst["fraction"]):
			worst = {"fraction": f, "offset": sum / maxf(float(left), 1.0), "level": y}
	worst["radius"] = rad
	return worst


func _should_fall(s: Dictionary) -> bool:
	var f: float = float(s.get("fraction", 1.0))
	var off: float = (s.get("offset", Vector3.ZERO) as Vector3).length() / maxf(float(s.get("radius", 1.0)), 0.1)
	return f < hold_fraction or (f < 0.5 and off > hold_offset)


## The share of the base still holding it, as a whole percentage (for the callouts).
func support_text() -> String:
	return "%d%%" % int(round(float(support.get("fraction", 1.0)) * 100.0))


# -- the fall --------------------------------------------------------------------------------------------

func _start_fall(s: Dictionary) -> void:
	var off: Vector3 = s.get("offset", Vector3.ZERO)
	# It tips away from what is left: (x, z, w) of the offset is voxels in x, z and W.
	var d4 := Vector4(-off.x, 0.0, -off.y, -off.z)
	if d4.length() < 0.3:
		# Cut evenly all round: it falls toward where the last cut was.
		var cuts: Array = specimen.get("cuts")
		var last: Dictionary = cuts[-1] if not cuts.is_empty() else {}
		var b: Array = last.get("aabb", [Vector4.ZERO, Vector4.ZERO])
		var mid: Vector4 = ((b[0] as Vector4) + (b[1] as Vector4)) * 0.5 - (recipe()["center"] as Vector4)
		d4 = Vector4(mid.x, 0.0, mid.z, mid.w)
	if d4.length() < 0.01:
		d4 = Vector4(0, 0, 1, 0)
	var d: Vector4 = d4.normalized()
	var dims: Dictionary = _dims()
	var rad: float = float(dims["r"])
	var seam_y: float = (recipe()["half"] as Vector4).y * VOXEL * 2.0
	_fall = {"d": d, "pivot": Vector4(0, seam_y, 0, 0) + d * rad, "rest": top.position, "theta": 0.0, "omega": 0.0,
		"phase": "tip", "v": Vector4.ZERO, "drop": Vector4.ZERO, "t": 0.0, "bounced": false,
		"floor": -stand.global_position.y + 0.02, "half_len": float(dims["top_h"]) * 0.5, "r": rad}
	state = "falling"
	var neck: Vector4 = stand.global_position + stand.global_basis * (Vector4(0, seam_y, 0, 0) + d * rad)
	Chips.spawn(get_tree().current_scene, neck, d, [Recipe.COLORS[Recipe.CORE], Recipe.COLORS[Recipe.CRUST]], 18, 0.06, 2.0)
	_play(0.5)


static func plane_rotation(u: Vector4, d: Vector4, th: float) -> Projection:
	var cols: Array = []
	for i in 4:
		var e := Vector4.ZERO
		e[i] = 1.0
		cols.append(e + (d * u.dot(e) - u * d.dot(e)) * sin(th) + (u * u.dot(e) + d * d.dot(e)) * (cos(th) - 1.0))
	return Projection(cols[0], cols[1], cols[2], cols[3])


func _process(delta: float) -> void:
	if state != "falling" or _fall.is_empty():
		return
	var f: Dictionary = _fall
	var u := Vector4(0, 1, 0, 0)
	var d: Vector4 = f["d"]
	f["t"] = float(f["t"]) + delta
	var th: float = float(f["theta"])
	var om: float = float(f["omega"])
	match String(f["phase"]):
		"tip":
			# Tipping over the edge: like an inverted pendulum, slow to start.
			om += (1.6 + 7.5 * sin(th + 0.12)) * delta
			th += om * delta
			if th > 0.55:
				# Off the edge: from here a free body. Its middle flies on as it was moving (gravity
				# from now on) and it turns about that middle, no longer about the edge.
				var arm: Vector4 = (f["rest"] as Vector4) - (f["pivot"] as Vector4)
				var rot: Projection = plane_rotation(u, d, th)
				var arm_now: Vector4 = rot * arm
				f["v"] = (d * u.dot(arm_now) - u * d.dot(arm_now)) * om
				f["release"] = (f["pivot"] as Vector4) + arm_now
				f["phase"] = "drop"
		"drop":
			om = maxf(om * (1.0 - 0.6 * delta), 1.2)
			th = minf(th + om * delta, PI * 0.5)
			var v: Vector4 = f["v"]
			v.y -= G * delta
			f["v"] = v
			f["drop"] = (f["drop"] as Vector4) + v * delta
			# The lowest point of the piece, from its middle: the long axis tilted by th, plus its radius.
			var mid: Vector4 = _top_middle(f, th)
			var lowest: float = mid.y - float(f["half_len"]) * absf(cos(th)) - float(f["r"]) * sin(th)
			if lowest <= float(f["floor"]):
				f["drop"] = (f["drop"] as Vector4) + Vector4(0, float(f["floor"]) - lowest, 0, 0)
				if not bool(f["bounced"]):
					f["bounced"] = true
					f["v"] = Vector4(v.x * 0.35, absf(v.y) * 0.22, v.z * 0.35, v.w * 0.35)
					var hit: Vector4 = stand.global_position + stand.global_basis * Vector4(mid.x, float(f["floor"]), mid.z, mid.w)
					Chips.spawn(get_tree().current_scene, hit, Vector4(0, 1, 0, 0), [Recipe.COLORS[Recipe.CRUST], Recipe.COLORS[Recipe.CORE]], 26, 0.08, 3.2)
					_play(1.0)
				elif v.y <= 0.0:
					th = PI * 0.5
					f["phase"] = "rest"
		"rest":
			th = PI * 0.5
			state = "lying"
	f["theta"] = th
	f["omega"] = om
	top.basis = plane_rotation(u, d, th)
	top.position = _top_middle(f, th)


## Where the top's middle is at turn `th`: turned about the edge it tips over; after it leaves the edge,
## where it was then plus how far it has flown.
func _top_middle(f: Dictionary, th: float) -> Vector4:
	if f.has("release"):
		return (f["release"] as Vector4) + (f["drop"] as Vector4)
	var arm: Vector4 = (f["rest"] as Vector4) - (f["pivot"] as Vector4)
	return (f["pivot"] as Vector4) + plane_rotation(Vector4(0, 1, 0, 0), f["d"], th) * arm


func _play(weight: float) -> void:
	if _audio == null:
		return
	_audio.stream = Sound.crunch(weight, 0.25 + 0.35 * weight)
	_audio.pitch_scale = randf_range(0.85, 1.0)
	_audio.play()


func idle(delta: float) -> void:
	if state == "standing":
		super.idle(delta)


# -- the story -----------------------------------------------------------------------------------------

func chapters() -> Array:
	var c := Vector4(0, 1.3, 0, 0)
	return [
		{"key": "column", "title": "A COLUMN", "length": 6.0,
			"line": "Round in X, Z and W, standing on its base.",
			"callouts": [[1.4, "{voxels} voxels of {voxel}. The top is a second piece, resting on the base."]],
			"eye": Vector4(2.6, 2.0, 4.6, 0), "look": c, "fov": 0.9},
		{"key": "slice", "title": "CUT THROUGH YOUR SLICE", "length": 11.0,
			"line": "Cut right through the base, in your slice.",
			"callouts": [[2.2, "In this slice it is cut through. It still stands."],
				[5.6, "Slide through W: its base is still there, ana and kata of your slice."]],
			"eye": Vector4(1.6, 1.6, 4.4, 0), "look": c + Vector4(0, -0.4, 0, 0), "fov": 0.85},
		{"key": "kata", "title": "THROUGH W AS WELL", "length": 9.0,
			"line": "Now cut away the kata side too.",
			"callouts": [[2.0, "Only the ana side holds it now."], [4.4, "It tips the way it lost its support: kata."]],
			"eye": Vector4(2.2, 1.9, 4.6, 0), "look": c, "fov": 0.9},
		{"key": "where", "title": "WHERE DID IT GO?", "length": 9.0,
			"line": "It fell out of your slice.",
			"callouts": [[1.6, "Slide kata to find it."], [5.0, "Lying along W, a round column looks like a ball."]],
			"eye": Vector4(2.8, 2.2, 5.4, 0), "look": c + Vector4(0, -0.6, 0, 0), "fov": 0.95},
	]


func play_part(key: String, t: float, length: float) -> Dictionary:
	var r: Dictionary = recipe()
	var col: Dictionary = r["column"]
	var ctr: Vector4 = col["center"]
	var rad: float = float(col["radius"])
	var neck_y: float = lerpf(float(col["y0"]), float(col["y1"]), 0.55)
	face_front(0.08)
	match key:
		"slice":
			if t > 1.0:
				# A slab through X and Z, only 0.3 m deep in W: through the column in your slice.
				_cut_once("slice", Cut.block(Vector4(ctr.x, neck_y, ctr.z, ctr.w), Vector4(rad + 2.0, 1.4, rad + 2.0, 0.15 / VOXEL)))
			return {"slice": _sweep(t, 5.0, length - 0.5, 0.3)}
		"kata":
			if t > 1.2:
				_cut_once("kata", Cut.block(Vector4(ctr.x, neck_y, ctr.z, ctr.w - rad), Vector4(rad + 2.0, 1.4, rad + 2.0, rad)))
		"where":
			# Kata, where it lies.
			var w_now: float = -0.35 * smoothstep(1.2, 4.0, t) * (1.0 - smoothstep(7.0, 8.6, t))
			return {"slice": _fraction(w_now)}
	return {}


func _cut_once(key: String, cut: Dictionary) -> void:
	if _done.has(key) or specimen == null or not bool(specimen.call("is_ready")):
		return
	_done[key] = true
	_story_cut = true
	cut["label"] = "Story: " + key
	specimen.call("apply_cut", cut)


func _sweep(t: float, t0: float, t1: float, reach: float) -> float:
	var u: float = clampf((t - t0) / maxf(t1 - t0, 0.1), 0.0, 1.0)
	return _fraction(sin(u * TAU) * reach)


func _fraction(w: float) -> float:
	return -(w * display_scale) / maxf(w_extent(), 0.01)


func end_cinematic() -> void:
	if _story_cut or state != "standing":
		_story_cut = false
		_done = {}
		reset()
	_done = {}


func numbers() -> Dictionary:
	var n: Dictionary = super.numbers()
	n["support"] = support_text()
	return n


func band_line() -> String:
	var n: Dictionary = numbers()
	return "%s  ·  CUT ITS BASE UNTIL IT FALLS  ·  %s VOXELS OF %s" % [title.to_upper(), String(n["voxels"]), String(n["voxel"]).to_upper()]


func live() -> Array:
	return [["Base left", support_text()], ["State", state]]


func card() -> Dictionary:
	var n: Dictionary = numbers()
	return {
		"short": "A column you can cut until it falls. In 4D it stands as long as any W of its base is left.",
		"code": code, "title": title, "kicker": "SUPPORT IN 4D",
		"method": "Two voxel worlds stacked, base and top, with no crust where they meet. After every cut the lab samples its own copy of the base across its height, each level a ball of points across X, Z and W, and finds the weakest level: how much is left, and where.",
		"shows": "Cut through your slice and it still stands: its base goes on ana and kata of you. Cut through W too and it tips the way it lost its support, which can be out of your slice.",
		"limits": "The fall is scripted, not simulated: it tips over the edge that is left, slides off and lies. The engine's physics treats every shape as a box.",
		"rows": [["Base left", support_text()], ["Voxels", "%s of %s" % [String(n["voxels"]), String(n["voxel"])]], ["Tetrahedra (base)", String(n["tets"])]],
		"tier": "MEASURED LIVE", "key": action_label(),
	}
