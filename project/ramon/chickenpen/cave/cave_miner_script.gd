extends RefCounted

## NO class_name, for the reason professor_script.gd gives: preloaded by path it works the
## moment it exists, without waiting for an editor scan.

## The miner in the spacesuit at the foot of the cube: Hale.
##
## THE PROFESSOR'S RULE HOLDS HERE: EVERY NUMBER IS MEASURED. Ramon asked for a miner who
## talks "voxel-rock benchmark details with mystery", and the professor's header is clear
## that a character who explains a system in invented terms is worse than one who says
## nothing. So each figure below comes from _measure_monolith_runner.gd on the cube as it
## stands in cave.tscn, 28 Sept 2026: an 8^4 lattice (4,096 points) at 0.8 m; 6,000
## tetrahedra whole and 6,480 after five blows; 544 surface colliders whole and 522 after
## five blows; 184-208 ms to re-contour after every blow; a 0.96 m bite; six pieces of gold
## of which three sit further through W than one blow reaches (pen_rock_gold_4d.gd). And
## the cave around it, 143,077 tetrahedra with the way through W and the far room (81,951
## in cave.res and 61,126 in cave_far.res, _bake_terrain_runner.gd what=cave and cave_far).
##
## MEASURE LIVE COLLIDERS, NOT CHILDREN. A blow queues the old colliders for freeing and
## adds new ones in the same frame, and a plain child count read 3,195 after five blows -
## more than the cube has points. This script once quoted such a number; it no longer does.
##
## THE MYSTERY IS IN WHAT THE NUMBERS DO, not in anything made up about them. A thing on a
## grid nobody laid, that re-computes all of itself when touched and has skin under its
## skin - those are true of the cube and they are strange, so he finds them strange. He
## never says what it is. Nobody here knows.
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
		"Mind the cables. And don't touch the cube unless you mean to.",
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
		"Pick on your belt, stand close, swing. It takes a bite about two metres across. The white-suits will scream. They're not wrong to.",
		"There's gold in it. Six pieces, the scanners say. Three you can reach from this slice. Three you can't, however close you stand.",
	],
	"topic": true,
	"goto": "menu",
},

"greet_after_strike": {
	"speaker": "Hale",
	"lines": [
		"You hit it. Hear them? The white-suits have been dreading that for three weeks.",
		"Felt the stall, though? A fifth of a second. Four thousand and ninety-six points, all of them, re-worked for a bite the size of your head. It never skips one.",
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
		"Honestly? A lattice. Eight points by eight by eight by eight, each one holding a single number that says how far inside the thing it is.",
		"The surface is where that number crosses zero. Somebody built this on a grid. The grid is eighty centimetres. I've measured it four times.",
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
		"Four thousand and ninety-six points. Whole, it's six thousand tetrahedra - that's all it takes to draw it. Every cut is new surface, so it only gets more.",
		"Everything else down here - the cave, the plinth, the lot - is a hundred and forty-three thousand. The cube's the smallest thing in the room, and the one nobody can explain.",
	],
	"topic": true,
	"goto": "menu",
},

"topic_cost": {
	"speaker": "Hale",
	"instead": "topic_cost_again",
	"lines": [
		"Every blow it re-contours the entire field. Not the bit you hit. All of it. About two hundred milliseconds, every time.",
		"You'd think something that old would have found a shortcut. It hasn't. Or it doesn't want one.",
	],
	"topic": true,
	"goto": "menu",
},

"topic_colliders": {
	"speaker": "Hale",
	"instead": "topic_colliders_again",
	"lines": [
		"Every point on its surface carries its own little box, for your pick to find. Five hundred and forty-four of them, whole.",
		"Five blows in, five hundred and twenty-two. You take the skin off and there's skin under it, nearly as much. The white-suits want to know where it stops.",
		"I tell them it stops where the grid does. They write that down too.",
	],
	"topic": true,
	"goto": "menu",
},

"topic_deep": {
	"speaker": "Hale",
	"instead": "topic_deep_again",
	"lines": [
		"Three pieces sit further through W than a blow can reach. It's as deep that way as it is wide - turn your slice and it's the same cube.",
		"So hollow it from here, turn the slice, and dig again from a side of it that wasn't there a minute ago. Nobody on the crew will. You might.",
	],
	"topic": true,
	"goto": "menu",
},

## SECOND VISITS ARE ONE LINE, the professor's rule: the first pass is for the idea, the
## second for the number you half-remember.
"topic_what_again": {
	"speaker": "Hale",
	"lines": ["A lattice. Eight to the fourth, eighty centimetres apart. Somebody's grid."],
	"goto": "menu",
},

"topic_suit_again": {
	"speaker": "Hale",
	"lines": ["Contract says wear it. The contract also says which slice. Draw your own conclusions."],
	"goto": "menu",
},

"topic_lattice_again": {
	"speaker": "Hale",
	"lines": ["Four thousand and ninety-six points. Six thousand tetrahedra, whole. Doesn't sound like much until you swing at it."],
	"goto": "menu",
},

"topic_cost_again": {
	"speaker": "Hale",
	"lines": ["The whole field, every blow, a fifth of a second. It never takes a shortcut."],
	"goto": "menu",
},

"topic_colliders_again": {
	"speaker": "Hale",
	"lines": ["Five hundred and forty-four boxes whole, five hundred and twenty-two after five blows. Skin under the skin."],
	"goto": "menu",
},

"topic_deep_again": {
	"speaker": "Hale",
	"lines": ["Three out of reach through W. Dig, turn your slice, dig again. Same cube, different hole."],
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
