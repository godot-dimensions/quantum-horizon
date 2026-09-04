extends SceneTree

## Headless structural check for the Demo hub.
##
## The hub's gates and billboards are generated at runtime and deliberately not
## saved into the scene, so opening `hub1.tscn` in a text editor tells you nothing
## about whether they were actually built. This instantiates the scene, walks the
## resulting tree and prints it, which is the only way to confirm the ring ran
## without opening the editor.
##
## The checks run on the first _process frame, not in _initialize(). Nodes added
## during _initialize() are not yet flagged as inside the tree, so _ready() has
## not fired and the ring has not built anything yet - checking there reports a
## false failure.
##
## Run with the editor CLOSED - two Godot processes touching the same project's
## .godot cache is what silently breaks @tool buttons in a running editor:
##
##   engine/godot/bin/godot.windows.editor.double.x86_64.console.exe \
##       --headless --path project --script res://ramon/Demo/_verify_hub.gd

const DEFAULT_HUB := "res://ramon/Demo/hub1.tscn"

var _hub: Node = null
var _failed: bool = false


## Scene to check, from user args after `--`. Defaults to the main hub:
##   ... --script res://ramon/Demo/_verify_hub.gd -- hub1.tscn
static func _hub_path() -> String:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		return DEFAULT_HUB
	return "res://ramon/Demo/" + args[0]


func _initialize() -> void:
	var hub_path := _hub_path()
	print("checking: ", hub_path)
	var packed: PackedScene = load(hub_path)
	if packed == null:
		printerr("VERIFY: could not load ", hub_path)
		_failed = true
		return
	_hub = packed.instantiate()
	root.add_child(_hub)


