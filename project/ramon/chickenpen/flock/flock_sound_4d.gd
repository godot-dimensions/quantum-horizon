extends Node

## What the murmuration sounds like from where the camera is - Ramon, 1 Oct: "a noise/
## flapping sound that gets louder as the player is closer or, as the clump is bigger".
##
## BOTH OF THOSE ARE ONE NUMBER. The flock sums every bird's sound power at the camera,
## falling with the square of distance (pen_flock_4d.sound()), so a dense clump overhead and
## a whole flock nearby are loud for the same reason they would be outside, and a far flock
## is a faint hiss. Three baked loops (bake_flock_sound.py) are mixed from it:
##   the rush     follows that power directly: +10 dB for every ten times the power
##   the flutter  the nearest wings, fading in only when the flock is close
##   the gust     the roll: as loud as the share of the sound that comes from rolling birds
##
## THERE IS NO POSITIONAL AUDIO IN 4D (see pen_sfx_4d.gd), so position is done by hand on a
## bus of its own: a low-pass that closes as the flock gets further away - air takes the top
## off distant sound - and a panner towards the side the mass is on.
##
## IT SLEEPS WITH THE PEN FOR FREE. The players are children of the flock, and Godot pauses
## an AudioStreamPlayer whose node cannot process or has left the tree, which is exactly
## what the cinema and the cave (World disabled) and a laptop trip (the pen parked) do.

const RUSH := preload("res://ramon/chickenpen/audio/sfx/flock_rush.wav")
const FLUTTER := preload("res://ramon/chickenpen/audio/sfx/flock_flutter.wav")
const GUST := preload("res://ramon/chickenpen/audio/sfx/flock_gust.wav")
const BUS := &"Flock"

@export var flock_path: NodePath = NodePath("..")
## The bus the flock's own bus feeds. Ambience, with the farm's bed.
@export var send_bus: StringName = &"Ambience"
## The rush's fader when the camera hears [member reference_power] - about what standing
## under the flock gives. The loops are -20 dBFS RMS, so this puts it near -24 effective,
## above the farm bed's -38 (pen_sfx_4d.gd's table), and a far flock under it.
@export_range(-40.0, 12.0, 0.5, "suffix:dB") var rush_db: float = -4.0
@export_range(1.0, 100000.0, 1.0) var reference_power: float = 1000.0
@export_range(-30.0, 12.0, 0.5, "suffix:dB") var flutter_trim: float = -2.0
@export_range(-30.0, 12.0, 0.5, "suffix:dB") var gust_trim: float = 2.0
## The flutter fades in between these sound powers.
@export var flutter_from: float = 150.0
@export var flutter_full: float = 1500.0
## Low-pass cutoff far and near, Hz.
@export var far_cutoff: float = 900.0
@export var near_cutoff: float = 9000.0
@export_range(0.0, 1.0, 0.05) var pan_width: float = 0.75
## How fast the mix follows the flock, per second.
@export_range(0.5, 20.0, 0.5) var follow: float = 5.0

var _flock: Node
var _rush: AudioStreamPlayer
var _flutter: AudioStreamPlayer
var _gust: AudioStreamPlayer
var _bus: int = -1
var _filter: AudioEffectLowPassFilter
var _panner: AudioEffectPanner
var _level: float = -80.0
var _near: float = 0.0
var _roll: float = 0.0
var _pan: float = 0.0


func _ready() -> void:
	_flock = get_node_or_null(flock_path)
	_make_bus()
	_rush = _player(RUSH)
	_flutter = _player(FLUTTER)
	_gust = _player(GUST)


## The flock's own bus, made here if it is not there yet: a low-pass and a panner, then on
## to [member send_bus]. Made at run time rather than in default_bus_layout.tres, which is
## the whole project's and not the pen's to change.
func _make_bus() -> void:
	_bus = AudioServer.get_bus_index(BUS)
	if _bus < 0:
		AudioServer.add_bus()
		_bus = AudioServer.bus_count - 1
		AudioServer.set_bus_name(_bus, BUS)
		AudioServer.add_bus_effect(_bus, AudioEffectLowPassFilter.new(), 0)
		AudioServer.add_bus_effect(_bus, AudioEffectPanner.new(), 1)
	var send: StringName = send_bus if AudioServer.get_bus_index(send_bus) >= 0 else &"Master"
	AudioServer.set_bus_send(_bus, send)
	_filter = AudioServer.get_bus_effect(_bus, 0) as AudioEffectLowPassFilter
	_panner = AudioServer.get_bus_effect(_bus, 1) as AudioEffectPanner


func _player(stream: AudioStreamWAV) -> AudioStreamPlayer:
	# Looped here, not in the import - the import's loop settings do nothing in this build
	# (pen_sfx_4d.gd). The loops are whole, so the points are the ends.
	var looped: AudioStreamWAV = stream.duplicate()
	looped.loop_mode = AudioStreamWAV.LOOP_FORWARD
	looped.loop_begin = 0
	looped.loop_end = int(looped.get_length() * float(looped.mix_rate))
	var p := AudioStreamPlayer.new()
	p.stream = looped
	p.bus = BUS
	p.volume_db = -80.0
	add_child(p)
	# Each from its own place in its loop, so the three never line up the same way twice.
	p.play(randf() * looped.get_length())
	return p


func _process(delta: float) -> void:
	if _flock == null or _rush == null:
		return
	var heard: Dictionary = _flock.call("sound")
	var shown: bool = (_flock as Node4D).is_visible_in_tree()
	var power: float = float(heard.get("loud", 0.0)) if shown else 0.0
	# Power sums, so level is ten times its log: ten times the power, +10 dB.
	var level: float = 10.0 * log(maxf(power, 1e-6) / reference_power) / log(10.0)
	var near: float = clampf(log(maxf(power, 1.0) / flutter_from) / log(flutter_full / flutter_from), 0.0, 1.0)
	var roll: float = float(heard.get("rolling", 0.0))
	var pan: float = 0.0
	if heard.has("from"):
		pan = clampf((heard["from"] as Vector4).dot(heard["right"] as Vector4), -1.0, 1.0) * pan_width
	var k: float = minf(delta * follow, 1.0)
	_level = lerpf(_level, clampf(level, -60.0, 8.0), k)
	_near = lerpf(_near, near, k)
	_roll = lerpf(_roll, roll, k)
	_pan = lerpf(_pan, pan, minf(delta * follow * 0.5, 1.0))
	_rush.volume_db = rush_db + _level
	_flutter.volume_db = rush_db + _level + flutter_trim + linear_to_db(maxf(_near, 0.001))
	_gust.volume_db = rush_db + _level + gust_trim + linear_to_db(maxf(_roll * 2.0, 0.001))
	# A bigger roll is a brighter one.
	_gust.pitch_scale = 1.0 + _roll * 0.25
	if _filter != null:
		var closeness: float = clampf((_level + 25.0) / 30.0, 0.0, 1.0)
		_filter.cutoff_hz = lerpf(far_cutoff, near_cutoff, closeness * closeness)
	if _panner != null:
		_panner.pan = _pan


## For runners: what the mix is doing.
func mix() -> Dictionary:
	return {"rush_db": _rush.volume_db if _rush else -80.0, "flutter_db": _flutter.volume_db if _flutter else -80.0,
		"gust_db": _gust.volume_db if _gust else -80.0, "cutoff": _filter.cutoff_hz if _filter else 0.0, "pan": _pan,
		"playing": _rush != null and _rush.playing and not _rush.stream_paused}
