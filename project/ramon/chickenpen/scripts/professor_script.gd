extends RefCounted

## NO class_name. The keeper's and Nessa's scripts register one, and it works because the
## editor has scanned them; a file created outside that scan is not in the global class
## cache yet, and anything referring to it by name fails to parse until the project is
## reopened. Preloaded by path it works the moment it exists.

## The mining professor's dialogue, as data - the same shape the keeper's is in, so the
## player it is handed to needs no new code and this is a file rather than a system.
##
## THE TECHNICAL DETAIL IS ALL TRUE. Every number he quotes is one this project measured:
## the 8^4 field, the whole-field remesh after every hit and what it costs, one BoxShape4D
## per SURFACE voxel and why it cannot be a mesh, the carve as an AIR layer with a
## GROUND-only replace mask, the 0.96 metre bite. A character who explains a system in
## invented terms is worse than one who says nothing, because the player who checks comes
## away trusting the game less. He is funny about things that are true.
##
## THE COMEDY IS THE GAP between the scale of his apparatus and the scale of his subject.
## He has instrumentation, a grant, a helmet with a lamp on it, a four-dimensional field
## solver - and he is standing in a chicken field hitting a rock. He does not find this
## funny, which is what makes it funny.
##
## FOUR REPLIES MAXIMUM, the same budget the keeper keeps, for the same reason: nine
## options is a database query and the eye stops reading and starts scanning.

const START: String = "intro"

