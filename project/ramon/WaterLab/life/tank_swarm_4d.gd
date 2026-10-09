extends Node4D

## WATER LAB, THE TANK: a swarm of very small fish (Ramon, 9 Oct, round 3: "in this fish tank you can
## create a swarm of very small fishes using the murmuration technique ... and make it move slow, and
## maybe if a shark comes, it can dissipate this cloud").
##
## THE PEN'S MURMURATION, IN THE TANK: the carried flock (carried/flock/school_flock_4d.gd, the sea's
## sardines' flock) with a tiny fish for its body (the sea's sardine mesh and shader, drawn 4.5 cm
## long), scaled down to the tank: this node scales the flock's own starling metres by 0.08 (a cloud
## a metre or two across, swimming at about 0.3 m/s), and a little more again front to back, the
## tank being only 3.2 m deep. Its roost is in the tank's lower water, where the room looks.
##
## THE HAMMERHEAD IS ITS HAWK: the flock's piloted hawk (undrawn), flown each frame at the shark's head,
## so the cloud parts round it and closes again behind (the fountain effect), the fish rolling.
##
## In the tank's Life node, so it turns through W with the rest of the contents. NO class_name.

const Flock := preload("res://ramon/WaterLab/carried/flock/school_flock_4d.gd")
const SHADER := preload("res://ramon/WaterLab/seascape/school_fish.gdshader")
const School := preload("res://ramon/WaterLab/seascape/fish_school_4d.gd")

@export var count: int = 1600
## The flock's units to the tank's metres (x, y, W), and front to back (z).
@export var scale_xyw: float = 0.08
@export var scale_z: float = 0.05
## Where it gathers (the Life node's frame, metres).
@export var home := Vector4(2.0, -1.6, 0.0, 0.0)
## The shark (life/shark_4d.gd), its hawk.
var hunter: Node4D = null
var flock: Node4D


func _ready() -> void:
	flock = Node4D.new()
	flock.name = "Flock"
	flock.set_script(Flock)
	flock.set("body_mesh", School._fish_mesh())
	flock.set("body_shader", SHADER)
	flock.set("hawk_drawn", false)
	flock.set("hawk_enabled", false)
	flock.set("count", count)
	# Drawn sizes are metres (the flock's scale moves the fish, not their bodies: fish_school_4d.gd):
	# 1.2 units of mesh x 0.06, a fish 7 cm long. Its W radius (bird_w_radius x that) 0.36 m, past the
	# school's +-0.24 m in W, so the whole cloud is in your slice (at 0.06 m most of it was not).
	# Round 4 (Ramon: "slightly larger ... swimming speed slightly" up): 0.075, 9 cm.
	flock.set("bird_scale", 0.075)
	flock.set("bird_w_radius", 6.0)
	# Slow (Ramon: "make it move slow"): a third of the pen's speeds, which at 0.08 is about 0.3 m/s.
	flock.set("cruise_speed", 5.0)
	flock.set("min_speed", 2.8)
	flock.set("max_speed", 11.0)
	flock.set("roost", Vector4(0.0, 0.0, 0.0, 0.0))
	flock.set("roost_radius", 14.0)
	flock.set("height_low", -9.0)
	flock.set("height_high", 9.0)
	flock.set("altitude_pull", 0.2)
	flock.set("w_half_depth", 3.0)
	flock.set("scare_radius", 14.0)
	flock.position = home
	flock.basis = Projection(Vector4(scale_xyw, 0, 0, 0), Vector4(0, scale_xyw, 0, 0), Vector4(0, 0, scale_z, 0), Vector4(0, 0, 0, scale_xyw))
	add_child(flock)
	flock.call("pilot_hawk", true)


func _process(_delta: float) -> void:
	if hunter == null or not is_instance_valid(hunter) or flock == null:
		return
	var body: Node4D = hunter.get_node_or_null("Body") as Node4D
	if body == null:
		return
	var ahead: Vector4 = (body.global_basis * Vector4(0, 0, 1, 0)).normalized()
	var length: float = float(hunter.get("length"))
	flock.call("fly_hawk", body.global_position + ahead * length * 0.5, ahead, 1.0, 0.0, 0.0)
