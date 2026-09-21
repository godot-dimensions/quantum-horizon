# Chickenpen walk — what is still wrong, and why

Parked deliberately, 21 Sep 2026. The walk works and plants its feet; it does not yet
look good. Ramon's note: "still not perfectly happy — knees still very bent."

## Where it actually stands

Measured as the angle between thigh and shin in world space, 0 = straight leg:

| | now | a person |
|---|---|---|
| knee at mid-stance | **19°** | ~5–10° |
| knee at swing | **106°** | ~65° |
| shoulder swing | ±31° | ±30° |
| cadence at 2.4 units/s | 1.8 steps/s | ~1.8 |
| foot plant error | 0.003 mean, 0.037 worst | — |

So the STANCE leg is close to right. The remaining fault is the SWING leg over-folding
by about 40°, which is what reads as "very bent" — the eye catches the folded leg, not
the straight one.

## Why the swing leg folds so far

The foot lifts by `step_height` and arcs forward. Lifting it brings it CLOSER to the
hip, and a two-bone leg has only one way to take up slack: fold. The fold is not
authored anywhere, it falls out of the triangle, so it cannot be tuned down directly -
only the target it is solving for can change.

## The deeper conflict, which is worth knowing before spending time here

Stride length and straight knees pull against each other whenever the hip is held at a
fixed height. A long step needs the foot far from under the hip, which needs a long leg
relative to hip height, which means more bend at every other moment. Pushed either way
it breaks: legs shorter than the hip is high gave a stride of ZERO and a character
marching on the spot; legs much longer gave a permanent squat.

Real walking escapes this with three things this rig does not have:

1. **A heel-toe roll.** The ankle extends at toe-off, which lengthens the leg exactly
   when it is furthest back. This is the big one, and it needs an ankle joint - the boot
   is currently rigid to the shin, so it tips with the leg instead of staying flat.
2. **A pelvis that drops at double support.** There is a rise at mid-stance now, but no
   matching dip at the stride extremes, which is where the reach runs out.
3. **Hip rotation about the vertical**, which lengthens a step without lengthening a leg.

## Cheapest things to try first

- Lower `step_height` on the Gait node. It is the direct cause of the swing fold.
- Keep the swing foot further forward through its arc rather than letting it pass close
  under the hip - a flatter arc folds the knee less.
- Add the ankle joint. It fixes the boot tipping as well, which is the other visible
  artefact, and it is the thing that would let the stride grow without a deeper crouch.

None of this is blocking. The walk plants, the cadence is right, and the controller is
playable.
