@tool
extends Resource

## A W Exploder preset (w_exploder_4d.gd): every number that shapes a planting through W, to keep, share and
## swap. Set one on the Exploder's `preset` and it takes these numbers (and can be changed after); the
## Exploder's "Save as preset" writes one from what it has. The presets that ship are in presets/, tested in
## the exploder lab (WTools/research/experiments.md).
##
## No class_name (engine_gotchas.md).

const FIELDS := ["layer_spacing", "w_reach", "w_jitter", "share", "auto_share", "crown_w_reach", "shift", "size_jitter",
	"swap_share", "turn_zx", "turn_xw", "turn_zw", "trunk_w_slab", "taper_top", "copies_solid", "copies_projected", "target_angle",
	"view_distance"]

## What it is for, in a line (shown nowhere but here and in the README).
@export_multiline var note: String = ""
@export_range(1.0, 20.0, 0.25, "suffix:m") var layer_spacing: float = 4.5
@export_range(0.0, 80.0, 0.5, "suffix:m") var w_reach: float = 18.0
@export_range(0.0, 4.0, 0.05, "suffix:m") var w_jitter: float = 0.8
@export_range(0.0, 1.0, 0.01) var share: float = 0.62
@export var auto_share: bool = true
@export_range(0.5, 10.0, 0.1, "suffix:m") var crown_w_reach: float = 3.6
@export var shift: Vector2 = Vector2(0.8, 2.2)
@export_range(0.0, 0.4, 0.01) var size_jitter: float = 0.12
@export_range(0.0, 1.0, 0.01) var swap_share: float = 0.3
@export var turn_zx: bool = true
@export var turn_xw: bool = true
@export var turn_zw: bool = false
@export_range(0.0, 1.2, 0.05) var trunk_w_slab: float = 0.9
@export_range(0.05, 1.0, 0.05) var taper_top: float = 0.45
@export var copies_solid: bool = true
@export var copies_projected: bool = false
@export_range(1.0, 80.0, 1.0, "suffix:deg") var target_angle: float = 30.0
@export_range(5.0, 120.0, 1.0, "suffix:m") var view_distance: float = 40.0


func apply_to(exploder: Object) -> void:
	for f in FIELDS:
		exploder.set(f, get(f))


func take_from(exploder: Object) -> void:
	for f in FIELDS:
		set(f, exploder.get(f))
