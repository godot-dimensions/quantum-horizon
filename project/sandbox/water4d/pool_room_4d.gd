extends Node4D
## A room built to show the water off: a deep pool, a walkway across it, and three things to
## look at from the walkway.
##
## WHAT EACH PIECE IS FOR, because otherwise it is just a corridor over a puddle:
##
##   the pool is DEEP   Beer-Lambert absorption only shows when there is a long path of water
##                      to look through. At 2 m depth water is nearly clear; at 14 m the red
##                      is gone and the floor reads blue-green. The depth is the demo.
##   the pillar         runs from the floor to just above the surface, so one object spans
##                      the whole range at once - its top is almost true colour, its foot is
##                      nearly lost. That is light attenuation made visible in a single
##                      glance, which a flat floor cannot do.
##   the rotation point mid-walkway, and the only place that turns the slice for you. The sea
##                      is a 4D field; the proof is that turning the slice changes the waves
##                      rather than just the view, and a slow controlled turn shows that far
##                      better than dragging a mouse.
##   the walkway itself is the wave-mode trigger, so the presets can be changed while you are
##                      standing over the water rather than from a menu somewhere else.
##
## THE FENCE GENERATOR'S FOOTPRINT IS (x, z, w), NOT (x, y, z), and getting that wrong is
## what let you walk off this walkway on the first build.
##
## `fence_generator_4d.cpp:42` says it outright - "The box size packs X, Z, W into X, Y, Z"
## - and every corner it writes has y = 0. The fence encloses a footprint in the three
## HORIZONTAL dimensions and raises posts of `post_height_meters` from it. So `box_size` is
## (length, width, DEPTH THROUGH W), and a box fence closes all four horizontal sides,
## including the two you can only reach by walking through W.
##
## The first version of this used `seed_mesh_3d` with a box whose ends were left off, which
## reads as the obvious way to make a doorway. It is not: a 3D seed goes through
## `convert_mesh_3d_to_4d_faces_only`, which maps the mesh as (x, y, z, 0), so the seed's y
## was height and the fence had NO W EXTENT AT ALL. It fenced z, the walkway's W sides were
## open, and Q or E walked you straight off into the pool. Measured, not guessed:
## `_probe_pool_collision_runner.gd` held at z 1.38 and reached w 10.2, ending on the pool
## floor at y -14.
##
## So the railing is four box fences tracing the walkway's cross-section - two long sides and
## two caps through W - and the doorways are the x ends, which no box covers.

const Presets := preload("res://sandbox/water4d/water4d_presets.gd")
## THIRD PERSON, NOT THE FIRST-PERSON PLAYER. A pool is a thing you look down INTO, and a
## first-person head at 1.6 m can only tilt so far before the walkway fills the frame. The
## lab kit's walker carries the pen's orbit rig, so the camera can be swung up and over the
## player to look steeply down through the water - which is the only way the depth reads.
##
## This is the LabKit's CARRIED copy, frozen inside CreationLab, not Ramon's live chickenpen
## scripts, so the room does not move when the pen does.
const LabPlayer := preload("res://ramon/CreationLab/LabKit/lab_player.gd")

@export_group("Room")
@export var room_size := Vector3(44.0, 40.0, 26.0) ## x, z, and W.
@export var wall_height: float = 11.0
@export var pool_depth: float = 35.0
## The POOL BOTTOM's own size in x, z and W, separate from `room_size` because the room's x
## also sets the walkway's length - widening one through the other would stretch the bridge.
## `water4d_surface.gd` draws a 120 x 120 m patch (EXTENT 60) and is unbounded through W, so
## the bottom is sized to run out as far as the surface above it does rather than stopping in
## open water with a visible edge.
@export var floor_size := Vector3(124.0, 124.0, 124.0)

