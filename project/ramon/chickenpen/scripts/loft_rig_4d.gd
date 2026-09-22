@tool
# COPIED INTO chickenpen SO THE SCENE OWNS EVERYTHING IT NEEDS. The original lives at
# res://ramon/Model/scripts/loft_rig_4d.gd and is what animation_test still uses. The two are
# now separate files: a change to the pig in one scene does NOT reach the other.
extends MeshInstance4D

# No `class_name` - see the note at the top of cloud_field_4d.gd.

## Builds a 4D model from the balls placed under it, live as you drag them.
##
## HOW TO USE: add child nodes running loft_ball_4d.gd (or press "Add ball here"
## on one that already exists), drag them where you want, set each one's radius.
## The balls are the cross-sections you are authoring; everything between them is
## generated, and the model re-lofts itself whenever one of them changes.
##
## Balls are chained in order of HEIGHT, lowest first, regardless of the order
## they appear in the scene tree - so you can add one in the middle later without
## reordering anything. Their X, Z and W positions are free: a stack that drifts
## sideways as it rises gives a leaning model, and one that drifts through W gives
## a model that changes shape as the player slice-rotates.
##
## This is the operation a boat builder calls lofting - draw a few stations, let
## the planking follow - lifted one dimension. In 3D you loft 2D outlines into a
## 3D surface; here we loft 3D cross-sections into a 4D one.

const _Builder = preload("res://ramon/chickenpen/scripts/loft_builder_4d.gd")
## Preloaded for its SYMMETRY_* constants only - the rig still duck-types its
## children, so this creates no requirement that a ball BE this script. Sharing the
## constants is the point: two copies of the enum is how the two files drift apart
## and silently stop agreeing about what "3" means.
const _Ball = preload("res://ramon/chickenpen/scripts/loft_ball_4d.gd")

## How far off X = 0 a ball must sit before the chain counts as off-centre and
## earns a mirrored twin.
const _MIDLINE_EPSILON: float = 0.001

## How close two consecutive balls must be before the section between them is
## treated as degenerate rather than lofted.
const _COINCIDENT_EPSILON: float = 0.0001

## Adds a ball to the end of this rig's own chain. Press it twice on a fresh rig
## and you have a shape; after that the buttons on the balls themselves are
## usually what you want, since they can continue a limb or start one.
@export_tool_button("Add ball") var _add_ball_action: Callable = add_ball

@export_tool_button("Build") var _build_action: Callable = build

## Sends the 4D editor viewport back to its default slice.
@export_tool_button("Reset 4D view") var _reset_view_action: Callable = reset_view
@export_tool_button("Bake ball scaling") var _bake_action: Callable = bake_ball_scaling

## Re-lofts automatically whenever a ball moves, resizes, or is added or removed.
## Rebuilds are coalesced to at most one per frame, so dragging a ball costs one
## build per frame rather than one per mouse event.
##
## Cost scales with resolution: roughly 13 ms at the default 12 x 6, but about
## 106 ms at 32 x 16. If a heavy model starts to feel sticky while dragging, turn
## this off and use the Build button, or author at a low resolution and raise it
## once the shape is right.
@export var live_rebuild: bool = true:
	set(value):
		live_rebuild = value
		if live_rebuild:
			request_rebuild()

## Drops the built model so the balls underneath can be clicked on.
##
## WHY THIS IS NEEDED: the 4D viewport picks by BOUNDING BOX. `MeshInstance4D` never
## overrides `raycast_intersects_local`, so the final picking pass falls back to
## `Node4D`'s axis-aligned box test - and this rig's box contains every one of its
## balls. Whenever the ray meets the built surface the rig wins, and the ball inside
## it can never be reached. It also makes shift-clicking balls look broken, because
## every click re-selects the same rig instead of adding a ball.
##
## With no mesh the rig has no bounds, so the viewport stops gathering it entirely and
## the balls become freely clickable - including tips buried inside the body, which
## cannot be reached any other way except from the Scene tree.
##
## Rebuilding is skipped outright while this is on, not just hidden, so dragging balls
## in this mode costs nothing at all. The guide wireframes still follow their balls.
## Turn it off to see the model again.
@export var edit_balls_only: bool = false:
	set(value):
		edit_balls_only = value
		request_rebuild()

## Builds a mirrored copy of this chain across the X = 0 plane.
##
## Spore makes bilateral symmetry the DEFAULT rather than a toggle you have to
## remember, and follows one rule worth copying exactly: a part sitting on the
## midline stays single, and only an off-centre part gets mirrored. So a chain
## whose balls are all at X = 0 - a body, a neck, a beak - is left alone
## automatically, and only something you have deliberately moved off-centre, like
## a leg or a wing, gets a twin. You author one side.
##
## The mirror is lofted as its own chain rather than reflecting the mesh, because
## reflecting a mesh inverts its orientation and would render the copy inside-out.
## Built separately, it is its own connected component and the winding pass sorts
## its outward direction on its own.
@export var mirror_x: bool = true:
	set(value):
		mirror_x = value
		request_rebuild()

## Which axis the mirror reflects across. X is bilateral symmetry - left and right
## - and is what a creature normally wants. Z mirrors front to back, W mirrors
## across the axis you cannot see.
##
## The mirror plane always passes THROUGH the ball a branch hangs off, so a limb's
## twin is guaranteed to meet the body at the same point. Only the rig's own chain,
## which has no anchor, reflects about the rig's origin.
##
## THIS PROPERTY HAS A SECOND MEANING for a branch set to Cyclic or Dihedral: it
## becomes the EXCLUDED axis. The axis it names is the one that stays fixed, and the
## ring sweeps the plane of the other two. Y is never involved either way, because
## the player only rotates within XZW and Y is therefore the model's stable up.
##
## So X here means a Cn/Dn ring sweeping the (Z, W) plane: X stays head-to-tail, Y
## stays up, and the limbs go round through the axis you cannot see. That is the
## arrangement the Cn/Dn horse prototypes used. It is a reinterpretation rather than
## a new property on purpose - the inspector does not need two axis pickers that are
## the same choice worded differently.
@export_enum("X", "Z", "W") var mirror_axis: int = 0:
	set(value):
		mirror_axis = value
		request_rebuild()

## Draws a ghost of each mirrored section where its twin will be.
##
## OFF BY DEFAULT, because it costs more than it gives. The ghost is part of the
## ball's own wire mesh, so switching it on doubles that ball's clickable footprint
## and scatters it across two separate places - and when one ball's ghost lands over
## another ball, clicking the second selects the first. Turn it on when you want to
## see where a twin lands, off while you are actually placing balls.
@export var show_mirror_ghost: bool = false:
	set(value):
		show_mirror_ghost = value
		request_rebuild()

