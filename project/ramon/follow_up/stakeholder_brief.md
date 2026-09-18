# Stakeholder brief — copy proposal

Thirteen slides. An **orientation brief**, not a pitch: what we did, what we are
doing, where we are going, and what we need decided. Sits alongside the
Octobergate deck (which argues the case) and D1–D4 (the formal submission)
without restating either.

**Status:** copy proposal, 2026-09-16. Nothing built in Figma yet.
**Target:** the 12 Oct package. Slides marked ★ are the six-slide subset for
Scott's mid-point review, week of 21 Sept.

## Rules this copy follows

1. **Three pillars, not four claims** — engine performance, player experience,
   developer experience, per Trym's 2026-09 framing. Each carries **two named
   sub-measures**, because each contains two things that dissociate. Engine
   already has its sub-structure (S1–S3); player and developer don't, and that
   is the gap this deck closes.
2. **Evidence tiers on the face of every claim** — `MEASURED` /
   `OBSERVED WHILE BUILDING, n = 1` / `NOT YET TESTED`. Inherited from the
   Octobergate deck, which needed them because the first draft overclaimed.
3. **No "kill condition."** CONTINUE / PIVOT / STOP, `GATE ESSENTIAL`, and
   "what would have to be true / what would change the answer" carry the same
   content. D2 §7 keeps the internal wording; this deck doesn't need it.
4. **No "ARC."** Superseded as the org frame — this is an IOR R&D programme
   with a gaming lean. The four-claims framing survives, unattributed.
5. **Prototypes are evidence under a pillar, never the claim.** At most two get
   a full visual. The rest appear once, as a grid. The menu appears once, last,
   as the invitation to audit — not as a feature.
6. **Copy comes from `catalogue.tres` where it exists.** Every prototype entry
   already has `question` / `approach` / `finding` / `benchmark`. Reading those
   fields means the deck and the artifact cannot drift.

---

# ACT 1 · WHERE THIS CAME FROM

## ★ Slide 1 — Six bets became one question

**ON-SCREEN**

> Quantum Hosky ran six converging bets. Five have been answered — two moved
> on, three did not survive diligence.
>
> **Moved on** · Agent simulation began here as Sun Haven and spun out as
> Midnight City. Biotech and BCI wound down with the clinic.
>
> **Answered no** · Chronos lacks the time accuracy to replace NTP. Hydra and
> Midgard are not operationally viable at per-title scale. The partnerchain
> team dissolved into Midnight. Token distribution was tested live at Rare Evo
> 2025: **0.5% activation from 100,000+ holders**, with real incentives.
>
> **Answered yes** · The 4D engine. The 4D voxel system.
>
> One question is left, and it is the only one this programme is about: **can
> 4D function as a real gaming platform — capable of shipping commercial
> titles, not tech demos?**

**FOOT**
Narrowing to one question is the reason for exploration mode. Six disciplines
diluted the focus; one can actually be answered. The Rare Evo result is worth
reading as a genuine, informative negative — it was a live test with
incentives, not a hunch, and it is why token mechanics are not in this plan.

**VISUAL** Six-to-one funnel. Five lanes terminating, one continuing. Greys for
the terminated lanes, the semantic blue only on the surviving one.
**TIER** `MEASURED` on Rare Evo. Everything else is a recorded decision, not a
claim.
**SOURCE** D1 exec summary; June stakeholder update, technical diligence section.

---

## Slide 2 — The prototype worked. The engine was the wrong place to keep it.

**ON-SCREEN**

> By mid-2026 a fork of Unreal Engine 5 was running genuine 4D gameplay:
>
> **6,000+** 4D mesh objects sliced in real time, with player interaction ·
> GPU slicing and projection under Unreal's full lighting and material system ·
> multithreaded CPU slicing for collision · character controller with climbing
> and mantling · 4D signed-distance collision · raycasting · G4MF asset
> pipeline · 4D editor gizmos, in-editor slice control, volume view · a
> playable fishing prototype on a permissioned Steam build.
>
> The cost was an **8-million-line fork** with thinner documentation than you
> would expect, maintained by a team that also had to invent the asset pipeline
> as it went.
>
> Exploration moved to **Godot 4D**: open-source, in-house, nimble. The engine
> module is shared beyond this project. Productization can port back.

