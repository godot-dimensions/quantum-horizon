@tool
extends Node4D

## THE KATA CACHE (discovery, 9 Oct 2026; follow_up/pen_discovery_plan.md, easter egg 1): a small cave in the
## quietest corner of the valley (the north-east meadow, measured as the place furthest from everything), whose way
## in is not in the farm's slice. Ramon's brief: "a second cave toward the upper-right area of the map ... smaller
## and simpler. Inside, place a treasure chest containing 10 Azoth. When discovered and activated, the chest should
## spin briefly, then disappear. Add a small reward moment to acknowledge the discovery."
##
## WHAT TEACHES IT: stepping through W. At W 0 it is a closed knoll of rocks, like the others on the meadow. Its mouth
## is plugged by one rock that reaches only up to [member plug_to_w]; ana of that, the mouth is open, and the
## chamber's lamp and the chest stand at [member open_w]. The clues get stronger as you get closer:
## - the dotted secondary path from the camp (PenLayout/paths/pen_b.tres, the "cache" stretch) climbs through W to
##   it: at W 0 you see only the piece of it that crosses W 0, its marks thinning away at both ends;
## - a three-stone cairn in front of the mouth at W 0 has only two stones there: the top one sits 0.9 m ana;
## - a pale glint at the mouth, an orthoplex as deep in W as the mouth band, grows as your slice nears it;
## - last, after lingering, the W guide's chip ("Q / E step through W"): never the big card here.
##
## NO CROSSING: it is walked into in W, no scene change, so none of the cave's crossing machinery (its fade, music,
## look hold) is involved. The rocks are the valley's own (scripts/pen_crag_chunk_4d.gd: shared baked stones, a box
## collider each, all unturned so their boxes are tight); everything here is built when the scene loads and never
## saved into it. Move or turn this node to move the whole cache.
##
## NO class_name (engine_gotchas.md).

const Chunk := preload("res://ramon/chickenpen/scripts/pen_crag_chunk_4d.gd")
const Mats := preload("res://ramon/CreationLab/LabKit/lab_materials.gd")
const Confetti := preload("res://ramon/chickenpen/discovery/pen_confetti_4d.gd")
const WSense := preload("res://ramon/chickenpen/discovery/w_sense_4d.gd")

@export var player_path: NodePath = ^"../../Player"
@export var inventory_path: NodePath = ^"../../UI/Inventory"
@export var readout_path: NodePath = ^"../../UI/LockOn"
@export var lookout_path: NodePath = ^"../../Systems/Lookout"
## Where the chamber, its lamp and the chest are in W.
@export var open_w: float = 7.5: set = _set_open_w
## How far ana the plug in the mouth reaches: from here to the shell's end, the mouth is open.
@export var plug_to_w: float = 5.5: set = _set_plug
@export_range(1, 30, 1) var azoth: int = 10
@export var timber: Color = Color(0.36, 0.24, 0.14)
@export var iron: Color = Color(0.22, 0.22, 0.24)
@export var crystal: Color = Color(1.0, 0.80, 0.32)

## Found this session (a new launch, or Ctrl+R, hides it again for the next visitor).
static var found: bool = false

# The shell's W reach: every rock of the walls and roof stands from SHELL_W.x to SHELL_W.y.
const SHELL_W := Vector2(-2.0, 9.5)

var _player: CharacterBody4D
var _cam: Camera4D
var _chest: Node4D
var _lid: Node4D
var _crystals: Array[Node4D] = []
var _glint: MeshInstance4D
var _lamp: OmniLight4D
var _tag_anchor: Node4D
var _tag: Node
var _tag_text: String = ""
var _opening: float = -1.0
var _paid: bool = false
var _toast_left: float = 0.0
var _toast: String = ""
var _t: float = 0.0


func _set_open_w(v: float) -> void:
	open_w = v
	_later()


func _set_plug(v: float) -> void:
	plug_to_w = v
	_later()


func _later() -> void:
	if is_node_ready():
		rebuild()


