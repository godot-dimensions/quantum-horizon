extends SceneTree
## One-off: repoints every entry at the new 512px icon set and adds Trym's two
## scenes to the catalogue.
##
## Additive, like _seed_menu2.gd - it edits what is there rather than rebuilding,
## so hand-tuned crops and any inspector edits survive.
##
## SAME TRAP as that script: ResourceSaver.save() over an existing .tres DROPS
## its `uid` header, and anything referencing it by uid then warns and silently
## falls back to the text path. The header is written back explicitly at the end.
##
##   godot.windows.editor.double.x86_64.console.exe --headless --path project \
##       --script res://ramon/Menu/_seed_menu2_entries.gd

const CATALOGUE_PATH := "res://ramon/Menu/entries/catalogue.tres"
const CATALOGUE_UID := "uid://b6ehjm0dis877"
const STYLE_PATH := "res://ramon/Menu/style/menu2_style.tres"
const ICON_DIR := "res://ramon/Menu/icons/"
const EntryScript := preload("res://ramon/Menu/scripts/menu_entry.gd")

## Existing entries keep their glyph, just at 4x the resolution. The old 128px
## set stays where it is because the Demo hub's billboards still use it.
const ICON_FOR := {
	"Slice Vision": "icon_slice_vision.png",
	"Phase Maze": "icon_phase_maze.png",
	"4D Ascent": "icon_ascent.png",
	"Portal": "icon_portal_chamber.png",
	"Quantum Range": "icon_quantum_range.png",
	"Voxel Mining": "icon_voxel_mining.png",
	"Sky Box Clouds": "icon_sky_box_clouds.png",
	"Voxel Port": "icon_voxel_port.png",
}

## Trym's two, inserted before the environment entries so the organic ones sit
## together - a walking creature and a forest are the only "look at this" items
## in the set, and they earn their place next to each other rather than buried
## at the end.
##
## Copy is written from the prototypes' OWN documentation, not invented:
## PROCEDURAL_CREATURE_ANIMATION_SYSTEM.md for the creature, and
## shrubbery_forest.gd's header for the Voronoi/crown-shyness explanation.
## The numbers are what the scenes reported when I ran them.
const NEW_ENTRIES := [
	{
		"after": "Voxel Mining",
		"title": "Creature Gallery",
		"blurb": "Creatures that walk without a single baked animation",
		"maturity": "Prototype",
		"duration": "2 min",
		"detail": "Quadrupeds whose gait is solved every frame from IK and a gait cycle, never played back.",
		"clip": "creature",
		"icon": "icon_creature.png",
		"scene": "res://sandbox/limb_prototype/creature_gallery.tscn",
		"keys": ["1 – 5", "0", "WASD"],
		"actions": ["gait", "halt", "move"],
		"question": "Can a creature animate convincingly with no baked clips at all?",
		"approach": "FABRIK limbs, a gait state machine, hip suspension and spine IK, solved per tick.",
		"finding": "Limb count and proportions fall out of parameters, so a new creature needs no rig.",
		"benchmark": "5 gaits - walk, trot, hop, canter L/R · per-foot ground raycast adaptation",
	},
	{
		"after": "Creature Gallery",
		"title": "Shrubbery Lab",
		"blurb": "A single tree grown in four dimensions, previewed across the slice",
		"maturity": "Prototype",
		"duration": "90 sec",
		"detail": "One tree grown by space colonisation, light enough to render with the projected preview turned on.",
		"clip": "shrubbery",
		"icon": "icon_shrubbery.png",
		"scene": "res://sandbox/shrubbery/shrubbery_lab.tscn",
		"keys": ["WASD", "RMB", "G"],
		"actions": ["move", "rotate slice", "new tree"],
		"question": "Does procedural growth still read as botanical once it grows in 4D?",
		"approach": "Space colonisation in 4D, rendered with the combined cross-section plus projection engine.",
		"finding": "One tree carries the projected pass comfortably where a whole forest turns it to soup.",
		"benchmark": "1 tree · combined renderer · plane sharpness 0.2, skewness 0.35",
	},
]


func _initialize() -> void:
	var catalogue: Resource = load(CATALOGUE_PATH)
	if catalogue == null:
		printerr("SEED: could not load ", CATALOGUE_PATH)
		quit(1)
		return

	var repointed: int = 0
	for entry in catalogue.entries:
		if entry == null or not ICON_FOR.has(entry.title):
			continue
		var icon: Texture2D = load(ICON_DIR + ICON_FOR[entry.title]) as Texture2D
		if icon == null:
			printerr("SEED: missing icon for ", entry.title, " - run --import first")
			quit(1)
			return
		entry.icon = icon
		repointed += 1
	print("SEED: repointed %d icons" % repointed)

	for spec in NEW_ENTRIES:
		if _index_of(catalogue, spec["title"]) >= 0:
			print("SEED: '%s' already present, skipping" % spec["title"])
			continue
		var entry: MenuEntry = EntryScript.new()
		entry.title = spec["title"]
		entry.blurb = spec["blurb"]
		entry.maturity = spec["maturity"]
		entry.duration = spec["duration"]
		entry.detail = spec["detail"]
		entry.clip = spec["clip"]
		entry.scene_path = spec["scene"]
		entry.icon = load(ICON_DIR + spec["icon"]) as Texture2D
		entry.control_keys = PackedStringArray(spec["keys"])
		entry.control_actions = PackedStringArray(spec["actions"])
		entry.question = spec["question"]
		entry.approach = spec["approach"]
		entry.finding = spec["finding"]
		entry.benchmark = spec["benchmark"]

		var at: int = _index_of(catalogue, spec["after"])
		var entries: Array[MenuEntry] = catalogue.entries
		if at < 0:
			entries.append(entry)
		else:
			entries.insert(at + 1, entry)
		catalogue.entries = entries
		print("SEED: added '%s' after '%s'" % [spec["title"], spec["after"]])

	_save(catalogue, CATALOGUE_PATH)
	_restore_uid(CATALOGUE_PATH, CATALOGUE_UID)

	var style: Resource = load(STYLE_PATH)
	if style != null:
		# A nudge darker again. The glyphs are supporting information; the row's
		# title is the thing being read.
		style.thumbnail_tint = Color(0.46, 0.50, 0.56)
		_save(style, STYLE_PATH)
		print("SEED: darkened thumbnail_tint")
	print("SEED: %d entries total" % catalogue.entries.size())
	quit(0)


func _index_of(catalogue: Resource, title: String) -> int:
	for i in catalogue.entries.size():
		var entry: MenuEntry = catalogue.entries[i]
		if entry != null and entry.title == title:
			return i
	return -1


func _save(resource: Resource, path: String) -> void:
	var err: int = ResourceSaver.save(resource, path)
	if err != OK:
		printerr("SEED: failed to save %s (%d)" % [path, err])
		quit(1)


## Puts the `uid` back into the .tres header that ResourceSaver just stripped.
func _restore_uid(path: String, uid: String) -> void:
	var absolute: String = ProjectSettings.globalize_path(path)
	var file := FileAccess.open(absolute, FileAccess.READ)
	if file == null:
		return
	var text: String = file.get_as_text()
	file.close()
	if text.contains("uid=\"uid://"):
		return
	var newline: int = text.find("]")
	if newline < 0:
		return
	text = text.insert(newline, " uid=\"%s\"" % uid)
	var out := FileAccess.open(absolute, FileAccess.WRITE)
	out.store_string(text)
	out.close()
	print("SEED: restored uid on ", path)
