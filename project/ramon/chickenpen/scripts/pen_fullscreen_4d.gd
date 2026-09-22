extends Node

## Opens the prototype full screen when somebody plays it.
##
## WHY NOT `window/size/mode` IN project.godot, which is the obvious place: that setting
## wins over the command line. Every capture and diagnostic runner in this repo is started
## with `--windowed --resolution 1100x680`, and with the project default set to fullscreen
## they all came back 3840x2160 instead - which is slower, fills the author's screen, and
## silently changes what forty existing runners produce, including another person's. It
## is also a project-wide setting for a thing that is wanted in one prototype.
##
## SO IT IS DONE AT RUN TIME, AND ONLY WHEN THE GAME IS BEING PLAYED. A run driven by
## `--script` is a runner, not a session: it has no business resizing the author's screen,
## and the capture runners in particular depend on the window being the size they asked
## for. Checking the command line for it is crude, but it is the one fact that actually
## distinguishes the two cases.
##
## Escape is left bound to nothing here on purpose - Godot's own Alt+Enter still toggles
## back out, and adding a second way to do it would be a control nobody asked for.

## Off turns the whole thing off without unwiring the node.
@export var full_screen: bool = true
## Borderless fullscreen rather than exclusive: it alt-tabs cleanly, which matters more
## in a prototype somebody is testing against notes on a second screen than the frame or
## two exclusive mode would win back.
@export var exclusive: bool = false


func _ready() -> void:
	if not full_screen:
		return
	if DisplayServer.get_name() == "headless":
		return
	for argument in OS.get_cmdline_args():
		if String(argument) == "--script" or String(argument) == "-s":
			return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
		if exclusive else DisplayServer.WINDOW_MODE_FULLSCREEN)
