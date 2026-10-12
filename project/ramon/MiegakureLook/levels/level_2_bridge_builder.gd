extends "res://ramon/MiegakureLook/scripts/miegakure_level_base.gd"
## LEVEL 2 - "The Bridge in Another World". Same single rotation out and back as
## level 1, but now the obstacle is the absence of floor rather than the presence
## of a wall, and getting it wrong drops you instead of stopping you.
##
## A chasm cuts the platform across its full x width. At most w it is genuinely
## open; in one 2 m band the floor runs straight across. Walk to the lip, rotate,
## walk along w into the cyan lane, rotate back, cross ground that was not there
## a moment ago.
##
## WHY THIS FOLLOWS THE WALL. Level 1 teaches the move with a safe failure - the
## wall just stops you. Level 2 keeps the identical move and adds a consequence,
## which is also what makes the fourth dimension feel real: the floor is a 4D
## object, and whether it exists under your feet depends on where you are along w.
## It is also the level where the mechanic is most legible, because the thing you
## must navigate IS the floor, and the floor is in every slice at every angle.
##
## The chasm is 4 m across - wide enough that it cannot be crossed by accident and
## reads unmistakably as a hole from the diorama camera, since the dark void shows
## straight through it against the light floor bands.

const CHASM_Z_MIN := -5.0
const CHASM_Z_MAX := -1.0
const BRIDGE_BAND := 1 # w -6..-4, centre -5.
const GOAL_Z := -6.5


func _ready() -> void:
	highlight_w = band_center_w(BRIDGE_BAND)
	highlight_color = Color(0.35, 0.85, 0.9, 0.85) # ramdev_cyan, the bridge's own colour.

	var bridged: Array = [Vector2(PLATFORM_Z_MIN, PLATFORM_Z_MAX)]
	var split: Array = [Vector2(PLATFORM_Z_MIN, CHASM_Z_MIN), Vector2(CHASM_Z_MAX, PLATFORM_Z_MAX)]
	for band_index in BAND_COUNT:
		var is_bridge: bool = band_index == BRIDGE_BAND
		var texture: Texture3D = TextureBridge if is_bridge else default_band_texture(band_index)
		build_floor_band(band_index, texture, bridged if is_bridge else split)

	build_rails()
	build_goal(GOAL_Z, band_center_w(BRIDGE_BAND))
