#include "fence_generator_4d.h"

#include "fence_build_job_4d.h"
#include "fence_guide_post_4d.h"

#include "core/math/convex_hull.h"

#include "modules/4d/model/mesh/poly/array_poly_mesh_4d.h"
#include "modules/4d/model/mesh/poly/poly_mesh_builder_4d.h"

void FenceGenerator4D::_notification(int p_what) {
	switch (p_what) {
		case NOTIFICATION_READY: {
			// Avoid updating the fence mesh while loading in all the properties.
			_is_ready = true;
			if (_input_shape_type == INPUT_SHAPE_RADIAL_POST_NODES) {
				// The guide posts are saved with the scene, so normally they are already here. A scene that has the corners but
				// no posts, such as one saved before the posts were kept, gets them back from the corners.
				if (_get_guide_posts().is_empty()) {
					_create_guide_posts_from_corners();
				}
#ifndef TOOLS_ENABLED
				WARN_PRINT("FenceGenerator4D: \"" + String(get_name()) + "\" uses guide post nodes in an exported project. Consider switching it to INPUT_SHAPE_RADIAL_POINTS, which stores the corners as data rather than as a node per corner.");
#endif
			} else if (!_get_guide_posts().is_empty()) {
				// Guide posts loaded for a shape that is no longer this node's, such as a scene whose shape a script changed
				// before adding it to the tree. The shape setter hands their positions over to the corners and removes them
				// when the node is ready, so the same happens here.
				_update_fence_corners_from_post_nodes();
				_remove_guide_posts();
			}
			if (_update_automatically) {
				queue_update_fence_mesh();
			}
		} break;
	}
}

void FenceGenerator4D::_update_fence_corners_from_box_size() {
	const Vector3 _box_half_extents = _box_size * 0.5;
	_fence_corners.resize(8); // A box has 8 corners.
	// The box size packs X, Z, W into X, Y, Z, so unpack back into X, Z, W.
	_fence_corners.set(0, Vector4(-_box_half_extents.x, 0.0, -_box_half_extents.y, -_box_half_extents.z));
	_fence_corners.set(1, Vector4(_box_half_extents.x, 0.0, -_box_half_extents.y, -_box_half_extents.z));
	_fence_corners.set(2, Vector4(_box_half_extents.x, 0.0, _box_half_extents.y, -_box_half_extents.z));
	_fence_corners.set(3, Vector4(-_box_half_extents.x, 0.0, _box_half_extents.y, -_box_half_extents.z));
	_fence_corners.set(4, Vector4(-_box_half_extents.x, 0.0, -_box_half_extents.y, _box_half_extents.z));
	_fence_corners.set(5, Vector4(_box_half_extents.x, 0.0, -_box_half_extents.y, _box_half_extents.z));
	_fence_corners.set(6, Vector4(_box_half_extents.x, 0.0, _box_half_extents.y, _box_half_extents.z));
	_fence_corners.set(7, Vector4(-_box_half_extents.x, 0.0, _box_half_extents.y, _box_half_extents.z));
}

// The seed mesh shapes hand their vertices over as the corners, like the box does, so that switching to a corner shape
// continues from the shape the fence had and the seed mesh can be left as it is.
void FenceGenerator4D::_update_fence_corners_from_seed_mesh() {
	ERR_FAIL_COND(_seed_mesh_4d.is_null());
	_fence_corners = _seed_mesh_4d->get_poly_cell_vertex_positions();
}

void FenceGenerator4D::set_fence_corners(const PackedVector4Array &p_fence_corners) {
	_fence_corners = p_fence_corners;
	if (_is_ready && _update_automatically) {
		_request_deferred_update();
	}
	_refresh_configuration_warnings();
}

void FenceGenerator4D::set_seed_mesh_3d(const Ref<Mesh> &p_seed_mesh_3d) {
	_seed_mesh_3d = p_seed_mesh_3d;
	if (_is_ready && _update_automatically) {
		_request_deferred_update();
	}
	_refresh_configuration_warnings();
}

void FenceGenerator4D::set_seed_mesh_4d(const Ref<PolyMesh4D> &p_seed_mesh_4d) {
	_seed_mesh_4d = p_seed_mesh_4d;
	if (_is_ready && _update_automatically) {
		_request_deferred_update();
	}
	_refresh_configuration_warnings();
}

void FenceGenerator4D::set_post_material(const Ref<Material4D> &p_post_material) {
	_post_material = p_post_material;
	if (_is_ready && _update_automatically) {
		_request_deferred_update();
	}
}

void FenceGenerator4D::set_rib_material(const Ref<Material4D> &p_rib_material) {
	_rib_material = p_rib_material;
	if (_is_ready && _update_automatically) {
		_request_deferred_update();
	}
}

void FenceGenerator4D::set_beam_material(const Ref<Material4D> &p_beam_material) {
	_beam_material = p_beam_material;
	if (_is_ready && _update_automatically) {
		_request_deferred_update();
	}
}

void FenceGenerator4D::set_box_size(const Vector3 &p_box_size) {
	ERR_FAIL_COND(p_box_size.x < 0.01 || p_box_size.y < 0.01 || p_box_size.z < 0.01);
	_box_size = p_box_size;
	if (_is_ready && _update_automatically && _input_shape_type == INPUT_SHAPE_BOX) {
		_request_deferred_update();
	}
}

void FenceGenerator4D::set_desired_spacing_meters(const double p_desired_spacing_meters) {
	ERR_FAIL_COND(p_desired_spacing_meters < 0.0);
	_desired_spacing_meters = p_desired_spacing_meters;
	if (_is_ready && _update_automatically) {
		_request_deferred_update();
	}
}

void FenceGenerator4D::set_post_height_meters(const double p_post_height_meters) {
	ERR_FAIL_COND(p_post_height_meters < 0.01);
	_post_height_meters = p_post_height_meters;
	if (_is_ready && _update_automatically) {
		_request_deferred_update();
	}
}

void FenceGenerator4D::set_post_thickness_meters(const double p_post_thickness_meters) {
	ERR_FAIL_COND(p_post_thickness_meters <= 0.0);
	_post_thickness_meters = p_post_thickness_meters;
	if (_is_ready && _update_automatically) {
		_request_deferred_update();
	}
}

void FenceGenerator4D::set_rib_height_ratio(const double p_rib_height_ratio) {
	ERR_FAIL_COND(p_rib_height_ratio <= 0.0 || p_rib_height_ratio > 1.0);
	_rib_height_ratio = p_rib_height_ratio;
	if (_is_ready && _update_automatically) {
		_request_deferred_update();
	}
}

void FenceGenerator4D::set_rib_thickness_ratio(const double p_rib_thickness_ratio) {
	ERR_FAIL_COND(p_rib_thickness_ratio <= 0.0 || p_rib_thickness_ratio > 1.0);
	_rib_thickness_ratio = p_rib_thickness_ratio;
	if (_is_ready && _update_automatically) {
		_request_deferred_update();
	}
}

void FenceGenerator4D::set_beam_max_height_ratio(const double p_beam_max_height_ratio) {
	ERR_FAIL_COND(p_beam_max_height_ratio <= 0.0 || p_beam_max_height_ratio > 1.0);
	_beam_max_height_ratio = p_beam_max_height_ratio;
	if (_is_ready && _update_automatically) {
		_request_deferred_update();
	}
}

