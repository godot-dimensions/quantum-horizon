extends Node
## Crosswise: its sounds (PLAN.md steps 69-71). The files are in ../audio/ (SOURCES.md says where
## each came from).
##
## SOUND FADES WITH W. Miegakure changes every sound with what should be audible across W
## (RESEARCH.md, lesson 7). Godot's 3D audio cannot hear a 4D world (the 4D renderer draws through
## a World3D of its own), so this works the level out by hand: an event at a 4D point is quieter the
## further it is from the listener in X, Y and Z, and much quieter for every metre of W between them,
## so a bridge laid in another world sounds like it is happening somewhere else.
##
## A small pool of plain players, so overlapping sounds do not cut each other off, plus one looping
## bed under everything.
##
## NO class_name (engine_gotchas.md).

const DIR := "res://ramon/MiegakureLook/Remake/audio/"
## name: [file, volume dB, pitch spread]
const SOUNDS := {
	"turn": ["turn.wav", -15.0, 0.04],
	"lift": ["lift.wav", -14.0, 0.06],
	"place": ["place.wav", -16.0, 0.05],
	"refuse": ["refuse.wav", -20.0, 0.0],
	"strike": ["strike.wav", -12.0, 0.07],
	"shatter": ["shatter.wav", -9.0, 0.04],
	"plate": ["plate.wav", -16.0, 0.0],
	"bridge": ["bridge.wav", -18.0, 0.08],
	"finale": ["finale.wav", -10.0, 0.0],
}
const BED := "bed.ogg"
const BED_DB := -24.0
## How much quieter, per metre of W between the sound and the listener.
const DB_PER_W_METRE := 5.0

var listener: Node4D
var muted: bool = false
var _streams: Dictionary = {}
var _pool: Array = []
var _next: int = 0
var _bed: AudioStreamPlayer


func _ready() -> void:
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	for name in SOUNDS:
		var stream: AudioStream = _stream(DIR + String(SOUNDS[name][0]))
		if stream != null:
			_streams[name] = stream
	var s: AudioStream = _stream(DIR + BED)
	if s != null:
		if s is AudioStreamOggVorbis:
			(s as AudioStreamOggVorbis).loop = true
		_bed = AudioStreamPlayer.new()
		_bed.stream = s
		_bed.volume_db = BED_DB
		add_child(_bed)
		_bed.play()


## A sound by path: the imported resource when the editor has imported it, else read straight from
## the file (so a run before anyone has opened the editor still has sound, and nothing has to run
## the project-wide importer).
static func _stream(path: String) -> AudioStream:
	if ResourceLoader.exists(path):
		return load(path)
	var file: String = ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(file):
		return null
	if path.ends_with(".ogg"):
		return AudioStreamOggVorbis.load_from_file(file)
	if path.ends_with(".wav"):
		return AudioStreamWAV.load_from_file(file)
	return null


## Plays `name`; with `at`, quieter by distance (and by W distance much more).
func play(name: String, at: Vector4 = Vector4.INF, gain_db: float = 0.0) -> void:
	if muted or not _streams.has(name):
		return
	var spec: Array = SOUNDS[name]
	var db: float = float(spec[1]) + gain_db
	if at != Vector4.INF and listener != null:
		var d: Vector4 = at - listener.global_position
		var near: float = Vector3(d.x, d.y, d.z).length()
		db -= 20.0 * log(1.0 + near / 8.0) / log(10.0)
		db -= absf(d.w) * DB_PER_W_METRE
	var p: AudioStreamPlayer = _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = _streams[name]
	p.volume_db = db
	p.pitch_scale = 1.0 + randf_range(-float(spec[2]), float(spec[2]))
	p.play()


func set_bed(on: bool) -> void:
	if _bed != null:
		_bed.stream_paused = not on
