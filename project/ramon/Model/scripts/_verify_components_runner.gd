extends SceneTree

## Answers "is the brachiosaurus really one mesh?" properly, by counting how many
## separate closed surfaces the single mesh actually contains.
##
## Two tetrahedra belong to the same surface if they share a triangular face. So
## flood-filling across shared faces counts the connected components: one component
## means a genuinely fused animal, several means separate shells that merely
## overlap in space and happen to sit in the same vertex buffer.

var _instance: Node
var _done: bool = false


func _initialize() -> void:
	_instance = (load("res://ramon/Model/model.tscn") as PackedScene).instantiate()
	root.add_child(_instance)


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	_report("Brachio/Spine", _instance.get_node("Models/Brachio/Spine"))
	for part in _instance.get_node("Models/Chicken").get_children():
		_report("Chicken/" + part.name, part)
	return true


func _report(label: String, node: Node) -> void:
	var mesh: ArrayTetraMesh4D = node.mesh
	if mesh == null:
		print("%-22s no mesh" % label)
		return
	var cells: PackedInt32Array = mesh.get_simplex_cell_vertex_indices()
	var cell_count: int = cells.size() / 4
	var sizes: Array[int] = _component_sizes(cells, cell_count)
	print("%-22s %5d tetrahedra in %d separate closed surface(s)  sizes=%s" % [
		label, cell_count, sizes.size(), sizes])


const _FACE_SLOTS: Array = [1, 2, 3, 0, 3, 2, 0, 1, 3, 0, 2, 1]


func _component_sizes(cells: PackedInt32Array, cell_count: int) -> Array[int]:
	var owners := {}
	for cell in range(cell_count):
		for slot in range(4):
			var key: int = _face_key(cells, cell, slot)
			if owners.has(key):
				owners[key].append(cell)
			else:
				owners[key] = [cell]

	var seen := PackedInt32Array()
	seen.resize(cell_count)
	seen.fill(0)
	var sizes: Array[int] = []
	for seed in range(cell_count):
		if seen[seed] == 1:
			continue
		var size: int = 0
		seen[seed] = 1
		var queue: Array[int] = [seed]
		while not queue.is_empty():
			var current: int = queue.pop_back()
			size += 1
			for slot in range(4):
				for other in owners[_face_key(cells, current, slot)]:
					if seen[other] == 0:
						seen[other] = 1
						queue.append(other)
		sizes.append(size)
	sizes.sort()
	sizes.reverse()
	return sizes


func _face_key(cells: PackedInt32Array, cell: int, slot: int) -> int:
	var base: int = cell * 4
	var offset: int = slot * 3
	var lo: int = cells[base + _FACE_SLOTS[offset]]
	var mid: int = cells[base + _FACE_SLOTS[offset + 1]]
	var hi: int = cells[base + _FACE_SLOTS[offset + 2]]
	var swap: int
	if lo > mid:
		swap = lo
		lo = mid
		mid = swap
	if mid > hi:
		swap = mid
		mid = hi
		hi = swap
	if lo > mid:
		swap = lo
		lo = mid
		mid = swap
	return lo | (mid << 21) | (hi << 42)
