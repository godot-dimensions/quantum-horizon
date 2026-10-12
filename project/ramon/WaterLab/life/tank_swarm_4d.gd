extends Node4D

## WATER LAB, THE TANK: a swarm of very small fish (Ramon, 9 Oct, round 3: "in this fish tank you can
## create a swarm of very small fishes using the murmuration technique ... and make it move slow, and
## maybe if a shark comes, it can dissipate this cloud").
##
## THE PEN'S MURMURATION, IN THE TANK: the carried flock (carried/flock/school_flock_4d.gd, the sea's
## sardines' flock), scaled down to the tank: this node scales the flock's own starling metres by
## 0.08 (a cloud a metre or two across, swimming at about 0.3 m/s), and a little more again front to
## back, the tank being only 3.2 m deep. Its roost is in the tank's lower water, where the room looks.
##
## ROUND 5, EVERY FISH LOFTED IN 4D (life/school_loft_4d.gd: a slim fish of two rigid pieces, 9 cm).
## Until 9 Oct it was 1,600 sardine shapes a shader shrank off the slice; Ramon chose fewer, all true
## 4D. The flock steps on the CPU (a few microseconds a fish) and draws nothing itself. A lofted fish
## 9 cm long is only about a centimetre deep through W, so the school's spread through W is squashed
## in the flock's basis (`scale_w`) to keep the fish within their own half width of the slice; turn
## the tank through W and your slice leaves the school.
##
## THE HAMMERHEAD IS ITS HAWK: the flock's piloted hawk (undrawn), flown each frame at the shark's head,
## so the cloud parts round it and closes again behind (the fountain effect), the fish rolling.
##
## In the tank's Life node, so it turns through W with the rest of the contents. NO class_name.

const Flock := preload("res://ramon/WaterLab/carried/flock/school_flock_4d.gd")
const SchoolLoft := preload("res://ramon/WaterLab/life/school_loft_4d.gd")

@export var count: int = 120
## The flock's units to the tank's metres (x, y), front to back (z), and through W.
@export var scale_xyw: float = 0.08
@export var scale_z: float = 0.05
@export var scale_w: float = 0.001
## Where it gathers (the Life node's frame, metres).
@export var home := Vector4(2.0, -1.6, 0.0, 0.0)
## The shark (life/shark_4d.gd), its hawk.
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
	# Round 4 (Ramon: "slightly larger ... swimming speed slightly" up): 9 cm fish (the lofted fish's
	# length below; the flock's own bird_scale only matters to what it would draw).
	flock.set("bird_scale", 0.075)
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
	flock.basis = Projection(Vector4(scale_xyw, 0, 0, 0), Vector4(0, scale_xyw, 0, 0), Vector4(0, 0, scale_z, 0), Vector4(0, 0, 0, scale_w))
	add_child(flock)
	flock.call("pilot_hawk", true)
	school = Node4D.new()
	school.name = "Fish"
	school.set_script(SchoolLoft)
	school.set("flock", flock)
	school.set("fish_length", 0.09)
	school.set("beat_rate", 5.5)
	add_child(school)


func _process(_delta: float) -> void:
	if hunter == null or not is_instance_valid(hunter) or flock == null:
		return
	var body: Node4D = hunter.get_node_or_null("Body") as Node4D
	if body == null:
		return
	var ahead: Vector4 = (body.global_basis * Vector4(0, 0, 1, 0)).normalized()
	var length: float = float(hunter.get("length"))
	flock.call("fly_hawk", body.global_position + ahead * length * 0.5, ahead, 1.0, 0.0, 0.0)


func bench_row() -> Array:
	var row: Array = school.call("bench_row", "Swarm") if school != null else ["Swarm", "0", "-", "0", ""]
	if flock != null:
		row[2] = "%.3f ms" % ((float(flock.get("mean_step_usec")) + float(school.get("cpu_us"))) / 1000.0)
	return row
