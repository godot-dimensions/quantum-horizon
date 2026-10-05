extends RefCounted
## Slice Garden: the building vocabulary every island uses, so the islands say WHAT they are and
## this says HOW (a box with collision, a floating slab, a fence bent into a wall or a cage).
##
## SOLIDS ARE BOXES. Physics is axis-aligned boxes only (engine_capabilities.md), so anything you
## walk on or bump into is a StaticBody4D with one BoxShape4D, and its mesh is the same box. Every
## solid is also recorded in the island's `solids` list as [centre, size] in world space, which is
## what putting a crate down checks against (there is no shape query in PhysicsServer4D).
##
## FENCES (Aaron's FenceGenerator4D) are built for their looks and get their collision from here:
## the generator makes none. `fence_sheet` lays one flat face as the seed: a face spanning X and W
## stands across X as a wall in every W it covers; a face spanning X and Z at one W stands ACROSS W,
## a wall you only see once the view is turned into W. `fence_tube` closes X and Z and leaves W open.
## Built synchronously with TETRA output (the probe measured the times; PLAN.md step 4).
##
## NO class_name (engine_gotchas.md).

const Mats := preload("res://ramon/MiegakureLook/Remake/world/mk_materials.gd")

## The W-face tint every structure carries (PLAN.md decision 5) and the warning tint near a solid's
## W ends (the shader's W edge).
const WFACE := Color(0.40, 0.36, 0.80, 0.72)
const WEDGE := Color(0.58, 0.50, 1.0, 0.45)
const SIDE_TINT := Color(0.60, 0.62, 0.70)


## A solid box: body, collider and mesh, at world `centre` with `size`, in `parent`. Returns the body.
## `solids` (optional) gets [centre, size] appended.
static func box(parent: Node, name: String, centre: Vector4, size: Vector4, material: Material4D, solids = null, collide: bool = true) -> Node4D:
	var holder: Node4D
	if collide:
		var body := StaticBody4D.new()
		var shape := CollisionShape4D.new()
		var b := BoxShape4D.new()
		b.size = size
		shape.shape = b
		body.add_child(shape)
		holder = body
	else:
		holder = Node4D.new()
	holder.name = name
	var mesh := MeshInstance4D.new()
	mesh.name = "Mesh"
	mesh.mesh = Mats.box_mesh(size)
	mesh.material_override = material
	holder.add_child(mesh)
	parent.add_child(holder)
	holder.global_position = centre
	if collide and solids != null:
		(solids as Array).append([centre, size])
	return holder


## A surface material for a box at `centre` of `size` (the shader needs both for its mapping and
## its world-space lanes).
static func surface(tex: String, centre: Vector4, size: Vector4, metres: float = 2.0, opts: Dictionary = {}) -> TetraMaterial4D:
	var o: Dictionary = {"origin": centre, "wface": WFACE}
	o.merge(opts, true)
	return Mats.surface(tex, size, metres, o)


## A floating slab: its top at `top_y`, spanning x, z and w ranges given as Vector2(min, max).
## Lanes (the W banding) come in `lanes`; `opts` passes on to the surface.
static func slab(parent: Node, name: String, x: Vector2, z: Vector2, w: Vector2, top_y: float, thickness: float, tex: String, solids: Array, opts: Dictionary = {}) -> Node4D:
	var size := Vector4(x.y - x.x, thickness, z.y - z.x, w.y - w.x)
	var centre := Vector4((x.x + x.y) * 0.5, top_y - thickness * 0.5, (z.x + z.y) * 0.5, (w.x + w.y) * 0.5)
	var o: Dictionary = {"side_tint": SIDE_TINT}
	o.merge(opts, true)
	return box(parent, name, centre, size, surface(tex, centre, size, 2.0, o), solids)


## A fence material: one dev texture, the W-face tint, mapped by metre.
static func fence_material(tex: String, tint: Color = Color.WHITE) -> TetraMaterial4D:
	return Mats.surface(tex, Vector4(1, 1, 1, 1), 1.0, {"wface": WFACE, "tint": tint})


## A FenceGenerator4D, not built yet, with TETRA output and the given look.
static func fence(name: String, post_h: float, post_t: float, beams: int, coverage: float, spacing: float, post_mat: Material4D, rib_mat: Material4D, beam_mat: Material4D):
	var f = ClassDB.instantiate("FenceGenerator4D")
	f.name = name
	f.set("update_automatically", false)
	f.set("output_mesh_type", 2)
	f.set("post_height_meters", post_h)
	f.set("post_thickness_meters", post_t)
	f.set("beam_count", beams)
	f.set("beam_coverage", coverage)
	f.set("desired_spacing_meters", spacing)
	f.set("post_material", post_mat)
	f.set("rib_material", rib_mat)
	f.set("beam_material", beam_mat)
	return f


