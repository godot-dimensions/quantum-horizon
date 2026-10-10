extends "res://ramon/MazeRemake2/levels/mr2_level_4d.gd"
## LEVEL 1, THE THRESHOLD: hold E and a door opens.
##
## You arrive in a small white room. A corridor runs ahead to a door with a teal frame: teal is ana.
## Hold E and the floor turns teal while the door's leaves slide apart into the wall (they are 4D
## solids slanted through W, so their slice really moves). V finishes it. Behind it, a garden hall that
## only exists ana, with an oak under a skylight; a glint in the air that only shows near its own W;
## a second, further-ana door to the lift. And for the curious, an amber door in the arrival room's west
## wall that opens the other way, kata, onto a niche with the first Phase Maze's old sign.
##
## On paper (PLAN.md section 4). You start at z 5.5 facing -z; the door is 14.5 m ahead, in sight.

const Oak := preload("res://ramon/MazeRemake2/carried/oak/mr2_oak_lite_4d.gd")
const OLD_SIGN := "res://ramon/textures/phaze_maze_new.png"

const W_LO := -3.5
const W_HI := 4.5
## The garden hall exists from here ana.
const G_W := 0.2
## The niche exists from here kata.
const N_W := -0.2
## The lift exists from here ana.
const L_W := 2.3

var oak: Node4D


func _init() -> void:
	number = 1
	title = "THE THRESHOLD"
	w_min = W_LO
	w_max = W_HI
	bands = [[-2.0, Build.KATA, "KATA"], [0.0, Build.HOME, "HOME"], [2.0, Build.ANA, "ANA"]]
	spawn = Vector4(0, 0, 5.5, 0)
	spawn_yaw = 0.0
	checkpoints = [
		{"name": "niche", "lo": Vector4(-6.2, -1, 1.7, W_LO), "hi": Vector4(-3.5, 4, 5.3, N_W), "at": Vector4(-4.3, 0, 3.5, -1.7), "yaw": -PI * 0.5},
		{"name": "garden", "lo": Vector4(-6, -1, -22, G_W), "hi": Vector4(6, 8, -9, W_HI), "at": Vector4(0, 0, -10.6, 1.7), "yaw": 0.0},
		{"name": "lift", "lo": Vector4(-1.5, -1, -26, L_W), "hi": Vector4(1.5, 4, -22, W_HI), "at": Vector4(0, 0, -23.0, 3.5), "yaw": 0.0},
		{"name": "arrival", "lo": Vector4(-3.5, -1, -9, W_LO), "hi": Vector4(3.5, 4, 7, W_HI), "at": spawn, "yaw": 0.0},
	]
	lift_out = {"lo": Vector4(-1.2, -1, -25.6, L_W), "hi": Vector4(1.2, 3, -23.0, W_HI)}


