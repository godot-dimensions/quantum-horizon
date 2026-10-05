extends SceneTree

## Pen layout, Phase C0 (6 Oct 2026): a scratch copy of the pen with every unit moved, most turned
## 90 degrees and one moved through W, to prove the units can be laid out freely. The pen is loaded
## but not run (nothing has done its _ready), the units' roots are moved, and the copy is saved to
## res://ramon/PenLayout/scratch/moved_pen.tscn. The real pen is not touched.
##
##   CreationLab/scripts/lab_run.sh headless pl_moved res://ramon/PenLayout/scripts/_make_moved_pen_runner.gd

const SCENE := "res://ramon/chickenpen/playable_world.tscn"
const OUT := "res://ramon/PenLayout/scratch/moved_pen.tscn"
## Unit: [new place (x, y, z, W), turn in degrees about the vertical]. Spread round the pen at
## (0, -11), inside the walkable circle (46 m), clear of each other. The professor is not in the
## list: he stands at the cave mouth in the story, so he goes with the cave (see FOLLOWS).
const MOVES := {
	"TrymCabin": [Vector4(-15.0, 0.0, -4.0, 0.0), 90.0],
	"KeeperPost": [Vector4(6.0, 0.0, -3.5, 0.0), 90.0],
	"Range": [Vector4(-24.0, 0.0, 8.0, 0.0), 90.0],
	"LookoutSite": [Vector4(-30.0, 0.0, -24.0, 0.0), 90.0],
	"RockPileSpot": [Vector4(-4.0, 0.0, 8.0, 1.5), 180.0],
	# East of the pen, its mouth turned to face it (the professor, who follows it, stays in the field).
	"Cave": [Vector4(30.0, 0.0, -14.0, 0.0), -90.0],
}
## Units that keep their place relative to another unit: they are moved and turned with it.
const FOLLOWS := {"ProfessorPost": "Cave"}


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://ramon/PenLayout/scratch/"))
	var root: Node = (load(SCENE) as PackedScene).instantiate()
	var world: Node = root.get_node("World")
	var was := {}
	for unit in MOVES:
		var n := world.get_node(unit) as Node4D
		was[unit] = [n.position, n.basis]
		var mv: Array = MOVES[unit]
		n.position = mv[0]
		n.basis = Basis4D.from_zx(deg_to_rad(float(mv[1]))) * n.basis
		print("MOVED %s to %s, turned %.0f" % [unit, str(mv[0]), float(mv[1])])
	for unit in FOLLOWS:
		var n := world.get_node(unit) as Node4D
		var lead := world.get_node(FOLLOWS[unit]) as Node4D
		var lead_was: Array = was[FOLLOWS[unit]]
		var turn: Projection = lead.basis * (lead_was[1] as Projection).inverse()
		n.position = lead.position + turn * (n.position - (lead_was[0] as Vector4))
		n.basis = turn * n.basis
		print("MOVED %s with %s to %s" % [unit, FOLLOWS[unit], str(n.position)])
	var packed := PackedScene.new()
	var err: int = packed.pack(root)
	if err == OK:
		err = ResourceSaver.save(packed, OUT)
	print("MOVED PEN saved: %s (%d)" % [OUT, err])
	root.free()
	quit(0 if err == OK else 1)
