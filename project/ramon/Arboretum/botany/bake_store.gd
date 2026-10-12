extends RefCounted

## The Arboretum's baked trees: where they are kept, the bake's record, and the number formats the
## cards and panels share. The bake (scripts/_bake_runner.gd) writes every pedestal tree, its story
## stages and the grove's lighter trees into Arboretum/baked/, and its own measurements into
## baked/bake.cfg: what each took to build, how many tetrahedra, on which machine and when. The room
## loads them as they are, and says so ("PRE-BAKED") wherever it shows their numbers.
##
## NO class_name (engine_gotchas.md): preload it.

const DIR := "res://ramon/Arboretum/baked/"
const RECORD := "res://ramon/Arboretum/baked/bake.cfg"


static func path(name: String) -> String:
	return DIR + name + (".tres" if name.ends_with("_skeleton") else ".res")


static func has(name: String) -> bool:
	return ResourceLoader.exists(path(name))


static func load_res(name: String) -> Resource:
	var p: String = path(name)
	return load(p) if ResourceLoader.exists(p) else null


static func save_res(r: Resource, name: String) -> int:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	return ResourceSaver.save(r, path(name))


## The bake's record for `section` ("voxel", "dc", "loft", "oak", "grove_*"): a Dictionary.
static func record(section: String) -> Dictionary:
	var cf := ConfigFile.new()
	if cf.load(RECORD) != OK or not cf.has_section(section):
		return {}
	var out: Dictionary = {}
	for k in cf.get_section_keys(section):
		out[k] = cf.get_value(section, k)
	return out


static func write_record(section: String, values: Dictionary) -> void:
	var cf := ConfigFile.new()
	cf.load(RECORD)
	for k in values:
		cf.set_value(section, String(k), values[k])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	cf.save(RECORD)


static func ms(v: float) -> String:
	if v <= 0.0:
		return "-"
	if v < 0.1:
		return "%.3f ms" % v
	if v < 10.0:
		return "%.2f ms" % v
	if v < 1000.0:
		return "%.0f ms" % v
	return "%.1f s" % (v / 1000.0)


static func thousands(n: int) -> String:
	var s: String = str(absi(n))
	var out: String = ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


## 148,330 -> "148K", 2,100,000 -> "2.1M".
static func short(n: int) -> String:
	if n >= 1000000:
		return "%.1fM" % (float(n) / 1000000.0)
	if n >= 10000:
		return "%dK" % int(round(float(n) / 1000.0))
	if n >= 1000:
		return "%.1fK" % (float(n) / 1000.0)
	return str(n)


## Video memory a mesh of `tets` tetrahedra holds, MB (the engine's proxy: about 1.25 KB each,
## follow_up/engine_gotchas.md).
static func mb(tets: int) -> float:
	return float(tets) * 1.25 / 1024.0
