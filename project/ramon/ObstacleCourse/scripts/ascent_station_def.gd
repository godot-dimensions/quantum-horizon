@tool
extends Resource
class_name AscentStationDef4D

## One station on THE 4D ASCENT - a bay where a single obstacle beat lives.
##
## The course is a LIST, not a layout, the same bet `hub_gate_ring_4d.gd` makes:
## `AscentBuilder4D` derives every position, every connecting stair and every
## recovery floor from this array, so re-ordering it re-lays-out the tower and
## adding a beat is one `.tres`. Heights are authored (the brief pins each beat
## to a Y range); bearings are derived, because a helix that has to be re-typed
## by hand every time a beat moves is a helix nobody will re-tune.

## Beat number from the brief's course script, "00".."09". Used for node names
## and telemetry, so it stays a string rather than an int - "00" and "0" reading
## as the same station in a log is a debugging afternoon nobody needs.
@export var beat_id: String = "00"

## Human-readable name, for the editor outline and telemetry only.
@export var label: String = "Calibration court"

## 0 = white (reveal and bypass), 1 = yellow (align and time), 2 = red (combine
## and ascend). Drives colour only. Deliberately NOT the same axis as the W
## banding: the brief's own kill criteria call out testers confusing tier colour
## with W location, so tier colour never encodes anything spatial.
@export_range(0, 2) var tier: int = 0

## Deck height in metres, from the brief's per-beat Y ranges.
@export var height: float = 0.0

## Deck footprint. Square-ish by default so a deck reads the same from any
## approach angle - which matters more here than in a 3D course, because slice
## rotation removes most of the cues people navigate by.
@export var deck_size: Vector2 = Vector2(8.0, 6.0)

## Extra rotation around the spine, on top of the even spacing the builder
## derives. Lets one bay be nudged clear of another without re-authoring the
## whole helix.
@export var bearing_nudge_degrees: float = 0.0

## Marks this deck as a checkpoint bay. The brief asks for three; which three is
## a tuning decision, so it lives on the station rather than in code.
@export var is_checkpoint: bool = false

## Skips generating the temporary Phase 1 stair up to this station. Set once a
## real 4D obstacle replaces the stair, so the greybox scaffolding disappears
## beat by beat instead of in one risky sweep.
@export var suppress_phase1_stair: bool = false
