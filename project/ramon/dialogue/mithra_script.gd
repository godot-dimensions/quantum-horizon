extends RefCounted
class_name MithraScript

## Mithra, who has been pacing the same field for days looking for a pocket watch that
## went sideways out of the world.
##
## Same shape as KeeperScript - see the header there for what a node is and what the
## fields do. Two characters, two files of writing, one dialogue system.
##
## THE JOKE SHE IS BUILT ON. She has been searching one patch of grass for days and has
## found a boot, a trowel, somebody's spectacles and a solid gold egg. She has not found
## the watch. Everything she says is straight; the comedy is entirely in the ratio - and
## in the fact that it is a watch, lost for four days, that she can hear ticking.
##
## IT WAS A COIN. An ADA, with the Cardano mark on it. Trym asked on 25 Sept for every
## mention of money to come out of the scene, so it became a 4D pocket watch - and the
## joke got better: a watch whose back boasts that it keeps four-dimensional time, which
## turns out not to have been a boast.
##
## SHE ALREADY EXISTED. pen_searcher_4d.gd walks her and gave her a one-line mutter as
## you passed; this replaces the mutter with something you can answer.
##
## WHY SHE IS ORDINARY. The keeper is a lab-grown intelligence. If she were strange too,
## neither of them would be - a field where everybody is remarkable has nobody in it. She
## is a person with a job and a grievance, and that is what makes him land.
##
## THE WATCH IS OFF-SLICE ON PURPOSE. It teaches the same lesson the chickens do, in one
## object, with a character standing next to it telling you plainly what to press.
##
## AND SHE POINTS YOU AT THE HILL. Her nugget was found up by the cave mouth, where the
## people in white suits are, so paying you also tells you where the rest of the azoth is -
## the errand hands you on to the cave instead of ending in a field.

const START: String = "intro"

