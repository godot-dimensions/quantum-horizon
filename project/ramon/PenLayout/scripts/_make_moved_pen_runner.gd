extends SceneTree

## Pen layout (6 Oct 2026): scratch copies of the pen with the units moved, turned and moved through
## W. The pen is loaded but not run (nothing has done its _ready), the units' roots and any other
## nodes the layout names are moved, and the copy is saved under res://ramon/PenLayout/scratch/.
## The real pen is not touched.
##   proof  every unit moved, most turned, one in W: Phase C0's proof that units can go anywhere
##   a      "Over the hill": you start at Trym's shed on the south edge, the cave hill hides the
##          pen, and coming round it the pen and the tower open up
##   b      "Compass": the start stays; one landmark per direction, the east left open for the sun
##   c      "Through W": the start and the ground plan stay; the places are spread through W instead
##
##   CreationLab/scripts/lab_run.sh headless pl_moved res://ramon/PenLayout/scripts/_make_moved_pen_runner.gd [layout]

const SCENE := "res://ramon/chickenpen/playable_world.tscn"
## Unit: [new place (x, y, z, W), turn in degrees about the vertical]. Spread round the pen at
## (0, -11), inside the walkable circle (46 m), clear of each other. The professor is not in the
## list: he stands at the cave mouth in the story, so he goes with the cave (see follows).
const MOVES := {
	"TrymCabin": [Vector4(-15.0, 0.0, -4.0, 0.0), 90.0],
	"KeeperPost": [Vector4(6.0, 0.0, -3.5, 0.0), 90.0],
	"Range": [Vector4(-24.0, 0.0, 8.0, 0.0), 90.0],
	"LookoutSite": [Vector4(-30.0, 0.0, -24.0, 0.0), 90.0],
	"RockPileSpot": [Vector4(-4.0, 0.0, 8.0, 1.5), 180.0],
	# East of the pen, its mouth turned to face it (the professor, who follows it, stays in the field).
	"Cave": [Vector4(30.0, 0.0, -14.0, 0.0), -90.0],
}
## By name: "units" as MOVES; "follows", units that keep their place relative to another unit
## (moved and turned with it; "keep_w" ones keep their own W); "nodes", other nodes put at a
## place (their parents stand at the origin, unturned); "props", properties set on nodes.
const LAYOUTS := {
	"proof": {"units": MOVES, "follows": {"ProfessorPost": "Cave"}},
	"a": {
		"units": {
			# Between the start and the pen, its mouth facing the start.
			"Cave": [Vector4(8.0, 0.0, 15.0, 0.0), 0.0],
			# On the south edge beside the start; turned so Trym's walk and door come toward it.
			"TrymCabin": [Vector4(-9.0, 0.0, 37.0, 0.0), 90.0],
		},
		"follows": {"ProfessorPost": "Cave"},
		"nodes": {
			"Player": Vector4(4.0, 1.2, 38.0, 0.0),
			# Out of the hill's way: Nike's run and two of the W posts.
			"World/Nike": Vector4(13.0, 0.0, -5.0, 0.0),
			"World/Scenery/Post6": Vector4(14.0, 1.1, -1.0, -1.6),
			"World/Scenery/Post7": Vector4(-15.0, 1.1, 12.0, 2.4),
		},
		# Waking facing north, at the hill and its arch.
		"props": {"Player/CameraRig": {"start_yaw_degrees": 0.0}},
	},
	"b": {
		"units": {
			# South, behind the start: the theatre's door opens toward the pen.
			"TrymCabin": [Vector4(-4.0, 0.0, 16.0, 0.0), 180.0],
			# South-west, firing south into the empty edge.
			"Range": [Vector4(-17.0, 0.0, 14.0, 0.0), 90.0],
			# North-east, its mouth facing west across to the tower.
			"Cave": [Vector4(29.0, 0.0, -34.0, 0.0), -90.0],
		},
		"follows": {"ProfessorPost": "Cave"},
	},
	"c": {
		"units": {
			# Kata: Trym's shed (and his door) two and a half metres off the farm's slice.
			"TrymCabin": [Vector4(-10.0, 0.0, -14.0, -2.5), 0.0],
			# Ana: the rock pile, a step and a half.
			"RockPileSpot": [Vector4(-7.4, 0.0, 1.8, 1.5), 0.0],
			# Ana: the hill stands in the field, but its door is four metres off the slice.
			"Cave": [Vector4(17.0, 0.0, -40.0, 4.0), 0.0],
		},
		# The professor stays on the farm's slice, in front of a hill with no door in it.
		"follows": {"ProfessorPost": "Cave"},
		"keep_w": ["ProfessorPost"],
	},
}


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var name: String = args[0] if args.size() > 0 else "proof"
	var layout: Dictionary = LAYOUTS[name]
	var out: String = "res://ramon/PenLayout/scratch/%s.tscn" % ("moved_pen" if name == "proof" else "layout_" + name)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://ramon/PenLayout/scratch/"))
	var root: Node = (load(SCENE) as PackedScene).instantiate()
	var world: Node = root.get_node("World")
	var was := {}
	var units: Dictionary = layout.get("units", {})
	for unit in units:
		var n := world.get_node(unit) as Node4D
		was[unit] = [n.position, n.basis]
		var mv: Array = units[unit]
		n.position = mv[0]
		n.basis = Basis4D.from_zx(deg_to_rad(float(mv[1]))) * n.basis
		print("MOVED %s to %s, turned %.0f" % [unit, str(mv[0]), float(mv[1])])
	var follows: Dictionary = layout.get("follows", {})
	for unit in follows:
		if not was.has(follows[unit]):
			continue
		var n := world.get_node(unit) as Node4D
		var lead := world.get_node(follows[unit]) as Node4D
		var lead_was: Array = was[follows[unit]]
		var turn: Projection = lead.basis * (lead_was[1] as Projection).inverse()
		var w: float = n.position.w
		n.position = lead.position + turn * (n.position - (lead_was[0] as Vector4))
		if unit in layout.get("keep_w", []):
			n.position.w = w
		n.basis = turn * n.basis
		print("MOVED %s with %s to %s" % [unit, follows[unit], str(n.position)])
	var nodes: Dictionary = layout.get("nodes", {})
	for path in nodes:
		(root.get_node(path) as Node4D).position = nodes[path]
		print("MOVED %s to %s" % [path, str(nodes[path])])
	var props: Dictionary = layout.get("props", {})
	for path in props:
		for key in props[path]:
			root.get_node(path).set(key, props[path][key])
	var packed := PackedScene.new()
	var err: int = packed.pack(root)
	if err == OK:
		err = ResourceSaver.save(packed, out)
	print("MOVED PEN saved: %s (%d)" % [out, err])
	root.free()
	quit(0 if err == OK else 1)
