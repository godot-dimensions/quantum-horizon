@tool
extends Node4D

## THE WATCHSTONE: the pen's lookout, a rock crag with timber walkways, built to Ramon's sheet
## (PenLayout/refs/watchstone_views.png) by measurement (PenLayout/PLAN_REF_LOCK.md, part C; Ramon,
## 6 Oct: "It looks nothing like the concept ... be more precise! ... the scaffolds also look
## different. like copying the general idea instead of following the design").
##
## EVERY NUMBER HERE IS MEASURED. Cameras were fitted to the sheet's front and top views
## (PenLayout/tools/ref_fit.py: 3.8 and 7.4 px from the picks) and every timber part was placed by
## triangulating it in both, or by putting a front-view point on the line the top view gives
## (PenLayout/RefLock/specs/watchstone_fit.json). The side view is a different drawing (the scaffold
## and landings sit 3-4 m further north in it) and gives only the scaffold's design: its bays, its
## ties and the way its braces lean. The origin is the plateau's middle on the ground; S is +z, the
## front view's side; the player stands at the path's end, 8.2 m south and 2.4 m west.
##
## THE CRAG: scripts/pen_crag_4d.gd on lookout/watchstone_spec.json (the rock hierarchy: one core,
## face blocks in courses, ledge stones, debris, grass). Where timber runs in front of the rock the
## courses step back to give it room (the spec's terraces), and every leg stops on the rock top
## under it (_rock_top).
##
## THE TIMBER, part by part, as numbered on PenLayout/refs/analysis/watchstone_breakdown.png:
##   T1 the first run: a cleated ramp from the path's end up to the lower landing, the one you walk.
##   T2 the lower landing on four braced legs, railed on its north, east and south.
##   T3 the long stair back west across the face to the terrace walkway.
##   T4 the terrace walkway along the south face, rising gently east.
##   T5 the left platform, a square turned 41 degrees, on braced legs off the terrace.
##   T6 the scaffold: a narrow two-post-deep frame against the east face, four bays, a tie at each
##      painted height and one brace per bay, and the shorter posts under the upper platform's
##      west strip.
##   T7 the upper platform, 1.9 m below the rim, its west strip along the face.
##   T8 the ladder from it onto the plateau.
##   T9 the plateau's railing: sixteen posts, one rail at sixty percent of their height (counted in
##      the top view), a gap where the ladder arrives.
## Railings, the plateau's ring and the scaffold's frame are the fence tech (FenceGenerator4D,
## engine/modules/quantum_horizon): posts are the ribs a slice shows, rails are the beams, and a
## stair's railing is a sloped seed so its posts stay upright while its rail follows the slope.
## Decks, treads, stringers, legs and braces are boards. No pins.
##
## THE WALK-UP (PLAN_WATCHSTONE.md step 9; Ramon: "you will just walk up the bottom slope a bit..
## and then spawn on top of it"). Partway up T1 the screen dips and you are on the plateau; walk to
## the ladder's head and you are back at T1's foot. The Lookout's old ladder climb is off for a
## tower that walks_up().
##
## WHAT THE LOOKOUT ASKS OF A TOWER, answered: deck_height, cab_size, cab_w_depth, is_balcony(),
## on_deck(), ladder_foot(), ladder_top(), ladder_z(), top_half(), cab_floor(), cab_eye(),
## ana_perch(), north(), dial_outline().
##
## Built when it loads (and in the editor); nothing generated is saved into the scene.
## NO class_name (engine_gotchas.md).

const Crag := preload("res://ramon/chickenpen/scripts/pen_crag_4d.gd")
const MainGreen := preload("res://ramon/chickenpen/terrain/main_green_4d.gd")
const SPEC := "res://ramon/chickenpen/lookout/watchstone_spec.json"

const OWN := &"_watchstone_part"
const PLACE := "The Watchstone"

## The plateau: its turf's height, the railing's radius (fitted to the sheet, 3.76 m) and the green turf
## disc's, a little smaller so it sits inside the rock rim (Ramon, 6 Oct: "make terras slightly smaller ...
## i just meant the green cylinder floor you use on top").
const TOP := 13.65
const RAIL_R := 3.76
const TURF_R := 3.7
## T1, the first run: its foot (deck middle at the low end) and its head on T2.
const T1_FOOT := Vector4(-1.55, 0.25, 7.6, 0)
const T1_HEAD := Vector4(4.55, 4.2, 5.75, 0)
const T1_WIDTH := 1.1
## T2, the lower landing: x and z extents, deck height.
const T2_X := Vector2(4.6, 7.0)
const T2_Z := Vector2(3.3, 5.9)
const T2_Y := 4.2
## T3, the long stair, from T2's west side to the terrace walkway.
const T3_FOOT := Vector4(4.6, 4.2, 4.85, 0)
const T3_HEAD := Vector4(-1.66, 8.0, 4.3, 0)
## T4, the terrace walkway, as a line of deck points.
const T4 := [Vector4(-3.35, 7.9, 3.15, 0), Vector4(-1.8, 7.95, 4.1, 0), Vector4(1.6, 8.25, 4.4, 0)]
## T5, the left platform: middle, half size, turn (from +x toward +z), deck height.
const T5_AT := Vector4(-4.84, 7.9, 2.73, 0)
const T5_HALF := 1.15
const T5_TURN := 0.72
## T6, the scaffold's long column: x (west, east) and z (north, middle), from its foot up to T7.
const T6_X := Vector2(4.7, 5.4)
const T6_Z := Vector2(1.8, 3.46)
const T6_FOOT := 4.0
## Its ties, from the side view's bays (11.8 to 4.0 in 1.5, 1.7, 1.9 and 2.7 m).
const T6_TIES := [4.0, 6.7, 8.6, 10.3, 11.8]
## T7, the upper platform: the main deck's x and z, the west strip's, the deck height.
const T7_X := Vector2(3.3, 5.4)
const T7_Z := Vector2(1.8, 4.8)
const T7_STRIP_X := Vector2(1.45, 3.3)
const T7_STRIP_Z := Vector2(3.9, 4.8)
const T7_Y := 11.8
## T8, the ladder: foot on T7, head on the rim.
const T8_FOOT := Vector4(3.1, 11.8, 3.05, 0)
const T8_HEAD := Vector4(2.34, 13.65, 2.53, 0)

