extends SceneTree

## The murmuration measured against the field data, headless - no pen, no window, just the
## flock stepped at a fixed rate. Three parts, each switchable:
##
##   metrics  every few seconds: order, milling, nearest-neighbour distance, the shape's
##            three axes, the border against the middle, neighbours seen, height, speed.
##            The targets are in flock_metrics_4d.gd.
##   wave     TWO copies of the same flock from the same seed, stepped in lockstep; at
##            wave_at seconds a few birds on one flank of ONE copy are sent off 60 degrees
##            to the side for 1.5 s, and mean it - startled birds, not a nudge that the
##            flock simply absorbs.
##            Every bird whose heading then differs between the copies by more than 12
##            degrees has been reached by the turn. Arrival time against distance gives the
##            wave's speed; the largest difference against distance says whether it fades.
##            Twins take everything else the flock was doing out of the measurement.
##   agitate  the dark band: at wave_at seconds a few birds on one flank start the escape
##            roll a hawk would set off, and every bird's first roll is timed. Arrival time
##            against distance gives the agitation wave's speed - about 13 m/s measured over
##            real murmurations (Hemelrijk et al. 2015) - and the share reached says whether
##            it crosses the flock or dies out.
##   timing   the CPU cost of a step at several flock sizes, in microseconds. GDScript is
##            the same speed headless, so this one number is real without a window.
##
##   godot... --headless --path project --script res://ramon/chickenpen/scripts/_measure_flock_runner.gd
##       -- count=300 seconds=40 parts=metrics,wave,timing set=turn_inertia:0.0,rule_alignment:3
##
## `set=` overrides exports on the flock by name before it starts, so a tuning pass is one
## command per setting rather than an edit per setting.

const FLOCK := preload("res://ramon/chickenpen/flock/pen_flock_4d.gd")
const METRICS := preload("res://ramon/chickenpen/flock/flock_metrics_4d.gd")
## The game's rate: the social rules run for a third of the birds a frame, so at 60 fps a
## bird looks at its neighbours 20 times a second, and wave speeds depend on that.
const DT := 1.0 / 60.0

var _count: int = 300
var _seconds: float = 40.0
var _parts: PackedStringArray = ["metrics", "wave", "timing"]
var _settings: Dictionary = {}
var _wave_at: float = 25.0
var _sizes: PackedInt32Array = [100, 200, 300, 500]


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var kv: PackedStringArray = arg.split("=", true, 1)
		if kv.size() != 2:
			continue
		match kv[0]:
			"count":
				_count = int(kv[1])
			"seconds":
				_seconds = float(kv[1])
			"parts":
				_parts = kv[1].split(",")
			"wave_at":
				_wave_at = float(kv[1])
			"sizes":
				_sizes = PackedInt32Array(Array(kv[1].split(",")).map(func(s: String) -> int: return int(s)))
			"set":
				for pair in kv[1].split(","):
					var p: PackedStringArray = pair.split(":")
					if p.size() == 2:
						_settings[p[0]] = float(p[1])
	print("FLOCK MEASURE  count %d  seconds %.0f  parts %s  set %s" % [_count, _seconds, ",".join(_parts), str(_settings)])
	if "metrics" in _parts:
		_metrics()
	if "wave" in _parts:
		_wave()
	if "agitate" in _parts:
		_agitate()
	if "timing" in _parts:
		_timing()
	print("FLOCK MEASURE: done")
	quit()


func _make(n: int) -> Node4D:
	var flock: Node4D = FLOCK.new()
	flock.set("count", n)
	flock.set("manual", true)
	# CPU on purpose, so Auto's cut to cpu_count does not apply.
	flock.set("backend", 1)
	for key in _settings:
		var current: Variant = flock.get(key)
		if current == null:
			print("   ! no setting called %s" % key)
			continue
		flock.set(key, int(_settings[key]) if typeof(current) == TYPE_INT else _settings[key])
	root.add_child(flock)
	return flock


func _metrics() -> void:
	print("-- metrics  (targets: order 0.96-0.99, nearest 0.7-1.5 m, shape 1 : 2.8 : 5.6 thin axis vertical, border/middle < 1)")
	var flock: Node4D = _make(_count)
	var t: float = 0.0
	var next_report: float = 5.0
	while t < _seconds - 0.001:
		flock.call("step", DT)
		t += DT
		if t >= next_report - 0.001:
			next_report += 5.0
			_report(flock, t)
	flock.free()


