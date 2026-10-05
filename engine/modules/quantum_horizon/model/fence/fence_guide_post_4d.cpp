#include "fence_guide_post_4d.h"

#include "fence_generator_4d.h"

FenceGuidePost4D::FenceGuidePost4D() {
	// The fence is rebuilt when a guide post moves, so the post has to hear about its own transform changes.
	set_should_notify_local_transform(true);
}

void FenceGuidePost4D::_notification(int p_what) {
	switch (p_what) {
		case NOTIFICATION_LOCAL_TRANSFORM_CHANGED: {
			// A guide post marks a point: the generator builds its post mesh standing upright at that point, so a rotation
			// or scale could only misplace the mesh. Setting the basis back sends this notification again, and that pass
			// finds the identity and goes on to tell the generator.
			if (!get_basis().is_equal_approx(Basis4D())) {
				set_basis(Basis4D());
				break;
			}
			FenceGenerator4D *generator = Object::cast_to<FenceGenerator4D>(get_parent());
			if (generator != nullptr) {
				generator->notify_guide_post_changed();
			}
			update_configuration_warnings();
		} break;
	}
}

// The parent rebuilds this post's mesh along with the fence, so the mesh is saved only when the fence keeps its own,
// see `FenceGenerator4D::_validate_property`.
void FenceGuidePost4D::_validate_property(PropertyInfo &p_property) const {
	if (p_property.name == StringName("mesh")) {
		const FenceGenerator4D *generator = Object::cast_to<FenceGenerator4D>(get_parent());
		const bool update_automatically = generator != nullptr && generator->get_update_automatically();
		p_property.usage = update_automatically ? PROPERTY_USAGE_EDITOR : PROPERTY_USAGE_DEFAULT;
	}
}

PackedStringArray FenceGuidePost4D::get_configuration_warnings() const {
	PackedStringArray warnings = MeshInstance4D::get_configuration_warnings();
	const FenceGenerator4D *generator = Object::cast_to<FenceGenerator4D>(get_parent());
	if (generator == nullptr) {
		warnings.push_back(RTR("FenceGuidePost4D only works as a direct child of a FenceGenerator4D node."));
		return warnings;
	}
	if (generator->get_input_shape_type() != FenceGenerator4D::INPUT_SHAPE_RADIAL_POST_NODES) {
		warnings.push_back(RTR("The parent FenceGenerator4D only uses its guide posts when its input shape type is Radial Posts."));
	}
	// The corner is the position, so two guide posts at the same position are one corner, and the first one is the one
	// that gets the post mesh. Only earlier siblings are checked, so that exactly one of the two carries the warning.
	bool has_earlier_twin = false;
	const int child_count = generator->get_child_count();
	for (int child_index = 0; child_index < child_count; child_index++) {
		const FenceGuidePost4D *sibling = Object::cast_to<FenceGuidePost4D>(generator->get_child(child_index));
		if (sibling == this) {
			break;
		}
		if (sibling != nullptr && sibling->get_position().is_equal_approx(get_position())) {
			has_earlier_twin = true;
			break;
		}
	}
	if (has_earlier_twin) {
		warnings.push_back(RTR("Another guide post before this one is at the same position, so this one has no effect on the fence."));
	} else if (_is_degenerate) {
		// Set by the generator on its last build, see `FenceGenerator4D::_build_fence_posts_from_seed_vertices`.
		warnings.push_back(RTR("This guide post is degenerate and adds no corner to the fence: it is at the fence's origin, where a newly added guide post starts, or in the same direction from the origin as an earlier guide post."));
	}
	return warnings;
}

void FenceGuidePost4D::_bind_methods() {
}