func _ready() -> void:
	rebuild()
	if Engine.is_editor_hint():
		return
	# Ctrl+R resets Systems only; the W guide passes it on to this group (discovery/pen_w_guide_4d.gd reset).
	add_to_group(&"discovery_reset")
	_player = get_node_or_null(player_path) as CharacterBody4D
	_cam = WSense.camera_of(_player)
	_tag_anchor = Node4D.new()
	_tag_anchor.name = "OpenAnchor"
	add_child(_tag_anchor)
	_tag_anchor.position = Vector4(0.0, 1.45, -0.8, open_w)
	_tag = WorldTag4D.new()
	_tag.name = "OpenPrompt"
	_tag.set("anchor_path", NodePath(".."))
	if _cam != null:
		_tag.set("camera_path", _cam.get_path())
	_tag.set("lift", 6.0)
	_tag_anchor.add_child(_tag)
	if found:
		_chest.visible = false


func rebuild() -> void:
	for child in get_children():
		if child.has_meta(&"_cache_part"):
			remove_child(child)
			child.free()
	_crystals.clear()
	var shell_mid: float = (SHELL_W.x + SHELL_W.y) * 0.5
	var shell_w: float = SHELL_W.y - SHELL_W.x
	# The walls and roof, round a chamber 3 m wide and 4 m deep, its mouth facing +z (south, toward the camp).
	_rock("Back", Vector4(0.0, 0.0, -2.6, shell_mid), Vector3(5.6, 3.6, 1.3), shell_w, "block", 0)
	_rock("Left", Vector4(-2.15, 0.0, 0.3, shell_mid), Vector3(1.3, 3.3, 6.0), shell_w, "block", 1)
	_rock("Right", Vector4(2.15, 0.0, 0.3, shell_mid), Vector3(1.3, 3.3, 6.0), shell_w, "block", 2)
	_rock("FrontLeft", Vector4(-1.6, 0.0, 2.7, shell_mid), Vector3(1.6, 3.2, 1.2), shell_w, "block", 3)
	_rock("FrontRight", Vector4(1.6, 0.0, 2.7, shell_mid), Vector3(1.6, 3.2, 1.2), shell_w, "block", 1)
	_rock("Lintel", Vector4(0.0, 2.25, 2.7, shell_mid), Vector3(1.9, 1.0, 1.2), shell_w, "slab", 0, 0.0)
	_rock("Roof", Vector4(0.0, 2.7, 0.0, shell_mid), Vector3(5.6, 1.0, 6.2), shell_w, "slab", 2, 0.0)
	# The plug: the mouth closed from the shell's kata end up to plug_to_w, open ana of it.
	var plug_from: float = SHELL_W.x
	_rock("Plug", Vector4(0.0, 0.0, 2.7, (plug_from + plug_to_w) * 0.5), Vector3(1.75, 2.35, 1.25), plug_to_w - plug_from, "round", 2)
	# Boulders round the outside, at their own W, so the knoll looks like the meadow's other rocks from any slice.
	_rock("BoulderA", Vector4(-3.3, 0.0, -1.5, 1.5), Vector3(2.2, 2.0, 2.6), 6.0, "round", 0)
	_rock("BoulderB", Vector4(3.4, 0.0, 1.4, 4.0), Vector3(2.0, 1.6, 2.2), 7.0, "round", 3)
	_rock("BoulderC", Vector4(0.8, 0.0, -3.7, 6.5), Vector3(2.6, 2.4, 1.8), 6.0, "round", 1)
	_rock("Chip", Vector4(-2.6, 0.0, 3.6, 0.5), Vector3(1.2, 0.9, 1.1), 3.0, "chip", 2)
	# The cairn at W 0, in front: two stones here, the top one 0.9 m ana.
	_rock("CairnBase", Vector4(3.0, 0.0, 4.6, 0.0), Vector3(0.7, 0.5, 0.7), 0.8, "round", 0, 0.2, false)
	_rock("CairnMid", Vector4(3.0, 0.45, 4.6, 0.0), Vector3(0.55, 0.4, 0.55), 0.7, "round", 1, 0.0, false)
	_rock("CairnTop", Vector4(3.0, 0.82, 4.6, 0.9), Vector3(0.45, 0.35, 0.45), 0.6, "round", 2, 0.0, false)
	_build_chest()
	_build_glint()
	if not Engine.is_editor_hint():
		_lamp = OmniLight4D.new()
		_lamp.name = "Lamp"
		_lamp.light_color = Color(1.0, 0.78, 0.45)
		_lamp.light_energy = 2.2
		_lamp.set("omni_range_meters", 5.5)
		_part(_lamp)
		_lamp.position = Vector4(0.0, 2.1, -0.3, open_w)
		_build_hint()


