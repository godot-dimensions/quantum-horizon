extends "res://ramon/Arboretum/room/arb_panel_source.gd"

## BOTANY LAB, round 2 (section 8, steps 27-31): the research wall's data for its "algorithm" layout
## (carried/kit/panels/kit_panel_research.gd): the Arboretum's own (room/arb_panel_source.gd) with the
## diagram's heading, a line a method on how its tree was grown, the foliage column as the fork has it
## (the loft carries no leaves since round 1, the smooth voxels leaf masses), and the credit.
##
## THE CREDIT IS VERIFIED, NOT GUESSED (Ramon: "Don't guess at the attribution"): pedestals 01 to 03 grow
## by `carried/shrubbery/shrub_generator.gd`, whose header and Trym's commit 3671323 (23 Aug 2026: "Ports
## TanTanDev/shrubbery's space-colonization branch-growth algorithm to 4D") name TanTanDev's shrubbery,
## github.com/TanTanDev/shrubbery. The oak grows by `botany/colonize_4d.gd`, our 4D version of Runions,
## Lane and Prusinkiewicz, "Modeling Trees with a Space Colonization Algorithm" (2007), as its header
## says.
##
## NO class_name (engine_gotchas.md).

const GROWN := {
	"voxel": "Grown by shrubbery's rules; every cell a branch passes through is filled.",
	"dc": "The same skeleton, one smooth surface run through it.",
	"loft": "The same skeleton, lofted branch by branch.",
	"oak": "Its own growth: each point pulls only its nearest bud.",
}
const FOLIAGE_HERE := {"voxel": "leaf cells", "dc": "leaf masses", "loft": "none: the branches", "oak": "GPU leaves"}
const CREDIT := "Pedestals 01 to 03 grow by TanTanDev's shrubbery (github.com/TanTanDev/shrubbery), ported to 4D by Trym. The oak: space colonization after Runions, Lane and Prusinkiewicz (2007)."


func research(info: Resource) -> Dictionary:
	var out: Dictionary = super.research(info)
	out["algorithm"] = {"label": "HOW THE TREES GROW", "headline": "Branches grow toward points\nscattered through the crown."}
	var stations: Array = _stations()
	var cols: Array = out.get("methods", [])
	var rows: Array = (out.get("table", {}) as Dictionary).get("rows", [])
	var r: int = 0
	for i in mini(stations.size(), cols.size()):
		var ex: Node = stations[i].get("exhibit") if stations[i] != null else null
		if ex == null:
			continue
		var key: String = String(ex.get("method"))
		(cols[i] as Dictionary)["grown"] = String(GROWN.get(key, ""))
		if r < rows.size():
			(rows[r] as Array)[6] = String(FOLIAGE_HERE.get(key, (rows[r] as Array)[6]))
		r += 1
	out["footnote"] = CREDIT
	# (The footnote's measuring note moves up into the table's heading.)
	if out.has("table"):
		out["table"]["heading"] = "BENCHMARK  every tree here, measured on %s" % RenderingServer.get_video_adapter_name()
	return out
