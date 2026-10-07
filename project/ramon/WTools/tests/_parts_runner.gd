extends SceneTree

## THE OPTIMISER'S PARTS, ONE BY ONE: for each unit, every drawn part as the W Optimiser reads it (its
## path, class, world size, where it sits in W, whether it would be deepened), and every solid box collider
## (its W middle and depth). For checking the analysis against a unit by eye.
##
##   lab_run.sh headless wt_parts res://ramon/WTools/tests/_parts_runner.gd [watchstone camp range]

const OPT := preload("res://ramon/WTools/optimiser/w_optimiser_4d.gd")
const UNITS := {
	"watchstone": "res://ramon/chickenpen/units/watchstone/watchstone.tscn",
	"camp": "res://ramon/chickenpen/units/camp/camp.tscn",
	"range": "res://ramon/chickenpen/units/rune_range/rune_range.tscn",
	"cabin": "res://ramon/chickenpen/units/trym_cabin/trym_cabin.tscn",
	"lookout": "res://ramon/chickenpen/units/lookout/lookout.tscn",
}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var want: PackedStringArray = OS.get_cmdline_user_args()
	var names: Array = UNITS.keys() if want.is_empty() else Array(want)
	for u in names:
		var unit: Node4D = (load(UNITS[u]) as PackedScene).instantiate()
		root.add_child(unit)
		for i in 6:
			await process_frame
		var opt := Node4D.new()
		opt.set_script(OPT)
		opt.set("enabled", false)
		root.add_child(opt)
		opt.set("target", opt.get_path_to(unit))
		opt.set("min_w_half", 6.0)
		opt.call("analyse")
		print("PARTS %s\n%s" % [u, String(opt.get("report"))])
		for p in opt.get("parts"):
			var n: Node = p["node"]
			var box: Array = OPT._world_box([n])
			print("  %-44s %-7s size %5.1f %5.1f %5.1f  W %+6.2f..%+6.2f  %s" % [String(unit.get_path_to(n)).left(44), p["class"],
				p["size"].x, p["size"].y, p["size"].z, box[0].w, box[1].w, "deepen" if p["deepen"] else ""])
		for cs in unit.find_children("*", "CollisionShape4D", true, false):
			var box := (cs as CollisionShape4D).shape as BoxShape4D
			if box == null:
				continue
			var hw: float = box.size.w * 0.5 * Vector4((cs as Node4D).global_basis.w).length()
			var w: float = (cs as Node4D).global_position.w
			print("  collider %-35s %-12s W %+6.2f..%+6.2f  size %.1f %.1f %.1f" % [String(unit.get_path_to(cs)).left(35), cs.get_parent().get_class(),
				w - hw, w + hw, box.size.x, box.size.y, box.size.z])
		opt.free()
		unit.queue_free()
		await process_frame
	quit(0)