func _report(flock: Node4D, t: float) -> void:
	var pos: PackedVector4Array = flock.call("positions")
	var head: PackedVector4Array = flock.call("headings")
	var sample := PackedInt32Array()
	for i in range(0, pos.size(), maxi(pos.size() / 60, 1)):
		sample.append(i)
	var nearest: float = METRICS.mean(METRICS.nearest_distances(pos, sample))
	var shape: PackedFloat32Array = METRICS.shape(pos)
	var thin: float = maxf(shape[0], 0.001)
	var edge: Vector2 = METRICS.edge_and_middle(pos, flock.call("centralities"))
	var seen: PackedInt32Array = flock.call("neighbour_counts")
	var seen_sum: int = 0
	for s in seen:
		seen_sum += s
	var c: Vector4 = METRICS.centre(pos)
	var roost: Vector4 = flock.get("roost")
	var y_lo: float = INF
	var y_hi: float = -INF
	for p in pos:
		y_lo = minf(y_lo, p.y)
		y_hi = maxf(y_hi, p.y)
	print("   t %4.0f  group %.2f  order %.3f  mill %.2f  nearest %.2f m  shape 1 : %.1f : %.1f  (%.1f m thin, vertical %.2f)  W %.2f m  border/middle %.2f  seen %.1f  y %.0f..%.0f  from roost %.0f m" % [
		t, METRICS.largest_group(pos), METRICS.order(head), METRICS.milling(pos, head), nearest, shape[1] / thin, shape[2] / thin, thin, shape[3], shape[4],
		edge.x / maxf(edge.y, 0.001), float(seen_sum) / maxf(float(seen.size()), 1.0), y_lo, y_hi,
		Vector2(c.x - roost.x, c.z - roost.z).length()])


func _wave() -> void:
	print("-- wave  (a held 60 degree turn on one flank at %.0f s, twins compared; real turns cross at 20-40 m/s without fading)" % _wave_at)
	var a: Node4D = _make(_count)
	var b: Node4D = _make(_count)
	# No hawk: after one, the birds furthest out along a flank are stragglers it scattered,
	# not the flock's edge, and a turn they start reaches nobody.
	a.set("hawk_enabled", false)
	b.set("hawk_enabled", false)
	var t: float = 0.0
	while t < _wave_at - 0.001:
		a.call("step", DT)
		b.call("step", DT)
		t += DT
	var pos: PackedVector4Array = (a.call("positions") as PackedVector4Array).duplicate()
	var head: PackedVector4Array = a.call("headings")
	var mean_head := Vector4.ZERO
	for h in head:
		mean_head += h
	mean_head = mean_head.normalized()
	# The flank: the birds furthest to one side of the flock, across its heading.
	var side := Vector4(mean_head.z, 0.0, -mean_head.x, 0.0).normalized()
	var c: Vector4 = METRICS.centre(pos)
	var order: Array = range(pos.size())
	order.sort_custom(func(i: int, j: int) -> bool: return (pos[i] - c).dot(side) > (pos[j] - c).dot(side))
	var starters: int = maxi(pos.size() / 30, 3)
	var start_centre := Vector4.ZERO
	var away: float = deg_to_rad(60.0)
	for k in starters:
		var h: Vector4 = head[order[k]]
		var turned := Vector4(h.x * cos(away) - h.z * sin(away), h.y, h.x * sin(away) + h.z * cos(away), h.w)
		b.call("lead", order[k], turned, 1.5)
		start_centre += pos[order[k]]
	start_centre /= float(starters)
	var arrived := PackedFloat32Array()
	var biggest := PackedFloat32Array()
	arrived.resize(pos.size())
	arrived.fill(-1.0)
	biggest.resize(pos.size())
	biggest.fill(0.0)
	var threshold: float = cos(deg_to_rad(12.0))
	var elapsed: float = 0.0
	while elapsed < 6.0:
		a.call("step", DT)
		b.call("step", DT)
		elapsed += DT
		var ha: PackedVector4Array = a.call("headings")
		var hb: PackedVector4Array = b.call("headings")
		for i in pos.size():
			var d: float = clampf(ha[i].dot(hb[i]), -1.0, 1.0)
			if d < threshold and arrived[i] < 0.0:
				arrived[i] = elapsed
			biggest[i] = maxf(biggest[i], acos(d))
	# Fit arrival time against distance from where it started, starters left out.
	var sx: float = 0.0
	var sy: float = 0.0
	var sxx: float = 0.0
	var sxy: float = 0.0
	var m: int = 0
	var reach: float = 0.0
	var bins := [[0.0, 0], [0.0, 0], [0.0, 0]]
	var width: float = 0.0
	for i in pos.size():
		width = maxf(width, (pos[i] - start_centre).length())
	for k in range(starters, pos.size()):
		var i: int = order[k]
		var dist: float = (pos[i] - start_centre).length()
		var bin: int = mini(int(dist / maxf(width, 0.001) * 3.0), 2)
		bins[bin][0] += biggest[i]
		bins[bin][1] += 1
		if arrived[i] < 0.0:
			continue
		reach = maxf(reach, dist)
		sx += dist
		sy += arrived[i]
		sxx += dist * dist
		sxy += dist * arrived[i]
		m += 1
	var reached: float = float(m) / float(maxi(pos.size() - starters, 1))
	var slope: float = (float(m) * sxy - sx * sy) / maxf(float(m) * sxx - sx * sx, 1e-6)
	var speed: float = 1.0 / slope if slope > 1e-4 else INF
	var fade: String = ""
	for bin in bins:
		fade += "%.0f  " % (rad_to_deg(bin[0] / maxf(float(bin[1]), 1.0)))
	print("   started by %d birds; reached %.0f%% of the rest, out to %.0f m of %.0f m  -  speed %.1f m/s  -  largest turn near / middle / far: %s degrees" % [
		starters, reached * 100.0, reach, width, speed, fade])
	a.free()
	b.free()