## Which way "Add branch here" throws a new limb.
##
## The default follows the mirror axis, so a new limb lands clear of the mirror
## plane and pairs up immediately. Choose an explicit direction to grow something
## that is NOT a pair - a neck or a tail along +Y or -Z stays on the mirror plane,
## so it stays single, which is usually what you want for it.
@export_enum("Along mirror axis", "+X", "-X", "+Y", "-Y", "+Z", "-Z", "+W", "-W")
var new_branch_direction: int = 0

## Builds the model as if every ball sat at W = 0, so it reads as a plain 3D shape.
##
## WHY THIS IS A BUILD MODE AND NOT A BUTTON THAT MOVES THINGS: nothing is edited. The
## balls keep the W you authored; only the loft is generated flat. Tick it to judge a
## silhouette, untick it and the fourth axis is exactly as it was. Nothing to undo,
## nothing to lose.
##
## It exists because the 4D editor has no way back to a default slice from a script.
## EditorCamera4D and EditorMainViewport4D expose NOTHING to GDScript - neither has a
## _bind_methods at all - and the camera rewrites its own position every frame lerping
## toward a target that is not bound either, so a tool button cannot steer the view. It
## can, however, change what the view is being pointed AT, which comes to the same
## thing for judging a shape.
##
## For the camera itself, the reliable route is the editor's own Layout menu ->
## "Preset: Ground View", which is a menu item rather than the corner axis ball. That
## ball is effectively broken: pressing inside it starts an orbit immediately, and any
## mouse movement at all clears the focused axis before the release that would have
## snapped the view.
@export var flatten_w: bool = false:
	set(value):
		flatten_w = value
		request_rebuild()

## Tilts each cross-section to sit square to the line the balls make, instead of
## leaving it a flat horizontal slice.
##
## Leave this ON. With it off, a stack that leans comes out SHEARED - the outline
## stays level while the body runs diagonally, so the model reads as a squashed
## tube rather than a round one following its own centreline. A perfectly vertical
## stack is unaffected either way, so this only starts mattering once you drag a
## ball sideways or through W. Turn it off if you specifically want flat level
## slices, e.g. for a stepped or terraced shape.
@export var align_to_spine: bool = true:
	set(value):
		align_to_spine = value
		request_rebuild()

## Colours the model from the balls instead of one flat colour for the whole rig.
##
## Set `color` on each ball; the rig bakes those into a ramp texture and points the
## material at it, fading between neighbouring balls along the chain. See
## [method _apply_ball_colors] for why it goes through a texture and not the
## material's per-cell colour array, which is stored but never drawn.
##
## OFF BY DEFAULT because it WRITES TO THE MATERIAL - it sets the albedo source and
## replaces the albedo texture on every rebuild. If the same material resource is
## shared with another rig, both will fight over it; give a rig its own material
## before switching this on.
##
## This is what a merged chain costs you today: the chicken's comb turned white the
## moment it joined the neck, because a rig has one colour. It also becomes
## unavoidable once limbs fuse into a single surface.
@export var use_ball_colors: bool = false:
	set(value):
		use_ball_colors = value
		request_rebuild()

## How many sections to generate per span between two balls.
##
## GEOMETRIC, not shading: it inserts real cross-sections along a curve through the
## balls, so the model actually becomes curved rather than merely looking it. At 1
## each span is a straight cone, which is why a neck needs six balls and still
## creases at every one; at 3 or 4 the same three balls describe a smooth curve.
##
## Cost is close to linear - 3 triples the tetrahedra of a chain - so raise it once
## a shape is roughed out rather than while dragging balls around.
@export_range(1, 8, 1) var smoothing: int = 1:
	set(value):
		smoothing = value
		request_rebuild()

## Vertices around the cross-section's X/Z circle. THIS IS THE ROUNDNESS YOU CAN
## SEE - at W = 0 the silhouette is literally a polygon with this many sides, so 6
## reads as a visible hexagon and 8 is about the lowest that still passes as round.
## Raise it at the end on anything that gets looked at closely.
@export_range(4, 32, 1) var profile_sides: int = 8:
	set(value):
		profile_sides = value
		request_rebuild()

## Rings from pole to pole of the cross-section, which run along W.
##
## Cheaper to spend than sides, because W is invisible within any one slice: this
## only controls how smoothly a section's size changes as the player travels
## through the fourth axis. Cost is linear in (rings - 1), so dropping 6 to 4 halves
## the whole model for nothing you can see standing still.
@export_range(3, 16, 1) var profile_rings: int = 4:
	set(value):
		profile_rings = value
		request_rebuild()

## Collapses the lowest and highest cross-sections to a point each, closing the
## model off. Without it the surface is left open at both ends, and an opening
## breaks cross-section tracing across a far larger region than its own size.
@export var taper_ends: bool = true:
	set(value):
		taper_ends = value
		request_rebuild()

## Prints the watertightness and winding reports to the Output panel. Both checks
## always run whatever this is set to - it only controls whether a CLEAN result is
## announced, and live rebuilds stay quiet regardless so dragging a ball does not
## flood the log. Real problems are pushed as warnings either way.
@export var verbose: bool = true

var _dirty: bool = false
var _last_signature: PackedFloat64Array = PackedFloat64Array()


func _ready() -> void:
	# ALWAYS rebuild, never "only if empty". The mesh is derived from the balls, so
	# anything already sitting there is by definition out of date the moment the
	# script that made it changes - and a stale mesh is invisible, because it looks
	# like a perfectly good model that simply ignores your edits.
	if get_child_count() > 0:
		build()


## Keeps the generated mesh OUT of the saved scene.
##
## It is derived data: it can always be rebuilt from the balls, it bloated this
## scene from 9 KB to 2.4 MB, and worse, a saved copy silently masks the real one
## on load. Marking it non-storable means the scene records only the balls, which
## is the actual source.
func _validate_property(property: Dictionary) -> void:
	if property.name == "mesh":
		property.usage &= ~PROPERTY_USAGE_STORAGE


func _notification(what: int) -> void:
	# Catches balls being added (including by "Add ball here") and deleted.
	if what == NOTIFICATION_CHILD_ORDER_CHANGED:
		request_rebuild()


## Marks the model as needing a rebuild on the next frame.
func request_rebuild() -> void:
	_dirty = true


