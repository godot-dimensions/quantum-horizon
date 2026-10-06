extends SceneTree

## Which axis is which in the torus-like primitives (follow_up: the gallery showed the torisphere as a
## flat donut and the spheritorus as a flat disc). For every axis assignment, how well do the vertices fit
## the shape's equation? The best fit names the axes.
##
##   torisphere   (|three axes| - R)^2 + (fourth)^2 = r^2         R 2, r 0.5
##   spheritorus  (|two axes| - R)^2 + (other two)^2 = r^2         R 2, r 0.25

const TORI := "res://models/primitives/torisphere/mesh/torisphere1_smooth_ma2_mi0pt5_step10.g4b"
const SPHERI := "res://models/primitives/spheritorus/mesh/spheritorus_smooth_ma2_mi0pt25_step32.g4b"
const AX := ["x", "y", "z", "w"]


func _initialize() -> void:
	var t: Mesh4D = load(TORI)
	var tv: PackedVector4Array = t.get("vertices")
	print("PROBE: torisphere %d vertices, bounds %s" % [tv.size(), t.call("get_rect_bounds") if t.has_method("get_rect_bounds") else "?"])
	for minor in 4:
		var err: float = 0.0
		for v in tv:
			var s: float = 0.0
			for i in 4:
				if i != minor:
					s += v[i] * v[i]
			err += absf(pow(sqrt(s) - 2.0, 2.0) + v[minor] * v[minor] - 0.25)
		print("PROBE: torisphere minor axis %s: mean error %.4f" % [AX[minor], err / maxf(1.0, tv.size())])
	var sp: Mesh4D = load(SPHERI)
	var sv: PackedVector4Array = sp.get("vertices")
	print("PROBE: spheritorus %d vertices, bounds %s" % [sv.size(), sp.call("get_rect_bounds") if sp.has_method("get_rect_bounds") else "?"])
	for a in 4:
		for b in range(a + 1, 4):
			var err2: float = 0.0
			for v in sv:
				var c: float = sqrt(v[a] * v[a] + v[b] * v[b])
				var rest: float = 0.0
				for i in 4:
					if i != a and i != b:
						rest += v[i] * v[i]
				err2 += absf(pow(c - 2.0, 2.0) + rest - 0.0625)
			print("PROBE: spheritorus circle in %s%s: mean error %.4f" % [AX[a], AX[b], err2 / maxf(1.0, sv.size())])
	quit()
