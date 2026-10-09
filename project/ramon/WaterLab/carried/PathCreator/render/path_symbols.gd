@tool
extends RefCounted

## PathCreator: the symbol libraries as data the vector shader reads (path_mark.gdshader). Each
## library is a folder of the sheet's masters as SVG, one a slot (`sets/07/A.svg` ... `I.svg`),
## read by path_svg.gd; every symbol of every library goes into three small float textures:
##
##   segcaps    two texels a segment: its run's start and end cap planes (a stroke's flat ends)
##   segments   one texel a straight segment: (x0, y0, x1, y1), in sheet units, the symbol's middle
##              at (0, 0), y down as the SVG has it (on the floor that is +z, so a symbol seen from
##              above reads as it does on the sheet)
##   shapes     two texels a shape: (first segment, segments, kind, stroke width) and (layer, colour
##              role, 0, 0). Kind: 0 fill (nonzero), 1 fill (even-odd), 2 stroke. Layer: 0 still,
##              1 the moving arc, 2 the focus accent
##   symbols    two texels a symbol: (first shape, shapes, half width, half height) and (radius, 0, 0, 0)
##
## LAYERS are found, not named. In each library, what E (action available) and F (focused) draw that
## D (arrival) does not is the arc (a stroke) or the accent (a fill): the sheet's rule 07 in data.
##
## COLOUR ROLES: each shape's colour is matched to the sheet's nearest token, so a look can
## recolour by role (DEV keeps them, WALK paints every role sand): 0 blue, 1 cyan, 2 edge, 3 muted,
## 4 floor. The floor role is the sheet's floor colour used as a fill (06's hollow junction is a ring
## filled with the floor, so the guide line under it is covered): it paints the floor's own albedo.
##
## A symbol is asked for by "library/slot", e.g. "07/A"; build() returns the ids.
##
## NO class_name (engine_gotchas.md).

const SVG := preload("res://ramon/WaterLab/carried/PathCreator/render/path_svg.gd")
const Spec := preload("res://ramon/WaterLab/carried/PathCreator/path_spec.gd")
const SETS_DIR := "res://ramon/WaterLab/carried/PathCreator/sets/"
const ROLES := ["blue", "cyan", "edge", "muted", "floor"]
const SEG_W := 1024
const SHAPE_W := 256
const SYM_W := 64


## The libraries on disk: their folder names ("07", ...).
static func libraries() -> PackedStringArray:
	var out := PackedStringArray()
	var dir := DirAccess.open(SETS_DIR)
	if dir == null:
		return out
	for d in dir.get_directories():
		out.append(d)
	out.sort()
	return out


## One library: {slot: {"shapes": [...], "size": Vector2}}, coordinates centred on the symbol.
static func read_library(lib: String) -> Dictionary:
	var out: Dictionary = {}
	for slot in Spec.SLOTS:
		var p: String = SETS_DIR + lib + "/" + String(slot) + ".svg"
		if not FileAccess.file_exists(p):
			continue
		var vb: Rect2 = SVG.view_box(p)
		var shapes: Array = SVG.read(p)
		var c: Vector2 = vb.get_center()
		for sh in shapes:
			var segs: PackedVector4Array = sh["segs"]
			for k in segs.size():
				segs[k] = segs[k] - Vector4(c.x, c.y, c.x, c.y)
			sh["segs"] = segs
			# The cap planes' points move with the symbol's middle; their directions do not.
			var caps: PackedVector4Array = sh.get("caps", PackedVector4Array())
			for k in caps.size():
				if caps[k].z != 0.0 or caps[k].w != 0.0:
					caps[k] = caps[k] - Vector4(c.x, c.y, 0.0, 0.0)
			sh["caps"] = caps
			sh["layer"] = 0
			sh["role"] = _role(String(sh["color"]))
		out[slot] = {"shapes": shapes, "size": vb.size}
	# The layers: E and F against D.
	if out.has("D"):
		var still: Dictionary = {}
		for sh in out["D"]["shapes"]:
			still[String(sh["d"]) + String(sh["kind"])] = true
		for slot in ["E", "F"]:
			if not out.has(slot):
				continue
			for sh in out[slot]["shapes"]:
				if not still.has(String(sh["d"]) + String(sh["kind"])):
					sh["layer"] = 1 if String(sh["kind"]) == "stroke" else 2
	return out


static func _role(hex: String) -> int:
	var c := Color.from_string(hex, Color("#1761d7"))
	var best: int = 0
	var best_d: float = INF
	for i in ROLES.size():
		var t: Color = Spec.TOKENS[ROLES[i]]
		var d: float = Vector3(c.r - t.r, c.g - t.g, c.b - t.b).length_squared()
		if d < best_d:
			best_d = d
			best = i
	return best


## Every library given ({lib: read_library(lib)}) packed: {"segments", "shapes", "symbols"
## (ImageTextures), "ids": {"07/A": index}, "counts": [segments, shapes, symbols]}.
static func build(libs: Dictionary) -> Dictionary:
	var segs := PackedVector4Array()
	var segcaps: Array = []
	var shapes: Array = []
	var syms: Array = []
	var ids: Dictionary = {}
	for lib in libs:
		var L: Dictionary = libs[lib]
		for slot in L:
			var sym: Dictionary = L[slot]
			var first_shape: int = shapes.size() / 2
			var r: float = 0.0
			for sh in sym["shapes"]:
				var s0: int = segs.size()
				var ss: PackedVector4Array = sh["segs"]
				segs.append_array(ss)
				var cp: PackedVector4Array = sh.get("caps", PackedVector4Array())
				for q in ss.size():
					for j in 2:
						var c: Vector4 = cp[q * 2 + j] if q * 2 + j < cp.size() else Vector4.ZERO
						segcaps.append(Color(c.x, c.y, c.z, c.w))
				for v in ss:
					r = maxf(r, maxf(Vector2(v.x, v.y).length(), Vector2(v.z, v.w).length()) + float(sh["width"]) * 0.5)
				var kind: int = 2 if String(sh["kind"]) == "stroke" else (1 if String(sh["rule"]) == "evenodd" else 0)
				shapes.append(Color(float(s0), float(ss.size()), float(kind), float(sh["width"])))
				shapes.append(Color(float(sh["layer"]), float(sh["role"]), 0.0, 0.0))
			var size: Vector2 = sym["size"]
			ids["%s/%s" % [lib, slot]] = syms.size() / 2
			syms.append(Color(float(first_shape), float((sym["shapes"] as Array).size()), size.x * 0.5, size.y * 0.5))
			syms.append(Color(r, 0.0, 0.0, 0.0))
	return {"segments": _tex_v4(segs, SEG_W), "segcaps": _tex(segcaps, SEG_W), "shapes": _tex(shapes, SHAPE_W), "symbols": _tex(syms, SYM_W),
		"ids": ids, "counts": [segs.size(), shapes.size() / 2, syms.size() / 2]}


static func _tex_v4(v: PackedVector4Array, w: int) -> ImageTexture:
	var cols: Array = []
	for x in v:
		cols.append(Color(x.x, x.y, x.z, x.w))
	return _tex(cols, w)


static func _tex(cols: Array, w: int) -> ImageTexture:
	var h: int = maxi(1, int(ceil(float(maxi(cols.size(), 1)) / float(w))))
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBAF)
	for i in cols.size():
		img.set_pixel(i % w, i / w, cols[i])
	return ImageTexture.create_from_image(img)
