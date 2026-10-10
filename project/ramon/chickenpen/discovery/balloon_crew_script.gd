extends RefCounted

## NO class_name - preloaded by path, like the camp guide's.

## The balloon's ground crew (discovery/pen_balloon_crew_4d.gd), at the fire where the balloon was moored. Ramon,
## 9 Oct: "simple and short dialogue, where the balloon is in W above or under him". The balloon hovers 5 m ana of its
## stake and 3.5 m up (lookout/balloon_4d.gd parked); she tells you so and how to bring it in, and, asked, where the
## airship fleet is (discovery/pen_zeppelins_4d.gd: one in the farm's slice, four more 9 m ana). Short lines, full
## stops and commas, no dashes.

const START: String = "intro"

const NODES: Dictionary = {

"intro": {
	"speaker": "Tamsin",
	"lines": [
		"Looking for Wren's balloon? It is right above me.",
		"Not up in the sky. Along W. The wind pushed it five metres ana last night.",
		"Its rope still comes down to my stake. Turn your slice until you see the basket, then press V.",
	],
	"choices": [
		{"text": "And that airship out there?", "goto": "ships"},
		{"text": "Thanks.", "goto": "", "leave": true},
	],
},

"ships": {
	"speaker": "Tamsin",
	"lines": [
		"That one is the only one in our slice. The rest of the fleet sails about nine metres ana.",
		"Step that way and look past the tower.",
	],
	"choices": [
		{"text": "Thanks.", "goto": "", "leave": true},
	],
},

"again": {
	"speaker": "Tamsin",
	"lines": ["Five metres ana, right above the stake. Turn your slice and look for the basket."],
	"choices": [
		{"text": "And the airships?", "goto": "ships"},
		{"text": "Right.", "goto": "", "leave": true},
	],
},

"found": {
	"speaker": "Tamsin",
	"lines": ["You found it. Go on, climb in. Wren will be thrilled."],
	"choices": [
		{"text": "On my way.", "goto": "", "leave": true},
	],
},

}
