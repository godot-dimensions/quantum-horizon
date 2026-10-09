extends RefCounted

## The journey round each level (round 2: R8, R10, R11; Ramon, 9 Oct, while the bot played): "look down
## from a highpoint at a giant maze ... as a journey ingredient", and "sometimes you end up in a big room,
## where for example the dreamer is from the pen ... you much smaller in the big room, and like stage
## completed ... making you curious about the next reward".
##
## THE OVERLOOK. A level begins 14 m up, on a platform over its start cell, railed, looking down over the
## whole maze. The platform spans every layer of the maze through W, so it stays under you when you turn:
## press F up there and the maze below rearranges into another flat maze, the clearest sight of the idea
## there is. Stand in its yellow ring and it lowers you into the maze (a lift; the rails stay up there,
## a frame in the sky over the start).
##
## THE REWARD HALL. The exit leads to a hall 48 m across with walls 22 m high, far from the maze. The
## stage's reward stands in it, huge, and you are small: a flock of giant chickens circling overhead (the
## Shooting Range's flying chicken, carried), a pack of wolves running laps (the range's rigid wolf), and
## last the dreamer from the pen's cave (carried, never touched). A blue panel on its wall shows the next
## stage's reward as a dark silhouette.
##
## NO class_name (engine_gotchas.md): preload it.

const LabGrid := preload("res://ramon/PhaseMazeRemake/carried/LabKit/lab_grid.gd")
const LabBatch := preload("res://ramon/PhaseMazeRemake/carried/LabKit/lab_batch.gd")
const LabMaterials := preload("res://ramon/PhaseMazeRemake/carried/LabKit/lab_materials.gd")
const LabPrint := preload("res://ramon/PhaseMazeRemake/carried/LabKit/lab_print.gd")
const Glyphs := preload("res://ramon/PhaseMazeRemake/carried/kit/kit_glyphs.gd")
const Style := preload("res://ramon/PhaseMazeRemake/maze/maze_style.gd")
const ChickenScript := preload("res://ramon/PhaseMazeRemake/carried/rewards/target_chicken.gd")
const WolfScript := preload("res://ramon/PhaseMazeRemake/carried/rewards/target_wolf.gd")
const DreamerScript := preload("res://ramon/PhaseMazeRemake/carried/rewards/dreamer/cave_dreamer_4d.gd")

const OVERLOOK_UP := 14.0
const RAIL := 1.2
## The hall: far from any maze, never seen from one.
const HALL_AT := Vector4(0.0, 0.0, -220.0, 0.0)
const HALL := Vector3(48.0, 22.0, 48.0)
const HALL_W := 40.0
## Rewards by name: what stands in the hall, and its silhouette on the next stage's teaser.
const REWARDS := {
	"chickens": {"title": "THE FLOCK", "glyph": "chicken"},
	"wolves": {"title": "THE PACK", "glyph": "wolf"},
	"dreamer": {"title": "THE DREAMER", "glyph": "dreamer"},
}


# -- the overlook --------------------------------------------------------------------------------------