void FenceGenerator4D::set_beam_coverage(const double p_beam_coverage) {
	ERR_FAIL_COND(p_beam_coverage < 0.0 || p_beam_coverage > 1.0);
	_beam_coverage = p_beam_coverage;
	if (_is_ready && _update_automatically) {
		_request_deferred_update();
	}
}

void FenceGenerator4D::set_beam_thickness_ratio(const double p_beam_thickness_ratio) {
	ERR_FAIL_COND(p_beam_thickness_ratio <= 0.0 || p_beam_thickness_ratio > 1.0);
	_beam_thickness_ratio = p_beam_thickness_ratio;
	if (_is_ready && _update_automatically) {
		_request_deferred_update();
	}
}

void FenceGenerator4D::set_beam_count(const int32_t p_beam_count) {
	// 100 is an arbitrary upper limit for performance sanity.
	// It can be increased if really needed (but it shouldn't be needed).
	ERR_FAIL_COND(p_beam_count < 0 || p_beam_count > 100);
	_beam_count = p_beam_count;
	if (_is_ready && _update_automatically) {
		_request_deferred_update();
	}
}

void FenceGenerator4D::set_input_shape_type(const InputShapeType p_input_shape_type) {
	const InputShapeType previous_shape_type = _input_shape_type;
	_input_shape_type = p_input_shape_type;
	if (_is_ready && previous_shape_type != p_input_shape_type) {
		if (previous_shape_type == INPUT_SHAPE_BOX) {
			// The box writes its corners when the fence is built, so with automatic updates off they can be behind the
			// box size. The other shapes start from the corners the box stands for now.
			_update_fence_corners_from_box_size();
		} else if ((previous_shape_type == INPUT_SHAPE_SEED_MESH_3D || previous_shape_type == INPUT_SHAPE_SEED_MESH_4D) && _seed_mesh_4d.is_valid()) {
			// Likewise the seed mesh's vertices, from the seed as last built, so that the other shapes continue from it.
			_update_fence_corners_from_seed_mesh();
		}
		// Guide posts exist only while they are in use. Entering their shape creates one per corner so that the layout
		// carries over, and leaving it copies their positions back into the corners before removing them, so that
		// nothing is lost in either direction, even with automatic updates off. While loading a scene the posts are
		// loaded along with everything else, so nothing is created or removed before the node is ready.
		if (p_input_shape_type == INPUT_SHAPE_RADIAL_POST_NODES) {
			_create_guide_posts_from_corners();
		} else if (previous_shape_type == INPUT_SHAPE_RADIAL_POST_NODES) {
			_update_fence_corners_from_post_nodes();
			_remove_guide_posts();
		}
	}
	if (_is_ready && _update_automatically) {
		_request_deferred_update();
	}
	notify_property_list_changed();
	_refresh_configuration_warnings();
}

void FenceGenerator4D::set_output_mesh_type(const OutputMeshType p_output_mesh_type) {
	_output_mesh_type = p_output_mesh_type;
	if (_is_ready && _update_automatically) {
		_request_deferred_update();
	}
}

void FenceGenerator4D::set_update_automatically(const bool p_update_automatically) {
	_update_automatically = p_update_automatically;
	if (_is_ready && _update_automatically) {
		_request_deferred_update();
	}
	notify_property_list_changed();
}

// Repacks a computed 3D convex hull into ArrayPolyMesh4D's edge and face arrays: edges as sorted vertex index pairs,
// and faces as loops of edge indices. The vertex indices refer to the hull's own vertex array.
bool FenceGenerator4D::_repack_convex_hull_topology(const ConvexHullComputer &p_convex_hull, PackedInt32Array &r_edge_vertex_indices, Vector<PackedInt32Array> &r_face_edge_indices) {
	// ConvexHullComputer::compute() always pushes half-edges in pairs, so the half-edge at index 2k
	// and its reverse at index 2k+1 together form undirected edge k. This is an implementation
	// detail rather than a documented guarantee, so it is verified below before relying on it.
	const ConvexHullComputer::Edge *half_edges = p_convex_hull.edges.ptr();
	const uint32_t half_edge_count = p_convex_hull.edges.size();
	ERR_FAIL_COND_V_MSG(half_edge_count % 2 != 0, false, "FenceGenerator4D: Convex hull half-edges are not paired.");
	const uint32_t edge_count = half_edge_count / 2;
	r_edge_vertex_indices.resize(edge_count * 2);
	for (uint32_t edge_index = 0; edge_index < edge_count; edge_index++) {
		const ConvexHullComputer::Edge *half_edge = &half_edges[edge_index * 2];
		ERR_FAIL_COND_V_MSG(half_edge->get_reverse_edge() != half_edge + 1, false, "FenceGenerator4D: Convex hull half-edge pair is not adjacent.");
		const int32_t vertex_a = half_edge->get_source_vertex();
		const int32_t vertex_b = half_edge->get_target_vertex();
		// ArrayPolyMesh4D stores each edge with the smaller vertex index first, see `append_edge_indices`.
		r_edge_vertex_indices.set(edge_index * 2, MIN(vertex_a, vertex_b));
		r_edge_vertex_indices.set(edge_index * 2 + 1, MAX(vertex_a, vertex_b));
	}
	// Each entry in `p_convex_hull.faces` is a single half-edge index belonging to that face, not a
	// run of indices. The full n-gon is recovered by walking `get_next_edge_of_face()` (which goes
	// counter-clockwise when viewed from outside the hull) until arriving back at the start.
	const uint32_t face_count = p_convex_hull.faces.size();
	r_face_edge_indices.resize(face_count);
	for (uint32_t face_index = 0; face_index < face_count; face_index++) {
		const int32_t face_starting_edge = p_convex_hull.faces[face_index]; // The rest follow this one in the half-edge loop.
		const ConvexHullComputer::Edge *start_half_edge = &half_edges[face_starting_edge];
		const ConvexHullComputer::Edge *half_edge = start_half_edge;
		PackedInt32Array face_edges;
		do {
			// Guard against a malformed loop, which would otherwise never terminate.
			ERR_FAIL_COND_V_MSG(face_edges.size() >= (int64_t)edge_count, false, "FenceGenerator4D: Convex hull face loop did not close.");
			const ptrdiff_t half_edge_start = half_edge - half_edges;
			face_edges.append((int32_t)(half_edge_start / 2));
			half_edge = half_edge->get_next_edge_of_face();
		} while (half_edge != start_half_edge);
		ERR_FAIL_COND_V_MSG(face_edges.size() < 3, false, "FenceGenerator4D: Convex hull produced a face with fewer than 3 edges.");
		r_face_edge_indices.set(face_index, face_edges);
	}
	return true;
}