## WHY THIS POLLS RATHER THAN LISTENING: Node4D has no transform notification.
## Node3D offers set_notify_transform() and NOTIFICATION_TRANSFORM_CHANGED, but
## Node4D implements neither, so a ball genuinely cannot announce that it has been
## dragged. Comparing a short signature each frame costs six floats per ball and
## catches everything - viewport drags, inspector edits, undo - where a
## notification would catch nothing at all.
func _process(_delta: float) -> void:
	if not live_rebuild:
		return
	var signature: PackedFloat64Array = _section_signature()
	if signature != _last_signature:
		_last_signature = signature
		_dirty = true
	if not _dirty:
		return
	_dirty = false
	build(false)


## Folds every ball's gizmo scaling into its radius/v_scale/w_scale numbers and
## resets its basis, the way Blender's Apply Transform does.
##
## DELIBERATELY MANUAL. Doing this automatically means guessing when a drag has
## ended, and the obvious guess - "nothing changed since last frame" - is wrong the
## moment you pause the mouse mid-drag: the bake fires, the gizmo's captured
## reference goes stale, and its next frame re-applies the whole factor to an
## already-scaled value. That compounds and jitters. Nothing writes to a basis
## unless you press this, so the gizmo is never fought.
##
## Pressing it changes no shape - the scaling is already being honoured live. It
## only moves the numbers out of sixteen basis floats and into the inspector.
func bake_ball_scaling() -> void:
	for ball in _all_balls(self):
		ball.bake_basis_scale()
	request_rebuild()


## Every ball anywhere under [param node], depth first. Balls can parent other
## balls to make a branch, so the tree has to be walked rather than just the rig's
## own children.
func _all_balls(node: Node) -> Array[Node]:
	var found: Array[Node] = []
	for child in node.get_children():
		if child.has_method("get_loft_section"):
			found.append(child)
			found.append_array(_all_balls(child))
	return found


func _ball_children(node: Node) -> Array[Node]:
	var found: Array[Node] = []
	for child in node.get_children():
		if child.has_method("get_loft_section"):
			found.append(child)
	return found


## Splits the ball tree into chains, each of which is lofted as one surface.
##
## The rig's own ball children are one chain, in SCENE TREE ORDER. Beyond that,
## PARENTING A BALL TO ANOTHER BALL STARTS A BRANCH: a limb, a neck, a tail. A
## branch chain begins at the ball it hangs off - so the limb emerges from inside
## its parent rather than floating beside it - and then follows the parenting down.
## Where a ball has several children, each one starts its own branch.
##
## ORDER ALWAYS COMES FROM THE SCENE TREE, NEVER FROM GEOMETRY. Sorting the root
## chain by height, as this used to, meant dragging a body ball past its neighbour
## silently rewired the chain mid-drag: the surface would suddenly run
## Ball2 -> Ball1 -> Ball3, doubling back through itself, which reads as the model
## tearing open for no reason. Position should never decide topology. It also means
## a chain is free to run in any direction, or double back, since nothing requires
## it to climb.
##
## Chains overlap at the ball they share rather than fusing into one surface. That
## is the same compromise Spore avoids entirely by summing metaball fields instead
## of joining meshes, and is the thing a Fuse pass would fix.
func _collect_chains() -> Array:
	var chains: Array = []
	var roots: Array[Node] = _ball_children(self)
	if roots.size() >= 2:
		chains.append(roots)
	for ball in roots:
		_collect_branches(ball, chains)
	return chains


func _collect_branches(anchor: Node, chains: Array) -> void:
	for kid in _ball_children(anchor):
		var chain: Array[Node] = [anchor]
		var current: Node = kid
		while true:
			chain.append(current)
			var next_balls: Array[Node] = _ball_children(current)
			# Carry on only through a single child that is NOT itself a branch root.
			# A ball marked as starting a branch begins its own chain even when it is
			# the only child, which is what makes a limb off the END of another limb
			# possible at all.
			if next_balls.size() != 1 or bool(next_balls[0].starts_branch):
				break
			current = next_balls[0]
		chains.append(chain)
		_collect_branches(current, chains)


func _section_signature() -> PackedFloat64Array:
	var signature := PackedFloat64Array()
	for child in _all_balls(self):
		var section: Dictionary = child.get_loft_section()
		var center: Vector4 = section["center"]
		# The WHOLE basis, all sixteen numbers, not a few axis lengths. Recording only
		# the X, Z and W lengths meant a ball scaled along Y produced an identical
		# signature, so no rebuild was even attempted - the gizmo appeared dead. Axis
		# lengths also miss a ball being rotated or sheared, which the builder now
		# honours. Sixteen floats per ball is nothing next to rebuilding the mesh.
		var ball_basis: Projection = child.basis
		signature.append_array(PackedFloat64Array([
			center.x, center.y, center.z, center.w,
			section["radius"], section.get("v_scale", 1.0), section["w_scale"],
			ball_basis.x.x, ball_basis.x.y, ball_basis.x.z, ball_basis.x.w,
			ball_basis.y.x, ball_basis.y.y, ball_basis.y.z, ball_basis.y.w,
			ball_basis.z.x, ball_basis.z.y, ball_basis.z.z, ball_basis.z.w,
			ball_basis.w.x, ball_basis.w.y, ball_basis.w.z, ball_basis.w.w,
		]))
	return signature


## The 4D editor's own "Preset: Ground View" command, and the one that follows it back
## to a single viewport. Their ids, from EditorMainScreen4D's LayoutItem enum.
const _LAYOUT_GROUND_VIEW: int = 6
const _LAYOUT_ONE_VIEWPORT: int = 0


## Sends the 4D editor viewport back to its default slice - Y up, no slice rotation.
##
## HOW, given the camera cannot be touched: EditorCamera4D and EditorMainViewport4D
## expose nothing to GDScript at all - neither has a _bind_methods - and the camera
## rewrites its own transform every frame lerping toward an unbound target, so setting
## its position or basis from here would be undone immediately.
##
## What IS reachable is the editor's own menu. The Layout menu's "Preset: Ground View"
## resets viewport 0 to the Y ground axis, and it is dispatched from an ordinary
## PopupMenu id_pressed signal - fully bound, like any other Control. So this fires that
## command rather than trying to steer the camera, then follows it with the
## single-viewport item so the reset lands without leaving four panes behind.
##
## This is a workaround for a real gap: the module never persists the 4D camera, so
## there is no stored default to return to and a fresh editor process is otherwise the
## only way back. See project/ramon/follow_up/ for the note to Aaron.
func reset_view() -> void:
	if not Engine.is_editor_hint():
		return
	var popup: PopupMenu = _find_layout_popup(EditorInterface.get_base_control())
	if popup == null:
		push_warning("Loft rig '%s': could not find the 4D editor's Layout menu, so the view was left alone. Open the 4D editor tab first." % name)
		return
	popup.id_pressed.emit(_LAYOUT_GROUND_VIEW)
	popup.id_pressed.emit(_LAYOUT_ONE_VIEWPORT)


