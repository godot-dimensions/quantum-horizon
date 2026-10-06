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
## TWO DESIGNS ([member design]). The CAB is the first one: a closed hide you stand in at a
## window. The BALCONY (Ramon, 2 Oct, from a reference photo of a lookout with a wide deck)
## is an open deck you walk round in first person with the camera raised, a very small cabin
## with a hip roof in the middle, and timber railings - so looking out, nothing stands between
## you and the farm but a rail below your eye. Same frame, same ladder. The deck is a real
## floor: colliders for the boards, the railings (and both W ends, so stepping along W cannot
## drop you off) and the cabin.
##
## Everything is boxes, as the pen's own buildings are, sharing one mesh per size.
##
## ONE MESH PER COLOUR, NOT ONE NODE PER BOX. Every MeshInstance4D costs something each
## frame whether or not it is on screen, and this is a few hundred boxes that never move.
## So with [member merge_parts] on (the default) the boxes of each colour are merged into a
## single ArrayTetraMesh4D (TetraMesh4D.to_array_tetra_mesh, ArrayTetraMesh4D.merge_with)
## and drawn by one node. Off, every box is its own named node, for picking parts apart.

enum Design { CAB, BALCONY }

## Which tower: the closed cab you stand in, or the open balcony you walk round.
@export var design: Design = Design.BALCONY:
	set(v):
		design = v
		if is_node_ready():
			rebuild()

@export_group("Size")
## Height of the cab floor above the tower's feet.
@export_range(4.0, 30.0, 0.5, "suffix:m") var deck_height: float = 10.0
## The cab's footprint, x and z, and its depth along W.
@export_range(2.0, 8.0, 0.1, "suffix:m") var cab_size: float = 4.0
@export_range(2.0, 10.0, 0.1, "suffix:m") var cab_w_depth: float = 6.4
@export_range(2.0, 4.0, 0.05, "suffix:m") var cab_height: float = 2.6
## The balcony's deck, edge to edge, and its little cabin.
@export_range(4.0, 12.0, 0.1, "suffix:m") var deck_size: float = 7.2
@export_range(1.2, 4.0, 0.1, "suffix:m") var cabin_size: float = 2.4
@export_range(1.6, 3.5, 0.05, "suffix:m") var cabin_height: float = 2.3
## Rail height above the deck: under the eye, so looking out you look over it.
@export_range(0.6, 1.4, 0.05, "suffix:m") var rail_height: float = 1.0
## Sill and lintel of the windows, from the cab floor. A hide's slot sits about 1 m up.
@export_range(0.3, 1.5, 0.05, "suffix:m") var sill: float = 1.0
@export_range(1.6, 3.0, 0.05, "suffix:m") var lintel: float = 2.2
## How far the legs splay out at the foot, past the cab's corners.
@export_range(0.0, 4.0, 0.1, "suffix:m") var splay: float = 1.4

@export_group("The ana post")
## Off: the owl sits in a dead tree now (lookout_tree_4d.gd, built by lookout_4d.gd with its
## twig at [method ana_perch]). The post is kept as the plain version.
@export var ana_post: bool = false
## Its W, and how far out from the north side it stands (Ramon, 2 Oct: "a bit further in the
## back" - it was 3.2 m out of the window).
@export_range(-4.0, 4.0, 0.05, "suffix:m") var ana_post_w: float = 1.5
@export_range(1.0, 12.0, 0.1, "suffix:m") var ana_post_out: float = 5.0
@export_range(-3.0, 3.0, 0.05, "suffix:m") var ana_post_side: float = 0.7

@export_group("Look")
@export var steel: Color = Color(0.20, 0.22, 0.21)
@export var timber: Color = Color(0.36, 0.27, 0.19)
@export var timber_dark: Color = Color(0.22, 0.16, 0.12)
@export var roof_colour: Color = Color(0.16, 0.18, 0.17)
## The deck's floor (and the cabin's): darker than the steel.
@export var floor_colour: Color = Color(0.10, 0.11, 0.11)
@export var inside: Color = Color(0.10, 0.08, 0.07)
@export var merge_parts: bool = true

