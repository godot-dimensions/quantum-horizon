extends RefCounted

## THE HATS AND THE JOKES, as boxes hung on the figure's Head (outfit_wearer_4d.gd builds them).
##
## SIZED TO THE HEAD IN ALL FOUR DIRECTIONS. The chibi's head is 0.30 wide, 0.32 tall and 0.29 deep,
## and 0.285 thick through W, with a pair of ears out along x (to 0.225) and, since Andrew's change of
## 7 Oct, a second pair out along W (to 0.2175). A hat thinner through W than the head would vanish
## the moment the slice turns a little, leaving a bare head on one slice and a hat on another; every
## piece here is at least as thick in W as what it covers (Miegakure's characters are the same idea:
## a figure with a real thickness in the fourth direction).
##
## Positions are in the Head's own frame: its centre at the origin, +Y up, +Z the way the face looks.
## With no cap the figure grows a crown of hair from y 0.10 to 0.20, so every hat sits on that.
##
## Each piece is [name, position, size (x y z), thickness in W, what colours it]. "hat" takes the
## hat colour, "trim" a darker or lighter shade of it, and a Color stays that colour.

const Outfit := preload("res://ramon/chickenpen/outfit/outfit_4d.gd")

const FEATHER := Color(0.93, 0.91, 0.86)
const COMB := Color(0.85, 0.16, 0.14)
const BEAK := Color(0.95, 0.62, 0.18)
const EYE := Color(0.08, 0.07, 0.07)

const BEANIE := [
	["Beanie", Vector4(0.0, 0.195, 0.0, 0.0), Vector3(0.35, 0.15, 0.34), 0.34, "hat"],
	["BeanieCuff", Vector4(0.0, 0.12, 0.0, 0.0), Vector3(0.36, 0.05, 0.35), 0.35, "trim"],
	["Pompom", Vector4(0.0, 0.31, 0.0, 0.0), Vector3(0.10, 0.09, 0.10), 0.10, "trim"],
]

const TOP_HAT := [
	# "HatCrown", not "Crown": the figure's own crown of hair is a Crown under the same Head.
	["Brim", Vector4(0.0, 0.215, 0.0, 0.0), Vector3(0.46, 0.03, 0.44), 0.44, "hat"],
	["HatCrown", Vector4(0.0, 0.39, 0.0, 0.0), Vector3(0.27, 0.32, 0.26), 0.26, "hat"],
	["Band", Vector4(0.0, 0.26, 0.0, 0.0), Vector3(0.28, 0.05, 0.27), 0.27, "trim"],
]

## THE CHICKEN: a mascot's neck and head worn on the shoulders, the way a costume is. Bigger than the
## figure's head in every direction, W included, so the head, cap, hair and both pairs of ears are
## simply inside it and nothing has to be hidden. Its eyes face front, as a mascot's do so it reads as
## a face from the camera, and a second pair looks out along W, after Andrew's ears: turn the slice
## and the chicken is still looking at you.
const CHICKEN := [
	["ChickenNeck", Vector4(0.0, 0.12, -0.01, 0.0), Vector3(0.50, 0.66, 0.42), 0.50, FEATHER],
	["ChickenHead", Vector4(0.0, 0.58, 0.04, 0.0), Vector3(0.44, 0.36, 0.48), 0.46, FEATHER],
	["BeakTop", Vector4(0.0, 0.58, 0.36, 0.0), Vector3(0.16, 0.07, 0.18), 0.16, BEAK],
	["BeakBottom", Vector4(0.0, 0.52, 0.33, 0.0), Vector3(0.12, 0.05, 0.12), 0.12, BEAK],
	["Wattle", Vector4(0.0, 0.43, 0.31, 0.0), Vector3(0.08, 0.14, 0.07), 0.08, COMB],
	["Comb1", Vector4(0.0, 0.80, 0.15, 0.0), Vector3(0.07, 0.11, 0.09), 0.10, COMB],
	["Comb2", Vector4(0.0, 0.84, 0.04, 0.0), Vector3(0.07, 0.13, 0.09), 0.10, COMB],
	["Comb3", Vector4(0.0, 0.80, -0.07, 0.0), Vector3(0.07, 0.10, 0.09), 0.10, COMB],
	["ChickenEyeL", Vector4(0.11, 0.64, 0.282, 0.0), Vector3(0.06, 0.07, 0.02), 0.06, EYE],
	["ChickenEyeR", Vector4(-0.11, 0.64, 0.282, 0.0), Vector3(0.06, 0.07, 0.02), 0.06, EYE],
	["ChickenEyeA", Vector4(0.0, 0.64, 0.12, 0.232), Vector3(0.06, 0.07, 0.06), 0.02, EYE],
	["ChickenEyeK", Vector4(0.0, 0.64, 0.12, -0.232), Vector3(0.06, 0.07, 0.06), 0.02, EYE],
]

