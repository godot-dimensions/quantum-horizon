extends RefCounted

## The grass's looks, by number: each a set of the Grass node's exports (pen_grass_4d.gd's
## apply_preset, the grass panel's buttons, O). BASE names everything a look sets; each look
## names only what it changes from BASE, so reworking one look never moves another.
##
## 1, PASTURE: grazed grass. Ramon, 3 Oct: "option one could be the shorter grazed grass .. i
##    would start from scratch in terms of the grass design parameters. probably less thick,
##    more, and shorter, feel free to reduce polycount, we dont need it for such short grass".
##    16 cm, thinner than either look before it and closer together than any, two bends to a
##    blade near you and one further out; a breeze barely moves it, it shimmers. (It was
##    "Meadow", 38 cm, saved as preset 1 on 2 Oct: that look is BASE now.)
## 2, HAY MEADOW: "longer grass, thinner grass and more grass, yes more, and improve the wind
##    animation, make it flow like on barley fields, even though its not". Long thin blades
##    closer together, and the wind in long soft crests that roll downwind through it, in sets,
##    the tips catching the light as each crest lays them over. First called Barley; Ramon, 3
##    Oct: "i wouldn't call it barley ... its more like longer beautiful grass" - a hay meadow,
##    the long grass left uncut till summer.

## The 2 Oct meadow, every value a look sets.
const BASE := {
	"spacing": 0.075,
	"spacing_far": 0.27,
	"spacing_from": 3.0,
	"band_radii": [5.0, 10.0, 18.0, 28.0],
	"band_vertices": [11, 9, 7, 5, 3],
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
}

const PRESETS := {
	1: {
		"name": "Pasture",
		# Short, thin, many, and cheap: two bends are plenty at 16 cm, one further out.
		"blade_height": 0.16,
		"blade_width": 0.006,
		"taper": 0.85,
		"spacing": 0.045,
		"spacing_far": 0.2,
		"spacing_from": 2.0,
		"band_vertices": [5, 5, 3, 3, 3],
		"min_pixels": 0.7,
		# Grazed: small patches a little taller or shorter, not tussocks.
		"clump_size": 0.7,
		# Short grass hardly bends; it shimmers as the gusts pass.
		"gustiness": 0.45,
		"bend_max": 0.24,
		"stiffness": 34.0,
		"sheen": 0.32,
	},
	2: {
		"name": "Hay meadow",
		# Longer, thinner, and more of it; one bend fewer to a blade than BASE, in every band
		# (Ramon, 3 Oct: "the general style is low poly, we only need enough to make sure it can
		# bend and not look off").
		"band_vertices": [9, 7, 5, 3, 3],
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
