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
		"Brilliant. Out we go.",
	],
	"do": "trym_invite",
	"do_on_line": 0,
	"goto": "",
},

## COMING BACK FROM THE SHOWING.
##
## IT MUST NOT FALL BACK TO THE ORIGINAL TOPIC LIST. The first version sent every answer
## home to `hub`, and after the cinema that reads as the conversation rewinding - you have
## just watched the thing and he offers you "why is this pen four-dimensional at all?"
## again. The return leg has its own hub, `post_show`, and nothing here reaches the old
## one.
##
## A SPECTRUM, NOT A MENU. Seven positions from enthusiastic to dismissive, sitting beside
## each other so the player picks a stance rather than a topic. Each is `once`, so the
## list thins as you work through it and the conversation ends when you have said your
## piece. This is the only node allowed past the four-reply cap, named explicitly in the
## verifier so the exception cannot spread by accident.
##
## EVERY ANSWER LEADS WITH UNDERSTANDING - the developer slide's own first beat, before
## Create and before Carry it forward. He concedes the sceptical ones outright, including
## the last, which he cannot answer with a number and does not pretend to.
##
## AND EVERY FIGURE IS FROM THE RECORD: 25.2 ms across seven creatures, 73,020 tetrahedra,
## 79.31 down to 19.76, ~130 ms a carve at ~58 fps, 40.5 ms to rebuild a portal chunk,
## 7 of 7 reporting intuition against 3 of 7 finishing, and goat 1.15 m, chicken 0.51 m,
## brachiosaurus 10.2 m from one authoring method. The floor banding is a HYPOTHESIS here
## because that is what the slide calls it. Understating the evidence is the character.
"what_did_you_think": {
	"speaker": "Trym",
	"topic": true,
	"lines": [
		"Right. You've seen it now.",
		"Not whether you enjoyed it - whether you think it can become a platform people build ON. That's the actual question in October, and it splits three ways: can it run reliably, can people understand it and enjoy it, and can anybody other than us build with it. Any one of them can change the scope on its own.",
		"So. Wherever you land, land on it honestly. I get the polite answer from everybody.",
	],
	"goto": "post_show",
},

"post_show": {
	"speaker": "Trym",
	"lines": [],
	"choices": [
		{"text": "This is it. You've got a platform.", "goto": "say_platform", "once": true},
		{"text": "I'd play a horror game built in this tomorrow.", "goto": "say_horror", "once": true},
		{"text": "The tools impressed me more than the games did.", "goto": "say_tools", "once": true},
		{"text": "It depends whether anyone else can build with it.", "goto": "say_transfer", "once": true},
		{"text": "People will bounce off it. It's too hard to read.", "goto": "say_player", "once": true},
		{"text": "It'll never run well enough to ship.", "goto": "say_engine", "once": true},
		{"text": "Honestly? It's a tech demo looking for a game.", "goto": "say_demo", "once": true},
		{"text": "So what are you actually asking for?", "goto": "the_ask", "once": true},
		{"text": "That's me done.", "goto": "exit", "leave": true},
	],
},

"say_platform": {
	"speaker": "Trym",
	"topic": true,
	"lines": [
		"I understand why it looks that way from inside it. It looks that way to me too, and two of the three legs are holding better than I expected.",
		"But I should be precise about what you just walked through, because the flattering version of the story is the wrong one. The foundation is specialist engineering - Aaron and Andrew write the engine, and nothing here happens without them. What sits on top was made by the two of us: a designer, and me, who knows what a rotor is and could not implement one at gunpoint. The claim is narrower than people hear it. Not that anybody can build 4D - that people who cannot build the floor can still build a room on it.",
		"And we've only been at it since May, after we came off Unreal onto Godot. Two of us over five months is not a sample. That's a partnership finding its feet, not a platform.",
	],
	"goto": "post_show",
},

"say_horror": {
	"speaker": "Trym",
	"topic": true,
	"lines": [
		"I understand the instinct, and you've picked the direction I'd pick. Let me tell you why it's the right one rather than just the fun one.",
		"In every genre, being disoriented is friction - something you pay for with fun somewhere else. In exactly one genre it isn't friction, it's the product. Iron Lung was a six-dollar indie about a submarine in the dark, it got famous on other people's channels, and then somebody made a film of it. We happen to be extremely good at taking a person's bearings away.",
		"What I won't do is plan on it. That's a low-probability breakout, not a forecast, and a studio that budgets for lightning gets what it deserves.",
	],
	"goto": "post_show",
},

"say_tools": {
	"speaker": "Trym",
	"topic": true,
	"lines": [
		"I understand why that sounds like faint praise, and I'd like to be clear that it isn't. That IS the finding. The tool is the output.",
		"You place control balls down a spine, set their size, and the thing lofts a body through them. Same method, different numbers: a goat at a metre fifteen, a chicken at half a metre, a brachiosaurus at ten. Nobody built those a tetrahedron at a time, which is the only reason there are nine experiments rather than one.",
		"With the caveat I keep repeating, because it's the honest half: specialist engineering still holds the foundation up. The authoring sits on top of work neither of us could do.",
	],
	"goto": "post_show",
},

