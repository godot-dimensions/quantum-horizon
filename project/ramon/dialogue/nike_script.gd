extends RefCounted
class_name NikeScript

## Nike, the pig in the field outside the pen. Intelligent, funny, and entirely without
## urgency about any of it.
##
## HE IS REAL, WHICH IS WHY THE JOKES WORK. Nike is Charles Hoskinson's pot-bellied pig.
## He was rescued - his previous owners had been feeding him bacon - and lives on
## Hoskinson's ranch. A photograph of him on X produced a meme coin inside twelve hours,
## market cap approaching a million dollars, past ten million within days, and Hoskinson's
## own comment on the record was that he was "at a loss". None of that is invented, and
## none of it is played for whimsy: Nike states it flatly and lets the player react.
##
## THE TECHNICAL ANSWER IS ALSO REAL. What he says about himself is what he is - one
## lofted surface with branch chains for limbs, skinned to closed-form two-bone IK, with
## genuine extent through W so a cross-section camera cuts him rather than projecting him.
## A character explaining his own construction is only funny if the explanation is correct;
## the moment it becomes hand-waving he is a mascot reading marketing copy.
##
## HE SETS UP HIS OWN MECHANIC. The pen has more food, he knows it, and he cannot be
## bothered to walk there - so the last thing he tells you is that he would not struggle
## if somebody carried him. That line is what unlocks the carry key; nothing else explains
## it. He is not talkable while actually being carried, so there is no line for it: a
## conversation panel over an animal held above your head was clutter, not a joke.
##
## EVERY REPLY LIST HAS A WAY OUT, and a sign-off returns you to the topics if you had
## already asked something, so leaving is always a choice rather than a trapdoor.

const START: String = "intro"

