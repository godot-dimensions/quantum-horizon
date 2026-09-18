extends SceneTree
## Fingerprints every loft rig in the example scenes, so the symmetry work can be
## proven to change nothing about the existing models.
##
## Counts alone are too weak - a wrong rotation can preserve them exactly - so
## this hashes the actual vertex positions and cell indices.

const SCENES := [
	"res://ramon/Model/model.tscn",
	"res://ramon/Model/animation_test.tscn",
]

var _frame: int = 0
var _roots: Array[Node] = []


func _initialize() -> void:
	for path in SCENES:
		var packed: PackedScene = load(path)
		if packed == null:
			print("MISSING SCENE: %s" % path)
			continue
		var instance: Node = packed.instantiate()
		root.add_child(instance)
		_roots.append(instance)
		# FREEZE THE GAIT. The strider's walker advances its phase from wall-clock
		# delta in _physics_process, so its pose - and therefore its fingerprint -
		# differs run to run on UNCHANGED code (measured: Rump y came out 5.5193,
		# 5.5169 and 5.5217 on three consecutive runs). Comparing an animated pose
		# would report a regression on every run and hide a real one. _ready has
		# already run by now, so the detached mirror balls it creates are still here;
		# only the per-frame animation is stopped.
		_freeze_walkers(instance)


func _freeze_walkers(node: Node) -> void:
	if node.has_method("_detach_mirrors"):
		node.process_mode = Node.PROCESS_MODE_DISABLED
	for child in node.get_children():
		_freeze_walkers(child)


func _rigs(node: Node, out: Array[Node]) -> void:
	if node.has_method("_collect_chains") and node.has_method("build"):
		out.append(node)
	for child in node.get_children():
		_rigs(child, out)


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame < 3:
		return false  # let _ready() and child-order notifications settle

	var rigs: Array[Node] = []
	for r in _roots:
		_rigs(r, rigs)
	print("rigs found: %d" % rigs.size())
	for rig in rigs:
		rig.verbose = false
		rig.live_rebuild = false
		rig.build(false)
		var mesh := rig.mesh as ArrayTetraMesh4D
		if mesh == null:
			print("%-44s  MESH NULL" % rig.get_path())
			continue
		var verts: PackedVector4Array = mesh.get_vertex_positions()
		var cells: PackedInt32Array = mesh.get_simplex_cell_vertex_indices()
		# Quantised so float noise cannot masquerade as a real difference, but fine
		# enough (1e-9) that any genuine geometric change shows up.
		var ctx := HashingContext.new()
		ctx.start(HashingContext.HASH_SHA256)
		var blob := PackedByteArray()
		for v in verts:
			blob.append_array(var_to_bytes(Vector4i(
				roundi(v.x * 1000000.0), roundi(v.y * 1000000.0),
				roundi(v.z * 1000000.0), roundi(v.w * 1000000.0))))
		ctx.update(blob)
		var idx := PackedByteArray()
		for i in cells:
			idx.append_array(var_to_bytes(i))
		ctx.update(idx)
		var digest: String = ctx.finish().hex_encode().substr(0, 16)
		print("%-44s  %6d verts  %7d cells  %s  chains=%d" % [
			rig.get_path(), verts.size(), cells.size() / 4, digest,
			rig._collect_chains().size()])
	quit(0)
	return true
