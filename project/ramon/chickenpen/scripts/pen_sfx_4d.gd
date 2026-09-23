extends Node

## The recorded sound: the farm you can hear, the bird in your hands, the cat, the crows.
##
## SEPARATE FROM chicken_cues_4d.gd ON PURPOSE. That node owns the SYNTHESISED sounds, and
## it owns them because they are instruments rather than recordings - the cluck's rate and
## level are the locator's alignment number made audible, so the sound and the words can
## never disagree. Nothing here encodes anything. These are field recordings played back
## because the farm should not be silent, and mixing the two into one node would mean the
## thing that has to stay honest shares a file with the thing that is just atmosphere.
##
## ALL OF IT IS NON-POSITIONAL, AND NOT BY CHOICE. The 4D module has no
## AudioStreamPlayer4D and no listener - there is no positional audio in a 4D scene at all,
## so a crow cawing from the fence and a crow cawing from behind you are the same sound at
## the same level. That decides the design rather than limiting it: everything in here is
## written as a BED, something heard rather than something located. A cacophony that swells
## and recedes reads as birds kicking off somewhere over there; the same recording snapped
## on at full level reads as a bug.
##
## THE LOOP IS SET HERE, NOT IN THE IMPORT, AND THAT IS NOT A PREFERENCE.
## `edit/loop_mode` in a .wav's .import does nothing in this build - measured directly, at
## both compression settings: the file says loop_mode=1 with loop points either side of
## the quiet ends, and the resource that comes back out reports loop_mode 0, begin 0,
## end 0. QOA drops them and PCM drops them too. So the bed is looped by setting the
## properties on the loaded AudioStreamWAV, which does work.
##
## AND THE LOOP POINTS ARE COMPUTED, NOT WRITTEN DOWN. They come from the resource's own
## mix_rate and length, because the importer resamples: the file on disk is 96 kHz, the
## resource is 44.1 kHz, and a frame number copied from the source file would land at
## twice the intended place. Anything derived from the resource survives a re-import at
## any rate.

## THE LEVELS ARE SET AGAINST THE AMBIENCE, NOT AGAINST ZERO. Every fader in this file
## was first picked as a fraction of full scale, one sound at a time as it arrived, and
## the result was a 43 dB spread: the beds near inaudible at -48 dBFS while a cat scratch
## landed at -5. A percentage of full scale says nothing about how a sound sits next to
## another one, because it ignores how the file was mastered - this project's recordings
## come from a dozen libraries and their peaks range over twenty decibels.
##
## So the bed is placed first, at about -38 dBFS, and everything else is placed against
## it. EFFECTIVE LEVEL = FADER + THE FILE'S OWN LEVEL, and it is the effective column
## that was chosen:
##
##   the bed ................ -38    a room tone, noticed when it stops
##   the music .............. -44    under the bed, as asked
##   the crows .............. -26    weather, somewhere else
##   cluck, stone, meow ..... -22    a thing you did, confirmed
##   the pickup blip ........ -22    the same, in a timbre the farm has not got
##   door, arrival .......... -16    a moment, once
##   the scratch ............ -14    the loudest thing, because it is the punishment
##   Venus under a speaker .. -34
##
## The faders themselves are therefore all over the place - the bed is at +4 because that
## recording is quiet, the stone at -20.5 because that one is mastered hot - and that is
## the point. A tidy-looking column of numbers here would mean an untidy mix.
##
## AND THERE ARE THREE BUSES, so those relationships survive somebody wanting the music
## down. Music, Ambience and SFX all feed a Master carrying a hard limiter at -1 dB,
## which does nothing at all until a scratch lands over a stone hit over two beds.

## A lot of crows has just started, and is about to get loud. Emitted at the bottom of the
## swell rather than the top, so whatever listens can decide for itself how far into the
## noise it wants to arrive - `pen_crow_line_4d` waits out the fade, because a line that
## appears before you have heard anything is a line about nothing.
signal crows_rising


const MUSIC := &"Music"
const AMBIENCE := &"Ambience"
const SFX := &"SFX"