func _part(node: Node) -> void:
	node.set_meta(&"_cache_part", true)
	add_child(node)


func _rock(part: String, at: Vector4, size: Vector3, w_size: float, kind: String, variant: int, bury: float = 0.6, solid: bool = true) -> void:
	var rock := MeshInstance4D.new()
	rock.name = part
	rock.set_script(Chunk)
	rock.set("kind", kind)
	rock.set("variant", variant)
	rock.set("size", size)
	rock.set("w_size", w_size)
	rock.set("bury", bury)
	rock.set("solid", solid)
	_part(rock)
	rock.position = at


## The chest: a timber body with iron bands and a hinged lid, 0.9 deep in W as it is wide, standing at open_w at the
## back of the chamber. Three crystals inside, which rise when it opens.
func _build_chest() -> void:
	_chest = Node4D.new()
	_chest.name = "Chest"
	_part(_chest)
	_chest.position = Vector4(0.0, 0.0, -0.8, open_w)
	_box(_chest, "Body", Vector4(0.0, 0.28, 0.0, 0.0), Vector4(0.9, 0.55, 0.6, 0.9), timber)
	for x in [-0.33, 0.33]:
		_box(_chest, "Band%d" % int(x * 10.0), Vector4(x, 0.28, 0.0, 0.0), Vector4(0.06, 0.57, 0.62, 0.92), iron)
	_box(_chest, "Lock", Vector4(0.0, 0.46, 0.31, 0.0), Vector4(0.12, 0.14, 0.04, 0.14), iron)
	_lid = Node4D.new()
	_lid.name = "LidHinge"
	_chest.add_child(_lid)
	_lid.position = Vector4(0.0, 0.555, -0.3, 0.0)
	_box(_lid, "Lid", Vector4(0.0, 0.08, 0.31, 0.0), Vector4(0.92, 0.16, 0.62, 0.92), timber)
	for x in [-0.33, 0.33]:
		_box(_lid, "LidBand%d" % int(x * 10.0), Vector4(x, 0.08, 0.31, 0.0), Vector4(0.06, 0.18, 0.64, 0.94), iron)
	for k in 3:
		var c := MeshInstance4D.new()
		c.name = "Crystal%d" % k
		var m := OrthoplexTetraMesh4D.new()
		m.half_extents = Vector4(0.09, 0.16, 0.09, 0.12)
		c.mesh = m
		c.material_override = Mats.glow(crystal, 1.0)
		c.set_meta(&"_look_own", true)
		_chest.add_child(c)
		c.position = Vector4(-0.22 + 0.22 * float(k), 0.42, 0.0, 0.0)
		_crystals.append(c)


func _box(parent: Node4D, part: String, at: Vector4, size: Vector4, colour: Color) -> MeshInstance4D:
	var node := MeshInstance4D.new()
	node.name = part
	var mesh := BoxTetraMesh4D.new()
	mesh.size = size
	node.mesh = mesh
	var mat := TetraMaterial4D.new()
	mat.albedo_color = colour
	node.material_override = mat
	# Kept as it is in the dev look, as the things you use are kept readable.
	node.set_meta(&"_look_own", true)
	parent.add_child(node)
	node.position = at
	return node


