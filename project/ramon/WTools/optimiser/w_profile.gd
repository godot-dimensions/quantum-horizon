@tool
extends Resource

## A W Optimiser profile (w_optimiser_4d.gd): the numbers that make a landmark hold when the slice turns, to
## keep, share and swap. Set one on the Optimiser's `profile` and it takes these numbers (and can be changed
## after); "Save as profile" writes one from what it has. The profiles that ship are in profiles/, tested in
## the optimiser lab (WTools/research/experiments.md).
##
## No class_name (engine_gotchas.md).

const FIELDS := ["min_w_half", "deepen_colliders", "respect_w_layout", "wrap", "wrap_arc", "wrap_length", "near_margin", "copies_projected"]

## What it is for, in a line.
@export_multiline var note: String = ""
@export_range(0.0, 80.0, 0.25, "suffix:m") var min_w_half: float = 6.0
@export var deepen_colliders: bool = true
@export var respect_w_layout: bool = true
@export var wrap: bool = false
@export_range(0.0, 89.0, 1.0, "suffix:deg") var wrap_arc: float = 60.0
@export_range(0.0, 200.0, 0.5, "suffix:m") var wrap_length: float = 40.0
@export_range(0.0, 40.0, 0.5, "suffix:m") var near_margin: float = 8.0
@export var copies_projected: bool = false


func apply_to(optimiser: Object) -> void:
	for f in FIELDS:
		optimiser.set(f, get(f))


func take_from(optimiser: Object) -> void:
	for f in FIELDS:
		set(f, optimiser.get(f))
