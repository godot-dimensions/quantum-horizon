@tool
extends RefCounted

## Grid surfaces (shaders/lab_grid.gdshader): Unreal's prototype grid as the kit's own, in named
## SWATCHES whose colours can change while the scene runs.
##
## A swatch is a surface colour, a line colour (the metre lines), a subline colour (the 20 cm
## lines) and a grid strength (0 for a plain colour field). Every grid material is made for one
## swatch and remembered under it, so `set_swatch()` recolours every surface wearing it at once,
## in the editor as well as in play. lab_grid_palette_4d.gd is the inspector for it: put one in a
## scene, edit its colours, and the walls follow live.
##
## ONE MATERIAL PER BOX, not one per swatch: the shader has no world position (the 4D renderer
## hands it a camera-relative frame only), so each box carries where it stands (`grid_offset`)
## and boxes side by side continue one grid. A room of a few dozen boxes is a few dozen
## materials, which is nothing; the swatch registry is what keeps them in step.
##
##   var m := LabGrid.material("wall", size, box.global_position)
##   LabGrid.set_print(m, texture, Vector4(0, 0, 1, 0), Rect2(1, 1, 8, 4))   # paint on its +Z face
##   LabGrid.set_chevrons(m, 1.0)                                            # arrows along its -Z
##
## NO class_name (engine_gotchas.md): preload it.

const GridShader := preload("res://ramon/Arboretum/botany_lab/carried/LabKit/shaders/lab_grid.gdshader")

## The signal colours the lab's floors and doors use (Ramon's my-own-01 wayfinding sheet for the
## acid yellow, Unreal's intro level for the orange and the red).
const ACID := Color(0.878, 0.976, 0.341)
const ORANGE := Color(1.0, 0.47, 0.06)
const RED := Color(0.86, 0.12, 0.14)

## Swatches every scene starts from: [surface, line, subline, grid strength], sRGB.
const DEFAULTS := {
	"wall": [Color(0.80, 0.80, 0.78), Color(0.42, 0.42, 0.42), Color(0.67, 0.67, 0.66), 1.0],
	"floor": [Color(0.58, 0.59, 0.60), Color(0.30, 0.30, 0.31), Color(0.49, 0.49, 0.50), 1.0],
	"slate": [Color(0.17, 0.20, 0.27), Color(0.10, 0.12, 0.16), Color(0.14, 0.17, 0.23), 1.0],
	"build": [Color(0.09, 0.29, 0.62), Color(0.05, 0.19, 0.45), Color(0.08, 0.25, 0.55), 0.55],
	"motion": [Color(0.70, 0.13, 0.41), Color(0.50, 0.07, 0.28), Color(0.62, 0.11, 0.36), 0.55],
	"door": [Color(1.0, 0.47, 0.06), Color(0.72, 0.29, 0.02), Color(0.90, 0.40, 0.05), 0.6],
	"open": [Color(0.878, 0.976, 0.341), Color(0.60, 0.70, 0.16), Color(0.78, 0.88, 0.28), 0.6],
	"drum": [Color(0.16, 0.18, 0.22), Color(0.08, 0.09, 0.11), Color(0.13, 0.15, 0.18), 0.8],
}

static var _values: Dictionary = {}     # swatch -> [surface, line, subline, strength]
static var _users: Dictionary = {}      # swatch -> Array of WeakRef(ShaderMaterial)


## The colours a swatch has now.
static func values(swatch: String) -> Array:
	if _values.has(swatch):
		return _values[swatch]
	if DEFAULTS.has(swatch):
		return DEFAULTS[swatch]
	return DEFAULTS["wall"]


## A grid material in `swatch` for a box of `size` whose centre stands at `origin` in the world.
static func material(swatch: String, size: Vector4, origin: Vector4) -> TetraMaterial4D:
	var m := TetraMaterial4D.new()
	var cs: ShaderMaterial = m.get_cross_section_material_3d()
	# The shader before anything else: Material4D only fills an empty slot with its own.
	cs.shader = GridShader
	m.albedo_color = Color.WHITE
	cs.set_shader_parameter("surface_size", size)
	cs.set_shader_parameter("grid_offset", origin)
	_apply(cs, values(swatch))
	if not _users.has(swatch):
		_users[swatch] = []
	(_users[swatch] as Array).append(weakref(cs))
	m.set_meta("lab_swatch", swatch)
	return m


## Recolours every surface in `swatch`, now and from here on.
static func set_swatch(swatch: String, surface: Color, line: Color, subline: Color, strength: float = 1.0) -> void:
	var v: Array = [surface, line, subline, strength]
	_values[swatch] = v
	if not _users.has(swatch):
		return
	var alive: Array = []
	for ref in _users[swatch]:
		var cs: ShaderMaterial = (ref as WeakRef).get_ref()
		if cs != null:
			_apply(cs, v)
			alive.append(ref)
	_users[swatch] = alive


## Moves a material to another swatch (a door turning from locked to open).
static func reswatch(m: TetraMaterial4D, swatch: String) -> void:
	var cs: ShaderMaterial = m.get_cross_section_material_3d()
	var old: String = String(m.get_meta("lab_swatch", ""))
	if _users.has(old):
		var kept: Array = []
		for ref in _users[old]:
			if (ref as WeakRef).get_ref() != cs:
				kept.append(ref)
		_users[old] = kept
	if not _users.has(swatch):
		_users[swatch] = []
	(_users[swatch] as Array).append(weakref(cs))
	m.set_meta("lab_swatch", swatch)
	_apply(cs, values(swatch))


