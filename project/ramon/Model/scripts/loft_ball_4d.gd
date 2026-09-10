@tool
extends MeshInstance4D

# No `class_name` - see the note at the top of cloud_field_4d.gd.

## One cross-section of a lofted model: drag it where you want, set its size, and
## the parent rig re-lofts itself as you go.
##
## Put several of these under a node running loft_rig_4d.gd and they become the
## keyframes of a loft, chained bottom to top by height. Everything between two
## balls is generated.
##
## THE POINT OF DRAGGING IT IN W: this node's `position` places the cross-section
## in all four axes, so sliding a ball along W is how you give a model genuine
## fourth-axis structure. If every ball sits at the same W, the result is a solid
## of revolution - a nice shape, but one that presents the same 3D slice from
## every W and so reads as an ordinary 3D object however far the player rotates.
## Stagger them in W and the model becomes a different silhouette at different W.
##
## The wireframe is a preview of this cross-section only. It is hidden when the
## game runs; the built mesh lives on the parent rig, not here.

const _Builder = preload("res://ramon/Model/scripts/loft_builder_4d.gd")

const _PREVIEW_SEGMENTS: int = 24

## How far above this ball a newly added one is placed. Deliberately not zero:
## two balls at the same height would loft into a zero-thickness slab, which the
## rig refuses to build. Drag the new one wherever it belongs.
const _NEW_BALL_RISE: float = 0.5

## Adds another ball just above this one, copying its size, ready to be dragged
## into place.

## Continues the chain this ball is on.
##
## Which direction "continue" means depends on where the ball sits, and the button
## follows that so you never have to think about it: a ball belonging to the rig's
## own chain gets a SIBLING placed right after it, while a ball inside a branch gets
## a CHILD, because a branch's order comes from parenting rather than sibling order.
## Either way the new ball carries on in the direction the chain was already going.
@export_tool_button("Add ball here") var _add_ball_action: Callable = add_ball_here

## Starts a new limb hanging off this ball.
##
## The new ball is a CHILD, which is what makes it a branch rather than a
## continuation, and it lands out to the side at half this ball's radius - off the
## midline, so it earns a mirrored twin straight away and one arm becomes two.
@export_tool_button("Add branch here") var _add_branch_action: Callable = add_branch_here

## Turns this branch's generated twin into real, editable balls.
##
## Up to now a mirrored limb is authored once and reflected at build time, so the
## two sides cannot differ. This writes the reflection out as actual nodes and stops
## generating it, after which both sides are ordinary balls you can drag apart. It
## is one-way: re-pairing them means deleting one side and switching the flag back.
@export_tool_button("Detach mirror") var _detach_action: Callable = detach_mirror

## Size of this cross-section across X and Z.
@export_range(0.05, 10.0, 0.05, "or_greater") var radius: float = 1.0:
	set(value):
		radius = value
		_rebuild_preview()
		_notify_rig()

## Squashes or stretches this cross-section across its second visible axis, making
## it an ELLIPSE rather than a circle. 1.0 is round; 0.4 is a flattened blade; 2.0
## is a broad paddle.
##
## Sections do not have to agree: an elliptical section lofted to a round one
## simply rotates its way between the two, because everything between keyframes is
## generated rather than repeated. That is the normal way to author a shape that
## changes character along its length.
@export_range(0.1, 3.0, 0.05) var v_scale: float = 1.0:
	set(value):
		v_scale = value
		_rebuild_preview()
		_notify_rig()

## Scales this cross-section along W only. Away from 1.0 the section is squashed
## or stretched in the invisible axis, so slicing at different W cuts discs of
## visibly different size even where the ball has not moved.
@export_range(0.1, 3.0, 0.05) var w_scale: float = 1.0:
	set(value):
		w_scale = value
		_rebuild_preview()
		_notify_rig()

