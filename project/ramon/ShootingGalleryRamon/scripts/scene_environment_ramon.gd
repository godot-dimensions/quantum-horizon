extends Node
## Ramon-only: darkens the empty-space background behind everything else.
## RenderingServer.set_default_clear_color() is the project-wide fallback
## background used whenever a viewport/world doesn't define its own
## environment/sky - the cross-section renderer's internal World3D
## (built directly via RenderingServer calls, not a real Node3D/
## WorldEnvironment scene member - confirmed while building the ray beam
## and poof effects) doesn't expose a dedicated background color property
## from GDScript, so this project-wide fallback is the most direct lever
## available for it.

const BACKGROUND_COLOR := Color(0.0, 0.0, 0.0, 1.0)


func _ready() -> void:
	RenderingServer.set_default_clear_color(BACKGROUND_COLOR)
	# One-time pass over the statically-authored scene (floor, barrier, gun
	# viewmodel, billboard): swaps every baked TetraMaterial4D to flat-shaded so
	# it's visible without a Light4D/WorldEnvironment4D. Dynamically spawned
	# objects (targets, ducks, blockers, etc.) apply this themselves at spawn
	# time instead, since they don't exist yet for this sweep to find.
	#
	# Walks THIS node's own scene, not get_tree().current_scene.
	#
	# current_scene is only the gallery when the gallery was loaded as the
	# current scene. Launch it from the menu - which adds the prototype as a
	# child of the tree root and stays current_scene itself - and this swept the
	# menu's Control tree instead, found no MeshInstance4D, and left every baked
	# tile on the engine's own LIT shader. This room has no lights, so those
	# tiles rendered black. Measured: 70 of 428 materials kept the built-in
	# shader from the menu, 0 of 428 opened directly.
	#
	# `owner` is the root of the scene this node was authored in, whatever the
	# tree looks like around it, so the sweep covers the right subtree either way.
	var scene_root: Node = owner if owner != null else self
	FlatShadingRamon.apply_recursive(scene_root)