@export_group("Fence frame")
## THE FRAME FROM THE FENCE TECH (6 Oct 2026, PenLayout/PLAN_A.md phase 7; Ramon: "it's so flat ...
## use the fence tech ... the base and the hut above"). Off: the tower as it was, legs and braces
## of solid struts each as deep in W as the cab (turned into W they read as plates). On:
##   the base   one FenceGenerator4D box as wide as the legs' spread and as deep in W as the cab:
##              posts at its corners and every `fence_spacing` along its edges, W edges too, leaning
##              in to the deck (top_footprint_ratio), tied by `fence_rings` rings of girts. So the
##              legs stand at whole W places and step out of view between them: a 4D tower.
##   the rail   the deck's railing is a fence box round the deck, its W ends included
##   the hut    the cabin's walls are a fence box of slats, its dark panes left behind them
## The pads, deck, ladder, roof, colliders and everything the Lookout calls stay as they are, so the
## switch changes what you see and nothing else.
##
## THE TOWER PASS (6 Oct, Ramon: "an optimization pass on the tower using the new fence tech. use it
## where you can"). Live in the Lookout unit since then, and three changes from the first build:
##   the base splays in W   the generator leans a box in all three of its ground directions at once,
##                          so a base as deep in W as the deck at its foot was barely half as deep
##                          at the top: a slice near the deck's W end showed the deck floating with
##                          nothing under it. Now its foot is as much deeper in W as it is wider in
##                          x and z, and its top holds the deck's whole W depth: legs that splay
##                          in four directions, like the tower's own shape but in 4D.
##   the rail is 2.4 apart  a 1.2 grid put a post in the middle of the ladder's opening and cost 12,900
##                          tetrahedra; at 2.4 the posts stand either side of the ladder.
##   the hut's slats 0.75   14,400 tetrahedra at 0.6, most of them in W layers no slice shows at once.
## `PenLayout/scripts/_study_tower_cells_runner.gd` counts the tetrahedra part by part.
@export var fence_frame: bool = false:
	set(v):
		fence_frame = v
		if is_node_ready():
			rebuild()
## The spacing decides where the grid's layers fall in W, and on a layer its ribs read as solid
## walls; 2.2 keeps every layer off the farm's slice (at +-1.07 and +-3.2 for a 6.4 m cab), so from
## there the base is an open lattice and the solid layers are what you pass through in W.
@export_range(0.5, 10.0, 0.1, "suffix:m") var fence_spacing: float = 2.2:
	set(v):
		fence_spacing = v
		if is_node_ready() and fence_frame:
			rebuild()
@export_range(0, 12) var fence_rings: int = 4:
	set(v):
		fence_rings = v
		if is_node_ready() and fence_frame:
			rebuild()
@export_range(0.05, 0.6, 0.01, "suffix:m") var fence_post: float = 0.24:
	set(v):
		fence_post = v
		if is_node_ready() and fence_frame:
			rebuild()

var _meshes: Dictionary = {}
var _batches: Dictionary = {}
var _arrays: Dictionary = {}
var _materials: Dictionary = {}


func _ready() -> void:
	add_to_group(&"slice_dial_outline")
	rebuild()


## On the pen's dial (pen_slice_plane_4d.gd, Ramon, 3 Oct: "I want the marsh, the watchtower,
## the owl, the cave, all to show up on the gizmo dynamically"): the deck's square, where it is now - asked
## for every frame, so moving it moves it on the dial too.
func dial_outline() -> Dictionary:
	var h: float = top_half()
	var points := PackedVector4Array()
	for c in [Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)]:
		points.append(global_position + global_basis * Vector4(c.x, 0.0, c.y, 0.0))
	return {"points": points, "label": "Lookout", "colour": Color(0.95, 0.70, 0.42, 0.9), "depth": cab_w_depth * 0.5}


