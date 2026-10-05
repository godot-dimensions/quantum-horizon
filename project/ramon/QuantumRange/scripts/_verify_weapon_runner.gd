extends SceneTree

## Plan steps 21 and 27: the weapon against the first three families, and the HUD reading them. A pip
## takes a quick shot; a block and an armoured core only scuff under a quick shot and break under a
## charged one; a pip 1.2 m ana is missed from your slice and hit once you step to it, the edge glowing as
## you arrive; a charge held too long vents and fires nothing. Frames in
## smoke_test_output/quantum_range/weapon/.
##
##   range_run.sh windowed weapon res://ramon/QuantumRange/scripts/_verify_weapon_runner.gd

const SCENE := "res://ramon/QuantumRange/quantum_range_final.tscn"
const OUT := "res://smoke_test_output/quantum_range/weapon/"
const Pip := preload("res://ramon/QuantumRange/scripts/targets/target_pip.gd")
const Block := preload("res://ramon/QuantumRange/scripts/targets/target_block.gd")
const Armoured := preload("res://ramon/QuantumRange/scripts/targets/target_armoured.gd")

var _r: Node
var _p: CharacterBody4D
var _w: Node
var _t0: int = 0
var _fails: int = 0


func _initialize() -> void:
	root.unfocusable = true
	_t0 = Time.get_ticks_msec()
	_run.call_deferred()


func _process(_d: float) -> bool:
	if Time.get_ticks_msec() - _t0 > 100000:
		print("WEAPON: gave up after 100 s")
		return true
	return false


func _check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		_fails += 1


func _shot(name: String) -> void:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name + ".png"))


func _spawn(script: Script, at: Vector4) -> Node4D:
	var t := Node4D.new()
	t.set_script(script)
	t.position = at
	(_r.get("targets") as Node).add_child(t)
	return t


func _aim(t: Node4D, part: String) -> void:
	var p: Dictionary = t.call("part", part)
	_p.call("aim_at", (p["node"] as Node4D).global_position)
	await process_frame
	await process_frame


func _quick() -> String:
	_w.call("press")
	var r: Dictionary = _w.call("release")
	await process_frame
	return String(r.get("outcome", ""))


func _charged(shoot_name: String = "") -> String:
	_w.call("press")
	await create_timer(1.0).timeout
	if not shoot_name.is_empty():
		await _shot(shoot_name)
	var r: Dictionary = _w.call("release")
	await process_frame
	return String(r.get("outcome", ""))


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_r = (load(SCENE) as PackedScene).instantiate()
	root.add_child(_r)
	current_scene = _r
	for i in 20:
		await process_frame
	_p = _r.get("player")
	_w = _r.get("weapon")
	_p.call("place", Vector4(0, 0.05, 1.5, 0), 0.0)
	var pip: Node4D = _spawn(Pip, Vector4(-2.4, 1.7, -8.0, 0.0))
	var block: Node4D = _spawn(Block, Vector4(0.0, 1.7, -8.0, 0.0))
	var arm: Node4D = _spawn(Armoured, Vector4(2.4, 1.7, -8.0, 0.0))
	var far: Node4D = _spawn(Pip, Vector4(0.6, 2.4, -12.0, 1.2))
	await create_timer(0.8).timeout
	_p.call("aim_at", Vector4(0.0, 1.9, -8.0, 0.0))
	await _shot("01_targets")
	await _aim(pip, "Core")
	_check(String(_w.get("hover")) == "core", "the crosshair knows it is over a core (%s)" % _w.get("hover"))
	await _shot("02_hover_core")
	var o: String = await _quick()
	_check(o == "pop", "a quick shot pops the pip (%s)" % o)
	await _shot("03_pop")
	await _aim(block, "Armour")
	o = await _quick()
	_check(o == "scuff", "a quick shot only scuffs amber (%s)" % o)
	o = await _charged("04_charge_full")
	_check(o == "break", "a charged shot breaks amber (%s)" % o)
	await _shot("05_block_broken")
	await _aim(arm, "Casing")
	o = await _quick()
	_check(o == "scuff", "the armoured core's casing scuffs under a quick shot (%s)" % o)
	o = await _charged()
	_check(o == "break", "and cracks under a charged one (%s)" % o)
	await _aim(arm, "Core")
	await _shot("06_core_exposed")
	o = await _quick()
	_check(o == "pop", "then the core it hid takes a quick shot (%s)" % o)
	await create_timer(0.4).timeout
	_check(not is_instance_valid(pip) and not is_instance_valid(block) and not is_instance_valid(arm), "all three are gone")
	# The pip 1.2 m ana: not in your slice, so the shot misses; step to it and it is there.
	await _aim(far, "Core")
	var hud: Node = _r.get("hud")
	await create_timer(0.3).timeout
	await _shot("07_far_off_slice")
	o = await _quick()
	_check(o == "", "the pip 1.2 m ana cannot be hit from your slice (%s)" % o)
	Input.action_press(&"move_ana")
	while _p.global_position.w < 1.18 and Time.get_ticks_msec() - _t0 < 90000:
		await physics_frame
	Input.action_release(&"move_ana")
	await create_timer(0.5).timeout
	await _aim(far, "Core")
	var g: float = float(((hud.get("_glow") as ColorRect).material as ShaderMaterial).get_shader_parameter("intensity"))
	_check(g > 0.15, "the edge glows once your slice cuts it (%.2f)" % g)
	await _shot("08_far_aligned")
	o = await _quick()
	_check(o == "pop", "and the shot lands (%s)" % o)
	# Held too long: it vents and fires nothing.
	_w.call("press")
	await create_timer(3.6).timeout
	_check(bool(_w.get("vented")), "a charge held 2.5 s past full vents")
	await _shot("09_vented")
	var r: Dictionary = _w.call("release")
	_check(not bool(r.get("fired", true)), "and fires nothing")
	var st: Dictionary = _w.get("stats")
	print("WEAPON: stats %s" % st)
	print("WEAPON: mean raycast %.1f us over %d rays" % [float(st["ray_us"]) / maxf(1.0, float(st["rays"])), int(st["rays"])])
	print("WEAPON: %d failed" % _fails)
	quit(1 if _fails > 0 else 0)