## The looping bed: ninety seconds of backyard farm.
@export_file("*.wav") var ambience_file: String = "res://ramon/chickenpen/audio/sfx/Craig Carter Collection - Australian Soundscapes - Backyard Farm Chicken Clucks Birds Chirping.wav"
## Half volume, which is -6 dB: an amplitude of 0.5. (Half as LOUD would be about -10 dB -
## loudness is not linear in amplitude - but half volume is the fader at the halfway mark,
## and that is -6.)
@export_range(-60.0, 6.0, 0.5) var ambience_db: float = 4.0
## How much to cut off each end before looping.
##
## The recording starts and finishes quieter than its body - about -55 dBFS against -40 -
## so looping the whole file puts an audible dip in every ninety seconds. Half a second
## inside each end, the two sides of the seam are within a couple of decibels of each
## other, which in a bed this diffuse is nothing.
@export_range(0.0, 5.0, 0.1) var ambience_loop_trim: float = 0.5
@export var ambience_enabled: bool = true

@export_group("Picking a chicken up")
## Two takes, played alternately rather than at random. Two sounds picked randomly repeat
## by chance about half the time, which is the case you actually notice; strict alternation
## never does, and with only two clips nobody can hear the pattern.
@export_file("*.wav") var cluck_a_file: String = "res://ramon/chickenpen/audio/sfx/Carlos Santa Rita - Chicken clucking in a farm 1.wav"
@export_file("*.wav") var cluck_b_file: String = "res://ramon/chickenpen/audio/sfx/Carlos Santa Rita - Chicken clucking in a farm 2.wav"
@export_range(-40.0, 12.0, 0.5) var cluck_db: float = -6.5
## Take 2 peaks 9 dB below take 1 (-24.6 against -15.5 dBFS), so alternating them raw gives
## a loud bird and then a quiet one. This trim is measured, not taste: it puts the two
## takes at the same peak so the alternation is heard as variety rather than as a fault.
@export_range(-12.0, 18.0, 0.5) var cluck_b_trim: float = 9.0
## Named rather than assumed, so a rename announces itself instead of going quiet.
@export var catcher_path: NodePath

@export_group("The cats")
## THE PICKUP BLIP, and it answers two complaints at once.
##
## ONE: nothing confirmed an item reaching the belt. The gauntlet, the coin, Mithra's
## nugget - they appeared in a slot and the world said nothing. This listens to the belt's
## own `picked_up`, which fires from the single line inside `add_item` that actually
## appends, so it cannot go off for a duplicate or a full belt.
##
## TWO: catching a chicken WAS already making a sound and Ramon could not hear it. The two
## cluck takes are farm recordings playing over `ambience_file`, which is ninety seconds of
## chicken clucks and birds. Same species, same room, same spectrum - the confirm was
## masked by the bed it was mixed against, which is a mixing fault and not a missing sound.
## So the blip plays on a catch too, under the cluck: a short bright UI transient has
## nothing in common with a farmyard and cuts straight through it. The cluck is still the
## character of the moment, the blip is what tells you it happened.
##
## It is the menu's select sound, copied into the pen's own audio folder rather than
## referenced across at res://ramon/sounds/, because the pen is meant to stand on its own.
@export_file("*.wav") var blip_file: String = "res://ramon/chickenpen/audio/sfx/Ni Sound - Soft UI - Digital Button Select.wav"
## The file peaks at -7.6 dBFS, and the confirm row in the table above is -22 effective.
@export_range(-40.0, 12.0, 0.5) var blip_db: float = -14.5
## The belt, which is where every item on the farm ends up.
@export var inventory_path: NodePath = NodePath("../../UI/Inventory")
## The troughs, so buying one makes the same noise as picking one up.
@export var upgrades_path: NodePath = NodePath("../../Pen/Upgrades")

## Picked up. Both cats get it - the tabby you are stealing and Trym's, who does not mind.
@export_file("*.wav") var cat_meow_file: String = "res://ramon/chickenpen/audio/sfx/Marcello Del Monaco - Pet Sounds - Cat Happy Meow.wav"
@export_range(-40.0, 12.0, 0.5) var cat_meow_db: float = -11.0
## And the moment its patience runs out and it takes your face off.
@export_file("*.wav") var cat_angry_file: String = "res://ramon/chickenpen/audio/sfx/Eneas Mentzel - Animal Species - Cat Angry.wav"
## Louder than the meow on purpose. The scratch is the one sound in here attached to
## something going wrong for the player, and the clip is mastered hot (-2.3 dBFS against
## the meow's -10.8), so this is a smaller number for a bigger sound.
@export_range(-40.0, 12.0, 0.5) var cat_angry_db: float = -12.0
## The grab nodes to listen to. Both of them by default; the red one never scratches, so
## it only ever contributes a meow.
@export var cat_grab_paths: Array[NodePath] = [NodePath("../CatGrab"), NodePath("../RedCatGrab")]

