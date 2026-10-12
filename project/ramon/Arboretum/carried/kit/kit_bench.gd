extends RefCounted

## Kit: the room's benchmark book. Every specimen's measured numbers, kept per machine in
## user://creation_lab_bench.cfg under its code (GT-01, CK-02, ...), so the research wall can set
## them side by side and an expensive measurement (a full loft) is taken once, not every visit.
##
## Keys an exhibit writes: name, icon, balls, tetra, build_ms (lofting the whole animal from its
## balls), limb_ms (lofting one leg), limbs, pieces, measured (the date). The wall adds anim_ms
## (the walk's own cost a frame, averaged while it walks).
##
## NO class_name (engine_gotchas.md).

const PATH := "user://creation_lab_bench.cfg"


static func read(code: String) -> Dictionary:
	var cfg := ConfigFile.new()
	var out: Dictionary = {}
	if cfg.load(PATH) != OK or not cfg.has_section(code):
		return out
	for k in cfg.get_section_keys(code):
		out[k] = cfg.get_value(code, k)
	return out


static func write(code: String, values: Dictionary) -> void:
	if code.is_empty():
		return
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	for k in values:
		cfg.set_value(code, String(k), values[k])
	cfg.save(PATH)


## Every specimen measured so far, code -> its numbers.
static func all() -> Dictionary:
	var cfg := ConfigFile.new()
	var out: Dictionary = {}
	if cfg.load(PATH) != OK:
		return out
	for code in cfg.get_sections():
		var rec: Dictionary = {}
		for k in cfg.get_section_keys(code):
			rec[k] = cfg.get_value(code, k)
		out[code] = rec
	return out


## Milliseconds since `from_usec` (Time.get_ticks_usec()).
static func ms_since(from_usec: int) -> float:
	return float(Time.get_ticks_usec() - from_usec) / 1000.0
