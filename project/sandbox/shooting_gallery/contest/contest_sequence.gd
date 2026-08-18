class_name ContestSequence
extends Resource
## An authored, ordered list of contest pairs - the whole point of building
## contest mode as data rather than code: a new sequence is a new .tres
## resource assigning ContestSequencePlayer.sequence, not a script change.

@export var pairs: Array[ContestPair] = []
