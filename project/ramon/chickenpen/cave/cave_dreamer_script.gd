extends RefCounted

## NO class_name, for the reason professor_script.gd gives.

## The dreamer in the far room.
##
## FROM THE LORE, NOT OUT OF IT. Lovecraft's Azathoth is the blind idiot god at the centre of
## everything, a nuclear chaos that does not think, lulled forever by the thin piping of
## flutes and the beating of drums, with a messenger who is its will and its face; later
## tellings make the world its dream, gone the moment it wakes. What is taken: a mind too
## large to know itself, a small waking part of it that does the talking, the music that
## keeps it under, the dream that is everything - the cave, the pen, the player. What is
## left: the name, and anything cosmic-horror about it being evil. It is not unkind. It is
## only very large.
##
## Ramon, 28 Sept: keep how it talks; let it say that only a sliver of its mind is awake
## and speaking, that the rest is a mystery even to that sliver, that it is the dreamer, the
## dream and every incarnation in it, the player among them; let it say it could end every
## dream, and go red, and then ask whether that frightened you - it was not meant to.
##
## TRUE WHERE IT CAN BE CHECKED. What it says of the cube is what Hale would confirm (4,096
## points, every blow re-works all of them - cave_miner_script.gd).
##
## ITS MOOD IS IN THE SCRIPT: "do": "warn" turns the core red, "calm" back to blue, and a
## "do_on_line" holds the change until that line has been said - which is how the red
## outlasts the threat into the next line. "leave_dream" is the way out: a flash, and you
## wake in front of the cave (pen_dream_wake_4d.gd). Same caps as the others: four replies
## at most, and a way out of every menu.

const START: String = "intro"

const NODES: Dictionary = {

"intro": {
	"speaker": "???",
	"do": "calm",
	"lines": [
		"...a thin one. You came in sideways.",
		"Most of you only ever meet one slice of me. You walked along it instead.",
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
		"You have been striking my thought.",
		"Every blow, the drums falter. I stir. You do not want me to stir, thin one. Nothing does.",
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
	"lines": ["There is always something else. That is most of what I am."],
	"choices": [
		{"text": "Where is this?", "goto": "topic_where"},
		{"text": "What is that music?", "goto": "topic_music"},
		{"text": "Something darker.", "goto": "menu_three"},
		{"text": "I'll go.", "goto": "bye", "leave": true},
	],
},

"menu_three": {
	"speaker": "???",
	"do": "calm",
	"lines": ["Darker. Yes. You would ask that."],
	"choices": [
		{"text": "Who am I, to you?", "goto": "topic_you"},
		{"text": "What if you woke up?", "goto": "topic_wake"},
		{"text": "Could you end all this?", "goto": "topic_end"},
		{"text": "Back.", "goto": "menu_two"},
	],
},

"topic_what": {
	"speaker": "???",
	"do": "calm",
	"instead": "topic_what_again",
	"lines": [
		"What speaks to you is a sliver of me that happens to be awake. A candle held up in a house with no walls.",
		"The rest does not think. It is what thinking happens in. Even this sliver cannot see where it ends, or what it wants.",
		"But this much the sliver knows: I am the one dreaming, and the dream, and every shape the dream takes on.",
	],
	"topic": true,
	"goto": "menu",
},

"topic_cube": {
	"speaker": "???",
	"do": "calm",
	"instead": "topic_cube_again",
	"lines": [
		"A thought that settled, and hardened, and forgot it was a thought. Four thousand and ninety-six points of it. Your people keep counting.",
		"Strike it and all of it is thought again, every point, not only the one you hit. I feel it as you would feel a word said wrong.",
	],
	"topic": true,
	"goto": "menu",
},

"topic_where": {
	"speaker": "???",
	"do": "calm",
	"instead": "topic_where_again",
	"lines": [
		"Beside the room with the cube, in the direction you do not look.",
		"Everything is beside something in that direction. You are the first in a long while to turn and see it.",
	],
	"topic": true,
	"goto": "menu_two",
},

"topic_music": {
	"speaker": "???",
	"do": "calm",
	"instead": "topic_music_again",
	"lines": [
		"It is not for you. Somewhere, always, something is playing - a pipe, a drum, a hum in the rock - so that I stay under.",
		"Every note of it is a lullaby. If you ever hear it stop, sing.",
	],
	"topic": true,
	"goto": "menu_two",
},

"topic_you": {
	"speaker": "???",
	"do": "calm",
	"instead": "topic_you_again",
	"lines": [
		"You are one of the ways I have of looking at myself. The hill is another. So is the chicken you chased this morning.",
		"You think you walked down here. I think I turned to look, and you were what the looking was made of.",
	],
	"topic": true,
	"goto": "menu_three",
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
	"goto": "menu_three",
},

## The threat, and after it the red stays - through your step back and the first line of
## what it says next - before it calms.
"topic_end": {
	"speaker": "???",
	"do": "warn",
	"instead": "topic_end_again",
	"lines": [
		"I could let go. Of all of it. Every dream at once, and no one left over to have dreamed them.",
		"Not an ending. An ending needs someone to notice it.",
	],
	"topic": true,
	"goto": "end_flinch",
},

"end_flinch": {
	"speaker": "You",
	"lines": ["(You take a step back.)"],
	"goto": "end_after",
},

"end_after": {
	"speaker": "???",
	"do": "calm",
	"do_on_line": 0,
	"lines": [
		"Did that frighten you? It was not meant to. It is only true, the way the edge of a cliff is true.",
		"What I intend is what everything intends: to go on finding out what it is. I cannot do that without you. Why would I end the looking?",
	],
	"goto": "menu_three",
},

"topic_what_again": {
	"speaker": "???",
	"do": "calm",
	"lines": ["The awake part of something much larger. Larger than it knows."],
	"goto": "menu",
},

"topic_cube_again": {
	"speaker": "???",
	"do": "calm",
	"lines": ["A thought that forgot it was one. Every point of it, every time."],
	"goto": "menu",
},

"topic_where_again": {
	"speaker": "???",
	"do": "calm",
	"lines": ["Beside. Along. Turn back and you are home."],
	"goto": "menu_two",
},

"topic_music_again": {
	"speaker": "???",
	"do": "calm",
	"lines": ["A lullaby. Keep it going."],
	"goto": "menu_two",
},

"topic_you_again": {
	"speaker": "???",
	"do": "calm",
	"lines": ["One of my eyes. Look well."],
	"goto": "menu_three",
},

"topic_wake_again": {
	"speaker": "???",
	"do": "warn",
	"lines": ["Nothing. Walk softly."],
	"goto": "menu_three",
},

"topic_end_again": {
	"speaker": "???",
	"do": "calm",
	"lines": ["I could. I will not. Asking twice does not change which is true."],
	"goto": "menu_three",
},

"bye": {
	"speaker": "???",
	"do": "leave_dream",
	"do_on_line": 0,
	"lines": ["Go gently, thin one. Wake."],
},

}