## Whether this ball STARTS a new chain rather than continuing its parent's.
##
## Without this the meaning of a ball had to be guessed from the shape of the tree -
## one child meant "carry on", two or more meant "fork". That makes a branch off the
## END of a limb impossible to express: a leaf has no other children, so the new
## ball is indistinguishable from a continuation and gets swallowed into the chain
## it was meant to leave. Recording the intent removes the guess.
##
## Set by "Add branch here", left alone by "Add ball here".
@export var starts_branch: bool = false:
	set(value):
		starts_branch = value
		_notify_rig()

## Whether the branch starting at this ball is still generated as a mirrored pair.
##
## Only meaningful on a ball that starts a branch. "Detach mirror" turns it off and
## builds the twin as real balls instead, so the two sides can then be shaped
## independently - the same trade Spore makes when you break symmetry.
@export var mirror_branch: bool = true:
	set(value):
		mirror_branch = value
		_notify_rig()

## Spins this cross-section within its own plane, in degrees.
##
## The only control you have over a section's twist: its orientation is otherwise
## entirely decided by the spine direction and the frame carried up from the
## previous section. Without roll an ellipse can only lie one way, which rules out
## twisting fins, propeller blades, curling horns and ribs that rotate along a body.
##
## Roll interpolates along a chain, so setting 0 at one ball and 90 at the next
## twists smoothly between them rather than snapping.
@export_range(-180.0, 180.0, 1.0, "suffix:°") var roll: float = 0.0:
	set(value):
		roll = value
		_rebuild_preview()
		_notify_rig()

## Squares the section off, or pinches it. 0 is round, 1 is nearly a box, -1 pinches
## it toward a star.
##
## This is a superellipsoid exponent rather than a shape dropdown, and that is the
## point: sections can only loft into one another if they share topology, so a cube
## and a sphere could never blend. An exponent keeps the vertex layout identical at
## every setting, so a round belly can flow into a square jaw with the sections in
## between simply being intermediate values.
@export_range(-1.0, 1.0, 0.05) var squareness: float = 0.0:
	set(value):
		squareness = value
		_rebuild_preview()
		_notify_rig()

## This section's colour in the built model.
##
## Only used when the rig's "Use Ball Colors" is on. Colour blends between
## neighbouring balls, so a yellow beak fading into a white head needs two balls,
## not two rigs - which is what a separate rig used to cost, along with a visible
## seam where they met.
@export var color: Color = Color(0.85, 0.85, 0.85):
	set(value):
		color = value
		_notify_rig()

## Colour of the editor preview wireframe. Has no effect on the built model.
@export var preview_color: Color = Color(0.35, 0.85, 1.0, 1.0):
	set(value):
		preview_color = value
		_rebuild_preview()

var _preview_frame: Array = []
var _mirror_preview: bool = false
var _mirror_plane: float = 0.0
var _mirror_axis: int = 0


func _ready() -> void:
	# The rig owns the real geometry; these markers are authoring aids only.
	visible = Engine.is_editor_hint()
	_rebuild_preview()


## The guide wireframe is derived from radius/v_scale/w_scale, so it does not
## belong in the saved scene either - see the same note in loft_rig_4d.gd.
func _validate_property(property: Dictionary) -> void:
	if property.name == "mesh":
		property.usage &= ~PROPERTY_USAGE_STORAGE


## NO TRANSFORM NOTIFICATION EXISTS HERE. Node3D offers set_notify_transform() and
## NOTIFICATION_TRANSFORM_CHANGED; Node4D implements neither, so there is no way
## for a ball to announce that it has been dragged. The rig therefore polls its
## balls each frame instead (see loft_rig_4d.gd). Referencing the Node3D calls
## does not fail at runtime - it fails to PARSE, and a scene whose script failed
## to parse loads its nodes as plain MeshInstance4D with every export silently
## missing, which looks exactly like "my changes do nothing".


