extends Node
## Spectator "treadmill" camera for watching the limb prototype live: keeps
## the player's camera at a fixed world-space offset from the wandering
## body every frame, so the creature stays framed no matter how far it
## wanders - the player's own movement/physics isn't needed for pure
## observation, so this just overrides its position/orientation directly
## every frame (in _process, which runs AFTER the player's own
## _physics_process each frame, so this always wins for what's actually
## rendered - reasserted fresh every frame, so there's no accumulated drift
## the way a one-off override would risk).

@export var player_path: NodePath
@export var body_path: NodePath
@export var offset: Vector4 = Vector4(0, 4, -9, 0)

@onready var player: Node4D = get_node(player_path)
@onready var body: Node4D = get_node(body_path)


func _process(_delta: float) -> void:
	var target_pos: Vector4 = body.position
	player.global_position = target_pos + offset
	player.global_basis = Basis4D.looking_at(target_pos - player.global_position)
