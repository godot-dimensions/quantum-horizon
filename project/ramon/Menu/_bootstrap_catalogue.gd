extends SceneTree
## One-off: writes `style/default_style.tres` and `entries/catalogue.tres` from
## the list that used to be hardcoded in menu_mockup.gd.
##
## Exists because hand-authoring .tres is how you get subtly wrong files -
## missing UIDs, wrong load_steps, sub-resource ids that collide. Letting
## ResourceSaver write them means the format is correct by construction.
##
## NOT SAFE TO RE-RUN, AND IT NOW REFUSES TO.
##
## This writes the catalogue from the hardcoded SEED below, which is a snapshot
## of what the list looked like when the menu was first built. Everything added
## since - durations, detail lines, benchmark figures, per-entry crops, Motion
## Lab, Shrubbery Forest, and every edit made in the inspector - exists only in
## the .tres and is NOT in SEED. Running this over a populated catalogue would
## silently delete all of it.
##
## So it bails out if the catalogue already exists. Pass `overwrite` after `--`
## if you genuinely mean to throw the current one away.
##
##   godot.windows.editor.double.x86_64.console.exe --headless --path project \
##       --script res://ramon/Menu/_bootstrap_catalogue.gd
##
## To ADD to the catalogue rather than replace it, copy `_seed_menu2_entries.gd`
## instead - that one loads what is there and edits it.

const StyleScript := preload("res://ramon/Menu/scripts/menu_style.gd")
const EntryScript := preload("res://ramon/Menu/scripts/menu_entry.gd")
const CatalogueScript := preload("res://ramon/Menu/scripts/menu_catalogue.gd")

const FONT_PATH := "res://ramon/Demo/fonts/Montserrat/static/Montserrat-SemiBold.ttf"
const ICON_DIR := "res://ramon/Demo/textures/"
const STYLE_PATH := "res://ramon/Menu/style/default_style.tres"
const CATALOGUE_PATH := "res://ramon/Menu/entries/catalogue.tres"

## Order is the curriculum: legibility, then interaction, then spectacle.
##
## The info-cell text is written from what the prototypes' own READMEs and
## follow-up notes already establish, deliberately at roughly twelve words each.
const SEED: Array[Dictionary] = [
	{
		"title": "Slice Vision",
		"blurb": "Camera and avatar tuned for reading a 4D cross-section",
		"maturity": "Playable",
		"clip": "slice_vision",
		"icon": "icon_slice_vision.png",
		"scene": "res://ramon/MiegakureLook/levels/level_1_wall.tscn",
		"keys": ["WASD", "RMB"],
		"actions": ["move", "rotate slice 90°"],
		"question": "Can anyone read a 4D scene at all without training?",
		"approach": "Third-person diorama, discrete 90° turns, floor banded along w.",
		"finding": "Banding is load-bearing; an unbanded rotated view is a blank diamond.",
	},
	{
		"title": "Phase Maze",
		"blurb": "Walls you pass by rotating, not by walking",
		"maturity": "Playable",
		"clip": "phase_maze",
		"icon": "icon_phase_maze.png",
		"scene": "res://ramon/PhaseMaze/phase_maze.tscn",
		"keys": ["WASD", "RMB", "Q / E"],
		"actions": ["move", "rotate slice", "through w"],
		"question": "Does rotation work as a navigation verb rather than a camera trick?",
		"approach": "Maze walls occupy w-bands; rotating changes which ones are solid.",
		"finding": "It reads immediately, but only where the route is signposted.",
	},
	{
		"title": "4D Ascent",
		"blurb": "A vertical course climbed by rotating as much as jumping",
		"maturity": "Greybox",
		"clip": "ascent",
		"icon": "icon_ascent.png",
		"scene": "res://ramon/ObstacleCourse/w_gap.tscn",
		"keys": ["WASD", "SPACE", "RMB"],
		"actions": ["move", "jump", "rotate slice"],
		"question": "Can a vertical course stay legible once the slice can change?",
		"approach": "Bounded tower, tier-coloured back wall as the only HUD.",
		"finding": "Physics is axis-aligned boxes only: no ramps, every rise is a step.",
	},
	{
		"title": "Portal",
		"blurb": "Linked openings that drop you somewhere else",
		"maturity": "Prototype",
		"clip": "portal",
		"icon": "icon_portal_chamber.png",
		"scene": "res://ramon/Portal/portal_test_1.tscn",
		"keys": ["LMB", "F", "RMB"],
		"actions": ["blue portal", "yellow portal", "rotate slice"],
		"question": "Does Portal's momentum-preserving link survive four dimensions?",
		"approach": "Two linked apertures; position, orientation and velocity carried across.",
		"finding": "Works, and accelerates: 7.7 to 22.2 m/s over five crossings.",
	},
	{
		"title": "Quantum Range",
		"blurb": "Hitscan raycasting against 4D colliders",
		"maturity": "Playable",
		"clip": "quantum_range",
		"icon": "icon_quantum_range.png",
		"scene": "res://ramon/ShootingGalleryRamon/shooting_gallery_ramon.tscn",
		"keys": ["WASD", "LMB", "RMB"],
		"actions": ["move", "fire", "rotate slice"],
		"question": "What does aiming mean when a target can leave your slice?",
		"approach": "Real 4D raycasts against 4D collision, independent of the camera.",
		"finding": "You can miss in a direction you cannot see - and it reads as fair.",
	},
	{
		"title": "Voxel Mining",
		"blurb": "Destructible geometry by dual contouring in four dimensions",
		"maturity": "Prototype",
		"clip": "voxel_mining",
		"icon": "icon_voxel_mining.png",
		"scene": "res://ramon/VoxelMining/voxel_mining_final_2.tscn",
		"keys": ["WASD", "LMB", "Q / E"],
		"actions": ["move", "carve", "through w"],
		"question": "Can 4D matter be destroyed at interactive rates?",
		"approach": "Persistent voxel field, dual contoured, re-meshed per hit.",
		"finding": "Yes: about 130 ms per carve at room scale, around 58 fps.",
	},
	{
		"title": "Sky Box Clouds",
		"blurb": "A sky built from geometry, so it exists in every slice",
		"maturity": "Prototype",
		"clip": "skybox_clouds",
		"icon": "icon_sky_box_clouds.png",
		"scene": "res://ramon/SkyBoxClouds/skybox_clouds.tscn",
		"keys": ["WASD", "RMB"],
		"actions": ["move", "rotate slice"],
		"question": "What does weather look like when you turn out of the world?",
		"approach": "Clumped polytope clouds on a 4D skydome, not a painted texture.",
		"finding": "Clouds genuinely reshape as you rotate, because they are solids.",
	},
	{
		"title": "Voxel Port",
		"blurb": "Streamed 4D terrain, contoured per slice",
		"maturity": "Greybox",
		"clip": "voxel_port",
		"icon": "icon_voxel_port.png",
		"scene": "",
		"keys": ["WASD", "Q / E"],
		"actions": ["move", "through w"],
		"question": "Does 4D terrain scale beyond a single authored room?",
		"approach": "Chunked field streamed and contoured around the viewer.",
		"finding": "Streaming holds; total tetrahedra, not visible geometry, is the budget.",
	},
]


