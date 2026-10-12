extends Area4D
## Reusable "player walks into this, something happens" trigger.
## Fires instantly on entry, no dwell time (deliberate simplicity for this
## testing stage - revisit if instant-fire proves too easy to trigger
## accidentally). Doesn't implement any specific behavior itself - callers
## connect to `triggered` and decide what happens (despawn+respawn, platform
## activate/deactivate, catch, etc).
class_name InteractionTrigger4D

## Emitted once per entry, with the entering body. Re-fires on every fresh
## entry (a body that exits and re-enters fires again).
signal triggered(body: PhysicsBody4D)

## When true (the default), only CharacterBody4D bodies fire the trigger.
## Set false if a future use case wants any physics body to count.
@export var player_only: bool = true

func _ready() -> void:
	body_entered_self.connect(_on_body_entered_self)

func _on_body_entered_self(body: PhysicsBody4D) -> void:
	print("InteractionTrigger4D._on_body_entered_self fired: body=%s get_class=%s is_CharacterBody4D=%s" % [
		body, body.get_class() if body else "<null>", body is CharacterBody4D,
	])
	if player_only and not (body is CharacterBody4D):
		return
	triggered.emit(body)