func build_level() -> void:
	var b = build
	# One floor under everything, and the building's two ends in W.
	b.floor_rect(-7, -27, 7, 8, W_LO - 0.1, W_HI + 0.1)
	b.cap(-7, -27, 7, 8, W_HI, W_HI + 1.0, 6.5)
	b.cap(-7, -27, 7, 8, W_LO - 1.0, W_LO, 6.5)

	# THE ARRIVAL ROOM (all W): x -3.5..3.5, z 0..7.
	b.wall_x(-3.5, 3.5, 7.0, W_LO, W_HI)
	b.wall_z(0.0, 7.0, 3.5, W_LO, W_HI)
	b.wall_z(0.0, 2.7, -3.5, W_LO, W_HI)
	b.wall_z(4.3, 7.0, -3.5, W_LO, W_HI)
	b.wall_x(-3.5, -1.3, 0.0, W_LO, W_HI)
	b.wall_x(1.3, 3.5, 0.0, W_LO, W_HI)
	b.ceiling_rect(-3.7, -0.2, 3.7, 7.2, 3.6, W_LO, W_HI)
	for x in [-1.4, 1.4]:
		b.glow(Morph.standing(Vector3(x - 0.5, 3.57, 2.2), Vector3(x + 0.5, 3.6, 4.8), W_LO, W_HI), Color(0.96, 0.97, 1.0))

	# THE CORRIDOR (all W): x -1.3..1.3, z -9..0, ending in the first door.
	b.wall_z(-9.0, 0.2, -1.3, W_LO, W_HI)
	b.wall_z(-9.0, 0.2, 1.3, W_LO, W_HI)
	b.ceiling_rect(-1.5, -9.2, 1.5, 0.2, 3.6, W_LO, W_HI)
	b.glow(Morph.standing(Vector3(-0.15, 3.57, -8.0), Vector3(0.15, 3.6, -0.6), W_LO, W_HI), Color(0.96, 0.97, 1.0))
	b.wall_x(-6.2, -0.9, -9.0, W_LO, W_HI, 6.0)
	b.wall_x(0.9, 6.2, -9.0, W_LO, W_HI, 6.0)
	b.door({"name": "the first door", "at": Vector2(0, -9), "along": "x", "closed_w": 0.3, "open_w": 1.4, "align_w": 1.7,
		"w_lo": W_LO, "w_hi": W_HI, "wall_h": 6.0, "color": Build.ANA})

	# THE GARDEN HALL (ana of 0.2): x -6..6, z -22..-9, 6 m high, capped kata.
	b.wall_z(-22.0, -9.0, -6.0, G_W, W_HI, 6.0)
	b.wall_z(-22.0, -9.0, 6.0, G_W, W_HI, 6.0)
	b.wall_x(-6.2, -0.9, -22.0, G_W, W_HI, 6.0)
	b.wall_x(0.9, 6.2, -22.0, G_W, W_HI, 6.0)
	b.ceiling_rect(-6.2, -22.2, 6.2, -8.8, 6.0, G_W, W_HI)
	b.cap(-6.2, -22.2, 6.2, -9.2, W_LO - 1.0, G_W, 6.0)
	b.glow(Morph.standing(Vector3(-3.0, 5.96, -19.0), Vector3(3.0, 6.0, -12.0), G_W, W_HI), Color(1.0, 0.97, 0.9))
	b.box(Vector3(-4.2, 0.0, -17.6), Vector3(-0.8, 0.45, -14.2), G_W, W_HI, "desk")
	b.omni(Vector4(-1.0, 4.6, -15.5, 2.0), 1.6, 10.0, Color(1.0, 0.86, 0.66))
	b.door({"name": "the second door", "at": Vector2(0, -22), "along": "x", "closed_w": 2.4, "open_w": 3.2, "align_w": 3.5,
		"w_lo": G_W, "w_hi": W_HI, "wall_h": 6.0, "color": Build.ANA})

	# THE LIFT (ana of 2.3): x -1.5..1.5, z -26..-22.2.
	b.wall_z(-26.0, -22.0, -1.5, L_W, W_HI, 3.0)
	b.wall_z(-26.0, -22.0, 1.5, L_W, W_HI, 3.0)
	b.wall_x(-1.7, 1.7, -26.0, L_W, W_HI, 3.0)
	b.ceiling_rect(-1.7, -26.2, 1.7, -22.0, 3.0, L_W, W_HI)
	b.cap(-1.7, -26.2, 1.7, -22.2, W_LO - 1.0, L_W, 3.2)
	_lift_ring(b, Vector2(0, -24.3), L_W, W_HI)

	# THE NICHE (kata of -0.2), through the amber door in the arrival room's west wall.
	b.door({"name": "the amber door", "at": Vector2(-3.5, 3.5), "along": "z", "width": 1.6, "closed_w": -0.4, "open_w": -1.4,
		"align_w": -1.7, "w_lo": W_LO, "w_hi": W_HI, "wall_h": 3.6, "color": Build.KATA})
	b.wall_z(1.9, 5.1, -6.0, W_LO, N_W, 3.0)
	b.wall_x(-6.2, -3.5, 1.9, W_LO, N_W, 3.0)
	b.wall_x(-6.2, -3.5, 5.1, W_LO, N_W, 3.0)
	b.ceiling_rect(-6.2, 1.7, -3.5, 5.3, 3.0, W_LO, N_W)
	b.cap(-6.2, 1.7, -3.7, 5.3, N_W, W_HI + 1.0, 3.6)
	b.box(Vector3(-5.7, 0.0, 2.7), Vector3(-4.6, 0.78, 4.3), W_LO, N_W, "desk")
	b.box(Vector3(-5.62, 0.78, 2.95), Vector3(-5.5, 1.9, 4.05), W_LO, N_W, "metal")


