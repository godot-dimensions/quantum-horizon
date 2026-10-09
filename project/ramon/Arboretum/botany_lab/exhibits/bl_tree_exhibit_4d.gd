extends Node4D

## BOTANY LAB (fork of exhibits/tree_exhibit_4d.gd, 9 Oct): the same, with how far a tree may be turned
## through W (`max_tilt`, read by the carried showcase: the Voxel Lab's, whose turn never touches up),
## and the Botany Lab's own bakes (botany_lab/baked/, their record bl_bake.cfg) beside the shared ones.
##
## The Arboretum: a tree on a pedestal, as the carried showcase (carried/kit/kit_showcase_4d.gd)
## holds an exhibit. One of these per method (ex_voxel_4d.gd, ex_dc_4d.gd, ex_loft_4d.gd,
## ex_oak_4d.gd), each saying what it shows in its story and what its one key does; this holds what
## they share:
##
##   THE TREE    a Stand that turns slowly (the room never moves, the exhibit does: the cinema's rule),
##               a Tree under it scaled to `tree_height`, and the tree's meshes as layers: "wood" (its
##               finished surface), "bones" (the skeleton's growth stages, gold), and whatever stages
##               the method's story shows. One material for all of them (botany_style.gd): the bark
##               shader reads which is which from each mesh's own texture coordinates.
##   BAKED       the meshes come from Arboretum/baked/ (scripts/_bake_runner.gd) with the bake's own
##               record (its times, its counts, its date); a method that can grow live says so on its
##               card and does it on its key, timed.
##   THE STORY   chapters(): this method's parts, each {key, title, length, line, callouts, eye, look,
##               fov}; play_part(key, t, length) shows the part at t; numbers() fills the callouts.
##   THE WIND    the room's wind (botany/wind_4d.gd) is handed the material with the Tree node.
##
## NO class_name (engine_gotchas.md).

const Style := preload("res://ramon/Arboretum/botany/botany_style.gd")
const Wind := preload("res://ramon/Arboretum/botany/wind_4d.gd")
const Bake := preload("res://ramon/Arboretum/botany/bake_store.gd")

const BL_DIR := "res://ramon/Arboretum/botany_lab/baked/"
const BL_RECORD := "res://ramon/Arboretum/botany_lab/baked/bl_bake.cfg"

## How far a turn through W may tip the tree's floor (degrees; plan step 37): past it the crown starts
## to leave the slice.
var max_tilt: float = 35.0

## Set by the showcase; trees ignore them.
var grow_in: bool = false
var joint_balls: bool = true

## Which method: "voxel", "dc", "loft" or "oak".
var method: String = "voxel"
## The height the tree is shown at, metres (its skeleton is scaled to it).
var tree_height: float = 4.3
## The turntable, degrees a second.
var turn_speed: float = 4.0

var sk: Resource
var stand: Node4D
var tree: Node4D
var material: TetraMaterial4D
var layers: Dictionary = {}
## The bake's record for this method (bake_store.gd) and anything measured live since.
var record: Dictionary = {}
var live_note: String = ""
var _yaw: float = 0.0
var _scale: float = 1.0
var _stages: Dictionary = {}
var _gusted: bool = false
var _busy: bool = false


func _ready() -> void:
	stand = Node4D.new()
	stand.name = "Stand"
	add_child(stand)
	tree = Node4D.new()
	tree.name = "Tree"
	stand.add_child(tree)
	_load()
	end_cinematic()


## A Botany Lab bake (botany_lab/scripts/_bl_bake_runner.gd), or null before it is baked.
static func bl_load(name: String) -> Resource:
	var p: String = BL_DIR + name + ".res"
	return load(p) if ResourceLoader.exists(p) else null


## A Botany Lab bake's record.
static func bl_record(section: String) -> Dictionary:
	var cf := ConfigFile.new()
	if cf.load(BL_RECORD) != OK or not cf.has_section(section):
		return {}
	var out: Dictionary = {}
	for k in cf.get_section_keys(section):
		out[k] = cf.get_value(section, k)
	return out


## Fills `sk`, the layers and `record` (each method its own).
func _load() -> void:
	pass


## Builds the material for `sk` and puts the tree at `tree_height`.
func _setup_tree(oak: bool = false) -> void:
	var summ: Dictionary = sk.call("summary")
	var h: float = maxf(float(summ["height"]), 0.5)
	_scale = tree_height / h
	tree.scale = Vector4(_scale, _scale, _scale, _scale)
	material = Style.tree_material(sk, h, oak)
	var wind: Node = Wind.of(get_tree())
	if wind != null:
		wind.call("register", Style.shader_of(material), tree)


## A mesh layer under the Tree, wearing the tree's material.
func layer(key: String, mesh: Resource) -> MeshInstance4D:
	var mi: MeshInstance4D = layers.get(key)
	if mi == null:
		mi = MeshInstance4D.new()
		mi.name = key.capitalize().replace(" ", "")
		tree.add_child(mi)
		layers[key] = mi
	mi.mesh = mesh as Mesh4D
	mi.material_override = material
	return mi


