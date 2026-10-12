extends PenNpcTalk4D

## Talking to Trym in the cinema once the presentation is over.
##
## THE FARM'S OWN MACHINERY, NOT A SECOND ONE. This started as a few lines typed into the
## theatre's caption band, on the reasoning that the room already had a voice and adding a
## dialogue system for three sentences was disproportionate. Ramon's answer was that the
## conversation should look and work like every other conversation in the game, and he is
## right: the caption is the PRESENTATION talking, and a character answering you is a
## different thing that happens to use words. A player who has learned that F over
## somebody's head means a conversation should get a conversation.
##
## So this is PenNpcTalk4D, exactly as the keeper, Mithra, the professor and Nike use it -
## the same box, the same prompt over his head, the same freeze and the same two-shot. All
## it adds is WHEN, and WHICH node of his script.
##
## WHICH IS THE ONLY INTERESTING PART. The prompt does not exist until the talk has
## finished, so F stays free for everything else it does while a presentation is running;
## and the show announces that itself, by `finished` from let_them_go, which fires whether
## you sat through part two or declined it.

const TrymScript = preload("res://ramon/dialogue/trym_script.gd")

## The two nodes of his script this opens on: the first time, and every time after it.
## They live in the dialogue file with all the other writing, even though nothing on the
## farm ever reaches them.
@export var first_node: String = "greet_cinema"
@export var again_node: String = "greet_cinema_again"
## The third time, when you refuse to be shooed out and he tells you where you are.
@export var insist_node: String = "greet_cinema_insist"
## And then he is done. Three conversations, and the prompt stops appearing.
@export_range(1, 10, 1) var done_after: int = 3
@export var show_path: NodePath = NodePath("../Show")
## Where his head is, for the box to sit over and the prompt to hang from.
##
## A SEPARATE NODE THAT FOLLOWS HIM, not a child of him - which is the farm's arrangement
## too, and not a stylistic choice. block_avatar_4d rebuilds its own body and frees every
## child it has while doing it, so a Head parented to the presenter is a freed object by
## the time anything asks for it. The box then had nothing to sit over and fell back to
## the bottom of the screen.
@export var head_path: NodePath = NodePath("../PresenterHead")
@export var presenter_path: NodePath = NodePath("../Presenter")
@export_range(0.0, 4.0, 0.05) var head_height: float = 1.5

var _show: Node
var _head: Node4D
var _presenter: Node4D
var _over: bool = false
## How many times you have spoken to him in here.
var _spoken: int = 0


func _configure() -> void:
	_talk.use_script(TrymScript.NODES, TrymScript.START)
	_show = get_node_or_null(show_path)
	_head = get_node_or_null(head_path) as Node4D
	_presenter = get_node_or_null(presenter_path) as Node4D
	if _show != null and _show.has_signal("finished"):
		_show.connect("finished", func() -> void: _over = true)
	# A second showing (sitting down again after the end): he is presenting again, so he
	# is not available to talk until it is over again.
	if _show != null and _show.has_signal("restarted"):
		_show.connect("restarted", func() -> void: _over = false)


## Not until the whole thing has finished - both halves, whichever way you went. And not
## at all once he has told you where you are.
##
## THE PROMPT GOES, RATHER THAN THE ANSWER GETTING SHORTER. He has said the one thing he
## was not going to say; a fourth conversation could only be him deflecting it, and a man
## who deflects the same question on a loop is a vending machine. So F simply stops
## offering him, and the last thing he ever says to you in that room is the line about the
## fourth dimension. Silence is the character finishing his sentence.
func _can_talk() -> bool:
	if not _is_over() or _spoken >= done_after:
		return false
	return super()


func _is_over() -> bool:
	if _over:
		return true
	# The signal is the reliable answer; the state is here for a scene loaded straight
	# into, which never had a beginning to announce an end of.
	return _show != null and _show.has_method("is_over") and bool(_show.call("is_over"))


func _tag_text() -> String:
	return "%s talk to Trym" % _catch_key()


## THREE CONVERSATIONS, AND THEY ARE NOT THE SAME ONE. The first has the questions in it.
## The second is him trying to leave. The third is you refusing to be shooed out, which is
## the only way that last beat could arrive without being handed to you.
##
## And then he stops - see _can_talk. Repeating the last one would turn a slip into an
## announcement, and there is nothing after it that is not worse than silence.
func _entry_node() -> String:
	_spoken += 1
	match _spoken:
		1:
			return first_node
		3:
			return insist_node
		_:
			return again_node


## Keep the head over him. He walks on at the start and stands at his mark after that, so
## this is three lines rather than an animation - but they have to be three lines that run
## every frame, because the walk on is exactly when somebody might talk to him.
func _process(delta: float) -> void:
	super(delta)
	if _head != null and _presenter != null:
		_head.global_position = _presenter.global_position 			+ Vector4(0.0, head_height, 0.0, 0.0)
