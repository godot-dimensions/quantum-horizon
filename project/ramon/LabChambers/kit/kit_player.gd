extends RefCounted

## Kit: the gallery's player. LabKit's lab player (LabKit/lab_player.gd: the pen's walker, gait
## and orbit camera, built in code) with the grown-up body (kit_avatar_4d.gd) put in place of the
## chibi, and its collision grown to fit. Only the gallery's rooms build this one; the pen and the
## other labs keep the player they had (Ramon, 4 Oct: "nothing I want inherited").
##
## NO class_name (engine_gotchas.md): preload it and call make().

const LabPlayer := preload("res://ramon/LabKit/lab_player.gd")
const Avatar := preload("res://ramon/LabChambers/kit/kit_avatar_4d.gd")


static func make() -> CharacterBody4D:
	var body: CharacterBody4D = LabPlayer.make(LabPlayer.GREY_SUIT, LabPlayer.GREY_TRIM, LabPlayer.GREY_HAIR)
	# Not in the tree yet, so the chibi has built nothing: swap the script and it never will.
	var avatar: Node4D = body.get_node("Avatar")
	avatar.set_script(Avatar)
	avatar.set("skin", LabPlayer.GREY_TRIM)
	avatar.set("hair", LabPlayer.GREY_HAIR)
	# Standing straighter than the chibi: see kit_avatar_4d.gd and the gait's reach_fraction.
	body.get_node("Gait").set("reach_fraction", 0.995)
	body.get_node("Gait").set("knee_slack", 0.002)
	var shape: CollisionShape4D = body.get_node("CollisionShape4D")
	var capsule := CapsuleShape4D.new()
	capsule.radius = 0.28
	capsule.full_height = 1.9
	shape.shape = capsule
	shape.position = Vector4(0.0, 0.95, 0.0, 0.0)
	return body