**FOOT**
This slide exists because the previous stakeholder update described a thriving
Unreal project, and the next thing stakeholders heard was a smaller programme on
a different engine. That reads as retreat unless the sequence is stated: the
Unreal work proved the thesis and was too heavy to iterate on. Nothing was
abandoned — collision was 3D-only with no W-strafing, and the Godot module
already carries 4D physics bodies, textures, two rendering engines and OFF
import that the Unreal fork never had.

**VISUAL** One frame from the fishing prototype at left, one from a current
Godot scene at right, same scale. Not a before/after — a "same thesis, lighter
substrate."
**TIER** `MEASURED` on the 6,000 figure and the line count.
**SOURCE** Prototype Milestone Update (2026-07-20), incl. its Godot 4D feature
comparison; Claude Context — Start Here.

---

# ACT 2 · THE QUESTION, STATED SO IT CAN BE ANSWERED

## ★ Slide 3 — Three things have to be true by the end of 2027

**ON-SCREEN**

> **ENGINE PERFORMANCE** — 4D can run. Frame rate, render distance, world
> scale, objects on screen, regeneration time.
>
> **PLAYER EXPERIENCE** — 4D can be understood *and* enjoyed. A first-time
> player can read a 4D scene, and wants to play another one.
>
> **DEVELOPER EXPERIENCE** — 4D content can be made at a sustainable rate,
> without a scarce specialist for every asset.
>
> The third is the one that ended the previous incarnation. Every asset
> hand-built is not a platform; it is a bespoke art project with an engine
> attached.

**FOOT**
These are conditions, not predictions. Each is measurable, each has an owner,
and each can come back negative — which is the point of setting them now rather
than at the end. The October decision funds the year in which they get tested;
the end-of-2027 decision reads the results.

**VISUAL** Three columns, equal weight, each with its owner named. Resist making
any one of them the hero.
**TIER** n/a — framing slide.
**SOURCE** Trym, Discord 2026-09; the four-claims framing behind it.

---

## ★ Slide 4 — Each pillar contains two things that come apart

**ON-SCREEN**

> A pillar with one name gets measured as whichever half is cheapest. Naming
> both halves is what makes a result interpretable.
>
> | | |
> |---|---|
> | **ENGINE** | **S1** stability · **S2** scale · **S3** regeneration — *already sub-structured* |
> | **PLAYER** | **comprehension** — can a naive player read the scene · **appeal** — would they play another |
> | **DEVELOPER** | **independence** — is the specialist bottleneck removable · **durability** — does it work without AI compensating for tooling |
>
> **Why player splits.** A 2026 study found players navigate a hypercube
> successfully *without understanding 4D*. Task success, comprehension and
> appeal are three dissociable things. An engine people can read but don't
> enjoy is a geometry demo — a failure mode with real precedent in this field.
>
> **Why developer splits.** AI assistance should amplify good tooling, not
> compensate for bad. If the result depends on the model papering over
> friction, it is fragile: 4D is the domain where AI help is thinnest, because
> the training data barely exists.

**FOOT**
Engine's pillar already reads as straightforward because someone did this work
for it — S1, S2 and S3 are three separate measures with three separate
thresholds. Player and developer have not had that pass yet. This slide is that
pass, and it is the substance of what we are asking to be agreed.

**VISUAL** Three-row table, the engine row visibly settled (ticked, greyed), the
other two rows live. Violet on the two new splits.
**TIER** n/a — proposal slide.
**SOURCE** Thrust C open questions (Hyperspace Game study); D2 §3 on the
geometry-demo failure mode; June update on AI weakness in 4D reasoning.

---

# ACT 3 · WHAT WE KNOW NOW

## Slide 5 — It runs, at interactive rates, with geometry changing under you

**ON-SCREEN**

> **Destructible 4D matter** · a persistent voxel field, dual contoured,
> re-meshed on every hit — **~130 ms per carve at room scale, ~58 fps**.
>
> **Cut-anywhere walls** · chunked voxel walls cut cumulatively —
> **40.5 ms per chunk rebuild, 10,752 tetrahedra**.
>
> **Momentum across linked openings** · position, orientation and velocity
> carried through — **7.7 → 22.2 m/s over five crossings**.
>
> **Weather as real geometry** · a cloud deck built from sliced 4D solids, so
> it exists at every w — 24-cell workhorse at 96 tetrahedra, 600-cell for hero
> puffs.