@export_group("Walkway")
@export var walkway_width: float = 3.4
@export var walkway_height: float = 0.75 ## Above the water line, so the surface is below you.
@export var walkway_w_depth: float = 4.2 ## How far it reaches through W. You can walk off it.
## HEIGHT AND OPENNESS ARE THE SAME DIAL, and there is no way round it in this generator.
## Measured on this footprint: rib_height 0.88 covers 21.4%% of the view, rib_height 0.14
## covers 8.0%% - and NOTHING else moves the number. Rib thickness is inert across an eight-
## fold range (21.5 to 21.4), and so is post spacing from 3 m to 16 m. So a hip-high railing
## from this system is a fairly solid one; an open one sits at ankle height.
##
## RIB HEIGHT IS WHAT SETS HOW HIGH THE RAILS SIT, not this. "beam_max_height_ratio" is, in
## the generator's own words, a "ratio of rib_height_ratio of post_height_meters" - so with
## rib_height at 0.14 every rail landed in the bottom seventh of the post and the whole fence
## read as ankle height while its posts were 1.55 m. Raising this did nothing to fix that.
##
## ONE NUMBER FOR BOTH the fence and the slabs that stop you. They were separate literals and
## that is exactly how a railing ends up with collision at a different height from the thing
## you can see.
@export var railing_height: float = 1.0

@export_group("Pillar")
@export var pillar_size: float = 2.3
@export var pillar_at := Vector3(5.5, 5.5, 0.0) ## x, z, W.
## HIGH ENOUGH TO SEE DRY. At 0.45 m the pillar was a stub you could not find from the
## walkway, which defeats the point - the comparison that matters is its dry top against its
## drowned foot, and you need to be able to see both at once. Still small next to 14 m of
## pool.
@export var pillar_above_water: float = 1.8

@export_group("Rotation point")
@export var rotation_radius: float = 2.0
@export var rotation_speed_degrees: float = 26.0

var _water: Node4D = null


## Off when this is an ANNEX of another scene rather than a scene of its own - the Arboretum
## brings its own player, its own lights and its own sky, and a second walker standing in the
## water is not a subtle bug to miss.
@export var spawn_player: bool = true

@export_group("Creature")
## How far through W the plesiosaur may wander. MUCH smaller than its X and Z range on
## purpose: it is about 2 m thick through W, so past a few metres it is not in the player's
## slice at all. Small enough and it drifts in and out of view; large enough and it is simply
## missing most of the time. Raise it to show off exactly that, and turn the slice to find it.
@export var creature_w_range: float = 8.0
@export var creature_min_depth: float = 10.0
## Nose to tail, in metres. The model is authored at about 9.4 m, which measured as a
## thumbnail from the walkway: 20 to 40 m away through a surface that reads opaque at grazing
## angles, it could not be picked out at all. The scale is derived from the hide's own
## measured length rather than written as a factor, so editing the balls does not quietly
## change how big the animal ends up.
@export var creature_length: float = 15.0

@export_group("Gust")
## The seas a gust can whip up, taken in turn so that tapping the key keeps changing the
## weather instead of setting the same storm over and over. Indices into water4d_presets.gd:
## 2 Storm, 4 Short chop, 5 Wind sea over swell, 6 Sharp crests, 7 Crossing seas - the rough
## half of the set, since a gust that calms the sea is a strange gust.
@export var gust_presets: PackedInt32Array = PackedInt32Array([2, 4, 5, 6, 7])
## How long the blow lasts before the sea settles back to `start_preset`. A gust that never
## ends is not a gust, it is a change of weather.
@export_range(2.0, 120.0, 0.5, "suffix:s") var gust_seconds: float = 16.0
## Slow on purpose - the brief was something you can spot and then keep track of while you
## look around, not something that crosses the pool before you have turned your head.
@export var creature_speed: float = 1.5

@export_group("Water")
## The presets are open-sea sized; a 40 m room needs them much smaller. See
## water4d_surface.gd's wave_scale.
@export var wave_scale: float = 0.2
@export var start_preset: int = 1
## Clear pool water, not open sea. At 14 m straight down this leaves roughly half the blue,
## a third of the green and almost none of the red - so the floor is visible but has plainly
## lost its own colour, which is the thing worth seeing. The ocean's own defaults are about
## four times murkier and would hide the floor completely.
@export var absorption := Vector3(0.30, 0.07, 0.045)
@export var scatter_color := Color(0.03, 0.14, 0.17)
@export var scatter_strength: float = 0.07

