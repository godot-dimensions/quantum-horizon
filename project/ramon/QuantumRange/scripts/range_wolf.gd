extends RefCounted

## The range's wolf, built once into rigid pieces from the pen's wolf (Model/wolf.tscn: its balls,
## copied here as numbers, so nothing of the pen or the Creation Lab is loaded or touched).
##
## WHY RIGID PIECES (Ramon, 6 Oct: "avoid realtime lofting and use the rigid system ... breaking up the
## limbs instead of one loft skin"). The pen's wolf is lofted as one hide and cut into a body and leg
## pieces, with thin joint bands re-posed vertex by vertex every frame; its head, tail and ears ride on
## the body. The Creation Lab's goes further: every piece moves by transform alone (0.012 ms a frame),
## but it still has one body. This one is cut finer, so the parts a running, leaping, catching wolf moves
## can move: two body halves that flex at the barrel, the head on its own neck joint with a lower jaw
## that opens, two tail pieces, and each leg in an upper and a lower piece. Every piece is lofted once
## (follow_up/lofting_gotchas.md: drawing is nearly free, re-lofting is not), with its pivot at its own
## origin, and is shared by every wolf on the range.
##
## Metres as in the pen (about 0.8 m at the shoulder, 1.3 m nose to rump); +Z ahead, +X its left.
##
## NO class_name (engine_gotchas.md): preload it.

const Loft := preload("res://ramon/QuantumRange/carried/chicken/loft_builder_4d.gd")

## The balls of Model/wolf.tscn, in its own space: [position, radius, v_scale, w_scale, grey].
const BALL := {
	"Rump": [Vector4(0, 0.66, -0.44, 0), 0.15, 1.2, 1.0, 0.22],
	"Loin": [Vector4(0, 0.68, -0.22, 0), 0.13, 1.2, 1.0, 0.24],
	"Barrel": [Vector4(0, 0.65, 0.02, 0), 0.155, 1.4, 1.0, 0.29],
	"Chest": [Vector4(0, 0.65, 0.24, 0), 0.165, 1.4, 1.0, 0.42],
	"Ruff": [Vector4(0, 0.74, 0.39, 0), 0.16, 1.2, 1.0, 0.56],
	"Skull": [Vector4(0, 0.8, 0.53, 0), 0.12, 1.0, 1.0, 0.36],
	"Muzzle": [Vector4(0, 0.76, 0.69, 0), 0.065, 0.95, 1.0, 0.66],
	"Nose": [Vector4(0, 0.755, 0.78, 0), 0.032, 1.0, 1.0, 0.05],
	"ForeHip": [Vector4(0.085, 0.56, 0.26, 0), 0.085, 1.3, 1.0, 0.40],
	"ForeKnee": [Vector4(0.085, 0.27, 0.17, 0), 0.05, 1.0, 1.0, 0.55],
	"ForeFoot": [Vector4(0.085, 0.025, 0.26, 0), 0.05, 1.0, 1.0, 0.62],
	"HindHip": [Vector4(0.085, 0.56, -0.42, 0), 0.1, 1.3, 1.0, 0.34],
	"HindKnee": [Vector4(0.085, 0.295, -0.55, 0), 0.052, 1.0, 1.0, 0.50],
	"HindFoot": [Vector4(0.085, 0.035, -0.44, 0), 0.05, 1.0, 1.0, 0.62],
	"TailBase": [Vector4(0, 0.69, -0.57, 0), 0.055, 1.0, 1.0, 0.26],
	"TailMid": [Vector4(0, 0.59, -0.69, 0), 0.08, 1.0, 1.0, 0.30],
	"TailEnd": [Vector4(0, 0.46, -0.74, 0), 0.065, 1.0, 1.0, 0.25],
	"TailTip": [Vector4(0, 0.38, -0.74, 0), 0.022, 1.0, 1.0, 0.10],
	"EarBase": [Vector4(0.06, 0.89, 0.51, 0), 0.042, 0.55, 0.8, 0.28],
	"EarTip": [Vector4(0.075, 0.975, 0.51, 0), 0.008, 1.0, 1.0, 0.12],
}

## Where the pieces turn, in the wolf's own space.
const SPINE := Vector4(0, 0.65, 0.02, 0)        ## the barrel: the body bends here in a gallop
const NECK := Vector4(0, 0.77, 0.44, 0)         ## the head turns on the neck, inside the ruff
const JAW := Vector4(0, 0.735, 0.565, 0)        ## the lower jaw hinges under the back of the skull
## The tail's root is set into the rump (the model's TailBase ball sits on its surface; raised, it
## showed a gap).
const TAIL_ROOT := Vector4(0, 0.675, -0.53, 0)
const TAIL_MID := Vector4(0, 0.59, -0.69, 0)
## Where the mouth holds what it catches, in the head's space (from NECK).
const MOUTH := Vector4(0, 0.69, 0.76, 0)
## The eyes: amber boxes (wolf.tscn EyeL), on the head.
const EYE := Vector4(0.052, 0.84, 0.62, 0)
const EYE_SIZE := Vector4(0.026, 0.016, 0.012, 0.02)
const EYE_COLOR := Color(0.86, 0.6, 0.16)
## The legs' lengths, hip to knee and knee to foot.
static var fore_lengths: Vector2 = Vector2.ZERO
static var hind_lengths: Vector2 = Vector2.ZERO

