#pragma once

#include "../../quantum_horizon_defines.h"

#include "modules/4d/model/mesh/mesh_instance_4d.h"
#include "modules/4d/model/mesh/poly/array_poly_mesh_4d.h"

class ConvexHullComputer;
class FenceBuildJob4D;
class FenceGuidePost4D;

class FenceGenerator4D : public MeshInstance4D {
	GDCLASS(FenceGenerator4D, MeshInstance4D);
	friend class FenceBuildJob4D; // Takes the snapshot a build reads from and reports back, see `queue_update_fence_mesh`.

public:
	enum InputShapeType : uint8_t {
		INPUT_SHAPE_BOX,
		INPUT_SHAPE_RADIAL_POINTS,
		INPUT_SHAPE_RADIAL_POST_NODES,
		INPUT_SHAPE_SEED_MESH_3D,
		INPUT_SHAPE_SEED_MESH_4D,
	};

	enum OutputMeshType : uint8_t {
		OUTPUT_MESH_POLY_VOLUMETRIC,
		OUTPUT_MESH_POLY_SURFACE,
		OUTPUT_MESH_TETRA,
		OUTPUT_MESH_WIRE,
	};

private:
	PackedVector4Array _fence_corners;
	Ref<Mesh> _seed_mesh_3d;
	Ref<PolyMesh4D> _seed_mesh_4d;
	Ref<Material4D> _post_material;
	Ref<Material4D> _rib_material;
	Ref<Material4D> _beam_material;
	Vector3 _box_size = Vector3(10, 10, 10); // X, Z, W.

	double _desired_spacing_meters = 2.0; // How far apart to try and place fence posts and ribs.
	double _post_height_meters = 1.25;
	double _post_thickness_meters = 0.1;
	double _top_footprint_ratio = 1.0; // The footprint at the top of the posts as a ratio of the one on the ground: below 1 the fence leans inward.
	double _rib_height_ratio = 0.8; // Ratio of _post_height_meters.
	double _rib_thickness_ratio = 0.5; // Ratio of _post_thickness_meters.
	double _beam_max_height_ratio = 0.8; // Ratio of _rib_height_ratio of _post_height_meters.
	double _beam_thickness_ratio = 0.5; // Ratio of _rib_thickness_ratio of _post_thickness_meters.
	double _beam_coverage = 0.25;
	int32_t _beam_count = 3;

	InputShapeType _input_shape_type = INPUT_SHAPE_BOX;
	OutputMeshType _output_mesh_type = OUTPUT_MESH_POLY_VOLUMETRIC;
	bool _is_ready = false;
	bool _update_automatically = true;
	bool _updating_guide_posts = false; // Set while this node adds or removes guide posts itself.
	bool _deferred_update_pending = false;
	bool _corners_surround_origin = true; // Whether the last corners surround the origin: at least 4, spanning a 3D volume.
	// The build in the background, see `queue_update_fence_mesh`: whether one runs, whether another is wanted once it
	// has, and the number of the latest build started, which a finished build must match to be applied.
	bool _is_fence_currently_generating = false;
	bool _is_fence_generation_queued = false;
	uint64_t _fence_generation_id = 0;

	bool _ensure_seed_mesh_4d_has_face_normals();
	void _update_fence_corners_from_box_size();
	void _update_fence_corners_from_seed_mesh();
	Vector<FenceGuidePost4D *> _get_guide_posts() const;
	void _update_fence_corners_from_post_nodes();
	void _create_guide_posts_from_corners();
	void _remove_guide_posts();
	void _on_guide_post_child_changed(Node *p_child);
	void _request_deferred_update();
	void _deferred_update();
	void _clear_fence_mesh();
	void _refresh_configuration_warnings();