## Quads (each four Vector3 corners in the fence's own X, Z, W order) as a seed mesh.
static func quads_mesh(quads: Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for q in quads:
		var a: Vector3 = q[0]
		var b: Vector3 = q[1]
		var c: Vector3 = q[2]
		var d: Vector3 = q[3]
		for v in [a, b, c, a, c, d]:
			st.add_vertex(v)
	return st.commit()


## Adds `f` to `parent` at world `at`, sets a seed of `quads` (fence X, Z, W, relative to `at`) if
## given, and builds it now. Returns it.
static func place_fence(parent: Node, f, at: Vector4, quads: Array = []):
	if not quads.is_empty():
		f.set("input_shape_type", 3)
		f.set("seed_mesh_3d", quads_mesh(quads))
	parent.add_child(f)
	f.global_position = at
	f.call("update_fence_mesh_now")
	return f


## A wall across X that spans a range of W, standing at world z: a fence sheet in X-W.
## x and w are Vector2(min, max) in world space.
static func fence_wall_x(parent: Node, f, z: float, x: Vector2, w: Vector2, base_y: float = 0.0):
	var at := Vector4((x.x + x.y) * 0.5, base_y, z, (w.x + w.y) * 0.5)
	var hx: float = (x.y - x.x) * 0.5
	var hw: float = (w.y - w.x) * 0.5
	return place_fence(parent, f, at, [[Vector3(-hx, 0, -hw), Vector3(hx, 0, -hw), Vector3(hx, 0, hw), Vector3(-hx, 0, hw)]])


## A wall across Z that spans a range of W, standing at world x: a fence sheet in Z-W (railings
## along an island's X edges, landmarks that survive the turn because they span Z and W).
static func fence_wall_z(parent: Node, f, x: float, z: Vector2, w: Vector2, base_y: float = 0.0):
	var at := Vector4(x, base_y, (z.x + z.y) * 0.5, (w.x + w.y) * 0.5)
	var hz: float = (z.y - z.x) * 0.5
	var hw: float = (w.y - w.x) * 0.5
	return place_fence(parent, f, at, [[Vector3(0, -hz, -hw), Vector3(0, hz, -hw), Vector3(0, hz, hw), Vector3(0, -hz, hw)]])


## A wall that stands ACROSS W at world w: a fence sheet in X-Z. Only seen once the view is turned.
static func fence_wall_w(parent: Node, f, w: float, x: Vector2, z: Vector2, base_y: float = 0.0):
	var at := Vector4((x.x + x.y) * 0.5, base_y, (z.x + z.y) * 0.5, w)
	var hx: float = (x.y - x.x) * 0.5
	var hz: float = (z.y - z.x) * 0.5
	return place_fence(parent, f, at, [[Vector3(-hx, -hz, 0), Vector3(hx, -hz, 0), Vector3(hx, hz, 0), Vector3(-hx, hz, 0)]])


## A cage closed in X and Z and open along W, round world `at` (its floor centre): half sizes in x
## and z, a W depth.
static func fence_tube_w(parent: Node, f, at: Vector4, half_x: float, half_z: float, depth_w: float):
	var a: float = half_x
	var c: float = half_z
	var b: float = depth_w * 0.5
	return place_fence(parent, f, at, [
		[Vector3(-a, -c, -b), Vector3(-a, c, -b), Vector3(-a, c, b), Vector3(-a, -c, b)],
		[Vector3(a, -c, -b), Vector3(a, -c, b), Vector3(a, c, b), Vector3(a, c, -b)],
		[Vector3(-a, -c, -b), Vector3(-a, -c, b), Vector3(a, -c, b), Vector3(a, -c, -b)],
		[Vector3(-a, c, -b), Vector3(a, c, -b), Vector3(a, c, b), Vector3(-a, c, b)]])


## A box-footprint fence (crate, shrine, tower, roof) at world `at`, size in X, Z, W.
static func fence_box(parent: Node, f, at: Vector4, size_xzw: Vector3):
	f.set("input_shape_type", 0)
	f.set("box_size", size_xzw)
	return place_fence(parent, f, at)


## An invisible collider (for a fence's footprint, a railing, a wall drawn by a fence).
static func collider(parent: Node, name: String, centre: Vector4, size: Vector4, solids = null) -> StaticBody4D:
	var body := StaticBody4D.new()
	body.name = name
	var shape := CollisionShape4D.new()
	var b := BoxShape4D.new()
	b.size = size
	shape.shape = b
	body.add_child(shape)
	parent.add_child(body)
	body.global_position = centre
	if solids != null:
		(solids as Array).append([centre, size])
	return body


## A glowing flat shape on the floor (a ring's segments, a pad, a key cap's outline): a thin box.
static func glow_box(parent: Node, name: String, centre: Vector4, size: Vector4, color: Color, pulse: float = 0.0) -> MeshInstance4D:
	var mesh := MeshInstance4D.new()
	mesh.name = name
	mesh.mesh = Mats.box_mesh(size)
	mesh.material_override = Mats.glow(color, 1.0, pulse)
	parent.add_child(mesh)
	mesh.global_position = centre
	return mesh


## Do two boxes ([centre, size]) overlap, with a margin shaved off each side?
static func overlaps(a_centre: Vector4, a_size: Vector4, b_centre: Vector4, b_size: Vector4, margin: float = 0.01) -> bool:
	var d: Vector4 = (a_centre - b_centre).abs()
	var r: Vector4 = (a_size + b_size) * 0.5 - Vector4(margin, margin, margin, margin)
	return d.x < r.x and d.y < r.y and d.z < r.z and d.w < r.w
