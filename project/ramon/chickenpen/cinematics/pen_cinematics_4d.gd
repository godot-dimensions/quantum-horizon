extends Node

## The pen's cinematics, played by name - the menu's CINEMATICS list (Ramon, 1 Oct: "a
## 'cinematics' menu ... press 1 ... press 2") and the film runner both come through here.
##
## FROM THE MENU: menu_final.gd sets the root's meta "pen_cinematic" to a name and either
## opens the pen or, when it was opened from one of the pen's laptops, sends you back into
## that pen. This node finds the meta whenever the pen enters the tree - a fresh pen, or the
## parked one coming back - and plays the cinematic. When it ends, or is skipped with
## Escape, "pen_cinematic_return" says where to: "menu" goes back to the menu, "pen" hands
## the pen back as it was. Played any other way (play() from a runner) it hands it back.
##
## A ROOT CHILD OF THE PEN, LAST IN THE SCENE, on purpose: _input reaches nodes later in the
## tree first, so a cinematic under here sees Escape before the pen's own controls do. And
## it is not under World, Systems or UI, so no crossing ever puts it to sleep.

signal finished(id: String)

const MENU := "res://ramon/menu_final.tscn"
const META := &"pen_cinematic"
const RETURN_META := &"pen_cinematic_return"
## Name to script. Names are what the menu stores.
const CINEMATICS := {
	"murmuration": preload("res://ramon/chickenpen/cinematics/cinematic_murmuration_4d.gd"),
}

var _playing: Node = null
var _id: String = ""
var _back_to_menu: bool = false


func _enter_tree() -> void:
	_check_for_request.call_deferred()


func _check_for_request() -> void:
	if not is_inside_tree():
		return
	var root: Window = get_tree().root
	if not root.has_meta(META):
		return
	var id: String = String(root.get_meta(META))
	var back: String = String(root.get_meta(RETURN_META, "menu"))
	root.remove_meta(META)
	if root.has_meta(RETURN_META):
		root.remove_meta(RETURN_META)
	_back_to_menu = back == "menu"
	if not play(id):
		push_warning("Cinematics: no cinematic called '%s'." % id)
		if _back_to_menu:
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