func _process(_delta: float) -> bool:
	if _failed or _hub == null:
		quit(1)
		return true

	print("\n===== hub tree =====")
	_dump(_hub, 0)

	var ring: Node = _hub.get_node_or_null("GateRing")
	if ring == null:
		printerr("VERIFY: no GateRing node")
		quit(1)
		return true

	# The ring generates more than gates now - the dais is a sibling of them - so
	# gates are identified by carrying the gate script's own properties rather than
	# by being a child of the ring. Counting children instead reported six gates
	# against five catalogue entries the moment the dais landed.
	var gate_nodes: Array[Node] = []
	var dais: Node = null
	for child in ring.get_children():
		if "gate_name" in child:
			gate_nodes.append(child)
		elif child.get_node_or_null("MeshInstance4D") != null:
			# Not a type check: the dais is a StaticBody4D only when
			# dais_collision is on, and a plain Node4D otherwise.
			dais = child

	print("\n===== summary =====")
	print("catalogue entries: ", ring.gates.size())
	print("gates generated:   ", gate_nodes.size())
	if dais == null:
		print("dais:              none")
	else:
		var dais_mesh := dais.get_node_or_null("MeshInstance4D") as MeshInstance4D
		var dais_shape := dais.get_node_or_null("CollisionShape4D") as CollisionShape4D
		var tets := 0
		var radius := 0.0
		var top := 0.0
		if dais_mesh != null and dais_mesh.mesh != null:
			tets = dais_mesh.mesh.get_simplex_cell_vertex_indices().size() / 4
			# Measured from the geometry rather than read back off the shape, so
			# this still reports honestly when there is no collider to ask.
			var highest := -INF
			for v in dais_mesh.mesh.get_vertex_positions():
				radius = maxf(radius, sqrt(v.x * v.x + v.z * v.z))
				highest = maxf(highest, v.y)
			top = dais.position.y + highest
		# A collider is OPTIONAL and off by default: physics is bounding-box only,
		# so a round platform would collide as a square and strand the player on a
		# ledge they cannot step back up. See HubGateRing4D.dais_collision.
		print("dais:              r=%.2f m, stands %.3f m proud of the floor, %d tetrahedra, collider=%s"
			% [radius, top, tets, "yes (square! check movement)" if dais_shape != null else "no (visual inlay)"])

	var billboards := 0
	var labels := 0
	var sprites := 0
	var frames := 0
	for gate in gate_nodes:
		var billboard := gate.get_node_or_null("Billboard")
		if billboard != null:
			billboards += 1
			for child in billboard.get_children():
				if child is Label3D:
					labels += 1
				elif child is Sprite3D:
					sprites += 1
		var frame := gate.get_node_or_null("Frame")
		if frame != null:
			frames += frame.get_child_count()
		var bb_pos := "none"
		if billboard != null:
			bb_pos = str(billboard.position)
		print("  %-26s gate=%s  sign=%s" % [gate.name, str(gate.position), bb_pos])

	print("billboards: %d   Label3D: %d   Sprite3D: %d   frame segments: %d"
		% [billboards, labels, sprites, frames])

	# The floor spawns its surface the same way, so that it never bakes a
	# tetrahedral array into the .tscn. Check it built and stayed unowned.
	# Only hubs whose floor carries the tiled-floor script generate a Surface.
	# A plain BoxTetraMesh4D floor is a valid configuration, not a failure.
	var floor_mesh: Node = _hub.get_node_or_null("Floor/Mesh")
	if floor_mesh != null and floor_mesh.get_script() == null:
		print("floor: plain mesh, no tiling script")
		floor_mesh = null
	if floor_mesh != null:
		var surface: Node = floor_mesh.get_node_or_null("Surface")
		if surface == null:
			printerr("VERIFY: FAILED - floor surface did not generate")
			quit(1)
			return true
		var detail := "no mesh"
		if surface.mesh != null:
			var s: Vector4 = surface.mesh.size
			var tetra: int = surface.mesh.get_simplex_cell_vertex_indices().size() / 4
			detail = "%.0f x %.0f m, %d tetrahedra, map=%d" % [s.x, s.z, tetra, surface.mesh.cell_texture_map]
		# The tiling lives in a shader uniform, not in the mesh, so report it -
		# it is the single number that decides whether the texture repeats.
		var scale := "none"
		# Material4D, NOT Godot's Material - they are unrelated hierarchies, and
		# typing this as Material throws every frame instead of failing once.
		var mat: Material4D = surface.material_override
		if mat != null and mat.has_method("get_cross_section_material"):
			var cs: ShaderMaterial = mat.get_cross_section_material_3d()
			if cs != null:
				var shader_name := "stock"
				if cs.shader != null and not cs.shader.resource_path.is_empty():
					shader_name = cs.shader.resource_path.get_file()
				scale = "%s size=%s per %s m" % [
					shader_name,
					str(cs.get_shader_parameter("surface_size")),
					str(cs.get_shader_parameter("texture_metres"))
				]
		print("floor: %s | %s | owned=%s" % [detail, scale, str(surface.owner != null)])

	# Nothing is owned by the scene, so a saved hub1.tscn must never contain the
	# generated nodes. Catching a regression here is cheaper than finding stale
	# geometry committed into the scene weeks later.
	var owned_leaks := 0
	for gate in ring.get_children():
		if gate.owner != null:
			owned_leaks += 1
	if floor_mesh != null:
		var floor_surface: Node = floor_mesh.get_node_or_null("Surface")
		if floor_surface != null and floor_surface.owner != null:
			owned_leaks += 1
	print("generated nodes wrongly owned by the scene: ", owned_leaks)

	if gate_nodes.is_empty() or billboards == 0 or frames == 0:
		printerr("VERIFY: FAILED - something did not generate")
		quit(1)
		return true
	if owned_leaks > 0:
		printerr("VERIFY: FAILED - generated nodes would be serialised into the scene")
		quit(1)
		return true
	print("VERIFY: OK")
	quit(0)
	return true


func _dump(node: Node, depth: int) -> void:
	var line := ""
	for i in depth:
		line += "  "
	line += "%s [%s]" % [node.name, node.get_class()]
	print(line)
	# Frame segments are numerous and identical; summarise rather than list.
	if node.name == "Frame":
		var pad := ""
		for i in depth + 1:
			pad += "  "
		print(pad, "... %d segments" % node.get_child_count())
		return
	for child in node.get_children():
		_dump(child, depth + 1)
