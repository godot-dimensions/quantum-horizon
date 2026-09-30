extends SceneTree
## Proves the menu crash's last step: a SubViewport added under a root Window that has no
## World3D. Argument `null` clears the root's world first (what the Cross-section engine's
## cleanup does); anything else leaves it.
func _initialize() -> void:
	root.unfocusable = true
	var clear: bool = OS.get_cmdline_user_args().size() > 0 and String(OS.get_cmdline_user_args()[0]) == "null"
	print("PROBE: root world before: %s" % root.world_3d)
	if clear:
		root.world_3d = null
		print("PROBE: root world cleared: %s" % root.world_3d)
	root.add_child(SubViewport.new())
	print("PROBE: SubViewport added, SURVIVED")
	quit()