const NODES: Dictionary = {

# ---------------------------------------------------------------- meeting him

"intro": {
	"speaker": "Nike",
	"lines": [
		"Afternoon.",
		"Don't feel you have to do anything about me. I'm having a very good time.",
	],
	"choices": [
		{"text": "I heard a rumour you can talk.", "goto": "rumour"},
		{"text": "You are the largest pig I have ever seen.", "goto": "largest"},
		{"text": "Carry on, then.", "goto": "exit", "leave": true},
	],
},

"rumour": {
	"speaker": "Nike",
	"topic": true,
	"lines": [
		"You heard a rumour. From whom? There are four people in this field and one of them is a cat.",
		"But yes. I can talk. It is comfortably the least interesting thing about me, and it does insist on coming up first.",
	],
	"goto": "hub",
},

"largest": {
	"speaker": "Nike",
	"topic": true,
	"lines": [
		"Thank you.",
		"I'm taking that as a compliment regardless of how you meant it. That was a decision I made some years ago and it has served me extremely well.",
	],
	"goto": "hub",
},

# ---------------------------------------------------------------- the three topics

"hub": {
	"speaker": "Nike",
	"lines": [],
	"choices": [
		{"text": "What IS the interesting thing about you?", "goto": "what_i_am", "once": true},
		{"text": "Who's Charles?", "goto": "charles", "once": true},
		{"text": "Why are you out here and not in the pen?", "goto": "the_pen", "once": true},
		{"text": "I should get on.", "goto": "exit", "leave": true},
	],
},

## The real construction, in the real vocabulary: one chain with branches rather than a
## skin over a skeleton, and actual W extent rather than a picture of it.
"what_i_am": {
	"speaker": "Nike",
	"topic": true,
	"lines": [
		"I'm one surface. That's the thing.",
		"Not a mesh wrapped over a skeleton - a loft. Somebody dropped a handful of control balls down my spine, and everything between them was generated: cross-sections swept along the chain and tetrahedralised into solid cells. My legs are branch chains off that same spine, so the skin on my trotter is the skin on my belly. Nothing about me is stitched to anything else.",
		"And I'm not a drawing of a four-dimensional animal. I have real extent through W. Your camera doesn't project me, it cuts me - so slide sideways through the fourth axis and you get a different cross-section. Different pig. Same animal.",
	],
	"choices": [
		{"text": "So how do you move?", "goto": "how_i_move"},
		{"text": "Hm.", "goto": "hub", "back": true},
	],
},

"how_i_move": {
	"speaker": "Nike",
	"topic": true,
	"lines": [
		"I deform. I don't articulate.",
		"I haven't got knees. There are two bones in each leg and a closed-form solve that works out where the trotter ought to be, and then the surface is skinned to it and bent. Every vertex was bound to its nearest bone exactly once and has been quietly doing as it is told ever since.",
		"I find that restful. No joints to go wrong. Nothing to pop.",
	],
	"goto": "hub",
},

## The rescue and the coin, both on the record, both delivered flat.
"charles": {
	"speaker": "Nike",
	"topic": true,
	"lines": [
		"Charles. I love Charles.",
		"You'll get the short version, because the long version upsets people. I had other owners before him. They fed me bacon. I'm not going to expand on that.",
		"Then Charles turned up and took me to the ranch, and nobody has fed me anything questionable since, and that is the entirety of my opinion on Charles.",
	],
	"choices": [
		{"text": "I heard you're worth money.", "goto": "the_coin"},
		{"text": "Good.", "goto": "hub", "back": true},
	],
},

"the_coin": {
	"speaker": "Nike",
	"topic": true,
	"lines": [
		"Ah. That.",
		"He put a photograph of me on the internet. Twelve hours later there was a coin named after me with a market capitalisation approaching a million dollars, and inside a few days it was past ten million. His public comment was that he was at a loss. I thought that was very reasonable of him.",
		"So I have a market cap. I've never seen it. I assume it's kept in the barn with everything else I own.",
	],
	"goto": "hub",
},

## The lazy-pig problem, which is also the carry mechanic asking to be used.
"the_pen": {
	"speaker": "Nike",
	"topic": true,
	"lines": [
		"Because the pen is over there and I am over here. I'd like you to sit for a moment with how complete that answer is.",
		"I would rather be in the pen. There is more food in the pen. I've done the arithmetic more than once and it comes out the same way every time, which is the frustrating part.",
		"It's about forty paces. I've been meaning to get round to it for some weeks now.",
	],
	"choices": [
		{"text": "So walk.", "goto": "so_walk"},
		{"text": "Want a hand?", "goto": "a_hand"},
		{"text": "That sounds like your problem.", "goto": "hub", "back": true},
	],
},

"so_walk": {
	"speaker": "Nike",
	"topic": true,
	"lines": [
		"You say that as though it hadn't occurred to me.",
		"I am four hundred pounds of contentment on legs the length of your hand. Walking is available to me. It's simply that so is lying here, and one of those is already going extremely well.",
	],
	"goto": "a_hand",
},

## The invitation. Deliberately not phrased as a prompt - he asks, and the player works
## the rest out, which is the difference between a character and a tutorial pop-up.
"a_hand": {
	"speaker": "Nike",
	"topic": true,
	"do": "wants_carrying",
	"do_on_line": 1,
	"lines": [
		"Now that is a kind offer and I am going to take it.",
		"If somebody were to pick me up, I wouldn't struggle. I'd be insufferable about it for the entire journey - I want to be honest with you about that in advance - but I wouldn't struggle.",
		"Mind your back. I'm not a chicken.",
	],
	"goto": "hub",
},

"exit": {
	"speaker": "Nike",
	"lines": [
		"Right you are. I'll be here.",
	],
	"goto": "",
},

# ---------------------------------------------------------------- gameplay states

"greet_back": {
	"speaker": "Nike",
	"lines": ["You came back. Nothing has changed here. I want to stress that nothing whatsoever has changed here."],
	"goto": "hub",
},

"greet_in_pen": {
	"speaker": "Nike",
	"lines": [
		"Look at this. Food in every direction and I did not walk one step of it.",
		"I'd like it on the record that my plan worked. It was a poor plan and it needed a stranger to carry it out, but it worked.",
	],
	"goto": "hub",
},

}