## Half the width of what you stand on up there: the deck, or the cab's catwalk.
func top_half() -> float:
	return deck_size * 0.5 if design == Design.BALCONY else cab_size * 0.5


## The ladder's line, in z from the middle: outside the deck's edge, or the cab's legs.
func ladder_z() -> float:
	if design == Design.BALCONY:
		return deck_size * 0.5 + 0.35
	return cab_size * 0.5 + splay * 0.8 + 0.35


## The point a climber stands at, at the ladder's foot, in global space.
func ladder_foot() -> Vector4:
	return global_position + global_basis * Vector4(0.0, 0.0, ladder_z() + 0.55, 0.0)


## Where you step onto the deck at the top of the ladder, in global space (the balcony).
func ladder_top() -> Vector4:
	return global_position + global_basis * Vector4(0.0, deck_height, deck_size * 0.5 - 0.65, 0.0)


func is_balcony() -> bool:
	return design == Design.BALCONY


## Whether [param p] (global) is up on the deck.
func on_deck(p: Vector4) -> bool:
	if design != Design.BALCONY:
		return false
	var local: Vector4 = global_basis.inverse() * (p - global_position)
	var half: float = deck_size * 0.5
	return absf(local.x) < half and absf(local.z) < half and local.y > deck_height - 0.6 and local.y < deck_height + 3.0 \
		and absf(local.w) < cab_w_depth * 0.5


## Where the eye is in the cab, standing at the north window, in global space.
func cab_eye() -> Vector4:
	return global_position + global_basis * Vector4(0.0, deck_height + 1.55, -cab_size * 0.18, 0.0)


## The cab's middle, at the floor, in global space.
func cab_floor() -> Vector4:
	return global_position + global_basis * Vector4(0.0, deck_height, 0.0, 0.0)


## The top of the ana post - where its perch is - in global space.
func ana_perch() -> Vector4:
	return global_position + global_basis * Vector4(ana_post_side, deck_height + 1.05, -top_half() - ana_post_out, ana_post_w)


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
	if fence_frame:
		_build_pads(h, half, wd)
		_fence_base(h, half, wd)
	else:
		_build_legs(h, half, wd)
	if design == Design.BALCONY:
		_build_balcony(h, half, wd)
	else:
		_build_cab(h, half, wd)
		_build_catwalk(h, half, wd)
	_build_ladder(h, half, wd)
	if ana_post:
		_build_ana_post(h, top_half())
	_flush()
	_build_colliders(h, half, wd)
	if design == Design.BALCONY:
		_build_deck_colliders(h, wd)


# --- The frame -------------------------------------------------------------------------------

func _build_legs(h: float, half: float, wd: float) -> void:
	var foot: float = half + splay
	var top: float = half - 0.12
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var a := Vector4(sx * foot, -0.6, sz * foot, 0.0)
			var b := Vector4(sx * top, h, sz * top, 0.0)
			_strut("Leg", a, b, 0.26, wd, steel)
			# One concrete block under each leg, standing well proud of the ground (Ramon,
			# 2 Oct: "a bit higher ... stronger base", one block per corner).
			_box("Pad", Vector4(sx * foot, 0.1, sz * foot, 0.0), Vector4(1.1, 1.0, 1.1, wd), Color(0.44, 0.43, 0.40))
	# X braces on the four faces, in three tiers, and a ring at the top of each - except the
	# bottom tier's X, which ran down into the concrete blocks (Ramon, 2 Oct: "remove the cross
	# bars from the bottom row"); its ring stays, tying the legs together.
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
			if t > 0:
				_strut("Brace", Vector4(ca.x, y0, ca.y, 0.0), Vector4(cd.x, y1, cd.y, 0.0), 0.09, wd, steel)
				_strut("Brace", Vector4(cb.x, y0, cb.y, 0.0), Vector4(cc.x, y1, cc.y, 0.0), 0.09, wd, steel)
			_strut("Girt", Vector4(cc.x, y1, cc.y, 0.0), Vector4(cd.x, y1, cd.y, 0.0), 0.12, wd, steel)


