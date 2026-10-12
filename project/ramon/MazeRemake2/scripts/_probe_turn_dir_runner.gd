extends SceneTree

## Which way does a drag up turn the view: ahead into ana (+W) or kata? Headless.
##   run.sh headless turndir res://ramon/MazeRemake2/scripts/_probe_turn_dir_runner.gd

const Player := preload("res://ramon/MazeRemake2/player/mr2_player_4d.gd")


func _initialize() -> void:
	var p: CharacterBody4D = Player.new()
	root.add_child(p)
	p.set("turn_enabled", true)
	p.set("_turn_held", true)
	for yaw in [0.0, PI * 0.5, PI]:
		p.call("place", Vector4(0, 0, 0, 0), yaw)
		for i in 40:
			p.call("look", Vector2(0.0, -6.0))
		var f: Vector4 = p.call("forward")
		print("TURNDIR yaw %.2f: after a drag up, forward = %s  (tilt %.2f)" % [yaw, f, float(p.call("tilt"))])
	quit(0)