"say_transfer": {
	"speaker": "Trym",
	"topic": true,
	"lines": [
		"I understand, and I agree with you completely. That's the third pillar, and it's the one I'd bet against.",
		"So it's the next test, and it's deliberately uncomfortable. One outside author. One defined task: take a creature, change its proportions, procedurally animate it, make it hold up in a scene. We hand over the tool, starter material, documentation and AI access.",
		"And we record the failures and how much help they needed, not just whether it came out. A result you have to stand next to in order to reproduce isn't independence. It's supervision.",
	],
	"goto": "post_show",
},

"say_player": {
	"speaker": "Trym",
	"topic": true,
	"lines": [
		"I understand, and I won't fight you with the number you're expecting me to use.",
		"Seven playtesters. Seven of seven said they came away with some intuition for it. Three of seven actually finished. Those two numbers tell different stories, and the honest reading is the second one - people believed they had understood it rather more than their hands had.",
		"Which is where the work went. If you can't see the fourth axis you need something that tells you it moved, so we band the floor - a repeating pattern the eye can measure the change against. And I'll be careful here: that's a hypothesis with a picture beside it. It hasn't been tested on anybody yet.",
		"The next study asks them to do the task, explain the rule back in their own words, and then choose whether to carry on. Understanding and appeal measured separately, because a thing can pass one and fail the other, and I'd rather know which than average them into a number that flatters us.",
	],
	"goto": "post_show",
},

"say_engine": {
	"speaker": "Trym",
	"topic": true,
	"lines": [
		"I understand, and rather than reassure you I'll just give you the numbers.",
		"Seven creatures animating together: 25.2 milliseconds a frame, so about forty a second, with seventy-three thousand tetrahedra on screen. Carving the rock runs around 130 milliseconds a carve and sits near fifty-eight frames between them. Cutting a portal through a wall rebuilds that chunk in 40.5.",
		"None of that is shippable and I'd rather say so than dress it up. But it moves when we push it - the five-creature test went from 79.31 milliseconds to 19.76 by binding each vertex to its bone once instead of rebuilding every limb from scratch every frame.",
		"And here's the caveat off our own slide, before you go and find it yourself: one machine, one scene, no controlled repeat, hardware and sample count not supplied. A number nobody else can reproduce isn't evidence. It's a nice afternoon.",
	],
	"goto": "post_show",
},

"say_demo": {
	"speaker": "Trym",
	"topic": true,
	"lines": [
		"I understand. That's the fear I'd have in your chair, and it's the only one on your list I can't wave a measurement at.",
		"The difference between a demo and a platform is whether the same foundation serves games that have nothing to do with one another. That's why there are nine experiments across four areas rather than one polished thing - reading 4D space, acting through the fourth axis, reusable environments, living creatures. One engine underneath all of it. A single beautiful slice would prove one game was worth finishing. It wouldn't tell you the ground was fertile.",
		"But I'd rather concede the shape of your point than dodge it. That's evidence, not proof. Which is why stop is genuinely on the table in October, alongside continue and rescope, and why I wrote down beforehand what would make me pick it.",
	],
	"goto": "post_show",
},

## THE ASK, STATED PLAINLY. A stakeholder who plays this should be able to leave knowing
## what is actually being requested in October, not merely that the numbers are honest.
## It is the deck's closing slide in his own voice: three outcomes, a BOUNDED
## recommendation rather than a runway, and continuation tied to the evidence.
"the_ask": {
	"speaker": "Trym",
	"topic": true,
	"lines": [
		"Three things, and none of them is more money for as long as it takes.",
		"Three outcomes are on the table in October. Continue, rescope, or stop. We're recommending continue - but bounded. Fund a named set of tests with review points attached, not a runway. If the wider case weakens, narrow it to one title or one tool. If the fundamentals fail, wind it down. Those are our words, in our own deck, written before anybody asked us for them.",
		"So: agree what we're testing, agree how it's paid for, agree when we next look. Tie the money to the evidence rather than to how keen I sound - because how keen I sound is not data.",
		"Decision pack on the twelfth, gate on the sixteenth. Build it, measure it, let the evidence decide. Which is either the dullest sentence in the whole deck or the entire point of it, depending rather a lot on how that week goes.",
	],
	"goto": "post_show",
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

"greet_ticket": {
	"speaker": "Trym",
	"topic": true,
	"lines": [
		"Before you go - here. Take this.",
		"It's a ticket. The projector doesn't care whether I'm standing next to it, and I've realised I'd rather you could go back and check a number than take my word for one of them. That's the entire argument I've been making at you all afternoon, so it would be a bit rich to make you come and ask me every time.",
		"Keep it on your belt. Press it whenever you like.",
	],
	"do": "rewatch_ticket",
	"do_on_line": 2,
	"goto": "",
},

## AFTER ALL OF IT. Short, and it ends - it does not reopen the topic list. Coming back
## to a man who offers you his introduction again is the thing that made the conversation
## feel like a machine in the first place.
"greet_after": {
	"speaker": "Trym",
	"lines": [
		"Go on, then. You've got the ticket - you don't need me to let you in.",
	],
	"goto": "",
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
	"goto": "",
},

}
