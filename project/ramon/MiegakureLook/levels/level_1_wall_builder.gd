extends "res://ramon/MiegakureLook/scripts/miegakure_level_base.gd"
## LEVEL 1 - "The Wall Around the Fourth". The teaching level: one obstacle, one
## rotation out, one rotation back.
##
## A wall spans the whole platform and blocks the only path forward. It is solid
## at every w except one 2 m band. Rotate 90 degrees so the ground you see is
## x-by-w instead of x-by-z, walk along w to the yellow lane, rotate back, and
## walk through where the wall no longer is.
##
## This is the technical paper's own worked example, and it is the level this
## folder started from. What is new here is the banded floor. In the original the
## floor was uniform grey, and because the wall is thin along z - and collision
## stops you 0.5 m short of it - the wall is NEVER in the constant-z slice you
## rotate into. The rotated view was a bare grey diamond with nothing on it, and
## the player was asked to walk to a specific w while blind. The yellow lane is
## the wall's own colour, so "the way through the yellow wall is the yellow lane"
## is learnable without a word of text.
##
## The floor is unbroken everywhere here: level 1 should not be able to kill you.
## The rails stop you leaving sideways, so the only thing to work out is the wall.

const WALL_Z := 2.0
const GATE_BAND := 1 # w -6..-4, centre -5.
const GOAL_Z := -6.0


func _ready() -> void:
	highlight_w = band_center_w(GATE_BAND)
	highlight_color = Color(0.886, 0.949, 0.322, 0.85) # ramdev_yellow, the wall's own colour.

	var full_floor: Array = [Vector2(PLATFORM_Z_MIN, PLATFORM_Z_MAX)]
	for band_index in BAND_COUNT:
		var texture: Texture3D = TextureGate if band_index == GATE_BAND else default_band_texture(band_index)
		build_floor_band(band_index, texture, full_floor)
		if band_index != GATE_BAND:
			build_wall_band(band_index, WALL_Z)

	build_rails()
	build_goal(GOAL_Z, band_center_w(GATE_BAND))
