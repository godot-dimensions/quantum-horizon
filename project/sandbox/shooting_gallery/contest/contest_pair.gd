class_name ContestPair
extends Resource
## One pair in a contest sequence - a small group of spawn events (normally
## 2, but nothing requires exactly 2) that all become active together and
## must all resolve (hit or expired) before the next pair starts. Timing
## within a pair is relative to the pair itself, not a global sequence
## clock, so the sequence never rushes a player into the next pair before
## they've finished the current one, regardless of how long that took.

@export var events: Array[ContestSpawnEvent] = []
