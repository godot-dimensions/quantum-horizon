#pragma once

// The engine's test runner compiles module tests outside of the module's own build environment,
// which is where this define normally comes from, and the module's headers insist on it.
#define GODOT_MODULE 1

#include "model/fence/test_fence_generator_4d.h"
#include "model/fence/test_fence_guide_posts_4d.h"