## THE HYPERCUBE: a small tesseract floating over the head, turning slowly through W. What you see of
## it is its slice, so as it turns it is a cube, then a slab, then a prism, then a cube again: the
## same object, never changing, only turning. The wearer turns it (Spinner).
const HYPERCUBE := [
	["Hypercube", Vector4(0.0, 0.44, 0.0, 0.0), Vector3(0.20, 0.20, 0.20), 0.20, "hat"],
]

## THE SAME HATS, KEPT LOW, for while you hold a chicken over your head (Ramon, 8 Oct: "keep the hats
## minimal if they overlay with chicken"). A caught chicken sits at 1.58 m (Player/CarryAnchor), just
## over a bare head; the cap's top is 1.54, and nothing here reaches past about that while you carry.
## The top hat drops to a flat crown, the beanie loses its pompom, the hypercube shrinks onto the hair,
## and the chicken costume comes down to a comb, a beak and a wattle on your own head.
const BEANIE_LOW := [
	["Beanie", Vector4(0.0, 0.195, 0.0, 0.0), Vector3(0.35, 0.15, 0.34), 0.34, "hat"],
	["BeanieCuff", Vector4(0.0, 0.12, 0.0, 0.0), Vector3(0.36, 0.05, 0.35), 0.35, "trim"],
]

const TOP_HAT_LOW := [
	["Brim", Vector4(0.0, 0.215, 0.0, 0.0), Vector3(0.46, 0.03, 0.44), 0.44, "hat"],
	["HatCrown", Vector4(0.0, 0.26, 0.0, 0.0), Vector3(0.27, 0.07, 0.26), 0.26, "hat"],
	["Band", Vector4(0.0, 0.24, 0.0, 0.0), Vector3(0.28, 0.03, 0.27), 0.27, "trim"],
]

const CHICKEN_LOW := [
	["Comb1", Vector4(0.0, 0.235, 0.09, 0.0), Vector3(0.06, 0.07, 0.07), 0.08, COMB],
	["Comb2", Vector4(0.0, 0.25, 0.0, 0.0), Vector3(0.06, 0.09, 0.07), 0.08, COMB],
	["Comb3", Vector4(0.0, 0.235, -0.09, 0.0), Vector3(0.06, 0.07, 0.07), 0.08, COMB],
	["BeakTop", Vector4(0.0, -0.02, 0.19, 0.0), Vector3(0.12, 0.05, 0.10), 0.12, BEAK],
	["Wattle", Vector4(0.0, -0.085, 0.165, 0.0), Vector3(0.06, 0.08, 0.04), 0.06, COMB],
]

const HYPERCUBE_LOW := [
	["Hypercube", Vector4(0.0, 0.27, 0.0, 0.0), Vector3(0.11, 0.11, 0.11), 0.11, "hat"],
]

## Marks what this file made, so the wearer can find and clear exactly its own pieces.
const PIECE := &"outfit_piece"
## The role a piece is painted by: "hat", "trim" or a fixed colour.
const ROLE := &"outfit_role"


## [param hat]'s pieces; [param low] for the kept-low ones, while a chicken is carried over the head.
static func pieces_for(hat: int, low: bool = false) -> Array:
	if hat == Outfit.HAT_BEANIE:
		return BEANIE_LOW if low else BEANIE
	if hat == Outfit.HAT_TOP:
		return TOP_HAT_LOW if low else TOP_HAT
	if hat == Outfit.HAT_CHICKEN:
		return CHICKEN_LOW if low else CHICKEN
	if hat == Outfit.HAT_HYPERCUBE:
		return HYPERCUBE_LOW if low else HYPERCUBE
	return []


## Builds [param hat]'s pieces under [param head] and returns them.
static func build(head: Node4D, hat: int, low: bool = false) -> Array[MeshInstance4D]:
	var made: Array[MeshInstance4D] = []
	for spec in pieces_for(hat, low):
		var node := MeshInstance4D.new()
		node.name = spec[0]
		var box := BoxTetraMesh4D.new()
		var size: Vector3 = spec[2]
		box.size = Vector4(size.x, size.y, size.z, float(spec[3]))
		node.mesh = box
		var material := TetraMaterial4D.new()
		material.albedo_color = spec[4] if spec[4] is Color else Color.WHITE
		node.material_override = material
		node.set_meta(PIECE, true)
		node.set_meta(ROLE, spec[4])
		head.add_child(node)
		node.position = spec[1]
		made.append(node)
	return made


## The shade a "trim" piece takes: darker on a light hat, lighter on a dark one, so the band of a
## charcoal top hat still shows.
static func trim_of(hat_colour: Color) -> Color:
	var light: float = hat_colour.get_luminance()
	return hat_colour.lightened(0.45) if light < 0.28 else hat_colour.darkened(0.42)
