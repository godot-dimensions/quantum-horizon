#include "fence_build_job_4d.h"

#include "fence_guide_post_4d.h"

#include "core/math/convex_hull.h"

#include "modules/4d/model/mesh/box_mesh_data.inc"
#include "modules/4d/model/mesh/multi_surface_mesh_4d.h"
#include "modules/4d/model/mesh/poly/array_poly_mesh_4d.h"
#include "modules/4d/model/mesh/poly/box_poly_mesh_4d.h"
#include "modules/4d/model/mesh/poly/poly_mesh_builder_4d.h"
#include "modules/4d/model/mesh/tetra/array_tetra_mesh_4d.h"
#include "modules/4d/model/mesh/wire/array_wire_mesh_4d.h"

// Copies everything the build reads from the node, on the main thread, so that the build can run on another.
void FenceBuildJob4D::snapshot_from(const FenceGenerator4D *p_fence, const uint64_t p_generation_id) {
	ERR_FAIL_NULL(p_fence);
	ERR_FAIL_COND(p_fence->_seed_mesh_4d.is_null());
	// The seed is copied, since the node's own may be edited while the build runs, and the build needs an ArrayPolyMesh4D.
	const Ref<ArrayPolyMesh4D> array_seed_mesh = p_fence->_seed_mesh_4d;
	if (array_seed_mesh.is_valid()) {
		_seed_mesh_4d = array_seed_mesh->duplicate();
	} else {
		_seed_mesh_4d = p_fence->_seed_mesh_4d->to_array_poly_mesh();
	}
	_post_material = p_fence->_post_material;
	_rib_material = p_fence->_rib_material;
	_beam_material = p_fence->_beam_material;
	_desired_spacing_meters = p_fence->_desired_spacing_meters;
	_post_height_meters = p_fence->_post_height_meters;
	_post_thickness_meters = p_fence->_post_thickness_meters;
	_rib_height_ratio = p_fence->_rib_height_ratio;
	_rib_thickness_ratio = p_fence->_rib_thickness_ratio;
	_beam_max_height_ratio = p_fence->_beam_max_height_ratio;
	_beam_thickness_ratio = p_fence->_beam_thickness_ratio;
	_top_footprint_ratio = p_fence->_top_footprint_ratio;
	_beam_coverage = p_fence->_beam_coverage;
	_beam_count = p_fence->_beam_count;
	_input_shape_type = p_fence->_input_shape_type;
	_output_mesh_type = p_fence->_output_mesh_type;
	_guide_post_positions.clear();
	_guide_post_ids.clear();
	if (_input_shape_type == FenceGenerator4D::INPUT_SHAPE_RADIAL_POST_NODES) {
		for (const FenceGuidePost4D *guide_post : p_fence->_get_guide_posts()) {
			_guide_post_positions.append(guide_post->get_position());
			_guide_post_ids.push_back(guide_post->get_instance_id());
		}
	}
	_fence_id = p_fence->get_instance_id();
	_generation_id = p_generation_id;
}

// Posts the build to the WorkerThreadPool. The job keeps itself alive until the node has been told, so that the node
// may go away in the meantime. On a build without worker threads the pool runs the task right here, and the node is
// still told through the message queue, the same as otherwise. The pool keeps its record of the task until the task
// is waited for, which `_finish_on_main_thread` does.
void FenceBuildJob4D::start_threaded() {
	_self_reference = Ref<FenceBuildJob4D>(this);
	_task_id = WorkerThreadPool::get_singleton()->add_task(callable_mp(this, &FenceBuildJob4D::_run_task), false, "FenceGenerator4D build");
}

void FenceBuildJob4D::_run_task() {
	run();
	callable_mp(this, &FenceBuildJob4D::_finish_on_main_thread).call_deferred();
}

// Called on the main thread by the message queue once the task has run, see `start_threaded`. The node may be gone by
// now, in which case the result is dropped. The job's own reference is released last, since it may be the last one.
void FenceBuildJob4D::_finish_on_main_thread() {
	Ref<FenceBuildJob4D> keep_alive = _self_reference;
	_self_reference.unref();
	// Every task posted to the pool has to be waited for once, or the pool keeps its record of the task until the engine
	// quits. The build has run, since it posted this call, so the wait only frees that record. In the rare case that the
	// message queue is flushed before the pool has marked the task complete, which it does right after the task returns,
	// the wait lasts until then.
	WorkerThreadPool::get_singleton()->wait_for_task_completion(_task_id);
	_task_id = WorkerThreadPool::INVALID_TASK_ID;
	FenceGenerator4D *fence = Object::cast_to<FenceGenerator4D>(ObjectDB::get_instance(_fence_id));
	if (fence != nullptr) {
		fence->_on_build_job_finished(this);
	}
}

// Builds the fence mesh and the guide posts' meshes from the snapshot, on whichever thread this is called on. When a
// step fails it says why, and the fence mesh stays null.
void FenceBuildJob4D::run() {
	_fence_mesh.unref();
	_guide_post_meshes.clear();
	_guide_post_meshes.resize(_guide_post_ids.size());
	_guide_post_degenerate.clear();
	_guide_post_degenerate.resize(_guide_post_ids.size());
	_guide_post_degenerate.fill(false);
	ERR_FAIL_COND_MSG(_seed_mesh_4d.is_null(), "FenceGenerator4D: The build has no seed mesh.");
	// Prepare common data used by many steps. The face normals come with the seed, and the build's copy of them is made
	// unit length and flattened into the ground hyperplane, which the beams also do for themselves in `solidify_faces`.
	// The ribs and the filler take their directions from these.
	const PackedVector4Array poly_cell_vertex_positions = _seed_mesh_4d->get_poly_cell_vertex_positions();
	const Vector<PackedVector4Array> seed_face_normal_binding = _seed_mesh_4d->get_poly_cell_dense_normals(PolyMesh4D::PER_FACE_KEY);
	ERR_FAIL_COND_MSG(seed_face_normal_binding.is_empty(), "FenceGenerator4D: The seed mesh has no face normals.");
	PackedVector4Array seed_face_normals = seed_face_normal_binding[0];
	for (int64_t face_index = 0; face_index < seed_face_normals.size(); face_index++) {
		Vector4 face_normal = seed_face_normals[face_index];
		face_normal.y = 0.0;
		face_normal.normalize();
		ERR_FAIL_COND_MSG(face_normal.is_zero_approx(), "FenceGenerator4D: Seed face " + itos(face_index) + " has a vertical normal, which a footprint face on the ground cannot have.");
		seed_face_normals.set(face_index, face_normal);
	}
	// Generate beams covering the seed mesh's faces.
	Ref<ArrayPolyMesh4D> fence_beams_mesh;
	if (_beam_count > 0 && _beam_coverage > 0.0) {
		fence_beams_mesh = _build_fence_beams_from_seed_faces();
	}
	// Generate ribs along the seed mesh's edges, which are big enough to cover the sides of the beams.
	Vector<PackedVector4Array> post_hull_offsets;
	Vector<PackedVector4Array> edge_corner_offsets;
	Ref<ArrayPolyMesh4D> fence_ribs_mesh = _build_fence_ribs_from_seed_edges(poly_cell_vertex_positions, seed_face_normals, post_hull_offsets, edge_corner_offsets);
	ERR_FAIL_COND_MSG(fence_ribs_mesh.is_null(), "FenceGenerator4D: Failed to build the fence ribs.");
	// Generate posts at the seed mesh's vertices, which are big enough to cover the ends of the ribs.
	// Posts with the same shape share one mesh for the duration of this build, see `_build_fence_single_post_shared`.
	HashMap<String, Ref<ArrayPolyMesh4D>> post_mesh_cache;
	Ref<ArrayPolyMesh4D> fence_posts_mesh = _build_fence_posts_from_seed_vertices(poly_cell_vertex_positions, post_hull_offsets, post_mesh_cache);
	// Generate filler posts and ribs across faces that are large compared to the desired spacing.
	if (_desired_spacing_meters > 0.0) {
		_build_fence_filler_posts_and_ribs(poly_cell_vertex_positions, seed_face_normals, edge_corner_offsets, post_mesh_cache, fence_posts_mesh, fence_ribs_mesh);
	}
	// Material assignment. Use a single-surface mesh when all of the post, rib, and beam materials are the same.
	if (_post_material == _rib_material && _post_material == _beam_material) {
		// The merge order does not really matter, so long as we merge into something that exists.
		// However, for the sake of a consistent merge order, let's start with posts, then ribs, then beams.
		fence_posts_mesh->merge_with(fence_ribs_mesh);
		if (fence_beams_mesh.is_valid()) {
			fence_posts_mesh->merge_with(fence_beams_mesh);
		}
		Ref<SingleSurfaceMesh4D> fence_single_mesh = _convert_to_output_mesh_type(fence_posts_mesh);
		fence_single_mesh->set_material(_beam_material);
		_fence_mesh = _validate_finished_mesh(fence_single_mesh);
		return;
	}
	// Use a multi-surface mesh when different materials are used for each part of the fence.
	Vector<Ref<SingleSurfaceMesh4D>> single_surface_meshes = { fence_posts_mesh, fence_ribs_mesh };
	fence_posts_mesh->set_material(_post_material);
	fence_ribs_mesh->set_material(_rib_material);
	if (fence_beams_mesh.is_valid()) {
		fence_beams_mesh->set_material(_beam_material);
		single_surface_meshes.append(fence_beams_mesh);
	}
	// Convert surface meshes to a simpler type if requested.
	for (int64_t i = 0; i < single_surface_meshes.size(); i++) {
		const Ref<ArrayPolyMesh4D> poly_surface = single_surface_meshes[i];
		single_surface_meshes.set(i, _convert_to_output_mesh_type(poly_surface));
	}
	// Populate a new multi-surface mesh with those surfaces.
	Ref<MultiSurfaceMesh4D> multi_surface_mesh;
	multi_surface_mesh.instantiate();
	multi_surface_mesh->set_surface_meshes(single_surface_meshes);
	_fence_mesh = _validate_finished_mesh(multi_surface_mesh);
}