## Finds the 4D editor's Layout menu by looking for the item it alone carries, rather
## than by node path - the editor's own tree shape is not ours to depend on.
func _find_layout_popup(node: Node) -> PopupMenu:
	var popup: PopupMenu = node as PopupMenu
	if popup != null:
		for index in range(popup.item_count):
			if popup.get_item_text(index).contains("Ground View"):
				return popup
	for child in node.get_children(true):
		var found: PopupMenu = _find_layout_popup(child)
		if found != null:
			return found
	return null


## Adds a ball at the end of this rig's chain, stacked above the last one.
##
## Exists because every other way of adding a ball hangs off an existing ball, so a
## brand new rig had no way to get started without hand-building a MeshInstance4D
## and attaching the script to it.
func add_ball() -> void:
	var existing: Array[Node] = _ball_children(self)
	var addition := MeshInstance4D.new()
	addition.set_script(load("res://ramon/chickenpen/scripts/loft_ball_4d.gd"))
	addition.name = "Ball%d" % (existing.size() + 1)
	if existing.is_empty():
		addition.position = Vector4()
		addition.radius = 0.5
	else:
		var last: Node = existing[existing.size() - 1]
		addition.position = last.position + Vector4(0.0, last.radius * 2.0, 0.0, 0.0)
		addition.radius = last.radius

	if not Engine.is_editor_hint():
		add_child(addition)
		addition.owner = owner
		request_rebuild()
		return

	var scene_root: Node = get_tree().edited_scene_root
	var undo_redo: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("Add loft ball")
	undo_redo.add_do_method(self, "add_child", addition, true)
	if scene_root != null:
		undo_redo.add_do_method(addition, "set_owner", scene_root)
	undo_redo.add_do_method(self, "request_rebuild")
	undo_redo.add_do_reference(addition)
	undo_redo.add_undo_method(self, "remove_child", addition)
	undo_redo.add_undo_method(self, "request_rebuild")
	undo_redo.commit_action()

	# Select it, so the next thing you do lands on the ball you just made.
	var selection: EditorSelection = EditorInterface.get_selection()
	selection.clear()
	selection.add_node(addition)


## Bakes the balls' colours into a ramp texture and points the material at it.
##
## WHY A TEXTURE AND NOT THE PER-CELL COLOUR ARRAY: the per-cell array is stored and
## validated but never drawn. The 3D proxy mesh that actually reaches the GPU has no
## channel left to carry it - Custom 0-3 hold the cell's four 4D positions and
## UV/UV2/Normal/Colour hold the UVW texture coordinates, which is the whole vertex
## format - and the material only ever hands the shader one flat albedo plus one
## sampler3D. Texture lookup is the one multi-colour path the renderer has.
##
## THE ARTIST NEVER SEES THIS TEXTURE. It is one texel per section, generated fresh on
## every rebuild from the balls' own `color` properties; nobody paints it, unwraps it
## or opens it. Each section was given the coordinate of its own texel's centre, so a
## ball's colour lands on that ball exactly and the sampler's linear filter fades
## between neighbours along the chain.
##
## The pool of coordinate values is rewritten here rather than in the builder because
## a rig's chains are lofted separately and merged: each chain numbers its sections
## from zero, so only once everything is merged is it known how wide the ramp is and
## where each chain sits along it. Merging concatenates the pool in chain order, which
## is the same order the colours were collected in, so entry k is section k.
##
## TETRA_COLOR_SOURCE_TEXTURE3D_CELL_UVW_ONLY is 3 in the material's enum.
func _apply_ball_colors(built: ArrayTetraMesh4D, ramp: PackedColorArray) -> void:
	var material: Material4D = material_override
	if material == null or not (material is TetraMaterial4D):
		push_warning("Loft rig '%s': ball colours need a TetraMaterial4D in Material Override." % name)
		return
	var pool: PackedVector3Array = built.get_texture_map_values()
	if ramp.size() != pool.size():
		push_warning("Loft rig '%s': %d ramp colours for %d texture coordinates - colours skipped." % [
			name, ramp.size(), pool.size()])
		return
	if pool.is_empty():
		return

	var spread := PackedVector3Array()
	spread.resize(pool.size())
	for index in range(pool.size()):
		spread[index] = Vector3((float(index) + 0.5) / float(pool.size()), 0.5, 0.5)
	built.set_texture_map_values(spread)

	var image: Image = Image.create(pool.size(), 1, false, Image.FORMAT_RGBA8)
	for index in range(ramp.size()):
		image.set_pixel(index, 0, ramp[index])
	var texture := ImageTexture3D.new()
	texture.create(Image.FORMAT_RGBA8, pool.size(), 1, 1, false, [image])
	material.set("albedo_source", 3)
	material.set("albedo_texture_3d", texture)
	# Kept on the mesh as the record of what was baked. A Texture3D cannot be read back
	# without a real rendering server, so this is the only way to check the ramp from a
	# headless run - and it is what tells you which ball a stray colour came from.
	built.set_meta("loft_ramp", ramp)


## Collects the balls, sorts them by height, and lofts between them.
##
## [param announce] is false for live rebuilds, which keeps a clean result quiet
## while still surfacing genuine problems as warnings.
func build(announce: bool = true) -> void:
	if not is_inside_tree():
		return
	_dirty = false
	if edit_balls_only:
		# No mesh means no bounds, which is what takes this rig out of the viewport's
		# picking entirely. Previews are still refreshed so the guides do not go stale.
		mesh = null
		_update_previews()
		return
	var chains: Array = _collect_chains()
	if chains.is_empty():
		push_warning("Loft rig '%s': needs at least 2 balls, or a ball parented to another." % name)
		mesh = null
		return

	var combined: ArrayTetraMesh4D = null
	var ramp := PackedColorArray()
	var built_chains: int = 0
	for chain_index in range(chains.size()):
		# Chain 0 is the rig's own ball children; everything after it is a branch.
		var chain: Array = chains[chain_index]
		# Checks run for every chain of a real build, but printing only for the first,
		# so a four-chain rig reports once rather than four times.
		var piece: ArrayTetraMesh4D = _build_chain(chain, announce and built_chains == 0, chain_index > 0, announce)
		if piece == null:
			continue
		built_chains += 1
		# merge_with appends the other mesh's texture-map entries after this one's, so
		# appending the colours in the same order keeps ramp entry k describing
		# coordinate k.
		ramp.append_array(piece.get_meta("loft_ramp", PackedColorArray()))
		if combined == null:
			combined = piece
		else:
			combined.merge_with(piece, Vector4(), Projection.IDENTITY)

	if combined == null:
		mesh = null
		return
	# COLOURS BEFORE THE MESH. Assigning `mesh` builds the proxy 3D mesh that actually
	# gets drawn, and the texture coordinates are baked into it at that moment - so
	# rewriting them afterwards leaves the proxy holding the old ones.
	if use_ball_colors:
		_apply_ball_colors(combined, ramp)
	mesh = combined
	if announce and verbose and chains.size() > 1:
		print("[Loft] rig '%s': %d chains, %d tetrahedra total." % [
			name, built_chains, combined.get_simplex_cell_vertex_indices().size() / 4])