**FOOT**
These are measurements from the interface and content scenes, taken while
building them. The **gate criteria S1–S3 are measured on the voxel artifact,
not on these scenes** — sustained frame rate at matched render distance, world
scale against the 4D Miner baseline, and in-place regeneration under 20 seconds
without a restart. Stating that separation matters: these numbers show the
substrate is interactive, not that the gate thresholds are met.

**VISUAL** Four-panel grid, HUD readouts kept visible in every frame. The debug
overlay is part of the visual identity here, not something to hide.
**TIER** `MEASURED` throughout.
**SOURCE** `catalogue.tres` — Voxel Mining, Portal, Sky Box Clouds `benchmark`
fields.
**ASSETS** Voxel Mining carve with ms/fps readout — **needs shooting**. Portal
crossing with velocity readout — **needs shooting**. Sky Box Clouds — frame
exists in `Menu/thumbs/`.

---

## ★ Slide 6 — Legibility responds to cheap decisions. This is the control.

**ON-SCREEN**

> **The same level. The same camera. One variable removed.**
>
> Left: floor panels banded along w. Right: identical view, every panel below
> y=0 repainted uniform grey.
>
> Rotate the slice in the banded version and you are still oriented. Rotate it
> in the unbanded version and the scene is a blank diamond. **Banding is
> load-bearing** — and it costs nothing but a decision.
>
> ---
>
> **Round 1 playtest** · N=7 · May–June 2026 · 4D obstacle course
>
> **7 / 7** developed 4D spatial intuition · **6 / 7** wanted to play a
> polished 4D game **in a different genre** · **8.4 / 10** mean forward
> interest in their own favourite genre · **5 / 7** independently articulated a
> structural 4D-vs-3D difference in writing · **7 / 7** used the 4D mini-map,
> **5 / 7** called it the most helpful aid.
>
> Every threshold set *before* collection was cleared. The 70%-plus band meant
> "polish work only."

**FOOT**
**Caveats, stated rather than buried.** N=7. Recruited from the Cardano-adjacent
community, including at least one moderator — a predisposed-favourable cohort.
**Zero non-gamers**, which the study design itself named as the highest-signal
segment. A form configuration bug voided 5 of 7 responses on the single most
valuable forward-looking question. And this round was run on the Slice 4D
obstacle course — **there is currently no naive-player data on any of the nine
Godot prototypes.** Closing that is a Round 2 with non-gamers and a fixed form;
the apparatus already exists.

**VISUAL** The banding pair, side by side, identical framing — this is the
deck's strongest single image and should be the largest.
**TIER** `MEASURED` on the pair. `MEASURED, N = 7, CAVEATED` on the survey.
`NOT YET TESTED` on the Godot prototypes.
**SOURCE** `_capture_banding.gd`; Playtest Results — Slice 4D Prototype (Round 1).
**ASSETS** `MiegakureLook/_capture_banding.gd` — **exists, shoots both frames
from one teleported camera.**

---

## Slide 7 — Nine prototypes. One non-engineer. Bounded help, logged.

**ON-SCREEN**

> Each one asked a question and returned an answer:
>
> | | |
> |---|---|
> | Can anyone read a 4D scene without training? | Banding is load-bearing; unbanded, a rotated view is a blank diamond |
> | Does rotation work as a navigation verb? | It reads immediately — but only where the route is signposted |
> | Can a vertical course stay legible once the slice can change? | Yes; physics is axis-aligned boxes only, so every rise is a step |
> | Does momentum-preserving linking survive four dimensions? | Both hold — cuts merge cumulatively, crossings accelerate |
> | What does aiming mean when a target can leave your slice? | You can miss in a direction you cannot see — and it reads as fair |
> | Can 4D matter be destroyed at interactive rates? | Yes, ~130 ms per carve |
> | Does procedural growth still read as botanical in 4D? | One tree carries the projected pass; a forest turns it to soup |
> | Can weather be a real 4D solid? | Coverage varies along w — rotating moves you into different weather |
> | Can a creature animate with no baked clips? | Limb count and proportions fall out of parameters; no rig needed |
>
> **Durability, separately.** Nine documented engine traps that each cost real
> time to find — a camera property silently falling through to wireframe, a
> trigger volume that never fires for a teleported body, a mesh-merge that
> mis-sizes its texture map. Two are upstream bugs worth reporting.

