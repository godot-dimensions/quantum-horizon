extends RefCounted

## NO class_name - preloaded by path, like the camp guide's.

## The balloon's ground crew at her fire by the stake (discovery/pen_balloon_crew_4d.gd), in the farm's slice.
## 9 Oct she said the balloon was right above her, along W. 10 Oct (Ramon's walkthrough, items 18 and 20) the balloon
## sits on the ground 5 m ana of her stake, and she sells the rides: "Hey mate! There's a balloon hidden somewhere in W.
## Find it, and for just 2 Azoth, I'll take you for a ride." Her twin by the basket takes the money
## (discovery/balloon_ride_script.gd). Short lines, full stops and commas, no dashes.

const START: String = "intro"

const NODES: Dictionary = {

"intro": {
	"speaker": "Tamsin",
	"lines": [
		"Hey mate! There's a balloon hidden somewhere in W.",
		"Find it, and for just 2 azoth, I'll take you for a ride.",
	],
	"choices": [
		{"text": "Any idea where?", "goto": "hint"},
		{"text": "Deal.", "goto": ""},
	],
},

"hint": {
	"speaker": "Tamsin",
	"lines": [
		"Not far. A few steps ana of my stake, sitting on a patch of sand.",
		"Turn your slice until you can see it, then press V.",
	],
	"choices": [
		{"text": "Thanks.", "goto": ""},
	],
},

"again": {
	"speaker": "Tamsin",
	"lines": ["Found my balloon yet? It's a few steps ana of my stake."],
	"choices": [
		{"text": "Any idea where?", "goto": "hint"},
		{"text": "Not yet.", "goto": ""},
	],
},

"found": {
	"speaker": "Tamsin",
	"lines": ["You found it! I'm by the basket. 2 azoth and we're up."],
	"choices": [
		{"text": "On my way.", "goto": ""},
	],
},

"flown": {
	"speaker": "Tamsin",
	"lines": ["Good flight? Same price any time, mate."],
	"choices": [
		{"text": "Cheers.", "goto": ""},
	],
},

}
