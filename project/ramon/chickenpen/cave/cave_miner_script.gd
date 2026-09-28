extends RefCounted

## NO class_name, for the reason professor_script.gd gives: preloaded by path it works the
## moment it exists, without waiting for an editor scan.

## The miner in the spacesuit at the foot of the monolith: Hale.
##
## THE PROFESSOR'S RULE HOLDS HERE: EVERY NUMBER IS MEASURED. Ramon asked for a miner who
## talks "voxel-rock benchmark details with mystery", and the professor's header is clear
## that a character who explains a system in invented terms is worse than one who says
## nothing. So each figure below comes from _measure_monolith_runner.gd on the slab as it
## stands in cave.tscn, 28 Sept 2026: a 10^4 lattice (10,000 points) at 0.66 m, 1,368
## tetrahedra when whole, 63 surface colliders before anyone digs and 363 after five blows,
## 172 ms to re-contour after every blow; the six pieces of gold of which three sit further
## through W than one blow reaches (pen_rock_gold_4d.gd, with the slab's 0.55 m bite). The
## pen's old rock, for comparison, is the professor's 8^4 and 544 colliders - and measured
## the same day at 184-209 ms a blow, MORE than the slab with two and a half times the
## points, because rebuilding its 544 colliders costs more than contouring the bigger
## field. That surprise is in his lines because it is true.
##
## THE MYSTERY IS IN WHAT THE NUMBERS DO, not in anything made up about them. A rock whose
## collider count goes UP as you take it away, that re-computes the whole of itself when
## touched, that is exactly as big in W as it is across - those are true of the slab and
## they are strange, so he finds them strange. He never says what it is. Nobody here knows.
##
## HE IS NOT THE PROFESSOR. The professor is a pedant in a chicken field and finds nothing
## funny. Hale is a working miner three weeks into a job that stopped making sense on day
## one, and is holding it together by being practical about it. Short lines, the same four-
## reply cap, a way out of every menu.

const START: String = "intro"