// Whether the origin is strictly inside the given convex hull. The footprint is built as a star-shaped polyhedron around
// the fence's origin, which only works when the corners surround it: a hull of their directions that leaves the origin on
// or outside one of its faces means that all of the corners lie within one half of the directions, and the radial
// projection would fold the far side of the footprint over the near side, silently losing corners.
bool FenceGenerator4D::_does_convex_hull_surround_origin(const ConvexHullComputer &p_convex_hull) {
	const ConvexHullComputer::Edge *half_edges = p_convex_hull.edges.ptr();
	const uint32_t half_edge_count = p_convex_hull.edges.size();
	for (uint32_t face_index = 0; face_index < p_convex_hull.faces.size(); face_index++) {
		const ConvexHullComputer::Edge *start_edge = &half_edges[p_convex_hull.faces[face_index]];
		// The face's normal by Newell's method, summed over the whole loop, which keeps its direction for the slivers
		// that corners in nearly one direction produce, where any three vertices are too nearly collinear to use.
		Vector3 outward;
		const ConvexHullComputer::Edge *edge = start_edge;
		uint32_t steps = 0;
		do {
			const Vector3 &from = p_convex_hull.vertices[edge->get_source_vertex()];
			const Vector3 &to = p_convex_hull.vertices[edge->get_target_vertex()];
			outward += from.cross(to);
			edge = edge->get_next_edge_of_face();
			steps++;
		} while (edge != start_edge && steps <= half_edge_count);
		if (outward.length_squared() == (real_t)0.0) {
			continue;
		}
		// The loop runs counter-clockwise seen from outside, so the normal points out of the hull, and the origin is
		// inside when it lies on the inner side of every face's plane by more than a sliver.
		const Vector3 &on_face = p_convex_hull.vertices[start_edge->get_source_vertex()];
		if (outward.normalized().dot(on_face) <= (real_t)CMP_EPSILON) {
			return false;
		}
	}
	return true;
}

// The footprint from a set of corners, see `build_seed_mesh_from_corners`. This fails quietly, with the reason in
// `r_error`, since corners that do not yet span a volume are a normal state while a fence is being laid out.
Ref<ArrayPolyMesh4D> FenceGenerator4D::_build_seed_mesh_from_corners_internal(const PackedVector4Array &p_corners, String &r_error) {
	PackedVector3Array flat_corners;
	flat_corners.resize(p_corners.size());
	// Convert 4D fence corners to normalized 3D points for the 3D convex hull calculation.
	for (int i = 0; i < p_corners.size(); i++) {
		const Vector4 &corner = p_corners[i];
		flat_corners.set(i, Vector3(corner.x, corner.z, corner.w).normalized());
	}
	// Compute the convex hull of the normalized 3D points.
	ConvexHullComputer convex_hull;
	convex_hull.compute(flat_corners.ptr(), flat_corners.size(), 0.0, 0.0);
	// This uses LocalVector which uses `uint32_t` rather than Godot's usual `int64_t`.
	const uint32_t hull_point_count = convex_hull.vertices.size();
	// Fewer than 4 distinct hull points cannot enclose a 3D volume in XZW. Coplanar corners are
	// caught separately below by the face count, since a flat hull can still have 4+ vertices.
	if (hull_point_count < 4) {
		r_error = "FenceGenerator4D: Fence corners must span a 3D volume in XZW, got a degenerate convex hull with " + itos(hull_point_count) + " points.";
		return Ref<ArrayPolyMesh4D>();
	}
	// Remap those points back to 4D space, each hull vertex to the corner whose direction is nearest to it. The hull's
	// own vertex positions are quantized, so they never match exactly, and how far off they are depends on how far
	// apart the directions are, which a fixed tolerance would get wrong for a small fence far from its origin. Two
	// corners in one direction resolve to the first, and a corner the hull left out, such as one at the origin, is
	// lost, which is fine.
	PackedVector4Array mesh_corners;
	mesh_corners.resize(hull_point_count);
	for (uint32_t hull_index = 0; hull_index < hull_point_count; hull_index++) {
		const Vector3 &hull_point = convex_hull.vertices[hull_index];
		int64_t nearest_corner = -1;
		real_t nearest_distance_squared = Math_INF;
		for (int64_t flat_index = 0; flat_index < flat_corners.size(); flat_index++) {
			const real_t distance_squared = flat_corners[flat_index].distance_squared_to(hull_point);
			if (distance_squared < nearest_distance_squared) {
				nearest_distance_squared = distance_squared;
				nearest_corner = flat_index;
			}
		}
		mesh_corners.set(hull_index, p_corners[nearest_corner]);
	}
	// Repack the convex hull's half-edge structure into the format expected by ArrayPolyMesh4D.
	PackedInt32Array edge_vertex_indices;
	Vector<PackedInt32Array> face_edge_indices;
	if (!_repack_convex_hull_topology(convex_hull, edge_vertex_indices, face_edge_indices)) {
		r_error = "FenceGenerator4D: Failed to repack the convex hull of the fence corners.";
		return Ref<ArrayPolyMesh4D>();
	}
	// A tetrahedron is the simplest closed polyhedron. Coplanar input yields a flat hull with fewer faces.
	if (face_edge_indices.size() < 4) {
		r_error = "FenceGenerator4D: Fence corners must span a 3D volume in XZW, got a flat convex hull with " + itos(face_edge_indices.size()) + " faces.";
		return Ref<ArrayPolyMesh4D>();
	}
	if (!_does_convex_hull_surround_origin(convex_hull)) {
		r_error = "FenceGenerator4D: Fence corners must surround the fence's origin, since the footprint is built as a star-shaped polyhedron around it.";
		return Ref<ArrayPolyMesh4D>();
	}
	Vector<Vector<PackedInt32Array>> poly_cell_indices;
	poly_cell_indices.push_back(face_edge_indices); // Poly index 0 is dimension 2: faces made of edges.
	// Set the mesh corners and convex hull data into the returned seed mesh.
	Ref<ArrayPolyMesh4D> seed_mesh;
	seed_mesh.instantiate();
	seed_mesh->set_poly_cell_vertex_positions(mesh_corners);
	seed_mesh->set_edge_vertex_indices(edge_vertex_indices);
	seed_mesh->set_poly_cell_indices(poly_cell_indices);
	// The hull was taken on the corners' directions, so a face whose corners are not all at one height is warped, and
	// since a beam has to be flat, such faces are split into flat triangles: a box face with one corner raised along
	// its level diagonal, into a flat triangle and a leaning one.
	PolyMeshBuilder4D::make_coplanar(seed_mesh);
	// The hull's own coplanar merging works on quantized coordinates, so faces that are not axis-aligned may come
	// out split into triangles. Merging them keeps each footprint face a single beam.
	PolyMeshBuilder4D::merge_coplanar_faces(seed_mesh);
	return seed_mesh;
}

Ref<ArrayPolyMesh4D> FenceGenerator4D::build_seed_mesh_from_corners() const {
	String error;
	const Ref<ArrayPolyMesh4D> seed_mesh = _build_seed_mesh_from_corners_internal(_fence_corners, error);
	ERR_FAIL_COND_V_MSG(seed_mesh.is_null(), Ref<ArrayPolyMesh4D>(), error);
	return seed_mesh;
}

