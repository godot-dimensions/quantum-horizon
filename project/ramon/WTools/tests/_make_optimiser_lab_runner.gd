extends SceneTree

## Makes WTools/tests/optimiser_lab.tscn: the test room (w_lab_4d.gd) with three of the pen's units as
## they are in their own scenes (units/...), each with a W Optimiser beside it: the Watchstone 45 m ahead
## (Skyline: wrapped round the player's start), the camp front left and the range front right (Landmark).
## Run again to remake it.
##
##   lab_run.sh headless make_optimiser_lab res://ramon/WTools/tests/_make_optimiser_lab_runner.gd

const OUT := "res://ramon/WTools/tests/optimiser_lab.tscn"
const OPT := "res://ramon/WTools/optimiser/w_optimiser_4d.gd"
const PROFILES := "res://ramon/WTools/optimiser/profiles/"
## [name, unit scene, where (x, z), turned (degrees), profile]
const UNITS := [
	["Watchstone", "res://ramon/chickenpen/units/watchstone/watchstone.tscn", Vector2(0.0, -45.0), 0.0, "skyline"],
	["Camp", "res://ramon/chickenpen/units/camp/camp.tscn", Vector2(-30.0, -18.0), 30.0, "landmark"],
	["Range", "res://ramon/chickenpen/units/rune_range/rune_range.tscn", Vector2(34.0, -22.0), -20.0, "landmark"],
]


func _initialize() -> void:
	var lab := Node4D.new()
	lab.name = "OptimiserLab"
	lab.set_script(load("res://ramon/WTools/tests/w_lab_4d.gd"))
	lab.set("player_at", Vector4(0.0, 1.0, 0.0, 0.0))
	lab.set("ground", Vector4(400.0, 1.0, 400.0, 400.0))
	for u in UNITS:
		var unit: Node4D = (load(u[1]) as PackedScene).instantiate()
		unit.name = u[0]
		unit.position = Vector4(u[2].x, 0.0, u[2].y, 0.0)
		unit.basis = Basis4D.from_zx(deg_to_rad(u[3]))
		lab.add_child(unit)
		unit.owner = lab
		var opt := Node4D.new()
		opt.name = "%sW" % u[0]
		opt.set_script(load(OPT))
		opt.set("target", NodePath("../%s" % u[0]))
		opt.set("profile", load(PROFILES + u[4] + ".tres"))
		lab.add_child(opt)
		opt.owner = lab
	var packed := PackedScene.new()
	var err: int = packed.pack(lab)
	if err == OK:
		err = ResourceSaver.save(packed, OUT)
	print("OPTIMISER LAB: %d units, saved %s (%s)" % [UNITS.size(), OUT, error_string(err)])
	quit(0)
