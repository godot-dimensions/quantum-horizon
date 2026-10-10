extends Node
## THE ANNEX'S SOUND, all made in code (no files, the Voxel Lab's way): quiet, and tied to what you do.
##
##   the hum      a low bed per level (a building's air handling: two detuned tones and a breath of
##                noise), different in each level, never loud
##   the W tone   a soft airy tone that rises with how fast you move through W and falls silent when
##                you stop: you hear W the way you hear footsteps
##   the slide    a hush when a door near you moves (its leaves sliding as you shift)
##   one-shots    a knock when W stops you, a chime for V, a bell for a relic, the lift's rise, a click
##                for B, a chord for the finale
##
## Loops are set in code (the import's loop setting does nothing in this build: water_lab_4d.gd).

const RATE := 22050

var _hum: AudioStreamPlayer
var _wtone: AudioStreamPlayer
var _slide: AudioStreamPlayer
var _shots: Array[AudioStreamPlayer] = []
var _streams: Dictionary = {}
var _level: int = 0
var _wt_level: float = 0.0
var _slide_level: float = 0.0
## Master trim, dB (the Tab panel tunes it).
var volume_db: float = 0.0


func _ready() -> void:
	_hum = _player(-30.0)
	_wtone = _player(-80.0)
	_slide = _player(-80.0)
	for i in 4:
		_shots.append(_player(-14.0))
	_streams["wtone"] = _loop(_make_wtone(2.0))
	_streams["slide"] = _loop(_make_noise_loop(2.0, 0.18))
	_streams["knock"] = _make_knock()
	_streams["align"] = _make_chime([660.0, 990.0], 0.7, 7.0)
	_streams["relic"] = _make_chime([880.0, 1320.0, 1760.0, 2640.0], 1.6, 3.2)
	_streams["tick"] = _make_chime([1800.0], 0.05, 120.0)
	_streams["lift"] = _make_lift()
	_streams["finale"] = _make_chime([261.6, 329.6, 392.0, 523.3, 784.0], 4.5, 0.9)
	_wtone.stream = _streams["wtone"]
	_slide.stream = _streams["slide"]
	_wtone.play()
	_slide.play()
	set_level(0)