## Paints `texture` on the face of the box whose outward normal (in the box's own space) is
## `normal`, over `rect` in metres from that face's lower-left corner as a reader sees it. On a
## floor (normal +Y) the rect is measured along +X and towards -Z.
static func set_print(m: TetraMaterial4D, texture: Texture2D, normal: Vector4, rect: Rect2, tint: Color = Color.WHITE, glow: float = 0.35) -> void:
	var cs: ShaderMaterial = m.get_cross_section_material_3d()
	cs.set_shader_parameter("print_texture", texture)
	cs.set_shader_parameter("print_normal", normal)
	cs.set_shader_parameter("print_rect", Vector4(rect.position.x, rect.position.y, rect.size.x, rect.size.y))
	cs.set_shader_parameter("print_tint", tint)
	cs.set_shader_parameter("print_glow", glow)
	cs.set_shader_parameter("print_on", 1.0 if texture != null else 0.0)


## Wraps `texture` round a cylinder's side (the material must be on a cylinder centred on its own
## origin): between angles `a0`..`a1` (radians from +Z towards +X) and heights `y0`..`y1` in the
## mesh's own space.
static func set_print_cylinder(m: TetraMaterial4D, texture: Texture2D, a0: float, a1: float, y0: float, y1: float, tint: Color = Color.WHITE, glow: float = 0.3) -> void:
	var cs: ShaderMaterial = m.get_cross_section_material_3d()
	cs.set_shader_parameter("print_texture", texture)
	cs.set_shader_parameter("print_cyl", 1.0)
	cs.set_shader_parameter("print_cylinder", Vector4(a0, a1, y0, y1))
	cs.set_shader_parameter("print_tint", tint)
	cs.set_shader_parameter("print_glow", glow)
	cs.set_shader_parameter("print_on", 1.0 if texture != null else 0.0)


## Paints a slowly turning ring into a floor material round world `centre` (x, z), `radius` out;
## `speed` in radians a second. `on` 0 hides it.
static func set_ring(m: TetraMaterial4D, centre: Vector2, radius: float, on: float = 1.0, color: Color = Color(0.12, 0.45, 1.0), speed: float = 0.08) -> void:
	var cs: ShaderMaterial = m.get_cross_section_material_3d()
	cs.set_shader_parameter("ring_at", Vector4(centre.x, centre.y, radius, speed))
	cs.set_shader_parameter("ring_color", color)
	cs.set_shader_parameter("ring_on", clampf(on, 0.0, 1.0) if radius > 0.0 else 0.0)


## How strongly the print shows (0 hides it, so a sign can fade in).
static func set_print_strength(m: TetraMaterial4D, k: float) -> void:
	m.get_cross_section_material_3d().set_shader_parameter("print_on", clampf(k, 0.0, 1.0))


## Chevrons marching along `direction` (x and z of the box, one of the four axis directions) on
## its top face; `on` from 0 (none) to 1. `phase` shifts the pattern by metres, so strips laid end
## to end can continue one stream of arrows.
static func set_chevrons(m: TetraMaterial4D, on: float, color: Color = ACID, speed: float = 1.2, spacing: float = 1.1, phase: float = 0.0, direction: Vector2 = Vector2(0.0, -1.0)) -> void:
	var cs: ShaderMaterial = m.get_cross_section_material_3d()
	cs.set_shader_parameter("chevron_dir", direction)
	cs.set_shader_parameter("chevron_on", clampf(on, 0.0, 1.0))
	cs.set_shader_parameter("chevron_color", color)
	cs.set_shader_parameter("chevron_speed", speed)
	cs.set_shader_parameter("chevron_spacing", spacing)
	cs.set_shader_parameter("chevron_phase", phase)


## Paints a route into a floor material: `points` in world x/z, up to nine, the arrows running
## from the first towards the last. `on` 0 hides it.
static func set_route(m: TetraMaterial4D, points: PackedVector2Array, on: float = 1.0, color: Color = Color(0.12, 0.45, 1.0)) -> void:
	var cs: ShaderMaterial = m.get_cross_section_material_3d()
	var segs: Array = []
	var starts: Array = []
	var run: float = 0.0
	for i in range(mini(points.size() - 1, 8)):
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		segs.append(Vector4(a.x, a.y, b.x, b.y))
		starts.append(run)
		run += a.distance_to(b)
	while segs.size() < 8:
		segs.append(Vector4.ZERO)
		starts.append(0.0)
	cs.set_shader_parameter("route_seg", segs)
	cs.set_shader_parameter("route_start", PackedFloat32Array(starts))
	cs.set_shader_parameter("route_count", mini(points.size() - 1, 8))
	cs.set_shader_parameter("route_color", color)
	cs.set_shader_parameter("route_on", clampf(on, 0.0, 1.0) if points.size() > 1 else 0.0)


static func _apply(cs: ShaderMaterial, v: Array) -> void:
	cs.set_shader_parameter("surface_color", v[0])
	cs.set_shader_parameter("line_color", v[1])
	cs.set_shader_parameter("subline_color", v[2])
	cs.set_shader_parameter("grid_strength", float(v[3]))