static var _pieces: Dictionary = {}
static var build_ms: float = 0.0


static func _sec(name: String, origin: Vector4, r_k: float = 1.0) -> Dictionary:
	var b: Array = BALL[name]
	return {"center": (b[0] as Vector4) - origin, "radius": float(b[1]) * r_k, "v_scale": float(b[2]), "w_scale": float(b[3]), "squareness": 0.0}


static func _at(name: String) -> Vector4:
	return BALL[name][0]


static func _grey(name: String) -> Color:
	var g: float = float(BALL[name][4])
	return Color(g, g, g * 1.03 + 0.01)


static func _loft(secs: Array, rings: int = 4, sides: int = 12) -> Mesh4D:
	return Loft.build(secs, rings, sides, true, false, true, 2, false)


## Every piece: {name: [mesh, colour, pivot (wolf space)]}. Legs are built for the left side (+X); the
## right side is the same mesh turned through x/w, as the chicken's other wing is.
static func pieces() -> Dictionary:
	if not _pieces.is_empty():
		return _pieces
	var t0: int = Time.get_ticks_usec()
	var p: Dictionary = {}
	# The body in two halves that meet at the barrel, each ending in it (round, so a bend shows no gap).
	p["Rear"] = [_loft([_sec("Rump", SPINE), _sec("Loin", SPINE), _sec("Barrel", SPINE)], 5), _grey("Loin"), SPINE]
	p["Front"] = [_loft([_sec("Barrel", SPINE), _sec("Chest", SPINE), _sec("Ruff", SPINE)], 5), _grey("Chest"), SPINE]
	# The head from inside the ruff to the nose; a lighter snout over it; the black nose; the lower jaw,
	# a slim wedge under the snout that drops open.
	var neck_in := {"center": Vector4(0, 0.775, 0.45, 0) - NECK, "radius": 0.1, "v_scale": 1.1, "w_scale": 1.0, "squareness": 0.0}
	p["Head"] = [_loft([neck_in, _sec("Skull", NECK), _sec("Muzzle", NECK, 0.9)], 4), _grey("Skull"), NECK]
	p["Snout"] = [_loft([_sec("Muzzle", NECK, 1.04), _sec("Nose", NECK, 1.1)], 3, 10), _grey("Muzzle"), NECK]
	p["NoseTip"] = [_loft([{"center": Vector4(0, 0.757, 0.79, 0) - NECK, "radius": 0.03, "v_scale": 1.0, "w_scale": 1.0, "squareness": 0.0},
		{"center": Vector4(0, 0.757, 0.81, 0) - NECK, "radius": 0.022, "v_scale": 1.0, "w_scale": 1.0, "squareness": 0.0}], 2, 8), Color(0.05, 0.05, 0.06), NECK]
	p["Jaw"] = [_loft([{"center": Vector4(0, 0.725, 0.58, 0) - JAW, "radius": 0.05, "v_scale": 0.55, "w_scale": 0.9, "squareness": 0.0},
		{"center": Vector4(0, 0.712, 0.66, 0) - JAW, "radius": 0.04, "v_scale": 0.5, "w_scale": 0.85, "squareness": 0.0},
		{"center": Vector4(0, 0.71, 0.73, 0) - JAW, "radius": 0.026, "v_scale": 0.5, "w_scale": 0.8, "squareness": 0.0}], 3, 10), Color(0.6, 0.58, 0.56), JAW]
	p["Ear"] = [_loft([_sec("EarBase", NECK), _sec("EarTip", NECK)], 3, 8), _grey("EarBase"), NECK]
	# The tail in two, the second with its dark tip.
	var root_in := {"center": Vector4.ZERO, "radius": 0.075, "v_scale": 1.0, "w_scale": 1.0, "squareness": 0.0}
	p["Tail1"] = [_loft([root_in, _sec("TailBase", TAIL_ROOT, 1.35), _sec("TailMid", TAIL_ROOT)], 3, 10), _grey("TailBase"), TAIL_ROOT]
	p["Tail2"] = [_loft([_sec("TailMid", TAIL_MID), _sec("TailEnd", TAIL_MID), _sec("TailTip", TAIL_MID)], 3, 10), _grey("TailMid"), TAIL_MID]
	# Each leg, upper and lower, the left one; each lower ends in its paw.
	for leg in ["Fore", "Hind"]:
		var hip: Vector4 = _at(leg + "Hip")
		var knee: Vector4 = _at(leg + "Knee")
		var foot: Vector4 = _at(leg + "Foot")
		p[leg + "Upper"] = [_loft([_sec(leg + "Hip", hip, 0.85), _sec(leg + "Knee", hip)], 3, 10), _grey(leg + "Hip"), hip]
		p[leg + "Lower"] = [_loft([_sec(leg + "Knee", knee), _sec(leg + "Foot", knee)], 3, 10), _grey(leg + "Foot"), knee]
		var l := Vector2((knee - hip).length(), (foot - knee).length())
		if leg == "Fore":
			fore_lengths = l
		else:
			hind_lengths = l
	_pieces = p
	build_ms += (Time.get_ticks_usec() - t0) / 1000.0
	return _pieces