// Makes sure every face of the seed mesh has a normal, computing the ones that are missing or zero. The fence reads
// only the seed's per-face normals: the beam slab takes its mitered offsets from them, and the ribs their orientation.
bool FenceGenerator4D::_ensure_seed_mesh_4d_has_face_normals() {
	ERR_FAIL_COND_V(!_seed_mesh_4d.is_valid(), false);
	const Vector<Vector<PackedInt32Array>> poly_cell_indices = _seed_mesh_4d->get_poly_cell_indices();
	ERR_FAIL_COND_V_MSG(poly_cell_indices.is_empty(), false, "FenceGenerator4D: The seed mesh has no faces.");
	const int64_t face_count = poly_cell_indices[0].size();
	Vector<PackedVector4Array> face_normals = _seed_mesh_4d->get_poly_cell_dense_normals(PolyMesh4D::PER_FACE_KEY);
	// A binding that is missing or short gets computed, and so does one with a zero entry, which is how a face
	// without a normal is stored in a binding that covers every face.
	bool needs_computing = face_normals.is_empty() || face_normals[0].size() != face_count;
	if (!needs_computing) {
		for (const Vector4 &face_normal : face_normals[0]) {
			if (face_normal.is_zero_approx()) {
				needs_computing = true;
				break;
			}
		}
	}
	if (needs_computing) {
		// Calculating normals writes to the mesh, so make sure it is writable.
		Ref<ArrayPolyMesh4D> array_seed_mesh = _seed_mesh_4d;
		if (array_seed_mesh.is_null()) {
			array_seed_mesh = _seed_mesh_4d->to_array_poly_mesh();
			_seed_mesh_4d = array_seed_mesh;
		}
		// The seed mesh lies in the XZW ground hyperplane, so its face normals lie in it too, with no Y component.
		// A seed with normals for only some of its faces keeps those and gets the rest computed.
		array_seed_mesh->calculate_face_normals(Vector4(0, 1, 0, 0), true);
		face_normals = array_seed_mesh->get_poly_cell_dense_normals(PolyMesh4D::PER_FACE_KEY);
	}
	ERR_FAIL_COND_V(face_normals.is_empty() || face_normals[0].size() != face_count, false);
	for (const Vector4 &face_normal : face_normals[0]) {
		ERR_FAIL_COND_V_MSG(face_normal.is_zero_approx(), false, "FenceGenerator4D: The seed mesh has a degenerate face, so its normal cannot be determined.");
	}
	return _seed_mesh_4d->is_mesh_data_valid();
}

// Texture mapping. Every part is textured the same way, by `ArrayPolyMesh4D::unwrap_texture_map_upright`: the cells
// with a horizontal normal, which are what a viewer mostly sees, get V along the height and their horizontal
// directions on U and W, and the cells facing up or down hang off them in the unfold. Each island then fills the unit
// cube of texture space with its proportions kept. Coordinates outside that range are valid, but staying inside it is
// strongly recommended: the renderer packs texture coordinates into vertex attributes whose precision is best there,
// see the proxy mesh in `TetraMesh4D`, and a texture then repeats evenly across a part, with the material's texture
// map scale setting how often.

// The guide posts among the children, in child order. Other children are left alone, so a fence can have children of its
// own, such as a body for collision.
Vector<FenceGuidePost4D *> FenceGenerator4D::_get_guide_posts() const {
	Vector<FenceGuidePost4D *> guide_posts;
	const int child_count = get_child_count();
	for (int child_index = 0; child_index < child_count; child_index++) {
		FenceGuidePost4D *guide_post = Object::cast_to<FenceGuidePost4D>(get_child(child_index));
		if (guide_post != nullptr) {
			guide_posts.push_back(guide_post);
		}
	}
	return guide_posts;
}

// In the guide post shape the posts are the source of truth and the corners follow them.
void FenceGenerator4D::_update_fence_corners_from_post_nodes() {
	const Vector<FenceGuidePost4D *> guide_posts = _get_guide_posts();
	_fence_corners.resize(guide_posts.size());
	for (int64_t post_index = 0; post_index < guide_posts.size(); post_index++) {
		_fence_corners.set(post_index, guide_posts[post_index]->get_position());
	}
}

// Creates a guide post at every corner that does not have one yet. The posts are owned by the scene so that they are
// saved with it, and the fence does not react to the children it adds here.
void FenceGenerator4D::_create_guide_posts_from_corners() {
	_updating_guide_posts = true;
	const Vector<FenceGuidePost4D *> existing_posts = _get_guide_posts();
	// A node without an owner is the root of its scene, and then owns its new children itself.
	Node *owner = get_owner() != nullptr ? get_owner() : this;
	for (const Vector4 &corner : _fence_corners) {
		bool has_post = false;
		for (const FenceGuidePost4D *existing_post : existing_posts) {
			if (existing_post->get_position().is_equal_approx(corner)) {
				has_post = true;
				break;
			}
		}
		if (has_post) {
			continue;
		}
		FenceGuidePost4D *guide_post = memnew(FenceGuidePost4D);
		guide_post->set_name("GuidePost");
		// Positioned before it has a parent, so the position change does not come back as a guide post change.
		guide_post->set_position(corner);
		add_child(guide_post, true);
		guide_post->set_owner(owner);
	}
	_updating_guide_posts = false;
}

// Removes every guide post without the fence reacting to it. The posts are freed at the end of the frame rather than
// right away, since the editor may still be showing one of them.
void FenceGenerator4D::_remove_guide_posts() {
	_updating_guide_posts = true;
	for (FenceGuidePost4D *guide_post : _get_guide_posts()) {
		remove_child(guide_post);
		guide_post->queue_free();
	}
	_updating_guide_posts = false;
}

// A child change matters when it is a guide post that the user adds, removes, or reorders while the fence is live and in
// the guide post shape, whether or not the fence is in the tree at the time. The fence adds and removes posts itself
// when the shape changes, and when a scene is freed, the rebuild this asks for finds no fence left and is dropped. The
// rebuild is deferred, since this node cannot change its own children while one is being added or removed, and a
// departing post still counts among them at this point.
void FenceGenerator4D::_on_guide_post_child_changed(Node *p_child) {
	if (Object::cast_to<FenceGuidePost4D>(p_child) == nullptr || _updating_guide_posts || !_is_ready || _input_shape_type != INPUT_SHAPE_RADIAL_POST_NODES) {
		return;
	}
	_request_deferred_update();
}

void FenceGenerator4D::add_child_notify(Node *p_child) {
	MeshInstance4D::add_child_notify(p_child);
	_on_guide_post_child_changed(p_child);
}

void FenceGenerator4D::remove_child_notify(Node *p_child) {
	MeshInstance4D::remove_child_notify(p_child);
	_on_guide_post_child_changed(p_child);
}

// Of two guide posts at one position, the first in child order gets the mesh, so their order matters as well.
void FenceGenerator4D::move_child_notify(Node *p_child) {
	MeshInstance4D::move_child_notify(p_child);
	_on_guide_post_child_changed(p_child);
}

// Called by a guide post when it has moved.
void FenceGenerator4D::notify_guide_post_changed() {
	if (_updating_guide_posts || !_is_ready || _input_shape_type != INPUT_SHAPE_RADIAL_POST_NODES) {
		return;
	}
	_request_deferred_update();
}

// Several guide posts can change within one frame, such as while one is dragged or when several are deleted together,
// so the fence is rebuilt once at the end of the frame rather than once per change.
void FenceGenerator4D::_request_deferred_update() {
	if (_deferred_update_pending) {
		return;
	}
	_deferred_update_pending = true;
	callable_mp(this, &FenceGenerator4D::_deferred_update).call_deferred();
}

