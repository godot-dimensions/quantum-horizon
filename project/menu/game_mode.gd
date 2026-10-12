extends Node
## Shared mode-selection flag (autoload singleton).
##
## main_menu.gd sets this immediately before change_scene_to_file() for any
## mode entry that needs it; the shooting gallery's own spawners
## (gallery_target_spawner.gd, duck_row_spawner.gd, contest_sequence_player.gd)
## read it in their own _ready() to decide whether to self-enable - this is
## the only way to pass a selection into a scene change_scene_to_file() can't
## take parameters for.

enum Mode { FREE, CONTEST }

var selected_mode: Mode = Mode.FREE
