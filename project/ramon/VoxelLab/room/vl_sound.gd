extends RefCounted

## The Voxel Lab's sounds, made in code (no files): a cut's crunch (filtered noise with a fast attack
## and a short tail, over a low thump) and a soft click for switching tools. Varied a little each time
## so a run of cuts does not sound like one sample.
##
## NO class_name (engine_gotchas.md).

const RATE := 22050


## A crunch about `length` seconds long; `weight` 0 to 1 lowers it and lengthens the thump.
static func crunch(weight: float = 0.5, length: float = 0.22) -> AudioStreamWAV:
	var n: int = int(RATE * length)
	var data := PackedByteArray()
	data.resize(n * 2)
	var lp: float = 0.0
	var phase: float = 0.0
	var thump_hz: float = lerpf(130.0, 70.0, weight)
	var grit: float = lerpf(0.55, 0.3, weight)
	for i in n:
		var t: float = float(i) / RATE
		var env: float = (1.0 - exp(-t * 900.0)) * exp(-t * lerpf(26.0, 15.0, weight))
		var noise: float = randf_range(-1.0, 1.0)
		# Rocky: noise through a one-pole low pass whose cutoff falls as it decays, broken up by grains.
		lp += (noise - lp) * lerpf(0.65, 0.12, clampf(t / length, 0.0, 1.0)) * grit * 2.0
		var grain: float = 1.0 if randf() > 0.08 else 2.2
		phase += TAU * thump_hz * (1.0 - t * 1.5) / RATE
		var thump: float = sin(phase) * exp(-t * 34.0) * 0.7
		var s: float = clampf((lp * grain * 0.8 + thump) * env, -1.0, 1.0)
		data.encode_s16(i * 2, int(s * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w


## A short soft click.
static func click() -> AudioStreamWAV:
	var n: int = int(RATE * 0.04)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t: float = float(i) / RATE
		var s: float = sin(TAU * 1800.0 * t) * exp(-t * 160.0) * 0.4
		data.encode_s16(i * 2, int(s * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = data
	return w
