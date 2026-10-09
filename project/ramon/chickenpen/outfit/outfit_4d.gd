extends RefCounted

## WHAT THE PLAYER IS WEARING: the outfit as a handful of numbers, kept for the whole run and saved
## to disk (follow_up/outfit.md). The fitting circle beside Trym's house changes it; the wearer
## (outfit_wearer_4d.gd) paints it onto whichever player figure is on screen, in the pen, the cave,
## the far room and the cinema alike.
##
## NUMBERS, NOT COLOURS. Each choice is an index into a short curated palette, the way Splatoon and
## Ratchet & Clank offer a dozen swatches rather than a colour wheel: every pick looks right on the
## flat-shaded blocks, and the save file stays a few small integers that survive any later change to
## the palette's exact shades.
##
## AND ONE COLOUR OF YOUR OWN per part (Ramon, 8 Oct: "in the advanced section also make a colorpicker
## wheel next to the colors"): the fitting room's wheel sets a colour key to CUSTOM, its colour kept
## beside it and saved as "<key>_custom". The arrows step off it onto the palette again: right to the
## first swatch, left to the last.
##
## STATIC, AND NO class_name (engine_gotchas.md: a class_name written outside the editor is invisible
## until it rescans). Everything that uses it preloads it. A script holding static variables stays
## loaded for the whole run, so a scene change keeps the values; the file is what keeps them between
## runs, and is read once, the first time anything asks.
##
## THE DEFAULTS ARE TODAY'S FIGURE, exactly: the green tunic and cap, the brown shorts and boots, the
## blond hair and the skin it has always had. A player who never visits the circle sees no change.

## Where the outfit is kept between runs. Runners point this at a file of their own first, through
## use_save_path(), so a test never overwrites Ramon's saved outfit.
static var save_path: String = "user://pen_outfit.cfg"
## Goes up by one on every change, so a wearer knows to repaint without being told who changed what.
static var _revision: int = 0

static var _loaded: bool = false
static var _choice: Dictionary = {}
## The wheel's colour per colour key, for when that key is CUSTOM.
static var _custom: Dictionary = {}

## The rows the circle offers, top of the body to the bottom, and which choices each row holds:
## [name, colour key, style key or ""].
const ROWS := [
	["HAT", "hat_colour", "hat"],
	["HAIR", "hair", ""],
	["SKIN", "skin", ""],
	["SHIRT", "shirt", ""],
	["TROUSERS", "trousers", "legs"],
	["SHOES", "shoes", ""],
]

## Hat styles. The cap is the figure's own; the last two are the jokes.
const HATS := ["Cap", "No hat", "Beanie", "Top hat", "Chicken", "Hypercube"]
const HAT_CAP := 0
const HAT_NONE := 1
const HAT_BEANIE := 2
const HAT_TOP := 3
const HAT_CHICKEN := 4
const HAT_HYPERCUBE := 5
## Trouser styles: the waistband as shorts with bare legs, as the figure was made, or long.
const LEGS := ["Shorts", "Long"]
const LEGS_LONG := 1

## Twelve clothing colours that read on flat-shaded blocks under the pen's light (researched,
## follow_up/outfit.md): no pure white or black, which lose their shading.
const CLOTH := [
	Color(0.851, 0.255, 0.231), Color(0.933, 0.541, 0.184), Color(0.957, 0.784, 0.259),
	Color(0.306, 0.604, 0.290), Color(0.165, 0.616, 0.561), Color(0.353, 0.682, 0.878),
	Color(0.204, 0.341, 0.659), Color(0.494, 0.322, 0.659), Color(0.922, 0.498, 0.682),
	Color(0.541, 0.353, 0.231), Color(0.945, 0.918, 0.847), Color(0.231, 0.231, 0.259),
]
const CLOTH_NAMES := ["Red", "Orange", "Yellow", "Green", "Teal", "Sky", "Cobalt", "Purple", "Pink",
	"Brown", "Cream", "Charcoal"]

