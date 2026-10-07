extends RefCounted

## NO class_name - preloaded by path, like the professor's.

## The camp guide's few lines (Ramon, 7 Oct: "keep his dialogue short ... he must tell you to stare ahead aligned
## with the path and rotate the slice"). He stands on the farm's slice where the camp's path gives out; the camp
## is 2.5 m kata, right in front of him. Short lines, full stops and commas, no dashes.

const START: String = "how"

const NODES: Dictionary = {

"how": {
	"speaker": "Camp Scout",
	"lines": [
		"The camp is right in front of you. Just not in your slice.",
		"Look straight ahead, down the path. Then hold the right mouse button and turn your slice.",
		"When most of the camp shows, press V.",
	],
	"choices": [
		{"text": "Thanks.", "goto": "", "leave": true},
	],
},

"greet_again": {
	"speaker": "Camp Scout",
	"lines": ["Straight down the path. Then turn your slice."],
	"choices": [
		{"text": "Right.", "goto": "", "leave": true},
	],
},

}
