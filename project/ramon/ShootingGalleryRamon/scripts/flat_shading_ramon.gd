class_name FlatShadingRamon
extends RefCounted
## Applies the old flat/unlit fake-lighting the engine's cross-section shader
## used before Aaron's real 4D light system replaced it, to a TetraMaterial4D.
## Reuses PhaseMaze's own copy of that fix (phase_maze_flat_shaded.gdshader)
## rather than duplicating it - see that file for the shader itself and the
## full rationale. The shooting gallery wants that always-visible per-object
## shading rather than depending on Light4D/WorldEnvironment4D nodes of its
## own, same as Phase Maze - this is purely a project-level material swap, no
## engine changes, so it can't conflict with Aaron's real lighting system.

const FlatShadedShader := preload("res://ramon/PhaseMaze/shaders/phase_maze_flat_shaded.gdshader")


## Swaps a single TetraMaterial4D's cross-section shader for the flat-shaded one.
static func apply(material: TetraMaterial4D) -> void:
	material.get_cross_section_material_3d().shader = FlatShadedShader


## Walks a subtree and applies the swap to every MeshInstance4D found whose
## material_override is a TetraMaterial4D - covers materials pre-baked into a
## .tscn (which can't call apply() themselves) and freshly-instantiated
## sub-scenes alike, without needing every node to carry its own patch-up code.
static func apply_recursive(node: Node) -> void:
	if node is MeshInstance4D and node.material_override is TetraMaterial4D:
		apply(node.material_override)
	for child in node.get_children():
		apply_recursive(child)