func _ready() -> void:
	_water = get_node_or_null(^"Water") as Node4D
	# GUARDED. If the water script ever fails to parse, an unguarded call here aborts _ready()
	# and the room is never built - the player then spawns over a hole and falls out of the
	# world, which looks nothing like the actual fault and wasted a debugging round.
	if _water != null and _water.has_method(&"set_preset"):
		_water.set(&"wave_scale", wave_scale)
		_water.set(&"absorption", absorption)
		_water.set(&"scatter_color", scatter_color)
		_water.set(&"scatter_strength", scatter_strength)
		_water.call(&"set_preset", start_preset)
	_build_room()
	_build_walkway()
	_build_pillar()
	_build_triggers()
	if spawn_player:
		_build_player()
	_build_creature()


## Whips the sea up, then lets it settle back. Returns the name of the sea it raised, so the
## caller can say which one, or "" if there is no water to blow on.
##
## The surface BLENDS between presets rather than snapping - `water4d_surface.gd` chases its
## target - so both the blow and the lull arrive as the sea building and dropping, which is
## the whole reason this reads as weather rather than as a switch.
##
## EACH GUST TAKES THE NEXT SEA. Tapping the key repeatedly used to re-set the same storm,
## which looks like the key doing nothing once the sea is already up.
##
## NO `await` IN HERE. A GDScript function that awaits hands its caller a coroutine instead of
## its return value, so the name would never arrive; the wait lives in `_settle_later`, which
## is started and not awaited.
var _gust_token: int = 0
var _gust_cursor: int = -1


func gust() -> String:
	if _water == null or not _water.has_method(&"set_preset") or gust_presets.is_empty():
		return ""
	_gust_cursor = (_gust_cursor + 1) % gust_presets.size()
	var index: int = gust_presets[_gust_cursor]
	_gust_token += 1
	_water.call(&"set_preset", index)
	_settle_later(_gust_token)
	return Presets.preset_name(index)


## Puts the sea back once the blow has passed, unless another gust has taken it over since.
## The token is what makes overlapping gusts safe: the second one owns the weather, and the
## first one's timer finds the token changed and leaves a storm somebody else started alone.
func _settle_later(token: int) -> void:
	await get_tree().create_timer(gust_seconds).timeout
	if token == _gust_token and _water != null and _water.has_method(&"set_preset"):
		_water.call(&"set_preset", start_preset)


## A plesiosaur, wandering the pool.
##
## Built last, after the player, because the pilot hands the swimmer a point to look at and
## wants the player to exist by then. Its bounds come from the pool rather than from numbers
## of their own, so deepening or widening the pool moves the animal with it instead of
## leaving it swimming through the floor.
func _build_creature() -> void:
	var scene: PackedScene = load("res://sandbox/water4d/plesiosaur.tscn") as PackedScene
	if scene == null:
		push_warning("Pool room: no plesiosaur scene to put in the water.")
		return
	var creature: Node4D = scene.instantiate() as Node4D
	creature.name = "Plesiosaur"
	add_child(creature)

	# SCALE THE RIG, NOT THE ROOT. Scale lives in the basis, and the pilot overwrites the
	# root's basis every frame to point the animal along its heading - so a scale set on the
	# root survives exactly one frame. The rig below it is never written to by anything.
	var rig: Node4D = creature.get_node_or_null(^"Hide") as Node4D
	var swimmer: Node = creature.get_node_or_null(^"Swimmer")
	if rig != null and swimmer != null and swimmer.has_method(&"rest_length"):
		var built: float = swimmer.call(&"rest_length")
		if built > 0.1:
			rig.set_uniform_scale(creature_length / built)

	var pilot := Node4D.new()
	pilot.name = "Pilot"
	pilot.set_script(load("res://sandbox/water4d/plesiosaur_pilot.gd"))
	# SET BEFORE add_child: the pilot resolves its body, swimmer and player in _ready, and a
	# node added first has already run it. The room hit this with the gait clock once already.
	pilot.set(&"body_path", NodePath(".."))
	pilot.set(&"swimmer_path", NodePath("../Swimmer"))
	pilot.set(&"player_path", NodePath("../../Player"))
	# Kept well inside the floor: the animal is about 9 m long and turns slowly, so a margin
	# smaller than its own turning circle means it spends its time scraping along a clamp.
	var margin: float = 16.0
	pilot.set(&"bounds", Vector3(floor_size.x * 0.5 - margin, floor_size.y * 0.5 - margin,
			creature_w_range))
	# Clearance over the floor scaled with the animal: at 15 m long it is about 2.7 m tall and
	# banks as it turns, so the three metres that suited a 9 m one is no longer clearance.
	pilot.set(&"depth_range", Vector2(creature_min_depth,
			pool_depth - maxf(4.0, creature_length * 0.3)))
	pilot.set(&"speed", creature_speed)
	creature.add_child(pilot)