@export_group("The rock")
## A swing that actually takes a bite out of the boulder.
##
## ON THE PICKAXE'S `mined` SIGNAL, WHICH IS THE WHOLE POINT OF IT. pen_pickaxe_4d emits
## that only after the ray has hit, come in under reach, found a body that owns a
## mine_at_shape, and carved - every other path returns before it. So a swing into thin
## air is silent and a swing that connects is not, without this file knowing anything
## about raycasts. The gold in the rock already listens to the same signal.
##
## Two takes, alternating, for the same reason the clucks are.
@export_file("*.wav") var stone_file: String = "res://ramon/chickenpen/audio/sfx/Ni Sound - Island Game - Stone Breaking.wav"
@export_file("*.wav") var stone_b_file: String = "res://ramon/chickenpen/audio/sfx/Mechanical Wave - Earth Rocks - Big Rock Impact Mining Hitting.wav"
## Take B is THREE impacts in one file - onsets at 0.01, 0.82 and 1.70 seconds - and one
## swing of a pick is one impact, so only the first is played.
##
## THE CUT POINT WAS MEASURED, NOT GUESSED, and that is what makes it safe. The first hit
## decays to the noise floor by 0.595 s and the file is at DIGITAL SILENCE, -138 dBFS, from
## there until 0.790 s, where the second hit starts. Stopping at 0.68 lands in the middle
## of that gap: nothing is cut off, nothing of the second hit leaks in, and because the
## waveform is at exactly zero there is no click to fade out - a stop anywhere in a sound
## that is still ringing would need one.
@export_range(0.05, 4.0, 0.01) var stone_b_first_hit_seconds: float = 0.68
## Take B peaks at -1.9 dBFS against take A's -1.5, so they are within half a decibel of
## each other already. Here in case a future take is not.
@export_range(-12.0, 18.0, 0.5) var stone_b_trim: float = 0.0
## Lower than the cat, and for the opposite reason: this one fires every second or so for
## as long as you are digging, and the clip is mastered hot at -1.5 dBFS. A sound you hear
## forty times has to sit further down than a sound you hear twice.
@export_range(-40.0, 12.0, 0.5) var stone_db: float = -20.5
## How much the pitch wanders from one hit to the next, as a fraction.
##
## The same 1.38 seconds played identically forty times stops sounding like rock and starts
## sounding like a sample, and the ear picks that up long before it can say why. A few per
## cent either way is enough to break it, and is cheap - one property on the player.
@export_range(0.0, 0.3, 0.01) var stone_pitch_jitter: float = 0.07
@export var pickaxe_path: NodePath = NodePath("../Pickaxe")

@export_group("The farm's music")
## A piece that plays under the whole outdoor scene, on a loop, and is meant to be barely
## there.
##
## SET AGAINST THE BIRDS, NOT AGAINST ZERO, which is why fifty per cent and then twenty
## per cent were both still too loud. A percentage of full scale says nothing about how a
## sound sits in a mix; what matters is the gap to the thing beside it. This piece has a
## body around -18 dBFS and the farm recording's body is nearer -42, so the track is
## intrinsically twenty-four decibels hotter than the ambience before either fader is
## touched. At fifty per cent it was about twenty over the birds, at twenty per cent about
## fifteen.
##
## -24 dB is six per cent, and it puts the music's body near -42 dBFS - give or take level
## with the ambience rather than on top of it. That is the point where a bed stops being a
## track that happens to be quiet and becomes something you only notice when it stops.
## Each further -6 dB halves it again: -30 for almost nothing, -36 for nothing.
@export_file("*.wav") var music_file: String = "res://ramon/chickenpen/audio/music/Yotam Agam - Unconscious Mind Delta.wav"
@export_range(-60.0, 6.0, 0.5) var music_db: float = -26.0
@export var music_enabled: bool = true
## The piece opens at full level - there is no fade in to skip - but it goes out over the
## last thirteen seconds into digital silence, so the loop ends before that starts. At
## these points the two sides of the seam measure -22 and -26 dBFS.
@export_range(0.0, 60.0, 0.5) var music_trim_head: float = 0.0
@export_range(0.0, 60.0, 0.5) var music_trim_tail: float = 14.0

