extends Control
## Main menu - lists the currently available gameplay modes as buttons.
## Purely 2D (Control-based) - no 4D/3D content needed for a menu screen.
##
## To add a mode later (Free/Scripted, Rail, etc.), just append an entry to
## AVAILABLE_MODES - nothing else in this script needs to change. Pure
## throwaway diagnostic scenes (jump_test, bearing_test, trigger_test,
## smoke_test, etc.) stay unlisted - this is a hand-curated list, not an
## automatic scan of every scene in the project. A WIP feature under active
## iteration DOES belong here once it's meant to be played and reviewed by
## the team, not just exercised by an automated test.
const AVAILABLE_MODES := [
	{"name": "Shooting Gallery - Free", "scene_path": "res://sandbox/shooting_gallery/shooting_gallery.tscn", "game_mode": "free"},
	{"name": "Shooting Gallery - Contest", "scene_path": "res://sandbox/shooting_gallery/shooting_gallery.tscn", "game_mode": "contest"},
	{"name": "4D Hub", "scene_path": "res://ramon/HubFinal.tscn"},
	{"name": "Shooting Range (Ramon)", "scene_path": "res://ramon/ShootingGalleryRamon/shooting_gallery_ramon.tscn"},
	{"name": "Bullseye Practice", "scene_path": "res://sandbox/shooting_gallery/bullseye/bullseye_range.tscn"},
	{"name": "4-Simplex Grid Test", "scene_path": "res://simplex_grid_test.tscn"},
	{"name": "4-Simplex Pillar Monument", "scene_path": "res://simplex_pillar_test.tscn"},
	{"name": "Area Capture Prototype", "scene_path": "res://sandbox/area_capture/area_capture_test.tscn"},
	{"name": "Synthwave Test", "scene_path": "res://sandbox/synthwave/synthwave_test.tscn"},
	{"name": "Skew Polyhedron {4,4|n}", "scene_path": "res://sandbox/skew_polyhedron/skew_polyhedron_test.tscn"},
	{"name": "IK Chain Test (5 joints)", "scene_path": "res://sandbox/single_joint/single_joint_test.tscn"},
	{"name": "Limb Prototype", "scene_path": "res://sandbox/limb_prototype/limb_prototype_test.tscn"},
	{"name": "Limb Prototype Treadmill", "scene_path": "res://sandbox/limb_prototype/limb_prototype_treadmill.tscn"},
]

@onready var mode_list: VBoxContainer = $CenterContainer/VBoxContainer/ModeList
@onready var quit_button: Button = $CenterContainer/VBoxContainer/QuitButton


func _ready() -> void:
	# Gameplay scenes capture the mouse (hidden + locked) for look-around;
	# nothing else resets it back, so without this the cursor stays invisible
	# here too, making it impossible to see which button is about to be clicked.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for mode in AVAILABLE_MODES:
		var button := Button.new()
		button.text = mode.name
		button.pressed.connect(_on_mode_selected.bind(mode))
		mode_list.add_child(button)
	quit_button.pressed.connect(_on_quit_pressed)


func _on_mode_selected(mode: Dictionary) -> void:
	# change_scene_to_file() can't take parameters, so a mode that needs to
	# tell the destination scene which variant to run (both Shooting Gallery
	# entries point at the same shooting_gallery.tscn) sets a flag on the
	# shared GameMode autoload immediately before switching - the only
	# other option here.
	if mode.has("game_mode"):
		GameMode.selected_mode = GameMode.Mode.CONTEST if mode.game_mode == "contest" else GameMode.Mode.FREE
	get_tree().change_scene_to_file(mode.scene_path)


func _on_quit_pressed() -> void:
	get_tree().quit()
