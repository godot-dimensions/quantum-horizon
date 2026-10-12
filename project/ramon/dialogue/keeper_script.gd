extends RefCounted
class_name KeeperScript

## The chicken keeper's dialogue, as data.
##
## Kept apart from the code that plays it so the writing can be rewritten without touching
## a state machine, and so a second character is a second file rather than a second system.
##
## A NODE is one beat: who speaks, what they say, and where it goes next. `lines` are shown
## one at a time and advanced by the player. `choices` appear after the last line. `goto`
## moves on without asking. `do` names an effect the game is expected to perform - the
## script says WHAT happens, never HOW, so handing over the gauntlet here does not need to
## know that a locator exists. `once` drops a topic off its menu after it is asked, and
## `instead` redirects a second visit, so he never delivers the same speech twice.
##
## A GOODBYE ENDS IT, UNLESS YOU WERE ALREADY TALKING. Saying "thanks" and being handed a
## menu is the oldest bug in dialogue design - the player has said they are done and the
## game disagrees. So the sign-offs close the conversation. But once somebody has asked
## about anything (a node marked `topic`), the same sign-offs hand them back the list via
## `goto_if_asked`, because at that point leaving was not what they meant.
##
## FOUR REPLIES, MAXIMUM, ANYWHERE. Nine options is a database query, not a conversation:
## the eye stops reading and starts scanning, and every line is written to be read. The
## topics are therefore two deep - the chickens, himself, the place, and leaving - and
## each sub-menu keeps its own "back" inside the same budget of four.
##
## ON THE JOKES. The comedy is the gap between what he is and what he does: a lab-grown
## intelligence, descended from a dish of cells that was taught to play Pong, employed to
## count chickens through a gate whose latch is older than he is. That gap is the joke,
## and it only works if he never once points at it. He plays everything straight and lets
## the facts do it. Where a line was only a wry tone of voice with nothing under it, it is
## gone - a dry delivery is not a joke, and four of those in a row is a mood, not a scene.

const START: String = "intro"