@export_group("The pen is full")
## The twelfth chicken lands. Two sounds at once, deliberately: a crowd and a chord.
##
## THE CHEER IS THE REACTION AND THE STRUM IS THE PUNCTUATION, and they do different
## jobs. A crowd on its own is a long unshaped noise that could mean anything; a chord on
## its own is a UI ding. Together the chord lands on the moment and the crowd carries it
## afterwards, which is the shape of the beat - a thing happened, and then everyone was
## pleased about it.
@export_file("*.wav") var cheer_file: String = "res://ramon/chickenpen/audio/sfx/Clap Studios - Crowd long and joyous cheering.wav"
@export_range(-40.0, 12.0, 0.5) var cheer_db: float = -12.0
@export_file("*.wav") var strum_file: String = "res://ramon/chickenpen/audio/sfx/Ni Sound - Acoustic Transitions - Acoustic Guitar Happy Strumming Ident.wav"
@export_range(-40.0, 12.0, 0.5) var strum_db: float = -12.0
## The game node, whose `completed` says the pen is full.
@export var game_path: NodePath = NodePath("../Game")

@export_group("Trym's door")
## The sci-fi arch Trym puts up in the field, and takes away again when you come back.
##
## WATCHED, NOT SIGNALLED. theatre_arch_4d has no signal for going up - it has an `armed`
## flag that pen_invitation_4d sets, and a setter that starts the animation. Edge-detecting
## the flag from out here gets both events, the raise and the shut, without a second file
## needing to know that a sound exists. It also means the theatre's own ExitArch, which
## runs the same script, stays silent: only the door named here is listened to.
@export_file("*.wav") var door_file: String = "res://ramon/chickenpen/audio/sfx/Dauzkobza - Broadcast Central - Neon Logo Reveal.wav"
@export_range(-40.0, 12.0, 0.5) var door_db: float = -11.0
@export var door_path: NodePath = NodePath("../../World/TrymDoor")

@export_group("The cinema")
## The first time you walk into the presentation, and only the first time.
##
## The crossing has no signal either, but it does answer `is_away()`, so this watches for
## that turning true. ONCE A RUN, because the piece is thirteen seconds of arrival music
## and the whole design of the crossing is that you can walk in and out twice in a minute -
## a fanfare on every entrance would punish exactly the behaviour it is built to allow.
@export_file("*.wav") var cinema_file: String = "res://ramon/chickenpen/audio/music/CB Sounddesign - All That Glitters - Cinematic and Bright Pad with Chimes.wav"
@export_range(-40.0, 12.0, 0.5) var cinema_db: float = -10.0
## And the music that plays under the whole presentation, every visit, on a loop.
##
## SOFTLY, because somebody is talking over it. Two and a half minutes of pad at -16 dB
## sits under a presenter; the same pad at the level it was mastered to (-4.1 dBFS peak)
## is the thing you are listening to, and the three findings become background.
@export_file("*.wav") var cinema_bed_file: String = "res://ramon/chickenpen/audio/music/Alon Peretz - Venus.wav"
@export_range(-50.0, 6.0, 0.5) var cinema_bed_db: float = -16.0
## The piece has a composed fade at each end - it comes up from -71 dBFS over ten seconds
## and goes out over twenty - so looping the file whole would drop a forty-second hole
## into the middle of the presentation. These cuts land where the two sides of the seam
## measure -23 and -22 dBFS: a decibel apart, which is under what anyone hears as a join.
@export_range(0.0, 60.0, 0.5) var cinema_bed_trim_head: float = 13.0
@export_range(0.0, 60.0, 0.5) var cinema_bed_trim_tail: float = 20.0
## The farm does not carry into the theatre. It is a room hanging in nothing, out of the
## world - chickens audible through the walls would be funny once and wrong every time
## after that.
@export var farm_stops_inside: bool = true
@export var crossing_path: NodePath = NodePath("../../Crossing")

