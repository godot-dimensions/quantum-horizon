# The Lookout: a 4D photography subgame (plan, 1 Oct 2026)

Ramon, 1 Oct: "draw a plan of 70 steps, for the new gameplay element with the photography
thing ... work with the W, and make it immersive ... definitely add the balloon ... small
cutscenes for payoffs, or to create anticipation, but all within reason ... when you created
the 70 step plan, execute." Built in `chickenpen/chickenpen_lookout.tscn`, a scene that
INHERITS the pen: the pen file is not touched; the lookout's nodes move into the pen when
Ramon says so.

## The design in one page

**The fiction.** Wren keeps a fire-lookout tower at the edge of the field and a field journal
of everything that lives on the farm, "and some things that live next to it, along W". She
hands you her camera. The tower is a hide: from up there nothing sees you, and nothing blocks
you.

**The camera is the 4D idea.** Its focus ring does not focus in depth - it slides the camera's
slice along W, up to four metres either way, without moving you. A 4D body photographed off
its W-middle shows a smaller cross-section (radius sqrt(R^2 - w^2)), so "out of focus" is
literal: thin, small, half there. Focusing is finding a thing in W. The viewfinder's W-meter
shows a tick for every creature in front of you, at its W offset, so you can pull focus to
it - the subgame's locator gizmo. Bright ticks are pages you have not got yet.

**Photos are judged from the game's state at the shutter** (as Pokemon Snap does, not from
pixels): who is in frame, how big, how centred, how sharp in W, and what it is DOING - one to
four stars for how rare the behaviour is (New Pokemon Snap). The journal has a page per
subject with four star slots and the best photo in each.

