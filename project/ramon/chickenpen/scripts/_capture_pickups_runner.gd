extends SceneTree

## Look at the coin and the egg, then walk into each and check it lands in a slot.

var _root: Node
var _f := 0
var _stage := 0
var _pending := ""
var _inv: Node


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/playable_world.tscn").instantiate()
	root.add_child(_root); current_scene = _root


func _process(_d) -> bool:
	_f += 1
	if _f < 70: return false
	if _pending != "":
		root.get_texture().get_image().save_png("res://smoke_test_output/pick_%s.png" % _pending)
		_pending = ""
		return false
	if _f % 30 != 0: return false
	_inv = _root.get_node("UI/Inventory")
	var player: Node4D = _root.get_node("Player")
	var rig: Node4D = _root.get_node("Player/CameraRig")
	var coin: Node4D = _root.get_node("World/Pickups/PocketWatch")
	var egg: Node4D = _root.get_node("World/Pickups/GoldenEgg")

	_stage += 1
	match _stage:
		1:
			_look_at(player, rig, coin, 2.0)
		2:
			_pending = "00_coin"
		3:
			_look_at(player, rig, egg, 1.9)
		4:
			_pending = "01_egg"
		5:
			# Now step into each, in its own slice.
			_look_at(player, rig, coin, 0.7)
			print("standing on the coin, in its slice")
		6:
			print("   inventory: %s" % [_inv.get("items")])
			_look_at(player, rig, egg, 0.7)
		7:
			print("standing on the egg")
			print("   inventory: %s" % [_inv.get("items")])
			_pending = "02_both"
		8:
			return true
	return false


## Copied from _playthrough_runner's _view, which is the version known to frame things.
## The two details that matter and that a hand-rolled copy keeps missing: the player's own
## basis has to be reset to identity, because the whole camera rig hangs off it, and the
## camera's yaw is the character's facing plus PI, not the facing itself.
func _look_at(player: Node4D, rig: Node4D, target: Node4D, back: float) -> void:
	var at: Vector4 = target.global_position
	var from := Vector4(at.x + back, 1.3, at.z + back, at.w)
	player.global_position = from
	player.global_basis = Projection.IDENTITY
	player.set("linear_velocity", Vector4.ZERO)
	# AIMED PAST IT, NOT AT IT. The camera sits behind the character and looks where the
	# character looks, so anything centred in the shot is directly behind the avatar and
	# invisible. Aiming a metre to one side puts the subject off-centre and in clear air.
	var to: Vector4 = (at + Vector4(1.6, 0.0, 0.0, 0.0)) - from
	var facing: float = atan2(to.x, to.z)
	player.set("_facing", facing)
	rig.set("yaw", facing + PI)
	rig.set("pitch", deg_to_rad(-11.0))
	rig.set("distance", 2.2)
	rig.set("_zoom_target", 2.2)
	rig.call("_apply")
	var avatar: Node4D = player.get_node_or_null("Avatar") as Node4D
	if avatar != null:
		avatar.basis = Basis4D.from_zx(facing)