@export_group("Crows")
## A murder of crows kicking off somewhere out of sight, now and then.
@export var crows_enabled: bool = true
@export_file("*.wav") var crow_file: String = "res://ramon/chickenpen/audio/sfx/Angel Perez Grandi - Irish Nature - Murder of Crows Cacophony.wav"
## The clip peaks at -3.9 dBFS - mastered as a foreground recording, about twenty decibels
## hotter than the bed. Left alone it does not join the farm, it replaces it.
@export_range(-50.0, 0.0, 0.5) var crow_db: float = -22.0
## Seconds between one lot and the next, picked fresh each time. Long, and wide: a sound on
## a predictable clock stops being weather and starts being a metronome.
@export_range(10.0, 400.0, 1.0) var crow_gap_min: float = 55.0
@export_range(10.0, 400.0, 1.0) var crow_gap_max: float = 150.0
## How long each lot lasts, fades included. The recording is eighty-eight seconds long and
## playing all of it would make the crows the subject of the scene rather than something
## happening at the edge of it, so an event is a WINDOW cut out of the middle.
@export_range(4.0, 90.0, 0.5) var crow_event_seconds: float = 24.0
## The swell in and the fall away, each. Clamped to half the event, so the fades can never
## overlap and leave a sound that never reaches its own level.
@export_range(0.2, 20.0, 0.1) var crow_fade_seconds: float = 5.0
## Each lot starts at a different point in the recording, so it is not the same birds doing
## the same thing every time.
@export var crow_vary_start: bool = true
## So two runs are not the same run.
@export var randomise: bool = true

var _bed: AudioStreamPlayer
var _cluck: AudioStreamPlayer
var _blip: AudioStreamPlayer
var _cat: AudioStreamPlayer
var _crow: AudioStreamPlayer
var _stone: AudioStreamPlayer
var _door: AudioStreamPlayer
var _cinema: AudioStreamPlayer
var _stone_streams: Array[AudioStream] = []
var _next_stone: int = 0
var _stone_stop_in: float = 0.0
var _arch: Node
var _arch_was: bool = false
var _crossing: Node
var _been_to_the_cinema: bool = false
var _cinema_bed: AudioStreamPlayer
var _inside: bool = false
var _music: AudioStreamPlayer
var _cheer: AudioStreamPlayer
var _strum: AudioStreamPlayer
var _cluck_streams: Array[AudioStream] = []
var _meow: AudioStream
var _angry: AudioStream
var _next_cluck: int = 0
var _crow_wait: float = 0.0
var _crow_left: float = 0.0
var _crow_fade: float = 0.0
var _crow_length: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	if randomise:
		_rng.randomize()
	_start_bed()
	_start_music()
	_start_clucks()
	_start_blips()
	_start_cats()
	_start_finish()
	_start_stone()
	_start_door()
	_start_cinema()
	_start_crows()


func _start_bed() -> void:
	if not ambience_enabled:
		return
	var wav := _load(ambience_file, "the farm bed") as AudioStreamWAV
	if wav == null:
		return
	_loop_between(wav, ambience_loop_trim, ambience_loop_trim)
	_bed = AudioStreamPlayer.new()
	_bed.name = "Ambience"
	_bed.bus = AMBIENCE
	_bed.stream = wav
	_bed.volume_db = ambience_db
	add_child(_bed)
	_bed.play()


## Sets a WAV looping between two points given in SECONDS from each end, and says so if
## it cannot. See the note at the top: the import will not carry this, so every looping
## sound in here goes through this function.
func _loop_between(wav: AudioStreamWAV, head: float, tail: float) -> void:
	if wav == null:
		return
	var rate: float = maxf(float(wav.mix_rate), 1.0)
	var length: float = wav.get_length()
	var a: float = clampf(head, 0.0, length * 0.45)
	var b: float = clampf(length - tail, a + 1.0, length)
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = int(a * rate)
	wav.loop_end = int(b * rate)


func _start_music() -> void:
	if not music_enabled:
		return
	var wav := _load(music_file, "the farm's music") as AudioStreamWAV
	if wav == null:
		return
	_loop_between(wav, music_trim_head, music_trim_tail)
	_music = AudioStreamPlayer.new()
	_music.name = "Music"
	_music.bus = MUSIC
	_music.stream = wav
	_music.volume_db = music_db
	add_child(_music)
	_music.play()


func _start_clucks() -> void:
	for path in [cluck_a_file, cluck_b_file]:
		var stream: AudioStream = _load(path, "a pickup cluck")
		if stream != null:
			_cluck_streams.append(stream)
	if _cluck_streams.is_empty():
		return
	_cluck = AudioStreamPlayer.new()
	_cluck.name = "Cluck"
	_cluck.bus = SFX
	add_child(_cluck)
	var catcher: Node = get_node_or_null(catcher_path)
	if catcher == null:
		push_warning("PenSfx: no catcher at catcher_path, so picking a chicken up is silent.")
		return
	# The catcher already announces a catch (chicken_catcher_4d.gd emits `caught` at the
	# end of _catch). Listening to that rather than editing the catcher keeps the sound out
	# of the gameplay code entirely: this node can be deleted and nothing breaks.
	catcher.connect("caught", _on_caught)