const NODES: Dictionary = {

# ---------------------------------------------------------------- first meeting

"intro": {
	"speaker": "Mithra",
	"lines": [
		"Don't, don't walk there. Stand still a moment.",
		"I dropped my watch. Just here, about a yard from my boot. It did not land.",
		"It went sideways, and not a sideways I've got. It is under my boots right now. I can hear it ticking.",
		"I wish I had one of those gauntlets he hands out. I'd have had it back on the first pass instead of the ninth.",
	],
	"choices": [
		{"text": "What kind of watch?", "goto": "watch_kind"},
		{"text": "I'll look for it.", "goto": "accept"},
		{"text": "Things don't fall out of the world.", "goto": "sceptic"},
		{"text": "Good luck with that.", "goto": "brush_off", "leave": true},
	],
},

"watch_kind": {
	"speaker": "Mithra",
	"topic": true,
	"lines": [
		"A pocket watch. My grandfather's. The back says it keeps four-dimensional time, which I always took to be a boast.",
		"It was not a boast. It is ticking within two metres of my feet, in a direction I can't lean.",
		"Four days I have been looking for a watch. Yes. I have noticed.",
	],
	"goto": "hub",
},

"sceptic": {
	"speaker": "Mithra",
	"topic": true,
	"lines": [
		"They do here. Ask the chickens.",
	],
	"goto": "hub",
},

"accept": {
	"speaker": "Mithra",
	"lines": [
		"Then you can do the one thing I can't.",
		"Step ana, that way, whichever way that turns out to be, and look at the ground.",
		"It'll be lying in the grass on the next slice over, keeping perfect time for nobody.",
	],
	"do": "watch_hinted",
	"goto": "",
	"goto_if_asked": "hub",
},

"brush_off": {
	"speaker": "Mithra",
	"lines": [
		"Mm. Everyone says that and then comes back.",
	],
	"goto": "",
	"goto_if_asked": "hub",
},

# ---------------------------------------------------------------- topics

"hub": {
	"speaker": "Mithra",
	"lines": [],
	"choices": [
		{"text": "Tell me about this watch.", "goto": "watch_kind", "once": true},
		{"text": "What have you found, then?", "goto": "found_things", "once": true},
		{"text": "And who are you?", "goto": "who_she_is", "once": true},
		{"text": "I'll keep an eye out.", "goto": "sign_off", "leave": true},
	],
},

## The setup. The egg is buried in a list of junk and thrown away in half a line, so that
## handing it over later is a callback rather than an announcement.
"found_things": {
	"speaker": "Mithra",
	"topic": true,
	"lines": [
		"A boot. Two boots, actually, and not a pair.",
		"A trowel. Somebody's spectacles, which I feel worst about. A solid gold egg.",
		"Everything, in other words, except the one thing I am looking for.",
	],
	"goto": "hub",
},

"who_she_is": {
	"speaker": "Mithra",
	"topic": true,
	"lines": [
		"I walk the far fence. Which mostly means I'm the one who notices when something has stopped being where it was.",
		"Ask him about the gate and he'll tell you the latch is old. He's not wrong. It isn't the latch.",
	],
	"goto": "hub",
},

"sign_off": {
	"speaker": "Mithra",
	"lines": [
		"Ana. Look down. That's the whole of it.",
	],
	"goto": "",
},

# ---------------------------------------------------------------- the handover

"greet_has_watch": {
	"speaker": "Mithra",
	"lines": [
		"You've, that's it. That's it, give it here.",
	],
	"choices": [
		{"text": "Here.", "goto": "handover"},
		{"text": "What's it worth to you?", "goto": "haggle"},
		{"text": "Not just now.", "goto": "not_yet", "leave": true},
	],
},

"not_yet": {
	"speaker": "Mithra",
	"lines": [
		"You're holding it. You are actually holding it and walking away.",
	],
	"goto": "",
},

"haggle": {
	"speaker": "Mithra",
	"lines": [
		"To a jeweller? Brass and a cracked crystal. It would not buy you lunch.",
		"But it has been four days under my own boot, in a direction I can't lean. That is what it is worth. Ask me again in a week and it will be worth more.",
	],
	"choices": [
		{"text": "Here. I was joking.", "goto": "handover"},
		{"text": "Keep looking, then.", "goto": "withhold", "leave": true},
	],
},

"withhold": {
	"speaker": "Mithra",
	"lines": [
		"Fine. It's had four days of my life, it can have the rest of the afternoon.",
	],
	"goto": "",
},

"handover": {
	"speaker": "Mithra",
	"lines": [
		"Thank you. Genuinely, that's four days off my week. And it's still going. Of course it is.",
		"Hold on. You've done me a turn and all I've got is other people's lost property.",
	],
	"do": "take_watch",
	"goto": "reward",
},

"reward": {
	"speaker": "Mithra",
	"lines": [
		"Here. I found this up by the hill, the one with the hole in it, the morning the watch went.",
		"It's warm, and it's purple, and when I look at it side-on it isn't all there. The keeper will take it. He has been waiting years for someone to hand him something.",
		"And there's more where it came from. There are people in white suits going in and out of that hill, and not one of them will tell me what they're measuring.",
	],
	"do": "give_nugget",
	"goto": "reward_close",
},

"reward_close": {
	"speaker": "Mithra",
	"lines": [
		"Don't drop it. I'd never find it.",
		"Oh, and before you go. Ask Trym about his presentation.",
		"It is better than he makes it sound, and he makes it sound quite good. Might see you there, yeah?",
	],
	# She does not go anywhere and does not wait for an answer. The errand used to end
	# with her sprinting off to catch you a chicken, which was a strange way to thank
	# somebody for returning her watch - and it made the one character who cannot reach
	# the fourth direction better at the fourth-direction job than you are.
	"goto": "",
},






"greet_after_gift": {
	"speaker": "Mithra",
	"lines": [
		"Back on the grass. There's a trowel down there somewhere that isn't mine either.",
	],
	"goto": "",
},

# ---------------------------------------------------------------- gameplay states

"greet_looking": {
	"speaker": "Mithra",
	"lines": ["Still here. Still the same nine yards of grass."],
	"goto": "hub",
},

"greet_hinted": {
	"speaker": "Mithra",
	"lines": ["Ana, and look down. I'd do it myself if I had the axis for it."],
	"goto": "hub",
},

"greet_done": {
	"speaker": "Mithra",
	"lines": ["Back in my pocket, where it can't get up to anything. How's the egg?"],
	"goto": "",
},

"greet_carrying": {
	"speaker": "Mithra",
	"lines": ["You've got a chicken under your arm and it is looking at me."],
	"goto": "",
},

}
