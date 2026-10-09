extends RefCounted

## WATER LAB: the herring gull's pieces, lofted in 4D once by the carried loft builder and baked under
## gull/baked/ (Ramon, 9 Oct: "Maybe add a lofting system for it and break it apart a little bit ... so
## that we don't render per frame"). gull_4d.gd hangs them on its joints and only turns the joints.
##
## A HERRING GULL (Larus argentatus; follow_up/water_lab.md): 0.6 m long, 1.4 m across the wings. White
## head, body and tail; a pale silver-grey back and upper wing; black wingtips with white "mirror" spots
## on the outer feathers; a yellow bill with a red spot near the tip of the lower half; pink legs.
##
## THE PIECES, each in its joint's own frame (the gull faces +Z, its right is +X, up +Y):
##   body   the torso, chest to tail root          head   neck, head and bill, from the neck's base
##   tail   a flat fan from its root               arm    shoulder to wrist (the broad inner wing)
##   hand   wrist to tip, swept, pointed, black-tipped               leg    tarsus and foot
## The wings and the leg are the LEFT ones (+X out); the right ones are the same meshes turned by
## from_xw(PI) (x and W both flipped: a rotation, so the faces stay outward; the range's chicken does
## the same).
##
## EVERY SECTION IS A ROUND BALL SHAPED BY A BASIS (as the hammerhead's, shark_4d.gd): the builder's
## own section axes depend on which way a spine runs, an explicit scale per axis does not.
##
## COLOUR: one small 3D texture for the whole bird, looked up by where each point sits on its piece
## (texture x: which part; y: across the wing or up the body; z: along the wing), painted here.
##
## NO class_name (engine_gotchas.md).

const Loft := preload("res://ramon/WaterLab/carried/chickenpen/scripts/loft_builder_4d.gd")
const BAKED := "res://ramon/WaterLab/gull/baked/"
const VERSION := "v3"

## Where the joints are on the body, metres (gull_4d.gd uses the same).
const NECK := Vector4(0.0, 0.05, 0.13, 0.0)
const TAIL := Vector4(0.0, 0.03, -0.17, 0.0)
const SHOULDER := Vector4(0.055, 0.055, 0.06, 0.0)
const HIP := Vector4(0.035, -0.04, -0.02, 0.0)
const ARM := 0.30
const HAND := 0.36

## Texture x for each part.
const PART := {"body": 0.1, "head": 0.25, "bill": 0.35, "tail": 0.45, "arm": 0.6, "hand": 0.75, "leg": 0.9}


static func scale(sx: float, sy: float, sz: float, sw: float) -> Projection:
	return Projection(Vector4(sx, 0, 0, 0), Vector4(0, sy, 0, 0), Vector4(0, 0, sz, 0), Vector4(0, 0, 0, sw))


static func ball(c: Vector4, r: float, b: Projection) -> Dictionary:
	return {"center": c, "radius": r, "v_scale": 1.0, "w_scale": 1.0, "basis": b, "color": Color.WHITE}


static func mesh(name: String) -> ArrayTetraMesh4D:
	var path: String = BAKED + "gull_%s_%s.res" % [name, VERSION]
	if ResourceLoader.exists(path):
		var r: Resource = load(path)
		if r is ArrayTetraMesh4D:
			return r
	var m: ArrayTetraMesh4D = null
	match name:
		"body":
			m = _body()
		"head":
			m = _head()
		"tail":
			m = _tail()
		"arm":
			m = _arm()
		"hand":
			m = _hand()
		"leg":
			m = _leg()
	if m != null:
		m.calculate_boundary_normals(false)
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BAKED))
		ResourceSaver.save(m, path)
	return m


## The torso: a teardrop, fullest at the chest, along -Z from the breast to the tail's root.
static func _body() -> ArrayTetraMesh4D:
	var rows: Array = [[0.17, 0.030, 0.040], [0.12, 0.055, 0.062], [0.06, 0.066, 0.070], [0.0, 0.066, 0.066], [-0.07, 0.056, 0.054], [-0.13, 0.040, 0.036], [-0.17, 0.024, 0.020]]
	var sections: Array = []
	for r in rows:
		var hw: float = r[1]
		sections.append(ball(Vector4(0.0, 0.0, float(r[0]), 0.0), hw, scale(1.0, float(r[2]) / hw, 1.0, 0.9)))
	var m: ArrayTetraMesh4D = Loft.build(sections, 4, 12, true, false, true, 1, false)
	_paint(m, "body", func(p: Vector4) -> Vector3: return Vector3(PART["body"], clampf(0.5 + p.y / 0.13, 0.0, 1.0), clampf(0.5 - p.z / 0.4, 0.0, 1.0)))
	return m


