@tool
extends Node4D

## The Lookout: a fire-lookout tower at the edge of the field, built as a hide.
##
## ITS SHAPE IS A REAL LOOKOUT'S, scaled to the pen. A steel frame of four splayed legs and
## X braces carries a small timber cab - real cabs are 2 to 4 m square on towers of 10 to
## 50 m (the US Forest Service's L-4 cab is 14 ft, 4.3 m) - with windows all round at sill
## height, a catwalk outside them and a low roof with a lightning rod. Ten metres up puts the
## deck above every roof on the farm (the shed ridge is about 3.2 m) and level with the bottom
## of the starlings' band (12-26 m), which is the point: nothing blocks you, and the flock
## comes past at eye level.
##
## THE CAB IS A CLOSED 4D ROOM (follow_up/4d_enclosure_rule.md): eight walls, not six. The
## four ordinary walls, the floor and the roof run the cab's whole W depth, and two more
## walls cap the two ends of W, so turning the slice never opens it. It is deeper in W (6.4 m)
## than it is wide (4 m), against the rule's advice, on purpose: the camera's focus ring slides
## your slice up to 3 m along W without moving you (lookout_station_4d.gd), and a cab that
## ended at 2 m would vanish round you halfway along the ring. A quarter turn into W shows a
## room a little longer than it is wide, which reads as a room. The W walls have windows too
## - a frame round an opening - so with the slice turned you can look out ALONG W.
##
## AND IT IS A HIDE. A dark inside and solid lower walls, as real hides have, because what
## frightens an animal is a silhouette in an opening, not the building.
##
## THE ANA POST. Outside the north window, three metres out, stands a perch that exists only
## at w +1.5 (thin in W, everything else here is full depth). From the home slice there is
## nothing there. Turn the camera's focus ring to +1.5 and there is a post, right outside the
## window - and on it, whatever lives there. It runs all the way down to the ground, so on
## foot, a step ana, it is a lone pole in the field.
##
## Everything is boxes, as the pen's own buildings are, sharing one mesh per size.
##
## ONE MESH PER COLOUR, NOT ONE NODE PER BOX. Every MeshInstance4D costs something each
## frame whether or not it is on screen, and this is a few hundred boxes that never move.
## So with [member merge_parts] on (the default) the boxes of each colour are merged into a
## single ArrayTetraMesh4D (TetraMesh4D.to_array_tetra_mesh, ArrayTetraMesh4D.merge_with)
## and drawn by one node. Off, every box is its own named node, for picking parts apart.

@export_group("Size")
## Height of the cab floor above the tower's feet.
@export_range(4.0, 30.0, 0.5, "suffix:m") var deck_height: float = 10.0
## The cab's footprint, x and z, and its depth along W.
@export_range(2.0, 8.0, 0.1, "suffix:m") var cab_size: float = 4.0
@export_range(2.0, 10.0, 0.1, "suffix:m") var cab_w_depth: float = 6.4
@export_range(2.0, 4.0, 0.05, "suffix:m") var cab_height: float = 2.6
## Sill and lintel of the windows, from the cab floor. A hide's slot sits about 1 m up.
@export_range(0.3, 1.5, 0.05, "suffix:m") var sill: float = 1.0
@export_range(1.6, 3.0, 0.05, "suffix:m") var lintel: float = 2.2
## How far the legs splay out at the foot, past the cab's corners.
@export_range(0.0, 4.0, 0.1, "suffix:m") var splay: float = 1.4

@export_group("The ana post")
@export var ana_post: bool = true
## Its W, and how far out of the north window it stands.
@export_range(-4.0, 4.0, 0.05, "suffix:m") var ana_post_w: float = 1.5
@export_range(1.0, 8.0, 0.1, "suffix:m") var ana_post_out: float = 3.2
@export_range(-3.0, 3.0, 0.05, "suffix:m") var ana_post_side: float = 0.7

@export_group("Look")
@export var steel: Color = Color(0.20, 0.22, 0.21)
@export var timber: Color = Color(0.36, 0.27, 0.19)
@export var timber_dark: Color = Color(0.22, 0.16, 0.12)
@export var roof_colour: Color = Color(0.16, 0.18, 0.17)
@export var inside: Color = Color(0.10, 0.08, 0.07)
@export var merge_parts: bool = true

var _meshes: Dictionary = {}
var _batches: Dictionary = {}
var _arrays: Dictionary = {}
var _materials: Dictionary = {}


func _ready() -> void:
	rebuild()