// Validates a finished mesh here, on the build's thread, rather than leaving it to the first frame that renders it.
// Validating a poly mesh also decomposes its cells into tetrahedra and caches them, which is the first thing the
// renderer asks of a mesh and would otherwise stall the main thread for a large fence, and the bounds are computed for
// the same reason. An invalid mesh is dropped, with its errors printed by the validation: the node reports a missing
// mesh as a failed build, and the renderer would otherwise validate the mesh again on every frame.
Ref<Mesh4D> FenceBuildJob4D::_validate_finished_mesh(const Ref<Mesh4D> &p_mesh) {
	if (p_mesh.is_null() || !p_mesh->is_mesh_data_valid()) {
		return Ref<Mesh4D>();
	}
	p_mesh->get_rect_bounds();
	return p_mesh;
}

// Merges meshes pairwise in rounds, rather than one after another into a single growing mesh. `merge_with` validates
// both meshes every time, including their simplex decompositions, so merging N parts one by one costs about N squared
// cell validations, while the rounds cost about N log N. The parts must already be in their final places. Returns an
// empty mesh when there is nothing to merge.
Ref<ArrayPolyMesh4D> FenceBuildJob4D::_merge_meshes(Vector<Ref<ArrayPolyMesh4D>> p_meshes) {
	if (p_meshes.is_empty()) {
		Ref<ArrayPolyMesh4D> empty_mesh;
		empty_mesh.instantiate();
		return empty_mesh;
	}
	while (p_meshes.size() > 1) {
		Vector<Ref<ArrayPolyMesh4D>> merged_meshes;
		for (int64_t i = 0; i + 1 < p_meshes.size(); i += 2) {
			p_meshes[i]->merge_with(p_meshes[i + 1]);
			merged_meshes.push_back(p_meshes[i]);
		}
		if (p_meshes.size() % 2 == 1) {
			merged_meshes.push_back(p_meshes[p_meshes.size() - 1]);
		}
		p_meshes = merged_meshes;
	}
	return p_meshes[0];
}

// Marks every face shared by cells of different groups as a seam, so that the texture islands of a part never cross
// from one group into another, replacing any seams the part had, such as the ones `extrude_linear` marks between
// caps and sides. Cells of the same group are never separated, including the group -1 of the cells that matched
// nothing in `_beam_cell_seed_faces`.
void FenceBuildJob4D::_set_seams_between_cell_groups(const Ref<ArrayPolyMesh4D> &p_mesh, const PackedInt32Array &p_cell_groups) {
	const Vector<Vector<PackedInt32Array>> poly_cell_indices = p_mesh->get_poly_cell_indices();
	ERR_FAIL_COND_MSG(poly_cell_indices.size() < 2, "FenceGenerator4D: Cannot mark seams on a part with no cells.");
	const Vector<PackedInt32Array> &cell_face_indices = poly_cell_indices[1];
	ERR_FAIL_COND_MSG(p_cell_groups.size() != cell_face_indices.size(), "FenceGenerator4D: The cell groups must have one entry per cell.");
	// The group of the first cell found on each face, with INT32_MIN for the faces not reached yet.
	PackedInt32Array face_group;
	face_group.resize(poly_cell_indices[0].size());
	face_group.fill(INT32_MIN);
	HashSet<int32_t> seam_faces;
	for (int64_t cell_index = 0; cell_index < cell_face_indices.size(); cell_index++) {
		for (const int32_t face_index : cell_face_indices[cell_index]) {
			if (face_group[face_index] == INT32_MIN) {
				face_group.set(face_index, p_cell_groups[cell_index]);
			} else if (face_group[face_index] != p_cell_groups[cell_index]) {
				seam_faces.insert(face_index);
			}
		}
	}
	p_mesh->set_seam_face_indices(seam_faces);
}

// The seed vertex nearest to each position on the ground, ignoring Y. The parts are built around the seed's vertices,
// offset by at most half a post thickness, which is far less than any seed edge, so this identifies the seed vertex a
// part's vertex stands on, and with it the ground under that vertex.
PackedInt32Array FenceBuildJob4D::_nearest_seed_vertices(const PackedVector4Array &p_positions) const {
	const PackedVector4Array seed_positions = _seed_mesh_4d->get_poly_cell_vertex_positions();
	PackedInt32Array nearest_seed_vertex;
	nearest_seed_vertex.resize(p_positions.size());
	for (int64_t vertex_index = 0; vertex_index < p_positions.size(); vertex_index++) {
		Vector4 position = p_positions[vertex_index];
		position.y = 0.0;
		int32_t nearest = -1;
		real_t nearest_distance_squared = Math_INF;
		for (int64_t seed_index = 0; seed_index < seed_positions.size(); seed_index++) {
			Vector4 seed_position = seed_positions[seed_index];
			seed_position.y = 0.0;
			const real_t distance_squared = position.distance_squared_to(seed_position);
			if (distance_squared < nearest_distance_squared) {
				nearest_distance_squared = distance_squared;
				nearest = (int32_t)seed_index;
			}
		}
		nearest_seed_vertex.set(vertex_index, nearest);
	}
	return nearest_seed_vertex;
}

// Leaning. A top footprint ratio below 1 makes the fence lean inward toward this node's origin, like the walls of a
// guard tower: a vertex at a given height above the ground takes the position of its ground point scaled toward the
// origin by this factor, 1 on the ground and the ratio at the top of the posts, linear in between, and stands that
// height above the result. The whole position is scaled, height included, rather than the horizontal part alone, so
// that on uneven ground each layer of a part is a homothetic copy of its ground, which keeps every cell flat, and so
// that the parts still meet: a post's column is then a straight line, and the layers of the ribs and beams at a height
// sit exactly where it passes that height. On level ground this is the same as scaling horizontally. Scaling the
// horizontal part alone would skew the sides of ribs along sloping edges and of beams on sloping faces out of any
// hyperplane, and scaling by absolute Y would move the bases of parts on raised ground off the footprint.
real_t FenceBuildJob4D::_taper_scale(const real_t p_height_above_ground) const {
	return (real_t)Math::lerp(1.0, _top_footprint_ratio, p_height_above_ground / _post_height_meters);
}

// Leans a part, see `_taper_scale`. `p_origin` is where this node's origin is in the part's coordinates, and
// `p_ground_heights` is the ground under each vertex, or empty when the part stands on Y = 0 in its own coordinates.
// The normals are recomputed from the new geometry, the way `extrude_linear` finishes a mesh, keeping the bindings the
// part had.
void FenceBuildJob4D::_taper_part(const Ref<ArrayPolyMesh4D> &p_part, const Vector4 &p_origin, const Vector<real_t> &p_ground_heights) const {
	PackedVector4Array positions = p_part->get_poly_cell_vertex_positions();
	ERR_FAIL_COND(!p_ground_heights.is_empty() && p_ground_heights.size() != positions.size());
	for (int64_t vertex_index = 0; vertex_index < positions.size(); vertex_index++) {
		const Vector4 position = positions[vertex_index];
		const real_t ground = p_ground_heights.is_empty() ? (real_t)0.0 : p_ground_heights[vertex_index];
		const real_t height = position.y - ground;
		const Vector4 ground_point = Vector4(position.x, ground, position.z, position.w);
		positions.set(vertex_index, p_origin + (ground_point - p_origin) * _taper_scale(height) + Vector4(0, height, 0, 0));
	}
	p_part->set_poly_cell_vertex_positions(positions);
	if (p_part->get_all_poly_cell_normal_indices().has(PolyMesh4D::CELL_TO_VERT_KEY)) {
		p_part->set_flat_shading_normals();
	} else {
		p_part->calculate_boundary_normals(ArrayPolyMesh4D::COMPUTE_NORMALS_MODE_CELL_ORIENTATION_ONLY);
	}
}

// Leans a post built at the origin that will stand at `p_post_position`, see `_taper_part`: in the post's own
// coordinates this node's origin is at minus that position, and the post's Y is its height above the ground.
void FenceBuildJob4D::_lean_post(const Ref<ArrayPolyMesh4D> &p_post, const Vector4 &p_post_position) const {
	if (_top_footprint_ratio < 1.0) {
		_taper_part(p_post, -p_post_position);
	}
}