## The neck rising from its base at NECK, the head, and the bill forward of it with the hook at its tip.
static func _head() -> ArrayTetraMesh4D:
	var parts: Array = []
	var neck: Array = []
	for k in 4:
		var u: float = float(k) / 3.0
		var c := Vector4(0.0, u * 0.07, u * 0.07, 0.0)
		var r: float = lerpf(0.042, 0.036, u)
		neck.append(ball(c, r, scale(1.0, 1.05, 1.0, 0.9)))
	# The head: rounder, its crown high.
	for k in 3:
		var u2: float = float(k) / 2.0
		neck.append(ball(Vector4(0.0, 0.085, 0.085 + u2 * 0.05, 0.0), 0.042 * (1.0 - 0.35 * u2 * u2), scale(0.95, 1.0, 1.0, 0.9)))
	var head_part: ArrayTetraMesh4D = Loft.build(neck, 4, 10, true, false, true, 1, false)
	_paint(head_part, "head", func(p: Vector4) -> Vector3: return Vector3(PART["head"], clampf(0.5 + (p.y - 0.06) / 0.1, 0.0, 1.0), 0.5))
	parts.append(head_part)
	var bill: Array = []
	for k in 4:
		var u3: float = float(k) / 3.0
		bill.append(ball(Vector4(0.0, 0.078 - u3 * 0.006 - (0.008 if k == 3 else 0.0), 0.135 + u3 * 0.058, 0.0), 0.012 * (1.0 - 0.45 * u3), scale(0.85, 1.35, 1.0, 0.8)))
	var bill_part: ArrayTetraMesh4D = Loft.build(bill, 3, 8, true, false, true, 0, false)
	_paint(bill_part, "bill", func(p: Vector4) -> Vector3: return Vector3(PART["bill"], clampf(0.5 + (p.y - 0.074) / 0.03, 0.0, 1.0), clampf((p.z - 0.13) / 0.07, 0.0, 1.0)))
	parts.append(bill_part)
	return _merge(parts)


## The tail: a flat fan back from its root, square-ended.
static func _tail() -> ArrayTetraMesh4D:
	var sections: Array = []
	for k in 4:
		var u: float = float(k) / 3.0
		var half: float = lerpf(0.035, 0.065, u)
		sections.append(ball(Vector4(0.0, -u * 0.01, -u * 0.13, 0.0), half, scale(1.0, 0.008 / half + 0.05, 1.0, 0.5)))
	var m: ArrayTetraMesh4D = Loft.build(sections, 3, 10, true, false, true, 1, false)
	_paint(m, "tail", func(p: Vector4) -> Vector3: return Vector3(PART["tail"], 0.5, clampf(-p.z / 0.14, 0.0, 1.0)))
	return m


## The inner wing (arm): shoulder (origin) out along +X to the wrist at ARM; a broad chord, its leading
## edge thick, the trailing edge thin (the section's middle sits behind the leading edge).
static func _arm() -> ArrayTetraMesh4D:
	var sections: Array = []
	var n: int = 6
	for k in n:
		var u: float = float(k) / float(n - 1)
		var chord: float = lerpf(0.20, 0.17, u)
		var lead: float = 0.035
		sections.append(ball(Vector4(u * ARM, 0.0, lead - chord * 0.5, 0.0), chord * 0.5, scale(1.0, lerpf(0.026, 0.016, u) / (chord * 0.5), 1.0, 0.55)))
	var m: ArrayTetraMesh4D = Loft.build(sections, 3, 12, true, false, true, 1, false)
	_paint(m, "arm", func(p: Vector4) -> Vector3: return Vector3(PART["arm"], clampf(0.5 + p.y / 0.03, 0.0, 1.0), clampf((0.035 - p.z) / 0.2, 0.0, 1.0)))
	return m


## The outer wing (hand): wrist (origin) out along +X to a pointed tip at HAND, swept back.
static func _hand() -> ArrayTetraMesh4D:
	var sections: Array = []
	var n: int = 7
	for k in n:
		var u: float = float(k) / float(n - 1)
		var chord: float = lerpf(0.17, 0.035, pow(u, 1.3))
		var lead: float = 0.035 - 0.10 * u * u
		sections.append(ball(Vector4(u * HAND, 0.0, lead - chord * 0.5, 0.0), chord * 0.5, scale(1.0, lerpf(0.016, 0.007, u) / (chord * 0.5), 1.0, 0.55)))
	var m: ArrayTetraMesh4D = Loft.build(sections, 3, 12, true, false, true, 1, false)
	_paint(m, "hand", func(p: Vector4) -> Vector3: return Vector3(PART["hand"], clampf(0.5 + p.y / 0.02, 0.0, 1.0), clampf(p.x / HAND, 0.0, 1.0)))
	return m


