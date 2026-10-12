extends RefCounted

## One experiment: a way of playing the range, in four stages after Nintendo's four steps (kishotenketsu:
## introduce the idea in safety, develop it, twist it, then a finish that brings it together;
## follow_up/quantum_range_final.md section 6). The director (range_director_4d.gd) runs it: it calls
## begin(i) as stage i starts (spawn its targets through `d`), tick(i, dt) every frame until it answers
## "done" (or "fail"), and reads progress(i) for the HUD's bar.
##
## Experiments extend this and fill in the words and the four stages. Everything they spawn goes through
## d.spawn(), so the director can clear it, count it and show it on the radar.
##
## NO class_name (engine_gotchas.md): preload it.

const Layout := preload("res://ramon/QuantumRange/scripts/range_layout.gd")

## The director that runs it (set before begin()).
var d: Node
var id: String = ""
var number: int = 0
var title: String = ""
## One word, for where the full title does not fit (the metrics wall's specimen name and its rows).
var short: String = ""
## One line under the title: what you do.
var tagline: String = ""
## The metrics wall's page for it: a claim in two lines, and two lines of what it shows.
var headline: String = ""
var explain: String = ""
## How much it asks of W: LOW, MEDIUM, HIGH, HIGHEST.
var w_load: String = ""
## The metrics wall's illustration (carried/kit/kit_glyphs.gd animal()).
var glyph: String = ""
## [{"title": "", "line": "", "par": seconds}, ...], four of them.
var stages: Array = []
## Strict mode can apply (Incoming).
var has_strict: bool = false


func stage_count() -> int:
	return stages.size()


func begin(_i: int) -> void:
	pass


## "run", "done" or "fail" (strict mode, or a stage's own rule).
func tick(_i: int, _dt: float) -> String:
	return "done" if d.alive_count() == 0 else "run"


## How far through stage i: Vector2(done, of).
func progress(_i: int) -> Vector2:
	return Vector2.ZERO


## A fail's reason for the HUD (strict mode).
func fail_reason() -> String:
	return ""


## Keys this experiment adds to the HUD's list while it plays: [[key, what], ...].
func keys() -> Array:
	return []


## How much nearer than written every experiment's distances are: the stages were written at 10 to 30 m,
## where through an 80 degree view between the two wings the targets read too small to see how they are
## built (frames moments/, 5 Oct); one number brings everything in together.
const NEARER := 0.82


## A point downrange in front of the firing position: `x` across, `y` up, `dist` metres out (times NEARER),
## `w` through W.
static func ahead(x: float, y: float, dist: float, w: float = 0.0) -> Vector4:
	return Vector4(x, y, Layout.STAND.z - dist * NEARER, w)
