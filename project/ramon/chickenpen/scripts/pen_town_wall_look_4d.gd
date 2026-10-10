extends Node

## THE TOWN WALL'S STONE (10 Oct 2026, Ramon's walkthrough item 29: "add a subtle stone-wall texture or surface
## variation appropriate to a medieval stone structure ... If a full texture treatment isn't practical, then simply add
## a gentle color gradient: slightly darker near the bottom, slightly lighter toward the top").
##
## The wall is Andrew's FenceGenerator4D (World/TownWall, from wall_with_gate.obj), its three materials plain colours.
## The generator gives every part an upright texture map, each connected part filling the unit cube of texture space
## with its proportions kept, and the texture is clamped, not repeated. So the wall itself (one part, about 120 m long
## and 4.5 m high) uses only the bottom few hundredths of the texture's height (measured 10 Oct: a test texture, red at
## the bottom, turned the whole wall red), and a post (tall and thin) uses all of it. Each gets its own small texture
## made here: the wall's has the gradient (darker at the foot) and a few courses of joints packed into that band, the
## posts' a plain gradient up their height; the ribs keep their own colour. Each keeps its old grey as the tint.
##
## Art only: the dev look lays its own flat colour over the wall as before. Nothing is saved: it is set when the pen
## loads. NO class_name (engine_gotchas.md).

@export var wall_path: NodePath = ^"../../World/TownWall"
## How much of the texture's height the wall's own height takes (its height over its length).
@export_range(0.005, 0.2, 0.001) var wall_v_share: float = 0.0375
## Courses of stone up the wall.
@export_range(1, 12, 1) var courses: int = 5
## Darker at the foot than the top (texture values, 1 the material's own colour).
@export var foot: float = 0.74
@export var crown: float = 1.0
@export_range(0.0, 0.6, 0.01) var joint_dark: float = 0.22


func _ready() -> void:
	var wall: Node = get_node_or_null(wall_path)
	if wall == null:
		return
	# Tetrahedra out, not the default poly cells: the 3D texture is read per tetrahedron's texture coordinates.
	if int(wall.get("output_mesh_type")) != 2:
		wall.set("output_mesh_type", 2)
	var textures: Dictionary = {"beam_material": _gradient(wall_v_share, courses, 1024), "post_material": _gradient(1.0, 0, 128)}
	for prop in textures:
		var old := wall.get(prop) as TetraMaterial4D
		if old == null:
			continue
		var m := TetraMaterial4D.new()
		m.albedo_source = TetraMaterial4D.TETRA_COLOR_SOURCE_TEXTURE3D_CELL_UVW_ONLY
		m.albedo_texture_3d = textures[prop]
		m.albedo_color = old.albedo_color.lightened(0.06)
		wall.set(prop, m)
	# The generator rebuilds itself on a material change when it updates automatically; otherwise ask it now.
	if not bool(wall.get("update_automatically")) and wall.has_method("update_fence_mesh_now"):
		wall.call("update_fence_mesh_now")


## A texture whose shade runs from [param foot] at v 0 to [param crown] at v [param v_top] (and stays there), with
## [param n_courses] darker joint lines in that band; [param rows] rows up, 2 wide, 2 deep.
func _gradient(v_top: float, n_courses: int, rows: int) -> ImageTexture3D:
	var layers: Array[Image] = []
	for z in 2:
		var img: Image = Image.create_empty(2, rows, false, Image.FORMAT_RGBA8)
		for y in rows:
			var v: float = (float(y) + 0.5) / float(rows)
			var up: float = clampf(v / v_top, 0.0, 1.0)
			var shade: float = lerpf(foot, crown, smoothstep(0.0, 1.0, up))
			if n_courses > 0 and up < 1.0 and _near_line(up * float(n_courses)):
				shade *= 1.0 - joint_dark
			for x in 2:
				img.set_pixel(x, y, Color(shade, shade, shade * 0.98, 1.0))
		layers.append(img)
	var tex := ImageTexture3D.new()
	tex.create(Image.FORMAT_RGBA8, 2, rows, 2, false, layers)
	return tex


## Within a joint's width of a whole number (a block edge).
static func _near_line(t: float) -> bool:
	var f: float = t - floor(t)
	return f < 0.06 or f > 0.94
