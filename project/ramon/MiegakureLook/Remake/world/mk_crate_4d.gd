extends CharacterBody4D
## Crosswise: a crate you can lift, carry through W and put down (PLAN.md steps 37-41).
##
## A 4D CUBE, THE SAME IN BOTH VIEWS. It is SIZE on all four axes, so turning the view into W shows
## the same crate (Miegakure's lesson: things that look the same in every slice come before true 4D
## shapes). Its body is a slatted crate built by Aaron's FenceGenerator4D (a box footprint, beams on
## every face) round a solid core in yellow, the islands' "use this" colour. Near its W ends the
## slats of its W faces fill the whole floor of the crate (a fence's W faces, seen face-on): what a
## crate looks like at the edge of its own W.
##
## RESTING, it falls with gravity and lands on whatever is under it (floors, plates, other crates);
## the walker can stand on it. CARRIED, its collision is off, it rides overhead at the walker's
## carry point and turns with the view, so it looks the same to you through a turn. If it ever
## falls off the world it goes home (where it was placed in the level) with a puff, and says so.
##
## NO class_name (engine_gotchas.md).

signal went_home

const Build := preload("res://ramon/MiegakureLook/Remake/world/mk_build.gd")
const Mats := preload("res://ramon/MiegakureLook/Remake/world/mk_materials.gd")

const SIZE := 0.7
const FALL_LIMIT_Y := -9.0

## Where it lives (put back here by a reset or a fall).
var home: Vector4 = Vector4.ZERO
var carrier: Node4D = null
## Set by the hands while it rides overhead (world space, recomputed each frame by the carrier).
var carry_point: Vector4 = Vector4.ZERO
var carry_rotation: Projection = Projection.IDENTITY

var _shape: CollisionShape4D
var _visual: Node4D


func _ready() -> void:
	add_to_group(&"mk_crate")
	_shape = CollisionShape4D.new()
	_shape.name = "Collider"
	var box := BoxShape4D.new()
	box.size = Vector4(SIZE, SIZE, SIZE, SIZE)
	_shape.shape = box
	_shape.position = Vector4(0, SIZE * 0.5, 0, 0)
	add_child(_shape)
	_visual = Node4D.new()
	_visual.name = "Visual"
	add_child(_visual)
	var post := Build.fence_material("grey", Color(0.78, 0.78, 0.80))
	var slat := Build.fence_material("yellow", Color(1.0, 0.92, 0.70))
	var f = Build.fence("Slats", SIZE, 0.09, 3, 0.62, 0.0, post, slat, slat)
	f.set("rib_height_ratio", 0.999)
	f.set("beam_max_height_ratio", 0.999)
	f.set("rib_thickness_ratio", 0.7)
	f.set("beam_thickness_ratio", 0.6)
	Build.fence_box(_visual, f, global_position, Vector3(SIZE, SIZE, SIZE))
	f.position = Vector4.ZERO
	var core_size := Vector4(SIZE - 0.16, SIZE - 0.12, SIZE - 0.16, SIZE - 0.16)
	var core := MeshInstance4D.new()
	core.name = "Core"
	core.mesh = Mats.box_mesh(core_size)
	core.material_override = Mats.surface("yellow", core_size, 0.7, {"wface": Build.WFACE, "tint": Color(1.0, 0.88, 0.45)})
	core.position = Vector4(0, core_size.y * 0.5 + 0.04, 0, 0)
	_visual.add_child(core)


func is_carried() -> bool:
	return carrier != null


## Lifted: collision off (so the carrier does not bump into it), no gravity.
func pick_up(by: Node4D) -> void:
	carrier = by
	_shape.collision_layer = 0
	_shape.collision_mask = 0
	linear_velocity = Vector4.ZERO


## Put down at `where` (its foot), square to the world axes, collision back on.
func put_down(where: Vector4) -> void:
	carrier = null
	global_position = where
	_visual.basis = Projection.IDENTITY
	_shape.collision_layer = 1
	_shape.collision_mask = 1
	linear_velocity = Vector4.ZERO


## Back to its home, at once (a reset).
func reset_home() -> void:
	carrier = null
	put_down(home)


func _physics_process(delta: float) -> void:
	if carrier != null:
		global_position = carry_point
		_visual.basis = carry_rotation
		return
	if global_position.y < FALL_LIMIT_Y:
		reset_home()
		went_home.emit()
		return
	if not is_on_floor():
		linear_velocity += get_gravity() * delta
	else:
		linear_velocity.y = minf(linear_velocity.y, 0.0)
	linear_velocity.x = 0.0
	linear_velocity.z = 0.0
	linear_velocity.w = 0.0
	move_and_slide()


## Its box in the world, [centre, size] (for placing and plates).
func bounds() -> Array:
	return [global_position + Vector4(0, SIZE * 0.5, 0, 0), Vector4(SIZE, SIZE, SIZE, SIZE)]
