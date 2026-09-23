extends SceneTree

## Does picking something up make a noise?
##
## This is a wiring test and it is honest about that. It cannot hear anything - the dummy
## audio driver produces no sound - so it checks the four things that were actually wrong
## or absent, all of which are structural: the clip loads, the player exists on the right
## bus, the belt's signal reaches it, and a catch reaches it too.
##
## WHY A CATCH IS IN A TEST ABOUT THE BELT. A caught chicken never touches the belt, so it
## would not be covered by the `picked_up` route. It had its own cluck all along and Ramon
## still could not hear it, because the cluck is a farm recording under ninety seconds of
## farm recording. Both now go through the same blip, and if somebody later unhooks one of
## the two connections, this says which.

var _root: Node
var _f := 0
var _fails: Array = []


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/chickenpen.tscn").instantiate()
	root.add_child(_root)
	current_scene = _root


func _check(label: String, ok: bool, detail: String) -> void:
	print("   %s %-44s %s" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_fails.append(label)


func _process(_d) -> bool:
	_f += 1
	if _f < 30:
		return false
	var sfx: Node = _root.get_node_or_null("Systems/Sfx")
	var belt: Node = _root.get_node_or_null("UI/Inventory")
	var catcher: Node = _root.get_node_or_null("Player/Catcher")
	if sfx == null or belt == null or catcher == null:
		_check("the pieces are in the scene", false, "Sfx / Inventory / Catcher")
		return _finish()

	print("\n--- the pickup sound ---")
	var blip: AudioStreamPlayer = sfx.get_node_or_null("Blip") as AudioStreamPlayer
	_check("the clip loaded", blip != null and blip.stream != null,
		String(sfx.get("blip_file")).get_file())
	if blip != null:
		_check("on the effects bus, at the confirm level", blip.bus == &"SFX"
			and blip.volume_db < 0.0, "%s, %.1f dB" % [blip.bus, blip.volume_db])
	_check("the belt announces what it takes", belt.has_signal("picked_up"),
		"signal picked_up(effect_name)")
	_check("and the sound is listening", belt.is_connected("picked_up", Callable(sfx, "_on_picked_up")),
		"UI/Inventory -> Systems/Sfx")
	_check("catching a chicken reaches it too",
		catcher.get_signal_connection_list("caught").size() >= 2,
		"%d listeners on `caught`: the cluck, and the blip under it"
			% catcher.get_signal_connection_list("caught").size())

	# The belt is stocked with a pickaxe at load. That is not a pickup and must not blip,
	# or the level opens with a noise nobody caused.
	var heard: Array = []
	belt.connect("picked_up", func(name_: String) -> void: heard.append(name_))
	_check("the starting pickaxe did not announce itself", heard.is_empty(),
		"silent through %d frames of loading" % _f)
	belt.call("add_item", "found_gold")
	_check("a real pickup does", heard == ["found_gold"], "%s" % [heard])
	belt.call("add_item", "found_gold")
	_check("and the same thing twice does not", heard.size() == 1,
		"add_item returns early on a duplicate, so no second sound")
	return _finish()


func _finish() -> bool:
	print("\n%d FAIL(s)" % _fails.size())
	quit(1 if _fails.size() > 0 else 0)
	return true
