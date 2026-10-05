extends SceneTree

## Does the farm actually make a sound - and are they the sounds that were asked for?
##
## NOBODY CAN HEAR A HEADLESS RUN, and with `--audio-driver Dummy` there is not even a
## mixer to ask. So this does not test whether the audio is any good; it tests the things
## that go wrong silently and would otherwise be found by sitting in the scene for a
## minute and a half wondering why it went quiet:
##
##   * a bed that is not looping, so the farm stops after one pass
##   * a loop that runs to the very end of the file, through the quiet either end
##   * a catch, a grab, a scratch or a swing that plays nothing because a signal was
##     renamed at the other end
##   * two takes alternating at wildly different levels, which reads as a fault
##   * the second and third impacts in a multi-hit recording arriving with the first
##   * a crow that snaps on at full volume instead of swelling out of the bed
##   * the theatre's arrival music playing on every visit instead of the first
##
## THE ENVELOPE IS SAMPLED, NOT DERIVED. The crow's fade is checked by reading the
## player's volume every frame and looking at the shape it traces, rather than by
## recomputing the arithmetic the code already did and then agreeing with it.
##
## AND THE POLLED SOUNDS NEED A FRAME. Trym's door and the theatre are watched rather
## than signalled - neither has a signal to connect to - so the sound arrives on the
## frame AFTER the state changes. The stages below exist for that one frame of delay;
## checking in the same breath as the call is what made this test fail first time.

## WHAT EACH FILE IS MASTERED TO, measured from the sources with a script, so this test
## can check EFFECTIVE levels - fader plus file - instead of faders. Faders on their own
## say nothing: the cat scratch sits on a lower fader than the meow and is seven decibels
## the louder sound, because the two clips were mastered nine decibels apart.
const SOURCE := {
	"bed": -42.0,        # body, not peak - it is a bed
	"music": -18.4,      # body
	"cluck_a": -15.5, "cluck_b": -24.6,
	"meow": -10.8, "scratch": -2.3,
	"stone_a": -1.5, "stone_b": -1.9,
	"door": -4.6, "glitters": -6.1, "venus": -18.3, "crows": -3.9,
}
## And where the mix puts them, effective, with the window each is allowed.
const WANTED := {
	"bed": -38.0, "music": -44.0, "crows": -26.0,
	"cluck_a": -22.0, "stone_a": -22.0, "meow": -22.0,
	"door": -16.0, "glitters": -16.0, "scratch": -14.0, "venus": -34.0,
}

var _root: Node
var _f := 0
var _fails: Array = []
var _sfx: Node
var _bed: AudioStreamPlayer
var _cluck: AudioStreamPlayer
var _cat: AudioStreamPlayer
var _stone: AudioStreamPlayer
var _door: AudioStreamPlayer
var _cinema: AudioStreamPlayer
var _cinema_bed: AudioStreamPlayer
var _music: AudioStreamPlayer
var _wrap_seen: bool = false
var _last_at: float = -1.0
var _wrap_frames: int = 0
var _crow: AudioStreamPlayer
var _arch: Node
var _crossing: Node
var _envelope: Array = []
var _crow_armed: bool = false
var _stage: int = 0


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/playable_world.tscn").instantiate()
	root.add_child(_root); current_scene = _root


