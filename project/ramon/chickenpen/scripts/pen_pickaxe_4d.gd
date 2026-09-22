extends Node

## Swinging the pickaxe at a voxel rock.
##
## IT REUSES VoxelMining WHOLE, and does not fork any of it. project/ramon/VoxelMining/
## already has the rock, the per-voxel colliders and the carve - `mine_at_shape()` takes
## the CollisionShape4D a raycast handed back and removes that voxel. What was missing was
## only the part that belongs to THIS scene: which tool is in your hand, and where the
## swing comes from. Its own mining_axe.gd could not be used as-is because it reaches for
## `$"../Player/PlayerHead"` - a node this scene does not have, the camera living on an
## orbit rig instead - and because it is always on, which is wrong the moment the belt has
## more than one thing in it.
##
## THE SWING COMES FROM THE CHARACTER, NOT THE CAMERA. The camera sits five metres behind
## you on its arm, so a ray cast from there would spend its whole melee range crossing the
## gap before it reached anything you could plausibly hit. The ray starts at chest height
## on the body and travels along the way the camera looks, which is also the way a press
## of forward would send you.
##
## IT TAKES THE KEY ONLY WHEN IT IS UNAMBIGUOUS. `fire` is the same button that puts down
## a carried chicken, so this listens in `_input` - ahead of the catcher's
## `_unhandled_input` - and claims the press only with the pickaxe in hand, empty arms,
## the mouse captured, and rock actually in reach. Every other press falls through
## untouched. That is the rule the talk driver and the cat grab already follow.

## Where a swing landed and how wide the bite was. Announced rather than acted on, so
## anything that cares about digging - gold in the seam today, something else tomorrow -
## hangs off the signal instead of being wired into the swing.
signal mined(at: Vector4, radius: float)

@export var player_path: NodePath
@export var camera_path: NodePath
@export var inventory_path: NodePath
@export var catcher_path: NodePath
## Which belt entry is a pickaxe. Named rather than assumed, so a second tool is a second
## node with a different name in it.
@export var tool_effect: String = "found_pickaxe"

@export_group("In hand")
## Where the prop hangs. The avatar's own right elbow, so it inherits the arm's swing for
## free and a walk carries the pickaxe without a line of code about walking.
@export var avatar_path: NodePath
@export_range(0.1, 2.0, 0.05) var swing_seconds: float = 0.45
## How the tool leans in the fist, in degrees off the forearm. 0 continues the arm like a
## staff held out in front of you; 90 crosses it at a right angle, which is what a fist
## closed round a haft actually does and what this wants.
@export_range(0.0, 90.0, 1.0) var haft_lean: float = 90.0
## The two ends of the arc, as angles at the shoulder.
##
## MEASURED, AND THE FIRST PAIR SWUNG BEHIND HIM. Basis4D.from_yz turns the limb's down
## axis to (0, -cos, -sin), so 0 hangs it down, PI stands it straight up, +PI/2 points it
## BACKWARD and -PI/2 forward - this scene faces +Z. Winding up to +2.4 and striking to
## -0.9 therefore raises the arm up and BEHIND, then drags it down through the back and
## only reaches the front on the last frame. Tracked at the hand: it sat 0.35 behind the
## shoulder for the whole swing and finished 0.30 in front.
##
## Both ends are negative now, so the arm lifts forward and up and comes down forward -
## the whole arc happens where the rock is and where the player is looking.
@export_range(-6.3, 6.3, 0.05) var windup_angle: float = -2.7
@export_range(-6.3, 6.3, 0.05) var strike_angle: float = -0.9
@export var haft_color: Color = Color(0.55, 0.36, 0.20)
@export var head_color: Color = Color(0.72, 0.75, 0.79)

@export_group("Reach")
## Metres. Melee, not a hitscan weapon's reach.
@export_range(0.5, 8.0, 0.1) var reach: float = 3.0
## How far up the body the swing starts.
@export_range(0.0, 2.5, 0.05) var chest_height: float = 1.0

var _player: Node4D
var _camera: Node4D
var _inventory: Node
var _catcher: Node
var _avatar: Node4D
var _prop: Node4D
## Seconds into the current swing, or -1 when the arm belongs to the walk again.
var _swinging: float = -1.0