## A pale glint in the mouth: an orthoplex as deep in W as the open band, so its cut is a speck far off in W and
## grows as your slice comes to the mouth's W (the chickens' glimpse, scripts/chicken_cues_4d.gd).
func _build_glint() -> void:
	_glint = MeshInstance4D.new()
	_glint.name = "Glint"
	var m := OrthoplexTetraMesh4D.new()
	m.half_extents = Vector4(0.16, 0.16, 0.16, (SHELL_W.y - plug_to_w) * 0.5 + 1.0)
	_glint.mesh = m
	_glint.material_override = Mats.glow(Color(1.0, 0.92, 0.62), 1.0)
	_glint.set_meta(&"_look_own", true)
	_part(_glint)
	_glint.position = Vector4(0.0, 1.3, 3.5, (plug_to_w + SHELL_W.y) * 0.5)


## The W guide's spot (discovery/pen_w_guide_4d.gd): in front of the knoll, a chip only, after a long linger, and done
## once your slice is at the mouth's W.
func _build_hint() -> void:
	var hint := Node4D.new()
	hint.name = "Hint"
	hint.add_to_group(&"w_hint")
	hint.set_meta(&"w_hint_key", "kata_cache")
	hint.set_meta(&"w_hint_skill", "step")
	hint.set_meta(&"w_hint_radius", 9.0)
	hint.set_meta(&"w_hint_target", NodePath(".."))
	hint.set_meta(&"w_hint_offset", Vector4(0.0, 1.2, 3.0, open_w))
	hint.set_meta(&"w_hint_reach", 1.2)
	hint.set_meta(&"w_hint_done", "in_slice")
	hint.set_meta(&"w_hint_linger", 8.0)
	hint.set_meta(&"w_hint_tier_min", 1)
	hint.set_meta(&"w_hint_chip_always", true)
	_part(hint)
	hint.position = Vector4(0.0, 0.0, 6.0, 0.0)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_t += delta
	if _glint != null:
		var s: float = 1.0 + 0.18 * sin(_t * 2.6)
		_glint.basis = Basis4D.from_zx(_t * 0.7) * Basis4D.from_scale(Vector4(s, s, s, 1.0))
		_glint.visible = not found
	if _toast_left > 0.0:
		_toast_left -= delta
		if _toast_left <= 0.0:
			var readout := get_node_or_null(readout_path) as Label
			if readout != null and readout.text == _toast:
				readout.text = ""
	if _opening >= 0.0:
		_animate(delta)
	_update_prompt()


func can_open() -> bool:
	if found or _opening >= 0.0 or _player == null or not _player.is_visible_in_tree() or _player.get("input_enabled") == false:
		return false
	var gap: Vector4 = _chest.global_position - _player.global_position
	if Vector2(gap.x, gap.z).length() > 1.9:
		return false
	return absf(WSense.off_slice(_cam, _chest.global_position + Vector4(0, 0.4, 0, 0))) <= 0.5


## V ALIGN (Ramon, 10 Oct, items 22-23: "I can't tell what it's supposed to do. Rotating through W doesn't produce an
## obvious result ... consider using the established V, Align to Slice"): the open chamber is [member open_w] ana of the
## farm; once your slice shows a part of it (turned or stepped toward it), V lays your slice flat at its W, as the
## balloon's and the camp's do, and you stand in front of the open mouth with its lamp and the chest inside.
func can_align() -> bool:
	if found or _opening >= 0.0 or _player == null or not _player.is_visible_in_tree() or _player.get("input_enabled") == false:
		return false
	var mouth: Vector4 = global_position + Vector4(0.0, 1.2, 0.6, open_w)
	var gap: Vector4 = mouth - _player.global_position
	if Vector2(gap.x, gap.z).length() > 16.0 or absf(_player.global_position.w - open_w) < 0.6:
		return false
	var share: float = WSense.share(WSense.off_slice(_cam, mouth), 2.6)
	return share >= 0.35 and share < 0.995


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or key.keycode != KEY_V or not can_align():
		return
	get_viewport().set_input_as_handled()
	var rig: Node = _player.get_node_or_null("CameraRig")
	if rig != null and rig.has_method("align_to"):
		rig.call("align_to", open_w)
	var lookout: Node = get_node_or_null(lookout_path)
	if lookout != null and lookout.has_method("sound"):
		lookout.call("sound", &"secret")


