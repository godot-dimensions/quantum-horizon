@tool
extends MeshInstance4D

## Shows a mesh baked by terrain_bake_4d.gd, with its colours.
##
## The baked file holds the shape and one colour coordinate per vertex, but not the tiny
## colour-cube texture those coordinates look up: an ImageTexture3D made in a headless run
## has no image data to save (the dummy renderer keeps none), so the bake would write an
## empty one. The cube is small and made once a run (terrain_bake_4d.gd), so it is made here.

const TerrainBake := preload("res://ramon/chickenpen/terrain/terrain_bake_4d.gd")

## Multiplies every baked colour - for dimming a whole bake without baking it again.
@export var tint: Color = Color.WHITE: set = _set_tint


func _ready() -> void:
	material_override = TerrainBake.material(tint)


func _set_tint(v: Color) -> void:
	tint = v
	if is_node_ready():
		material_override = TerrainBake.material(tint)