func _initialize() -> void:
	if not _may_overwrite():
		return

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://ramon/Menu/style/"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://ramon/Menu/entries/"))

	var style: Resource = StyleScript.new()
	style.font = load(FONT_PATH)
	_save(style, STYLE_PATH)

	var catalogue: Resource = CatalogueScript.new()
	# Typed to match the export exactly. An untyped Array assigned into an
	# Array[MenuEntry] forces a conversion, which is what triggered the setter
	# recursion above.
	var built: Array[MenuEntry] = []
	for seed_entry in SEED:
		var entry: MenuEntry = EntryScript.new()
		entry.title = seed_entry["title"]
		entry.blurb = seed_entry["blurb"]
		entry.maturity = seed_entry["maturity"]
		entry.clip = seed_entry["clip"]
		entry.scene_path = seed_entry["scene"]
		entry.icon = load(ICON_DIR + str(seed_entry["icon"]))
		entry.control_keys = PackedStringArray(seed_entry["keys"])
		entry.control_actions = PackedStringArray(seed_entry["actions"])
		entry.question = seed_entry["question"]
		entry.approach = seed_entry["approach"]
		entry.finding = seed_entry["finding"]
		# Sub-resources of a .tres must be marked local to scene = false and
		# simply be referenced; ResourceSaver writes them inline automatically
		# because they have no path of their own.
		built.append(entry)
	catalogue.entries = built
	_save(catalogue, CATALOGUE_PATH)

	print("BOOTSTRAP: wrote %s and %s (%d entries)" % [STYLE_PATH, CATALOGUE_PATH, built.size()])
	quit(0)


## Refuses to clobber a catalogue that already exists, and says what would be
## lost rather than just saying no.
##
## The guard reports the CURRENT entry count against SEED's, because the two
## diverging is the whole hazard: the file on disk has grown entries and fields
## this script has never heard of.
func _may_overwrite() -> bool:
	if not ResourceLoader.exists(CATALOGUE_PATH):
		return true

	var wanted: bool = false
	for arg in OS.get_cmdline_user_args():
		if arg == "overwrite":
			wanted = true
	if wanted:
		print("BOOTSTRAP: overwriting %s as instructed" % CATALOGUE_PATH)
		return true

	var existing: Resource = load(CATALOGUE_PATH)
	var count: int = existing.entries.size() if existing != null else -1
	printerr("BOOTSTRAP: REFUSING TO RUN.")
	printerr("  %s already exists with %d entries; this script would replace it with %d" % [
		CATALOGUE_PATH, count, SEED.size()
	])
	printerr("  and drop every duration, detail line, benchmark and crop added since.")
	printerr("  To add entries instead, copy _seed_menu2_entries.gd.")
	printerr("  To replace it anyway:  --script ... -- overwrite")
	quit(1)
	return false


func _save(resource: Resource, path: String) -> void:
	var err: int = ResourceSaver.save(resource, path)
	if err != OK:
		printerr("BOOTSTRAP: failed to save %s (%d)" % [path, err])
		quit(1)
