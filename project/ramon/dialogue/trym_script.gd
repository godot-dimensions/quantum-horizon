extends RefCounted
class_name TrymScript

## Trym, at the desk behind the pen. Delighted, nerdy, and very hard to stop once started.
##
## HE IS NOT THE MAN THE KEEPER DESCRIBED, and the script does not point that out. An
## earlier draft had him explain that people can't read him - which landed as the
## character being made fun of rather than as characterisation, so it is gone. He is
## simply delighted to be talked to, and the contrast with the keeper does its own work
## without either of them narrating it.
##
## THE FACTS ARE REAL. What he says about the October gate is the ARC decision package's
## own framing, near enough word for word: four things - it can run, it can be understood,
## it can create worthwhile gameplay, and it can be developed at a sustainable rate. The
## meta answer about the pen is real too. The pen was built by a non-engineer working
## mostly by asking, which is Rung 1 of the non-expert independence ladder; Trym is Rung 2.
## Nothing here is invented flattery, which is what lets him say it deadpan.
##
## HE RUNS LONG, AND THAT IS THE POINT. The keeper is capped at three sentences and often
## uses one; Trym goes to four and would go further if you let him. The two of them are
## the same information delivered at opposite pressures, and the contrast is most of what
## makes either of them a person rather than a dispenser of facts.
##
## EVERY LIST HAS A WAY OUT, marked `leave`. Not one buried at the bottom of a menu you
## have to reach - the first time he offers you anything you can already decline it.

const START: String = "intro"

