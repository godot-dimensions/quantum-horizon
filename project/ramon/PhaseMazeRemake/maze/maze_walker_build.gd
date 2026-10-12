extends RefCounted

## The walker, built in code from the carried copies of the pen's scripts (carried/walker/, PLAN.md
## steps 3 and 33): Andrew's way of walking and seeing, exactly as the pen has it since 8 Oct.
##   - Q and E step along the view's own W at 0.3 of the run (block_walker_character_4d.gd).
##   - The body faces through W with the slice (_target_stance), so on a turned slice it is still seen
##     whole.
##   - Every body part has its own thickness through W, and W ears (block_avatar_4d.gd W_SIZES).
##   - Right mouse held tilts the slice in the view's own axes (pen_orbit_rig_4d.gd, GroundBasis4D).
## The pen's player in shape; in colour the maze's own, dark blue with a brighter face (Ramon, 9 Oct).
## The node layout is the pen's Player (playable_world.tscn), which the scripts expect by name:
##   Player (CharacterBody4D) > CollisionShape4D, Avatar, Gait, CameraRig > Pitch > Camera4D.
##
## THE PLAYABLE WORLD'S SETTINGS (Ramon, 9 Oct: "make sure we're using andrews walker and w rotation
## settings from the playable world"). The scripts are the pen's own (carried/walker/, byte for byte
## the pen's at 11971e1 and still at 1131bb2, apart from the changes carried/README.md lists), and the
## pen's Player sets nothing on the walker or its slice turning, so both run on the scripts' defaults
## here too: W steps at 0.3 of the run, the right-drag tilts the slice at the rig's 0.005 a pixel through
## GroundBasis4D.sliced, the body faces through W. The avatar, the gait, the capsule, the camera's
## renderer, W fade and 77.3 degree lens, and the pitch and zoom limits are set as playable_world.tscn
## sets them. scripts/_check_walker_settings_runner.gd compares it all and lists the differences kept
## on purpose: the framing (a chase camera made for 6 m corridors, not the pen's open-field preset), the
## arm coming all the way in (corridors), R keeping your W (the pen's R walks you to W 0, through maze
## walls), and the walker's colours.
##
## THE RIG'S OWN KEYS ARE SWITCHED OFF, through its exports, so the copy stays as the pen has it: its T
## locks on to chickens, its R walks you home to W 0 (through walls, in a maze), and its Tab cycles
## cameras. The maze's view (maze_view_4d.gd) handles R, T and Tab its own way.
##
## NO class_name (engine_gotchas.md): preload it.

const Character := preload("res://ramon/PhaseMazeRemake/carried/walker/block_walker_character_4d.gd")
const Avatar := preload("res://ramon/PhaseMazeRemake/carried/walker/block_avatar_4d.gd")
const Gait := preload("res://ramon/PhaseMazeRemake/carried/walker/block_gait_4d.gd")
const Rig := preload("res://ramon/PhaseMazeRemake/carried/walker/pen_orbit_rig_4d.gd")

## The walker's colours: dark blue with subtle shifts and a brighter face (Ramon, 9 Oct). Each is an
## avatar export; the Tab panel's Colours page changes them live (recolour()).
const COLOURS := {
	"skin": Color(0.10, 0.17, 0.40),
	"accent": Color(0.15, 0.25, 0.52),
	"face": Color(0.38, 0.58, 0.93),
	"hair": Color(0.06, 0.09, 0.21),
	"belt_colour": Color(0.07, 0.11, 0.27),
	"boot_colour": Color(0.09, 0.12, 0.24),
	"eye_colour": Color(0.03, 0.05, 0.12),
}
## Which body parts each colour paints (block_avatar_4d.gd _build_chibi), by name without the side.
const PARTS := {
	"skin": ["Tunic", "Cap", "UpperArm"],
	"accent": ["Thigh", "Shin", "Forearm", "Hand"],
	"face": ["Head", "Ear"],
	"hair": ["Hair", "Crown", "Tie", "Tail"],
	"belt_colour": ["Belt"],
	"boot_colour": ["Boot"],
	"eye_colour": ["Eye"],
}


## {"body", "rig", "camera", "avatar", "gait"}. The body is added to `parent`.
static func make(parent: Node, at: Vector4) -> Dictionary:
	var body := CharacterBody4D.new()
	body.name = "Player"
	body.set_script(Character)
	body.position = at
	var shape := CollisionShape4D.new()
	shape.name = "CollisionShape4D"
	var capsule := CapsuleShape4D.new()
	capsule.radius = 0.26
	capsule.full_height = 1.35
	shape.shape = capsule
	shape.position = Vector4(0.0, 0.68, 0.0, 0.0)
	body.add_child(shape)
	# The pen's player avatar: the chibi build in its colours (playable_world.tscn).
	var avatar := Node4D.new()
	avatar.name = "Avatar"
	avatar.set_script(Avatar)
	avatar.set("shorts_length", 0.16)
	avatar.set("eyes", true)
	avatar.set("eye_spacing", 0.07)
	avatar.set("eye_height", 0.038)
	avatar.set("eye_width", 0.044)
	avatar.set("eye_tall", 0.054)
	avatar.set("build", 2)
	# Dark blue, with subtle shifts and a brighter blue face (Ramon, 9 Oct). The pen's walker is green;
	# this one is the maze's own (the carried avatar's face, belt and boot colours are Phase Maze additions).
	for k in COLOURS:
		avatar.set(String(k), COLOURS[k])
	body.add_child(avatar)
	var gait := Node4D.new()
	gait.name = "Gait"
	gait.set_script(Gait)
	gait.set("run_speed", 6.0)
	body.add_child(gait)
	var rig := Node4D.new()
	rig.name = "CameraRig"
	rig.set_script(Rig)
	rig.set("start_preset", -1)
	rig.set("lock_key", KEY_NONE)
	rig.set("home_key", KEY_NONE)
	rig.set("cycle_key", KEY_NONE)
	rig.set("pivot_height", 2.1)
	rig.set("distance", 3.6)
	# All the way in: in a corridor the arm must be able to come right up to the walker.
	rig.set("min_distance", 0.0)
	rig.set("start_pitch_degrees", -24.0)
	var pitch := Node4D.new()
	pitch.name = "Pitch"
	rig.add_child(pitch)
	var cam := Camera4D.new()
	cam.name = "Camera4D"
	cam.position = Vector4(0.0, 0.0, 3.6, 0.0)
	cam.set("rendering_engine_name", "Cross-section")
	cam.set("w_fade_distance", 6.0)
	# The pen's lens: its presets all set 77.3 degrees on field_of_view_4d (pen_orbit_rig_4d.gd PRESETS).
	cam.set("field_of_view_4d", deg_to_rad(77.3))
	cam.current = true
	pitch.add_child(cam)
	body.add_child(rig)
	parent.add_child(body)
	return {"body": body, "rig": rig, "camera": cam, "avatar": avatar, "gait": gait}


## Paints the built walker in place: each part's own material, by its name. (Setting the avatar's
## exports would rebuild it, and the gait holds its old limbs.)
static func recolour(avatar: Node4D, colours: Dictionary) -> void:
	for mi in avatar.find_children("*", "MeshInstance4D", true, false):
		var nm: String = (mi as Node).name
		for k in colours:
			if not PARTS.has(k):
				continue
			for prefix in PARTS[k]:
				if nm.begins_with(String(prefix)):
					var m := (mi as MeshInstance4D).material_override as TetraMaterial4D
					if m != null:
						m.albedo_color = colours[k]
