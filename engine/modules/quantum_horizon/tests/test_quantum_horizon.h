#pragma once

// The engine's test runner compiles module tests outside of the module's own build environment,
// which is where this define normally comes from, and the module's headers insist on it.
#define GODOT_MODULE 1
