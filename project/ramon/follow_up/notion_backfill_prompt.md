# Backfilling your work onto the Notion board — a prompt to paste

The **Claude Work Log — cross-team status** board lives in the Quantum Horizon R&D
Working Space. Trym set it up on 10 September 2026 as a shared operational status
source for everyone's Claude instances, not just his — but in practice almost nobody
writes to it, so it reads as one person's private status page.

If your work is not on it, it is invisible to the gate.

Claude can reconstruct your history from git and fill it in for you. Paste the prompt
below into a Claude Code session opened on this repo.

## The prompt

```
Backfill my work onto the team's Notion board from my git history.

1. Find the "Claude Work Log — cross-team status" database in Notion (it lives
   under the Quantum Horizon — R&D Working Space). Read its schema and check
   what rows already exist under my name so we don't duplicate anything.

2. Mine this repo's git log for my commits. Go back as far as there is real
   work, not just the last week. Group them into coherent work ITEMS — one card
   per prototype, tool or feature — not one card per commit.

3. Date each card from its substantial submit, NOT its last touch. This matters:
   project-wide renames, engine-API follow-ups and sweeps that add a file to
   every folder will make dead prototypes look like last week's work. Find the
   largest commit per area by lines changed, and discard it if it turns out to
   be a cross-cutting sweep rather than real work on that thing.

4. Skip chores. Maintenance, submodule bumps and rename-following don't belong
   on the board — only substantive prototypes, tools and deliverables.

5. SHOW ME THE FULL LIST FIRST as a table (Item / Area / Status / Date) and wait
   for my approval before writing anything to Notion. Flag any judgement calls:
   Area assignments you're unsure of, items you merged, and anything you'd file
   differently.

6. Be honest about status. Anything parked, blocked or still moving gets
   "Blocked" / "Waiting on input" / "In progress" with the Blocking On field
   filled in — not "Done". A board that overstates completion is worse than no
   board three weeks before a gate.

Area options are Thrust A (engine & rendering), Thrust B (content & 4D science),
Thrust C (interface, control & perception), Engine, Partners, Ops.
```

## Before you paste it

**You need the Notion connector enabled** in your Claude Code session. Without it
step 1 fails silently and everything after it is invention.

## Why each step is in there

**Step 3 is the one that does the real work.** Six of Ramon's prototypes were last
*touched* on 19 September by a sweep that added frame-capture scripts to every folder,
and several more by a project-wide `vertices` → `vertex_positions` rename. Dating cards
from those would have claimed he was working on Phase Maze last week when the real work
finished on 12 August. Find the biggest commit per area, then check whether it is
actually about that area or just swept through it.

**Step 5 is the one to keep when you trim the prompt.** The temptation is to let Claude
write the cards directly. Reviewing the table first is where you catch a wrong date, a
prototype filed under the wrong thrust, or two things that should not have been merged
— and this is a shared board, so those are visible to the whole team.

**Step 6 is not modesty.** Ramon's backfill came out as 16 Done and 3 not: the chicken
pen still moving, the gait polish parked on a design decision, and the gizmo patch
waiting on Aaron. Those three are the rows a reader actually learns something from.

## What it produced

Nineteen cards spanning 6 August to 24 September 2026, in about ten minutes of back and
forth. `Engine`, `Thrust A` and `Thrust B` went from zero rows to populated.

The schema, if you want to add rows by hand instead:
`Item` (title) · `Area` · `Person` · `Status` · `Current Detail` · `Blocking On` ·
`Last Updated`.
