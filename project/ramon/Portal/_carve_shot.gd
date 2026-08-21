extends SceneTree

## Renders what a carved panel actually looks like.
##
## _verify_chamber.gd proves a carve changes the counts; it cannot show whether
## the resulting hole reads as a clean opening or as a mangled surface, which is
## the only thing that matters for a portal aperture. Same reasoning as
## Demo/_screenshot.gd, which this borrows its warm-up and camera handling from -
## early frames render before shaders finish compiling and look like bugs that
## are not there.
##
## Carves are aimed at the voxel nearest the panel's front-centre rather than at
## an arbitrary collider, so the hole lands where a player aiming at the middle
## of the panel would put it.
##
##   godot.windows.editor.double.x86_64.console.exe --path project \
##       --script res://ramon/Portal/_carve_shot.gd -- 6 carved.png

const CHAMBER_PATH := "res://ramon/Portal/portal_chamber.tscn"
const CARVE_RADIUS := 0.6
const WARMUP_FRAMES := 30
## Metres back from the panel face to stand the camera - close enough that the
## opening fills the frame, far enough to see the rim in context.
const VIEW_DISTANCE := 4.0

var _chamber: Node = null
var _prepared: bool = false
var _frames: int = 0
var _carve_count: int = 6
var _out_name: String = "carved.png"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_carve_count = int(args[0])
	if args.size() > 1:
		_out_name = args[1]

	root.set_size(Vector2i(1600, 900))
	var packed: PackedScene = load(CHAMBER_PATH)
	if packed == null:
		printerr("CARVE SHOT: could not load ", CHAMBER_PATH)
		quit(1)
		return
	_chamber = packed.instantiate()
	root.add_child(_chamber)
	set_current_scene(_chamber)
	# The carve itself waits for the first _process frame: a node added during
	# _initialize() is not flagged as inside the tree yet, so the builder's
	# _ready() has not run and it has no panels to carve. Doing it here reported
	# "chamber built no panels" a line BEFORE the builder announced building four
	# of them - the same ordering trap _verify_hub.gd documents.


## Fires at the voxel nearest the panel's front-centre, re-picking it after every
## carve: a remesh replaces every collider node, so a reference held across a
## carve is stale by definition.
func _carve(panel: Node) -> void:
	var voxels: StaticBody4D = panel.get_node_or_null("Voxels")
	if voxels == null:
		return
	var front_offset: float = panel.thickness_half_cells * panel.cell_size
	var aim_point := Vector4(0.0, 0.0, front_offset, 0.0)
	if panel.normal_axis == 0:
		aim_point = Vector4(front_offset, 0.0, 0.0, 0.0)

	for i in range(_carve_count):
		var nearest: CollisionShape4D = null
		var nearest_distance: float = INF
		for child in voxels.get_children():
			var collider := child as CollisionShape4D
			if collider == null:
				continue
			var distance: float = (collider.position - aim_point).length()
			if distance < nearest_distance:
				nearest_distance = distance
				nearest = collider
		if nearest == null:
			break
		if not panel.carve_at_shape(nearest, CARVE_RADIUS):
			print("CARVE SHOT: carve %d refused" % (i + 1))
			break
		print("carve %d: %.0f ms, %d colliders, %d tetrahedra" % [
			i + 1, panel.last_carve_msec, panel.collider_count, panel.tetra_count])


## Detached from the player rig and parked in front of the panel, looking at it
## down -z (or -x for a side panel), which is where a player would stand.
func _place_camera(panel: Node) -> void:
	var camera: Node4D = _find_camera(_chamber)
	if camera == null:
		printerr("CARVE SHOT: no Camera4D found")
		return
	var holder: Node = camera.get_parent()
	if holder != null:
		holder.remove_child(camera)
		_chamber.add_child(camera)

	var panel_position: Vector4 = panel.position
	if panel.normal_axis == 2:
		camera.position = panel_position + Vector4(0.0, 0.0, VIEW_DISTANCE, 0.0)
		camera.basis = Projection.IDENTITY # Looks down -z.
	else:
		var side: float = signf(panel_position.x)
		camera.position = panel_position - Vector4(side * VIEW_DISTANCE, 0.0, 0.0, 0.0)
		# Yaw so -z points along -x (or +x), i.e. straight at the panel.
		camera.basis = Basis4D.from_zx(signf(side) * PI * 0.5)
	print("CARVE SHOT: camera at ", camera.position)


func _find_camera(node: Node) -> Node4D:
	if node is Camera4D:
		return node
	for child in node.get_children():
		var found := _find_camera(child)
		if found != null:
			return found
	return null


func _process(_delta: float) -> bool:
	if not _prepared:
		_prepared = true
		var builder: Node = _chamber.get_node_or_null("ChamberWorld/ChamberBuilder")
		if builder == null or builder.panels.is_empty():
			printerr("CARVE SHOT: chamber built no panels")
			quit(1)
			return true
		var panel: Node = builder.panels[0]
		_carve(panel)
		_place_camera(panel)
		return false

	_frames += 1
	if _frames < WARMUP_FRAMES:
		return false
	var image: Image = root.get_texture().get_image()
	if image == null:
		printerr("CARVE SHOT: no viewport image - running with --headless?")
		quit(1)
		return true
	var absolute := ProjectSettings.globalize_path("res://ramon/Portal/" + _out_name)
	var err := image.save_png(absolute)
	if err != OK:
		printerr("CARVE SHOT: save failed (%d)" % err)
		quit(1)
		return true
	print("CARVE SHOT: wrote ", absolute)
	quit(0)
	return true
