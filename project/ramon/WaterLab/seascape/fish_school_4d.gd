extends Node4D

## WATER LAB: the sea's school of sardines, a fish murmuration (Ramon, 9 Oct: "create schools of fish like
## the pen's starling murmuration"). The pen's flock itself, carried (carried/flock/school_flock_4d.gd).
##
## ROUND 5, EVERY SARDINE LOFTED IN 4D (life/school_loft_4d.gd, two rigid pieces each). Until 9 Oct the
## school was 3,000 sardine shapes a shader shrank off the slice; Ramon chose fewer, all true 4D: 150
## (the HARBOUR slider, up to 300). The flock steps on the CPU and draws nothing itself. A 20 cm
## sardine is under 3 cm deep through W, so the school's spread through W is squashed in the flock's
## basis (W_SCALE) to keep the fish within their half width of the slice; turn the slice and you
## leave the school behind.
##
## WHY SARDINES (the research in follow_up/water_lab.md): the classic bait-ball fish, 15 to 20 cm, a
## clear look from a pier (blue-green back, silver flanks, a row of spots), schooling a body length
## apart; driven up toward the surface by predators, the school balls up, splits round an attacker
## (the fountain effect) and flashes as the fish roll.
##
## THE FLOCK AT A FIFTH OF ITS SIZE. The flock's rules are tuned in starling metres (seven neighbours,
## a couple of metres apart, ten metres a second). This node scales the flock node by 0.2, so the same
## rules move a school at two metres a second in a ball a few metres across. Its roost is under the
## water off the pier; its height band 1 to 4 m down (deeper, the water swallowed them: 9 Oct).
##
## THE SCALE DOES NOT REACH THE FISH THEMSELVES (round 2, Ramon: "the sardines do look huge ... I would
## imagine this to be way smaller fish and more scattered"). The node's 0.2 shrinks the spacing, not
## the bodies: the lofted fish are drawn 20 cm long, and the spacing rules are three times the pen's,
## which at a fifth of the size leaves them about two body lengths apart, as the pen's starlings are
## (follow_up/flocking.md: 2 to 2.5 lengths).
##
## THE PLESIOSAUR IS ITS HAWK: the flock's piloted hawk (pilot_hawk, fly_hawk), undrawn, flown each
## frame at the plesiosaur's head. Fish near it flee and roll, the roll runs through the school as a
## wave, the silver flanks flash.
##
## NO class_name (engine_gotchas.md).

const Flock := preload("res://ramon/WaterLab/carried/flock/school_flock_4d.gd")
const SchoolLoft := preload("res://ramon/WaterLab/life/school_loft_4d.gd")
const SCALE := 0.2
## The flock's W band (1.2 units) to under a centimetre either side of the slice.
const W_SCALE := 0.006

## Setting it respawns the school at that size (the HUD's HARBOUR section).
@export var count: int = 150:
	set(v):
		count = clampi(v, 0, 300)
		if flock != null:
			flock.set("count", count)
			flock.call("respawn")
## The school's middle in the world (the gulls gather over it when it is near the surface).
func middle() -> Vector4:
	if flock == null:
		return global_position
	return flock.global_position + flock.global_basis * (flock.get("_middle") as Vector4)


## The plesiosaur (its body node), whose head is the school's hunter.
var hunter: Node4D = null
var flock: Node4D
## The lofted fish (life/school_loft_4d.gd), posed at the flock's rows.
var school: Node4D


func _ready() -> void:
	flock = Node4D.new()
	flock.name = "Flock"
	flock.set_script(Flock)
	flock.set("drawn", false)
	flock.set("backend", 1)
	flock.set("hawk_drawn", false)
	flock.set("hawk_enabled", false)
	flock.set("count", count)
	# In the flock's own (starling) units: a fifth of each in the world (W squashed, W_SCALE).
	flock.set("bird_scale", 0.17)
	# Looser than the pen's flock (1.1 and 2.2): the school spreads out.
	flock.set("separation_radius", 3.3)
	flock.set("radius_max", 6.0)
	flock.set("cruise_speed", 8.0)
	flock.set("min_speed", 5.0)
	flock.set("max_speed", 16.0)
	flock.set("roost", Vector4(0.0, 0.0, 0.0, 0.0))
	flock.set("roost_radius", 22.0)
	flock.set("height_low", -20.0)
	flock.set("height_high", -5.0)
	flock.set("altitude_pull", 0.12)
	flock.set("w_half_depth", 1.2)
	flock.set("scare_radius", 30.0)
	flock.basis = Projection(Vector4(SCALE, 0, 0, 0), Vector4(0, SCALE, 0, 0), Vector4(0, 0, SCALE, 0), Vector4(0, 0, 0, W_SCALE))
	add_child(flock)
	flock.call("pilot_hawk", true)
	school = Node4D.new()
	school.name = "Fish"
	school.set_script(SchoolLoft)
	school.set("flock", flock)
	school.set("fish_length", 0.2)
	add_child(school)


func _process(_delta: float) -> void:
	if hunter == null or not is_instance_valid(hunter) or flock == null:
		return
	var ahead: Vector4 = (hunter.global_basis * Vector4(0, 0, 1, 0)).normalized()
	var head: Vector4 = hunter.global_position + ahead * 6.0
	flock.call("fly_hawk", head, ahead, 1.5, 0.0, 0.0)