void FenceGenerator4D::_deferred_update() {
	_deferred_update_pending = false;
	if (!_is_ready) {
		return;
	}
	if (_update_automatically) {
		queue_update_fence_mesh();
	} else if (_input_shape_type == INPUT_SHAPE_RADIAL_POST_NODES) {
		// The stored corners follow the posts even when the mesh waits for a manual update.
		_update_fence_corners_from_post_nodes();
	}
	_refresh_configuration_warnings();
}

// Clears the fence, its footprint, and its guide posts' meshes, for a shape whose source is incomplete. Without a
// footprint nothing is inside the fence, see `is_local_point_inside`, and no post can be called degenerate, so that
// warning is cleared too.
void FenceGenerator4D::_clear_fence_mesh() {
	_seed_mesh_4d.unref();
	set_mesh(Ref<Mesh4D>());
	for (FenceGuidePost4D *guide_post : _get_guide_posts()) {
		guide_post->set_mesh(Ref<Mesh4D>());
		guide_post->set_is_degenerate(false);
	}
}

// The warnings of the guide posts depend on the fence's shape and on each other, so they are refreshed together.
void FenceGenerator4D::_refresh_configuration_warnings() {
	update_configuration_warnings();
	for (FenceGuidePost4D *guide_post : _get_guide_posts()) {
		guide_post->update_configuration_warnings();
	}
}

// Filler posts and ribs. A seed face much larger than the desired spacing would have no vertical support across its
// middle, so each such face gets ribs across it, and posts where those ribs meet each other and the ribs along the
// edges. The division of every seed edge is decided first, so that the two faces sharing an edge continue from the same
// points, and then each face is filled with chords between the division points on its boundary. Nothing is written back
// to the seed mesh, and the existing ribs and beams are left whole where the filler meets them.

// Makes the seed ready for a build: a face that is not flat is split into flat ones in place, since a beam has to be
// flat, and a face without a normal gets one computed, both edits in place like `make_coplanar` and
// `calculate_face_normals` make them. Only an ArrayPolyMesh4D can be edited, and the other seeds are primitives, which
// are flat by construction and have their normals.
bool FenceGenerator4D::_prepare_seed_mesh_4d() {
	ERR_FAIL_COND_V(!_seed_mesh_4d.is_valid(), false);
	const Ref<ArrayPolyMesh4D> array_seed_mesh = _seed_mesh_4d;
	if (array_seed_mesh.is_valid()) {
		PolyMeshBuilder4D::make_coplanar(array_seed_mesh);
	}
	return _ensure_seed_mesh_4d_has_face_normals();
}

// Builds the fence from the current seed mesh on the calling thread and returns it without assigning it, see
// `update_fence_mesh_now`. The guide posts of the post shape do get their meshes, as in a full update.
Ref<Mesh4D> FenceGenerator4D::build_fence_from_seed_mesh() {
	ERR_FAIL_COND_V(!_seed_mesh_4d.is_valid(), Ref<Mesh4D>());
	ERR_FAIL_COND_V(!_prepare_seed_mesh_4d(), Ref<Mesh4D>());
	Ref<FenceBuildJob4D> job;
	job.instantiate();
	job->snapshot_from(this, _fence_generation_id);
	job->run();
	_apply_guide_post_results(job.ptr());
	return job->get_fence_mesh();
}

// Derives the seed mesh from the shape's source and makes it ready for a build, see `_prepare_seed_mesh_4d`, on the
// calling thread. Returns false when the shape has no complete source yet, which leaves the fence empty and is a
// configuration warning, or when the seed cannot be built, which is an error.
bool FenceGenerator4D::_update_seed_mesh() {
	// Update the seed mesh based on the current shape type.
	switch (_input_shape_type) {
		case InputShapeType::INPUT_SHAPE_BOX: {
			_update_fence_corners_from_box_size();
			_seed_mesh_4d = build_seed_mesh_from_corners();
		} break;
		case InputShapeType::INPUT_SHAPE_RADIAL_POST_NODES:
			_update_fence_corners_from_post_nodes();
			[[fallthrough]];
		case InputShapeType::INPUT_SHAPE_RADIAL_POINTS: {
			// Too few corners to surround the origin: corners that do not span a 3D volume,
			// such as four posts placed in one 3D slice, or corners all to one side of the origin.
			// This is the normal state while a fence is laid out one guide post at a time, so it is a
			// configuration warning rather than an error, and the fence is empty until the layout is complete.
			String error;
			Ref<ArrayPolyMesh4D> seed_mesh;
			if (_fence_corners.size() >= 4) {
				seed_mesh = _build_seed_mesh_from_corners_internal(_fence_corners, error);
			}
			_corners_surround_origin = seed_mesh.is_valid();
			if (seed_mesh.is_null()) {
				_clear_fence_mesh();
				_refresh_configuration_warnings();
				return false;
			}
			_seed_mesh_4d = seed_mesh;
		} break;
		case InputShapeType::INPUT_SHAPE_SEED_MESH_3D: {
			if (_seed_mesh_3d.is_null()) {
				// A shape without its source yet is a configuration warning rather than an error, like too few corners.
				_clear_fence_mesh();
				_refresh_configuration_warnings();
				return false;
			}
			Ref<ArrayPolyMesh4D> array_seed_mesh_4d = PolyMeshBuilder4D::convert_mesh_3d_to_4d_faces_only(_seed_mesh_3d);
			ERR_FAIL_COND_V_MSG(array_seed_mesh_4d.is_null(), false, "FenceGenerator4D: Failed to convert the 3D seed mesh.");
			// Exported meshes can carry zero-area triangles, which have no normal to build a beam along, so the derived
			// seed drops them before anything else looks at them, and then the edges no face uses any more, so that
			// nothing stands on their vertices either. The converted mesh lies in the XYZ hyperplane at this point.
			const PackedVector4Array converted_face_normals = array_seed_mesh_4d->compute_face_normals(Vector4(0, 0, 0, 1));
			for (int64_t face_index = converted_face_normals.size() - 1; face_index >= 0; face_index--) {
				if (converted_face_normals[face_index].is_zero_approx()) {
					array_seed_mesh_4d->delete_poly_element(2, (int32_t)face_index);
				}
			}
			const Vector<Vector<PackedInt32Array>> remaining_poly_indices = array_seed_mesh_4d->get_poly_cell_indices();
			const int64_t converted_edge_count = array_seed_mesh_4d->get_edge_indices().size() / 2;
			Vector<bool> edge_has_face;
			edge_has_face.resize(converted_edge_count);
			edge_has_face.fill(false);
			if (!remaining_poly_indices.is_empty()) {
				for (const PackedInt32Array &face_edges : remaining_poly_indices[0]) {
					for (const int32_t edge_index : face_edges) {
						edge_has_face.set(edge_index, true);
					}
				}
			}
			for (int64_t edge_index = converted_edge_count - 1; edge_index >= 0; edge_index--) {
				if (!edge_has_face[edge_index]) {
					array_seed_mesh_4d->delete_poly_element(1, (int32_t)edge_index);
				}
			}
			// 3D meshes only have triangles, and exporters such as Blender's glTF export triangulate quads, so put
			// coplanar triangles back together into single faces, which become single beams.
			PolyMeshBuilder4D::merge_coplanar_faces(array_seed_mesh_4d);
			array_seed_mesh_4d->transform_mesh(Transform4D(Vector4(1, 0, 0, 0), Vector4(0, 0, 1, 0), Vector4(0, 0, 0, 1), Vector4(0, 1, 0, 0)));
			_seed_mesh_4d = array_seed_mesh_4d;
			_update_fence_corners_from_seed_mesh();
		} break;
		case InputShapeType::INPUT_SHAPE_SEED_MESH_4D: {
			if (_seed_mesh_4d.is_null()) {
				_clear_fence_mesh();
				_refresh_configuration_warnings();
				return false;
			}
			_update_fence_corners_from_seed_mesh();
		} break;
	}
	ERR_FAIL_COND_V_MSG(_seed_mesh_4d.is_null(), false, "FenceGenerator4D: Failed to build seed mesh.");
	return _prepare_seed_mesh_4d();
}

