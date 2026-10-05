#pragma once

#include "../../../model/fence/fence_generator_4d.h"
#include "../../../model/fence/fence_guide_post_4d.h"

#include "core/object/message_queue.h"
#include "core/os/os.h"
#include "scene/main/window.h"
#include "scene/resources/packed_scene.h"
#include "tests/test_macros.h"

#include "modules/4d/model/mesh/multi_surface_mesh_4d.h"
#include "modules/4d/model/mesh/poly/poly_material_4d.h"
#include "modules/4d/model/mesh/tetra/array_tetra_mesh_4d.h"
#include "modules/4d/model/mesh/wire/array_wire_mesh_4d.h"

namespace TestFenceGuidePosts4D {

static Vector<FenceGuidePost4D *> get_guide_posts(const Node *p_fence) {
	Vector<FenceGuidePost4D *> guide_posts;
	for (int child_index = 0; child_index < p_fence->get_child_count(); child_index++) {
		FenceGuidePost4D *guide_post = Object::cast_to<FenceGuidePost4D>(p_fence->get_child(child_index));
		if (guide_post != nullptr) {
			guide_posts.push_back(guide_post);
		}
	}
	return guide_posts;
}

// Automatic updates run at the end of the frame, which the message queue flush stands in for here, and then build on a
// worker thread, so this flushes and waits until the fence has nothing running or queued, delivering results as they come.
static void settle_fence(FenceGenerator4D *p_fence) {
	MessageQueue::get_singleton()->flush();
	while (p_fence->is_updating()) {
		OS::get_singleton()->delay_usec(200);
		MessageQueue::get_singleton()->flush();
	}
}

// The guide posts react to child changes with a deferred rebuild in the background, see `settle_fence`.
TEST_CASE("[SceneTree][FenceGenerator4D] Guide posts") {
	FenceGenerator4D *fence = memnew(FenceGenerator4D);
	SceneTree::get_singleton()->get_root()->add_child(fence);
	settle_fence(fence);
	REQUIRE(fence->get_mesh().is_valid());
	fence->set_input_shape_type(FenceGenerator4D::INPUT_SHAPE_RADIAL_POST_NODES);
	settle_fence(fence);
	const Vector<FenceGuidePost4D *> posts = get_guide_posts(fence);
	REQUIRE(posts.size() == 8);

	SUBCASE("Entering the guide post shape creates owned posts with meshes and no warnings") {
		CHECK(fence->get_fence_corners().size() == 8);
		CHECK(fence->get_configuration_warnings().is_empty());
		for (const FenceGuidePost4D *post : posts) {
			CHECK(post->get_owner() == fence);
			CHECK(post->get_mesh().is_valid());
			CHECK(post->get_configuration_warnings().is_empty());
		}
	}

	SUBCASE("A second guide post at the same position is ignored and says so") {
		FenceGuidePost4D *duplicate = memnew(FenceGuidePost4D);
		duplicate->set_position(posts[2]->get_position());
		fence->add_child(duplicate);
		settle_fence(fence);
		CHECK(fence->get_fence_corners().size() == 9);
		CHECK(duplicate->get_mesh().is_null());
		CHECK(posts[2]->get_mesh().is_valid());
		CHECK(duplicate->get_configuration_warnings().size() == 1);
		CHECK(posts[2]->get_configuration_warnings().is_empty());
	}

	SUBCASE("Removing posts the way the editor does rebuilds the fence, and too few posts is a warning rather than an error") {
		Vector<FenceGuidePost4D *> removed;
		for (int post_index = 0; post_index < 5; post_index++) {
			fence->remove_child(posts[post_index]);
			removed.push_back(posts[post_index]);
		}
		CHECK_MESSAGE(fence->get_fence_corners().size() == 8, "The rebuild waits for the end of the frame.");
		settle_fence(fence);
		CHECK(fence->get_fence_corners().size() == 3);
		CHECK(fence->get_mesh().is_null());
		CHECK(fence->get_configuration_warnings().size() == 1);
		// Undo in the editor adds the same nodes back.
		for (FenceGuidePost4D *post : removed) {
			fence->add_child(post);
		}
		settle_fence(fence);
		CHECK(fence->get_fence_corners().size() == 8);
		CHECK(fence->get_mesh().is_valid());
		CHECK(fence->get_configuration_warnings().is_empty());
		for (const FenceGuidePost4D *post : posts) {
			CHECK(post->get_mesh().is_valid());
		}
	}

	SUBCASE("Leaving the guide post shape keeps the corners and removes the posts") {
		fence->set_input_shape_type(FenceGenerator4D::INPUT_SHAPE_RADIAL_POINTS);
		settle_fence(fence);
		CHECK(get_guide_posts(fence).is_empty());
		CHECK(fence->get_fence_corners().size() == 8);
		CHECK(fence->get_mesh().is_valid());
	}

	SUBCASE("Guide post meshes follow the output mesh type like the fence's own") {
		fence->set_output_mesh_type(FenceGenerator4D::OUTPUT_MESH_WIRE);
		settle_fence(fence);
		for (const FenceGuidePost4D *post : posts) {
			CHECK(Object::cast_to<ArrayWireMesh4D>(post->get_mesh().ptr()) != nullptr);
		}
		fence->set_output_mesh_type(FenceGenerator4D::OUTPUT_MESH_TETRA);
		settle_fence(fence);
		for (const FenceGuidePost4D *post : posts) {
			CHECK(Object::cast_to<ArrayTetraMesh4D>(post->get_mesh().ptr()) != nullptr);
		}
		fence->set_output_mesh_type(FenceGenerator4D::OUTPUT_MESH_POLY_SURFACE);
		settle_fence(fence);
		for (const FenceGuidePost4D *post : posts) {
			CHECK(Object::cast_to<ArrayPolyMesh4D>(post->get_mesh().ptr()) != nullptr);
		}
	}

	SUBCASE("A degenerate guide post gets no mesh and says so") {
		FenceGuidePost4D *inside = memnew(FenceGuidePost4D);
		inside->set_position(Vector4(0, 0, 0, 0)); // At the origin, where a new child starts: its direction is zero, so the hull drops it.
		fence->add_child(inside);
		settle_fence(fence);
		CHECK(inside->get_mesh().is_null());
		CHECK(inside->get_configuration_warnings().size() == 1);
		for (const FenceGuidePost4D *post : posts) {
			CHECK(post->get_configuration_warnings().is_empty());
		}
		// Without a footprint no post is degenerate, so the warning leaves with the fence. Only two other corners are left,
		// since with three the origin would be a fourth corner rather than a dropped one.
		Vector<FenceGuidePost4D *> removed;
		for (int post_index = 0; post_index < 6; post_index++) {
			fence->remove_child(posts[post_index]);
			removed.push_back(posts[post_index]);
		}
		settle_fence(fence);
		CHECK(fence->get_mesh().is_null());
		CHECK(inside->get_configuration_warnings().is_empty());
		for (FenceGuidePost4D *post : removed) {
			fence->add_child(post);
		}
		settle_fence(fence);
		CHECK(inside->get_configuration_warnings().size() == 1);
	}

	SUBCASE("Guide post meshes are saved only while updates are manual") {
		auto packed_posts_store_mesh = [&]() -> bool {
			Ref<PackedScene> packed;
			packed.instantiate();
			REQUIRE(packed->pack(fence) == OK);
			const Ref<SceneState> state = packed->get_state();
			int posts_found = 0;
			bool stores_mesh = false;
			for (int node_index = 0; node_index < state->get_node_count(); node_index++) {
				if (state->get_node_type(node_index) != StringName("FenceGuidePost4D")) {
					continue;
				}
				posts_found++;
				for (int property_index = 0; property_index < state->get_node_property_count(node_index); property_index++) {
					stores_mesh = stores_mesh || state->get_node_property_name(node_index, property_index) == StringName("mesh");
				}
			}
			REQUIRE(posts_found == 8);
			return stores_mesh;
		};
		CHECK_FALSE(packed_posts_store_mesh());
		fence->set_update_automatically(false);
		CHECK(packed_posts_store_mesh());
	}

	SUBCASE("Reordering two guide posts at one position moves the mesh to the one now first") {
		FenceGuidePost4D *duplicate = memnew(FenceGuidePost4D);
		duplicate->set_position(posts[2]->get_position());
		fence->add_child(duplicate);
		settle_fence(fence);
		REQUIRE(duplicate->get_mesh().is_null());
		fence->move_child(duplicate, 0);
		settle_fence(fence);
		CHECK(duplicate->get_mesh().is_valid());
		CHECK(duplicate->get_configuration_warnings().is_empty());
		CHECK(posts[2]->get_mesh().is_null());
		CHECK(posts[2]->get_configuration_warnings().size() == 1);
	}

	SUBCASE("Adding a guide post while the fence is detached still counts") {
		SceneTree::get_singleton()->get_root()->remove_child(fence);
		FenceGuidePost4D *far_post = memnew(FenceGuidePost4D);
		far_post->set_position(Vector4(0, 0, 0, 9));
		fence->add_child(far_post);
		settle_fence(fence);
		CHECK(fence->get_fence_corners().size() == 9);
		CHECK(far_post->get_mesh().is_valid());
		SceneTree::get_singleton()->get_root()->add_child(fence);
	}

	SUBCASE("Leaving the box shape with updates off hands over the current box's corners") {
		fence->set_update_automatically(false);
		fence->set_input_shape_type(FenceGenerator4D::INPUT_SHAPE_BOX);
		fence->set_box_size(Vector3(20, 20, 20));
		fence->set_input_shape_type(FenceGenerator4D::INPUT_SHAPE_RADIAL_POINTS);
		const PackedVector4Array corners = fence->get_fence_corners();
		REQUIRE(corners.size() == 8);
		for (const Vector4 &corner : corners) {
			CHECK(Math::is_equal_approx(Math::abs(corner.x), (real_t)10.0));
			CHECK(Math::is_equal_approx(Math::abs(corner.z), (real_t)10.0));
			CHECK(Math::is_equal_approx(Math::abs(corner.w), (real_t)10.0));
		}
	}

	SUBCASE("Guide post meshes carry the post material, whatever the output type") {
		Ref<PolyMaterial4D> post_material;
		post_material.instantiate();
		fence->set_post_material(post_material);
		settle_fence(fence);
		for (const FenceGuidePost4D *post : posts) {
			const Ref<SingleSurfaceMesh4D> post_mesh = post->get_mesh();
			REQUIRE(post_mesh.is_valid());
			CHECK(post_mesh->get_material() == post_material);
		}
		fence->set_output_mesh_type(FenceGenerator4D::OUTPUT_MESH_WIRE);
		settle_fence(fence);
		for (const FenceGuidePost4D *post : posts) {
			const Ref<SingleSurfaceMesh4D> post_mesh = post->get_mesh();
			REQUIRE(post_mesh.is_valid());
			CHECK(post_mesh->get_material() == post_material);
		}
	}

	SUBCASE("Guide posts loaded for another shape are handed over and removed when the fence is ready") {
		// A saved post-shape fence whose shape a script changes before adding it to the tree.
		Ref<PackedScene> packed;
		packed.instantiate();
		REQUIRE(packed->pack(fence) == OK);
		FenceGenerator4D *loaded = Object::cast_to<FenceGenerator4D>(packed->instantiate());
		REQUIRE(loaded != nullptr);
		REQUIRE(get_guide_posts(loaded).size() == 8);
		loaded->set_input_shape_type(FenceGenerator4D::INPUT_SHAPE_RADIAL_POINTS);
		SceneTree::get_singleton()->get_root()->add_child(loaded);
		settle_fence(loaded);
		CHECK(get_guide_posts(loaded).is_empty());
		CHECK(loaded->get_fence_corners().size() == 8);
		CHECK(loaded->get_mesh().is_valid());
		CHECK(loaded->get_configuration_warnings().is_empty());
		memdelete(loaded);
	}

	SUBCASE("A guide post whose parent is not a fence warns about it") {
		Node4D *plain_node = memnew(Node4D);
		SceneTree::get_singleton()->get_root()->add_child(plain_node);
		FenceGuidePost4D *stray_post = memnew(FenceGuidePost4D);
		plain_node->add_child(stray_post);
		CHECK(stray_post->get_configuration_warnings().size() == 1);
		memdelete(plain_node);
	}

	memdelete(fence);
}

static Vector3 xzw(const Vector4 &p_vector) {
	return Vector3(p_vector.x, p_vector.z, p_vector.w);
}

// Checks that each post's footprint, the cell of its 4D volume that sits on the ground, contains every rib vertex within a
// post thickness of the post, which are the ends of the ribs meeting there. Returns how many posts had rib ends to check,
// and requires at least `p_min_posts` of them, since a post that a rib only passes through has no rib vertex near it.
static int check_posts_cover_rib_ends(const Ref<ArrayPolyMesh4D> &p_posts, const Ref<ArrayPolyMesh4D> &p_ribs, const double p_post_thickness, const int p_min_posts) {
	const PackedVector4Array post_positions = p_posts->get_poly_cell_vertex_positions();
	const Vector<Vector<PackedInt32Array>> post_indices = p_posts->get_poly_cell_indices();
	REQUIRE(post_indices.size() == 3); // Faces, cells, and one volume per post.
	const Vector<PackedInt32Array> face_loops = p_posts->get_all_face_vertex_indices();
	const Vector<PackedInt32Array> cell_vertices = p_posts->get_all_poly_cell_vertex_indices(3, false);
	const PackedVector4Array rib_positions = p_ribs->get_poly_cell_vertex_positions();
	int posts_with_rib_ends = 0;
	for (const PackedInt32Array &volume : post_indices[2]) {
		// The bottom cap is the cell whose vertices all sit on the ground.
		int32_t cap = -1;
		for (const int32_t cell_index : volume) {
			bool on_ground = true;
			for (const int32_t vertex_index : cell_vertices[cell_index]) {
				if (Math::abs(post_positions[vertex_index].y) > (real_t)1e-6) {
					on_ground = false;
					break;
				}
			}
			if (on_ground) {
				cap = cell_index;
				break;
			}
		}
		REQUIRE(cap != -1);
		Vector3 centroid;
		for (const int32_t vertex_index : cell_vertices[cap]) {
			centroid += xzw(post_positions[vertex_index]);
		}
		centroid /= (real_t)cell_vertices[cap].size();
		// Outward planes of the cap's faces.
		Vector<Plane> planes;
		for (const int32_t face_index : post_indices[1][cap]) {
			const PackedInt32Array &loop = face_loops[face_index];
			const Vector3 origin = xzw(post_positions[loop[0]]);
			Vector3 normal;
			for (int64_t i = 1; i + 1 < loop.size() && normal.length_squared() <= (real_t)1e-24; i++) {
				normal = (xzw(post_positions[loop[i]]) - origin).cross(xzw(post_positions[loop[i + 1]]) - origin);
			}
			REQUIRE(normal.length_squared() > (real_t)1e-24);
			normal.normalize();
			if (normal.dot(centroid - origin) > 0.0) {
				normal = -normal;
			}
			planes.push_back(Plane(normal, origin));
		}
		int rib_points_checked = 0;
		for (const Vector4 &rib_position : rib_positions) {
			const Vector3 rib_point = xzw(rib_position);
			if (rib_point.distance_to(centroid) > p_post_thickness) {
				continue;
			}
			rib_points_checked++;
			for (const Plane &plane : planes) {
				CHECK_MESSAGE(plane.distance_to(rib_point) <= (real_t)1e-9, "A rib end pokes out of its post.");
			}
		}
		if (rib_points_checked > 0) {
			CHECK(rib_points_checked >= 8);
			posts_with_rib_ends++;
		}
	}
	CHECK(posts_with_rib_ends >= p_min_posts);
	return posts_with_rib_ends;
}

// A footprint face that is not flat turns the cross-sections of the ribs around it slightly, which used to hand the
// post hull points a few millimeters apart and leave the post with cells too thin to texture. The posts merge such
// points now, and have to stay big enough to cover the ends of their ribs while doing so.
TEST_CASE("[FenceGenerator4D] Posts of a folded footprint are textured and cover their ribs") {
	FenceGenerator4D *fence = memnew(FenceGenerator4D);
	fence->set_update_automatically(false);
	fence->set_desired_spacing_meters(0.0); // No filler, so that every post is a corner post.
	fence->set_input_shape_type(FenceGenerator4D::INPUT_SHAPE_RADIAL_POINTS);
	PackedVector4Array corners;
	for (const real_t w : { -5.0, 5.0 }) {
		for (const real_t z : { -5.0, 5.0 }) {
			for (const real_t x : { -5.0, 5.0 }) {
				corners.push_back(Vector4(x, 0, z, w));
			}
		}
	}
	corners.set(0, Vector4(-5, 0, -5, -6)); // Pushed out, so the face at W = -5 folds along a diagonal.
	fence->set_fence_corners(corners);
	// Distinct materials keep the posts, ribs, and beams as separate surfaces.
	Ref<PolyMaterial4D> post_material;
	post_material.instantiate();
	Ref<PolyMaterial4D> rib_material;
	rib_material.instantiate();
	fence->set_post_material(post_material);
	fence->set_rib_material(rib_material);
	fence->update_fence_mesh_now();
	Ref<MultiSurfaceMesh4D> mesh = fence->get_mesh();
	REQUIRE(mesh.is_valid());
	const Vector<Ref<SingleSurfaceMesh4D>> surfaces = mesh->get_surface_meshes();
	REQUIRE(surfaces.size() == 3);
	Ref<ArrayPolyMesh4D> posts = surfaces[0];
	Ref<ArrayPolyMesh4D> ribs = surfaces[1];
	REQUIRE(posts.is_valid());
	REQUIRE(ribs.is_valid());

	SUBCASE("Every cell of every part has texture coordinates") {
		for (const Ref<SingleSurfaceMesh4D> &surface : surfaces) {
			Ref<ArrayPolyMesh4D> part = surface;
			REQUIRE(part.is_valid());
			const Vector<PackedInt32Array> texture_map = part->get_poly_cell_texture_map_indices();
			const int64_t cell_count = part->get_poly_cell_indices()[1].size();
			REQUIRE(texture_map.size() == cell_count);
			for (int64_t cell_index = 0; cell_index < cell_count; cell_index++) {
				CHECK(!texture_map[cell_index].is_empty());
			}
		}
	}

	SUBCASE("Each post's footprint contains the ends of the ribs at its corner") {
		const int posts_with_rib_ends = check_posts_cover_rib_ends(posts, ribs, fence->get_post_thickness_meters(), 8);
		CHECK(posts_with_rib_ends == 8);
	}

	memdelete(fence);
}

static int64_t count_volumes(const Ref<ArrayPolyMesh4D> &p_mesh) {
	const Vector<Vector<PackedInt32Array>> indices = p_mesh->get_poly_cell_indices();
	return indices.size() > 2 ? indices[2].size() : 0;
}

// The default box footprint has six 10 m by 10 m faces. A spacing of 2 divides every edge into 5 spans, the opposite
// edges of each quad share their division, so every face gets a 4 by 4 grid of chords, and the two faces sharing an edge
// end their chords on the same points, so each of those points gets one post. In the volumetric output every post and rib
// is its own 4D volume, which makes them countable.
TEST_CASE("[FenceGenerator4D] Filler posts and ribs follow the desired spacing") {
	FenceGenerator4D *fence = memnew(FenceGenerator4D);
	fence->set_update_automatically(false);
	Ref<PolyMaterial4D> post_material;
	post_material.instantiate();
	Ref<PolyMaterial4D> rib_material;
	rib_material.instantiate();
	fence->set_post_material(post_material);
	fence->set_rib_material(rib_material);

	SUBCASE("A spacing of zero adds nothing") {
		fence->set_desired_spacing_meters(0.0);
		fence->update_fence_mesh_now();
		Ref<MultiSurfaceMesh4D> mesh = fence->get_mesh();
		REQUIRE(mesh.is_valid());
		CHECK(count_volumes(mesh->get_surface_meshes()[0]) == 8);
		CHECK(count_volumes(mesh->get_surface_meshes()[1]) == 12);
	}

	SUBCASE("A spacing of 2 gives every face a 4 by 4 grid, shared along the edges") {
		fence->set_desired_spacing_meters(2.0);
		fence->update_fence_mesh_now();
		Ref<MultiSurfaceMesh4D> mesh = fence->get_mesh();
		REQUIRE(mesh.is_valid());
		const Vector<Ref<SingleSurfaceMesh4D>> surfaces = mesh->get_surface_meshes();
		REQUIRE(surfaces.size() == 3);
		Ref<ArrayPolyMesh4D> posts = surfaces[0];
		Ref<ArrayPolyMesh4D> ribs = surfaces[1];
		// 12 edge ribs, plus 8 chords across each of the 6 faces.
		CHECK(count_volumes(ribs) == 12 + 6 * 8);
		// 8 corner posts, one post at each of the 4 division points of each of the 12 edges, and 16 crossings per face.
		CHECK(count_volumes(posts) == 8 + 12 * 4 + 6 * 16);
		// Every post stands on the 2 m grid of the footprint: each ground coordinate is a face coordinate of 5 or one of the
		// division points at -3, -1, 1, and 3, so a whole odd number no larger than 5.
		const PackedVector4Array post_positions = posts->get_poly_cell_vertex_positions();
		const Vector<Vector<PackedInt32Array>> post_indices = posts->get_poly_cell_indices();
		const Vector<PackedInt32Array> cell_vertices = posts->get_all_poly_cell_vertex_indices(3, false);
		for (const PackedInt32Array &volume : post_indices[2]) {
			Vector4 center;
			int64_t counted = 0;
			for (const int32_t cell_index : volume) {
				for (const int32_t vertex_index : cell_vertices[cell_index]) {
					center += post_positions[vertex_index];
					counted++;
				}
			}
			center /= (real_t)counted;
			for (const real_t coordinate : { center.x, center.z, center.w }) {
				const real_t rounded = Math::round(coordinate);
				CHECK(Math::abs(coordinate - rounded) < (real_t)1e-6);
				CHECK(Math::fmod(Math::abs(rounded), (real_t)2.0) == (real_t)1.0);
				CHECK(Math::abs(rounded) <= (real_t)5.0);
			}
		}
		// Every cell is textured, and every post with rib ends near it contains them: the 8 corners and 48 junctions.
		for (const Ref<SingleSurfaceMesh4D> &surface : surfaces) {
			Ref<ArrayPolyMesh4D> part = surface;
			const Vector<PackedInt32Array> texture_map = part->get_poly_cell_texture_map_indices();
			const int64_t cell_count = part->get_poly_cell_indices()[1].size();
			REQUIRE(texture_map.size() == cell_count);
			for (int64_t cell_index = 0; cell_index < cell_count; cell_index++) {
				CHECK(!texture_map[cell_index].is_empty());
			}
		}
		CHECK(check_posts_cover_rib_ends(posts, ribs, fence->get_post_thickness_meters(), 56) == 56);
	}

	memdelete(fence);
}

} // namespace TestFenceGuidePosts4D