## The point a climber stands at, at the ladder's foot, in global space.
func ladder_foot() -> Vector4:
	return global_position + global_basis * Vector4(0.0, 0.0, cab_size * 0.5 + splay * 0.8 + 0.9, 0.0)


## Where the eye is in the cab, standing at the north window, in global space.
func cab_eye() -> Vector4:
	return global_position + global_basis * Vector4(0.0, deck_height + 1.55, -cab_size * 0.18, 0.0)


## The cab's middle, at the floor, in global space.
func cab_floor() -> Vector4:
	return global_position + global_basis * Vector4(0.0, deck_height, 0.0, 0.0)


## The top of the ana post - where its perch is - in global space.
func ana_perch() -> Vector4:
	return global_position + global_basis * Vector4(ana_post_side, deck_height + 1.05, -cab_size * 0.5 - ana_post_out, ana_post_w)


## The north direction the windows look out of: -z of this node.
func north() -> Vector4:
	return (global_basis * Vector4(0.0, 0.0, -1.0, 0.0)).normalized()


func rebuild() -> void:
	for child in get_children():
		child.free()
	_meshes.clear()
	var h: float = deck_height
	var half: float = cab_size * 0.5
	var wd: float = cab_w_depth
	_build_legs(h, half, wd)
	_build_cab(h, half, wd)
	_build_ladder(h, half, wd)
	_build_catwalk(h, half, wd)
	if ana_post:
		_build_ana_post(h, half)
	_flush()
	_build_colliders(h, half, wd)


# --- The frame -------------------------------------------------------------------------------

func _build_legs(h: float, half: float, wd: float) -> void:
	var foot: float = half + splay
	var top: float = half - 0.12
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var a := Vector4(sx * foot, -0.6, sz * foot, 0.0)
			var b := Vector4(sx * top, h, sz * top, 0.0)
			_strut("Leg", a, b, 0.26, wd, steel)
			# A concrete pad under each foot.
			_box("Pad", Vector4(sx * foot, 0.05, sz * foot, 0.0), Vector4(0.9, 0.3, 0.9, wd), Color(0.42, 0.41, 0.38))
	# X braces on the four faces, in three tiers, and a ring at the top of each.
	var tiers: int = 3
	for t in tiers:
		var y0: float = h * float(t) / float(tiers)
		var y1: float = h * float(t + 1) / float(tiers)
		var r0: float = lerpf(foot, top, float(t) / float(tiers))
		var r1: float = lerpf(foot, top, float(t + 1) / float(tiers))
		for face in 4:
			var ca: Vector2 = _corner(face, r0)
			var cb: Vector2 = _corner(face + 1, r0)
			var cc: Vector2 = _corner(face, r1)
			var cd: Vector2 = _corner(face + 1, r1)
			_strut("Brace", Vector4(ca.x, y0, ca.y, 0.0), Vector4(cd.x, y1, cd.y, 0.0), 0.09, wd, steel)
			_strut("Brace", Vector4(cb.x, y0, cb.y, 0.0), Vector4(cc.x, y1, cc.y, 0.0), 0.09, wd, steel)
			_strut("Girt", Vector4(cc.x, y1, cc.y, 0.0), Vector4(cd.x, y1, cd.y, 0.0), 0.12, wd, steel)


## Corner [param i] of the square of half-size [param r], going round.
func _corner(i: int, r: float) -> Vector2:
	var corners: Array = [Vector2(-r, -r), Vector2(r, -r), Vector2(r, r), Vector2(-r, r)]
	return corners[posmod(i, 4)]


func _build_ladder(h: float, half: float, wd: float) -> void:
	# On the south face, the pen's side. Straight up from the ground to a hatch in the catwalk,
	# well clear of the splayed legs.
	var z: float = half + splay * 0.8 + 0.35
	for side in [-0.32, 0.32]:
		_box("LadderRail", Vector4(side, h * 0.5 - 0.3, z, 0.0), Vector4(0.06, h + 0.6, 0.06, wd), steel)
	var rungs: int = int(h / 0.35)
	for i in rungs:
		_box("Rung", Vector4(0.0, 0.3 + float(i) * 0.35, z, 0.0), Vector4(0.64, 0.04, 0.04, wd), steel)
	# At the foot: a slab to stand on, and Wren's notice board on its post beside it.
	_box("LadderSlab", Vector4(0.0, 0.04, z + 0.7, 0.0), Vector4(1.8, 0.08, 1.6, wd), Color(0.42, 0.41, 0.38))
	_box("BoardPost", Vector4(1.35, 0.75, z + 1.05, 0.0), Vector4(0.1, 1.5, 0.1, 0.3), timber_dark)
	_box("Board", Vector4(1.35, 1.35, z + 1.0, 0.0), Vector4(0.9, 0.6, 0.05, 0.6), timber)
	_box("BoardFace", Vector4(1.35, 1.35, z + 1.03, 0.0), Vector4(0.78, 0.48, 0.02, 0.5), Color(0.86, 0.82, 0.70))
	_box("BoardRoof", Vector4(1.35, 1.7, z + 1.0, 0.0), Vector4(1.04, 0.05, 0.22, 0.7), roof_colour)
	# A stand-off to the catwalk at the top, and a cage hoop or two.
	_box("LadderTop", Vector4(0.0, h - 0.05, (z + half + 0.6) * 0.5, 0.0), Vector4(0.8, 0.08, z - half, wd), timber)
	for y in [h - 2.6, h - 1.2]:
		_box("Hoop", Vector4(0.0, y, z + 0.38, 0.0), Vector4(0.86, 0.05, 0.05, wd), steel)


