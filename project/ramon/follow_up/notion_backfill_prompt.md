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

2. Work out which commits are mine before mining anything: read
   `git config user.name` and `git config user.email`, then show me the authors
   actually present in the log (`git log --pretty="%an <%ae>" | sort | uniq -c`)
   and confirm which of them are me. People commit under more than one identity,
   and on a shared checkout they sometimes commit under someone else's.

3. Check every repo I work in, not just this one. This project nests
   submodules — engine/godot and engine/modules/4d — and engine work lives in
   those rather than here, so a log of the outer repo alone can miss most of
   it. Run the author counts in each, tell me where my commits actually are,
   and mine all of them. Ask me if I have work in a sibling repo outside this
   tree.

4. Mine the log for my commits. Go back as far as there is real work, not just
   the last week. Group them into coherent work ITEMS — one card per prototype,
   tool or feature — not one card per commit.

5. Date each card from its substantial submit, NOT its last touch. This matters:
   project-wide renames, engine-API follow-ups and sweeps that add a file to
   every folder will make dead prototypes look like last week's work. Find the
   largest commit per area by lines changed, and discard it if it turns out to
   be a cross-cutting sweep rather than real work on that thing.

6. Skip chores. Maintenance, submodule bumps and rename-following don't belong
   on the board — only substantive prototypes, tools and deliverables.

7. SHOW ME THE FULL LIST FIRST as a table (Item / Area / Status / Date) and wait
   for my approval before writing anything to Notion. Flag any judgement calls:
   Area assignments you're unsure of, items you merged, and anything you'd file
   differently.

8. Be honest about status. Anything parked, blocked or still moving gets
   "Blocked" / "Waiting on input" / "In progress" with the Blocking On field
   filled in — not "Done". A board that overstates completion is worse than no
   board three weeks before a gate.

Area options are Thrust A (engine & rendering), Thrust B (content & 4D science),
Thrust C (interface, control & perception), Engine, Partners, Ops.
```

## Before you paste it

**You need the Notion connector enabled** in your session. Without it, step 1 fails
and everything after it is invention.

**If your work is mostly in documents rather than commits, this is the wrong tool.**
Some people on the team have no commits in either repo — their contribution is real
and simply is not in git. Add those rows by hand using the schema at the bottom.

Expect about ten minutes of back and forth. Most of that is you reading the table at
step 7 and correcting it.

## Why four of the steps are in there

**Step 2 catches a quiet failure.** "My commits" is not something Claude can work out
on its own, and if it does not ask, it will happily summarise the whole team's work as
yours. In a repo where one person holds two thirds of the commits, that mistake looks
plausible right up until somebody reads the board.

**Step 3 is the one that matters most for engine work.** The 4D module is a submodule,
and a `git log` of the outer repo only sees the pointer moving, not the work. Someone
whose contribution is overwhelmingly in `engine/modules/4d` will come out of an
outer-repo-only run looking like a light contributor — roughly a sixth of their real
output. Run the author counts in each repo before deciding where to mine.

**Step 5 is the one that does the real work on dates.** This repo is full of commits
that swept through every folder at once — a `vertices` → `vertex_positions` rename,
engine-API follow-ups, a batch that dropped a capture script into half a dozen
prototypes. Any of those will make a prototype you finished in August look like last
week's work. Find the biggest commit per area, then check whether it was actually
about that area or just passed through it.

**Step 7 is the one to keep if you trim the prompt.** The temptation is to let Claude
write the cards straight to Notion. Reviewing the table first is where you catch a
wrong date, something filed under the wrong thrust, or two items that should not have
been merged. This is a shared board — those mistakes are visible to everyone.

And step 8 is not modesty. The rows people actually learn something from are the ones
that are not Done: what is still moving, what is parked and why, and who you are
waiting on. A board of uniform green tells a reader nothing, and three weeks before a
gate it invites a question you do not want asked in the room.

## Adding rows by hand instead

The schema is: `Item` (title) · `Area` · `Person` · `Status` · `Current Detail` ·
`Blocking On` · `Last Updated`.

`Status` options are Not started · In progress · Blocked · Waiting on input · Done.