// Which seed face each cell of the beam came from. `solidify_faces` and `extrude_linear` keep no record of that, but
// every vertex of the beam is a mitered copy of a seed vertex, displaced by at most half a rib thickness, which is far
// less than any seed edge, so the nearest seed vertex identifies it. A cell's set of seed vertices is then a face's
// whole vertex set for that face's walls and caps, or one edge for the walls at the seed's border and between adjacent
// faces, which go to a face using that edge. A cell that matches nothing gets -1, and such cells group among themselves.
PackedInt32Array FenceBuildJob4D::_beam_cell_seed_faces(const Ref<ArrayPolyMesh4D> &p_beam_mesh) const {
	const Vector<PackedInt32Array> seed_face_vertices = _seed_mesh_4d->get_all_poly_cell_vertex_indices(2, false);
	const PackedInt32Array nearest_seed_vertex = _nearest_seed_vertices(p_beam_mesh->get_poly_cell_vertex_positions());
	const Vector<PackedInt32Array> beam_cell_vertices = p_beam_mesh->get_all_poly_cell_vertex_indices(3, false);
	PackedInt32Array cell_seed_faces;
	cell_seed_faces.resize(beam_cell_vertices.size());
	for (int64_t cell_index = 0; cell_index < beam_cell_vertices.size(); cell_index++) {
		PackedInt32Array seed_vertices;
		for (const int32_t vertex_index : beam_cell_vertices[cell_index]) {
			const int32_t seed_vertex = nearest_seed_vertex[vertex_index];
			if (!seed_vertices.has(seed_vertex)) {
				seed_vertices.append(seed_vertex);
			}
		}
		int32_t matched_face = -1;
		for (int64_t face_index = 0; face_index < seed_face_vertices.size() && matched_face == -1; face_index++) {
			const PackedInt32Array &face_vertices = seed_face_vertices[face_index];
			bool all_in_face = true;
			for (const int32_t seed_vertex : seed_vertices) {
				if (!face_vertices.has(seed_vertex)) {
					all_in_face = false;
					break;
				}
			}
			// A face's own walls and caps use all of its vertices, and an edge's walls use two of them.
			if (all_in_face && (seed_vertices.size() == face_vertices.size() || seed_vertices.size() == 2)) {
				matched_face = (int32_t)face_index;
			}
		}
		cell_seed_faces.set(cell_index, matched_face);
	}
	return cell_seed_faces;
}

Ref<ArrayPolyMesh4D> FenceBuildJob4D::_build_fence_beams_from_seed_faces() const {
	Ref<ArrayPolyMesh4D> fence_beams_mesh;
	fence_beams_mesh.instantiate();
	const double beam_all_top = _post_height_meters * (_rib_height_ratio * _beam_max_height_ratio);
	const double beam_each_top = beam_all_top / _beam_count;
	const double beam_half_height = beam_each_top * (0.5 * _beam_coverage);
	const double beam_middle_height = beam_each_top - beam_half_height;
	// The seed mesh is the 2D outline of the beam, like a 1D line loop would be for a 3D fence. Thickening it within
	// the XZW ground hyperplane gives a solid slab of 3D cells, one per seed face, with the vertices mitered so that
	// the beam is exactly that thick everywhere, including around the corners.
	const double beam_thickness_meters = _post_thickness_meters * (_rib_thickness_ratio * _beam_thickness_ratio);
	// The miter limit that keeps every beam corner hidden inside its rib. A mitered corner vertex sits `limit` times half
	// the beam thickness away from the seed vertex, and the rib is centered on that vertex with half its thickness to
	// spare in every direction, so the corner stays inside the rib when the limit is at most rib thickness over beam
	// thickness. The limit is never below 1, since a flat face needs exactly its own offset and clamping below that would
	// make every beam thinner than requested.
	const double miter_limit = 1.0 / _beam_thickness_ratio;
	Ref<ArrayPolyMesh4D> beam_flat = PolyMeshBuilder4D::solidify_faces(_seed_mesh_4d, beam_thickness_meters, 0.0, miter_limit, Vector4(0, 1, 0, 0));
	ERR_FAIL_COND_V_MSG(!beam_flat->is_mesh_data_valid() || beam_flat->get_poly_cell_indices().size() < 2, Ref<ArrayPolyMesh4D>(), "FenceGenerator4D: Failed to thicken the seed mesh into the beam's slab.");
	// The seed's texture map describes the seed's own surface, and the beam is textured from scratch below, so drop
	// it from the slab before extruding. Otherwise the extrusion would derive a texture map for some cells but not
	// for the caps, and every validation along the way would warn about the cells it missed.
	beam_flat->delete_texture_maps_below_dimension(4);
	// Represents a 4D volumetric beam extruded vertically, fully ready to append to the 4D fence mesh.
	// Because the slab has per-face normals, `extrude_linear` takes its per-face path: each extruded cell inherits the
	// orientation of the face it came from, and the two slab copies become the caps, oriented to face along their
	// respective extrusion directions. `make_boundary_normals_topologically_consistent` is only used on the other
	// path, when per-face normals are absent, so it does not run here.
	Ref<ArrayPolyMesh4D> beam_mesh = PolyMeshBuilder4D::extrude_linear(beam_flat, Vector4(0, beam_half_height, 0, 0));
	if (_output_mesh_type != FenceGenerator4D::OUTPUT_MESH_POLY_VOLUMETRIC) {
		// The walls between adjacent slab cells were extruded into cells interior to the beam, which would only add
		// hidden geometry. Unless volumetric poly geometry was requested, keep only the beam's boundary.
		PolyMeshBuilder4D::delete_interior(beam_mesh);
	}
	// `extrude_linear` carries the slab's 2D face normal bindings over to its two copies only, so the newly extruded
	// faces have no entries, and whatever the seed had below its faces travels along as well. A 4D solid renders from
	// its cell bindings, so everything below the cell level is dead weight here, and every later `merge_with` with a
	// mesh lacking the same keys would warn about missing entries. Drop them before merging into the fence.
	beam_mesh->delete_normals_below_dimension(3);
	// Texture the template once, with one island per seed face: the faces between cells of different seed faces are
	// marked as seams, which islands never cross. The ribs cover the beam's edges, so the seams between the faces'
	// islands are hidden, and each island stays about the size of a face rather than the whole beam, so the texture
	// repeats about as often on the beams as on the ribs and posts. Every copy shares the map.
	_set_seams_between_cell_groups(beam_mesh, _beam_cell_seed_faces(beam_mesh));
	beam_mesh->unwrap_texture_map_upright(Vector4(0, 1, 0, 0), ArrayPolyMesh4D::UNWRAP_MODE_EACH_ISLAND_FILLS);
	// Each beam is the template moved up into its slot. A leaning fence scales each copy by its own heights, see
	// `_taper_part`, measured from the ground under each vertex, which is the seed vertex it is a mitered copy of.
	Vector<real_t> ground_heights;
	if (_top_footprint_ratio < 1.0) {
		const PackedVector4Array seed_positions = _seed_mesh_4d->get_poly_cell_vertex_positions();
		const PackedInt32Array nearest_seed_vertex = _nearest_seed_vertices(beam_mesh->get_poly_cell_vertex_positions());
		ground_heights.resize(nearest_seed_vertex.size());
		for (int64_t vertex_index = 0; vertex_index < nearest_seed_vertex.size(); vertex_index++) {
			ground_heights.write[vertex_index] = seed_positions[nearest_seed_vertex[vertex_index]].y;
		}
	}
	for (int64_t beam_num = 0; beam_num < _beam_count; beam_num++) {
		const Transform4D offset = Transform4D(Basis4D(), Vector4(0, beam_middle_height + beam_each_top * beam_num, 0, 0));
		if (ground_heights.is_empty()) {
			fence_beams_mesh->merge_with(beam_mesh, offset);
			continue;
		}
		Ref<ArrayPolyMesh4D> leaning_beam = beam_mesh->duplicate();
		leaning_beam->transform_mesh(offset);
		_taper_part(leaning_beam, Vector4(), ground_heights);
		fence_beams_mesh->merge_with(leaning_beam);
	}
	return fence_beams_mesh;
}

