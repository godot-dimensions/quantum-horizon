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
	FlatShadingRamon.apply_recursive(get_tree().current_scene)
