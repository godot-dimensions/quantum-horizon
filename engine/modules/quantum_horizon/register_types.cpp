#include "register_types.h"

#include "example_node.h"

#include "core/config/engine.h"
#include "core/core_bind.h"

inline void add_godot_singleton(const StringName &p_singleton_name, Object *p_object) {
	CoreBind::Engine::get_singleton()->register_singleton(p_singleton_name, p_object);
}

inline void remove_godot_singleton(const StringName &p_singleton_name) {
	CoreBind::Engine::get_singleton()->unregister_singleton(p_singleton_name);
}

void initialize_quantum_horizon_module(ModuleInitializationLevel p_level) {
	// Note: Classes MUST be registered in inheritance order.
	if (p_level == MODULE_INITIALIZATION_LEVEL_SCENE) {
		// Register node classes here.
		// You can add singletons using add_godot_singleton().
		GDREGISTER_CLASS(ExampleNode);
	}
}

void uninitialize_quantum_horizon_module(ModuleInitializationLevel p_level) {
	if (p_level == MODULE_INITIALIZATION_LEVEL_SCENE) {
		// Perform cleanup here.
		// You can remove singletons using remove_godot_singleton().
	}
}