@export_tool_button("Rebuild") var _rebuild_action: Callable = rebuild
## Turns the crag's generated stones into nodes under Stones, one a stone, grouped by where they sit,
## so each can be moved, turned and resized by hand (Ramon, 6 Oct: "i want to be able to move all the
## stones"). Once only: after it, the stones are the scene's, and [member stones_baked] keeps the crag
## from laying out its own. Open units/watchstone/watchstone.tscn itself to use it.
@export_tool_button("Bake every stone into the scene") var _bake_action: Callable = bake_stones
## Set by the bake: the stones are nodes under Stones, and the crag builds no stones of its own.
@export var stones_baked: bool = false: set = _set_baked
## The grass disc the sheet stands the crag on (off in the pen, where the pen's ground is).
@export var ground_disc: bool = false: set = _set_disc
## How deep in W the plateau and the crag are, and the timber.
@export_range(2.0, 10.0, 0.1, "suffix:m") var w_depth: float = 6.0
@export_range(0.4, 4.0, 0.05, "suffix:m") var timber_w: float = 1.4: set = _set_timber_w

@export_group("Look")
## The painted timber (refs/measure: 151, 110, 75 as painted), set under the ref stage's light.
@export var timber: Color = Color(0.6, 0.44, 0.3)
@export var timber_dark: Color = Color(0.45, 0.32, 0.21)
@export var timber_light: Color = Color(0.68, 0.51, 0.35)

@export_group("The walk-up")
@export var player_path: NodePath = NodePath("../../../Player")
@export var lookout_path: NodePath = NodePath("../../../Systems/Lookout")
## How far up T1 (metres along it from its foot) the walk-up takes you.
@export_range(0.5, 6.0, 0.1, "suffix:m") var walk_up_at: float = 2.4
@export_range(0.05, 1.0, 0.01, "suffix:s") var fade_out: float = 0.25
@export_range(0.05, 1.5, 0.01, "suffix:s") var fade_in: float = 0.5

## Rail heights and sizes: posts 0.16 thick and a metre above the deck, the rail on top; the
## plateau's posts 0.85 tall with the rail at 0.55 (the sheet, zoomed: one round rail through the
## posts at about sixty percent).
const POST := 0.16
const RAIL := 0.09
const RAIL_H := 1.0

var _player: Node4D
var _lookout: Node
var _fade: ColorRect
var _phase: int = 0
var _to := Vector4.ZERO
var _going_up: bool = true
var _t: float = 0.0
var _rest: float = 0.0
var _input_was: bool = true
var _way_down: WorldTag4D
var _way_shown: String = ""

var _pending: bool = false
var _batches: Dictionary = {}
var _body: StaticBody4D
var _crag: Node4D
var _wood: TetraMaterial4D


func _set_disc(v: bool) -> void:
	ground_disc = v
	_later()


func _set_baked(v: bool) -> void:
	stones_baked = v
	_later()


func _set_timber_w(v: float) -> void:
	timber_w = v
	_later()


func _ready() -> void:
	rebuild()
	if Engine.is_editor_hint():
		return
	add_to_group(&"slice_dial_outline")
	add_to_group(MainGreen.GROUP)
	_player = get_node_or_null(player_path) as Node4D
	_lookout = get_node_or_null(lookout_path)
	var layer := CanvasLayer.new()
	layer.name = "WalkUpFade"
	layer.layer = 55
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0.0, 0.0, 0.0, 0.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_fade)
	var anchor := Node4D.new()
	anchor.name = "WayDown"
	anchor.position = _ladder_head() + Vector4(0.0, 1.1, 0.0, 0.0)
	add_child(anchor)
	_way_down = WorldTag4D.new()
	_way_down.name = "Prompt"
	_way_down.anchor_path = NodePath("..")
	var cam: Node = _player.get_node_or_null("CameraRig/Pitch/Camera4D") if _player != null else null
	if cam != null:
		_way_down.camera_path = cam.get_path()
	_way_down.lift = 8.0
	anchor.add_child(_way_down)


func _later() -> void:
	if not is_node_ready() or _pending:
		return
	_pending = true
	rebuild.call_deferred()


## New moss baked, or the main green switched on or off (terrain/main_green_4d.gd): every stone built
## again from the stone library, and merged again. The turf is the crag's own (pen_crag_4d.gd).
func main_green_changed(_c: Color, baked: bool) -> void:
	if not baked:
		return
	for holder_name in ["Stones", "Chunks"]:
		var holder: Node = get_node_or_null(holder_name)
		if holder == null:
			continue
		for mi in holder.find_children("*", "MeshInstance4D", true, false):
			if mi.has_method("rebuild"):
				mi.call("rebuild")
	_merge_stones()


func rebuild() -> void:
	_pending = false
	for c in get_children():
		if c.has_meta(OWN):
			remove_child(c)
			c.queue_free()
	_batches.clear()
	_wood = TetraMaterial4D.new()
	_wood.albedo_color = timber
	_body = StaticBody4D.new()
	_body.name = "Solid"
	_own(_body)
	_crag = Crag.new()
	_crag.name = "Crag"
	_crag.set("solid", not Engine.is_editor_hint())
	_crag.set("ground_disc", ground_disc)
	# The walkways the rock must step back from (the terraces): their middle lines and half widths.
	_crag.set("clear_paths", [[[T1_FOOT, T1_HEAD], T1_WIDTH * 0.5], [[Vector4(T2_X.x, T2_Y, (T2_Z.x + T2_Z.y) * 0.5, 0), Vector4(T2_X.y, T2_Y, (T2_Z.x + T2_Z.y) * 0.5, 0)], (T2_Z.y - T2_Z.x) * 0.5],
		[[T3_FOOT, T3_HEAD], 0.5], [T4, 0.5], [[T5_AT, T5_AT + Vector4(0.01, 0, 0, 0)], T5_HALF * 1.3],
		[[Vector4(T6_X.x, T6_FOOT, (T6_Z.x + T6_Z.y) * 0.5, 0), Vector4(T6_X.x, T7_Y, (T6_Z.x + T6_Z.y) * 0.5, 0)], (T6_Z.y - T6_Z.x) * 0.5]])
	_crag.set("chunks", _chunk_nodes())
	_crag.set("procedural_stones", not stones_baked)
	_crag.set("spec_path", SPEC)
	_own(_crag)
	_t1()
	_t2()
	_t3()
	_t4()
	_t5()
	_t6()
	_t7()
	_t8()
	_t9()
	_flush()
	if not Engine.is_editor_hint():
		_merge_stones.call_deferred()


# --- The chunks --------------------------------------------------------------------------------

## The big rock chunks, placed by hand (the scene's Chunks node, pen_crag_chunk_4d.gd each).
func _chunk_nodes() -> Array:
	var out: Array = []
	var holder: Node = get_node_or_null("Chunks")
	if holder != null:
		for c in holder.get_children():
			if c.has_method("footprint"):
				out.append(c)
	return out