## Read by loft_rig_4d.gd. Duck-typed rather than class-checked so the rig does
## not need a global class name to recognise its own children.
##
## Any scaling currently on the basis is folded into the returned sizes but NOT
## written back here, so the model tracks the gizmo live, in both directions, while
## the gizmo keeps its own reference frame intact. Committing it to the numbers is
## bake_basis_scale()'s job, and only once the drag has stopped.
func get_loft_section() -> Dictionary:
	# The BASIS IS HANDED OVER WHOLE rather than folded into the three numbers here.
	#
	# Folding it meant deciding which of the ball's local axes were the section's, and
	# the answer was hard-coded as (X, Z, W) with Y assumed to run along the chain.
	# That holds only for a spine that runs vertically. Once a body runs along Z - a
	# goat's, say - the frame turns with it and Y becomes a genuine section axis, so
	# scaling a ball vertically did nothing at all while the gizmo's W handle silently
	# drove its height instead.
	#
	# The builder knows the real frame, so it applies this basis to the finished
	# cross-section. That is exact for any orientation, and identical to the old
	# behaviour whenever the frame is the unaligned one.
	return {
		"center": position,
		"radius": radius,
		"v_scale": v_scale,
		"w_scale": w_scale,
		"roll": roll,
		"squareness": squareness,
		"color": color,
		"basis": basis,
	}


## Folds any scaling done with the viewport gizmo into [member radius], [member
## v_scale] and [member w_scale], then resets the basis - the same idea as applying
## a transform in Blender.
##
## ONLY EVER CALLED FROM THE RIG'S "Bake ball scaling" BUTTON, never automatically.
## Godot's scale gizmo works out each frame's basis from the state it captured when
## the drag began; resetting the basis underneath it leaves that reference stale, so
## the next frame re-applies its whole factor to an already-scaled value. That
## compounds and the radius runs away outward, never inward. Trying to detect the
## end of a drag does not save you - "nothing changed since last frame" is also true
## whenever the mouse pauses mid-drag, which reintroduces exactly that jitter.
##
## Nothing is lost by waiting: get_loft_section() already honours the basis live, so
## the model tracks the gizmo either way. Baking only moves the numbers somewhere
## legible.
##
## The Y column is deliberately ignored: a cross-section has no thickness along the
## spine, so scaling a ball vertically has nothing to act on.
func bake_basis_scale() -> void:
	# Measured against the section's ACTUAL axes, which the rig stored here on the last
	# build, rather than against a fixed guess. A chain that runs along Z has its
	# section axes turned to (X, W, Y), so scaling along the ball's local Y is a real
	# widening there while being meaningless on a vertical chain - and only the frame
	# knows which case this is.
	if _preview_frame.size() < 4:
		push_warning("Loft ball '%s' has not been built yet, so its section axes are unknown - press Build first." % name)
		return
	var scale_u: float = (basis * (_preview_frame[0] as Vector4)).length()
	var scale_v: float = (basis * (_preview_frame[1] as Vector4)).length()
	var scale_w: float = (basis * (_preview_frame[2] as Vector4)).length()
	if is_zero_approx(scale_u) or is_zero_approx(scale_v) or is_zero_approx(scale_w):
		return
	# Scaling ALONG THE CHAIN is the one direction that really is meaningless, and
	# silence about it looks like the tool refusing to work: a cross-section has no
	# thickness in the direction it is swept. To lengthen a region, move the balls
	# apart instead. Note this is the tangent, not Y - on a horizontal body Y widens.
	var unchanged: bool = (is_equal_approx(scale_u, 1.0) and is_equal_approx(scale_v, 1.0)
		and is_equal_approx(scale_w, 1.0))
	if unchanged:
		var along_chain: float = (basis * (_preview_frame[3] as Vector4)).length()
		if not is_equal_approx(along_chain, 1.0):
			push_warning("Loft ball '%s' was scaled only along the chain, which does nothing - a cross-section has no thickness in the direction it is swept. Scale it across the chain, raise its radius, or move the neighbouring balls apart." % name)
			basis = Projection.IDENTITY
		return
	# v_scale and w_scale are relative to radius, so they only take the part of
	# their own scaling that radius has not already absorbed.
	radius *= scale_u
	v_scale *= scale_v / scale_u
	w_scale *= scale_w / scale_u
	basis = Projection.IDENTITY