func _ready() -> void:
	# AFTER THE GAIT, DELIBERATELY. The walk writes the arm's pose every frame and the
	# swing has to overwrite it, so this runs late rather than being moved in the tree -
	# process_priority orders it without anybody else's node having to move.
	process_priority = 20
	_avatar = get_node_or_null(avatar_path) as Node4D
	_player = get_node_or_null(player_path) as Node4D
	_camera = get_node_or_null(camera_path) as Node4D
	_inventory = get_node_or_null(inventory_path)
	_catcher = get_node_or_null(catcher_path)
	if _player == null or _camera == null or _inventory == null:
		push_warning("PenPickaxe: player, camera or inventory missing - nothing can be mined.")


## The prop, built once and hidden rather than made and unmade as it is chosen. It hangs
## off the avatar's own elbow, so the walk cycle carries it and nothing here knows how to
## walk; only the swing is this node's business.
##
## BUILT LATE, AND REBUILT IF IT GOES. block_avatar_4d frees every child when it rebuilds
## itself, which it does whenever one of its colours is touched - so a prop parented into
## it can vanish without warning. Checking it is still there costs one null test a frame.
func _hang_it() -> void:
	if _avatar == null:
		return
	var hand: Node4D = _avatar.get("elbow_right") as Node4D
	if hand == null or (_prop != null and is_instance_valid(_prop) and _prop.get_parent() == hand):
		return
	_prop = Node4D.new()
	_prop.name = "Pickaxe"
	hand.add_child(_prop)
	# Held at the bottom of the haft with the head above the fist, which is how a pickaxe
	# is carried and also what keeps it clear of the leg while walking.
	_prop.position = Vector4(0.0, -0.20, 0.0, 0.0)
	_prop.basis = _grip()
	_haft()


## SIZED TO THE CHIBI, which is smaller than it sounds. The first version had a haft 0.72
## long against an arm of 0.36, which put the head of the pickaxe level with the shoulder
## - right on the pivot it is supposed to swing around, so the whole arc moved it about
## nine centimetres. The head now sits a little above the fist and well below the
## shoulder, which is what gives the swing something to travel.
## THE GRIP IS BUILT FROM THE AXES IT SHOULD HAVE, not from a stack of quarter turns.
##
## Three rounds went by turning it ninety degrees in one plane after another and looking:
## each fixed one view and broke the next, because a quarter turn moves all three axes and
## only one of them was ever being judged. Naming the axes instead settles all three at
## once and reads as what it is.
##
## The prop is modelled with its haft along local +Y and its picks along local +/-X. In
## the elbow's frame -Y runs down the forearm and +Z is the way the character faces, so:
##
##   the haft leans up and FORWARD out of the fist, head uppermost
##   the picks cross it in the same plane the arm swings through, so they bite
##   what is left over points sideways, which is the one direction nothing wants
##
## Right-handed, so the third column is the cross of the first two and not a guess: for
## picks (0,-s,c) and haft (0,c,s) that cross comes out (-1,0,0).
func _grip() -> Projection:
	var lean: float = deg_to_rad(haft_lean)
	var haft := Vector4(0.0, cos(lean), sin(lean), 0.0)
	var picks := Vector4(0.0, -sin(lean), cos(lean), 0.0)
	return Projection(picks, haft, Vector4(-1.0, 0.0, 0.0, 0.0), Vector4(0.0, 0.0, 0.0, 1.0))


func _haft() -> void:
	_block("Haft", Vector4(0.0, 0.04, 0.0, 0.0), Vector3(0.026, 0.40, 0.026), haft_color)
	_block("Collar", Vector4(0.0, 0.21, 0.0, 0.0), Vector3(0.062, 0.070, 0.062), head_color)
	_block("Cap", Vector4(0.0, 0.25, 0.0, 0.0), Vector3(0.032, 0.028, 0.032), haft_color)
	# Two picks, each three blocks that shrink and droop as they go out. Blocky rather
	# than curved, to sit with everything else in this scene.
	for side in [-1.0, 1.0]:
		var tag: String = "L" if side < 0.0 else "R"
		var steps := [[0.070, 0.224, 0.094, 0.040, 0.10], [0.152, 0.212, 0.078, 0.033, 0.26],
			[0.218, 0.182, 0.058, 0.025, 0.45]]
		for i in steps.size():
			var step: Array = steps[i]
			var part: MeshInstance4D = _block("Pick%s%d" % [tag, i],
				Vector4(side * float(step[0]), float(step[1]), 0.0, 0.0),
				Vector3(float(step[2]), float(step[3]), 0.030), head_color)
			part.basis = Basis4D.from_xy(-side * float(step[4]))