var _chunk_sig: float = 0.0
var _chunk_moved_at: float = -1.0
var _clock: float = 0.0


## In the editor: when a chunk has been moved and then left alone for half a second, the crag is
## rebuilt round it (only the crag: the timber does not change). Not once the stones are baked: then
## nothing of the crag's depends on where a chunk stands.
func _process(delta: float) -> void:
	if not Engine.is_editor_hint() or stones_baked or _crag == null or not is_instance_valid(_crag):
		return
	_clock += delta
	var sig: float = 0.0
	for c in _chunk_nodes():
		sig += float(c.call("signature"))
	if absf(sig - _chunk_sig) > 1e-4:
		_chunk_sig = sig
		_chunk_moved_at = _clock
	elif _chunk_moved_at >= 0.0 and _clock - _chunk_moved_at > 0.5:
		_chunk_moved_at = -1.0
		_crag.set("chunks", _chunk_nodes())
		_crag.call("rebuild")


## Every stone node's mesh (Stones and Chunks) merged into one at runtime, the single ones hidden: a
## crag of two hundred and fifty stones is one draw in the pen, not two hundred and fifty (Trym's
## Experiment B). In the editor each stays its own, so each can be picked and moved.
func _merge_stones() -> void:
	var old: Node = get_node_or_null("AllStones")
	if old != null:
		remove_child(old)
		old.queue_free()
	var merged := ArrayTetraMesh4D.new()
	var count: int = 0
	var inv: Projection = global_basis.inverse()
	for holder_name in ["Stones", "Chunks"]:
		var holder: Node = get_node_or_null(holder_name)
		if holder == null:
			continue
		for mi in holder.find_children("*", "MeshInstance4D", true, false):
			var m := mi as MeshInstance4D
			if not m.has_method("footprint") or not (m.mesh is ArrayTetraMesh4D):
				continue
			merged.merge_with(m.mesh, inv * (m.global_position - global_position), inv * m.global_basis)
			m.visible = false
			count += 1
	if count == 0:
		return
	var node := MeshInstance4D.new()
	node.name = "AllStones"
	node.mesh = merged
	node.material_override = preload("res://ramon/chickenpen/terrain/terrain_bake_4d.gd").material()
	_own(node)


## The bake (see [member _bake_action]).
func bake_stones() -> void:
	if not Engine.is_editor_hint():
		return
	var root: Node = get_tree().edited_scene_root
	if root != self:
		push_warning("Watchstone: open units/watchstone/watchstone.tscn itself to bake its stones; here it is inside another scene.")
		return
	if stones_baked:
		push_warning("Watchstone: the stones are baked already. To lay them out afresh: delete the Stones node, untick stones_baked, then bake.")
		return
	bake_into(root)


## The bake's work, owned by [param root] (the scene being saved): also run by
## PenLayout/RefLock/_bake_watchstone_stones_runner.gd without the editor. Returns how many it made.
func bake_into(root: Node) -> int:
	if _crag == null or not is_instance_valid(_crag):
		rebuild()
	var Chunk: Script = load("res://ramon/chickenpen/scripts/pen_crag_chunk_4d.gd")
	var CutStone: Script = load("res://ramon/chickenpen/terrain/cut_stone_4d.gd")
	var layout: Array = _crag.call("stone_layout")
	var holder := get_node_or_null("Stones") as Node4D
	if holder == null:
		holder = Node4D.new()
		holder.name = "Stones"
		add_child(holder)
		holder.owner = root
	var groups: Dictionary = {}
	var made: int = 0
	for s in layout:
		if s.size() > 6 and s[6] != null:
			continue
		var group: String = String(s[7]) if s.size() > 7 else "Stones"
		if not groups.has(group):
			var g := Node4D.new()
			g.name = group
			holder.add_child(g)
			g.owner = root
			groups[group] = g
		var full: String = String(s[0])
		var mossy: bool = full.ends_with("_moss")
		var kind: String = full.trim_suffix("_moss")
		var half: Vector4 = CutStone.KINDS[kind][0]
		var sc: Vector4 = s[3]
		var size := Vector3(sc.x * 2.0 * half.x, sc.y * 2.0 * half.y, sc.z * 2.0 * half.z)
		var tilt: Vector2 = s[5]
		var rot: Projection = Basis4D.from_xy(tilt.x) * Basis4D.from_yz(tilt.y) * Basis4D.from_zx(float(s[4]))
		var n := MeshInstance4D.new()
		n.set_script(Chunk)
		n.name = "Stone%03d" % made
		n.set("kind", kind)
		n.set("variant", int(s[1]))
		n.set("moss", mossy)
		n.set("size", size)
		n.set("w_size", sc.w * 2.0 * half.w)
		n.set("bury", 0.0)
		n.set("solid", false)
		n.position = (s[2] as Vector4) - rot * Vector4(0, size.y * 0.5, 0, 0)
		n.basis = rot
		(groups[group] as Node).add_child(n)
		n.owner = root
		made += 1
	stones_baked = true
	rebuild()
	print("Watchstone: %d stones baked into the scene under Stones (%s). Save the scene to keep them." % [made, ", ".join(PackedStringArray(groups.keys()))])
	return made


# --- The rock under the timber ------------------------------------------------------------------

## The height of the rock's top at (x, z): the highest course whose face is beyond that point, or
## the ground. Every leg stands on it.
func _rock_top(x: float, z: float) -> float:
	if _crag == null or (_crag.get("spec") as Dictionary).is_empty():
		return 0.0
	var a: float = atan2(z, x)
	var r: float = Vector2(x, z).length()
	var top: float = 0.0
	var courses: Array = (_crag.get("spec") as Dictionary)["courses"]
	for i in courses.size():
		if r < float(_crag.call("face", i, a)) - 0.3:
			top = maxf(top, float(courses[i]["y1"]))
	return top


# --- T1 the first run ---------------------------------------------------------------------------

