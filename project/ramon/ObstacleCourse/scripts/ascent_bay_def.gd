@tool
extends Resource
class_name AscentBayDef4D

## One bay on THE 4D ASCENT (wall course) - a locally controlled space where a
## single obstacle beat lives.
##
## Unlike the helix course's `AscentStationDef4D`, a bay's plan position is
## AUTHORED rather than derived. The brief's page 5 elevation is a drawing, not a
## curve: the route zigzags left and right across the spine at specific points,
## and which side of the spine a beat sits on is the substance of that beat, not
## a by-product of spacing it evenly.

## Beat number from the brief's course script, "00".."09". A string rather than
## an int so "00" and "0" can never read as the same bay in a telemetry log.
@export var beat_id: String = "00"

## Human-readable name, for the editor outline and telemetry only.
@export var label: String = "Calibration court"

## 0 = white (reveal and bypass), 1 = yellow (align and time), 2 = red (combine
## and ascend). Drives colour only, and colour here means TIER AND NOTHING ELSE -
## the brief's kill criteria fire if testers start reading tier colour as a
## spatial or W cue.
@export_range(0, 2) var tier: int = 0

## Deck height in metres, from the brief's per-beat Y ranges.
@export var height: float = 0.0

## Position across the tower's width. The zigzag lives here.
@export var plan_x: float = -10.0

## Depth within the tower. Bays sit in front of the spine, which is broad in z
## and acts as a backdrop reference rather than a wall to detour around.
@export var plan_z: float = -9.0

## Bay footprint (width, depth).
@export var deck_size: Vector2 = Vector2(8.0, 6.0)

## Marks this bay as a checkpoint. The brief asks for three; which three is a
## tuning decision, so it lives on the bay rather than in code.
@export var is_checkpoint: bool = false

## Skips the temporary Phase 1 stair into this bay. Set once a real 4D obstacle
## replaces it, so the scaffolding retires one beat at a time and the course
## stays finishable at every commit.
@export var suppress_phase1_stair: bool = false