## The platform over the start cell, its rails and its lift ring. {"lift": StaticBody4D, "top": float,
## "bottom": float, "centre": Vector4, "spawn": Vector4}.
static func overlook(parent: Node4D, lv) -> Dictionary:
	var s: Vector4 = lv.cell_centre(lv.start)
	var sz: Vector3 = lv.size_of(lv.start)
	var b: Array = lv.bounds()
	var all_w: float = (b[1] as Vector4).w - (b[0] as Vector4).w + 1.0
	var mid_w: float = ((b[0] as Vector4).w + (b[1] as Vector4).w) * 0.5
	var top: float = s.y + OVERLOOK_UP
	var px: float = sz.x - 0.9
	var pz: float = sz.y - 0.9
	var lift := StaticBody4D.new()
	lift.name = "Lift"
	lift.position = Vector4(s.x, top, s.z, mid_w)
	parent.add_child(lift)
	var plate := Vector4(px, 0.3, pz, all_w)
	_solid(lift, "Plate", plate, Vector4(0.0, -0.15, 0.0, 0.0), "maze_climb")
	var ring := LabBatch.new()
	ring.ring("lift", Vector4(0.0, 0.02, 0.0, 0.0), 1.25, 0.16, 0.04, all_w, 48)
	var rm: MeshInstance4D = ring.instance("lift")
	rm.name = "LiftRing"
	rm.material_override = LabMaterials.glow(Style.glow("start"), 1.2)
	rm.set("allow_projection", false)
	lift.add_child(rm)
	# The rails stay up: a frame in the sky over the start once the lift has gone down.
	var rails := StaticBody4D.new()
	rails.name = "Rails"
	rails.position = Vector4(s.x, top, s.z, mid_w)
	parent.add_child(rails)
	for r in [[Vector4(px + 0.12, RAIL, 0.12, all_w), Vector4(0, RAIL * 0.5, pz * 0.5, 0)], [Vector4(px + 0.12, RAIL, 0.12, all_w), Vector4(0, RAIL * 0.5, -pz * 0.5, 0)],
			[Vector4(0.12, RAIL, pz, all_w), Vector4(px * 0.5, RAIL * 0.5, 0, 0)], [Vector4(0.12, RAIL, pz, all_w), Vector4(-px * 0.5, RAIL * 0.5, 0, 0)]]:
		_solid(rails, "Rail", r[0], r[1], "maze_cap")
	return {"lift": lift, "rails": rails, "top": top, "bottom": s.y + 0.02, "centre": Vector4(s.x, top, s.z, s.w),
		"spawn": Vector4(s.x, top + 0.1, s.z + pz * 0.5 - 1.0, s.w)}


static func _solid(parent: Node4D, nm: String, size: Vector4, at: Vector4, swatch: String) -> void:
	var mi := MeshInstance4D.new()
	mi.name = nm
	var mesh := BoxTetraMesh4D.new()
	mesh.size = size
	mi.mesh = mesh
	mi.position = at
	mi.material_override = LabGrid.material(swatch, size, at)
	mi.set("allow_projection", false)
	parent.add_child(mi)
	var shape := CollisionShape4D.new()
	var box := BoxShape4D.new()
	box.size = size
	shape.shape = box
	shape.position = at
	parent.add_child(shape)


# -- the hall --------------------------------------------------------------------------------------------

## The reward hall: floor, four walls, a ring of light round its middle. {"centre", "spawn", "room"}.
static func hall(parent: Node4D) -> Dictionary:
	var body := StaticBody4D.new()
	body.name = "Hall"
	body.position = HALL_AT
	parent.add_child(body)
	var t: float = 0.6
	_solid(body, "HallFloor", Vector4(HALL.x + t * 2.0, 1.0, HALL.z + t * 2.0, HALL_W), Vector4(0, -0.5, 0, 0), "maze_floor")
	for wdef in [[Vector4(HALL.x + t * 2.0, HALL.y, t, HALL_W), Vector4(0, HALL.y * 0.5, -HALL.z * 0.5 - t * 0.5, 0)],
			[Vector4(HALL.x + t * 2.0, HALL.y, t, HALL_W), Vector4(0, HALL.y * 0.5, HALL.z * 0.5 + t * 0.5, 0)],
			[Vector4(t, HALL.y, HALL.z, HALL_W), Vector4(-HALL.x * 0.5 - t * 0.5, HALL.y * 0.5, 0, 0)],
			[Vector4(t, HALL.y, HALL.z, HALL_W), Vector4(HALL.x * 0.5 + t * 0.5, HALL.y * 0.5, 0, 0)]]:
		_solid(body, "HallWall", wdef[0], wdef[1], "kit_wall")
	var glow := LabBatch.new()
	glow.ring("ring", Vector4(0, 0.03, 0, 0), 12.0, 0.25, 0.04, HALL_W - 2.0, 96, 0.6)
	glow.ring("ring", Vector4(0, 0.03, 0, 0), 16.0, 0.12, 0.04, HALL_W - 2.0, 96, 0.5)
	var gm: MeshInstance4D = glow.instance("ring")
	gm.material_override = LabMaterials.glow(Style.glow("w"), 1.1)
	gm.set("allow_projection", false)
	body.add_child(gm)
	return {"centre": HALL_AT, "spawn": HALL_AT + Vector4(0.0, 0.1, 8.0, 0.0),
		"room": [HALL_AT - Vector4(HALL.x * 0.5 - 2.0, 0, HALL.z * 0.5 - 2.0, 0), HALL_AT + Vector4(HALL.x * 0.5 - 2.0, 0, HALL.z * 0.5 - 2.0, 0)]}