const NODES: Dictionary = {

# ---------------------------------------------------------------- first meeting

"intro": {
	"speaker": "Professor",
	"lines": [
		"Ah. An assistant. Or a trespasser. The paperwork is identical, so let us proceed as though it were the first.",
		"This is a boulder. That is the least interesting true statement I can make about it, and I would ask you not to repeat it.",
		"It is a scalar field on an eight-by-eight-by-eight-by-eight lattice, surfaced by dual contouring, and you may hit it with a pick.",
	],
	"choices": [
		{"text": "I can hit it?", "goto": "how_to_mine"},
		{"text": "Dual what?", "goto": "topic_contour"},
		{"text": "Is there anything in it?", "goto": "topic_gold"},
		{"text": "I'll leave you to it.", "goto": "bye", "leave": true},
	],
},

"how_to_mine": {
	"speaker": "Professor",
	"lines": [
		"Take the pick — press one, it is the first thing on your belt — and strike the rock from close range.",
		"Each blow removes a sphere of material about a metre across. Not a hole: a SPHERE. The distinction will matter to you in a moment.",
		"Go on. I have been hitting it alone for two weeks and my notes have begun to repeat themselves.",
	],
	"topic": true,
	"goto": "menu",
},

# ---------------------------------------------------------------- the topics

"menu": {
	"speaker": "Professor",
	"lines": ["Ask. I am contractually obliged to disseminate."],
	"choices": [
		{"text": "What is it actually made of?", "goto": "topic_contour"},
		{"text": "Why does it hitch when I hit it?", "goto": "topic_cost"},
		{"text": "How does it know which bit I hit?", "goto": "topic_collision"},
		{"text": "What do I do once it's open?", "goto": "topic_rotate"},
	],
},

"topic_contour": {
	"speaker": "Professor",
	"instead": "topic_contour_again",
	"lines": [
		"Four thousand and ninety-six points, each holding a number: how far inside the rock it is. Positive within, negative without.",
		"The surface you can see is where that number crosses zero. Dual contouring finds that crossing and fits a vertex to it, which is why the rock has corners instead of stairs.",
		"Carving is not subtraction. It adds a layer of AIR over the top, masked to replace only GROUND — so the rock forgets, but the field remembers everything it was told, in order.",
		"I find that rather moving. My colleagues find it a reason not to sit with me.",
	],
	"topic": true,
	"goto": "menu",
},

"topic_cost": {
	"speaker": "Professor",
	"instead": "topic_cost_again",
	"lines": [
		"Because every blow re-contours the ENTIRE field. All four thousand and ninety-six points, for a bite the size of your head.",
		"About a sixth of a second. You feel it as a stumble. I feel it as the sound of a man who has not yet implemented chunking.",
		"Making the rock twice as large cost nothing, incidentally — the cells were simply told to be bigger. Doubling the LATTICE would have cost sixteen times as much. There is a lesson in that, and it is not about rocks.",
	],
	"topic": true,
	"goto": "menu",
},

"topic_collision": {
	"speaker": "Professor",
	"instead": "topic_collision_again",
	"lines": [
		"Every voxel on the SURFACE carries its own box-shaped collider. Five hundred and forty-four of them, at present count.",
		"Only the surface. A buried voxel gets nothing, on the grounds that a ray from outside can never reach one — the shell always takes the hit first. Colliders for the invisible are how you spend a frame budget on nothing.",
		"And they must be BOXES. The physics here collapses any other shape to a single bounding volume, so a mesh-shaped collider would give you one enormous invisible crate and no way to tell which part of it you struck.",
		"Your pick asks the raycast which shape it hit, and the block looks that shape up in a dictionary. No geometry. A lookup.",
	],
	"topic": true,
	"goto": "menu",
},

"topic_gold": {
	"speaker": "Professor",
	"instead": "topic_gold_again",
	"lines": [
		"There is gold in it. Five pieces, on my last survey, though I concede my last survey was conducted by hitting the rock and looking hopeful.",
		"They are not part of the field — they are simply IN there, waiting for the material in front of them to stop existing. Dig, and they turn up.",
		"Walk into one and it is yours. I have not tried this myself. I am on a grant, and the terms are specific.",
	],
	"topic": true,
	"goto": "menu",
},

"topic_rotate": {
	"speaker": "Professor",
	"instead": "topic_rotate_again",
	"lines": [
		"Now THIS is the part I would like you to actually do, rather than nod at.",
		"Hollow it out, then turn your slice. Hold the W-drag and lean on the mouse.",
		"The hole you dug is a hole in FOUR dimensions, and what you are looking at is one three-dimensional slice of it. Turn the slice and you are not looking at the hole from a new angle — you are looking at a DIFFERENT HOLE. Same rock. Same blow. A shape you have never seen and did not make on purpose.",
		"The first time it happened to me I sat down in the grass. A chicken stood on my clipboard. I have not been the same.",
	],
	"topic": true,
	"goto": "menu",
},

# ---------------------------------------------------------------- second visits

## SECOND VISITS ARE SHORT. A character who delivers the same three-paragraph lecture
## every time you ask is one you stop asking, and the topics are worth asking twice - the
## first pass is for the idea and the second is for the number you half-remember.
"topic_contour_again": {
	"speaker": "Professor",
	"lines": ["A field of numbers, a surface where they cross zero, and a memory of every layer it was ever given. Yes."],
	"goto": "menu",
},

"topic_cost_again": {
	"speaker": "Professor",
	"lines": ["The whole lattice, every blow. A sixth of a second. I have made peace with it in the way one makes peace with a neighbour."],
	"goto": "menu",
},

"topic_collision_again": {
	"speaker": "Professor",
	"lines": ["Boxes on the shell, nothing buried, and a dictionary instead of geometry. Five hundred and forty-four little certainties."],
	"goto": "menu",
},

"topic_gold_again": {
	"speaker": "Professor",
	"lines": ["Still five. Still in there. Still not mine, per the terms."],
	"goto": "menu",
},

"topic_rotate_again": {
	"speaker": "Professor",
	"lines": ["Dig, then turn the slice. Same rock, same blow, a shape you did not make on purpose. Do go and do it."],
	"goto": "menu",
},

"bye": {
	"speaker": "Professor",
	"lines": ["Mind the rock. It is, in a strict sense, four times more rock than it appears."],
	"goto_if_asked": "menu",
},

}
