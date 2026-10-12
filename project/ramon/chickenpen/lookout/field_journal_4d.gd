extends Node

## Wren's field journal: a page for everything that lives on the farm, and for three things
## that live next to it, along W.
##
## A PAGE HAS FOUR SLOTS, ONE PER BEHAVIOUR, rarest last - New Pokemon Snap's one-to-four
## stars, where each star is a different thing to catch rather than a better grade of the
## same photo. A slot keeps the best photo of that behaviour by points; a better one
## replaces it. The three secret pages show as a question until something is on them.
##
## WHY A JOURNAL AND NOT A SCORE. The photography articles this rests on agree that a score
## turns a camera game into a shooting gallery; what makes people keep looking is a list of
## things they have not seen yet (Alba's species list, Umurangi's bounties, the Snap dex).
## Points are here to choose the best photo for a slot, not to be chased.
##
## Saved to [member save_path] with the photos beside it as small PNGs, so the book is still
## there next time. Tests point [member save_path] somewhere else.

signal changed
signal page_found(page: String)
signal slot_filled(page: String, stars: int)

const PAGES := [
	{"id": "starlings", "title": "Starlings", "latin": "Sturnus vulgaris, five thousand of them", "secret": false,
		"slots": ["A flock in flight", "The turning wave", "A sky full of birds", "The hawk's hole"],
		"hints": ["They're up most of the evening. Point the lens at the sky.",
			"When the hawk comes, a shiver goes through them. Catch the roll.",
			"Get the whole flock in. Zoom right out.",
			"The moment it dives, they open round it like a hole."]},
	{"id": "hawk", "title": "The hawk", "latin": "Accipiter nisus, a sparrowhawk", "secret": false,
		"slots": ["A hawk over the field", "The stoop", "Eye to eye", "Above the hawk"],
		"hints": ["Every half minute or so, in from the far side of the flock.",
			"When it folds its wings and drops.",
			"Close enough to fill a good part of the frame.",
			"You'd have to be higher than it flies."]},
	{"id": "crows", "title": "Crows", "latin": "Corvus corone", "secret": false,
		"slots": ["On the fence", "On the wing", "Wings wide", "All three crows"],
		"hints": ["They like the pen fence.", "They go up when you come near.",
			"Taking off, or coming in to land.", "All three, in one picture."]},
	{"id": "chickens", "title": "Chickens", "latin": "Gallus gallus domesticus", "secret": false,
		"slots": ["Scratching about", "On the run", "Home to roost", "Out along W"],
		"hints": ["Anywhere near the pen.", "Something has to frighten them first.",
			"At the coop, settling in.", "Some wander off the slice. Pull focus to find them."]},
	{"id": "nike", "title": "Nike", "latin": "Sus scrofa domesticus, the farm's pig", "secret": false,
		"slots": ["Out for a walk", "Nose in the dirt", "Flat out", "A pig in the air"],
		"hints": ["He ambles about the yard.", "He stops to root now and then.",
			"Sometimes he flops over for a lie down.", "He hops. Not often."]},
	{"id": "cats", "title": "The cats", "latin": "Felis catus, grey and red", "secret": false,
		"slots": ["On the prowl", "Sitting pretty", "A cat mid-leap", "Both cats"],
		"hints": ["Round the crates and the shed.", "When one sits still, for once.",
			"A jump, or running off.", "Both of them, in one picture."]},
	{"id": "folk", "title": "Farm folk", "latin": "Homo sapiens, mostly", "secret": false,
		"slots": ["Farm folk", "Two of them", "A crowd of three", "Wren on the Watchstone"],
		"hints": ["Anyone on the farm.", "Two people in one picture.", "Three in one picture.",
			"From the air, looking back at the Watchstone."]},
	{"id": "owl", "title": "The ana owl", "latin": "Bubo, an eagle owl, from somewhere else", "secret": true,
		"slots": ["The ana owl", "It's seen you", "The wing stretch", "A head turned through W"],
		"hints": ["Something sits in a dead tree north of the Watchstone. Not on this slice.",
			"Wait until it looks at you.", "Now and then it stretches a wing.",
			"Its head turns further than a head should. Through W."]},
	{"id": "white_starling", "title": "The white starling", "latin": "Sturnus vulgaris, leucistic", "secret": true,
		"slots": ["One white bird", "Picked out", "Close up", "In the middle of it"],
		"hints": ["One in five thousand. You'll need the long lens.",
			"Sharp, and right in the middle of the frame.", "Big in the frame.",
			"From inside the flock."]},
	{"id": "heron", "title": "The heron", "latin": "Ardea cinerea, out along W", "secret": true,
		"slots": ["The ana heron", "On one leg", "The strike", "Heron rising"],
		"hints": ["There is water out along W, if you go far enough.",
			"It rests on one leg.", "Stalking, and the stab.", "When it lifts off."]},
	{"id": "chipmunks", "title": "Chipmunks", "latin": "Tamias striatus, out along kata", "secret": true,
		"slots": ["A chipmunk", "Cheeks full", "Up the tree", "Round the back, through W"],
		"hints": ["The marsh is ana. What is kata of it?",
			"When one sits up with something in its paws.", "They run up the big tree in the middle.",
			"Up the trunk, one goes round it through W. Follow it with the ring."]},
]

@export var save_path: String = "user://lookout_journal.cfg"
## Where the photos go, beside the journal.
@export var photo_folder: String = "user://lookout_photos"
@export_range(64, 640, 16) var thumb_width: int = 320

