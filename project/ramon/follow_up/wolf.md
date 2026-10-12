# The wolf (3 Oct 2026)

Ramon: "whats a pen without a wolf. when you're done with everything, start modelling a wolf in
model tscn, animate it. check it several times for proportions and oddities. when done, make it
appear only sometimes, and make it run into the pen, and jump out of it again. he will catch a
chicken in his mouth jump out of pen an eventually run out of slice. the chicken wont be eaten, it
just means you have to catch him again somewhere ... make the wolf look good. he won't arrive
often." Then: a cutscene, letterboxed, "a far shot if you're far ... then a closer shot of what
happens, medium close, and then the face with line", the line "did i just see a 4d wolf grab a 4d
chicken?", and how to handle where the player is: "I'll leave that up to you".

## Where things are

- **The model**: `Model/wolf.tscn`, a loft rig authored as balls (as Nike is), in pen metres:
  about 0.8 m at the shoulder, 1.3 m nose to rump, 1.6 m with the tail. Dark saddle, pale ruff,
  muzzle and legs, amber eyes (boxes on the rig, so they ride the bob), upright ears, a bushy
  tail to the hocks. Its own `Walker` (strider_walker.gd) with `blend_joints` on, so hips and
  knees bend (lofting_gotchas.md, "Joints that bend").
- **In the Model lineup**: `Model/model.tscn`, `Models/Wolf`, at x -3 beside the goat, scaled x4
  (the lineup's unit is 0.25 m), walking in place.
- **In the pen**: `World/Wolf` (the same scene, hidden until it comes) and `Systems/WolfRaid`
  (`chickenpen/wolf/wolf_raid_4d.gd`).
- **Runners**: `Model/_capture_wolf_runner.gd` (six views standing, then walking, with a 1.7 m
  post for scale, and its measured size), `chickenpen/wolf/_verify_wolf_raid_runner.gd` (the raid
  start to finish, a frame per beat, 15 checks).

## How it comes

- **Rarely**: a chance every 300 s (`every`), taken 35% of the time (`chance`), the first not
  before 240 s (`first_after`). Only when the farm is up, you are free (your input on, so not
  talking, in a cutscene, at the tower or flying, and not carrying a chicken), no film is playing,
  and at least one chicken is home and not all of them: it never undoes the ending.
- **Now, to look at it**: the debug card's **8** (`pen_debug_4d.gd`); it says why if it cannot.
- **The route**: in over the side of the pen away from you, so it comes towards you over it; to
  the nearest chicken on the floor (not in or on the henhouse), a lunge, the bird across its jaws;
  out over a side across your view and away from you; then 12 m on, drifting 1.4 m ana as it goes,
  so the slice cuts it thinner and thinner until it is gone. Each crossing is put where its camera
  can see it over the fence, not behind the henhouse, as near level with the chicken as that
  allows. It parts the grass as it runs (the grass's `add_walker`).
- **The chicken**: out of the pen's count the moment it is grabbed, flapping in the wolf's mouth,
  and set down loose where the wolf left the slice, 1.4 m ana (`exit_w`): home is there now, the
  locator finds it, and the count says one fewer.

## The cutscene (where you are stays put)

Your input is held and the HUD hidden behind a letterbox; the camera is its own and you are not
moved. Shots:

1. **Your view**: from where your camera is, turning to the wolf, the lens closing in with its
   distance (it keeps the wolf about a fifth of the frame high), as it comes and leaps the fence.
   From more than 45 m off, from a point 24 m out on your side instead.
2. **Beside the pen**, at a crouch on your side: the run to the chicken, the grab, the run to the
   far fence (the lens racking in) and the leap out.
3. **From inside the pen**, behind it: it running off and out of the slice, the lens closing in so
   you see it thin out through W rather than shrink.
4. **Your face**, turned the way it went, and the line in the lower bar: "Did I just see a 4D wolf
   grab a 4D chicken?" Then everything is handed back.

## Checked (frames looked at, not only numbers)

Three passes on the model, each from six sides: the first read as a tan deer (too thin, small
head high on a long neck, warm greys gone tan in the dusk light); `w_scale` turned out to stretch a
section through W, not vertically, so the chest had got deeper in the wrong axis (`v_scale` is the
vertical one for a body along Z). The raid was filmed five times: the far shots were specks until
the lens was the 4D one (below), the henhouse hid both leaps, the leap out came at the camera, and
the hen sat upright on the wolf's nose before it was laid across its jaws.

## Traps

- **A Camera4D projects in 4D by default: its lens is `field_of_view_4d`.** Setting
  `field_of_view_3d` does nothing. The starlings film (cinematic_murmuration_4d.gd) sets the 3D one
  for its lens changes, so they have never applied; left as it is, Ramon's call.
- `v_scale` / `w_scale` on a ball, for a body along Z: `v_scale` is vertical, `w_scale` is
  through W (measured from the wolf's own vertices).

## Not done

- No sound: there is no wolf recording in the project. A growl as it lands and the hen squawking
  would sell it; Ramon's pick.
- It runs on flat ground in straight lines and does not path round hills; the route starts 16 m
  out from the pen, inside the open field.