## A square of glowing strips on the floor: stand inside it to ride on.
func _lift_ring(b, c: Vector2, w0: float, w1: float) -> void:
	var r: float = 0.95
	var t: float = 0.06
	var col := Color(0.55, 0.85, 1.0)
	b.glow(Morph.standing(Vector3(c.x - r, 0.0, c.y - r), Vector3(c.x + r, 0.02, c.y - r + t), w0, w1), col)
	b.glow(Morph.standing(Vector3(c.x - r, 0.0, c.y + r - t), Vector3(c.x + r, 0.02, c.y + r), w0, w1), col)
	b.glow(Morph.standing(Vector3(c.x - r, 0.0, c.y - r), Vector3(c.x - r + t, 0.02, c.y + r), w0, w1), col)
	b.glow(Morph.standing(Vector3(c.x + r - t, 0.0, c.y - r), Vector3(c.x + r, 0.02, c.y + r), w0, w1), col)


func after_build() -> void:
	# The lesson on the arrival room's east wall.
	sign_painted(Vector3(3.24, 0.7, 1.2), Vector3(3.28, 3.1, 5.8), W_LO, W_HI, Vector4(-1, 0, 0, 0), Vector2i(1840, 960),
		lesson_paint("THE ANNEX  ·  1  THE THRESHOLD", "THE CORRIDOR ENDS.\nTHE BUILDING DOES NOT.",
			"There is a direction you cannot see: W.\nHold E to move ana along it. Q moves you kata.\nTeal means ana. Amber means kata."))
	# In the garden hall, on its west wall.
	sign_painted(Vector3(-5.78, 1.2, -19.6), Vector3(-5.74, 3.6, -14.8), G_W, W_HI, Vector4(1, 0, 0, 0), Vector2i(1600, 800),
		lesson_paint("ANA  ·  W +1.7", "THIS HALL LIVES\nANA OF THE CORRIDOR",
			"Every room in the Annex has its own W.\nThe next door opens further ana.", Color(0.55, 1.0, 0.9)))
	# The lift's panel.
	sign_painted(Vector3(-1.0, 1.0, -25.78), Vector3(1.0, 2.2, -25.74), L_W, W_HI, Vector4(0, 0, 1, 0), Vector2i(1000, 600),
		lesson_paint("LIFT", "LEVEL 2\nTHE STACKS", "Stand in the square."))
	# The niche's old monitor: the first Phase Maze's sign, an homage.
	var img := Image.new()
	var ok: bool = img.load(ProjectSettings.globalize_path(OLD_SIGN)) == OK
	if ok:
		# Stored the way the old maze's 3D texture mapping wanted it: upside down and mirrored.
		img.rotate_180()
	var old: Texture2D = ImageTexture.create_from_image(img) if ok else null
	var monitor := func(c: Control) -> void:
		c.draw_rect(Rect2(Vector2.ZERO, c.size), Color(0.02, 0.03, 0.05))
		if old != null:
			var s: float = minf(c.size.x / old.get_width(), (c.size.y * 0.78) / old.get_height())
			var sz := Vector2(old.get_width(), old.get_height()) * s
			c.draw_texture_rect(old, Rect2(Vector2((c.size.x - sz.x) * 0.5, c.size.y * 0.06), sz), false)
		var f: Font = LabPrint.font("bold")
		c.draw_string(f, Vector2(c.size.x * 0.06, c.size.y * 0.93), "PHASE MAZE  ·  WHERE IT STARTED", HORIZONTAL_ALIGNMENT_LEFT, -1, int(c.size.y * 0.05), Color(1.0, 0.75, 0.4))
	sign_painted(Vector3(-5.5, 0.88, 3.02), Vector3(-5.46, 1.82, 3.98), W_LO, N_W, Vector4(1, 0, 0, 0), Vector2i(900, 900), monitor, "glass", 0.8)
	# The two relics.
	add_relic("the first sign", Vector4(-4.4, 1.5, 3.5, -1.9), 0.7, Build.KATA.lerp(Color.WHITE, 0.3), "the niche kata of the arrival room")
	add_relic("the glint", Vector4(4.0, 1.6, -15.0, 3.0), 0.6, Build.ANA.lerp(Color.WHITE, 0.3), "a glint near W 3 in the garden hall")
	# The oak under the skylight.
	oak = Oak.new()
	oak.name = "Oak"
	oak.set("bake", "oak_lite2")
	oak.set("height", 5.2)
	oak.position = Vector4(-2.5, 0.45, -15.9, 2.2)
	oak.set("snap_to_ground", false)
	add_child(oak)


func tick(player: Node4D, delta: float) -> void:
	super.tick(player, delta)
	tick_relics(player, delta)
