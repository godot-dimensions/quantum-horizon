extends Control
## Player's "radar orb" HUD: the flat slice_radar.gd readout with a real
## glass dome rendered over it, like a boat compass - the dome is genuine
## 3D content (SphereMesh + StandardMaterial3D under a Camera3D/light, all
## inside GlassViewport), not a 4D shape. That's a deliberate choice, not
## just a style pick: a plain MeshInstance3D placed directly in this
## scene's tree would never render at all, because the active Camera4D's
## Cross-section rendering mode swaps out the WHOLE viewport's World3D (see
## gun_core_rotator.gd's notes on the same engine behavior). A SubViewport
## with its own dedicated Camera3D/World3D is unaffected by that swap, so
## it's the only way to get real lighting, transparency, and a texture-
## mapped material here - not a workaround, just the correct tool.
##
## SliceRadar and GlassTextureRect are both full-rect children of this
## Control (see the scene), so they automatically share this node's own
## size/position - the glass dome always exactly overlaps the flat readout
## it's covering, with no separate projection math needed to keep them in
## sync (compare to the previous 4D-orb version, which had to bounce
## through Camera4D.world_to_viewport() every frame for this).
##
## Held down and to the left by default, raised toward a readable position
## while holding right-click (rotate_4d) - same button already used for
## the 4D slice-rotate look, so raising the orb doubles as "I'm actively
## re-orienting my slice, let me check the radar while I do it." Now a
## pure 2D screen-space animation, since this is a HUD element, not a
## world-space object (per the above, it never could be one here).

## Fraction of the viewport's WIDTH used for both dimensions of this
## (square) widget. Grows from lowered to raised along with the position -
## simulates an instrument being brought closer to the player's eyes, not
## just moved up.
@export var lowered_size_fraction: float = 0.2
@export var raised_size_fraction: float = 0.32

## Anchor point (fraction of viewport size) this widget's CENTER rests at
## by default, and where it's drawn toward while holding rotate_4d.
@export var lowered_anchor: Vector2 = Vector2(0.09, 0.92)
@export var raised_anchor: Vector2 = Vector2(0.16, 0.6)
@export var raise_speed: float = 8.0 # Higher = reaches the target pose faster.

var _current_anchor: Vector2 = lowered_anchor
var _current_size_fraction: float = lowered_size_fraction


func _process(delta: float) -> void:
	var held: bool = Input.is_action_pressed(&"rotate_4d")
	var target_anchor: Vector2 = raised_anchor if held else lowered_anchor
	var target_size_fraction: float = raised_size_fraction if held else lowered_size_fraction
	var lerp_weight: float = 1.0 - exp(-raise_speed * delta)
	_current_anchor = _current_anchor.lerp(target_anchor, lerp_weight)
	_current_size_fraction = lerpf(_current_size_fraction, target_size_fraction, lerp_weight)
	var viewport_size: Vector2 = get_viewport_rect().size
	var widget_size: Vector2 = Vector2.ONE * (viewport_size.x * _current_size_fraction)
	size = widget_size
	position = viewport_size * _current_anchor - widget_size * 0.5
