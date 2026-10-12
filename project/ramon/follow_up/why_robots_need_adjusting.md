# Why the robots sometimes need adjusting (6 Oct 2026)

"Robots" here means the scripts that play the game for us, with no hands on the keyboard:

- **tests** (`_verify_..._runner.gd`) set up a situation, act, and print PASS or FAIL per check;
- **capture scripts** (`_capture_..._runner.gd`) put the camera on set spots and save screenshots;
- **diagnostics** and **studies** (`_diagnose_...`, `_study_...`) print numbers to look at.

They run through `CreationLab/scripts/lab_run.sh` and write their logs to
`smoke_test_output/creation_lab/logs/`.

A robot knows the game only through its code: the names of nodes and settings, positions in the
world, which key does what. It is written against the game as it was that day. When the game
changes, the robot is not told. Then one of three things happens:

1. **It fails.** That's loud, which is good: someone looks.
2. **It passes while testing nothing.** That's silent, which is the dangerous one.
3. **It fails for a reason that isn't a bug.** That's noise: time spent hunting a problem that
   isn't there.

## Seven ways it happens here, each one seen in this project

### 1. A setting is renamed or removed, and Godot does not complain

On 4 Oct a teammate (4Denthusiast, commit b27ffa1) rebuilt the pen's camera so the slice tilt
and the heading are one rotation, matching the editor's 4D camera. The two old slice numbers
(`_slice_xw`, `_slice_zw`) were removed. Setting a property that doesn't exist does
nothing in Godot, with no error. So 24 robots that tilted the slice by setting those numbers
quietly stopped tilting it:

- the slice-plane tests failed (outcome 3: the game was fine);
- the dreamer test failed: the dreamer never came into view;
- the lookout and marsh-align tests kept passing without testing their tilted-slice part
  (outcome 2).

Fixed on 6 Oct (c2c90b5): `chickenpen/scripts/slice_angles_4d.gd` builds the same tilt the
robots always meant, in the new camera's terms, and all 24 use it.

### 2. The game changed on purpose

Since 22 Sept (50e8db7) Trym only gets up when you talk to him (F). His test still waited for him
to get up by himself, so it failed for two weeks. The robot was out of date, not the game.
Fixed in d9178dd: the test presses F. On the way it found a real bug: he aimed his turn from his
stool's spot rather than from where he stood.

### 3. Things moved

Since the units became movable (6 Oct) and layout A rearranged the field, anything a robot
wrote down as a world position may now point at empty grass. The cave-fade test's points in the tunnel were
written in field coordinates and had to be rewritten once the cave unit could move. The fix that
lasts: robots ask the unit where its
spots are (`CaveHill.to_world(...)`, the tower's `ladder_foot()`, the units' `...Arrival`
markers) instead of writing coordinates down.

### 4. Something was taken out or rebuilt

`_verify_talk` looks for `UI/Radar`, which no longer exists. `_verify_range` expects the old
shooting gallery, which the Quantum Range replaced. Both fail, and neither failure is a bug in
the game.

### 5. Someone else's update underneath

- When Aaron's fence generator replaced the old fence (4 Oct), 8 links the pen's fence code
  relied on came through empty. Returns stopped being counted, and the tests filled with about
  63,000 script errors. Fixed in Phase 0 of `PenLayout/PLAN.md`.
- After an engine pull, a newly added script class can show as "not declared" in robot runs
  until the project is rescanned (`godot --headless --path project --import` once).
- 9 old voxel-era robots call engine functions that never existed (`Math4D.noise_4d()`,
  `fastnoise2_4d()`). They are dead, and no pull broke them.

### 6. The robot only looked where it was told to

The cave's fade-to-black test checked the screen going dark inside the tunnel, and it passed.
Once layout A put the pen behind the hill, the screen also went black behind the hill, across
the pen's gate. No robot looked there, because the place didn't matter before. Fixed on 6 Oct,
and the test now checks behind the hill too. Earlier, on 21 Sept, eight robots passed while five
real gameplay bugs got through (chickens catchable through W, a catch cone pointing backwards,
and more). Robots check numbers; some bugs are a wrong experience with every number right.

### 7. The robot's own surroundings

- **Focus:** a robot window that loses focus misses its key presses. The balloon ride's burner
  check failed once and passed on the rerun. Newer robot windows refuse focus
  (`root.unfocusable`).
- **Sharing Godot:** several Claude windows share one Godot, so a robot can wait, time out, or
  never run. A lock file (`.claude/godot_in_use.txt`) takes turns.
- **Timing:** frame times measured headless are not real ones.

## How to tell which one it is

| What you see | Most likely | Look first at |
|---|---|---|
| Fails right after someone else's commit, in code you didn't touch | 1, 4 or 5 | `git log` for the files it uses; search the code for the name it sets |
| Fails after things were moved or rearranged | 3 | the positions written in the robot |
| Passes, but its screenshots don't change when they should | 1 | whether the robot's action still does anything |
| Fails once, passes on a rerun | 7 | focus, the lock, timing |
| Everything passes but it plays wrong | 6 | play it, capture frames, look at them |

## What we do when one breaks

1. **Decide first whether the game or the robot is wrong.** Read the history for what changed
   and why (`git log -S"_slice_xw"` finds the commit that removed a name). The dreamer fix came
   from reading b27ffa1, not from guessing.
2. **If it's the robot, port it and keep what it was meant to check.** Never loosen a check just
   to make it pass.
3. **Make the robot act the way a player does.** If it tests something the player does, like a
   drag or a key, it does exactly that: the drag-hint robot now drags through the camera's own
   drag, the way a mouse does.
4. **Translate once, in one place.** One helper for the slice, not 24 copies, so the next change
   is one fix.
5. **After a layout change, add checks for the new places.** The back of the hill is one.
6. **Look at the frames.** A green log is not the same as a game that plays right.

## Where things stand (6 Oct)

- **Fixed today:**
  - Trym (3 checks), the dreamer (1) and the slice plane (3);
  - 21 more robots that had been blind to the slice since 4 Oct;
  - the cave fade, which now checks behind the hill.
- **Still failing, older, not looked at yet:**
  - `_verify_sfx_mix` (4 checks);
  - `_verify_range` (the old gallery);
  - `_verify_talk` (`UI/Radar`);
  - the keeper's first speech, which comes up empty in its test.

  All are listed in `PenLayout/PLAN.md` under "Later".
- **Dead:** the 9 voxel-era robots above, and `_verify_shrubbery_phase2_runner.gd`, whose
  shrub code has moved on.
- **The lab prototypes** (Creation Lab, PathCreator, Arboretum) use a copy of the camera from
  before 4 Oct, so their robots still use the old slice numbers and work. If that copy is ever
  updated, the same port applies there.