// Updates the seed from the shape's source on the calling thread, see `_update_seed_mesh`, and builds the fence mesh on
// a worker thread, see `FenceBuildJob4D`. One build runs at a time: a request made while one runs is remembered, and a
// fresh build follows the running one, with the inputs as they are then, so that a drag of a guide post has at most
// one build running and one waiting. On a build without worker threads the pool runs the build on the calling thread,
// and the result arrives the same way, just at the next message queue flush.
void FenceGenerator4D::queue_update_fence_mesh() {
	if (_is_fence_currently_generating) {
		_is_fence_generation_queued = true;
		return;
	}
	if (!_update_seed_mesh()) {
		emit_signal(SNAME("fence_mesh_updated"));
		return;
	}
	_fence_generation_id++;
	Ref<FenceBuildJob4D> job;
	job.instantiate();
	job->snapshot_from(this, _fence_generation_id);
	_is_fence_currently_generating = true;
	job->start_threaded();
}

// Updates the seed and builds the fence mesh on the calling thread, so that both are in place when this returns. A
// build running on a worker thread meanwhile has older inputs, so its result is dropped when it arrives, and a request
// waiting behind it is satisfied by this one.
void FenceGenerator4D::update_fence_mesh_now() {
	_fence_generation_id++;
	_is_fence_generation_queued = false;
	if (!_update_seed_mesh()) {
		emit_signal(SNAME("fence_mesh_updated"));
		return;
	}
	Ref<FenceBuildJob4D> job;
	job.instantiate();
	job->snapshot_from(this, _fence_generation_id);
	job->run();
	_apply_build_job(job.ptr());
}

// Called on the main thread by a job whose task has run, see `FenceBuildJob4D::_finish_on_main_thread`. A result from
// before a synchronous update is stale and dropped, and a request made during the build starts a fresh one.
void FenceGenerator4D::_on_build_job_finished(FenceBuildJob4D *p_job) {
	_is_fence_currently_generating = false;
	if (p_job->get_generation_id() == _fence_generation_id) {
		_apply_build_job(p_job);
	}
	if (_is_fence_generation_queued) {
		_is_fence_generation_queued = false;
		queue_update_fence_mesh();
	}
}

// Puts a finished build in place: the fence's mesh, the guide posts' meshes, and the warnings, and tells whoever waits.
void FenceGenerator4D::_apply_build_job(FenceBuildJob4D *p_job) {
	const Ref<Mesh4D> fence_mesh = p_job->get_fence_mesh();
	if (fence_mesh.is_valid()) {
		set_mesh(fence_mesh);
		_apply_guide_post_results(p_job);
	} else {
		ERR_PRINT("FenceGenerator4D: Failed to build fence mesh.");
	}
	_refresh_configuration_warnings();
	emit_signal(SNAME("fence_mesh_updated"));
}

// Hands the guide posts the meshes a job built for them, see `FenceBuildJob4D`. A post that has been removed or freed
// since the job was made is skipped, which is why the job refers to them by id.
void FenceGenerator4D::_apply_guide_post_results(FenceBuildJob4D *p_job) {
	for (int64_t post_index = 0; post_index < p_job->_guide_post_ids.size(); post_index++) {
		FenceGuidePost4D *guide_post = Object::cast_to<FenceGuidePost4D>(ObjectDB::get_instance(p_job->_guide_post_ids[post_index]));
		if (guide_post == nullptr || guide_post->get_parent() != this) {
			continue;
		}
		guide_post->set_mesh(p_job->_guide_post_meshes[post_index]);
		guide_post->set_is_degenerate(p_job->_guide_post_degenerate[post_index]);
	}
}

// Whether a point is inside the fence: its projection onto the ground lies within the footprint, which is the seed as
// last built, whatever the point's height. The footprint is a closed surface of faces over the ground hyperplane, so
// the test is the winding number of the point around it, measured within that hyperplane, which handles the
// star-shaped footprint a pushed corner makes as well as a convex one, and gives an open footprint, which encloses
// nothing, less than a half everywhere. The sign only tells which way the faces are oriented, so it is dropped.
bool FenceGenerator4D::is_local_point_inside(const Vector4 &p_local_point) const {
	if (_seed_mesh_4d.is_null()) {
		return false; // No footprint yet, or a shape whose source is incomplete, see `_clear_fence_mesh`.
	}
	return Math::abs(_seed_mesh_4d->compute_face_winding_number(p_local_point, Vector4(0, 1, 0, 0))) > (real_t)0.5;
}

bool FenceGenerator4D::is_global_point_inside(const Vector4 &p_global_point) const {
	return is_local_point_inside(global_to_local(p_global_point));
}

// A shape whose source is incomplete is a warning rather than an error, see `_update_seed_mesh`. Whether the corners
// surround the origin is known from the last build, so with automatic updates off it reflects the last manual update.
PackedStringArray FenceGenerator4D::get_configuration_warnings() const {
	PackedStringArray warnings = MeshInstance4D::get_configuration_warnings();
	switch (_input_shape_type) {
		case INPUT_SHAPE_RADIAL_POINTS: {
			if (_fence_corners.size() < 4 || !_corners_surround_origin) {
				warnings.push_back(RTR("The Radial Points shape needs at least 4 fence corners that span a 3D volume in XZW and surround this node's origin."));
			}
		} break;
		case INPUT_SHAPE_RADIAL_POST_NODES: {
			if (_get_guide_posts().size() < 4 || !_corners_surround_origin) {
				warnings.push_back(RTR("The Radial Posts shape needs at least 4 FenceGuidePost4D children that span a 3D volume in XZW and surround this node's origin."));
			}
		} break;
		case INPUT_SHAPE_SEED_MESH_3D: {
			if (_seed_mesh_3d.is_null()) {
				warnings.push_back(RTR("The Seed Mesh 3D shape needs a Mesh in Seed Mesh 3D."));
			}
		} break;
		case INPUT_SHAPE_SEED_MESH_4D: {
			if (_seed_mesh_4d.is_null()) {
				warnings.push_back(RTR("The Seed Mesh 4D shape needs a PolyMesh4D in Seed Mesh 4D."));
			}
		} break;
		default:
			break;
	}
	return warnings;
}

// The inspector's "Update Fence Mesh" button calls this, see `PROPERTY_HINT_TOOL_BUTTON` in `_bind_methods`. A Callable
// made from the object and the method's name stays valid for as long as the node does, and no custom callable is needed.
Callable FenceGenerator4D::_get_update_fence_mesh_button() const {
	return Callable(this, SNAME("queue_update_fence_mesh"));
}

