extends MeshInstance4D
## Rotating 4D "core" of the player's gun viewmodel: a 600-cell (600
## tetrahedral cells - rich enough topology to show interesting cross-
## section changes on its own, at a normal uniform scale, no artificial
## stretching needed), rendered as genuine wireframe, with continuous
## isoclinic rotation: equal-angle rotation in two completely orthogonal
## planes at once (xw and yz here - they share no common axis, which is
## what makes a compound rotation "isoclinic" rather than a "simple"
## rotation that leaves one whole plane fixed; the other two valid
## disjoint pairs would be xy/zw or xz/yw).
##
## Wireframe, not solid, and rendered through the SAME Cross-section camera
## as everything else - not a separate Wireframe Canvas viewport. Confirmed
## directly in the engine source: Mesh4D::get_cross_section_mesh() calls a
## per-subclass virtual (_update_cross_section_mesh) to build the actual
## ArrayMesh each frame - TetraMesh4D builds PRIMITIVE_TRIANGLES (solid),
## WireMesh4D builds PRIMITIVE_LINES (true wireframe), and WireMaterial4D
## has its own dedicated cross-section shader specifically for this. So a
## mesh converted to a WireMesh4D renders as real wireframe lines within
## Cross-section itself - no per-camera engine swap, no secondary viewport
## needed for just this one object.
##
## Specifically NOT xy/zw: whichever spatial axis gets paired with w in the
## rotation periodically inherits w's own extent during the spin (w isn't
## rendered directly, so mixing it into a spatial axis is the only way its
## rotation becomes visible at all). zw would mix w into z - the same axis
## Barrel/Stock are arranged along - which is what caused the earlier
## solid-mesh version to clip straight through them. xw instead mixes w
## into x, where there's open space to the sides of the viewmodel. yz is
## the harmless remainder: y and z are both small, comparable spatial
## extents, so mixing them is just an ordinary contained roll. This
## reasoning still applies even without the exaggerated w-stretch this
## script used to have - it's not just about how far things swing, it's
## about which axis they swing into.
##
## rotate_rotor() is "same as operator* but as a function" (confirmed
## directly in rotor_4d.cpp - Rotor4D's *= isn't exposed to GDScript at
## all). Order doesn't matter here specifically because xw and yz share no
## axis and therefore commute; this wouldn't generally hold for two
## rotations that share an axis.
##
## Speeds up briefly on fire (call pulse()) then eases back down to
## base_speed - an exponential decay of the speed multiplier back toward
## 1.0, not an instant snap.

@export var base_speed: float = 1.5 # Radians per second, in each of the xw/yz planes.
@export var pulse_speed_multiplier: float = 6.0
@export var pulse_decay_rate: float = 4.0 # Higher = settles back to base_speed faster.

var _speed_multiplier: float = 1.0


func _ready() -> void:
	# The scene assigns the solid 600-cell mesh directly (so it's a normal,
	# inspectable Mesh4D resource reference in the .tscn) - converted to a
	# wire mesh once here, rather than needing a second wire-specific
	# resource authored by hand.
	mesh = mesh.to_wire_mesh()


func _process(delta: float) -> void:
	_speed_multiplier = 1.0 + (_speed_multiplier - 1.0) * exp(-pulse_decay_rate * delta)
	var angle: float = base_speed * _speed_multiplier * delta
	rotate_rotor_local(Rotor4D.from_xw(angle).rotate_rotor(Rotor4D.from_yz(angle)))


func pulse() -> void:
	_speed_multiplier = pulse_speed_multiplier
