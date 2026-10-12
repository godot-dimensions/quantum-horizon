extends Node

## PUTS THE OUTFIT ON ONE PLAYER FIGURE (outfit_4d.gd says what; this paints it on). Made by the
## keeper (outfit_keeper_4d.gd) for every player figure that comes into the tree, so the pen's player,
## and the cinema's own, wear the same thing.
##
## IT LIVES BESIDE THE FIGURE, NEVER IN IT. block_avatar_4d.gd frees every child it has whenever it
## rebuilds (scripts/pen_pickaxe_4d.gd learned this first), so a wearer inside it would be freed by
## the first rebuild and the outfit would silently fall off. From outside, one check a frame notices
## a rebuild (the mark it leaves on the figure has gone) and dresses the new body.
##
## PAINT, NOT A NEW BODY. Every part of the figure is its own box with its own material, so the outfit
## is colours laid on the parts it names, plus a few boxes for a hat. The figure's own settings stay as
## they are, with one exception: the cap, which is part of the figure, comes off for any other hat.
##
## WHAT PAINTS WHAT (the chibi's part names, block_avatar_4d.gd _build_chibi):
##   shirt     Tunic, UpperArm (the short sleeves)
##   skin      Head, the four ears, Forearm, Hand, and the legs when in shorts
##   trousers  Belt (shorts), and Thigh and Shin when long
##   shoes     Boot
##   hair      Hair, Crown (the hair on top with no cap), the ponytail if there is one
##   hat       Cap, or the hat's own pieces (outfit_pieces_4d.gd)
## The eyes are left alone.

const Outfit := preload("res://ramon/chickenpen/outfit/outfit_4d.gd")
const Pieces := preload("res://ramon/chickenpen/outfit/outfit_pieces_4d.gd")

## The cyan the scan and a change light a part with: the arch's lit field (theatre/theatre_arch_4d.gd).
const FLASH := Color(0.45, 0.92, 1.0)
const FLASH_SECONDS := 0.45
const MARK := &"OutfitMark"
const ROW_HAT := 0
const ROW_HAIR := 1
const ROW_SKIN := 2
const ROW_SHIRT := 3
const ROW_TROUSERS := 4
const ROW_SHOES := 5

## The figure: the Avatar under a Player, on block_avatar_4d.gd.
var avatar: Node4D

var _mark: Node4D
var _rev: int = -1
var _hat_built: int = -1
## Whether the hat is in its kept-low form, and whether it should be: low while the player carries a
## chicken over their head (outfit_pieces_4d.gd, the _LOW pieces).
var _low_built: bool = false
var _catcher: Node
var _pieces: Array[MeshInstance4D] = []
var _cube: MeshInstance4D
## Per row, how much of a flash is left.
var _flash: PackedFloat32Array = PackedFloat32Array([0.0, 0.0, 0.0, 0.0, 0.0, 0.0])
var _was_lit: bool = false
var _spin: float = 0.0


func _process(delta: float) -> void:
	if avatar == null or not is_instance_valid(avatar):
		queue_free()
		return
	if not avatar.is_inside_tree() or not avatar.is_node_ready():
		return
	var lit: bool = false
	for i in _flash.size():
		if _flash[i] > 0.0:
			_flash[i] = maxf(_flash[i] - delta, 0.0)
			lit = true
	if not _is_dressed() or _rev != Outfit.changes() or _carrying() != _low_built:
		_dress()
	elif lit or _was_lit:
		_paint()
	_was_lit = lit
	if _cube != null and is_instance_valid(_cube):
		# Through W on two planes and round on the floor, at speeds that never line up, so the slice
		# keeps changing and never repeats on a beat.
		_spin += delta
		_cube.basis = Basis4D.from_xw(_spin * 0.9) * Basis4D.from_zw(_spin * 0.55) * Basis4D.from_zx(_spin * 0.35)


## Lights a row's parts cyan for a moment: the scan passing them, or a change made to them.
func flash(row: int, strength: float = 1.0) -> void:
	if row >= 0 and row < _flash.size():
		_flash[row] = maxf(_flash[row], FLASH_SECONDS * clampf(strength, 0.0, 1.0))


## Whether the player holds a chicken over their head (chicken_catcher_4d.gd's carried), when the hat
## keeps low. Only the chicken (Ramon's word); the cat is held at the same spot (scripts/pen_cat_grab_4d.gd)
## and could join it. The cinema's player has no catcher, so never.
func _carrying() -> bool:
	if _catcher == null or not is_instance_valid(_catcher):
		_catcher = null
		var body: Node = avatar.get_parent()
		if body == null:
			return false
		for child in body.get_children():
			if "carried" in child:
				_catcher = child
				break
		if _catcher == null:
			return false
	return _catcher.get("carried") != null