void FenceGenerator4D::_validate_property(PropertyInfo &p_property) const {
	// The fence is rebuilt when the scene loads while automatic updates are on, so saving the generated mesh would only
	// bloat the scene file. With automatic updates off, the saved mesh is what the scene shows until a manual update.
	if (p_property.name == StringName("mesh") && _update_automatically) {
		p_property.usage = _update_automatically ? PROPERTY_USAGE_EDITOR : PROPERTY_USAGE_DEFAULT;
	}
	if (p_property.name == StringName("update_fence_mesh_button")) {
		p_property.usage = _update_automatically ? PROPERTY_USAGE_INTERNAL : (PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_INTERNAL);
	}
	// Store these properties even if not used to avoid data loss when changing the shape type.
	if (p_property.name == StringName("fence_corners")) {
		if (_input_shape_type == InputShapeType::INPUT_SHAPE_RADIAL_POINTS) {
			p_property.usage = PROPERTY_USAGE_DEFAULT;
		} else {
			// In the other shapes the corners are derived from the shape's source when the fence is built, so they are
			// saved only as a backup: when updates are manual, since then nothing rebuilds them on load, or when the source
			// is missing, so that a seed mesh that goes away or posts that are lost do not take the layout with them.
			bool source_available = true;
			switch (_input_shape_type) {
				case INPUT_SHAPE_RADIAL_POST_NODES:
					source_available = !_get_guide_posts().is_empty();
					break;
				case INPUT_SHAPE_SEED_MESH_3D:
					source_available = _seed_mesh_3d.is_valid();
					break;
				case INPUT_SHAPE_SEED_MESH_4D:
					source_available = _seed_mesh_4d.is_valid();
					break;
				default:
					break;
			}
			p_property.usage = _update_automatically && source_available ? PROPERTY_USAGE_NONE : PROPERTY_USAGE_STORAGE;
		}
	}
	if (p_property.name == StringName("box_size")) {
		p_property.usage = _input_shape_type == InputShapeType::INPUT_SHAPE_BOX ? PROPERTY_USAGE_DEFAULT : PROPERTY_USAGE_STORAGE;
	}
	if (p_property.name == StringName("seed_mesh_3d")) {
		p_property.usage = _input_shape_type == InputShapeType::INPUT_SHAPE_SEED_MESH_3D ? PROPERTY_USAGE_DEFAULT : PROPERTY_USAGE_STORAGE;
	}
	// Don't store `seed_mesh_4d` if it's derived data generated from another source shape type.
	// It's not useful as a cache because this would be regenerated every time anyway, and the whole mesh serves a cache already.
	if (p_property.name == StringName("seed_mesh_4d")) {
		p_property.usage = _input_shape_type == InputShapeType::INPUT_SHAPE_SEED_MESH_4D ? PROPERTY_USAGE_DEFAULT : PROPERTY_USAGE_NONE;
	}
}

