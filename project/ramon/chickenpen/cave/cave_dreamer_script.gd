extends RefCounted

## NO class_name, for the reason professor_script.gd gives.

## The dreamer in the far room. Loosely the idiot-god of the lore deck - a presence that
## everything here is being dreamed by, which must not wake - and nothing more of it than
## that (Ramon, 28 Sept: "most of the text does not apply").
##
## IT DOES NOT EXPLAIN ITSELF. The professor explains, Hale reports; this answers sideways,
## and every true thing it says about the cube is one Hale would confirm - the lattice is
## 4,096 points, and every blow does re-work all of them (cave_miner_script.gd). The
## mystery is in whose thought that is, not in invented facts.
##
## WARM UNTIL IT IS NOT. Its lines are calm, and the core burns blue; the few that are
## warnings carry "do": "warn" and the core goes red for them ("do": "calm" brings it
## back). Same caps as the others: four replies at most, a way out of every menu.

const START: String = "intro"

const NODES: Dictionary = {

"intro": {
	"speaker": "???",
	"do": "calm",
	"lines": [
		"...a thin one. You came in sideways.",
		"Most of you only ever see one slice of me. You found the way along.",
	],
	"choices": [
		{"text": "What are you?", "goto": "topic_what"},
		{"text": "What is the cube?", "goto": "topic_cube"},
		{"text": "Something else.", "goto": "menu_two"},
		{"text": "I'll go.", "goto": "bye", "leave": true},
	],
},

"greet_after_strike": {
	"speaker": "???",
	"do": "warn",
	"lines": [
		"You have been breaking my thought.",
		"Every blow, I nearly wake. You do not want me awake, small one. Nothing does.",
	],
	"goto": "menu",
},

"menu": {
	"speaker": "???",
	"do": "calm",
	"lines": ["Ask."],
	"choices": [
		{"text": "What are you?", "goto": "topic_what"},
		{"text": "What is the cube?", "goto": "topic_cube"},
		{"text": "Something else.", "goto": "menu_two"},
		{"text": "I'll go.", "goto": "bye", "leave": true},
	],
},

"menu_two": {
	"speaker": "???",
	"do": "calm",
	"lines": ["There is always something else."],
	"choices": [
		{"text": "Where is this?", "goto": "topic_where"},
		{"text": "What if you woke up?", "goto": "topic_wake"},
		{"text": "Back.", "goto": "menu"},
		{"text": "I'll go.", "goto": "bye", "leave": true},
	],
},

"topic_what": {
	"speaker": "???",
	"do": "calm",
	"instead": "topic_what_again",
	"lines": [
		"The one this is being dreamed by. The hill. The field. The birds in it. You.",
		"Do not be alarmed. It is a good dream. Mostly.",
	],
	"topic": true,
	"goto": "menu",
},

"topic_cube": {
	"speaker": "???",
	"do": "calm",
	"instead": "topic_cube_again",
	"lines": [
		"A thought of mine that settled. Four thousand and ninety-six points of it. Your people keep counting.",
		"Strike it and all of it is thought again, every point, not just the one you hit. I feel each time.",
	],
	"topic": true,
	"goto": "menu",
},

"topic_where": {
	"speaker": "???",
	"do": "calm",
	"instead": "topic_where_again",
	"lines": [
		"Beside the room with the cube. In the direction you do not look.",
		"You turned your slice and walked. Few do. Turn it back, and the way home is where you left it.",
	],
	"topic": true,
	"goto": "menu_two",
},

"topic_wake": {
	"speaker": "???",
	"do": "warn",
	"instead": "topic_wake_again",
	"lines": [
		"Then there is no one dreaming. And nothing dreamed.",
		"So walk softly. And put the pick away when you are near my thought.",
	],
	"topic": true,
	"goto": "menu_two",
},

"topic_what_again": {
	"speaker": "???",
	"do": "calm",
	"lines": ["The one this is dreamed by. Still. For now."],
	"goto": "menu",
},

"topic_cube_again": {
	"speaker": "???",
	"do": "calm",
	"lines": ["A thought that settled. Every point of it, every time."],
	"goto": "menu",
},

"topic_where_again": {
	"speaker": "???",
	"do": "calm",
	"lines": ["Beside. Along. Turn back and you are home."],
	"goto": "menu_two",
},

"topic_wake_again": {
	"speaker": "???",
	"do": "warn",
	"lines": ["Nothing. Walk softly."],
	"goto": "menu_two",
},

"bye": {
	"speaker": "???",
	"do": "calm",
	"lines": ["Go gently. Keep to your slice."],
	"goto_if_asked": "menu",
},

}