## The teaser on the hall's east wall: the next stage, and its reward as a dark silhouette.
static func teaser(parent: Node4D, next_label: String, reward: String) -> void:
	var old: Node = parent.get_node_or_null("Teaser")
	if old != null:
		old.free()
	var size_m := Vector2(16.0, 7.0)
	var at: Vector4 = HALL_AT + Vector4(HALL.x * 0.5 - 0.05, 3.0 + size_m.y * 0.5, 0.0, 0.0)
	var box := Vector4(0.08, size_m.y, size_m.x, 3.0)
	var mi := MeshInstance4D.new()
	mi.name = "Teaser"
	var mesh := BoxTetraMesh4D.new()
	mesh.size = box
	mi.mesh = mesh
	mi.position = at
	var m: TetraMaterial4D = LabGrid.material("kit_code_blue", box, at)
	mi.material_override = m
	mi.set("allow_projection", false)
	parent.add_child(mi)
	var ppm: float = 90.0
	var glyph: String = String(REWARDS.get(reward, {}).get("glyph", "chicken"))
	var tex: Texture2D = await LabPrint.render(parent.get_tree(), Vector2i(int(size_m.x * ppm), int(size_m.y * ppm)), func(c: Control) -> void:
		var w: float = c.size.x
		var h: float = c.size.y
		var fb: Font = LabPrint.font("black")
		var fs: Font = LabPrint.font("bold")
		c.draw_string(fs, Vector2(0.6 * ppm, 0.9 * ppm), "NEXT", HORIZONTAL_ALIGNMENT_LEFT, -1, int(0.45 * ppm), Color(1, 1, 1, 0.75))
		c.draw_string(fb, Vector2(0.6 * ppm, 1.9 * ppm), next_label, HORIZONTAL_ALIGNMENT_LEFT, w * 0.55, int(0.8 * ppm), Color.WHITE)
		c.draw_string(fs, Vector2(0.6 * ppm, h - 0.8 * ppm), "Something waits at the end of it.", HORIZONTAL_ALIGNMENT_LEFT, -1, int(0.4 * ppm), Color(1, 1, 1, 0.85))
		var r := Rect2(Vector2(w * 0.58, 0.5 * ppm), Vector2(w * 0.38, h - 1.0 * ppm))
		draw_silhouette(c, glyph, r))
	# The panel faces -x (into the hall): its x face.
	LabGrid.set_print(m, tex, Vector4(-1, 0, 0, 0), Rect2(Vector2.ZERO, size_m), Color.WHITE, 0.35)
	LabGrid.set_print_strength(m, 1.0)


