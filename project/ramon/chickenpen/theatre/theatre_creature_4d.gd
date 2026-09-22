extends Node4D

## Trym's eight-legged creature, adopted out of the Model scene and walked on the
## theatre's turntable so a slide can point at it.
##
## ADOPTED, NOT REBUILT, for the same reason the goat is: there is already a creature in
## this repo with a full procedural animation stack wired to it, and a second one written
## from scratch here would be a worse creature making a weaker claim. The whole
## `Creature` branch is lifted out of `rigged_creature_ramon.tscn` together with its six
## solver nodes, which are added as its SIBLINGS because every one of them resolves
## `NodePath("../Creature")` - put them anywhere else in the tree and they silently find
## nothing and switch themselves off.
##
## IT IS NOT SCALED, and that is not an oversight. `ik_chain_controller.gd` solves FABRIK
## entirely in GLOBAL space while its `link_lengths` stay in the chain's own local units,
## so a uniform scale on any ancestor leaves every leg reaching for a target it can no
## longer arrive at - and the solver also writes `joints[i].global_basis` directly, which
## fights a parent scale rather than composing with it. The goat can be fitted to the
## stage because nothing solves against it. This one is placed, not sized: it stands 5.9
## long and 4.1 tall, and the exhibit is built around that.
##
## IT WALKS ON A TREADMILL. `ik_gait_driver._foot_position` slides a PLANTED foot backward
## through its stance phase - the ground moving under a creature that stays put - so it
## walks without travelling, and there is no danger of it stepping off the drum mid-slide.
##
## THE RIG UNDERNEATH IS THE RIG THAT SHAPED IT. Every segment is a `loft_rig_4d` with two
## control balls, and `loft_ball_4d._ready` hides those balls outside the editor. Showing
## them again and blanking the segment meshes is the entire "x-ray" effect - no second
## skeleton is modelled, because the handles a designer placed to shape the animal are
## literally the joints the solvers move. That is the sentence the slide is built on, and
## it is only sayable because it is true of this file.

const SOURCE := "res://ramon/Model/rigged_creature_ramon.tscn"
const SOLVERS: PackedStringArray = ["IKGaitDriver", "FootGroundSolver", "TailSway",
	"SpineNeckSolver", "IdleLayer", "HeadAttention"]
const FEET: PackedStringArray = ["ForeLA", "ForeLK", "ForeRA", "ForeRK",
	"HindLA", "HindLK", "HindRA", "HindRK"]

## The gaits the driver knows, in the order its own number keys use them.
const GAITS: PackedStringArray = ["walk", "trot", "hop", "canter_right", "canter_left"]

## Where the creature's feet should land. The drum's deck is y = 0 in the exhibit's frame
## and the creature's own ground plane is a little under its hips, so this is measured at
## build time rather than guessed.
@export var stand_on: float = 0.0
## The eight foot targets get a dot each while the rig is showing - they are the thing the
## gait actually writes, and watching them trace their Bezier arcs is most of the slide.
@export var target_color: Color = Color(1.0, 0.62, 0.24)
@export_range(0.02, 0.4, 0.01) var target_size: float = 0.14
## The bones. The control balls alone read as a scattering of small shapes once the skin is
## off - it took a picture of the finished slide to see it - so the segments are strung
## together with lines bright enough to carry the silhouette on their own.
##
## NEAR-WHITE RATHER THAN THE SLIDE'S OWN TEAL: the first pass matched the bones to the
## backdrop's colour and the skeleton disappeared into it. Three layers have to stay apart
## here - white bones, the handles in their authored colours, and the foot targets in
## amber - because each one is a different kind of thing.
@export var bone_color: Color = Color(0.94, 0.97, 1.0)
@export_range(0.5, 12.0, 0.5) var bone_thickness: float = 4.0
## And the handles are turned DOWN to let the bones carry it. Eighty-four wire spheres at
## full brightness, each drawn as a four-dimensional cross, read as static around the
## skeleton rather than as part of it. Dim and thin, they become what they are: the marks
## at the joints. Set once, because the handles are only ever seen with the skin off.
@export var handle_color: Color = Color(0.30, 0.66, 0.82)
@export_range(0.5, 8.0, 0.5) var handle_thickness: float = 1.5