## The cleated ramp you walk: a deck, cleats across it, a stringer under each side, a railing each
## side (fence tech, sloped), and legs down to the ground at the railing posts. Solid as low steps.
func _t1() -> void:
	var a: Vector4 = T1_FOOT
	var b: Vector4 = T1_HEAD
	_ramp(a, b, T1_WIDTH, 0.42, true)
	var side: Vector4 = _side(a, b) * (T1_WIDTH * 0.5 - 0.05)
	for s in [-1.0, 1.0]:
		_railing([a + side * s, b + side * s], 1.6)
	# Solid: a flight of low boxes along it, and its sides walled.
	var d: Vector4 = b - a
	var flat: float = Vector2(d.x, d.z).length()
	# From the ground, not from the deck's first board: every rise under the walker's 0.32 m.
	var steps: int = int(ceil(b.y / 0.24))
	var dir2: Vector2 = Vector2(d.x, d.z) / flat
	var across := Vector2(-dir2.y, dir2.x)
	for k in steps:
		var f0: float = float(k) / float(steps)
		var f1: float = float(k + 1) / float(steps)
		var h: float = b.y * f1
		var mid2: Vector2 = Vector2(a.x, a.z) + dir2 * flat * (f0 + f1) * 0.5
		# Boxes cannot turn: a run along a slant is a staircase of axis boxes covering it.
		var len: float = flat / float(steps) + 0.06
		var size2: Vector2 = Vector2(absf(dir2.x) * len + absf(across.x) * T1_WIDTH, absf(dir2.y) * len + absf(across.y) * T1_WIDTH)
		_solid(Vector4(size2.x, h, size2.y, timber_w), Vector4(mid2.x, h * 0.5, mid2.y, 0))


# --- T2 the lower landing ------------------------------------------------------------------------

func _t2() -> void:
	var y: float = T2_Y
	_deck(T2_X, T2_Z, y, Vector2(0, 1))
	var nw := Vector4(T2_X.x, y, T2_Z.x, 0)
	var ne := Vector4(T2_X.y, y, T2_Z.x, 0)
	var se := Vector4(T2_X.y, y, T2_Z.y, 0)
	var s_end := Vector4(T2_X.x + 1.0, y, T2_Z.y, 0)
	# Railed north, east and south as painted; open on the west (T3) and at the south-west corner
	# (T1 arrives there).
	_railing([nw, ne, se, s_end], 1.2)
	_legs([Vector2(T2_X.x + 0.1, T2_Z.x + 0.1), Vector2(T2_X.y - 0.1, T2_Z.x + 0.1), Vector2(T2_X.y - 0.1, T2_Z.y - 0.1), Vector2(T2_X.x + 0.1, T2_Z.y - 0.1)], y, true)
	_solid(Vector4(T2_X.y - T2_X.x, 0.3, T2_Z.y - T2_Z.x, timber_w), Vector4((T2_X.x + T2_X.y) * 0.5, y - 0.15, (T2_Z.x + T2_Z.y) * 0.5, 0))


# --- T3 the long stair -------------------------------------------------------------------------

func _t3() -> void:
	var a: Vector4 = T3_FOOT
	var b: Vector4 = T3_HEAD
	_ramp(a, b, 1.0, 0.36, false)
	var side: Vector4 = _side(a, b) * 0.45
	for s in [-1.0, 1.0]:
		_railing([a + side * s, b + side * s], 1.6)


# --- T4 the terrace walkway ----------------------------------------------------------------------

func _t4() -> void:
	for i in T4.size() - 1:
		_ramp(T4[i], T4[i + 1], 1.0, 0.5, false, i == 0)
	# A railing on the outer (south) side all along, and on the rock side.
	var outer: Array = []
	var inner: Array = []
	for i in T4.size():
		var p: Vector4 = T4[i]
		var a: Vector4 = T4[maxi(i - 1, 0)]
		var b: Vector4 = T4[mini(i + 1, T4.size() - 1)]
		var side: Vector4 = _side(a, b) * 0.45
		# The south side: the side vector that points toward +z.
		if side.z < 0.0:
			side = -side
		outer.append(p + side)
		inner.append(p - side)
	_railing(outer, 1.6)
	_railing(inner, 1.6)


# --- T5 the left platform ------------------------------------------------------------------------

func _t5() -> void:
	var c: Vector4 = T5_AT
	var h: float = T5_HALF
	var ax := Vector4(cos(T5_TURN), 0, sin(T5_TURN), 0)
	var az := Vector4(-sin(T5_TURN), 0, cos(T5_TURN), 0)
	var corners: Array = [c - ax * h - az * h, c + ax * h - az * h, c + ax * h + az * h, c - ax * h + az * h]
	_deck_turned(c, ax, az, h)
	# Railed on its three outer sides; open toward T4 (its east corner side).
	_railing([corners[2], corners[3], corners[0], corners[1]], 1.15)
	var feet: Array = []
	for p in corners:
		feet.append(Vector2((p as Vector4).x, (p as Vector4).z) + Vector2(c.x - (p as Vector4).x, c.z - (p as Vector4).z) * 0.08)
	_legs(feet, c.y, true)


# --- T6 the scaffold ----------------------------------------------------------------------------