const NODES: Dictionary = {

# ---------------------------------------------------------------- meeting him

"intro": {
	"speaker": "Trym",
	"lines": [
		"Hey there! Hang on — right — sorry. I'd been sitting so long my legs had developed opinions.",
		"You're the one going after the chickens through W, aren't you. I've been watching from the desk instead of doing the thing I'm meant to be doing. Best afternoon I've had in weeks, and I want to be clear that I mean that literally and not as a way of being polite.",
	],
	"choices": [
		{"text": "Who are you, then?", "goto": "who_he_is"},
		{"text": "You've been watching me?", "goto": "watching"},
		{"text": "I'm in the middle of something.", "goto": "exit", "leave": true},
	],
},

"watching": {
	"speaker": "Trym",
	"topic": true,
	"lines": [
		"Constantly. Don't let that put you off.",
		"I have a spreadsheet open that I have not looked at since about eleven this morning. You are considerably more interesting than the spreadsheet, and I want to stress that this is not a low bar being cleared.",
	],
	"goto": "who_he_is",
},

"who_he_is": {
	"speaker": "Trym",
	"lines": [
		"I'm Trym. I like horses, but I like 4D more.",
		"That's the whole introduction. I've tried making it longer and it always comes back to those two things, and then people ask which one wins, and then we're here for an hour. So I've stopped fighting it.",
		"What about you?",
	],
	"choices": [
		{"text": "I catch chickens. Apparently that's a career now.", "goto": "you_chickens"},
		{"text": "Still deciding whether any of this is real.", "goto": "you_real"},
		{"text": "I like the fourth direction. I don't understand it.", "goto": "you_like"},
		{"text": "I'd rather get on.", "goto": "exit", "leave": true},
	],
},

"you_chickens": {
	"speaker": "Trym",
	"lines": [
		"It is here, and it's the good kind. You can't do it wrong in three dimensions — only slowly.",
	],
	"goto": "offer",
},

"you_real": {
	"speaker": "Trym",
	"lines": [
		"Ha! Nobody who says that ever leaves. Go on, ask me something.",
	],
	"goto": "offer",
},

"you_like": {
	"speaker": "Trym",
	"lines": [
		"That's the right order, actually. Everyone who ends up any good at this liked it first and understood it second.",
	],
	"goto": "offer",
},

# ---------------------------------------------------------------- the thing he built

## HE ASKS, THE PLAYER DECIDES. An NPC who simply walks off and expects to be followed is
## a cutscene with extra steps; one who asks is a person with an idea. Declining costs
## nothing - the hub keeps the offer open - which is the same rule every other list in
## this script follows.
##
## IT SITS ON THE PATH EVERY INTRODUCTION TAKES - all three answers to "what about you"
## come here - so it lands in the first conversation without being bolted to the end of
## one. There is no `instead` on it: turning him down should not cost the trip, so his
## driver simply opens with this node again next time, and stops the moment you accept.
## Which is also in character for a man the script describes as hard to stop once started.
"offer": {
	"speaker": "Trym",
	"lines": [
		"Right - hang on. While you're here.",
		"I've been building something in the evenings. It isn't on this farm, and I have completely failed to explain it to anybody standing still. Two minutes. Come outside with me.",
	],
	"choices": [
		{"text": "Sounds fascinating. Lead the way.", "goto": "show_you"},
		{"text": "Later, maybe.", "goto": "hub", "back": true},
	],
},

## The effect fires on the SECOND line, not the first: `do_on_line` holds it back until
## the sentence that announces it has been read, so he gets up as he finishes speaking
## rather than while the player is still on "Brilliant". `goto` is empty because he is
## leaving - the conversation ends and the walk begins.
"show_you": {
	"speaker": "Trym",
	"instead": "what_did_you_think",
	"lines": [
		"Brilliant. Right.",
		"Out we go. Don't wander off - I'll only have to come and find you.",
	],
	"do": "trym_invite",
	"do_on_line": 1,
	"goto": "",
},

"what_did_you_think": {
	"speaker": "Trym",
	"lines": [
		"So. What did you think?",
		"No - don't answer that. I'll take it personally and then we'll be here all evening. I'm glad you came.",
	],
	"goto": "hub",
},

# ---------------------------------------------------------------- the three questions

"hub": {
	"speaker": "Trym",
	"lines": [],
	"choices": [
		{"text": "Why is this pen four-dimensional at all?", "goto": "why_the_pen", "once": true},
		{"text": "What are you actually trying to prove out here?", "goto": "the_gate", "once": true},
		{"text": "Tell me about the horses.", "goto": "horses", "once": true},
		{"text": "I should get back to it.", "goto": "exit", "leave": true},
	],
},

## Meta, and true. The pen really was built by somebody who is not an engineer.
"why_the_pen": {
	"speaker": "Trym",
	"topic": true,
	"lines": [
		"Because a chicken is the smallest thing that makes the fourth direction matter.",
		"You can explain a tesseract at someone for a solid hour and they will nod at you the entire time and retain none of it. Let one chicken walk out of the world in front of them and they've got ana and kata in about nine seconds. Nobody has ever thanked a diagram. People will chase a bird.",
		"And the other reason: this pen was built by somebody who isn't an engineer, mostly by asking. That's not a fun fact. That's the experiment.",
	],
	"goto": "hub",
},

## The ARC package's own four-part framing, and the risk that actually keeps the team up.
"the_gate": {
	"speaker": "Trym",
	"topic": true,
	"lines": [
		"Four things, and they're all smaller than people expect. That it runs. That it can be understood. That it makes gameplay worth having. And that it can be built at a rate that doesn't need a specialist for every blade of grass.",
		"There's a week in October where we have to show all four of those rather than say them. The stance is that we're proving it works, not that it's optimised — which sounds like a get-out and isn't, because the two get confused constantly and the second one is a different year's problem.",
		"The fourth one is the one that keeps me up. And the test for it is me: somebody who is not an engineer, building something, badly, on purpose.",
	],
	"choices": [
		{"text": "Badly on purpose?", "goto": "gate_more"},
		{"text": "Fair enough.", "goto": "hub", "back": true},
	],
},

## The payoff. He gets to be straightforwardly hopeful once, having been careful about
## every other claim, and the hope is about a specific thing he has watched happen rather
## than about the future in general.
"gate_more": {
	"speaker": "Trym",
	"topic": true,
	"lines": [
		"Badly is the wrong word, I'll give you that. I mean without a specialist standing behind me — that's the actual test, and it only counts if it's a fair one.",
		"Look at this field, though. A designer built it. Not an engineer — a designer, working with Claude, asking for things and getting them back. A year ago that sentence would have been a joke and I'd have been the one laughing at it.",
		"And I've been doing my own prototypes in the evenings, which is how I know the difference between the AI wrote some code and somebody who can't write code finished something. It's promising. Not meeting-promising. I keep getting surprised in the right direction, which is the only kind of promising I trust.",
	],
	"goto": "hub",
},

"horses": {
	"speaker": "Trym",
	"topic": true,
	"lines": [
		"Oh, now you've done it.",
		"I keep a stable. And I'll say the thing nobody who keeps horses says out loud, which is that they are an enormous amount of work. Every single day, in three dimensions, in the rain, whether or not you are currently enjoying horses. There is no version where you skip a Tuesday.",
		"A tesseract has never once needed its feet picked out.",
	],
	"goto": "hub",
},

"exit": {
	"speaker": "Trym",
	"lines": [
		"Go on then. Mind the fourth way.",
	],
	"goto": "",
},

# ---------------------------------------------------------------- gameplay states

"greet_back": {
	"speaker": "Trym",
	"lines": ["Back! Good. I've been sitting here with nobody to be nerdy at."],
	"goto": "hub",
},

"greet_carrying": {
	"speaker": "Trym",
	"lines": [
		"You've got one! Look at it. Completely unbothered about having been in two places.",
		"Go on — fence first, me after.",
	],
	"goto": "",
},

"greet_done": {
	"speaker": "Trym",
	"lines": [
		"All twelve. You realise you've just done the whole experiment, don't you.",
		"Ran, was understood, was worth doing. Somebody write that down.",
	],
	"goto": "hub",
},

}