Ref<ArrayPolyMesh4D> FenceBuildJob4D::_build_fence_single_rib(const Vector4 &p_edge_vert_0, const Vector4 &p_edge_vert_1, const Vector4 &p_radial_normal, const double p_normal_dot, PackedVector4Array &r_base_corner_offsets) const {
	// Using a rib mesh with a cubic flat base makes it look more like a traditional 3D fence post.
	const Vector4 edge_offset = p_edge_vert_1 - p_edge_vert_0; // Do not normalize this one.
	const Vector4 perp_normal = Vector4D::perpendicular(edge_offset, Vector4(0, 1, 0, 0), p_radial_normal).normalized();
	const double rib_height_meters = _post_height_meters * _rib_height_ratio;
	const double rib_thickness_meters = _post_thickness_meters * _rib_thickness_ratio;
	// The cross-section is the same at both ends, so the offsets from one endpoint describe the whole rib.
	r_base_corner_offsets.resize(4);
	if (p_normal_dot > Math_SQRT12) {
		// If the dihedral angle is mostly straight, between 135 and 225 degrees,
		// place a rib face between where the beams connect.
		const double rib_half_thickness = rib_thickness_meters * 0.5;
		const Vector4 perp_face_offset = perp_normal * rib_half_thickness;
		const Vector4 radial_face_offset = p_radial_normal * rib_half_thickness;
		const Vector4 sum = perp_face_offset + radial_face_offset;
		const Vector4 diff = perp_face_offset - radial_face_offset;
		r_base_corner_offsets.set(0, -sum);
		r_base_corner_offsets.set(1, diff);
		r_base_corner_offsets.set(2, -diff);
		r_base_corner_offsets.set(3, sum);
	} else {
		// If the dihedral angle is sharp, place a rib corner between the beams.
		const double rib_corner_distance = rib_thickness_meters * Math_SQRT12;
		const Vector4 perp_corner_offset = perp_normal * rib_corner_distance;
		const Vector4 radial_corner_offset = p_radial_normal * rib_corner_distance;
		r_base_corner_offsets.set(0, -radial_corner_offset);
		r_base_corner_offsets.set(1, perp_corner_offset);
		r_base_corner_offsets.set(2, -perp_corner_offset);
		r_base_corner_offsets.set(3, radial_corner_offset);
	}
	// The p/r parts of the below names do not make sense in the "else" case but it just needs to be a consistent convention.
	const Vector4 e0p0r0 = p_edge_vert_0 + r_base_corner_offsets[0];
	const Vector4 e0p1r0 = p_edge_vert_0 + r_base_corner_offsets[1];
	const Vector4 e0p0r1 = p_edge_vert_0 + r_base_corner_offsets[2];
	const Vector4 e0p1r1 = p_edge_vert_0 + r_base_corner_offsets[3];
	const Vector4 e1p0r0 = p_edge_vert_1 + r_base_corner_offsets[0];
	const Vector4 e1p1r0 = p_edge_vert_1 + r_base_corner_offsets[1];
	const Vector4 e1p0r1 = p_edge_vert_1 + r_base_corner_offsets[2];
	const Vector4 e1p1r1 = p_edge_vert_1 + r_base_corner_offsets[3];
	// The top corners stand the rib's height above the base ones, which a leaning fence first scales toward this node's
	// origin, see `_taper_scale`. The ribs are built in place, so that origin is the origin.
	const real_t top_scale = _taper_scale((real_t)rib_height_meters);
	auto top_of = [&](const Vector4 &p_base) { return p_base * top_scale + Vector4(0.0, rib_height_meters, 0.0, 0.0); };
	PackedVector4Array rib_edge_vertex_pos = {
		e0p0r0,
		e1p0r0,
		top_of(e0p0r0),
		top_of(e1p0r0),
		e0p0r1,
		e1p0r1,
		top_of(e0p0r1),
		top_of(e1p0r1),
		e0p1r0,
		e1p1r0,
		top_of(e0p1r0),
		top_of(e1p1r0),
		e0p1r1,
		e1p1r1,
		top_of(e0p1r1),
		top_of(e1p1r1),
	};
	// Create this edge's rib mesh using the calculated vertex positions, the box indices, etc.
	Ref<ArrayPolyMesh4D> single_rib_mesh;
	single_rib_mesh.instantiate();
	single_rib_mesh->set_poly_cell_vertex_positions(rib_edge_vertex_pos);
	single_rib_mesh->set_edge_vertex_indices(BOX_EDGE_INDICES);
	single_rib_mesh->set_poly_cell_indices(BOX_POLY_CELL_INDICES);
	single_rib_mesh->set_flat_shading_normals();
	// Texture the rib upright with U along its edge. The +Z cell, index 3 in the box data, is one of its two big
	// sides, the one facing the radial direction, so it is projected first, and the unwrap keeps it as the seed that
	// every other cell is unfolded from.
	const Vector4 up = Vector4(0, 1, 0, 0);
	const PackedVector4Array rib_boundary_normals = single_rib_mesh->get_poly_cell_boundary_normals();
	// The seed's mesh-to-texture basis: U along the edge, V up, and W completing the frame with the cell's normal.
	// `Vector4D::perpendicular(a, b, c)` completes a positively oriented frame (a, b, c, result), so passing V before U
	// makes (U, V, W, normal) positively oriented, the same trick as in `PolyMesh4D::compute_face_normals`, and since
	// unfolding preserves handedness, no part renders mirrored. These directions are the columns of a texture-to-mesh
	// basis, and its transpose maps each of them onto a texture axis and the normal onto the discarded component.
	const Vector4 along = edge_offset.normalized();
	const Vector4 across = Vector4D::perpendicular(up, along, rib_boundary_normals[3]);
	single_rib_mesh->project_texture_map(PackedInt32Array{ 3 }, Basis4D(along, up, across, rib_boundary_normals[3]).transposed());
	single_rib_mesh->unwrap_texture_map_upright(up, ArrayPolyMesh4D::UNWRAP_MODE_EACH_ISLAND_FILLS, 0.0, true, true);
	if (_output_mesh_type != FenceGenerator4D::OUTPUT_MESH_POLY_VOLUMETRIC) {
		PolyMeshBuilder4D::delete_interior(single_rib_mesh); // The box comes with its volume, which a surface has no use for.
	}
	return single_rib_mesh;
}

// The points a rib contributes to the hull of a post it meets, see `_build_fence_single_post`: its cross-section scaled
// up from the rib thickness to the post thickness, placed half a post thickness along the rib in both directions. The
// rib may end at the post or pass through it, and since the placement is symmetric the points are the same either way.
void FenceBuildJob4D::_append_post_hull_points_for_rib(const Vector4 &p_rib_direction, const PackedVector4Array &p_rib_corner_offsets, PackedVector4Array &r_hull_points) const {
	const double rib_thickness_meters = _post_thickness_meters * _rib_thickness_ratio;
	if (rib_thickness_meters <= 0.0) {
		return; // Ribs have no thickness, so posts fall back to plain cubes.
	}
	const real_t rib_to_post_scale = (real_t)(_post_thickness_meters / rib_thickness_meters);
	const Vector4 along_rib = p_rib_direction.normalized() * (real_t)(0.5 * _post_thickness_meters);
	for (const Vector4 &corner_offset : p_rib_corner_offsets) {
		const Vector4 post_sized_corner = corner_offset * rib_to_post_scale;
		r_hull_points.append(post_sized_corner + along_rib);
		r_hull_points.append(post_sized_corner - along_rib);
	}
}

Ref<ArrayPolyMesh4D> FenceBuildJob4D::_build_fence_ribs_from_seed_edges(const PackedVector4Array &p_poly_cell_vertex_positions, const PackedVector4Array &p_seed_face_normals, Vector<PackedVector4Array> &r_post_hull_offsets, Vector<PackedVector4Array> &r_edge_corner_offsets) const {
	Vector<Ref<ArrayPolyMesh4D>> rib_meshes; // Merged at the end, see `_merge_meshes`.
	// Each rib contributes the points that define the posts at its two ends. The offsets are relative to the post's
	// vertex, and since a rib's cross-section is the same at both ends, both ends receive the same 8 offsets. The
	// cross-section itself is kept per edge as well, for the filler posts that later sit on the rib along its length.
	r_post_hull_offsets.clear();
	r_post_hull_offsets.resize(p_poly_cell_vertex_positions.size());
	auto add_post_hull_points_for_rib = [&](const int32_t p_vertex_a, const int32_t p_vertex_b, const PackedVector4Array &p_corner_offsets) {
		const Vector4 direction = p_poly_cell_vertex_positions[p_vertex_b] - p_poly_cell_vertex_positions[p_vertex_a];
		PackedVector4Array offsets_a = r_post_hull_offsets[p_vertex_a];
		_append_post_hull_points_for_rib(direction, p_corner_offsets, offsets_a);
		r_post_hull_offsets.set(p_vertex_a, offsets_a);
		PackedVector4Array offsets_b = r_post_hull_offsets[p_vertex_b];
		_append_post_hull_points_for_rib(direction, p_corner_offsets, offsets_b);
		r_post_hull_offsets.set(p_vertex_b, offsets_b);
	};
	// Traverse the faces of the seed mesh.
	const Vector<Vector<PackedInt32Array>> seed_poly_indices = _seed_mesh_4d->get_poly_cell_indices();
	const Vector<PackedInt32Array> &face_edge_indices = seed_poly_indices[0];
	ERR_FAIL_COND_V_MSG(face_edge_indices.size() != p_seed_face_normals.size(), Ref<ArrayPolyMesh4D>(), "FenceGenerator4D: The seed mesh must have one normal per face.");
	const PackedInt32Array seed_edge_indices = _seed_mesh_4d->get_edge_indices();
	r_edge_corner_offsets.clear();
	r_edge_corner_offsets.resize(seed_edge_indices.size() / 2);
	const int64_t face_count = face_edge_indices.size();
	HashSet<int32_t> ribbed_edges;
	for (int64_t face_a = 0; face_a < face_count; face_a++) {
		const PackedInt32Array &face_a_edges = face_edge_indices[face_a];
		for (int64_t edge_in_face_a = 0; edge_in_face_a < face_a_edges.size(); edge_in_face_a++) {
			const int32_t edge_a = face_a_edges[edge_in_face_a];
			// Skip already ribbed edges. This guards against duplicate ribs for an edge shared by 3+ faces.
			if (ribbed_edges.has(edge_a)) {
				continue;
			}
			ribbed_edges.insert(edge_a); // Will get ribbed below no matter what.
			const Vector4 &edge_vert_0 = p_poly_cell_vertex_positions[seed_edge_indices[edge_a * 2]];
			const Vector4 &edge_vert_1 = p_poly_cell_vertex_positions[seed_edge_indices[edge_a * 2 + 1]];
			const Vector4 &face_a_normal = p_seed_face_normals[face_a];
			bool edge_found_in_another_face = false;
			for (int64_t face_b = face_a + 1; face_b < face_count; face_b++) {
				const PackedInt32Array &face_b_edges = face_edge_indices[face_b];
				for (int64_t edge_in_face_b = 0; edge_in_face_b < face_b_edges.size(); edge_in_face_b++) {
					const int32_t edge_b = face_b_edges[edge_in_face_b];
					if (edge_a == edge_b) {
						// Edge is shared between face_a and face_b. The rib's orientation should consider both face normals.
						edge_found_in_another_face = true;
						const Vector4 &face_b_normal = p_seed_face_normals[face_b];
						const Vector4 normal_sum = face_a_normal + face_b_normal;
						Vector4 combined_normal;
						double normal_dot;
						if (normal_sum.is_zero_approx()) {
							// The two faces fold back onto each other, so their normals cancel and the edge has no direction
							// of its own. A rib's cross-section is the same for a normal and its opposite, so the first face's
							// frame serves, with the flat cross-section of a straight run, and the beams there get their rib.
							combined_normal = face_a_normal;
							normal_dot = 1.0;
						} else {
							combined_normal = normal_sum.normalized();
							normal_dot = face_a_normal.dot(face_b_normal);
						}
						PackedVector4Array rib_corner_offsets;
						const Ref<ArrayPolyMesh4D> single_rib_mesh = _build_fence_single_rib(edge_vert_0, edge_vert_1, combined_normal, normal_dot, rib_corner_offsets);
						rib_meshes.push_back(single_rib_mesh);
						add_post_hull_points_for_rib(seed_edge_indices[edge_a * 2], seed_edge_indices[edge_a * 2 + 1], rib_corner_offsets);
						r_edge_corner_offsets.set(edge_a, rib_corner_offsets);
						break;
					}
				}
				if (edge_found_in_another_face) {
					break;
				}
			}
			if (!edge_found_in_another_face) {
				// Terminology note: "border" always refers to the boundary of a boundary in this codebase.
				// This edge is a border of just one face, so generate a single rib just for this edge.
				PackedVector4Array rib_corner_offsets;
				const Ref<ArrayPolyMesh4D> single_rib_mesh = _build_fence_single_rib(edge_vert_0, edge_vert_1, face_a_normal, 1.0, rib_corner_offsets);
				rib_meshes.push_back(single_rib_mesh);
				add_post_hull_points_for_rib(seed_edge_indices[edge_a * 2], seed_edge_indices[edge_a * 2 + 1], rib_corner_offsets);
				r_edge_corner_offsets.set(edge_a, rib_corner_offsets);
			}
		}
	}
	return _merge_meshes(rib_meshes);
}