## Lofts one chain, plus its mirrored twin if the chain sits off the midline.
func _build_chain(chain: Array, announce: bool, is_branch: bool = false, run_checks: bool = true) -> ArrayTetraMesh4D:
	if chain.size() < 2:
		push_warning("Loft rig '%s': a chain needs at least 2 balls, found %d." % [name, chain.size()])
		return null

	var sections: Array[Dictionary] = []
	for ball in chain:
		var section: Dictionary = ball.get_loft_section()
		# A branch ball is a CHILD of another ball, so Godot stores its position
		# relative to that parent, not to the rig. Lofting the raw local value put
		# limbs wherever their anchor happened to sit - a branch off a ball high on
		# the body came out displaced downward by exactly that ball's height - and
		# left the guide wireframes drawn somewhere else again, since those follow the
		# node's real transform.
		section["center"] = _position_in_rig(ball)
		if flatten_w:
			# Only the OFFSET through W is dropped. Each section keeps its own w_scale,
			# so the model still has real thickness in the fourth axis - it is simply
			# not displaced along it, which is what makes a limb wander out of the
			# slice you are looking at.
			var flat: Vector4 = section["center"]
			flat.w = 0.0
			section["center"] = flat
		sections.append(section)

	# Two sections in the same place would loft into a zero-thickness slab of
	# degenerate tetrahedra, which reads as an invisible or flickering band rather
	# than an obvious error - worth naming rather than rendering.
	for index in range(sections.size() - 1):
		var lower: Vector4 = sections[index]["center"]
		var upper: Vector4 = sections[index + 1]["center"]
		if lower.distance_to(upper) < _COINCIDENT_EPSILON:
			push_warning("Loft rig '%s': balls '%s' and '%s' are in the same place - separate them." % [
				name, chain[index].name, chain[index + 1].name])
			return null

	var built: ArrayTetraMesh4D = _Builder.build(sections, profile_rings, profile_sides, taper_ends, verbose and announce, align_to_spine, smoothing, run_checks)
	if built == null:
		return null

	# MIRROR ABOUT THE BALL A BRANCH HANGS OFF, not about the rig's centre. Both
	# arms should splay from the same shoulder, so the shoulder is what has to stay
	# put. Reflecting a branch about the rig's x = 0 instead only works when the body
	# happens to be built on the centre line - move the body sideways and the twin
	# lands nowhere near the ball it belongs to, floating free. The rig's own chain
	# has no anchor, so it still mirrors about x = 0.
	var mirror_plane: float = _axis_value(sections[0]["center"]) if is_branch else 0.0
	# The ring turns about the ball the branch hangs off, for the same reason the
	# mirror plane passes through it: every copy has to meet the body at the one
	# point they share. The rig's own chain has no anchor, so it uses the origin and
	# stays mirror-only - a body is not a thing you take five of.
	var anchor: Vector4 = sections[0]["center"] if is_branch else Vector4()
	var mode: int = _Ball.SYMMETRY_MIRROR
	var count: int = 2
	if is_branch and chain.size() > 1:
		# A branch whose root has been detached keeps its copies as REAL balls, so
		# generating them as well would give three limbs where two were asked for.
		# That case now arrives as symmetry_type = None rather than a separate flag.
		mode = int(chain[1].symmetry_type)
		count = maxi(2, int(chain[1].symmetry_count))
	# EACH HALF OF THE GROUP IS TESTED SEPARATELY, because either can be degenerate
	# on its own and they fail in opposite directions:
	#
	#   - a limb on the MIRROR PLANE is unchanged by the reflection, so a dihedral
	#     ring would generate all 2N elements into N places - coincident surfaces,
	#     doubled tetrahedra, and a watertight check that fails on every face at once.
	#   - a limb on the RING'S OWN AXIS is unchanged by the rotation, so all N
	#     rotations land on top of each other instead of spreading out.
	#
	# Collapsing the degenerate half and keeping the other is what makes a Dihedral
	# limb on the ring axis come out as the pair it geometrically is, rather than as
	# nothing at all - which is what testing the two together did.
	var ring_useful: bool = _should_symmetrize(sections, is_branch, mirror_plane, anchor, mode)
	var reflect_useful: bool = _should_mirror(sections, is_branch, mirror_plane)
	var turns: int = 1
	var reflections: int = 1
	if mode == _Ball.SYMMETRY_CYCLIC:
		turns = count if ring_useful else 1
	elif mode == _Ball.SYMMETRY_DIHEDRAL:
		turns = count if ring_useful else 1
		reflections = 2 if reflect_useful else 1
		if turns > 1 and reflections == 1:
			push_warning("Loft rig '%s': branch '%s' is Dihedral but sits ON the mirror plane, where the reflection maps it onto itself - built as Cyclic(%d) rather than doubling every limb. Offset it along the mirror axis to get %d." % [
				name, chain[1].name if chain.size() > 1 else "?", turns, turns * 2])
		elif turns == 1 and reflections > 1:
			push_warning("Loft rig '%s': branch '%s' is Dihedral but sits ON the ring axis, where every rotation lands in the same place - built as a mirrored pair rather than %d copies of one spot. Offset it within the rotation plane to get a real ring." % [
				name, chain[1].name if chain.size() > 1 else "?", count * 2])
	var mirroring: bool = false
	if mode == _Ball.SYMMETRY_MIRROR:
		mirroring = reflect_useful
	elif mode != _Ball.SYMMETRY_NONE:
		mirroring = turns * reflections > 1
	if mirroring and mode == _Ball.SYMMETRY_MIRROR:
		var mirrored_sections: Array[Dictionary] = []
		for section in sections:
			var mirrored_section: Dictionary = section.duplicate()
			var center: Vector4 = section["center"]
			mirrored_section["center"] = _with_axis_value(center, 2.0 * mirror_plane - _axis_value(center))
			# ROLL IS HANDED, so a reflection has to negate it. It is a SIGNED spin of
			# the section within its own plane, and mirroring a twist reverses which way
			# it turns - the same reason a right hand reflects into a left one. Copying
			# it across unchanged gives a twin twisted the WRONG WAY, which does not read
			# as a twist error at all: it reads as the mirrored limb being squashed and
			# mis-shapen compared to its original, because its blade section is now
			# rotated away from where the geometry expects it.
			#
			# Positions alone were symmetric all along; only the twist was not, which is
			# why this is invisible until a rolled limb gets mirrored.
			mirrored_section["roll"] = -float(section.get("roll", 0.0))
			mirrored_sections.append(mirrored_section)
		# Quiet: the twin's checks would otherwise report the same result twice.
		var mirrored: ArrayTetraMesh4D = _Builder.build(mirrored_sections, profile_rings, profile_sides, taper_ends, false, align_to_spine, smoothing, run_checks)
		_merge_copy(built, mirrored)
	elif mirroring:
		# THE RING IS PLACED BY TRANSFORMING A FINISHED MESH, not by re-lofting
		# rotated sections, and that distinction is the whole correctness of it.
		#
		# build_frames() seeds every section's frame from the GLOBAL axes (X, Z, W)
		# and Gram-Schmidts them against the spine tangent. A rotation in the (Z, W)
		# plane MOVES two of those seeds, so a chain whose centres have been rotated
		# comes back with a frame that is not the rotation of the original's frame -
		# its cross-sections are spun by some other amount and the copies are not
		# congruent. Measured on a Dihedral(2) hind leg: 1040 of 1100 vertices had no
		# partner under the ring's own half turn.
		#
		# Reflection survives that same code because an x-reflection leaves the Z and
		# W seeds untouched, which is why the mirror path was correct all along and
		# only the ring was wrong. Rather than depend on that distinction, the ring
		# now moves the very vertices that were already correct. A rotation also
		# preserves handedness, so unlike a reflection it needs no winding rescue.
		var template: ArrayTetraMesh4D = _Builder.build(sections, profile_rings, profile_sides, taper_ends, false, align_to_spine, smoothing, false)
		var reflected_template: ArrayTetraMesh4D = null
		if reflections == 2:
			var reflected_sections: Array[Dictionary] = []
			for section in sections:
				var reflected_section: Dictionary = section.duplicate()
				var center: Vector4 = section["center"]
				reflected_section["center"] = _with_axis_value(center, 2.0 * mirror_plane - _axis_value(center))
				# Handed, exactly as in the Mirror path - see the note there.
				reflected_section["roll"] = -float(section.get("roll", 0.0))
				reflected_sections.append(reflected_section)
			reflected_template = _Builder.build(reflected_sections, profile_rings, profile_sides, taper_ends, false, align_to_spine, smoothing, false)
		# k = 0 unreflected is the original, which `built` already holds, so it is the
		# one element skipped rather than special-cased. Every other element comes out
		# of the same loop, so the ring cannot disagree with itself.
		for reflected in range(reflections):
			var source: ArrayTetraMesh4D = template if reflected == 0 else reflected_template
			if source == null:
				continue
			for k in range(turns):
				if reflected == 0 and k == 0:
					continue
				var angle: float = TAU * float(k) / float(turns)
				# Rotation about the anchor, as basis + offset: R * v + (a - R * a).
				var rotation: Projection = _rotate_basis_in_plane(Projection.IDENTITY, angle)
				var offset: Vector4 = anchor - _rotate_in_plane(anchor, Vector4(), angle)
				_merge_copy(built, source, rotation, offset)

	if mirroring and mode >= _Ball.SYMMETRY_CYCLIC:
		_check_ring_w_coverage(sections, anchor, mirror_plane, turns, reflections, chain)

	# A ball shared by two chains gets a frame from each; the last one wins, which
	# only affects its guide wireframe, never the geometry.
	var frames: Array = _Builder.build_frames(sections, align_to_spine)
	var ghosting: bool = mirroring and show_mirror_ghost
	for index in range(chain.size()):
		if chain[index].has_method("set_preview_frame"):
			chain[index].set_preview_frame(frames[index])
		if chain[index].has_method("set_symmetry_preview"):
			# Every copy gets a ghost now, not just one twin, so a ring of five reads
			# as five rather than as a limb and one unexplained extra.
			var offsets: Array[Vector4] = []
			if ghosting:
				offsets = _ghost_offsets(sections[index]["center"], anchor, mirror_plane, mode, turns, reflections)
			chain[index].set_symmetry_preview(offsets)
	return built