# --- The cab -----------------------------------------------------------------------------------

func _build_cab(h: float, half: float, wd: float) -> void:
	var t: float = 0.12
	var ch: float = cab_height
	var wh: float = wd * 0.5
	_box("CabFloor", Vector4(0.0, h - 0.08, 0.0, 0.0), Vector4(cab_size, 0.16, cab_size, wd), timber_dark)
	# The four ordinary walls: a solid panel to the sill, a band above the lintel, posts at
	# the corners and two mullions - three panes a side.
	for face in 4:
		var axis: Vector4 = [Vector4(0, 0, -1, 0), Vector4(1, 0, 0, 0), Vector4(0, 0, 1, 0), Vector4(-1, 0, 0, 0)][face]
		var along: Vector4 = Vector4(-axis.z, 0.0, axis.x, 0.0)
		var at: Vector4 = axis * (half - t * 0.5)
		var long_size: Vector4 = _orient(along, cab_size, t, wd)
		if face == 2:
			# The south face has the doorway, between the middle mullions, where the ladder
			# comes up: two short sill panels either side and no door. A door leaf folded back
			# against the wall covered a pane from outside, and every long-lens view out of
			# it was a close-up of planks.
			var side_len: float = half - half / 3.0
			for sx in [-1.0, 1.0]:
				_box("Sill", at + along * (sx * (half - side_len * 0.5)) + Vector4(0, h + sill * 0.5, 0, 0),
					_with_y(_orient(along, side_len, t, wd), sill), timber)
				_box("SillShelf", at - axis * 0.16 + along * (sx * (half - side_len * 0.5)) + Vector4(0, h + sill + 0.02, 0, 0),
					_with_y(_orient(along, side_len - 0.15, 0.32, wd), 0.04), timber_dark)
		else:
			_box("Sill", at + Vector4(0, h + sill * 0.5, 0, 0), _with_y(long_size, sill), timber)
			_box("SillShelf", at - axis * 0.16 + Vector4(0, h + sill + 0.02, 0, 0), _with_y(_orient(along, cab_size - 0.3, 0.32, wd), 0.04), timber_dark)
		_box("Header", at + Vector4(0, h + (lintel + ch) * 0.5, 0, 0), _with_y(long_size, ch - lintel), timber)
		for k in [-1.0, -1.0 / 3.0, 1.0 / 3.0]:
			var post_at: Vector4 = at + along * (k * half) + Vector4(0, h + (sill + lintel) * 0.5, 0, 0)
			var post_size: Vector4 = _orient(along, 0.1 if absf(k) < 0.9 else 0.16, t, wd)
			_box("Mullion" if absf(k) < 0.9 else "Corner", post_at, _with_y(post_size, lintel - sill), timber_dark)
	# The two W walls, thin in W, just inside both ends: the whole footprint, full height - and
	# a window in each, a frame round an opening, so a turned slice can look out along W.
	for sw in [-1.0, 1.0]:
		var ww: float = sw * (wh - t * 0.5)
		_box("WSill", Vector4(0, h + sill * 0.5, 0, ww), Vector4(cab_size, sill, cab_size, t), timber)
		_box("WHeader", Vector4(0, h + (lintel + ch) * 0.5, 0, ww), Vector4(cab_size, ch - lintel, cab_size, t), timber)
		for side in [-1.0, 1.0]:
			_box("WFrame", Vector4(side * (half - 0.08), h + (sill + lintel) * 0.5, 0, ww), Vector4(0.16, lintel - sill, cab_size, t), timber_dark)
			_box("WFrame", Vector4(0, h + (sill + lintel) * 0.5, side * (half - 0.08), ww), Vector4(cab_size, lintel - sill, 0.16, t), timber_dark)
	# The roof: a low hip, an overhang the windows shelter under, and a lightning rod.
	_box("Roof", Vector4(0, h + ch + 0.08, 0, 0), Vector4(cab_size + 1.0, 0.16, cab_size + 1.0, wd + 0.6), roof_colour)
	_box("RoofCap", Vector4(0, h + ch + 0.32, 0, 0), Vector4(cab_size * 0.62, 0.32, cab_size * 0.62, wd * 0.62), roof_colour)
	_box("Rod", Vector4(0, h + ch + 1.0, 0, 0), Vector4(0.04, 1.4, 0.04, 0.04 + wd * 0.0), steel)
	# Inside: dark, as a hide is, with the lookout's furniture - the fire finder on its stand
	# in the middle, a stool on glass feet (the lightning stool) and a film box.
	_box("Ceiling", Vector4(0, h + ch - 0.04, 0, 0), Vector4(cab_size - 0.2, 0.06, cab_size - 0.2, wd - 0.3), inside)
	_box("FinderStand", Vector4(0, h + 0.5, 0.35, 0), Vector4(0.18, 1.0, 0.18, 0.18), timber_dark)
	_box("FinderTop", Vector4(0, h + 1.02, 0.35, 0), Vector4(0.7, 0.05, 0.7, 0.7), Color(0.52, 0.47, 0.36))
	_box("FinderSight", Vector4(0.0, h + 1.14, 0.35, 0), Vector4(0.06, 0.2, 0.5, 0.06), Color(0.62, 0.58, 0.40))
	_box("Stool", Vector4(-0.95, h + 0.42, 0.9, 0), Vector4(0.42, 0.06, 0.42, 0.42), timber)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_box("StoolLeg", Vector4(-0.95 + sx * 0.15, h + 0.2, 0.9 + sz * 0.15, 0), Vector4(0.05, 0.4, 0.05, 0.05), timber_dark)
			_box("GlassFoot", Vector4(-0.95 + sx * 0.15, h + 0.03, 0.9 + sz * 0.15, 0), Vector4(0.09, 0.06, 0.09, 0.09), Color(0.55, 0.70, 0.66))
	_box("FilmBox", Vector4(1.25, h + sill + 0.12, 1.55, 0), Vector4(0.42, 0.2, 0.3, 0.3), Color(0.55, 0.16, 0.10))