## The long column: four posts against the east face from T6_FOOT up to T7, a tie round it at each
## painted height (fence tech: one box fence a bay, one beam at its top, so the ties sit where the
## side view has them), one brace per bay on each face. And the shorter posts under T7's south edge
## down to the ledge, braced.
func _t6() -> void:
	for i in T6_TIES.size() - 1:
		var y0: float = T6_TIES[i]
		var y1: float = T6_TIES[i + 1]
		var f := _fence_node("ScaffoldBay%d" % i)
		f.input_shape_type = FenceGenerator4D.INPUT_SHAPE_BOX
		f.box_size = Vector3(T6_X.y - T6_X.x, T6_Z.y - T6_Z.x, timber_w)
		f.position = Vector4((T6_X.x + T6_X.y) * 0.5, y0, (T6_Z.x + T6_Z.y) * 0.5, 0)
		f.post_height_meters = y1 - y0
		f.post_thickness_meters = 0.2
		f.rib_thickness_ratio = 0.95
		f.beam_count = 1
		f.beam_max_height_ratio = 0.999
		f.beam_coverage = clampf(0.14 / (y1 - y0), 0.02, 1.0)
		f.beam_thickness_ratio = 0.7
		f.desired_spacing_meters = 0.0
		f.update_fence_mesh_now()
		# The braces: one a bay on each face, leaning as the side view's do (down toward the north
		# on the east and west faces; alternating on the south and north).
		for x in [T6_X.x - 0.02, T6_X.y + 0.02]:
			_strut(timber_dark, Vector4(x, y1 - 0.1, T6_Z.y, 0), Vector4(x, y0 + 0.1, T6_Z.x, 0), 0.11)
		var flip: bool = i % 2 == 0
		for z in [T6_Z.x - 0.02, T6_Z.y + 0.02]:
			_strut(timber_dark, Vector4(T6_X.x if flip else T6_X.y, y1 - 0.1, z, 0), Vector4(T6_X.y if flip else T6_X.x, y0 + 0.1, z, 0), 0.1)
	# The south column (the side view's left one): the frame carried on from the long column to T7's
	# south edge, standing on the ledge, one bay, tied at its foot and under the deck, braced.
	var s_foot: float = maxf(_rock_top(T6_X.x, T7_Z.y - 0.2), _rock_top(T6_X.y, T7_Z.y - 0.2))
	if T7_Y - s_foot > 0.6:
		var sc := _fence_node("ScaffoldSouth")
		sc.input_shape_type = FenceGenerator4D.INPUT_SHAPE_BOX
		sc.box_size = Vector3(T6_X.y - T6_X.x, T7_Z.y - 0.1 - T6_Z.y, timber_w)
		sc.position = Vector4((T6_X.x + T6_X.y) * 0.5, s_foot, (T6_Z.y + T7_Z.y - 0.1) * 0.5, 0)
		sc.post_height_meters = T7_Y - s_foot
		sc.post_thickness_meters = 0.2
		sc.rib_thickness_ratio = 0.95
		sc.beam_count = 2
		sc.beam_max_height_ratio = 0.999
		sc.beam_coverage = clampf(0.14 / ((T7_Y - s_foot) * 0.5), 0.02, 1.0)
		sc.beam_thickness_ratio = 0.7
		sc.desired_spacing_meters = 0.0
		sc.update_fence_mesh_now()
		for x in [T6_X.x - 0.02, T6_X.y + 0.02]:
			_strut(timber_dark, Vector4(x, s_foot + 0.15, T7_Z.y - 0.1, 0), Vector4(x, T7_Y - 0.15, T6_Z.y, 0), 0.1)
	# The shorter posts under T7's south edge, down to the ledge, a brace between each pair.
	var shorts: Array = [Vector2(T7_STRIP_X.x + 0.15, T7_Z.y - 0.1), Vector2(T7_STRIP_X.y, T7_Z.y - 0.1), Vector2(T7_X.y - 0.1, T7_Z.y - 0.1)]
	var prev: Variant = null
	for s in shorts:
		var base: float = _rock_top(s.x, s.y)
		_post(Vector4(s.x, 0, s.y, 0), base, T7_Y, 0.18)
		if prev != null:
			var p: Vector2 = prev
			var pb: float = _rock_top(p.x, p.y)
			_strut(timber_dark, Vector4(p.x, T7_Y - 0.2, p.y + 0.02, 0), Vector4(s.x, maxf(base, pb) + 0.3, s.y + 0.02, 0), 0.1)
		prev = s


# --- T7 the upper platform -----------------------------------------------------------------------

func _t7() -> void:
	var y: float = T7_Y
	_deck(T7_X, T7_Z, y, Vector2(0, 1))
	_deck(T7_STRIP_X, T7_STRIP_Z, y, Vector2(0, 1))
	# Railed east and south, and round the strip's west end; open to the rock and the ladder.
	_railing([Vector4(T7_X.x + 0.6, y, T7_Z.x, 0), Vector4(T7_X.y, y, T7_Z.x, 0), Vector4(T7_X.y, y, T7_Z.y, 0),
		Vector4(T7_STRIP_X.x, y, T7_STRIP_Z.y, 0), Vector4(T7_STRIP_X.x, y, T7_STRIP_Z.x, 0)], 1.1)


# --- T8 the ladder ------------------------------------------------------------------------------

func _t8() -> void:
	var a: Vector4 = T8_FOOT
	var b: Vector4 = T8_HEAD + Vector4(0, 0.3, 0, 0)
	var side: Vector4 = _side(a, b) * 0.25
	for s in [-1.0, 1.0]:
		_strut(timber_dark, a + side * s, b + side * s, 0.08)
	var rungs: int = 7
	for k in rungs:
		var q: Vector4 = a.lerp(b, (float(k) + 0.6) / float(rungs + 0.4))
		_strut(timber, q - side, q + side, 0.06)


# --- T9 the plateau's railing --------------------------------------------------------------------

## Sixteen posts round the plateau, one rail through them at sixty percent of their height, a gap
## where the ladder arrives (one bay left out).
##
## A WHOLE 4D RAILING (Ramon, 6 Oct: "is the top of the rock a proper 4d generator fence tech?"). The
## plateau is a 4D disc: round in x and z and 6 m deep in W. Its railing is one FenceGenerator4D whose
## seed is the plateau's whole boundary in the ground hyperplane: the ring of sixteen posts at both W
## ends of the plateau, the band of faces between them all round (rails in every slice through the
## plateau), and the two sixteen-sided faces closing it at the W ends (the railing you meet when you
## step to the plateau's edge in W). Before this it was a strip 1.4 m deep in W, so stepping ana or
## kata off it left the plateau standing without its railing. The bay where the ladder arrives is
## left open.
func _t9() -> void:
	var gap: float = atan2(T8_HEAD.z, T8_HEAD.x)
	var n: int = 16
	var start: int = int(round(gap / (TAU / float(n)))) + 1
	var hw: float = w_depth * 0.5 - 0.3
	var seed := ArrayPolyMesh4D.new()
	var lo: Array = []
	var hi: Array = []
	for k in n:
		var a: float = TAU * float(start + k) / float(n) - TAU / float(n) * 0.5
		lo.append(seed.append_vertex(Vector4(cos(a) * RAIL_R, TOP, sin(a) * RAIL_R, -hw)))
		hi.append(seed.append_vertex(Vector4(cos(a) * RAIL_R, TOP, sin(a) * RAIL_R, hw)))
	var ring_lo := PackedInt32Array()
	var ring_hi := PackedInt32Array()
	for k in n:
		var k2: int = (k + 1) % n
		var e_lo: int = seed.append_edge_indices(lo[k], lo[k2])
		var e_hi: int = seed.append_edge_indices(hi[k], hi[k2])
		ring_lo.append(e_lo)
		ring_hi.append(e_hi)
		# The band all round but the last bay, which is the ladder's (the points start just past it).
		if k < n - 1:
			var e_a: int = seed.append_edge_indices(lo[k2], hi[k2])
			var e_b: int = seed.append_edge_indices(hi[k], lo[k])
			seed.append_poly_cell(2, PackedInt32Array([e_lo, e_a, e_hi, e_b]))
	seed.append_poly_cell(2, ring_lo)
	seed.append_poly_cell(2, ring_hi)
	var f := _fence_node("PlateauRailing")
	f.input_shape_type = FenceGenerator4D.INPUT_SHAPE_SEED_MESH_4D
	f.seed_mesh_4d = seed
	f.post_height_meters = 0.85
	f.post_thickness_meters = POST / 0.95
	f.rib_thickness_ratio = 0.95
	f.beam_count = 1
	f.beam_max_height_ratio = 0.55 / 0.85
	f.beam_coverage = clampf(RAIL / 0.55, 0.02, 1.0)
	f.beam_thickness_ratio = RAIL / POST
	f.desired_spacing_meters = 0.0
	f.update_fence_mesh_now()
	# Solid: a ring of small boxes along the railing (physics is boxes that do not turn), the floor out
	# to it, so nobody walks off the top; the ladder's bay closed too, the way down is a zone inside it.
	var r: float = RAIL_R - 0.05
	for k in n:
		var a0: float = TAU * float(k) / float(n)
		var a1: float = TAU * float(k + 1) / float(n)
		var p0 := Vector4(cos(a0) * r, TOP + 0.6, sin(a0) * r, 0)
		var p1 := Vector4(cos(a1) * r, TOP + 0.6, sin(a1) * r, 0)
		for j in 3:
			_solid(Vector4(0.55, 1.2, 0.55, w_depth), p0.lerp(p1, (float(j) + 0.5) / 3.0))
	_solid(Vector4(RAIL_R * 2.0, 0.6, RAIL_R * 2.0, w_depth), Vector4(0, TOP - 0.3, 0, 0))