const NODES: Dictionary = {

"intro": {
	"speaker": "Hale",
	"lines": [
		"Mind the cables. And don't touch the slab unless you mean to.",
		"Name's Hale. I dig things out of hills for a living. Usually I know what they are before I start.",
		"This one was here before the hill was.",
	],
	"choices": [
		{"text": "What is it?", "goto": "topic_what"},
		{"text": "Why the spacesuit?", "goto": "topic_suit"},
		{"text": "Can I hit it?", "goto": "how_to_mine"},
		{"text": "I'll look around.", "goto": "bye", "leave": true},
	],
},

"how_to_mine": {
	"speaker": "Hale",
	"lines": [
		"Pick on your belt, stand close, swing. It takes a bite about a metre across. The white-suits will scream. They're not wrong to.",
		"There's gold in it. Six pieces, the scanners say. Three you can reach from this slice. Three you can't, however close you stand.",
	],
	"topic": true,
	"goto": "menu",
},

"greet_after_strike": {
	"speaker": "Hale",
	"lines": [
		"You hit it. Hear them? The white-suits have been dreading that for three weeks.",
		"Felt the stall, though? A sixth of a second. Ten thousand points, all of them, re-worked for a bite the size of your head. It never skips one.",
		"I won't stop you. I'm not sure anyone should be encouraging you, either.",
	],
	"goto": "menu",
},

"menu": {
	"speaker": "Hale",
	"lines": ["Go on, then."],
	"choices": [
		{"text": "What is it made of?", "goto": "topic_lattice"},
		{"text": "Why does it stall when I hit it?", "goto": "topic_cost"},
		{"text": "Something else.", "goto": "menu_two"},
		{"text": "Back to work. See you.", "goto": "bye_work", "leave": true},
	],
},

"menu_two": {
	"speaker": "Hale",
	"lines": ["Ask. I've had three weeks to think of answers."],
	"choices": [
		{"text": "Your people keep measuring it.", "goto": "topic_colliders"},
		{"text": "The gold you can't reach?", "goto": "topic_deep"},
		{"text": "Back to the start.", "goto": "menu"},
		{"text": "I'll leave you to it.", "goto": "bye", "leave": true},
	],
},

"topic_what": {
	"speaker": "Hale",
	"instead": "topic_what_again",
	"lines": [
		"Honestly? A lattice. Ten points by ten by ten by ten, each one holding a single number that says how far inside the slab it is.",
		"The surface is where that number crosses zero. Somebody built this on a grid. The grid is 66 centimetres. I've measured it four times.",
	],
	"topic": true,
	"goto": "menu",
},

"topic_suit": {
	"speaker": "Hale",
	"instead": "topic_suit_again",
	"lines": [
		"Contract says anything in the chamber wears one. The white-suits wrote the contract.",
		"They also wrote down which slice every reading was taken from. That's the bit that bothers me. You don't write that down for a rock.",
	],
	"topic": true,
	"goto": "menu",
},

"topic_lattice": {
	"speaker": "Hale",
	"instead": "topic_lattice_again",
	"lines": [
		"The old rock in the field was eight on a side - four thousand and ninety-six points. This is ten. Ten thousand.",
		"Whole, it's one thousand three hundred and sixty-eight tetrahedra. That's all it takes to draw it. Everything down here - the cave, the lot - is sixty-seven thousand.",
	],
	"topic": true,
	"goto": "menu",
},

"topic_cost": {
	"speaker": "Hale",
	"instead": "topic_cost_again",
	"lines": [
		"Every blow it re-contours the entire field. Not the bit you hit. All of it. A hundred and seventy milliseconds, give or take a few.",
		"Here's the odd part. The old rock in the field has a quarter of the points and takes LONGER - two hundred a blow. It isn't the points. It's the skin: that one rebuilds five hundred and forty-four boxes every hit. This starts with sixty-three.",
	],
	"topic": true,
	"goto": "menu",
},

"topic_colliders": {
	"speaker": "Hale",
	"instead": "topic_colliders_again",
	"lines": [
		"Every point on its surface carries its own little box, for your pick to find. Sixty-three of them, whole.",
		"Five blows in, three hundred and sixty-three. You take it away and there's MORE of it to touch. The white-suits did not like that at all.",
		"It's just the inside coming to the surface, I tell them. They write that down too.",
	],
	"topic": true,
	"goto": "menu",
},

"topic_deep": {
	"speaker": "Hale",
	"instead": "topic_deep_again",
	"lines": [
		"Three pieces sit further through W than a blow can reach. It's as deep that way as it is wide - look at it with your slice turned and it's the same slab.",
		"So hollow it from here, turn the slice, and dig again from a side of it that wasn't there a minute ago. Nobody on the crew will. You might.",
	],
	"topic": true,
	"goto": "menu",
},

## SECOND VISITS ARE ONE LINE, the professor's rule: the first pass is for the idea, the
## second for the number you half-remember.
"topic_what_again": {
	"speaker": "Hale",
	"lines": ["A lattice. Ten to the fourth, sixty-six centimetres apart. Somebody's grid."],
	"goto": "menu",
},

"topic_suit_again": {
	"speaker": "Hale",
	"lines": ["Contract says wear it. The contract also says which slice. Draw your own conclusions."],
	"goto": "menu",
},

"topic_lattice_again": {
	"speaker": "Hale",
	"lines": ["Ten thousand points. Thirteen hundred and sixty-eight tetrahedra, whole. Doesn't sound like much until you swing at it."],
	"goto": "menu",
},

"topic_cost_again": {
	"speaker": "Hale",
	"lines": ["The whole field, every blow, a sixth of a second. And the skin costs more than the size. It never takes a shortcut."],
	"goto": "menu",
},

"topic_colliders_again": {
	"speaker": "Hale",
	"lines": ["Sixty-three boxes whole, three hundred and sixty-three after five blows. Less of it, more to touch."],
	"goto": "menu",
},

"topic_deep_again": {
	"speaker": "Hale",
	"lines": ["Three out of reach through W. Dig, turn your slice, dig again. Same slab, different hole."],
	"goto": "menu",
},

"bye": {
	"speaker": "Hale",
	"lines": ["Keep to the boards. The white-suits count footprints."],
	"goto_if_asked": "menu",
},

"bye_work": {
	"speaker": "Hale",
	"lines": ["Right. I'll be here, looking at it. It's mostly what the job is now."],
	"goto_if_asked": "menu",
},

}