## The lab kit's walker, with its orbit camera, dropped at the near doorway.
func _build_player() -> void:
	var player: CharacterBody4D = LabPlayer.make()
	player.name = "Player"
	# The kit turns W walking off, because a lab bay leashes you to one slice. Here it is the
	# point: Q and E should carry you through W so the sea changes around you.
	player.set("w_speed_scale", 0.3)
	player.set("jump_velocity", 4.2)
	add_child(player)
	player.position = Vector4(-17.0, walkway_height + 1.0, 0.0, 0.0)


# --- materials -----------------------------------------------------------------------------

static func _material(colour: Color) -> TetraMaterial4D:
	var m := TetraMaterial4D.new()
	m.albedo_color = colour
	return m


## A solid box with collision. Everything in the room that is not fence or water is one of
## these, so the room is one idea repeated rather than a pile of special cases.
func _box(parent: Node, part: String, centre: Vector4, size: Vector4, colour: Color,
		solid: bool = true) -> StaticBody4D:
	var body := StaticBody4D.new()
	body.name = part
	body.position = centre
	parent.add_child(body)
	if solid:
		var collider := CollisionShape4D.new()
		var shape := BoxShape4D.new()
		shape.size = size
		collider.shape = shape
		body.add_child(collider)
	var mesh := BoxTetraMesh4D.new()
	mesh.size = size
	var instance := MeshInstance4D.new()
	instance.mesh = mesh
	instance.material_override = _material(colour)
	body.add_child(instance)
	return body


# --- the room ------------------------------------------------------------------------------

## THE FLOOR, AND NOTHING ELSE FOR NOW. The walls, the roof and the structural frame are
## out: they are a separate job, and until then they cost ~490k vertices and box you in while
## the railing is being worked on. The room is therefore open on every side, including
## through W - that is deliberate and temporary.
func _build_room() -> void:
	var holder := Node4D.new()
	holder.name = "Room"
	add_child(holder)

	var thickness: float = 1.0
	_box(holder, "Floor", Vector4(0.0, -pool_depth - thickness * 0.5, 0.0, 0.0),
			Vector4(floor_size.x, thickness, floor_size.y, floor_size.z),
			Color(0.30, 0.31, 0.29))

	# Markings on the pool floor, so the absorption has a ruler to work against. A floor of
	# one flat colour hides it. Spaced wider than before: at 5 m a 124 m floor wants 25 of
	# them, and from 36 m up through absorbing water that is a grey haze, not a ruler.
	var tile := Color(0.46, 0.47, 0.44)
	var stripe_gap: float = 12.0
	var stripes: int = int(floor_size.x * 0.5 / stripe_gap)
	for i in range(-stripes, stripes + 1):
		_box(holder, "FloorStripe%d" % i,
				Vector4(float(i) * stripe_gap, -pool_depth + 0.03, 0.0, 0.0),
				Vector4(0.6, 0.08, floor_size.y - 2.0, floor_size.z), tile, false)