## Warns when a limb ring leaves W GAPS the player can stand in and see no limbs.
##
## THE ONE FAILURE MODE NONE OF THE OTHER CHECKS CAN SEE. Watertight, winding, fold
## and sliver all pass on a limb that is geometrically perfect and yet invisible,
## because the player's 3D cross-section never intersects it: a ring spreads its
## limbs through W, but each limb is only as thick in W as its own radius * w_scale,
## so a wide ring made of thin limbs exists mostly in between slices. Measured on the
## hand-authored Cn/Dn horses this replaces, the limbs covered 17% and 27% of the W
## range - the model looked complete at w = 0 and lost its legs by w = 0.25.
##
## The ring geometry is known here, so the gap is computed rather than left to be
## found later by eye or by an external script.
func _check_ring_w_coverage(sections: Array, anchor: Vector4, plane: float, turns: int, reflections: int, chain: Array) -> void:
	# TESTED SECTION BY SECTION, not as one pooled union. Pooling hides the actual
	# failure: a limb's ring radius GROWS along its length while the limb NARROWS, so
	# the hoof end is both the thinnest in W and the most widely spaced around the
	# ring. Unioning every section together let one leg's thick shoulder cover the gap
	# between another leg's thin hooves, and the check passed a model whose legs
	# genuinely vanished at w = 0.25.
	#
	# Every copy is a rotation of the same chain, so section i has the same W
	# half-extent in all of them and the question is simply whether its own copies
	# tile W.
	var worst_gap: float = 0.0
	var worst_at: float = 0.0
	var worst_index: int = 0
	var total: float = 0.0
	for index in range(1, sections.size()):
		var half: float = absf(float(sections[index]["radius"]) * float(sections[index]["w_scale"]))
		var spans: Array[Vector2] = []
		for reflected in range(reflections):
			for k in range(turns):
				var center: Vector4 = sections[index]["center"]
				if reflected == 1:
					center = _with_axis_value(center, 2.0 * plane - _axis_value(center))
				var w: float = _rotate_in_plane(center, anchor, TAU * float(k) / float(turns)).w
				spans.append(Vector2(w - half, w + half))
		if spans.size() < 2:
			continue
		spans.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
		var reach: float = spans[0].y
		for span in spans:
			if span.x - reach > worst_gap:
				worst_gap = span.x - reach
				worst_at = reach
				worst_index = index
			reach = maxf(reach, span.y)
		total = maxf(total, reach - spans[0].x)
	# A TOLERANCE, because this samples the sections while the built surface is
	# CONTINUOUS between them. A limb tapers from one ball to the next, so its W reach
	# varies all the way along and a hairline gap measured at one station is closed by
	# the taper either side of it. Warning on those cried wolf on a model whose legs
	# measurably covered 99% of the W range. Anything above a fiftieth of the span is
	# a real hole the player can stand in.
	if worst_gap <= maxf(_COINCIDENT_EPSILON, total * 0.02):
		return
	push_warning("Loft rig '%s': ring branch '%s' leaves a %.2f-wide GAP in W at w = %.2f, around ball '%s', out of %.2f spanned - the player standing there sees no limb at all, however sound the geometry is. Raise that ball's w_scale or radius until consecutive copies overlap, pull the ring in, or use fewer copies." % [
		name, chain[1].name if chain.size() > 1 else "?", worst_gap, worst_at,
		chain[worst_index].name if worst_index < chain.size() else "?", total])


