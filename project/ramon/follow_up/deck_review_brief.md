# Review brief — October Gate stakeholder deck

Context for an outside reviewer. Read this before critiquing the slides.

## What this is

A 13-slide stakeholder deck for the **Quantum Horizon October gate, 16 October 2026**.
Quantum Horizon is an R&D programme at IO Research exploring whether four-dimensional
space works as a *game* platform. The gate decides whether to fund a 2027 preproduction
year, rescope, or stop. All three outcomes are live.

Audience: Scott Kelly (reviews/approves), plus Charles, Aggelos, Nicolas, Brandon and the
investment-committee side. They are not designers and not 4D specialists. Several of them
have questioned the funding of the design/comprehension seat specifically.

Author of the deck: Ramon Tuynman, design/art/exposition lead — who also owns one of the
two research problems the programme is trying to prove.

## Slide order

| # | Slide |
|---|---|
| 01 | Building toward a fourth spatial dimension |
| 02 | Six bets became one question |
| 03 | Why nine prototypes, not one demo |
| 04 | DIVIDER — Pillar 01, Engine performance |
| 05 | Quantum Engine (placeholder name) |
| 06 | The artifact is the whole bar, not one demo |
| 07 | DIVIDER — Pillar 02, Player experience |
| 08 | Comprehension is the second thing we have to prove |
| 09 | DIVIDER — Pillar 03, Developer experience |
| 10 | Nine prototypes, each answering one question |
| 11 | The conditions under which we would stop |
| 12 | Three decisions that are not ours to make |
| 13 | October sets the next test |

## The argument the deck is making

Three pillars, each a question:

1. **Engine performance** — can richer 4D worlds run reliably?
2. **Player experience** — can players read them, and want another?
3. **Developer experience** — can other people build with the tools?

The programme's honest position is that pillar 3 is largely evidenced (nine prototypes
built by a designer, not an engine programmer), pillar 1 has thresholds defined but none
measured, and pillar 2 has no evidence at all — no first-time player has touched any of
the nine prototypes.

The deck is deliberately built to state that rather than hide it.

## Evidence discipline — the rule the deck runs on

Every claim is tiered, and the tier is visible:

- **Measured** — a number exists from the build
- **Observed, n=1** — one person's judgement, that person already fluent in 4D
- **Not yet measured / not yet measurable** — stated as such, never implied

Specific commitments made in the slides:

- Slide 06 shows three numeric thresholds (S1 stability, S2 world scale, S3 regeneration)
  with **0 of 3 measured**, and states that the threshold values themselves are provisional.
- Slide 08 separates the cost of *finding out* where comprehension stands (cheap, bounded,
  15+ players) from the cost of *closing* whatever that finds (unbounded, an open research
  problem, the RFP's largest thrust). The second cost is drawn as a meter that runs off the
  edge of the slide.
- Slide 10 labels six of nine prototype tiles `capture pending` rather than leaving gaps.
- Slide 11 splits stop conditions by which gate reads them, and marks the four that cannot
  be evaluated until 2027 as `NOT YET MEASURABLE`.
- Slide 11 carries a note stating it is deck framing, **not** the register of record — the
  costed triggers live in Deliverable 2 §7, which currently holds five and is under review.

**Do not suggest softening any of this.** Overclaiming has already cost this project
credibility once; the honesty is the deck's main asset with this audience.

## Design system

- Ground `#EFEFEE`. Content panels recessed to `#E6E6E4`. White `#FFFFFF` reserved for
  image plates and for emphasised blocks.
- Type: Montserrat only. Display 126, section head 110–120, miniheader 34 SemiBold +10
  tracking, body 28–32, caption 22–26.
- Three dark dividers at `#303030` punctuate the chapters and carry the deck's contrast.
- Chapter colour coding: Engine `#CBE86A`, Player `#EA6F96`, Developer `#9F7FFF`,
  and the gate itself `#FFD166`.
- Accent rule: one per slide, and it marks the **open question**, not the achievement.
  This is a deliberate inversion of normal practice.

## Decisions already taken — please don't relitigate these

- **Bright deck, not dark.** An earlier dark version exists. The Godot captures are bright
  and benefit from a light surround.
- **Light grey ground, not white.** Pure white was explicitly rejected.
- **Rounded corners, no strokes.** Contrast by fill only.
- **The accent marks gaps, not wins.** See above.
- **Dividers are dark on purpose.** Thirteen light slides in a row read as monotonous.
- **Mid-grey tints were tried and abandoned.** Anything around 0.55–0.75 luminance
  compromises both ink and white text.

## Known open items — critique here is welcome

- Six of nine prototype captures are still missing.
- The three dark dividers carry a colour logo built from two blend-mode layers that only
  resolve correctly on a light ground; they render badly on dark and need the inverted mark.
- Slide 01's cross-section diagram is the only explanation of what a 4D slice *is*.
  It may be too little, too early, or in the wrong place.
- Deck shows seven stop conditions; Deliverable 2 §7 holds five; the ARC package holds
  five of its own. Three documents, three counts.
- Slide 05 lists ~29 engine features in four columns. Possibly too dense.
- The deck never states a budget. All figures in the underlying plan are placeholders.

## What useful critique looks like

Most valuable:

1. **Does the argument land for a non-specialist in one pass?** Especially slides 02, 06
   and 08, which carry the most reasoning.
2. **Is anything overclaimed?** Flag any sentence that asserts more than the stated tier
   supports. This is the highest-value catch.
3. **Where does a hostile reader push back?** Assume a stakeholder already sceptical about
   funding the comprehension seat.
4. **Slide 08 specifically** — does the two-cost structure read, or does it look like
   hedging?
5. **Cuts.** Thirteen slides for a gate conversation may be two too many. Which two?

Less valuable: palette suggestions, "add more visuals", requests for a tidier narrative
arc at the expense of the evidence tiering, or proposals that require data the programme
does not have.