func _start_blips() -> void:
	var stream: AudioStream = _load(blip_file, "the pickup blip")
	if stream == null:
		return
	_blip = AudioStreamPlayer.new()
	_blip.name = "Blip"
	_blip.bus = SFX
	_blip.stream = stream
	_blip.volume_db = blip_db
	add_child(_blip)
	var belt: Node = get_node_or_null(inventory_path)
	if belt == null or not belt.has_signal("picked_up"):
		push_warning("PenSfx: no belt at inventory_path, so picking things up is silent.")
	else:
		belt.connect("picked_up", _on_picked_up)
	# The catcher is fetched a second time rather than kept from _start_clucks, so that
	# either of the two sounds can be deleted without taking the other with it.
	var catcher: Node = get_node_or_null(catcher_path)
	if catcher != null:
		catcher.connect("caught", func(_agent: Node) -> void: _play_blip())
	# And a trough going up, which is the one purchase in the game. Spending a nugget was
	# silent, which made an upgrade feel like a bug until you spotted the thing in the
	# grass.
	var upgrades: Node = get_node_or_null(upgrades_path)
	if upgrades != null and upgrades.has_signal("feeder_raised"):
		upgrades.connect("feeder_raised", func(_at: Vector4) -> void: _play_blip())


func _on_picked_up(_effect_name: String) -> void:
	_play_blip()


## Restarted from the top every time rather than allowed to ring on. Two pickups in quick
## succession should sound like two, and a 1.25 s tail over itself sounds like neither.
func _play_blip() -> void:
	if _blip == null:
		return
	_blip.stop()
	_blip.play()


func _start_cats() -> void:
	_meow = _load(cat_meow_file, "the cat's meow")
	_angry = _load(cat_angry_file, "the cat's scratch")
	if _meow == null and _angry == null:
		return
	_cat = AudioStreamPlayer.new()
	_cat.name = "Cat"
	_cat.bus = SFX
	add_child(_cat)
	# pen_cat_grab_4d.gd gained two signals for this, the same way the chicken catcher
	# already had one. The alternative was watching its `holding` flag for a falling edge,
	# which cannot tell a scratch from a throw - both let go of the cat.
	for path in cat_grab_paths:
		var grab: Node = get_node_or_null(path)
		if grab == null:
			push_warning("PenSfx: no cat grab at %s, so that cat is silent." % path)
			continue
		grab.connect("grabbed", _on_cat_grabbed)
		grab.connect("scratched", _on_cat_scratched)


func _start_stone() -> void:
	var stream: AudioStream = _load(stone_file, "the stone breaking")
	if stream == null:
		return
	_stone_streams.append(stream)
	var take_b: AudioStream = _load(stone_b_file, "the second stone take")
	if take_b != null:
		_stone_streams.append(take_b)
	_stone = AudioStreamPlayer.new()
	_stone.name = "Stone"
	_stone.bus = SFX
	_stone.stream = stream
	_stone.volume_db = stone_db
	add_child(_stone)
	var pickaxe: Node = get_node_or_null(pickaxe_path)
	if pickaxe == null:
		push_warning("PenSfx: no pickaxe at pickaxe_path, so mining the rock is silent.")
		return
	pickaxe.connect("mined", _on_mined)


## The pick has just taken a bite. Where it landed and how wide the bite was are no use
## here - there is no positional audio to spend them on - so both are ignored and only the
## fact of the hit is played.
func _on_mined(_at: Vector4, _radius: float) -> void:
	if _stone == null or _stone_streams.is_empty():
		return
	var second: bool = _next_stone == 1
	_stone.stream = _stone_streams[_next_stone]
	_stone.pitch_scale = 1.0 + _rng.randf_range(-stone_pitch_jitter, stone_pitch_jitter)
	_stone.volume_db = stone_db + (stone_b_trim if second else 0.0)
	_stone.play()
	# Take B carries two more impacts after the one we want. The stop is scheduled in
	# WALL TIME rather than by watching the playback position, because pitch_scale moves
	# that position faster or slower than the clock and the cut would wander into the
	# second hit on a high roll.
	_stone_stop_in = (stone_b_first_hit_seconds / maxf(_stone.pitch_scale, 0.01)) if second else 0.0
	_next_stone = (_next_stone + 1) % _stone_streams.size()


