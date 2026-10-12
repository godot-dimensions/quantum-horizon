# How a grey heron moves, and what the rigid rig does about it

Ramon, 2 Oct 2026: "the heron is still broken, it flies with the feet stretched out in
front. Make a proper case study how this creature behaves and moves and inform the rigid
animation system accordingly."

The bug he saw was a sign: the hip angle in flight was -1.35 rad, which under
`Basis4D.from_yz` swings a leg hanging down -y towards **+z**, the way the bird faces. It
should have been +1.35. Fixing the sign was one line; the rest of this is what the bird
actually does, so the other poses stop being guesses too.

Code: `chickenpen/lookout/heron_4d.gd`. Frames: `_capture_creature_runner.gd -- creature=heron`
(16 views, the last six one continuous flight).

## What the bird does

**Anatomy that matters for a rig.** The joint halfway down the leg that looks like a knee
bending backwards is the ankle (heel). The real knee is up against the body, hidden in the
feathers. So the visible leg is two bones: the tibiotarsus (hip to heel, the rig's "thigh")
and the tarsometatarsus (heel to foot, the "shank"). The neck is 20 or so vertebrae in a
permanent S; the kink near the middle is what lets it fold flat and fire forward.
(Sussex Wildlife Trust, "Bird legs and feet"; Kootenay Lake blog, "Heron heels".)

**Standing.** Neck in an easy S, head well up. Legs nearly straight, the heel just behind
the line from hip to foot.

**Resting.** On one leg, the other drawn up into the belly feathers; the head sunk onto the
shoulders, so the neck all but disappears.

**Foraging.** The field literature (Kushlan 1976, "Feeding behavior of North American
herons", The Auk 93) names the behaviours this bird uses:
- *Stand and wait*: motionless, either upright (neck extended) or crouched (body level,
  legs bent, neck partly drawn in).
- *Walk slowly*: one deliberate step at a time, so slow it merges into standing; each foot
  lifted high and set down carefully to disturb the water as little as possible, the toes
  closed as the foot comes out and opened as it goes down.
- The head is kept still while the body moves, then moved on: the neck takes up the
  difference, so the head glides rather than bobbing.
- *The strike*: the neck drawn back into a tight S, a pause, then shot out and down in a
  fraction of a second, bill into the water. Head up again; a fish is turned and swallowed
  head first, bill up, in gulps. A miss ends in a shake of the head.

**Take-off.** A crouch, a jump, wings open and a few hard beats with the legs still
hanging; then the legs swing back and the neck folds in as it levels off.

**Flight.** Neck pulled right back so the head rests on the shoulders, with a bulge of neck
under the chest; legs straight out behind, well past the tail; slow, deep, bowed wingbeats
(the hands below the line of the arms), one of the slowest wing actions of any common bird.
Pennycuick's wingbeat formula puts a 1.5 kg bird with a 1.7 m span near 2.8 beats a second;
field descriptions say slower, so the rig uses 2.3. (karits.eu, "Grey Heron (Ardea cinerea)";
Pennycuick 1990/1996 on wingbeat frequency.)

**Landing.** A glide in, losing height; just before landing the neck stretches out, the legs
drop and swing forward, the body tips up nearly vertical, and the wings flap forward as a
brake. The wings are often held up a moment after touchdown before they fold.

## What the rig does about it

The rig moves whole nodes and never re-lofts (lofting_gotchas.md: re-lofting costs about
70 times what drawing does). Every pose below is a handful of rotations.

| Behaviour | Before | Now |
|---|---|---|
| Legs in flight | forward (sign error) | straight back past the tail, toes turned in line with the leg |
| Neck in flight | upright S | `fly`: a bulge under the chest, head on the shoulders, bill level |
| Take-off | 0.45 s of the alert pose, then away | 0.25 s crouch on bent legs, the jump, hard 3 Hz beats with legs dangling, then legs and neck fold over about a second |
| Landing | legs reach forward, beats shrink | glide with wings held out and bowed, neck stretched, body tipping up; then upright braking flaps; wings held up a moment after touching down |
| Flight path | straight line plus a sine for height | a Bezier that climbs steeply off the water and comes down steeply, eased at both ends; 4 m/s |
| Wading | both legs on one sine, body gliding, feet sliding; a 180 degree snap at each end | one foot at a time with pauses; **feet planted** - each leg solved by two-bone IK from where its foot is, so nothing slides; the swing foot lifts 13 cm with its toes closed; a turn on the spot, stepping |
| Head while wading | fixed pose | the gliding head: `stalk_out` while the body waits, `stalk_in` while it catches up, so the head moves smoothly |
| Strike | neck snaps to one pose | coil back (0.45 s), the stab (0.11 s, accelerating), bill in the water, up again; a swallowed fish with gulps, or a head shake for a miss |
| Resting on one leg | upright S | `hunch`: head sunk on the shoulders; the lifted leg solved to tuck into the belly |
| Body lean | about the feet, so the hips swung and the feet slid | about the hips, so the legs hang from the same place whatever the body does |
| Wings | one box per wing on the shoulder | an arm and a hand on a wrist, so the beat bows; the downstroke is 60 percent of the beat |

**The IK, for anyone extending it.** `_leg_ik(target)` takes the foot's place from the hip as
(y, z) and returns the world angles of the two bones, in the same sense as
`Basis4D.from_yz`: a bone at angle `a` hangs along `(-cos a, -sin a)`, so 0 is straight down
and + is swung back. The heel is put behind the hip-to-foot line, as a bird's is. Pivots get
the differences: hip = thigh - lean, heel = shank - thigh, foot = foot - shank. Every bone
was rebuilt to hang straight down its own pivot so the solve is exact.

**Neck poses** are four relative tilts (three segments and the head). A segment at a summed
angle `a` points along `(y, z) = (cos a, sin a)`; the bill points along `(-sin h, cos h)` for
the summed head angle `h`. So "bill down 50 degrees at the water" is `h = 0.87`, and a
pose's last number is whatever makes the sum come out there. The comments in `POSES` say
what each is for.

## Not done, and why

- The neck is still three rigid segments. A real heron's S curls smoothly; skinning it
  would cost ~2.5 us a cell a frame (about 1 ms for this neck), which is affordable if it
  matters. It reads as a heron at camera distances already.
- No fish-turning in the bill before the swallow; no preening; no wing-drying pose.
- The wading turn is a yaw on the spot while stepping. A real heron turns over two or three
  steps.

## Sources

- [Grey Heron (Ardea cinerea), karits.eu](https://karits.eu/index.php/2026/05/16/grey-heron-ardea-cinerea/) - flight posture, take-off, landing
- [Kushlan 1976, Feeding behavior of North American herons, The Auk 93](https://sora.unm.edu/sites/default/files/journals/auk/v093n01/p0086-p0094.pdf) - stand and wait, walk slowly
- [Bird legs and feet, Sussex Wildlife Trust](https://sussexwildlifetrust.org.uk/news/bird-legs-and-feet) - the heel that looks like a knee
- [Heron heels, Kootenay Lake blog](https://blog.kootenay-lake.ca/?p=8410) - the same, with the knee hidden by the wing
- [Pennycuick, Predicting wingbeat frequency and wavelength of birds](https://research-information.bris.ac.uk/en/publications/predicting-wingbeat-frequency-and-wavelength-of-birds/) - the wingbeat formula