## The figure's own colours (block_avatar_4d.gd, and the Player's Avatar in playable_world.tscn and
## theatre.tscn): each clothing row starts with its own, so the first tile is always "as it was".
const ORIGINAL_SHIRT := Color(0.42, 0.62, 0.36)
const ORIGINAL_TROUSERS := Color(0.35, 0.22, 0.14)
const ORIGINAL_SHOES := Color(0.40, 0.26, 0.16)
const ORIGINAL_HAIR := Color(0.86, 0.72, 0.32)
const ORIGINAL_SKIN := Color(0.93, 0.80, 0.62)

## Eight skin tones, light to deep, after the Monk Skin Tone scale (CC BY 4.0), a touch richer so
## faces still read on flat shading, with the figure's own tone in its place as the second.
const SKIN := [
	Color(0.961, 0.863, 0.784), ORIGINAL_SKIN, Color(0.867, 0.663, 0.494), Color(0.769, 0.541, 0.361),
	Color(0.647, 0.427, 0.271), Color(0.518, 0.322, 0.200), Color(0.380, 0.227, 0.145),
	Color(0.271, 0.157, 0.102),
]
## Hair: the natural colours, then two that are not.
const HAIR := [
	ORIGINAL_HAIR, Color(0.165, 0.137, 0.125), Color(0.294, 0.188, 0.133), Color(0.478, 0.255, 0.153),
	Color(0.710, 0.337, 0.165), Color(0.612, 0.604, 0.588), Color(0.922, 0.498, 0.682),
	Color(0.353, 0.682, 0.878),
]
const HAIR_NAMES := ["Blond", "Black", "Dark brown", "Chestnut", "Ginger", "Grey", "Pink", "Sky"]

const DEFAULTS := {
	"hat": HAT_CAP, "hat_colour": 0, "hair": 0, "skin": 1, "shirt": 0, "legs": 0, "trousers": 0, "shoes": 0,
}
const VERSION := 1
## A colour key's value when its colour is the wheel's, not a swatch.
const CUSTOM := -1
## The keys that hold a colour (each row's second), the ones that can be CUSTOM.
const COLOUR_KEYS := ["hat_colour", "hair", "skin", "shirt", "trousers", "shoes"]


## The palette behind [param key]: a list of colours for a colour key, of names for a style key.
static func options(key: String) -> Array:
	match key:
		"hat":
			return HATS
		"legs":
			return LEGS
		"skin":
			return SKIN
		"hair":
			return HAIR
		"hat_colour", "shirt":
			return [ORIGINAL_SHIRT] + CLOTH
		"trousers":
			return [ORIGINAL_TROUSERS] + CLOTH
		"shoes":
			return [ORIGINAL_SHOES] + CLOTH
	return []


## How many changes there have been: a wearer repaints when this moves.
static func changes() -> int:
	return _revision


static func get_value(key: String) -> int:
	_ensure_loaded()
	return int(_choice.get(key, DEFAULTS.get(key, 0)))


## Sets a choice, wrapped round its palette, and says so by bumping the revision.
static func set_value(key: String, value: int) -> void:
	_ensure_loaded()
	var count: int = options(key).size()
	if count == 0:
		return
	var wrapped: int = posmod(value, count)
	if int(_choice.get(key, -2)) == wrapped:
		return
	_choice[key] = wrapped
	_revision += 1


## A colour of your own for [param key] (a colour key), from the fitting room's wheel.
static func set_custom(key: String, c: Color) -> void:
	_ensure_loaded()
	if not key in COLOUR_KEYS:
		return
	c.a = 1.0
	if int(_choice.get(key, -2)) == CUSTOM and (_custom.get(key, Color(-1, -1, -1)) as Color).is_equal_approx(c):
		return
	_choice[key] = CUSTOM
	_custom[key] = c
	_revision += 1


static func is_custom(key: String) -> bool:
	return get_value(key) == CUSTOM


static func step(key: String, delta: int) -> void:
	var at: int = get_value(key)
	if at == CUSTOM:
		# Off your own colour onto the palette: right to its first swatch, left to its last.
		set_value(key, 0 if delta > 0 else -1)
		return
	set_value(key, at + delta)


## The colour chosen for [param key] (a colour key).
static func colour(key: String) -> Color:
	var list: Array = options(key)
	var at: int = get_value(key)
	if at == CUSTOM:
		return _custom.get(key, list[0] if not list.is_empty() else Color.WHITE)
	return list[at] if at >= 0 and at < list.size() and list[at] is Color else Color.WHITE


