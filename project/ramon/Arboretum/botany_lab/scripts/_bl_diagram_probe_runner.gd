extends SceneTree

## BOTANY LAB, round 2: the research wall's growth diagram on its own (room/bl_growth_diagram.gd), headless:
## grown once, timed, its counts printed. Run before the hall after any change to it (its first version
## never ended its trunk loop and took the PC down, 9 Oct).

const Growth := preload("res://ramon/Arboretum/botany_lab/room/bl_growth_diagram.gd")


func _initialize() -> void:
	var t0: int = Time.get_ticks_usec()
	var g: Control = Growth.new("Probe", 1.0)
	var ms: float = (Time.get_ticks_usec() - t0) / 1000.0
	var br: Array = g.get("_br")
	var pts: Array = g.get("_pts")
	var used: int = 0
	for p in pts:
		if int(p["used"]) >= 0:
			used += 1
	var top := 0.0
	for b in br:
		top = maxf(top, (b["p"] as Vector2).y)
	print("DIAGRAM grown in %.0f ms: %d branches, %d steps, %d of %d points used, %d tips, %d cells, top %.2f m, memory %.1f MB" % [ms, br.size(),
		int(g.get("_steps")), used, pts.size(), (g.get("_tips") as Array).size(), (g.get("_cells") as Array).size(), top,
		OS.get_static_memory_usage() / 1048576.0])
	g.free()
	quit()