func _player(db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.volume_db = db
	add_child(p)
	return p


func set_level(i: int) -> void:
	_level = i
	var key: String = "hum%d" % i
	if not _streams.has(key):
		var freqs: Array = [[55.0, 82.5, 110.25], [60.0, 120.0, 90.25], [41.25, 61.75, 82.5]][clampi(i, 0, 2)]
		_streams[key] = _loop(_make_hum(4.0, freqs, [0.05, 0.14, 0.08][clampi(i, 0, 2)]))
	_hum.stream = _streams[key]
	_hum.volume_db = -30.0 + volume_db
	_hum.play()


## Every frame from the game: how fast you move through W (m/s) and how fast the nearest door moves.
func feed(w_rate: float, door_rate: float, delta: float) -> void:
	var want: float = clampf(absf(w_rate) / 1.6, 0.0, 1.0)
	_wt_level = move_toward(_wt_level, want, delta * 4.0)
	_wtone.volume_db = (lerpf(-60.0, -21.0, sqrt(_wt_level)) if _wt_level > 0.01 else -80.0) + volume_db
	_wtone.pitch_scale = lerpf(0.85, 1.25, _wt_level)
	var s: float = clampf(absf(door_rate) * 1.2, 0.0, 1.0)
	_slide_level = move_toward(_slide_level, s, delta * 6.0)
	_slide.volume_db = (lerpf(-60.0, -22.0, sqrt(_slide_level)) if _slide_level > 0.01 else -80.0) + volume_db


func _shot(name: String, db: float = -14.0) -> void:
	for p in _shots:
		if not p.playing:
			p.stream = _streams[name]
			p.volume_db = db + volume_db
			p.play()
			return
	_shots[0].stream = _streams[name]
	_shots[0].volume_db = db + volume_db
	_shots[0].play()


func knock() -> void:
	_shot("knock", -12.0)


func align() -> void:
	_shot("align", -17.0)


func relic() -> void:
	_shot("relic", -14.0)


func tick() -> void:
	_shot("tick", -18.0)


func lift() -> void:
	_shot("lift", -15.0)


func finale() -> void:
	_shot("finale", -12.0)


# --- making the sounds ---

func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w


func _loop(w: AudioStreamWAV) -> AudioStreamWAV:
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = w.data.size() / 2
	return w


## A bed `seconds` long whose tones complete whole cycles in it (so the loop is seamless), with a
## breath of filtered noise crossfaded at the ends.
func _make_hum(seconds: float, freqs: Array, noise: float) -> AudioStreamWAV:
	var n: int = int(RATE * seconds)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp: float = 0.0
	var amps: Array = [0.32, 0.18, 0.07]
	for i in n:
		var t: float = float(i) / RATE
		var s: float = 0.0
		for k in freqs.size():
			s += sin(TAU * float(freqs[k]) * t) * float(amps[mini(k, 2)])
		lp += (randf_range(-1.0, 1.0) - lp) * 0.02
		var edge: float = minf(1.0, minf(t, seconds - t) / 0.25)
		out[i] = s * 0.5 + lp * noise * 3.0 * edge
	return _wav(out)


## The W tone: an airy band of noise round a soft tone.
func _make_wtone(seconds: float) -> AudioStreamWAV:
	var n: int = int(RATE * seconds)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp: float = 0.0
	var bp: float = 0.0
	for i in n:
		var t: float = float(i) / RATE
		var x: float = randf_range(-1.0, 1.0)
		lp += (x - lp) * 0.18
		bp += (lp - bp) * 0.05
		var tone: float = sin(TAU * 330.0 * t) * 0.18 + sin(TAU * 495.0 * t) * 0.08
		var edge: float = minf(1.0, minf(t, seconds - t) / 0.2)
		out[i] = ((lp - bp) * 0.9 * edge + tone) * 0.6
	return _wav(out)


func _make_noise_loop(seconds: float, smooth: float) -> AudioStreamWAV:
	var n: int = int(RATE * seconds)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp: float = 0.0
	for i in n:
		var t: float = float(i) / RATE
		lp += (randf_range(-1.0, 1.0) - lp) * smooth
		var edge: float = minf(1.0, minf(t, seconds - t) / 0.2)
		out[i] = lp * 0.9 * edge
	return _wav(out)


func _make_knock() -> AudioStreamWAV:
	var n: int = int(RATE * 0.35)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase: float = 0.0
	var lp: float = 0.0
	for i in n:
		var t: float = float(i) / RATE
		phase += TAU * (95.0 - t * 60.0) / RATE
		lp += (randf_range(-1.0, 1.0) - lp) * 0.3
		out[i] = (sin(phase) * 0.9 * exp(-t * 18.0) + lp * 0.4 * exp(-t * 60.0)) * 0.9
	return _wav(out)


## Bell-like partials with a soft attack, `length` seconds, decaying at `decay`.
func _make_chime(freqs: Array, length: float, decay: float) -> AudioStreamWAV:
	var n: int = int(RATE * length)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t: float = float(i) / RATE
		var s: float = 0.0
		for k in freqs.size():
			s += sin(TAU * float(freqs[k]) * t) * exp(-t * decay * (1.0 + k * 0.35)) / (1.0 + k * 0.6)
		var att: float = minf(1.0, t / 0.012)
		out[i] = s * att * 0.45
	return _wav(out)


func _make_lift() -> AudioStreamWAV:
	var n: int = int(RATE * 1.8)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase: float = 0.0
	var lp: float = 0.0
	for i in n:
		var t: float = float(i) / RATE
		var f: float = lerpf(70.0, 140.0, smoothstep(0.0, 1.8, t))
		phase += TAU * f / RATE
		lp += (randf_range(-1.0, 1.0) - lp) * 0.05
		var env: float = smoothstep(0.0, 0.4, t) * (1.0 - smoothstep(1.3, 1.8, t))
		out[i] = (sin(phase) * 0.5 + sin(phase * 1.5) * 0.2 + lp * 1.5) * env * 0.7
	return _wav(out)
