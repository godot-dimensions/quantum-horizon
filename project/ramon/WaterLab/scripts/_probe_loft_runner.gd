extends SceneTree

## WATER LAB, round 5: where each lofted animal's meshes actually are (their vertices' extents in the
## animal's body frame, posed straight at one unit), to catch a piece built or placed wrong. Headless.

const EelLoft := preload("res://ramon/WaterLab/life/eel_loft_4d.gd")
const CrabLoft := preload("res://ramon/WaterLab/life/crab_loft_4d.gd")
const KoiLoft := preload("res://ramon/WaterLab/life/koi_loft_4d.gd")


func _initialize() -> void:
	for pair in [["eel", EelLoft], ["crab", CrabLoft], ["koi", KoiLoft]]:
		var k := Node4D.new()
		k.set_script(pair[1])
		k.call("build")
		var body: Node4D = k.get("body")
		var lo := Vector4.ONE * 1e9
		var hi := -Vector4.ONE * 1e9
		for mi in k.find_children("*", "MeshInstance4D", true, false):
			var b := Projection.IDENTITY
			var o := Vector4.ZERO
			var up: Node = mi
			while up != null and up != body:
				var h := up as Node4D
				o = h.basis * o + h.position
				b = h.basis * b
				up = up.get_parent()
			var mlo := Vector4.ONE * 1e9
			var mhi := -Vector4.ONE * 1e9
			for p in ((mi as MeshInstance4D).mesh as ArrayTetraMesh4D).get_vertex_positions():
				var q: Vector4 = b * p + o
				for c in 4:
					mlo[c] = minf(mlo[c], q[c])
					mhi[c] = maxf(mhi[c], q[c])
			lo = Vector4(minf(lo.x, mlo.x), minf(lo.y, mlo.y), minf(lo.z, mlo.z), minf(lo.w, mlo.w))
			hi = Vector4(maxf(hi.x, mhi.x), maxf(hi.y, mhi.y), maxf(hi.z, mhi.z), maxf(hi.w, mhi.w))
			print("PROBE %s %s/%s: z %.3f..%.3f  x %.3f..%.3f  y %.3f..%.3f  w %.3f..%.3f" % [pair[0], mi.get_parent().name, mi.name, mlo.z, mhi.z, mlo.x, mhi.x, mlo.y, mhi.y, mlo.w, mhi.w])
		print("PROBE %s ALL: from %s to %s" % [pair[0], str(lo), str(hi)])
		k.free()
	quit()
