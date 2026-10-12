extends Node4D
## Reusable "ammo pips" viewmodel component.
##
## A row of small MeshInstance4D cubes, all at local w=0, that flip between
## a bright "loaded" material and a dim "spent" material as rounds are
## fired and reloaded. Fully self-contained: any scene's gun viewmodel can
## instance this scene as a child and it manages its own ammo count,
## visuals, and reload timing. The only external touchpoints are
## [method can_fire] and [method consume_round], meant to be called by
## whatever script actually fires the weapon; reload itself is handled
## internally by listening for the "reload" input action.

const MAGAZINE_SIZE := 6
const PIP_SIZE := 0.025
const PIP_SPACING := 0.03
const RELOAD_DURATION_SEC := 1.3

## Bright "round loaded" material - assign a pre-made TetraMaterial4D.
@export var loaded_material: Material4D
## Dim/gray "round spent" material - assign a pre-made TetraMaterial4D.
@export var spent_material: Material4D

var _pips: Array[MeshInstance4D] = []
var _spent_count: int = 0

var _reloading: bool = false
var _reload_elapsed_sec: float = 0.0
var _pips_to_reload: int = 0
var _pips_restored: int = 0


func _ready() -> void:
	for i in MAGAZINE_SIZE:
		var pip := MeshInstance4D.new()
		var pip_mesh := BoxTetraMesh4D.new()
		pip_mesh.size = Vector4(PIP_SIZE, PIP_SIZE, PIP_SIZE, PIP_SIZE)
		pip.mesh = pip_mesh
		pip.material_override = loaded_material
		var offset: float = (i - (MAGAZINE_SIZE - 1) / 2.0) * PIP_SPACING
		pip.position = Vector4(offset, 0, 0, 0)
		add_child(pip)
		_pips.append(pip)


func _process(delta: float) -> void:
	if Input.is_action_just_pressed(&"reload") and not _reloading and _spent_count > 0:
		_reloading = true
		_reload_elapsed_sec = 0.0
		_pips_to_reload = _spent_count
		_pips_restored = 0

	if not _reloading:
		return

	_reload_elapsed_sec += delta
	var target_restored: int = floori((_reload_elapsed_sec / RELOAD_DURATION_SEC) * _pips_to_reload)
	target_restored = mini(target_restored, _pips_to_reload)
	while _pips_restored < target_restored:
		_restore_one_pip()
		_pips_restored += 1

	if _pips_restored >= _pips_to_reload:
		_reloading = false


func can_fire() -> bool:
	return _spent_count < MAGAZINE_SIZE


func consume_round() -> void:
	var index: int = MAGAZINE_SIZE - _spent_count - 1
	_pips[index].material_override = spent_material
	_spent_count += 1


func _restore_one_pip() -> void:
	_spent_count -= 1
	var index: int = MAGAZINE_SIZE - _spent_count - 1
	_pips[index].material_override = loaded_material
