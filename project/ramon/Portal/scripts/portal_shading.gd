extends RefCounted
## Applies the Portal scenes' flat shading, which is PhaseMaze's with an ambient
## floor added.
##
## Use this instead of FlatShadingRamon anywhere in these scenes. The difference
## is one line in the shader and it matters a lot: the original maps a
## straight-down normal to zero brightness, so undersides, ceilings and the lips
## above openings render pure black and read as missing geometry. See the shader
## for the full account.

const FlatShadedShader := preload("res://ramon/Portal/shaders/portal_flat_shaded.gdshader")


## Swaps a TetraMaterial4D's cross-section shader. Must be called BEFORE the
## albedo texture is assigned: Material4D only fills an empty shader slot, and
## setting the texture afterwards re-runs update_cross_section_material() so the
## texture is pushed at the replacement rather than left unbound.
static func apply(material: TetraMaterial4D) -> void:
	material.get_cross_section_material().shader = FlatShadedShader