## page id -> four slots, each {} or {points, doing, file, time, from}.
var slots: Dictionary = {}
## The roll so far this session, newest last: {thumb, page, stars, points, doing, verdict}.
var recent: Array = []
## Story flags, saved with the book.
var flags: Dictionary = {}
var _thumbs: Dictionary = {}


func _ready() -> void:
	for page in PAGES:
		slots[page["id"]] = [{}, {}, {}, {}]
	load_book()


func page(id: String) -> Dictionary:
	for p in PAGES:
		if p["id"] == id:
			return p
	return {}


func found(id: String) -> bool:
	for s in slots.get(id, []):
		if not (s as Dictionary).is_empty():
			return true
	return false


func filled(id: String, stars: int) -> bool:
	var row: Array = slots.get(id, [])
	return stars >= 1 and stars <= row.size() and not (row[stars - 1] as Dictionary).is_empty()


## Every filled slot in the book.
func star_count() -> int:
	var n: int = 0
	for id in slots:
		for s in slots[id]:
			if not (s as Dictionary).is_empty():
				n += 1
	return n


func pages_found() -> int:
	var n: int = 0
	for p in PAGES:
		if found(p["id"]):
			n += 1
	return n


## The thumbnail for a slot, loaded from disk once.
func thumb(id: String, stars: int) -> Texture2D:
	var key: String = "%s_%d" % [id, stars]
	if _thumbs.has(key):
		return _thumbs[key]
	if not filled(id, stars):
		return null
	var file: String = String(slots[id][stars - 1].get("file", ""))
	if file == "" or not FileAccess.file_exists(file):
		return null
	var image := Image.load_from_file(file)
	if image == null:
		return null
	var tex := ImageTexture.create_from_image(image)
	_thumbs[key] = tex
	return tex


## A photo just taken: into its slot if it is the best yet. Returns what happened:
## {look, verdict, new_page, new_slot, better, thumb}.
func record(photo: Dictionary, verdict: String) -> Dictionary:
	var look: Dictionary = photo.get("best", {})
	var out: Dictionary = {"look": look, "verdict": verdict, "new_page": false, "new_slot": false, "better": false}
	var image: Image = photo.get("image") as Image
	var small: Image = null
	if image != null:
		small = image.duplicate() as Image
		small.resize(thumb_width, maxi(int(float(thumb_width) * float(image.get_height()) / float(maxi(image.get_width(), 1))), 1), Image.INTERPOLATE_BILINEAR)
		out["thumb"] = ImageTexture.create_from_image(small)
	recent.append({"thumb": out.get("thumb"), "page": look.get("page", ""), "stars": look.get("stars", 0),
		"points": look.get("points", 0), "doing": look.get("doing", ""), "verdict": verdict, "name": look.get("name", ""),
		"size": look.get("size", 0.0), "sharp": look.get("sharp", 0.0), "centred": look.get("centred", 0.0)})
	while recent.size() > 36:
		recent.pop_front()
	if verdict != "good" or not slots.has(look.get("page", "")):
		changed.emit()
		return out
	var id: String = look["page"]
	var stars: int = clampi(int(look["stars"]), 1, 4)
	var was_found: bool = found(id)
	var row: Array = slots[id]
	var old: Dictionary = row[stars - 1]
	if not old.is_empty() and int(old.get("points", 0)) >= int(look["points"]):
		changed.emit()
		return out
	out["new_slot"] = old.is_empty()
	out["better"] = not old.is_empty()
	out["new_page"] = not was_found
	var file: String = ""
	if small != null:
		DirAccess.make_dir_recursive_absolute(photo_folder)
		file = "%s/%s_%d.png" % [photo_folder, id, stars]
		small.save_png(file)
		_thumbs["%s_%d" % [id, stars]] = out.get("thumb")
	row[stars - 1] = {"points": int(look["points"]), "doing": String(look["doing"]), "file": file,
		"time": photo.get("time", 0.0), "from": photo.get("from", "tower")}
	save_book()
	if out["new_page"]:
		page_found.emit(id)
	slot_filled.emit(id, stars)
	changed.emit()
	return out


func set_flag(key: String, value: Variant = true) -> void:
	flags[key] = value
	save_book()
	changed.emit()


func flag(key: String) -> bool:
	return bool(flags.get(key, false))


func save_book() -> void:
	if save_path == "":
		return
	var cfg := ConfigFile.new()
	for id in slots:
		cfg.set_value("slots", id, slots[id])
	cfg.set_value("story", "flags", flags)
	cfg.save(save_path)


func load_book() -> void:
	if save_path == "" or not FileAccess.file_exists(save_path):
		return
	var cfg := ConfigFile.new()
	if cfg.load(save_path) != OK:
		return
	for id in slots:
		var row: Variant = cfg.get_value("slots", id, null)
		if row is Array and (row as Array).size() == 4:
			slots[id] = row
	var f: Variant = cfg.get_value("story", "flags", {})
	if f is Dictionary:
		flags = f


## A fresh book: every slot and flag cleared, the photos deleted.
func wipe() -> void:
	for id in slots:
		for stars in range(1, 5):
			var file: String = String(slots[id][stars - 1].get("file", ""))
			if file != "" and FileAccess.file_exists(file):
				DirAccess.remove_absolute(file)
		slots[id] = [{}, {}, {}, {}]
	flags.clear()
	_thumbs.clear()
	recent.clear()
	save_book()
	changed.emit()