**FOOT**
The nine scenes are the independence measure: a non-engineer producing working
4D content with AI assistance and bounded, logged developer support. The trap
list is the durability measure, and it is the more uncomfortable half — it is a
record of where the tooling surprised someone, which is exactly what a competent
developer with no 4D background would hit. Both halves are needed; the first
alone would only show that AI can navigate a difficult engine.

**VISUAL** Nine icons from `catalogue.tres` in a tight grid, question/finding as
dense two-line type. Deliberately reads as a table of results, not a portfolio.
**TIER** `OBSERVED WHILE BUILDING, n = 1` on every finding. No naive-player
testing behind any of them.
**SOURCE** `catalogue.tres` `question`/`finding` fields;
`follow_up/engine_gotchas.md`.

---

# ACT 4 · WHERE WE ARE GOING

## Slide 8 — 2027 is preproduction. Two jams, not a vertical slice.

**ON-SCREEN**

> **A polished vertical slice proves one game is worth finishing. It does not
> prove the platform is fertile.** The claim here is platform-level — that
> roguelike, horror, RTS and puzzle-platformer are all viable on one substrate
> — so the proof has to match the claim.
>
> **Q2 · hosted jam.** Engine-restricted, open to outside entrants. Bar: **≥3
> entrant teams**. Prize pool pays every entrant something. Doubles as the
> recruiting funnel for a dedicated gameplay developer — a skill set nobody on
> the team currently has.
>
> **Q3 · external jam.** GMTK 2027, 11–20 Aug. Competing openly against other
> engines. No home-field advantage.
>
> **Q4 · Gate 1.** A defensible production plan, not a finished product.
>
> Jam results are evidence **independent of whether anyone likes the specific
> games produced.** Turnout and external participation are the signal. A single
> internally-made title invites a taste objection that waves away a real result.

**FOOT**
Preproduction carries no fixed internal milestones, because the work is
inherently unpredictable — the dated items above are the genuinely schedulable
events. Progress is reviewed at fortnightly checkpoints rather than gated to a
milestone. Setting a jam date also works backwards usefully: it forces an
explicit list of what an outside contributor needs in order to succeed, which is a
feature-prioritisation tool we don't otherwise have.

**VISUAL** Four-quarter horizontal band. The two jams as the only filled marks.
**TIER** n/a — plan slide.
**SOURCE** D2 §2, §7; D1's preproduction reframe scratch pad.

---

## Slide 9 — The shape past 2027, with two real exits

**ON-SCREEN**

> **2027 · exploration** — prove the core. IO Research plus grants where a
> window is live. Priced and pitched as R&D.
>
> **GATE 1 · establish the studio, or wind down.** Does the engine hold up
> under real production use — measured on engine metrics, player data, and
> developer scalability. If not, an orderly wind-down or re-scope, not continued
> investment chasing a platform that hasn't proven itself.
>
> **2028–29 · shipping** — 1 to 3 small titles on the shared core. IO scale-up
> capital primary; publisher advances against revenue share as a secondary
> source once there is something to show. No equity — there is no track record
> to price it against.
>
> **GATE 2 · three live paths.** A proven studio's default is simply to keep
> shipping; that is a good outcome on its own. Expanding into a launchpad, and
> the blockchain integration that would warrant, is an **optional third path**
> — not the assumed next step.

**FOOT**
A proposed sequence, not a commitment. The two gates are the point: explicit
exits rather than an open-ended runway. On blockchain specifically — before Gate
2 there is no genuine use for it, and bolting it on earlier would solve a problem
we don't have, add cost structure, and risk the studio's reputation given the
standing perception among gamers. Audience widens in step: the weird-geometry
niche, then students and academic buyers via a visualization title, then the
conversion funnel between them.

**VISUAL** Reuse the timeline diagram already in D1 rather than redrawing it —
one artifact, one diagram.
**TIER** n/a — plan slide.
**SOURCE** D1, proposed timeline and Option A.

---

## ★ Slide 10 — What this rests on

**ON-SCREEN**

