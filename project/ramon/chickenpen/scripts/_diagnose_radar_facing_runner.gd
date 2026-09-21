extends SceneTree

## Which way is UP on the radar?
##
## The radar copies the Shooting Range's projection, which maps the player-frame +Z onto
## screen-down. On the Range that is correct, because its player faces -Z - the ordinary
## Godot looking_at convention. THIS scene does not: everything here is posed with
## Basis4D.from_zx(facing), so +Z is FORWARD. Copying the line without copying the
## convention would put everything ahead of you at the bottom of the dial.
##
## So: stand a chicken dead ahead, and see where its dot lands.

const NAT_LOG_2: float = 0.6931471805599453094
const HALFWAY_METERS: float = 8.0

var _root: Node
var _f := 0


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/chickenpen.tscn").instantiate()
	root.add_child(_root); current_scene = _root


func _process(_d) -> bool:
	_f += 1
	if _f < 70: return false
	var player: Node4D = _root.get_node("Player")
	var rig: Node4D = _root.get_node("Player/CameraRig")
	var manager: Node = _root.get_node("Chickens")

	player.position = Vector4(0.0, 1.3, 0.0, 0.0)
	rig.set("yaw", 0.0)
	rig.call("_apply")

	# The rig unrotated: its forward is +Z, the same convention the avatars are posed with.
	var frame: Projection = rig.global_basis.inverse()
	var fails: int = 0

	for pair in [["dead ahead", Vector4(0.0, 0.0, 10.0, 0.0), "above"],
			["behind", Vector4(0.0, 0.0, -10.0, 0.0), "below"],
			["to the right", Vector4(10.0, 0.0, 0.0, 0.0), "right"],
			["to the left", Vector4(-10.0, 0.0, 0.0, 0.0), "left"]]:
		var at: Vector4 = pair[1]
		var rel: Vector4 = frame * at
		var span: float = rel.length()
		var squashed: float = 1.0 - exp(-span * (NAT_LOG_2 / HALFWAY_METERS))
		var s: Vector4 = rel * (squashed / span)
		# The radar's own line: screen x from the frame's x, screen y from MINUS its z.
		var screen := Vector2(s.x, -s.z)
		var reads: String
		if pair[2] == "above" or pair[2] == "below":
			reads = "below centre" if screen.y > 0.0 else "above centre"
		else:
			reads = "right of centre" if screen.x > 0.0 else "left of centre"
		var want: String = pair[2] + (" centre" if pair[2] in ["above", "below"] else " of centre")
		var ok: bool = reads == want
		if not ok:
			fails += 1
		print("   %s something %-14s draws %-16s  (should be %-16s) %s"
			% ["PASS" if ok else "FAIL", pair[0], reads, want, ""])

	print("\n%d FAIL(s)" % fails)
	quit(1 if fails > 0 else 0)
	return true
