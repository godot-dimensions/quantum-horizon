extends Node

## The water's wall panels' live data (the carried kit's panels ask a source for it: fill() for the
## introduction's words, research() for the research panel). Everything here is read from the sea
## itself, so the panel says what the water is doing now: the sea running, its waves, how far your
## slice is turned.
##
## The research panel is the kit's "steps" layout: three columns in the order the sea is made (the
## waves, the slice solve, the foam), and under them a table of the eight seas, the one running lit.
##
## NO class_name (engine_gotchas.md).

const Presets := preload("res://ramon/WaterLab/carried/water4d/water4d_presets.gd")

## The scene's root (seascape_4d.gd), for the sea and the slice.
@export var room_path: NodePath = ^".."


func _room() -> Node:
	return get_node_or_null(room_path)


func _water() -> Node:
	var r: Node = _room()
	return r.get_node_or_null("Water") if r != null else null


func fill(text: String) -> String:
	var w: Node = _water()
	var name: String = "Moderate swell"
	if w != null:
		name = Presets.preset_name(int(w.get("preset_index")))
	return text.replace("{preset}", name)


func research(info: Resource) -> Dictionary:
	var w: Node = _water()
	var r: Node = _room()
	var index: int = int(w.get("preset_index")) if w != null else 1
	var scale: float = float(w.get("wave_scale")) if w != null else 1.0
	var iterations: int = int(w.get("solve_iterations")) if w != null else 2
	var turn: Vector2 = r.call("slice_degrees") if r != null and r.has_method("slice_degrees") else Vector2.ZERO
	var waves: Array = Presets._preset(index)
	var live: int = 0
	var biggest: float = 0.0
	for wave in waves:
		if float(wave.amplitude) > 0.0001:
			live += 1
			biggest = maxf(biggest, float(wave.amplitude))
	var rows: Array = []
	var seas: Array = r.call("seas") if r != null and r.has_method("seas") else range(Presets.count())
	for k in seas.size():
		var i: int = int(seas[k])
		var ws: Array = Presets._preset(i)
		var n: int = 0
		var amp: float = 0.0
		var length: float = 0.0
		var off: float = 0.0
		for wave in ws:
			if float(wave.amplitude) <= 0.0001:
				continue
			n += 1
			if float(wave.amplitude) > amp:
				amp = float(wave.amplitude)
				length = float(wave.wavelength)
				off = absf((wave.dir as Vector3).z)
		rows.append(["%d  %s" % [k + 1, Presets.preset_name(i)], str(n), "%.1f m" % (amp * scale), "%.0f m" % (length * scale), "%.0f%%" % (off * 100.0)])
	var turned: float = Vector2(turn.x, turn.y).length()
	return {
		"header_left": String(info.call("research_header")) if info != null else "RESEARCH",
		"header_right": String(info.get("research_status")) if info != null else "",
		"steps": [
			{"title": "Waves through W.", "text": "Each sea is a few Gerstner waves added up. Each wave runs in x, z and W, so some arrive from a direction your slice cannot see.",
				"value": str(live), "value_text": "waves in %s" % Presets.preset_name(index)},
			{"title": "Solved for your slice.", "text": "Water moves sideways in a wave, through W too. For each point it draws, the shader works out which water lands there.",
				"value": "%d" % iterations if iterations > 0 else "off", "value_text": "passes of the solve a frame", "accent": true},
			{"title": "Turn it.", "text": "On the platform a right drag turns your slice. The same sea is cut a new way, and its waves change while the platform stays set.",
				"value": "%.0f°" % turned, "value_text": "your slice is turned now"},
		],
		"table": {"heading": "THE SEAS  keys 1 to 4, the one running lit",
			"heads": ["SEA", "WAVES", "BIGGEST", "WAVELENGTH", "THROUGH W"],
			"rows": rows, "current": seas.find(index)},
		"footnote": "Trym's 4D water, from his water-annex branch. Wave heights at this scene's wave scale (%.1f)." % scale,
	}
