#pragma once
// This file should be included before any other files.

#ifndef GODOT_MODULE
#error "Must build as a Godot module."
#endif // GODOT_MODULE

#include "core/object/class_db.h"
#include "core/string/ustring.h"
#include "core/version.h"

#define GDEXTMOD_GUI_INPUT gui_input
#define GET_NODE_TYPE(m_parent, m_type, m_path) Object::cast_to<m_type>(m_parent->get_node(NodePath(m_path)))
#define MODULE_OVERRIDE override
#define MOUSE_BUTTON_LEFT MouseButton::LEFT

#ifndef GODOT_VERSION_MAJOR
// Prior to Godot 4.5, the Godot version macros were just "VERSION_*" which did not match the godot-cpp API.
// See https://github.com/godotengine/godot/pull/103557
#define GODOT_VERSION_MAJOR VERSION_MAJOR
#define GODOT_VERSION_MINOR VERSION_MINOR
#define GODOT_VERSION_PATCH VERSION_PATCH
#endif

#if GODOT_VERSION_MAJOR > 4 || (GODOT_VERSION_MAJOR == 4 && GODOT_VERSION_MINOR > 6)
// In Godot 4.7, callable_mp was moved to its own header.
#include "core/object/callable_mp.h"
#endif

#if GODOT_VERSION_MAJOR == 4 && GODOT_VERSION_MINOR < 7
// Prior to Godot 4.7, Input enums were located in the Input class,
// but in 4.7 they were moved to a separate InputClassEnums namespace.
#define InputClassEnums Input
#endif

#if GODOT_VERSION_MAJOR == 4 && GODOT_VERSION_MINOR < 6
// Prior to Godot 4.6, the internal API of free_rid in RenderingServer and other servers did not match the exposed API.
// See https://github.com/godotengine/godot/pull/107139
#define free_rid free

// Prior to Godot 4.6, the internal API of to_string did not match the exposed API of _to_string.
#define _to_string to_string
#endif

#if GODOT_VERSION_MAJOR == 4 && GODOT_VERSION_MINOR < 5
// In Godot 4.5 and later, namespaces were capitalized: core_bind -> CoreBind.
#define CoreBind core_bind

// Prior to Godot 4.5, the vector resize API did not clarify whether it was initializing new elements or not.
// See https://github.com/godotengine/godot/pull/104522
#define resize_initialized resize
#define resize_uninitialized resize

// As of Godot 4.5, we can use constexpr for vectors, but 4.4 and earlier don't support constexpr for vectors.
#define USE_CONST_NOT_CONSTEXPR_FOR_VECTORS 1
#endif

#if GODOT_VERSION_MAJOR > 4 || (GODOT_VERSION_MAJOR == 4 && GODOT_VERSION_MINOR > 4)
// In Godot 4.5 and later, Math_TAU was replaced with Math::TAU, and a few other things also moved to the Math namespace.
#define ABS Math::abs
#define Math_E Math::E
#define Math_PI Math::PI
#define Math_SQRT12 Math::SQRT12
#define Math_SQRT2 Math::SQRT2
#define Math_TAU Math::TAU
#endif

#if GODOT_VERSION_MAJOR > 4 || (GODOT_VERSION_MAJOR == 4 && GODOT_VERSION_MINOR >= 4)
#define GODOT_HAS_TYPED_DICTIONARY 1
#endif

#include <limits>

#ifndef Math_INF
#define Math_INF std::numeric_limits<double>::infinity()
#endif // Math_INF

#ifndef Math_NAN
#define Math_NAN std::numeric_limits<double>::quiet_NaN()
#endif // Math_INF

#ifndef REAL_T_IS_DOUBLE
#error "Quantum Horizon's Godot fork should be built with `precision=double`."
#endif // REAL_T_IS_DOUBLE

#if GODOT_VERSION_MAJOR < 4 || (GODOT_VERSION_MAJOR == 4 && GODOT_VERSION_MINOR < 5)
#error "The Quantum Horizon C++ module requires Godot 4.5 or later."
#endif