// A post is the convex hull of the cross-sections of the ribs meeting at its vertex, each scaled up from the rib
// thickness to the post thickness and placed half a post thickness along its rib in both directions, then extruded
// from the ground up to the post height. Where three ribs meet at right angles, such as every corner of a box, those
// squares are the faces of a cube, so the post is exactly a cube of the post thickness. A vertex in a flat region or
// on a straight run gets a cube too. A vertex where many ribs meet at various angles, such as one of an icosahedral
// fence, gets a rounded polyhedron symmetric about the ribs, which no fixed box orientation could match. Since each
// hulled cross-section is twice the size of its rib's real one and the hull is convex, every rib is covered by its
// posts out to half a post thickness from the vertex, in any orientation, with a margin that only closes as the rib
// thickness ratio approaches 1. Part of that margin pays for the merging of nearby hull points described below.
// The mesh is built with its origin at the vertex, on the ground, so it can be merged at the vertex or given to a
// guide post node at that position. A vertex with no ribs gets a plain cube.
Ref<ArrayPolyMesh4D> FenceBuildJob4D::_build_fence_single_post(const PackedVector4Array &p_hull_point_offsets) const {
	const Vector4 rise_to_ground = Vector4(0.0, 0.5 * _post_height_meters, 0.0, 0.0);
	Ref<ArrayPolyMesh4D> cross_section;
	if (p_hull_point_offsets.size() >= 4) {
		// The footprint lives in XZW, so the hull is computed on those three coordinates. Several ribs usually contribute
		// nearly the same corner: exactly the same up to floating-point error at a box corner, but a few millimeters
		// apart wherever a footprint face is not quite flat, since the cross-section of a rib between two faces is
		// turned by half the angle between them. Close points make sliver faces on the hull, which the extrusion turns
		// into cells too thin to texture, so points within a tenth of the post thickness are merged into one at their
		// average. That may move the post's surface by that much, which the coverage margin absorbs, see above. The
		// hull's vertices are mapped back to these merged points afterward rather than using its quantized positions.
		const real_t merge_distance = (real_t)(0.1 * _post_thickness_meters);
		PackedVector3Array flat_offsets; // One point per cluster, the running average of the points merged into it.
		PackedInt32Array cluster_sizes;
		for (const Vector4 &offset : p_hull_point_offsets) {
			const Vector3 flat_offset = Vector3(offset.x, offset.z, offset.w);
			int64_t cluster = -1;
			for (int64_t i = 0; i < flat_offsets.size(); i++) {
				if (flat_offsets[i].distance_squared_to(flat_offset) <= merge_distance * merge_distance) {
					cluster = i;
					break;
				}
			}
			if (cluster == -1) {
				flat_offsets.append(flat_offset);
				cluster_sizes.append(1);
			} else {
				const int32_t cluster_size = cluster_sizes[cluster] + 1;
				flat_offsets.set(cluster, flat_offsets[cluster] + (flat_offset - flat_offsets[cluster]) / (real_t)cluster_size);
				cluster_sizes.set(cluster, cluster_size);
			}
		}
		ConvexHullComputer convex_hull;
		convex_hull.compute(flat_offsets.ptr(), flat_offsets.size(), 0.0, 0.0);
		PackedInt32Array edge_vertex_indices;
		Vector<PackedInt32Array> face_edge_indices;
		if (convex_hull.vertices.size() >= 4 && FenceGenerator4D::_repack_convex_hull_topology(convex_hull, edge_vertex_indices, face_edge_indices) && face_edge_indices.size() >= 4) {
			PackedVector4Array hull_positions;
			hull_positions.resize(convex_hull.vertices.size());
			for (uint32_t i = 0; i < convex_hull.vertices.size(); i++) {
				const Vector3 &hull_point = convex_hull.vertices[i];
				// Snap to the nearest merged point, since the hull's own vertex positions are quantized.
				Vector3 nearest = flat_offsets[0];
				real_t nearest_distance_squared = nearest.distance_squared_to(hull_point);
				for (const Vector3 &candidate : flat_offsets) {
					const real_t candidate_distance_squared = candidate.distance_squared_to(hull_point);
					if (candidate_distance_squared < nearest_distance_squared) {
						nearest = candidate;
						nearest_distance_squared = candidate_distance_squared;
					}
				}
				hull_positions.set(i, Vector4(nearest.x, 0.0, nearest.y, nearest.z));
			}
			cross_section.instantiate();
			cross_section->set_poly_cell_vertex_positions(hull_positions);
			cross_section->set_edge_vertex_indices(edge_vertex_indices);
			cross_section->set_poly_cell_indices(Vector<Vector<PackedInt32Array>>{ face_edge_indices });
			// The hull only merges coplanar triangles that are exactly coplanar after its quantization, which
			// non-axis-aligned faces rarely are, so a dodecahedral post would arrive as 36 triangles rather than
			// 12 pentagons. Merging them keeps the post's cell count down and its faces whole.
			PolyMeshBuilder4D::merge_coplanar_faces(cross_section);
			cross_section->append_poly_cell(3, cross_section->make_single_cell_from_all_faces());
		}
	}
	Ref<ArrayPolyMesh4D> single_post_mesh;
	if (cross_section.is_valid() && cross_section->is_mesh_data_valid()) {
		// Extrude the footprint polyhedron up into the post. The extrusion is symmetric around the ground, so raise it after.
		single_post_mesh = PolyMeshBuilder4D::extrude_linear(cross_section, rise_to_ground);
	} else {
		// No ribs, or a degenerate footprint: fall back to a plain cube of the post thickness.
		Ref<BoxPolyMesh4D> post_box;
		post_box.instantiate();
		post_box->set_size(Vector4(_post_thickness_meters, _post_height_meters, _post_thickness_meters, _post_thickness_meters));
		single_post_mesh = post_box->to_array_poly_mesh();
	}
	// Either way the mesh is centered on the ground point, but a post stands on it, so shift it up.
	single_post_mesh->transform_mesh(Transform4D(Basis4D(), rise_to_ground));
	if (_output_mesh_type != FenceGenerator4D::OUTPUT_MESH_POLY_VOLUMETRIC) {
		PolyMeshBuilder4D::delete_interior(single_post_mesh);
	}
	// Texture the post upright, seeded on one of its sides. A fallback cube arrives with the box's own texture map,
	// which is replaced, and an extruded footprint with the seams `extrude_linear` marks between its caps and its
	// sides, which are dropped so that the caps hang off the sides in the unfold instead of being islands of their own.
	single_post_mesh->set_seam_face_indices(HashSet<int32_t>());
	single_post_mesh->unwrap_texture_map_upright(Vector4(0, 1, 0, 0), ArrayPolyMesh4D::UNWRAP_MODE_EACH_ISLAND_FILLS);
	return single_post_mesh;
}