## A leg: the tarsus down from the hip (origin), the webbed foot forward at its end.
static func _leg() -> ArrayTetraMesh4D:
	var parts: Array = []
	var shank: Array = []
	for k in 3:
		var u: float = float(k) / 2.0
		shank.append(ball(Vector4(0.0, -u * 0.09, -u * 0.01, 0.0), 0.007, scale(1.0, 1.0, 1.0, 1.0)))
	parts.append(Loft.build(shank, 3, 6, true, false, true, 0, false))
	var foot: Array = []
	for k in 3:
		var u2: float = float(k) / 2.0
		foot.append(ball(Vector4(0.0, -0.092, -0.01 + u2 * 0.05, 0.0), 0.02 * (0.6 + 0.4 * u2), scale(1.0, 0.18, 1.0, 0.6)))
	parts.append(Loft.build(foot, 3, 6, true, false, true, 0, false))
	for part in parts:
		_paint(part, "leg", func(_p: Vector4) -> Vector3: return Vector3(PART["leg"], 0.5, 0.5))
	return _merge(parts)


static func _merge(parts: Array) -> ArrayTetraMesh4D:
	var pos := PackedVector4Array()
	var cells := PackedInt32Array()
	var tex := PackedVector3Array()
	for m in parts:
		if m == null:
			continue
		var off: int = pos.size()
		pos.append_array((m as ArrayTetraMesh4D).get_vertex_positions())
		tex.append_array((m as ArrayTetraMesh4D).get_texture_map_values())
		for c in (m as ArrayTetraMesh4D).get_simplex_cell_vertex_indices():
			cells.append(c + off)
	var out := ArrayTetraMesh4D.new()
	out.set_vertex_positions(pos)
	out.set_simplex_cell_vertex_indices(cells)
	# Each part was painted per vertex before the merge, so its coordinates follow its vertices.
	if tex.size() == pos.size():
		out.set_texture_map_values(tex)
		out.set_simplex_cell_texture_map_indices(cells)
	return out


static func _paint(m: ArrayTetraMesh4D, _part: String, at: Callable) -> void:
	var pos: PackedVector4Array = m.get_vertex_positions()
	var tex := PackedVector3Array()
	tex.resize(pos.size())
	for i in pos.size():
		tex[i] = at.call(pos[i])
	m.set_texture_map_values(tex)
	m.set_simplex_cell_texture_map_indices(m.get_simplex_cell_vertex_indices())


## The gull's colours as one 3D texture (x: the part; y: below to above; z: along).
static func material() -> TetraMaterial4D:
	var nx: int = 20
	var ny: int = 8
	var nz: int = 24
	# Picked as seen (sRGB); the material reads its texture as linear, so each is converted (a 0.62
	# grey read as linear lit nearly white: the first frames, 9 Oct).
	var white := Color(0.95, 0.95, 0.94).srgb_to_linear()
	var grey := Color(0.62, 0.66, 0.71).srgb_to_linear()
	var under := Color(0.88, 0.89, 0.90).srgb_to_linear()
	var under_hand := Color(0.84, 0.85, 0.86).srgb_to_linear()
	var black := Color(0.05, 0.05, 0.06).srgb_to_linear()
	var yellow := Color(0.98, 0.80, 0.18).srgb_to_linear()
	var red := Color(0.86, 0.14, 0.10).srgb_to_linear()
	var pink := Color(0.93, 0.76, 0.72).srgb_to_linear()
	var slices: Array[Image] = []
	for k in nz:
		var img: Image = Image.create(nx, ny, false, Image.FORMAT_RGBA8)
		for j in ny:
			for i in nx:
				var part: float = (float(i) + 0.5) / float(nx)
				var y: float = float(j) / float(ny - 1)
				var z: float = float(k) / float(nz - 1)
				var c: Color = white
				if part < 0.2:
					# Body: the mantle grey on top, toward the back.
					c = white.lerp(grey, smoothstep(0.62, 0.8, y) * smoothstep(0.15, 0.4, z))
				elif part < 0.3:
					c = white
				elif part < 0.4:
					# The bill: yellow, the red spot near the tip below.
					c = yellow
					if z > 0.6 and y < 0.45:
						c = red
				elif part < 0.5:
					c = white
				elif part < 0.68:
					# The arm: grey above, white below and along the trailing edge.
					c = grey if y > 0.5 else under
					if z > 0.82:
						c = white
				elif part < 0.83:
					# The hand: grey to black at the tip, white mirrors near it, white below.
					var blackness: float = smoothstep(0.55, 0.68, z)
					c = (grey if y > 0.5 else under_hand).lerp(black, blackness)
					if z > 0.84 and z < 0.92:
						c = white
				else:
					c = pink
				img.set_pixel(i, j, c)
		slices.append(img)
	var tex := ImageTexture3D.new()
	tex.create(Image.FORMAT_RGBA8, nx, ny, nz, false, slices)
	var m := TetraMaterial4D.new()
	m.set("albedo_source", 3)
	m.set("albedo_texture_3d", tex)
	return m
