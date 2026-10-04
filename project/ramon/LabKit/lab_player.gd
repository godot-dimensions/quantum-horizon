extends RefCounted

## The lab's player: the pen's own third-person walker (chickenpen/scripts/block_walker_character_4d.gd
## with its block avatar, gait and orbit camera), built in code so every lab gets the same one and
## any fix to the pen's walk reaches the labs too. The cinema builds its player the same way in
## its scene (theatre/theatre.tscn).
##
## Lab settings: no jumping (Space plays and pauses an exhibit), and no walking through W on Q/E
## (moving between steps along W is the W-lift's job, and the sequence leashes you to the bay you
## are in). Turning the slice with the mouse stays, so the 4D tasks can use it.
##
## NO class_name (engine_gotchas.md): preload and call `make()`.

const Walker := preload("res://ramon/LabKit/carried/chickenpen/scripts/block_walker_character_4d.gd")
const Avatar := preload("res://ramon/LabKit/carried/chickenpen/scripts/block_avatar_4d.gd")
const Gait := preload("res://ramon/LabKit/carried/chickenpen/scripts/block_gait_4d.gd")
const OrbitRig := preload("res://ramon/LabKit/carried/chickenpen/scripts/pen_orbit_rig_4d.gd")


## The gallery's greys (Ramon, 4 Oct: "make main character more a grey, not too colorful"): a mid
## grey tunic, darker head, hands and legs, charcoal hair. Pass them as make(GREY_SUIT, GREY_TRIM,
## GREY_HAIR).
const GREY_SUIT := Color(0.58, 0.59, 0.62)
const GREY_TRIM := Color(0.38, 0.39, 0.42)
const GREY_HAIR := Color(0.20, 0.20, 0.22)


static func make(suit: Color = Color(0.92, 0.93, 0.95), trim: Color = Color(0.20, 0.72, 0.80), hair: Color = Color(-1, -1, -1)) -> CharacterBody4D:
	var body := CharacterBody4D.new()
	body.name = "Player"
	body.set_script(Walker)
	body.set("jump_velocity", 0.0)
	body.set("w_speed_scale", 0.0)
	var shape := CollisionShape4D.new()
	shape.name = "CollisionShape4D"
	var capsule := CapsuleShape4D.new()
	capsule.radius = 0.26
	capsule.full_height = 1.35
	shape.shape = capsule
	shape.position = Vector4(0.0, 0.68, 0.0, 0.0)
	body.add_child(shape)
	var avatar := Node4D.new()
	avatar.name = "Avatar"
	avatar.set_script(Avatar)
	avatar.set("build", 2)
	avatar.set("skin", suit)
	avatar.set("accent", trim)
	avatar.set("wear_cap", false)
	if hair.r >= 0.0:
		avatar.set("hair", hair)
	body.add_child(avatar)
	var gait := Node4D.new()
	gait.name = "Gait"
	gait.set_script(Gait)
	gait.set("run_speed", 4.5)
	body.add_child(gait)
	var rig := Node4D.new()
	rig.name = "CameraRig"
	rig.set_script(OrbitRig)
	body.add_child(rig)
	var pitch := Node4D.new()
	pitch.name = "Pitch"
	rig.add_child(pitch)
	var cam := Camera4D.new()
	cam.name = "Camera4D"
	cam.position = Vector4(0.0, 0.0, 5.0, 0.0)
	cam.current = true
	cam.set("rendering_engine_name", "Cross-section")
	cam.add_to_group("lab_camera")
	pitch.add_child(cam)
	return body
