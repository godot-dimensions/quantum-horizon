@tool
extends "res://ramon/voxel_port/scripts/voxel_terrain_4d.gd"

## Makes the brick-streaming terrain follow whichever camera is ACTUALLY
## rendering, so it previews live in the editor's "4D" tab instead of only in
## Play. Used by voxel_port_2.tscn.
##
## Deliberately a subclass, not a copy. voxel_terrain_4d.gd is Trym's file and
## under active development (748 -> 1912 lines today); extending it means his
## next change arrives here for free, and this file stays small enough to throw
## away if he adopts the idea upstream.
##
## [b]The two problems this fixes[/b]
##
## 1. [i]Nothing appears in the editor.[/i] The base [code]_process()[/code]
##    returns immediately when [method Engine.is_editor_hint] - reasonably, it
##    was written as a live-camera concern. But [code]_poll_brick_tasks()[/code]
##    lives inside it, and that is what reaps finished background tasks and
##    actually builds their meshes. So in the editor bricks get queued, get
##    computed on the WorkerThreadPool, and are then never collected. Pressing
##    Generate looks like it does nothing.
##
## 2. [i]Visibility is culled from the wrong camera.[/i] The base resolves
##    [member camera_path], which points at the scene's HoverCamera. The editor
##    "4D" tab renders from its own internal camera instead, and there is no way
##    to preview through a scene [Camera4D] - the 4D editor plugin has no
##    equivalent of the 3D "Preview" checkbox. So chunks get hidden for failing
##    a slice test against a camera you are not looking through.
##
## [b]How[/b]
##
## [RenderingServer4D] is a registered engine singleton and emits
## [signal RenderingServer4D.pre_render] with the [Camera4D] it is about to
## render from. [EditorCamera4D] owns a real [Camera4D] internally, so in the
## editor that signal hands over the editor's camera and in Play it hands over
## HoverCamera - no branching on [method Engine.is_editor_hint] needed to pick
## one. Everything else (streaming radius, slice test, eviction) is the base
## class's, unchanged.

## The generation budget every one of Trym's demo bakes shares, from
## _bake_preset_runner.gd's [code]_apply_preset()[/code]. 48/16 gives 3 bricks
## per axis, so 3^4 = 81 candidate bricks - and 35 is what clears the corner
## ones: candidates are picked by distance to a brick's CENTRE, and the
## diagonal to a brick offset on all 4 axes is 16*sqrt(4) = 32. A smaller
## radius silently drops the 8 corner bricks, which is what produced the
## long-standing "gap-toothed sphere" on ocean_globe.
const BAKE_BRICK_CORE_CELLS := 16
const BAKE_GRID_SIZE := 48
const BAKE_CELL_SIZE := 1.0
const BAKE_RENDER_DISTANCE := 35.0

## How often the progress line refreshes. Deliberately much shorter than the
## re-request cadence below - this only reads counters, so it is nearly free,
## and a 15-second-stale progress bar is the thing this was added to avoid.
const BAKE_PROGRESS_INTERVAL_SECONDS := 2.0

## How often the radius request is re-issued, matching the runner's interval.
## generate() makes ONE request pass, so a candidate whose task could not be
## queued at that moment would otherwise never be retried - but re-scanning is
## real work, so it stays at 15s rather than every progress tick.
const BAKE_RESTREAM_INTERVAL_SECONDS := 15.0

## Width of the text progress bar drawn in [member bake_progress].
const BAKE_BAR_WIDTH := 24

@export_tool_button("Bake At Demo Settings") var _bake_action: Callable = bake_at_demo_settings

## Written to Godot's user:// data dir, not the project - bakes run 140-275 MB,
## far past what belongs in git.
@export var bake_file_name: String = "voxel_bake_custom.bin"

## Live progress readout, refreshed in the Inspector while a bake runs. Output
## only - editing it does nothing. Exists because a bake is minutes long with
## no other visible sign it is working, and the editor's own progress dialog
## has no GDScript API to hook into.
@export var bake_progress: String = "idle"

