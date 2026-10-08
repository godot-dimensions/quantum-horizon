extends SceneTree
## What source does the ENGINE have for the water shader?
## Three shader edits in a row failed to change the rendered picture while grep showed them
## present on disk. Guessing at caches got nowhere, so ask the loaded resource itself.
func _initialize() -> void:
	var shader: Shader = load("res://sandbox/water4d/water4d.gdshader") as Shader
	if shader == null:
		print("  FAIL - could not load the shader at all")
		quit(1)
		return
	var code: String = shader.code
	print("  loaded shader: %d characters" % code.length())
	for marker in ["STALENESS CANARY", "found_bottom", "debug_path", "intersection_foam_depth"]:
		print("    %-26s %s" % [marker, "present" if code.contains(marker) else "ABSENT"])
	quit(0)
