extends SceneTree

## Lists the editable properties of the light and environment classes the water scene uses, so the
## HUD's light and environment mode can be built from what the engine really exposes.

func _initialize() -> void:
	for cls in ["DirectionalLight4D", "WorldEnvironment4D", "GradientSkyMaterial4D", "VolumetricCloudMaterial4D", "Camera4D"]:
		var o: Object = ClassDB.instantiate(cls)
		print("CLASS ", cls)
		for p in o.get_property_list():
			var usage: int = int(p["usage"])
			if (usage & PROPERTY_USAGE_EDITOR) == 0:
				continue
			print("  %s  type %d  hint %d  '%s'  = %s" % [p["name"], p["type"], p["hint"], p["hint_string"], str(o.get(p["name"]))])
		if o is Node:
			(o as Node).free()
	quit()
