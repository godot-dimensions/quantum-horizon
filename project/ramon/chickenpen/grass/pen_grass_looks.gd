extends RefCounted

## The grass's looks, by number: each a set of the Grass node's exports (pen_grass_4d.gd's
## apply_preset, the grass panel's buttons, O). Look 1 names everything a look sets; any other
## look names only what it changes from 1.
##
## 1, MEADOW: the field as it was on 2 Oct when Ramon said "save this as preset 1" - 38 cm,
##    sap green with a deeper and a brighter offset, gusts in bands across the wind.
## 2, HAY MEADOW: "longer grass, thinner grass and more grass, yes more, and improve the wind
##    animation, make it flow like on barley fields, even though its not". Long thin blades
##    closer together, and the wind in long soft crests that roll downwind through it, in sets,
##    the tips catching the light as each crest lays them over. First called Barley; Ramon, 3
##    Oct: "i wouldn't call it barley ... its more like longer beautiful grass" - a hay meadow,
##    the long grass left uncut till summer.

const PRESETS := {
	1: {
		"name": "Meadow",
		"spacing": 0.075,
		"spacing_far": 0.27,
		"spacing_from": 3.0,
		"blade_height": 0.38,
		"blade_width": 0.011,
		"taper": 0.5,
		"min_pixels": 0.8,
		"clump_size": 1.3,
		"colour_root": Color(0.11, 0.17, 0.07),
		"colour_base": Color(0.31, 0.49, 0.16),
		"colour_lush": Color(0.27, 0.47, 0.18),
		"colour_dry": Color(0.47, 0.44, 0.22),
		"colour_tip": Color(0.48, 0.62, 0.26),
		"region_deep": Color(0.21, 0.40, 0.19),
		"region_bright": Color(0.40, 0.56, 0.17),
		"region_size": 13.0,
		"region_share": 0.25,
		"region_strength": 1.0,
		"hue_jitter": 0.05,
		"shade": 0.7,
		"toward_ground": 0.18,
		"saturation": 1.45,
		"wind_speed": 3.0,
		"gustiness": 0.55,
		"gust_length": 7.0,
		"gust_width": 18.0,
		"bend_max": 0.42,
		"stiffness": 30.0,
		"sheen": 0.2,
		"wave_strength": 0.0,
		"wave_length": 8.0,
		"wave_speed": 3.2,
		"wave_width": 22.0,
	},
	2: {
		"name": "Hay meadow",
		# Longer, thinner, and more of it.
		"blade_height": 0.62,
		"blade_width": 0.0075,
		"taper": 0.6,
		"spacing": 0.058,
		"spacing_far": 0.21,
		"min_pixels": 0.7,
		"clump_size": 1.6,
		# The wind as on barley: long crests, a softer, more even blow under them, less of each
		# stalk's own rocking, and the light on the tips as a crest lays them over.
		"wind_speed": 3.4,
		"gustiness": 0.3,
		"bend_max": 0.55,
		"stiffness": 26.0,
		"sheen": 0.45,
		"wave_strength": 1.0,
		"wave_length": 8.0,
		"wave_speed": 3.2,
		"wave_width": 22.0,
	},
}