var _creature: Node4D
var _gait: Node
var _segments: Array[MeshInstance4D] = []
var _skins: Array[Mesh4D] = []
var _balls: Array[MeshInstance4D] = []
var _targets: Array[MeshInstance4D] = []
var _bones: Array[MeshInstance4D] = []
var _bare: bool = false
var _tetra: int = 0
var _build_ms: float = 0.0


func _ready() -> void:
	var started: int = Time.get_ticks_usec()
	if not _adopt():
		return
	_collect()
	_stand()
	_mark()
	_skeleton()
	_build_ms = float(Time.get_ticks_usec() - started) / 1000.0
	# The lofts run in each segment's own _ready, which is AFTER this one for nodes added
	# during it - so the tetrahedra cannot be counted here. Deferred to the frame after,
	# which is also where the honest build cost shows up.
	call_deferred("_settle")


## Everything that happened after _ready returned: the 42 segments lofting themselves.
func _settle() -> void:
	_tetra = _count(_creature)
	show_rig(false)


func _adopt() -> bool:
	if not ResourceLoader.exists(SOURCE):
		push_warning("TheatreCreature: %s is missing, so there is nothing to walk." % SOURCE)
		return false
	var scene: Node = (load(SOURCE) as PackedScene).instantiate()
	var found: Node = scene.get_node_or_null("Creature")
	if found == null:
		push_warning("TheatreCreature: no Creature inside %s." % SOURCE)
		scene.free()
		return false

	# CREATURE FIRST, SOLVERS AFTER. A solver's _ready fires the moment it is added, and
	# the first thing it does is resolve ../Creature; add one before the creature is in
	# place and it finds null, warns, and turns its own _physics_process off for good.
	_hush(found)
	_disown(found)
	found.get_parent().remove_child(found)
	add_child(found)
	_own(found)
	_creature = found as Node4D

	for name in SOLVERS:
		var solver: Node = scene.get_node_or_null(String(name))
		if solver == null:
			push_warning("TheatreCreature: %s has no %s." % [SOURCE, name])
			continue
		# Two of the six put a debug Label on a CanvasLayer of their own, which in the
		# Model scene is useful and in a cinema is a caption nobody wrote. The gait driver
		# also grabs the number keys, and this presentation has its own controls.
		solver.set("show_label", false)
		solver.set("standalone_input", false)
		_disown(solver)
		solver.get_parent().remove_child(solver)
		add_child(solver)
		_own(solver)
		if String(name) == "IKGaitDriver":
			_gait = solver
	scene.free()
	return _gait != null


## Every loft rig prints five lines of self-checks per build. Forty-two of them is two
## hundred lines of console during the arrival, so they are silenced before the rigs
## reach the tree and run their first build.
func _hush(node: Node) -> void:
	if node is MeshInstance4D and node.has_method("build"):
		node.set("verbose", false)
		node.set("live_rebuild", false)
	for child in node.get_children():
		_hush(child)


func _collect() -> void:
	_segments.clear()
	_balls.clear()
	_gather(_creature)


func _gather(node: Node) -> void:
	for child in node.get_children():
		if child.has_method("get_loft_section"):
			_balls.append(child as MeshInstance4D)
		elif child is MeshInstance4D and child.has_method("build"):
			_segments.append(child as MeshInstance4D)
		_gather(child)


## Dropped onto the deck rather than scaled onto it - see the header. The height is taken
## from the control balls, which are where the surface actually reaches, and not from the
## foot targets, which sit slightly under the ground on purpose.
func _stand() -> void:
	var low: float = INF
	for ball in _balls:
		low = minf(low, ball.global_position.y - float(ball.get("radius")))
	if not is_finite(low):
		return
	_creature.position.y += stand_on - low


## A dot on each of the eight foot targets. Parented to the target itself, so it rides the
## Bezier the gait writes every frame instead of being animated a second time here.
func _mark() -> void:
	for tag in FEET:
		var target: Node4D = _creature.get_node_or_null("%sFootTarget" % tag) as Node4D
		if target == null:
			continue
		var dot := MeshInstance4D.new()
		dot.name = "Marker"
		var mesh := BoxTetraMesh4D.new()
		mesh.size = Vector4(target_size, target_size, target_size, target_size)
		dot.mesh = mesh
		var glow := TetraMaterial4D.new()
		glow.albedo_color = target_color
		dot.material_override = glow
		target.add_child(dot)
		_own(dot)
		_targets.append(dot)