## True when this ball hangs off another ball rather than off the rig, which means
## it is part of a branch and its chain order comes from parenting.
func _is_in_branch() -> bool:
	var parent: Node = get_parent()
	return parent != null and parent.has_method("get_loft_section")


## The step that carries on the way the chain was already heading. Falls back to
## straight up for the very first ball, where there is no direction yet.
func _continuation_offset() -> Vector4:
	var parent: Node = get_parent()
	# INSIDE A BRANCH this ball's own position IS the step from its parent to it,
	# because a branch ball is stored relative to the ball it hangs off. Subtracting
	# the parent's position as well - which is measured against the RIG, not against
	# this ball - mixes two frames and drags every new ball downhill by however high
	# the parent sat.
	if _is_in_branch():
		if position.length() > 0.0001:
			return position
		return Vector4(0.0, _NEW_BALL_RISE, 0.0, 0.0)

	var previous: Node = null
	if parent != null:
		for sibling in parent.get_children():
			if sibling == self:
				break
			if sibling.has_method("get_loft_section"):
				previous = sibling
	if previous == null:
		return Vector4(0.0, _NEW_BALL_RISE, 0.0, 0.0)
	var heading: Vector4 = position - (previous.get_loft_section()["center"] as Vector4)
	if heading.length() < 0.0001:
		return Vector4(0.0, _NEW_BALL_RISE, 0.0, 0.0)
	return heading


func add_ball_here() -> void:
	if _is_in_branch():
		# Inside a branch the chain follows PARENTING, so carrying on means a child.
		_spawn(self, null, _continuation_offset(), radius, v_scale, "Continue loft branch")
	else:
		# In the rig's own chain the order is sibling order, so carrying on means a
		# sibling placed directly after this one - appended at the end it would join
		# the chain in the wrong place and kink it.
		_spawn(get_parent(), self, _continuation_offset(), radius, v_scale, "Add loft ball")


func add_branch_here() -> void:
	# Thrown along the rig's MIRROR AXIS, so the new limb is immediately clear of the
	# mirror plane and pairs up on the first build. Spawning it along a fixed axis
	# instead meant a rig mirroring across Z or W produced a branch sitting right on
	# its own mirror plane, which pairs unpredictably.
	var reach: float = maxf(radius * 1.5, _NEW_BALL_RISE)
	var direction := Vector4(1.0, 0.0, 0.0, 0.0)
	var rig: Node = self
	while rig != null and rig.has_method("get_loft_section"):
		rig = rig.get_parent()
	if rig != null and rig.has_method("branch_spawn_direction"):
		direction = rig.branch_spawn_direction()
	_spawn(self, null, direction * reach, maxf(radius * 0.5, 0.05), 1.0, "Add loft branch", true)


