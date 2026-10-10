extends RefCounted

## NO class_name: preloaded by path, like the camp guide's and the balloon crew's.

## The Dream Shifter's words (discovery/dream_shifter/pen_dream_shifter_4d.gd). Ramon, 9 Oct: "keep it extremely short
## and punchy ... Player: 'Whoa... what's this orb?' Orb: 'I am the Dream Shifter.' Orb: 'Do you want to see what this
## world is really made of?' Orb: 'Check it out.'" Four lines and one choice, then it shifts the world itself
## (the "shift" effect: discovery/dream_shifter/pen_look_guide_4d.gd).
##
## The question follows the look you are in: in the art look it offers what the world is made of (the dev look), in the
## dev look (the pen opens in it) what it could become (the art). {question} is filled in by fill().
## Full stops and commas, no dashes (feedback_no_em_dashes).

const START: String = "hello"

const NODES: Dictionary = {

"hello": {
	"speaker": "You",
	"lines": ["Whoa. What is this orb?"],
	"goto": "orb",
},

"orb": {
	"speaker": "Dream Shifter",
	"lines": [
		"I am the Dream Shifter.",
		"{question}",
	],
	"choices": [
		{"text": "Show me.", "goto": "shift"},
		{"text": "Not now.", "goto": "later"},
	],
},

"shift": {
	"speaker": "Dream Shifter",
	"lines": ["Check it out."],
	"do": "shift",
	"goto": "",
},

"later": {
	"speaker": "Dream Shifter",
	"lines": ["I will be here. The world will wait."],
	"goto": "",
},

"again": {
	"speaker": "Dream Shifter",
	"lines": ["One world, two dreams of it. I switches between them, whenever you like."],
	"choices": [
		{"text": "Shift it again.", "goto": "shift"},
		{"text": "Tell me again.", "goto": "explain"},
		{"text": "Thanks.", "goto": ""},
	],
},

"explain": {
	"speaker": "Dream Shifter",
	"lines": ["Watch."],
	"do": "explain",
	"goto": "",
},

}


## {question} for the look you are in now: [param dev] true when the dev look is showing.
static func question(dev: bool) -> String:
	if dev:
		return "Do you want to see what this world could become?"
	return "Do you want to see what this world is really made of?"
