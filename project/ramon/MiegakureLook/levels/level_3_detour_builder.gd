extends "res://ramon/MiegakureLook/scripts/miegakure_level_base.gd"
## LEVEL 3 - "The Detour". Both obstacles, and the first level that needs a ROUTE
## through w rather than a single trip to one lane.
##
## A wall first, gapped only in the yellow lane at w = -5. A chasm behind it,
## bridged only in the cyan lane at w = +5. So the solution is: rotate, go to
## yellow, rotate back, walk past the wall - then rotate again, travel the other
## way along w to cyan, rotate back, and cross.
##
## WHAT THIS TEACHES THAT 1 AND 2 CANNOT. In both earlier levels w is effectively
## a one-way trip to "the coloured lane", and a player can clear them while still
## believing the fourth dimension has one interesting place in it. Here the second
## leg runs the OPPOSITE way along w and is ten metres rather than six, so the
## lane you needed a moment ago is the wrong answer now and you have to travel
## back through the ones you already visited. w stops being a switch and starts
## being an axis you navigate.
##
## The two lanes are coloured after their own obstacles - yellow lane for the
## yellow wall, cyan lane for the cyan bridge - so both answers are visible
## simultaneously from the rotated view and the player has to work out which
## belongs to which. Guessing wrong is cheap and informative: take cyan first and
## the wall simply stops you, which is the level explaining itself.
##
## Note for anyone re-timing this: at 90 degrees "forward" moves toward -w, so the
## second leg (-5 to +5) is walked with BACK, not forward. That reversal is a
## deliberate part of the lesson.

const WALL_Z := 2.0
const GATE_BAND := 1 # w -6..-4, centre -5.
const CHASM_Z_MIN := -5.0
const CHASM_Z_MAX := -1.0
const BRIDGE_BAND := 6 # w +4..+6, centre +5.
const GOAL_Z := -6.5


func _ready() -> void:
	# The gauge highlights the bridge, not the gate: the gate is the obvious first
	# problem and is solved by the lane you can see, whereas the chasm is the one
	# that drops you. Highlighting the survivable answer is the more useful hint.
	highlight_w = band_center_w(BRIDGE_BAND)
	highlight_color = Color(0.35, 0.85, 0.9, 0.85) # ramdev_cyan, the bridge's own colour.

	var bridged: Array = [Vector2(PLATFORM_Z_MIN, PLATFORM_Z_MAX)]
	var split: Array = [Vector2(PLATFORM_Z_MIN, CHASM_Z_MIN), Vector2(CHASM_Z_MAX, PLATFORM_Z_MAX)]

	for band_index in BAND_COUNT:
		var is_bridge: bool = band_index == BRIDGE_BAND
		var is_gate: bool = band_index == GATE_BAND
		var texture: Texture3D = default_band_texture(band_index)
		if is_bridge:
			texture = TextureBridge
		elif is_gate:
			texture = TextureGate
		build_floor_band(band_index, texture, bridged if is_bridge else split)
		if not is_gate:
			build_wall_band(band_index, WALL_Z)

	build_rails()
	build_goal(GOAL_Z, band_center_w(BRIDGE_BAND))