func _build_catwalk(h: float, half: float, wd: float) -> void:
	var out: float = half + 0.9
	_box("Catwalk", Vector4(0, h - 0.12, 0, 0), Vector4(out * 2.0, 0.1, out * 2.0, wd), timber_dark)
	for face in 4:
		var c0: Vector2 = _corner(face, out - 0.05)
		var c1: Vector2 = _corner(face + 1, out - 0.05)
		# The south rail has a gap where the ladder comes over the top.
		var runs: Array = [[c0, c1]]
		if face == 2:
			runs = [[c0, Vector2(0.5, c0.y)], [Vector2(-0.5, c1.y), c1]]
			for gx in [-0.5, 0.5]:
				_box("RailPost", Vector4(gx, h + 0.5, c0.y, 0), Vector4(0.06, 1.0, 0.06, wd), steel)
		for run in runs:
			var a: Vector2 = run[0]
			var b: Vector2 = run[1]
			_strut("Rail", Vector4(a.x, h + 1.0, a.y, 0), Vector4(b.x, h + 1.0, b.y, 0), 0.06, wd, steel)
			_strut("Rail", Vector4(a.x, h + 0.5, a.y, 0), Vector4(b.x, h + 0.5, b.y, 0), 0.04, wd, steel)
		_box("RailPost", Vector4(c0.x, h + 0.5, c0.y, 0), Vector4(0.06, 1.0, 0.06, wd), steel)


func _build_ana_post(h: float, half: float) -> void:
	# Thin in W - 0.3 m - so it is there only near its own w, from the ground to a little
	# above the sill, with a weathered cross-bar to perch on. Grey-silver, like old wood.
	var at := Vector4(ana_post_side, 0.0, -half - ana_post_out, ana_post_w)
	var post := Color(0.48, 0.47, 0.44)
	_box("AnaPost", at + Vector4(0, (h + 0.95) * 0.5 - 0.3, 0, 0), Vector4(0.16, h + 1.55, 0.16, 0.30), post)
	_box("AnaPerch", at + Vector4(0, h + 0.98, 0, 0), Vector4(0.62, 0.06, 0.08, 0.30), post)


