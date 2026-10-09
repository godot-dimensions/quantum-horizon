extends RefCounted

## Kit: the gallery's player. LabKit's lab player (LabKit/lab_player.gd: the pen's walker, gait
## and orbit camera, built in code) with the grown-up body (kit_avatar_4d.gd) put in place of the
## chibi, and its collision grown to fit. Only the gallery's rooms build this one; the pen and the
## other labs keep the player they had (Ramon, 4 Oct: "nothing I want inherited").
##
## NO class_name (engine_gotchas.md): preload it and call make().

const LabPlayer := preload("res://ramon/Arboretum/botany_lab/carried/LabKit/lab_player.gd")
const Avatar := preload("res://ramon/Arboretum/botany_lab/carried/kit/kit_avatar_4d.gd")
const RunGait := preload("res://ramon/Arboretum/botany_lab/carried/kit/kit_run_gait_4d.gd")


static func make() -> CharacterBody4D:
	var body: CharacterBody4D = LabPlayer.make(LabPlayer.GREY_SUIT, LabPlayer.GREY_TRIM, LabPlayer.GREY_HAIR)
	# Not in the tree yet, so the chibi has built nothing: swap the script and it never will.
	var avatar: Node4D = body.get_node("Avatar")
	avatar.set_script(Avatar)
	avatar.set("skin", LabPlayer.GREY_TRIM)
	avatar.set("hair", LabPlayer.GREY_HAIR)
	# The run (Ramon, 4 Oct: "he should run, and very elegantly ... a run is like a jump almost ...
	# a dynamic stop"): the lab's own gait in place of the block gait (kit_run_gait_4d.gd), a run by
	# default, ALT to walk, SHIFT to sprint; and momentum: about 0.4 s to get up to a run, and as long
	# to stop (some 0.65 m of slide), so the stop has something to carry.
	var gait: Node = body.get_node("Gait")
	gait.set_script(RunGait)
	body.set("walk_speed", 1.3)
	body.set("run_speed", 2.8)
	body.set("sprint_speed", 4.2)
	body.set("acceleration", 2.6)
	var shape: CollisionShape4D = body.get_node("CollisionShape4D")
	var capsule := CapsuleShape4D.new()
	capsule.radius = 0.26
	capsule.full_height = 1.84
	shape.shape = capsule
	shape.position = Vector4(0.0, 0.92, 0.0, 0.0)
	return body
