extends Control
## Readout for the portal test chamber.
##
## Speed is on screen because it is the mechanic: watching the number survive a
## crossing is how you tell a portal from a door, and watching it climb in the
## floor-to-ceiling loop is how you tell the fall is real.

@onready var _builder: Node4D = $"../ChamberWorld/ChamberBuilder"
@onready var _link: Node = $"../ChamberWorld/PortalLink"
@onready var _gun: Node = $"../ChamberWorld/PortalGun"
@onready var _player: CharacterBody4D = $"../ChamberWorld/Player"
@onready var _label: Label = $Readout


func _placed(aperture: Node4D) -> String:
	if aperture == null or not is_instance_valid(aperture):
		return "not placed"
	return "on %s" % aperture.surface.name


func _process(_delta_time: float) -> void:
	var velocity: Vector4 = _player.linear_velocity
	var horizontal := Vector2(velocity.x, velocity.z).length()
	_label.text = "\n".join([
		"PORTAL TEST CHAMBER  -  shoot two openings, reach the ledge you cannot jump to",
		"",
		"LEFT CLICK blue portal    F yellow portal    WASD move    SPACE jump",
		"RIGHT CLICK + mouse rotate 4D    Q / E move through w    ESC free mouse",
		"",
		"blue     %s" % _placed(_link.blue),
		"yellow   %s" % _placed(_link.yellow),
		"linked   %s" % ("yes - both openings are passable" if _link.is_paired() else "no - a lone portal is a solid oval"),
		"",
		"speed    %.1f m/s  (%.1f horizontal, %.1f vertical)" % [velocity.length(), horizontal, velocity.y],
		"crossings %d,  last exit speed %.1f m/s" % [_link.teleport_count, _link.last_teleport_speed],
		"",
		"last shot: %s" % _gun.last_shot_status,
		"",
		"LEDGE: %s" % ("REACHED" if _builder.goal_reached else "not yet - it is 3 m up and you jump 1 m"),
		"",
		"White surfaces take a portal anywhere you aim; dark ones refuse. Shooting a",
		"colour again closes the old one. Put both on the white floor and ceiling",
		"squares and step in: portals keep your motion, they only turn it.",
	])
