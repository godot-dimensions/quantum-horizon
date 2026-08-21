extends Node
## TEMPORARY - verifies, independently, the four pieces just added to
## limb_prototype_treadmill.tscn:
##   1. BodyPOI (POI4D, category=UNIT) is discovered by POIRadar._collect_pois.
##   2. POIRadar draws without error and its exported wiring resolves.
##   3. The travel-direction indicator (direction_source_path=Body) draws a
##      second marker distinct from the PoI dot.
##   4. GaitController's 1/2 key bindings actually switch presets, and the
##      InfoLabel text updates to show the new gait while keeping its
##      original description intact.
## Not part of the shipped scene - wired in as a temporary autoload with
## limb_prototype_treadmill.tscn set as the main scene.


func _screenshot(image_name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://smoke_test_output/" + image_name)


func _press_key(keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame
	var release := InputEventKey.new()
	release.keycode = keycode
	release.physical_keycode = keycode
	release.pressed = false
	Input.parse_input_event(release)
	await get_tree().process_frame


func _ready() -> void:
	await get_tree().process_frame
	_run()


func _run() -> void:
	var scene: Control = get_tree().current_scene
	var flat_plane: Node4D = scene.get_node("FlatPlane")
	var body: Node4D = flat_plane.get_node("Body")
	var body_poi: Node = flat_plane.get_node("Body/BodyPOI")
	var poi_radar: Control = scene.get_node("POIRadar")
	var gait: Node = flat_plane.get_node("GaitController")
	var info_label: Label = scene.get_node("InfoLabel")

	print("1.nodes_resolve: body_poi=%s poi_radar=%s gait=%s info_label=%s" % [
		body_poi != null, poi_radar != null, gait != null, info_label != null,
	])
	print("2.body_poi_is_POI4D=%s body_poi_category=%s" % [body_poi is POI4D, body_poi.category if body_poi is POI4D else "N/A"])

	# --- Piece 1+2: PoI discovery + radar wiring ---
	var container: Node = poi_radar.get_node_or_null(poi_radar.poi_container_path)
	var collected: Array = poi_radar._collect_pois(container) if container != null else []
	print("3.poi_container_resolves=%s collected_poi_count=%d contains_body_poi=%s" % [
		container != null, collected.size(), body_poi in collected,
	])

	var camera_ok: bool = poi_radar.get_node_or_null(poi_radar.camera_path) != null
	var rig_ok: bool = poi_radar.get_node_or_null(poi_radar.rig_path) != null
	print("4.poi_radar_camera_resolves=%s rig_resolves=%s" % [camera_ok, rig_ok])

	# --- Piece 3: travel-direction indicator ---
	var direction_source: Node = poi_radar.get_node_or_null(poi_radar.direction_source_path)
	var has_method: bool = direction_source != null and direction_source.has_method("get_travel_direction")
	print("5.direction_source_resolves=%s has_get_travel_direction=%s live_travel_dir=%s" % [
		direction_source != null, has_method, body.get_travel_direction() if has_method else "N/A",
	])

	await _screenshot("limb_prototype_poi_radar_initial.png")

	# --- Piece 4: gait key binding + label ---
	print("6.initial_gait=%s initial_label_text=\"%s\"" % [gait.preset, info_label.text])

	await _press_key(KEY_2)
	print("7.after_KEY_2: gait=%s label_text=\"%s\" (expect trot)" % [gait.preset, info_label.text])

	await _press_key(KEY_1)
	print("8.after_KEY_1: gait=%s label_text=\"%s\" (expect walk)" % [gait.preset, info_label.text])

	await _screenshot("limb_prototype_poi_radar_after_keys.png")

	print("DONE")
	get_tree().quit()