static func hat() -> int:
	return get_value("hat")


static func long_legs() -> bool:
	return get_value("legs") == LEGS_LONG


## Whether the hat takes the hat colour: the cap, beanie, top hat and hypercube do; no hat has nothing
## to paint, and the chicken is a chicken.
static func hat_takes_colour() -> bool:
	return hat() != HAT_NONE and hat() != HAT_CHICKEN


## What the circle's label says for an option.
static func name_of(key: String, index: int) -> String:
	var list: Array = options(key)
	if index == CUSTOM and key in COLOUR_KEYS:
		return "Your own"
	if index < 0 or index >= list.size():
		return ""
	if list[index] is String:
		return list[index]
	match key:
		"skin":
			return "Tone %d" % (index + 1)
		"hair":
			return HAIR_NAMES[index]
	return "Original" if index == 0 else CLOTH_NAMES[index - 1]


## Everything chosen, for putting back later (the room's undo): a colour of your own as its colour too.
static func snapshot() -> Dictionary:
	_ensure_loaded()
	var out: Dictionary = {}
	for key in DEFAULTS:
		out[key] = get_value(key)
		if out[key] == CUSTOM:
			out[key + "_custom"] = colour(key)
	return out


static func restore(choice: Dictionary) -> void:
	for key in DEFAULTS:
		var v: int = int(choice.get(key, DEFAULTS[key]))
		if v == CUSTOM and choice.get(key + "_custom") is Color:
			set_custom(key, choice[key + "_custom"])
		else:
			set_value(key, v if v != CUSTOM else int(DEFAULTS[key]))


static func is_default() -> bool:
	return snapshot() == DEFAULTS


static func reset() -> void:
	restore(DEFAULTS)


## A whole new outfit at random, never the one already worn. The jokes come up as often as any other
## hat, which is the point of a "surprise me".
static func randomise(rng: RandomNumberGenerator) -> void:
	var before: Dictionary = snapshot()
	for attempt in 8:
		for key in DEFAULTS:
			set_value(key, rng.randi_range(0, options(key).size() - 1))
		if snapshot() != before:
			return


## Writes the outfit to [member save_path]. Returns the error, so a caller can say it failed.
static func save() -> Error:
	_ensure_loaded()
	var file := ConfigFile.new()
	file.set_value("outfit", "version", VERSION)
	for key in DEFAULTS:
		file.set_value("outfit", key, get_value(key))
		if get_value(key) == CUSTOM:
			file.set_value("outfit", key + "_custom", colour(key))
	var err: Error = file.save(save_path)
	if err != OK:
		push_warning("Outfit: could not save to %s (%s)." % [save_path, error_string(err)])
	return err


## Points the store at another file (a test's own) and reads it.
static func use_save_path(path: String) -> void:
	save_path = path
	read_again()


static func current_save_path() -> String:
	return save_path


## Reads the file again.
##
## NOT CALLED reload(). Measured 8 Oct: from another script, `Outfit.reload()` (Outfit a preloaded
## constant) runs the Script's own reload(), which recompiles this script and resets every static
## variable, the save path included, so the first test run wrote the real file. A name of our own.
static func read_again() -> void:
	_loaded = false
	_ensure_loaded()


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_choice = DEFAULTS.duplicate()
	_custom.clear()
	var file := ConfigFile.new()
	if file.load(save_path) != OK:
		return
	# A value that is missing, not a number, or past the end of its palette falls back to the
	# default rather than failing: an old or hand-edited file must never stop the pen from loading.
	for key in DEFAULTS:
		var v: Variant = file.get_value("outfit", key, DEFAULTS[key])
		var count: int = options(key).size()
		if (v is int or v is float) and int(v) >= 0 and int(v) < count:
			_choice[key] = int(v)
		elif (v is int or v is float) and int(v) == CUSTOM and key in COLOUR_KEYS and file.get_value("outfit", key + "_custom") is Color:
			_choice[key] = CUSTOM
			_custom[key] = file.get_value("outfit", key + "_custom")
	_revision += 1
