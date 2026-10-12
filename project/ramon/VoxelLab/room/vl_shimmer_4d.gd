extends Node4D

## The Voxel Lab's way through to another room: a hologram filling a doorway (Ramon, 8 Oct: "a sci-fi
## door that you can go through to teleport back ... this blue shimmer that you walk through"; 9 Oct:
## "the holo door looks bad, draw inspiration from the holo [shift] on the pedestals"). It is the
## pedestals' own hologram (the carried grid shader's hologram mode): an ordered dither, so you see the
## room beyond through it, densest at its foot and thinning upward, with bright bands drifting up it.
## A thin lit line down each side and across the top. No collision: you walk into it, and flash_out()
## washes the screen blue and hands over.
##
## The node stands on the floor in the middle of the doorway, the sheet across +X.
##
## NO class_name (engine_gotchas.md).

const Build := preload("res://ramon/VoxelLab/carried/scripts/chamber_build.gd")
const Mats := preload("res://ramon/VoxelLab/carried/LabKit/lab_materials.gd")
const LabGrid := preload("res://ramon/VoxelLab/carried/LabKit/lab_grid.gd")

@export var width: float = 3.2
@export var height: float = 4.1
@export var color: Color = Color(0.32, 0.66, 1.0)


func _ready() -> void:
	# Two sheets a hand apart, their dither shifted against each other, so the door has some depth.
	for i in 2:
		var sheet := MeshInstance4D.new()
		sheet.name = "Sheet%d" % i
		var size := Vector4(width - 0.08, height - 0.04, 0.03, Build.W_DEPTH)
		sheet.mesh = Mats.box_mesh(size)
		sheet.position = Vector4(0, height * 0.5, -0.06 + 0.12 * float(i), 0)
		var m: TetraMaterial4D = LabGrid.material("kit_code_blue", size, Vector4.ZERO)
		var cs: ShaderMaterial = m.get_cross_section_material_3d()
		cs.set_shader_parameter("holo_on", 1.0)
		cs.set_shader_parameter("holo_base", 0.92 if i == 0 else 0.7)
		cs.set_shader_parameter("holo_falloff", 0.7 if i == 0 else 1.1)
		cs.set_shader_parameter("holo_color", color if i == 0 else color.lightened(0.25))
		cs.set_shader_parameter("holo_glow", 0.9)
		cs.set_shader_parameter("holo_scan", 0.7)
		cs.set_shader_parameter("holo_scan_density", 1.4 + 0.5 * float(i))
		cs.set_shader_parameter("holo_scan_speed", 0.42 + 0.15 * float(i))
		cs.set_shader_parameter("holo_fine", 1.0)
		sheet.material_override = m
		add_child(sheet)
	var edge_col := Color(0.70, 0.88, 1.0)
	for side in [-1.0, 1.0]:
		var edge := MeshInstance4D.new()
		edge.name = "Edge"
		edge.mesh = Mats.box_mesh(Vector4(0.035, height, 0.06, Build.W_DEPTH))
		edge.position = Vector4(side * (width * 0.5 - 0.02), height * 0.5, 0, 0)
		edge.material_override = Mats.glow(edge_col, 1.4)
		add_child(edge)
	var top := MeshInstance4D.new()
	top.name = "Lintel"
	top.mesh = Mats.box_mesh(Vector4(width, 0.035, 0.06, Build.W_DEPTH))
	top.position = Vector4(0, height - 0.02, 0, 0)
	top.material_override = Mats.glow(edge_col, 1.4)
	add_child(top)


## Washes the screen in the door's blue, then calls `done` (the scene change).
func flash_out(host: Node, done: Callable) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	host.add_child(layer)
	var rect := ColorRect.new()
	rect.color = Color(color.lightened(0.35), 0.0)
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(rect)
	var tw: Tween = host.create_tween()
	tw.tween_property(rect, "color:a", 1.0, 0.45)
	tw.tween_callback(done)


## A wash coming back the other way, on arrival.
static func flash_in(host: Node, col: Color = Color(0.32, 0.66, 1.0)) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	host.add_child(layer)
	var rect := ColorRect.new()
	rect.color = Color(col.lightened(0.35), 1.0)
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(rect)
	var tw: Tween = host.create_tween()
	tw.tween_interval(0.15)
	tw.tween_property(rect, "color:a", 0.0, 0.6)
	tw.tween_callback(layer.queue_free)