void FenceGenerator4D::_bind_methods() {
	ClassDB::bind_method(D_METHOD("get_update_automatically"), &FenceGenerator4D::get_update_automatically);
	ClassDB::bind_method(D_METHOD("set_update_automatically", "update_automatically"), &FenceGenerator4D::set_update_automatically);
	ADD_PROPERTY(PropertyInfo(Variant::BOOL, "update_automatically"), "set_update_automatically", "get_update_automatically");
	// A button in the inspector that regenerates the fence, shown while automatic updates are off. It is an editor
	// affordance rather than data, so it is neither stored nor documented, and its getter is bound first since
	// `ADD_PROPERTY` checks for it.
	ClassDB::bind_method(D_METHOD("_get_update_fence_mesh_button"), &FenceGenerator4D::_get_update_fence_mesh_button);
	ADD_PROPERTY(PropertyInfo(Variant::CALLABLE, "update_fence_mesh_button", PROPERTY_HINT_TOOL_BUTTON, "Update Fence Mesh,Reload", PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_INTERNAL), "", "_get_update_fence_mesh_button");

	ADD_GROUP("Source Data", "");
	ClassDB::bind_method(D_METHOD("get_input_shape_type"), &FenceGenerator4D::get_input_shape_type);
	ClassDB::bind_method(D_METHOD("set_input_shape_type", "input_shape_type"), &FenceGenerator4D::set_input_shape_type);
	ClassDB::bind_method(D_METHOD("get_fence_corners"), &FenceGenerator4D::get_fence_corners);
	ClassDB::bind_method(D_METHOD("set_fence_corners", "fence_corners"), &FenceGenerator4D::set_fence_corners);
	ClassDB::bind_method(D_METHOD("get_box_size"), &FenceGenerator4D::get_box_size);
	ClassDB::bind_method(D_METHOD("set_box_size", "box_size"), &FenceGenerator4D::set_box_size);
	ClassDB::bind_method(D_METHOD("get_seed_mesh_3d"), &FenceGenerator4D::get_seed_mesh_3d);
	ClassDB::bind_method(D_METHOD("set_seed_mesh_3d", "seed_mesh_3d"), &FenceGenerator4D::set_seed_mesh_3d);
	ClassDB::bind_method(D_METHOD("get_seed_mesh_4d"), &FenceGenerator4D::get_seed_mesh_4d);
	ClassDB::bind_method(D_METHOD("set_seed_mesh_4d", "seed_mesh_4d"), &FenceGenerator4D::set_seed_mesh_4d);
	ADD_PROPERTY(PropertyInfo(Variant::INT, "input_shape_type", PROPERTY_HINT_ENUM, "Box,Radial Points,Radial Posts,Seed Mesh 3D,Seed Mesh 4D"), "set_input_shape_type", "get_input_shape_type");
	ADD_PROPERTY(PropertyInfo(Variant::VECTOR3, "box_size", PROPERTY_HINT_RANGE, "0.01,100,0.001,or_greater,suffix:m"), "set_box_size", "get_box_size");
	ADD_PROPERTY(PropertyInfo(Variant::PACKED_VECTOR4_ARRAY, "fence_corners"), "set_fence_corners", "get_fence_corners");
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "seed_mesh_3d", PROPERTY_HINT_RESOURCE_TYPE, "Mesh"), "set_seed_mesh_3d", "get_seed_mesh_3d");
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "seed_mesh_4d", PROPERTY_HINT_RESOURCE_TYPE, "PolyMesh4D"), "set_seed_mesh_4d", "get_seed_mesh_4d");
	// Changing the shape overwrites these two, so the inspector's undo of a shape change restores them along with it.
	ADD_LINKED_PROPERTY("input_shape_type", "fence_corners");
	ADD_LINKED_PROPERTY("input_shape_type", "seed_mesh_4d");

	ADD_GROUP("Output Mesh", "");
	ClassDB::bind_method(D_METHOD("get_output_mesh_type"), &FenceGenerator4D::get_output_mesh_type);
	ClassDB::bind_method(D_METHOD("set_output_mesh_type", "output_mesh_type"), &FenceGenerator4D::set_output_mesh_type);
	ClassDB::bind_method(D_METHOD("get_beam_material"), &FenceGenerator4D::get_beam_material);
	ClassDB::bind_method(D_METHOD("set_beam_material", "beam_material"), &FenceGenerator4D::set_beam_material);
	ClassDB::bind_method(D_METHOD("get_rib_material"), &FenceGenerator4D::get_rib_material);
	ClassDB::bind_method(D_METHOD("set_rib_material", "rib_material"), &FenceGenerator4D::set_rib_material);
	ClassDB::bind_method(D_METHOD("get_post_material"), &FenceGenerator4D::get_post_material);
	ClassDB::bind_method(D_METHOD("set_post_material", "post_material"), &FenceGenerator4D::set_post_material);
	ADD_PROPERTY(PropertyInfo(Variant::INT, "output_mesh_type", PROPERTY_HINT_ENUM, "Poly Volumetric,Poly Surface,Tetra,Wire"), "set_output_mesh_type", "get_output_mesh_type");
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "beam_material", PROPERTY_HINT_RESOURCE_TYPE, "Material4D"), "set_beam_material", "get_beam_material");
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "rib_material", PROPERTY_HINT_RESOURCE_TYPE, "Material4D"), "set_rib_material", "get_rib_material");
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "post_material", PROPERTY_HINT_RESOURCE_TYPE, "Material4D"), "set_post_material", "get_post_material");

	ADD_GROUP("Post Settings", ""); // Include rib settings in here too.
	ClassDB::bind_method(D_METHOD("get_desired_spacing_meters"), &FenceGenerator4D::get_desired_spacing_meters);
	ClassDB::bind_method(D_METHOD("set_desired_spacing_meters", "desired_spacing_meters"), &FenceGenerator4D::set_desired_spacing_meters);
	ClassDB::bind_method(D_METHOD("get_post_height_meters"), &FenceGenerator4D::get_post_height_meters);
	ClassDB::bind_method(D_METHOD("set_post_height_meters", "post_height_meters"), &FenceGenerator4D::set_post_height_meters);
	ClassDB::bind_method(D_METHOD("get_post_thickness_meters"), &FenceGenerator4D::get_post_thickness_meters);
	ClassDB::bind_method(D_METHOD("set_post_thickness_meters", "post_thickness_meters"), &FenceGenerator4D::set_post_thickness_meters);
	ClassDB::bind_method(D_METHOD("get_rib_height_ratio"), &FenceGenerator4D::get_rib_height_ratio);
	ClassDB::bind_method(D_METHOD("set_rib_height_ratio", "rib_height_ratio"), &FenceGenerator4D::set_rib_height_ratio);
	ClassDB::bind_method(D_METHOD("get_rib_thickness_ratio"), &FenceGenerator4D::get_rib_thickness_ratio);
	ClassDB::bind_method(D_METHOD("set_rib_thickness_ratio", "rib_thickness_ratio"), &FenceGenerator4D::set_rib_thickness_ratio);
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "desired_spacing_meters", PROPERTY_HINT_RANGE, "0,10,0.01,or_greater,suffix:m"), "set_desired_spacing_meters", "get_desired_spacing_meters");
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "post_height_meters", PROPERTY_HINT_RANGE, "0.01,10,0.01,or_greater,suffix:m"), "set_post_height_meters", "get_post_height_meters");
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "post_thickness_meters", PROPERTY_HINT_RANGE, "0.01,1,0.001,or_greater,suffix:m"), "set_post_thickness_meters", "get_post_thickness_meters");
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "rib_height_ratio", PROPERTY_HINT_RANGE, "0.001,0.999,0.001"), "set_rib_height_ratio", "get_rib_height_ratio");
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "rib_thickness_ratio", PROPERTY_HINT_RANGE, "0.001,0.999,0.001"), "set_rib_thickness_ratio", "get_rib_thickness_ratio");

	ADD_GROUP("Beam Settings", "");
	ClassDB::bind_method(D_METHOD("get_beam_max_height_ratio"), &FenceGenerator4D::get_beam_max_height_ratio);
	ClassDB::bind_method(D_METHOD("set_beam_max_height_ratio", "beam_max_height_ratio"), &FenceGenerator4D::set_beam_max_height_ratio);
	ClassDB::bind_method(D_METHOD("get_beam_coverage"), &FenceGenerator4D::get_beam_coverage);
	ClassDB::bind_method(D_METHOD("set_beam_coverage", "beam_coverage"), &FenceGenerator4D::set_beam_coverage);
	ClassDB::bind_method(D_METHOD("get_beam_thickness_ratio"), &FenceGenerator4D::get_beam_thickness_ratio);
	ClassDB::bind_method(D_METHOD("set_beam_thickness_ratio", "beam_thickness_ratio"), &FenceGenerator4D::set_beam_thickness_ratio);
	ClassDB::bind_method(D_METHOD("get_beam_count"), &FenceGenerator4D::get_beam_count);
	ClassDB::bind_method(D_METHOD("set_beam_count", "beam_count"), &FenceGenerator4D::set_beam_count);
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "beam_max_height_ratio", PROPERTY_HINT_RANGE, "0.001,0.999,0.001"), "set_beam_max_height_ratio", "get_beam_max_height_ratio");
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "beam_coverage", PROPERTY_HINT_RANGE, "0,1,0.001"), "set_beam_coverage", "get_beam_coverage");
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "beam_thickness_ratio", PROPERTY_HINT_RANGE, "0.001,0.999,0.001"), "set_beam_thickness_ratio", "get_beam_thickness_ratio");
	ADD_PROPERTY(PropertyInfo(Variant::INT, "beam_count", PROPERTY_HINT_RANGE, "0,100,1"), "set_beam_count", "get_beam_count");

	ClassDB::bind_method(D_METHOD("build_seed_mesh_from_corners"), &FenceGenerator4D::build_seed_mesh_from_corners);
	ClassDB::bind_method(D_METHOD("build_fence_from_seed_mesh"), &FenceGenerator4D::build_fence_from_seed_mesh);
	ClassDB::bind_method(D_METHOD("queue_update_fence_mesh"), &FenceGenerator4D::queue_update_fence_mesh);
	ClassDB::bind_method(D_METHOD("update_fence_mesh_now"), &FenceGenerator4D::update_fence_mesh_now);
	ClassDB::bind_method(D_METHOD("is_updating"), &FenceGenerator4D::is_updating);
	ClassDB::bind_method(D_METHOD("is_local_point_inside", "local_point"), &FenceGenerator4D::is_local_point_inside);
	ClassDB::bind_method(D_METHOD("is_global_point_inside", "global_point"), &FenceGenerator4D::is_global_point_inside);
	ADD_SIGNAL(MethodInfo("fence_mesh_updated"));

	BIND_ENUM_CONSTANT(INPUT_SHAPE_BOX);
	BIND_ENUM_CONSTANT(INPUT_SHAPE_RADIAL_POINTS);
	BIND_ENUM_CONSTANT(INPUT_SHAPE_RADIAL_POST_NODES);
	BIND_ENUM_CONSTANT(INPUT_SHAPE_SEED_MESH_3D);
	BIND_ENUM_CONSTANT(INPUT_SHAPE_SEED_MESH_4D);

	BIND_ENUM_CONSTANT(OUTPUT_MESH_POLY_VOLUMETRIC);
	BIND_ENUM_CONSTANT(OUTPUT_MESH_POLY_SURFACE);
	BIND_ENUM_CONSTANT(OUTPUT_MESH_TETRA);
	BIND_ENUM_CONSTANT(OUTPUT_MESH_WIRE);
}