func _agitate() -> void:
	print("-- agitate  (an escape roll started on one flank at %.0f s; real agitation waves run at about 13 m/s)" % _wave_at)
	var flock: Node4D = _make(_count)
	flock.set("hawk_enabled", false)
	var t: float = 0.0
	while t < _wave_at - 0.001:
		flock.call("step", DT)
		t += DT
	var pos: PackedVector4Array = (flock.call("positions") as PackedVector4Array).duplicate()
	var head: PackedVector4Array = flock.call("headings")
	var mean_head := Vector4.ZERO
	for h in head:
		mean_head += h
	mean_head = mean_head.normalized()
	var side := Vector4(mean_head.z, 0.0, -mean_head.x, 0.0).normalized()
	var c: Vector4 = METRICS.centre(pos)
	var order: Array = range(pos.size())
	order.sort_custom(func(i: int, j: int) -> bool: return (pos[i] - c).dot(side) > (pos[j] - c).dot(side))
	var starters: int = maxi(pos.size() / 50, 3)
	var start_centre := Vector4.ZERO
	for k in starters:
		flock.call("startle", order[k], 1.0)
		start_centre += pos[order[k]]
	start_centre /= float(starters)
	var first := PackedFloat32Array()
	first.resize(pos.size())
	first.fill(-1.0)
	var elapsed: float = 0.0
	while elapsed < 5.0:
		flock.call("step", DT)
		elapsed += DT
		var ag: PackedFloat32Array = flock.call("agitation")
		for i in pos.size():
			if first[i] < 0.0 and ag[i] > 0.9:
				first[i] = elapsed
	var sx: float = 0.0
	var sy: float = 0.0
	var sxx: float = 0.0
	var sxy: float = 0.0
	var m: int = 0
	var width: float = 0.0
	var reach: float = 0.0
	for k in range(starters, pos.size()):
		var i: int = order[k]
		var dist: float = (pos[i] - start_centre).length()
		width = maxf(width, dist)
		if first[i] < 0.0:
			continue
		reach = maxf(reach, dist)
		sx += dist
		sy += first[i]
		sxx += dist * dist
		sxy += dist * first[i]
		m += 1
	var slope: float = (float(m) * sxy - sx * sy) / maxf(float(m) * sxx - sx * sx, 1e-6)
	var speed: float = 1.0 / slope if slope > 1e-4 else INF
	print("   started by %d birds; reached %.0f%% of the rest, out to %.0f m of %.0f m  -  speed %.1f m/s" % [
		starters, 100.0 * float(m) / float(maxi(pos.size() - starters, 1)), reach, width, speed])
	flock.free()


func _timing() -> void:
	print("-- timing  (CPU per step, GDScript, after 3 s of settling)")
	for n in _sizes:
		var flock: Node4D = _make(n)
		for k in 90:
			flock.call("step", DT)
		var total: int = 0
		var worst: int = 0
		var steps: int = 150
		for k in steps:
			var t0: int = Time.get_ticks_usec()
			flock.call("step", DT)
			var took: int = Time.get_ticks_usec() - t0
			total += took
			worst = maxi(worst, took)
		print("   %4d birds  mean %6.0f us   worst %6.0f us   %.2f us a bird" % [n, float(total) / steps, float(worst), float(total) / steps / float(n)])
		flock.free()