## The concrete blocks under the legs alone, for the fence frame (whose posts are the legs): as long
## in W as the base's splayed foot.
func _build_pads(_h: float, half: float, wd: float) -> void:
	var foot: float = half + splay
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_box("Pad", Vector4(sx * foot, 0.1, sz * foot, 0.0), Vector4(1.1, 1.0, 1.1, _pad_w(half, wd)), Color(0.44, 0.43, 0.40))


## How deep in W the pads (and their colliders) are: the cab's depth on the old frame, the fence
## base's splayed foot and a margin on the new one.
func _pad_w(half: float, wd: float) -> float:
	return _base_foot_w(half, wd) + 1.1 if fence_frame else wd


## The fence base's depth in W at its foot: the deck's depth, splayed as much as the legs are in x
## and z, so that after the generator's lean its top is the deck's whole depth (see fence_frame).
func _base_foot_w(half: float, wd: float) -> float:
	return wd * (half + splay) / (half - 0.12)


## The base as one fence box (see fence_frame): from the pads' tops to the deck, leaning in from
## the legs' spread at the foot to just inside the deck's corners at the top.
func _fence_base(h: float, half: float, wd: float) -> void:
	var foot: float = half + splay
	var top: float = half - 0.12
	_fence("FenceBase", Vector3(foot * 2.0, foot * 2.0, _base_foot_w(half, wd)), h - 0.5, fence_spacing, fence_rings, 0.05,
		fence_post, top / foot, Vector4(0.0, 0.5, 0.0, 0.0), steel)


## A FenceGenerator4D box: [param box] is its size in x, z and W; [param height] its posts'; built
## at once, in one colour.
func _fence(part: String, box: Vector3, height: float, spacing: float, rings: int, coverage: float,
		post: float, ratio: float, at: Vector4, colour: Color) -> FenceGenerator4D:
	var f := FenceGenerator4D.new()
	f.name = part
	f.update_automatically = false
	f.input_shape_type = FenceGenerator4D.INPUT_SHAPE_BOX
	f.box_size = box
	f.output_mesh_type = FenceGenerator4D.OUTPUT_MESH_TETRA
	f.desired_spacing_meters = spacing
	f.post_height_meters = height
	f.post_thickness_meters = post
	f.top_footprint_ratio = ratio
	f.beam_count = rings
	f.beam_coverage = coverage
	f.beam_max_height_ratio = 0.98
	var m: TetraMaterial4D = _material(colour)
	f.post_material = m
	f.rib_material = m
	f.beam_material = m
	f.position = at
	add_child(f, true)
	f.update_fence_mesh_now()
	return f


## Corner [param i] of the square of half-size [param r], going round.
func _corner(i: int, r: float) -> Vector2:
	var corners: Array = [Vector2(-r, -r), Vector2(r, -r), Vector2(r, r), Vector2(-r, r)]
	return corners[posmod(i, 4)]