func _check(label: String, ok: bool, detail: String) -> void:
	print("   %s %-46s %s" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_fails.append(label)


func _process(_d) -> bool:
	_f += 1
	if _f < 5: return false

	match _stage:
		0: _find()
		1: _the_bed()
		2: _the_chicken()
		3: _the_cats()
		4: _the_rock()
		5: _door_goes_up()
		6: _door_is_up()
		7: _into_the_cinema()
		8: _first_visit()
		9: _still_inside()
		10: _second_visit()
		11: _second_visit_check()
		12: _crow_begins()
		13: return _crow_envelope()
		14: return _does_it_wrap()
		_: return true
	_stage += 1
	return false


func _find() -> void:
	_sfx = _root.get_node_or_null("Systems/Sfx")
	if _sfx == null:
		print("   FAIL there is no Systems/Sfx in the scene")
		_fails.append("no Sfx node")
		_stage = 98
		return
	_bed = _sfx.get_node_or_null("Ambience") as AudioStreamPlayer
	_cluck = _sfx.get_node_or_null("Cluck") as AudioStreamPlayer
	_cat = _sfx.get_node_or_null("Cat") as AudioStreamPlayer
	_stone = _sfx.get_node_or_null("Stone") as AudioStreamPlayer
	_door = _sfx.get_node_or_null("Door") as AudioStreamPlayer
	_cinema = _sfx.get_node_or_null("Cinema") as AudioStreamPlayer
	_cinema_bed = _sfx.get_node_or_null("CinemaBed") as AudioStreamPlayer
	_music = _sfx.get_node_or_null("Music") as AudioStreamPlayer
	_crow = _sfx.get_node_or_null("Crow") as AudioStreamPlayer
	_arch = _root.get_node_or_null("World/TrymCabin/TrymDoor")
	_crossing = _root.get_node_or_null("Crossing")


func _the_bed() -> void:
	print("\n--- the bed ---")
	_check("there is one, and it is playing", _bed != null and _bed.playing,
		_bed.stream.resource_path.get_file().left(42) if _bed != null else "missing")
	var wav := (_bed.stream if _bed != null else null) as AudioStreamWAV
	_check("it loops", wav != null and wav.loop_mode == AudioStreamWAV.LOOP_FORWARD,
		"loop_mode %d (1 = forward)" % (wav.loop_mode if wav != null else -1))
	if wav == null:
		return
	var frames: int = int(wav.get_length() * wav.mix_rate)
	_check("the loop skips the quiet ends",
		wav.loop_begin > 0 and wav.loop_end > 0 and wav.loop_end < frames,
		"%d..%d of %d frames" % [wav.loop_begin, wav.loop_end, frames])
	_check("the bed lands where the mix wants it",
		absf(_bed.volume_db + SOURCE["bed"] - (-38.0)) < 2.0,
		"%.1f dB fader + %.1f dBFS file = %.1f effective" % [_bed.volume_db,
			SOURCE["bed"], _bed.volume_db + SOURCE["bed"]])

	print("
--- the farm's music ---")
	_check("it is playing", _music != null and _music.playing,
		_music.stream.resource_path.get_file().left(42) if _music != null else "missing")
	# Not a fixed number but a RELATIONSHIP: the music has to sit at or under the ambience,
	# because that is what "subtle" turned out to mean after two goes at a percentage.
	_check("the music sits under the birds, not over them",
		_music != null and _music.volume_db <= _bed.volume_db - 12.0,
		"music %.1f dB (%.0f%%) against the bed's %.1f dB" % [_music.volume_db,
			db_to_linear(_music.volume_db) * 100.0, _bed.volume_db])
	var tune := (_music.stream if _music != null else null) as AudioStreamWAV
	_check("its loop ends before the fade-out", tune != null
		and tune.loop_mode == AudioStreamWAV.LOOP_FORWARD
		and tune.loop_end < int(tune.get_length() * tune.mix_rate),
		"%.1f s to %.1f s of %.1f s" % [
			float(tune.loop_begin) / maxf(tune.mix_rate, 1.0),
			float(tune.loop_end) / maxf(tune.mix_rate, 1.0),
			tune.get_length()] if tune != null else "no wav")


func _the_chicken() -> void:
	print("\n--- picking a chicken up ---")
	var catcher: Node = _root.get_node_or_null("Player/Catcher")
	_check("the catcher's signal is connected", catcher != null and _cluck != null
		and catcher.is_connected("caught", Callable(_sfx, "_on_caught")),
		"caught -> PenSfx._on_caught")
	if catcher == null or _cluck == null:
		return
	var takes: Array = []
	for i in 3:
		catcher.emit_signal("caught", null)
		takes.append([_cluck.stream.resource_path.get_file(), _cluck.volume_db])
	_check("the two takes alternate",
		takes[0][0] != takes[1][0] and takes[0][0] == takes[2][0],
		"%s / %s" % [takes[0][0].left(32), takes[1][0].left(32)])
	# Take 2 peaks 9.1 dB below take 1, so a matched pair should land within a decibel.
	_check("and land at the same level", absf((takes[0][1] + 9.1) - takes[1][1]) < 1.5,
		"%.1f dB + 9.1 of headroom against %.1f dB" % [takes[0][1], takes[1][1]])


func _the_cats() -> void:
	print("\n--- the cats ---")
	_check("a player is standing by", _cat != null, "Systems/Sfx/Cat")
	for n in ["CatGrab", "RedCatGrab"]:
		var grab: Node = _root.get_node_or_null("Systems/" + n)
		_check("%s is connected both ways" % n, grab != null
			and grab.is_connected("grabbed", Callable(_sfx, "_on_cat_grabbed"))
			and grab.is_connected("scratched", Callable(_sfx, "_on_cat_scratched")),
			"grabbed + scratched")
	var tabby: Node = _root.get_node_or_null("Systems/CatGrab")
	if tabby == null or _cat == null:
		return
	tabby.emit_signal("grabbed")
	var meow: String = _cat.stream.resource_path.get_file()
	var meow_db: float = _cat.volume_db
	tabby.emit_signal("scratched")
	var angry: String = _cat.stream.resource_path.get_file()
	_check("a grab meows, a scratch does not", meow != angry
		and meow.contains("Meow") and angry.contains("Angry"),
		"%s / %s" % [meow.left(24), angry.left(24)])
	# Compared EFFECTIVE, not by fader. The scratch's fader is the lower of the two and
	# the sound is still much the louder, because the clip is mastered nine decibels
	# hotter - which is the whole reason this file stopped trusting faders.
	var meow_at: float = meow_db + SOURCE["meow"]
	var angry_at: float = _cat.volume_db + SOURCE["scratch"]
	_check("and the scratch is the louder of the two", angry_at > meow_at + 4.0,
		"%.1f dBFS against %.1f, on faders of %.1f and %.1f" % [angry_at, meow_at,
			_cat.volume_db, meow_db])


func _the_rock() -> void:
	print("\n--- the rock ---")
	var pick: Node = _root.get_node_or_null("Systems/Pickaxe")
	_check("the pickaxe's signal is connected", pick != null and _stone != null
		and pick.is_connected("mined", Callable(_sfx, "_on_mined")),
		"mined -> PenSfx._on_mined")
	if pick == null or _stone == null:
		return
	var takes: Array = []
	var pitches: Array = []
	var stops: Array = []
	for i in 4:
		pick.emit_signal("mined", Vector4.ZERO, 1.0)
		takes.append(_stone.stream.resource_path.get_file())
		pitches.append(_stone.pitch_scale)
		stops.append(float(_sfx.get("_stone_stop_in")))
	_check("the two takes alternate", takes[0] != takes[1] and takes[0] == takes[2],
		"%s / %s" % [takes[0].left(21), takes[1].left(21)])
	_check("the pitch moves between hits", pitches.max() - pitches.min() > 0.005,
		"%.3f to %.3f over four swings" % [pitches.min(), pitches.max()])
	_check("only the multi-hit take is cut short", stops[0] == 0.0 and stops[1] > 0.0,
		"take A runs out, take B stops at %.2f s" % stops[1])
	# That file's first and second impacts are 0.595 s and 0.790 s apart, with digital
	# silence between them. A cut inside the gap takes the whole first hit and none of
	# the second.
	_check("and the cut lands in the silence between impacts",
		stops[1] > 0.60 and stops[1] < 0.78, "%.2f s, gap is 0.60-0.79 s" % stops[1])
	_check("quieter than the clip is mastered", _stone.volume_db < -4.0,
		"%.1f dB against a clip peaking at -1.5 dBFS" % _stone.volume_db)


func _door_goes_up() -> void:
	print("\n--- Trym's door ---")
	_check("it has a sound, and has not made it yet",
		_door != null and not _door.playing, "Systems/Sfx/Door")
	if _arch != null:
		_arch.set("armed", true)


func _door_is_up() -> void:
	_check("raising it plays the reveal", _door != null and _door.playing,
		"armed false -> true, one frame later")
	if _door != null:
		_door.stop()
	if _arch != null:
		_arch.set("armed", false)


func _into_the_cinema() -> void:
	_check("closing it plays the same sound again", _door != null and _door.playing,
		"armed true -> false")
	print("\n--- the cinema ---")
	_check("it has a sound, and has not played", _cinema != null
		and not bool(_sfx.get("_been_to_the_cinema")), "Systems/Sfx/Cinema")
	if _crossing != null and _crossing.has_method("go"):
		_crossing.call("go")


func _first_visit() -> void:
	_check("walking in plays the arrival", _cinema != null and _cinema.playing,
		"once a run")
	_check("and the music starts, softly, on a loop", _cinema_bed != null
		and _cinema_bed.playing and _cinema_bed.volume_db < -10.0,
		"%.1f dB" % (_cinema_bed.volume_db if _cinema_bed != null else 0.0))
	var bed := (_cinema_bed.stream if _cinema_bed != null else null) as AudioStreamWAV
	_check("its loop skips the composed fades", bed != null
		and bed.loop_mode == AudioStreamWAV.LOOP_FORWARD and bed.loop_begin > 0
		and bed.loop_end < int(bed.get_length() * bed.mix_rate),
		"%.1f s to %.1f s of %.1f s" % [
			float(bed.loop_begin) / maxf(bed.mix_rate, 1.0),
			float(bed.loop_end) / maxf(bed.mix_rate, 1.0),
			bed.get_length()] if bed != null else "no wav")
	_check("the farm does not carry into the room", _bed != null and not _bed.playing,
		"the ambience stops at the door")
	# THE THIRD SOUND, which the first version of this forgot. Silencing the two beds by
	# hand is the obvious half of "the farm stops at the door"; the crows are on a timer
	# of their own and kept going, because the node deliberately survives the crossing so
	# the music can start. A check that only knows about the beds passes a scene with
	# crows in the theatre.
	_check("and neither do the crows", _crow != null and not _crow.playing,
		"crow player silent inside")
	# Hurry its clock right up. Outdoors this would fire an event immediately; in here it
	# must not fire at all, and it must not be sitting fully wound to go off the instant
	# the player steps back out.
	_sfx.set("_crow_wait", 0.01)
	_crow_armed = true
	if _cinema != null:
		_cinema.stop()
	# Deliberately NOT leaving yet - _still_inside runs next, with the clock wound and the
	# player still in the room. Coming home here is what made this check meaningless the
	# first time: the crow then fired outdoors, correctly, and was reported as a failure.


## Still in the theatre, one frame on, with the crow's clock wound to almost nothing.
func _still_inside() -> void:
	_check("a wound-up crow does not go off indoors",
		_crow != null and not _crow.playing and _crow_armed,
		"clock forced to 0.01 s, a frame has passed, still nothing")
	if _crossing != null:
		_crossing.call("come_back")


func _second_visit() -> void:
	_check("coming home brings the farm back", _bed != null and _bed.playing,
		"and the music stops: %s" % ("stopped" if _cinema_bed != null
			and not _cinema_bed.playing else "STILL PLAYING"))
	if _crossing != null:
		_crossing.call("go")
	# Straight to the second-visit check, skipping the stage numbers in between. Written
	# as the stage BEFORE it because _process adds one after every arm.
	_stage = 10


func _second_visit_check() -> void:
	_check("a second visit does not replay the arrival",
		_cinema != null and not _cinema.playing, "still once a run")
	_check("but the music does start again", _cinema_bed != null and _cinema_bed.playing,
		"every visit")
	if _crossing != null:
		_crossing.call("come_back")


func _crow_begins() -> void:
	print("\n--- the crows ---")
	_check("there is a player for them", _crow != null, "Systems/Sfx/Crow")
	if _crow == null:
		_finish()
		return
	# Hurry the first lot along - the real gap is a minute or more.
	_sfx.set("_crow_wait", 0.02)


func _crow_envelope() -> bool:
	_envelope.append(_crow.volume_db)
	if _envelope.size() < 5:
		return false
	if float(_sfx.get("_crow_left")) > 0.0 and _envelope.size() < 4000:
		return false
	var top: float = _envelope.max()
	var at_top: int = _envelope.find(top)
	_check("it starts from silence", _envelope[0] < -40.0,
		"%.1f dB on the first frame" % _envelope[0])
	_check("it swells to its level", absf(top - float(_sfx.get("crow_db"))) < 1.0,
		"%.1f dB, asked for %.1f" % [top, float(_sfx.get("crow_db"))])
	_check("the top is in the middle, not at either end",
		at_top > 0 and at_top < _envelope.size() - 1,
		"peaked %d frames into %d" % [at_top, _envelope.size()])
	_check("and it falls away again", _envelope[-1] < top - 10.0,
		"%.1f dB at the end, %.1f at the top" % [_envelope[-1], top])
	_check("quieter than the clip is mastered", float(_sfx.get("crow_db")) < -10.0,
		"%.1f dB against a clip peaking at -3.9 dBFS" % float(_sfx.get("crow_db")))
	_check("it is the murder of crows, not the single caw",
		_crow.stream.resource_path.get_file().contains("Murder"),
		_crow.stream.resource_path.get_file().left(38))
	_check("an event is a window, not the whole recording",
		float(_sfx.get("crow_event_seconds")) < _crow.stream.get_length() * 0.5,
		"%.0f s window out of %.0f s" % [float(_sfx.get("crow_event_seconds")),
			_crow.stream.get_length()])
	_the_whole_mix()
	_stage = 14
	_arm_wrap()
	return false


## Every sound against the one number that matters: where it ends up, in dBFS.
##
## THIS IS THE CHECK THAT WOULD HAVE CAUGHT THE ORIGINAL MIX. Each fader was reasonable
## on its own and the set of them was not: 43 dB between the quietest always-on sound and
## the loudest one-shot. Asserting each fader separately can never see that, because the
## fault is in the relationships. So this asserts the relationships.
func _the_whole_mix() -> void:
	print("
--- the mix, in effective dBFS ---")
	var at := {
		"bed": _bed.volume_db + SOURCE["bed"],
		"music": _music.volume_db + SOURCE["music"],
		"crows": _crow.get("volume_db") if false else float(_sfx.get("crow_db")) + SOURCE["crows"],
		"cluck_a": float(_sfx.get("cluck_db")) + SOURCE["cluck_a"],
		"stone_a": float(_sfx.get("stone_db")) + SOURCE["stone_a"],
		"meow": float(_sfx.get("cat_meow_db")) + SOURCE["meow"],
		"door": float(_sfx.get("door_db")) + SOURCE["door"],
		"glitters": float(_sfx.get("cinema_db")) + SOURCE["glitters"],
		"scratch": float(_sfx.get("cat_angry_db")) + SOURCE["scratch"],
		"venus": float(_sfx.get("cinema_bed_db")) + SOURCE["venus"],
	}
	for key in WANTED:
		_check("%-9s" % key, absf(at[key] - WANTED[key]) < 2.5,
			"%6.1f dBFS, wanted %6.1f" % [at[key], WANTED[key]])
	# Take B of each pair has to arrive at the same place as take A, or the alternation
	# is heard as a fault rather than as variety.
	_check("both cluck takes land together",
		absf((float(_sfx.get("cluck_db")) + float(_sfx.get("cluck_b_trim"))
			+ SOURCE["cluck_b"]) - at["cluck_a"]) < 1.5, "within a decibel")
	_check("both stone takes land together",
		absf((float(_sfx.get("stone_db")) + float(_sfx.get("stone_b_trim"))
			+ SOURCE["stone_b"]) - at["stone_a"]) < 1.5, "within a decibel")
	# The spread is the thing that was actually wrong. Everything that is always there
	# has to live within shouting distance of everything that happens.
	var loudest: float = -200.0
	for key in at:
		loudest = maxf(loudest, at[key])
	_check("nothing towers over the bed", loudest - at["bed"] < 26.0,
		"%.1f dB from the bed to the loudest sound (was 43)" % (loudest - at["bed"]))
	print("
--- the buses ---")
	for name in ["Master", "Music", "Ambience", "SFX"]:
		_check("there is a %s bus" % name, AudioServer.get_bus_index(name) >= 0,
			"limiter on it" if AudioServer.get_bus_index(name) == 0
				and AudioServer.get_bus_effect_count(0) > 0 else "")
	for pair in [[_bed, "Ambience"], [_music, "Music"], [_cinema_bed, "Music"],
			[_cluck, "SFX"], [_cat, "SFX"], [_stone, "SFX"], [_door, "SFX"],
			[_crow, "Ambience"]]:
		_check("%s goes to %s" % [(pair[0] as Node).name, pair[1]],
			(pair[0] as AudioStreamPlayer).bus == StringName(pair[1]),
			str((pair[0] as AudioStreamPlayer).bus))


## Does a QOA-compressed stream ACTUALLY loop, or does it just carry the properties?
##
## This is the question the rest of the file cannot answer. The loop is set in code rather
## than in the import, and the checks above only prove the numbers are on the resource -
## which is exactly the trap the import turned out to be. The farm's music is the one
## sound left at the project's default compression, and at seven and a half minutes it is
## also the one where the choice is worth about sixty megabytes, so it is worth knowing
## rather than assuming.
##
## So: shrink its loop to half a second, drop the playhead just before the end of that
## window, and watch. A playhead that goes BACKWARDS while the player is still going has
## wrapped. One that runs past the end, or stops, has not.
func _arm_wrap() -> void:
	print("
--- does the loop actually come round ---")
	if _music == null:
		_check("there is music to test", false, "no Music player")
		_finish()
		return
	var wav := _music.stream as AudioStreamWAV
	var rate: float = float(wav.mix_rate)
	wav.loop_begin = int(2.0 * rate)
	wav.loop_end = int(2.5 * rate)
	_music.play(2.4)
	_last_at = -1.0
	_wrap_seen = false
	_wrap_frames = 0


func _does_it_wrap() -> bool:
	_wrap_frames += 1
	var at: float = _music.get_playback_position()
	if _last_at >= 0.0 and at < _last_at - 0.001:
		_wrap_seen = true
	_last_at = at
	if not _wrap_seen and _wrap_frames < 400 and _music.playing:
		return false
	var wav := _music.stream as AudioStreamWAV
	var fmt: String = ["8-bit", "16-bit", "IMA ADPCM", "QOA"][wav.format]
	_check("the playhead comes back round", _wrap_seen,
		"%s, %d frames, last position %.3f s" % [fmt, _wrap_frames, _last_at])
	_check("and it is still playing", _music.playing, "not stopped at the loop end")
	_finish()
	return true


func _finish() -> void:
	if _fails.is_empty():
		print("\nALL PASS")
	else:
		print("\n%d FAILED: %s" % [_fails.size(), ", ".join(_fails)])
	quit(1 if _fails.size() > 0 else 0)
