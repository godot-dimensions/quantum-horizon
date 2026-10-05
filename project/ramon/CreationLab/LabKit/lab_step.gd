@tool
extends Resource

## One step of a lab explanation: everything a bay says and does, in one place, so the lectern,
## the guide panel, the controls card and the explainer film's captions all read the same words
## and can never disagree.
##
## The beat of every step (follow_up/creation_lab_plan.md): arrive, show, try, unlock, next. The
## guide panel shows `idea` and `task` on arrival; the step's content scene reports when the task
## is done; then the card opens its detail and the lift lights up.
##
## NO class_name (engine_gotchas.md): preload this file.

## The step's code on its signage ("CL-03").
@export var code: String = "CL-00"
## Which part of the explanation it belongs to, for its colour.
@export_enum("atrium", "build", "motion", "hall") var part: String = "build"
## The number on the bay's back wall; -1 for none (the Atrium, the Hall).
@export var number: int = 1
@export var title: String = ""
## The one idea, in a sentence.
@export_multiline var idea: String = ""
## The one task, in a sentence ("Press ] to widen the ball").
@export_multiline var task: String = ""
## The keys the task is done with, shown as chips beside it.
@export var task_keys: PackedStringArray = PackedStringArray()
## What just happened, said once the task is done.
@export_multiline var after: String = ""
## The card: how it was made, what it shows, what it cannot do yet, and what was measured.
@export_multiline var method: String = ""
@export_multiline var shows: String = ""
@export_multiline var limits: String = ""
@export_multiline var measured: String = ""
## How sure the MEASURED row is, in the menu's own words.
@export_enum("Measured", "Observed while building · n = 1", "Not yet tested") var tier: String = "Measured"
## Extra controls for the curious, as "key|what it does".
@export var extras: PackedStringArray = PackedStringArray()
## The film's captions for this step, in order.
@export var captions: PackedStringArray = PackedStringArray()
## The bay shell's size in metres (0: the sequence's own `bay_size`). The Hall at the end of a
## route is a big room.
@export var shell_size: float = 0.0
## The bay's content: rigs, props and the step's own behaviour (a scene whose root extends
## CreationLab/scripts/bay_content_4d.gd or follows the same duck-typed surface).
@export var content: PackedScene
