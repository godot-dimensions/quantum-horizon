extends Node

## The pen's cinematics, played by name - the menu's CINEMATICS list (Ramon, 1 Oct: "a
## 'cinematics' menu ... press 1 ... press 2") and the film runner both come through here.
##
## FROM THE MENU: menu_final.gd sets the root's meta "pen_cinematic" to a name and opens the
## pen. This node finds it as the pen starts, plays that cinematic, and when it ends - or is
## skipped with Escape - goes back to the menu. Played any other way (play() from a runner)
## it hands the pen back instead, as it was.
##
## A ROOT CHILD OF THE PEN, LAST IN THE SCENE, on purpose: _input reaches nodes later in the
## tree first, so a cinematic under here sees Escape before the pen's own controls do. And
## it is not under World, Systems or UI, so no crossing ever puts it to sleep.

signal finished(id: String)

const MENU := "res://ramon/menu_final.tscn"
const META := &"pen_cinematic"
## Name to script. Names are what the menu stores.
const CINEMATICS := {
	"murmuration": preload("res://ramon/chickenpen/cinematics/cinematic_murmuration_4d.gd"),
}

var _playing: Node = null
var _id: String = ""
var _back_to_menu: bool = false


func _ready() -> void:
	var root: Window = get_tree().root
	if root.has_meta(META):
		var id: String = String(root.get_meta(META))
		root.remove_meta(META)
		_back_to_menu = true
		if not play(id):
			push_warning("Cinematics: no cinematic called '%s', back to the menu." % id)
			get_tree().change_scene_to_file.call_deferred(MENU)


## Plays cinematic [param id]. False if there is none by that name or one is playing.
func play(id: String) -> bool:
	if _playing != null or not CINEMATICS.has(id):
		return false
	_id = id
	_playing = (CINEMATICS[id] as GDScript).new()
	_playing.name = id.capitalize()
	add_child(_playing)
	_playing.connect("finished", _on_finished)
	# Deferred: from _ready the rest of the pen is not ready yet.
	_playing.call_deferred("play", get_parent())
	return true


func is_playing() -> bool:
	return _playing != null


func _on_finished() -> void:
	var id: String = _id
	if is_instance_valid(_playing):
		_playing.queue_free()
	_playing = null
	_id = ""
	finished.emit(id)
	if _back_to_menu:
		_back_to_menu = false
		get_tree().change_scene_to_file.call_deferred(MENU)
