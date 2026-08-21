# What Portal actually does, and what of it transfers

Researched 2026-08-19 from Valve's own commentary and the placement
documentation, to check the strategy paper's claims about Portal against the
source rather than inheriting them second-hand. Every entry ends with what it
means for *this* prototype.

## Rendering

Valve renders a **virtual camera looking out of the opposite portal**, drawing
only what is visible through that portal's limited field of view and
**excluding objects between the virtual camera and the destination portal
plane** (David Kircher, Portal commentary). Recursion is capped at **nine**
views down a chain, and deeper levels reuse *previously rendered frames* rather
than rendering fresh.

> **For us:** this is exactly the architecture the paper proposes, and exactly
> the one `engine/modules/4d` cannot do per-viewport today — one shared
> `RenderingEngine4D`, one `World3D`, one set of slice uniforms. Valve's cheap
> recursion trick is irrelevant to the MVP (recursion is excluded anyway), but
> the front-plane exclusion is not optional: it is what stops the entrance wall
> leaking into the destination image. Whatever we do for look-through has to
> solve that clipping too.

## Collision was their hardest problem, and they gave up on exactness

Dynamic collision regeneration cost **500 ms per portal placement**. They
replaced it with **temporary hybrid physics environments in "bubbles" around
the portals** — less accurate, far cheaper — reaching **10 ms**. Moving objects
were solved separately by **cloning the object on both sides** and strictly
controlling what is allowed to collide with what.

> **For us:** our analogue of that 500 ms is the remesh + collider rebuild after
> carving an aperture. `VoxelMining` measures "a few tens of ms" per hit at
> `grid_size` 8, and per-voxel `BoxShape4D` colliders mean carving already
> removes collision *locally* — we get most of the bubble's benefit for free.
> The untested part is room scale, not the mechanism.

## Portal 2: teleportation is almost never axis-aligned

They had to **trace the player as the axis-aligned box they would occupy on
each side of a portal simultaneously and merge the results**, because "portal
teleportation is almost never axis-aligned" (Dave Kircher) — non-linear time in
non-linear space.

> **For us:** this is the single biggest simplification available. Our physics
> is axis-aligned-box-only anyway, and if apertures are only ever placed on
> axis-aligned walls with roll quantised to four orientations (as the paper
> already recommends), **both sides stay axis-aligned and Valve's hardest
> problem never arises.** Free-placement on arbitrary curved dual-contoured
> surfaces would reintroduce it in full. Strong argument for authored panels
> first.

## Placement rules, with numbers

From `prop_portal` and the placement documentation:

| Rule | Value | In metres (1 u = 0.01905 m) |
| --- | --- | --- |
| Clearance above/below portal centre | ≥ 57 u | ≈ 1.09 m (so ~2.17 m tall) |
| Clearance to either side of centre | ≥ 32 u | ≈ 0.61 m (so ~1.22 m wide) |
| Distance from the host surface | 0–8 u | ≈ 0–0.15 m — flush, never a tunnel |
| Bump distance to a free spot | up to 32 u (65 u past an obstacle) | ≈ 0.6–1.2 m |
| Paired portals | must be the same size | — |
| Non-portalable surfaces | material flag (`%noportal`) | — |

> **For us, and this corrects a first impression:** Valve's aperture is
> ~1.22 × 2.17 m. The paper's **passable core** is 1.4 × 2.45 m — within a
> hand's width of Valve's, so it is *not* oversized as it first looked. The
> paper's 2.1 × 3.15 m figure is the **exterior including the rim collar**,
> a distinction worth keeping straight.
>
> The real tension is resolution: at `VoxelMining`'s `cell_size` 0.4 m, a
> Valve-sized aperture is only ~3 cells wide, and the paper's own topology
> caveat wants features 2–3 cells thick. Halving `cell_size` costs **16×** the
> points in 4D, not 4×. So aperture size is set by the voxel grid, not by the
> human — which is why the paper lands on 0.35 m cells and a slightly generous
> opening. Its numbers are better reasoned than they first appear.

## Teaching, which is where Portal's real lesson is

- Playtesters initially believed **"portals took them into other spaces or even
  other dimensions"** (Kim Swift). Valve had to fight that misconception.
  **We are building it as the literal rule.** The single most useful finding
  here: the intuition players arrive with is *our* mechanic, so the teaching
  burden is lower than Valve's — but only if the two sides are visibly
  different, or it reads as an ordinary same-room portal.
- They start the player **in a visually unique room with memorable objects**,
  and have them **see themselves through a portal first**. The paper's State A
  is exactly this, correctly borrowed.
- Puzzles are gated so that **"stumbling around will virtually always lead to a
  dead end"** (Robin Walker) — the player must demonstrate understanding to
  progress.
- Momentum was introduced **gradually across several chambers**; combining
  concepts overwhelmed testers.
- Testers assumed **one colour was exit-only** (Kerry Davis) and had to be
  taught otherwise by puzzle design.
- Testers **rarely look up** (Jeep Barnett), and **leap blindly rather than
  looking through the portal first** (Scott Dalton).

> **For us:** the "look through before you commit" habit is the one we most
> need, because in our version the far side is a different *slice* and cannot
> be inferred from the room you are standing in. Any hazard on the far side
> should be introduced only after the player has demonstrably used the view.

## Assistance is authored, not emergent

Portal 2 detects a wrong portal placement and **silently moves the player's
other portal** to make a section foolproof (Dave Saunders). Portal 1 has
placement helpers, and bumping slides a portal to the nearest legal spot rather
than failing.

> **For us:** a stakeholder-facing chamber should lean on authored helpers and
> generous fit tolerance well before it attempts free placement on arbitrary
> dual-contoured surfaces.

## Sources

- [Developer commentary — Portal](https://combineoverwiki.net/wiki/Developer_commentary/Portal)
- [Developer commentary — Portal 2](https://combineoverwiki.net/wiki/Developer_commentary/Portal_2)
- [prop_portal — Valve Developer Community](https://developer.valvesoftware.com/wiki/Prop_portal)
- [Portal Placement — P2SR Wiki](https://wiki.portal2.sr/Portal_Placement)
- [Portal bumping — SourceRuns Wiki](https://wiki.sourceruns.org/Portal-Bumping.html)
- [Thinking With Portals: Making a Portal 2 Test Chamber — Game Informer](https://gameinformer.com/b/features/archive/2010/03/17/thinking-with-portals-making-a-test-chamber.aspx)