# --- Builders -----------------------------------------------------------------------------------

## A railing along [param points] (deck-height points, in order): fence tech on a seed of strips
## stretched in W, so each joint is a post and [param spacing] fills posts between (0: none).
func _railing(points: Array, spacing: float, post_h: float = RAIL_H, rail_top: float = RAIL_H - 0.03) -> FenceGenerator4D:
	var seed := ArrayPolyMesh4D.new()
	var hw: float = timber_w * 0.5
	var lo: Array = []
	var hi: Array = []
	for p in points:
		var q: Vector4 = p
		lo.append(seed.append_vertex(Vector4(q.x, q.y, q.z, -hw)))
		hi.append(seed.append_vertex(Vector4(q.x, q.y, q.z, hw)))
	for i in points.size() - 1:
		var e0: int = seed.append_edge_indices(lo[i], lo[i + 1])
		var e1: int = seed.append_edge_indices(lo[i + 1], hi[i + 1])
		var e2: int = seed.append_edge_indices(hi[i + 1], hi[i])
		var e3: int = seed.append_edge_indices(hi[i], lo[i])
		seed.append_poly_cell(2, PackedInt32Array([e0, e1, e2, e3]))
	var f := _fence_node("Railing")
	f.input_shape_type = FenceGenerator4D.INPUT_SHAPE_SEED_MESH_4D
	f.seed_mesh_4d = seed
	f.post_height_meters = post_h
	f.post_thickness_meters = POST / 0.95
	f.rib_thickness_ratio = 0.95
	f.beam_count = 1
	f.beam_max_height_ratio = clampf(rail_top / post_h, 0.05, 0.999)
	f.beam_coverage = clampf(RAIL / rail_top, 0.02, 1.0)
	f.beam_thickness_ratio = RAIL / POST
	f.desired_spacing_meters = spacing
	f.update_fence_mesh_now()
	return f


func _fence_node(name: String) -> FenceGenerator4D:
	var f := FenceGenerator4D.new()
	f.name = name
	f.update_automatically = false
	f.output_mesh_type = FenceGenerator4D.OUTPUT_MESH_TETRA
	f.rib_height_ratio = 0.999
	f.post_material = _wood
	f.rib_material = _wood
	f.beam_material = _wood
	_own(f)
	return f


## A cleated ramp from [param a] to [param b] (deck-top points on its middle line): the deck,
## cleats across every [param cleat] metres, a stringer under each side, legs at about every 1.6 m
## down to the rock (or the ground) when [param legs_to_ground].
func _ramp(a: Vector4, b: Vector4, width: float, cleat: float, legs_to_ground: bool, first: bool = true) -> void:
	var d: Vector4 = b - a
	var length: float = d.length()
	var frame: Projection = _frame_x(d / length)
	_box(timber, Vector4(length, 0.08, width, timber_w), (a + b) * 0.5 - Vector4(0, 0.04, 0, 0), frame)
	var cleats: int = int(length / cleat)
	for k in cleats:
		var q: Vector4 = a.lerp(b, (float(k) + 0.5) / float(cleats))
		_box(timber_light, Vector4(0.07, 0.05, width * 0.98, timber_w * 0.98), q + Vector4(0, 0.02, 0, 0), frame)
	var side: Vector4 = _side(a, b) * (width * 0.5 - 0.04)
	for s in [-1.0, 1.0]:
		_box(timber_dark, Vector4(length + 0.1, 0.24, 0.09, timber_w), (a + b) * 0.5 + side * s - Vector4(0, 0.16, 0, 0), frame)
	var legs: int = int(length / 1.6)
	for k in legs + 1:
		var q: Vector4 = a.lerp(b, minf((float(k) + (0.5 if not first else 0.3)) * 1.6 / length, 1.0))
		if q.y < 0.5:
			continue
		for s in [-1.0, 1.0]:
			var p: Vector4 = q + side * s
			var base: float = 0.0 if legs_to_ground else _rock_top(p.x, p.z)
			base = maxf(base, _rock_top(p.x, p.z))
			if q.y - base > 0.4:
				_post(p, base, q.y - 0.2, 0.13)


## A deck over [param xs] by [param zs] at [param y]: boards, its planks across [param along].
func _deck(xs: Vector2, zs: Vector2, y: float, along: Vector2) -> void:
	var c := Vector4((xs.x + xs.y) * 0.5, y - 0.05, (zs.x + zs.y) * 0.5, 0)
	var size := Vector4(xs.y - xs.x, 0.1, zs.y - zs.x, timber_w)
	_box(timber, size, c)
	var horiz: bool = absf(along.x) > absf(along.y)
	var n: int = int((size.z if not horiz else size.x) / 0.32)
	for k in n + 1:
		var f: float = float(k) / float(maxi(n, 1))
		if horiz:
			_box(timber_dark, Vector4(0.03, 0.105, size.z, timber_w), c + Vector4(-size.x * 0.5 + size.x * f, 0, 0, 0))
		else:
			_box(timber_dark, Vector4(size.x, 0.105, 0.03, timber_w), c + Vector4(0, 0, -size.z * 0.5 + size.z * f, 0))
	# The rim beam round its edge.
	for s in [-1.0, 1.0]:
		_box(timber_dark, Vector4(size.x + 0.06, 0.2, 0.08, timber_w), c + Vector4(0, -0.1, s * size.z * 0.5, 0))
		_box(timber_dark, Vector4(0.08, 0.2, size.z + 0.06, timber_w), c + Vector4(s * size.x * 0.5, -0.1, 0, 0))


