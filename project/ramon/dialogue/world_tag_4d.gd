extends Control
class_name WorldTag4D

## A short label pinned over something in the 4D world. The "Press F to talk" over the
## keeper's head, and the one-line things he says as you walk past.
##
## SHORT TEXT ONLY, ON PURPOSE. The conversation itself lives in a fixed screen panel, and
## the split is the whole design. A world-anchored box holding four wrapped reply lines has
## to survive an orbiting camera, a slice rotation, the coop in front of it, the screen
## edge, and the speaker leaving your slice entirely - five separate fights. A tag that is
## two words survives all of them because it is small enough to simply clamp and fade.
##
## IT IS A CONTROL, NOT A BILLBOARD MESH. Projecting the anchor's position to the viewport
## and drawing flat text there means the label never tips, never shears under a 4D
## rotation, and stays at a readable pixel size at any distance - none of which is true of
## geometry standing in the world. The cost is that it draws over everything, so it is
## faded out rather than occluded when the speaker is far or off-slice.

@export var camera_path: NodePath
## What to hover over - usually a Node4D at head height on the character.
@export var anchor_path: NodePath

@export_group("Behaviour")
## Pixels above the projected anchor point.
@export_range(-200.0, 200.0, 1.0) var lift: float = 0.0
## Sideways offset, for when a character has more than one prompt over him and they should
## sit beside each other rather than stack. The tag is centred on its anchor, so equal and
## opposite nudges put two of them either side of the head.
@export_range(-300.0, 300.0, 1.0) var nudge_x: float = 0.0
## Beyond this, the tag fades out. Stops distant chatter cluttering the screen.
@export_range(1.0, 60.0, 0.5) var fade_from: float = 9.0
@export_range(1.0, 80.0, 0.5) var fade_to: float = 14.0
## And how far through W the speaker can drift before he stops being addressable. Generous,
## because a tag that blinks out mid-step reads as a bug rather than as a rule.
@export_range(0.5, 12.0, 0.5) var w_range: float = 3.0
## Keep it on screen when the anchor goes past the edge, so a speaker just out of frame
## still shows you he is there.
@export var clamp_to_screen: bool = true
@export_range(0.0, 200.0, 1.0) var screen_margin: float = 28.0

@export_group("Look")
@export var text_color: Color = Color(1.0, 0.95, 0.74)
@export var panel_color: Color = Color(0.08, 0.10, 0.13, 0.78)
@export_range(10, 40, 1) var text_size: int = 20
@export_file("*.ttf") var font_path: String = "res://ramon/Demo/fonts/Montserrat/static/Montserrat-SemiBold.ttf"

var _camera: Camera4D
var _anchor: Node4D
var _panel: PanelContainer
var _label: Label
var _text: String = ""
var _fade: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	_camera = get_node_or_null(camera_path) as Camera4D
	_anchor = get_node_or_null(anchor_path) as Node4D
	if _camera == null or _anchor == null:
		push_warning("WorldTag4D: camera or anchor missing - the tag will never appear (fail visibly).")
	_build()
	modulate.a = 0.0


func show_text(text: String) -> void:
	_text = text
	_label.text = text


func clear() -> void:
	_text = ""


func _process(delta: float) -> void:
	var want: float = 0.0
	if _text != "" and _camera != null and _anchor != null:
		want = _place()
	_fade = move_toward(_fade, want, delta / 0.18)
	modulate.a = _fade
	visible = _fade > 0.002


## Returns the opacity the tag should be at, and moves it there. Zero means "not shown",
## which covers behind the camera, too far, and off-slice alike.
func _place() -> float:
	var here: Vector4 = _anchor.global_position
	var eye: Vector4 = _camera.global_position
	var gap: Vector4 = here - eye

	# Behind the camera projects to nonsense, so reject it before asking.
	var forward: Vector4 = -_camera.global_basis.z
	if forward.dot(gap) <= 0.05:
		return 0.0

	# Off the current slice. Checked against the camera rather than the player because it
	# is the camera's slice that decides what is on screen at all - and ALONG the camera's
	# own slice normal, not along w: with the slice turned a quarter through W, as it is
	# walking the way to the dreamer, w is a direction you are looking down, and a creature
	# twenty metres ahead of you counted as twenty metres off the slice (Ramon, 29 Sept: "I
	# don't see the F with talk"). On the flat slice the normal is w and nothing changes.
	var normal: Vector4 = _camera.global_basis.w.normalized()
	var off: float = gap.dot(normal)
	if absf(off) > w_range:
		return 0.0

	# Track the panel's own size each frame: the text changes, and the tag has to stay
	# centred over the head rather than anchored by its left edge.
	size = _panel.get_combined_minimum_size()
	_panel.size = size

	var screen: Vector2 = get_viewport_rect().size
	# world_to_viewport answers in window pixels; this control lives in canvas units, which
	# differ when the window's content is scaled (pen_ui_scale_4d.gd).
	var point: Vector2 = _camera.world_to_viewport(here) * screen / Vector2(get_viewport().get_size())
	var want: Vector2 = point - Vector2(size.x * 0.5 - nudge_x, size.y + lift)
	if clamp_to_screen:
		want.x = clampf(want.x, screen_margin, screen.x - size.x - screen_margin)
		want.y = clampf(want.y, screen_margin, screen.y - size.y - screen_margin)
	position = want

	var flat: float = (gap - normal * off).length()
	return 1.0 - clampf((flat - fade_from) / maxf(fade_to - fade_from, 0.001), 0.0, 1.0)


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.name = "Tag"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = panel_color
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 5.0
	style.content_margin_bottom = 5.0
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	_label = Label.new()
	_label.add_theme_font_size_override("font_size", text_size)
	_label.add_theme_color_override("font_color", text_color)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Static face: Montserrat's variable wght axis is inert in this build and its default
	# instance is Thin. See the note in dialogue_box_4d.gd.
	if font_path != "" and ResourceLoader.exists(font_path):
		var font: Font = load(font_path) as Font
		if font != null:
			_label.add_theme_font_override("font", font)
	_panel.add_child(_label)

	_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
