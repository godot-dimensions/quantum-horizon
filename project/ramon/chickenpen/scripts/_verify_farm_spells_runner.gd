extends SceneTree

## The farm bed in spells (pen_sfx_4d.gd, ambience_spells): it plays at full volume for a
## while, fades out, is quiet for a while, fades back in. Time is run eight times fast and the
## bed's volume printed every two game seconds for about three minutes; checks it reached full
## volume, went silent, and came back. Gives up after 90 real seconds.
##
##   godot... --path project --windowed --resolution 640x360 --position 40,40 --audio-driver Dummy
##       --script res://ramon/chickenpen/scripts/_verify_farm_spells_runner.gd

var _room: Node
var _sfx: Node
var _t: float = 0.0
var _real: float = 0.0
var _next_print: float = 0.0
var _seen_full: bool = false
var _seen_quiet: bool = false
var _back: bool = false
var _line: String = ""


func _initialize() -> void:
	root.unfocusable = true
	_room = load("res://ramon/chickenpen/playable_world.tscn").instantiate()
	root.add_child(_room)
	current_scene = _room
	Engine.time_scale = 8.0


func _process(d: float) -> bool:
	_t += d
	_real += d / Engine.time_scale
	if _real > 90.0:
		print("FARM SPELLS FAIL: timed out")
		return true
	if _sfx == null:
		_sfx = _room.get_node_or_null("Systems/Sfx")
		return false
	var bed: AudioStreamPlayer = _sfx.get("_bed")
	if bed == null:
		return false
	var db: float = bed.volume_db
	var full: float = float(_sfx.get("ambience_db"))
	if db > full - 0.5:
		_seen_full = true
	if db < full - 40.0 and _seen_full:
		_seen_quiet = true
	if _seen_quiet and db > full - 0.5:
		_back = true
	if _t >= _next_print:
		_next_print += 2.0
		_line += ("#" if db > full - 1.0 else ("+" if db > full - 30.0 else ".")) + ("" if bed.playing else "x")
	if _t > 180.0:
		print("      bed over 3 min, a mark every 2 s (# full, + fading, . quiet): ", _line)
		print("FARM SPELLS %s" % ("PASS" if _seen_full and _seen_quiet and _back else "FAIL (full %s, quiet %s, back %s)" % [_seen_full, _seen_quiet, _back]))
		Engine.time_scale = 1.0
		return true
	return false