## Creates a ball under [param parent], optionally placed directly after
## [param after], and registers the whole thing with the editor's undo.
##
## REGISTERED WITH UNDO SO Ctrl+Z REMOVES IT. Adding nodes straight to the tree
## works, but it changes the scene behind the undo system's back: the new ball is
## not in the history, so undoing afterwards steps over it and can leave the
## history describing a scene that no longer matches what is on screen.
func _spawn(parent: Node, after: Node, offset: Vector4, new_radius: float, new_v_scale: float, action: String, branch_root: bool = false) -> void:
	if parent == null:
		push_warning("Loft ball '%s': nothing to attach a new ball to." % name)
		return

	var addition := MeshInstance4D.new()
	addition.set_script(get_script())
	addition.name = _next_ball_name(parent)
	addition.position = position + offset if parent != self else offset
	addition.radius = new_radius
	addition.v_scale = new_v_scale
	addition.w_scale = w_scale
	addition.starts_branch = branch_root
	addition.preview_color = preview_color

	var rig: Node = self
	while rig != null and rig.has_method("get_loft_section"):
		rig = rig.get_parent()

	if not Engine.is_editor_hint():
		parent.add_child(addition)
		if after != null:
			parent.move_child(addition, after.get_index() + 1)
		addition.owner = owner
		if rig != null and rig.has_method("request_rebuild"):
			rig.request_rebuild()
		return

	var scene_root: Node = get_tree().edited_scene_root
	var undo_redo: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	undo_redo.create_action(action)
	undo_redo.add_do_method(parent, "add_child", addition, true)
	if after != null:
		# Chains run in scene tree order, so a continuation has to land directly
		# after the ball it came from or it joins the chain in the wrong place.
		undo_redo.add_do_method(parent, "move_child", addition, after.get_index() + 1)
	if scene_root != null:
		undo_redo.add_do_method(addition, "set_owner", scene_root)
	if rig != null and rig.has_method("request_rebuild"):
		undo_redo.add_do_method(rig, "request_rebuild")
		undo_redo.add_undo_method(rig, "request_rebuild")
	undo_redo.add_do_reference(addition)
	undo_redo.add_undo_method(parent, "remove_child", addition)
	undo_redo.commit_action()

	# Select the new ball so it can be dragged straight away. Without this you add a
	# ball, then have to hunt for it in the scene tree before you can touch it, which
	# breaks the rhythm of building a limb one ball at a time.
	var selection: EditorSelection = EditorInterface.get_selection()
	selection.clear()
	selection.add_node(addition)


## A name not already used anywhere under the rig.
##
## Checking only the immediate parent's children is not enough: each ball in a limb
## is the FIRST child of the one before it, so every single one came out called
## "Branch1". Godot allows that - they are not siblings - but a scene tree full of
## identically named nodes is unreadable and impossible to talk about.
## Writes this branch's mirrored twin out as real balls and stops generating it.
func detach_mirror() -> void:
	# Being a chain head is what matters, and there are TWO ways to become one: the
	# explicit "starts_branch" flag, or implicitly by being one of several children,
	# since a ball with more than one child forks and each child heads its own chain.
	# Testing only the flag refused to detach perfectly ordinary forks.
	if not _is_branch_head():
		push_warning("Loft ball '%s' does not head a branch, so it has no twin of its own to detach. Press this on the first ball of a limb - the one directly under the ball it grows from." % name)
		return
	var rig: Node = _rig()
	if rig == null or not rig.has_method("mirror_axis_index"):
		return
	if not mirror_branch:
		push_warning("Loft ball '%s': this branch is already detached." % name)
		return

	var axis: int = rig.mirror_axis_index()
	var chain: Array[Node] = []
	var node: Node = self
	while node != null:
		chain.append(node)
		var kids: Array[Node] = []
		for child in node.get_children():
			if child.has_method("get_loft_section"):
				kids.append(child)
		node = kids[0] if kids.size() == 1 else null

	# Reflection is linear and the mirror plane passes through the anchor, so every
	# ball's own offset simply flips its component along the mirror axis. That holds
	# at any depth, which is why the whole limb can be copied in one pass.
	var undo_redo: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo() if Engine.is_editor_hint() else null
	var scene_root: Node = get_tree().edited_scene_root if Engine.is_editor_hint() else owner
	if undo_redo != null:
		undo_redo.create_action("Detach mirrored limb")

	var parent: Node = get_parent()
	var made: Array[Node] = []
	for index in range(chain.size()):
		var source: Node = chain[index]
		var copy := MeshInstance4D.new()
		copy.set_script(get_script())
		copy.name = "%s_mirror" % source.name
		copy.position = _reflect(source.position, axis)
		# EVERY section property, not just the size ones. roll, squareness and colour
		# were each added after this function was written, and a copy that silently
		# drops them turns a detached twin white and untwisted while its original is
		# neither - which is exactly what it did the first time a coloured model was
		# detached.
		copy.radius = source.radius
		copy.v_scale = source.v_scale
		copy.w_scale = source.w_scale
		copy.roll = source.roll
		copy.squareness = source.squareness
		copy.color = source.color
		copy.preview_color = source.preview_color
		copy.starts_branch = index == 0
		copy.mirror_branch = false
		made.append(copy)
		var target: Node = parent if index == 0 else made[index - 1]
		if undo_redo != null:
			undo_redo.add_do_method(target, "add_child", copy, true)
			if scene_root != null:
				undo_redo.add_do_method(copy, "set_owner", scene_root)
			undo_redo.add_do_reference(copy)
		else:
			target.add_child(copy)
			copy.owner = scene_root

	if undo_redo != null:
		undo_redo.add_do_property(self, "mirror_branch", false)
		undo_redo.add_undo_property(self, "mirror_branch", true)
		undo_redo.add_undo_method(parent, "remove_child", made[0])
		undo_redo.add_do_method(rig, "request_rebuild")
		undo_redo.add_undo_method(rig, "request_rebuild")
		undo_redo.commit_action()
	else:
		mirror_branch = false