// Posts with the same hull points, such as the crossings of a flat face's filler grid or the eight corners of a box, get
// one mesh built once and copied into place, since building a post costs far more than copying one. The key is the sorted
// set of points, quantized to a millionth of the post thickness so that the floating-point noise of equal cross-sections
// built from different chords does not split them, while anything that differs by a real amount stays apart.
Ref<ArrayPolyMesh4D> FenceBuildJob4D::_build_fence_single_post_shared(const PackedVector4Array &p_hull_point_offsets, HashMap<String, Ref<ArrayPolyMesh4D>> &r_post_mesh_cache) const {
	const real_t quantum = (real_t)(1e-6 * _post_thickness_meters);
	PackedVector4Array quantized_points;
	quantized_points.resize(p_hull_point_offsets.size());
	for (int64_t i = 0; i < p_hull_point_offsets.size(); i++) {
		const Vector4 &point = p_hull_point_offsets[i];
		quantized_points.set(i, Vector4(Math::round(point.x / quantum), Math::round(point.y / quantum), Math::round(point.z / quantum), Math::round(point.w / quantum)));
	}
	quantized_points.sort();
	String key;
	for (const Vector4 &point : quantized_points) {
		key += itos((int64_t)point.x) + "," + itos((int64_t)point.y) + "," + itos((int64_t)point.z) + "," + itos((int64_t)point.w) + ";";
	}
	const Ref<ArrayPolyMesh4D> *cached_mesh = r_post_mesh_cache.getptr(key);
	if (cached_mesh != nullptr) {
		Ref<ArrayPolyMesh4D> copy = (*cached_mesh)->duplicate();
		return copy;
	}
	const Ref<ArrayPolyMesh4D> post_mesh = _build_fence_single_post(p_hull_point_offsets);
	// The cache keeps its own copy, since the caller moves the returned mesh into place.
	Ref<ArrayPolyMesh4D> cache_copy = post_mesh->duplicate();
	r_post_mesh_cache.insert(key, cache_copy);
	return post_mesh;
}

// Converts a finished part to the requested output mesh type. The poly types return the part as it is, since the parts
// are built as poly meshes, with their interior already removed for the surface type by the builders.
Ref<SingleSurfaceMesh4D> FenceBuildJob4D::_convert_to_output_mesh_type(const Ref<ArrayPolyMesh4D> &p_mesh) const {
	switch (_output_mesh_type) {
		case FenceGenerator4D::OUTPUT_MESH_TETRA:
			return p_mesh->to_array_tetra_mesh();
		case FenceGenerator4D::OUTPUT_MESH_WIRE:
			return p_mesh->to_array_wire_mesh();
		default:
			return p_mesh;
	}
}

// Builds one post per seed vertex. In the guide post shape, each post mesh is given to the guide post standing at that
// vertex, converted to the output mesh type like the fence's own surfaces, so the node renders it with its own transform
// and stays selectable in the editor. The corners are the posts' positions, so the match is by position, and the first
// guide post at a position wins: a second one there gets no mesh, and neither does a degenerate guide post, one the hull
// drops because it is at the origin or in the same direction from the origin as an earlier post, which the post reports
// as a configuration warning. A vertex without a guide post, and every post in the other shapes, is merged into the
// returned mesh.
Ref<ArrayPolyMesh4D> FenceBuildJob4D::_build_fence_posts_from_seed_vertices(const PackedVector4Array &p_poly_cell_vertex_positions, const Vector<PackedVector4Array> &p_post_hull_offsets, HashMap<String, Ref<ArrayPolyMesh4D>> &r_post_mesh_cache) {
	Vector<Ref<ArrayPolyMesh4D>> post_meshes; // Merged at the end, see `_merge_meshes`.
	const int64_t vertex_count = p_poly_cell_vertex_positions.size();
	ERR_FAIL_COND_V(p_post_hull_offsets.size() != vertex_count, _merge_meshes(post_meshes));
	// The guide posts of the post shape, by their index in the snapshot, each waiting for the vertex at its position.
	Vector<int64_t> unassigned_posts;
	if (_input_shape_type == FenceGenerator4D::INPUT_SHAPE_RADIAL_POST_NODES) {
		for (int64_t post_index = 0; post_index < _guide_post_positions.size(); post_index++) {
			unassigned_posts.push_back(post_index);
		}
	}
	// A vertex that no edge uses, such as a loose vertex of a 3D seed, has no ribs or beams, so it gets no post either.
	Vector<bool> vertex_has_edge;
	vertex_has_edge.resize(vertex_count);
	vertex_has_edge.fill(false);
	for (const int32_t edge_vertex : _seed_mesh_4d->get_edge_indices()) {
		if (edge_vertex >= 0 && edge_vertex < vertex_count) {
			vertex_has_edge.set(edge_vertex, true);
		}
	}
	for (int64_t vertex_index = 0; vertex_index < vertex_count; vertex_index++) {
		if (!vertex_has_edge[vertex_index]) {
			continue;
		}
		const Vector4 &post_position = p_poly_cell_vertex_positions[vertex_index];
		const Ref<ArrayPolyMesh4D> single_post_mesh = _build_fence_single_post_shared(p_post_hull_offsets[vertex_index], r_post_mesh_cache);
		int64_t guide_post_at_vertex = -1;
		for (int64_t i = 0; i < unassigned_posts.size(); i++) {
			if (_guide_post_positions[unassigned_posts[i]].is_equal_approx(post_position)) {
				guide_post_at_vertex = unassigned_posts[i];
				unassigned_posts.remove_at(i);
				break;
			}
		}
		_lean_post(single_post_mesh, post_position);
		if (guide_post_at_vertex >= 0) {
			// A part gets its material once it is complete, which for a guide post's mesh is here and for the merged parts is
			// the end of `run`. Merging duplicates the destination's material, so a material set on every post before
			// merging would be copied and thrown away once per post. The node hands the mesh to the post on the main thread.
			Ref<SingleSurfaceMesh4D> guide_post_mesh = _convert_to_output_mesh_type(single_post_mesh);
			guide_post_mesh->set_material(_post_material);
			_guide_post_meshes.write[guide_post_at_vertex] = _validate_finished_mesh(guide_post_mesh);
		} else {
			single_post_mesh->transform_mesh(Transform4D(Basis4D(), post_position));
			post_meshes.push_back(single_post_mesh);
		}
	}
	// The guide posts left over are the degenerate ones, which they report as a configuration warning.
	for (const int64_t post_index : unassigned_posts) {
		_guide_post_degenerate.write[post_index] = true;
	}
	return _merge_meshes(post_meshes);
}

// A division point of a seed edge, with its coordinates in the frame of the face being filled.
struct FenceFillerPoint {
	real_t along = 0.0; // Along the axis that the chords of this family are paired by.
	real_t across = 0.0; // Along the other axis, which the chords of this family roughly follow.
	Vector2i key; // The seed edge and the division index along it, shared by the faces on both sides of the edge.
	Vector4 position;
};

struct FenceFillerPointSort {
	_FORCE_INLINE_ bool operator()(const FenceFillerPoint &p_a, const FenceFillerPoint &p_b) const { return p_a.along < p_b.along; }
};

// A chord across a face, between two division points on its boundary, and the rib built along it.
struct FenceFillerChord {
	Vector2 start_2d;
	Vector2 end_2d;
	Vector4 start;
	Vector4 end;
	Vector2i start_key;
	Vector2i end_key;
	PackedVector4Array rib_corner_offsets;
};

