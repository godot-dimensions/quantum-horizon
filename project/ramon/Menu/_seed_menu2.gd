extends SceneTree
## One-off: fills the new Menu2 fields into the shared catalogue, and retunes
## menu2_style.tres.
##
## Written as a script rather than by hand-editing the .tres for the reason
## _bootstrap_catalogue.gd gives: letting ResourceSaver write the file means the
## format is correct by construction. Unlike that script this one is ADDITIVE -
## it loads what is there and sets only the new fields, so existing text, order
## and per-entry crops survive.
##
## KNOWN TRAP: ResourceSaver.save() over an existing .tres DROPS its `uid` from
## the header. Any scene that referenced it by uid then warns on load - "invalid
## UID ... using text path instead" - and silently falls back to the path, which
## still resolves but breaks the moment the file is moved. After running this,
## check the header still carries `uid="uid://..."` and put it back if not.
##
##   godot.windows.editor.double.x86_64.console.exe --headless --path project \
##       --script res://ramon/Menu/_seed_menu2.gd

const CATALOGUE_PATH := "res://ramon/Menu/entries/catalogue.tres"
const STYLE_PATH := "res://ramon/Menu/style/menu2_style.tres"

## Durations are ESTIMATES, not measurements - nobody has timed these. They are
## seeded so the field is populated and the layout can be judged; correct them in
## the inspector. Benchmarks, by contrast, are real figures lifted from the
## prototypes' own READMEs and follow-up notes.
const SEED := {
	"Slice Vision": {
		"duration": "90 sec",
		"detail": "Three chambers that teach reading a cross-section before asking anything of you.",
		"benchmark": "10 / 10 scripted checks pass · 3 levels · 90° turn eased over 0.7 s",
	},
	"Phase Maze": {
		"duration": "2 min",
		"detail": "A maze whose walls occupy bands of w, so the route exists only at the right slice.",
		"benchmark": "2 levels · walls 0.4 m thick in z · slice rotation on right mouse",
	},
	"4D Ascent": {
		"duration": "2 min",
		"detail": "A vertical course where the next foothold is often a rotation away rather than a jump.",
		"benchmark": "Gap 7 m vs 4.59 m jump reach - uncrossable until w changes",
	},
	"Portal": {
		"duration": "90 sec",
		"detail": "Linked openings carved into a wall, preserving momentum across the crossing.",
		"benchmark": "7.7 → 22.2 m/s over five crossings · 21 chunks rebuilt in ~1,093 ms",
	},
	"Quantum Range": {
		"duration": "2 min",
		"detail": "A range where targets can leave your slice entirely, so aiming is four-dimensional.",
		"benchmark": "True 4D raycasts against 4D colliders, independent of the camera",
	},
	"Voxel Mining": {
		"duration": "2 min",
		"detail": "A rock made of 4D voxels that you can carve into, re-meshed on every hit.",
		"benchmark": "~130 ms per carve at room scale · ~58 fps · 10,752 tetrahedra",
	},
	"Sky Box Clouds": {
		"duration": "60 sec",
		"detail": "Clouds built as 4D solids rather than a painted sky, so they reshape as you turn.",
		"benchmark": "Clumped polytope clouds on a 4D skydome · previews in-editor",
	},
	"Voxel Port": {
		"duration": "90 sec",
		"detail": "Streamed 4D terrain, contoured per slice, to see whether it scales past one room.",
		"benchmark": "Chunked streaming holds; total tetrahedra is the budget, not visible geometry",
	},
}


func _initialize() -> void:
	var catalogue: Resource = load(CATALOGUE_PATH)
	if catalogue == null:
		printerr("SEED: could not load ", CATALOGUE_PATH)
		quit(1)
		return

	var touched: int = 0
	for entry in catalogue.entries:
		if entry == null or not SEED.has(entry.title):
			continue
		var data: Dictionary = SEED[entry.title]
		entry.duration = data["duration"]
		entry.detail = data["detail"]
		entry.benchmark = data["benchmark"]
		touched += 1

	var err: int = ResourceSaver.save(catalogue, CATALOGUE_PATH)
	if err != OK:
		printerr("SEED: failed to save catalogue (%d)" % err)
		quit(1)
		return
	print("SEED: filled duration/detail/benchmark on %d entries" % touched)

	var style: Resource = load(STYLE_PATH)
	if style == null:
		printerr("SEED: could not load ", STYLE_PATH)
		quit(1)
		return
	# Greyer glyphs. The previous tint still sat high in the value range and the
	# icons read as brighter than the titles beside them, which inverts the
	# hierarchy - the title is what the row is for.
	style.thumbnail_tint = Color(0.56, 0.60, 0.66)
	# One point up on the info body, and a little more air between the blocks.
	style.info_body_nudge = 1
	style.detail_paragraph_gap = 2.8
	style.info_cell_h_gap = 2.4
	err = ResourceSaver.save(style, STYLE_PATH)
	if err != OK:
		printerr("SEED: failed to save style (%d)" % err)
		quit(1)
		return
	print("SEED: retuned ", STYLE_PATH)
	quit(0)