static func _reflect(point: Vector4, axis: int) -> Vector4:
	match axis:
		1:
			return Vector4(point.x, point.y, -point.z, point.w)
		2:
			return Vector4(point.x, point.y, point.z, -point.w)
	return Vector4(-point.x, point.y, point.z, point.w)


## Whether this ball begins a branch, i.e. a chain anchored on its own parent.
##
## Asks the rig how it actually decomposes rather than trusting a flag, so a fork
## created by adding a second child counts just as much as one made with the branch
## button.
func _is_branch_head() -> bool:
	var rig: Node = _rig()
	if rig == null or not rig.has_method("_collect_chains"):
		return false
	for chain in rig._collect_chains():
		# chain[0] is the ball a branch hangs off; for the rig's own chain it is just
		# the first ball, and its successor's parent is the rig, not chain[0].
		if chain.size() > 1 and chain[1] == self and chain[1].get_parent() == chain[0]:
			return true
	return false


## The rig this ball ultimately hangs off.
func _rig() -> Node:
	var node: Node = get_parent()
	while node != null and node.has_method("get_loft_section"):
		node = node.get_parent()
	return node


func _next_ball_name(parent: Node) -> String:
	var rig: Node = self
	while rig != null and rig.has_method("get_loft_section"):
		rig = rig.get_parent()
	if rig == null:
		rig = parent
	var prefix: String = "Branch" if parent == self else "Ball"
	var index: int = 1
	while _name_taken(rig, "%s%d" % [prefix, index]):
		index += 1
	return "%s%d" % [prefix, index]


func _name_taken(node: Node, candidate: String) -> bool:
	for child in node.get_children():
		if child.name == candidate:
			return true
		if child.has_method("get_loft_section") and _name_taken(child, candidate):
			return true
	return false


func _notify_rig() -> void:
	if not is_inside_tree():
		return
	var rig: Node = get_parent()
	if rig != null and rig.has_method("request_rebuild"):
		rig.request_rebuild()


## Told by the rig whether this chain is being mirrored, so the guide can show a
## ghost of the twin. Without it a mirrored rig draws one wireframe but builds two
## limbs, and the second one looks like it came from nowhere.
func set_mirror_preview(enabled: bool, plane: float = 0.0, axis: int = 0) -> void:
	if enabled == _mirror_preview and is_equal_approx(plane, _mirror_plane) and axis == _mirror_axis:
		return
	_mirror_preview = enabled
	_mirror_plane = plane
	_mirror_axis = axis
	_rebuild_preview()


## Shares the builder's superellipsoid maths so the guide shows the section that
## will actually be built, not an idealised circle.
static func _shaped(x: float, y: float, z: float, exponent: float) -> Vector3:
	return _Builder._apply_squareness(Vector3(x, y, z), exponent)


