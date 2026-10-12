# Walking creatures — recorded performance

Numbers for a deck slide in the shape of the Voxel Mining / Motion Lab ones. Unlike
those two, these are **a new benchmark run, not catalogue values** — the conditions are
stated below and the run is repeatable from the repo.

**Scene:** `project/ramon/Model/rigged_creature_ramon.tscn` — five procedurally walking
chickens, one walking brachiosaurus, and Trym's rigged creature, all animating at once.

---

## Slide numbers

| | value | label |
|---|---|---|
| **P1** | **~25 ms** | Per frame, seven creatures walking |
| **P2** | **~4.5 ms** | Per animated creature |
| **P3** | **73,020** | Tetrahedra in motion |

Caveat lines, in the style the other slides use:

> Drawing all 73,020 tetrahedra costs 1.2 ms of that frame. The cost is deformation,
> not geometry.
> One machine, one scene, vsync disabled. Not yet repeated across hardware.

---

## The full breakdown

Measured by switching ONE group off at a time and re-measuring, so each figure is
attributable rather than inferred:

| what is running | frame |
|---|---|
| everything walking | **25.20 ms** (40 fps) |
| five chicken walkers off | 2.60 ms |
| brachiosaurus walker off | 22.49 ms |
| Trym's six solvers off | 27.79 ms |
| everything frozen, still drawn | 1.99 ms |
| creatures hidden entirely | 0.80 ms |

Which gives:

| | cost |
|---|---|
| five chickens | **22.55 ms** (4.51 ms each) |
| brachiosaurus | **2.23 ms** |
| Trym's six solvers | **~0 ms** (measured -2.59, i.e. below the noise floor) |
| all animation | **23.21 ms** |
| drawing all 73,020 tetrahedra | **1.20 ms** |

**The two findings worth a stakeholder's attention:**

1. **Geometry is nearly free; deformation is the whole cost.** 73,020 tetrahedra draw in
   1.2 ms. Tetrahedron count is not the thing to optimise.
2. **Rigid transforms cost nothing; skinning costs everything.** Trym's creature moves by
   transforming nodes and does not register above the noise floor. The chickens and the
   brachiosaurus deform their meshes, and that is where 23 of the 25 ms goes — almost all
   of it the engine rebuilding a proxy mesh because vertices moved. The GDScript solving
   is ~0.2 ms per creature.

## The optimisation already banked

Posing a limb by moving its rig's control points makes the rig re-loft the whole limb.
Replacing that with skinning — bind each vertex to its bone once, then move vertices —
on the five chickens:

| | frame |
|---|---|
| re-lofting legs each frame | **79.31 ms** |
| skinning them instead | **19.76 ms** |

**4× faster**, same motion. Measured on the five-chicken scene before the brachiosaurus
was added.

Cost per tetrahedron per frame, for sizing future work:

| | per tet per frame |
|---|---|
| drawing it | ~0.15 us |
| deforming it (skinning) | ~2.5 us |
| re-lofting it | ~11 us |

## Behaviour, if a second slide wants it

| | |
|---|---|
| creatures animating simultaneously | 7 |
| gaits implemented | biped walk + feeding, quadruped walk |
| chicken foot lift / stride | 0.070 / 0.172 units, matching its authored gait exactly |
| brachiosaurus stance | each foot planted **60%** of the cycle |
| flock separation | five birds, closest approach **0.24** units against bodies 0.22 wide |
| feeding | 3 pecks per 26 s; ground travel **exactly 0.0000** units/frame while the beak is down |
| path | steering from fBm noise — no two birds' paths closer than 1.37 units on average |

## Conditions

Windows, RTX 5080, windowed 900x600, **vsync disabled**, 350 frames averaged per phase
after a 40-frame settle. 19 Sep 2026.

Vsync must be off: it quantises the frame to the 60 Hz beat, so a real cost shows up
either as nothing at all or as a whole missed frame. Headless runs are useless for this —
the dummy renderer never builds the proxy mesh the cost lives in.

Repeat with:

```
godot --resolution 900x600 --script res://ramon/Model/scripts/_measure_motion_metrics_runner.gd
```

## What is NOT established

- One machine only. Not repeated across hardware or driver versions.
- One scene and one creature mix. The per-creature figure is five chickens plus one
  sauropod, not a general "cost per creature".
- No headroom figure: nothing establishes how many creatures fit in a 16.7 ms budget,
  because the cost is dominated by an engine path that an incremental proxy update would
  change entirely.
- The brachiosaurus re-poses its mesh every third frame rather than every frame. That is
  a deliberate trade and it is in the 2.23 ms figure.
