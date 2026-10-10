@tool
extends Node
class_name MenuAudio

## Every sound either menu screen makes, in one node.
##
## A component rather than an autoload: nothing outside `ramon/Menu/` should gain
## an audio bus or a persistent player just because these two screens want click
## feedback. It is added as a child, it dies with the screen, and it touches
## nothing global except the master bus it plays into.
##
## THREE CUES, THREE MEANINGS. The vocabulary is small on purpose - a UI that
## chirps differently for every control teaches nothing:
##
##   click  - you touched a node. Acknowledgement, nothing more.
##   select - something OPENED. A prototype launching, a mode switching.
##   error  - you tried to open something that cannot open. This is the one that
##            earns its place: the map deliberately shows work that does not
##            exist yet, and silence there reads as a broken button rather than
##            as "not yet".
##   swipe  - a panel slid in over the map. Distinct from `select` because the
##            drawer does not OPEN anything - it layers over where you already
##            are and closing it puts you straight back. A sound that matches
##            the gesture teaches that difference before any label does.
##
## Ambience is separate and mutable, because background music is the one sound
## someone might be listening past rather than to. The speaker in the legend
## stops THAT and nothing else.

const CLICK: String = "res://ramon/sounds/Eytan Krief - Slick UI - Subtle Metal Click.wav"
const SELECT: String = "res://ramon/sounds/Ni Sound - Soft UI - Digital Button Select.wav"
const ERROR: String = "res://ramon/sounds/Ni Sound - Clear UI - Modern Error.wav"
const SWIPE: String = "res://ramon/sounds/Artlist Original - Interference - Swipe.wav"
const AMBIENCE: String = "res://ramon/sounds/Okaya - Textures.mp3"

## Interface cues sit under the ambience bed rather than over it - these fire on
## every hover-click, and at full level they stop being feedback and start being
## an interruption.
const CLICK_DB: float = -14.0
const SELECT_DB: float = -9.0
## UNATTENUATED. Every other cue is pulled down to sit under the ambience bed,
## but a refusal is the one that must not be missed - it is the difference
## between "not built yet" and "this button is broken" - and it fires far less
## often than click or select, so it can afford full level without fatiguing.
## The file peaks at -4 dBFS, so this is its natural loudness, not a boost.
const ERROR_DB: float = 0.0
## Quieter than the other cues on purpose. The swipe accompanies a panel that is
## already moving and already obvious; it only has to confirm the gesture, not
## announce it. It is also the longest clip at 0.33 s, so the same level reads
## louder than a click of the same peak.
const SWIPE_DB: float = -19.0
## Background, and it should stay background. Loud enough to notice when it
## stops, quiet enough to talk over during a demo.
const AMBIENCE_DB: float = -26.0

signal muted_changed(muted: bool)

var _click: AudioStreamPlayer = null
var _select: AudioStreamPlayer = null
var _error: AudioStreamPlayer = null
var _swipe: AudioStreamPlayer = null
var _ambience: AudioStreamPlayer = null
var _muted: bool = false
var _fade: Tween = null
## The bed's level now: AMBIENCE_DB unless menu_final's Tab panel set another (set_ambience_db).
var _ambience_db: float = AMBIENCE_DB


func _ready() -> void:
	# @tool means this script also runs while authoring, and a menu that plays
	# sounds at the editor is a menu nobody leaves open.
	if Engine.is_editor_hint():
		return
	_click = _make_player(CLICK, CLICK_DB)
	_select = _make_player(SELECT, SELECT_DB)
	_error = _make_player(ERROR, ERROR_DB)
	_swipe = _make_player(SWIPE, SWIPE_DB)
	_ambience = _make_player(AMBIENCE, AMBIENCE_DB)
	if _ambience != null and _ambience.stream is AudioStreamMP3:
		# Set here rather than in the .import file: the import default is
		# loop=false, and flipping it there would change the file for anything
		# else that ever uses this track.
		(_ambience.stream as AudioStreamMP3).loop = true
		_ambience.play()


func _make_player(path: String, volume_db: float) -> AudioStreamPlayer:
	if not ResourceLoader.exists(path):
		push_warning("menu audio: missing %s" % path)
		return null
	var player := AudioStreamPlayer.new()
	player.stream = load(path)
	player.volume_db = volume_db
	add_child(player)
	return player


## A node was touched. Restarted rather than layered, because clicking along a
## row of nodes should sound like a row of clicks, not like a pile of them.
func click() -> void:
	_play(_click)


func select() -> void:
	_play(_select)


func error() -> void:
	_play(_error)


## A layer slid over the map - the contextual drawer opening or closing.
func swipe() -> void:
	_play(_swipe)


## Interface cues are NOT affected by the mute. The speaker switches off the
## background track only, so the screen keeps answering you after you silence
## the music - a menu that stops acknowledging clicks feels broken rather than
## quiet.
func _play(player: AudioStreamPlayer) -> void:
	if player == null:
		return
	player.play()


func is_muted() -> bool:
	return _muted


## Pauses or resumes the background track with a short fade, keeping its place (menu_final does
## this around a prototype, 10 Oct: the bed must not play under one, and picks up where it was on
## the way back). Does nothing while muted.
func pause_ambience(paused: bool, seconds: float = 0.6) -> void:
	if _ambience == null or _muted:
		return
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_fade = create_tween()
	if paused:
		_fade.tween_property(_ambience, "volume_db", -60.0, seconds)
		_fade.tween_callback(func() -> void: _ambience.stream_paused = true)
	else:
		_ambience.stream_paused = false
		if not _ambience.playing:
			_ambience.play()
		_ambience.volume_db = -60.0
		_fade.tween_property(_ambience, "volume_db", _ambience_db, seconds)


## The bed's level, live (menu_final's Tab panel, "Music"). Cues are not touched.
func set_ambience_db(db: float) -> void:
	_ambience_db = db
	if _ambience != null and not _ambience.stream_paused and (_fade == null or not _fade.is_running()):
		_ambience.volume_db = db


## Stops the background track. Interface cues keep playing.
func set_muted(value: bool) -> void:
	if _muted == value:
		return
	_muted = value
	if _ambience != null:
		if _muted:
			_ambience.stop()
		else:
			_ambience.play()
	muted_changed.emit(_muted)


func toggle_muted() -> void:
	set_muted(not _muted)