## Shows only the layers named in `keys`.
func show_only(keys: Array) -> void:
	for k in layers:
		(layers[k] as MeshInstance4D).visible = k in keys


## A growth stage of a staged layer: stage `i` of the meshes kept under `key`.
func show_stage(key: String, i: int) -> void:
	var list: Array = _stages.get(key, [])
	if list.is_empty():
		return
	var m: Resource = list[clampi(i, 0, list.size() - 1)]
	var mi: MeshInstance4D = layer(key, m)
	mi.visible = true


func set_stages(key: String, meshes: Array) -> void:
	_stages[key] = meshes
	if not meshes.is_empty():
		layer(key, meshes[meshes.size() - 1]).visible = false


func stage_count(key: String) -> int:
	return (_stages.get(key, []) as Array).size()


func _process(delta: float) -> void:
	pass


## The turntable, between stories (the showcase calls it).
func idle(delta: float) -> void:
	_yaw += deg_to_rad(turn_speed) * delta
	stand.basis = Basis4D.from_zx(_yaw)


## The stand's turn, so the showcase's turning through W is in the tree's own frame.
func stand_basis() -> Projection:
	return stand.basis if stand != null else Projection.IDENTITY


## How far the tree reaches through W either side of its middle (shown size), metres.
func w_extent() -> float:
	var bb: Dictionary = sk.call("bounds") if sk != null else {}
	if bb.is_empty():
		return 1.0
	return maxf(absf((bb["min"] as Vector4).w), absf((bb["max"] as Vector4).w)) * _scale


func grown() -> bool:
	return true


## The finished tree, as it stands between stories.
func end_cinematic() -> void:
	_gusted = false
	show_only(["wood"])


func chapters() -> Array:
	return []


func play_part(_key: String, _t: float, _length: float) -> Dictionary:
	return {}


## Sends one gust through the room (the wind parts of every story).
func gust_once(t: float, at: float = 0.6) -> void:
	if t < at:
		_gusted = false
	elif not _gusted:
		_gusted = true
		var wind: Node = Wind.of(get_tree())
		if wind != null:
			wind.call("gust")


## A slice sweep for the story's slice part: -1 to 1 and back over `length`.
static func sweep(t: float, length: float) -> float:
	var u: float = clampf((t - 0.8) / maxf(length - 1.6, 0.1), 0.0, 1.0)
	return sin(u * TAU) * 0.85


## The method's entry in botany_style.gd METHODS.
func info() -> Dictionary:
	for m in Style.METHODS:
		if String(m["key"]) == method:
			return m
	return {}


func data() -> Dictionary:
	var m: Dictionary = info()
	var summ: Dictionary = sk.call("summary") if sk != null else {}
	return {"name": String(m.get("name", "Tree")), "code": String(m.get("code", "XX-00")), "icon": "tree",
		"stats": {"tetra": int(record.get("tets", 0)), "nodes": int(summ.get("nodes", 0)), "branches": int(summ.get("branches", 0)),
			"reach": w_extent()}}


## The measured numbers (the panels and the cards read these).
func bench() -> Dictionary:
	return record


func numbers() -> Dictionary:
	var summ: Dictionary = sk.call("summary") if sk != null else {}
	var st: Dictionary = sk.get("stats") if sk != null else {}
	var out: Dictionary = {
		"name": String(info().get("name", "tree")).to_lower(),
		"nodes": str(int(summ.get("nodes", 0))),
		"branches": str(int(summ.get("branches", 0))),
		"tips": str(int(summ.get("tips", 0))),
		"height": "%.1f m" % (float(summ.get("height", 0.0)) * _scale),
		"w_depth": "%.1f m" % (float(summ.get("w_depth", 0.0)) * _scale),
		"grow_ms": Bake.ms(float(st.get("grow_ms", 0.0)) + float(st.get("shape_ms", 0.0))),
	}
	if int(record.get("tets", 0)) > 0:
		out["tets"] = Bake.thousands(int(record["tets"]))
		out["mb"] = "%.0f MB" % (float(record["tets"]) * 1.25 / 1024.0)
	return out


func action_label() -> String:
	return ""


func action() -> String:
	return ""


## The line round the pedestal's side.
func band_line() -> String:
	var m: Dictionary = info()
	var tier: String = "PRE-BAKED" if live_note.is_empty() else "GROWN LIVE"
	return "%s  ·  %s TETRAHEDRA  ·  %s" % [String(m.get("name", "")).to_upper(), Bake.short(int(record.get("tets", 0))), tier]


## What the room's card shows (tree_card.gd): method, shows, limits, measured rows.
func card() -> Dictionary:
	return {}


func live() -> Array:
	return []