## A SKELETON THAT NEVER HAS TO BE ANIMATED. Each segment gets one wire edge drawn in its
## OWN local frame, running from its first control ball to its second. That is correct for
## all time, because a segment is rigid and the solvers only ever write its BASIS - the
## local positions inside it never move. So the bones follow every FABRIK solve, every
## spine flex and every tail sway for free, with nothing per-frame on this side at all.
##
## NOTHING JOINS ONE BONE TO THE NEXT, and nothing needs to: every segment's first ball
## sits at that segment's own origin, and a child segment is parented at its parent's
## origin too, so the chain is already continuous. An earlier version drew link edges from
## each segment's far ball out to its children and produced a barrel with a line doubling
## back along itself, which is what reading the scene file rather than assuming would have
## said in the first place.
func _skeleton() -> void:
	for ball in _balls:
		var dim := WireMaterial4D.new()
		dim.albedo_color = handle_color
		dim.line_thickness = handle_thickness
		ball.material_override = dim
	for segment in _segments:
		var ends: Array[Node4D] = []
		for child in segment.get_children():
			if child.has_method("get_loft_section"):
				ends.append(child as Node4D)
		if ends.size() < 2:
			continue
		var mesh := ArrayWireMesh4D.new()
		mesh.append_edge_points(ends[0].position, ends[1].position)
		var line := MeshInstance4D.new()
		line.name = "Bone"
		line.mesh = mesh
		var ink := WireMaterial4D.new()
		ink.albedo_color = bone_color
		ink.line_thickness = bone_thickness
		line.material_override = ink
		segment.add_child(line)
		_own(line)
		_bones.append(line)


# ---------------------------------------------------------------- what the slide drives

## X-RAY. The segment MESHES are taken away rather than the segment NODES hidden, because
## `visible` propagates to children in 4D exactly as it does in 3D - hiding a segment
## would take its control balls with it, which are the only thing left to look at.
func show_rig(on: bool) -> void:
	if on == _bare and not _skins.is_empty():
		return
	_bare = on
	if on:
		_skins.clear()
		for segment in _segments:
			_skins.append(segment.mesh)
			segment.mesh = null
	else:
		for i in _segments.size():
			if i < _skins.size():
				_segments[i].mesh = _skins[i]
		_skins.clear()
	for ball in _balls:
		ball.visible = on
	for bone in _bones:
		bone.visible = on
	for dot in _targets:
		dot.visible = on


## Switches gait mid-stride. The driver leaves the cycle position alone and only rewrites
## the per-leg offsets, so a leg that was half way through a swing stays half way through
## it and the change reads as a transition rather than a cut.
func set_gait(which: String) -> void:
	if _gait == null or not _gait.has_method("apply_preset"):
		return
	if String(_gait.get("preset")) == which and not bool(_gait.get("halted")):
		return
	_gait.call("apply_preset", which)


## Stops the clock and hands the creature to idle_layer.gd, which breathes it and swishes
## its tail. Not a pause: the gait driver eases every foot home first.
func halt() -> void:
	if _gait != null:
		_gait.set("halted", true)


func gait_name() -> String:
	if _gait == null:
		return ""
	return "idle" if bool(_gait.get("halted")) else String(_gait.get("preset"))


func showing_rig() -> bool:
	return _bare


func leg_count() -> int:
	return _targets.size()


func segment_count() -> int:
	return _segments.size()


func bone_count() -> int:
	return _bones.size()


func ball_count() -> int:
	return _balls.size()


func gait_count() -> int:
	return GAITS.size()


func tetra_count() -> int:
	return _tetra


func build_ms() -> float:
	return _build_ms


func _count(node: Node) -> int:
	var total: int = 0
	var stack: Array = [node]
	while not stack.is_empty():
		var here: Node = stack.pop_back()
		if here is MeshInstance4D and (here as MeshInstance4D).mesh is TetraMesh4D:
			var mesh := (here as MeshInstance4D).mesh as TetraMesh4D
			total += mesh.get_simplex_cell_vertex_indices().size() / 4
		for child in here.get_children():
			stack.append(child)
	return total


## Strips the old scene's ownership off a branch before it is adopted, or Godot complains
## that the tree is inconsistent the moment it is added here.
func _disown(node: Node) -> void:
	node.owner = null
	for child in node.get_children():
		_disown(child)


func _own(node: Node) -> void:
	if owner != null:
		node.owner = owner
	for child in node.get_children():
		_own(child)
