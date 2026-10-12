extends Node

## BOTANY LAB, plan steps 27-31 (Ramon, 9 Oct: "Replace outdated booth-style or fixed information elements
## with floating panels ... Preserve existing useful information while improving its presentation ...
## use a simple interaction such as More Information ... The main display should remain concise, with
## more detailed information available on demand"): what a pedestal's floating panel says. The panel
## (carried/voxel_lab/float_panel_4d.gd, the Aquatic Lab's) asks its source for face() and
## panel_pages(); this answers from the exhibit's own card (the words the booth consoles' card showed),
## so nothing of what they said is lost:
##   THE FACE   three numbers: tetrahedra, how it was built, and whether it is the bake or grown live
##   E          METHOD, WHAT IT SHOWS, LIMITS, MEASURED (the card's rows), then back to the face
## With `tour` on it is the showcase pad's panel instead: what the tour is; E plays it (the room's).
##
## NO class_name (engine_gotchas.md).

## The pedestal it is about (a carried showcase), from this node.
@export var station: NodePath
## The showcase pad's panel (no pages: E plays the tour).
@export var tour: bool = false


func _exhibit() -> Node:
	var s: Node = get_node_or_null(station) if not station.is_empty() else null
	return s.get("exhibit") if s != null else null


func _card() -> Dictionary:
	var ex: Node = _exhibit()
	return ex.call("card") if ex != null and ex.has_method("card") else {}


## The summary's three rows.
func face() -> Array:
	if tour:
		return [["Pedestals", "Four, one after another"], ["Takes", "About a minute"], ["Leave", "Esc, any time"]]
	var c: Dictionary = _card()
	var out: Array = []
	for r in c.get("rows", []):
		var label: String = String(r[0])
		if label == "Tetrahedra" or label.begins_with("Built") or label == "Wood" or label == "Leaves":
			out.append(r)
		if out.size() == 2:
			break
	var tier: String = String(c.get("tier", ""))
	if not tier.is_empty():
		out.append(["As you see it", tier.capitalize() if tier.length() < 18 else tier.get_slice(",", 0).capitalize()])
	return out


## The pages behind E.
func panel_pages() -> Array:
	if tour:
		return []
	var c: Dictionary = _card()
	if c.is_empty():
		return []
	var code: String = String(c.get("code", ""))
	return [
		{"title": "Method", "kicker": code + "  ·  HOW IT IS BUILT", "text": String(c.get("method", ""))},
		{"title": "What it shows", "kicker": code + "  ·  WHY IT IS HERE", "text": String(c.get("shows", ""))},
		{"title": "Limits", "kicker": code + "  ·  WHAT IT CANNOT DO", "text": String(c.get("limits", ""))},
		{"title": "Measured", "kicker": code + "  ·  ON THIS MACHINE", "rows": c.get("rows", [])},
	]
