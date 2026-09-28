# Enclosed spaces in 4D — the rule, and a prompt that produces it

**28 September 2026.** Trym's spike note of 25 Sept: *"a quick little spike on 4D 'house'
design which we can apply to all enclosed spaces like the chicken pen, the little shed
thing, all the activity booths etc, so that we don't get quite as many missing walls and
empty spaces when rotating and strafing around in 4D ... we need to figure out a more
consistent way to prompt to get spaces that fill out and enclose more properly."*

## Why they were holey

Every building in the pen was a **3D building extruded through W**: four walls, a floor and
a roof, each given some depth along W so it would not vanish. That gives six boundaries.
A room in four dimensions has **eight** — minus and plus x, y, z **and w**. Nothing capped
the two ends of W, so:

- **Strafe along W** and you walk out of the end of the slab into the field.
- **Turn the slice a quarter through W** and you look straight out of the open end.

From the home slice you never notice, which is why it survived.

## The rule

1. **Eight walls, not six.** Add the two W walls: the room's whole footprint (x by z), full
   height, thin in W, at both ends of its W depth — just inside the ends, so they cap the
   room without poking out of it.
2. **Everything else keeps real W depth**, the full depth of the room, or it vanishes when
   the slice turns — floor, roof, the four ordinary walls, and anything the player is meant
   to stand on or look at.
3. **Match the W depth to the footprint where you can.** A room 6 m long and 3 m deep in W
   halves in length when you turn a quarter into W. The Miegakure note in this folder says
   the same about props: matching the z and w extents is what stops them ballooning and
   shrinking mid-rotation.
4. **Doorways only on the ordinary walls.** A doorway in a W wall is a way in from a
   direction nobody can see coming.
5. **If there is a cutaway, give the W walls normals along W** and let the same dot product
   decide. It is already four-dimensional; it hides a near W wall from a rotated camera
   exactly as it hides a near side wall from an ordinary one.

Applied so far: `pen_shed_4d.gd` (`_close_in_w`, on by default) and `pen_coop_4d.gd`.
**Not** the pen fence — Aaron's procedural fence, *"arbitrary shapes, enclosed in 4
dimensions"*, is due in a day or two and replaces it.

## The prompt

Paste this when asking for any enclosed space:

```
Build this as a closed room in FOUR dimensions, not a 3D room stretched through W.

- It has eight walls: -x, +x, -y (floor), +y (roof), -z, +z, AND -w, +w. The two W walls
  are the room's whole footprint, full height, thin in W, sitting just inside both ends
  of its W depth. From the home slice they must not be visible at all.
- Every other part - floor, roof, the four ordinary walls, anything stood on or looked at -
  has the room's full W depth, never a thin one.
- Make the W depth close to the footprint's size, so turning the slice a quarter into W
  does not squash the room.
- Doorways go in the ordinary walls, never in a W wall.
- If the room hides walls between the camera and its inside, give the W walls outward
  normals along W and use the same test for all eight.

Then prove it: capture the room from the home slice, from a quarter turn through xw, and
from the edge of its W depth. The first should look like it always did; the other two must
show walls, not the field.
```

## How to check a room

`scripts/_capture_enclosure_runner.gd` turns the slice a quarter through W in front of
Trym's shed and captures it with the W walls off, then on. Off, the view is a roof beam and
a floor with the field visible through the middle; on, it is a solid room.
