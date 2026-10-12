extends "res://ramon/QuantumRange/scripts/range_target_4d.gd"

## CAPSULE: a red core inside a closed bud of six grey petals that open on their own, briefly, through W.
## Each petal swings on its hinge in a plane that runs into W, so in your slice the petals do not fan out:
## they thin away to their hinges and the core stands in the open for a moment, then they come back. The
## petals are deep through W, so stepping does not help here (unlike a shell): only the timing does. While
## closed the core is locked and a shot pings.
##
## The cycle: closed CLOSED s, opening, open OPEN s, closing. `phase` offsets one capsule from another.

const Shapes := preload("res://ramon/QuantumRange/scripts/range_shapes.gd")

const CLOSED := 2.4
const OPEN := 1.1
const MOVE := 0.35
const PETALS := 6

var core_r: float = 0.34
var bud_r: float = 0.55
var bud_h: float = 1.25
var phase: float = 0.0
## 0 closed .. 1 open, now.
var openness: float = 0.0

var _hinges: Array = []


func build() -> void:
	family = "capsule"
	add_part("Core", "core", Shapes.ball(), Vector4(core_r * 1.8, core_r * 1.8, core_r * 1.8, core_r * 2.0),
		{"basis": Basis4D.from_scale_uniform(core_r), "locked": true})
	for i in PETALS:
		var a: float = TAU * float(i) / float(PETALS)
		var hinge := Node4D.new()
		hinge.name = "Hinge%d" % i
		hinge.position = Vector4(cos(a) * bud_r * 0.55, -bud_h * 0.5, sin(a) * bud_r * 0.55, 0.0)
		add_child(hinge)
		_hinges.append([hinge, a])
		add_part("Petal%d" % i, "shell", Shapes.petal(), Vector4(0.36, bud_h * 0.8, 0.36, 1.2),
			{"parent": hinge, "at": Vector4(0, bud_h * 0.45, 0, 0), "basis": Basis4D.from_scale(Vector4(0.62, bud_h, 0.62, 1.5)) * Basis4D.from_xy(0.0), "radar": false})
		# The petal's mesh hangs from the hinge, not round the area's middle.
		var p: Dictionary = parts[parts.size() - 1]
		(p["mesh"] as MeshInstance4D).position = Vector4(0, -bud_h * 0.45, 0, 0)
	_pose(0.0)


## Where the cycle is: 0 closed .. 1 open.
func _cycle(t: float) -> float:
	var period: float = CLOSED + OPEN + MOVE * 2.0
	var c: float = fposmod(t + phase, period)
	if c < CLOSED:
		return 0.0
	c -= CLOSED
	if c < MOVE:
		return c / MOVE
	c -= MOVE
	if c < OPEN:
		return 1.0
	c -= OPEN
	return 1.0 - c / MOVE


func _pose(k: float) -> void:
	openness = k
	var e: float = k * k * (3.0 - 2.0 * k)
	for h in _hinges:
		var hinge: Node4D = h[0]
		var a: float = h[1]
		# Facing out from the axis, leaning in over the core when closed; opening swings it into W.
		var lean: float = 0.42
		hinge.basis = Basis4D.from_zx(PI * 0.5 - a) * Basis4D.from_yz(-lean) * Basis4D.from_wy(e * PI * 0.5)


func animate(t: float, _dt: float) -> void:
	_pose(_cycle(t))
	var core: Dictionary = parts[0]
	var open_now: bool = openness > 0.85
	if open_now != not bool(core["locked"]):
		core["locked"] = not open_now
		_paint(core)
	# The petals stand in the way only while they are mostly closed.
	for p in parts:
		if String(p["role"]) == "shell":
			var area: Node = p["node"]
			for c in area.get_children():
				if c is CollisionShape4D:
					(c as CollisionShape4D).position = Vector4(0, 0, 0, 0) if openness < 0.5 else Vector4(0, 0, 0, 1000.0)
