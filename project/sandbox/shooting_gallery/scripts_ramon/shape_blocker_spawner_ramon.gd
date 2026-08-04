extends Node4D
## Ramon-only "blockers" experiment: repurposes the earlier static shape
## showcase into active obstacles for the yellow-cube shooting gallery.
## Twice as many instances as the original showcase had shapes (2 of each
## of the 9 shape types) - each one slowly patrols back and forth in x and
## wobbles gently in all 4 axes (a lazy "floating underwater" jitter, not
## real physics), meant to drift in front of the yellow cube spawn area on
## the blue floor and make it harder to get a clean shot without clearing
## blockers first.
##
## Most blockers are fragile (textured with ramdev_white.png, 1 hit, 2 of
## each shape) - only Box and Cylinder are "tough" (ramdev_grey.png,
## HP_TOUGH hits, only 1 of each) - a deliberate minority in both count and
## toughness, per "only a few that are harder to break" and later feedback
## that the grey ones were "large and annoying... too many or too hard to
## destroy" - scaled down (Box 1.2->0.8, Cylinder 2.0->1.2), cut from 2 of
## each to 1, and HP_TOUGH dropped 3->2 in response. Both are the actual
## dev_finals textures now (previously flat colors) - several of these
## imported meshes (5-cell, 24-cell, etc.) aren't guaranteed to carry the
## UVW texture-map data TetraMaterial4D's texture albedo source needs, so
## some shapes may not show the texture's grid pattern correctly; flag
## which ones look wrong and they can go back to flat colors individually.
##
## Respawning doesn't destroy a blocker permanently - it moves to a new
## random position, deliberately re-rolling if the new w lands too close
## to the old one, so it isn't sitting in the same slice as before.
##
## Box and Cylinder additionally get a slow scale "breathing" pulse on top
## of the position wobble - same cosmetic-only technique black_stalker_
## spawner_ramon.gd uses for its own breathing effect, just applied to a
## subset of shapes here instead of all of them, for a bit of shape
## variety in how the blockers read while idling. They're also the two
## "tough" shapes - the pulse doubles as a visual cue for which ones take
## more hits.
##
## Movement here is a plain position assignment, not Area4D.move_area() -
## blockers only ever need to be found by hitscan_weapon_ramon.gd's raycast
## query (which doesn't care how a body's transform was last set), not by
## an enter/exit signal. black_stalker_spawner_ramon.gd is the one that
## actually needs move_area(), since it depends on body_entered_self.

const FRAGILE_COUNT := 2
const TOUGH_COUNT := 1
const HP_FRAGILE := 1
const HP_TOUGH := 2

const SPAWN_X_RANGE := 8.5
const SPAWN_Z_RANGE := 4.0
const SPAWN_W_RANGE := 4.0
const HOVER_Y_MIN := 1.0
const HOVER_Y_MAX := 3.0

const PATROL_AMPLITUDE := 2.5 # Meters, x-only.
const PATROL_SPEED_MIN := 0.08
const PATROL_SPEED_MAX := 0.2
const WOBBLE_AMPLITUDE := 0.18 # Meters, all 4 axes - the "floating underwater" jitter.

const BREATH_SPEED := 1.5
const BREATH_AMOUNT := 0.12 # Larger than the stalker's - blockers are meant to be noticed.

const MIN_W_RESPAWN_DELTA := 1.5 # Re-roll once if the new slice lands closer than this to the old one.

const FragileTexture := preload("res://textures/dev_finals/ramdev_white.png")
const ToughTexture := preload("res://textures/dev_finals/ramdev_grey.png")

var _blockers: Array = [] # Array of Dictionary: {node, mesh_instance, base_scale, pulse, tough, base_pos, phase, patrol_speed, hp}
var _elapsed_sec: float = 0.0


func _ready() -> void:
	var mesh_pool := _build_mesh_pool()
	for entry in mesh_pool:
		var count: int = TOUGH_COUNT if entry.tough else FRAGILE_COUNT
		for i in count:
			_spawn_blocker(entry.mesh, entry.scale, entry.pulse, entry.tough)


func _process(delta: float) -> void:
	_elapsed_sec += delta
	for blocker in _blockers:
		var t: float = _elapsed_sec
		var phase: float = blocker.phase
		var patrol_x: float = blocker.base_pos.x + PATROL_AMPLITUDE * sin(t * blocker.patrol_speed + phase)
		var wobble := Vector4(
			sin(t * 2.3 + phase) * WOBBLE_AMPLITUDE,
			sin(t * 1.7 + phase * 1.3) * WOBBLE_AMPLITUDE * 0.3,
			sin(t * 2.9 + phase * 0.7) * WOBBLE_AMPLITUDE,
			sin(t * 2.1 + phase * 1.7) * WOBBLE_AMPLITUDE,
		)
		var base: Vector4 = blocker.base_pos
		blocker.node.position = Vector4(patrol_x, base.y, base.z, base.w) + wobble

		if blocker.pulse:
			var breath: float = blocker.base_scale * (1.0 + sin(t * BREATH_SPEED + phase) * BREATH_AMOUNT)
			blocker.mesh_instance.basis = Projection(
				Vector4(breath, 0, 0, 0),
				Vector4(0, breath, 0, 0),
				Vector4(0, 0, breath, 0),
				Vector4(0, 0, 0, breath),
			)


