extends Node

## What the three researchers are saying to each other, overheard as you pass - and what
## they shout when you take a pick to the thing they have spent three weeks measuring.
##
## NOT CONVERSATIONS. The miner is the one who talks to you; these three are working, and
## a whole dialogue each would make a site into a queue of interviews. So each of them has
## a handful of lines that appear over their head while you are near and change every few
## seconds - you catch the site's mood without anyone turning round. The lines are the
## mystery told sideways: none of them explains the slab, all of them are worried about it.
##
## THEY ARE STUDYING IT AND THEY DO NOT KNOW WHAT IT IS. Ramon: "they are studying the
## voxel artifact, they don't know where it came from". So what you overhear is people
## measuring something that has no provenance - no quarry, no tool marks, no date that
## means anything - and trying to stay professional about it. Walk right up to one and
## they stop muttering and address you: this is delicate equipment, please don't touch
## anything. Polite, a little strained, and the only thing any of them says TO you until
## you give them a reason to shout.
##
## AND AFTERWARDS, UP CLOSE, THE DATA WAS GOOD. Ramon: "when you talk to them afterwards
## ... hitting it was bad but we did get more data, the voxel data on each hit". Walk up to
## one of them once it has calmed down and they will tell you so, grudgingly - and the
## numbers they give are read off the slab as it is at that moment (its collider count,
## the blows they have logged), so what they say stays true however much you have dug.
##
## THEY DO NOT ENCOURAGE YOU. Ramon, 28 Sept: "as you start mining the monolith ... the
## researchers there are panicking as you break that thing apart. They probably won't
## encourage you." Every blow sets all three off at once - they turn to you, hands up, and
## their lines are heard across the chamber, not just up close. When it dies down they do
## not go back to work as if nothing happened: from the first blow on, what they mutter is
## about you, and it gets worse the more you dig. The gold is still yours to take. Nobody
## down here is going to tell you it was a good idea.

@export var player_path: NodePath = NodePath("../../../Player")
## The pen's pickaxe, whose `mined` signal is every blow.
@export var pickaxe_path: NodePath = NodePath("../../../Systems/Pickaxe")
## One tag per researcher. Each tag's own anchor is the head it hangs over, and the reach
## is measured to it, like every other tag in the pen.
@export var tag_paths: Array[NodePath] = []
## The researchers themselves, in the same order, so a blow can make them react.
@export var figure_paths: Array[NodePath] = []
## The slab, whose collider count the researchers quote.
@export var monolith_path: NodePath = NodePath("../../Monolith")
@export_range(1.0, 12.0, 0.5) var hear_within: float = 4.5
## Closer than this and they talk to you instead of to each other.
@export_range(0.5, 6.0, 0.1) var address_within: float = 2.6
@export_range(0.5, 6.0, 0.5) var hear_within_w: float = 2.0
@export_range(1.0, 15.0, 0.5) var seconds_per_line: float = 5.5
## How long a blow keeps them shouting, and how far away you can hear it.
@export_range(1.0, 20.0, 0.5) var panic_seconds: float = 7.0
@export_range(2.0, 40.0, 1.0) var shout_within: float = 22.0

const LINES := [
	[
		"Level it again. It moved.",
		"Nothing moved. The number moved.",
		"No quarry, no tool marks. It didn't come from anywhere we can find.",
		"Same reading from the other side. Write down which slice we took that from.",
	],
	[
		"Every sample comes up with the same structure. Every one.",
		"Dating it is meaningless. There's nothing in it to date.",
		"It's not stone. Stone doesn't agree with itself this much.",
		"Older than the hill. Possibly older than the question.",
	],
	[
		"Remesh log's in. Ten thousand points, every single time.",
		"Why would anyone build a thing that recomputes itself when it's touched?",
		"The plinth's older than anything else down here. The slab isn't the same age as the plinth.",
		"Upload failed. Of course the upload failed. We're in a hill.",
	],
]

## When you walk right up to them, calm: what they say TO you.
const ADDRESS := [
	["This is delicate equipment. Please don't touch anything.", "Mind the tripod, please. It's levelled to a tenth of a millimetre.", "Sorry - could you not stand in the line of sight?"],
	["Careful. Please don't touch anything.", "Those cases are samples. Please leave them be.", "It's fine. You're fine. Just don't touch it."],
	["Please don't touch anything. We're mid-reading.", "Visitors stay on the boards, please.", "If you want to know what it is, so do we."],
]

const PANIC := [
	["STOP! Stop hitting it!", "Put the pick DOWN!", "You're changing the readings!", "Hale! HALE! They're hitting it!"],
	["Get back from it!", "Oh no. Oh no no no.", "It's warm - it's getting WARM!", "Don't touch the seam!"],
	["Remesh spike! It's recomputing!", "Ten thousand points and you just moved every one!", "Who authorised this?!", "Log it. LOG IT."],
]