## Frame counter for editor-side streaming, kept separate from the base class's
## own [code]_stream_frame_counter[/code] so the two modes cannot interfere.
var _editor_stream_counter := 0

var _baking := false

## The camera the renderer last reported. Null until the first frame is drawn,
## which is why [method _get_viewer_state] still falls back to the base
## behaviour rather than assuming this is set.
var _render_camera: Camera4D = null


func _ready() -> void:
	super()
	if not RenderingServer4D.pre_render.is_connected(_on_pre_render):
		RenderingServer4D.pre_render.connect(_on_pre_render)


func _exit_tree() -> void:
	if RenderingServer4D.pre_render.is_connected(_on_pre_render):
		RenderingServer4D.pre_render.disconnect(_on_pre_render)


func _on_pre_render(camera: Camera4D, _viewport: Viewport, _rendering_engine: RenderingEngine4D) -> void:
	_render_camera = camera


## In Play, defer entirely to the base class. In the editor, run the same three
## steps it would - reap finished bricks, cull, stream - which it skips.
func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		super(delta)
		return

	_poll_brick_tasks()
	_update_chunk_visibility()

	_editor_stream_counter += 1
	if not freeze_streaming and _editor_stream_counter >= STREAM_SCAN_INTERVAL_FRAMES:
		_editor_stream_counter = 0
		_stream_bricks_near_camera()


## Bakes the CURRENT inspector settings at the demo generation budget, then
## writes the result to [member bake_file_name] under user://.
##
## Only the budget is overridden (brick size, grid size, cell size, render
## distance) - model layers, noise and shape are left exactly as configured, so
## this bakes whatever you have set up rather than one of Trym's four presets.
## For those, run the `_bake_*.tscn` scenes, which carry their own parameters.
##
## Runs in the editor because this subclass polls brick tasks there; the base
## class does not, so the same button on voxel_port.tscn would hang forever
## waiting for bricks that never get reaped.
##
## [b]This is slow and heavy.[/b] Trym measured 6.5-8.5 minutes per preset on
## an RTX 3090 with FPS in single digits, and the output files run 140-275 MB.
## The editor stays responsive-ish but will not be pleasant. Leave it alone
## until the "baked" line prints.
func bake_at_demo_settings() -> void:
	if _baking:
		push_warning("VoxelTerrain4D2: a bake is already running.")
		return
	if not Engine.is_editor_hint() and not is_inside_tree():
		push_error("VoxelTerrain4D2: bake needs the node in the tree.")
		return
	_baking = true

	BRICK_CORE_CELLS = BAKE_BRICK_CORE_CELLS
	grid_size = BAKE_GRID_SIZE
	cell_size = BAKE_CELL_SIZE
	max_render_distance = BAKE_RENDER_DISTANCE

	# Without this, bricks near the eviction boundary relative to wherever the
	# camera happens to sit cycle generate -> evict -> re-request forever and
	# never converge. Trym measured a bake stalling at 4/8 bricks for over 30
	# minutes before the churn crashed the renderer.
	suppress_eviction = true

	var path: String = "user://%s" % bake_file_name
	print("[bake] starting: grid %d^4, brick %d, radius %.0f -> %s" % [
		grid_size, BRICK_CORE_CELLS, max_render_distance, path])

	var start_usec: int = Time.get_ticks_usec()
	generate()

	# Re-issue the same radius request each interval: generate() makes ONE
	# request pass, so a candidate whose task could not be queued right then
	# would otherwise never be retried.
	var expected_bricks: int = _expected_brick_count()
	var elapsed := 0.0
	var since_restream := 0.0
	var previous_generated_count := -1
	while true:
		await get_tree().create_timer(BAKE_PROGRESS_INTERVAL_SECONDS).timeout
		elapsed += BAKE_PROGRESS_INTERVAL_SECONDS
		since_restream += BAKE_PROGRESS_INTERVAL_SECONDS

		var generated_count: int = _generated_bricks.size()
		var in_flight: int = _bricks_in_flight.size() + _pending_brick_tasks.size()
		_set_bake_progress(_format_progress(generated_count, expected_bricks, in_flight, elapsed))

		if since_restream < BAKE_RESTREAM_INTERVAL_SECONDS:
			continue
		since_restream = 0.0
		print("[bake] t=%.0fs  bricks=%d/%d  in_flight=%d  tets=%d" % [
			elapsed, generated_count, expected_bricks, in_flight, _total_tet_count])
		_stream_bricks_in_radius(Vector4.ZERO, max_render_distance, _nominal_center)
		if in_flight == 0 and generated_count == previous_generated_count:
			break
		previous_generated_count = generated_count

	_set_bake_progress("writing %s ..." % bake_file_name)
	bake_to_file(path)
	var megabytes: float = FileAccess.get_file_as_bytes(path).size() / (1024.0 * 1024.0)
	var seconds: float = (Time.get_ticks_usec() - start_usec) / 1000000.0
	print("[bake] done in %.0fs: %d bricks, %d tets, %.1f MB -> %s" % [
		seconds, _generated_bricks.size(), _total_tet_count, megabytes, path])
	_set_bake_progress("done - %d bricks, %d tets, %.1f MB in %s" % [
		_generated_bricks.size(), _total_tet_count, megabytes, _format_clock(seconds)])
	suppress_eviction = false
	_baking = false


