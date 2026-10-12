@tool
extends "res://ramon/chickenpen/scripts/pen_stone_set_4d.gd"

## Every kind of designed-cut stone, every variant, in rows (PenLayout/PLAN_REF_LOCK.md step 13):
## one row a kind, front to back in the order of cut_stone_4d.gd's KINDS, at the size the
## painting's stones come in (about 1.4 m wide and 1.6 m tall for a face block). For the ref stage
## to frame next to crops of the painted twins.


func _ready() -> void:
	var list: Array = []
	var row: int = 0
	for kind in CutStone.KINDS:
		for n in CutStone.VARIANTS:
			list.append([kind, n, Vector4((float(n) - 1.5) * 2.4, 0.0, float(row) * -2.6, 0.0) + Vector4(0, 0.9, 0, 0), Vector4(1.6, 1.6, 1.6, 1.6), 0.25 * float(n), Vector2.ZERO])
		row += 1
	stones = list
	super._ready()
