extends SceneTree

## How solid is the walkway railing, slice by slice?
##
##   godot --path project --rendering-method forward_plus --resolution 900x600 \
##       --script res://sandbox/water4d/_probe_rail_openness_runner.gd
##
## The report is that the railing looks solid at the starting slice and gappy at every other
## one. That is a measurable claim: point a camera at a stretch of rail, sweep the slice, and
## count how much of the frame the rail covers at each angle. If w = 0 really is special, it
## will stand out as a number and not as an impression.
##
## EVERYTHING ELSE IS HIDDEN so the count means one thing. With the deck, the walls and the
## water in frame, "rail-coloured pixels" is a guess about shading; with only the rails left
## against the sky, it is just coverage.

const SCENE := "res://sandbox/water4d/pool_room.tscn"
const ANGLES: Array[float] = [0.0, 4.0, 10.0, 18.0, 28.0, 40.0]
const SETTLE := 0.5
## ABOVE THIS IT READS AS A WALL. The starting slice will always cover more than a turned one
## - at w = 0 the cut passes straight through the rails and at an angle it only clips them -
## so the ratio is 4x whatever the numbers are, and chasing it to 1 would mean deleting the
## railing. What matters is the absolute figure: 30%% looked like hoarding, 12%% looks like a
## fence you can see the pool through.
const SOLID_AT := 20.0

var _root: Node = null
var _camera: Camera4D = null
var _frames: int = 0
var _held: float = 0.0
var _index: int = 0
var _rows: Array[String] = []
var _cover: Array[float] = []


func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)


func _process(delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		_root = (load(SCENE) as PackedScene).instantiate()
		root.add_child(_root)
		current_scene = _root
		return false
	if _frames == 2:
		_isolate_rails()
		_camera = Camera4D.new()
		_camera.rendering_engine_name = "Cross-section"
		_root.add_child(_camera)
		_camera.current = true
		_aim(0.0)
		return false

	_held += delta
	if _held < SETTLE:
		return false
	_held = 0.0

	_measure(ANGLES[_index])
	_index += 1
	if _index >= ANGLES.size():
		return _report()
	_aim(ANGLES[_index])
	return false


## Keep the four rail fences, hide everything else that draws.
func _isolate_rails() -> void:
	var walkway: Node = _root.get_node_or_null("Walkway")
	for node in _walk(_root):
		if node is MeshInstance4D:
			# ANY ancestor, not the immediate parent: the generator nests its output several
			# levels down, so a parent-name test hides the rails along with everything else
			# and the probe measures a blank screen - which is exactly what it did.
			var keep := false
			var up: Node = node
			while up != null:
				if up is FenceGenerator4D and String(up.name).begins_with("Rail"):
					keep = true
					break
				up = up.get_parent()
			(node as MeshInstance4D).visible = keep
	var water: Node = _root.get_node_or_null("Water")
	if water != null:
		(water as Node4D).visible = false
	var player: Node = _root.get_node_or_null("Player")
	if player != null:
		(player as Node4D).visible = false


## Square on to a stretch of rail, close enough that it fills the middle of the frame.
func _aim(degrees: float) -> void:
	_camera.position = Vector4(0.0, 1.3, 7.0, 0.0)
	_camera.basis = Basis4D.orthonormalized(
			Basis4D.from_xw(deg_to_rad(degrees)) * Basis4D.from_yz(-0.05))


func _measure(degrees: float) -> void:
	var image: Image = root.get_texture().get_image()
	image.save_png("user://rail_slice_%02d.png" % int(degrees))
	# Everything visible is rail, so anything that is not the background counts.
	var hits: int = 0
	var total: int = 0
	var y0: int = int(float(image.get_height()) * 0.30)
	var y1: int = int(float(image.get_height()) * 0.72)
	for y in range(y0, y1):
		for x in range(0, image.get_width(), 2):
			var c: Color = image.get_pixel(x, y)
			total += 1
			# The rails are warm; the sky behind them is blue-grey. Warm means rail.
			if c.r > c.b + 0.04:
				hits += 1
	var percent: float = 100.0 * float(hits) / maxf(float(total), 1.0)
	_cover.append(percent)
	_rows.append("  slice %5.1f deg   rail covers %5.1f%% of the band" % [degrees, percent])


func _report() -> bool:
	print("")
	for row in _rows:
		print(row)
	var at_zero: float = _cover[0]
	var rest_max: float = 0.0
	for i in range(1, _cover.size()):
		rest_max = maxf(rest_max, _cover[i])
	print("")
	if at_zero < 1.0:
		print("  FAIL - nothing at all at 0 degrees (%.1f%%). The camera is not pointed at the" % at_zero)
		print("         rails, so none of these numbers mean anything." )
	elif at_zero > SOLID_AT:
		print("  SOLID - the starting slice covers %.1f%%, over the %.0f%% that reads as a wall" % [at_zero, SOLID_AT])
		print("          rather than a railing. Other slices sit at %.1f%%." % rest_max)
	else:
		print("  OPEN - the starting slice covers %.1f%%, others %.1f%%. Both read as railing." % [at_zero, rest_max])
	quit(0)
	return true


func _walk(node: Node) -> Array[Node]:
	var found: Array[Node] = [node]
	for child in node.get_children():
		found.append_array(_walk(child))
	return found