## A turned square deck (T5): middle [param c], its axes, half size [param h].
func _deck_turned(c: Vector4, ax: Vector4, az: Vector4, h: float) -> void:
	var basis := Projection(ax, Vector4(0, 1, 0, 0), az, Vector4(0, 0, 0, 1))
	_box(timber, Vector4(h * 2.0, 0.1, h * 2.0, timber_w), c - Vector4(0, 0.05, 0, 0), basis)
	var n: int = int(h * 2.0 / 0.32)
	for k in n + 1:
		_box(timber_dark, Vector4(0.03, 0.105, h * 2.0, timber_w), c - Vector4(0, 0.05, 0, 0) + ax * (-h + 2.0 * h * float(k) / float(n)), basis)
	for s in [-1.0, 1.0]:
		_box(timber_dark, Vector4(h * 2.0 + 0.06, 0.2, 0.08, timber_w), c - Vector4(0, 0.15, 0, 0) + az * s * h, basis)
		_box(timber_dark, Vector4(0.08, 0.2, h * 2.0 + 0.06, timber_w), c - Vector4(0, 0.15, 0, 0) + ax * s * h, basis)


## Legs at [param feet] (x, z) from the rock up to a deck at [param top]; with [param braced], a
## brace from each leg's foot to the next leg's head, as the sheet's landings have.
func _legs(feet: Array, top: float, braced: bool) -> void:
	var bases: Array = []
	for f in feet:
		var p: Vector2 = f
		var base: float = _rock_top(p.x, p.y)
		bases.append(base)
		_post(Vector4(p.x, 0, p.y, 0), base, top - 0.2, 0.17)
	if braced:
		for i in feet.size():
			var p: Vector2 = feet[i]
			var q: Vector2 = feet[(i + 1) % feet.size()]
			var lo: float = maxf(float(bases[i]), float(bases[(i + 1) % feet.size()])) + 0.25
			if top - 0.3 - lo > 0.8:
				_strut(timber_dark, Vector4(p.x, lo, p.y, 0), Vector4(q.x, top - 0.3, q.y, 0), 0.1)


func _post(at: Vector4, y0: float, y1: float, thick: float) -> void:
	if y1 - y0 < 0.05:
		return
	_box(timber_dark, Vector4(thick, y1 - y0, thick, timber_w), Vector4(at.x, (y0 + y1) * 0.5, at.z, 0))


## The horizontal direction across the run from [param a] to [param b] (unit, in x-z).
static func _side(a: Vector4, b: Vector4) -> Vector4:
	var d := Vector2(b.x - a.x, b.z - a.z).normalized()
	return Vector4(-d.y, 0, d.x, 0)


# --- Helpers ------------------------------------------------------------------------------------

func _box(colour: Color, size: Vector4, at: Vector4, basis: Projection = Projection.IDENTITY) -> void:
	var key: String = colour.to_html(false)
	if not _batches.has(key):
		_batches[key] = ArrayTetraMesh4D.new()
	var box := BoxTetraMesh4D.new()
	box.size = size
	(_batches[key] as ArrayTetraMesh4D).merge_with(box.to_array_tetra_mesh(), at, basis)


func _strut(colour: Color, a: Vector4, b: Vector4, thick: float) -> void:
	var d: Vector4 = b - a
	var length: float = d.length()
	if length < 0.001:
		return
	_box(colour, Vector4(thick, length, thick, timber_w), (a + b) * 0.5, _frame_along(d / length))


func _flush() -> void:
	for key in _batches:
		var node := MeshInstance4D.new()
		node.name = "Timber_" + String(key)
		node.mesh = _batches[key]
		var m := TetraMaterial4D.new()
		m.albedo_color = Color.html(key)
		node.material_override = m
		_own(node)
	_batches.clear()


func _solid(size: Vector4, at: Vector4) -> void:
	var holder := CollisionShape4D.new()
	var shape := BoxShape4D.new()
	shape.size = size
	holder.shape = shape
	holder.position = at
	_body.add_child(holder)


## An orthonormal frame whose y is [param y] (lookout_tower_4d.gd's own).
static func _frame_along(y: Vector4) -> Projection:
	var picks: Array[Vector4] = []
	for axis in [Vector4(1, 0, 0, 0), Vector4(0, 0, 1, 0), Vector4(0, 1, 0, 0), Vector4(0, 0, 0, 1)]:
		var v: Vector4 = axis - y * y.dot(axis)
		for p in picks:
			v -= p * p.dot(v)
		if v.length() > 0.2:
			picks.append(v.normalized())
		if picks.size() == 3:
			break
	var frame := Projection(picks[0], y, picks[1], picks[2])
	if frame.determinant() < 0.0:
		frame.w = -frame.w
	return frame


## A frame whose x is [param x] (a run's direction) with y as near up as it can be.
static func _frame_x(x: Vector4) -> Projection:
	var up := Vector4(0.0, 1.0, 0.0, 0.0)
	var y: Vector4 = (up - x * x.dot(up)).normalized()
	var z := Vector4(-x.z, 0.0, x.x, 0.0).normalized()
	z = (z - x * x.dot(z) - y * y.dot(z)).normalized()
	var frame := Projection(x, y, z, Vector4(0.0, 0.0, 0.0, 1.0))
	if frame.determinant() < 0.0:
		frame.z = -frame.z
	return frame


func _own(node: Node) -> void:
	node.set_meta(OWN, true)
	add_child(node)


# --- What the Lookout asks of a tower -----------------------------------------------------------

var deck_height: float:
	get:
		return TOP
var cab_size: float:
	get:
		return TURF_R * 2.0
var cab_w_depth: float:
	get:
		return w_depth
var cab_height: float:
	get:
		return 2.6


func walks_up() -> bool:
	return true


## The way up T1 (global, level): for runners that walk it.
func walk_up_direction() -> Vector4:
	var d: Vector4 = T1_HEAD - T1_FOOT
	d.y = 0.0
	return (global_basis * d).normalized()


## A point on T1 just past where the walk-up takes you (global), for runners that put you there.
func walk_up_point() -> Vector4:
	var d: Vector4 = T1_HEAD - T1_FOOT
	var flat: float = Vector2(d.x, d.z).length()
	var f: float = clampf((walk_up_at + 0.6) / flat, 0.0, 1.0)
	return _global(T1_FOOT.lerp(T1_HEAD, f) + Vector4(0, 0.3, 0, 0))


func place_name() -> String:
	return PLACE


func is_balcony() -> bool:
	return true


func top_half() -> float:
	return TURF_R


