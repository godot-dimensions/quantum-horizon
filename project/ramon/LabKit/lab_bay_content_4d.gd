extends Node4D

## The base of a bay's content: what stands in the bay for one step, and how the step behaves.
## A step's content scene extends this and overrides what it needs; the sequence
## (LabKit/lab_sequence_4d.gd) calls these and nothing else, so the kit knows nothing about any
## particular lab.
##
##   begin(sequence)        the bay is now the one you are in (wake things up, reset the task)
##   end()                  you have left it (it may stop working, it stays as it is)
##   task_done() -> bool    polled every frame until true; then the step unlocks
##   handle_key(event)      a key press while you are in this bay; return true if it was used
##   controls() -> Array    rows for the controls card: [key, what it does] (the task's first)
##   metrics() -> Array     live numbers for the lectern's monitor: [label, value text]
##   demo(t) -> float       the autopilot: perform the step's own task at t seconds into its
##                          demonstration; return how long the whole demonstration lasts
##   rig() -> Node          the bay's main rig, if it has one (for the global view and spin keys)
##
## NO class_name (engine_gotchas.md).

var sequence: Node
## The bay's shell (LabKit/lab_bay_4d.gd), set by the sequence before the content enters the
## tree: its `spot()` gives the places for the rig, the lectern, the zone and the pad.
var shell: Node
var active: bool = false


func begin(seq: Node) -> void:
	sequence = seq
	active = true


func end() -> void:
	active = false


func task_done() -> bool:
	return false


func handle_key(_event: InputEventKey) -> bool:
	return false


func controls() -> Array:
	return []


func metrics() -> Array:
	return []


func demo(_t: float) -> float:
	return 0.0


func rig() -> Node:
	for c in get_children():
		if c.is_in_group("lab_rig"):
			return c
	return null