// Pairs the points of one chain of edges with those of the opposite chain in order, so that the chords between the pairs
// never cross, choosing the pairing that makes the most chords and, among those, the straightest ones. A pair is
// acceptable when its sideways offset is small next to the chord's length or next to the spacing, which keeps the fan of
// a trapezoid and skips points that are simply not across from each other. This is a small sequence alignment, which
// unlike a greedy walk never lets a point that could only match one partner lose it to a neighbor that had another. Both
// lists must be sorted along the pairing axis.
static Vector<Vector2i> _match_fence_filler_points(const Vector<FenceFillerPoint> &p_near, const Vector<FenceFillerPoint> &p_far, const real_t p_spacing) {
	Vector<Vector2i> pairs;
	const int64_t near_count = p_near.size();
	const int64_t far_count = p_far.size();
	if (near_count == 0 || far_count == 0) {
		return pairs;
	}
	// The best alignment of the first `near` near points with the first `far` far points: the most pairs, then the
	// least total sideways offset. Each cell remembers the step that produced it, for walking the pairs back out.
	struct Alignment {
		int32_t pair_count = 0;
		real_t total_offset = 0.0;
		int8_t step = 0; // 1 leaves out a near point, 2 leaves out a far point, 3 pairs the two.
	};
	auto is_better = [](const Alignment &p_a, const Alignment &p_b) {
		return p_a.pair_count > p_b.pair_count || (p_a.pair_count == p_b.pair_count && p_a.total_offset < p_b.total_offset);
	};
	Vector<Alignment> table;
	table.resize((near_count + 1) * (far_count + 1));
	Alignment *cells = table.ptrw();
	auto cell = [&](const int64_t p_near, const int64_t p_far) -> Alignment & { return cells[p_near * (far_count + 1) + p_far]; };
	for (int64_t near = 1; near <= near_count; near++) {
		cell(near, 0).step = 1;
	}
	for (int64_t far = 1; far <= far_count; far++) {
		cell(0, far).step = 2;
	}
	for (int64_t near = 1; near <= near_count; near++) {
		for (int64_t far = 1; far <= far_count; far++) {
			Alignment best = cell(near - 1, far);
			best.step = 1;
			Alignment without_far = cell(near, far - 1);
			without_far.step = 2;
			if (is_better(without_far, best)) {
				best = without_far;
			}
			const FenceFillerPoint &near_point = p_near[near - 1];
			const FenceFillerPoint &far_point = p_far[far - 1];
			const real_t offset = Math::abs(near_point.along - far_point.along);
			const real_t length = Math::abs(near_point.across - far_point.across);
			if (offset <= MAX((real_t)(0.25 * p_spacing), (real_t)0.4 * length)) {
				Alignment paired = cell(near - 1, far - 1);
				paired.pair_count++;
				paired.total_offset += offset;
				paired.step = 3;
				if (is_better(paired, best)) {
					best = paired;
				}
			}
			cell(near, far) = best;
		}
	}
	int64_t near = near_count;
	int64_t far = far_count;
	while (near > 0 && far > 0) {
		const int8_t step = cell(near, far).step;
		if (step == 3) {
			pairs.push_back(Vector2i((int32_t)(near - 1), (int32_t)(far - 1)));
			near--;
			far--;
		} else if (step == 1) {
			near--;
		} else {
			far--;
		}
	}
	pairs.reverse();
	return pairs;
}

// Where two chords cross, strictly inside both, as the fraction of the way along each chord. In the face's frame the
// crossing is one point, but the chords themselves may pass at different heights where the face is warped.
static bool _intersect_fence_filler_chords(const FenceFillerChord &p_a, const FenceFillerChord &p_b, real_t &r_along_a, real_t &r_along_b) {
	const Vector2 a = p_a.end_2d - p_a.start_2d;
	const Vector2 b = p_b.end_2d - p_b.start_2d;
	const real_t denominator = a.cross(b);
	if (Math::is_zero_approx(denominator)) {
		return false;
	}
	const Vector2 start_offset = p_b.start_2d - p_a.start_2d;
	r_along_a = start_offset.cross(b) / denominator;
	r_along_b = start_offset.cross(a) / denominator;
	const real_t margin = (real_t)1e-6;
	return r_along_a > margin && r_along_a < (real_t)1.0 - margin && r_along_b > margin && r_along_b < (real_t)1.0 - margin;
}