func _build_ladder(h: float, half: float, wd: float) -> void:
	# On the south face, the pen's side. Straight up from the ground to a hatch in the catwalk,
	# well clear of the splayed legs.
	var z: float = ladder_z()
	# With the fence frame, a ladder as deep in W as you can climb it from (the Lookout's
	# ladder_reach_w, 1.2 either side): as deep as the cab, its rails read as two 6.4 m plates the
	# moment the slice turns into W, the flatness Ramon saw (6 Oct).
	var lwd: float = 2.4 if fence_frame else wd
	for side in [-0.32, 0.32]:
		_box("LadderRail", Vector4(side, h * 0.5 - 0.3, z, 0.0), Vector4(0.06, h + 0.6, 0.06, lwd), steel)
	var rungs: int = int(h / 0.35)
	for i in rungs:
		_box("Rung", Vector4(0.0, 0.3 + float(i) * 0.35, z, 0.0), Vector4(0.64, 0.04, 0.04, lwd), steel)
	# At the foot: a slab to stand on. (Wren's notice board stood beside it; removed, Ramon, 2 Oct.)
	_box("LadderSlab", Vector4(0.0, 0.04, z + 0.7, 0.0), Vector4(1.8, 0.08, 1.6, wd), Color(0.42, 0.41, 0.38))
	# A stand-off to the catwalk at the top. (Two "cage hoop" bars stood behind the ladder's top
	# with nothing joining them to it - sticks in the air, like the knee braces; gone, 2 Oct.)
	if design == Design.CAB:
		_box("LadderTop", Vector4(0.0, h - 0.05, (z + half + 0.6) * 0.5, 0.0), Vector4(0.8, 0.08, z - half, wd), timber)


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
			box.size = Vector4(1.1, 2.4, 1.1, _pad_w(half, wd))
			shape.shape = box
			# Round the block, which is the widest thing at the height you walk into.
			shape.position = Vector4(sx * foot, 1.2, sz * foot, 0.0)
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
	return _box(part, (a + b) * 0.5, Vector4(thick, length, thick, wd), colour, _frame_along(y))

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

# --- The balcony -------------------------------------------------------------------------------

