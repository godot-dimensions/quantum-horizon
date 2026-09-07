class_name Noise4D
extends RefCounted
## Hash-based 4D value noise with multilinear (16-corner) interpolation and
## fractal octave summation. No dependency on any external noise library -
## this project has no 4D-capable noise generator, so this hand-rolls the
## minimum needed to drive SingleVertexDualContour4D's density field.
##
## Performance note: this is called once per grid point per octave (so
## tens of millions of times for a full terrain generation), so the hot
## path deliberately avoids allocating anything per call - no array
## literals in _hash4i, and PackedFloat64Array (a real packed native array)
## instead of Array[float]/Array[Variant] for the corner/interpolation
## scratch space in value_noise().

var seed: int

func _init(p_seed: int = 0) -> void:
	seed = p_seed

## Integer hash over (seed, i, j, k, l) - a one-at-a-time-style avalanche
## mix, folded once per axis. All intermediate values are masked to 32 bits
## so the bit-shifts behave the same regardless of GDScript's 64-bit int.
## Manually unrolled (no `for v in [i, j, k, l]`) to avoid allocating a
## throwaway array on every one of the millions of calls this gets.
func _hash4i(i: int, j: int, k: int, l: int) -> int:
	var h := seed
	h = (h + i) & 0xffffffff
	h = (h + (h << 10)) & 0xffffffff
	h = (h ^ (h >> 6)) & 0xffffffff
	h = (h + j) & 0xffffffff
	h = (h + (h << 10)) & 0xffffffff
	h = (h ^ (h >> 6)) & 0xffffffff
	h = (h + k) & 0xffffffff
	h = (h + (h << 10)) & 0xffffffff
	h = (h ^ (h >> 6)) & 0xffffffff
	h = (h + l) & 0xffffffff
	h = (h + (h << 10)) & 0xffffffff
	h = (h ^ (h >> 6)) & 0xffffffff
	h = (h + (h << 3)) & 0xffffffff
	h = (h ^ (h >> 11)) & 0xffffffff
	h = (h + (h << 15)) & 0xffffffff
	return h

## Deterministic pseudo-random value in [-1, 1] for one integer lattice point.
func _hash4f(i: int, j: int, k: int, l: int) -> float:
	return (float(_hash4i(i, j, k, l)) / float(0xffffffff)) * 2.0 - 1.0

static func _smootherstep(t: float) -> float:
	return t * t * t * (t * (t * 6.0 - 15.0) + 10.0)

## Single-octave value noise, continuous in all 4 dimensions, range [-1, 1].
##
## Unrolled into scalars rather than the PackedFloat64Array-based
## corner/reduction buffers this used to build fresh on every call - that
## was 4 heap allocations per call (16 corners + 3 reduction passes),
## exactly the kind of per-call allocation this file's own top comment
## already says the hot path avoids elsewhere (_hash4i's manual unroll),
## just not followed through here. Measured, not theoretical: sampling a
## few hundred thousand points during a voxel-world showcase's load
## turned into 70+ real seconds because of this, at a call volume where
## GDScript's allocator overhead dominates. The reduction order (w, then
## z, then y, then x) and corner-to-axis mapping are unchanged from the
## array-based version, so output is bit-identical - this is a pure
## allocation removal, not a redesign.
func value_noise(p: Vector4) -> float:
	var base := Vector4(floor(p.x), floor(p.y), floor(p.z), floor(p.w))
	var f := p - base
	var fade := Vector4(_smootherstep(f.x), _smootherstep(f.y), _smootherstep(f.z), _smootherstep(f.w))
	var ix := int(base.x)
	var iy := int(base.y)
	var iz := int(base.z)
	var iw := int(base.w)

	# 16 corners, named c<x><y><z><w> by which corner of the hypercube each
	# 0/1 offset picks - matches the old corners[bi*8+bj*4+bk*2+bl] indexing
	# exactly, just held in scalars instead of array slots.
	var c0000 := _hash4f(ix, iy, iz, iw)
	var c0001 := _hash4f(ix, iy, iz, iw + 1)
	var c0010 := _hash4f(ix, iy, iz + 1, iw)
	var c0011 := _hash4f(ix, iy, iz + 1, iw + 1)
	var c0100 := _hash4f(ix, iy + 1, iz, iw)
	var c0101 := _hash4f(ix, iy + 1, iz, iw + 1)
	var c0110 := _hash4f(ix, iy + 1, iz + 1, iw)
	var c0111 := _hash4f(ix, iy + 1, iz + 1, iw + 1)
	var c1000 := _hash4f(ix + 1, iy, iz, iw)
	var c1001 := _hash4f(ix + 1, iy, iz, iw + 1)
	var c1010 := _hash4f(ix + 1, iy, iz + 1, iw)
	var c1011 := _hash4f(ix + 1, iy, iz + 1, iw + 1)
	var c1100 := _hash4f(ix + 1, iy + 1, iz, iw)
	var c1101 := _hash4f(ix + 1, iy + 1, iz, iw + 1)
	var c1110 := _hash4f(ix + 1, iy + 1, iz + 1, iw)
	var c1111 := _hash4f(ix + 1, iy + 1, iz + 1, iw + 1)

	# Reduce along w, then z, then y, then x - same order as before.
	var w000 := lerpf(c0000, c0001, fade.w)
	var w001 := lerpf(c0010, c0011, fade.w)
	var w010 := lerpf(c0100, c0101, fade.w)
	var w011 := lerpf(c0110, c0111, fade.w)
	var w100 := lerpf(c1000, c1001, fade.w)
	var w101 := lerpf(c1010, c1011, fade.w)
	var w110 := lerpf(c1100, c1101, fade.w)
	var w111 := lerpf(c1110, c1111, fade.w)

	var z00 := lerpf(w000, w001, fade.z)
	var z01 := lerpf(w010, w011, fade.z)
	var z10 := lerpf(w100, w101, fade.z)
	var z11 := lerpf(w110, w111, fade.z)

	var y0 := lerpf(z00, z01, fade.y)
	var y1 := lerpf(z10, z11, fade.y)

	return lerpf(y0, y1, fade.x)

## Fractal (multi-octave) noise, normalized back to roughly [-1, 1].
##
## SPIKE INSTRUMENTATION (temporary - see Terrain4DProfile): times only
## this function's own body, so the profiling sweep can separate "noise
## math itself" from the surrounding sampling loop's own overhead
## (position construction, sign-check, array writes) - see
## _profile_terrain4d.gd. Remove the two Terrain4DProfile lines (and this
## paragraph) once the spike's numbers are captured; they are not part of
## the algorithm.
func fractal_noise(p: Vector4, octaves: int = 3, persistence: float = 0.5, lacunarity: float = 2.0) -> float:
	var _profile_t0 := Time.get_ticks_usec()
	var total := 0.0
	var amplitude := 1.0
	var frequency := 1.0
	var max_value := 0.0
	for i in range(octaves):
		total += value_noise(p * frequency) * amplitude
		max_value += amplitude
		amplitude *= persistence
		frequency *= lacunarity
	var result := total / max_value
	Terrain4DProfile.add("noise_fractal", Time.get_ticks_usec() - _profile_t0)
	return result
