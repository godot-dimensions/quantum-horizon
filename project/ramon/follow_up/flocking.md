# The murmuration over the pen (30 Sept 2026)

Ramon asked for research on how sparrow flocks and fish schools move, then "execute the 10
steps ... directly in the pen ... then you can test performance at the same time". What
was built, what was measured, what is still his call, and the traps found on the way.

## Where it is

- `chickenpen/flock/pen_flock_4d.gd`: the flock node (`World/Flock` in `chickenpen.tscn`).
  The model, the hawk, a GDScript step (CPU) and the GPU driver.
- `chickenpen/flock/flock_step.glsl`: the same model as a compute shader, five passes
  (count, scan, scatter, update, reduce).
- `chickenpen/flock/flock_bird.gdshader`: draws each bird. It moves the bird into the
  camera's frame and cuts it at the slice itself.
- `chickenpen/flock/flock_metrics_4d.gd`: the ruler. Order, milling, nearest neighbour,
  shape axes, border against middle, largest group, share in the slice.
- Runners in `chickenpen/scripts/`:
  - `_measure_flock_runner.gd`: headless metrics, turning waves via twin runs, agitation
    waves, CPU timing. Takes `set=name:value,...` for tuning.
  - `_capture_flock_runner.gd`: windowed views, calibration against real 4D boxes, a hawk
    pass, GPU timing. Takes `count=`, `backend=`, `hawk=` and `w_depth=`.
  - `_verify_flock_runner.gd`: headless. The flock sleeps with the pen and survives a trip.
  - `_record_flock_runner.gd`: a clip, made with `--write-movie`.
  - `_debug_flock_gpu_runner.gd`: reads the GPU buffers back and prints them.

## The model: boids plus four things from field studies

Reynolds' three rules (keep apart, align, move towards the others) work unchanged on
`Vector4`. On top of them:

1. **About 6.5 neighbours instead of a fixed radius.** Each bird adapts its own search
   radius, as Hemelrijk's StarDisplay does.
2. **Turning inertia.** The turn rate lags what the neighbours ask for, following Attanasi
   et al.'s inertial spin model.
3. **Cohesion scaled by centrality**, so border birds are pulled in hardest.
4. **A roost, an altitude spring and a band in W.**

Four fixes turned it from a scatter into a flock:

- **Level-flight damping.** Without it, the height and W springs rang against the turning
  lag and grew until the flock was 40 m tall.
- **Roost pull measured from the flock's middle.** Measured per bird, every U-turn tore
  the flock apart: the biggest group held 20–40% of the birds.
- **One turn side for the whole flock** when it is heading away from home. Otherwise half
  the flock turned each way.
- **A weak gather towards the middle.** It starts at a distance that grows with the cube
  root of the flock's size.

### Measured against the field data

300 birds, CPU, headless.

| | Ours | Field data |
|---|---|---|
| Order | 0.99–1.00 | 0.96–0.99 (ours is a little too rigid) |
| Nearest neighbour | 0.75–0.9 m | 0.7–1.5 m |
| Shape (thin : mid : long) | 1 : 2–2.7 : 5–7, flat and level | 1 : 2.8 : 5.6 |
| Border against middle spacing | 1.0–1.2 | below 1 (border denser); not reached |
| Largest group | 1.00 until a hawk; it can split after one | |

### Waves

- **Turning waves**, twin runs with 10 birds holding a 60° turn for 1.5 s:
  - Plain boids: reached 5% of the flock and faded.
  - Alignment 14/s with 0.05 s inertia: reached 61–65% at 8.5 m/s without fading, with a
    5 m cell. With the 2.2 m cell now used, it reaches 29% and fades.
- **Agitation waves:** a bird copies a rolling neighbour after `reaction_delay`. The wave
  reached 100% of the flock:

  | Reaction delay | Wave speed (CPU) |
  |---|---|
  | 0.08 s | 9.2 m/s |
  | 0.12 s | 6.8 m/s |

  The default is 0.07 s, about 14 m/s on the GPU, which looks every frame rather than
  every third. Real agitation waves run at about 13 m/s.

## Cost

All measured in the pen on the RTX 5080: 1280×720, vsync off, flock switched on and off in
blocks of 40 frames.

| Birds | Where | Frame cost | GPU compute |
|---|---|---|---|
| 300 | CPU | 1.65 ms (1.55 ms of it the GDScript step, 3.4 µs a bird; 4.2 µs with the hawk code) | |
| 2,000 | GPU, 5 m cell | 0.42 ms | 0.39 ms |
| 5,000 | GPU, 2.2 m cell, spread out | 0.38 ms | 0.27 ms |
| 5,000 | GPU, 2.2 m cell, after a hawk | 0.79 ms | 0.68 ms |
| 10,000 | GPU, 2.2 m cell, spread out | 0.52 ms | 0.34 ms |

- A 5 m cell after a hawk cost 2.85 ms. The cell size is what sets the GPU cost.
- Drawing is about 0.1 ms: one multimesh, one draw call.
- The flock sleeps with the pen. The cinema and cave hide and disable `World`; a laptop
  trip takes the pen out of the tree.

## Still Ramon's call

- **Sparrows or starlings.** Built as a starling murmuration. Sparrows would be small
  flocks rolling along the ground, flushing all at once.
- **Depth in W** (step 7). Thin (0.25 m) reads as a 3D flock. Deep (4 m) shows a sparser,
  different flock at each w, and a thin clump through a turned slice. Frames are in
  `smoke_test_output/w_4` and `w_0.25`.
- **Grid cell 2.2 m or 5 m.** 2.2 m halves the GPU cost; 5 m keeps turning waves from
  fading.
- **Bird count** (5,000 now), **how often the hawk comes** (every 25–45 s, the first at
  12 s), and whether the dark band reads well enough or needs faking with colour.
- **Skipped by the plan's own rule:** curl-noise art direction (the rules already flow)
  and the dusk gathering.

## Traps found (engine and Godot)

1. **An instance whose AABB has no surface is never drawn, whatever `ignore_culling`
   says.** `renderer_scene_cull.cpp` `_update_instance` returns before indexing it. A
   multimesh never given a buffer by `set_buffer` has an empty AABB, so the GPU flock
   stepped perfectly and drew nothing. Fix: `instance_set_custom_aabb`.
2. **`multimesh_set_buffer` while any viewport wants motion vectors (TAA, FSR2) doubles
   the buffer** and points drawing at its second half (`mesh_storage.cpp`). A compute
   shader writing the first half would be invisible, so the GPU path never calls
   `set_buffer`.
3. **`get_captured_timestamp_gpu_time` returns nanoseconds.** The docs say microseconds.
4. **Double-precision build: `Vector4` holds doubles**, so `PackedVector4Array.to_byte_array()`
   is not a float buffer. Pack 32-bit floats by hand.
5. **The Cross-section engine draws in camera space** (its 3D camera has no transform).
   Any 3D instance in `viewport.find_world_3d().scenario`, placed at camera-relative
   coordinates, lands in the same picture. `RenderingServer4D.pre_render` is the moment
   to set the camera uniforms.
6. **Toggling a GPU cost every other frame measures a negative cost.** The GPU runs a
   frame or two behind; toggle in blocks.
7. **A windowed test can still catch a keystroke** before `root.unfocusable` takes hold:
   Ramon's "c" opened the cinema over a run. Flock runners turn off every
   `debug_key_enabled` in the pen.
8. **`.glsl` compute shaders are only imported by the editor.** Runners launched with
   `--script` compile from the text (`RDShaderSource`) when there is no import.