## The deck on the frame's top, its railings, the cabin and its hip roof.
func _build_balcony(h: float, _frame_half: float, wd: float) -> void:
	var half: float = deck_size * 0.5
	# ALL ONE DARK METAL (Ramon, 2 Oct): the deck's rails, edge, joists, roof and furniture are
	# the frame's steel; the floor darker still; only the white cabin keeps its own colours.
	var deck := floor_colour
	var rail := steel
	# Boards, and the joists under them. (There were knee braces too, twelve struts from the
	# frame out to the deck's edge; they met no member of the frame and read as sticks hanging
	# in the air, so they went - Ramon, 2 Oct.)
	_box("Deck", Vector4(0.0, h - 0.06, 0.0, 0.0), Vector4(deck_size, 0.12, deck_size, wd), deck)
	_box("Fascia", Vector4(0.0, h - 0.2, 0.0, 0.0), Vector4(deck_size - 0.1, 0.16, deck_size - 0.1, wd - 0.1), steel)
	for k in 5:
		var x: float = lerpf(-half + 0.3, half - 0.3, float(k) / 4.0)
		_box("Joist", Vector4(x, h - 0.36, 0.0, 0.0), Vector4(0.14, 0.2, deck_size - 0.2, wd), steel)
	# Railings: posts, a top rail and a mid rail on the four edges, a gap at the ladder. (With the
	# fence frame, one fence box round the deck instead, its W ends included. It has no gap, but at
	# 2.4 its posts stand either side of the ladder, three spans a side and three layers in W, none
	# on the farm's slice; at 1.2 there was a post in the middle of the ladder's opening.)
	var posts: int = 6 if not fence_frame else -1
	if fence_frame:
		_fence("FenceRail", Vector3(deck_size - 0.12, deck_size - 0.12, wd - 0.12), rail_height, 2.4, 2, 0.12,
			0.08, 1.0, Vector4(0.0, h, 0.0, 0.0), rail)
	for face in (4 if not fence_frame else 0):
		var a: Vector2 = _corner(face, half - 0.06)
		var b: Vector2 = _corner(face + 1, half - 0.06)
		for k in posts + 1:
			var p: Vector2 = a.lerp(b, float(k) / float(posts))
			if face == 2 and absf(p.x) < 0.55:
				continue
			_box("Post", Vector4(p.x, h + rail_height * 0.5, p.y, 0.0), Vector4(0.09, rail_height, 0.09, wd), rail)
		var runs: Array = [[a, b]]
		if face == 2:
			runs = [[a, Vector2(0.55, a.y)], [Vector2(-0.55, b.y), b]]
			for gx in [-0.55, 0.55]:
				_box("GatePost", Vector4(gx, h + rail_height * 0.55, a.y, 0.0), Vector4(0.11, rail_height * 1.1, 0.11, wd), rail)
		for run in runs:
			var r0: Vector2 = run[0]
			var r1: Vector2 = run[1]
			_strut("Rail", Vector4(r0.x, h + rail_height, r0.y, 0.0), Vector4(r1.x, h + rail_height, r1.y, 0.0), 0.08, wd, rail)
			_strut("MidRail", Vector4(r0.x, h + rail_height * 0.5, r0.y, 0.0), Vector4(r1.x, h + rail_height * 0.5, r1.y, 0.0), 0.05, wd, rail)
	# The railing's W ends: a low panel, thin in W, over the whole deck - the eight-walls rule
	# for a railing, so the deck is fenced along W too.
	for sw in ([-1.0, 1.0] if not fence_frame else []):
		_box("WRail", Vector4(0.0, h + rail_height * 0.5, 0.0, sw * (wd * 0.5 - 0.06)), Vector4(deck_size, rail_height, deck_size, 0.12), rail)
	# The cabin: small, windows all round, dark inside - looked into, not walked into.
	var ch: float = cabin_height
	var cs: float = cabin_size
	var cw: float = cs * 0.5
	var wall := Color(0.82, 0.80, 0.74)
	var frame_c := Color(0.92, 0.91, 0.88)
	_box("CabinFloor", Vector4(0.0, h + 0.02, 0.0, 0.0), Vector4(cs, 0.04, cs, wd), floor_colour)
	if fence_frame:
		# Slatted walls, the same white, as deep in W as the cabin, the dark panes left behind them.
		# Slats 0.8 apart (spacing 0.75: three spans a side, nine in W, the nearest W layers 0.36 off
		# the farm's slice), four girts.
		_fence("FenceHut", Vector3(cs, cs, wd), ch, 0.75, 4, 0.45, 0.07, 1.0, Vector4(0.0, h, 0.0, 0.0), wall)
		for face in 4:
			var ax: Vector4 = [Vector4(0, 0, -1, 0), Vector4(1, 0, 0, 0), Vector4(0, 0, 1, 0), Vector4(-1, 0, 0, 0)][face]
			var al: Vector4 = Vector4(-ax.z, 0.0, ax.x, 0.0)
			_box("Pane", ax * (cw - 0.12) + Vector4(0, h + 1.45, 0, 0), _with_y(_orient(al, cs - 0.2, 0.03, wd - 0.3), 1.1), Color(0.10, 0.12, 0.14))
	for face in (4 if not fence_frame else 0):
		var axis: Vector4 = [Vector4(0, 0, -1, 0), Vector4(1, 0, 0, 0), Vector4(0, 0, 1, 0), Vector4(-1, 0, 0, 0)][face]
		var along: Vector4 = Vector4(-axis.z, 0.0, axis.x, 0.0)
		var at: Vector4 = axis * (cw - 0.05)
		_box("CabinSill", at + Vector4(0, h + 0.45, 0, 0), _with_y(_orient(along, cs, 0.1, wd), 0.9), wall)
		_box("CabinHead", at + Vector4(0, h + (ch + 2.0) * 0.5, 0, 0), _with_y(_orient(along, cs, 0.1, wd), ch - 2.0), wall)
		# Window frames over a dark pane: from outside it reads as glass with a room behind.
		_box("Pane", at - axis * 0.02 + Vector4(0, h + 1.45, 0, 0), _with_y(_orient(along, cs - 0.1, 0.03, wd - 0.2), 1.1), Color(0.10, 0.12, 0.14))
		for k in [-1.0, -0.33, 0.33, 1.0]:
			_box("CabinMullion", at + along * (k * (cw - 0.04)) + Vector4(0, h + 1.45, 0, 0), _with_y(_orient(along, 0.07, 0.12, wd), 1.1), frame_c)
		_box("CabinTransom", at + Vector4(0, h + 1.45, 0, 0), _with_y(_orient(along, cs, 0.12, wd), 0.05), frame_c)
	for sw in ([-1.0, 1.0] if not fence_frame else []):
		_box("CabinW", Vector4(0.0, h + ch * 0.5, 0.0, sw * (wd * 0.5 - 0.1)), Vector4(cs, ch, cs, 0.1), wall)
	# The hip roof: four boards falling from a ridge cap to an overhang, and a lightning rod.
	var over: float = cw + 0.45
	var rise: float = 0.75
	var slope: float = atan2(rise, over)
	var board: float = sqrt(over * over + rise * rise)
	var roof := steel
	for face in 4:
		var turn: float = float(face) * PI * 0.5
		var plank := Basis4D.from_zx(turn) * Basis4D.from_yz(slope)
		var centre: Vector4 = Basis4D.from_zx(turn) * Vector4(0.0, h + ch + rise * 0.5, over * 0.5, 0.0)
		_box("Roof", centre, Vector4(over * 2.0, 0.06, board, wd + 0.5), roof, plank)
	_box("RoofCap", Vector4(0.0, h + ch + rise, 0.0, 0.0), Vector4(0.3, 0.12, 0.3, wd * 0.4), steel)
	_box("Rod", Vector4(0.0, h + ch + rise + 0.7, 0.0, 0.0), Vector4(0.04, 1.3, 0.04, 0.04), steel)
	# Inside, seen through the panes: the fire finder on its stand.
	_box("FinderStand", Vector4(0, h + 0.5, 0, 0), Vector4(0.16, 1.0, 0.16, 0.16), steel)
	_box("FinderTop", Vector4(0, h + 1.02, 0, 0), Vector4(0.6, 0.05, 0.6, 0.6), steel)
	# Wren's film box and a bench on the deck, against the cabin's south wall.
	_box("Bench", Vector4(-0.7, h + 0.42, cw + 0.35, 0.0), Vector4(1.1, 0.06, 0.38, 0.5), steel)
	for bx in [-1.15, -0.25]:
		_box("BenchLeg", Vector4(bx, h + 0.2, cw + 0.35, 0.0), Vector4(0.06, 0.4, 0.3, 0.3), steel)
	_box("FilmBox", Vector4(0.75, h + 0.15, cw + 0.3, 0.0), Vector4(0.42, 0.3, 0.3, 0.3), Color(0.55, 0.16, 0.10))


