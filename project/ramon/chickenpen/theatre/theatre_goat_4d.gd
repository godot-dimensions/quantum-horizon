@tool
extends Node4D

## The goat from `Model/model.tscn`, adopted whole - assembled in front of the audience one
## handle at a time, and then reshaped into a different animal.
##
## IT IS RAMON'S GOAT, NOT A NEW ONE. An earlier version of this exhibit hand-placed
## thirty-five balls in code and got a stool with legs, because it avoided the rig's branch
## support and guessed at proportions. There was a properly authored goat sitting in the
## Model scene the whole time - rump, barrel, chest, neck, skull, muzzle, nose, beard,
## horns and two real leg chains, twenty-five balls in a branching hierarchy. An exhibit
## whose entire claim is "a person made this with the tool" should be showing the thing a
## person actually made with the tool.
##
## THE BUILD IS BAKED, NOT LOFTED LIVE. A full rebuild measured over a hundred milliseconds
## - several frames - so re-lofting on every handle would have turned "watch it being made"
## into "watch it stutter". Every stage is generated once while the room is still arriving
## and nobody is looking at the drum, and playback afterwards is assigning a mesh that
## already exists. The expensive thing happens where the rock carve happens.
##
## THE BUILD IS BAKED PLAIN AND THE FINISHED ANIMAL IS BAKED IN ITS COLOURS. While the
## surface is still arriving, the thing to look at is the geometry - where the tool put a
## face, how the sections between two handles are bridged - and the goat's own markings
## pull the eye straight off it. So the stages are lofted with `use_ball_colors` off and a
## flat material, and one extra loft at the end carries the coat.
##
## STAGES ARE MADE BY DETACHING HANDLES, in reverse depth-first order so a ball is always
## removed before its parent and the tree can be put back by index. The rig collects its
## balls by walking its children for `get_loft_section` and pays no attention to
## visibility, so hiding them would have lofted the whole animal every time.

const SOURCE := "res://ramon/Model/model.tscn"
const GOAT_PATH := "Models/Goat"

@export_tool_button("Rebuild") var _rebuild_action: Callable = rebuild

## How tall the animal should stand on the drum. The authored one is built at its own
## scale; this fits it to the stage without touching the source.
@export_range(0.5, 6.0, 0.1) var stand_height: float = 2.4
@export var marker_color: Color = Color(0.95, 0.76, 0.28)
## What the animal is made of while it is still being made: one flat tone, so the surface
## reads as surface rather than as a goat with a pattern on it.
@export var plain_color: Color = Color(0.68, 0.71, 0.78)

@export_group("The build")
## How many steps the animal is assembled in. Each costs a full loft to bake, so this is
## the number that decides how long the arrival's hitch is.
@export_range(2, 16, 1) var build_stages: int = 7
## And how many steps the reshape takes once it is whole.
@export_range(0, 8, 1) var morph_stages: int = 4

## The handles the reshape moves, and how far. Four of twenty-five: the neck reaches, the
## skull follows it, and the horns sweep up and out. Named rather than indexed, so the
## intent survives somebody reordering the model.
const RESHAPE := {
	"NeckHigh": Vector4(0.0, 0.62, 0.16, 0.0),
	"Skull": Vector4(0.0, 0.30, 0.22, 0.0),
	"HornBase": Vector4(0.10, 0.34, -0.10, 0.0),
	"HornMid": Vector4(0.26, 0.52, -0.26, 0.0),
}

var _goat: Node4D
var _rig: MeshInstance4D
var _balls: Array[Node4D] = []
var _markers: Array[Node4D] = []
var _baked: Array[ArrayTetraMesh4D] = []
var _finished: ArrayTetraMesh4D
var _coat: Material4D
var _plain: TetraMaterial4D
var _showing_plain: bool = false
var _balls_at_stage: Array[int] = []
var _shown: int = -1
var _tetra_whole: int = 0
var _bake_ms: float = 0.0


func _ready() -> void:
	rebuild()


# ---------------------------------------------------------------- adopting it

