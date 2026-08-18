extends Node
## TEMPORARY - sanity-checks the new prototype Math4D.noise_4d() native
## binding before trusting it in the full benchmark. Not part of the
## shipped scene.

func _ready() -> void:
	var a: float = Math4D.noise_4d(1, 1.3, -0.7, 2.1, 0.4)
	var b: float = Math4D.noise_4d(1, 1.3, -0.7, 2.1, 0.4)
	var c: float = Math4D.noise_4d(1, 1.31, -0.7, 2.1, 0.4)
	var d: float = Math4D.noise_4d(2, 1.3, -0.7, 2.1, 0.4)
	print("deterministic: a=%s b=%s (expect equal)" % [a, b])
	print("varies_by_point: a=%s c=%s (expect different)" % [a, c])
	print("varies_by_seed: a=%s d=%s (expect different)" % [a, d])
	print("in_range: a=%s (expect within roughly [-1,1])" % [a])

	# Same checks for the second prototype binding, Math4D.fastnoise2_4d()
	# (native FastNoise2 SuperSimplex, see math_4d.cpp) - not swapped into
	# production yet, this just confirms the binding itself behaves like a
	# real noise function before it goes anywhere near the benchmark.
	var fa: float = Math4D.fastnoise2_4d(1, 1.3, -0.7, 2.1, 0.4)
	var fb: float = Math4D.fastnoise2_4d(1, 1.3, -0.7, 2.1, 0.4)
	var fc: float = Math4D.fastnoise2_4d(1, 1.31, -0.7, 2.1, 0.4)
	var fd: float = Math4D.fastnoise2_4d(2, 1.3, -0.7, 2.1, 0.4)
	print("fastnoise2_deterministic: a=%s b=%s (expect equal)" % [fa, fb])
	print("fastnoise2_varies_by_point: a=%s c=%s (expect different)" % [fa, fc])
	print("fastnoise2_varies_by_seed: a=%s d=%s (expect different)" % [fa, fd])
	print("fastnoise2_in_range: a=%s (expect within roughly [-1,1])" % [fa])
	print("DONE")
	get_tree().quit()
