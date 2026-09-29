extends RefCounted

## NO class_name. The keeper's and Mithra's scripts register one, and it works because the
## editor has scanned them; a file created outside that scan is not in the global class
## cache yet, and anything referring to it by name fails to parse until the project is
## reopened. Preloaded by path it works the moment it exists.

## The mining professor's dialogue, as data - the same shape the keeper's is in, so the
## player it is handed to needs no new code and this is a file rather than a system.
##
## HE IS THE MANUAL FOR THE VOXEL SYSTEM, and that is his job in the scene. Everything the
## rock does that a player cannot see - the field underneath it, the cost of a blow, why
## the colliders are boxes, why a carve is an addition rather than a subtraction - is here
## and nowhere else. A demo of a technology that never says what the technology is asks
## the visitor to be impressed by a rock.
##
## THE CUBE WAS FOUND, NOT BROUGHT (28 Sept 2026). The rock that used to sit in the field is
## the cube on the plinth in the cave (cave/cave.tscn), and in the fiction it was dug out
## of the hill, not carried into it - Ramon: "the monolith should be a discovery". He has
## not been down; he points you in, and his numbers are the cube's, because it is the same
## block VoxelMining ships - re-measured the same day at 184-208 ms a blow, hence "a fifth of
## a second" where it used to say a sixth.
##
## AND HE KNOWS SOMETHING IS OFF DOWN THERE (Ramon: "the professor ... probably knows
## there's something off"). The unease is the lattice itself: a grid of 8^4 points that
## nobody laid, on a plinth older than the hill. True of the cube, and nobody can explain it.
##
## THE TECHNICAL DETAIL IS ALL TRUE. Every number he quotes was measured in this project:
## 8^4 points, the whole-field remesh after every hit and what it costs, one BoxShape4D
## per SURFACE voxel and why it cannot be a mesh, the carve as an AIR layer with a
## GROUND-only replace mask, the 0.96 metre bite, six pieces of azoth of which three sit further
## through W than any single blow can reach. A character who explains a system in invented
## terms is worse than one who says nothing, because the player who checks comes away
## trusting the game less.
##
## SHORT LINES. The first draft gave him three long paragraphs a topic, which reads as a
## lecture however good the sentences are - and a player skimming a lecture learns nothing
## the third of a page they actually read. Two lines, one idea each, one number each. He
## is precise because he is a pedant, not because he is thorough.
##
## THE COMEDY IS THE GAP between the scale of his apparatus and the scale of his subject.
## A grant, a lamp on his helmet, a four-dimensional field solver - and he is standing in
## a chicken field hitting a rock. He does not find this funny.
##
## FOUR REPLIES MAXIMUM, which is why the topics run over two pages instead of seven in a
## column. Nine options is a database query: the eye stops reading and starts scanning.

const START: String = "intro"

