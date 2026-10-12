class_name POI4D
extends Node4D
## A single point of interest - a decorative marker representing something
## like a rare-ore deposit, a base building, or a unit, placed directly on
## the terrain's surface (see poi_spawner.gd). Deliberately a real Node4D
## child of the terrain rather than living in a separate world-space list -
## that's what makes it automatically appear/disappear exactly like any
## other terrain geometry as the 4D slice rotates, via the SAME Cross-
## section rendering pipeline this project already uses for everything
## else - no custom visibility logic needed here at all.
##
## Not a game object - no health, no interaction, no gameplay loop. This
## exists to exercise the supporting systems (surface placement, real 4D
## presence, bearing/radar tracking) that gameplay would eventually build
## on top of - see the conversation this was built in.

enum Category {
	ORE,
	BASE,
	UNIT,
}

## Reused by poi_radar.gd so a tracked dot on the radar reads as "which kind
## of thing is this" at a glance - same convention as slice_radar.gd's
## TARGET_COLOR/DUCK_COLOR constants.
const CATEGORY_COLOR := {
	Category.ORE: Color(0.85, 0.65, 0.15, 1.0),
	Category.BASE: Color(0.25, 0.55, 0.95, 1.0),
	Category.UNIT: Color(0.85, 0.2, 0.2, 1.0),
}
const CATEGORY_NAME := {
	Category.ORE: "Ore",
	Category.BASE: "Base",
	Category.UNIT: "Unit",
}
const CATEGORY_MARKER_SIZE := {
	Category.ORE: 1.0,
	Category.BASE: 2.2,
	Category.UNIT: 0.8,
}

@export var category: Category = Category.ORE
@export var display_name: String = ""


func _ready() -> void:
	if display_name.is_empty():
		display_name = CATEGORY_NAME[category]

	var mesh_instance := MeshInstance4D.new()
	mesh_instance.name = "Marker"
	var mesh := BoxTetraMesh4D.new()
	mesh.size = Vector4.ONE * float(CATEGORY_MARKER_SIZE[category])
	mesh_instance.mesh = mesh

	var material := TetraMaterial4D.new()
	material.albedo_source = TetraMaterial4D.TETRA_COLOR_SOURCE_SINGLE_COLOR
	material.albedo_color = CATEGORY_COLOR[category]
	mesh_instance.material_override = material

	add_child(mesh_instance)