func _start_door() -> void:
	var stream: AudioStream = _load(door_file, "the door")
	if stream == null:
		return
	_arch = get_node_or_null(door_path)
	if _arch == null:
		push_warning("PenSfx: no arch at door_path, so Trym's door is silent.")
		return
	_door = AudioStreamPlayer.new()
	_door.name = "Door"
	_door.bus = SFX
	_door.stream = stream
	_door.volume_db = door_db
	add_child(_door)
	# Seeded from wherever the door already is, so the state it starts in is not heard as
	# an event. It starts down, but reading it is free and a scene that starts with the
	# door up should not open with a bang either.
	_arch_was = bool(_arch.get("armed"))


func _start_cinema() -> void:
	var stream: AudioStream = _load(cinema_file, "the cinema music")
	if stream == null:
		return
	_crossing = get_node_or_null(crossing_path)
	if _crossing == null or not _crossing.has_method("is_away"):
		push_warning("PenSfx: no crossing at crossing_path, so arriving at the theatre is silent.")
		return
	_cinema = AudioStreamPlayer.new()
	_cinema.name = "Cinema"
	_cinema.bus = MUSIC
	_cinema.stream = stream
	_cinema.volume_db = cinema_db
	add_child(_cinema)
	var bed := _load(cinema_bed_file, "the cinema's music") as AudioStreamWAV
	if bed == null:
		return
	_loop_between(bed, cinema_bed_trim_head, cinema_bed_trim_tail)
	_cinema_bed = AudioStreamPlayer.new()
	_cinema_bed.name = "CinemaBed"
	_cinema_bed.bus = MUSIC
	_cinema_bed.stream = bed
	_cinema_bed.volume_db = cinema_bed_db
	add_child(_cinema_bed)


func _start_finish() -> void:
	var game: Node = get_node_or_null(game_path)
	if game == null or not game.has_signal("completed"):
		push_warning("PenSfx: no game with a `completed` signal, so filling the pen is silent.")
		return
	var cheer: AudioStream = _load(cheer_file, "the cheering")
	if cheer != null:
		_cheer = AudioStreamPlayer.new()
		_cheer.name = "Cheer"
		_cheer.stream = cheer
		_cheer.volume_db = cheer_db
		_cheer.bus = SFX
		add_child(_cheer)
	var strum: AudioStream = _load(strum_file, "the strumming ident")
	if strum != null:
		_strum = AudioStreamPlayer.new()
		_strum.name = "Strum"
		_strum.stream = strum
		_strum.volume_db = strum_db
		_strum.bus = SFX
		add_child(_strum)
	game.connect("completed", _on_completed)


func _on_completed() -> void:
	if _strum != null:
		_strum.play()
	if _cheer != null:
		_cheer.play()


func _start_crows() -> void:
	if not crows_enabled:
		return
	var stream: AudioStream = _load(crow_file, "the crows")
	if stream == null:
		return
	_crow_length = stream.get_length()
	_crow = AudioStreamPlayer.new()
	_crow.name = "Crow"
	_crow.bus = AMBIENCE
	_crow.stream = stream
	_crow.volume_db = -80.0
	add_child(_crow)
	# The first lot does not arrive on frame one - crows over the opening of the scene are
	# a sting, and this is meant to be weather.
	_crow_wait = _rng.randf_range(crow_gap_min, crow_gap_max)


func _process(delta: float) -> void:
	if _stone_stop_in > 0.0:
		_stone_stop_in -= delta
		if _stone_stop_in <= 0.0:
			# Landing in the silence between the hits, so there is nothing to fade.
			_stone.stop()
	if _arch != null:
		var up: bool = bool(_arch.get("armed"))
		if up != _arch_was:
			# The same sound both ways. It is the same door doing the same thing in
			# reverse, and a second recording for the way down would be two sounds where
			# the player only ever hears one at a time.
			_door.play()
			_arch_was = up
	if _crossing != null:
		var away: bool = bool(_crossing.call("is_away"))
		if away != _inside:
			_inside = away
			_crossed(away)
	if _crow == null:
		return
	if _crow_left > 0.0 and not _inside:
		_crow_left -= delta
		var window: float = minf(crow_event_seconds, _crow_length)
		var done: float = window - _crow_left
		# Linear in AMPLITUDE, not in decibels. A straight line from -80 dB spends most of
		# its length inaudible and then arrives all at once; a straight line in amplitude,
		# converted at the end, is the fade you expect to hear.
		var gain: float = 1.0
		if _crow_fade > 0.0:
			gain = minf(done / _crow_fade, minf(_crow_left / _crow_fade, 1.0))
		_crow.volume_db = crow_db + linear_to_db(clampf(gain, 0.0001, 1.0))
		if _crow_left <= 0.0:
			_crow.stop()
			_crow_wait = _rng.randf_range(crow_gap_min, crow_gap_max)
		return
	# The clock only runs outdoors. Stopping the player alone would leave the timer to
	# expire in the theatre and fire the moment you stepped back out, which is a crow
	# waiting behind the door rather than weather.
	if _inside:
		return
	_crow_wait -= delta
	if _crow_wait <= 0.0:
		_start_crow_event()