## Folds one symmetry copy into [param built], colour bookkeeping included.
##
## SHARED BY MIRROR AND BY THE RING on purpose. The merge appends the copy's cells
## and texture-map entries, so its colour arrays have to be appended in the same
## order or the copy falls off the end of both and comes out white while its
## original is not - which is exactly what a mirrored limb did the first time a
## coloured model was built. Two copies of that reasoning is how one of them gets
## fixed and the other does not.
func _merge_copy(built: ArrayTetraMesh4D, copy: ArrayTetraMesh4D, basis: Projection = Projection.IDENTITY, offset: Vector4 = Vector4()) -> void:
	if copy == null:
		return
	# merge_with applies basis * v + offset, and carries normals through the
	# inverse-transpose, so a placed copy needs no separate normal fix-up.
	built.merge_with(copy, offset, basis)
	var both_colors: PackedColorArray = built.get_meta("loft_colors", PackedColorArray())
	both_colors.append_array(copy.get_meta("loft_colors", PackedColorArray()))
	built.set_meta("loft_colors", both_colors)
	var both_ramps: PackedColorArray = built.get_meta("loft_ramp", PackedColorArray())
	both_ramps.append_array(copy.get_meta("loft_ramp", PackedColorArray()))
	built.set_meta("loft_ramp", both_ramps)


## Points every ball's guide wireframe along its chain, without building anything.
##
## Only used by [member edit_balls_only]: the normal path already does this per chain
## as a by-product of lofting, and repeating it there would just be work done twice.
func _update_previews() -> void:
	for chain in _collect_chains():
		if chain.size() < 2:
			continue
		var sections: Array[Dictionary] = []
		for ball in chain:
			var section: Dictionary = ball.get_loft_section()
			section["center"] = _position_in_rig(ball)
			sections.append(section)
		var frames: Array = _Builder.build_frames(sections, align_to_spine)
		for index in range(chain.size()):
			if chain[index].has_method("set_preview_frame"):
				chain[index].set_preview_frame(frames[index])


## Whether this chain is a limb sitting off to one side, and so earns a mirrored
## twin, rather than a central chain that must stay single.
##
## THE RULE: every ball must be clear of the midline AND all on the SAME side.
## A leg or a wing satisfies both along its whole length. A body does not - even
## one nudged sideways still has balls sitting on the centre line, and a spine that
## weaves across the middle changes sign.
##
## Getting this wrong is expensive: the earlier version mirrored a chain if ANY
## ball was off-centre, so dragging a single mid-body ball sideways silently
## generated a SECOND WHOLE BODY overlapping the first. It reads as the model
## splitting in two, and it makes every later edit look broken because you are
## adjusting one of two bodies.
func _should_mirror(sections: Array, skip_anchor: bool, plane: float) -> bool:
	if not mirror_x:
		return false
	var first: int = 1 if skip_anchor else 0
	if first >= sections.size():
		return false

	if skip_anchor:
		# A BRANCH is judged by where it sits ON AVERAGE, not by every single ball.
		# Requiring all of them clear of the plane made the twin flicker in and out
		# while dragging a limb across it, and made a limb that merely grazed the
		# plane lose its pair for no visible reason - which is what made the mirroring
		# look like it was picking centres at random.
		var total: float = 0.0
		for index in range(first, sections.size()):
			total += _axis_value(sections[index]["center"]) - plane
		return absf(total / float(sections.size() - first)) > _MIDLINE_EPSILON

	# The RIG'S OWN CHAIN is a body, so it keeps the strict rule: every ball clear of
	# the plane and all on the same side. A body with one ball nudged sideways must
	# not suddenly grow a second body.
	var side: float = 0.0
	for index in range(first, sections.size()):
		var offset: float = _axis_value(sections[index]["center"]) - plane
		if absf(offset) <= _MIDLINE_EPSILON:
			return false
		var this_side: float = signf(offset)
		if side == 0.0:
			side = this_side
		elif this_side != side:
			return false
	return true


## Whether a chain earns its copies, for any symmetry mode.
##
## DELEGATES FOR MIRROR rather than reimplementing it: _should_mirror carries a
## scalar rule that took real work to get right (a branch judged on its average
## offset, a body judged strictly ball by ball) and five of the diagnostic runners
## call it directly. Reproducing that logic here would give two rules to keep in
## step, and the mirror half of the work is already correct.
##
## For a ring the same question needs a 2D answer, because "off the plane" becomes
## "off the axis": a limb's average offset from the anchor is a vector in the
## rotation plane, and what matters is its LENGTH. That keeps the existing and
## already-correct rule that a branch sitting dead centre - a neck, a tail, a spine
## ridge - stays single instead of being multiplied into a starburst through itself.
func _should_symmetrize(sections: Array, skip_anchor: bool, plane: float, anchor: Vector4, mode: int) -> bool:
	if mode == _Ball.SYMMETRY_NONE:
		return false
	if mode == _Ball.SYMMETRY_MIRROR:
		return _should_mirror(sections, skip_anchor, plane)
	# mirror_x stays the master switch for every mode, so there is one place to turn
	# branch duplication off wholesale rather than one per mode.
	if not mirror_x:
		return false
	var first: int = 1 if skip_anchor else 0
	if first >= sections.size():
		return false
	# A ring about the rig origin would sweep the body through itself, so the rig's
	# own chain is never cyclic however its balls are arranged.
	if not skip_anchor:
		return false
	var total_a: float = 0.0
	var total_b: float = 0.0
	for index in range(first, sections.size()):
		total_a += _plane1_value(sections[index]["center"]) - _plane1_value(anchor)
		total_b += _plane2_value(sections[index]["center"]) - _plane2_value(anchor)
	var divisor: float = float(sections.size() - first)
	return Vector2(total_a / divisor, total_b / divisor).length() > _MIDLINE_EPSILON


