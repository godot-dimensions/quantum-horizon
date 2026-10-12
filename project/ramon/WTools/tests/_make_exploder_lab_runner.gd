extends SceneTree

## Makes WTools/tests/exploder_lab.tscn: the test room (w_lab_4d.gd) and a wood "placed by hand" (40 light
## oaks and bushes from the pen's bakes, each its own node, in three bands at 12-20, 20-30 and 30-45 m in
## front of the player's start, looking north), under a W Exploder (exploder/w_exploder_4d.gd). Run again to
## remake it; the wood is the same every time (a fixed seed stands in for a hand).
##
##   lab_run.sh headless make_exploder_lab res://ramon/WTools/tests/_make_exploder_lab_runner.gd

const OAK := preload("res://ramon/chickenpen/scripts/pen_oak_4d.gd")
const OUT := "res://ramon/WTools/tests/exploder_lab.tscn"


func _initialize() -> void:
	var lab := Node4D.new()
	lab.name = "ExploderLab"
	lab.set_script(load("res://ramon/WTools/tests/w_lab_4d.gd"))
	lab.set("player_at", Vector4(0.0, 1.0, 14.0, 0.0))
	var trees := Node4D.new()
	trees.name = "Trees"
	trees.set_script(load("res://ramon/WTools/exploder/w_exploder_4d.gd"))
	trees.set("paths_path", NodePath(""))
	trees.set("valley_centre", Vector2(0.0, -15.0))
	trees.set("valley_radius", 120.0)
	trees.set("use_hill_heights", false)
	lab.add_child(trees)
	trees.owner = lab
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261007
	var bands := [[12.0, 20.0, 10], [20.0, 30.0, 14], [30.0, 45.0, 16]]
	var n: int = 0
	for band in bands:
		var made: int = 0
		var tries: int = 0
		var spots: Array[Vector2] = []
		while made < int(band[2]) and tries < 4000:
			tries += 1
			var z: float = -rng.randf_range(float(band[0]), float(band[1])) + 14.0
			var x: float = rng.randf_range(-22.0, 22.0)
			var p := Vector2(x, z)
			var ok: bool = true
			for s in spots:
				if s.distance_to(p) < 3.2:
					ok = false
			if not ok:
				continue
			spots.append(p)
			var oak := Node4D.new()
			var kind: float = rng.randf()
			var bake: String = "oak_lite3" if kind < 0.45 else ("oak_lite4" if kind < 0.8 else "bush_%d" % rng.randi_range(1, 3))
			oak.name = ("Oak%02d" if not bake.begins_with("bush") else "Bush%02d") % n
			oak.set_script(OAK)
			oak.set("bake", bake)
			oak.set("height", rng.randf_range(5.6, 6.8) if bake == "oak_lite3" else (rng.randf_range(4.2, 5.4) if bake == "oak_lite4" else rng.randf_range(1.0, 1.6)))
			oak.set("trunk", Vector2(0.8, 2.6) if not bake.begins_with("bush") else Vector2(0.3, 0.6))
			oak.position = Vector4(p.x, 0.0, p.y, 0.0)
			oak.basis = Basis4D.from_zx(rng.randf() * TAU)
			trees.add_child(oak)
			oak.owner = lab
			made += 1
			n += 1
	var packed := PackedScene.new()
	var err: int = packed.pack(lab)
	if err == OK:
		err = ResourceSaver.save(packed, OUT)
	print("EXPLODER LAB: %d plants, saved %s (%s)" % [n, OUT, error_string(err)])
	quit(0)
