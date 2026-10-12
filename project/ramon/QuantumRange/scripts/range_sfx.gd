extends Node

## The range's sounds, by name, from files already in the project (referenced, never copied: the
## project's UI sounds, Ramon's range's charge sounds, and two of the pen's, its cluck and its wings).
## A small pool of players, so sounds overlap without cutting each other off.
##
## NO class_name (engine_gotchas.md).

const SOUNDS := {
	"charge": "res://ramon/ShootingGalleryRamon/audio/charge_buildup_ramon.wav",
	"release": "res://ramon/ShootingGalleryRamon/audio/charge_release_ramon.wav",
	"pop": "res://ramon/sounds/Ni Sound - Soft UI - Digital Button Select.wav",
	"click": "res://ramon/sounds/Eytan Krief - Slick UI - Subtle Metal Click.wav",
	"error": "res://ramon/sounds/Ni Sound - Clear UI - Modern Error.wav",
	"break": "res://ramon/chickenpen/audio/sfx/Ni Sound - Island Game - Stone Breaking.wav",
	"whoosh": "res://ramon/sounds/Artlist Original - Interference - Swipe.wav",
	"done": "res://ramon/chickenpen/audio/sfx/Dauzkobza - Broadcast Central - Neon Logo Reveal.wav",
	"cluck": "res://ramon/chickenpen/audio/sfx/Carlos Santa Rita - Chicken clucking in a farm 1.wav",
	"wings": "res://ramon/chickenpen/audio/sfx/lookout_wings.wav",
}

var _streams: Dictionary = {}
var _pool: Array = []
var _next: int = 0
var _charge: AudioStreamPlayer
var muted: bool = false


func _ready() -> void:
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	_charge = AudioStreamPlayer.new()
	add_child(_charge)


func _stream(nm: String) -> AudioStream:
	if not _streams.has(nm):
		var path: String = String(SOUNDS.get(nm, ""))
		_streams[nm] = load(path) if not path.is_empty() and ResourceLoader.exists(path) else null
	return _streams[nm]


func play(nm: String, pitch: float = 1.0, db: float = 0.0, from: float = 0.0) -> void:
	if muted:
		return
	var s: AudioStream = _stream(nm)
	if s == null:
		return
	var p: AudioStreamPlayer = _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = s
	p.pitch_scale = pitch
	p.volume_db = db
	p.play(from)


## The charge's rising tone (Ramon's): `k` 0..1 pitches it up; below 0 stops it.
func charge(k: float) -> void:
	if muted:
		return
	if k < 0.0:
		if _charge.playing:
			_charge.stop()
		return
	if _charge.stream == null:
		_charge.stream = _stream("charge")
		_charge.volume_db = -2.0
	_charge.pitch_scale = lerpf(0.7, 2.0, clampf(k, 0.0, 1.0))
	if not _charge.playing:
		_charge.play()