func _block(part: String, at: Vector4, size: Vector3, colour: Color) -> MeshInstance4D:
	var node := MeshInstance4D.new()
	node.name = part
	var mesh := BoxTetraMesh4D.new()
	# A real extent through W, or the tool vanishes the moment the slice moves.
	mesh.size = Vector4(size.x, size.y, size.z, 0.30)
	node.mesh = mesh
	var material := TetraMaterial4D.new()
	material.albedo_color = colour
	node.material_override = material
	_prop.add_child(node)
	node.position = at
	return node


func _process(delta: float) -> void:
	_hang_it()
	var in_hand: bool = _inventory != null \
		and String(_inventory.call("selected_effect")) == tool_effect
	if _prop != null and is_instance_valid(_prop):
		_prop.visible = in_hand
	if _swinging < 0.0:
		return
	_swinging += delta
	var t: float = clampf(_swinging / maxf(swing_seconds, 0.01), 0.0, 1.0)
	_pose(t)
	if t >= 1.0:
		_swinging = -1.0


## The arc, as one angle at the shoulder. Up and back for the first third, then over and
## down - which is the whole of a pickaxe swing and needs no more joints than that.
##
## THE SIGNS ARE MEASURED, NOT REASONED. Basis4D.from_yz(0) hangs the arm straight down
## and from_yz(PI) puts it straight up, so anything between PI/2 and PI is up-and-BACK and
## anything negative is forward-and-down. That was settled by sweeping the angle and
## watching where the head of the pickaxe ended up, the same way the gauntlet's raised arm
## was, because neither sign is obvious from the name of the function.
func _pose(t: float) -> void:
	if _avatar == null:
		return
	var shoulder: Node4D = _avatar.get("shoulder_right") as Node4D
	var elbow: Node4D = _avatar.get("elbow_right") as Node4D
	if shoulder == null:
		return
	var lift: float = windup_angle
	var strike: float = strike_angle
	var angle: float = 0.0
	if t < 0.35:
		# Wind up quickly, then hold for an instant at the top.
		angle = lerpf(0.0, lift, ease(t / 0.35, 0.4))
	else:
		# And down, fast at first so the contact reads as a hit rather than a wave.
		angle = lerpf(lift, strike, ease((t - 0.35) / 0.65, 2.6))
	shoulder.basis = Basis4D.from_yz(angle)
	if elbow != null:
		elbow.basis = Basis4D.from_yz(lerpf(-0.6, 0.0, clampf(t * 1.6, 0.0, 1.0)))


func _input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"fire"):
		return
	if not _armed():
		return
	# The arm moves on every press. Only a press that actually reaches rock swallows the
	# button, but a swing at thin air is still a swing and has to look like one.
	_swinging = 0.0
	if _swing():
		get_viewport().set_input_as_handled()


## Pickaxe in hand, hands otherwise empty, and a pointer that is not being used to click
## about the interface.
func _armed() -> bool:
	if _player == null or _camera == null or _inventory == null:
		return false
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return false
	if _catcher != null and _catcher.get("carried") != null:
		return false
	return String(_inventory.call("selected_effect")) == tool_effect


## Returns whether anything was actually hit, because only a real hit should swallow the
## button - a swing at thin air has to fall through to whatever else wanted the press.
func _swing() -> bool:
	var from: Vector4 = _player.global_position + Vector4(0.0, chest_height, 0.0, 0.0)
	# The camera looks along its own -Z, the same axis a press of forward moves you along.
	var along: Vector4 = (_camera.global_basis * Vector4(0.0, 0.0, -1.0, 0.0)).normalized()
	var params := RaycastParameters4D.new()
	params.global_ray_origin = from
	params.global_ray_direction = along
	params.set_exclude_nodes([_player])
	var hit: Dictionary = PhysicsServer4D.raycast_physics_objects(params)
	if not bool(hit.get("hit", false)):
		return false
	if float(hit.get("global_distance", INF)) > reach:
		return false
	# The body that owns the hit shape is the rock's "Voxels" StaticBody4D, so the rock
	# itself is its parent - the same hop VoxelMining's own axe makes.
	var body: Object = hit.get("body")
	if body == null:
		return false
	var rock: Object = (body as Node).get_parent()
	if rock == null or not rock.has_method("mine_at_shape"):
		return false
	rock.call("mine_at_shape", hit.get("shape"))
	var bite: Variant = rock.get("mining_radius_meters")
	mined.emit(hit.get("position", from), float(bite) if bite != null else 0.5)
	return true
