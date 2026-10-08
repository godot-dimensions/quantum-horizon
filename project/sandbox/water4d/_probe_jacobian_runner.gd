extends SceneTree

## What range does the Jacobian determinant actually take, per preset?
##
##   godot --path project --headless \
##       --script res://sandbox/water4d/_probe_jacobian_runner.gd
##
## WHY NOT MEASURE IT OFF THE SCREEN. Two attempts to read this from the debug view were
## worthless: the first painted the ramp into ALBEDO and came back a flat white sea, which
## is what a tonemapper does to any bright colour and says nothing about the determinant;
## the second made it unlit emission and the water did not draw at all, so the "0.01%"
## it reported was the orange body. The determinant is arithmetic over the wave set, so it
## can be computed here directly, with no renderer in the way and nothing to misread.
##
## This duplicates the shader's Jacobian on purpose. If the two ever disagree the shader is
## the one that matters - but a number here is a number, where a picture is an argument.

const Presets := preload("res://sandbox/water4d/water4d_presets.gd")
const SAMPLES := 40
## Must match water4d.gdshader's defaults, or the last column is measuring a shader nobody
## is running.
const FOAM_THRESHOLD := 0.62
const FOAM_SOFTNESS := 0.18
const HISTORY_SAMPLES := 4
const HISTORY_STEP := 0.28
const DECAY := 1.15
const GRAVITY := 9.81


func _initialize() -> void:
	print("\n  preset             min det   mean det   max det   below 0.88   below 0.60   foam now   + trailing")
	for index in range(Presets.count()):
		_report(index)
	print("")
	quit(0)


func _report(index: int) -> void:
	var waves: Array = Presets._preset(index)
	# The same clamp water4d_surface.gd applies before it pushes anything.
	var total: float = 0.0
	for w in waves:
		total += w.steepness * (TAU / maxf(w.wavelength, 0.1)) * w.amplitude
	var scale: float = 1.0 / total if total > 1.0 else 1.0

	var lo: float = INF
	var hi: float = -INF
	var sum: float = 0.0
	var under_88: int = 0
	var under_60: int = 0
	var count: int = 0
	var foam_now: float = 0.0
	var foam_with_history: float = 0.0
	# A patch of horizontal space a few wavelengths across, at a fixed time.
	for a in range(SAMPLES):
		for b in range(SAMPLES):
			for c in range(4):
				var h := Vector3(float(a) * 1.7, float(b) * 1.7, float(c) * 3.1)
				var det: float = _determinant(waves, scale, h)
				lo = minf(lo, det)
				hi = maxf(hi, det)
				sum += det
				count += 1
				if det < 0.88:
					under_88 += 1
				if det < 0.60:
					under_60 += 1
				var now: float = _pinch(det)
				var best: float = now
				for step in range(1, HISTORY_SAMPLES + 1):
					var back: float = float(step) * HISTORY_STEP
					var was: float = _determinant(waves, scale, h, back)
					best = maxf(best, _pinch(was) * exp(-back / DECAY))
				foam_now += now
				foam_with_history += best
	var now_pct: float = 100.0 * foam_now / float(count)
	var all_pct: float = 100.0 * foam_with_history / float(count)
	print("  %d %-16s %7.3f  %8.3f  %8.3f   %6.2f%%     %6.2f%%   %6.2f%%   %+6.2f%%"
			% [index + 1, Presets.preset_name(index), lo, sum / float(count), hi,
			100.0 * float(under_88) / float(count), 100.0 * float(under_60) / float(count),
			now_pct, all_pct - now_pct])


## How much foam a determinant is worth, matching the shader's smoothstep.
func _pinch(det: float) -> float:
	return smoothstep(FOAM_THRESHOLD + FOAM_SOFTNESS, FOAM_THRESHOLD - FOAM_SOFTNESS, det)


## J = I + sum( -Q A k sin(phase) * dir (x) dir ), the same expansion the shader builds,
## optionally wound back `seconds_ago` by each wave's own omega.
##
## WHAT THIS LAST COLUMN DOES AND DOES NOT SHOW. It is a GDScript copy of the shader's
## arithmetic, so it answers "does winding the phases back leave trailing foam, and how
## much" - a property of the method. It cannot confirm the SHADER implements it; that is a
## thing to look at. Two copies of my own maths agreeing is not evidence about either.
func _determinant(waves: Array, scale: float, h: Vector3, seconds_ago: float = 0.0) -> float:
	var m := Basis.IDENTITY
	for w in waves:
		if w.amplitude <= 0.0:
			continue
		var k: float = TAU / maxf(w.wavelength, 0.1)
		var phase: float = (w.dir * k).dot(h) + sqrt(GRAVITY * k) * seconds_ago
		var s: float = -w.steepness * scale * w.amplitude * k * sin(phase)
		var d: Vector3 = w.dir
		# Basis columns, matching the shader's jac[0..2].
		m.x += s * d * d.x
		m.y += s * d * d.y
		m.z += s * d * d.z
	return m.determinant()