## Called by hitscan_weapon_ramon.gd. Returns whether the hit body was one of
## the active blockers. Respawns it elsewhere once its hp is depleted.
func try_hit_blocker(hit_body: Object) -> bool:
	for blocker in _blockers:
		if blocker.node == hit_body:
			blocker.hp -= 1
			if blocker.hp <= 0:
				_respawn_blocker(blocker)
			return true
	return false


func _build_mesh_pool() -> Array:
	return [
		{"mesh": BoxTetraMesh4D.new(), "scale": 0.8, "pulse": true, "tough": true},
		{"mesh": OrthoplexTetraMesh4D.new(), "scale": 2.0, "pulse": false, "tough": false},
		{"mesh": preload("res://models/primitives/platonic/5_cell/5_cell.g4b"), "scale": 0.3, "pulse": false, "tough": false},
		{"mesh": preload("res://models/primitives/platonic/24_cell/24_cell_smooth.g4b"), "scale": 0.3, "pulse": false, "tough": false},
		{"mesh": preload("res://models/primitives/platonic/120_cell/120_cell_smooth.g4b"), "scale": 0.3, "pulse": false, "tough": false},
		{"mesh": preload("res://models/primitives/platonic/600_cell/600_cell_smooth.g4b"), "scale": 0.3, "pulse": false, "tough": false},
		{"mesh": preload("res://models/primitives/torisphere/mesh/torisphere2_smooth_ma2_mi0pt5_step14.g4b"), "scale": 0.6, "pulse": false, "tough": false},
		{"mesh": preload("res://models/primitives/spheritorus/mesh/spheritorus_smooth_ma2_mi0pt5_step32.g4b"), "scale": 0.6, "pulse": false, "tough": false},
		{"mesh": preload("res://models/primitives/cylinder/ico/cylinder_smooth_ico2.g4b"), "scale": 1.2, "pulse": true, "tough": true},
	]


func _spawn_blocker(mesh: Mesh4D, scale: float, pulse: bool, tough: bool) -> void:
	var area := Area4D.new()
	add_child(area)

	var collision_shape := CollisionShape4D.new()
	var box_shape := BoxShape4D.new()
	box_shape.size = Vector4(1, 1, 1, 1) * scale * 1.2 # Generous hitbox - a forgiving shooting gallery, not a precision test.
	collision_shape.shape = box_shape
	area.add_child(collision_shape)

	var mesh_instance := MeshInstance4D.new()
	mesh_instance.mesh = mesh
	mesh_instance.basis = Projection(
		Vector4(scale, 0, 0, 0),
		Vector4(0, scale, 0, 0),
		Vector4(0, 0, scale, 0),
		Vector4(0, 0, 0, scale),
	)
	var material := TetraMaterial4D.new()
	material.albedo_source = 3 # TETRA_COLOR_SOURCE_TEXTURE3D_CELL_UVW_ONLY.
	material.albedo_texture_3d = ToughTexture if tough else FragileTexture
	mesh_instance.material_override = material
	area.add_child(mesh_instance)

	var blocker := {
		"node": area,
		"mesh_instance": mesh_instance,
		"base_scale": scale,
		"pulse": pulse,
		"tough": tough,
		"base_pos": Vector4.ZERO,
		"phase": randf_range(0.0, TAU),
		"patrol_speed": randf_range(PATROL_SPEED_MIN, PATROL_SPEED_MAX),
		"hp": HP_TOUGH if tough else HP_FRAGILE,
	}
	_blockers.append(blocker)
	_respawn_blocker(blocker)


func _respawn_blocker(blocker: Dictionary) -> void:
	var old_w: float = blocker.base_pos.w
	var new_w: float = randf_range(-SPAWN_W_RANGE, SPAWN_W_RANGE)
	if absf(new_w - old_w) < MIN_W_RESPAWN_DELTA:
		new_w = randf_range(-SPAWN_W_RANGE, SPAWN_W_RANGE)
	blocker.base_pos = Vector4(
		randf_range(-SPAWN_X_RANGE, SPAWN_X_RANGE),
		randf_range(HOVER_Y_MIN, HOVER_Y_MAX),
		randf_range(-SPAWN_Z_RANGE, SPAWN_Z_RANGE),
		new_w,
	)
	blocker.phase = randf_range(0.0, TAU)
	blocker.patrol_speed = randf_range(PATROL_SPEED_MIN, PATROL_SPEED_MAX)
	blocker.hp = HP_TOUGH if blocker.tough else HP_FRAGILE