> Six measures, one per half-pillar. Each has a threshold set in advance and an
> owner.
>
> | Measure | Threshold | Owner |
> |---|---|---|
> | **S1** stability | ≥30 fps at matched render distance | Aaron / Andrew |
> | **S2** world scale | exceeds the 4D Miner visible-in-slice baseline | Aaron / Andrew |
> | **S3** regeneration | ≤20 s, in place, no restart | Aaron / Andrew |
> | **Comprehension** | a naive, non-gamer cohort reads a 4D scene | Ramon |
> | **Appeal** | that cohort wants to play another, in another genre | Ramon |
> | **Independence + durability** | outside developers build on it with bounded help | Trym / Ramon |
>
> **One item is gate-essential and not yet built:** usable 4D terrain generated
> from seeds and parameters rather than bespoke construction. Its output feeds
> the S1–S3 package.

**FOOT**
The dependency chain between that terrain work and the S1–S3 evidence is an
engineering estimate and still needs Aaron and Andrew to validate it — it is
drawn as an estimate everywhere it appears, deliberately, because a solid line
would promote a guess into a claim. The three player and developer measures do
not yet have instruments in place; proposing them is half of what this brief is
for.

**VISUAL** Screenshot the **October Gate sub-map** from the Frontier Map. It
already carries three bands, the gate-essential halo, dashed estimated edges and
its own `ESTIMATED · ENGINEER VALIDATION REQUIRED` caveat.
**TIER** Thresholds are agreed. Instruments: `NOT YET IN PLACE` for three of six.
**SOURCE** S1–S3 criteria; `entries/map_october_gate.tres`.
**ASSETS** `Menu/_shot_frontier.gd` — **exists**, shoot with the October Gate
layout.

---

## Slide 11 — What would change the answer

**ON-SCREEN**

> Stated in advance, so a negative result is a finding rather than an argument.
>
> **If new 4D content still fundamentally requires bespoke specialist
> hand-construction** — the sustainable-rate case is unproven, and this is the
> one that ended the previous incarnation.
>
> **If the engine cannot hold frame rate or world scale** at a matched render
> distance, or regeneration needs a restart.
>
> **If a naive cohort can complete tasks without understanding anything** —
> task success without comprehension does not transfer between genres the way
> real competence does.
>
> **If they understand it and still don't want another** — comprehension
> without appeal is a geometry demo.
>
> **If the hosted jam draws fewer than three entrants** despite genuine
> outreach — external validation via jams is not landing; fall back to a single
> dogfooded title as the proof point.
>
> **If zero written partner interest exists** by mid-2027 — re-scope the RFP's
> ambition rather than continue waiting on the grant clock.
>
> Nothing here votes on the outcome. It states what the call will be read from.

**FOOT**
Four of these six are ours to name and we have named them; two are inherited
from the gate metrics. The closing line is the posture of the whole brief: this
is not a case for a verdict, it is the evidence base a verdict would be read
from. Three outcomes remain genuinely live — continue, pivot, stop.

**VISUAL** Six rows, plain, no imagery. Type-only slide as a deliberate change
of pace before the decision register.
**TIER** n/a.
**SOURCE** D2 §7 triggers 1 and 3; S1–S3 kill lines; the scalability condition;
the task-success dissociation from Thrust C.

---

# ACT 5 · THE AGENDA

## ★ Slide 12 — Open, and who closes it

**ON-SCREEN — two columns, designed to be marked up live**

> **YOURS**
>
> **Funding fallback for the RFP** — grant timeline only, or bridge a partner
> on before grant money lands and recover against the award? *Nicolas /
> Charles. Blocks the RFP's financial ask now.* Currently written up only in a
> superseded document.
>
> **Public release of the RFP** — go / no-go. *Charles.*
>
> **Is the twelve-week partner line a process milestone?** RFP drafted plus one
> written, funding-conditional expression of interest — rather than secured
> engagement, which the grant clock makes structurally unprovable on this
> timeline. *Confirmation needed, not assumed.*
>
> **Does player experience include appeal?** Per slide 4. *Trym.*
>
> **OURS**
>
> **Engine-side timeline validation** — the 2027 sequencing and the terrain
> dependency chain are both unreviewed. *Andrew, Aaron.*
>
> **Real budget figures** — every number in the twelve-month plan is a
> placeholder. *Trym / Finance.*
>
> **Are six triggers enough?** *Trym — flagged, not yet reviewed.*
>
> **Round 2 playtest on the Godot prototypes** — non-gamers, fixed form, N≥15.
> *Ramon. Zero data exists today.*
>
> **Feature-readiness list derived backwards from the jam** — what an outside
> contributor needs to succeed. *Unowned.*