void FenceBuildJob4D::_build_fence_filler_posts_and_ribs(const PackedVector4Array &p_poly_cell_vertex_positions, const PackedVector4Array &p_seed_face_normals, const Vector<PackedVector4Array> &p_edge_corner_offsets, HashMap<String, Ref<ArrayPolyMesh4D>> &r_post_mesh_cache, Ref<ArrayPolyMesh4D> &r_fence_posts_mesh, Ref<ArrayPolyMesh4D> &r_fence_ribs_mesh) const {
	const real_t spacing = (real_t)_desired_spacing_meters;
	ERR_FAIL_COND(!(spacing > (real_t)0.0));
	const Vector<Vector<PackedInt32Array>> seed_poly_indices = _seed_mesh_4d->get_poly_cell_indices();
	ERR_FAIL_COND(seed_poly_indices.is_empty());
	const Vector<PackedInt32Array> &face_edge_indices = seed_poly_indices[0];
	ERR_FAIL_COND(face_edge_indices.size() != p_seed_face_normals.size());
	const PackedInt32Array seed_edge_indices = _seed_mesh_4d->get_edge_indices();
	const int64_t edge_count = seed_edge_indices.size() / 2;
	ERR_FAIL_COND(p_edge_corner_offsets.size() != edge_count);
	const Vector4 up = Vector4(0, 1, 0, 0);
	auto edge_start = [&](const int32_t p_edge) -> const Vector4 & { return p_poly_cell_vertex_positions[seed_edge_indices[p_edge * 2]]; };
	auto edge_end = [&](const int32_t p_edge) -> const Vector4 & { return p_poly_cell_vertex_positions[seed_edge_indices[p_edge * 2 + 1]]; };
	auto edges_share_vertex = [&](const int32_t p_edge_a, const int32_t p_edge_b) {
		const int32_t a0 = seed_edge_indices[p_edge_a * 2];
		const int32_t a1 = seed_edge_indices[p_edge_a * 2 + 1];
		const int32_t b0 = seed_edge_indices[p_edge_b * 2];
		const int32_t b1 = seed_edge_indices[p_edge_b * 2 + 1];
		return a0 == b0 || a0 == b1 || a1 == b0 || a1 == b1;
	};
	// Step 1: Divide each edge into spans about the desired spacing long. The opposite edges of a quad must get the same
	// number of spans for its grid to work out, which links edges through quads into classes, and a class is divided by
	// its mean length. Any edge in no quad is divided by its own length.
	PackedInt32Array class_parent;
	class_parent.resize(edge_count);
	for (int64_t edge_index = 0; edge_index < edge_count; edge_index++) {
		class_parent.set(edge_index, (int32_t)edge_index);
	}
	auto find_class = [&](int32_t p_edge) {
		while (class_parent[p_edge] != p_edge) {
			class_parent.set(p_edge, class_parent[class_parent[p_edge]]);
			p_edge = class_parent[p_edge];
		}
		return p_edge;
	};
	for (const PackedInt32Array &face_edges : face_edge_indices) {
		if (face_edges.size() != 4) {
			continue;
		}
		bool in_loop_order = true;
		for (int64_t i = 0; i < 4; i++) {
			if (!edges_share_vertex(face_edges[i], face_edges[(i + 1) % 4])) {
				in_loop_order = false;
			}
		}
		if (!in_loop_order) {
			continue;
		}
		for (int64_t i = 0; i < 2; i++) {
			const int32_t root_a = find_class(face_edges[i]);
			const int32_t root_b = find_class(face_edges[i + 2]);
			if (root_a != root_b) {
				class_parent.set(root_b, root_a);
			}
		}
	}
	Vector<real_t> class_length_sums;
	class_length_sums.resize(edge_count);
	class_length_sums.fill(0.0);
	PackedInt32Array class_sizes;
	class_sizes.resize(edge_count);
	class_sizes.fill(0);
	for (int64_t edge_index = 0; edge_index < edge_count; edge_index++) {
		const int32_t root = find_class((int32_t)edge_index);
		class_length_sums.set(root, class_length_sums[root] + edge_start((int32_t)edge_index).distance_to(edge_end((int32_t)edge_index)));
		class_sizes.set(root, class_sizes[root] + 1);
	}
	PackedInt32Array edge_divisions;
	edge_divisions.resize(edge_count);
	for (int64_t edge_index = 0; edge_index < edge_count; edge_index++) {
		const int32_t root = find_class((int32_t)edge_index);
		const real_t mean_length = class_length_sums[root] / (real_t)class_sizes[root];
		// Only divide when that brings the spans closer to the desired spacing, and never into more than 100 spans.
		edge_divisions.set(edge_index, (int32_t)CLAMP(Math::round(mean_length / spacing), 1.0, 100.0));
	}
	// Step 2: Fill each face with chords between the division points on its boundary. In the frame of the face, with
	// U along its longest edge and V across, the edges facing down and up (by their outward normal) form two chains whose
	// points are paired by U into chords that run roughly along V, and the edges facing left and right form two chains
	// paired by V into chords along U. A slanted edge takes part in both. Posts go where chords end on the boundary,
	// collected over all faces so that the two faces sharing an edge share the post, and where chords cross.
	struct Junction {
		Vector4 position;
		PackedVector4Array hull_points;
		bool has_edge_rib_points = false;
	};
	HashMap<Vector2i, Junction> junctions;
	PackedVector4Array crossing_positions;
	Vector<PackedVector4Array> crossing_hull_points;
	Vector<Ref<ArrayPolyMesh4D>> filler_rib_meshes; // Merged at the end, see `_merge_meshes`.
	const real_t chain_threshold = (real_t)0.2; // On the component of an edge's unit outward normal: edges nearly parallel to an axis are not paired along it.
	const real_t min_chord_length = (real_t)0.5 * spacing;
	for (int64_t face_index = 0; face_index < face_edge_indices.size(); face_index++) {
		const PackedInt32Array &face_edges = face_edge_indices[face_index];
		if (face_edges.size() < 3) {
			continue;
		}
		const Vector4 &face_normal = p_seed_face_normals[face_index];
		// The face's frame: its centroid, U along its longest edge, V across within the face.
		Vector4 centroid;
		HashSet<int32_t> face_vertices;
		real_t longest_edge_length = 0.0;
		Vector4 axis_u;
		for (const int32_t edge_index : face_edges) {
			for (int64_t end = 0; end < 2; end++) {
				const int32_t vertex_index = seed_edge_indices[edge_index * 2 + end];
				if (!face_vertices.has(vertex_index)) {
					face_vertices.insert(vertex_index);
					centroid += p_poly_cell_vertex_positions[vertex_index];
				}
			}
			const Vector4 edge_vector = edge_end(edge_index) - edge_start(edge_index);
			if (edge_vector.length() > longest_edge_length) {
				longest_edge_length = edge_vector.length();
				axis_u = edge_vector;
			}
		}
		if (face_vertices.size() < 3 || longest_edge_length <= (real_t)0.0) {
			continue;
		}
		centroid /= (real_t)face_vertices.size();
		axis_u.normalize();
		// The face may lean out of the ground along Y, so V is perpendicular to U within the face rather than on the
		// ground, and the frame measures the face itself, along which the filler is spaced. The face's other normal,
		// besides its ground normal, is found from the vertex standing farthest out of the line of U, pointed upward,
		// and V is perpendicular to U and both normals. For a face on the ground that normal is exactly up, and V is
		// exactly the ground direction across the face.
		Vector4 second_axis;
		real_t second_axis_length = (real_t)0.0;
		for (const int32_t vertex_index : face_vertices) {
			const Vector4 offset = p_poly_cell_vertex_positions[vertex_index] - centroid;
			const Vector4 rejection = offset - axis_u * axis_u.dot(offset);
			if (rejection.length() > second_axis_length) {
				second_axis_length = rejection.length();
				second_axis = rejection;
			}
		}
		Vector4 face_up = Vector4D::perpendicular(axis_u, second_axis, face_normal).normalized();
		if (face_up.dot(up) < (real_t)0.0) {
			face_up = -face_up;
		}
		Vector4 axis_v = Vector4D::perpendicular(axis_u, face_up, face_normal);
		if (axis_v.is_zero_approx()) {
			continue;
		}
		axis_v.normalize();
		auto to_2d = [&](const Vector4 &p_point) {
			const Vector4 offset = p_point - centroid;
			return Vector2(offset.dot(axis_u), offset.dot(axis_v));
		};
		// The division points of each edge, sorted into the chains by which way the edge faces.
		Vector<FenceFillerPoint> lower_chain;
		Vector<FenceFillerPoint> upper_chain;
		Vector<FenceFillerPoint> left_chain;
		Vector<FenceFillerPoint> right_chain;
		for (const int32_t edge_index : face_edges) {
			const Vector4 &start = edge_start(edge_index);
			const Vector4 &end = edge_end(edge_index);
			const Vector2 start_2d = to_2d(start);
			const Vector2 end_2d = to_2d(end);
			const Vector2 direction_2d = (end_2d - start_2d).normalized();
			const Vector2 midpoint_2d = (start_2d + end_2d) * (real_t)0.5;
			// The midpoint is relative to the centroid, so its component across the edge points outward.
			Vector2 outward = midpoint_2d - direction_2d * midpoint_2d.dot(direction_2d);
			if (outward.is_zero_approx()) {
				continue;
			}
			outward.normalize();
			const int32_t divisions = edge_divisions[edge_index];
			for (int32_t division = 1; division < divisions; division++) {
				FenceFillerPoint point;
				point.key = Vector2i(edge_index, division);
				point.position = start + (end - start) * ((real_t)division / (real_t)divisions);
				const Vector2 point_2d = to_2d(point.position);
				point.along = point_2d.x;
				point.across = point_2d.y;
				if (outward.y < -chain_threshold) {
					lower_chain.push_back(point);
				} else if (outward.y > chain_threshold) {
					upper_chain.push_back(point);
				}
				point.along = point_2d.y;
				point.across = point_2d.x;
				if (outward.x < -chain_threshold) {
					left_chain.push_back(point);
				} else if (outward.x > chain_threshold) {
					right_chain.push_back(point);
				}
			}
		}
		lower_chain.sort_custom<FenceFillerPointSort>();
		upper_chain.sort_custom<FenceFillerPointSort>();
		left_chain.sort_custom<FenceFillerPointSort>();
		right_chain.sort_custom<FenceFillerPointSort>();
		// The chords of both families, each built as a rib along the face, with the post hull points of its two ends.
		Vector<FenceFillerChord> chord_families[2];
		for (int64_t family = 0; family < 2; family++) {
			const Vector<FenceFillerPoint> &near_chain = family == 0 ? lower_chain : left_chain;
			const Vector<FenceFillerPoint> &far_chain = family == 0 ? upper_chain : right_chain;
			const Vector<Vector2i> pairs = _match_fence_filler_points(near_chain, far_chain, spacing);
			for (const Vector2i &pair : pairs) {
				const FenceFillerPoint &near_point = near_chain[pair.x];
				const FenceFillerPoint &far_point = far_chain[pair.y];
				if (near_point.position.distance_to(far_point.position) < min_chord_length) {
					continue;
				}
				FenceFillerChord chord;
				chord.start = near_point.position;
				chord.end = far_point.position;
				chord.start_2d = to_2d(chord.start);
				chord.end_2d = to_2d(chord.end);
				chord.start_key = near_point.key;
				chord.end_key = far_point.key;
				// Both sides of a chord are the same face, so the rib is aligned with the face, as on a straight run.
				filler_rib_meshes.push_back(_build_fence_single_rib(chord.start, chord.end, face_normal, 1.0, chord.rib_corner_offsets));
				const Vector4 direction = chord.end - chord.start;
				for (int64_t end = 0; end < 2; end++) {
					const Vector2i &key = end == 0 ? chord.start_key : chord.end_key;
					Junction *junction = junctions.getptr(key);
					if (junction == nullptr) {
						Junction new_junction;
						new_junction.position = end == 0 ? chord.start : chord.end;
						junction = &junctions.insert(key, new_junction)->value;
					}
					_append_post_hull_points_for_rib(direction, chord.rib_corner_offsets, junction->hull_points);
					if (!junction->has_edge_rib_points) {
						// The post sits on the rib of the seed edge, which passes straight through it.
						junction->has_edge_rib_points = true;
						_append_post_hull_points_for_rib(edge_end(key.x) - edge_start(key.x), p_edge_corner_offsets[key.x], junction->hull_points);
					}
				}
				chord_families[family].push_back(chord);
			}
		}
		// Where a chord of one family crosses one of the other, a post covers the crossing.
		for (const FenceFillerChord &chord_a : chord_families[0]) {
			for (const FenceFillerChord &chord_b : chord_families[1]) {
				if (chord_a.start_key == chord_b.start_key || chord_a.start_key == chord_b.end_key || chord_a.end_key == chord_b.start_key || chord_a.end_key == chord_b.end_key) {
					continue; // They meet at a junction on the boundary, which already has its post.
				}
				real_t along_a;
				real_t along_b;
				if (!_intersect_fence_filler_chords(chord_a, chord_b, along_a, along_b)) {
					continue;
				}
				PackedVector4Array hull_points;
				_append_post_hull_points_for_rib(chord_a.end - chord_a.start, chord_a.rib_corner_offsets, hull_points);
				_append_post_hull_points_for_rib(chord_b.end - chord_b.start, chord_b.rib_corner_offsets, hull_points);
				// The post stands on the chords rather than in the face's frame, which a warped face, such as a box face
				// with one corner raised, leaves below or above its surface. The chords of a warped quad meet on it when
				// they run between matching division points of opposite edges, and where two chords do not quite meet,
				// the post stands halfway between them.
				crossing_positions.push_back((chord_a.start.lerp(chord_a.end, along_a) + chord_b.start.lerp(chord_b.end, along_b)) * (real_t)0.5);
				crossing_hull_points.push_back(hull_points);
			}
		}
	}
	// Step 3: The posts, each built at the origin and moved into place, then everything merged into the fence in bulk.
	Vector<Ref<ArrayPolyMesh4D>> filler_post_meshes;
	for (const KeyValue<Vector2i, Junction> &junction : junctions) {
		const Ref<ArrayPolyMesh4D> post_mesh = _build_fence_single_post_shared(junction.value.hull_points, r_post_mesh_cache);
		_lean_post(post_mesh, junction.value.position);
		post_mesh->transform_mesh(Transform4D(Basis4D(), junction.value.position));
		filler_post_meshes.push_back(post_mesh);
	}
	for (int64_t crossing_index = 0; crossing_index < crossing_positions.size(); crossing_index++) {
		const Ref<ArrayPolyMesh4D> post_mesh = _build_fence_single_post_shared(crossing_hull_points[crossing_index], r_post_mesh_cache);
		_lean_post(post_mesh, crossing_positions[crossing_index]);
		post_mesh->transform_mesh(Transform4D(Basis4D(), crossing_positions[crossing_index]));
		filler_post_meshes.push_back(post_mesh);
	}
	if (!filler_post_meshes.is_empty()) {
		r_fence_posts_mesh->merge_with(_merge_meshes(filler_post_meshes));
	}
	if (!filler_rib_meshes.is_empty()) {
		r_fence_ribs_mesh->merge_with(_merge_meshes(filler_rib_meshes));
	}
}