## Boxes the player walks round: the four feet and the ladder's foot. The physics is boxes
## only (hub demo lessons), so a splayed leg gets an upright box where it meets the ground.
func _build_colliders(_h: float, half: float, wd: float) -> void:
	var body := StaticBody4D.new()
	body.name = "Colliders"
	add_child(body)
	var foot: float = half + splay
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var shape := CollisionShape4D.new()
			var box := BoxShape4D.new()
			box.size = Vector4(0.9, 2.4, 0.9, wd)
			shape.shape = box
			shape.position = Vector4(sx * (foot - 0.15), 1.2, sz * (foot - 0.15), 0.0)
			body.add_child(shape)


# --- Helpers --------------------------------------------------------------------------------

## A box [param size] long along [param along] (x or z), [param thick] across, [param wd] in W.
func _orient(along: Vector4, length: float, thick: float, wd: float) -> Vector4:
	if absf(along.x) > 0.5:
		return Vector4(length, 1.0, thick, wd)
	return Vector4(thick, 1.0, length, wd)


func _with_y(size: Vector4, y: float) -> Vector4:
	return Vector4(size.x, y, size.z, size.w)


func _mesh(size: Vector4) -> BoxTetraMesh4D:
	var key: String = "%.3f,%.3f,%.3f,%.3f" % [size.x, size.y, size.z, size.w]
	if not _meshes.has(key):
		var mesh := BoxTetraMesh4D.new()
		mesh.size = size
		_meshes[key] = mesh
	return _meshes[key]


func _material(colour: Color) -> TetraMaterial4D:
	var key: String = colour.to_html()
	if not _materials.has(key):
		var m := TetraMaterial4D.new()
		m.albedo_color = colour
		_materials[key] = m
	return _materials[key]


func _box(part: String, at: Vector4, size: Vector4, colour: Color, basis: Projection = Projection.IDENTITY) -> MeshInstance4D:
	if merge_parts:
		return _batch(part, at, size, colour, basis)
	var node := MeshInstance4D.new()
	node.name = part
	node.mesh = _mesh(size)
	node.material_override = _material(colour)
	add_child(node, true)
	node.position = at
	if basis != Projection.IDENTITY:
		node.basis = basis
	return node


## A bar of square section [param thick] from [param a] to [param b], [param wd] deep in W.
func _strut(part: String, a: Vector4, b: Vector4, thick: float, wd: float, colour: Color) -> MeshInstance4D:
	var d: Vector4 = b - a
	var length: float = d.length()
	if length < 0.001:
		return null
	var y: Vector4 = d / length
	# The other three axes by Gram-Schmidt from x, z and w, so the bar keeps its W depth.
	var x: Vector4 = Vector4(1, 0, 0, 0) - y * y.x
	if x.length() < 0.2:
		x = Vector4(0, 0, 1, 0) - y * y.z
	x = x.normalized()
	var z: Vector4 = Vector4(0, 0, 1, 0) - y * y.z - x * x.z
	if z.length() < 0.2:
		z = Vector4(1, 0, 0, 0) - y * y.x - x * x.x
	z = z.normalized()
	var w: Vector4 = Vector4(0, 0, 0, 1) - y * y.w - x * x.w - z * z.w
	w = w.normalized()
	return _box(part, (a + b) * 0.5, Vector4(thick, length, thick, wd), colour, Projection(x, y, z, w))

## Into this colour's merged mesh, or a node of its own when merging is off.
func _batch(_part: String, at: Vector4, size: Vector4, colour: Color, basis: Projection) -> MeshInstance4D:
	var key: String = colour.to_html()
	if not _batches.has(key):
		_batches[key] = [ArrayTetraMesh4D.new(), colour]
	var skey: String = "%.3f,%.3f,%.3f,%.3f" % [size.x, size.y, size.z, size.w]
	if not _arrays.has(skey):
		var box := BoxTetraMesh4D.new()
		box.size = size
		_arrays[skey] = box.to_array_tetra_mesh()
	(_batches[key][0] as ArrayTetraMesh4D).merge_with(_arrays[skey], at, basis)
	return null


## The merged meshes, one node each.
func _flush() -> void:
	for key in _batches:
		var node := MeshInstance4D.new()
		node.name = "Parts_" + String(key)
		node.mesh = _batches[key][0]
		var m := TetraMaterial4D.new()
		m.albedo_color = _batches[key][1]
		node.material_override = m
		add_child(node, true)
	_batches.clear()