## What you walk on and against up there: the boards, the railings (and a bar across the
## ladder's gap, so you cannot step off it - F climbs down), both W ends, and the cabin.
func _build_deck_colliders(h: float, wd: float) -> void:
	var body := StaticBody4D.new()
	body.name = "DeckColliders"
	add_child(body)
	var half: float = deck_size * 0.5
	var shapes: Array = [
		[Vector4(0.0, h - 0.12, 0.0, 0.0), Vector4(deck_size, 0.24, deck_size, wd)],
		[Vector4(0.0, h + 0.6, -half + 0.06, 0.0), Vector4(deck_size, 1.2, 0.14, wd)],
		[Vector4(half - 0.06, h + 0.6, 0.0, 0.0), Vector4(0.14, 1.2, deck_size, wd)],
		[Vector4(-half + 0.06, h + 0.6, 0.0, 0.0), Vector4(0.14, 1.2, deck_size, wd)],
		[Vector4(0.0, h + 0.6, half - 0.06, 0.0), Vector4(deck_size, 1.2, 0.14, wd)],
		[Vector4(0.0, h + 0.6, 0.0, wd * 0.5 - 0.06), Vector4(deck_size, 1.2, deck_size, 0.14)],
		[Vector4(0.0, h + 0.6, 0.0, -wd * 0.5 + 0.06), Vector4(deck_size, 1.2, deck_size, 0.14)],
		[Vector4(0.0, h + cabin_height * 0.5, 0.0, 0.0), Vector4(cabin_size, cabin_height, cabin_size, wd)],
	]
	for sh in shapes:
		var shape := CollisionShape4D.new()
		var box := BoxShape4D.new()
		box.size = sh[1]
		shape.shape = box
		shape.position = sh[0]
		body.add_child(shape)