const NODES: Dictionary = {

# ---------------------------------------------------------------- first meeting

"intro": {
	"speaker": "Professor Miner",
	"lines": [
		"An assistant, or a trespasser. The paperwork is identical.",
		"They found something in that hill. A cube, on a plinth older than the hill it is in.",
		"A scalar field on an eight-by-eight-by-eight-by-eight lattice. Nobody laid that lattice. Nobody can say who did. I have stopped sleeping well.",
		"And there is something in it that is not rock. Violet, glassy, and never wholly in the slice you are looking at. The suits call it azoth. You, I gather, have a keeper who would take it as payment.",
	],
	"choices": [
		{"text": "I can hit it?", "goto": "how_to_mine"},
		{"text": "A field of what?", "goto": "topic_contour"},
		{"text": "Azoth? What is that?", "goto": "topic_azoth"},
		{"text": "I'll leave you to it.", "goto": "bye", "leave": true},
	],
},

"how_to_mine": {
	"speaker": "Professor Miner",
	"lines": [
		"The hole behind me. Walk in until it gets dark, then keep walking. The miner at the bottom is called Hale; he has newer numbers than mine and fewer opinions.",
		"My instruments have not agreed with one another since the day they opened that hill. I mention it only because nobody down there will.",
		"Pick is on your belt. Press its number, stand close, swing. Each blow takes a sphere about two metres across; the azoth sits a hand's depth under the skin.",
		"Bring what you find to the keeper. He has been waiting years for someone to hand him something.",
	],
	"topic": true,
	"goto": "menu",
},

# ---------------------------------------------------------------- the topics

## A WAY OUT OF EVERY ONE OF THEM. The topics used to run across two menus and only the
## second carried a way to leave, so getting out of the first one meant going further IN -
## you had to ask for more questions in order to stop asking questions. Three menus now,
## four entries each, and the fourth is always the door.
##
## THE FOUR-REPLY CAP IS WHY IT IS THREE MENUS AND NOT ONE LONG ONE. Six topics and a
## leave is seven replies, which is a wall of text where a conversation should be, and
## _verify_script_runner enforces four for exactly that reason. A carousel costs one entry
## per page and keeps every page readable.
"menu": {
	"speaker": "Professor Miner",
	"lines": ["Ask. I am contractually obliged to disseminate."],
	"choices": [
		{"text": "What is it made of?", "goto": "topic_contour"},
		{"text": "Why does it hitch when I hit it?", "goto": "topic_cost"},
		{"text": "Other questions.", "goto": "menu_two"},
		{"text": "I'll go and dig something. Cya.", "goto": "bye_dig", "leave": true},
	],
},

"menu_two": {
	"speaker": "Professor Miner",
	"lines": ["Go on."],
	"choices": [
		{"text": "How does it know which bit I hit?", "goto": "topic_collision"},
		{"text": "Tell me about the azoth again.", "goto": "topic_azoth"},
		{"text": "More.", "goto": "menu_three"},
		{"text": "That's me. Cheers.", "goto": "bye", "leave": true},
	],
},

"menu_three": {
	"speaker": "Professor Miner",
	"lines": ["There is more of it than anybody expects. That is the recurring theme."],
	"choices": [
		{"text": "What happens if I turn the slice?", "goto": "topic_rotate"},
		{"text": "Why a sphere?", "goto": "topic_bite"},
		{"text": "Back to the start.", "goto": "menu"},
		{"text": "Right. I'm off.", "goto": "bye_off", "leave": true},
	],
},

"topic_contour": {
	"speaker": "Professor Miner",
	"instead": "topic_contour_again",
	"lines": [
		"Four thousand and ninety-six points, each holding one number: how far inside the rock it is. Positive within, negative without.",
		"The surface is where that number crosses zero. Dual contouring fits a vertex to the crossing, which is why the rock has corners and not stairs.",
	],
	"topic": true,
	"goto": "menu",
},

"topic_cost": {
	"speaker": "Professor Miner",
	"instead": "topic_cost_again",
	"lines": [
		"Every blow re-contours the entire field. All four thousand and ninety-six points, for a bite the size of your head. A fifth of a second.",
		"Making the rock bigger was free - the cells were told to be wider. Doubling the LATTICE would cost sixteen times as much. There is a lesson in that, and it is not about rocks.",
	],
	"topic": true,
	"goto": "menu",
},

"topic_collision": {
	"speaker": "Professor Miner",
	"instead": "topic_collision_again",
	"lines": [
		"Every voxel on the surface carries its own box collider. Five hundred and forty-four of them. Buried ones get nothing - the shell always takes the hit first.",
		"They must be boxes. This physics collapses any other shape to one bounding volume, so a mesh collider would be a single enormous crate with no way to tell which part you struck.",
		"Your pick asks the raycast which shape it hit and looks that shape up in a dictionary. No geometry. A lookup.",
	],
	"topic": true,
	"goto": "menu",
},

"topic_bite": {
	"speaker": "Professor Miner",
	"instead": "topic_bite_again",
	"lines": [
		"Because carving is not subtraction. It lays a sphere of AIR over the field, masked to replace only GROUND, and the field keeps every layer it was ever given, in order.",
		"The rock forgets. The field remembers. I find that moving; my colleagues find it a reason not to sit with me.",
	],
	"topic": true,
	"goto": "menu",
},

"topic_azoth": {
	"speaker": "Professor Miner",
	"instead": "topic_azoth_again",
	"lines": [
		"Azoth. The alchemists' word for the first matter, the stuff under all the other stuff. The suits borrowed it because nothing in the periodic table would have it.",
		"Its crystal habit is four-dimensional, so every slice of a piece is a different stone. It is warm when nothing near it is. The suits think it seeped out of whatever laid the lattice. I think they read too much. I also think they are right.",
		"Six pieces in the rock. Three within reach of the slice you are standing in; three do not, and no blow from here will ever touch them.",
		"Each one buys a feeding trough from the keeper, who does not care what it is. It will not catch a bird for you. It will save you the walk to where the bird went.",
	],
	"topic": true,
	"goto": "menu",
},

"topic_rotate": {
	"speaker": "Professor Miner",
	"instead": "topic_rotate_again",
	"lines": [
		"A blow reaches about a metre. Three of the six sit further through W than that, so the geometry - not a difficulty setting - says you cannot have them from here.",
		"Hollow it out, hold the W-drag, lean on the mouse. Then dig again from a cross-section that did not exist a moment ago.",
		"The hole you made is a hole in four dimensions. Turn the slice and you are not seeing it from a new angle. You are seeing a different hole. Same rock, same blow.",
	],
	"topic": true,
	"goto": "menu",
},

# ---------------------------------------------------------------- second visits

## SECOND VISITS ARE ONE LINE. A character who delivers the same lecture every time is one
## you stop asking, and these are worth asking twice - the first pass is for the idea, the
## second for the number you half-remember.
"topic_contour_again": {
	"speaker": "Professor Miner",
	"lines": ["A field of numbers, and a surface where they cross zero. Four thousand and ninety-six of them."],
	"goto": "menu",
},

"topic_cost_again": {
	"speaker": "Professor Miner",
	"lines": ["The whole lattice, every blow, a fifth of a second. I have made peace with it as one does with a neighbour."],
	"goto": "menu",
},

"topic_collision_again": {
	"speaker": "Professor Miner",
	"lines": ["Boxes on the shell, nothing buried, a dictionary instead of geometry. Five hundred and forty-four little certainties."],
	"goto": "menu",
},

"topic_bite_again": {
	"speaker": "Professor Miner",
	"lines": ["Air laid over ground, never taken away. The rock forgets and the field does not."],
	"goto": "menu",
},

"topic_azoth_again": {
	"speaker": "Professor Miner",
	"lines": ["Azoth. Six pieces, three here, three a slice away. One trough apiece, and the keeper does the building."],
	"goto": "menu",
},

"topic_rotate_again": {
	"speaker": "Professor Miner",
	"lines": ["Dig, then turn the slice. Same rock, same blow, a shape you did not make on purpose. Do go and do it."],
	"goto": "menu",
},

## THREE WAYS OF SAYING GOODBYE, because one line said every time is a machine and this
## is the one character who would notice. All three come back to the same place if you
## turn round and ask him something else.
"bye": {
	"speaker": "Professor Miner",
	"lines": ["Mind the cube. It is, in a strict sense, four times more cube than it appears."],
	"goto_if_asked": "menu",
},

"bye_dig": {
	"speaker": "Professor Miner",
	"lines": ["Dig something. Yes. That is the correct instinct and I am glad one of us has it."],
	"goto_if_asked": "menu",
},

"bye_off": {
	"speaker": "Professor Miner",
	"lines": ["Off. Right. I shall be here, being rained on by a sky that is only three quarters there."],
	"goto_if_asked": "menu",
},

}
