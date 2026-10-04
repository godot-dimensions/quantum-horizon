# Creation Gallery: the plan (4 Oct 2026)

Ramon, 4 Oct: build the original idea, the round gallery (my v1 sketch for the Creation Lab, which
became the W-stacked bays instead): six stations on a ring round a centre stage, every creature on
its own drum behind them, the entrance and a welcome card at the front. Third person, so a room you
see all at once is less disorienting than it would be in first person. A bright dev look and a dark
one on a toggle; the sci-fi presentation and the menu style of the Creation Lab. The avatar in
greys. **Built for an explainer cinematic from the start, with a play button.** And: whatever the lab
borrows from the pen (the playable world) is **carried over, not reused**, so the two can change
apart.

New scene: `res://ramon/CreationGallery/creation_gallery.tscn`. The Creation Lab is untouched as a
design; only its borrowed files change source (section A).

## What the research changed

| Finding | What it does to the gallery |
|---|---|
| Visitors turn right on entering a gallery unless something stronger pulls them; then they keep walking the way they started (Melton's right-turn bias, and human inertia; the strongest force is a goal they can see). | **The ring is mirrored from the sketch:** station 1 is front-right and the stations run anticlockwise, so the natural right turn meets the first idea. The hero on the centre stage is the visible goal that draws you in. |
| The first few metres inside an entrance are a transition: people are adjusting, not reading. | The welcome card stands about ten metres in, not at the door. |
| Labels are read in layers: a title in seconds, one idea in half a minute, detail only by those who stay (Serrell's interpretive labels). | Every card has three layers: a title and number readable from the path; the one idea when you step into the station's zone; the method, limits and measured numbers when you do its task. |
| Exhibits compete with exits, and a seen goal beats a sign. | The roster arc and the brachiosaurus are visible from the entrance as the far goal; the exit is behind you. |
| The explainer's most reliable shape is reveal and hold: start in compression, open onto the space, rest there; orbit to show a thing in the round, push in to explain it. | The cinematic opens in the dark entrance gate, cranes up to reveal the rotunda and holds; orbits the hero; pushes into each station; tracks along the roster; ends on the overhead mark, the gallery seen as the sketch drew it. |

## Layout (in metres; the sketch's grid is 2 m)

- Centre stage at the origin: a turntable 8 m across with a cyan ring (the hero turns through W on
  it now and then: W is the one thing the room is about).
- The path: a lit ring at radius 9.5 m, joined to the entrance by a straight lit walk along +Z.
- Six stations at radius 13.5 m, from 60 degrees right of the entrance round the back to 60 degrees
  left, 48 degrees apart. Each: a drum, a lectern facing the path, a learning zone ring on the path,
  a camera mark. 1 to 3 build (violet), 4 to 6 animate (blue).
- The roster: every other creature on its own drum on an arc at radius 25 m; the brachiosaurus on
  the big drum at the back, 32 m out.
- The entrance at 32 m, a gate; the welcome card and the play button about 10 m in.
- W: everything at W 0, except what is about W.

## The 70 steps

Every visible step ends with frames looked at by eye in both moods (bright is the default, dark the
toggle, both designed). One Godot at a time, the lock taken in the launching command. Commits by
explicit paths at the end of each section; nothing pushed.

### A. Carry over what the lab borrows (steps 1 to 8)
1. Map every file LabKit and the Creation Lab load from outside themselves, transitively.
2. Decide what is carried: everything under `ramon/` that is not the lab's own (the pen, the
   loft-modelling prototype, the hub). Shared project scripts (`res://scripts/`) and binary assets
   stay referenced; say so in the guide.
3. Copy into `LabKit/carried/`, mirroring the source paths, each file headed with where it came from
   and on which day. No `.uid` sidecars copied (duplicate UIDs would make Godot load the originals).
4. Strip `uid=` from copied scenes' ext_resource lines and headers, so they resolve by path.
5. Repoint every copied file's own preloads and paths to the carried copies.
6. Repoint LabKit and the Creation Lab (scripts, creature wrappers, step resources) to the copies.
7. Prove nothing outside the lab is loaded: a runner lists every resource the Creation Lab loads
   and fails on any path into the pen or the other prototypes.
8. The Creation Lab's lift, guided and perf runners pass again, in both moods.

### B. The space (steps 9 to 20)
9. `CreationGallery/` and the scene: room (moods, ground), clock, the gallery script.
10. The floor: a large disc of the dev grid, with the 2 m grid readable at the scale of the room.
11. The path: the ring and the entrance walk drawn as glow strips set into the floor, lime as in
    the sketch's colour key, dimmer in bright, brighter in dark.
12. The centre stage: a turntable 8 m across, a raised rim, the cyan W ring, a slow rotation.
13. Six station plinths at 13.5 m, sized to their exhibit, their part colour in the rim.
14. The lecterns: one per station, between drum and path, facing the path.
15. The learning zones: a ring on the path in front of each station, lit when you are in it.
16. The roster arc at 25 m: a drum per creature, sized to it, and the brachiosaurus's big drum.
17. The rotunda's edge: a low perimeter wall and columns beyond the roster, chamfered, so the room
    ends somewhere and frames the shots; an entrance gate in it.
18. Overhead: a light ring above the path and spokes to the centre (sci-fi, and it gives the
    overhead shot a shape).
19. Lighting for both moods: the bright studio; the dark room carried by pools on every exhibit,
    the path's glow and the centre ring.
20. Sightlines: frames from the entrance, the welcome card, and each zone, checked by eye; nothing
    tall between the path and a station.

### C. Moving through it (steps 21 to 30)
21. The player: the lab's third-person walker, carried over, recoloured in greys.
22. Start at the gate facing in; the camera framed so the hero and the roster read as the goal.
23. Zone detection by polling distance (an Area4D never fires on a teleport).
24. Approach: a station brightens and its card grows from title to idea as you come near.
25. The guide panel, reworded for free walking: where you are, which stations are done, the
    nearest one's task.
26. A small map in the corner: the gallery from above, as the sketch, with you on it.
27. Progress: a tick on the map and on the station for each task done; all six light the centre.
28. Keys: the Creation Lab's (V, U, Space, `.`, `,`, B, P, C, F3, H) plus the station's own;
    checked free against the walker and the orbit rig.
29. The camera near a station frames it: when you stand in a zone the camera eases to face the
    exhibit over your shoulder, and lets go when you walk on.
30. A runner that walks the ring with simulated keys and checks every zone triggers.

### D. The six stations (steps 31 to 44)
31. A station adapter: the Creation Lab's bay contents run as station exhibits (begin on entering
    the zone, end on leaving, their keys and overlays only while you are there).
