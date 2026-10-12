# Case study: how a tutorial space teaches

4 October 2026. Research for the Creation Lab redo, after both lab prototypes (the W-lift lab and the
ring gallery) failed Ramon's review (memory: `feedback_lab_presentation.md`). Four sources, all looked
at with screenshots rather than read from code alone:

1. **Unreal Engine 5.8, "Intro to Unreal"** (`Templates/TP_UEIntro_BP`, level `Lvl_IntroRoom`), the
   only in-world tutorial level UE 5.8 ships. Copied to `D:\depot\__UE_study\` (Program Files untouched),
   opened in the editor with a small Python bridge, then played: 49 shots walking the whole route,
   12 from the designers' spawn points, 9 framed on station titles, the Sequencer flythrough, the
   gizmo demo frame by frame, aerial and plan views. Every text, colour and material value below
   was read out of the level itself.
2. **Our cinema** (`chickenpen/theatre/`): its code, plus frames from its capture runners.
3. **Ramon's own Godot lab** (`D:\depot\__GODOT\my-own-01`, Godot 4.7.1), run and captured.
4. **Online research**: tutorial chambers, galleries and museums, immersion, Marathon's art direction.
   Sources are linked inline.

---

## 1. Unreal's intro level

![The first wall, in the editor](img/ue01_editor_start_wall.jpg)
![The same wall once you press Play](img/ue02_play_start_wall.jpg)

**The first wall rewrites itself.** In the editor it says "hold the right mouse button and use W, A, S
and D to fly", with Q/E keys and a right-click mouse. Press Play and the same wall says "use W, A, S
and D to walk", the Q/E keys and the right-click are gone, and the last line becomes "walk around this
wall". Every text block in the level (`BP_TextSwitcher`) holds two texts, one per mode. **The words on
the wall always describe what you can do right now.**

**Keys are objects.** W, A, S, D, Q and E are 3D key caps standing on the wall, beside a 3D mouse. They are
not on a HUD and not in a list in a corner.

### The route

![Plan of the whole level](img/ue10_plan.jpg)

- **One route, one direction.** A single spline 290 m long, through 26 points, climbs from a basement
  (−2 m) through five floor levels to 9 m. It is never a loop and never a choice.
- **You see one corridor at a time.** Walls are 4 to 12 m tall around corridors 3 to 6 m wide. The
  whole block is about 45 × 70 m. From anywhere on the route you see the corridor you are in and
  the title at its end, and nothing else (the plan above, and the oblique view below).
- **The route is drawn on the floor.** White centre-line dashes, 2.4 m long and 20 cm wide, with a
  white disc at every turn. **They are static: nothing animates.** It is plain road marking.
- **The next title is the destination.** Almost every corridor ends on a wall that carries the next
  station's title, framed by the corridor ("4/16 Outliner" below). That is Disney's "weenie": a
  visual magnet at the end of the street.

![The corridor ends on the next title](img/ue05_weenie_outliner.jpg)
![Blue path segments mark where something is taught](img/ue04_route_blue_pills.jpg)

### The stations

All 16 titles read **"n/16 Title"**: number small, title large, white. The title is 80 cm tall and the body
26 cm, both in one font (Roboto). Text is printed straight onto the wall, on the grid, with no card,
panel or frame. The only exception is the first wall, which is a dark slate panel.

The body copy is 3 to 6 short lines and always ends on one thing to do ("Try dragging some in so you can
get across this gap.", "Try lighting up this room!").

There are three layouts:

| Layout | Example | How it reads |
|---|---|---|
| **Bay**: three walls, open towards you | Animation, Sequencer | A saturated blue back wall fills the view. Title and copy are centred high on it, and one exhibit stands small on a blue disc below the text. The text is never in front of the exhibit. |
| **Room**: you walk into it | Materials, Particles | The exhibit sits in the middle on a blue disc. The text is on the side wall beside you, read at an angle. A glowing orange strip marks the far door. |
| **Wall**: exhibits in a row | Moving Objects | Three cubes on a long wall, with a big word above each ("Move", "Rotate", "Scale") and a 3D key cap beside each (W, E, R). The title and copy are to the right. |

![Bay: Animation](img/ue07_animation_bay.jpg)
![Bay: Sequencer](img/ue08_sequencer_bay.jpg)
![Room: Materials](img/ue06_materials_room.jpg)

### Demonstrate, then do

![The gizmo cubes demonstrate their own verb, six frames](img/ue13_gizmo_demo_frames.jpg)
![Station 1 from its spawn point](img/ue03_station1_moving_objects.jpg)

- **The exhibits demonstrate themselves on a loop.** The Rotate cube swings back and forth with its
  rotation gizmo drawn on. The Scale cube stretches and shrinks with its scale gizmo. So the station
  shows the verb, names it in big letters, and puts its key (E, R) next to it. Then the text asks you
  to do it yourself.
- Other stations behave the same way:
  - **Animation:** the mannequin copies your movements (`ABP_Copycat`).
  - **Metasounds:** the tuning fork plays a tune.
  - **Physics:** the blocks dangle.
  - **Sequencer:** stepping onto the disc plays a camera flythrough. It rises over the level, swoops
    down onto the station's wall and pushes into the copy with depth of field (below).
  - **Blueprint:** the one thing to press is a big red button on the floor, and the locked door
    beside it has red lights.

![Mid flythrough, the camera above the bays](img/ue12_flythrough_aerial.jpg)
![Red means press](img/ue09_blueprint_red_button.jpg)

### The colour code (exact values, linear)

| Colour | Meaning | Value |
|---|---|---|
| Grid grey | Architecture: walls, floors, everything neutral | surface 0.18, 1 m lines 0.026, 20 cm lines 0.089. **1 m cells, 5 subdivisions**, major lines 2.2% of a cell |
| Blue "colourway" | Where a lesson is: exhibit discs, bay back walls, lesson-carrying path segments | (0.024, 0.090, 0.172) |
| Light blue | The path segment you are meant to cross (rounded "pills" on ramps and bridges) | lighter variant |
| Red | The one thing you press, and door lights | (0.71, 0.02, 0.035) |
| Orange glow | Beacons and door strips | (1.0, 0.47, 0.0) × 5, emissive |
| White | Text and route marks | |

### Other mechanisms

- **12 spawn points.** Play drops you at the station your editor camera is nearest, so you can
  start anywhere.
- **The space opens the editor's UI.** Spheres 5 m across (`BP_UI_Update`) open the Outliner, Content
  Drawer or Details panel as you fly up to the station that teaches it.
- **No HUD at all in play.** Every instruction is in the world.
- **Daylight.** Hard sun shadows across white grid walls give depth without any decoration.

![The level from above, at an angle](img/ue11_oblique.jpg)

---

## 2. Our cinema

![Frames from the cinema](img/cinema_sheet.jpg)

What makes it elegant and immersive:

- **A dark house** with one lit stage, and a seat that hands the camera over to eased shots that
  never cut.
- **A tall colour field behind one exhibit.** The 7.4 m backdrop arc changes colour per idea: violet,
  green, magenta, red.
- **One exhibit on a drum.** The room stays still while the exhibit turns (yaw on the turntable, W on
  the exhibit).
- **Labels beside the exhibit, never on it.** One big number or word with a small line under it, on a
  leader line. A lower-third caption gives the numeral title ("V. NOBODY BUILT THIS SURFACE").
- **The goat grows in 11 stages, swapped in place** every 1.55 s:
  - plain grey with gold handle markers;
  - the camera on a three-quarter push-in;
  - the handle count climbing beside it.
- **The x-ray:** the creature's skin is swapped instantly for thin ellipses and bone lines, for about
  8 s in the middle of its walk, then back.

**The cinema and Unreal share the core move: a saturated wall of one colour, one exhibit in front of
it, text beside it or above it, and nothing else in view.**

---

## 3. Ramon's my-own-01 lab

![my-own-01 in Godot 4.7.1](img/myown01_sheet.jpg)
![Its wayfinding decal sheet](img/myown01_wayfinding_sheet.jpg)

- **The camera** is third person behind a red-suited figure.
- **Black triple chevrons scroll along floor strips** towards a ramp (`mesh_instance_3d_14.gd` scrolls
  the texture).
- **The goal is a black wall** with "CHAMBER 06" in acid yellow.
- **The exhibit stands on an acid-yellow disc** on a dark plinth. It is choreographed with tweens:
  turn 90°, wait, sink 1 m, rise while turning 180°, hold 2 s.
- **The masses are colour-blocked** in coral red, navy, black and white on a grey grid.
- **The decal sheet is the clearest statement of a style in any of the four sources.** Acid
  yellow-green, a huge chamber number ("CH-06", "ENTER CHAMBER 06"), "EXIT ROUTE", "STAND ON YELLOW",
  "DROP OBJECT HERE", chevrons, hazard stripes and ruler ticks. That is Marathon's register.

---

## 4. Online research (condensed)

- **One idea per chamber.** Portal introduces each element alone in at least one room before it
  combines it with anything
  ([Game Developer](https://www.gamedeveloper.com/design/portal-2-game-design-review-part-1)).
  - Clutter was removed because it distracted.
  - Glass was added where playtesters skipped the lesson.
  - Light points at the key object.
  - The chamber sign at the door gives the chamber number, progress such as "3/19", and icons
    ([Portal commentary](https://theportalwiki.com/wiki/Portal_developer_commentary),
    [Valve wiki](https://developer.valvesoftware.com/wiki/Test_Sign)).
- **Show, then do.** In Half-Life 2 you see a zombie cut by a saw blade. Then you pull a blade off the
  wall, and a zombie appears.
- **Players skip text.** Valve's playtests found experienced players walk past signs, so text has to
  back up a demonstration, never carry the lesson alone
  ([Engadget](https://www.engadget.com/2012-03-08-the-importance-of-playtesting-what-portal-2-could-have-been.html)).
- **Open floor plans are the worst performers.** Serrell's meta-analysis found the least-used
  exhibition was the one with an "open and nondirective floor plan". The exceptionally well-used ones
  had *fewer* elements and a bounded space
  ([PDF](https://informalscience.org/wp-content/uploads/2024/01/SA.PA2.FinalDforCAISE2016.pdf)).
- **Exits pull.** About 70% of visitors turn right on entering, and the pull of an exit grows the
  closer they get ([Melton](https://informalscience.org/research/visitor-turning-and-exiting-museum-galleries/)).
- **Navigation must cost nothing.** Bitgood: finding your way while learning is the classic
  two-tasks-at-once failure. Visitors look at the object first, then the image, then the text
  ([AAM PDF](https://www.aam-us.org/wp-content/uploads/2024/04/4EXHSP14Bitgood_ExhibitionDesignthatprovidesHighValues.pdf)).
- **Label rules:** one big idea, at most 50 words, lines of 50 to 60 characters.
- **Scale and light:**
  - A focal object 2.5 to 4 times the visitor's height.
  - At least 5:1 light contrast between exhibit and surround; 10:1 for clear separation
    ([ERCO](https://erco.com/en/designing-with-light/lighting-knowledge/visual-perception/contrast-vision-7466)).
  - Compress, then release: a low, narrow way in, then a tall room.
- **Marathon's "graphic realism"**
  ([The Game Post](https://thegamepost.com/marathon-art-style-mirrors-edge-ghost-in-the-shell/),
  [80.lv](https://80.lv/articles/marathon-art-director-shares-the-team-s-creative-influences),
  [Fonts In Use](https://fontsinuse.com/uses/67879/marathon-2026-video-game-1)):
  - simplified forms, strong colour statements, few materials, real proportions;
  - neon signal colours taken from F1;
  - labels and markings used to show scale;
  - wide all-caps display type with a mono for body text.
  - Its own warning is the "fontslop" criticism of its menus, with about 20 font combinations on
    one page ([Kotaku](https://kotaku.com/marathon-ui-fontslop-menus-bungie-2000675332)).
    Two type families is enough.

---

## 5. Why the two prototypes failed, in these terms

| What Ramon saw | What the references do instead |
|---|---|
| The ring invited both ways ("do I start at 1 or 5?") | A single serpentine, numbered n/N, with the next title framed at the end of each corridor |
| Everything visible at once, any direction | Tall walls: one corridor, one station in view |
| Cards that grow as you approach, jitter and reflow | Text printed on the wall at a fixed size, like paint |
| Cards and labels in front of the creature | Text on the wall above or beside the exhibit, or one leader-line label |
| "Painstakingly hard to figure out what to do"; key lists in a corner | The exhibit demonstrates its verb, the verb is written above it, its key stands beside it, and then you do it |
| Tiny platforms | Exhibit 2.5 to 4 times body height on a drum; walls up to 12 m |
| The world rotating | The exhibit rotates; the room never moves |
| Booths facing away, two kinds of card | One kind of text (on walls). Every station faces the route |
| Dotted strip on the floor | Unreal uses static dashes. Ramon's own lab uses scrolling chevrons, which pull the eye more strongly |

## 6. The rules the test scene follows

**Space**
1. **Chambers in a row.** Each chamber teaches one thing and has one door in and one door out. The
   exit stays locked (orange) until you have done the thing.
2. **Tall walls** (9 m), so only the current chamber is ever in view. Corridors turn between chambers.
3. **Compress, then release.** A narrow corridor opens into a big chamber.

**Exhibit**
4. **The creature is the weenie.** It stands on a drum at the far end of the axis you enter on, in
   front of a saturated colour-field wall, the way Unreal's bays and the cinema's backdrop work.
5. **Watch, then try.** First step onto the yellow WATCH disc: the camera eases to a framing and the
   exhibit demonstrates, cinema style. Then the TRY disc lights. Step onto it and press one key; the
   exhibit itself responds.
6. **The room never moves.** Exhibits turn on the drum and in W.

**Text and signs**
7. **Text is paint.** Title, one sentence and at most about 40 words, printed on the wall beside the
   exhibit through the surface shader. It has a fixed size, is depth-correct, and is never in front
   of the creature.
8. **Number every chamber**, n/N, large on the wall. Each chamber's number and title also sit on the
   wall at the end of the corridor that leads to it.
9. **One HUD element only:** a centred card while you stand on a TRY disc, showing the key and the
   mechanic. Ramon asked for this, and Unreal has nothing like it. Unreal's key cap beside the exhibit
   is used as well: the key is printed on the wall next to the exhibit.

**Colour and type**
10. **Colour has one job each:**
    - grid grey for architecture;
    - one saturated colour per chamber for the lesson wall and the drum;
    - acid yellow for "stand here" and "go" (Ramon's sheet);
    - orange for locked doors;
    - white for text.
11. **The grid is Unreal's grid,** rebuilt as our own shader: 1 m cells, 5 subdivisions, major lines
    2.2% of a cell. Surface, line and sub-line colours can all be changed live.
12. **Guidance is animated chevrons** on floor strips (Ramon's lab), drawn by a shader. Unreal's
    plain dashes were the alternative; the chevrons are the stronger pull, and he asked for them.
13. **Two type families,** Montserrat for titles and body text. No other decoration.
