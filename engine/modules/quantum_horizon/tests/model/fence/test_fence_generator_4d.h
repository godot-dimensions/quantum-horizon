#pragma once

#include "../../../model/fence/fence_generator_4d.h"
#include "../../../model/fence/fence_guide_post_4d.h"

#include "core/object/class_db.h"
#include "core/object/message_queue.h"
#include "core/os/os.h"
#include "scene/main/window.h"
#include "scene/resources/mesh.h"
#include "scene/resources/packed_scene.h"
#include "tests/test_macros.h"

#include "modules/4d/model/mesh/multi_surface_mesh_4d.h"
#include "modules/4d/model/mesh/poly/poly_material_4d.h"

namespace TestFenceGenerator4D {

static int64_t count_volumes(const Ref<ArrayPolyMesh4D> &p_mesh) {
	const Vector<Vector<PackedInt32Array>> indices = p_mesh->get_poly_cell_indices();
	return indices.size() > 2 ? indices[2].size() : 0;
}

// A seed with one square face on the ground, 4 m on a side and centered on the origin, with the given per-face normals
// bound to it, or none. Double-sided adds the same square with its loop reversed, a sheet whose two faces fold back
// onto each other along every edge.
static Ref<ArrayPolyMesh4D> make_square_seed(const Vector<PackedVector4Array> &p_face_normals, const bool p_double_sided) {
	Ref<ArrayPolyMesh4D> seed;
	seed.instantiate();
	seed->set_poly_cell_vertex_positions(PackedVector4Array{ Vector4(-2, 0, -2, 0), Vector4(2, 0, -2, 0), Vector4(2, 0, 2, 0), Vector4(-2, 0, 2, 0) });
	seed->set_edge_vertex_indices(PackedInt32Array{ 0, 1, 1, 2, 2, 3, 0, 3 });
	Vector<PackedInt32Array> faces = { PackedInt32Array{ 0, 1, 2, 3 } };
	if (p_double_sided) {
		faces.push_back(PackedInt32Array{ 3, 2, 1, 0 });
	}
	seed->set_poly_cell_indices(Vector<Vector<PackedInt32Array>>{ faces });
	if (!p_face_normals.is_empty()) {
		seed->set_poly_cell_dense_normals(PolyMesh4D::PER_FACE_KEY, p_face_normals);
	}
	return seed;
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

// A fence that builds only on request, with distinct materials so that its posts, ribs, and beams stay separate surfaces.
static FenceGenerator4D *make_manual_fence() {
	FenceGenerator4D *fence = memnew(FenceGenerator4D);
	fence->set_update_automatically(false);
	Ref<PolyMaterial4D> post_material;
	post_material.instantiate();
	Ref<PolyMaterial4D> rib_material;
	rib_material.instantiate();
	Ref<PolyMaterial4D> beam_material;
	beam_material.instantiate();
	fence->set_post_material(post_material);
	fence->set_rib_material(rib_material);
	fence->set_beam_material(beam_material);
	return fence;
}

// The vertex positions of a part, sorted, so that parts built in a different vertex order still compare equal.
static PackedVector4Array sorted_positions(const Ref<SingleSurfaceMesh4D> &p_part) {
	const Ref<ArrayPolyMesh4D> part = p_part;
	REQUIRE(part.is_valid());
	PackedVector4Array positions = part->get_poly_cell_vertex_positions();
	positions.sort();
	return positions;
}

static bool positions_match(const PackedVector4Array &p_a, const PackedVector4Array &p_b) {
	if (p_a.size() != p_b.size()) {
		return false;
	}
	for (int64_t i = 0; i < p_a.size(); i++) {
		if (!p_a[i].is_equal_approx(p_b[i])) {
			return false;
		}
	}
	return true;
}

// Laying a fence out one corner at a time passes through states with no footprint, which are warnings, not errors.
TEST_CASE("[FenceGenerator4D] Incomplete sources leave the fence empty with a warning") {
	FenceGenerator4D *fence = make_manual_fence();
	fence->set_input_shape_type(FenceGenerator4D::INPUT_SHAPE_RADIAL_POINTS);

	SUBCASE("Corners in one plane do not span a volume") {
		fence->set_fence_corners(PackedVector4Array{ Vector4(-5, 0, -5, 0), Vector4(5, 0, -5, 0), Vector4(5, 0, 5, 0), Vector4(-5, 0, 5, 0) });
		fence->update_fence_mesh_now();
		CHECK(fence->get_mesh().is_null());
		CHECK(fence->get_configuration_warnings().size() == 1);
		// Spread out into a volume, the same corners make a fence and the warning goes away.
		PackedVector4Array corners;
		for (const real_t w : { -5.0, 5.0 }) {
			for (const real_t z : { -5.0, 5.0 }) {
				for (const real_t x : { -5.0, 5.0 }) {
					corners.push_back(Vector4(x, 0, z, w));
				}
			}
		}
		fence->set_fence_corners(corners);
		fence->update_fence_mesh_now();
		CHECK(fence->get_mesh().is_valid());
		CHECK(fence->get_configuration_warnings().is_empty());
		// Scripts asking for the seed directly still get told why there is none.
		fence->set_fence_corners(PackedVector4Array{ Vector4(-5, 0, -5, 0), Vector4(5, 0, -5, 0), Vector4(5, 0, 5, 0), Vector4(-5, 0, 5, 0) });
		ERR_PRINT_OFF;
		CHECK(fence->build_seed_mesh_from_corners().is_null());
		ERR_PRINT_ON;
	}

	SUBCASE("Corners all to one side of the origin do not surround it") {
		// A 10 m box far away: a valid shape, but not around this node's origin, so the radial footprint would fold. The
		// farther away, the more the hull of the corners' directions degenerates into slivers, which the check must see through.
		PackedVector4Array corners;
		for (const real_t distance : { 1000.0, 10000.0, 100000.0 }) {
			CAPTURE(distance);
			corners.clear();
			for (const real_t w : { -5.0, 5.0 }) {
				for (const real_t z : { -5.0, 5.0 }) {
					for (const real_t x : { -5.0, 5.0 }) {
						corners.push_back(Vector4(x + distance, 0, z + distance, w + distance));
					}
				}
			}
			fence->set_fence_corners(corners);
			fence->update_fence_mesh_now();
			CHECK(fence->get_mesh().is_null());
			CHECK(fence->get_configuration_warnings().size() == 1);
			ERR_PRINT_OFF;
			CHECK(fence->build_seed_mesh_from_corners().is_null());
			ERR_PRINT_ON;
		}
		// The same box around the origin is a footprint.
		for (int64_t i = 0; i < corners.size(); i++) {
			corners.set(i, corners[i] - Vector4(100000, 0, 100000, 100000));
		}
		fence->set_fence_corners(corners);
		fence->update_fence_mesh_now();
		CHECK(fence->get_mesh().is_valid());
		CHECK(fence->get_configuration_warnings().is_empty());
	}

	SUBCASE("A mesh shape without its mesh") {
		fence->set_input_shape_type(FenceGenerator4D::INPUT_SHAPE_SEED_MESH_3D);
		fence->update_fence_mesh_now();
		CHECK(fence->get_mesh().is_null());
		CHECK(fence->get_configuration_warnings().size() == 1);
		fence->set_input_shape_type(FenceGenerator4D::INPUT_SHAPE_SEED_MESH_4D);
		fence->update_fence_mesh_now();
		CHECK(fence->get_mesh().is_null());
		CHECK(fence->get_configuration_warnings().size() == 1);
		fence->set_seed_mesh_4d(make_square_seed(Vector<PackedVector4Array>(), false));
		fence->update_fence_mesh_now();
		CHECK(fence->get_mesh().is_valid());
		CHECK(fence->get_configuration_warnings().is_empty());
	}

	memdelete(fence);
}

// A sheet whose two faces fold back onto each other has normals that cancel on every shared edge. The rib's cross-section
// does not depend on the sign of the normal, so those edges get ribs like any other.
TEST_CASE("[FenceGenerator4D] Edges whose faces fold back onto each other get ribs") {
	FenceGenerator4D *fence = make_manual_fence();
	fence->set_desired_spacing_meters(0.0);
	fence->set_beam_count(0);
	fence->set_input_shape_type(FenceGenerator4D::INPUT_SHAPE_SEED_MESH_4D);
	fence->set_seed_mesh_4d(make_square_seed(Vector<PackedVector4Array>{ PackedVector4Array{ Vector4(0, 0, 0, 1), Vector4(0, 0, 0, -1) } }, true));
	fence->update_fence_mesh_now();
	Ref<MultiSurfaceMesh4D> mesh = fence->get_mesh();
	REQUIRE(mesh.is_valid());
	const Vector<Ref<SingleSurfaceMesh4D>> surfaces = mesh->get_surface_meshes();
	REQUIRE(surfaces.size() == 2);
	CHECK(count_volumes(surfaces[0]) == 4);
	CHECK(count_volumes(surfaces[1]) == 4);
	memdelete(fence);
}

// The fence takes the ribs' and filler's directions from the seed's per-face normals, which a user's seed may store at
// any length, tilted out of the ground, or as zero for a face without one.
TEST_CASE("[FenceGenerator4D] Seed face normals are used as unit vectors in the ground hyperplane") {
	FenceGenerator4D *fence = make_manual_fence();
	fence->set_desired_spacing_meters(0.0);
	fence->set_beam_count(0);
	fence->set_input_shape_type(FenceGenerator4D::INPUT_SHAPE_SEED_MESH_4D);
	fence->set_seed_mesh_4d(make_square_seed(Vector<PackedVector4Array>{ PackedVector4Array{ Vector4(0, 0, 0, 1) } }, false));
	fence->update_fence_mesh_now();
	Ref<MultiSurfaceMesh4D> reference_mesh = fence->get_mesh();
	REQUIRE(reference_mesh.is_valid());
	const PackedVector4Array reference_posts = sorted_positions(reference_mesh->get_surface_meshes()[0]);
	const PackedVector4Array reference_ribs = sorted_positions(reference_mesh->get_surface_meshes()[1]);
	REQUIRE(reference_ribs.size() == 4 * 16);

	SUBCASE("A long, tilted normal gives the same fence as the unit normal") {
		fence->set_seed_mesh_4d(make_square_seed(Vector<PackedVector4Array>{ PackedVector4Array{ Vector4(0, 1.5, 0, 2) } }, false));
		fence->update_fence_mesh_now();
		Ref<MultiSurfaceMesh4D> mesh = fence->get_mesh();
		REQUIRE(mesh.is_valid());
		CHECK(positions_match(sorted_positions(mesh->get_surface_meshes()[0]), reference_posts));
		CHECK(positions_match(sorted_positions(mesh->get_surface_meshes()[1]), reference_ribs));
	}

	SUBCASE("A zero normal in a complete binding is computed like a missing one") {
		fence->set_seed_mesh_4d(make_square_seed(Vector<PackedVector4Array>{ PackedVector4Array{ Vector4() } }, false));
		fence->update_fence_mesh_now();
		Ref<MultiSurfaceMesh4D> mesh = fence->get_mesh();
		REQUIRE(mesh.is_valid());
		CHECK(positions_match(sorted_positions(mesh->get_surface_meshes()[0]), reference_posts));
		CHECK(positions_match(sorted_positions(mesh->get_surface_meshes()[1]), reference_ribs));
	}

	memdelete(fence);
}

// The hull is computed on the corners' directions and its vertex positions are quantized, so each hull vertex is matched
// back to the nearest corner, which must give every corner its exact position, whatever the distances from the origin.
TEST_CASE("[FenceGenerator4D] Hull vertices take the exact positions of their corners") {
	FenceGenerator4D *fence = make_manual_fence();
	fence->set_input_shape_type(FenceGenerator4D::INPUT_SHAPE_RADIAL_POINTS);
	// A box footprint with every corner pushed out by a different amount, still star-shaped around the origin.
	PackedVector4Array corners;
	real_t stretch = 1.0;
	for (const real_t w : { -5.0, 5.0 }) {
		for (const real_t z : { -5.0, 5.0 }) {
			for (const real_t x : { -5.0, 5.0 }) {
				corners.push_back(Vector4(x, 0, z, w) * stretch);
				stretch += 0.137;
			}
		}
	}
	fence->set_fence_corners(corners);
	const Ref<ArrayPolyMesh4D> seed = fence->build_seed_mesh_from_corners();
	REQUIRE(seed.is_valid());
	PackedVector4Array seed_positions = seed->get_poly_cell_vertex_positions();
	seed_positions.sort();
	corners.sort();
	CHECK(seed_positions == corners);
	memdelete(fence);
}

// A seed may carry vertices that no edge uses, such as loose vertices of a 3D mesh, which have nothing for a post to stand between.
TEST_CASE("[FenceGenerator4D] A seed vertex without edges gets no post") {
	FenceGenerator4D *fence = make_manual_fence();
	fence->set_desired_spacing_meters(0.0);
	fence->set_beam_count(0);
	Ref<ArrayPolyMesh4D> seed = make_square_seed(Vector<PackedVector4Array>(), false);
	PackedVector4Array positions = seed->get_poly_cell_vertex_positions();
	positions.push_back(Vector4(8, 0, 8, 0)); // Used by no edge.
	seed->set_poly_cell_vertex_positions(positions);
	fence->set_input_shape_type(FenceGenerator4D::INPUT_SHAPE_SEED_MESH_4D);
	fence->set_seed_mesh_4d(seed);
	fence->update_fence_mesh_now();
	Ref<MultiSurfaceMesh4D> mesh = fence->get_mesh();
	REQUIRE(mesh.is_valid());
	CHECK(count_volumes(mesh->get_surface_meshes()[0]) == 4);
	CHECK(count_volumes(mesh->get_surface_meshes()[1]) == 4);
	memdelete(fence);
}

// Whether every cell of a part fits in one 3D hyperplane, which a 3D cell must for its cross-sections to be flat.
static bool cells_are_flat(const Ref<SingleSurfaceMesh4D> &p_part) {
	const Ref<ArrayPolyMesh4D> part = p_part;
	REQUIRE(part.is_valid());
	const PackedVector4Array positions = part->get_poly_cell_vertex_positions();
	for (const PackedInt32Array &vertices : part->get_all_poly_cell_vertex_indices(3, false)) {
		real_t scale = 0.0;
		for (const int32_t vertex_index : vertices) {
			scale = MAX(scale, (positions[vertex_index] - positions[vertices[0]]).length());
		}
		Vector<Vector4> basis;
		for (const int32_t vertex_index : vertices) {
			Vector4 rejection = positions[vertex_index] - positions[vertices[0]];
			for (const Vector4 &direction : basis) {
				rejection -= direction * direction.dot(rejection);
			}
			if (rejection.length() > scale * (real_t)1e-6) {
				if (basis.size() == 3) {
					return false;
				}
				basis.push_back(rejection.normalized());
			}
		}
	}
	return true;
}

// Checks that every vertex of a part is at one of the given heights above the ground, which is the Y of the nearest
// corner on the ground hyperplane, so the corners must be far apart compared to the parts' thickness.
static void check_heights_above_ground(const Ref<SingleSurfaceMesh4D> &p_part, const PackedVector4Array &p_corners, const Vector<real_t> &p_heights) {
	const Ref<ArrayPolyMesh4D> part = p_part;
	REQUIRE(part.is_valid());
	for (const Vector4 &position : part->get_poly_cell_vertex_positions()) {
		real_t ground = 0.0;
		real_t nearest_distance_squared = Math::INF;
		for (const Vector4 &corner : p_corners) {
			const Vector4 offset = corner - position;
			const real_t distance_squared = offset.x * offset.x + offset.z * offset.z + offset.w * offset.w;
			if (distance_squared < nearest_distance_squared) {
				nearest_distance_squared = distance_squared;
				ground = corner.y;
			}
		}
		bool at_a_height = false;
		for (const real_t height : p_heights) {
			if (Math::is_equal_approx(position.y - ground, height)) {
				at_a_height = true;
			}
		}
		CHECK_MESSAGE(at_a_height, vformat("The vertex at %s is %f above its ground, which is not a part height.", position, position.y - ground));
	}
}

// The Y of a corner is the height of the ground at its post, so a fence on uneven ground follows it: posts stand at their
// vertex's height, and ribs and beams run between the heights of their vertices.
TEST_CASE("[FenceGenerator4D] Corners at different heights make a fence that follows the ground") {
	FenceGenerator4D *fence = make_manual_fence();
	fence->set_desired_spacing_meters(0.0);
	fence->set_input_shape_type(FenceGenerator4D::INPUT_SHAPE_RADIAL_POINTS);
	// A 10 m box with one corner raised by 1 m. The hull is taken on the corners' directions, where every box face is
	// flat, so the three faces at the raised corner come out warped, and each is split along its level diagonal into
	// a flat triangle and a leaning one, with a rib along the diagonal, since a beam has to be flat.
	PackedVector4Array corners;
	for (const real_t w : { -5.0, 5.0 }) {
		for (const real_t z : { -5.0, 5.0 }) {
			for (const real_t x : { -5.0, 5.0 }) {
				corners.push_back(Vector4(x, 0, z, w));
			}
		}
	}
	corners.set(7, Vector4(5, 1, 5, 5));
	fence->set_fence_corners(corners);
	fence->update_fence_mesh_now();
	Ref<MultiSurfaceMesh4D> mesh = fence->get_mesh();
	REQUIRE(mesh.is_valid());
	CHECK(fence->get_configuration_warnings().is_empty());
	const Vector<Ref<SingleSurfaceMesh4D>> surfaces = mesh->get_surface_meshes();
	REQUIRE(surfaces.size() == 3);
	CHECK(count_volumes(surfaces[0]) == 8);
	CHECK_MESSAGE(count_volumes(surfaces[1]) == 15, "The 12 box edges and the level diagonal of each of the 3 split faces.");
	CHECK_MESSAGE(count_volumes(surfaces[2]) == 3 * 9, "3 beams on each of the 3 flat quads and 6 triangles.");
	CHECK(cells_are_flat(surfaces[0]));
	CHECK(cells_are_flat(surfaces[1]));
	CHECK_MESSAGE(cells_are_flat(surfaces[2]), "A beam cell that fits no hyperplane renders as a blob.");
	const real_t post_height = fence->get_post_height_meters();
	const real_t rib_height = post_height * fence->get_rib_height_ratio();
	check_heights_above_ground(surfaces[0], corners, { 0.0, post_height });
	check_heights_above_ground(surfaces[1], corners, { 0.0, rib_height });
	// Each beam fills the top part of its slot, and the slots stack from the ground up to the beams' maximum height.
	const real_t slot_height = rib_height * fence->get_beam_max_height_ratio() / fence->get_beam_count();
	Vector<real_t> beam_heights;
	for (int32_t beam = 1; beam <= fence->get_beam_count(); beam++) {
		beam_heights.push_back(slot_height * beam);
		beam_heights.push_back(slot_height * (beam - fence->get_beam_coverage()));
	}
	check_heights_above_ground(surfaces[2], corners, beam_heights);
	// With filler, posts and ribs also stand across the faces. Under a split face the ground is the flat triangle at
	// the ground and the leaning triangle rising to the corner, which agree along the diagonal, and the faces agree
	// along their shared edges. The filler's chords lie on the triangles, so the posts where they cross stand on the
	// ground too, rather than at the height of a flat frame through the whole face.
	fence->set_desired_spacing_meters(2.0);
	fence->update_fence_mesh_now();
	mesh = fence->get_mesh();
	REQUIRE(mesh.is_valid());
	const Vector<Ref<SingleSurfaceMesh4D>> filled_surfaces = mesh->get_surface_meshes();
	REQUIRE(filled_surfaces.size() == 3);
	CHECK(count_volumes(filled_surfaces[0]) > 8);
	auto check_heights_above_split_ground = [&](const Ref<SingleSurfaceMesh4D> &p_part, const Vector<real_t> &p_heights) {
		const Ref<ArrayPolyMesh4D> part = p_part;
		REQUIRE(part.is_valid());
		for (const Vector4 &position : part->get_poly_cell_vertex_positions()) {
			real_t ground = 0.0;
			if (Math::abs(position.x - (real_t)5.0) < (real_t)0.5) {
				ground = MAX(ground, (position.z + position.w) / (real_t)10.0);
			}
			if (Math::abs(position.z - (real_t)5.0) < (real_t)0.5) {
				ground = MAX(ground, (position.x + position.w) / (real_t)10.0);
			}
			if (Math::abs(position.w - (real_t)5.0) < (real_t)0.5) {
				ground = MAX(ground, (position.x + position.z) / (real_t)10.0);
			}
			bool at_a_height = false;
			for (const real_t height : p_heights) {
				if (Math::abs(position.y - ground - height) < (real_t)0.05) {
					at_a_height = true;
				}
			}
			CHECK_MESSAGE(at_a_height, vformat("The vertex at %s is %f above the split ground, which is not a part height.", position, position.y - ground));
		}
	};
	check_heights_above_split_ground(filled_surfaces[0], { 0.0, post_height });
	check_heights_above_split_ground(filled_surfaces[1], { 0.0, rib_height });
	check_heights_above_split_ground(filled_surfaces[2], beam_heights);
	CHECK(cells_are_flat(filled_surfaces[0]));
	CHECK(cells_are_flat(filled_surfaces[1]));
	CHECK(cells_are_flat(filled_surfaces[2]));
	memdelete(fence);
}

// A corner raised by a hair warps its faces by less than `make_coplanar` splits at, so they stay whole and lean, and
// the beams must still thicken. Solidifying used to measure the flatness of the beam's cell differently from how the
// split measures the face's, so a face just inside the one tolerance could fall just outside the other: this box built
// with the corner next to the raised one pushed out to Z = 7.72 m and lost its beams at 7.73 m.
TEST_CASE("[FenceGenerator4D] Faces warped by less than the split tolerance keep their beams") {
	FenceGenerator4D *fence = make_manual_fence();
	fence->set_desired_spacing_meters(0.0);
	fence->set_input_shape_type(FenceGenerator4D::INPUT_SHAPE_RADIAL_POINTS);
	PackedVector4Array corners;
	for (const real_t w : { -5.0, 5.0 }) {
		for (const real_t z : { -5.0, 5.0 }) {
			for (const real_t x : { -5.0, 5.0 }) {
				corners.push_back(Vector4(x, 0, z, w));
			}
		}
	}
	corners.set(7, Vector4(5, 0.01112489516261701, 5, 5)); // As a gizmo drag leaves it.
	corners.set(6, Vector4(-5, 0, 7.73, 5));
	fence->set_fence_corners(corners);
	fence->update_fence_mesh_now();
	Ref<MultiSurfaceMesh4D> mesh = fence->get_mesh();
	REQUIRE(mesh.is_valid());
	CHECK(fence->get_configuration_warnings().is_empty());
	const Vector<Ref<SingleSurfaceMesh4D>> surfaces = mesh->get_surface_meshes();
	REQUIRE(surfaces.size() == 3);
	CHECK_MESSAGE(count_volumes(surfaces[2]) == 3 * 7, "3 beams on each of the 5 quads, two of them leaning, and the 2 triangles at the pushed corner.");
	memdelete(fence);
}

// The filler lays its chords out in the frame of each face, which must follow a leaning face so that the posts at the
// chord crossings stand on the face rather than at the height of its center.
TEST_CASE("[FenceGenerator4D] Filler parts stand on a leaning face") {
	FenceGenerator4D *fence = make_manual_fence();
	fence->set_desired_spacing_meters(1.0);
	fence->set_input_shape_type(FenceGenerator4D::INPUT_SHAPE_SEED_MESH_4D);
	// A 4 m by 3 m face rising 1 m across its short side, so that its longest edges lie flat and the lean is across them.
	Ref<ArrayPolyMesh4D> seed;
	seed.instantiate();
	seed->set_poly_cell_vertex_positions(PackedVector4Array{ Vector4(-2, 0, -1.5, 0), Vector4(2, 0, -1.5, 0), Vector4(2, 1, 1.5, 0), Vector4(-2, 1, 1.5, 0) });
	seed->set_edge_vertex_indices(PackedInt32Array{ 0, 1, 1, 2, 2, 3, 0, 3 });
	seed->set_poly_cell_indices(Vector<Vector<PackedInt32Array>>{ { PackedInt32Array{ 0, 1, 2, 3 } } });
	fence->set_seed_mesh_4d(seed);
	fence->update_fence_mesh_now();
	Ref<MultiSurfaceMesh4D> mesh = fence->get_mesh();
	REQUIRE(mesh.is_valid());
	CHECK(fence->get_configuration_warnings().is_empty());
	const Vector<Ref<SingleSurfaceMesh4D>> surfaces = mesh->get_surface_meshes();
	REQUIRE(surfaces.size() == 3);
	// The long edges are divided in 4 and the leaning ones in 3, so 3 chords run up the lean and 2 run across it.
	CHECK_MESSAGE(count_volumes(surfaces[0]) == 4 + 2 * 3 + 2 * 2 + 3 * 2, "Corner posts, posts at the division points, and posts at the chord crossings.");
	CHECK(count_volumes(surfaces[1]) == 4 + 3 + 2);
	CHECK(count_volumes(surfaces[2]) == 3);
	// Every vertex of a part is at one of the given heights above the face, which rises by 1 m over 3 m along Z. A
	// part's vertices are offset from its center by less than a post thickness, over which the face rises by far less
	// than the gaps between the heights.
	auto check_heights_above_face = [&](const Ref<SingleSurfaceMesh4D> &p_part, const Vector<real_t> &p_heights) {
		const Ref<ArrayPolyMesh4D> part = p_part;
		REQUIRE(part.is_valid());
		for (const Vector4 &position : part->get_poly_cell_vertex_positions()) {
			const real_t above_face = position.y - (position.z + (real_t)1.5) / (real_t)3.0;
			bool at_a_height = false;
			for (const real_t height : p_heights) {
				if (Math::abs(above_face - height) < (real_t)0.05) {
					at_a_height = true;
				}
			}
			CHECK_MESSAGE(at_a_height, vformat("The vertex at %s is %f above the face, which is not a part height.", position, above_face));
		}
	};
	const real_t post_height = fence->get_post_height_meters();
	const real_t rib_height = post_height * fence->get_rib_height_ratio();
	check_heights_above_face(surfaces[0], { 0.0, post_height });
	check_heights_above_face(surfaces[1], { 0.0, rib_height });
	const real_t slot_height = rib_height * fence->get_beam_max_height_ratio() / fence->get_beam_count();
	Vector<real_t> beam_heights;
	for (int32_t beam = 1; beam <= fence->get_beam_count(); beam++) {
		beam_heights.push_back(slot_height * beam);
		beam_heights.push_back(slot_height * (beam - fence->get_beam_coverage()));
	}
	check_heights_above_face(surfaces[2], beam_heights);
	CHECK(cells_are_flat(surfaces[0]));
	CHECK(cells_are_flat(surfaces[1]));
	CHECK(cells_are_flat(surfaces[2]));
	memdelete(fence);
}

// A user's 4D seed must have flat faces, since a beam is flat, so a warped face is split in place into flat faces,
// which get beams, with a rib along the new edge.
TEST_CASE("[FenceGenerator4D] A warped face of a 4D seed is split into flat faces") {
	FenceGenerator4D *fence = make_manual_fence();
	fence->set_desired_spacing_meters(0.0);
	fence->set_input_shape_type(FenceGenerator4D::INPUT_SHAPE_SEED_MESH_4D);
	Ref<ArrayPolyMesh4D> seed;
	seed.instantiate();
	seed->set_poly_cell_vertex_positions(PackedVector4Array{ Vector4(-2, 0, -2, 0), Vector4(2, 0, -2, 0), Vector4(2, 1, 2, 0), Vector4(-2, 0, 2, 0) });
	seed->set_edge_vertex_indices(PackedInt32Array{ 0, 1, 1, 2, 2, 3, 0, 3 });
	seed->set_poly_cell_indices(Vector<Vector<PackedInt32Array>>{ { PackedInt32Array{ 0, 1, 2, 3 } } });
	fence->set_seed_mesh_4d(seed);
	fence->update_fence_mesh_now();
	Ref<MultiSurfaceMesh4D> mesh = fence->get_mesh();
	REQUIRE(mesh.is_valid());
	CHECK(fence->get_configuration_warnings().is_empty());
	CHECK_MESSAGE(seed->get_poly_cell_indices()[0].size() == 2, "The seed itself is split, along the level diagonal.");
	CHECK(seed->get_edge_indices().size() == 5 * 2);
	const Vector<Ref<SingleSurfaceMesh4D>> surfaces = mesh->get_surface_meshes();
	REQUIRE(surfaces.size() == 3);
	CHECK(count_volumes(surfaces[0]) == 4);
	CHECK_MESSAGE(count_volumes(surfaces[1]) == 5, "The four edges and the diagonal.");
	CHECK(count_volumes(surfaces[2]) == 2 * 3);
	CHECK(cells_are_flat(surfaces[0]));
	CHECK(cells_are_flat(surfaces[1]));
	CHECK(cells_are_flat(surfaces[2]));
	memdelete(fence);
}

TEST_CASE("[FenceGenerator4D] The beam thickness ratio is capped like the other ratios") {
	FenceGenerator4D *fence = memnew(FenceGenerator4D);
	ERR_PRINT_OFF;
	fence->set_beam_thickness_ratio(1.5);
	ERR_PRINT_ON;
	CHECK(fence->get_beam_thickness_ratio() == 0.5);
	fence->set_beam_thickness_ratio(1.0);
	CHECK(fence->get_beam_thickness_ratio() == 1.0);
	memdelete(fence);
}

TEST_CASE("[FenceGenerator4D] Surfaces are posts, ribs, and then beams, which are optional") {
	FenceGenerator4D *fence = make_manual_fence();
	fence->update_fence_mesh_now();
	Ref<MultiSurfaceMesh4D> mesh = fence->get_mesh();
	REQUIRE(mesh.is_valid());
	Vector<Ref<SingleSurfaceMesh4D>> surfaces = mesh->get_surface_meshes();
	REQUIRE(surfaces.size() == 3);
	CHECK(surfaces[0]->get_material() == fence->get_post_material());
	CHECK(surfaces[1]->get_material() == fence->get_rib_material());
	CHECK(surfaces[2]->get_material() == fence->get_beam_material());
	fence->set_beam_count(0);
	fence->update_fence_mesh_now();
	mesh = fence->get_mesh();
	REQUIRE(mesh.is_valid());
	surfaces = mesh->get_surface_meshes();
	REQUIRE(surfaces.size() == 2);
	CHECK(surfaces[0]->get_material() == fence->get_post_material());
	CHECK(surfaces[1]->get_material() == fence->get_rib_material());
	memdelete(fence);
}

// Whether a packed scene stores a property of its root node.
static bool packed_root_stores(Node *p_root, const StringName &p_property) {
	Ref<PackedScene> packed;
	packed.instantiate();
	REQUIRE(packed->pack(p_root) == OK);
	const Ref<SceneState> state = packed->get_state();
	for (int property_index = 0; property_index < state->get_node_property_count(0); property_index++) {
		if (state->get_node_property_name(0, property_index) == p_property) {
			return true;
		}
	}
	return false;
}

// With automatic updates the mesh is rebuilt when the scene loads, so saving it would only bloat the scene file.
TEST_CASE("[FenceGenerator4D] The generated mesh is saved only while updates are manual") {
	FenceGenerator4D *fence = memnew(FenceGenerator4D);
	fence->set_box_size(Vector3(12, 10, 10)); // Not the default, so that it is stored and shows the check works.
	fence->update_fence_mesh_now();
	REQUIRE(fence->get_mesh().is_valid());
	CHECK_FALSE(packed_root_stores(fence, "mesh"));
	CHECK(packed_root_stores(fence, "box_size"));
	fence->set_update_automatically(false);
	CHECK(packed_root_stores(fence, "mesh"));
	// The corners are derived in every shape but the radial points, so they are saved only as a backup: with manual
	// updates, or when the shape's source is missing.
	CHECK(packed_root_stores(fence, "fence_corners"));
	fence->set_update_automatically(true);
	CHECK_FALSE(packed_root_stores(fence, "fence_corners"));
	// The seed the box derived stays as the 4D shape's seed until replaced, so the backup case needs the seed taken away.
	fence->set_input_shape_type(FenceGenerator4D::INPUT_SHAPE_SEED_MESH_4D);
	fence->set_seed_mesh_4d(Ref<PolyMesh4D>());
	CHECK(packed_root_stores(fence, "fence_corners"));
	fence->set_seed_mesh_4d(make_square_seed(Vector<PackedVector4Array>(), false));
	CHECK_FALSE(packed_root_stores(fence, "fence_corners"));
	fence->set_input_shape_type(FenceGenerator4D::INPUT_SHAPE_RADIAL_POINTS);
	CHECK(packed_root_stores(fence, "fence_corners"));
	memdelete(fence);
}

// The box and guide post shapes overwrite the corners, and the derived shapes overwrite the seed mesh, so the inspector's
// undo of a shape change has to restore those along with the shape.
TEST_CASE("[FenceGenerator4D] Undoing a shape change restores the data it overwrites") {
	List<StringName> linked;
	ClassDB::get_linked_properties_info("FenceGenerator4D", "input_shape_type", &linked);
	CHECK(linked.find("fence_corners") != nullptr);
	CHECK(linked.find("seed_mesh_4d") != nullptr);
}

// A point is inside the fence when its projection onto the ground lies within the footprint, at any height. The test
// follows the seed as last built: the footprint's own shape rather than a box around it, and nothing without a
// footprint.
TEST_CASE("[FenceGenerator4D] Points inside the fence are those within the footprint, at any height") {
	FenceGenerator4D *fence = make_manual_fence();
	fence->set_desired_spacing_meters(0.0);
	CHECK_MESSAGE(!fence->is_local_point_inside(Vector4()), "Nothing is inside before the first build.");

	SUBCASE("The box, in local and in global coordinates") {
		fence->update_fence_mesh_now();
		CHECK(fence->is_local_point_inside(Vector4()));
		CHECK(fence->is_local_point_inside(Vector4(4.9, 0, -4.9, 4.9)));
		CHECK_MESSAGE(fence->is_local_point_inside(Vector4(0, 100, 0, 0)), "Height does not matter.");
		CHECK(fence->is_local_point_inside(Vector4(0, -3, 0, 0)));
		CHECK_FALSE(fence->is_local_point_inside(Vector4(5.1, 0, 0, 0)));
		CHECK_FALSE(fence->is_local_point_inside(Vector4(0, 0, 0, -5.1)));
		// A global point goes through the node's transform: a long thin box moved away and given a quarter turn in XZ,
		// so that its long axis lies along global Z.
		fence->set_box_size(Vector3(10, 2, 2));
		fence->update_fence_mesh_now();
		fence->set_position(Vector4(100, 0, 0, 0));
		fence->set_basis(Basis4D::from_zx(Math_TAU / 4.0));
		CHECK(fence->is_global_point_inside(Vector4(100, 0, 0, 0)));
		CHECK(fence->is_global_point_inside(Vector4(100, 5, 4, 0)));
		CHECK_FALSE(fence->is_global_point_inside(Vector4(104, 0, 0, 0)));
		CHECK_FALSE(fence->is_global_point_inside(Vector4()));
		CHECK_MESSAGE(fence->is_local_point_inside(Vector4(4, 0, 0, 0)), "Local coordinates do not see the node's transform.");
	}

	SUBCASE("A footprint that is not convex") {
		// A box with one corner pulled in toward the origin, which dents the three faces around it inward.
		fence->set_input_shape_type(FenceGenerator4D::INPUT_SHAPE_RADIAL_POINTS);
		PackedVector4Array corners;
		for (const real_t w : { -5.0, 5.0 }) {
			for (const real_t z : { -5.0, 5.0 }) {
				for (const real_t x : { -5.0, 5.0 }) {
					corners.push_back(Vector4(x, 0, z, w));
				}
			}
		}
		corners.set(7, Vector4(2, 0, 2, 2));
		fence->set_fence_corners(corners);
		fence->update_fence_mesh_now();
		REQUIRE(fence->get_mesh().is_valid());
		CHECK(fence->is_local_point_inside(Vector4(1, 0, 1, 1)));
		CHECK(fence->is_local_point_inside(Vector4(-4, 0, -4, -4)));
		CHECK_MESSAGE(fence->is_local_point_inside(Vector4(4, 0, -4, -4)), "Away from the dent the box is whole.");
		CHECK_MESSAGE(!fence->is_local_point_inside(Vector4(3.5, 0, 3.5, 3.5)), "In the dent: inside the box, outside the footprint.");
		CHECK_FALSE(fence->is_local_point_inside(Vector4(6, 0, 0, 0)));
	}

	SUBCASE("Nothing is inside without a footprint") {
		fence->set_input_shape_type(FenceGenerator4D::INPUT_SHAPE_SEED_MESH_4D);
		fence->set_seed_mesh_4d(make_square_seed(Vector<PackedVector4Array>(), false));
		fence->update_fence_mesh_now();
		REQUIRE(fence->get_mesh().is_valid());
		CHECK_MESSAGE(!fence->is_local_point_inside(Vector4(0, 0.5, 0, 0)), "A single sheet does not close, so it encloses nothing.");
		// Corners that do not span a volume leave the fence without a footprint, after a box that had one.
		fence->set_input_shape_type(FenceGenerator4D::INPUT_SHAPE_BOX);
		fence->update_fence_mesh_now();
		REQUIRE(fence->is_local_point_inside(Vector4()));
		fence->set_input_shape_type(FenceGenerator4D::INPUT_SHAPE_RADIAL_POINTS);
		fence->set_fence_corners(PackedVector4Array{ Vector4(-5, 0, -5, 0), Vector4(5, 0, -5, 0), Vector4(5, 0, 5, 0) });
		fence->update_fence_mesh_now();
		CHECK(fence->get_mesh().is_null());
		CHECK_FALSE(fence->is_local_point_inside(Vector4()));
	}

	memdelete(fence);
}

// Leaving a seed mesh shape for a corner shape hands the seed's vertices over as the corners, so that the shape the fence
// had can be edited as points or posts without editing the seed mesh. They are written when the fence is built from the
// seed, and again when the shape changes with updates off, from the seed as last built.
TEST_CASE("[SceneTree][FenceGenerator4D] Switching from a seed mesh to corners continues from the seed") {
	FenceGenerator4D *fence = make_manual_fence();
	SceneTree::get_singleton()->get_root()->add_child(fence);
	// Stale corners, as a scene saved in another shape would carry.
	fence->set_fence_corners(PackedVector4Array{ Vector4(1, 0, 0, 0), Vector4(0, 0, 1, 0), Vector4(0, 0, 0, 1), Vector4(-1, 0, -1, -1) });
	const Ref<ArrayPolyMesh4D> seed = make_square_seed(Vector<PackedVector4Array>(), false);
	const PackedVector4Array seed_vertices = seed->get_poly_cell_vertex_positions();
	fence->set_input_shape_type(FenceGenerator4D::INPUT_SHAPE_SEED_MESH_4D);
	fence->set_seed_mesh_4d(seed);

	SUBCASE("Built from the seed, the corners follow it") {
		fence->update_fence_mesh_now();
		CHECK(fence->get_fence_corners() == seed_vertices);
		fence->set_input_shape_type(FenceGenerator4D::INPUT_SHAPE_RADIAL_POINTS);
		CHECK(fence->get_fence_corners() == seed_vertices);
	}

	SUBCASE("Switched to guide posts before any build, the posts stand on the seed's vertices") {
		fence->set_input_shape_type(FenceGenerator4D::INPUT_SHAPE_RADIAL_POST_NODES);
		CHECK(fence->get_fence_corners() == seed_vertices);
		PackedVector4Array post_positions;
		for (int child_index = 0; child_index < fence->get_child_count(); child_index++) {
			const FenceGuidePost4D *post = Object::cast_to<FenceGuidePost4D>(fence->get_child(child_index));
			if (post != nullptr) {
				post_positions.push_back(post->get_position());
			}
		}
		CHECK(post_positions == seed_vertices);
	}

	memdelete(fence);
}

// Exported 3D meshes can carry zero-area triangles, which have no normal to build a beam along. The derived seed drops
// them, with the edges only they used, rather than failing the whole fence. The rendering server that building a 3D
// mesh needs is only there in scene tree tests.
TEST_CASE("[SceneTree][FenceGenerator4D] Zero-area triangles of a 3D seed are dropped") {
	FenceGenerator4D *fence = make_manual_fence();
	fence->set_desired_spacing_meters(0.0);
	// A square, and a triangle of three collinear vertices off to the side.
	Array arrays;
	arrays.resize(Mesh::ARRAY_MAX);
	arrays[Mesh::ARRAY_VERTEX] = PackedVector3Array{ Vector3(0, 0, 0), Vector3(4, 0, 0), Vector3(4, 0, 4), Vector3(0, 0, 4), Vector3(6, 0, 0), Vector3(7, 0, 0), Vector3(8, 0, 0) };
	arrays[Mesh::ARRAY_INDEX] = PackedInt32Array{ 0, 1, 2, 0, 2, 3, 4, 5, 6 };
	Ref<ArrayMesh> mesh_3d;
	mesh_3d.instantiate();
	mesh_3d->add_surface_from_arrays(Mesh::PRIMITIVE_TRIANGLES, arrays);
	fence->set_input_shape_type(FenceGenerator4D::INPUT_SHAPE_SEED_MESH_3D);
	fence->set_seed_mesh_3d(mesh_3d);
	fence->update_fence_mesh_now();
	Ref<MultiSurfaceMesh4D> mesh = fence->get_mesh();
	REQUIRE(mesh.is_valid());
	const Ref<ArrayPolyMesh4D> seed = fence->get_seed_mesh_4d();
	REQUIRE(seed.is_valid());
	CHECK(seed->get_poly_cell_indices()[0].size() == 1);
	CHECK(seed->get_edge_indices().size() == 4 * 2);
	CHECK(count_volumes(mesh->get_surface_meshes()[0]) == 4);
	CHECK(count_volumes(mesh->get_surface_meshes()[1]) == 4);
	memdelete(fence);
}

// Automatic updates build on a worker thread, see `queue_update_fence_mesh`: the mesh arrives with the message queue
// flush after the build, a request made during a build is honored by one more build with the inputs as they are then,
// and a synchronous update outranks a running one, whose older result is dropped. The SceneTree tag provides the
// message queue that delivers the results, like the one a running game has.
static int fence_updated_count = 0;
static void count_fence_updated() {
	fence_updated_count++;
}

TEST_CASE("[SceneTree][FenceGenerator4D] Queued updates build in the background") {
	FenceGenerator4D *fence = make_manual_fence();
	fence->set_desired_spacing_meters(0.0);
	fence_updated_count = 0;
	fence->connect("fence_mesh_updated", callable_mp_static(&count_fence_updated));
	fence->queue_update_fence_mesh();
	CHECK_MESSAGE(fence->is_updating(), "The build counts as running until the message queue delivers its result.");
	CHECK(fence->get_mesh().is_null());
	settle_fence(fence);
	CHECK_FALSE(fence->is_updating());
	REQUIRE(fence->get_mesh().is_valid());
	CHECK(fence_updated_count == 1);
	CHECK(Ref<MultiSurfaceMesh4D>(fence->get_mesh())->get_surface_meshes().size() == 3);
	// A request during a build runs once more afterwards, with the inputs as they are then.
	fence->queue_update_fence_mesh();
	fence->set_beam_count(0);
	fence->queue_update_fence_mesh();
	settle_fence(fence);
	CHECK(fence_updated_count == 3);
	CHECK(Ref<MultiSurfaceMesh4D>(fence->get_mesh())->get_surface_meshes().size() == 2);
	// A synchronous update outranks a running one, whose older result is dropped when it arrives.
	fence->set_beam_count(3);
	fence->queue_update_fence_mesh();
	fence->set_beam_count(0);
	fence->update_fence_mesh_now();
	CHECK(fence_updated_count == 4);
	CHECK(Ref<MultiSurfaceMesh4D>(fence->get_mesh())->get_surface_meshes().size() == 2);
	settle_fence(fence);
	CHECK_MESSAGE(fence_updated_count == 4, "The stale result is dropped without a signal.");
	CHECK(Ref<MultiSurfaceMesh4D>(fence->get_mesh())->get_surface_meshes().size() == 2);
	memdelete(fence);
}

} // namespace TestFenceGenerator4D
