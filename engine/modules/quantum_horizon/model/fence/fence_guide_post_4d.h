#pragma once

#include "../../quantum_horizon_defines.h"

#include "modules/4d/model/mesh/mesh_instance_4d.h"

class FenceGuidePost4D : public MeshInstance4D {
	GDCLASS(FenceGuidePost4D, MeshInstance4D);

	bool _is_degenerate = false; // Set by the parent generator when it builds, see `set_is_degenerate`.

protected:
	static void _bind_methods();
	void _notification(int p_what);
	void _validate_property(PropertyInfo &p_property) const;

public:
	// Whether this post adds no corner to the fence. The corners are projected onto a sphere around the origin before
	// their hull is taken, so every post is a corner except a degenerate one: at the origin, whose direction is zero,
	// or in the same direction from the origin as an earlier post. Such a post has no effect on the fence, which it
	// reports as a configuration warning. Not exposed, since the generator owns it.
	void set_is_degenerate(const bool p_is_degenerate) { _is_degenerate = p_is_degenerate; }
	virtual PackedStringArray get_configuration_warnings() const override;

	FenceGuidePost4D();
};
