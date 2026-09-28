extends RefCounted

## NO class_name - preloaded by path, like the professor's (see its header).

## The range master's dialogue: one offer, as Ramon wrote it. "You look like you got some
## experience, how about I show you a more challenging shooting range instead."
##
## WHAT HE SAYS ABOUT IT IS TRUE OF IT. Targets spread across slices, and the gallery's own
## black stalker - a 2001 slab that spawns far off on another slice and comes for you
## (black_stalker_spawner_ramon.gd) - which is why he finds the one in the hill "funny".
##
## ONE QUESTION AND A WAY OUT. He is a door, not a character to interview - the range
## here is for show, and his whole job is to send you to the real one. Saying yes ends
## the conversation and the trip starts (pen_range_talk_4d.gd, pen_range_trip_4d.gd);
## saying no leaves the offer standing for next time.

const START: String = "offer"

const NODES: Dictionary = {

"offer": {
	"speaker": "Range Master",
	"lines": [
		"You look like you've got some experience.",
		"This lot's for show - boards and sandbags. How about I show you a more challenging shooting range instead?",
	],
	"choices": [
		{"text": "Show me.", "goto": "off_you_go"},
		{"text": "What's so challenging about it?", "goto": "what"},
		{"text": "Maybe later.", "goto": "later", "leave": true},
	],
},

"what": {
	"speaker": "Range Master",
	"lines": [
		"Targets that aren't on your slice until you turn to them. And a black slab, out past the floor, that comes for you. Don't let it reach you.",
		"Funny. They've got one just like it in the hill. H brings you back here when you've had enough.",
	],
	"choices": [
		{"text": "Show me.", "goto": "off_you_go"},
		{"text": "Maybe later.", "goto": "later", "leave": true},
	],
},

"off_you_go": {
	"speaker": "Range Master",
	"lines": ["Good. Mind your footing. And your slice."],
	"do": "go_range",
	"do_on_line": 0,
	"goto": "",
},

"later": {
	"speaker": "Range Master",
	"lines": ["Offer stands. I'll be here."],
	"goto_if_asked": "offer",
},

"greet_again": {
	"speaker": "Range Master",
	"lines": ["Back for another go?"],
	"choices": [
		{"text": "Show me.", "goto": "off_you_go"},
		{"text": "Not yet.", "goto": "later", "leave": true},
	],
},

}