func _start_crow_event() -> void:
	emit_signal("crows_rising")
	var window: float = minf(crow_event_seconds, _crow_length)
	_crow_left = window
	# Half the event each way at most, so the swell always reaches its top before it turns.
	_crow_fade = minf(crow_fade_seconds, window * 0.5)
	var from: float = 0.0
	if crow_vary_start and _crow_length > window:
		from = _rng.randf_range(0.0, _crow_length - window)
	_crow.volume_db = -80.0
	_crow.play(from)


## A chicken has just been picked up. The catcher passes the agent; which bird it was makes
## no difference to the sound, because there is nowhere to play it from.
## Through the door, or back out of it.
##
## THIS NODE HAS TO SURVIVE THE CROSSING TO DO ANY OF IT. pen_crossing_4d disables the
## whole of `Systems` on the way in - that is how the farm is switched off rather than
## unloaded - and Systems/Sfx is inside it. So the node is set to PROCESS_MODE_ALWAYS in
## the scene, which is resolved per-node and does not inherit an ancestor's DISABLED.
## Without it the music never starts, the farm bed goes on playing over the presentation,
## and the crow's fade freezes mid-swell. It is one property, and it is load-bearing.
func _crossed(away: bool) -> void:
	if away:
		if farm_stops_inside:
			if _bed != null:
				_bed.stop()
			if _music != null:
				_music.stop()
		# AND THE CROWS STAY OUTSIDE. The node survives the crossing on purpose - it is set
		# to PROCESS_MODE_ALWAYS so the music can start at all - but "survives" applies to
		# the whole node, so the crow scheduler went on ticking and a murder of crows would
		# swell up over the presentation at -14 dB, louder than the music the presenter is
		# talking over. One already in flight kept fading in as the player walked through
		# the door. The theatre is a room hanging in nothing; there is no sky in it.
		if _crow != null:
			_crow.stop()
		_crow_left = 0.0
		if _cinema_bed != null:
			_cinema_bed.play()
		# The arrival, over the top of the music starting, and only ever once.
		if not _been_to_the_cinema and _cinema != null:
			_been_to_the_cinema = true
			_cinema.play()
		return
	if _cinema_bed != null:
		_cinema_bed.stop()
	if _cinema != null:
		_cinema.stop()
	if _bed != null and not _bed.playing:
		# Back in from the loop points rather than from the top, so coming home does not
		# start with the recording's quiet opening.
		_bed.play(ambience_loop_trim)
	if _music != null and not _music.playing:
		_music.play(music_trim_head)


func _on_caught(_agent: Node) -> void:
	if _cluck == null or _cluck_streams.is_empty():
		return
	_cluck.stream = _cluck_streams[_next_cluck]
	_cluck.volume_db = cluck_db + (cluck_b_trim if _next_cluck == 1 else 0.0)
	_cluck.play()
	_next_cluck = (_next_cluck + 1) % _cluck_streams.size()


func _on_cat_grabbed() -> void:
	_play_cat(_meow, cat_meow_db)


func _on_cat_scratched() -> void:
	# Straight over the top of the meow if one is still going: the whole point of the
	# scratch is that it interrupts.
	_play_cat(_angry, cat_angry_db)


func _play_cat(stream: AudioStream, db: float) -> void:
	if _cat == null or stream == null:
		return
	_cat.stream = stream
	_cat.volume_db = db
	_cat.play()


## Loads a sound and says which one is missing rather than failing silently - the one
## failure mode of an audio system nobody notices until they go looking for it (item 82).
func _load(path: String, what: String) -> AudioStream:
	if path.is_empty():
		return null
	if not ResourceLoader.exists(path):
		push_warning("PenSfx: %s is missing at %s - that sound will not play." % [what, path])
		return null
	return load(path) as AudioStream