func _update_prompt() -> void:
	if _tag == null:
		return
	var text: String = ""
	if can_open():
		text = "%s  Open the chest" % _key_for(&"catch_target")
		_tag_anchor.position = Vector4(0.0, 1.45, -0.8, open_w)
	elif can_align():
		text = "V  Align to the opening"
		# Over the mouth, where your slice crosses it, so the prompt is in your slice.
		var at: Vector4 = global_position + Vector4(0.0, 2.6, 0.6, 0.0)
		var w: float = WSense.slice_w_at(_cam, at.x, at.y, at.z)
		at.w = w if w != INF else _player.global_position.w
		_tag_anchor.global_position = at
	if text != _tag_text:
		_tag_text = text
		if text == "":
			_tag.call("clear")
		else:
			_tag.call("show_text", text)


## F, in _input: the catcher takes every F in its _unhandled_input (scripts/chicken_catcher_4d.gd), so this has to
## come first, as the talking characters do (PenNpcTalk4D). It takes the key only at the open chest's mouth with no
## chicken in reach or in your arms; any other press falls through to the catcher untouched.
func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not event.is_action_pressed(&"catch_target") or not can_open():
		return
	var catcher: Node = _player.get_node_or_null(^"Catcher") if _player != null else null
	if catcher != null and (catcher.get("carried") != null or catcher.get("_candidate") != null):
		return
	get_viewport().set_input_as_handled()
	_open()


func _open() -> void:
	var inventory: Node = get_node_or_null(inventory_path)
	if inventory != null and not bool(inventory.call("has_item", "found_azoth")) \
			and (inventory.get("items") as Array).size() >= int(inventory.get("slot_count")):
		_say("Your belt is full. Make room, and the azoth is yours.")
		return
	_opening = 0.0
	_paid = false
	var lookout: Node = get_node_or_null(lookout_path)
	if lookout != null and lookout.has_method("sound"):
		lookout.call("sound", &"secret")


## The reward: the lid opens and the crystals rise (0 to 1.6 s), then the chest spins and shrinks away (1.2 to 3.4 s);
## the azoth, the confetti and the line at 2.6 s.
func _animate(delta: float) -> void:
	_opening += delta
	var t: float = _opening
	_lid.basis = Basis4D.from_yz(-1.9 * smoothstep(0.0, 0.6, t))
	for i in _crystals.size():
		var c: Node4D = _crystals[i]
		c.position.y = 0.42 + 0.6 * smoothstep(0.4 + 0.12 * float(i), 1.6, t)
		c.basis = Basis4D.from_zx(t * 3.0 + float(i))
	var spin: float = smoothstep(1.2, 3.4, t)
	var shrink: float = 1.0 - smoothstep(2.2, 3.4, t)
	_chest.basis = Basis4D.from_zx(spin * spin * TAU * 3.0) * Basis4D.from_scale(Vector4.ONE * maxf(shrink, 0.001))
	if t >= 2.6 and not _paid:
		_pay()
	if t >= 3.4:
		_chest.visible = false
		_opening = -1.0
		found = true


func _pay() -> void:
	_paid = true
	var inventory: Node = get_node_or_null(inventory_path)
	if inventory != null:
		for i in azoth:
			inventory.call("add_item", "found_azoth")
	var burst := Confetti.new()
	add_child(burst)
	burst.call("throw", _chest.global_position + Vector4(0.0, 0.9, 0.0, 0.0))
	_say("Found: %d azoth, in a chest out along W. Somebody hid this well." % azoth)


func _say(line: String) -> void:
	var readout := get_node_or_null(readout_path) as Label
	if readout == null:
		return
	readout.text = line
	_toast = line
	_toast_left = 4.5


## For the W guide's "flag" rule.
func hint_done() -> bool:
	return found


func _key_for(action: StringName) -> String:
	if not InputMap.has_action(action):
		return "?"
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
			return OS.get_keycode_string(code)
	return "?"


## Ctrl+R: hidden again for the next visitor.
func reset() -> void:
	found = false
	_opening = -1.0
	rebuild()
	if not Engine.is_editor_hint() and _chest != null:
		_chest.visible = true