## Whether [param p] (global) is up on the plateau.
func on_deck(p: Vector4) -> bool:
	var local: Vector4 = global_basis.inverse() * (p - global_position)
	return Vector2(local.x, local.z).length() < RAIL_R + 0.2 and local.y > TOP - 0.8 and local.y < TOP + 3.0 \
		and absf(local.w) < w_depth * 0.5


## Where the walk down puts you (global): at T1's foot, where the path ends.
func ladder_foot() -> Vector4:
	return _global(T1_FOOT + (T1_FOOT - T1_HEAD).normalized() * 1.0 * Vector4(1, 0, 1, 0) - Vector4(0, T1_FOOT.y, 0, 0))


## Where the walk-up puts you (global): the plateau's south-west, the ladder's head (east-south-east)
## well out of reach of your first step.
func ladder_top() -> Vector4:
	return _global(Vector4(-1.4, TOP, 1.3, 0.0))


func ladder_z() -> float:
	return T1_FOOT.z


func cab_floor() -> Vector4:
	return _global(Vector4(0.0, TOP, 0.0, 0.0))


func cab_eye() -> Vector4:
	return cab_floor() + global_basis * Vector4(0.0, 1.55, 0.0, 0.0)


## The owl's perch: north of the top, at about its height, a metre and a half ana.
func ana_perch() -> Vector4:
	return _global(Vector4(0.7, TOP - 0.55, -TURF_R - 5.5, 1.5))


func north() -> Vector4:
	return (global_basis * Vector4(0.0, 0.0, -1.0, 0.0)).normalized()


## On the pen's dial: the crag's round at its foot, named.
func dial_outline() -> Dictionary:
	var points := PackedVector4Array()
	for i in 12:
		var a: float = TAU * float(i) / 12.0
		points.append(_global(Vector4(cos(a) * 7.5, 0.0, sin(a) * 7.5, 0.0)))
	return {"points": points, "label": "Watchstone", "colour": Color(0.95, 0.70, 0.42, 0.9), "depth": w_depth * 0.5}


func _global(local: Vector4) -> Vector4:
	return global_position + global_basis * local


# --- The walk-up -------------------------------------------------------------------------------

## Where the walk down starts, in this node's frame: inside the railing where the ladder comes up.
func _ladder_head() -> Vector4:
	var d := Vector2(T8_HEAD.x, T8_HEAD.z).normalized() * (RAIL_R - 0.75)
	return Vector4(d.x, TOP, d.y, 0.0)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or _player == null or _fade == null:
		return
	_rest = maxf(_rest - delta, 0.0)
	if _phase == 1:
		_t += delta
		_fade.color.a = clampf(_t / fade_out, 0.0, 1.0)
		if _t >= fade_out:
			_arrive()
		return
	if _phase == 2:
		_t += delta
		_fade.color.a = 1.0 - clampf(_t / fade_in, 0.0, 1.0)
		if _t >= fade_in:
			_phase = 0
			_fade.color.a = 0.0
		return
	var local: Vector4 = global_basis.inverse() * (_player.global_position - global_position)
	_show_way_down(local)
	if _rest > 0.0 or not _free():
		return
	# Up: partway along T1, on it.
	var d: Vector4 = T1_HEAD - T1_FOOT
	var flat := Vector2(d.x, d.z)
	var along: float = Vector2(local.x - T1_FOOT.x, local.z - T1_FOOT.z).dot(flat.normalized())
	var off: float = absf(Vector2(local.x - T1_FOOT.x, local.z - T1_FOOT.z).dot(Vector2(-flat.y, flat.x).normalized()))
	if absf(local.w) < timber_w * 0.5 + 0.3 and along > walk_up_at and along < flat.length() and off < T1_WIDTH * 0.5 + 0.4 \
			and local.y > 0.3 and local.y < T2_Y + 1.0:
		_go(ladder_top(), true)
		return
	# Down: at the railing where the ladder comes up.
	var head: Vector4 = _ladder_head()
	if absf(local.y - TOP) < 1.6 and absf(local.w) < w_depth * 0.5 and Vector2(local.x - head.x, local.z - head.z).length() < 0.8:
		_go(ladder_foot(), false)


## "Walk to the ladder to go down", on the top within a few metres of it.
func _show_way_down(local: Vector4) -> void:
	if _way_down == null:
		return
	var head: Vector4 = _ladder_head()
	var near: bool = _phase == 0 and absf(local.y - TOP) < 1.6 and absf(local.w) < w_depth * 0.5 \
		and Vector2(local.x - head.x, local.z - head.z).length() < 2.4
	var text: String = "Walk to the ladder to go down" if near else ""
	if _lookout != null:
		_way_down.set("_camera", _lookout.call("current_camera"))
	if text != _way_shown:
		_way_shown = text
		if text == "":
			_way_down.clear()
		else:
			_way_down.show_text(text)


## Whether the player is free to be taken: on the farm, walking, no story playing, no camera up
## (a raised camera is put down first, as the old ladder did).
func _free() -> bool:
	if not _player.is_visible_in_tree() or _player.get("input_enabled") == false:
		return false
	if _lookout == null:
		return true
	if bool(_lookout.call("story_busy")):
		return false
	var station: Node = _lookout.get("station")
	if station == null:
		return true
	var mode: int = int(station.get("mode"))
	return mode == 0 or mode == 5


## Off to [param to] (global), the screen dark on the way.
func _go(to: Vector4, up: bool) -> void:
	var station: Node = _lookout.get("station") if _lookout != null else null
	if station != null and int(station.get("mode")) == 5:
		station.call("lower")
	_to = to
	_going_up = up
	_phase = 1
	_t = 0.0
	_input_was = _player.get("input_enabled") != false
	_player.set("input_enabled", false)
	_player.set("linear_velocity", Vector4.ZERO)


func _arrive() -> void:
	_player.global_position = _to + Vector4(0.0, 0.05, 0.0, 0.0)
	_player.set("linear_velocity", Vector4.ZERO)
	_player.set("input_enabled", _input_was)
	# Up: facing north over the field, Wren in front of you. Down: facing away from the crag,
	# toward the pen, as the old ladder left you.
	var look: Vector4 = north()
	if not _going_up:
		var pen := _player.get_parent().get_node_or_null("Pen") as Node4D
		look = (pen.global_position if pen != null else Vector4.ZERO) - _to
	look.y = 0.0
	var rig: Node = _player.get_node_or_null("CameraRig")
	if rig != null and look.length() > 0.1:
		rig.call("face_toward", look)
		rig.set("pitch", -0.15)
		if rig.has_method("_apply"):
			rig.call("_apply")
	_phase = 2
	_t = 0.0
	_rest = 1.0
	if _lookout != null:
		_lookout.call("on_cab_entered" if _going_up else "on_cab_left")