## A reward as a dark shape with a faint rim: enough to wonder at, not to know.
static func draw_silhouette(c: CanvasItem, glyph: String, r: Rect2) -> void:
	var dark := Color(0.02, 0.05, 0.14, 0.92)
	if glyph == "dreamer":
		var o: Vector2 = r.get_center()
		var rad: float = minf(r.size.x, r.size.y) * 0.18
		for i in 14:
			var a: float = TAU * float(i) / 14.0
			var p := PackedVector2Array()
			for q in 12:
				var t: float = float(q) / 11.0
				var bend: float = sin(t * 3.0 + float(i)) * 0.35
				p.append(o + Vector2(cos(a + bend * t), sin(a + bend * t)) * (rad + t * rad * 1.8))
			c.draw_polyline(p, dark, maxf(2.0, rad * 0.12 * (1.0 - float(i % 3) * 0.2)), true)
		c.draw_circle(o, rad, dark)
		c.draw_arc(o, rad * 0.6, 0.0, TAU, 32, Color(0.4, 0.6, 1.0, 0.35), 3.0, true)
		return
	Glyphs.animal(c, glyph, r, dark, dark)
	c.draw_string(LabPrint.font("black"), r.get_center() + Vector2(-r.size.y * 0.06, r.size.y * 0.1), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, int(r.size.y * 0.3), Color(1, 1, 1, 0.35))


# -- the rewards -----------------------------------------------------------------------------------------

## The reward `name` in the hall under `parent`, facing the arrival. Returns the node holding it.
static func reward(parent: Node4D, name: String, player: Node4D, rig: Node4D, camera: Camera4D) -> Node4D:
	var holder := Node4D.new()
	holder.name = "Reward"
	holder.position = HALL_AT
	parent.add_child(holder)
	match name:
		"chickens":
			# Five giant birds circling over the middle (the range's flying chicken, its wings beating as it
			# moves); circle() moves them.
			for i in 5:
				var bird := Node4D.new()
				bird.set_script(ChickenScript)
				bird.set("size", 5.0)
				bird.set("friendly", true)
				if "camera" in bird:
					bird.set("camera", camera)
				bird.set_meta("orbit", [9.0 + float(i % 2) * 5.0, 7.0 + float(i) * 1.6, TAU * float(i) / 5.0, 0.32 + float(i % 3) * 0.06])
				bird.position = Vector4(10.0, 8.0, 0.0, 0.0)
				holder.add_child(bird)
		"wolves":
			# Three wolves, three times the range's size, running laps round the middle (their own route).
			for i in 3:
				var route: Array = []
				var r: float = 11.0 + float(i) * 3.0
				for q in 16:
					var a: float = TAU * float(q) / 16.0 + float(i) * 0.7
					route.append({"run": Vector4(cos(a) * r, 0.0, sin(a) * r, 0.0), "speed": 7.0 - float(i) * 0.5})
				var wolf := Node4D.new()
				wolf.set_script(WolfScript)
				wolf.set("size", 3.2)
				wolf.set("collar", "green")
				wolf.set("route", route)
				wolf.set("loop", true)
				wolf.set("delay", float(i) * 0.8)
				if "camera" in wolf:
					wolf.set("camera", camera)
				wolf.position = route[0]["run"]
				holder.add_child(wolf)
		"dreamer":
			var d := Node4D.new()
			d.set_script(DreamerScript)
			d.set("creature_scale", 2.1)
			d.set("room_radii", Vector4(22.0, 20.0, 22.0, 18.0))
			# It turns to face your head and your slice: paths from where it will stand.
			d.set("player_path", NodePath("../" + String(holder.get_path_to(player))))
			d.set("camera_rig_path", NodePath("../" + String(holder.get_path_to(rig))))
			d.position = Vector4(0.0, 0.0, -3.0, 0.0)
			holder.add_child(d)
	return holder


## The flock's circling, every frame (the birds animate from how they move).
static func circle(holder: Node4D, t: float) -> void:
	for bird in holder.get_children():
		if not bird.has_meta("orbit"):
			continue
		var o: Array = bird.get_meta("orbit")
		var a: float = float(o[2]) + t * float(o[3])
		(bird as Node4D).position = Vector4(cos(a) * float(o[0]), float(o[1]) + sin(t * 0.7 + float(o[2])) * 0.8, sin(a) * float(o[0]), 0.0)
