extends SceneTree

## Headless check and measurement pass for Portal Chamber 01, milestone A.
##
## Structure is only half the job here. The chamber exists to answer one
## question - does VoxelMining's per-hit carve-and-remesh survive being
## multiplied up to room scale, given that VoxelMining has only ever run a
## single block - so this also fires a few carves and reports what they cost.
## Those numbers are the deliverable; the pass/fail assertions just stop a
## broken build being measured.
##
## Checks run on the first _process frame rather than in _initialize(): nodes
## added during _initialize() are not flagged as inside the tree yet, so _ready()
## has not fired and the builder has not built anything - the same trap
## _verify_hub.gd documents.
##
## Headless has no renderer and no physics stepping, so this proves counts,
## timings and tree structure only. Whether the room LOOKS like a room, and
## whether the player can walk on the shell, still need Play mode.
##
## Run with the editor CLOSED - two Godot processes on one .godot cache is what
## silently breaks @tool buttons in a running editor:
##
##   engine/godot/bin/godot.windows.editor.double.x86_64.console.exe \
##       --headless --path project --script res://ramon/Portal/_verify_chamber.gd

const CHAMBER_PATH := "res://ramon/Portal/portal_chamber.tscn"
const EXPECTED_PANELS := 4
const CARVE_SAMPLE_COUNT := 3
const CARVE_RADIUS := 0.6

var _chamber: Node = null
var _failed: bool = false


func _initialize() -> void:
	print("checking: ", CHAMBER_PATH)
	var packed: PackedScene = load(CHAMBER_PATH)
	if packed == null:
		printerr("VERIFY: could not load ", CHAMBER_PATH)
		_failed = true
		return
	_chamber = packed.instantiate()
	root.add_child(_chamber)


func _process(_delta: float) -> bool:
	if _failed or _chamber == null:
		quit(1)
		return true
	var builder: Node = _chamber.get_node_or_null("ChamberWorld/ChamberBuilder")
	if builder == null:
		printerr("VERIFY FAIL: no ChamberWorld/ChamberBuilder in the scene")
		quit(1)
		return true

	_report_build(builder)
	_check_shell(builder)
	_check_panels(builder)
	_measure_carves(builder)
	_check_nothing_is_owned(builder)

	print("")
	print("VERIFY: ", "FAILED" if _failed else "PASSED")
	quit(1 if _failed else 0)
	return true


func _fail(message: String) -> void:
	printerr("VERIFY FAIL: ", message)
	_failed = true


func _report_build(builder: Node) -> void:
	print("")
	print("--- build ---")
	print("panels          %d" % builder.panels.size())
	print("colliders       %d" % builder.total_collider_count())
	print("tetrahedra      %d" % builder.total_tetra_count())
	print("initial build   %.0f ms" % builder.build_msec)


## The shell must be ordinary boxes with a large w extent, because a room that
## stops existing when the player moves in w is not a room. Counting the static
## bodies that are NOT panels is the cheapest proxy for "the shell got built".
func _check_shell(builder: Node) -> void:
	var shell_bodies := 0
	for child in builder.get_children():
		if child is StaticBody4D:
			shell_bodies += 1
	print("shell boxes     %d" % shell_bodies)
	if shell_bodies < 6:
		_fail("expected at least 6 shell boxes (floor, ceiling, 4 walls), found %d" % shell_bodies)


func _check_panels(builder: Node) -> void:
	print("")
	print("--- panels ---")
	if builder.panels.size() != EXPECTED_PANELS:
		_fail("expected %d panels, found %d" % [EXPECTED_PANELS, builder.panels.size()])
	for panel in builder.panels:
		var surface: MeshInstance4D = panel.get_node_or_null("Surface")
		var voxels: StaticBody4D = panel.get_node_or_null("Voxels")
		var has_mesh: bool = surface != null and surface.mesh != null
		print("%-8s colliders %4d   tetrahedra %5d   remesh %5.0f ms   mesh %s" % [
			panel.name, panel.collider_count, panel.tetra_count, panel.last_remesh_msec,
			"yes" if has_mesh else "NO"])
		if not has_mesh:
			_fail("%s built no mesh - the slab layer produced no sign-changing cells" % panel.name)
		if voxels == null or voxels.get_child_count() == 0:
			_fail("%s built no colliders - nothing could be shot or stood on" % panel.name)
		if panel.collider_count != (voxels.get_child_count() if voxels != null else -1):
			_fail("%s collider_count disagrees with its actual child count" % panel.name)


## The measurement this milestone exists for. Carves are fired at real collider
## nodes, exactly as a raycast would hand them over, so the cost measured here is
## the cost a player pays per shot.
func _measure_carves(builder: Node) -> void:
	print("")
	print("--- carves (panel 1) ---")
	if builder.panels.is_empty():
		return
	var panel: Node = builder.panels[0]
	var voxels: StaticBody4D = panel.get_node_or_null("Voxels")
	if voxels == null or voxels.get_child_count() == 0:
		return

	for i in range(CARVE_SAMPLE_COUNT):
		var colliders: Array[Node] = voxels.get_children()
		if colliders.is_empty():
			_fail("panel ran out of colliders after %d carves" % i)
			return
		# Middle of the list rather than the first: the first collider is a
		# corner voxel, and a corner carve removes less than a face-centre one,
		# which would flatter the timing.
		var target: CollisionShape4D = colliders[colliders.size() / 2]
		var before: int = panel.collider_count
		var carved: bool = panel.carve_at_shape(target, CARVE_RADIUS)
		if not carved:
			_fail("carve %d was refused - the collider/grid-point map is out of step" % (i + 1))
			return
		print("carve %d  %5.0f ms   colliders %4d -> %4d   tetrahedra %5d" % [
			i + 1, panel.last_carve_msec, before, panel.collider_count, panel.tetra_count])


## Everything the chamber builds is generated at runtime and must not be owned by
## the scene, or it would serialise into the .tscn - which is how the skydome
## silently broke (see follow_up/engine_gotchas.md: a MeshInstance4D with a
## non-null mesh on load skips its own generate() and every setup step inside it).
func _check_nothing_is_owned(builder: Node) -> void:
	var owned := 0
	for child in builder.get_children():
		if child.owner != null:
			owned += 1
	print("")
	print("generated nodes owned by the scene: %d (must be 0)" % owned)
	if owned != 0:
		_fail("%d generated nodes are owned by the scene and would be serialised" % owned)
