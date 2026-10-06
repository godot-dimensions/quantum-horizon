extends RefCounted
## Crosswise: assembles the little walker (body, collider, avatar, gait) in code, the way the
## lab kit's lab_player.gd does, so the scene, the probes and the runners all get the same one.
##
## The collider is a box as deep in Z as in W (0.5 m), 1.3 m tall, its foot at the body's origin:
## physics here is axis-aligned boxes only (engine_capabilities.md), so a box says exactly what he
## bumps into, and equal depths in Z and W mean the turn never changes it.
##
## NO class_name (engine_gotchas.md).

const Walker := preload("res://ramon/MiegakureLook/Remake/character/mk_walker_4d.gd")
const Avatar := preload("res://ramon/MiegakureLook/Remake/character/mk_avatar_4d.gd")
const Gait := preload("res://ramon/MiegakureLook/Remake/character/mk_gait_4d.gd")

const BODY_SIZE := Vector4(0.5, 1.3, 0.5, 0.5)


## A walker, not yet in the tree. `camera_path` is set by the caller once both are placed.
static func make() -> CharacterBody4D:
	var body := CharacterBody4D.new()
	body.name = "Walker"
	body.set_script(Walker)
	var shape := CollisionShape4D.new()
	shape.name = "Collider"
	var box := BoxShape4D.new()
	box.size = BODY_SIZE
	shape.shape = box
	shape.position = Vector4(0.0, BODY_SIZE.y * 0.5, 0.0, 0.0)
	body.add_child(shape)
	var avatar := Node4D.new()
	avatar.name = "Avatar"
	avatar.set_script(Avatar)
	body.add_child(avatar)
	var gait := Node4D.new()
	gait.name = "Gait"
	gait.set_script(Gait)
	gait.set("run_speed", 6.0)
	body.add_child(gait)
	return body