## Handed back by the rig after each build, as [axis_u, axis_v, axis_n, tangent].
##
## Without this the guide would lie: the rig tilts each cross-section to sit square
## to the spine, so a preview drawn flat in the global axes would show a level ring
## where the actual section is tilted.
func set_preview_frame(frame: Array) -> void:
	if frame.size() < 3 or frame == _preview_frame:
		return
	_preview_frame = frame
	_rebuild_preview()


## Three great circles spanning each pair of the section's own axes. The first
## reads as the familiar outline; the other two are the only way to see how far the
## section reaches into W, which is otherwise invisible.
func _rebuild_preview() -> void:
	if not is_inside_tree():
		return
	var axis_u := Vector4(1.0, 0.0, 0.0, 0.0)
	var axis_v := Vector4(0.0, 0.0, 1.0, 0.0)
	var axis_n := Vector4(0.0, 0.0, 0.0, 1.0)
	if _preview_frame.size() >= 3:
		axis_u = _preview_frame[0]
		axis_v = _preview_frame[1]
		axis_n = _preview_frame[2]

	var turn: float = deg_to_rad(roll)
	if not is_zero_approx(turn):
		var turned_u: Vector4 = axis_u * cos(turn) + axis_v * sin(turn)
		axis_v = axis_v * cos(turn) - axis_u * sin(turn)
		axis_u = turned_u
	var exponent: float = _Builder._squareness_exponent(squareness)

	var wire := ArrayWireMesh4D.new()
	var v_radius: float = radius * v_scale
	var w_radius: float = radius * w_scale
	# The ghost sits where the mirrored twin's section will be. Local space, so the
	# offset is twice this ball's own X, backwards.
	var origins: Array[Vector4] = [Vector4()]
	if _mirror_preview:
		var own: float = position.x
		if _mirror_axis == 1:
			own = position.z
		elif _mirror_axis == 2:
			own = position.w
		var step: float = 2.0 * (_mirror_plane - own)
		if _mirror_axis == 1:
			origins.append(Vector4(0.0, 0.0, step, 0.0))
		elif _mirror_axis == 2:
			origins.append(Vector4(0.0, 0.0, 0.0, step))
		else:
			origins.append(Vector4(step, 0.0, 0.0, 0.0))
	for origin in origins:
		for segment in range(_PREVIEW_SEGMENTS):
			var from_angle: float = TAU * float(segment) / float(_PREVIEW_SEGMENTS)
			var to_angle: float = TAU * float(segment + 1) / float(_PREVIEW_SEGMENTS)
			wire.append_edge_points(
				origin + axis_u * (_shaped(cos(from_angle), sin(from_angle), 0.0, exponent).x * radius) + axis_v * (_shaped(cos(from_angle), sin(from_angle), 0.0, exponent).y * v_radius),
				origin + axis_u * (_shaped(cos(to_angle), sin(to_angle), 0.0, exponent).x * radius) + axis_v * (_shaped(cos(to_angle), sin(to_angle), 0.0, exponent).y * v_radius), true)
			wire.append_edge_points(
				origin + axis_u * (cos(from_angle) * radius) + axis_n * (sin(from_angle) * w_radius),
				origin + axis_u * (cos(to_angle) * radius) + axis_n * (sin(to_angle) * w_radius), true)
			wire.append_edge_points(
				origin + axis_v * (cos(from_angle) * v_radius) + axis_n * (sin(from_angle) * w_radius),
				origin + axis_v * (cos(to_angle) * v_radius) + axis_n * (sin(to_angle) * w_radius), true)
	# Reused rather than replaced: the preview is rebuilt every frame while a ball is
	# dragged, and allocating a fresh material each time is pure churn.
	var wire_material: WireMaterial4D = material_override as WireMaterial4D
	if wire_material == null:
		wire_material = WireMaterial4D.new()
		material_override = wire_material
	wire_material.albedo_color = preview_color
	mesh = wire
