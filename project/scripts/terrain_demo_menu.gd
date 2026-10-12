extends Control
## Entry-point menu for browsing the baked voxel terrain demos in context,
## in one running instance, instead of launching each as a separate
## one-off window from the command line. Each button loads
## _interactive_bake.tscn with a different bake_path - the scene's export
## is normally set once in the editor Inspector, so this instantiates it
## manually and assigns bake_path BEFORE adding it to the tree, ahead of
## its own _ready() reading that value.

const INTERACTIVE_BAKE_SCENE: PackedScene = preload("res://_interactive_bake.tscn")

@onready var _button_container: VBoxContainer = %ButtonContainer

## label, bake filename
const DEMOS: Array[Array] = [
	["Rolling hills", "voxel_bake_rolling_hills.bin"],
	["Cracked archipelago", "voxel_bake_cracked_archipelago.bin"],
	["4D arch", "voxel_bake_arch.bin"],
	["Ocean globe", "voxel_bake_ocean_globe.bin"],
]


func _ready() -> void:
	for demo in DEMOS:
		var label: String = demo[0]
		var bake_filename: String = demo[1]
		var button := Button.new()
		button.text = label
		button.custom_minimum_size = Vector2(260, 40)
		button.pressed.connect(_on_demo_pressed.bind(bake_filename))
		_button_container.add_child(button)


func _on_demo_pressed(bake_filename: String) -> void:
	var instance: Node = INTERACTIVE_BAKE_SCENE.instantiate()
	instance.bake_path = "user://%s" % bake_filename
	get_tree().root.add_child(instance)
	get_tree().current_scene = instance
	queue_free()