## Whether the figure this wearer last dressed is still the figure there (it has not rebuilt).
func _is_dressed() -> bool:
	return _mark != null and is_instance_valid(_mark) and _mark.get_parent() == avatar


## Dresses the figure from scratch where needed: the cap on or off, the hat's pieces, then the paint.
func _dress() -> void:
	_rev = Outfit.changes()
	var fresh: bool = not _is_dressed()
	var want_cap: bool = Outfit.hat() == Outfit.HAT_CAP
	if "wear_cap" in avatar and bool(avatar.get("wear_cap")) != want_cap:
		avatar.set("wear_cap", want_cap)
		if avatar.has_method("rebuild"):
			avatar.call("rebuild")
		fresh = true
	var low: bool = _carrying()
	if fresh or _hat_built != Outfit.hat() or low != _low_built:
		for piece in _pieces:
			if is_instance_valid(piece):
				piece.free()
		_pieces.clear()
		_cube = null
		var head: Node4D = avatar.get("head") as Node4D
		if head != null and is_instance_valid(head):
			_pieces = Pieces.build(head, Outfit.hat(), low)
			for piece in _pieces:
				if piece.name == &"Hypercube":
					_cube = piece
		_hat_built = Outfit.hat()
		_low_built = low
	if fresh:
		_mark = Node4D.new()
		_mark.name = MARK
		avatar.add_child(_mark)
	_paint()


func _paint() -> void:
	var hat_colour: Color = Outfit.colour("hat_colour")
	var trim: Color = Pieces.trim_of(hat_colour)
	for node in avatar.find_children("*", "MeshInstance4D", true, false):
		var part := node as MeshInstance4D
		var row: int = -1
		var base: Color
		if part.has_meta(Pieces.PIECE):
			var role: Variant = part.get_meta(Pieces.ROLE)
			row = ROW_HAT
			base = role if role is Color else (hat_colour if role == "hat" else trim)
		else:
			if not _is_body_part(part):
				continue
			row = row_of(String(part.name))
			if row < 0:
				continue
			base = _colour_for(row)
		var k: float = clampf(_flash[row] / FLASH_SECONDS, 0.0, 1.0)
		var colour: Color = base.lerp(FLASH, k * 0.85)
		var material := part.material_override as TetraMaterial4D
		if material != null and material.albedo_color != colour:
			material.albedo_color = colour


func _colour_for(row: int) -> Color:
	match row:
		ROW_HAT:
			return Outfit.colour("hat_colour")
		ROW_HAIR:
			return Outfit.colour("hair")
		ROW_SKIN:
			return Outfit.colour("skin")
		ROW_SHIRT:
			return Outfit.colour("shirt")
		ROW_TROUSERS:
			return Outfit.colour("trousers")
		ROW_SHOES:
			return Outfit.colour("shoes")
	return Color.WHITE


## Whether [param part] is the figure's own, not something hung on it. The pickaxe hangs off the right
## elbow and has a part called Cap of its own (scripts/pen_pickaxe_4d.gd), which the first version
## painted in the hat's colour. The figure's parts hang only off the figure itself, its Tunic and
## Head, and its joints (block_avatar_4d.gd _pivot), so anything under another parent is somebody
## else's.
func _is_body_part(part: Node) -> bool:
	var parent: Node = part.get_parent()
	if parent == avatar:
		return true
	var bare: String = String(parent.name)
	if bare.ends_with("L") or bare.ends_with("R"):
		bare = bare.left(bare.length() - 1)
	return bare in ["Tunic", "Head", "Hip", "Knee", "Ankle", "Shoulder", "Elbow"]


## Which row paints the figure's part called [param part]. The pairs are named by side (EarL, EarR,
## and the W pair EarA, EarK; ThighL, ThighR), so the side comes off first.
static func row_of(part: String) -> int:
	var bare: String = part
	if part.begins_with("Ear"):
		bare = "Ear"
	elif part.length() > 1 and (part.ends_with("L") or part.ends_with("R")):
		bare = part.left(part.length() - 1)
	match bare:
		"Cap":
			return ROW_HAT
		"Hair", "Crown", "Tie", "Tail1", "Tail2", "Tail3":
			return ROW_HAIR
		"Head", "Ear", "Forearm", "Hand":
			return ROW_SKIN
		"Tunic", "UpperArm":
			return ROW_SHIRT
		"Belt":
			return ROW_TROUSERS
		"Thigh", "Shin":
			return ROW_TROUSERS if Outfit.long_legs() else ROW_SKIN
		"Boot", "Foot":
			return ROW_SHOES
	return -1
