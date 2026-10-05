extends "res://ramon/QuantumRange/scripts/range_experiment.gd"

## 03 REVEAL THE CORE: the core is always hidden, and the way to it is always through W. The range's most
## four-dimensional experiment. The way of playing: SPATIAL REASONING.
##
##   A  shell       a grey shell no shot breaks, sealed round its core in your slice. It is thin through
##                  W and the core is not: step past the shell (Q or E) and the core is in the open.
##                  In 4D a box has no lid along W.
##   B  cluster     eight white satellites on the 16-cell's vertices guard a locked core. Six are in your
##                  slice; the radar shows the other two, ana and kata.
##   C  capsule     grey petals that open by themselves, through W: in your slice they thin away to their
##                  hinges. Shoot in the window.
##   D  sentinel    a core whose tendrils sweep across its face and through W, with a shell and a capsule
##                  beside it: everything at once

const SHELL := "res://ramon/QuantumRange/scripts/targets/target_shell.gd"
const CLUSTER := "res://ramon/QuantumRange/scripts/targets/target_cluster.gd"
const CAPSULE := "res://ramon/QuantumRange/scripts/targets/target_capsule.gd"
const SENTINEL := "res://ramon/QuantumRange/scripts/targets/target_sentinel.gd"

var _total: int = 0
var _spawned: Array = []
var _resolved: int = 0


func _init() -> void:
	id = "reveal"
	number = 3
	title = "Reveal the Core"
	short = "Reveal"
	tagline = "The way in is through W."
	headline = "A wall in 3D is only a\nwall in some slices."
	explain = "A shell sealed in your slice is open a step away through W; guards hide in slices you are not in. Each stage counts the steps it took."
	w_load = "HIGHEST"
	glyph = "reveal"
	stages = [
		{"title": "Shell", "line": "Grey never breaks. The shell is thin\nthrough W: step past it, E or Q.", "par": 12.0},
		{"title": "Cluster", "line": "Clear the eight satellites. Two are in\nother slices: the radar shows them.", "par": 25.0},
		{"title": "Capsule", "line": "The petals open through W for a\nmoment. Shoot then.", "par": 15.0},
		{"title": "Sentinel", "line": "Shoot a tendril and it recoils.\nThen the core, through the gap.", "par": 30.0},
	]


func begin(i: int) -> void:
	_spawned = []
	_resolved = 0
	match i:
		0:
			_spawned.append(d.spawn(SHELL, ahead(-1.6, 2.0, 9.5)))
			_spawned.append(d.spawn(SHELL, ahead(2.0, 2.4, 12.0)))
		1:
			_spawned.append(d.spawn(CLUSTER, ahead(0.0, 2.3, 10.5)))
		2:
			_spawned.append(d.spawn(CAPSULE, ahead(-1.8, 2.0, 10.0)))
			_spawned.append(d.spawn(CAPSULE, ahead(2.0, 2.2, 12.0), {"phase": 1.9}))
		3:
			_spawned.append(d.spawn(SENTINEL, ahead(0.0, 2.3, 10.5)))
			_spawned.append(d.spawn(SHELL, ahead(-3.4, 1.9, 12.5)))
			_spawned.append(d.spawn(CAPSULE, ahead(3.4, 2.0, 12.5), {"phase": 0.8}))
	_total = _spawned.size()


func tick(_i: int, _dt: float) -> String:
	var live: int = 0
	for t in _spawned:
		if is_instance_valid(t) and bool(t.get("alive")):
			live += 1
	_resolved = _total - live
	return "done" if live == 0 else "run"


func progress(i: int) -> Vector2:
	# The cluster's progress is its satellites, then its core.
	if i == 1 and not _spawned.is_empty() and is_instance_valid(_spawned[0]):
		var c: Node = _spawned[0]
		var gone: int = 0
		for p in c.get("parts"):
			if String(p["role"]) == "cover" and not bool(p["alive"]):
				gone += 1
		return Vector2(gone + (0 if bool(c.get("alive")) else 1), 9)
	return Vector2(_resolved, _total)