func rebuild() -> void:
	for child in get_children():
		child.free()
	_goat = null
	_rig = null
	_balls.clear()
	_markers.clear()
	_baked.clear()
	_balls_at_stage.clear()
	_shown = -1
	if not _adopt():
		return
	_collect(_rig)
	_fit()
	_mark()
	_coat = _rig.material_override
	_plain = TetraMaterial4D.new()
	_plain.albedo_color = plain_color
	_bake()
	show_finished()
	set_markers_visible(false)


## Lifts the goat out of the Model scene and throws the rest of that scene away. Loading a
## whole scene to keep one branch of it is not elegant, but the alternative is a second
## copy of the goat that has to be kept in step with the first by hand - and the first one
## is the one an artist edits.
func _adopt() -> bool:
	if not ResourceLoader.exists(SOURCE):
		push_warning("TheatreGoat: %s is missing, so there is no goat." % SOURCE)
		return false
	var scene: Node = (load(SOURCE) as PackedScene).instantiate()
	var found: Node = scene.get_node_or_null(GOAT_PATH)
	if found == null:
		push_warning("TheatreGoat: no %s inside %s." % [GOAT_PATH, SOURCE])
		scene.free()
		return false
	# Owner cleared first: it still belongs to the scene being thrown away, and adding it
	# here with that owner still set makes Godot complain about an inconsistent tree.
	_disown(found)
	found.get_parent().remove_child(found)
	add_child(found)
	_own(found)
	scene.free()
	_goat = found as Node4D
	_goat.position = Vector4.ZERO
	for child in _goat.get_children():
		if child is MeshInstance4D and child.has_method("build"):
			_rig = child as MeshInstance4D
			break
	if _rig == null:
		push_warning("TheatreGoat: the adopted goat has no loft rig on it.")
		return false
	return true


## Depth-first, which is the order the rig itself walks the tree in - so keeping the first
## N of this list keeps a partial animal rather than a scattering of parts.
func _collect(node: Node) -> void:
	for child in node.get_children():
		if child.has_method("get_loft_section"):
			_balls.append(child as Node4D)
			_collect(child)


## Scaled to the stage, and stood on the floor rather than through it. The basis IS the
## transform on a Node4D, so a uniform scale is the identity with its diagonal opened up.
func _fit() -> void:
	var low: float = INF
	var high: float = -INF
	for ball in _balls:
		var y: float = (_goat.global_basis.inverse()
			* (ball.global_position - _goat.global_position)).y
		var r: float = float(ball.get("radius"))
		low = minf(low, y - r)
		high = maxf(high, y + r)
	if not is_finite(low) or high <= low:
		return
	var k: float = stand_height / (high - low)
	_goat.basis = Projection(Vector4(k, 0.0, 0.0, 0.0), Vector4(0.0, k, 0.0, 0.0),
		Vector4(0.0, 0.0, k, 0.0), Vector4(0.0, 0.0, 0.0, k))
	_goat.position = Vector4(0.0, -low * k, 0.0, 0.0)


## A bright dot at every handle, parented to the handle itself so it travels with the
## hierarchy - including through the reshape, where the point is watching them move.
func _mark() -> void:
	for ball in _balls:
		var marker := MeshInstance4D.new()
		marker.name = "Handle"
		var mesh := BoxTetraMesh4D.new()
		var dot: float = maxf(float(ball.get("radius")) * 0.5, 0.05)
		mesh.size = Vector4(dot, dot, dot, dot)
		marker.mesh = mesh
		var glow := TetraMaterial4D.new()
		glow.albedo_color = marker_color
		marker.material_override = glow
		ball.add_child(marker)
		_own(marker)
		_markers.append(marker)


# ---------------------------------------------------------------- baking

func _bake() -> void:
	var started: int = Time.get_ticks_usec()
	var rest: Array = []
	for ball in _balls:
		rest.append(ball.position)

	# Assembling: keep the first share of the handles, loft, keep the mesh.
	for step in build_stages:
		var keep: int = maxi(2, int(ceil(float(_balls.size())
			* float(step + 1) / float(build_stages))))
		var parked: Array = _detach_beyond(keep)
		_snapshot(keep)
		_reattach(parked)

	# Reshaping: the whole animal, with four handles moved a little further each time.
	for step in morph_stages:
		var v: float = float(step + 1) / float(maxi(morph_stages, 1))
		for i in _balls.size():
			var push: Vector4 = RESHAPE.get(String(_balls[i].name), Vector4.ZERO)
			_balls[i].position = (rest[i] as Vector4) + push * v
		_snapshot(_balls.size())
	for i in _balls.size():
		_balls[i].position = rest[i]

	# And once more in its own colours, for the slide where it is finished and the
	# markings are the point rather than a distraction from it.
	_rig.set("use_ball_colors", true)
	_rig.call("build")
	var dressed := _rig.mesh as ArrayTetraMesh4D
	if dressed != null:
		_finished = dressed.duplicate(true) as ArrayTetraMesh4D
		_tetra_whole = _finished.simplex_cell_vertex_indices.size() / 4
	_bake_ms = float(Time.get_ticks_usec() - started) / 1000.0


