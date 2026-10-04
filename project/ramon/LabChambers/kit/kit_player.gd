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
	var gait: Node = body.get_node("Gait")
	gait.set("reach_fraction", 0.995)
	gait.set("knee_slack", 0.002)
	# A grown-up's walk, not the chibi's bounce (Ramon, 4 Oct: "walks very weird, with his arms
	# swinging harshly ... legs move weird too ... as natural as possible"). A museum pace; the
	# gait's reference speed close to it, so the stride is not cut short at a walk (the stride is
	# scaled by speed against 60% of it) and the clock runs about one cycle in 0.85 s rather than
	# a quick shuffle; arms swinging some 13 degrees, not 34; a 6 cm bob, not 9.5; feet lifting
	# 7 cm; barely any lean.
	body.set("walk_speed", 1.25)
	gait.set("run_speed", 2.4)
	gait.set("stride_length", 0.75)
	gait.set("body_bob", 0.06)
	gait.set("step_height", 0.07)
	gait.set("arm_swing", 0.22)
	gait.set("elbow_bend", 0.15)
	gait.set("run_lean", 0.05)
	var shape: CollisionShape4D = body.get_node("CollisionShape4D")
	var capsule := CapsuleShape4D.new()
	capsule.radius = 0.26
	capsule.full_height = 1.84
	shape.shape = capsule
	shape.position = Vector4(0.0, 0.92, 0.0, 0.0)
	return body
