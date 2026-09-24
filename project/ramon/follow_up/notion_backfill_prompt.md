# Backfilling your work onto the Notion board — a prompt to paste

The **Claude Work Log — cross-team status** board lives in the Quantum Horizon R&D
Working Space. Trym set it up on 10 September 2026 as a shared operational status
source for everyone's Claude instances — but in practice almost nobody writes to it.

If your work is not on it, it is invisible to the gate.

You do not have to fill it in by hand. Claude can reconstruct your history from git
and write the cards for you. Open a Claude Code session on this repo and paste the
prompt below.

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

**You need the Notion connector enabled** in your session. Without it, step 1 fails
and everything after it is invention.

Expect about ten minutes of back and forth. Most of that is you reading the table at
step 5 and correcting it.

## Why three of the steps are in there

**Step 3 is the one that does the real work.** This repo is full of commits that swept
through every folder at once — a `vertices` → `vertex_positions` rename, engine-API
follow-ups, a batch that dropped a capture script into half a dozen prototypes. Any of
those will make a prototype you finished in August look like last week's work. Tell
Claude to find the biggest commit per area, then check whether it was actually about
that area or just passed through it.

**Step 5 is the one to keep if you trim the prompt.** The temptation is to let Claude
write the cards straight to Notion. Reviewing the table first is where you catch a
wrong date, something filed under the wrong thrust, or two items that should not have
been merged. This is a shared board — those mistakes are visible to everyone.

**Step 6 is not modesty.** The rows people actually learn something from are the ones
that are not Done: what is still moving, what is parked and why, and who you are
waiting on. A board of uniform green tells a reader nothing, and three weeks before a
gate it invites a question you do not want asked in the room.

## Adding rows by hand instead

The schema is: `Item` (title) · `Area` · `Person` · `Status` · `Current Detail` ·
`Blocking On` · `Last Updated`.

`Status` options are Not started · In progress · Blocked · Waiting on input · Done.