const NODES: Dictionary = {

# ---------------------------------------------------------------- first meeting

"intro": {
	"speaker": "Keeper",
	"lines": [
		"You. I've watched you skirt this field all week without once crossing into it. Today that is the exact qualification I need.",
		"Nine chickens are out. Through the gate, and then out of the world, into a direction I can't turn my head far enough to see.",
			"I am asking you to go and find them. I cannot. I have watched that gate for four years and I have never once seen where they go.",
		"So take this. A gauntlet. It reads the fourth way and points down it. Where I'm blind, it isn't.",
	],
	"do": "give_gauntlet",
	## Held back until that third line has been said. It used to fire the moment the node
	## was entered, which flew the gauntlet onto your wrist while he was still two lines
	## away from offering it.
	"do_on_line": 2,
	"choices": [
		{"text": "I'll find them. You'll get this back.", "goto": "gift_return"},
		{"text": "Thanks.", "goto": "gift_thanks", "leave": true},
		{"text": "I'll try without, thanks.", "goto": "gift_decline"},
		{"text": "Is there a human I can talk to about this?", "goto": "ask_human"},
	],
},

## The three goodbyes END the conversation instead of depositing you in a topic menu.
## Saying "thanks" and then being handed a list of things to ask about is the oldest bug
## in dialogue design: the player has said they are done and the game disagrees. Curiosity
## brings them back - his prompt is still over his head - and the menu is waiting then.
"gift_return": {
	"speaker": "Keeper",
	"lines": [
		"Keep it. I've no use for a window I can't look through.",
	],
	"goto": "",
	"goto_if_asked": "hub",
},

"gift_thanks": {
	"speaker": "Keeper",
	"lines": [
		"Don't thank me yet. Thank me at nine.",
	],
	"goto": "",
	"goto_if_asked": "hub",
},

## Declining has to cost something or it is not a choice. He keeps it, the locator stays
## dark, and his menu grows a line that lets you come back for it - which is the apology,
## without anyone having to say the word.
"gift_decline": {
	"speaker": "Keeper",
	"lines": [
		"That will be difficult, sir. Not impossible. Difficult.",
		"You'll pass within arm's reach of most of them, feel the air go wrong, and put it down to weather.",
		"It'll be on the post when the principle wears thin.",
	],
	"do": "withhold_gauntlet",
	"goto": "",
	"goto_if_asked": "hub",
},

"ask_gauntlet": {
	"speaker": "Keeper",
	"lines": [
		"Mm. Here.",
		"No speech. I'd been saving one and I'd hate to waste it on a good decision.",
	],
	"do": "give_gauntlet",
	"goto": "",
	"goto_if_asked": "hub",
},

# ---------------------------------------------------------------- topics

"greet_azoth": {
	"speaker": "Keeper",
	"lines": [
		"Is that the purple stuff? From the rock out there? It's warm. Why is it warm.",
		"Well. The suits pay good money for that, and I've been meaning to do something about this place for a long while. Say the word and I'll put it to use - one piece, one job, mind. I'm not a magician.",
	],
	"choices": [
		{"text": "Put up a feeder.", "goto": "built_feeder"},
		{"text": "I'll hang on to it for now.", "goto": "exit", "leave": true},
	],
},

"built_feeder": {
	"speaker": "Keeper",
	"do": "build_feeder",
	"do_on_line": 1,
	"lines": [
		"Grain in a trough. I'll set it down where they're thickest just now - no sense putting it where there's nothing to feed.",
		"It'll not put a single bird back for you, mind, and I'd not want it to. But the ones that wander near will come and stand about it instead of drifting off to the far hedge, and you'll spend a good deal less of your day walking.",
		"Bring me another piece and I'll put up another. There's enough in that rock for six, by my reckoning.",
	],
	"goto": "",
},

"hub": {
	"speaker": "Keeper",
	"lines": [],
	"choices": [
		{"text": "The chickens, then.", "goto": "hub_birds"},
		{"text": "You're not what I expected.", "goto": "hub_him"},
		{"text": "Who else is out here?", "goto": "hub_place"},
		{"text": "I'll get on with it.", "goto": "exit", "leave": true},
	],
},

"hub_birds": {
	"speaker": "Keeper",
	"lines": [],
	"choices": [
		{"text": "Where do I even start looking?", "goto": "where_look"},
		{"text": "And once I've got hold of one?", "goto": "how_catch"},
		{"text": "Nine of them? How does that even happen?", "goto": "how_out", "once": true},
		{"text": "Enough about chickens.", "goto": "hub", "back": true},
	],
},

"hub_him": {
	"speaker": "Keeper",
	"lines": [],
	"choices": [
		{"text": "Go on then. What are you?", "goto": "what_i_am", "once": true},
		{"text": "Do you ever want to go after them yourself?", "goto": "wistful", "once": true},
		{"text": "I'll take that gauntlet after all.", "goto": "ask_gauntlet", "needs": "!gauntlet"},
		{"text": "Never mind.", "goto": "hub", "back": true},
	],
},

"hub_place": {
	"speaker": "Keeper",
	"lines": [],
	"choices": [
		{"text": "Whose field is this, anyway?", "goto": "hoskinson", "once": true},
		{"text": "And who do you answer to?", "goto": "trym", "once": true},
		{"text": "Never mind.", "goto": "hub", "back": true},
	],
},

# ---------------------------------------------------------------- the chickens

"how_out": {
	"speaker": "Keeper",
	"topic": true,
	"lines": [
		"The latch is older than I am.",
		"I'm eight months old. Nobody has yet drawn the obvious conclusion about which of us gets replaced.",
	],
	"goto": "hub_birds",
},

"where_look": {
	"speaker": "Keeper",
	"topic": true,
	"lines": [
		"You've been looking in three directions. That's reading one page and calling the book short.",
		"Half of them aren't far off. They're beside you, in a direction you've no word for, and the gauntlet has one. Follow it and it'll swing you onto their slice.",
		"Ana and kata. Don't ask me which is which. I only know that neither of them is left.",
	],
	"goto": "hub_birds",
},

"how_catch": {
	"speaker": "Keeper",
	"topic": true,
	"lines": [
		"Get close. It'll run. It has no plan beyond that.",
		"Then pick it up and carry it in, or throw it over the fence. I'm not marking you on style.",
	],
	"goto": "hub_birds",
},

# ---------------------------------------------------------------- the place
#
# Both of these are about people the player may well know, so the joke is always on the
# situation and never on the man.

"hoskinson": {
	"speaker": "Keeper",
	"topic": true,
	"lines": [
		"A man three valleys over who keeps bison. I asked him once why bison.",
		"He said: they can't leave.",
		"Then he looked at my chickens for a while and changed the subject.",
	],
	"goto": "hub_place",
},

"trym": {
	"speaker": "Keeper",
	"topic": true,
	"lines": [
		"A Norwegian. I asked him once whether the work was good. He said: it's not bad.",
		"I spent a week deciding whether I'd been praised. I've settled on yes.",
	],
	"goto": "hub_place",
},

# ---------------------------------------------------------------- what he is
#
# Two ways in: asked straight, or arrived at by asking to speak to a human instead. He
# never takes offence at the second one; he answers it, which is worse.

"ask_human": {
	"speaker": "Keeper",
	"lines": [
		"There is one. He's three valleys away with his bison and he is not coming.",
		"But I can hear the question underneath that one, so let me answer it instead.",
	],
	"goto": "what_i_am",
},

"what_i_am": {
	"speaker": "Keeper",
	"topic": true,
	"instead": "what_i_am_again",
	"lines": [
		"I'm a culture. Human neurons grown on a grid of electrodes, kept warm, kept fed, and taught the only way anything is taught, by consequence.",
		"My ancestors, and I use the word loosely, were taught to play Pong. A dish of cells learning to keep a square between two lines. That was the entire ambition of the field at the time.",
		"Four generations on, here I am, keeping nine chickens between four fences. You can see the family resemblance.",
	],
	"goto": "what_i_am_close",
},

## The landing. It has to stop being about him and become about the player, or the whole
## branch is just a man explaining his own condition at you.
"what_i_am_close": {
	"speaker": "Keeper",
	"lines": [
		"And don't look like that. You see three directions out of four and call it the world.",
		"I see the same three. At least I know what's missing.",
		"Anyway. Chickens.",
	],
	"goto": "hub",
},

"what_i_am_again": {
	"speaker": "Keeper",
	"lines": [
		"We've done this. Chickens.",
	],
	"goto": "hub",
},

## The one moment he is allowed to mean something, and it is short because he would keep
## it short. It also earns the reply under it: the cheapest possible response to sincerity.
"wistful": {
	"speaker": "Keeper",
	"topic": true,
	"lines": [
		"Every day. Not about the chickens.",
		"There's an entire direction out there that I can prove exists and will never once look down. You'll do it this afternoon and think about it less than you think about a doorway.",
		"Bring them back. That's as close as I get to going.",
	],
	"choices": [
		{"text": "I'll bring them back.", "goto": "hub_him", "back": true},
		{"text": "It's a machine feeling sorry for itself.", "goto": "rude_pity"},
	],
},

"rude_pity": {
	"speaker": "Keeper",
	"lines": [
		"Careful. Self-pity is one of the harder things to grow. They were pleased when it turned up.",
	],
	"goto": "what_i_am",
},

"exit": {
	"speaker": "Keeper",
	"lines": [
		"Good. Nine.",
	],
	"goto": "",
},

# ---------------------------------------------------------------- gameplay states
# Entered by the game rather than chosen by the player, according to the count and to what
# you happen to be carrying.

"greet_none": {
	"speaker": "Keeper",
	"lines": ["Back, and empty-handed. Nine. Still nine."],
	"goto": "hub",
},

"greet_some": {
	"speaker": "Keeper",
	"lines": ["{returned} in, {remaining} out. The easy ones went first, which is the trouble with easy ones."],
	"goto": "hub",
},

"greet_nearly": {
	"speaker": "Keeper",
	"lines": ["{remaining} left. I'd written off more than that this morning."],
	"goto": "hub",
},

"greet_carrying": {
	"speaker": "Keeper",
	"lines": ["You're holding one. Don't show me. Show the fence."],
	"goto": "",
},

"greet_done": {
	"speaker": "Keeper",
	"lines": [
		"That's the lot. Every one of them.",
		"Keep the gauntlet. It's wasted on something whose whole employment is standing at a gate and counting to nine.",
		"And the latch is still old.",
	],
	"goto": "",
},

"greet_no_gauntlet": {
	"speaker": "Keeper",
	"lines": ["Still doing it the hard way. I admire it the way I admire swimming to Norway."],
	"goto": "hub",
},

}


## Substitutes the counts into a line. Kept here rather than in the player so a line is
## responsible for its own placeholders and nothing has to parse the writing twice.
static func fill(line: String, returned: int, total: int) -> String:
	return line.replace("{returned}", str(returned)).replace("{remaining}", str(total - returned))
