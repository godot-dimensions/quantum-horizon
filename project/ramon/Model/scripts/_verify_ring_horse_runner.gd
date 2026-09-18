extends SceneTree
## Acceptance cases 3-4: the C3/C5/D4/D5 horse rebuilt with NATIVE ring branches
## instead of the Python pipeline's hand-authored duplicate limbs, then exported so
## check_w_coverage.py can be run against it.
##
## mirror_axis stays X, so the ring sweeps (Z, W) and the reflection flips X. For a
## quadruped that is the natural reading of Dn: an n-fold limb ring, reflected
## fore/aft, giving 2n legs from one authored limb.

const RIG := "res://ramon/Model/scripts/loft_rig_4d.gd"
const BALL := "res://ramon/Model/scripts/loft_ball_4d.gd"

## Ring radius in the (Z, W) plane. Chosen, not guessed: a leg's own W half-extent
## is radius * w_scale = 0.3, and the widest W gap between adjacent legs on a ring
## this size is under that, so consecutive legs OVERLAP in W and the horse never
## loses its legs as the player travels - the exact failure the v2 models had.
const RING_RADIUS := 0.62
const LEG_RADIUS := 0.30

## W SCALE RISES DOWN THE LIMB, and that is the whole lesson of the diagnosis. A
## ring's radius GROWS along the limb while the limb NARROWS, so the hoof end is
## simultaneously the thinnest in W and the most widely spaced around the ring - it
## is always where the W gap opens first. A uniform w_scale therefore cannot work;
## the lower balls have to be deliberately fatter in W than they look in 3D.
##
## These three are not guessed: the rig's own ring check reports the gap and the ball
## it opens around, and these are the values at which it stops reporting one.
const TOP_W_SCALE := 1.1 # 4-fold is the worst case: sin(90) = 1 puts two legs at the ring's full W reach while two sit at w = 0, so the widest spacing of any plan here.
const MID_W_SCALE := 1.9
const HOOF_W_SCALE := 2.7

var _frame: int = 0
var _world: Node4D
var _plans := [
	{"name": "C3", "sym": 2, "count": 3, "fore_aft": false},
	{"name": "C5", "sym": 2, "count": 5, "fore_aft": false},
	{"name": "D4", "sym": 3, "count": 4, "fore_aft": true},
	{"name": "D5", "sym": 3, "count": 5, "fore_aft": true},
]


func _ball(parent: Node, n: String, pos: Vector4, props: Dictionary) -> MeshInstance4D:
	var b := MeshInstance4D.new()
	b.set_script(load(BALL))
	b.name = n
	parent.add_child(b)
	b.position = pos
	for k in props:
		b.set(k, props[k])
	return b


func _horse(plan: Dictionary) -> MeshInstance4D:
	var rig := MeshInstance4D.new()
	rig.set_script(load(RIG))
	rig.name = "Horse%s" % plan["name"]
	rig.live_rebuild = false
	rig.verbose = true
	rig.smoothing = 3
	rig.profile_sides = 10
	rig.profile_rings = 5
	_world.add_child(rig)

	# Spine along X - head to tail - so the ring in (Z, W) wraps the body.
	_ball(rig, "Nose", Vector4(-2.60, 2.40, 0, 0), {"radius": 0.26, "w_scale": 1.1})
	_ball(rig, "Head", Vector4(-2.05, 2.45, 0, 0), {"radius": 0.38, "w_scale": 1.2})
	_ball(rig, "Neck", Vector4(-1.35, 2.42, 0, 0), {"radius": 0.44, "w_scale": 1.3})
	var chest := _ball(rig, "Chest", Vector4(-0.60, 2.40, 0, 0), {"radius": 0.60, "w_scale": 1.4})
	_ball(rig, "Barrel", Vector4(0.30, 2.40, 0, 0), {"radius": 0.64, "w_scale": 1.45})
	var rump := _ball(rig, "Rump", Vector4(1.20, 2.40, 0, 0), {"radius": 0.58, "w_scale": 1.35})
	_ball(rig, "Tail", Vector4(1.95, 2.35, 0, 0), {"radius": 0.20, "w_scale": 1.1})

	# ONE authored limb per station; the ring makes the rest.
	#
	# For Cn the limb sits at its anchor's own X, so it stays on the mirror plane and
	# the reflection is correctly skipped. For Dn it is offset in X, which is what
	# earns the fore/aft reflection and turns n legs into 2n.
	var stations: Array = [[chest, "ForeLeg", -0.30 if plan["fore_aft"] else 0.0]]
	if not plan["fore_aft"]:
		stations.append([rump, "HindLeg", 0.0])
	for station in stations:
		var anchor: Node = station[0]
		var prefix: String = station[1]
		var dx: float = station[2]
		var top := _ball(anchor, prefix + "Top", Vector4(dx, -0.70, RING_RADIUS, 0), {
			"radius": LEG_RADIUS, "w_scale": TOP_W_SCALE, "v_scale": 0.6,
			"starts_branch": true,
		})
		top.symmetry_type = int(plan["sym"])
		top.symmetry_count = int(plan["count"])
		var mid := _ball(top, prefix + "Mid", Vector4(0, -0.80, 0.22, 0), {
			"radius": 0.22, "w_scale": MID_W_SCALE, "v_scale": 0.55, "roll": 12.0,
		})
		_ball(mid, prefix + "Hoof", Vector4(0, -0.62, 0.10, 0), {
			"radius": 0.19, "w_scale": HOOF_W_SCALE, "squareness": 0.4,
		})
	return rig


func _initialize() -> void:
	_world = Node4D.new()
	_world.name = "W"
	root.add_child(_world)


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame < 2:
		return false
	for plan in _plans:
		var rig := _horse(plan)
		print("=== %s ===" % plan["name"])
		rig.build(true)
		var m := rig.mesh as ArrayTetraMesh4D
		if m == null:
			print("  BUILD FAILED")
			continue
		print("  %d verts, %d tets, %d chains" % [
			m.get_vertex_positions().size(),
			m.get_simplex_cell_vertex_indices().size() / 4,
			rig._collect_chains().size()])
		var export_root := Node4D.new()
		export_root.name = "Horse"
		var out := MeshInstance4D.new()
		out.name = "HorseMesh"
		out.mesh = m
		export_root.add_child(out)
		root.add_child(export_root)
		var doc := G4MFDocument4D.new()
		var state := G4MFState4D.new()
		var err := doc.export_append_from_godot_scene(state, export_root)
		var path := "user://ring_horse_%s.g4tf" % plan["name"]
		var werr := doc.export_write_to_file(state, path)
		print("  export: append=%d write=%d -> %s" % [err, werr, ProjectSettings.globalize_path(path)])
	quit(0)
	return true