## The walkway's footprint as a seed mesh, with the DOORWAY END LEFT OPEN.
##
## [param half] is half the footprint in x, z and W. A face is appended as its EDGE indices,
## not its corners, so each quad's four edges are made first - that is what `append_poly_cell`
## takes at dimension 2.
##
## The face at -x is simply not added. Its four edges still exist, because each is shared with
## one of the side faces, so the doorway keeps the vertical ribs that read as its jambs and
## loses only the rails that used to run across it.
func _footprint_without_entry(half: Vector3) -> ArrayPolyMesh4D:
	var mesh := ArrayPolyMesh4D.new()
	var corner: Dictionary = {}
	for i in 2:
		for j in 2:
			for k in 2:
				corner[Vector3i(i, j, k)] = mesh.append_vertex(Vector4(
						half.x if i == 1 else -half.x, 0.0,
						half.y if j == 1 else -half.y,
						half.z if k == 1 else -half.z), true)
	# Wound so that each face's normal points away from the middle, which is what the
	# generator assumes of a seed and what it computes for any face missing a normal.
	var quads: Array = [
		[Vector3i(1, 0, 0), Vector3i(1, 0, 1), Vector3i(1, 1, 1), Vector3i(1, 1, 0)],  # far end
		[Vector3i(0, 0, 0), Vector3i(0, 0, 1), Vector3i(1, 0, 1), Vector3i(1, 0, 0)],  # -z side
		[Vector3i(0, 1, 0), Vector3i(1, 1, 0), Vector3i(1, 1, 1), Vector3i(0, 1, 1)],  # +z side
		[Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(1, 1, 0), Vector3i(0, 1, 0)],  # -w side
		[Vector3i(0, 0, 1), Vector3i(0, 1, 1), Vector3i(1, 1, 1), Vector3i(1, 0, 1)],  # +w side
	]
	for quad in quads:
		var edges := PackedInt32Array()
		for n in (quad as Array).size():
			edges.append(mesh.append_edge_indices(corner[quad[n]],
					corner[quad[(n + 1) % (quad as Array).size()]], true))
		mesh.append_poly_cell(2, edges, true)
	# The ground is the XZW hyperplane here, so Y is the direction to work the normals out
	# against - not the default W.
	mesh.calculate_face_normals(Vector4(0.0, 1.0, 0.0, 0.0), false)
	return mesh


## One box fence. [param footprint] is its size in x, z and W - NOT x, y, z; see the note at
## the top of this file.
## [param coverage] is how much of each gap the horizontal beams fill: near 1 it is a wall,
## near 0 it is a handrail with air under it. [param rib] is the vertical infill's thickness
## as a share of a post's.
##
## THE RIBS ARE WHAT YOU SEE IN A SLICE. A cross-section through a fence cuts the uprights,
## so their thickness and spacing decide whether it reads as railing or as hoarding - the
## lookout tower's fence says the same thing. Thin ribs, few beams and wide spacing are what
## make the walkway see-through; the room's frame keeps the solid numbers.
func _fence(parent: Node, part: String, footprint: Vector3, at: Vector4, height: float,
		open_entry: bool,
		spacing: float, beams: int, colour: Color, post: float = 0.12,
		coverage: float = 0.94, rib: float = 0.55,
		rib_height: float = 1.0, beam_thick: float = 0.5) -> FenceGenerator4D:
	var fence := FenceGenerator4D.new()
	fence.name = part
	fence.update_automatically = false
	# AN OPEN END NEEDS A SEED MESH, because nothing in the generator opens a side. Its docs
	# and its source have no gate, gap or skip: a box footprint is closed, and the radial
	# shapes validate that their corners SURROUND the origin. What they do have is
	# INPUT_SHAPE_SEED_MESH_4D, where beams come from the seed's faces, ribs from its edges
	# and posts from its vertices - so a seed that is a box MINUS the doorway face keeps the
	# jamb ribs and the posts and simply has no rails across the opening.
	#
	# An open seed is supported, not a trick: the docs say only that
	# `is_local_point_inside` returns false for "a seed whose faces do not close up ... since
	# an open footprint encloses nothing". The railing never asks that question.
	if open_entry:
		fence.input_shape_type = FenceGenerator4D.INPUT_SHAPE_SEED_MESH_4D
		fence.seed_mesh_4d = _footprint_without_entry(footprint * 0.5)
	else:
		fence.input_shape_type = FenceGenerator4D.INPUT_SHAPE_BOX
		fence.box_size = footprint
	fence.output_mesh_type = FenceGenerator4D.OUTPUT_MESH_TETRA
	fence.desired_spacing_meters = spacing
	fence.post_height_meters = height
	fence.post_thickness_meters = post
	fence.top_footprint_ratio = 1.0
	fence.rib_height_ratio = rib_height
	fence.rib_thickness_ratio = rib
	fence.beam_thickness_ratio = beam_thick
	fence.beam_count = beams
	fence.beam_coverage = coverage
	fence.beam_max_height_ratio = 0.95
	var material := _material(colour)
	fence.post_material = material
	fence.rib_material = material
	fence.beam_material = material
	fence.position = at
	parent.add_child(fence)
	fence.update_fence_mesh_now()
	return fence


