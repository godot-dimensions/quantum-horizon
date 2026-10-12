# w_gap — one room, one gap, one idea

Open `w_gap.tscn`. Walk forward. The gap is 7 m and you can jump 4.59 m, so it
cannot be crossed. Hold **ana** — the ground turns blue and a bridge is there.
Cross. Hold **kata** to come home.

That is the whole scene. It exists because the tower greybox had **no 4D content
in it at all** — it was a staircase with w as decoration, which is exactly why
slicing felt like nothing was happening. Nothing here exists except the verb.

## Verified by playing it, not by reasoning about it

```bash
engine/godot/bin/godot.windows.editor.double.x86_64.console.exe --path project --script res://ramon/ObstacleCourse/_w_gap_test.gd
```

`_w_gap_test.gd` presses the real input actions, drives the real controller, and
runs **with a renderer** (no `--headless`). It passes only if the player ends up
across the gap, back in the home band, still standing. Last run:

```
gap spans x -3.5 .. 3.5, bridge sits at w 5.0
  ok    reached the lip at x -4.92
  ok    shifted to w 4.67, in the bridge's band
  ok    crossed to x 5.08
  ok    returned to w 0.33
final: (5.17, 0.88, 0.00, 0.25)  lowest y reached 0.88
=== PASS: crossed an unjumpable gap using w, and came back ===
```

`lowest y reached 0.88` is the important one — it never fell. It writes
`wgap_phase*.png` per phase, so the run can be reviewed frame by frame.

## The ramp

Past the far ledge there is a ramp you **walk** up — no jumping. It is a rotated
box, but the rotation is on the MESH ONLY. A rotated `BoxShape4D` collides as its
enclosing axis-aligned box (measured: y grows ×5.11 at 15°, ×12.02 at 45°), so a
tilted collider is a huge invisible wall, nothing like the slope it draws.

The real collision is a flight of small axis-aligned steps hidden inside the
slab, each step's top centred on the drawn slope so the player's feet never sit
more than half a rise (~9 cm) from the visible surface. That only works because
`ascent_player_4d.gd` has step-up: with a 0.7 m allowance the steps are walked
straight over. Without it, even a 1 cm step stops you dead.

`ramp_tread` controls how closely the hidden steps hug the drawn slope. The
builder warns if a tread makes the rise per step exceed the step-up allowance.

## The two things that make it readable

**The ground is banded along w, each band a different colour.** This is the one
idea worth keeping from Miegakure, which textures the ground differently at
intervals along the fourth dimension so 4D space reads as a stack of parallel
worlds. Without it, sliding along w changes nothing on screen until something
abruptly pops in — a box either exists in your slice or it does not, and there is
no partial reveal to hint at what is next door. With it, the floor under your
feet changes colour the instant you leave a band, and no HUD is needed.

**Both ledges exist in every band; only the bridge is conditional.** If the
ground vanished too, sliding would read as falling out of the world rather than
as stepping sideways into another version of it.

## The bug this nearly shipped with

Bands were 4.4 m thick on 5.0 m spacing, leaving **0.6 m of pure nothing between
them**. The player is 0.5 m wide in w, so sliding across a boundary would drop
you into the void with no floor at all — an abyss with no cause you could see.
Band thickness is now *derived* from the spacing so bands always tile exactly.
Two bands that share a plane do not overlap, so this creates no interpenetration.

## Status of the tower

`ascent_wall.tscn` and `ascent.tscn` are **parked, not fixed**. Their geometry
checks pass but they are staircase towers with no 4D beats, and the fundamental
problem is design, not tuning. If this room feels right, the tower gets rebuilt
around this verb — the brief's nine beats are all variations of it (bypass a wall
through w, a bridge elsewhere in w, two walkways sharing a 3D footprint at
different w). If it does not feel right, nothing above it was worth building.
