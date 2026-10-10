extends RefCounted

## NO class_name - preloaded by path, like the camp guide's.

## Tamsin's twin by the basket, 5 m ana of the stake (Ramon, 10 Oct, item 20: "Place a second instance of the same NPC
## beside the balloon ... When the player approaches him, he should offer the ride"). She takes the 2 azoth and you go
## up; the talk driver (discovery/pen_balloon_crew_talk_4d.gd, role "ride") picks the opening by what you carry, and
## the "pay" effect takes the azoth (once) and starts the ride when the box closes. His lines, near enough; full stops
## and commas, no dashes.

const START: String = "offer"

const NODES: Dictionary = {

"short": {
	"speaker": "Tamsin",
	"lines": ["The ride costs 2 azoth, mate. Come back when you've got enough."],
	"choices": [
		{"text": "Okay.", "goto": ""},
	],
},

"offer": {
	"speaker": "Tamsin",
	"lines": ["Fancy a balloon ride? It'll cost you 2 azoth."],
	"choices": [
		{"text": "Yes. Pay 2 azoth.", "goto": "paid"},
		{"text": "No. Maybe later.", "goto": "later"},
	],
},

"paid": {
	"speaker": "Tamsin",
	"lines": ["Lovely. Climb in and hold on to the rail."],
	"do": "pay",
	"goto": "",
},

"later": {
	"speaker": "Tamsin",
	"lines": ["No rush. She'll be right here."],
	"goto": "",
},

"ready": {
	"speaker": "Tamsin",
	"lines": ["You've paid, mate. Climb in."],
	"do": "board",
	"goto": "",
},

}
