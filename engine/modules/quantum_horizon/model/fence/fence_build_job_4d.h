#pragma once

#include "fence_generator_4d.h"

#include "core/object/worker_thread_pool.h"

// One build of a fence mesh, see `FenceGenerator4D::queue_update_fence_mesh`. The job holds a snapshot of everything the
// build reads, taken on the main thread when the job is made, so that the build can run on a worker thread while the
// node's properties, seed, and guide posts keep changing, and it holds what the build produced, validated and ready to
// render, which the node applies on the main thread once the job has finished. The builders live here so that they
// read the snapshot and nothing else.
//
// The build runs on its one thread from start to finish. Spreading its independent steps, the pairs of each round of
// merging and the distinct posts, over WorkerThreadPool tasks was tried and measured, and gained no wall time at all,
// with few or many pool threads and with or without the editor's allocation counters: merging and validating poly
// meshes allocate per cell, so they are bound by the allocator and memory rather than by compute, and threads only
// contend. Making the steps themselves cheaper is what pays.
class FenceBuildJob4D : public RefCounted {
	GDCLASS(FenceBuildJob4D, RefCounted);
	friend class FenceGenerator4D;

	// The snapshot. The names match FenceGenerator4D's members, which the builders were written against.
	Ref<ArrayPolyMesh4D> _seed_mesh_4d; // A copy of the node's seed, with a normal for every face.
	Ref<Material4D> _post_material;
	Ref<Material4D> _rib_material;
	Ref<Material4D> _beam_material;
	double _desired_spacing_meters = 2.0;
	double _post_height_meters = 1.25;
	double _post_thickness_meters = 0.1;
	double _rib_height_ratio = 0.8;
	double _rib_thickness_ratio = 0.5;
	double _beam_max_height_ratio = 0.8;
	double _beam_thickness_ratio = 0.5;
	double _top_footprint_ratio = 1.0;
	double _beam_coverage = 0.25;
	int32_t _beam_count = 3;
	FenceGenerator4D::InputShapeType _input_shape_type = FenceGenerator4D::INPUT_SHAPE_BOX;
	FenceGenerator4D::OutputMeshType _output_mesh_type = FenceGenerator4D::OUTPUT_MESH_POLY_VOLUMETRIC;
	// The guide posts of the post shape: the positions the posts are matched to vertices by, and the ids their meshes
	// are handed back through, since nodes are never touched off the main thread.
	PackedVector4Array _guide_post_positions;
	Vector<ObjectID> _guide_post_ids;

	// The results.
	Ref<Mesh4D> _fence_mesh;
	Vector<Ref<Mesh4D>> _guide_post_meshes; // One per guide post, and null for a degenerate one.
	Vector<bool> _guide_post_degenerate;

	// The task.
	ObjectID _fence_id;
	uint64_t _generation_id = 0;
	Ref<FenceBuildJob4D> _self_reference; // Held while the task runs and until the node has been told.
	WorkerThreadPool::TaskID _task_id = WorkerThreadPool::INVALID_TASK_ID; // Waited for once it has run, which frees the pool's record of it.

	Ref<ArrayPolyMesh4D> _build_fence_beams_from_seed_faces() const;
	Ref<ArrayPolyMesh4D> _build_fence_single_rib(const Vector4 &p_edge_vert_0, const Vector4 &p_edge_vert_1, const Vector4 &p_radial_normal, const double p_normal_dot, PackedVector4Array &r_base_corner_offsets) const;
	void _append_post_hull_points_for_rib(const Vector4 &p_rib_direction, const PackedVector4Array &p_rib_corner_offsets, PackedVector4Array &r_hull_points) const;
	Ref<ArrayPolyMesh4D> _build_fence_ribs_from_seed_edges(const PackedVector4Array &p_poly_cell_vertex_positions, const PackedVector4Array &p_seed_face_normals, Vector<PackedVector4Array> &r_post_hull_offsets, Vector<PackedVector4Array> &r_edge_corner_offsets) const;
	static Ref<ArrayPolyMesh4D> _merge_meshes(Vector<Ref<ArrayPolyMesh4D>> p_meshes);
	static void _set_seams_between_cell_groups(const Ref<ArrayPolyMesh4D> &p_mesh, const PackedInt32Array &p_cell_groups);
	PackedInt32Array _beam_cell_seed_faces(const Ref<ArrayPolyMesh4D> &p_beam_mesh) const;
	Ref<ArrayPolyMesh4D> _build_fence_single_post(const PackedVector4Array &p_hull_point_offsets) const;
	PackedInt32Array _nearest_seed_vertices(const PackedVector4Array &p_positions) const;
	real_t _taper_scale(const real_t p_height_above_ground) const;
	void _taper_part(const Ref<ArrayPolyMesh4D> &p_part, const Vector4 &p_origin, const Vector<real_t> &p_ground_heights = Vector<real_t>()) const;
	void _lean_post(const Ref<ArrayPolyMesh4D> &p_post, const Vector4 &p_post_position) const;
	Ref<SingleSurfaceMesh4D> _convert_to_output_mesh_type(const Ref<ArrayPolyMesh4D> &p_mesh) const;
	static Ref<Mesh4D> _validate_finished_mesh(const Ref<Mesh4D> &p_mesh);
	Ref<ArrayPolyMesh4D> _build_fence_single_post_shared(const PackedVector4Array &p_hull_point_offsets, HashMap<String, Ref<ArrayPolyMesh4D>> &r_post_mesh_cache) const;
	Ref<ArrayPolyMesh4D> _build_fence_posts_from_seed_vertices(const PackedVector4Array &p_poly_cell_vertex_positions, const Vector<PackedVector4Array> &p_post_hull_offsets, HashMap<String, Ref<ArrayPolyMesh4D>> &r_post_mesh_cache);
	void _build_fence_filler_posts_and_ribs(const PackedVector4Array &p_poly_cell_vertex_positions, const PackedVector4Array &p_seed_face_normals, const Vector<PackedVector4Array> &p_edge_corner_offsets, HashMap<String, Ref<ArrayPolyMesh4D>> &r_post_mesh_cache, Ref<ArrayPolyMesh4D> &r_fence_posts_mesh, Ref<ArrayPolyMesh4D> &r_fence_ribs_mesh) const;
	void _run_task();
	void _finish_on_main_thread();

protected:
	static void _bind_methods() {}

public:
	void snapshot_from(const FenceGenerator4D *p_fence, const uint64_t p_generation_id);
	void run();
	void start_threaded();
	Ref<Mesh4D> get_fence_mesh() const { return _fence_mesh; }
	uint64_t get_generation_id() const { return _generation_id; }
};
