extends "res://ramon/QuantumRange/scripts/range_target_4d.gd"

## TENDRIL SENTINEL: a red core with four articulated white tendrils that sweep across in front of it, and
## a little through W, so in your slice they thicken and thin as well as move (each joint is three times
## as deep through W as it is wide, or a sweep through W made it vanish, gallery/sentinel, 5 Oct). Each tendril is a chain of lofted joints
## (rigid pieces on hinges, nothing re-lofted). Shoot a tendril and it recoils, curling back out of the
## way for a few seconds; shoot the core through the gap.

const Shapes := preload("res://ramon/QuantumRange/scripts/range_shapes.gd")

const JOINTS := 4
const RECOIL := 3.0

var core_r: float = 0.3
var seg_len: float = 0.34
var seg_r: float = 0.075

var _tendrils: Array = []     # [root Node4D, [joint Node4D...], base angle, recoil seconds left]


func build() -> void:
	family = "sentinel"
	add_part("Core", "core", Shapes.ball(), Vector4(core_r * 1.8, core_r * 1.8, core_r * 1.8, core_r * 2.0),
		{"basis": Basis4D.from_scale_uniform(core_r)})
	for i in 4:
		var a: float = TAU * float(i) / 4.0 + PI * 0.25
		var root := Node4D.new()
		root.name = "Tendril%d" % i
		root.position = Vector4(cos(a) * core_r * 0.8, sin(a) * core_r * 0.8, 0.0, 0.0)
		add_child(root)
		var joints: Array = []
		var parent: Node4D = root
		for j in JOINTS:
			var joint := Node4D.new()
			joint.name = "J%d" % j
			joint.position = Vector4(0, seg_len if j > 0 else 0.0, 0, 0)
			parent.add_child(joint)
			var tip: float = 1.0 - 0.18 * float(j)
			add_part("T%d_%d" % [i, j], "cover", Shapes.segment(0.8), Vector4(seg_r * 2.6, seg_len, seg_r * 2.6, seg_r * 6.0),
				{"parent": joint, "at": Vector4(0, seg_len * 0.5, 0, 0), "basis": Basis4D.from_scale(Vector4(seg_r * tip, seg_len, seg_r * tip, seg_r * tip * 3.0)), "hp": 999, "radar": false})
			var p: Dictionary = parts[parts.size() - 1]
			(p["mesh"] as MeshInstance4D).position = Vector4(0, -seg_len * 0.5, 0, 0)
			joints.append(joint)
			parent = joint
		_tendrils.append([root, joints, a, 0.0])


func on_hit(p: Dictionary, outcome: String) -> void:
	if outcome != "chip":
		return
	var nm: String = String(p["name"])
	if not nm.begins_with("T"):
		return
	var i: int = int(nm.substr(1, 1))
	_tendrils[i][3] = RECOIL


func animate(t: float, dt: float) -> void:
	for i in _tendrils.size():
		var td: Array = _tendrils[i]
		var root: Node4D = td[0]
		var a: float = td[2]
		td[3] = maxf(0.0, float(td[3]) - dt)
		var left: float = float(td[3])
		# 0 out, 1 curled away: in fast as it is hit, back out over its last half second.
		var rec: float = clampf((RECOIL - left) / 0.15, 0.0, 1.0) if left > RECOIL - 0.15 else clampf(left / 0.5, 0.0, 1.0)
		if left <= 0.0:
			rec = 0.0
		# The root points out from the core and sweeps forward across its face, and through W.
		var sweep: float = sin(t * 1.3 + float(i) * 1.7)
		var through: float = sin(t * 0.9 + float(i) * 2.3)
		root.basis = Basis4D.from_xy(a - PI * 0.5) * Basis4D.from_yz(0.9 * sweep * (1.0 - rec) - 1.3 * rec) * Basis4D.from_wy(0.28 * through * (1.0 - rec))
		var joints: Array = td[1]
		for j in range(1, joints.size()):
			var curl: float = 0.35 * sin(t * 2.1 + float(j) * 0.8 + float(i)) * (1.0 - rec) + 0.9 * rec
			(joints[j] as Node4D).basis = Basis4D.from_yz(curl)