# --- the walkway and its railing --------------------------------------------------------------

func _build_walkway() -> void:
	var holder := Node4D.new()
	holder.name = "Walkway"
	add_child(holder)

	var length: float = room_size.x
	var half_z: float = walkway_width * 0.5
	var half_w: float = walkway_w_depth * 0.5
	_box(holder, "Deck", Vector4(0.0, walkway_height - 0.15, 0.0, 0.0),
			Vector4(length, 0.3, walkway_width, walkway_w_depth), Color(0.52, 0.48, 0.42))

	# ONE FENCE AROUND THE WHOLE WALKWAY, which is the shape the generator is built for.
	#
	# The version before this was four separate fences, one per side, each with a footprint
	# 0.16 m thick - and a fence around a 0.16 m sliver is two rows of posts 16 cm apart with
	# tiny ribs between them. Seen head-on that read as a wall; seen from anywhere else it
	# read as scattered splinters. The room's own frame looked right the whole time for
	# exactly the reason this now does: its footprint was a box, not a sliver.
	#
	# `box_size` is (length, width, DEPTH THROUGH W) - see the note at the top of this file -
	# so one box encloses the walkway on all four horizontal sides, the two through W
	# included.
	# ONE FENCE. How this generator actually makes a railing, read out of the builder rather
	# than guessed at:
	#
	#   ribs   a WALL along each seed edge, post_height x rib_height_ratio tall and
	#          rib_thickness across (`_build_fence_single_rib` - its 16 vertices are a 4D box
	#          spanning the edge, two thicknesses and the height).
	#   beams  horizontal sheets following the seed's faces, `beam_count` of them, each
	#          beam_each_top x beam_coverage thick, capped at
	#          post_height x rib_height_ratio x beam_max_height_ratio.
	#   posts  at the seed's vertices.
	#
	# `desired_spacing_meters` SUBDIVIDES THE FACES, not just the outline, and every sub-edge
	# gets its own rib. That is where the vertical bars come from: the ribs running across W
	# are cut by the slice as uprights. It is also where the original bug came from - the
	# ribs running along X are full-length walls, and with the walkway 4.2 m deep through W
	# and a spacing of 2.1 or 2.8, a division line landed exactly on w = 0 and put a solid
	# wall in the starting slice while every other slice missed it.
	#
	# So the spacing is chosen to straddle w = 0 rather than land on it: 4.2 / 1.4 is three
	# divisions, at w = -0.7 and +0.7. Ramon's scaffold in watchstone_4d.gd takes the other
	# way out and sets the spacing to 0, which leaves ribs only on the box's own edges.
	_fence(holder, "Railing",
			Vector3(length - 0.4, walkway_width, walkway_w_depth),
			Vector4(0.0, walkway_height, 0.0, 0.0),
			railing_height, true, 1.4, 2, Color(0.62, 0.57, 0.48), 0.10, 0.14, 0.30, 0.9, 0.5)

	# The generator makes mesh, not collision, so each side gets a slab. Thin in the
	# direction it blocks, full across the other two.
	var rail_height: float = railing_height
	var thin: float = 0.16
	var blocks := [
		["BlockZPositive", Vector4(0.0, walkway_height + rail_height * 0.5, half_z, 0.0),
				Vector4(length, rail_height, thin, walkway_w_depth)],
		["BlockZNegative", Vector4(0.0, walkway_height + rail_height * 0.5, -half_z, 0.0),
				Vector4(length, rail_height, thin, walkway_w_depth)],
		["BlockWPositive", Vector4(0.0, walkway_height + rail_height * 0.5, 0.0, half_w),
				Vector4(length, rail_height, walkway_width, thin)],
		["BlockWNegative", Vector4(0.0, walkway_height + rail_height * 0.5, 0.0, -half_w),
				Vector4(length, rail_height, walkway_width, thin)],
	]
	for block in blocks:
		var body := StaticBody4D.new()
		body.name = block[0]
		body.position = block[1]
		holder.add_child(body)
		var collider := CollisionShape4D.new()
		var shape := BoxShape4D.new()
		shape.size = block[2]
		collider.shape = shape
		body.add_child(collider)


