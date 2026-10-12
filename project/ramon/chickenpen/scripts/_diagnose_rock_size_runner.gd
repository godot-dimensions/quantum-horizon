extends SceneTree

## What one swing costs, and how big the rock is for it.
##
## Every carve reruns dual contouring over the WHOLE field - voxel_mining_block.gd says so
## and has no chunking - so cost goes as the fourth power of grid_size. cell_size is free
## by comparison: it scales the rock in metres and leaves the grid untouched, which is why
## the rock got bigger that way rather than by adding voxels.
##
## THE COLLIDER HAS TO BE FETCHED A FRAME LATE. _clear_colliders uses queue_free, so the
## frame after a generate() the old shapes are still children - and an old shape is not in
## the block's own lookup, so mine_at_shape returns immediately. Timed that way a bite
## reads as 0.0 ms, which is how this first reported it: not fast, just not happening.

var _root: Node
var _f := 0
var _step := 0
var _gen: float = 0.0


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/playable_world.tscn").instantiate()
	root.add_child(_root); current_scene = _root


func _live(voxels: Node) -> Array:
	var out: Array = []
	for shape in voxels.get_children():
		if shape is CollisionShape4D and not shape.is_queued_for_deletion():
			out.append(shape)
	return out


func _process(_d) -> bool:
	_f += 1
	if _f < 70: return false
	var rock: Node4D = _root.get_node("World/MiningRock")
	var voxels: Node = rock.get_node("Voxels")

	match _step:
		0:
			var t0: int = Time.get_ticks_usec()
			rock.call("generate")
			_gen = float(Time.get_ticks_usec() - t0) / 1000.0
		1:
			pass  # let the freed colliders actually go
		_:
			var live: Array = _live(voxels)
			var lo := Vector4.ONE * 1e9
			var hi := Vector4.ONE * -1e9
			for shape in live:
				var at: Vector4 = (shape as CollisionShape4D).global_position
				lo = Vector4(minf(lo.x, at.x), minf(lo.y, at.y), minf(lo.z, at.z), minf(lo.w, at.w))
				hi = Vector4(maxf(hi.x, at.x), maxf(hi.y, at.y), maxf(hi.z, at.z), maxf(hi.w, at.w))
			var t1: int = Time.get_ticks_usec()
			rock.call("mine_at_shape", live[0])
			var bite: float = float(Time.get_ticks_usec() - t1) / 1000.0
			print("\n   grid %d, cell %.2f, carve %.2f m"
				% [rock.get("grid_size"), rock.get("cell_size"), rock.get("mining_radius_meters")])
			print("   %d surface voxels, %.1f m across and %.1f m tall"
				% [live.size(), maxf(hi.x - lo.x, hi.z - lo.z), hi.y - lo.y])
			print("   building it from nothing: %.1f ms" % _gen)
			print("   one swing:                %.1f ms" % bite)
			quit(0)
			return true
	_step += 1
	_f = 65
	return false
