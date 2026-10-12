extends SceneTree

## Bakes the Watchstone's generated stones into its scene as nodes, one a stone (watchstone_4d.gd
## bake_into; Ramon, 6 Oct: "i want to be able to move all the stones, not just the huge ones"), and
## saves the scene. The same as the "Bake every stone into the scene" button, without the editor.
##
##   lab_run.sh headless bake_ws_stones res://ramon/PenLayout/RefLock/_bake_watchstone_stones_runner.gd

const SCENE := "res://ramon/chickenpen/units/watchstone/watchstone.tscn"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	# scene=<res path> bakes another copy (a check against what was baked: PenLayout/RefLock).
	var scene: String = SCENE
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("scene="):
			scene = arg.substr(6)
	var inst: Node = (load(scene) as PackedScene).instantiate()
	root.add_child(inst)
	await process_frame
	if bool(inst.get("stones_baked")):
		print("BAKE: already baked, nothing done")
		quit(1)
		return
	var made: int = int(inst.call("bake_into", inst))
	var packed := PackedScene.new()
	var err: int = packed.pack(inst)
	if err != OK:
		print("BAKE: pack failed ", error_string(err))
		quit(1)
		return
	err = ResourceSaver.save(packed, scene)
	var stones: int = inst.get_node("Stones").find_children("Stone*", "Node4D", true, false).size()
	print("BAKE: %d stones made, %d in the scene, saved %s (%s)" % [made, stones, scene, error_string(err)])
	quit(0 if err == OK else 1)
