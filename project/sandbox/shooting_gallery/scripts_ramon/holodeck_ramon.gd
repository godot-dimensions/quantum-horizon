extends Node4D
## Ramon-only "holodeck" backdrop: a physical, tiled grid enclosure (ceiling
## + all 4 walls, forming a full room) built from many small ramdev_black.
## png-textured panels, using the exact same "many small tiles, not one huge
## stretched texture" technique already proven on blackfloor/BlueFloor's own
## tile grids earlier in this project - FILL_EACH_SIDE (cell_texture_map=1)
## always maps the WHOLE texture onto whatever single face it's given,
## regardless of that face's size, so one giant panel would just show one
## enormous stretched copy; repeating many same-sized small panels is what
## actually produces a tiled look, same as a real tiled floor/wall.
##
## An earlier version only built the ceiling and one distant back wall -
## looking sideways or back toward spawn still showed the flat void
## instead, an inconsistent "partial holodeck" look. This is now a full
## enclosing room (ceiling + all 4 walls) at a consistent ROOM_HALF_EXTENT.
##
## This is a physical geometric stand-in for a skybox, not a real
## Sky/Environment - the cross-section renderer builds its own internal
## World3D directly via RenderingServer calls (confirmed while building the
## ray beam and poof effects, and again when darkening the background in
## scene_environment_ramon.gd), not as a real Node3D/WorldEnvironment scene
## member, so there's no accessible hook from GDScript to attach a real
## PanoramaSkyMaterial to it. Building actual tiled geometry sidesteps that
## entirely.
##
## Each tile is deliberately thick in w (see TILE_W_THICKNESS) rather than a
## thin slab at w=0 - the player can slice-rotate to view a wide range of w
## (the black stalker alone spawns anywhere in +-SPAWN_W_RANGE), and a
## backdrop that only existed at w=0 would vanish the moment you rotated
## away from that exact slice. Comfortably covers the same w range every
## other spawner in this scene already uses.

const TILE_SIZE := 8.0
const TILE_W_THICKNESS := 24.0 # Comfortably covers every spawner's own w-range in this scene.

## Divides evenly by TILE_SIZE (11 tiles per side) - avoids a partial-tile
## seam at the room's edges.
const ROOM_HALF_EXTENT := 44.0
const ROOM_FLOOR_Y := -5.0
const ROOM_CEILING_Y := 35.0

const BackdropTexture := preload("res://textures/dev_finals/ramdev_black.png")


func _ready() -> void:
	var material := TetraMaterial4D.new()
	material.albedo_source = 3
	material.albedo_texture_3d = BackdropTexture

	_build_ceiling(material)
	_build_wall(material, true, -ROOM_HALF_EXTENT) # Left wall (fixed x).
	_build_wall(material, true, ROOM_HALF_EXTENT) # Right wall (fixed x).
	_build_wall(material, false, -ROOM_HALF_EXTENT) # Back wall (fixed z).
	_build_wall(material, false, ROOM_HALF_EXTENT) # Front wall (fixed z).


func _build_ceiling(material: TetraMaterial4D) -> void:
	var mesh := BoxTetraMesh4D.new()
	mesh.size = Vector4(TILE_SIZE, 0.5, TILE_SIZE, TILE_W_THICKNESS)
	mesh.cell_texture_map = 1

	var count: int = int(ROOM_HALF_EXTENT * 2.0 / TILE_SIZE)
	var start: float = -ROOM_HALF_EXTENT + TILE_SIZE * 0.5
	for xi in count:
		for zi in count:
			var tile := MeshInstance4D.new()
			tile.mesh = mesh
			tile.material_override = material
			tile.position = Vector4(start + xi * TILE_SIZE, ROOM_CEILING_Y, start + zi * TILE_SIZE, 0.0)
			add_child(tile)


## fixed_axis_is_x true builds a wall at a fixed x (spanning z and y) - a
## side wall; false builds a wall at a fixed z (spanning x and y) - the
## back/front wall. fixed_value is that fixed x or z coordinate.
func _build_wall(material: TetraMaterial4D, fixed_axis_is_x: bool, fixed_value: float) -> void:
	var mesh := BoxTetraMesh4D.new()
	if fixed_axis_is_x:
		mesh.size = Vector4(0.5, TILE_SIZE, TILE_SIZE, TILE_W_THICKNESS)
	else:
		mesh.size = Vector4(TILE_SIZE, TILE_SIZE, 0.5, TILE_W_THICKNESS)
	mesh.cell_texture_map = 1

	var horiz_count: int = int(ROOM_HALF_EXTENT * 2.0 / TILE_SIZE)
	var vert_count: int = int((ROOM_CEILING_Y - ROOM_FLOOR_Y) / TILE_SIZE)
	var horiz_start: float = -ROOM_HALF_EXTENT + TILE_SIZE * 0.5
	var vert_start: float = ROOM_FLOOR_Y + TILE_SIZE * 0.5
	for hi in horiz_count:
		for vi in vert_count:
			var tile := MeshInstance4D.new()
			tile.mesh = mesh
			tile.material_override = material
			var horiz: float = horiz_start + hi * TILE_SIZE
			var vert: float = vert_start + vi * TILE_SIZE
			tile.position = Vector4(fixed_value, vert, horiz, 0.0) if fixed_axis_is_x else Vector4(horiz, vert, fixed_value, 0.0)
			add_child(tile)
