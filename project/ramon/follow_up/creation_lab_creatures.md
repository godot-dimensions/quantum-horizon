# Creation Lab: the animals, read from their code (3 Oct 2026, step 2)

What each creature needs to stand on its own outside the pen, how to hold it on a rig, and
the traps. Line numbers are from the 3 Oct sources. All paths are res://.

## Shared facts

- None of them reads an autoload, the time of day, `get_first_node_in_group` or an absolute
  `/root` path. Groups: the owl joins `slice_dial_outline`; chickens join `chicken_flock`.
- **Freezing one:** `process_mode = DISABLED` on its root (or the walker's `halted`).
  **Slowing one:** nothing has its own time scale. Either the strider's `speed` (cadence), or
  turn processing off and step `_process(delta * k)` yourself. Everything steps on its delta,
  except `chicken_agent:414`.
- **@tool rebuilds:** the crow, owl, heron, chipmunk and block avatar `rebuild()` at `_ready`,
  freeing ALL their children, and `_own()` saves editor-built parts into the .tscn. Never parent
  rig props under them.

## The strider (`chickenpen/scripts/strider_walker.gd`): wolf, Nike, cats, horse, brachio, goat

- Rig shape it needs: rig → root ball (direct child, flat spine) → hip → knee → foot (the first
  ball child each). A leg must point down: `-drop.y >= 0.5*length` (240). Prefixes match the hip
  name; use them, or a tail can pass as a leg. Extra balls below the foot ride with the shank.
- Leg order: hip z descending, then x descending: FL, FR, BL, BR (cat "L" is +x).
- **Clock:** a child `GaitController` (`res://scripts/gait_controller.gd`, built 165-174, physics
  priority -1). Exposes `phase_progress` (never wrapped), `duty_factor`, `phase_offsets`,
  `period_sec`, `preset`. `period = reference_period*reference_speed/speed`. Presets: walk, trot,
  hop, canter_right, canter_left; `apply_preset` RESETS the phase (legs snap). The walker forces
  walk in `_ready` (174).
- **Foot path** `_foot_position(leg, p, duty)` (321-335) is pure: stance is a straight line
  rest+stride/2·Z to rest−stride/2·Z (stride_length is the whole stride); swing an eased
  quadratic Bezier peaking exactly at step_height. Bob `sin(phase·TAU·2)·body_bob` on the rig's
  y (298-300). IK: closed-form two-bone, knee towards −Z, reach clamped (341-366).
- **Per-leg data for overlays:** `walker._legs` (Array of Dictionaries), all in **rig (Hide)
  local space**: `knee_now`, `foot_now` (the solved pose; use these), `hip_world` (rig space
  despite its name), `rest_foot`, `rest_knee`, `upper`, `lower`, `order`, `in_stance`,
  `was_stance`, `foot_goal`. The ball nodes themselves never move. World = `hide.global_basis*p
  + hide.global_position`. `knee_now` exists from the first physics frame. Draw in `_process`.
- **Pieces:** on the first physics frame `_bind_mesh` cuts the hide: `Body`, `Leg{k}Thigh`
  (1+2k), `Leg{k}Shank` (2+2k); with `blend_joints`, `Leg{k}Hip` / `Leg{k}Knee` meshes posed per
  vertex. Then `rig.mesh = null`. All pieces copy the rig's material_override; colour them by
  setting each child's material_override.
- **Live:** `speed` (write it; `belt_speed` is only copied in `_ready`, so the cat's flee pace
  and the wolf raid's run speed never take effect), `stride_length`, `step_height`, `body_bob`,
  `travel`, `halted` (freezes mid-stride), `skin_every`. Treadmill speed for the belt =
  `stride_length*speed/(duty*ref_period*ref_speed)`; walk: `stride*speed/4.8` rig units/s.
- **Traps:** set rig_path, prefixes, animation_* and belt_speed BEFORE add_child. Set
  blend_joints before the first tick. Never `build()` or `live_rebuild = true` after the cut
  (the whole mesh comes back over the pieces). The walker owns the Hide's y: move the root.
- **Model copy** (`Model/scripts/strider_walker.gd`) differs only in skinning: every vertex per
  frame, smooth falloff binding. The chickenpen copy is a superset of its exports. Swapping a
  scene to it needs the **uid changed too** (`animation_test.tscn:7` carries
  `uid://bobn7d7vxflmp`; the chickenpen walker is `uid://c5wyf0hlrekp0`), and the pose changes
  (binary binding, rigid pieces). Loft rigs differ only by `branch_root_size` (wolf and Nike need
  the chickenpen rig).

| Creature | Source | Notes |
|---|---|---|
| Wolf | `Model/wolf.tscn` | Hide (12×4, root 0.3, smoothing 2) + Walker: prefixes ForeHip/HindHip, belt 6, stride 0.3, step 0.12, bob 0.03, blend_joints, travel off. ~1.2 m long, ~0.9 m tall, feet at y 0. |
| Nike | `chickenpen/nike.tscn` | Walker: travel ON, skin_every 2, belt 9. Antics need only ../Walker and ../Hide; set `turn_rate = 0`, walker travel false; `lie_chance` 1/0 or `_enter(State.ROOT/GOING_DOWN, secs)`. ~5.5 units, scaled 0.6 in the pen. |
| Cat | `pen_cat_4d.gd` (@tool, built in code) | Walker configured before add_child. Treadmill: `walks = false`, then `$Walker.travel = false`, and call `_follow_hide` yourself. **Sit and wash move ball nodes only (_tuck 669, _wash 678); after the cut nothing re-lofts, so by the code those poses never show.** Check by eye. |
| Horse | `Model/animation_test.tscn` | Model walker, all defaults, travel off. 4-ball legs (the hock is the "foot"). ~7 units tall. |
| Brachio | `Model/rigged_creature_ramon.tscn:2783-2919` | Root scale 0.25, Model walker: FrontLeg/BackLeg, skin_every 3, belt 4, travel ON, stride 2.5. ~10 world units tall. |
| Goat | `Model/model.tscn:456-645` | No walker. Legs RearLegTop→Mid→Hoof, FrontLegTop→Mid→Hoof, starts_branch, mirrored: the strider accepts them (use those prefixes). ~3.5 units. |

## The chicken (`chickenpen/chicken.tscn`, `chicken_walker.gd`, `chicken_agent_4d.gd`)

- Root basis 0.25; rigs Body, NeckHead (beak, wattle), LegL, LegR, Wing; ~0.48 m long. Legs cut
  into Thigh/Shank on the first physics frame.
- Drop the Agent (it leashes, pins y, and teleports birds it thinks are stuck). Flock crowding
  pushes birds apart by `.position` across the group: set `separation = 0`.
- `halted` is overwritten every frame by the pecking (278), so it cannot hold a bird still.
- **Walking in place does not work as is:** stance plants the foot in the world (450-454) but
  swing lifts from a local point (448, 459), so a pinned root snaps the foot ~0.62 units at
  every lift-off. Needs a lab copy with a travel flag and a local treadmill stance (the old
  approach, 427-431). Set scale before `_ready` (238).

## Flyers and perchers

| | Built | Hold it on a rig |
|---|---|---|
| **Crow** (`pen_crow_4d.gd`) | code: Hide loft, beak/eye boxes, quill wings; 0.52 m | PERCHED/TAKEOFF/FLYING/LANDING on random timers; take-off is straight up; flight wanders round `_home`. A later-priority script resets x/z/w every frame keeps it in the column. Force take-off: `_mood_left = 0` while perched. Size with `length` (root basis is overwritten). |
| **Owl** (`lookout/owl_4d.gd`) | code: plumage loft, head pivot, disc, tufts; 0.55 m | Never moves its root. `idle_only` + `perform("turn_w"/"stretch"/"hoot"/"look")` still work and return to SIT. Fixed seed 41. |
| **Heron** (`lookout/heron_4d.gd`) | code: plumage loft, wing/leg pivots, 3 neck segments; 1.0 m | `idle_only` forces STAND and undoes `perform`, so keep it false for flight. Vertical loop: after `perform("take_off")` overwrite `_path` = [p, p+up·h, p+up·h, p] and `_flight_len`; zero horizontal travel leaves the basis alone. Re-trigger within 4-7 s of landing. Two sounds per take-off. |
| **Chipmunk** (`lookout/chipmunk_4d.gd`) | code: fur loft, stripes, tail pivot; ~0.46 m | `idle_only` alternates SIT 5 s / STUFF 4 s in place; the root never moves. Cheeks stay full after the first cycle (trap). |

## The dreamer (`chickenpen/cave/cave_dreamer_4d.gd`)

- Built in `_ready` (not @tool): ~680 mesh instances (lip, teeth, throat, heart, swirl, 480 limb
  pieces, 44 motes) sharing two loft meshes, plus an OmniLight4D glow.
- Shrink `creature_scale` (min 0.25), `core_height` (not scaled, 11 m), `room_radii` and
  `floor_clear`, or the limbs flatten against the ellipsoid. `player_path` may point at any
  marker (it aims at marker + 1.4 m). `set_mood("warn"/"calm")`; anything within 4 m turns it red.
- Rewrites Mouth and Body transforms every frame (CPU: measure it).

## People (`pen_searcher_4d` + `block_avatar_4d` + `block_gait_4d`)

- A CharacterBody4D with a capsule, an Avatar (chibi, basis 0.75) and a Gait. The gait reads
  `linear_velocity` and `is_on_floor()`: needs a floor and `move_and_slide`.
- **Walking in place does not work as is:** feet plant in the world. A lab copy needs a
  treadmill stance (`_plant[i] -= forward*speed*delta`), velocity set, move_and_slide, position
  restored. Scale a parent (the searcher overwrites the avatar's basis).

## Trym's 8-legged creature (`Model/rigged_creature.tscn`, `Model/scripts/*`)

- 42 loft segments (2 handles each), 8 FABRIK legs (`res://scripts/ik_chain_controller.gd`,
  lengths 1.15/0.95/0.7) aimed at `<Tag>FootTarget` nodes; A/K halves at w ±0.85 / ±0.95. The
  Ramon variant splits A/K on Z and sets `w_pair_phase_offset` 0.5. 20,160 tetrahedra; builds in
  367 ms. One shared material (give each segment its own for Blocks).
- **Solver order** (all physics): HeadAttention -3, IdleLayer -2, IKGaitDriver -1, SpineNeck 0 and
  TailSway 0, the 8 IK chains 1, FootGround 2. They talk through shared vars
  (`gait.target_offsets`, `breath_offset`, `spine.flex_scale`, `aim_direction/aim_weight`,
  `tail.sway_scale`).
- **Switching off:** `set_physics_process(false)` freezes that layer at its last values; nothing
  snaps. IK back on jumps to target in one frame. Don't free solvers (others read them). Rest
  bases are private.
- **Gaits:** walk 4.0 s duty 0.6, trot 1.2/0.5, hop 1.0/0.5, canters 2.2/0.4. `apply_preset`
  KEEPS the phase. The K halves get `+w_pair_phase_offset`, applied on the next apply_preset.
  `halted` eases feet home; planted = `fposmod(phase + foot.phase, 1) < duty`.
- **World:** FootGroundSolver uses world `ground_y` 0.05 and world forward −X (set ground_y to
  the deck + 0.05). SpineNeck records the head's world y in `_ready`: place the creature before
  adding the solvers. HeadAttention looks at `../Player`'s global position (glance within 4 m).
- **Cannot be scaled** (FABRIK). Does not travel. `theatre_creature_4d.gd` adopts it
  (`_adopt` 100-138: creature first, then the solvers; `show_rig`, bones as ArrayWireMesh4D,
  amber foot dots): reusable on any unscaled Node4D.

## The symmetry creature (`Model/symmetry_lab*.tscn`)

- One rig: a 10-ball body, fore and hind legs as Dihedral branches. D2 → 8 legs (lab), D3 → 12
  (Ramon's; `symmetry_count` 3 on the leg heads). Copies are moved copies of one lofted mesh.
- Changing the count does not rebuild by itself (the rig's change check ignores symmetry): call
  `Creature.build()`; cost unmeasured (a full loft).

## The first armature (old Motion Lab)

- Built in code by `res://scripts/motion_lab_creature.gd` (box body, orthoplex segments, feet);
  GaitController, FootTargets and HipSuspension go on Body's PARENT with "../Body" paths.
- Feet raycast down from absolute y 20 for 40 units: needs a collider under every probe or a
  foot slides away for ever. Parent at zero world Y, unrotated (faces world +X); platform about
  x ±1.8, 1.5 ahead, 4 behind. Belt = planted feet slide back along +X; body on a spring.
- Keys U/I size, K/L limbs, N/M segments, 1/2/4/5 gaits, 0 halt (no enable flag).

## Goat build stages (the method to copy for the wolf)

`chickenpen/theatre/theatre_goat_4d.gd` + `chickenpen/scripts/_bake_goat_runner.gd`: detach
handles beyond N in reverse depth-first order, `build()`, `mesh.duplicate(true)`, reattach; 7
build stages, 4 reshape stages, a finished one; saved as `.res` plus a cfg. For the wolf: free
its Walker before it enters the tree, hush the rig (live_rebuild off) or the first `_process`
re-lofts over the shown stage. Finished colours live on the material, not in the .res.
