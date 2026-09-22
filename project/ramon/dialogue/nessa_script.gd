extends RefCounted
class_name NessaScript

## Nessa, who has been pacing the same field for days looking for a coin that went
## sideways out of the world.
##
## Same shape as KeeperScript - see the header there for what a node is and what the
## fields do. Two characters, two files of writing, one dialogue system.
##
## THE JOKE SHE IS BUILT ON. She has been searching one patch of grass for days and has
## found a boot, a trowel, somebody's spectacles and a solid gold egg. She has not found
## the coin. Everything she says is straight; the comedy is entirely in the ratio.
##
## SHE ALREADY EXISTED. pen_searcher_4d.gd walks her and gave her a one-line mutter as
## you passed; this replaces the mutter with something you can answer.
##
## WHY SHE IS ORDINARY. The keeper is a lab-grown intelligence. If she were strange too,
## neither of them would be - a field where everybody is remarkable has nobody in it. She
## is a person with a job and a grievance, and that is what makes him land.
##
## THE COIN IS OFF-SLICE ON PURPOSE. It teaches the same lesson the chickens do, in one
## object, with a character standing next to it telling you plainly what to press.

const START: String = "intro"

const NODES: Dictionary = {

# ---------------------------------------------------------------- first meeting

"intro": {
	"speaker": "Nessa",
	"lines": [
		"Don't — don't walk there. Stand still a moment.",
		"I dropped a coin. Just here, about a yard from my boot. It did not land.",
		"It went sideways, and not a sideways I've got. It is under my boots right now and I cannot reach it.",
		"I wish I had one of those gauntlets he hands out. I'd have had it back on the first pass instead of the ninth.",
	],
	"choices": [
		{"text": "What kind of coin?", "goto": "coin_kind"},
		{"text": "I'll look for it.", "goto": "accept"},
		{"text": "Things don't fall out of the world.", "goto": "sceptic"},
		{"text": "Good luck with that.", "goto": "brush_off", "leave": true},
	],
},

"coin_kind": {
	"speaker": "Nessa",
	"topic": true,
	"lines": [
		"An ADA. A physical one — a real disc, struck in metal, for a currency that has never once been a disc.",
		"Yes. I know. It was a gift, and the person who gave it to me thought that was funny too.",
		"It's the only one I have and it is within two metres of my feet, in a direction I can't lean.",
	],
	"goto": "hub",
},

"sceptic": {
	"speaker": "Nessa",
	"topic": true,
	"lines": [
		"They do here. Ask the chickens.",
	],
	"goto": "hub",
},

"accept": {
	"speaker": "Nessa",
	"lines": [
		"Then you can do the one thing I can't.",
		"Step ana — that way, whichever way that turns out to be — and look at the ground.",
		"It'll be lying in the grass on the next slice over, being extremely gold about it.",
	],
	"do": "coin_hinted",
	"goto": "",
	"goto_if_asked": "hub",
},

"brush_off": {
	"speaker": "Nessa",
	"lines": [
		"Mm. Everyone says that and then comes back.",
	],
	"goto": "",
	"goto_if_asked": "hub",
},

# ---------------------------------------------------------------- topics

"hub": {
	"speaker": "Nessa",
	"lines": [],
	"choices": [
		{"text": "Tell me about this coin.", "goto": "coin_kind", "once": true},
		{"text": "What have you found, then?", "goto": "found_things", "once": true},
		{"text": "And who are you?", "goto": "who_she_is", "once": true},
		{"text": "I'll keep an eye out.", "goto": "sign_off", "leave": true},
	],
},

## The setup. The egg is buried in a list of junk and thrown away in half a line, so that
## handing it over later is a callback rather than an announcement.
"found_things": {
	"speaker": "Nessa",
	"topic": true,
	"lines": [
		"A boot. Two boots, actually, and not a pair.",
		"A trowel. Somebody's spectacles, which I feel worst about. A solid gold egg.",
		"Everything, in other words, except the one thing I am looking for.",
	],
	"goto": "hub",
},

"who_she_is": {
	"speaker": "Nessa",
	"topic": true,
	"lines": [
		"I walk the far fence. Which mostly means I'm the one who notices when something has stopped being where it was.",
		"Ask him about the gate and he'll tell you the latch is old. He's not wrong. It isn't the latch.",
	],
	"goto": "hub",
},

"sign_off": {
	"speaker": "Nessa",
	"lines": [
		"Ana. Look down. That's the whole of it.",
	],
	"goto": "",
},

# ---------------------------------------------------------------- the handover

"greet_has_coin": {
	"speaker": "Nessa",
	"lines": [
		"You've — that's it. That's it, give it here.",
	],
	"choices": [
		{"text": "Here.", "goto": "handover"},
		{"text": "What's it worth to you?", "goto": "haggle"},
		{"text": "Not just now.", "goto": "not_yet", "leave": true},
	],
},

"not_yet": {
	"speaker": "Nessa",
	"lines": [
		"You're holding it. You are actually holding it and walking away.",
	],
	"goto": "",
},

"haggle": {
	"speaker": "Nessa",
	"lines": [
		"Nothing. It's worth nothing, it's a novelty disc, you could buy nine of them.",
		"That isn't the point and you know it isn't.",
	],
	"choices": [
		{"text": "Here. I was joking.", "goto": "handover"},
		{"text": "Keep looking, then.", "goto": "withhold", "leave": true},
	],
},

"withhold": {
	"speaker": "Nessa",
	"lines": [
		"Fine. It's had four days of my life, it can have the rest of the afternoon.",
	],
	"goto": "",
},

"handover": {
	"speaker": "Nessa",
	"lines": [
		"Thank you. Genuinely — that's four days off my week.",
		"Hold on. You've done me a turn and all I've got is other people's lost property.",
	],
	"do": "take_coin",
	"goto": "reward",
},

"reward": {
	"speaker": "Nessa",
	"lines": [
		"Here. Three slices over, in a nest that wasn't there the day before.",
		"It's an egg, it's gold, and I have no earthly use for either of those facts.",
	],
	"do": "give_egg",
	"goto": "reward_close",
},

"reward_close": {
	"speaker": "Nessa",
	"lines": [
		"Don't drop it. I'd never find it.",
	],
	"goto": "",
},

# ---------------------------------------------------------------- gameplay states

"greet_looking": {
	"speaker": "Nessa",
	"lines": ["Still here. Still the same nine yards of grass."],
	"goto": "hub",
},

"greet_hinted": {
	"speaker": "Nessa",
	"lines": ["Ana, and look down. I'd do it myself if I had the axis for it."],
	"goto": "hub",
},

"greet_done": {
	"speaker": "Nessa",
	"lines": ["Back in my pocket, where it can't get up to anything. How's the egg?"],
	"goto": "",
},

"greet_carrying": {
	"speaker": "Nessa",
	"lines": ["You've got a chicken under your arm and it is looking at me."],
	"goto": "",
},

}
