extends SceneTree

## Is the flock audible: the buses, their sends and mutes, and the live peak on each, after
## a few seconds in the pen. Windowed, so the audio driver is a real one.
##
##   godot... --path project --windowed --resolution 640x360 --position 40,40
##       --script res://ramon/chickenpen/scripts/_probe_flock_sound_runner.gd [-- film=1]

var _room: Node
var _f: int = 0


func _initialize() -> void:
	root.unfocusable = true
	_room = load("res://ramon/chickenpen/playable_world.tscn").instantiate()
	root.add_child(_room)
	current_scene = _room
	print("   at _initialize: Flock bus index %d, Sound ready %s" % [AudioServer.get_bus_index(&"Flock"),
		str(_room.get_node("World/Flock/Sound").is_node_ready())])


func _process(_d: float) -> bool:
	_f += 1
	if _f == 240 or _f == 241:
		for b in AudioServer.bus_count:
			print("   bus %d %-9s send %-9s mute %-5s  peak L %.1f dB  effects %d" % [b, AudioServer.get_bus_name(b), AudioServer.get_bus_send(b),
				str(AudioServer.is_bus_mute(b)), AudioServer.get_bus_peak_volume_left_db(b, 0), AudioServer.get_bus_effect_count(b)])
		print("   mix %s" % str(_room.get_node("World/Flock/Sound").call("mix")))
		var player: AudioStreamPlayer = _room.get_node("World/Flock/Sound").get_child(0)
		print("   rush player: stream %s length %.2f s  loop %d  playing %s  paused %s  pos %.2f" % [str(player.stream), player.stream.get_length(),
			(player.stream as AudioStreamWAV).loop_mode, str(player.playing), str(player.stream_paused), player.get_playback_position()])
	if _f >= 242:
		quit()
		return true
	return false