# --- the pillar ------------------------------------------------------------------------------

## Floor to just above the surface, in one piece. The point is that a single object spans the
## whole depth, so you can see the absorption eat it from the top down without having to
## compare two things.
func _build_pillar() -> void:
	var holder := Node4D.new()
	holder.name = "Pillar"
	add_child(holder)
	var height: float = pool_depth + pillar_above_water
	_box(holder, "Shaft",
			Vector4(pillar_at.x, -pool_depth + height * 0.5, pillar_at.y, pillar_at.z),
			Vector4(pillar_size, height, pillar_size, pillar_size * 2.4),
			Color(0.88, 0.86, 0.80))
	# Bands at known heights, so the eye has marks to measure the fade against rather than
	# one smooth gradient it cannot read a distance from.
	for i in range(1, 7):
		var y: float = -pool_depth + float(i) * (height / 7.0)
		_box(holder, "Band%d" % i,
				Vector4(pillar_at.x, y, pillar_at.y, pillar_at.z),
				Vector4(pillar_size * 1.12, 0.22, pillar_size * 1.12, pillar_size * 2.4),
				Color(0.86, 0.33, 0.22), false)


# --- where the player is ------------------------------------------------------------------------

## POLLED, NOT AN Area4D. `engine_gotchas.md:95`: an Area4D never fires for a body that
## arrives by teleport, and the player is spawned straight onto the walkway, which is a
## teleport as far as the physics server is concerned - it would stand inside the trigger
## for the whole session without it ever firing. The Creation Lab and the gallery plan both
## reached the same conclusion. Two plain tests against the deck's own extents cost nothing
## and cannot miss.

func is_on_walkway(where: Vector4) -> bool:
	return (absf(where.x) <= room_size.x * 0.5
			and absf(where.z) <= walkway_width * 0.5 + 0.4
			and absf(where.w) <= walkway_w_depth * 0.5 + 0.4
			and where.y > walkway_height - 1.0 and where.y < walkway_height + 3.0)


func is_on_rotation_point(where: Vector4) -> bool:
	return is_on_walkway(where) and absf(where.x) <= rotation_radius


## A ring on the deck, so the rotation point is somewhere you can see and not just somewhere
## the HUD knows about.
func _build_triggers() -> void:
	var mark := Node4D.new()
	mark.name = "RotationMark"
	add_child(mark)
	var ring := Color(0.25, 0.72, 0.85)
	for i in range(10):
		var angle: float = TAU * float(i) / 10.0
		_box(mark, "Mark%d" % i,
				Vector4(cos(angle) * rotation_radius, walkway_height + 0.02,
						sin(angle) * (walkway_width * 0.42), 0.0),
				Vector4(0.30, 0.05, 0.30, walkway_w_depth), ring, false)
