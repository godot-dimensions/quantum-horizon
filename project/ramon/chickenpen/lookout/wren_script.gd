extends RefCounted

## NO class_name - preloaded by path, like the professor's and the range master's.

## Wren's dialogue. She keeps the Lookout: fire watch on paper, everything else in practice.
## Practical, warm, a little dry. Short lines, full stops and commas, no dashes (Ramon: dash
## clauses read as machine-written).
##
## BUILT FRESH EACH TIME YOU SPEAK TO HER, from where the story is (lookout_story_4d.gd's
## flags) and what the journal still lacks, so her tips are always about something you have
## not got. The dialogue player itself only ever sees a plain dictionary, as for everyone.

const START_MEET := "hello"
const START_AGAIN := "again"
const START_BALLOON := "balloon"
const START_AFTER_RIDE := "after_ride"
const START_DONE := "done"


## The script for now. [param tip] is a line about something still missing from the book.
static func nodes(tip: String, can_ride: bool) -> Dictionary:
	var again_choices: Array = [
		{"text": "Any tips?", "goto": "tip"},
		{"text": "Tell me about W again.", "goto": "along_w_again"},
	]
	if can_ride:
		again_choices.append({"text": "Can we take the balloon up?", "goto": "balloon_again"})
	again_choices.append({"text": "Just passing.", "goto": "bye", "leave": true})
	return {

"hello": {
	"speaker": "Wren",
	"lines": [
		"Oh, hello. Mind the ladder, it's slippery.",
		"I'm Wren. I keep the lookout. Fire watch, officially. Mostly I watch everything else.",
		"Everything on this farm is in my journal. And a few things that live next to it, out along W.",
	],
	"choices": [
		{"text": "Out along W?", "goto": "along_w"},
		{"text": "Can I go up?", "goto": "camera"},
	],
},

"along_w": {
	"speaker": "Wren",
	"lines": [
		"You know how you can step ana and kata. Things live out there too, just off the slice. You walk right past them.",
		"From up there, with this, you don't have to walk anywhere.",
	],
	"goto": "camera",
},

"camera": {
	"speaker": "Wren",
	"lines": [
		"Here. Take my camera. Z puts it to your eye, up on the deck or in my balloon. The ring on the lens doesn't focus near and far. It focuses in W.",
		"Fill the journal for me. Every animal, doing every thing it does. J to read it.",
	],
	"do": "give_camera",
	"do_on_line": 0,
	"choices": [
		{"text": "I'll go up.", "goto": "go_up", "leave": true},
		{"text": "Anything I should look for?", "goto": "first_tips"},
	],
},

"first_tips": {
	"speaker": "Wren",
	"lines": [
		"The starlings are up all evening. When the hawk dives, they open round it. Nobody's got that picture.",
		"And something sits in an old dead tree north of the tower. I hear it at night. I've never seen it.",
	],
	"goto": "go_up",
},

"go_up": {
	"speaker": "Wren",
	"lines": ["Go on. I'll be on the radio."],
	"goto": "",
},

"again": {
	"speaker": "Wren",
	"lines": ["How's the book coming?"],
	"choices": again_choices,
},

"tip": {
	"speaker": "Wren",
	"lines": [tip],
	"goto": "again_short",
},

"again_short": {
	"speaker": "Wren",
	"lines": [],
	"choices": again_choices,
},

"along_w_again": {
	"speaker": "Wren",
	"lines": [
		"The ring slides your picture along W without moving you. Things off your slice are thinner, then gone.",
		"Watch the scale at the bottom of the viewfinder. Every mark is something out there. Put the needle on it.",
	],
	"goto": "again_short",
},

"balloon": {
	"speaker": "Wren",
	"lines": [
		"You've an eye for it. I want to show you something.",
		"She's my balloon. She goes up on her rope and drifts where the wind says, and the wind out here blows a little ana.",
		"One roll of thirty six, no reloads up there. X to whistle, if you want something to look up. B any time you want to go up. Ready?",
	],
	"choices": [
		{"text": "Let's go.", "goto": "board"},
		{"text": "Not yet.", "goto": "bye", "leave": true},
	],
},

"balloon_again": {
	"speaker": "Wren",
	"lines": ["She's ready when you are. Same as before, one roll."],
	"choices": [
		{"text": "Let's go.", "goto": "board"},
		{"text": "Not yet.", "goto": "bye", "leave": true},
	],
},

"board": {
	"speaker": "Wren",
	"lines": ["In you get. Hold on to something."],
	"do": "board",
	"do_on_line": 0,
	"goto": "",
},

"after_ride": {
	"speaker": "Wren",
	"lines": [
		"Well? Did you see the water out there? I've only ever seen it from the basket.",
		"Whatever's in it, I want a picture.",
	],
	"goto": "again_short",
},

"done": {
	"speaker": "Wren",
	"lines": [
		"Every page. Every one.",
		"I'll have to go and find more things.",
	],
	"goto": "again_short",
},

"bye": {
	"speaker": "Wren",
	"lines": ["Mind the ladder."],
	"goto": "",
},

	}
