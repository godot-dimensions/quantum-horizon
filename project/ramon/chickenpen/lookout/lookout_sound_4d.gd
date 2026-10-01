extends Node

## The Lookout's one-shot sounds, by name: the shutter and the winder, the rungs, the focus
## ring's ratchet, the radio's click, the balloon's burner, the owl and the heron.
##
## All baked by bake_lookout_sound.py into chickenpen/audio/sfx/lookout_*.wav, so they can be
## rebaked without touching this. A name with no file is silent rather than an error: the
## game must never stop for a missing sound.
##
## THE FOCUS RING TICKS BY DISTANCE, NOT BY FRAME: one soft click every [member focus_tick]
## metres of travel, so turning it slowly is a slow ratchet and a fast turn a buzz - which is
## what a real ring's detents sound like. [method play] is told how fast it is turning.

const FILES := {
	&"shutter": "lookout_shutter.wav",
	&"winder": "lookout_winder.wav",
	&"reload": "lookout_reload.wav",
	&"empty": "lookout_empty.wav",
	&"rung": "lookout_rung.wav",
	&"rung_start": "lookout_rung.wav",
	&"hatch": "lookout_hatch.wav",
	&"focus": "lookout_focus.wav",
	&"af": "lookout_af.wav",
	&"af_miss": "lookout_af_miss.wav",
	&"page": "lookout_page.wav",
	&"new_page": "lookout_new_page.wav",
	&"radio_on": "lookout_radio_on.wav",
	&"radio_off": "lookout_radio_off.wav",
	&"burner": "lookout_burner.wav",
	&"whistle": "lookout_whistle.wav",
	&"owl": "lookout_owl.wav",
	&"heron": "lookout_heron.wav",
	&"wings": "lookout_wings.wav",
	&"wind": "lookout_wind.wav",
	&"secret": "res://ramon/chickenpen/audio/music/CB Sounddesign - All That Glitters - Cinematic and Bright Pad with Chimes.wav",
}
const FOLDER := "res://ramon/chickenpen/audio/sfx/"
## Loudness of each, in dB, so the bakes can all sit at one level.
const LEVEL := {
	&"shutter": -4.0, &"winder": -9.0, &"reload": -8.0, &"empty": -10.0, &"rung": -14.0, &"rung_start": -14.0,
	&"hatch": -10.0, &"focus": -22.0, &"af": -14.0, &"af_miss": -16.0, &"page": -10.0, &"new_page": -6.0,
	&"radio_on": -12.0, &"radio_off": -12.0, &"burner": -6.0, &"whistle": -6.0, &"owl": -8.0, &"heron": -6.0,
	&"wings": -8.0, &"wind": -16.0, &"secret": -9.0,
}

@export_range(0.01, 0.5, 0.01, "suffix:m") var focus_tick: float = 0.08
@export var bus: StringName = &"SFX"

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next: int = 0
var _focus_travel: float = 0.0
## Held loops by name: {player, target dB}.
var _loops: Dictionary = {}


func _ready() -> void:
	for id in FILES:
		var path: String = String(FILES[id]) if String(FILES[id]).begins_with("res://") else FOLDER + String(FILES[id])
		if ResourceLoader.exists(path):
			_streams[id] = load(path)
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.bus = bus if AudioServer.get_bus_index(bus) >= 0 else &"Master"
		add_child(p)
		_players.append(p)


func has(id: StringName) -> bool:
	return _streams.has(id)


## Plays [param id]. For &"focus", [param amount] is how fast the ring is turning in m/s.
func play(id: StringName, amount: float = 1.0) -> void:
	if id == &"focus":
		_focus_travel += amount * get_process_delta_time()
		if _focus_travel < focus_tick:
			return
		_focus_travel = fmod(_focus_travel, focus_tick)
	if not _streams.has(id):
		return
	var p: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[id]
	p.volume_db = float(LEVEL.get(id, -8.0))
	p.pitch_scale = randf_range(0.94, 1.06) if id == &"rung" or id == &"focus" else 1.0
	p.play()


## A player of its own, for a sound that has to be held and faded (the burner).
func held(id: StringName) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus if AudioServer.get_bus_index(bus) >= 0 else &"Master"
	p.stream = _streams.get(id)
	p.volume_db = float(LEVEL.get(id, -8.0))
	add_child(p)
	return p


## A loop held on or off, faded to [param db] (or out): the wind up the tower and in the
## basket. Seamless loops only (they are baked to repeat without a join).
func loop(id: StringName, on: bool, db: float = 0.0) -> void:
	if not _streams.has(id):
		return
	if not _loops.has(id):
		var p: AudioStreamPlayer = held(id)
		var stream := p.stream as AudioStreamWAV
		if stream != null:
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			stream.loop_end = int(stream.get_length() * float(stream.mix_rate))
		p.volume_db = -60.0
		_loops[id] = {"player": p, "db": -60.0}
	var entry: Dictionary = _loops[id]
	entry["db"] = (float(LEVEL.get(id, -8.0)) + db) if on else -60.0
	var player: AudioStreamPlayer = entry["player"]
	if on and not player.playing:
		player.play()


func _process(delta: float) -> void:
	for id in _loops:
		var entry: Dictionary = _loops[id]
		var player: AudioStreamPlayer = entry["player"]
		player.volume_db = move_toward(player.volume_db, float(entry["db"]), delta * 30.0)
		if player.playing and player.volume_db <= -59.0 and float(entry["db"]) <= -59.0:
			player.stop()