**FOOT**
Four decisions above this team, five inside it. The first is the live blocker —
the RFP cannot go external until it resolves, and outreach credibility erodes
with each week it drifts. The last is unowned and cheap, and it doubles as
feature prioritisation for the whole year.

**VISUAL** Two columns, generous whitespace, numbered rows. This slide is
furniture for a conversation, not a graphic.
**TIER** n/a.
**SOURCE** Work Log rows; D2 §5 and §8; ARC package §6.2–6.3; Trym's Discord message.

---

## Slide 13 — Check any of this yourself

**ON-SCREEN**

> Every claim in this brief is attached to something you can run.
>
> Nine prototypes launch from one screen, each with the question it asked and
> what it returned. A second view of the same catalogue shows the programme
> rather than the tour: what is built, what is research, what is still fog —
> and which dependencies are estimates rather than facts.
>
> **Both screens read from one file.** A blurb rewritten in one place is
> rewritten in both, and neither can claim a prototype the other does not have.
>
> Built on the same engine module the open-sourcing plan covers.

**FOOT**
This is the independence evidence in its most direct form: the prototypes, the
menu that presents them, and the programme map are all the work of the
non-engineer on the team, with AI assistance and bounded developer support. It
is also the audit trail — if a number on slide 5 looks wrong, the scene it came
from is two clicks away.

**VISUAL** Menu full screen, Frontier Map overview beside it. Small, late,
unemphatic — the footnote that makes everything above it checkable.
**TIER** n/a.
**SOURCE** `Menu.tscn` / `Menu2.tscn`, `FrontierMap.tscn`, `Menu/FRONTIER_MAP.md`.
**ASSETS** Both **need shooting** via `_shot.gd` / `_shot2.gd` / `_shot_frontier.gd`.

---

# BUILD NOTES

## Assets

**Exist** · `MiegakureLook/_capture_banding.gd` (slide 6, the pair) ·
`Menu/_shot_frontier.gd` (slides 10, 13) · `Menu/_shot.gd`, `_shot2.gd`
(slide 13) · clips in `Menu/thumbs/` · `PhaseMaze/_capture_gate.gd` and
`ObstacleCourse/_capture_wgap.gd` (spares for slide 7) · D1's timeline image
(slide 9).

**Need shooting** · Voxel Mining carve with the ms/fps readout visible (slide 5)
· Portal crossing with velocity readout (slide 5) · Quantum Range miss
out-of-slice (spare) · one current Godot frame at fishing-prototype scale
(slide 2).

**Capture rules** — all of these are earned the hard way and still apply:

- Run **windowed**. `--headless` creates no rendering device and draws nothing.
- **Teleport the player** rather than driving polled input, so both frames of a
  pair share a camera exactly. `Input.action_press()` only feeds polled reads.
- **Read geometry off the builder at runtime** (`gap_width`, `band_centres`,
  gate tables) so retuning a scene cannot silently misframe a shot.
- **Pitch matters more than position.** `player.gd` applies pitch to
  `PlayerHead` only inside its mouse handler, so a capture script must set both.
- Output to `D:\temp_docs\deck_shots\`, crop with ffmpeg before upload.

## Visual language

From the 4D Lab Artifact board, same as the Octobergate deck. Ground **0.164
grey**, not the 0.062 void. Colour is semantic and category-level only: **blue**
= information and readout, **orange** = player-facing affordance, **green** =
stable/aligned, **violet** = 4D transformation. Debug views, axis labels, slice
markers and metric HUDs are **kept visible** — they are part of the identity,
not clutter. Avoid darkness that hides geometry.

## Open build questions

- Slide 2 needs a current Godot frame that stands next to the fishing prototype
  without looking thinner. The Ascent room renders near-monochrome; Slice
  Vision or Sky Box Clouds are the stronger candidates.
- Slide 9 reuses D1's timeline image. If D1's timeline changes in review, this
  slide changes with it — worth a note in D1 rather than a silent divergence.
- Whether to generate slides 5 and 7 from `catalogue.tres` at build time. It
  removes drift permanently but front-loads work. Recommend hand-placing for
  this pass and revisiting if the deck gets a second version.