	static bool _repack_convex_hull_topology(const ConvexHullComputer &p_convex_hull, PackedInt32Array &r_edge_vertex_indices, Vector<PackedInt32Array> &r_face_edge_indices);
	static bool _does_convex_hull_surround_origin(const ConvexHullComputer &p_convex_hull);
	static Ref<ArrayPolyMesh4D> _build_seed_mesh_from_corners_internal(const PackedVector4Array &p_corners, String &r_error);
	bool _update_seed_mesh();
	bool _prepare_seed_mesh_4d();
	void _apply_build_job(FenceBuildJob4D *p_job);
	void _apply_guide_post_results(FenceBuildJob4D *p_job);
	void _on_build_job_finished(FenceBuildJob4D *p_job);

protected:
	static void _bind_methods();
	void _notification(int p_what);
	void _validate_property(PropertyInfo &p_property) const;
	virtual void add_child_notify(Node *p_child) override;
	virtual void remove_child_notify(Node *p_child) override;
	virtual void move_child_notify(Node *p_child) override;

public:
	PackedVector4Array get_fence_corners() const { return _fence_corners; }
	void set_fence_corners(const PackedVector4Array &p_fence_corners);

	Ref<Mesh> get_seed_mesh_3d() const { return _seed_mesh_3d; }
	void set_seed_mesh_3d(const Ref<Mesh> &p_seed_mesh_3d);

	Ref<PolyMesh4D> get_seed_mesh_4d() const { return _seed_mesh_4d; }
	void set_seed_mesh_4d(const Ref<PolyMesh4D> &p_seed_mesh_4d);

	Ref<Material4D> get_post_material() const { return _post_material; }
	void set_post_material(const Ref<Material4D> &p_post_material);

	Ref<Material4D> get_rib_material() const { return _rib_material; }
	void set_rib_material(const Ref<Material4D> &p_rib_material);

	Ref<Material4D> get_beam_material() const { return _beam_material; }
	void set_beam_material(const Ref<Material4D> &p_beam_material);

	Vector3 get_box_size() const { return _box_size; }
	void set_box_size(const Vector3 &p_box_size);

	double get_desired_spacing_meters() const { return _desired_spacing_meters; }
	void set_desired_spacing_meters(const double p_desired_spacing_meters);

	double get_post_height_meters() const { return _post_height_meters; }
	void set_post_height_meters(const double p_post_height_meters);

	double get_post_thickness_meters() const { return _post_thickness_meters; }
	void set_post_thickness_meters(const double p_post_thickness_meters);

	double get_top_footprint_ratio() const { return _top_footprint_ratio; }
	void set_top_footprint_ratio(const double p_top_footprint_ratio);

	double get_rib_height_ratio() const { return _rib_height_ratio; }
	void set_rib_height_ratio(const double p_rib_height_ratio);

	double get_rib_thickness_ratio() const { return _rib_thickness_ratio; }
	void set_rib_thickness_ratio(const double p_rib_thickness_ratio);

	double get_beam_max_height_ratio() const { return _beam_max_height_ratio; }
	void set_beam_max_height_ratio(const double p_beam_max_height_ratio);

	double get_beam_coverage() const { return _beam_coverage; }
	void set_beam_coverage(const double p_beam_coverage);

	double get_beam_thickness_ratio() const { return _beam_thickness_ratio; }
	void set_beam_thickness_ratio(const double p_beam_thickness_ratio);

	int32_t get_beam_count() const { return _beam_count; }
	void set_beam_count(const int32_t p_beam_count);

	InputShapeType get_input_shape_type() const { return _input_shape_type; }
	void set_input_shape_type(const InputShapeType p_input_shape_type);

	OutputMeshType get_output_mesh_type() const { return _output_mesh_type; }
	void set_output_mesh_type(const OutputMeshType p_output_mesh_type);

	bool get_update_automatically() const { return _update_automatically; }
	void set_update_automatically(const bool p_update_automatically);

	Ref<ArrayPolyMesh4D> build_seed_mesh_from_corners() const;
	Ref<Mesh4D> build_fence_from_seed_mesh();
	void notify_guide_post_changed(); // Do not expose.
	void queue_update_fence_mesh();
	void update_fence_mesh_now();
	bool is_local_point_inside(const Vector4 &p_local_point) const;
	bool is_global_point_inside(const Vector4 &p_global_point) const;
	bool is_updating() const { return _is_fence_currently_generating; }
	virtual PackedStringArray get_configuration_warnings() const override;
	Callable _get_update_fence_mesh_button() const;
};

VARIANT_ENUM_CAST(FenceGenerator4D::InputShapeType);
VARIANT_ENUM_CAST(FenceGenerator4D::OutputMeshType);