32. Station 1, "A section you can shape": the ball, plus its shape controls (radius, squareness,
    roll, W stretch) re-lofted live, and the slice diagram.
33. Station 1's card in three layers, its task and measured numbers.
34. Station 2, "The skin, stage by stage": the wolf grown from its baked stages, the checks.
35. Station 2's card, task, numbers.
36. Station 3, "Mirror and symmetry through W": the symmetry creature turning through W, and the
    wolf's mirror shown as its authored half and its twin.
37. Station 3's card, task, numbers.
38. Station 4, "Coloured blocks": the wolf cut into its rigid pieces, apart and back.
39. Station 4's card, task, numbers.
40. Station 5, "Foot paths and contacts": the wolf in the Lines view, slow motion, the legend.
41. Station 5's card, task, numbers.
42. Station 6, "4D gaits and the cost ladder": Trym's creature with the footfall chart and the W
    offset, beside the four legs' cost ladder.
43. Station 6's card, task, numbers.
44. A runner that does every station's task and checks it ticks.

### E. The centre stage and the roster (steps 45 to 52)
45. The hero on the centre stage: the wolf walking, larger than life, turning through W on a slow
    timer (the cyan ring lights while it does).
46. The centre console: from here V switches every creature's view at once, the whole room.
47. The roster: every creature on its drum, facing the path, with name tags in range.
48. The nearest roster creature's card (its own texts) when you walk up to it.
49. Sleep by distance and joint bending only near you, as in the Hall.
50. The brachiosaurus at the back, on the big drum, lit as the far goal.
51. The finale for doing all six: the centre ring and the path light up in sequence.
52. Performance: under 8 ms a frame at 1280x720 from the gate, the centre and every zone.

### F. The presentation (steps 53 to 58)
53. Station signage: the big number and name on a tall sign behind each drum, in the part colour,
    readable from across the room.
54. The welcome card: what the gallery is, the order, the keys, and the play button.
55. The play button: a lit console by the welcome card; walk up and press K (or click it) to play
    the breakdown; the menu's WATCH opens the gallery straight into it.
56. Both moods tuned side by side for every shot in the cinematic.
57. Text: no em dashes, every claim a measured one or marked as observed.
58. A frame review of the whole gallery by eye, with fixes.

### G. The cinematic explainer (steps 59 to 66)
59. Camera marks: entrance, crane, overhead, centre orbit, each station (wide, close), the roster
    track, the brachiosaurus; red triangles as in the sketch, editable in the scene.
60. The director: a timeline of shots and beats, each beat a camera move (hold, push in, orbit,
    track, crane) with easing, captions and the station's demo on cue.
61. The script: the explainer's narration as captions, one idea per beat, in the station cards' words.
62. The opening: the gate in darkness, crane up into the rotunda, hold; the title.
63. The middle: the hero orbit, then the six stations in order, each demo running in shot.
64. The ending: the roster track, the brachiosaurus, then up to the overhead mark: the gallery as
    the sketch, the end card.
65. Playback: from the play button, from the menu, Esc to skip back to walking; a film runner that
    renders it at a fixed 30 fps with ffmpeg encode, and a stills mode for checking.
66. Render it, watch it frame by frame, fix, render again.

### H. Finish (steps 67 to 70)
67. The menu entry, "Creation Gallery", with WALK and WATCH (the cinematic), and its preview clip.
68. The runners together: walking, stations, cinematic, performance, both moods.
69. `follow_up/lab_kit.md` brought up to date (the carried files, the gallery's station adapter,
    the director), this plan's status, memory.
70. Report with the film and the frames.

Pivot rule: if a step fails or a better way shows up, take it and write down why here. Questions
outside the plan go to the top. The plan does not grow.

Sources: [Visitor circulation: is there really a right-turn bias?](https://www.informalscience.org/visitor-circulation-there-really-right-turn-bias),
[Serrell, Exhibit Labels: An Interpretive Approach](https://scholarsbank.uoregon.edu/items/12334458-00ca-4c2c-bb47-046c3a22a818),
[Reveal shot](https://morphic.com/ar/ai-glossary/Reveal-Shot),
[Storytelling in motion (reveal and hold)](https://www.studiomatrx.org/students/architectural-visualization-rendering/storytelling-in-motion).