## Lofts what is currently attached and files the result away. Plain: the build stages
## are about the geometry, so they are lofted without the coat.
func _snapshot(balls: int) -> void:
	_rig.set("use_ball_colors", false)
	_rig.call("build")
	var mesh := _rig.mesh as ArrayTetraMesh4D
	if mesh == null:
		return
	_baked.append(mesh.duplicate(true) as ArrayTetraMesh4D)
	_balls_at_stage.append(balls)


## Reverse depth-first, so a ball is always taken out before its parent is - which keeps
## every recorded index valid for putting them back.
func _detach_beyond(keep: int) -> Array:
	var parked: Array = []
	for i in range(_balls.size() - 1, keep - 1, -1):
		var ball: Node4D = _balls[i]
		var parent: Node = ball.get_parent()
		if parent == null:
			continue
		parked.append([ball, parent, ball.get_index()])
		parent.remove_child(ball)
	return parked


func _reattach(parked: Array) -> void:
	for i in range(parked.size() - 1, -1, -1):
		var entry: Array = parked[i]
		var parent: Node = entry[1]
		parent.add_child(entry[0])
		parent.move_child(entry[0], mini(int(entry[2]), parent.get_child_count() - 1))
		_own(entry[0])


# ---------------------------------------------------------------- playback

## The finished animal in its own colours - the one a designer actually made.
func show_finished() -> void:
	if _rig == null or _finished == null:
		return
	_shown = -1
	_showing_plain = false
	_rig.mesh = _finished
	_rig.material_override = _coat
	for marker in _markers:
		marker.visible = _markers_wanted


## Instant: every stage was lofted up front, so this is assigning a mesh that exists.
func show_stage(which: int) -> void:
	if _baked.is_empty() or _rig == null:
		return
	var want: int = clampi(which, 0, _baked.size() - 1)
	if want == _shown and _showing_plain:
		return
	_shown = want
	if not _showing_plain:
		_showing_plain = true
		_rig.material_override = _plain
	_rig.mesh = _baked[want]
	# The handles that belong to the part of the animal that has not arrived yet go with
	# it, so the markers show the build rather than the finished plan.
	var here: int = _balls_at_stage[want]
	for i in _markers.size():
		_markers[i].visible = i < here and _markers_wanted


var _markers_wanted: bool = false


func set_markers_visible(shown: bool) -> void:
	_markers_wanted = shown
	var here: int = _balls.size()
	if _shown >= 0 and _shown < _balls_at_stage.size():
		here = _balls_at_stage[_shown]
	for i in _markers.size():
		_markers[i].visible = shown and i < here


func stage_count() -> int:
	return _baked.size()


func shown_stage() -> int:
	return _shown


## Where the build ends and the reshape begins.
func first_morph_stage() -> int:
	return build_stages


## How many handles exist at the stage showing now - the figure that climbs while the
## animal assembles.
func balls_shown() -> int:
	if _shown < 0 or _shown >= _balls_at_stage.size():
		return _balls.size()
	return _balls_at_stage[_shown]


func showing_plain() -> bool:
	return _showing_plain


func ball_count() -> int:
	return _balls.size()


func tetra_count() -> int:
	return _tetra_whole


func bake_ms() -> float:
	return _bake_ms


## Strips the old scene's ownership off a branch before it is adopted.
func _disown(node: Node) -> void:
	node.owner = null
	for child in node.get_children():
		_disown(child)


func _own(node: Node) -> void:
	if Engine.is_editor_hint() and get_tree() != null and get_tree().edited_scene_root != null:
		node.owner = get_tree().edited_scene_root
