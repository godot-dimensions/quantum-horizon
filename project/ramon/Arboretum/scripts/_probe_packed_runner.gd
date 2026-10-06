extends SceneTree

## Does appending to a packed array held in a Dictionary or an Array stick? (GDScript 4 packed
## arrays are copy-on-write values.)

func _initialize() -> void:
	var d := {"a": PackedInt32Array()}
	(d["a"] as PackedInt32Array).append(1)
	d["a"].append(2)
	var arr: Array = [PackedInt32Array()]
	(arr[0] as PackedInt32Array).append(3)
	arr[0].append(4)
	var local: PackedInt32Array = d["a"]
	local.append(5)
	print("PROBE dict=", d["a"], " array=", arr[0], " local-copy-appended dict=", d["a"])
	quit()