## Where each generated copy of [param center] lands, as offsets from it.
##
## Authoring aid only - this is what the ball ghosts draw. Computed from rig-space
## centres and the same transforms the build uses, so the ghost cannot promise a
## limb somewhere the build will not put one.
func _ghost_offsets(center: Vector4, anchor: Vector4, plane: float, mode: int, turns: int, reflections: int) -> Array[Vector4]:
	var offsets: Array[Vector4] = []
	if mode == _Ball.SYMMETRY_MIRROR:
		offsets.append(_with_axis_value(center, 2.0 * plane - _axis_value(center)) - center)
		return offsets
	# Handed the build's OWN counts, degenerate halves already collapsed - a ghost
	# promising ten limbs where five will be built is worse than no ghost at all.
	for reflected in range(reflections):
		for k in range(turns):
			if reflected == 0 and k == 0:
				continue
			var point: Vector4 = center
			if reflected == 1:
				point = _with_axis_value(point, 2.0 * plane - _axis_value(point))
			offsets.append(_rotate_in_plane(point, anchor, TAU * float(k) / float(turns)) - center)
	return offsets


## A ball's centre expressed in the RIG's space, whichever ball it hangs off.
##
## Walks up through any parent balls, applying each one's own transform, so a limb
## nested four deep lands where its nodes actually are.
func _position_in_rig(ball: Node) -> Vector4:
	var point: Vector4 = ball.position
	var node: Node = ball.get_parent()
	while node != null and node != self and node.has_method("get_loft_section"):
		point = node.basis * point + node.position
		node = node.get_parent()
	return point


## The component of [param point] along the mirror axis.
func _axis_value(point: Vector4) -> float:
	match mirror_axis:
		1:
			return point.z
		2:
			return point.w
	return point.x


## [param point] with its mirror-axis component replaced by [param value].
func _with_axis_value(point: Vector4, value: float) -> Vector4:
	match mirror_axis:
		1:
			return Vector4(point.x, point.y, value, point.w)
		2:
			return Vector4(point.x, point.y, point.z, value)
	return Vector4(value, point.y, point.z, point.w)


## The direction a new branch should be thrown, so that it lands off the mirror
## plane and pairs up immediately. Read by loft_ball_4d.gd.
func branch_spawn_direction() -> Vector4:
	match new_branch_direction:
		1:
			return Vector4(1.0, 0.0, 0.0, 0.0)
		2:
			return Vector4(-1.0, 0.0, 0.0, 0.0)
		3:
			return Vector4(0.0, 1.0, 0.0, 0.0)
		4:
			return Vector4(0.0, -1.0, 0.0, 0.0)
		5:
			return Vector4(0.0, 0.0, 1.0, 0.0)
		6:
			return Vector4(0.0, 0.0, -1.0, 0.0)
		7:
			return Vector4(0.0, 0.0, 0.0, 1.0)
		8:
			return Vector4(0.0, 0.0, 0.0, -1.0)
	return _with_axis_value(Vector4(), 1.0)


## Which axis index the mirror uses, so a ball can reflect its own chain.
func mirror_axis_index() -> int:
	return mirror_axis


## The linear part of a ring rotation, for a ball detaching its own copies.
##
## Public because "Detach mirror" has to reproduce the transforms the build used,
## and a ball has no business knowing which two axes the ring turns in - that is the
## rig's setting.
func rotate_direction_in_plane(direction: Vector4, angle: float) -> Vector4:
	return _rotate_in_plane(direction, Vector4(), angle)


## The two axes a Cyclic/Dihedral ring rotates in: the complement of [member
## mirror_axis] within (X, Z, W). Same three-case shape as _axis_value, returning
## the pair it leaves out instead of the one it names.
##
## Y IS NEVER RETURNED. It is the axis every player rotation preserves, so it is the
## model's up; sweeping a limb ring through it would tip the creature over rather
## than arrange it radially.
func _plane_axes() -> Vector2i:
	match mirror_axis:
		1:
			return Vector2i(0, 3)  # Z excluded -> rotate in (X, W)
		2:
			return Vector2i(0, 2)  # W excluded -> rotate in (X, Z)
	return Vector2i(2, 3)  # X excluded -> rotate in (Z, W)


## One component of [param point], by axis index (0 = x, 1 = y, 2 = z, 3 = w).
static func _component(point: Vector4, axis: int) -> float:
	match axis:
		1:
			return point.y
		2:
			return point.z
		3:
			return point.w
	return point.x


## [param point] with its first rotation-plane component replaced.
func _plane1_value(point: Vector4) -> float:
	return _component(point, _plane_axes().x)


## [param point] with its second rotation-plane component replaced.
func _plane2_value(point: Vector4) -> float:
	return _component(point, _plane_axes().y)


## [param point] with both rotation-plane components replaced, the other two kept.
func _with_plane_values(point: Vector4, first: float, second: float) -> Vector4:
	var axes: Vector2i = _plane_axes()
	var out: Vector4 = point
	out[axes.x] = first
	out[axes.y] = second
	return out


## [param point] turned [param angle] radians about [param anchor], within the
## rotation plane. The two axes outside that plane are left exactly as they were, so
## a limb ring stays at its own height and its own head-to-tail station.
func _rotate_in_plane(point: Vector4, anchor: Vector4, angle: float) -> Vector4:
	var da: float = _plane1_value(point) - _plane1_value(anchor)
	var db: float = _plane2_value(point) - _plane2_value(anchor)
	var c: float = cos(angle)
	var s: float = sin(angle)
	return _with_plane_values(point,
		_plane1_value(anchor) + da * c - db * s,
		_plane2_value(anchor) + da * s + db * c)


## The same rotation applied to a BASIS rather than a point.
##
## Needed because a section carries its own basis, and rotating only the centres
## leaves every copy's cross-section oriented as though it had never moved - a
## gizmo-scaled or rolled limb would come out sheared the wrong way round the ring.
## Rotating each column reuses _rotate_in_plane with a zero anchor, so a direction
## and a position can never disagree about which way the ring turns.
##
## Safe in a way reflection is not: a rotation preserves handedness, so a rotated
## copy is not inside-out and needs no winding rescue.
func _rotate_basis_in_plane(basis: Projection, angle: float) -> Projection:
	var origin := Vector4()
	return Projection(
		_rotate_in_plane(basis.x, origin, angle),
		_rotate_in_plane(basis.y, origin, angle),
		_rotate_in_plane(basis.z, origin, angle),
		_rotate_in_plane(basis.w, origin, angle))