**What you photograph**: the starlings (cruising / turning / the dark band / the hawk's hole),
the hawk, the crows, Nike, the cats, the chickens, the people - and three secrets: an owl that
sits on a post outside the north window but only at w +2.6 (only the focus ring finds it), a
white starling among 5,000, and a heron that stands in a marsh that exists only along W.

**The balloon** is the set piece: unlocked once you have found the owl and eight stars, it
lifts off the tower and drifts over the farm, through the murmuration and then slowly ANA -
the farm thins and vanishes as you leave its slice, and the marsh appears - to the heron.
36 shots, no reload, a whistle to make things look up. Pokemon Snap's rail, because a rail
solves the hardest problem in a 4D game: steering through W. The designer does it for you.

**Cutscenes, within reason**: the tower when you first come near (anticipation); the climb;
the owl turning its head through W when you first catch it; the balloon lifting off; the
heron taking off in slow motion when you get it (payoff).

## Research it rests on

- Bird hides: the slot about 1 m up, a dark inside and a back wall so no silhouette shows;
  stillness; bait brings animals close; 10-30 minute public visits, hours for photographers
  (Rewilding Europe hides guide; BirdLife South Africa; Nature TTL).
- Fire lookouts: a 2-4 m cab on a 10-50 m tower, windows all round, the Osborne Fire Finder
  (bearing and elevation), a lightning stool (Wikipedia; USDA).
- Games: Pokemon Snap (size, pose, centre, film, judged after), New Pokemon Snap (1-4 star
  behaviours, items that provoke behaviour, a dex that wants one of each), Pokemon GO
  (photobombs found in review), Fatal Frame (the camera sees what the eye can't),
  Umurangi Generation (lenses, a bounty list), Alba (species checklist), Shutter Stroll and
  Lushfoil (manual focus, a focus lock), game-dev photography articles (tactile shutter
  feedback; an album that is a pleasure to browse; scoring changes the mindset, so keep it
  about discovery).

## The 70 steps

### A. Ground work
1. Write this plan; folder `chickenpen/lookout/`.
2. The inherited scene `chickenpen/chickenpen_lookout.tscn`: the pen plus a `Lookout` node.
3. A smoke runner that loads it headless and windowed and checks the pen still runs inside it.
4. Measure the ground: a height probe over the hills mesh for where the tower and marsh go.
5. Choose the spots with frames from the spawn point (tower near (-16, 0, -36)).
6. Commit; the lock routine on every Godot run.

### B. The tower
7. `lookout_tower_4d.gd`: a fire-lookout frame - legs, braces, a stair/ladder face.
8. The cab: a closed 4D room (eight walls), windows all round at sill height ~1 m, a roof.
9. Window frames that frame the view from inside (mullions, a sill shelf).
10. The ana post: a perch outside the north window that exists only at w +2.6.
11. Colliders for the legs only (box physics), so you walk round it, not through it.
12. The base: a small platform, a sign, the ladder foot with an F prompt.
13. Frames from the field, from the deck, and with the slice turned (eight walls hold).
14. Frame cost: the pen with and without the tower.

### C. The camera (scope mode)
15. `lookout_station_4d.gd`: F at the ladder climbs; the player is parked and hidden; the
    farm's HUD hides; a first-person camera at the cab window.
16. Mouse look with limits, eased; Esc or F climbs down and gives everything back.
17. Zoom 1x-10x on the wheel, eased, with the lens's field of view.
18. The focus ring: E/Q slide the camera's slice along its own W, +-4 m, eased.
19. RMB tilts the slice through W, R straightens it - the pen's own controls, kept.
20. The viewfinder overlay: frame lines, centre mark, zoom readout, film counter.
21. The W-meter: the focus scale with a tick per subject ahead at its W offset.
22. The shutter: mirror blackout, flash edge, click and winder sounds, film count.
23. Rolls: 24 shots; in the cab an empty roll reloads itself (a 1.2 s winder), the
    balloon carries one roll of 36.
24. Runner: climb, look, zoom, focus, shoot, climb down; the pen's state given back.

### D. Judging photos
25. `photo_subject_4d.gd`: an adapter per subject, reading its state by duck typing - nothing
    in the pen's own scripts changes.
26. Subjects: Nike (walk/root/lie/hop), crows (perched/flying/take-off/landing), cats,
    chickens, people, the flock, the hawk.
27. `photo_judge_4d.gd`: in frame, behind, W-sharpness, apparent size, centring, stars, points.
28. The flock as a subject: birds in frame (a readback at the shutter), the band, the hawk.
29. A headless runner pinning subjects in front of a camera and checking the numbers.
30. The photo itself: the frame grabbed during the blackout, a thumbnail kept.
31. A toast: the subject, its stars, its points, "new page".
32. `field_journal_4d.gd`: pages, four star slots each, best photo per slot, saved to user://.
33. Runner: a photo of Nike lands on her page with the right stars.

### E. The journal and the HUD
34. The Journal card in the right column (under Cinematics): pages found, stars, the roll,
    the next thing to do.
35. The camera picker moved under it (in the inherited scene only).
36. `journal_book_4d.gd`: J opens the book - page list, four slots with thumbnails, hints for
    slots not yet filled.
37. Arrow keys through pages, Esc closes; works on the ground and in the cab.
38. The book's style: the HUD's cards, one accent bar.
39. The farm's HUD hidden while in the cab; only the viewfinder, radio and toasts.
40. Frames of the card, the book and the viewfinder at 1280x720 and 1920x1080.

### F. The owl (first secret, teaches W)
41. `owl_4d.gd` + `owl.tscn`: body, round head with a facial disc, eyes, ear tufts, wings.
42. Its behaviours: sitting, looking at you, a wing stretch, its head turning through W.
43. On the ana post at w +2.6; hoots now and then (the sound is in every slice).
44. Owl reveal cutscene the first time you catch it: it turns its head through W.
45. Frames: invisible at focus 0, there at +2.6.
46. A copy in the creature showcase (`Model/rigged_creature_ramon.tscn`).

### G. Wren and the story
47. Wren: the shared block avatar, dressed (field vest, cap, binoculars), at the tower foot.
48. Her dialogue: the hand-over, the hide's rules, what she has never seen.
49. A radio: Wren's lines in the cab as subtitles that do not take input.
50. Story beats: first climb, first photo, the owl hint, the owl found, the balloon ready,
    the heron hint, the journal complete.
51. The approach cutscene: first time near the tower, the camera rises up it to the cab.
52. Runner: the story walks from meeting Wren to the balloon unlock.

### H. The balloon
53. `balloon_4d.gd`: a striped 4D envelope (loft), a wicker basket closed in W, ropes, a burner.
54. Moored at the tower deck; the burner breathes.
55. The ride: a smooth 4D path (x, y, z AND w) through planned beats, ~2.5 minutes.
56. Departure cutscene: ropes off, burner, the ground falls away.
57. The basket camera: free look within limits, zoom, focus, 36 shots, no reload.
58. The whistle (X): what can hear it looks up - Nike, the crows, the chickens, the heron.
59. The W leg: the balloon drifts ana; the farm thins and vanishes; Wren on the radio.
60. Landing and the hand-back; runner and frames along the whole ride.

### I. The marsh and the heron
61. `ana_marsh_4d.gd`: a pond, reeds, stones - all around w +8, nothing at w 0.
62. `heron_4d.gd` + `heron.tscn`: long legs, S-neck, dagger bill, a plume.
63. Its behaviours: standing, one leg up, stalking, the strike; it lifts off if you come on foot.
64. The heron payoff: slow motion, it takes off, the journal page goes gold.
65. A heron copy in the showcase.
66. Frames from the balloon and from the marsh on foot.

### J. Finish
67. The white starling: one bird in the flock, opt-in, found only with the long lens.
68. Sound: shutter, winder, burner, wind, owl, heron, radio click - baked loops like the flock's.
69. Performance and a regression pass: the pen's runners unchanged, the lookout's all green.
70. A short film of the lookout for the morning, and the handover notes.

Pivot rule: if a step fails or a better way shows up while building, take it, and write
down why here.
