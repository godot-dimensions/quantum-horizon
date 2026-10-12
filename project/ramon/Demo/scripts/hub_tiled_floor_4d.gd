@tool
extends Node4D

## A single box whose dev texture actually repeats, rather than stretching once
## across the whole slab.
##
## WHY A FORKED SHADER. The project's normal way to texture a surface - used by
## phase_maze_builder.gd and gallery_target_ramon.tscn - is
## `cell_texture_map = FILL_EACH_SIDE` plus
## `albedo_source = TEXTURE3D_CELL_UVW_ONLY`, leaving the mesh's texture map
## alone. That maps exactly ONE texture per side. It looks right there because
## every maze wall is its own box, so repetition comes from having many boxes.
##
## That does not scale to a floor. Two earlier attempts are worth not repeating:
## rewriting the mesh's texture map (skewed, because the map is per simplex-cell
## vertex and the shader interpolates it along sliced edges, so the box's own
## tetrahedralisation shows through), and building a grid of boxes (works, but it
## is a stand-in for tiling rather than tiling, and costs thousands of nodes).
##
## The stock fragment stage samples `texture(albedo_texture, uvw)` directly, so
## there is nowhere in the data to express a repeat. Multiplying uvw before the
## lookup is the only place it can happen, which is what
## `shaders/hub_tiled_surface.gdshader` adds. That fork also carries `light()`
## across, so unlike the other two forks in this project the surface stays lit.
##
## With FILL_EACH_SIDE each side spans 0..1, so tiles-per-side is just side
## length divided by [member texture_metres] - no calibration by eye.

const Palette := preload("res://ramon/Demo/scripts/hub_palette.gd")
const SurfaceMaterial := preload("res://ramon/Demo/scripts/hub_material_4d.gd")

## Marks the generated child so a rebuild clears exactly what it made. Nothing
## here is owned by the scene, so it is never serialised into the .tscn -
## `MeshInstance4D.mesh` is a stored property, and assigning generated geometry to
## one bakes the whole tetrahedral array into the scene file.
const GENERATED_META := "hub_generated"

@export_tool_button("Rebuild floor") var _rebuild_action: Callable = rebuild

@export var size: Vector4 = Vector4(48.0, 1.0, 48.0, 80.0):
	set(value):
		size = value
		rebuild()

## Metres covered by one texture. 1.0 means the grid lines really are a metre
## apart, which is the convention the dev textures were authored to.
@export_range(0.1, 32.0, 0.1, "suffix:m") var texture_metres: float = 1.0:
	set(value):
		texture_metres = value
		rebuild()

@export var palette_color: String = "grey":
	set(value):
		palette_color = value
		rebuild()

## Falls back to flat albedo sampled from the same PNG and the stock shader.
## Useful for checking geometry independently of the texture.
@export var use_dev_textures: bool = true:
	set(value):
		use_dev_textures = value
		rebuild()


func _ready() -> void:
	rebuild()


func rebuild() -> void:
	if not is_inside_tree():
		return

	for child in get_children():
		if child.has_meta(GENERATED_META):
			child.queue_free()
			remove_child(child)

	var mesh := BoxTetraMesh4D.new()
	mesh.size = size
	# Each side gets the full 0..1 range, matching the rest of the project. The
	# fork's uv_scale then turns that into a repeat count.
	mesh.cell_texture_map = BoxTetraMesh4D.BOX_CELL_TEXTURE_MAP_FILL_EACH_SIDE

	var surface := MeshInstance4D.new()
	surface.name = "Surface"
	surface.mesh = mesh
	surface.material_override = SurfaceMaterial.surface(palette_color, size, texture_metres, use_dev_textures)
	surface.set_meta(GENERATED_META, true)
	add_child(surface)


## Turns [member palette_color] into a dropdown of whatever is actually in
## textures/dev_finals/, rather than a free-text field where a typo silently falls
## back to flat magenta.
##
## Applied as a hint at inspect time instead of an @export_enum so the property
## stays a plain String - the palette is read from disk, and baking its contents
## into the type would defeat the point of scanning.
func _validate_property(property: Dictionary) -> void:
	if property.name == &"palette_color":
		# SUGGESTION rather than plain ENUM. PROPERTY_HINT_ENUM on a String is the
		# fragile pairing - the inspector treats an enum hint as index-based in
		# several paths, so entries could fail to round-trip depending on their
		# position in the list. SUGGESTION is the hint meant for a String with
		# known-good values: it stores the name, not an index, and still allows
		# typing one that is not listed.
		property.hint = PROPERTY_HINT_ENUM_SUGGESTION
		property.hint_string = Palette.get_names_hint()