## Bricks the streaming pass will attempt, for the denominator. Candidates form
## a cube of ceil(grid_size / BRICK_CORE_CELLS) per axis, to the fourth power -
## 3^4 = 81 at the demo budget, matching the "19/81 chunks" in Trym's HUD. It
## is an upper bound, not a promise: a brick that resolves to pure air still
## counts as attempted but adds no geometry, so the bar can settle below 100%
## and that is correct rather than a stall.
func _expected_brick_count() -> int:
	var per_axis: int = maxi(1, ceili(float(grid_size) / float(BRICK_CORE_CELLS)))
	return per_axis * per_axis * per_axis * per_axis


func _format_progress(done: int, expected: int, in_flight: int, elapsed: float) -> String:
	var fraction: float = clampf(float(done) / float(maxi(1, expected)), 0.0, 1.0)
	var filled: int = int(round(fraction * float(BAKE_BAR_WIDTH)))
	var bar := "#".repeat(filled) + "-".repeat(BAKE_BAR_WIDTH - filled)
	# Only meaningful once something has finished; before that the rate is
	# undefined and any estimate would be invented.
	var eta := "estimating..."
	if done > 0 and fraction > 0.0:
		eta = _format_clock((elapsed / fraction) - elapsed) + " left"
	return "[%s] %d%%  %d/%d bricks, %d busy  |  %s elapsed, %s" % [
		bar, int(fraction * 100.0), done, expected, in_flight, _format_clock(elapsed), eta]


func _format_clock(seconds: float) -> String:
	var total: int = maxi(0, int(round(seconds)))
	return "%d:%02d" % [total / 60, total % 60]


## The Inspector only redraws a property when told to, so a plain assignment
## would sit stale for the whole bake - which is the exact problem this is here
## to solve.
func _set_bake_progress(text: String) -> void:
	bake_progress = text
	notify_property_list_changed()


## Same shape as the base implementation - [camera, rig, viewer_position in
## rig-local space] - but sourced from the rendering camera when one is known.
func _get_viewer_state() -> Array:
	if _render_camera == null or not is_instance_valid(_render_camera):
		return super()
	var rig: Node4D = (get_node_or_null(rig_path) as Node4D) if not rig_path.is_empty() else self
	if rig == null:
		return super()
	var inverse_basis: Projection = rig.global_basis.inverse()
	var viewer_position: Vector4 = inverse_basis * (_render_camera.global_position - rig.global_position)
	return [_render_camera, rig, viewer_position]