## Up close after a blow, calm again: it was a bad idea, and the data is excellent.
## %b is replaced with the blows logged so far, %c with the slab's collider count now.
const ADDRESS_AFTER := [
	["That was a bad idea. ...The readings off it are the cleanest we've had, though.", "Every blow, all ten thousand points re-worked. We logged every one. That's %b now.", "Don't do it again. Or - if you do, tell us first so we can start the scan."],
	["You scared the life out of me. But look - the fresh faces are cleaner than anything on the outside.", "It's warmer where you cut it. We have the temperature on every blow.", "I'm not saying thank you. The samples are good."],
	["Sixty-three colliders when we started. %c now. You made more of it by taking some away.", "A hundred and seventy milliseconds a blow, near enough. The most consistent thing about it.", "Bad. Very bad. Best data of the whole dig."],
]

## After the first blow, instead of LINES. Worse the more you have taken.
const AFTER := [
	["Every time you hit it, the reading changes. Every time.", "We had three weeks of baseline. HAD.", "It was whole when we found it. It was whole for a very long time."],
	["Please. Just... leave it alone.", "Whatever's inside it, it wasn't asking to come out.", "My hands are shaking. Look at them."],
	["Colliders up again. There's more of it every time you take some away.", "I'm writing your name down.", "If it stops recomputing, I want it on record that it was you."],
]

var _player: Node4D
var _tags: Array[WorldTag4D] = []
var _figures: Array[Node] = []
var _t := 0.0
var _panic := 0.0
var _blows := 0


func _ready() -> void:
	_player = get_node_or_null(player_path) as Node4D
	for path in tag_paths:
		_tags.append(get_node_or_null(path) as WorldTag4D)
	for path in figure_paths:
		_figures.append(get_node_or_null(path))
	_listen()


## Connected on every arrival - the cave is kept between visits (pen_crossing_4d keep_scene)
## and comes back into the tree without _ready.
func _enter_tree() -> void:
	if is_node_ready():
		_listen()


func _listen() -> void:
	var pick: Node = get_node_or_null(pickaxe_path)
	if pick != null and pick.has_signal("mined") and not pick.is_connected("mined", _on_mined):
		pick.connect("mined", _on_mined)


func _exit_tree() -> void:
	# The pickaxe is the pen's and outlives this scene; leaving a connection to a freed
	# node on it would error on the next swing in the field.
	var pick: Node = get_node_or_null(pickaxe_path)
	if pick != null and pick.is_connected("mined", _on_mined):
		pick.disconnect("mined", _on_mined)


## A blow landed on the slab.
func _on_mined(_at: Vector4 = Vector4.ZERO, _radius: float = 0.0) -> void:
	_blows += 1
	_panic = panic_seconds
	for figure in _figures:
		if figure != null and figure.has_method("panic") and _player != null:
			figure.call("panic", panic_seconds, _player.global_position)


## How many blows they have seen, for anything that wants to know.
func blows() -> int:
	return _blows


func is_panicking() -> bool:
	return _panic > 0.0


func _process(delta: float) -> void:
	_t += delta
	_panic = maxf(_panic - delta, 0.0)
	if _player == null:
		return
	for i in _tags.size():
		var tag: WorldTag4D = _tags[i]
		if tag == null:
			continue
		var head: Node4D = tag.get_node_or_null(tag.anchor_path) as Node4D
		if head == null:
			continue
		var gap: Vector4 = head.global_position - _player.global_position
		var reach: float = shout_within if _panic > 0.0 else hear_within
		if Vector2(gap.x, gap.z).length() > reach or absf(gap.w) > hear_within_w * (2.0 if _panic > 0.0 else 1.0):
			tag.clear()
			continue
		var lines: Array
		var every: float = seconds_per_line
		var close: bool = Vector2(gap.x, gap.z).length() <= address_within
		if _panic > 0.0:
			lines = PANIC[i % PANIC.size()]
			every = 1.6
		elif _blows > 0 and close:
			lines = ADDRESS_AFTER[i % ADDRESS_AFTER.size()]
			every = 4.0
		elif _blows > 0:
			lines = AFTER[i % AFTER.size()]
		elif close:
			lines = ADDRESS[i % ADDRESS.size()]
			every = 3.5
		else:
			lines = LINES[i % LINES.size()]
		# Offset per speaker, so the three are not all changing line at the same moment.
		var n: int = int((_t + float(i) * 1.9) / every) % lines.size()
		if _blows > 0 and _panic <= 0.0 and not close:
			# The more you have taken, the further down the list they have got.
			n = mini(n, mini(_blows, lines.size()) - 1) if _blows < lines.size() else n
		tag.show_text(_fill(String(lines[n])))


## The live numbers in a line: blows logged, and the slab's collider count as it is now.
func _fill(line: String) -> String:
	if line.contains("%b"):
		line = line.replace("%b", str(_blows))
	if line.contains("%c"):
		var slab: Node = get_node_or_null(monolith_path)
		var voxels: Node = slab.get_node_or_null("Voxels") if slab != null else null
		var count: int = 0
		if voxels != null:
			for child in voxels.get_children():
				if not child.is_queued_for_deletion():
					count += 1
		line = line.replace("%c", str(count))
	return line
